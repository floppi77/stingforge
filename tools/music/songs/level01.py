"""Level 1 – Blütenmeer: sonnig, leicht, Aufbruch.

D-Dur mit lydischer Färbung (Gis) · 120 BPM · Abschnitte A–E = Checkpoints.
Leitmotiv (Stingforge-Thema) wird hier vorgestellt; Miniboss (Blütengeschütz)
bei Takt 17 von C mit Pizzicato-Marsch in h-Moll, danach Rückung nach E-Dur,
zum Schluss Eintrübung nach e-Moll und ein C-Orgelpunkt, der in die
Bossmusik (f-Moll) führt.
"""
from __future__ import annotations

from score import Song, n
from songs._kit import (lead_in, CHIMES_UP, CRASH, Human, SNARE_ROLL, SWELL4, TIMP_LO, TIMP_ROLL_LO, arp, bar_slots,
                        bassline, close, crash, diatonic, drums, pad, phrase, transpose_name, voicing)

BPM = 120

# --------------------------------------------------------------- Motive
THEME_1 = [('D5', 1), ('F#5', .5), ('A5', .5), ('B5', 1.5), ('A5', .5),
           ('G5', 1), ('F#5', 1), ('E5', 2),
           ('F#5', .5), ('A5', .5), ('D6', 1), ('C#6', .5), ('B5', .5), ('A5', 1),
           ('G#5', .5), ('A5', .5), ('B5', 1), ('A5', 2)]
THEME_2 = [('D5', 1), ('F#5', .5), ('A5', .5), ('B5', 1.5), ('D6', .5),
           ('C#6', 1), ('B5', 1), ('A5', 2),
           ('B5', .5), ('A5', .5), ('G5', .5), ('F#5', .5), ('E5', 1), ('F#5', .5), ('G5', .5),
           ('F#5', .5), ('E5', .5), ('D5', 3)]
THEME_H = ['D', 'Gmaj7', 'Bm7', 'E', 'D', 'A', 'G|A7', 'D']

B_PHRASE = [('B5', 1.5), ('A5', .5), ('G5', 1), ('E5', 1),
            ('E5', .5), ('F#5', .5), ('G5', 1), ('A5', 2),
            ('C#6', 1.5), ('B5', .5), ('A5', 1), ('F#5', 1),
            ('D6', 1), ('C#6', .5), ('B5', .5), ('F#5', 2),
            ('G5', 1.5), ('A5', .5), ('B5', 1), ('D6', 1),
            ('C#6', 2), ('E6', 1), ('C#6', 1),
            ('D6', 1), ('B5', 1), ('C#6', 1), ('A5', 1),
            ('D6', 4)]
B_H = ['Em7', 'A7sus', 'F#m7', 'Bm7', 'Gmaj7', 'A', 'Bm7|A', 'D']
# Gegenstimme fürs Glockenspiel: kurze Antworten in den Pausen der Melodie
B_GLOCK = [(None, 2), ('E6', .5), ('G6', .5), ('B6', 1), (None, 2), ('A6', .5), ('E6', .5), ('D6', 1),
           (None, 2), ('F#6', .5), ('A6', .5), ('C#7', 1), (None, 2), ('B6', .5), ('F#6', .5), ('D6', 1),
           (None, 2), ('D6', .5), ('F#6', .5), ('B6', 1), (None, 3), ('A6', 1),
           (None, 2), ('A6', .5), ('F#6', .5), ('E6', 1), ('F#6', .5), ('A6', .5), ('D7', 3)]

BRIDGE = [('F#5', 1), ('B5', 1), ('A5', .5), ('F#5', .5), ('D5', 1),
          ('G5', 1.5), ('F#5', .5), ('E5', 1), ('D5', 1),
          ('F#5', 2), ('A5', 1), ('D6', 1),
          ('C#6', 1.5), ('B5', .5), ('A5', 2),
          ('B5', 1), ('D6', 1), ('C#6', .5), ('B5', .5), ('F#5', 1),
          ('G5', 1), ('B5', 1), ('D6', 1), ('B5', 1),
          ('E6', 1.5), ('D6', .5), ('B5', 1), ('G5', 1),
          ('A#5', 2), ('C#6', 2)]
