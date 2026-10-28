#!/usr/bin/env python3
"""R4: neue Gegnersprites (Hornisse von hinten, Spinne von oben, Ameise und
Maulwurfsgrille vom Boden) aus den Vorlagen in assets/aseprite/generated.
Je zwei Animationsbilder; Manifest-Einträge werden ergänzt."""
from pathlib import Path
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[1]
GEN = ROOT / 'assets/aseprite/generated'
OUT = ROOT / 'assets/sprites'
spec = importlib.util.spec_from_file_location('mb', ROOT / 'tools/make_bosses.py')
mb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mb)
px = mb.px

# name: (Quelle, Feld, Zuschnitt, Farben, Zuckgrenze)
SPRITES = {
    'hornet': ('hornet_src.png', (44, 32), (0.05, 0.0, 0.95, 0.94), 20, 0.62),
    'spider': ('spider_src.png', (40, 40), (0.0, 0.12, 1.0, 1.0), 18, 0.55),
    'ant_gunner': ('ant_src.png', (48, 34), (0.0, 0.0, 1.0, 0.84), 18, 0.7),
    'molecricket': ('molecricket_src.png', (40, 40), (0.0, 0.0, 1.0, 1.0), 18, 0.5),
}


def main():
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    tmp = ROOT / 'build/r4-enemies'
    tmp.mkdir(parents=True, exist_ok=True)
    for name, (src, size, crop, colors, twitch) in SPRITES.items():
        one = px.run(GEN / src, tmp / f'{name}_f1.png', size, True, colors, 'border', 80, 0.2, True, crop,
                     1.2, 1.12, (12, 8, 20), 1)
        f1, f2 = mb.frame_pair(one, 0.15, twitch)
        mb.strip([f1, f2]).save(OUT / f'{name}.png')
        manifest[name] = {'w': size[0], 'h': size[1], 'frames': 2, 'fps': 8}
        print('ENEMY', name, size)
    manifest_path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
    print('ENEMIES_R4_OK')


if __name__ == '__main__':
    main()
