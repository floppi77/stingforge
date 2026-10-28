"""Entwirft die vier Spielergeschosse als Pixelkarten und schreibt sie als JSON.

Kaltes Farbschema (Weiß/Eisblau/Cyan) – deutlich getrennt vom warmen
Blütenstaub (Gold/Bernstein).
"""
import json

O = "#08222f"   # Rand
D = "#12658c"   # Tiefblau
C = "#3fb8e6"   # Cyan
L = "#a9e9ff"   # Eisblau
W = "#ffffff"   # Kern

def blank(w, h):
    return [["." for _ in range(w)] for _ in range(h)]

def put(g, x, y, c):
    if 0 <= y < len(g) and 0 <= x < len(g[0]):
        g[y][x] = c

def dart(w, h, phase):
    """Nadel mit hellem Kern, Spitze rechts."""
    g = blank(w, h)
    cy = h // 2
    # Kern
    for x in range(2, 8):
        put(g, x, cy - 1, W)
        put(g, x, cy, W)
    # Spitze
    put(g, 8, cy - 1 + (0 if phase == 0 else 0), L)
    put(g, 8, cy, L)
    put(g, 9, cy, L)
    if phase == 1:
        put(g, 9, cy - 1, C)
    # Glimmen oben/unten
    for x in range(3, 8):
        put(g, x, cy - 2, C)
        put(g, x, cy + 1, C)
    # Schwanz
    put(g, 1, cy, C)
    put(g, 1, cy - 1, D)
    put(g, 1, cy + 1, D)
    put(g, 0, cy, D)
    return g

def fan(w, h, phase):
    """Breiterer Splitter, leicht keilförmig."""
    g = blank(w, h)
    cy = h // 2
    for x in range(1, 8):
        put(g, x, cy - 1, W)
        put(g, x, cy, L)
    for x in range(2, 9):
        put(g, x, cy - 2, C)
        put(g, x, cy + 1, C)
    put(g, 9, cy - 1, L)
    put(g, 9, cy, L)
    if phase == 1:
        put(g, 10, cy, C)
        put(g, 8, cy + 1, L)
    put(g, 0, cy - 1, D)
    put(g, 0, cy + 1, D)
    return g

def bolt(w, h, phase):
    """Blitzzacken: gezackte Ober- und Unterkante."""
    g = blank(w, h)
    cy = h // 2
    for x in range(2, 13):
        put(g, x, cy, W)
    for x in range(2, 13, 2):
        put(g, x, cy - 1, L)
    for x in range(3, 13, 2):
        put(g, x, cy - 1, C)
    for x in range(2, 13):
        put(g, x, cy + 1, C)
    # Zacken
    zack = [(3, cy - 2), (6, cy - 2), (9, cy - 2), (12, cy - 1),
            (4, cy + 2), (7, cy + 2), (10, cy + 2)]
    for (x, y) in zack:
        put(g, x, y, L if (x + phase) % 3 else C)
    put(g, 1, cy, D)
    put(g, 0, cy, D)
    put(g, 13, cy, W)
    put(g, 14, cy, C)
    return g

def plasma(w, h, phase):
    """Kugel mit weißem Kern und blauem Hof."""
    g = blank(w, h)
    cx, cy = w // 2, h // 2
    rings = [(0.34, W), (0.52, L), (0.72, C), (0.92, D)]
    for y in range(h):
        for x in range(w):
            dx = (x - cx + 0.5) / (w * 0.5)
            dy = (y - cy + 0.5) / (h * 0.5)
            r = (dx * dx + dy * dy) ** 0.5
            for lim, col in rings:
                if r <= lim:
                    g[y][x] = col
                    break
    # Funkeln
    if phase == 1:
        put(g, cx, cy - 1, W)
        put(g, cx - 1, cy, W)
        put(g, 1, cy - 4, L)
        put(g, w - 2, cy + 4, L)
    return g

def rim(g, col=O):
    """Dunkle Kante um die Figur – trennt sie auch von hellem Hintergrund."""
    h = len(g); w = len(g[0])
    add = []
    for y in range(h):
        for x in range(w):
            if g[y][x] == ".":
                continue
            for (dx, dy) in ((1,0),(-1,0),(0,1),(0,-1)):
                nx, ny = x+dx, y+dy
                if 0 <= nx < w and 0 <= ny < h and g[ny][nx] == ".":
                    add.append((nx, ny))
    for (x, y) in add:
        g[y][x] = col
    return g

SPECS = [
    ("bullet_base", 12, 8, dart),
    ("bullet_fan", 12, 8, fan),
    ("bullet_lightning", 16, 8, bolt),
    ("bullet_plasma", 16, 16, plasma),
]

out = {}
for name, w, h, fn in SPECS:
    frames = []
    for phase in (0, 1):
        g = rim(fn(w, h, phase))
        px = []
        for y in range(h):
            for x in range(w):
                if g[y][x] != ".":
                    px.append({"x": x, "y": y, "color": g[y][x]})
        frames.append(px)
    out[name] = {"w": w, "h": h, "frames": frames}
    print(name, w, h, "Pixel je Bild:", [len(f) for f in frames])

json.dump(out, open(".godot_data/art/bullets.json", "w"))
