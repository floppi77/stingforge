#!/usr/bin/env python3
"""Erzeugt die beiden nahtlosen Parallax-Ebenen (Wolken und Vordergrundpflanzen).

Beide Bilder wiederholen sich waagerecht ohne sichtbare Naht: alle Formen werden
aus ganzzahligen Sinusperioden über die Breite aufgebaut und zusätzlich um ±Breite
versetzt gezeichnet. Ergebnis:
  assets/bg/bg_clouds.png  – weiche Sporenschwaden (weiß, wird im Spiel eingefärbt)
  assets/bg/bg_front.png   – dunkle Halme unten, hängende Blätter oben (Vordergrund)

Aufruf: python3 tools/make_parallax.py
"""
from PIL import Image
import math
import os
import random

W, H = 512, 540
TAU = math.pi * 2.0
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "bg")


def make_clouds() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    def soft_blob(cx, cy, rx, ry, alpha):
        for dy in range(-ry, ry + 1):
            for dx in range(-rx, rx + 1):
                t = (dx / rx) ** 2 + (dy / ry) ** 2
                if t > 1.0:
                    continue
                a = int(alpha * (1.0 - t) ** 1.4)
                if a <= 0:
                    continue
                y = int(cy + dy)
                if not (0 <= y < H):
                    continue
                for ox in (-W, 0, W):
                    x = int(cx + ox + dx)
                    if 0 <= x < W:
                        old = img.getpixel((x, y))
                        img.putpixel((x, y), (255, 255, 255, min(255, old[3] + a)))

    rnd = random.Random(770423)
    for i in range(9):
        cx = (i * 61 + rnd.randrange(0, 30)) % W
        cy = 90 + int(60 * math.sin(i * 1.7)) + rnd.randrange(-25, 25)
        soft_blob(cx, cy, rnd.randrange(70, 150), rnd.randrange(22, 40), rnd.randrange(9, 15))
    for i in range(22):
        cx = (i * 29 + rnd.randrange(0, 20)) % W
        cy = rnd.randrange(70, 470)
        soft_blob(cx, cy, rnd.randrange(26, 66), rnd.randrange(10, 22), rnd.randrange(12, 22))
    for i in range(40):
        cx = rnd.randrange(0, W)
        cy = rnd.randrange(40, 500)
        soft_blob(cx, cy, rnd.randrange(6, 16), rnd.randrange(4, 9), rnd.randrange(18, 30))
    for y in range(H):
        a = 6 + int(6 * math.sin(y / H * math.pi))
        for x in range(W):
            if img.getpixel((x, y))[3] < a:
                img.putpixel((x, y), (255, 255, 255, a))
    return img


def make_front() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    def wave(x, base, parts):
        v = base
        for (k, amp, ph) in parts:
            v += amp * math.sin(TAU * k * x / W + ph)
        return v

    for x in range(W):
        h = int(max(7, wave(x, 23.0, [(7, 8.0, 0.0), (19, 4.0, 1.3), (41, 2.0, 2.1)])))
        for y in range(H - h, H):
            a = 150 + int(75 * (y - (H - h)) / max(1, h))
            img.putpixel((x, y), (9, 18, 24, min(240, a)))
        hs = wave(x, 36.0, [(11, 13.0, 0.7), (29, 6.0, 2.4), (53, 3.0, 0.2)])
        if hs > 42.0:
            for y in range(H - int(hs), H - h):
                img.putpixel((x, y), (7, 13, 18, 225))
        hv = wave(x, 10.0, [(5, 7.0, 0.0), (17, 4.0, 1.9), (37, 1.6, 0.6)])
        if hv > 15.0:
            for y in range(0, int(hv)):
                a = 200 - int(70 * y / max(1, int(hv)))
                img.putpixel((x, y), (8, 15, 20, max(80, a)))
    return img


def edge_diff(img: Image.Image) -> float:
    px = img.load()
    tot = 0.0
    n = 0
    for y in range(0, H, 3):
        a = px[0, y]
        b = px[W - 1, y]
        tot += abs(a[3] - b[3]) + abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])
        n += 1
    return tot / n


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, img in (("bg_clouds.png", make_clouds()), ("bg_front.png", make_front())):
        path = os.path.join(OUT, name)
        img.save(path)
        print("%s  %dx%d  Naht %.1f" % (name, img.size[0], img.size[1], edge_diff(img)))
