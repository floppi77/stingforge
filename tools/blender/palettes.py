"""palettes.py -- Farbkonzepte pro Level.

Jede Palette besteht aus benannten Rampen (dunkel -> hell oder nach Rolle).
Dieselben Farben werden sowohl fuer die Blender-Materialien als auch fuer die
Pixel-Reduktion (Nearest-Match) verwendet. Dadurch bleibt das Ergebnis
kohaerent und wirkt gestaltet statt gefiltert.
"""

# ramps: name -> Liste von '#rrggbb'
LEVELS = [
    # 1 ---------------------------------------------------------------- rosa
    dict(id=1, key="l01", name="Bluetenmeer",
         ramps={
             "sky":    ["#a8527d", "#d97aa5", "#f5a0c2", "#ffc9dc", "#ffe9f0"],
             "warm":   ["#ffb066", "#ffd7a8", "#fff1d8"],
             "ground": ["#1b3b23", "#2d5c30", "#4f8a3c", "#7cae45", "#a8c95c", "#d6e08a"],
             "leaf":   ["#3f7a37", "#5e9b3f", "#8fc05a"],
             "flower": ["#c4557f", "#e86e9e", "#ffb8d2", "#fff2f7"],
             "accent": ["#f2a53c", "#ffe08a"],
             "dark":   ["#0a120e", "#14231a", "#1f3226"],
             "white":  ["#ffffff"],
         }),
    # 2 ---------------------------------------------------------------- erde
    dict(id=2, key="l02", name="Wurzelreich",
         ramps={
             "sky":    ["#2b1d12", "#40301e", "#5c4228", "#7a5a33", "#9c7c48"],
             "ground": ["#120b06", "#1e130a", "#2e1c10", "#442c18", "#5c3e20"],
             "root":   ["#31200f", "#4a3118", "#6b4a28", "#8a5c2e", "#a8783c"],
             "accent": ["#c99a54", "#e0b46a", "#f2d79a"],
             "moss":   ["#3a3a1c", "#5a5a2a", "#7a7a3c"],
             "dark":   ["#070402", "#0c0805", "#140d07"],
         }),
    # 3 ---------------------------------------------------------------- teich
    dict(id=3, key="l03", name="Schilf und Teich",
         ramps={
             "sky":    ["#4c9fb4", "#6fc0cc", "#96dce0", "#c8f2ef", "#eafffb"],
             "water":  ["#1c6576", "#2a8a96", "#46b0b4", "#7fd6cf"],
             "reed":   ["#24452a", "#3f6b34", "#6f9c3f", "#a8c95c", "#d9e88a"],
             "flower": ["#e58bb0", "#ffd9e6", "#ffffff"],
             "accent": ["#7fd6cf", "#bff5ea"],
             "dark":   ["#081412", "#10231f", "#183028"],
         }),
    # 4 ---------------------------------------------------------------- pilze
    dict(id=4, key="l04", name="Pilzwald",
         ramps={
             "sky":    ["#0c0a1c", "#14122c", "#1d1b3c", "#2a2450", "#3a3266"],
             "glow":   ["#1a8a96", "#38c8c0", "#7ff2e0"],
             "cap":    ["#452a72", "#6b46a8", "#9b6ed8", "#c9a0f0"],
             "ground": ["#1a1628", "#2a2440", "#3c3358", "#4e4470"],
             "accent": ["#d69b45", "#ffd27f"],
             "dark":   ["#04030a", "#07050f", "#0e0b1a"],
         }),
    # 5 ---------------------------------------------------------------- sturm
    dict(id=5, key="l05", name="Dornen im Sturm",
         ramps={
             "sky":    ["#2b2736", "#3f3a4e", "#565068", "#7e7699", "#a79ec0"],
             "cloud":  ["#3a3547", "#4e4860", "#655e7a", "#8b83a8"],
             "thorn":  ["#1a1622", "#221d2b", "#332d3e", "#4a4258"],
             "light":  ["#cfc0ff", "#f2ecff"],
             "grass":  ["#3a3528", "#4a4434", "#6b6350"],
             "dark":   ["#0b0910", "#16121d", "#1f1a28"],
         }),
    # 6 ---------------------------------------------------------------- glas
    dict(id=6, key="l06", name="Glaesernes Gewaechshaus",
         ramps={
             "sky":    ["#7fc8dc", "#a6e0ee", "#d8f7fb", "#f2ffff"],
             "frame":  ["#1c4452", "#2f6474", "#4f8a9c", "#7fb8c6"],
             "glass":  ["#9ad8e8", "#bdf0fa", "#e6fbff", "#ffffff"],
             "plant":  ["#35704a", "#5aa347", "#8fd06a"],
             "accent": ["#fff0b0", "#ffd97a"],
             "dark":   ["#0a1e24", "#123038", "#1a3f48"],
         }),
    # 7 ---------------------------------------------------------------- kanal
    dict(id=7, key="l07", name="Verlorene Kanalisation",
         ramps={
             "sky":    ["#1c241f", "#2a352e", "#38463e", "#4a5a50"],
             "brick":  ["#2a201a", "#3d3028", "#554436", "#6e5a46", "#8a7458"],
             "pipe":   ["#2e3a34", "#4a5850", "#6a7a72", "#8a9a90"],
             "water":  ["#1e3a30", "#24503f", "#3e6e5e"],
             "glow":   ["#6aa87a", "#a8d8a0"],
             "dark":   ["#070b09", "#0e1512", "#141d18"],
         }),
    # 8 ---------------------------------------------------------------- maschine
    dict(id=8, key="l08", name="Maschinenherz",
         ramps={
             "sky":    ["#2a1210", "#3a1a18", "#521f1c", "#6e2a22"],
             "metal":  ["#261b17", "#3c2c26", "#5a453e", "#7a6258", "#9c8274"],
             "rust":   ["#5c2e18", "#7a3f22", "#a05a34"],
             "glow":   ["#e0602a", "#ff9a3c", "#ffd27a"],
             "dark":   ["#080404", "#120908", "#1a0d0a"],
         }),
    # 9 ---------------------------------------------------------------- stock
    dict(id=9, key="l09", name="Biomechanischer Schwarmstock",
         ramps={
             "sky":    ["#1c1028", "#2c1a3c", "#3f2350", "#552c62", "#6e3a76"],
             "hive":   ["#281a34", "#3f2850", "#5f3d74", "#8a5aa0"],
             "gold":   ["#6f4f1c", "#a87a2c", "#e0ac4e", "#ffd98a", "#fff0c0"],
             "vein":   ["#9a5cb0", "#c88ad8", "#f0bcf0"],
             "dark":   ["#080510", "#120a18", "#1a0e24"],
         }),
    # 10 --------------------------------------------------------------- kern
    dict(id=10, key="l10", name="Kern der Verwandlung",
         ramps={
             "sky":    ["#050306", "#0b0610", "#14101a", "#1c1226", "#2a1634"],
             "crystal": ["#150a1a", "#221028", "#33193c", "#4a2a54", "#6b3d74"],
             "glow":   ["#c62a6e", "#ff5fa8", "#ff9ccb", "#ffd1e6"],
             "vein":   ["#7a1e4a", "#a82a68", "#e04a94"],
             "dark":   ["#020103", "#050306", "#0b0610"],
         }),
]

BY_ID = {d["id"]: d for d in LEVELS}
BY_KEY = {d["key"]: d for d in LEVELS}


def ramp(level_id, name):
    return BY_ID[level_id]["ramps"][name]


def col(level_id, name, idx):
    r = ramp(level_id, name)
    return r[max(0, min(idx, len(r) - 1))]


def all_colors(level_id):
    """Alle Palettenfarben eines Levels, dedupliziert, in Rampen-Reihenfolge."""
    seen = []
    for ramp_name, colors in BY_ID[level_id]["ramps"].items():
        for c in colors:
            if c not in seen:
                seen.append(c)
    return seen
