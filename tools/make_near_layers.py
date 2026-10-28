#!/usr/bin/env python3
"""Erzeugt die vorderen Silhouettenebenen (assets/bg/lXX_near.png) aller Level neu.

Pixelgenaue Silhouetten je Levelthema, nahtlos kachelbar (jede Form wird über den
linken/rechten Rand umgebrochen), Boden exakt an der Quell-Bodenlinie 476 wie die
übrigen Bodenebenen. Lichtkante oben in der Akzentfarbe des Levels.
Die alten Ebenen liegen in build/claude-backup-r4-*/ bzw. werden hier gesichert.
"""
from pathlib import Path
import math
import random
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BG = ROOT / 'assets/bg'
W, H = 960, 540
GROUND = 476

# sky, haze, ground, accent, dark – aus data.gd
PAL = {
    1: ('#f7c8d8', '#ffd9e6', '#3f7a3a', '#ffd34e', '#22331f'),
    2: ('#2b2018', '#4a3524', '#6b4a2a', '#c8892c', '#150f0a'),
    3: ('#7fc8e8', '#bfe8f2', '#2f6b52', '#ffe08a', '#12303a'),
    4: ('#141a2e', '#233a52', '#2b4a4a', '#6ef0c8', '#080b14'),
    5: ('#3a2a4a', '#6b4a72', '#4a3a2a', '#ff9a5a', '#120c18'),
    6: ('#cfe8ff', '#e8f4ff', '#5a7a8a', '#ffd0f0', '#1a2630'),
    7: ('#1a2024', '#2f3a34', '#4a5a3a', '#a8e05a', '#080c0a'),
    8: ('#241c1c', '#3d2a26', '#6a4a30', '#ff7a3c', '#0e0a08'),
    9: ('#2a1c3a', '#4a2a52', '#5a6a3a', '#ffcf5a', '#0c0812'),
    10: ('#101018', '#2a1a2a', '#4a2a3a', '#ff5a8a', '#05050a'),
}


