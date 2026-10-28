"""Level 6 – Gläsernes Gewächshaus: kalt, präzise, kristallin.

H-Dur lydisch (mit E#/F als lydischer Färbung) · 120 BPM · durchgehende
Sechzehntel. Zwei Arpeggien laufen mit unterschiedlichen Schrittweiten durch
denselben Vorrat und verschieben sich gegeneinander (Phasing). Alles Glas:
Glockenspiel, Vibraphon, FM-Glas, hohe Flageolett-Streicher.

Form: A 28 · B 31 · C 30 · D 27 · E 23 Takte. Miniboss bei Levelzeit 148 s =
Takt 14 von C.
"""
from __future__ import annotations

from score import Song, n
from songs._kit import (CHIMES_FAST, CRASH, CLASH, GONG, Human, SHAKE_A, SWELL4, TIMP_LO,
                        TIMP_ROLL_LO, TRI, WOOD, arp, bassline, close, crash, drums, grid, pad,
                        phrase, repeat_to, voicing)
from songs._themes import fragment, leitmotiv, mechanize, second_theme, transposed

BPM = 120

# ------------------------------------------------------------------ Harmonik
H1 = ['Bsus2', 'D#sus4', 'C#sus4', 'G#sus2']
H2 = ['Esus2', 'F#sus4', 'Bsus2', 'D#sus4']
H3 = ['G#sus4', 'C#sus4', 'Esus2', 'Bsus2']
H4 = ['Bsus2', 'A#sus4', 'G#sus2', 'F#sus4']          # chromatischer Abstieg: das Glas springt
HMINI = ['Bsus2', 'Bsus2', 'C#sus4', 'F#sus4']

# ------------------------------------------------------------------ Motive
THEME = leitmotiv('B', 'lyd')                       # 8 Takte
THEME_HEAD = leitmotiv('B', 'lyd', part='head')
THEME_TAIL = leitmotiv('B', 'lyd', part='tail')
SECOND = second_theme('B', 'lyd')
SPLINTER = mechanize(fragment(leitmotiv('B', 'lyd'), 0, 8), 0.25)[:64]     # 4 Takte 16tel
CRYSTAL = [('B5', .25), (None, .75), ('F#6', .25), (None, 1.75),
           ('D#6', .25), (None, .75), ('A#6', .25), (None, 1.75)]          # 2 Takte


def phased(S: Song, part: str, sec: str, bar0: int, bars: int, pool: list[int],
           stride: int, vel: int = 56, step: float = 0.25, dur: float | None = None) -> None:
    """Phasing-Arpeggio: läuft mit eigener Schrittweite durch denselben Vorrat."""
    steps = int(round(bars * 4 / step))
    dur = step * 0.92 if dur is None else dur
    for i in range(steps):
        S.add(part, sec, bar0, i * step, dur, pool[(i * stride) % len(pool)],
              vel if i % 4 == 0 else int(vel * 0.8))


