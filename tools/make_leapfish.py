#!/usr/bin/env python3
"""Springfisch (Barsch) für Wasserlevel: Pixelsprite aus assets/aseprite/generated/leapfish_src.png.
Drei Bilder mit schlagender Schwanzflosse; Manifest-Eintrag wird ergänzt."""
from pathlib import Path
import importlib.util
import json

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GEN = ROOT / 'assets/aseprite/generated'
OUT = ROOT / 'assets/sprites'
spec = importlib.util.spec_from_file_location('mb', ROOT / 'tools/make_bosses.py')
mb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mb)
px = mb.px

NAME = 'leapfish'
SIZE = (42, 32)


def tail(img: Image.Image, dy: int) -> Image.Image:
    """Schwanzflosse (rechtes Drittel) um dy Pixel auf- oder abschlagen lassen."""
    a = np.asarray(img).copy()
    x0 = int(a.shape[1] * 0.70)
    part = np.zeros_like(a[:, x0:])
    if dy > 0:
        part[dy:] = a[:-dy, x0:]
    else:
        part[:dy] = a[-dy:, x0:]
    a[:, x0:] = part
    return Image.fromarray(a, 'RGBA')


def eye(img: Image.Image) -> Image.Image:
    """Auge nachsetzen (geht beim Verkleinern verloren): gelber Ring, schwarze Pupille."""
    a = np.asarray(img).copy()
    ys, xs = np.nonzero(a[:, :, 3])
    x = int(xs.min() + (xs.max() - xs.min()) * 0.15)
    y = int(ys.min() + (ys.max() - ys.min()) * 0.30)
    a[y:y + 2, x:x + 2] = (255, 196, 64, 255)
    a[y + 1, x] = (12, 8, 20, 255)
    return Image.fromarray(a, 'RGBA')


def main():
    tmp = ROOT / 'build/leapfish'
    tmp.mkdir(parents=True, exist_ok=True)
    one = px.run(GEN / 'leapfish_src.png', tmp / 'leapfish_f1.png', SIZE, True, 18, 'border', 80, 0.2, True,
                 (0.06, 0.04, 0.92, 0.94), 1.15, 1.1, (12, 8, 20), 1)
    one = eye(one)
    mb.strip([one, tail(one, -1), tail(one, 1)]).save(OUT / f'{NAME}.png')
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    manifest[NAME] = {'w': SIZE[0], 'h': SIZE[1], 'frames': 3, 'fps': 12}
    manifest_path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
    print('LEAPFISH_OK', SIZE)


if __name__ == '__main__':
    main()
