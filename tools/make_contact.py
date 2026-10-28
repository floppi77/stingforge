#!/usr/bin/env python3
"""Kontaktbogen: alle Sprites des Manifests mit Beschriftung.

Schreibt assets/sprites/_contact.png
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SPR = ROOT / "assets" / "sprites"

GROUPS = [
    ("SPIELER", ["bee", "drone"]),
    ("GEGNER", ["moth", "beetle", "wasp", "aphid", "pod", "ladybug", "borer", "grub",
                "dragonfly", "mosquito", "hopper", "pike", "spore", "mushroom", "vine",
                "mantis", "glassdrone", "mirrororb", "crawler", "sludge", "piston",
                "generator", "hiveguard", "acolyte", "shard"]),
    ("BOSSE", ["boss_beetle", "boss_larva", "boss_pike", "boss_fungus", "boss_mantis",
               "boss_pollinator", "boss_skater", "boss_harvester", "boss_queen", "boss_core"]),
    ("GESCHOSSE", ["bullet_base", "bullet_fan", "bullet_lightning", "bullet_plasma", "bomb",
                   "ebullet_orb", "ebullet_needle", "ebullet_spore", "ebullet_laser"]),
    ("PICKUPS", ["blossom", "nectar", "heart"]),
    ("EFFEKTE", ["explode", "spark", "pollen", "ring"]),
    ("UI-ICONS", ["icon_base", "icon_fan", "icon_lightning", "icon_plasma", "icon_companion",
                  "icon_bombs", "icon_shield", "icon_speed", "icon_repair", "icon_hp",
                  "icon_nectar", "icon_shieldbar", "icon_autofire"]),
    ("LOGO / ICON", ["logo", "icon"]),
]


def main() -> None:
    man = json.loads((SPR / "manifest.json").read_text())
    pad, label_h, group_h = 10, 13, 20
    bg = (22, 24, 31, 255)
    cols = 3
    rows = []
    for title, names in GROUPS:
        names = [n for n in names if n in man]
        cells = []
        for n in names:
            im = Image.open(SPR / f"{n}.png").convert("RGBA")
            scale = 1.0
            if im.width > 380:
                scale = 0.5
            elif im.width > 190:
                scale = 0.7
            if scale != 1.0:
                im = im.resize((int(im.width * scale), int(im.height * scale)), Image.NEAREST)
            cells.append((n, im))
        rows.append((title, cells))

    col_w = 300
    # Zeilenhöhe = höchstes Sprite dieser Zeile
    layout = []
    for title, cells in rows:
        bands = [cells[i:i + cols] for i in range(0, len(cells), cols)]
        band_heights = [max(im.height for _, im in b) + label_h + pad for b in bands] or [pad]
        layout.append((title, bands, band_heights))

    total_h = pad
    for title, bands, bh in layout:
        total_h += group_h + sum(bh)
    width = cols * col_w + pad
    canvas = Image.new("RGBA", (width, total_h + pad), bg)
    d = ImageDraw.Draw(canvas)

    y = pad
    for title, bands, bh in layout:
        d.text((pad, y), title, fill=(255, 214, 120))
        d.line([(pad, y + 12), (width - pad, y + 12)], fill=(80, 70, 50))
        y += group_h
        for (band, h) in zip(bands, bh):
            for i, (n, im) in enumerate(band):
                cx = pad + i * col_w
                m = man[n]
                d.text((cx, y), f"{n} {m['w']}x{m['h']} {m['frames']}f@{m['fps']}",
                       fill=(140, 160, 190))
                canvas.alpha_composite(im, (cx, y + label_h))
            y += h

    canvas.save(SPR / "_contact.png")
    print(f"_contact.png {canvas.width}x{canvas.height}")


if __name__ == "__main__":
    main()
