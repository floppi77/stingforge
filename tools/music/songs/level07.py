"""Level 7 – Verlorene Kanalisation: schwer, echoend, unter Druck.

c-Moll mit phrygischer kleiner Sekunde (Db) · 100 BPM · Dub: alles hängt im
Echo, fast kein Schlagzeug, nur ein Pumpen-Puls und Wassertropfen. Das Klavier
steht weit hinten im Hall, ein portamento-führender Lead zieht die Melodie.

Form: A 23 · B 26 · C 25 · D 22 · E 19 Takte. Miniboss bei Levelzeit 148 s =
Takt 12 von C. Am Ende verstummen die Pumpen, nur Tropfen bleiben.
"""
from __future__ import annotations

from score import Song, n
from songs._kit import (BRAKE_SUSP, CRASH, CLASH, GONG, Human, SNARE, SWELL4, TIMP_LO,
                        TIMP_ROLL_LO, WOOD, arp, bassline, close, crash, drums, grid, pad, phrase,
                        repeat_to, voicing)
from songs._themes import fragment, invert, leitmotiv, mechanize, second_theme

BPM = 100

# ------------------------------------------------------------------ Harmonik
H1 = ['Cm', 'Db', 'Cm', 'G7']          # Db als phrygische Reibung
H2 = ['Cm', 'Fm', 'Db', 'G7']
H3 = ['Ab', 'Bb', 'Cm', 'G7']
H4 = ['Fm', 'Cm', 'Db', 'G7']
H5 = ['Cm', 'Ab', 'Db', 'G7']          # enger, dunkler
HMINI = ['Cm', 'Cm', 'Db', 'G7']

# ------------------------------------------------------------------ Motive
THEME = leitmotiv('C', 'min')                       # 8 Takte
THEME_HEAD = leitmotiv('C', 'min', part='head')
THEME_TAIL = leitmotiv('C', 'min', part='tail')
THEME_PHRYG = leitmotiv('C', 'phryg')               # mit Db
SECOND = second_theme('C', 'min')
DRIP = [('G5', .5), (None, 1.5), ('Eb5', .5), (None, 2.5), ('C5', .5), (None, 3.5)]     # 2 Takte
PUMP = [('C2', .5), (None, 1.5)]                                                      # 1 Takt


def drops(S: Song, part: str, sec: str, bar0: int, bars: int, base: int = 76, vel: int = 48,
          every: float = 1.5) -> None:
    """Wassertropfen: unregelmäßig, aber deterministisch gesetzt."""
    tones = [n(x) for x in ('G5', 'Eb5', 'C5', 'Bb5', 'G5', 'F5', 'Eb5', 'Db5')]
    t = 0.0
    i = 0
    total = bars * 4
    while t < total:
        S.add(part, sec, bar0, t, 1.2, tones[(i * 3) % len(tones)], vel + (i % 3) * 4)
        t += every + (0.25 if i % 4 == 0 else 0.0)
        i += 1


