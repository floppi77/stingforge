"""pixelize.py -- Nachbearbeitung der Blender-Renderings zu Pixelgrafik.

Schritte pro Bild:
  1. Rendern laden (PNG, 1920x540), Alpha fuer mid/near hart ausschneiden.
  2. Kontrast/Luminanz-Grading, Kantenbetonung (Sobel, horizontal gewrappt).
  3. Geordnetes Dithering (Bayer 8x8, Periode 8 teilt 1920 -> nahtlos).
  4. Nearest-Match auf die Level-Palette (OKLab-Abstand).
  5. QA: Wrap-Differenz, Farbanzahl, Near-Deckung, Palettenfehler.
Zusaetzlich: assets/bg/palettes.json und assets/bg/_contact.png.

Standalone:  python3 tools/blender/pixelize.py [--levels 1,2]
"""

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import palettes as P  # noqa: E402

W, H = 960, 540
LAYERS = ("far", "mid", "near")

BAYER8 = np.array([
    [0, 32, 8, 40, 2, 34, 10, 42],
    [48, 16, 56, 24, 50, 18, 58, 26],
    [12, 44, 4, 36, 14, 46, 6, 38],
    [60, 28, 52, 20, 62, 30, 54, 22],
    [3, 35, 11, 43, 1, 33, 9, 41],
    [51, 19, 59, 27, 49, 17, 57, 25],
    [15, 47, 7, 39, 13, 45, 5, 37],
    [63, 31, 55, 23, 61, 29, 53, 21],
], dtype=np.float64) / 64.0


# --------------------------------------------------------------------------
# Farbraum
# --------------------------------------------------------------------------
def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def rgb_to_oklab(rgb):
    """rgb: (..., 3) sRGB 0..1 -> OKLab."""
    lin = srgb_to_linear(rgb)
    r, g, b = lin[..., 0], lin[..., 1], lin[..., 2]
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l_ = np.cbrt(l)
    m_ = np.cbrt(m)
    s_ = np.cbrt(s)
    return np.stack([
        0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
    ], axis=-1)


def luma(rgb):
    return (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2])


# --------------------------------------------------------------------------
# Dither-Muster
# --------------------------------------------------------------------------
def bayer_field(h, w):
    ty = np.arange(h) % 8
    tx = np.arange(w) % 8
    return BAYER8[np.ix_(ty, tx)]


# --------------------------------------------------------------------------
# Quantisierung
# --------------------------------------------------------------------------
class Quantizer:
    def __init__(self, colors, dither=0.052, chroma=0.85):
        self.colors = np.array([hex_to_rgb(c) for c in colors], dtype=np.float64)
        self.lab = rgb_to_oklab(self.colors)
        self.lab[:, 0] *= 1.0
        self.lab[:, 1] *= chroma
        self.lab[:, 2] *= chroma
        self.dither = dither
        self.n = len(colors)

    def apply(self, rgb, edge_weight=0.0, contrast=1.0, lift=0.0,
              dither_scale=1.0, x_wrap=True):
        lab = rgb_to_oklab(rgb)
        lab[..., 1] *= 0.85
        lab[..., 2] *= 0.85
        lab[..., 0] = (lab[..., 0] - 0.5) * contrast + 0.5 + lift

        if edge_weight > 0.0:
            y = luma(rgb)
            gx = np.roll(y, -1, axis=1) - np.roll(y, 1, axis=1)
            gy = np.roll(y, -1, axis=0) - np.roll(y, 1, axis=0)
            mag = np.hypot(gx, gy)
            hi = np.percentile(mag, 98.0)
            mag = np.clip(mag / (hi + 1e-6), 0.0, 1.0) ** 0.8
            lab[..., 0] -= edge_weight * mag

        if self.dither > 0.0 and dither_scale > 0.0:
            # Dithering nur in weichen Verlaeufen (grosser Massstab) --
            # grosse, gleichmaessig beleuchtete Flaechen bleiben sauber.
            y8 = luma(rgb)
            g8 = np.hypot(np.roll(y8, -8, axis=1) - np.roll(y8, 8, axis=1),
                          np.roll(y8, -8, axis=0) - np.roll(y8, 8, axis=0))
            gate = np.clip(g8 / 0.014, 0.0, 1.0) ** 0.75
            f = (bayer_field(rgb.shape[0], rgb.shape[1]) - 0.5) * \
                self.dither * dither_scale * gate
            lab[..., 0] += f
            lab[..., 1] += f * 0.55
            lab[..., 2] += f * 0.55

        h, w = rgb.shape[0], rgb.shape[1]
        flat = lab.reshape(-1, 3)
        pal = self.lab
        idx = np.empty(flat.shape[0], dtype=np.int32)
        dmin = np.empty(flat.shape[0], dtype=np.float64)
        step = 262144
        for i in range(0, flat.shape[0], step):
            chunk = flat[i:i + step]
            d = ((chunk[:, None, 0] - pal[None, :, 0]) ** 2 +
                 (chunk[:, None, 1] - pal[None, :, 1]) ** 2 +
                 (chunk[:, None, 2] - pal[None, :, 2]) ** 2)
            idx[i:i + step] = d.argmin(axis=1)
            dmin[i:i + step] = np.sqrt(d.min(axis=1))
        return idx.reshape(h, w), dmin.reshape(h, w)


