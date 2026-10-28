#!/usr/bin/env python3
"""Erzeugt das Pixel-UI-Kit (9-Slice-Rahmen, Slots, Ornamente) im 1×-Raster.

Alle Grafiken sind pixelgenau gesetzt (keine Kantenglättung) und werden in Godot
als StyleBoxTexture bzw. Texturen mit Nearest-Filter verwendet. Ausgabe:
assets/ui/kit/*.png. Erneut ausführbar; die Palette steht unten.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/ui/kit'

# Palette: tiefes Indigo, Honiggold, Nektar-Türkis – Amiga-Wärme mit modernem Kontrast.
INK = (8, 7, 18, 255)
SHADOW = (14, 13, 30, 255)
PLATE_D = (20, 22, 44, 255)
PLATE = (27, 31, 60, 255)
PLATE_L = (36, 42, 78, 255)
RIM_L = (70, 82, 132, 255)
RIM_D = (16, 17, 36, 255)
GOLD_D = (122, 70, 18, 255)
GOLD = (226, 156, 36, 255)
GOLD_L = (255, 214, 102, 255)
GOLD_W = (255, 240, 180, 255)
MINT_D = (24, 92, 96, 255)
MINT = (82, 214, 196, 255)
MINT_L = (170, 250, 232, 255)
ROSE = (255, 92, 132, 255)
CLEAR = (0, 0, 0, 0)


def canvas(w, h, fill=CLEAR):
    return Image.new('RGBA', (w, h), fill)


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, c)


def chamfer_mask(w, h, cut):
    """True innerhalb der Plakette mit abgeschrägten Ecken (cut Pixel)."""
    def inside(x, y):
        dx = min(x, w - 1 - x)
        dy = min(y, h - 1 - y)
        return dx + dy >= cut
    return inside


def plate(w, h, cut, fill, fill_top, rim_light, rim_dark, outline=INK, inner=None, notch=None):
    """Plakette: Außenkontur, Lichtkante oben/links, Schattenkante unten/rechts,
    obere Glanzzeilen. `notch` setzt kleine Nieten in die vier Ecken."""
    img = canvas(w, h)
    inside = chamfer_mask(w, h, cut)
    for y in range(h):
        for x in range(w):
            if not inside(x, y):
                continue
            edge = not (inside(x - 1, y) and inside(x + 1, y) and inside(x, y - 1) and inside(x, y + 1))
            if edge:
                put(img, x, y, outline)
                continue
            put(img, x, y, fill_top if y < 4 else fill)
    # Kantenlicht: eine Pixelreihe innerhalb der Kontur.
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y)) in (fill, fill_top):
                up = img.getpixel((x, y - 1)) == outline if y > 0 else True
                left = img.getpixel((x - 1, y)) == outline if x > 0 else True
                down = img.getpixel((x, y + 1)) == outline if y < h - 1 else True
                right = img.getpixel((x + 1, y)) == outline if x < w - 1 else True
                if up or left:
                    put(img, x, y, rim_light)
                elif down or right:
                    put(img, x, y, rim_dark)
    if inner is not None:
        # Zweite, feine Innenlinie (z. B. Goldsaum beim Fokus).
        for y in range(h):
            for x in range(w):
                c = img.getpixel((x, y))
                if c in (fill, fill_top):
                    near = any(img.getpixel((x + dx, y + dy)) in (rim_light, rim_dark)
                               for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                               if 0 <= x + dx < w and 0 <= y + dy < h)
                    if near:
                        put(img, x, y, inner)
    if notch is not None:
        for cx, cy in ((cut + 3, 3), (w - cut - 4, 3), (cut + 3, h - 4), (w - cut - 4, h - 4)):
            put(img, cx, cy, notch)
    return img


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / (name + '.png'))


def main():
    # Panels (Menüspalten, Dialoge): 48×48, Ränder 12 px.
    save(plate(48, 48, 4, PLATE_D, PLATE, RIM_L, RIM_D, notch=RIM_L), 'panel')
    save(plate(48, 48, 4, PLATE_D, PLATE, GOLD, GOLD_D, notch=GOLD_L), 'panel_gold')
    # Menüzeilen: 32×32, Ränder 8 px.
    save(plate(32, 32, 3, PLATE, PLATE_L, RIM_L, RIM_D), 'row')
    save(plate(32, 32, 3, (44, 40, 52, 255), (58, 52, 58, 255), GOLD_L, GOLD_D, inner=GOLD), 'row_focus')
    save(plate(32, 32, 3, PLATE_D, PLATE_D, (40, 46, 78, 255), RIM_D), 'row_disabled')
    save(plate(32, 32, 3, (22, 48, 60, 255), (28, 60, 72, 255), MINT, MINT_D), 'row_accent')
    # Karten (Evolution, Werkstatt-Details): 48×48, Ränder 12 px.
    save(plate(48, 48, 5, PLATE_D, PLATE, RIM_L, RIM_D, notch=RIM_L), 'card')
    save(plate(48, 48, 5, (38, 36, 56, 255), (50, 46, 66, 255), GOLD_L, GOLD_D, inner=GOLD, notch=GOLD_W), 'card_focus')
    # Reiter/Chips: 24×24, Ränder 7 px.
    save(plate(24, 24, 2, PLATE, PLATE_L, RIM_L, RIM_D), 'chip')
    save(plate(24, 24, 2, (66, 46, 20, 255), (86, 60, 24, 255), GOLD_L, GOLD_D), 'chip_on')
    # HUD-Slots und -Instrumente.
    save(plate(40, 40, 4, (16, 18, 36, 255), (24, 27, 52, 255), RIM_L, RIM_D, notch=RIM_L), 'slot')
    save(plate(40, 40, 4, (44, 36, 30, 255), (60, 48, 34, 255), GOLD_L, GOLD_D, inner=GOLD, notch=GOLD_W), 'slot_sel')
    save(plate(40, 40, 4, (18, 40, 50, 255), (24, 52, 62, 255), MINT, MINT_D, notch=MINT_L), 'slot_active')
    save(plate(40, 40, 4, (12, 13, 26, 255), (16, 18, 34, 255), (48, 54, 92, 255), RIM_D), 'gauge')
    # Bandleiste des HUD: 64×64, Ränder 16 px; obere Kante goldene Zierlinie.
    band = plate(64, 64, 0, (14, 15, 32, 255), (20, 22, 44, 255), RIM_L, RIM_D)
    for x in range(1, 63):
        put(band, x, 1, GOLD_D)
        put(band, x, 2, GOLD)
        put(band, x, 3, GOLD_D)
    save(band, 'band')
    # Fokusmarke: Pixelpfeil mit Stachel (12×12).
    arrow = canvas(12, 12)
    shape = ['............', '..##........', '..#o#.......', '..#oo#......', '..#ooo#.....',
             '..#oooo#....', '..#oooo#....', '..#ooo#.....', '..#oo#......', '..#o#.......',
             '..##........', '............']
    for y, row in enumerate(shape):
        for x, ch in enumerate(row):
            if ch == '#':
                put(arrow, x, y, GOLD_D)
            elif ch == 'o':
                put(arrow, x, y, GOLD_L if y < 6 else GOLD)
    save(arrow, 'cursor')
    # Ornament: Trennlinie mit Wabenknoten (96×8), mittig gekachelt im Spiel.
    orn = canvas(96, 8)
    for x in range(96):
        put(orn, x, 4, GOLD_D)
        put(orn, x, 3, (70, 50, 24, 255))
    for cx in (8, 48, 88):
        for dx, dy in ((0, -3), (-2, -2), (2, -2), (-3, 0), (3, 0), (-2, 2), (2, 2), (0, 3)):
            put(orn, cx + dx, 4 + dy if 0 <= 4 + dy < 8 else 4, GOLD)
        put(orn, cx, 4, GOLD_L)
    save(orn, 'divider')
    # Wabenmuster für Hintergründe (Kachel 28×48, eine Linienstärke).
    hexa = canvas(28, 48)
    pts = []
    for y in range(48):
        for x in range(28):
            pass
    def line(x0, y0, x1, y1, c):
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(steps + 1):
            put(hexa, round(x0 + (x1 - x0) * i / steps), round(y0 + (y1 - y0) * i / steps), c)
    c = (255, 210, 120, 40)
    line(0, 8, 14, 0, c); line(14, 0, 27, 8, c); line(0, 8, 0, 24, c)
    line(0, 24, 14, 32, c); line(14, 32, 27, 24, c); line(14, 32, 14, 47, c)
    save(hexa, 'honeycomb')
    print('UI_KIT_OK', OUT)


if __name__ == '__main__':
    main()


BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def copper(width, height, stops):
    """Amiga-Copperverlauf: Farbbänder mit geordnetem 4×4-Dithering dazwischen."""
    img = canvas(width, height)
    px = img.load()
    for y in range(height):
        t = y / (height - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                a, b = stops[i], stops[i + 1]
                break
        local = (t - a[0]) / max(1e-6, b[0] - a[0])
        # In 8 Stufen quantisieren, die Zwischenwerte per Bayer-Muster verteilen.
        level = local * 8.0
        base = int(level)
        frac = level - base
        for x in range(width):
            step = base + (1 if frac * 16 > BAYER4[y % 4][x % 4] else 0)
            f = min(1.0, step / 8.0)
            c = tuple(round(a[1][k] + (b[1][k] - a[1][k]) * f) for k in range(3)) + (255,)
            px[x, y] = c
    return img


def backdrops():
    # Menühintergrund (960×540, im Spiel ×2): Nachthimmel, violetter Horizont, Honigglut.
    save(copper(960, 540, [(0.0, (9, 8, 22)), (0.45, (24, 18, 54)), (0.72, (58, 28, 78)),
                           (0.86, (120, 52, 74)), (0.93, (60, 24, 52)), (1.0, (10, 8, 20))]), 'backdrop')
    # Kühlere Variante für Werkstatt/Einstellungen.
    save(copper(960, 540, [(0.0, (8, 10, 24)), (0.55, (18, 28, 56)), (0.85, (28, 58, 78)),
                           (1.0, (8, 10, 22))]), 'backdrop_cool')


if __name__ == '__main__':
    backdrops()
