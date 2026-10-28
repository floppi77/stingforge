"""Leitmotiv und Verwandlungen für Level 2–10.

Das Stingforge-Thema wird in Level 1 (D-Dur, lydisch) vorgestellt. Hier liegt es
ein zweites Mal als gemeinsamer Baukasten: `leitmotiv()` schreibt es in eine
beliebige Tonart und Leiter um, damit dasselbe Thema in jedem Level als Moll-,
dorische oder mechanisierte Fassung wiederkehrt.

Die Notenlisten sind absichtlich identisch mit `songs/level01.py`; dort bleiben
sie unverändert, weil Level 1 als Muster abgenommen ist.
"""
from __future__ import annotations

from score import n

# ------------------------------------------------------------------ Thema
# 4 Takte Vorstellung + 4 Takte Antwort, zusammen 8 Takte über THEME_H.
THEME_1 = [('D5', 1), ('F#5', .5), ('A5', .5), ('B5', 1.5), ('A5', .5),
           ('G5', 1), ('F#5', 1), ('E5', 2),
           ('F#5', .5), ('A5', .5), ('D6', 1), ('C#6', .5), ('B5', .5), ('A5', 1),
           ('G#5', .5), ('A5', .5), ('B5', 1), ('A5', 2)]
THEME_2 = [('D5', 1), ('F#5', .5), ('A5', .5), ('B5', 1.5), ('D6', .5),
           ('C#6', 1), ('B5', 1), ('A5', 2),
           ('B5', .5), ('A5', .5), ('G5', .5), ('F#5', .5), ('E5', 1), ('F#5', .5), ('G5', .5),
           ('F#5', .5), ('E5', .5), ('D5', 3)]
THEME = THEME_1 + THEME_2
THEME_H = ['D', 'Gmaj7', 'Bm7', 'E', 'D', 'A', 'G|A7', 'D']

# Zweite Melodie (B-Teil von Level 1) und der Moll-Gegensatz
PHRASE_B = [('B5', 1.5), ('A5', .5), ('G5', 1), ('E5', 1),
            ('E5', .5), ('F#5', .5), ('G5', 1), ('A5', 2),
            ('C#6', 1.5), ('B5', .5), ('A5', 1), ('F#5', 1),
            ('D6', 1), ('C#6', .5), ('B5', .5), ('F#5', 2),
            ('G5', 1.5), ('A5', .5), ('B5', 1), ('D6', 1),
            ('C#6', 2), ('E6', 1), ('C#6', 1),
            ('D6', 1), ('B5', 1), ('C#6', 1), ('A5', 1),
            ('D6', 4)]
PHRASE_B_H = ['Em7', 'A7sus', 'F#m7', 'Bm7', 'Gmaj7', 'A', 'Bm7|A', 'D']
PHRASE_B_GLOCK = [(None, 2), ('E6', .5), ('G6', .5), ('B6', 1), (None, 2), ('A6', .5), ('E6', .5), ('D6', 1),
                  (None, 2), ('F#6', .5), ('A6', .5), ('C#7', 1), (None, 2), ('B6', .5), ('F#6', .5), ('D6', 1),
                  (None, 2), ('D6', .5), ('F#6', .5), ('B6', 1), (None, 3), ('A6', 1),
                  (None, 2), ('A6', .5), ('F#6', .5), ('E6', 1), ('F#6', .5), ('A6', .5), ('D7', 3)]
THEME_MIN = [('B4', 1), ('D5', .5), ('F#5', .5), ('G5', 1.5), ('F#5', .5),
             ('E5', 1), ('D5', 1), ('C#5', 2),
             ('D5', .5), ('F#5', .5), ('B5', 1), ('A#5', .5), ('G5', .5), ('F#5', 1),
             ('E5', .5), ('F#5', .5), ('G5', 1), ('F#5', 2)]
THEME_MIN_H = ['Bm', 'Em', 'G', 'F#7b9']
BRIDGE = [('F#5', 1), ('B5', 1), ('A5', .5), ('F#5', .5), ('D5', 1),
          ('G5', 1.5), ('F#5', .5), ('E5', 1), ('D5', 1),
          ('F#5', 2), ('A5', 1), ('D6', 1),
          ('C#6', 1.5), ('B5', .5), ('A5', 2),
          ('B5', 1), ('D6', 1), ('C#6', .5), ('B5', .5), ('F#5', 1),
          ('G5', 1), ('B5', 1), ('D6', 1), ('B5', 1),
          ('E6', 1.5), ('D6', .5), ('B5', 1), ('G5', 1),
          ('A#5', 2), ('C#6', 2)]
BRIDGE_H = ['Bm', 'G', 'D', 'A', 'Bm', 'G', 'Em', 'F#']

# ------------------------------------------------------------------ Leitern
SCALES = {
    'maj': (0, 2, 4, 5, 7, 9, 11),
    'min': (0, 2, 3, 5, 7, 8, 10),
    'harm': (0, 2, 3, 5, 7, 8, 11),
    'dorian': (0, 2, 3, 5, 7, 9, 10),
    'phryg': (0, 1, 3, 5, 7, 8, 10),
    'lyd': (0, 2, 4, 6, 7, 9, 11),
    'mixo': (0, 2, 4, 5, 7, 9, 10),
    'whole': (0, 2, 4, 6, 8, 10),
}
TONIC = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6,
         'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}