BRIDGE_H = ['Bm', 'G', 'D', 'A', 'Bm', 'G', 'Em', 'F#']

# Leitmotiv in h-Moll (Miniboss) und e-Moll (Eintrübung)
THEME_MIN = [('B4', 1), ('D5', .5), ('F#5', .5), ('G5', 1.5), ('F#5', .5),
             ('E5', 1), ('D5', 1), ('C#5', 2),
             ('D5', .5), ('F#5', .5), ('B5', 1), ('A#5', .5), ('G5', .5), ('F#5', 1),
             ('E5', .5), ('F#5', .5), ('G5', 1), ('F#5', 2)]
MIN_H = ['Bm', 'Em', 'G', 'F#7b9']

CALL = [('A5', 1), ('F#5', .5), ('E5', .5), ('D5', 2), (None, 4)]
ANSWER = [(None, 4), ('B6', .5), ('A6', .5), ('F#6', 1), ('E6', 2)]


def build():
    song = Song.for_level(1, BPM)
    hum = Human(101)
    S = song

    # ---------------------------------------------------------- Intro (2,2 s)
    for i, p in enumerate(voicing('Dmaj7', n('D3'), n('A6'))[:16]):
        S.add('harp', 'intro', 0, i * 0.24, 2.5, p, 58 + i * 2)
    pad(S, 'pad', 'intro', 0, ['Dmaj7'], vel=55, bright=0.25)
    S.add('fx', 'intro', 0, 0, 4, CHIMES_UP, 70)

    # ---------------------------------------------------------- A (28 Takte)
    a_open = ['D', 'Gmaj7', 'Bm7', 'Asus4|A']
    arp(S, 'harp', 'A', 0, a_open * 2, step=0.5, low=n('D3'), high=n('D6'), vel=66, human=hum)
    arp(S, 'kalimba', 'A', 4, a_open, step=1.0, low=n('A4'), high=n('A5'), shape='broken', vel=58, human=hum)
    pad(S, 'pad', 'A', 2, a_open[2:] + a_open, vel=52, bright=0.2)
    drums(S, 'kit', 'A', 4, 4, 'shaker', vel=70, human=hum)
    bassline(S, 'bass', 'A', 4, a_open, 'roots', vel=70, bright=0.25)

    phrase(S, 'flute', 'A', 8, THEME_1 + THEME_2, vel=84, human=hum)
    arp(S, 'harp', 'A', 8, THEME_H * 2, step=0.5, low=n('D3'), high=n('D5'), vel=60, human=hum)
    pad(S, 'pad', 'A', 8, THEME_H * 2, vel=54, bright=0.3)
    bassline(S, 'bass', 'A', 8, THEME_H * 2, 'half', vel=82, bright=0.3)
    drums(S, 'kit', 'A', 8, 8, 'light', vel=78, human=hum)

    phrase(S, 'flute', 'A', 16, B_PHRASE, vel=80, human=hum)
    phrase(S, 'glock', 'A', 16, B_GLOCK, vel=70, human=hum, legato=1.4)
    arp(S, 'harp', 'A', 16, B_H, step=0.5, low=n('E3'), high=n('E5'), vel=60, human=hum)
    pad(S, 'pad', 'A', 16, B_H, vel=56, bright=0.35)
    bassline(S, 'bass', 'A', 16, B_H, 'half', vel=84, bright=0.3)
    drums(S, 'kit', 'A', 16, 8, 'light', vel=82, human=hum)

    build_h = ['G', 'A', 'Bm7', 'Asus4|A']
    arp(S, 'harp', 'A', 24, build_h, step=0.25, low=n('D3'), high=n('D6'), vel=58, human=hum, ring=2)
    pad(S, 'pad', 'A', 24, build_h, vel=62, bright=0.5)
    bassline(S, 'bass', 'A', 24, build_h, 'drive', vel=80, bright=0.35)
    drums(S, 'kit', 'A', 24, 4, 'light', vel=86, human=hum, fill='snare')
    S.add('riser', 'A', 26, 0, 8, n('D3'), 70)
    S.add('fx', 'A', 26, 0, 8, SWELL4, 80)

    # ---------------------------------------------------------- B (31 Takte)
    crash(S, 'kit', 'B', 0)
    phrase(S, 'lead', 'B', 0, THEME_1 + THEME_2, vel=96, human=hum, bright=0.55)
    phrase(S, 'flute', 'B', 0, THEME_1 + THEME_2, vel=74, transpose=12, human=hum)
    arp(S, 'harp', 'B', 0, THEME_H * 2, step=0.25, low=n('D4'), high=n('D6'), vel=54, human=hum, ring=2)
    pad(S, 'pad', 'B', 0, THEME_H * 2, vel=60, bright=0.45)
    bassline(S, 'bass', 'B', 0, THEME_H * 2, 'pop', vel=96, human=hum, bright=0.5)
    drums(S, 'kit', 'B', 0, 8, 'full', vel=96, human=hum, fill='snare')

    crash(S, 'kit', 'B', 8, 90)
    phrase(S, 'flute', 'B', 8, B_PHRASE, vel=86, human=hum)
    phrase(S, 'glock', 'B', 8, B_GLOCK, vel=78, human=hum, legato=1.4)
    pad(S, 'strings', 'B', 8, B_H, vel=70, center=n('A4'))
    pad(S, 'pad', 'B', 8, B_H, vel=56, bright=0.4)
    arp(S, 'harp', 'B', 8, B_H, step=0.25, low=n('E4'), high=n('E6'), vel=50, human=hum, ring=2)
    bassline(S, 'bass', 'B', 8, B_H, 'pop', vel=94, human=hum, bright=0.5)
    drums(S, 'kit', 'B', 8, 8, 'full', vel=94, human=hum, fill='timp')

    # Brücke in h-Moll: Kalimba-Ostinato, halbes Tempo-Gefühl
    phrase(S, 'flute', 'B', 16, BRIDGE, vel=84, human=hum)
    arp(S, 'kalimba', 'B', 16, BRIDGE_H, step=0.5, low=n('B3'), high=n('F#5'), shape='broken', vel=70, human=hum)
    pad(S, 'pad', 'B', 16, BRIDGE_H, vel=58, bright=0.3)
    bassline(S, 'bass', 'B', 16, BRIDGE_H, 'half', vel=86, bright=0.3)
    drums(S, 'kit', 'B', 16, 8, 'half', vel=86, human=hum)

    reprise_h = THEME_H[:4] + ['G', 'A', 'Asus4|A']
    phrase(S, 'lead', 'B', 24, THEME_1, vel=96, human=hum, bright=0.6)
    phrase(S, 'flute', 'B', 24, THEME_1, vel=70, transpose=12, human=hum)
    arp(S, 'harp', 'B', 24, reprise_h, step=0.25, low=n('D4'), high=n('D6'), vel=54, human=hum, ring=2)
    pad(S, 'pad', 'B', 24, reprise_h, vel=60, bright=0.5)
    bassline(S, 'bass', 'B', 24, reprise_h, 'pop', vel=96, human=hum, bright=0.5)
    drums(S, 'kit', 'B', 24, 7, 'full', vel=98, human=hum, fill='timp')
    S.add('riser', 'B', 29, 0, 8, n('A2'), 60)

    # ---------------------------------------------------------- C (30 Takte)
    # Takte 0–15: Atempause. Ab Takt 16 (= 150 s Levelzeit) Blütengeschütz.
    calm = ['Gmaj7', 'A', 'F#m7', 'Bm7']
    crash(S, 'kit', 'C', 0, 70)
    arp(S, 'harp', 'C', 0, calm * 4, step=0.5, low=n('D3'), high=n('B4'), vel=58, human=hum)
    pad(S, 'pad', 'C', 0, calm * 4, vel=56, bright=0.22)
    for k in range(4):
        phrase(S, 'flute', 'C', k * 4, CALL, vel=78, human=hum)
        phrase(S, 'glock', 'C', k * 4, ANSWER, vel=66, human=hum, legato=1.5)
    arp(S, 'kalimba', 'C', 8, calm * 2, step=1.0, low=n('F#4'), high=n('D5'), shape='broken', vel=56, human=hum)
    bassline(S, 'bass', 'C', 8, calm * 2, 'roots', vel=76, bright=0.2)
    drums(S, 'kit', 'C', 8, 8, 'shaker', vel=64, human=hum)
    S.add('kit', 'C', 15, 0, 4, TIMP_ROLL_LO, 90)

    mini = MIN_H * 3 + ['F#7b9', 'F#7b9']
    crash(S, 'kit', 'C', 16, 110)
    S.add('kit', 'C', 16, 0, 2, TIMP_LO, 120)
    for b, slots in enumerate(bar_slots(mini)):
        for start, dur, ch in slots:
            tones = voicing(ch, n('B3'), n('F#5'))
            seq = [tones[0], tones[2 % len(tones)], tones[1], tones[3 % len(tones)]] * 2
            for s in range(8):
                S.add('pizz', 'C', 16 + b, s * 0.5, 0.4, seq[s], hum.v(88 if s % 2 == 0 else 70))
            bn = voicing(ch, n('B1'), n('A#2'))[0]
            for q in range(4):
                S.add('cbpizz', 'C', 16 + b, q, 0.6, bn if q % 2 == 0 else bn + 12, hum.v(96 if q == 0 else 80))
            for p in close(ch, n('F#4'), 3):
                S.add('horn', 'C', 16 + b, 0, 0.9, p, 92)
                S.add('horn', 'C', 16 + b, 2.5, 0.45, p, 78)
    phrase(S, 'lead', 'C', 16, THEME_MIN + THEME_MIN, vel=96, human=hum, bright=0.75)
    phrase(S, 'flute', 'C', 20, THEME_MIN, vel=80, transpose=12, human=hum)
    drums(S, 'kit', 'C', 16, 12, 'march', vel=100, human=hum)
    drums(S, 'kit', 'C', 28, 2, 'march', vel=104, human=hum, fill='roll')
    S.add('riser', 'C', 28, 0, 8, n('F#2'), 80)
    S.add('fx', 'C', 28, 0, 8, SWELL4, 90)

    # ---------------------------------------------------------- D (27 Takte) – Rückung nach E-Dur
    up = 2
    TH_E = [transpose_name(c, up) for c in THEME_H]
    B_E = [transpose_name(c, up) for c in B_H]
    crash(S, 'kit', 'D', 0, 115)
    S.add('boom', 'D', 0, 0, 4, n('E1'), 80)
    phrase(S, 'flute', 'D', 0, THEME_1 + THEME_2, vel=92, transpose=up, human=hum)
    phrase(S, 'violins', 'D', 0, THEME_1 + THEME_2, vel=82, transpose=up - 12, human=hum, legato=1.0)
    pad(S, 'strings', 'D', 0, TH_E * 2, vel=74, center=n('B3'))
    pad(S, 'pad', 'D', 0, TH_E * 2, vel=60, bright=0.55)
    arp(S, 'harp', 'D', 0, TH_E * 2, step=0.25, low=n('E4'), high=n('E6'), vel=52, human=hum, ring=2)
    bassline(S, 'bass', 'D', 0, TH_E * 2, 'pop', vel=98, human=hum, bright=0.55)
    drums(S, 'kit', 'D', 0, 8, 'full', vel=100, human=hum, fill='snare')

    crash(S, 'kit', 'D', 8, 100)
    phrase(S, 'lead', 'D', 8, THEME_1 + THEME_2, vel=98, transpose=up, human=hum, bright=0.65)
    # Terz darunter (diatonisch in E-Dur): Terzenklang zur Leadstimme
    phrase(S, 'flute', 'D', 8, diatonic(THEME_1 + THEME_2, 'E', up, -2), vel=74, human=hum)
    phrase(S, 'glock', 'D', 8, B_GLOCK, vel=72, transpose=up, human=hum, legato=1.4)
    pad(S, 'horns', 'D', 8, TH_E * 2, vel=72, center=n('G#3'), size=3)
    pad(S, 'pad', 'D', 8, TH_E * 2, vel=60, bright=0.6)
    arp(S, 'harp', 'D', 8, TH_E * 2, step=0.25, low=n('E4'), high=n('E6'), vel=52, human=hum, ring=2)
    bassline(S, 'bass', 'D', 8, TH_E * 2, 'pop', vel=98, human=hum, bright=0.55)
    drums(S, 'kit', 'D', 8, 8, 'full', vel=100, human=hum, fill='timp')

    crash(S, 'kit', 'D', 16, 96)
    phrase(S, 'flute', 'D', 16, B_PHRASE, vel=88, transpose=up, human=hum)
    phrase(S, 'glock', 'D', 16, B_GLOCK, vel=76, transpose=up, human=hum, legato=1.4)
    pad(S, 'strings', 'D', 16, B_E, vel=76, center=n('B4'))
    pad(S, 'pad', 'D', 16, B_E, vel=58, bright=0.5)
    arp(S, 'harp', 'D', 16, B_E, step=0.25, low=n('F#4'), high=n('F#6'), vel=50, human=hum, ring=2)
    bassline(S, 'bass', 'D', 16, B_E, 'pop', vel=96, human=hum, bright=0.5)
    drums(S, 'kit', 'D', 16, 8, 'full', vel=98, human=hum)

    turn = ['C#m', 'A', 'Bsus4|B']
    pad(S, 'strings', 'D', 24, turn, vel=80, center=n('B4'))
    pad(S, 'pad', 'D', 24, turn, vel=62, bright=0.6)
    arp(S, 'harp', 'D', 24, turn, step=0.25, low=n('E4'), high=n('E6'), vel=56, human=hum, ring=2)
    bassline(S, 'bass', 'D', 24, turn, 'drive', vel=92, bright=0.5)
    drums(S, 'kit', 'D', 24, 3, 'full', vel=100, human=hum, fill='roll')
    S.add('riser', 'D', 25, 0, 8, n('B2'), 70)

    # ---------------------------------------------------------- E (24 Takte) – Eintrübung
    TM_E = [(p, d) for p, d in THEME_MIN]
    e_h = ['Em', 'Am', 'C', 'B7'] * 2
    crash(S, 'kit', 'E', 0, 90)
    phrase(S, 'clarinet', 'E', 0, TM_E + TM_E, vel=88, transpose=5 - 12, human=hum)
    arp(S, 'harp', 'E', 0, e_h, step=0.5, low=n('E3'), high=n('E5'), vel=60, human=hum)
    pad(S, 'pad', 'E', 0, e_h, vel=58, bright=0.2)
    bassline(S, 'cbpizz', 'E', 0, e_h, 'half', vel=92)
    drums(S, 'kit', 'E', 0, 8, 'half', vel=90, human=hum)

    e2 = ['Cmaj7', 'Am7', 'Em', 'B7'] * 2
    phrase(S, 'horn', 'E', 8, [('E4', 2), ('G4', 1), ('B4', 1), ('A4', 3), ('E4', 1),
                               ('G4', 2), ('F#4', 1), ('E4', 1), ('D#4', 4)] * 2, vel=86, human=hum)
    phrase(S, 'flute', 'E', 12, THEME_1[:9], vel=70, transpose=-10, human=hum)
    pad(S, 'strings', 'E', 8, e2, vel=72, center=n('G4'))
    pad(S, 'pad', 'E', 8, e2, vel=56, bright=0.25)
    arp(S, 'harp', 'E', 8, e2, step=0.5, low=n('E3'), high=n('G5'), vel=58, human=hum)
    bassline(S, 'bass', 'E', 8, e2, 'half', vel=90, bright=0.3)
    drums(S, 'kit', 'E', 8, 8, 'half', vel=94, human=hum, fill='timp')

    e3 = ['Em', 'C', 'D', 'B7']
    phrase(S, 'lead', 'E', 16, THEME_MIN, vel=94, transpose=5, human=hum, bright=0.7)
    pad(S, 'strings', 'E', 16, e3, vel=80, center=n('B4'))
    pad(S, 'pad', 'E', 16, e3, vel=60, bright=0.35)
    bassline(S, 'bass', 'E', 16, e3, 'drive', vel=94, bright=0.45)
    drums(S, 'kit', 'E', 16, 4, 'full', vel=98, human=hum, fill='snare')

    # Orgelpunkt C mit Des darüber: Dominante von f-Moll (Bossmusik)
    omen = ['C', 'Db/C', 'C', 'Db/C']
    S.add('boom', 'E', 20, 0, 6, n('C1'), 90)
    pad(S, 'strings', 'E', 20, omen, vel=86, center=n('G4'))
    pad(S, 'horns', 'E', 20, omen, vel=84, center=n('E3'), size=3)
    pad(S, 'pad', 'E', 20, omen, vel=64, bright=0.5)
    for b in range(4):
        for s in range(8):
            S.add('cbpizz', 'E', 20 + b, s * 0.5, 0.35, n('C2'), 84 + s * 2)
    S.add('kit', 'E', 20, 0, 8, TIMP_ROLL_LO, 100)
    S.add('kit', 'E', 22, 0, 8, SNARE_ROLL, 110)
    S.add('riser', 'E', 20, 0, 16, n('C3'), 95)
    S.add('fx', 'E', 22, 0, 8, SWELL4, 100)

    # ---------------------------------------------------------- Ankündigung (1,25 s): Auftakt
    # Kein Schlussakkord: Wirbel und Basshinführung münden auf dem nächsten Schlag in die
    # Bossmusik (boss1, Grundton F), die genau dann mit der Ankunft des Bosses einsetzt.
    leadin_spec = lead_in(S, 'F')

    mixspec = {
        'kit':      {'engine': 'sfz', 'inst': 'kit', 'gain': -1.0, 'rev': 0.12, 'duck_source': False},
        'harp':     {'engine': 'sfz', 'inst': 'harp', 'gain': -8.0, 'pan': -0.25, 'rev': 0.32, 'dly': 0.1},
        'kalimba':  {'engine': 'sfz', 'inst': 'kalimba', 'gain': -7.0, 'pan': 0.35, 'rev': 0.3, 'dly': 0.18},
        'flute':    {'engine': 'sfz', 'inst': 'flute', 'gain': -1.0, 'pan': 0.1, 'rev': 0.3, 'dly': 0.12},
        'glock':    {'engine': 'sfz', 'inst': 'glock', 'gain': -9.5, 'pan': 0.3, 'rev': 0.38, 'dly': 0.2},
        'violins':  {'engine': 'sfz', 'inst': 'vln_sus', 'gain': -5.0, 'pan': -0.3, 'rev': 0.35},
        'strings':  {'engine': 'sfz', 'inst': 'vla_sus', 'gain': -7.0, 'pan': 0.2, 'rev': 0.4, 'hp': 120},
        'pizz':     {'engine': 'sfz', 'inst': 'vln_pizz', 'gain': -3.0, 'pan': -0.2, 'rev': 0.28},
        'cbpizz':   {'engine': 'sfz', 'inst': 'cb_pizz', 'gain': -5.0, 'rev': 0.15},
        'horn':     {'engine': 'sfz', 'inst': 'horn', 'gain': -4.0, 'pan': 0.15, 'rev': 0.35},
        'horns':    {'engine': 'sfz', 'inst': 'horn', 'gain': -7.0, 'pan': -0.15, 'rev': 0.4},
        'clarinet': {'engine': 'sfz', 'inst': 'clarinet', 'gain': -2.0, 'pan': 0.05, 'rev': 0.3},
        'fx':       {'engine': 'sfz', 'inst': 'kit', 'gain': -11.0, 'rev': 0.3, 'width': 1.0},
        'pad':      {'engine': 'cs', 'instr': 'pad', 'gain': -8.0, 'rev': 0.3, 'hp': 140, 'width': 1.2},
        'bass':     {'engine': 'cs', 'instr': 'bass', 'gain': -3.0, 'lp': 2400},
        'lead':     {'engine': 'cs', 'instr': 'lead', 'gain': 1.0, 'pan': -0.05, 'rev': 0.22, 'dly': 0.22},
        'riser':    {'engine': 'cs', 'instr': 'riser', 'gain': -11.0, 'rev': 0.2},
        'boom':     {'engine': 'cs', 'instr': 'boom', 'gain': -6.0, 'rev': 0.1},
    }
    mixspec.update(leadin_spec)
    return song, mixspec, {'file': 'level1', 'title': 'Level 1 – Blütenmeer', 'reverb': 2.4}