def hexc(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


class Layer:
    def __init__(self, level):
        self.img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        sky, haze, ground, accent, dark = PAL[level]
        self.sil = mix(hexc(dark), hexc(ground), 0.22)
        self.sil2 = mix(hexc(dark), hexc(ground), 0.05)
        self.accent = hexc(accent)
        self.rng = random.Random(9000 + level)

    # Jede Zeichnung wird bei x-W, x und x+W ausgeführt: nahtlose Kachel.
    def wrap(self, fn):
        for dx in (-W, 0, W):
            fn(dx)

    def poly(self, pts, col=None):
        self.wrap(lambda dx: self.d.polygon([(x + dx, y) for x, y in pts], fill=col or self.sil))

    def line(self, pts, width, col=None):
        self.wrap(lambda dx: self.d.line([(x + dx, y) for x, y in pts], fill=col or self.sil, width=width))

    def ellipse(self, box, col=None):
        x0, y0, x1, y1 = box
        self.wrap(lambda dx: self.d.ellipse((x0 + dx, y0, x1 + dx, y1), fill=col or self.sil))

    def rect(self, box, col=None):
        x0, y0, x1, y1 = box
        self.wrap(lambda dx: self.d.rectangle((x0 + dx, y0, x1 + dx, y1), fill=col or self.sil))

    def ground(self, bumps=6, amp=4.0):
        pts = [(0, H)]
        # Oberkante höchstens bis Zeile 468: die Anschlusszeile 469 bleibt lückenlos.
        top = GROUND - 8 - amp - 2
        for x in range(0, W + 1, 4):
            y = top + amp * math.sin(x / W * math.tau * bumps) + 2.0 * math.sin(x / W * math.tau * 17)
            pts.append((x, round(y)))
        pts.append((W, H))
        self.d.polygon(pts, fill=self.sil)
        # Tieferes Band und Krümel im Boden.
        self.d.rectangle((0, GROUND + 22, W, H), fill=self.sil2)
        for _ in range(140):
            x = self.rng.randrange(W)
            y = self.rng.randrange(GROUND + 6, H)
            self.d.point((x, y), fill=mix(self.sil, self.accent, 0.12))

    def stem(self, x, base, height, lean, width=2):
        """Geschwungener Halm von unten nach oben."""
        pts = []
        for i in range(13):
            t = i / 12
            pts.append((x + lean * t * t * height * 0.25, base - height * t))
        self.line(pts, width)
        self.last_stem = pts
        return pts[-1]

    def leaf(self, x, y, length, angle, width=5):
        a = math.radians(angle)
        tip = (x + math.cos(a) * length, y - math.sin(a) * length)
        n = (math.cos(a + math.pi / 2) * width, -math.sin(a + math.pi / 2) * width)
        mid = (x + (tip[0] - x) * 0.45, y + (tip[1] - y) * 0.45)
        self.poly([(x, y), (mid[0] + n[0], mid[1] + n[1]), tip, (mid[0] - n[0] * 0.4, mid[1] - n[1] * 0.4)])

    def finish(self, path):
        px = self.img.load()
        rim = self.accent
        out = self.img.copy()
        po = out.load()
        for y in range(1, H):
            for x in range(W):
                if px[x, y][3] > 0 and px[x, y - 1][3] == 0:
                    # Lichtkante oben (Gegenlicht), zwei Pixel weich.
                    po[x, y] = mix(px[x, y], rim, 0.55)
                    if y + 1 < H and px[x, y + 1][3] > 0:
                        po[x, y + 1] = mix(px[x, y + 1], rim, 0.22)
        out.save(path)


def meadow(L):  # 1 Blütenmeer
    L.ground(5)
    for i in range(14):
        x = L.rng.randrange(W)
        h = L.rng.randrange(40, 110)
        top = L.stem(x, GROUND + 2, h, L.rng.uniform(-1, 1), 2)
        if i % 3 == 0:  # Blütenknospe
            L.ellipse((top[0] - 6, top[1] - 8, top[0] + 6, top[1] + 4))
            L.poly([(top[0] - 8, top[1] + 2), (top[0], top[1] - 12), (top[0] + 8, top[1] + 2)])
        pts = L.last_stem
        for k in range(2):
            # Blatt sitzt am tatsächlichen (geneigten) Halm, nicht daneben.
            ax, ay = pts[3 + k * 3]
            L.leaf(ax, ay, L.rng.randrange(14, 26), L.rng.choice([20, 160, 40, 140]))
    for i in range(40):  # Grasbüschel
        x = L.rng.randrange(W)
        for k in range(3):
            L.stem(x + k * 3, GROUND + 2, L.rng.randrange(10, 28), L.rng.uniform(-2, 2), 1)
    for i in range(3):  # hängende Blätter oben
        x = L.rng.randrange(W)
        for k in range(3):
            L.leaf(x + k * 10, -4, L.rng.randrange(30, 50), -70 - k * 15, 7)


def roots(L):  # 2 Wurzelreich
    L.ground(4, 6)
    for i in range(5):
        x = L.rng.randrange(W)
        w = L.rng.randrange(90, 170)
        h = L.rng.randrange(50, 95)
        pts = [(x + w * t, GROUND + 4 - h * math.sin(math.pi * t) ** 0.8) for t in [k / 16 for k in range(17)]]
        L.line(pts, L.rng.randrange(9, 14))
        for k in range(4):  # Würzelchen
            t = L.rng.uniform(0.1, 0.9)
            px, py = x + w * t, GROUND + 4 - h * math.sin(math.pi * t) ** 0.8
            L.line([(px, py), (px + L.rng.randrange(-14, 14), py + L.rng.randrange(8, 22))], 2)
    for i in range(30):
        x = L.rng.randrange(W)
        L.ellipse((x, GROUND - 3, x + L.rng.randrange(4, 9), GROUND + 3))
    for i in range(4):  # hängende Wurzeln oben
        x = L.rng.randrange(W)
        pts = [(x + math.sin(t * 5) * 6, -2 + t * L.rng.randrange(40, 90)) for t in [k / 10 for k in range(11)]]
        L.line(pts, 3)


def reeds(L):  # 3 Schilf und Teich
    L.ground(3, 2)
    for i in range(22):
        x = L.rng.randrange(W)
        h = L.rng.randrange(60, 150)
        lean = L.rng.uniform(-0.6, 0.6)
        top = L.stem(x, GROUND + 2, h, lean, 2)
        if i % 2 == 0:  # Rohrkolben
            L.rect((top[0] - 2, top[1] + 4, top[0] + 2, top[1] + 20), mix(L.sil, (90, 60, 30, 255), 0.45))
            L.line([top, (top[0], top[1] - 8)], 1)
        else:
            ax, ay = L.last_stem[5]
            L.leaf(ax, ay, L.rng.randrange(30, 60), L.rng.choice([60, 120, 75, 105]), 3)
    for i in range(3):
        x = L.rng.randrange(W)
        for k in range(3):
            L.leaf(x + k * 12, -4, L.rng.randrange(36, 56), -78 - k * 10, 6)


def mushrooms(L):  # 4 Pilzwald
    L.ground(5, 3)
    for i in range(12):
        x = L.rng.randrange(W)
        h = L.rng.randrange(14, 46)
        r = L.rng.randrange(9, 24)
        L.rect((x - 2, GROUND - h, x + 2, GROUND + 2))
        L.ellipse((x - r, GROUND - h - r * 0.6, x + r, GROUND - h + r * 0.35))
    for i in range(30):
        x = L.rng.randrange(W)
        L.stem(x, GROUND + 2, L.rng.randrange(8, 20), L.rng.uniform(-2, 2), 1)
    for i in range(5):  # hängende Pilzfäden
        x = L.rng.randrange(W)
        pts = [(x + math.sin(t * 7) * 4, -2 + t * L.rng.randrange(30, 80)) for t in [k / 10 for k in range(11)]]
        L.line(pts, 1)


def brambles(L):  # 5 Dornen im Sturm (Wind von der Seite: alles neigt sich)
    L.ground(4, 4)
    for i in range(10):
        x = L.rng.randrange(W)
        h = L.rng.randrange(40, 110)
        pts = []
        for k in range(14):
            t = k / 13
            pts.append((x + 30 * t * t + math.sin(t * 4 + i) * 6, GROUND + 2 - h * t))
        L.line(pts, 3)
        for k in range(2, 13, 2):  # Dornen
            px, py = pts[k]
            L.poly([(px, py), (px - 5, py - 3), (px, py - 2)])
            L.poly([(px, py), (px + 5, py - 1), (px + 1, py - 3)])
    for i in range(40):
        x = L.rng.randrange(W)
        L.stem(x, GROUND + 2, L.rng.randrange(12, 34), 3.0, 1)


def greenhouse(L):  # 6 Gläsernes Gewächshaus
    L.ground(2, 2)
    for i in range(6):  # Pflanzkübel mit Farn
        x = L.rng.randrange(W)
        L.poly([(x - 18, GROUND - 26), (x + 18, GROUND - 26), (x + 13, GROUND + 2), (x - 13, GROUND + 2)])
        for k in range(5):
            L.leaf(x, GROUND - 26, L.rng.randrange(20, 34), 30 + k * 30, 4)
    for i in range(4):  # Rahmenstreben aus dem Glasdach, mit Nieten
        x = L.rng.randrange(W)
        L.rect((x - 3, 0, x + 3, 70))
        L.rect((x - 9, 64, x + 9, 72))
        for y in range(8, 64, 14):
            L.ellipse((x - 1, y - 1, x + 1, y + 1), mix(L.sil, L.accent, 0.35))


def sewer(L):  # 7 Verlorene Kanalisation
    L.ground(2, 2)
    for i in range(4):  # Rohre mit Flanschen
        x = L.rng.randrange(W)
        h = L.rng.randrange(40, 90)
        L.rect((x - 7, GROUND - h, x + 7, GROUND + 2))
        L.rect((x - 10, GROUND - h - 4, x + 10, GROUND - h + 2))
        L.rect((x - 7, GROUND - h - 2, x + 40, GROUND - h + 10))
        L.rect((x + 38, GROUND - h - 6, x + 44, GROUND - h + 14))
    for i in range(3):  # Ventilräder
        x = L.rng.randrange(W)
        L.wrap(lambda dx: L.d.ellipse((x - 12 + dx, GROUND - 40, x + 12 + dx, GROUND - 16), outline=L.sil, width=3))
        L.rect((x - 1, GROUND - 16, x + 1, GROUND + 2))
    for i in range(3):  # tropfende Leitungen oben
        x = L.rng.randrange(W)
        L.rect((x, 0, x + 6, L.rng.randrange(20, 60)))


def machine(L):  # 8 Maschinenherz
    L.ground(2, 2)
    for i in range(3):
        cx = L.rng.randrange(W)
        r = L.rng.randrange(22, 44)
        teeth = 14
        pts = []
        for k in range(teeth * 2):
            a = math.tau * k / (teeth * 2)
            rr = r + (6 if k % 2 == 0 else 0)
            pts.append((cx + math.cos(a) * rr, GROUND - r * 0.6 + math.sin(a) * rr))
        L.poly(pts)
    for i in range(4):  # Kolben
        x = L.rng.randrange(W)
        L.rect((x - 5, GROUND - 56, x + 5, GROUND + 2))
        L.rect((x - 11, GROUND - 62, x + 11, GROUND - 50))
    for i in range(3):  # Kabelbögen oben
        x = L.rng.randrange(W)
        pts = [(x + 60 * t, 8 + 40 * math.sin(math.pi * t)) for t in [k / 12 for k in range(13)]]
        L.line(pts, 3)


def hive(L):  # 9 Biomechanischer Schwarmstock
    L.ground(4, 4)
    for i in range(7):
        cx = L.rng.randrange(W)
        cy = GROUND - L.rng.randrange(6, 40)
        r = L.rng.randrange(10, 18)
        hexagon = [(cx + math.cos(math.radians(60 * k + 30)) * r, cy + math.sin(math.radians(60 * k + 30)) * r) for k in range(6)]
        L.poly(hexagon)
        L.line([(cx, cy + r), (cx, GROUND + 2)], 3)
    for i in range(4):  # organische Röhren
        x = L.rng.randrange(W)
        pts = [(x + 40 * t, GROUND - 60 * math.sin(math.pi * t)) for t in [k / 12 for k in range(13)]]
        L.line(pts, 6)
    for i in range(4):  # hängende Waben
        x = L.rng.randrange(W)
        for k in range(3):
            r = 8
            cx, cy = x + k * 14, 10 + (k % 2) * 8
            L.poly([(cx + math.cos(math.radians(60 * j + 30)) * r, cy + math.sin(math.radians(60 * j + 30)) * r) for j in range(6)])


def core(L):  # 10 Kern der Verwandlung
    L.ground(5, 5)
    for i in range(9):  # Kristallspitzen
        x = L.rng.randrange(W)
        h = L.rng.randrange(30, 90)
        w = L.rng.randrange(8, 16)
        lean = L.rng.uniform(-10, 10)
        L.poly([(x - w, GROUND + 2), (x + lean, GROUND - h), (x + w, GROUND + 2)])
        L.line([(x + lean * 0.3, GROUND - h * 0.3), (x + lean * 0.8, GROUND - h * 0.8)], 1, mix(L.sil, L.accent, 0.4))
    for i in range(5):  # Ranken von oben
        x = L.rng.randrange(W)
        pts = [(x + math.sin(t * 6 + i) * 8, -2 + t * L.rng.randrange(40, 100)) for t in [k / 12 for k in range(13)]]
        L.line(pts, 2)


THEMES = {1: meadow, 2: roots, 3: reeds, 4: mushrooms, 5: brambles, 6: greenhouse, 7: sewer, 8: machine,
          9: hive, 10: core}


def main():
    backup = ROOT / 'build/near-layers-original'
    backup.mkdir(parents=True, exist_ok=True)
    for level, fn in THEMES.items():
        path = BG / f'l{level:02d}_near.png'
        if not (backup / path.name).exists():
            shutil.copy2(path, backup / path.name)
        L = Layer(level)
        fn(L)
        L.finish(path)
        print('NEAR', path.name)
    print('NEAR_LAYERS_OK')


if __name__ == '__main__':
    main()
