#!/usr/bin/env python3
"""Erzeugt die Beleuchtungshilfen: Vignette, Lichtsaum von oben und weiche Glorien.

Die Bilder sind einfarbig (weiß) und werden im Spiel eingefärbt, damit sie zu
jeder Levelpalette passen. Alles bleibt absichtlich schwach – die Beleuchtung soll
die Szene fassen, nicht überstrahlen.

Ergebnis:
  assets/fx/vignette.png  – dunkler Rand (256x144, gestreckt über den Bildschirm)
  assets/fx/light_top.png – heller Verlauf von oben (64x256)
  assets/fx/glow.png      – runde Glorie für Sammelobjekte (64x64)
"""
from PIL import Image
import math
import os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "fx")


def vignette(w=256, h=144) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            nx = (x / (w - 1)) * 2.0 - 1.0
            ny = (y / (h - 1)) * 2.0 - 1.0
            r = math.sqrt(nx * nx * 0.85 + ny * ny)
            a = int(255 * min(1.0, max(0.0, (r - 0.55) / 0.75)) ** 1.6)
            if a > 0:
                img.putpixel((x, y), (6, 8, 12, a))
    return img


def light_top(w=64, h=256) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        t = y / (h - 1)
        a = int(46 * (1.0 - t) ** 2.2)
        for x in range(w):
            img.putpixel((x, y), (255, 255, 255, a))
    return img


def glow(size=64, power=2.0) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = math.sqrt((x - c) ** 2 + (y - c) ** 2) / c
            if d <= 1.0:
                a = int(255 * (1.0 - d) ** power)
                img.putpixel((x, y), (255, 255, 255, a))
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, img in (("vignette.png", vignette()),
                      ("light_top.png", light_top()),
                      ("glow.png", glow())):
        img.save(os.path.join(OUT, name))
        print("%s  %dx%d" % (name, img.size[0], img.size[1]))
