"""Gemeinsame Notendaten-Helfer fuer die Apidya-Reimagined-Songs.

Die Song-Dateien in diesem Ordner enthalten nur Daten (Dicts). Alles, was zur
Notation gehoert - Skalen, Akkordgriffe, Trommel-Patterns, Bass-Ostinati - steht
hier, damit die Songs lesbar bleiben und die Engine (tools/audio/synth.py)
dieselbe Sprache spricht.

Konventionen
------------
* Ein Takt hat 16 Schritte (16tel). 4/4, keine Taktwechsel.
* Motiv-Eintraege sind (step, degree, length16). `degree` ist ein Skalenschritt
  relativ zum Grundton der Tonart, 0 = Grundton, 7 = Oktave, -1 = Septime
  darunter. Negative und >7-Werte werden oktaviert.
* Bass-Patterns sind (step, semitone_offset, length16) relativ zum Akkordgrundton.
"""

# --------------------------------------------------------------------- Noten

_PC = {
    "C": 0, "C#": 1, "DB": 1, "D": 2, "D#": 3, "EB": 3, "E": 4, "F": 5,
    "F#": 6, "GB": 6, "G": 7, "G#": 8, "AB": 8, "A": 9, "A#": 10, "BB": 10, "B": 11,
}


def key_pc(name):
    """'D', 'F#', 'Bb' -> 0..11"""
    return _PC[name.upper()]


SCALES = {
    "major":         [0, 2, 4, 5, 7, 9, 11],
    "minor":         [0, 2, 3, 5, 7, 8, 10],
    "harmonic_minor": [0, 2, 3, 5, 7, 8, 11],
    "dorian":        [0, 2, 3, 5, 7, 9, 10],
    "phrygian":      [0, 1, 3, 5, 7, 8, 10],
    "lydian":        [0, 2, 4, 6, 7, 9, 11],
    "mixolydian":    [0, 2, 4, 5, 7, 9, 10],
    "minor_pent":    [0, 3, 5, 7, 10],
}


def deg_semitone(scale, degree):
    """Skalenschritt -> Halbtonabstand (oktaviert)."""
    iv = SCALES[scale]
    n = len(iv)
    octs, idx = divmod(int(degree), n)
    return iv[idx] + 12 * octs


# --------------------------------------------------------------------- Akkorde

QUALITIES = {
    "":      [0, 4, 7],
    "m":     [0, 3, 7],
    "5":     [0, 7],
    "6":     [0, 4, 7, 9],
    "m6":    [0, 3, 7, 9],
    "7":     [0, 4, 7, 10],
    "maj7":  [0, 4, 7, 11],
    "m7":    [0, 3, 7, 10],
    "dim":   [0, 3, 6],
    "dim7":  [0, 3, 6, 9],
    "sus2":  [0, 2, 7],
    "sus4":  [0, 5, 7],
    "add9":  [0, 4, 7, 14],
    "m9":    [0, 3, 7, 10, 14],
    "maj9":  [0, 4, 7, 11, 14],
}


def chord(spec):
    """'Dmaj7' -> (root_pc, [semitones])"""
    spec = spec.strip()
    if ":" in spec:
        root, qual = spec.split(":", 1)
    else:
        # laengster passender Qualitaets-Suffix
        root, qual = None, None
        for q in sorted(QUALITIES, key=len, reverse=True):
            if q and spec.endswith(q) and len(spec) > len(q):
                root, qual = spec[: -len(q)], q
                break
        if root is None:
            root, qual = spec, ""
    return key_pc(root), QUALITIES[qual]


# --------------------------------------------------------------------- Drums
# 16 Schritte pro Takt, (step, velocity 0..1)

