"""Level 4 – Pilzwald: schwebend, feucht, hypnotisch.

Fis-Dorisch · 90 BPM · Trip-Hop-Halftime mit 3-gegen-4-Polyrhythmus in den
Sporenshakern. Drei Glockentöne (E-Dur-Dreiklang) takten den Weg, ein verstimmter
Ah-Chor liegt darunter. Der Miniboss (Sporenschleuderer, Levelzeit 148 s =
Takt 11 von C) zerlegt das Material in Partikel.

Form: A 21 · B 23 · C 22 · D 20 · E 18 Takte.
"""
from __future__ import annotations

from score import Song, n
from songs._kit import (lead_in, CRASH, GONG, Human, SHAKE_A, SHAKE_B, SHAKE_C, SNARE_ROLL, SWELL4,
                        TIMP_LO, TIMP_ROLL_LO, TRI, WOOD, arp, bassline, close, crash, drums,
                        grid, pad, phrase, repeat_to, voicing)
from songs._themes import fragment, invert, leitmotiv, mechanize, second_theme

BPM = 90

# ------------------------------------------------------------------ Harmonik
H1 = ['F#sus4', 'G#sus4', 'F#sus2', 'Dsus2']
H2 = ['F#sus4', 'Bsus4', 'Esus4', 'Dsus2']
H3 = ['Bsus2', 'C#sus4', 'F#sus4', 'Esus2']
H4 = ['Dsus2', 'Esus4', 'F#sus4', 'C#sus4']
H5 = ['F#sus4', 'Dsus2', 'C#sus2', 'Bsus4']          # dunkler: Pilzgeflecht
HMINI = ['F#sus4', 'F#sus4', 'Dsus2', 'Esus4']

# ------------------------------------------------------------------ Motive
THEME = leitmotiv('F#', 'dorian')                    # 8 Takte
THEME_HEAD = leitmotiv('F#', 'dorian', part='head')
THEME_TAIL = leitmotiv('F#', 'dorian', part='tail')
SECOND = second_theme('F#', 'dorian', transpose=0)
THEME_INV = invert(leitmotiv('F#', 'dorian'))
BELLS = [('E6', 1), (None, 1.5), ('B6', .5), (None, 1),
         ('G#6', 1), (None, 2.5), ('E6', 2), ('F#6', 1), ('E6', 3)]      # 4 Takte Taktgeber
PARTICLE = mechanize(fragment(leitmotiv('F#', 'dorian'), 0, 8), 0.25)[:48]


