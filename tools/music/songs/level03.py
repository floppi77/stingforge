"""Level 3 – Schilf und Teich: fließend, glitzernd, verspielt mit Sprüngen.

G-Dur mit mixolydischer Färbung (F statt Fis) · 96 BPM im 12/8-Gefühl (Triolen),
Melodie springt in Oktaven (Hechtsprünge). Zwei Welten: „über Wasser" hell und
offen, „unter Wasser" dieselben Instrumente tiefpassgefiltert und hallig.

Form: A 22 · B 25 · C 24 · D 22 · E 18 Takte. Miniboss bei Levelzeit 146 s = Takt 11 von C.
"""
from __future__ import annotations

from score import Song, n
from songs._kit import (lead_in, CRASH, Human, SHAKE_A, SHAKE_B, SHAKE_C, SWELL4, TIMP_ROLL_LO, TRI,
                        WOOD, arp, bassline, close, crash, drums, grid, pad, phrase, repeat_to,
                        voicing)
from songs._themes import fragment, leitmotiv, mechanize, second_theme, transposed

BPM = 96
T = 1 / 3        # Triolenachtel in Schlägen

# ------------------------------------------------------------------ Harmonik
H1 = ['G', 'C', 'G', 'F']              # mixolydisch: großes F als Eigenheit
H2 = ['G', 'Am', 'F', 'C']
H3 = ['Em', 'C', 'D', 'G']
H4 = ['G', 'F', 'C', 'G']
H5 = ['Am', 'F', 'G', 'Em']            # Unterwasser: dumpfer, kreisend
H6 = ['Em', 'Am', 'D', 'G']            # Vorbote Hecht
HMINI = ['C', 'G', 'Am', 'F']

# ------------------------------------------------------------------ Motive
THEME = leitmotiv('G', 'mixo')                      # 8 Takte
THEME_HEAD = leitmotiv('G', 'mixo', part='head')
THEME_TAIL = leitmotiv('G', 'mixo', part='tail')
SECOND = second_theme('G', 'mixo')                  # 8 Takte
SPRUNG = [('G4', 2 * T), ('G5', 2 * T), ('D5', 2 * T), ('B4', 2 * T), ('G5', 4 * T),   # 12/8-Takt
          ('A4', 2 * T), ('A5', 2 * T), ('E5', 2 * T), ('C5', 2 * T), ('A5', 4 * T)]
SPRUNG_ANT = [('D5', 2 * T), ('G5', 2 * T), ('B5', 2 * T), ('D6', 2 * T), ('B5', 4 * T),
              ('C5', 2 * T), ('E5', 2 * T), ('G5', 2 * T), ('C6', 2 * T), ('G5', 4 * T)]
WATER = [(None, 4 * T), ('D6', 1 * T), ('G6', 1 * T), (None, 6 * T)]      # Tropfen
DIVE = [('G4', 1), ('F4', 1), ('Eb4', 1), ('D4', 1), ('C4', 2), ('Bb3', 2)]   # Abtauchen