DRUM_PATTERNS = {
    "sparse": {
        "kick": [(0, 0.95)],
        "snare": [],
        "hat": [(8, 0.30)],
    },
    "halftime": {
        "kick": [(0, 1.0), (10, 0.55)],
        "snare": [(8, 0.85)],
        "hat": [(2, 0.25), (6, 0.22), (10, 0.25), (14, 0.22)],
    },
    "basic": {
        "kick": [(0, 1.0), (6, 0.62), (10, 0.72)],
        "snare": [(4, 0.80), (12, 0.86)],
        "hat": [(0, 0.30), (2, 0.24), (4, 0.28), (6, 0.24),
                (8, 0.30), (10, 0.24), (12, 0.28), (14, 0.26)],
    },
    "four": {
        "kick": [(0, 1.0), (4, 0.95), (8, 1.0), (12, 0.95)],
        "snare": [(4, 0.62), (12, 0.70)],
        "hat": [(1, 0.26), (3, 0.26), (5, 0.26), (7, 0.26),
                (9, 0.26), (11, 0.26), (13, 0.26), (15, 0.26)],
    },
    "full": {
        "kick": [(0, 1.0), (3, 0.50), (6, 0.68), (10, 0.84), (13, 0.46)],
        "snare": [(4, 0.88), (12, 0.92)],
        "hat": [(i, 0.42 if i % 2 == 0 else 0.26) for i in range(16)],
        "ohat": [(6, 0.26), (14, 0.30)],
    },
    "drive": {
        "kick": [(0, 1.0), (2, 0.42), (4, 0.72), (8, 1.0), (10, 0.44), (12, 0.78), (14, 0.40)],
        "snare": [(4, 0.90), (12, 0.94), (15, 0.34)],
        "hat": [(i, 0.34 if i % 2 == 0 else 0.22) for i in range(16)],
        "ohat": [(6, 0.24), (14, 0.28)],
    },
    "break": {
        "kick": [(0, 0.92), (8, 0.70)],
        "snare": [(8, 0.55)],
        "hat": [(4, 0.20), (12, 0.20)],
    },
    "march": {
        "kick": [(0, 1.0), (6, 0.60), (8, 0.85), (14, 0.55)],
        "snare": [(4, 0.85), (12, 0.90), (7, 0.30), (15, 0.32)],
        "hat": [(2, 0.26), (6, 0.24), (10, 0.26), (14, 0.24)],
    },
}

FILL_PATTERNS = {
    "snare_roll": {"snare": [(i, 0.35 + 0.04 * i) for i in (8, 9, 10, 11, 12, 13, 14, 15)]},
    "tom_fill": {"tom": [(0, 0.7), (2, 0.65), (4, 0.75), (6, 0.7), (8, 0.8), (10, 0.75),
                         (12, 0.85), (13, 0.8), (14, 0.9), (15, 0.9)]},
    "hat_roll": {"hat": [(i, 0.20 + 0.03 * i) for i in range(8, 16)]},
}


# --------------------------------------------------------------------- Bass

BASS_PATTERNS = {
    "half": [(0, 0, 7)],
    "quarter": [(0, 0, 3), (4, 0, 3), (8, 0, 3), (12, 0, 3)],
    "ostinato": [(0, 0, 2), (2, 0, 2), (4, 0, 2), (6, 0, 2),
                 (8, 0, 2), (10, 7, 2), (12, 0, 2), (14, 0, 2)],
    "boogie": [(0, 0, 2), (2, 7, 2), (4, 0, 2), (6, 10, 2),
               (8, 0, 2), (10, 7, 2), (12, 0, 2), (14, 12, 2)],
    "drive": [(i, (0, 0, 0, 7, 0, 0, 12, 0, 0, 0, 7, 0, 0, 5, 0, 0)[i], 1)
              for i in range(16)],
    "gallop": [(0, 0, 2), (3, 0, 1), (4, 0, 1), (6, 0, 2), (8, 0, 2),
               (11, 0, 1), (12, 0, 1), (14, 0, 2)],
    "walk": [(0, 0, 3), (4, 3, 3), (8, 7, 3), (12, 10, 3)],
    "march": [(0, 0, 2), (2, 0, 2), (4, 0, 2), (6, 0, 2),
              (8, 0, 2), (10, -5, 2), (12, 0, 2), (14, 7, 2)],
}
