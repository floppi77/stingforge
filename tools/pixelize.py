#!/usr/bin/env python3
"""Überführt eine Bildvorlage in echte Pixelart.

Schritte: Hintergrund freistellen (Randfarbe oder Schwarz), auf das Zielraster
verkleinern (Flächenmittel), Kontrast/Sättigung leicht anheben, Palette mit
Median-Cut bestimmen, geordnetes 4×4-Dithering (Amiga-typisch) zur Palette,
optional dunkle Außenkontur und Entfernen verirrter Einzelpixel.

Beispiel:
  tools/pixelize.py vorlage.png ziel.png --size 176x128 --fit --colors 28 \\
      --key border --outline --dither 0.35
"""
from pathlib import Path
import argparse
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

HUE_TOL = 0.06
BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0 - 0.5


def key_mask(img, mode, tol, hue_key=True):
    """Alphamaske: verbundener Hintergrund ab dem Bildrand wird transparent."""
    rgb = np.asarray(img.convert('RGB')).astype(np.float32)
    h, w, _ = rgb.shape
    if mode == 'black':
        bg = np.array([0, 0, 0], np.float32)
    else:
        border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
        bg = np.median(border, axis=0)
    dist = np.sqrt(((rgb - bg) ** 2).sum(axis=2))
    near = dist < tol
    # Nur mit dem Rand verbundene Hintergrundflächen entfernen (Flutfüllung).
    from collections import deque
    seen = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and near[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    # Zusätzlich: eingeschlossene Inseln, Schatten und Säume im Farbton des Grundes
    # (Sättigung hoch, Helligkeit beliebig) – nicht nur mit dem Rand verbundene Flächen.
    if mode != 'black' and hue_key:
        import colorsys
        bh, bs, bv = colorsys.rgb_to_hsv(*(bg / 255.0))
        c = rgb / 255.0
        mx = c.max(axis=2)
        mn = c.min(axis=2)
        sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
        d = mx - mn + 1e-6
        r, g, b = c[..., 0], c[..., 1], c[..., 2]
        hue = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6.0
        dh = np.minimum(np.abs(hue - bh), 1 - np.abs(hue - bh))
        seen |= (dh < HUE_TOL) & (sat > 0.32) & (mx > 0.12)
    alpha = np.where(seen, 0, 255).astype(np.uint8)
    out = img.convert('RGBA')
    out.putalpha(Image.fromarray(alpha).filter(ImageFilter.MinFilter(3)))
    return out


def palette_of(img, colors):
    q = img.convert('RGB').quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = np.array(q.getpalette()[:colors * 3], np.float32).reshape(-1, 3)
    return pal


def ordered(rgb, pal, strength):
    h, w, _ = rgb.shape
    spread = strength * 48.0
    thr = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w][..., None] * spread
    src = rgb + thr
    d = ((src[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(axis=3)
    return pal[d.argmin(axis=2)]


def despeckle(rgb, alpha):
    """Einzelpixel ohne gleichfarbigen Nachbarn erhalten die häufigste Nachbarfarbe."""
    h, w, _ = rgb.shape
    out = rgb.copy()
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if alpha[y, x] == 0:
                continue
            c = rgb[y, x]
            nb = [rgb[y + dy, x + dx] for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1))
                  if alpha[y + dy, x + dx] > 0]
            if nb and not any((n == c).all() for n in nb):
                vals, counts = np.unique(np.array(nb), axis=0, return_counts=True)
                if counts.max() >= 3:
                    out[y, x] = vals[counts.argmax()]
    return out


def outline(rgb, alpha, color):
    h, w = alpha.shape
    solid = alpha > 0
    ring = np.zeros_like(solid)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        shifted = np.zeros_like(solid)
        ys = slice(max(dy, 0), h + min(dy, 0))
        yd = slice(max(-dy, 0), h + min(-dy, 0))
        xs = slice(max(dx, 0), w + min(dx, 0))
        xd = slice(max(-dx, 0), w + min(-dx, 0))
        shifted[yd, xd] = solid[ys, xs]
        ring |= shifted
    ring &= ~solid
    rgb = rgb.copy()
    rgb[ring] = color
    alpha = alpha.copy()
    alpha[ring] = 255
    return rgb, alpha


def run(src, dst, size, fit, colors, key, tol, dither, do_outline, crop, sat, contrast, ink, pad, hue_key=True):
    img = Image.open(src).convert('RGBA')
    if crop:
        x0, y0, x1, y1 = crop
        W, H = img.size
        img = img.crop((int(x0 * W), int(y0 * H), int(x1 * W), int(y1 * H)))
    if key:
        img = key_mask(img, key, tol, hue_key)
        bbox = img.getchannel('A').getbbox()
        if bbox:
            img = img.crop(bbox)
    img = ImageEnhance.Color(img).enhance(sat)
    img = ImageEnhance.Contrast(img).enhance(contrast)
    tw, th = size
    inner = (tw - 2 * pad, th - 2 * pad)
    if fit:
        k = min(inner[0] / img.width, inner[1] / img.height)
        nw, nh = max(1, round(img.width * k)), max(1, round(img.height * k))
    else:
        nw, nh = inner
    small = img.resize((nw, nh), Image.Resampling.BOX)
    arr = np.asarray(small).astype(np.float32)
    alpha = np.where(arr[:, :, 3] >= 128, 255, 0).astype(np.uint8)
    rgb = arr[:, :, :3]
    pal = palette_of(Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)), colors)
    rgb = ordered(rgb, pal, dither)
    rgb = despeckle(rgb, alpha)
    if do_outline:
        canvas_rgb = np.zeros((nh + 2, nw + 2, 3), np.float32)
        canvas_a = np.zeros((nh + 2, nw + 2), np.uint8)
        canvas_rgb[1:-1, 1:-1] = rgb
        canvas_a[1:-1, 1:-1] = alpha
        rgb, alpha = outline(canvas_rgb, canvas_a, np.array(ink, np.float32))
        nw, nh = nw + 2, nh + 2
    out = np.zeros((nh, nw, 4), np.uint8)
    out[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[:, :, 3] = alpha
    piece = Image.fromarray(out, 'RGBA')
    final = Image.new('RGBA', (tw, th), (0, 0, 0, 0))
    final.paste(piece, ((tw - nw) // 2, (th - nh) // 2))
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    final.save(dst)
    return final


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src')
    ap.add_argument('dst')
    ap.add_argument('--size', required=True)
    ap.add_argument('--fit', action='store_true')
    ap.add_argument('--colors', type=int, default=32)
    ap.add_argument('--key', choices=['border', 'black'], default=None)
    ap.add_argument('--tol', type=float, default=60.0)
    ap.add_argument('--dither', type=float, default=0.3)
    ap.add_argument('--outline', action='store_true')
    ap.add_argument('--crop', default='')
    ap.add_argument('--sat', type=float, default=1.15)
    ap.add_argument('--contrast', type=float, default=1.08)
    ap.add_argument('--ink', default='14,10,24')
    ap.add_argument('--pad', type=int, default=1)
    a = ap.parse_args()
    size = tuple(int(v) for v in a.size.split('x'))
    crop = tuple(float(v) for v in a.crop.split(',')) if a.crop else None
    ink = tuple(int(v) for v in a.ink.split(','))
    run(a.src, a.dst, size, a.fit, a.colors, a.key, a.tol, a.dither, a.outline, crop, a.sat, a.contrast,
        ink, a.pad)
    print('PIXELIZE_OK', a.dst)


if __name__ == '__main__':
    main()