# --------------------------------------------------------------------------
# Bildverarbeitung
# --------------------------------------------------------------------------
def load_raw(path):
    im = Image.open(path).convert("RGBA")
    if im.size != (W, H):
        im = im.resize((W, H), Image.BOX)
    a = np.asarray(im, dtype=np.uint8)
    return a


def process_layer(level_id, layer, raw_path, out_path, settings=None):
    settings = settings or {}
    arr = load_raw(raw_path)
    rgb = arr[:, :, :3].astype(np.float64) / 255.0
    alpha = arr[:, :, 3]

    if layer == "far":
        mask = np.ones((H, W), dtype=bool)
    else:
        mask = alpha >= 128

    q = Quantizer(P.all_colors(level_id), dither=settings.get("dither", 0.052))
    idx, err = q.apply(rgb,
                       edge_weight=settings.get("edge", 0.055),
                       contrast=settings.get("contrast", 1.06),
                       lift=settings.get("lift", 0.0),
                       dither_scale=settings.get("dither_scale", 1.0))
    out = q.colors[idx]
    out_u8 = np.clip(np.round(out * 255.0), 0, 255).astype(np.uint8)

    if layer == "far":
        img = Image.fromarray(out_u8, mode="RGB")
    else:
        rgba = np.zeros((H, W, 4), dtype=np.uint8)
        rgba[:, :, :3] = out_u8 * mask[:, :, None]
        rgba[:, :, 3] = np.where(mask, 255, 0).astype(np.uint8)
        img = Image.fromarray(rgba, mode="RGBA")
    img.save(out_path, optimize=True)

    stats = dict(
        file=os.path.basename(out_path),
        size=list(img.size),
        mode=img.mode,
        colors=int(len(np.unique(out_u8[mask].reshape(-1, 3), axis=0))) if mask.any() else 0,
        palette_size=q.n,
        mean_palette_err=round(float(err[mask].mean()), 4) if mask.any() else 0.0,
        coverage=round(float(mask.mean()), 4),
    )
    stats["mid_band_coverage"] = round(float(mask[200:340, :].mean()), 4)
    stats["wrap_diff"] = wrap_diff(img, mask)
    stats["neighbor_diff"] = neighbor_diff(img, mask)
    return img, stats


def _cmp_arr(img, mask):
    a = np.asarray(img, dtype=np.int16)
    if img.mode == "RGBA":
        return a[:, :, :3], mask
    return a, mask


def wrap_diff(img, mask):
    a, m = _cmp_arr(img, mask)
    a = a.astype(np.int32)
    col0 = a[:, 0, :]
    col1 = a[:, -1, :]
    both = m[:, 0] | m[:, -1]
    if not both.any():
        return 0.0
    d = np.abs(col0[both] - col1[both]).mean()
    return round(float(d), 2)


def neighbor_diff(img, mask):
    a, m = _cmp_arr(img, mask)
    a = a.astype(np.int32)
    ds = []
    for x in range(1, W - 1):
        both = m[:, x] & m[:, x + 1]
        if both.any():
            ds.append(np.abs(a[both, x, :] - a[both, x + 1, :]).mean())
    return round(float(np.mean(ds)), 2) if ds else 0.0


