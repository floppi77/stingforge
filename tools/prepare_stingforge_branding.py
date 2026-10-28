#!/usr/bin/env python3
"""Übernimmt das transparente Nutzerlogo bytegleich und erstellt ein Spielsymbol."""
from pathlib import Path
import argparse
import hashlib
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('logo', type=Path)
    args = parser.parse_args()
    image = Image.open(args.logo)
    assert image.mode == 'RGBA' and image.getchannel('A').getextrema() == (0, 255)
    target = ROOT / 'assets/ui/menu'
    shots = ROOT / 'docs/stingforge'
    target.mkdir(parents=True, exist_ok=True)
    shots.mkdir(parents=True, exist_ok=True)
    for output in [target / 'stingforge.png', shots / 'logo_source.png']:
        if args.logo.resolve() != output.resolve():
            shutil.copyfile(args.logo, output)
    # Eigenes lesbares Emblem für kleine Fenster-/Dateisymbole: Bernstein-Stachel,
    # Chitin und die eisblauen Flügel des gelieferten Logos, kein winziger Schriftzug.
    s = 4
    icon = Image.new('RGBA', (256*s, 256*s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    def poly(points, fill, outline=None, width=1):
        points = [(round(x*s), round(y*s)) for x, y in points]
        draw.polygon(points, fill=fill)
        if outline:
            draw.line(points + [points[0]], fill=outline, width=width*s, joint='curve')
    poly([(128,8),(231,67),(231,190),(128,248),(25,190),(25,67)], '#082123', '#e2b754', 5)
    poly([(119,99),(43,51),(57,103),(108,135)], '#73d5e5', '#d3ad55', 3)
    poly([(137,99),(213,51),(199,103),(148,135)], '#73d5e5', '#d3ad55', 3)
    poly([(119,111),(55,82),(64,111),(112,140)], '#2e8596', '#c5f4ed', 1)
    poly([(137,111),(201,82),(192,111),(144,140)], '#2e8596', '#c5f4ed', 1)
    poly([(128,44),(145,111),(158,132),(140,165),(128,221),(116,165),(98,132),(111,111)], '#1b1812', '#edbb46', 4)
    poly([(128,62),(137,115),(147,132),(131,160),(128,202),(124,155),(109,132),(122,113)], '#f0a52e')
    poly([(128,83),(132,121),(140,131),(128,151),(118,131),(126,118)], '#ffe998')
    icon = icon.resize((256,256), Image.Resampling.LANCZOS)
    icon.save(target / 'stingforge_icon.png')
    icon.save(target / 'stingforge.ico', sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
    digest = hashlib.sha256((target / 'stingforge.png').read_bytes()).hexdigest()
    print('Logo bytegleich:', digest, 'RGBA:', image.size)
    print('Symbol:', target / 'stingforge_icon.png')


if __name__ == '__main__':
    main()