def build():
    song = Song.for_level(7, BPM)
    hum = Human(707)
    S = song

    # ---------------------------------------------------------- Intro (2,2 s)
    S.add('drone', 'intro', 0, 0, 4, n('C1'), 86, bright=0.28, aux=3.0)
    S.add('boom', 'intro', 0, 0, 4, n('C1'), 78)
    S.add('glass', 'intro', 0, 1.1, 1.6, n('G5'), 54, bright=0.4)
    for p in close('Cm', n('C3'), 3):
        S.add('piano', 'intro', 0, 0, 2.6, p, 60)

    # ---------------------------------------------------------- A (23 Takte)
    # Tropfen und Drohne; das Klavier kommt aus der Ferne.
    S.add('drone', 'A', 0, 0, 16, n('C1'), 94, bright=0.3, aux=3.4)
    drops(S, 'glass', 'A', 0, 8, vel=44)
    pad(S, 'pad', 'A', 0, repeat_to(H1, 8), vel=44, center=n('C3'), size=3, bright=0.16)
    for b in range(8):
        if b % 2 == 0:
            for p in close(H1[b % 4], n('C3'), 3):
                S.add('piano', 'A', b, 0, 3.6, p, 52)
            S.add('boom', 'A', b, 0, 3.0, n('C1'), 72)
    phrase(S, 'lead', 'A', 8, THEME_HEAD, vel=70, bright=0.3, human=hum)
    S.add('drone', 'A', 8, 0, 15, n('C2'), 84, bright=0.42, aux=3.0)
    bassline(S, 'bass', 'A', 8, repeat_to(H2, 8), 'roots', vel=78, bright=0.24)
    for b in range(8, 23):
        if b % 2 == 0:
            S.add('boom', 'A', b, 0, 2.4, n('C1'), 84 + (b % 4) * 2)
    drums(S, 'kit', 'A', 12, 11, 'dub', vel=66, human=hum)
    pad(S, 'vc_sus', 'A', 8, repeat_to(H2, 8), vel=48, center=n('C2'), size=3, bright=0.3)
    arp(S, 'piano', 'A', 16, repeat_to(H3, 7), step=1.0, low=n('C3'), high=n('C5'), shape='broken',
        vel=44, human=hum)
    drops(S, 'glass', 'A', 12, 11, vel=40)
    S.add('riser', 'A', 21, 0, 8, n('C1'), 50)

    # ---------------------------------------------------------- B (26 Takte)
    crash(S, 'kit', 'B', 0, 66)
    S.add('drone', 'B', 0, 0, 16, n('C1'), 104, bright=0.42, aux=3.6)
    S.add('drone', 'B', 0, 0, 16, n('G1'), 76, bright=0.34, aux=3.0)
    phrase(S, 'lead', 'B', 0, THEME_PHRYG, vel=82, bright=0.42, human=hum)
    phrase(S, 'piano', 'B', 0, THEME, vel=64, transpose=-12, human=hum)
    for b in range(8):
        for p in close(H2[b % 4], n('C3'), 3):
            S.add('piano', 'B', b, 1.5, 2.0, p, 46)
    pad(S, 'pad', 'B', 0, repeat_to(H2, 8), vel=50, center=n('C3'), size=4, bright=0.24)
    bassline(S, 'bass', 'B', 0, repeat_to(H2, 8), 'half', vel=88, bright=0.32)
    drums(S, 'kit', 'B', 0, 8, 'dub', vel=76, human=hum)
    for b in range(0, 8, 2):
        S.add('boom', 'B', b, 0, 3.0, n('C1'), 94)
    drops(S, 'glass', 'B', 0, 8, vel=42)

    crash(S, 'kit', 'B', 8, 64)
    phrase(S, 'lead', 'B', 8, SECOND, vel=84, bright=0.46, human=hum)
    phrase(S, 'vc_sus', 'B', 8, SECOND, vel=60, transpose=-24, human=hum)
    pad(S, 'pad', 'B', 8, repeat_to(H3, 8), vel=50, center=n('C4'), size=4, bright=0.28)
    bassline(S, 'bass', 'B', 8, repeat_to(H3, 8), 'half', vel=86, bright=0.3)
    drums(S, 'kit', 'B', 8, 8, 'dub', vel=74, human=hum, fill='timp')
    for b in range(8, 16, 2):
        S.add('boom', 'B', b, 0, 2.6, n('C1'), 92)
    arp(S, 'piano', 'B', 8, repeat_to(H3, 8), step=0.5, low=n('C3'), high=n('C6'), vel=46, human=hum)
    drops(S, 'glass', 'B', 8, 8, vel=40, every=1.75)

    # Takte 16–25: Druck steigt – Metall im Hall, Sub-Puls
    crash(S, 'kit', 'B', 16, 78)
    S.add('drone', 'B', 16, 0, 10, n('Db2'), 92, bright=0.5, aux=3.2)
    for b in range(10):
        S.add('boom', 'B', 16 + b, 0, 1.4, n('C1'), 96)
        S.add('boom', 'B', 16 + b, 2.5, 1.0, n('C1'), 84)
        S.add('kit', 'B', 16 + b, 1.5, .5, BRAKE_SUSP, 72)
        S.add('kit', 'B', 16 + b, 3.25, .2, WOOD, 62)
    phrase(S, 'lead', 'B', 16, THEME_PHRYG, vel=88, bright=0.5, human=hum)
    phrase(S, 'piano', 'B', 16, THEME_PHRYG, vel=62, transpose=-12, human=hum)
    pad(S, 'pad', 'B', 16, repeat_to(H5, 10), vel=54, center=n('C4'), size=4, bright=0.36)
    bassline(S, 'bass', 'B', 16, repeat_to(H5, 10), 'pop', vel=90, bright=0.4)
    drums(S, 'kit', 'B', 16, 10, 'dub', vel=80, human=hum, fill='roll')
    S.add('riser', 'B', 23, 0, 12, n('C1'), 72)
    S.add('kit', 'B', 23, 0, 12, SWELL4, 78)

    # ---------------------------------------------------------- C (25 Takte)
    # Takte 0–11: der Tunnel. Ab Takt 12 (= 148 s) der Schlickwächter.
    S.add('drone', 'C', 0, 0, 16, n('C1'), 92, bright=0.3, aux=3.2)
    pad(S, 'pad', 'C', 0, repeat_to(H5, 12), vel=44, center=n('C3'), size=3, bright=0.14)
    drops(S, 'glass', 'C', 0, 12, vel=40, every=1.25)
    for b in range(12):
        if b % 2 == 0:
            S.add('boom', 'C', b, 0, 2.0, n('C1'), 72)
        S.add('kit', 'C', b, 3.5, .2, WOOD, 48)
    phrase(S, 'piano', 'C', 0, fragment(leitmotiv('C', 'phryg'), 0, 16), vel=52, human=hum)
    S.add('kit', 'C', 11, 0, 4, TIMP_ROLL_LO, 84)

    # Miniboss (Takte 12–24): Metall, Sub, chromatische Enge
    crash(S, 'kit', 'C', 12, 96)
    S.add('kit', 'C', 12, 0, .3, CLASH, 92)
    S.add('boom', 'C', 12, 0, 4, n('C1'), 108)
    for bar, k in grid(13, 4):
        b = 12 + bar
        h = repeat_to(HMINI, k)
        pad(S, 'pad', 'C', b, h, vel=56, center=n('C4'), size=4, bright=0.4)
        bassline(S, 'bass', 'C', b, h, 'drive', vel=94, bright=0.5)
        drums(S, 'kit', 'C', b, k, 'industrial', vel=88, human=hum)
        arp(S, 'piano', 'C', b, h, step=0.5, low=n('C3'), high=n('C6'), vel=54, human=hum)
        for i in range(k):
            S.add('boom', 'C', b + i, 0, 1.2, n('C1'), 98)
            S.add('kit', 'C', b + i, 2.5, .4, BRAKE_SUSP, 78)
            S.add('glass', 'C', b + i, 3.75, .6, n('Db5'), 46)
    phrase(S, 'lead', 'C', 12, THEME_PHRYG, vel=94, bright=0.6, human=hum)
    phrase(S, 'vc_sus', 'C', 16, invert(leitmotiv('C', 'min')), vel=80, human=hum)
    phrase(S, 'piano', 'C', 20, mechanize(THEME_HEAD, 0.5)[:32], vel=66, human=hum)
    for b in range(4):
        S.add('kit', 'C', 21 + b, 0, .5, TIMP_LO, 100)
        S.add('kit', 'C', 21 + b, 2, .5, TIMP_LO, 94)
    S.add('riser', 'C', 21, 0, 16, n('C1'), 84)
    S.add('kit', 'C', 21, 0, 16, SWELL4, 88)

    # ---------------------------------------------------------- D (22 Takte)
    crash(S, 'kit', 'D', 0, 96)
    S.add('drone', 'D', 0, 0, 16, n('C1'), 110, bright=0.55, aux=3.8)
    S.add('drone', 'D', 0, 0, 16, n('Db2'), 88, bright=0.5, aux=3.2)
    phrase(S, 'lead', 'D', 0, leitmotiv('C', 'harm'), vel=90, bright=0.5, human=hum)
    phrase(S, 'piano', 'D', 0, THEME, vel=68, transpose=-12, human=hum)
    pad(S, 'pad', 'D', 0, repeat_to(H2, 8), vel=54, center=n('C4'), size=4, bright=0.34)
    bassline(S, 'bass', 'D', 0, repeat_to(H2, 8), 'pop', vel=94, bright=0.44)
    drums(S, 'kit', 'D', 0, 8, 'dub', vel=84, human=hum, fill='timp')
    for b in range(0, 8, 2):
        S.add('boom', 'D', b, 0, 3.2, n('C1'), 102)
    drops(S, 'glass', 'D', 0, 8, vel=44, every=2.0)

    crash(S, 'kit', 'D', 8, 92)
    phrase(S, 'lead', 'D', 8, SECOND, vel=88, bright=0.54, human=hum)
    phrase(S, 'vc_sus', 'D', 8, SECOND, vel=70, transpose=-12, human=hum)
    arp(S, 'piano', 'D', 8, repeat_to(H4, 8), step=0.25, low=n('C3'), high=n('C6'), vel=50, human=hum)
    pad(S, 'pad', 'D', 8, repeat_to(H4, 8), vel=56, center=n('C4'), size=4, bright=0.38)
    bassline(S, 'bass', 'D', 8, repeat_to(H4, 8), 'pop', vel=92, bright=0.42)
    drums(S, 'kit', 'D', 8, 8, 'dub', vel=82, human=hum, fill='snare')
    for b in range(8, 16, 2):
        S.add('boom', 'D', b, 0, 2.8, n('C1'), 100)

    for b in range(16, 22):                             # Takte 16–21: Verdichtung
        S.add('boom', 'D', b, 0, 1.2, n('C1'), 104)
        S.add('boom', 'D', b, 2.5, 1.0, n('C1'), 92)
        S.add('kit', 'D', b, 0, .5, TIMP_LO, 100)
        S.add('kit', 'D', b, 2, .5, TIMP_LO, 94)
        S.add('kit', 'D', b, 3.5, .3, BRAKE_SUSP, 78)
    phrase(S, 'lead', 'D', 16, THEME_PHRYG, vel=94, bright=0.6, human=hum)
    pad(S, 'pad', 'D', 16, repeat_to(H5, 6), vel=58, center=n('C4'), size=4, bright=0.44)
    bassline(S, 'bass', 'D', 16, repeat_to(H5, 6), 'drive', vel=94, bright=0.48)
    S.add('riser', 'D', 19, 0, 12, n('C1'), 88)
    S.add('kit', 'D', 19, 0, 12, SWELL4, 92)

    # ---------------------------------------------------------- E (19 Takte)
    # Die Pumpen verstummen: nur Tropfen, Drohne und ein letztes Echo.
    S.add('drone', 'E', 0, 0, 16, n('C1'), 96, bright=0.34, aux=3.0)
    pad(S, 'pad', 'E', 0, repeat_to(H5, 12), vel=46, center=n('C3'), size=3, bright=0.18)
    drops(S, 'glass', 'E', 0, 12, vel=46, every=1.0)
    phrase(S, 'piano', 'E', 0, fragment(THEME, 0, 12), vel=58, human=hum)
    phrase(S, 'lead', 'E', 2, fragment(THEME, 12, 12), vel=66, bright=0.34, human=hum)
    for b in range(0, 12, 4):
        S.add('boom', 'E', b, 0, 3.4, n('C1'), 88)
        S.add('kit', 'E', b, 3.5, .2, WOOD, 52)

    for b in range(12, 16):                             # Takte 12–15: Puls kehrt zurück
        S.add('boom', 'E', b, 0, 1.2, n('C1'), 100)
        S.add('boom', 'E', b, 2.5, 1.0, n('C1'), 90)
        S.add('kit', 'E', b, 0, .4, TIMP_LO, 96)
    bassline(S, 'bass', 'E', 12, repeat_to(HMINI, 4), 'drive', vel=92, bright=0.46)
    pad(S, 'pad', 'E', 12, repeat_to(HMINI, 4), vel=58, center=n('C4'), size=4, bright=0.46)
    drums(S, 'kit', 'E', 12, 4, 'dub', vel=88, human=hum, fill='roll')

    for b in range(16, 19):                             # Takte 16–18: Abriss
        S.add('kit', 'E', b, 0, .5, TIMP_LO, 112)
        S.add('boom', 'E', b, 0, 1.6, n('C1'), 106)
        for p in close('Cm', n('C2'), 3):
            S.add('vc_sus', 'E', b, 0, 2.0, p, 96, bright=0.5)
    S.add('riser', 'E', 15, 0, 16, n('C1'), 96)
    S.add('kit', 'E', 15, 0, 16, SWELL4, 100)
    S.add('drone', 'E', 14, 0, 5, n('Db2'), 104, bright=0.7, aux=4.2)

    # ---------------------------------------------------------- Ankündigung (1,25 s)
    S.add('kit', 'tail', 0, 0, 2.5, TIMP_LO, 122)
    S.add('kit', 'tail', 0, 0, 2.5, GONG, 110)
    S.add('boom', 'tail', 0, 0, 2.5, n('C1'), 112)
    for p in close('Cm', n('C3'), 4):
        S.add('piano', 'tail', 0, 0, 1.2, p, 112)
        S.add('vc_sus', 'tail', 0, 0, 1.2, p - 12, 104)

    mixspec = {
        'kit':      {'engine': 'sfz', 'inst': 'kit', 'gain': -2.0, 'rev': 0.45},
        'piano':    {'engine': 'sfz', 'inst': 'piano', 'gain': -5.0, 'pan': -0.22, 'rev': 0.62, 'lp': 4800, 'dly': 0.22},
        'vc_sus':   {'engine': 'sfz', 'inst': 'vc_sus', 'gain': -6.0, 'pan': 0.18, 'rev': 0.4},
        'lead':     {'engine': 'cs', 'instr': 'lead', 'gain': -3.0, 'pan': 0.08, 'rev': 0.45, 'dly': 0.4},
        'pad':      {'engine': 'cs', 'instr': 'pad', 'gain': -10.0, 'rev': 0.5, 'hp': 110, 'width': 1.3, 'lp': 3000},
        'bass':     {'engine': 'cs', 'instr': 'bass', 'gain': -1.5, 'lp': 1500},
        'drone':    {'engine': 'cs', 'instr': 'drone', 'gain': -3.0, 'rev': 0.28, 'lp': 2600},
        'glass':    {'engine': 'cs', 'instr': 'glass', 'gain': -11.0, 'pan': 0.3, 'rev': 0.55, 'dly': 0.34},
        'riser':    {'engine': 'cs', 'instr': 'riser', 'gain': -9.0, 'rev': 0.24},
        'boom':     {'engine': 'cs', 'instr': 'boom', 'gain': -3.0, 'rev': 0.2},
    }
    return song, mixspec, {'file': 'level7', 'title': 'Level 7 – Verlorene Kanalisation', 'reverb': 3.2}