def build():
    song = Song.for_level(4, BPM)
    hum = Human(404)
    S = song

    def bell_bar(sec, bar, vel=64):
        """Der Glockentakt: E-Dur-Dreiklang als Wegweiser."""
        for k, (p, d) in enumerate(BELLS):
            pass
        S.add('glock', sec, bar, 0, 2.0, n('E6'), vel)
        S.add('glock', sec, bar, 2.0, 1.5, n('B6'), vel - 6)
        S.add('glock', sec, bar + 1, 3.0, 2.0, n('G#6'), vel - 3)
        S.add('glock', sec, bar + 2, 1.0, 1.0, n('E6'), vel - 8)
        S.add('glock', sec, bar + 3, 0.0, 3.0, n('F#6'), vel - 5)

    # ---------------------------------------------------------- Intro (2,2 s)
    S.add('wind', 'intro', 0, 0, 4, n('F#3'), 70, bright=0.35)
    S.add('pad', 'intro', 0, 0, 4, n('F#3'), 52, bright=0.3)
    S.add('glass', 'intro', 0, 0.9, 2.0, n('E6'), 54, bright=0.4)

    # ---------------------------------------------------------- A (21 Takte)
    # Wind, Fernklavier, drei Glockentöne; der Groove schleicht sich ein.
    S.add('wind', 'A', 0, 0, 16, n('F#3'), 82, bright=0.4)
    pad(S, 'pad', 'A', 0, repeat_to(H1, 8), vel=48, center=n('F#3'), size=3, bright=0.2)
    for b in (0, 2, 4, 6):
        for p in close(H1[b % 4], n('F#3'), 3):
            S.add('piano', 'A', b, 0, 3.5, p, 48)
    bell_bar('A', 0, 60)
    bell_bar('A', 4, 58)
    phrase(S, 'vibes', 'A', 8, THEME_HEAD, vel=72, human=hum)
    arp(S, 'vibes', 'A', 8, repeat_to(H2, 4), step=1.0, low=n('F#3'), high=n('C#6'), shape='broken',
        vel=54, human=hum)
    arp(S, 'piano', 'A', 8, repeat_to(H2, 4), step=2.0, low=n('F#2'), high=n('F#4'), vel=44, human=hum)
    bassline(S, 'bass', 'A', 8, repeat_to(H2, 4), 'roots', vel=76, bright=0.26)
    for b in range(4):
        S.add('kit', 'A', 8 + b, 0, .3, WOOD, 52)
        S.add('kit', 'A', 8 + b, 2, .3, WOOD, 44)
    S.add('choir', 'A', 8, 0, 16, n('A3'), 62, bright=0.3, aux=0)
    drums(S, 'kit', 'A', 12, 9, 'trip', vel=76, human=hum)
    phrase(S, 'vibes', 'A', 12, THEME_TAIL, vel=74, human=hum)
    arp(S, 'vibes', 'A', 12, repeat_to(H3, 8), step=1.0, low=n('F#3'), high=n('C#6'), shape='broken',
        vel=56, human=hum)
    pad(S, 'pad', 'A', 12, repeat_to(H3, 8), vel=52, center=n('F#3'), size=4, bright=0.26)
    bassline(S, 'bass', 'A', 12, repeat_to(H3, 8), 'half', vel=82, bright=0.3)
    S.add('choir', 'A', 16, 0, 8, n('C#4'), 66, bright=0.36, aux=1)
    S.add('riser', 'A', 19, 0, 8, n('F#2'), 52)
    S.add('kit', 'A', 19, 0, 8, SWELL4, 60)

    # ---------------------------------------------------------- B (23 Takte)
    crash(S, 'kit', 'B', 0, 78)
    S.add('wind', 'B', 0, 0, 16, n('F#3'), 78, bright=0.5)
    S.add('choir', 'B', 0, 0, 16, n('A3'), 78, bright=0.42, aux=0)
    S.add('choir', 'B', 0, 0, 16, n('C#4'), 70, bright=0.34, aux=1)
    phrase(S, 'vibes', 'B', 0, THEME, vel=84, human=hum)
    arp(S, 'vibes', 'B', 0, repeat_to(H1, 8), step=1.0, low=n('F#3'), high=n('C#6'), shape='broken',
        vel=56, human=hum)
    pad(S, 'pad', 'B', 0, repeat_to(H1, 8), vel=54, center=n('F#3'), size=4, bright=0.3)
    bassline(S, 'bass', 'B', 0, repeat_to(H1, 8), 'half', vel=88, bright=0.34)
    drums(S, 'kit', 'B', 0, 8, 'trip', vel=86, human=hum)
    for b in range(8):
        for p in close(H1[b % 4], n('F#3'), 3):
            S.add('piano', 'B', b, 1.5, 2.0, p, 42)
    bell_bar('B', 4, 52)

    crash(S, 'kit', 'B', 8, 74)
    phrase(S, 'glock', 'B', 8, SECOND, vel=74, human=hum, legato=1.2)
    phrase(S, 'vibes', 'B', 8, SECOND, vel=60, transpose=-12, human=hum)
    arp(S, 'vibes', 'B', 8, repeat_to(H2, 8), step=1.0, low=n('F#3'), high=n('C#6'), shape='broken',
        vel=54, human=hum)
    arp(S, 'pluck', 'B', 8, repeat_to(H2, 8), step=0.5, low=n('C#5'), high=n('C#7'), vel=40, human=hum)
    pad(S, 'pad', 'B', 8, repeat_to(H2, 8), vel=52, center=n('F#4'), size=4, bright=0.34)
    bassline(S, 'bass', 'B', 8, repeat_to(H2, 8), 'half', vel=86, bright=0.32)
    drums(S, 'kit', 'B', 8, 8, 'trip', vel=84, human=hum, fill='timp')
    S.add('choir', 'B', 8, 0, 16, n('E4'), 68, bright=0.38, aux=2)

    # Takte 16–22: Sporen steigen – Verdichtung
    crash(S, 'kit', 'B', 16, 86)
    S.add('wind', 'B', 16, 0, 7, n('C#4'), 92, bright=0.7)
    for b in range(7):
        for p in voce(H4[b % 4]):
            S.add('pluck', 'B', 16 + b, float(b % 4) * 0.75, 0.3, p, 58)
        S.add('kit', 'B', 16 + b, 0, .4, TIMP_LO, 84)
        S.add('kit', 'B', 16 + b, 2.5, .3, SHAKE_C, 56)
    phrase(S, 'vibes', 'B', 16, mechanize(THEME_HEAD, 0.5)[:32], vel=80, human=hum)
    pad(S, 'pad', 'B', 16, repeat_to(H4, 7), vel=58, center=n('F#4'), size=4, bright=0.42)
    bassline(S, 'bass', 'B', 16, repeat_to(H4, 7), 'pop', vel=88, bright=0.4)
    S.add('riser', 'B', 20, 0, 12, n('F#2'), 66)
    S.add('kit', 'B', 21, 0, 8, SWELL4, 76)

    # ---------------------------------------------------------- C (22 Takte)
    # Takte 0–10: nur Glocken, Partikel, Wind. Ab Takt 11 (= 148 s) Miniboss.
    S.add('wind', 'C', 0, 0, 16, n('F#3'), 76, bright=0.34)
    pad(S, 'pad', 'C', 0, repeat_to(H5, 11), vel=46, center=n('F#3'), size=3, bright=0.16)
    for b in range(0, 11, 4):
        bell_bar('C', b, 58)
    for b in range(11):
        S.add('glass', 'C', b, 2.75, 1.2, n('E6') if b % 3 else n('B6'), 40)
        S.add('kit', 'C', b, 3.5, .2, WOOD, 40)
    phrase(S, 'vibes', 'C', 0, fragment(leitmotiv('F#', 'dorian'), 0, 12), vel=66, human=hum)
    for b in range(3):
        for p in close(H5[b], n('F#3'), 3):
            S.add('piano', 'C', b * 3, 0, 4.0, p, 40)
    S.add('kit', 'C', 10, 0, 4, TIMP_ROLL_LO, 78)

    # Miniboss (Takte 11–21): Partikel, Poly-Wirbel, Chor schwillt an
    crash(S, 'kit', 'C', 11, 96)
    S.add('kit', 'C', 11, 0, 2, TIMP_LO, 110)
    S.add('choir', 'C', 11, 0, 16, n('A3'), 82, bright=0.5, aux=0)
    for bar, k in grid(11, 4):
        b = 11 + bar
        h = repeat_to(HMINI, k)
        arp(S, 'vibes', 'C', b, h, step=0.5, low=n('F#3'), high=n('C#6'), vel=62, human=hum)
        arp(S, 'pluck', 'C', b, h, step=0.25, low=n('C#5'), high=n('C#7'), vel=44, human=hum)
        pad(S, 'pad', 'C', b, h, vel=58, center=n('F#4'), size=4, bright=0.4)
        bassline(S, 'bass', 'C', b, h, 'drive', vel=90, bright=0.44)
        drums(S, 'kit', 'C', b, k, 'trip', vel=94, human=hum)
        for i in range(k):
            for s in range(6):
                S.add('kit', 'C', b + i, s * 2 / 3, .15, SHAKE_A if s % 2 else SHAKE_B, 62)
    phrase(S, 'vibes', 'C', 11, THEME_INV, vel=86, human=hum)
    phrase(S, 'glock', 'C', 15, PARTICLE, vel=70, human=hum)
    for b in range(3):
        S.add('choir', 'C', 19 + b, 0, 1.2, n('D4') + (0 if b < 2 else 1), 96, bright=0.6, aux=0)
    S.add('riser', 'C', 19, 0, 12, n('F#2'), 80)
    S.add('kit', 'C', 20, 0, 8, SWELL4, 88)

    # ---------------------------------------------------------- D (20 Takte)
    crash(S, 'kit', 'D', 0, 96)
    S.add('choir', 'D', 0, 0, 16, n('A3'), 86, bright=0.48, aux=0)
    S.add('choir', 'D', 0, 0, 16, n('F#4'), 72, bright=0.4, aux=1)
    S.add('wind', 'D', 0, 0, 16, n('A3'), 84, bright=0.5)
    phrase(S, 'vibes', 'D', 0, THEME, vel=88, human=hum)
    phrase(S, 'glock', 'D', 0, THEME, vel=72, transpose=12, human=hum, legato=1.2)
    arp(S, 'vibes', 'D', 0, repeat_to(H3, 8), step=0.5, low=n('F#3'), high=n('C#6'), vel=60, human=hum)
    pad(S, 'pad', 'D', 0, repeat_to(H3, 8), vel=58, center=n('F#4'), size=4, bright=0.42)
    bassline(S, 'bass', 'D', 0, repeat_to(H3, 8), 'pop', vel=94, bright=0.46)
    drums(S, 'kit', 'D', 0, 8, 'trip', vel=92, human=hum, fill='timp')
    for b in range(8):
        for p in close(H3[b % 4], n('F#3'), 4):
            S.add('piano', 'D', b, 0.5, 3.0, p, 52)

    crash(S, 'kit', 'D', 8, 92)
    phrase(S, 'glock', 'D', 8, SECOND, vel=82, human=hum, legato=1.2)
    arp(S, 'pluck', 'D', 8, repeat_to(H2, 8), step=0.25, low=n('C#5'), high=n('C#7'), vel=48, human=hum)
    arp(S, 'vibes', 'D', 8, repeat_to(H2, 8), step=0.5, low=n('F#3'), high=n('C#6'), vel=58, human=hum)
    pad(S, 'pad', 'D', 8, repeat_to(H2, 8), vel=56, center=n('F#4'), size=4, bright=0.46)
    bassline(S, 'bass', 'D', 8, repeat_to(H2, 8), 'pop', vel=92, bright=0.44)
    drums(S, 'kit', 'D', 8, 8, 'trip', vel=90, human=hum, fill='roll')
    S.add('choir', 'D', 8, 0, 16, n('C#4'), 76, bright=0.44, aux=2)

    for b in range(4):
        S.add('kit', 'D', 16 + b, 0, .5, TIMP_LO, 100)
        S.add('kit', 'D', 16 + b, 2, .5, TIMP_LO, 94)
        S.add('kit', 'D', 16 + b, 3.5, .2, SHAKE_C, 66)
    S.add('riser', 'D', 17, 0, 12, n('F#2'), 74)
    S.add('kit', 'D', 17, 0, 16, SWELL4, 86)

    # ---------------------------------------------------------- E (18 Takte)
    # Die Stimme verstummt: zurück bleiben Glocken, Wind und Partikel.
    crash(S, 'kit', 'E', 0, 70)
    S.add('wind', 'E', 0, 0, 16, n('F#3'), 88, bright=0.42)
    for b in range(0, 12, 4):
        bell_bar('E', b, 58)
    pad(S, 'pad', 'E', 0, repeat_to(H5, 12), vel=50, center=n('F#3'), size=3, bright=0.22)
    arp(S, 'pluck', 'E', 0, repeat_to(H5, 12), step=0.75, low=n('C#5'), high=n('C#7'), vel=36, human=hum)
    phrase(S, 'vibes', 'E', 0, fragment(THEME, 8, 12), vel=70, human=hum)
    phrase(S, 'vibes', 'E', 6, fragment(THEME, 20, 12), vel=68, transpose=-12, human=hum)
    bassline(S, 'bass', 'E', 0, repeat_to(H5, 12), 'roots', vel=78, bright=0.26)
    drums(S, 'kit', 'E', 0, 8, 'trip', vel=72, human=hum)
    for b in range(8):
        S.add('glass', 'E', b, 1.5, 1.5, n('B6') if b % 2 else n('E6'), 38)

    # Takte 8–17: Aufwühlen, dann Abriss
    crash(S, 'kit', 'E', 8, 92)
    S.add('wind', 'E', 8, 0, 10, n('C#4'), 100, bright=0.72)
    S.add('choir', 'E', 8, 0, 8, n('A3'), 88, bright=0.55, aux=0)
    phrase(S, 'vibes', 'E', 6, leitmotiv('F#', 'harm'), vel=94, human=hum)
    phrase(S, 'glock', 'E', 14, THEME_HEAD, vel=70, transpose=12, human=hum, legato=1.2)
    arp(S, 'vibes', 'E', 8, repeat_to(H2, 8), step=0.25, low=n('F#3'), high=n('C#6'), vel=62, human=hum)
    pad(S, 'pad', 'E', 8, repeat_to(H2, 8), vel=62, center=n('F#4'), size=4, bright=0.55)
    bassline(S, 'bass', 'E', 8, repeat_to(H2, 8), 'drive', vel=96, bright=0.5)
    drums(S, 'kit', 'E', 8, 8, 'trip', vel=98, human=hum, fill='roll')
    for b in range(8):
        for s in range(6):
            S.add('kit', 'E', 8 + b, s * 2 / 3, .12, SHAKE_A if s % 2 else SHAKE_B, 68)
    S.add('kit', 'E', 12, 0, 12, SNARE_ROLL, 94)
    S.add('riser', 'E', 14, 0, 16, n('F#2'), 90)
    S.add('kit', 'E', 13, 0, 20, SWELL4, 96)

    # ---------------------------------------------------------- Ankündigung (1,25 s): Auftakt
    # Kein Schlussakkord: Wirbel und Basshinführung münden auf dem nächsten Schlag in die
    # Bossmusik (boss4, Grundton F#), die genau dann mit der Ankunft des Bosses einsetzt.
    leadin_spec = lead_in(S, 'F#')

    mixspec = {
        'kit':      {'engine': 'sfz', 'inst': 'kit', 'gain': -1.0, 'rev': 0.3},
        'piano':    {'engine': 'sfz', 'inst': 'piano', 'gain': -6.0, 'pan': -0.25, 'rev': 0.6, 'lp': 5200, 'dly': 0.18},
        'vibes':    {'engine': 'sfz', 'inst': 'vibes', 'gain': -3.5, 'pan': 0.18, 'rev': 0.42, 'dly': 0.2},
        'glock':    {'engine': 'sfz', 'inst': 'glock', 'gain': -8.0, 'pan': 0.3, 'rev': 0.5, 'dly': 0.24},
        'choir':    {'engine': 'cs', 'instr': 'choir', 'gain': -3.5, 'rev': 0.5, 'hp': 130, 'width': 1.35, 'lp': 6000},
        'pad':      {'engine': 'cs', 'instr': 'pad', 'gain': -9.5, 'rev': 0.45, 'hp': 120, 'width': 1.3},
        'bass':     {'engine': 'cs', 'instr': 'bass', 'gain': -2.0, 'lp': 1900},
        'pluck':    {'engine': 'cs', 'instr': 'pluck', 'gain': -9.0, 'pan': 0.28, 'rev': 0.42, 'dly': 0.26},
        'glass':    {'engine': 'cs', 'instr': 'glass', 'gain': -13.0, 'pan': -0.3, 'rev': 0.5, 'dly': 0.24},
        'wind':     {'engine': 'cs', 'instr': 'wind', 'gain': -8.0, 'rev': 0.3},
        'riser':    {'engine': 'cs', 'instr': 'riser', 'gain': -10.0, 'rev': 0.24},
        'boom':     {'engine': 'cs', 'instr': 'boom', 'gain': -6.0, 'rev': 0.16},
    }
    mixspec.update(leadin_spec)
    return song, mixspec, {'file': 'level4', 'title': 'Level 4 – Pilzwald', 'reverb': 3.0}


def voce(ch: str):
    """Spreizung für Partikel-Akkorde: weiter oben, damit es glitzert."""
    return [p + 12 for p in close(ch, n('F#4'), 3)]