def build():
    song = Song.for_level(3, BPM)
    hum = Human(303)
    S = song

    def tri_hats(sec, bar0, bars, vel, up=True):
        """Triolenachtel-Teppich: Hi-Hats bzw. Shaker über ganze Takte."""
        for b in range(bars):
            for i in range(12):
                v = vel * (1.0 if i % 6 == 0 else (0.72 if i % 3 == 0 else 0.45))
                S.add('kit', sec, bar0 + b, i * T, T * 0.8,
                      SHAKE_A if (i + b) % 2 == 0 else SHAKE_B, int(v))

    # ---------------------------------------------------------- Intro (2,2 s)
    for i, p in enumerate(voicing('Gmaj7', n('G3'), n('D5'))[:8]):
        S.add('harp', 'intro', 0, i * 0.26, 2.2, p, 54 + i * 2)
    S.add('glass', 'intro', 0, 0, 2.0, n('G6'), 60, bright=0.5)
    S.add('pad', 'intro', 0, 0, 4, n('D3'), 50, bright=0.3)

    # ---------------------------------------------------------- A (22 Takte)
    # Über Wasser: leeres Arpeggio, dann das Thema auf der Rohrflöte.
    arp(S, 'harp', 'A', 0, repeat_to(H1, 8), step=0.5, low=n('G2'), high=n('D5'), vel=54, human=hum)
    pad(S, 'pad', 'A', 0, repeat_to(H1, 8), vel=46, center=n('B4'), size=3, bright=0.22)
    for b in range(8):
        S.add('glass', 'A', b, 2 * T, T, n('G6') if b % 2 == 0 else n('C7'), 42)
    tri_hats('A', 4, 4, 46)
    phrase(S, 'flute', 'A', 4, THEME_HEAD, vel=78, human=hum)
    arp(S, 'marimba', 'A', 4, repeat_to(H2, 4), step=2 * T, low=n('G3'), high=n('D5'), vel=58, human=hum)
    bassline(S, 'bass', 'A', 4, repeat_to(H2, 4), 'roots', vel=70, bright=0.24)
    phrase(S, 'vibes', 'A', 8, THEME_TAIL, vel=70, human=hum)
    arp(S, 'marimba', 'A', 8, repeat_to(H3, 4), step=2 * T, low=n('G3'), high=n('D5'), vel=60, human=hum)
    pad(S, 'pad', 'A', 8, repeat_to(H3, 4), vel=52, center=n('B4'), size=4, bright=0.3)
    bassline(S, 'bass', 'A', 8, repeat_to(H3, 4), 'half', vel=76, bright=0.3)
    tri_hats('A', 8, 4, 54)
    phrase(S, 'flute', 'A', 12, SPRUNG + SPRUNG_ANT, vel=82, human=hum)
    arp(S, 'marimba', 'A', 12, repeat_to(H1, 6), step=2 * T, low=n('G3'), high=n('D6'), vel=62, human=hum)
    pad(S, 'pad', 'A', 12, repeat_to(H1, 6), vel=54, center=n('B4'), size=4, bright=0.34)
    bassline(S, 'bass', 'A', 12, repeat_to(H1, 6), 'half', vel=80, bright=0.32)
    bassline(S, 'vcpizz', 'A', 12, repeat_to(H1, 6), 'roots', vel=64)
    drums(S, 'kit', 'A', 12, 6, 'light', vel=58, human=hum)
    tri_hats('A', 12, 6, 52)
    for b in range(8):
        S.add('glass', 'A', 16 + b, 3 * T, T, n('C7') if b % 3 else n('E7'), 44)
    for b in range(18, 22):                             # Takte 18–21: Übergang
        S.add('marimba', 'A', b, 0, .5, n('G3'), 62)
        S.add('marimba', 'A', b, 1, .5, n('D4'), 58)
        S.add('vibes', 'A', b, 2, .5, n('G5') if b % 2 else n('B5'), 54)
        S.add('kit', 'A', b, 0, .4, 41, 78)
        S.add('glass', 'A', b, 2 * T, T, n('G6'), 42)
    phrase(S, 'flute', 'A', 18, fragment(THEME, 8, 12), vel=74, human=hum)
    pad(S, 'pad', 'A', 18, repeat_to(H1, 4), vel=56, center=n('B4'), size=4, bright=0.4)
    bassline(S, 'bass', 'A', 18, repeat_to(H1, 4), 'half', vel=84, bright=0.36)
    tri_hats('A', 18, 4, 54)
    S.add('riser', 'A', 20, 0, 8, n('G2'), 54)
    S.add('kit', 'A', 20, 0, 8, SWELL4, 62)

    # ---------------------------------------------------------- B (25 Takte)
    # Volles Wasser: Bass und Triolen-Groove, dann Abtauchen.
    crash(S, 'kit', 'B', 0, 84)
    phrase(S, 'flute', 'B', 0, THEME, vel=88, human=hum)
    arp(S, 'marimba', 'B', 0, repeat_to(H1, 8), step=T, low=n('G3'), high=n('D6'), vel=58, human=hum)
    pad(S, 'pad', 'B', 0, repeat_to(H1, 8), vel=56, center=n('B4'), size=4, bright=0.36)
    bassline(S, 'bass', 'B', 0, repeat_to(H1, 8), 'pop', vel=90, bright=0.42)
    drums(S, 'kit', 'B', 0, 8, 'full', vel=82, human=hum, fill='snare')
    tri_hats('B', 0, 8, 60)

    crash(S, 'kit', 'B', 8, 80)
    phrase(S, 'vibes', 'B', 8, SECOND, vel=80, human=hum)
    phrase(S, 'flute', 'B', 8, SECOND, vel=64, transpose=12, human=hum, legato=0.9)
    arp(S, 'marimba', 'B', 8, repeat_to(H2, 8), step=2 * T, low=n('G3'), high=n('D5'), vel=60, human=hum)
    pad(S, 'pad', 'B', 8, repeat_to(H2, 8), vel=54, center=n('B4'), size=4, bright=0.3)
    bassline(S, 'bass', 'B', 8, repeat_to(H2, 8), 'pop', vel=86, bright=0.38)
    drums(S, 'kit', 'B', 8, 8, 'light', vel=76, human=hum, fill='timp')
    tri_hats('B', 8, 8, 52)

    # Takte 16–24: unter Wasser – dasselbe Material, dumpf und hallig
    crash(S, 'kit', 'B', 16, 64)
    phrase(S, 'vibes_uw', 'B', 16, SECOND, vel=76, human=hum)
    phrase(S, 'flute', 'B', 16, fragment(THEME, 8, 12), vel=66, transpose=-12, human=hum)
    arp(S, 'marimba_uw', 'B', 16, repeat_to(H5, 9), step=T, low=n('G3'), high=n('D5'), vel=54, human=hum)
    pad(S, 'pad', 'B', 16, repeat_to(H5, 9), vel=58, center=n('G3'), size=3, bright=0.16)
    bassline(S, 'bass', 'B', 16, repeat_to(H5, 9), 'half', vel=82, bright=0.3)
    for b in range(9):
        S.add('kit', 'B', 16 + b, 0, .8, 41 if b % 2 == 0 else 43, 74)   # dumpfe Pauke als Puls
        S.add('glass', 'B', 16 + b, 6 * T, T, n('C6'), 40)
    S.add('riser', 'B', 23, 0, 8, n('F2'), 58)
    S.add('kit', 'B', 23, 0, 8, SWELL4, 70)

    # ---------------------------------------------------------- C (24 Takte)
    # Takte 0–10: unter Wasser. Ab Takt 11 (= 146 s Levelzeit) Miniboss (Hecht).
    crash(S, 'kit', 'C', 0, 58)
    arp(S, 'marimba_uw', 'C', 0, repeat_to(H5, 11), step=T, low=n('G3'), high=n('D5'), vel=50, human=hum)
    pad(S, 'pad', 'C', 0, repeat_to(H5, 11), vel=52, center=n('G3'), size=3, bright=0.14)
    for k in range(3):
        phrase(S, 'vibes_uw', 'C', k * 2, WATER, vel=62, human=hum)
        phrase(S, 'flute', 'C', (k * 2) + 1, WATER, vel=54, transpose=12, human=hum)
    bassline(S, 'bass', 'C', 0, repeat_to(H5, 11), 'roots', vel=66, bright=0.2)
    for b in range(11):
        if b % 2 == 0:
            S.add('kit', 'C', b, 0, 1.0, 41, 66)
        S.add('glass', 'C', b, 9 * T, T, n('G6'), 34)
    S.add('kit', 'C', 10, 0, 4, TIMP_ROLL_LO, 80)

    # Miniboss (Takte 11–23): Hecht – Pizzicato, Staccato, Sprünge
    crash(S, 'kit', 'C', 11, 100)
    S.add('kit', 'C', 11, 0, 1.5, 41, 112)
    for bar, k in grid(13, 4):
        b = 11 + bar
        h = repeat_to(HMINI, k)
        arp(S, 'marimba', 'C', b, h, step=T, low=n('G3'), high=n('D6'), vel=64, human=hum)
        arp(S, 'harp', 'C', b, h, step=2 * T, low=n('G2'), high=n('G4'), vel=58, human=hum)
        pad(S, 'pad', 'C', b, h, vel=58, center=n('B4'), size=4, bright=0.4)
        bassline(S, 'bass', 'C', b, h, 'drive', vel=92, bright=0.48)
        bassline(S, 'vcpizz', 'C', b, h, 'drive', vel=86)
        for i, ch in enumerate(h):
            for s in range(6):
                tones = voicing(ch, n('G3'), n('D5'))
                S.add('vcpizz', 'C', b + i, s * 2 * T, T * 1.4, tones[s % len(tones)],
                      88 if s % 2 == 0 else 70)
        drums(S, 'kit', 'C', b, k, 'full', vel=92, human=hum)
        tri_hats('C', b, k, 62)
    phrase(S, 'flute', 'C', 11, SPRUNG + SPRUNG_ANT + SPRUNG, vel=90, human=hum)
    phrase(S, 'vibes', 'C', 15, leitmotiv('G', 'mixo', part='tail') + THEME_HEAD, vel=78, human=hum)
    drums(S, 'kit', 'C', 20, 3, 'full', vel=98, human=hum, fill='roll')
    S.add('riser', 'C', 21, 0, 8, n('G2'), 74)
    S.add('kit', 'C', 22, 0, 8, SWELL4, 84)

    # ---------------------------------------------------------- D (22 Takte)
    # Auftauchen: breite Reprise über Wasser.
    crash(S, 'kit', 'D', 0, 108)
    phrase(S, 'flute', 'D', 0, THEME, vel=92, human=hum)
    phrase(S, 'vibes', 'D', 0, THEME, vel=76, transpose=12, human=hum)
    arp(S, 'marimba', 'D', 0, repeat_to(H3, 8), step=T, low=n('G3'), high=n('D6'), vel=62, human=hum)
    pad(S, 'pad', 'D', 0, repeat_to(H3, 8), vel=58, center=n('B4'), size=4, bright=0.42)
    bassline(S, 'bass', 'D', 0, repeat_to(H3, 8), 'pop', vel=94, bright=0.46)
    bassline(S, 'vcpizz', 'D', 0, repeat_to(H3, 8), 'roots', vel=84)
    drums(S, 'kit', 'D', 0, 8, 'full', vel=90, human=hum, fill='timp')
    tri_hats('D', 0, 8, 64)

    crash(S, 'kit', 'D', 8, 96)
    phrase(S, 'flute', 'D', 8, SECOND, vel=88, human=hum)
    phrase(S, 'glock', 'D', 8, [('G6', 1 * T), (None, 2 * T)] + [(None, 3), ('D6', 1), ('G6', 2)], vel=66,
           human=hum, legato=1.4)
    arp(S, 'marimba', 'D', 8, repeat_to(H2, 8), step=T, low=n('G3'), high=n('D6'), vel=60, human=hum)
    arp(S, 'harp', 'D', 8, repeat_to(H2, 8), step=0.5, low=n('G2'), high=n('G4'), vel=50, human=hum)
    pad(S, 'pad', 'D', 8, repeat_to(H2, 8), vel=56, center=n('B4'), size=4, bright=0.4)
    bassline(S, 'bass', 'D', 8, repeat_to(H2, 8), 'pop', vel=92, bright=0.44)
    drums(S, 'kit', 'D', 8, 8, 'full', vel=88, human=hum, fill='snare')
    tri_hats('D', 8, 8, 62)
    for b in range(6):
        S.add('glass', 'D', 16 + b, 2 * T, T, n('C7') if b % 2 else n('G7'), 40)

    # Takte 16–21: Rückung nach Dur und Sprung in den Abgrund
    crash(S, 'kit', 'D', 16, 92)
    phrase(S, 'vibes', 'D', 16, SPRUNG + SPRUNG_ANT, vel=84, human=hum)
    arp(S, 'marimba', 'D', 16, repeat_to(H4, 6), step=T, low=n('G3'), high=n('D6'), vel=62, human=hum)
    pad(S, 'pad', 'D', 16, repeat_to(H4, 6), vel=60, center=n('B4'), size=4, bright=0.5)
    bassline(S, 'bass', 'D', 16, repeat_to(H4, 6), 'drive', vel=92, bright=0.5)
    drums(S, 'kit', 'D', 16, 6, 'full', vel=94, human=hum, fill='roll')
    tri_hats('D', 16, 6, 66)
    S.add('riser', 'D', 20, 0, 8, n('G2'), 66)

    # ---------------------------------------------------------- E (18 Takte)
    # Der Bass springt in Oktaven: Vorbote des Hechts.
    crash(S, 'kit', 'E', 0, 86)
    e_h = repeat_to(H6, 18)
    pad(S, 'pad', 'E', 0, e_h, vel=54, center=n('G3'), size=3, bright=0.28)
    arp(S, 'marimba_uw', 'E', 0, e_h, step=T, low=n('G3'), high=n('D5'), vel=52, human=hum)
    for b in range(16):
        root = voicing(H6[b % 4], n('G2'), n('G3'))[0]
        S.add('bass', 'E', b, 0, 1.2, root, 92)
        S.add('bass', 'E', b, 2, 1.2, root + 12, 82)
        S.add('vcpizz', 'E', b, 1, .5, root + 12, 74)
        S.add('vcpizz', 'E', b, 3, .5, root, 78)
    phrase(S, 'flute', 'E', 0, fragment(THEME, 0, 12), vel=72, human=hum)
    phrase(S, 'vibes', 'E', 6, fragment(THEME, 12, 12), vel=70, transpose=-12, human=hum)
    for b in range(10):
        S.add('glass', 'E', b, 7 * T, T, n('G6') if b % 2 else n('C6'), 38)
    drums(S, 'kit', 'E', 0, 8, 'half', vel=80, human=hum)
    tri_hats('E', 0, 8, 50)

    # Takte 8–17: Wasser läuft ab, Riser, Abriss
    crash(S, 'kit', 'E', 8, 92)
    for b in range(8):
        root = voicing(H6[b % 4], n('G2'), n('G3'))[0]
        S.add('bass', 'E', 8 + b, 0, .6, root, 96)
        S.add('bass', 'E', 8 + b, float(1 + b % 2), .6, root + 12, 88)
        S.add('bass', 'E', 8 + b, 2 + (b % 2) * 0.5, .6, root, 94)
        S.add('bass', 'E', 8 + b, 3, .6, root + 12, 90)
        S.add('kit', 'E', 8 + b, 0, .4, 41, 92 + b * 2)
    phrase(S, 'vibes', 'E', 8, SPRUNG, vel=86, human=hum, transpose=-12)
    pad(S, 'pad', 'E', 8, repeat_to(H6, 8), vel=62, center=n('G4'), size=4, bright=0.45)
    drums(S, 'kit', 'E', 8, 8, 'full', vel=96, human=hum, fill='roll')
    tri_hats('E', 8, 8, 56)
    for b in range(6):
        S.add('glass', 'E', 12 + b, 4 * T, T, n('C7'), 42)
    S.add('riser', 'E', 15, 0, 12, n('G2'), 88)
    S.add('kit', 'E', 14, 0, 16, SWELL4, 92)

    # ---------------------------------------------------------- Ankündigung (1,25 s): Auftakt
    # Kein Schlussakkord: Wirbel und Basshinführung münden auf dem nächsten Schlag in die
    # Bossmusik (boss3, Grundton G), die genau dann mit der Ankunft des Bosses einsetzt.
    leadin_spec = lead_in(S, 'G')

    mixspec = {
        'kit':        {'engine': 'sfz', 'inst': 'kit', 'gain': -1.5, 'rev': 0.2},
        'harp':       {'engine': 'sfz', 'inst': 'harp', 'gain': -8.0, 'pan': -0.3, 'rev': 0.32, 'dly': 0.1},
        'marimba':    {'engine': 'sfz', 'inst': 'marimba', 'gain': -6.0, 'pan': 0.22, 'rev': 0.28, 'dly': 0.12},
        'marimba_uw': {'engine': 'sfz', 'inst': 'marimba', 'gain': -4.0, 'pan': 0.1, 'rev': 0.55, 'lp': 780},
        'vibes':      {'engine': 'sfz', 'inst': 'vibes', 'gain': -7.0, 'pan': -0.2, 'rev': 0.34, 'dly': 0.14},
        'vibes_uw':   {'engine': 'sfz', 'inst': 'vibes', 'gain': -5.5, 'pan': -0.1, 'rev': 0.5, 'lp': 700},
        'flute':      {'engine': 'sfz', 'inst': 'flute', 'gain': -2.0, 'pan': 0.12, 'rev': 0.3, 'dly': 0.12},
        'glock':      {'engine': 'sfz', 'inst': 'glock', 'gain': -10.0, 'pan': 0.35, 'rev': 0.4, 'dly': 0.2},
        'vcpizz':     {'engine': 'sfz', 'inst': 'vc_pizz', 'gain': -5.0, 'pan': -0.2, 'rev': 0.24},
        'pad':        {'engine': 'cs', 'instr': 'pad', 'gain': -9.0, 'rev': 0.36, 'hp': 130, 'width': 1.2},
        'bass':       {'engine': 'cs', 'instr': 'bass', 'gain': -2.5, 'lp': 2300},
        'glass':      {'engine': 'cs', 'instr': 'glass', 'gain': -12.0, 'pan': 0.25, 'rev': 0.4, 'dly': 0.2},
        'riser':      {'engine': 'cs', 'instr': 'riser', 'gain': -11.0, 'rev': 0.2},
    }
    mixspec.update(leadin_spec)
    return song, mixspec, {'file': 'level3', 'title': 'Level 3 – Schilf und Teich', 'reverb': 2.8}