def build():
    song = Song.for_level(6, BPM)
    hum = Human(606)
    S = song

    pool_hi = [n(x) for x in ('B4', 'D#5', 'F#5', 'A#5', 'C#6', 'E6', 'F#6', 'B6')]
    pool_lo = [n(x) for x in ('B2', 'D#3', 'F#3', 'A#3', 'C#4', 'E4')]

    # ---------------------------------------------------------- Intro (2,2 s)
    for p in close('Bmaj7', n('B4'), 4):
        S.add('glock', 'intro', 0, 0.05 * (p % 7), 2.4, p, 62)
    S.add('pad', 'intro', 0, 0, 4, n('B3'), 54, bright=0.4)
    S.add('glass', 'intro', 0, 0.6, 2.0, n('F#6'), 58, bright=0.55)

    # ---------------------------------------------------------- A (28 Takte)
    # Glas wächst: erst Tropfen, dann Sechzehntel.
    pad(S, 'pad', 'A', 0, repeat_to(H1, 8), vel=48, center=n('B3'), size=3, bright=0.26)
    for b in range(8):
        S.add('glass', 'A', b, 2.25, 1.2, n('F#6') if b % 2 else n('B6'), 44)
    phased(S, 'glock', 'A', 4, 8, pool_hi, 5, vel=54, step=0.5)
    arp(S, 'piano', 'A', 4, repeat_to(H2, 8), step=0.25, low=n('B2'), high=n('B4'), vel=40, human=hum)
    bassline(S, 'bass', 'A', 4, repeat_to(H2, 8), 'pulse', vel=76, bright=0.3)
    phrase(S, 'vibes', 'A', 12, THEME_HEAD, vel=74, human=hum)
    phased(S, 'glock', 'A', 12, 4, pool_hi, 3, vel=58, step=0.25)
    pad(S, 'vln_sus', 'A', 12, repeat_to(H2, 4), vel=52, center=n('B4'), size=3, bright=0.5)
    bassline(S, 'bass', 'A', 12, repeat_to(H2, 4), 'drive', vel=82, bright=0.36)
    for b in range(4):
        for s in range(8):
            S.add('kit', 'A', 12 + b, s * 0.5, .12, WOOD if s % 2 else TRI, 44 + (6 if s % 4 == 0 else 0))
    phrase(S, 'vibes', 'A', 16, THEME_TAIL, vel=76, human=hum)
    phrase(S, 'glock', 'A', 16, THEME_TAIL, vel=66, transpose=12, human=hum, legato=1.1)
    phased(S, 'glock', 'A', 16, 8, pool_hi, 7, vel=56, step=0.25)
    arp(S, 'piano', 'A', 16, repeat_to(H3, 8), step=0.25, low=n('B2'), high=n('B4'), vel=44, human=hum)
    pad(S, 'pad', 'A', 16, repeat_to(H3, 8), vel=52, center=n('B3'), size=4, bright=0.32)
    bassline(S, 'bass', 'A', 16, repeat_to(H3, 8), 'drive', vel=84, bright=0.4)
    drums(S, 'kit', 'A', 16, 8, 'glitch', vel=62, human=hum)
    S.add('riser', 'A', 26, 0, 8, n('B2'), 56)
    S.add('kit', 'A', 26, 0, 8, SWELL4, 66)

    # ---------------------------------------------------------- B (31 Takte)
    crash(S, 'kit', 'B', 0, 84)
    phrase(S, 'vibes', 'B', 0, THEME, vel=84, human=hum)
    phased(S, 'glock', 'B', 0, 8, pool_hi, 3, vel=62, step=0.25)
    phased(S, 'piano', 'B', 0, 8, pool_lo, 4, vel=46, step=0.25)
    pad(S, 'pad', 'B', 0, repeat_to(H1, 8), vel=54, center=n('B3'), size=4, bright=0.34)
    bassline(S, 'bass', 'B', 0, repeat_to(H1, 8), 'drive', vel=88, bright=0.44)
    drums(S, 'kit', 'B', 0, 8, 'glitch', vel=74, human=hum)
    for b in range(8):
        S.add('glass', 'B', b, 3.5, .6, n('A#6') if b % 2 else n('F#6'), 46)

    crash(S, 'kit', 'B', 8, 80)
    phrase(S, 'glock', 'B', 8, SECOND, vel=80, human=hum, legato=1.15)
    phrase(S, 'vln_sus', 'B', 8, SECOND, vel=62, transpose=-12, human=hum)
    phased(S, 'glock', 'B', 8, 8, pool_hi, 5, vel=60, step=0.25)
    phased(S, 'vibes', 'B', 8, 8, pool_hi, 7, vel=54, step=0.25)
    pad(S, 'pad', 'B', 8, repeat_to(H2, 8), vel=54, center=n('B4'), size=4, bright=0.38)
    bassline(S, 'bass', 'B', 8, repeat_to(H2, 8), 'drive', vel=86, bright=0.42)
    drums(S, 'kit', 'B', 8, 8, 'glitch', vel=72, human=hum, fill='snare')

    crash(S, 'kit', 'B', 16, 76)
    phrase(S, 'vibes', 'B', 16, SPLINTER, vel=78, human=hum)
    phased(S, 'glock', 'B', 16, 7, pool_hi, 11, vel=58, step=0.25)
    arp(S, 'piano', 'B', 16, repeat_to(H3, 7), step=0.125, low=n('B3'), high=n('B5'), vel=40, human=hum)
    pad(S, 'pad', 'B', 16, repeat_to(H3, 7), vel=56, center=n('B4'), size=4, bright=0.42)
    bassline(S, 'bass', 'B', 16, repeat_to(H3, 7), 'drive', vel=90, bright=0.46)
    drums(S, 'kit', 'B', 16, 7, 'glitch', vel=78, human=hum)
    for b in range(7):
        S.add('kit', 'B', 16 + b, 0, .2, TRI, 70)
        S.add('kit', 'B', 16 + b, 1.75, .2, WOOD, 62)
    for b in range(23, 27):                             # Takte 23–26: Aufbau
        for i in range(4):
            S.add('glock', 'B', b, i, .2, pool_hi[(i * 3 + b) % len(pool_hi)], 58 if i == 0 else 46)
        S.add('kit', 'B', b, 0, .4, TIMP_LO, 88)
        S.add('kit', 'B', b, 2, .3, WOOD, 72)
        S.add('glass', 'B', b, 1.5, .5, n('F#6') if b % 2 else n('C#7'), 50)
    phrase(S, 'vibes', 'B', 23, fragment(THEME, 8, 12), vel=76, human=hum)
    phrase(S, 'glock', 'B', 23, fragment(THEME, 20, 12), vel=66, transpose=12, human=hum, legato=1.2)
    pad(S, 'pad', 'B', 23, repeat_to(H4, 4), vel=58, center=n('B4'), size=4, bright=0.46)
    bassline(S, 'bass', 'B', 23, repeat_to(H4, 4), 'drive', vel=92, bright=0.5)
    drums(S, 'kit', 'B', 23, 4, 'glitch', vel=80, human=hum, fill='snare')
    S.add('riser', 'B', 27, 0, 12, n('B2'), 68)
    S.add('kit', 'B', 28, 0, 12, SWELL4, 78)

    # ---------------------------------------------------------- C (30 Takte)
    # Takte 0–13: das Glas klingt allein. Ab Takt 14 (= 148 s) der Spiegelkern.
    pad(S, 'pad', 'C', 0, repeat_to(H4, 14), vel=46, center=n('B3'), size=3, bright=0.2)
    for b in range(0, 14, 2):
        phrase(S, 'glock', 'C', b, CRYSTAL, vel=62, human=hum, legato=1.3)
    phased(S, 'vibes', 'C', 0, 14, pool_hi, 9, vel=42, step=0.5)
    for b in range(14):
        S.add('glass', 'C', b, 1.5, 1.0, n('F#6') if b % 3 else n('C#7'), 42)
    S.add('kit', 'C', 13, 0, 4, TIMP_ROLL_LO, 82)

    # Miniboss (Takte 14–29): Sechzehntel-Maschine, grelles Glas
    crash(S, 'kit', 'C', 14, 98)
    S.add('kit', 'C', 14, 0, .3, CLASH, 96)
    for bar, k in grid(16, 4):
        b = 14 + bar
        h = repeat_to(HMINI, k)
        phased(S, 'glock', 'C', b, k, pool_hi, 5, vel=64, step=0.25)
        phased(S, 'vibes', 'C', b, k, pool_hi, 3, vel=56, step=0.25)
        arp(S, 'piano', 'C', b, h, step=0.25, low=n('B2'), high=n('B4'), vel=46, human=hum)
        pad(S, 'pad', 'C', b, h, vel=56, center=n('B4'), size=4, bright=0.44)
        bassline(S, 'bass', 'C', b, h, 'drive', vel=94, bright=0.5)
        drums(S, 'kit', 'C', b, k, 'glitch', vel=86, human=hum)
    phrase(S, 'vibes', 'C', 14, THEME, vel=88, human=hum)
    phrase(S, 'glock', 'C', 18, THEME, vel=78, transpose=12, human=hum, legato=1.1)
    phrase(S, 'vln_sus', 'C', 22, SPLINTER + SPLINTER, vel=80, human=hum)
    for b in range(4):
        S.add('glass', 'C', 26 + b, 0, .5, n('C#7'), 62)
        S.add('glass', 'C', 26 + b, 2, .5, n('F#7') if b % 2 else n('G#7'), 60)
    S.add('riser', 'C', 27, 0, 12, n('B2'), 82)
    S.add('kit', 'C', 28, 0, 8, SWELL4, 88)

    # ---------------------------------------------------------- D (27 Takte)
    crash(S, 'kit', 'D', 0, 100)
    phrase(S, 'vibes', 'D', 0, THEME, vel=88, human=hum)
    phrase(S, 'glock', 'D', 0, THEME, vel=76, transpose=12, human=hum, legato=1.1)
    phased(S, 'glock', 'D', 0, 8, pool_hi, 3, vel=66, step=0.25)
    phased(S, 'vibes', 'D', 0, 8, pool_hi, 5, vel=58, step=0.25)
    pad(S, 'pad', 'D', 0, repeat_to(H3, 8), vel=58, center=n('B4'), size=4, bright=0.46)
    bassline(S, 'bass', 'D', 0, repeat_to(H3, 8), 'drive', vel=94, bright=0.5)
    drums(S, 'kit', 'D', 0, 8, 'glitch', vel=88, human=hum, fill='timp')

    crash(S, 'kit', 'D', 8, 94)
    phrase(S, 'vibes', 'D', 8, SECOND, vel=86, human=hum)
    phrase(S, 'vln_sus', 'D', 8, SECOND, vel=70, transpose=12, human=hum)
    phased(S, 'glock', 'D', 8, 8, pool_hi, 7, vel=64, step=0.25)
    arp(S, 'piano', 'D', 8, repeat_to(H2, 8), step=0.125, low=n('B3'), high=n('B5'), vel=42, human=hum)
    pad(S, 'pad', 'D', 8, repeat_to(H2, 8), vel=58, center=n('B4'), size=4, bright=0.5)
    bassline(S, 'bass', 'D', 8, repeat_to(H2, 8), 'pulse', vel=92, bright=0.5)
    drums(S, 'kit', 'D', 8, 8, 'glitch', vel=86, human=hum, fill='snare')

    # Takte 16–26: chromatischer Abstieg – das Glas bekommt Risse
    crash(S, 'kit', 'D', 16, 98)
    for bar, k in grid(11, 4):
        b = 16 + bar
        h = repeat_to(H4, k)
        phased(S, 'glock', 'D', b, k, pool_hi, 11, vel=62, step=0.25)
        arp(S, 'piano', 'D', b, h, step=0.25, low=n('B2'), high=n('B4'), vel=48, human=hum)
        pad(S, 'pad', 'D', b, h, vel=58, center=n('B4'), size=4, bright=0.5)
        bassline(S, 'bass', 'D', b, h, 'drive', vel=96, bright=0.54)
        drums(S, 'kit', 'D', b, k, 'glitch', vel=90, human=hum)
        for i in range(k):
            S.add('kit', 'D', b + i, 0, .25, TRI, 78)
            S.add('kit', 'D', b + i, 2.5, .25, CHIMES_FAST, 60)
    phrase(S, 'vibes', 'D', 20, leitmotiv('B', 'min') + leitmotiv('B', 'min', part='head'), vel=90,
           human=hum)
    S.add('riser', 'D', 24, 0, 12, n('B2'), 88)
    S.add('kit', 'D', 24, 0, 12, SWELL4, 92)

    # ---------------------------------------------------------- E (23 Takte)
    # Das Glas zerspringt: nur noch Splitter, dann Stille vor dem Riser.
    crash(S, 'kit', 'E', 0, 90)
    pad(S, 'pad', 'E', 0, repeat_to(H4, 12), vel=50, center=n('B3'), size=3, bright=0.3)
    phased(S, 'glock', 'E', 0, 12, pool_hi, 13, vel=54, step=0.25)
    for b in range(12):
        S.add('glass', 'E', b, 1.75, .8, n('G#7') if b % 2 else n('D#7'), 44)
        S.add('kit', 'E', b, 3, .2, TRI, 46)
    phrase(S, 'vibes', 'E', 0, fragment(THEME, 0, 12), vel=74, human=hum)
    phrase(S, 'glock', 'E', 4, fragment(THEME, 12, 12), vel=64, transpose=12, human=hum, legato=1.2)
    bassline(S, 'bass', 'E', 0, repeat_to(H4, 12), 'roots', vel=78, bright=0.3)

    # Takte 12–22: Zersplittern, Riser, Abriss
    crash(S, 'kit', 'E', 12, 96)
    for b in range(8):
        for s in range(16):
            S.add('glock', 'E', 12 + b, s * 0.25, .22,
                  pool_hi[(s * 3 + b) % len(pool_hi)], 58 if s % 4 == 0 else 44)
        S.add('kit', 'E', 12 + b, 0, .3, TIMP_LO, 92)
        S.add('kit', 'E', 12 + b, 2, .3, WOOD, 78)
    phrase(S, 'vibes', 'E', 12, leitmotiv('B', 'min', part='head') + THEME_HEAD, vel=88, human=hum)
    pad(S, 'pad', 'E', 12, repeat_to(H4, 8), vel=60, center=n('B4'), size=4, bright=0.55)
    bassline(S, 'bass', 'E', 12, repeat_to(H4, 8), 'drive', vel=94, bright=0.52)
    drums(S, 'kit', 'E', 12, 8, 'glitch', vel=88, human=hum, fill='roll')
    S.add('riser', 'E', 18, 0, 20, n('B2'), 94)
    S.add('kit', 'E', 18, 0, 20, SWELL4, 96)

    # ---------------------------------------------------------- Ankündigung (1,25 s)
    S.add('kit', 'tail', 0, 0, 2.5, CLASH, 114)
    S.add('kit', 'tail', 0, 0, 2.5, GONG, 108)
    S.add('boom', 'tail', 0, 0, 2.5, n('B1'), 100)
    for p in close('Bmaj7', n('B4'), 4):
        S.add('glock', 'tail', 0, 0, 1.2, p + 12, 108)
    S.add('pad', 'tail', 0, 0, 1.2, n('F#4'), 104, bright=0.6)
    S.add('kit', 'tail', 0, 0, 1.2, TIMP_LO, 110)

    mixspec = {
        'kit':      {'engine': 'sfz', 'inst': 'kit', 'gain': -2.0, 'rev': 0.22},
        'glock':    {'engine': 'sfz', 'inst': 'glock', 'gain': -7.0, 'pan': 0.28, 'rev': 0.34, 'dly': 0.16},
        'vibes':    {'engine': 'sfz', 'inst': 'vibes', 'gain': -5.5, 'pan': -0.24, 'rev': 0.34, 'dly': 0.18},
        'piano':    {'engine': 'sfz', 'inst': 'piano', 'gain': -9.0, 'pan': -0.08, 'rev': 0.3, 'dly': 0.1},
        'vln_sus':  {'engine': 'sfz', 'inst': 'vln_sus', 'gain': -7.0, 'pan': 0.08, 'rev': 0.4},
        'pad':      {'engine': 'cs', 'instr': 'pad', 'gain': -10.0, 'rev': 0.42, 'hp': 160, 'width': 1.3},
        'bass':     {'engine': 'cs', 'instr': 'bass', 'gain': -2.5, 'lp': 2600},
        'glass':    {'engine': 'cs', 'instr': 'glass', 'gain': -11.0, 'pan': 0.3, 'rev': 0.44, 'dly': 0.2},
        'riser':    {'engine': 'cs', 'instr': 'riser', 'gain': -10.0, 'rev': 0.2},
        'boom':     {'engine': 'cs', 'instr': 'boom', 'gain': -6.0, 'rev': 0.14},
    }
    return song, mixspec, {'file': 'level6', 'title': 'Level 6 – Gläsernes Gewächshaus', 'reverb': 2.7}