def contact_sheet(entries, out_path, root):
    cols, rows = 3, 10
    tw, th = 480, 270
    pad = 10
    label_w = 96
    sheet_w = label_w + cols * (tw + pad) + pad
    sheet_h = pad + rows * (th + pad + 14)
    sheet = Image.new("RGB", (sheet_w, sheet_h), (16, 16, 20))
    draw = ImageDraw.Draw(sheet)
    font_path = os.path.join(root, "assets/ui/fonts/DejaVuSans.ttf")
    try:
        font = ImageFont.truetype(font_path, 15)
        small = ImageFont.truetype(font_path, 11)
    except Exception:
        font = ImageFont.load_default()
        small = font
    bg = Image.new("RGB", (tw, th), (40, 40, 46))
    for r in range(rows):
        for c in range(cols):
            draw.text((6, pad + r * (th + pad + 14) + th // 2 - 8),
                      "L%02d" % (r + 1), font=font, fill=(220, 220, 230))
            if c == 0:
                draw.text((pad + c * (tw + pad), pad + r * (th + pad + 14) - 12),
                          LAYERS[c].upper(), font=small, fill=(150, 150, 165))
    for (path, level_id, layer) in entries:
        r = level_id - 1
        c = LAYERS.index(layer)
        try:
            im = Image.open(path).convert("RGBA").resize((tw, th), Image.LANCZOS)
        except FileNotFoundError:
            continue
        tile = bg.copy()
        tile.paste(im, (0, 0), im)
        x = label_w + c * (tw + pad)
        y = pad + r * (th + pad + 14)
        sheet.paste(tile, (x, y))
        draw.rectangle([x - 1, y - 1, x + tw, y + th], outline=(70, 70, 80))
        draw.text((x + 4, y + th - 13), "%s_%s" % (P.BY_ID[level_id]["key"], layer),
                  font=small, fill=(200, 200, 210))
    sheet.save(out_path, optimize=True)
    return out_path


def write_palettes_json(root, outdir):
    data = {}
    for lv in P.LEVELS:
        colors = P.all_colors(lv["id"])
        data[lv["key"]] = dict(
            level=lv["id"], name=lv["name"], count=len(colors),
            colors=colors, ramps=lv["ramps"],
        )
    path = os.path.join(outdir, "palettes.json")
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
    return path


SETTINGS = {
    1: dict(edge=0.050, contrast=1.06, dither=0.038),
}


def run(root, outdir, rawdir, level_ids=None):
    level_ids = level_ids or [lv["id"] for lv in P.LEVELS]
    qa = {}
    entries = []
    for lv in level_ids:
        key = P.BY_ID[lv]["key"]
        for layer in LAYERS:
            raw = os.path.join(rawdir, "%s_%s.png" % (key, layer))
            out = os.path.join(outdir, "%s_%s.png" % (key, layer))
            if not os.path.exists(raw):
                print("[post][skip] fehlt: %s" % raw)
                continue
            img, st = process_layer(lv, layer, raw, out,
                                    SETTINGS.get(lv, {}))
            qa["%s_%s" % (key, layer)] = st
            entries.append((out, lv, layer))
            print("[post] %-14s colors=%2d wrap=%5.2f nb=%5.2f "
                  "cov=%4.1f%% mid=%4.1f%%" %
                  (st["file"], st["colors"], st["wrap_diff"],
                   st["neighbor_diff"], 100.0 * st["coverage"],
                   100.0 * st["mid_band_coverage"]))
    pal_path = write_palettes_json(root, outdir)
    if entries:
        contact_sheet(entries, os.path.join(outdir, "_contact.png"), root)
    with open(os.path.join(outdir, "_qa.json"), "w") as f:
        json.dump(qa, f, indent=1)
    print("[post] Palette: %s" % pal_path)
    return qa


def main():
    root = os.path.dirname(os.path.dirname(HERE))
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="1,2,3,4,5,6,7,8,9,10")
    ap.add_argument("--outdir", default="assets/bg")
    ap.add_argument("--rawdir", default="tools/blender/_raw")
    args = ap.parse_args()
    ids = [int(v) for v in args.levels.split(",") if v.strip()]
    run(root, os.path.join(root, args.outdir),
        os.path.join(root, args.rawdir), level_ids=ids)


if __name__ == "__main__":
    main()
