#!/usr/bin/env python3
"""Baut die Boss-Spritestreifen aus den Vorlagen in assets/aseprite/generated.

Je Boss zwei Animationsbilder im bisherigen Format (Breite = 2 × Feld). Bild 2
lässt die untere Körperpartie (Beine, Wurzeln) um einen Pixel zucken und hebt
Leuchtstellen an. Die Kernorganismus-Wiedergeburt erhält drei Glutstufen.
"""
from pathlib import Path
import colorsys
import importlib.util
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GEN = ROOT / 'assets/aseprite/generated'
OUT = ROOT / 'assets/sprites'
spec = importlib.util.spec_from_file_location('pixelize', ROOT / 'tools/pixelize.py')
px = importlib.util.module_from_spec(spec)
spec.loader.exec_module(px)

# name: (Feldgröße, Freistellmodus, Toleranz, Farben, zusätzliche Optionen)
BOSSES = {
    'boss_beetle': ((176, 128), 'border', 70, 30, {'hue': False}),
    'boss_larva': ((176, 120), 'border', 90, 28, {}),
    'boss_pike': ((192, 112), 'border', 70, 30, {}),
    'boss_fungus': ((176, 144), 'border', 90, 30, {}),
    'boss_mantis': ((192, 128), 'border', 75, 28, {}),
    'boss_pollinator': ((176, 120), 'border', 70, 30, {}),
    'boss_skater': ((192, 120), 'border', 75, 26, {}),
    'boss_harvester': ((184, 128), 'border', 90, 30, {}),
    'boss_queen': ((176, 136), 'border', 90, 30, {}),
    'boss_core': ((176, 144), 'border', 80, 30, {}),
}


def frame_pair(img, glow_gain=0.18, twitch_from=0.64):
    a = np.asarray(img).copy()
    b = a.copy()
    h = a.shape[0]
    y0 = int(h * twitch_from)
    b[y0:] = np.roll(a[y0:], 1, axis=1)
    rgb = b[:, :, :3].astype(np.float32) / 255.0
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    bright = (mx > 0.72) & (sat > 0.45) & (b[:, :, 3] > 0)
    rgb[bright] = np.clip(rgb[bright] + glow_gain, 0, 1)
    b[:, :, :3] = (rgb * 255).astype(np.uint8)
    return Image.fromarray(a, 'RGBA'), Image.fromarray(b, 'RGBA')


def strip(frames):
    w, h = frames[0].size
    out = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def ember(img, hue_shift, gain, red):
    """Glutstufe: Farbton leicht verschieben, Leuchtstellen verstärken."""
    a = np.asarray(img).astype(np.float32)
    out = a.copy()
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            if a[y, x, 3] == 0:
                continue
            r, g, b = a[y, x, :3] / 255.0
            hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
            hh = (hh + hue_shift) % 1.0
            if ss > 0.4 and ll > 0.35:
                ll = min(1.0, ll * gain)
            r, g, b = colorsys.hls_to_rgb(hh, ll, ss)
            r = min(1.0, r + red * ll)
            out[y, x, :3] = (r * 255, g * 255, b * 255)
    return Image.fromarray(out.astype(np.uint8), 'RGBA')


def main():
    tmp = ROOT / 'build/r4-bosses'
    tmp.mkdir(parents=True, exist_ok=True)
    for name, (size, key, tol, colors, opts) in BOSSES.items():
        one = px.run(GEN / f'{name}_src.png', tmp / f'{name}_f1.png', size, True, colors, key, tol,
                     0.28, True, None, 1.18, 1.10, (12, 8, 20), 2, opts.get('hue', True))
        f1, f2 = frame_pair(one)
        strip([f1, f2]).save(OUT / f'{name}.png')
        print('BOSS', name, size)
    base = px.run(GEN / 'boss_reborn_src.png', tmp / 'reborn_f1.png', (224, 224), True, 34, 'border', 90,
                  0.28, True, None, 1.15, 1.10, (12, 8, 20), 2)
    for phase, (shift, gain, red) in enumerate([(0.0, 1.0, 0.0), (-0.03, 1.12, 0.05), (-0.06, 1.25, 0.12)], 1):
        img = base if phase == 1 else ember(base, shift, gain, red)
        f1, f2 = frame_pair(img, 0.22 + 0.06 * phase, 0.70)
        strip([f1, f2]).save(OUT / f'boss_reborn_p{phase}.png')
        print('REBORN', phase)
    print('BOSSES_OK')


if __name__ == '__main__':
    main()