_NAMES = ('C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B')


def midi_name(m: int) -> str:
    return f'{_NAMES[m % 12]}{m // 12 - 1}'


def remap(notes, src_key: str = 'D', src_scale: str = 'maj',
          dst_key: str = 'D', dst_scale: str = 'min', transpose: int = 0):
    """Notenliste leitereigen umschreiben – Kontur und Lage bleiben erhalten.

    Jeder Ton wird als Leiterstufe plus Oktave gelesen und in der Zielleiter auf
    derselben Stufe und in derselben Oktave neu gesetzt. Dadurch bleibt die
    Melodie in ihrer Gestalt: Sprünge bleiben Sprünge, Schritte bleiben Schritte.
    Leiterfremde Töne (etwa das Gis der lydischen Färbung im Original) werden auf
    die nächstgelegene Leiterstufe gelegt. Eine mitgenommene chromatische Abweichung
    klingt in einer Moll-Leiter schnell falsch: das Gis des Originals würde in
    a-Phrygisch zum D kommen, und D gegen A ist ein Tritonus. Die lydische Färbung
    entsteht in der lydischen Fassung ohnehin aus der Leiter selbst (erhöhte vierte
    Stufe), sie muss nicht künstlich mitgeschleppt werden.

    Rückgabe sind MIDI-Nummern, keine Notennamen – die Aufrufer rechnen damit.
    """
    src = SCALES[src_scale]                    # Stufen relativ zum Grundton
    dst = SCALES[dst_scale]
    dst_tonic = TONIC[dst_key]
    src_tonic = TONIC[src_key]
    out = []
    for p, d in notes:
        if p is None:
            out.append((None, d))
            continue
        m = n(p) + transpose
        rel = m - src_tonic                      # Abstand zum Grundton, in Halbtönen
        pc_rel = rel % 12
        if pc_rel in src:
            degree = src.index(pc_rel)
        else:
            # chromatischer Ton: auf die Stufe darunter legen, nicht verstimmt mitnehmen
            degree = max(i for i, st in enumerate(src) if st <= pc_rel)
        octave = (rel - pc_rel) // 12             # Oktavlage der Quellstufe
        cand = dst_tonic + dst[degree] + 12 * octave
        out.append((cand, d))
    return out


def leitmotiv(dst_key: str = 'D', dst_scale: str = 'min', transpose: int = 0, part: str = 'all'):
    """Das Thema in einer Zielfassung; part = 'all' | 'head' (Takt 1–4) | 'tail' (5–8)."""
    src = {'all': THEME, 'head': THEME_1, 'tail': THEME_2}[part]
    return remap(src, 'D', 'maj', dst_key, dst_scale, transpose)


def second_theme(dst_key: str = 'D', dst_scale: str = 'min', transpose: int = 0):
    return remap(PHRASE_B, 'D', 'maj', dst_key, dst_scale, transpose)


def _num(p):
    """Tonhöhe als MIDI-Nummer – akzeptiert Zahlen und Notennamen."""
    return int(p) if isinstance(p, int) else n(p)


def transposed(notes, semis: int):
    return [(None, d) if p is None else (_num(p) + semis, d) for p, d in notes]


def rotate(notes, beats: float):
    """Thema rhythmisch verschieben (Auftakt-Verschiebung um `beats`)."""
    total = sum(d for _, d in notes)
    shift = beats % total
    out, acc = [], 0.0
    for p, d in notes:
        out.append((p, d))
    # Noten an der neuen Einsatzstelle beginnen lassen: Pause voranstellen
    return [(None, shift)] + out if shift else out


def fragment(notes, start_beat: float = 0.0, beats: float | None = None):
    """Ausschnitt des Themas (für Zitate und Verkürzungen)."""
    out, acc = [], 0.0
    for p, d in notes:
        if acc >= start_beat and (beats is None or acc < start_beat + beats):
            out.append((p, d))
        acc += d
    return out


def mechanize(notes, div: float = 0.25, repeat: int = 2):
    """Mechanisieren: jede Note in kurze, gleiche Stöße zerlegen (Maschinenherz)."""
    out = []
    for p, d in notes:
        if p is None:
            out.append((None, d))
            continue
        steps = max(1, int(round(d / div)))
        for _ in range(steps):
            out.append((p, div))
    return out


def augment(notes, factor: float = 2.0):
    """Augmentation: alles doppelt so lang (epische Dehnung, Level 10)."""
    return [(p, d * factor) for p, d in notes]


def invert(notes, axis='D5'):
    """Umkehrung um eine Achse (Spiegelmotiv für Bedrohungsvarianten)."""
    a = _num(axis) if isinstance(axis, str) else int(axis)
    return [(None, d) if p is None else (2 * a - _num(p), d) for p, d in notes]


__all__ = ['THEME', 'THEME_1', 'THEME_2', 'THEME_H', 'PHRASE_B', 'PHRASE_B_H', 'PHRASE_B_GLOCK',
           'THEME_MIN', 'THEME_MIN_H', 'BRIDGE', 'BRIDGE_H', 'SCALES', 'TONIC', 'midi_name',
           'remap', 'leitmotiv', 'second_theme', 'transposed', 'rotate', 'fragment', 'mechanize',
           'augment', 'invert']
