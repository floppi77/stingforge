"""Level 2 – Wurzelreich: unterirdisch, erdig, tastend-bedrohlich.

A-Moll mit phrygischer kleiner Sekunde (Bb) als Grabgeräusch-Reibung · 112 BPM,
Halftime-Gefühl. Die Drohne (Formantfilter, didgeridoo-artig) wächst langsam zum
Groove. Miniboss „Wurzelfresser" bei Levelzeit 148 s = Takt 12 von C; das Ende
gräbt sich mit pulsierendem Grollen ein und reißt in die Larven-Bossmusik ab.

Form: A 28 · B 29 · C 28 · D 25 · E 21 Takte (= Checkpoints).
"""
from __future__ import annotations

from score import Song, n
from songs._kit import (lead_in, CLASH, Human, LOG_HI, LOG_LO, SNARE_ROLL, SWELL4, TIMP_LO, TIMP_MID,
                        TIMP_ROLL_LO, TIMP_ROLL_MID, TOM_LO, WOOD, arp, bar_slots, bassline,
                        close, crash, drums, fit_octave, grid, pad, phrase, repeat_to, take,
                        voicing)
from songs._themes import fragment, invert, leitmotiv, mechanize, remap

BPM = 112

# ------------------------------------------------------------------ Harmonik
H1 = ['Am', 'Bb', 'Am', 'E7']          # b2-Reibung: das Grabgeräusch
H2 = ['Am', 'Dm', 'Bb', 'E7']
H3 = ['Am', 'C', 'Dm', 'E7']
H4 = ['F', 'Am', 'E7', 'Am']
H5 = ['Am', 'E7', 'Am', 'E7']          # Stab-Ostinato
H6 = ['Am', 'Bb', 'G', 'E7']
HMINI = ['Am', 'Am', 'Bb', 'G']        # Miniboss-Vamp
HGROLL = ['Am', 'Bb', 'Am', 'Bb']

# ------------------------------------------------------------------ Motive
THEME = leitmotiv('A', 'phryg')                     # 8 Takte
THEME_HEAD = leitmotiv('A', 'phryg', part='head')   # 4 Takte
THEME_MIN = leitmotiv('A', 'min')                   # 8 Takte, ohne b2
THEME_INV = invert(leitmotiv('A', 'min'))           # 8 Takte, Spiegelung
THEME_AUG = [(p, d * 2) for p, d in leitmotiv('A', 'min', part='head')]   # 8 Takte gedehnt
CRAWL = mechanize(leitmotiv('A', 'min', part='head'), 0.5)[:32]          # 4 Takte 8tel-Puls
CRY = [('A4', 2), ('Bb4', 1), ('A4', 1), ('G4', 1), ('F4', 1), ('E4', 2)]   # 2 Takte
ANSWER = [(None, 2), ('E5', 1), ('D5', 1), ('C5', 2), (None, 2)]            # 2 Takte
STAB = [(('A2'), .5), (None, .5), ('A2', .5), (None, .5),
        ('Bb2', .5), (None, .5), ('A2', .5), (None, .5)]                    # 1 Takt


def build():
    song = Song.for_level(2, BPM)
    hum = Human(202)
    S = song
    secbars = {s.name: s.bars for s in song.sections}

    # ---------------------------------------------------------- Intro (2,2 s)
    for i, p in enumerate((n('A2'), n('E3'), n('A3'), n('Bb3'), n('A3'), n('E3'))):
        S.add('drone', 'intro', 0, i * 0.7, 2.4, p, 78 - i * 3, bright=0.35, aux=3.2)
    S.add('kit', 'intro', 0, 0, 4, TIMP_ROLL_LO, 70)
    S.add('boom', 'intro', 0, 0, 4, n('A1'), 60)

    # ---------------------------------------------------------- A (28 Takte)
    S.add('drone', 'A', 0, 0, 16, n('A1'), 92, bright=0.32, aux=3.1)
    S.add('drone', 'A', 0, 0, 16, n('E2'), 72, bright=0.26, aux=2.7)
    for b in range(8):                                    # Knarzgeräusche der Wurzeln
        S.add('kit', 'A', b, 2.5, .2, WOOD, 46 + (b % 3) * 6)
        S.add('kit', 'A', b, 0, .2, WOOD, 38)

    for bar, k in grid(4, 4):                             # Takte 4–7: Bass und Balafon
        h = repeat_to(H1, k)
        bassline(S, 'bass', 'A', 4 + bar, h, 'roots', vel=74, bright=0.22)
        arp(S, 'balafon', 'A', 4 + bar, h, step=1.0, low=n('D4'), high=n('A5'), shape='broken',
            vel=52, human=hum)
        pad(S, 'pad', 'A', 4 + bar, h, vel=46, center=n('A2'), size=3, bright=0.18)

    # Takte 8–11: erster Themenkopf auf dem Fagott, Taiko setzt ein
    S.add('drone', 'A', 8, 0, 12, n('A1'), 88, bright=0.42, aux=3.4)
    phrase(S, 'bassoon', 'A', 8, THEME_HEAD, vel=80, transpose=-24, human=hum)
    pad(S, 'pad', 'A', 8, repeat_to(H3, 4), vel=50, center=n('A2'), size=4, bright=0.26)
    bassline(S, 'bass', 'A', 8, repeat_to(H3, 4), 'half', vel=80, bright=0.28)
    drums(S, 'kit', 'A', 8, 4, 'taiko', vel=72, human=hum)

    # Takte 12–19: das Thema vollständig, Fagott + Klarinette im Unteroktav
    S.add('drone', 'A', 12, 0, 8, n('A1'), 96, bright=0.5, aux=3.6)
    phrase(S, 'bassoon', 'A', 12, THEME, vel=86, transpose=-24, human=hum)
    phrase(S, 'clarinet', 'A', 12, THEME, vel=62, transpose=-12, human=hum)
    pad(S, 'pad', 'A', 12, repeat_to(H2, 8), vel=52, center=n('A2'), size=4, bright=0.32)
    arp(S, 'balafon', 'A', 12, repeat_to(H2, 8), step=0.5, low=n('D4'), high=n('A5'),
        vel=56, human=hum)
    bassline(S, 'bass', 'A', 12, repeat_to(H2, 8), 'half', vel=86, bright=0.34)
    bassline(S, 'cbpizz', 'A', 12, repeat_to(H2, 8), 'roots', vel=84)
    drums(S, 'kit', 'A', 12, 8, 'taiko', vel=86, human=hum, fill='timp')

    # Takte 20–23: Frage und Antwort (Fagott unten, Klarinette oben)
    for i, cell in enumerate((CRY, ANSWER)):
        phrase(S, 'bassoon', 'A', 20 + i * 2, cell, vel=78, transpose=fit_octave(cell, 'bassoon'),
               human=hum)
        phrase(S, 'clarinet', 'A', 22 - i * 2, cell, vel=68, transpose=-12, human=hum)
    pad(S, 'pad', 'A', 20, repeat_to(H4, 4), vel=50, center=n('A2'), size=4, bright=0.3)
    arp(S, 'balafon', 'A', 20, repeat_to(H4, 4), step=0.5, low=n('D4'), high=n('A5'), vel=54, human=hum)
    bassline(S, 'bass', 'A', 20, repeat_to(H4, 4), 'half', vel=84, bright=0.3)
    drums(S, 'kit', 'A', 20, 4, 'tribal', vel=84, human=hum)

    # Takte 24–27: Verdichtung zum Abschnittswechsel
    for bar, k in grid(4, 4):
        h = repeat_to(H5, 4)
        arp(S, 'balafon', 'A', 24, h, step=0.25, low=n('A4'), high=n('A5'), vel=58, human=hum, ring=1.2)
        pad(S, 'pad', 'A', 24, h, vel=58, center=n('A2'), size=4, bright=0.42)
        bassline(S, 'bass', 'A', 24, h, 'pulse', vel=88, bright=0.4)
    for b in range(4):
        S.add('kit', 'A', 24 + b, 0, 1.0, TIMP_LO, 94 + b * 4)
        S.add('kit', 'A', 24 + b, 2.5, .25, LOG_LO, 78 + b * 4)
        S.add('kit', 'A', 24 + b, 3.5, .25, LOG_HI, 72 + b * 4)
        S.add('cbpizz', 'A', 24 + b, 0, .45, n('A2'), 88)
        S.add('cbpizz', 'A', 24 + b, 2, .45, n('Bb2'), 82)
    drums(S, 'kit', 'A', 24, 4, 'taiko', vel=92, human=hum, fill='timp')
    S.add('riser', 'A', 26, 0, 8, n('A1'), 60)
    S.add('kit', 'A', 27, 0, 4, SWELL4, 70)

    # ---------------------------------------------------------- B (29 Takte)
    crash(S, 'kit', 'B', 0, 92)
    S.add('boom', 'B', 0, 0, 4, n('A1'), 86)
    S.add('drone', 'B', 0, 0, 16, n('A1'), 104, bright=0.55, aux=3.8)
    phrase(S, 'lead', 'B', 0, THEME, vel=90, transpose=-12, bright=0.5, human=hum)
    phrase(S, 'bassoon', 'B', 0, THEME, vel=88, transpose=-24, human=hum)
    pad(S, 'pad', 'B', 0, repeat_to(H1, 8), vel=56, center=n('A2'), size=4, bright=0.36)
    arp(S, 'balafon', 'B', 0, repeat_to(H1, 8), step=0.5, low=n('D4'), high=n('F6'), vel=54, human=hum)
    bassline(S, 'bass', 'B', 0, repeat_to(H1, 8), 'half', vel=94, bright=0.4)
    bassline(S, 'cbpizz', 'B', 0, repeat_to(H1, 8), 'roots', vel=88)
    drums(S, 'kit', 'B', 0, 8, 'taiko', vel=92, human=hum, fill='timp')

    crash(S, 'kit', 'B', 8, 88)
    for i in range(4):                                    # Takte 8–15: Rufe
        phrase(S, 'clarinet', 'B', 8 + i * 2, CRY, vel=84, human=hum)
        phrase(S, 'balafon', 'B', 9 + i * 2, ANSWER, vel=72, human=hum, legato=1.3)
    pad(S, 'pad', 'B', 8, repeat_to(H2, 8), vel=54, center=n('A2'), size=4, bright=0.32)
    arp(S, 'balafon', 'B', 8, repeat_to(H2, 8), step=0.5, low=n('D4'), high=n('A5'), vel=54, human=hum)
    bassline(S, 'bass', 'B', 8, repeat_to(H2, 8), 'pop', vel=92, bright=0.42)
    bassline(S, 'cbpizz', 'B', 8, repeat_to(H2, 8), 'half', vel=90)
    drums(S, 'kit', 'B', 8, 8, 'tribal', vel=90, human=hum, fill='timp')

    # Takte 16–23: Wurzeln fahren aus – Stab-Motiv und Spiegelthema
    crash(S, 'kit', 'B', 16, 96)
    for b in range(8):
        ch = H5[b % 4]
        S.add('kit', 'B', 16 + b, 0, 1.2, TIMP_LO, 102)
        S.add('kit', 'B', 16 + b, 1, .5, LOG_LO, 86)
        S.add('kit', 'B', 16 + b, 2, .2, WOOD, 84)
        S.add('kit', 'B', 16 + b, 2.75, .2, WOOD, 76)
        S.add('kit', 'B', 16 + b, 3, .5, LOG_HI, 82)
        root = voicing(ch, n('A1'), n('A2'))[0]
        for q in range(4):
            S.add('cbpizz', 'B', 16 + b, q, .35, root + (12 if q % 2 else 0), 92 - (6 if q % 2 else 0))
    phrase(S, 'lead', 'B', 16, THEME_INV, vel=92, bright=0.62, human=hum)
    phrase(S, 'bassoon', 'B', 16, THEME_INV, vel=84, transpose=-12, human=hum)
    pad(S, 'pad', 'B', 16, repeat_to(H5, 8), vel=56, center=n('E2'), size=4, bright=0.45)
    bassline(S, 'bass', 'B', 16, repeat_to(H5, 8), 'drive', vel=94, bright=0.5)
    drums(S, 'kit', 'B', 16, 8, 'taiko', vel=96, human=hum)

    # Takte 24–28: Steigerung in den Abschnittswechsel
    for b in range(5):
        S.add('kit', 'B', 24 + b, 0, .5, TIMP_LO, 108)
        S.add('kit', 'B', 24 + b, 1.5, .5, TIMP_MID, 96)
        S.add('kit', 'B', 24 + b, 2, .5, TIMP_LO, 104)
        for s in range(4):
            S.add('kit', 'B', 24 + b, s * 0.75, .2, LOG_HI if s % 2 else LOG_LO, 74 + s * 4)
    arp(S, 'balafon', 'B', 24, repeat_to(H6, 5), step=0.25, low=n('A4'), high=n('A5'), vel=62,
        human=hum, ring=1.2)
    pad(S, 'pad', 'B', 24, repeat_to(H6, 5), vel=62, center=n('A2'), size=4, bright=0.5)
    bassline(S, 'bass', 'B', 24, repeat_to(H6, 5), 'pulse', vel=96, bright=0.45)
    S.add('riser', 'B', 25, 0, 8, n('A1'), 70)
    S.add('kit', 'B', 26, 0, 8, SWELL4, 84)

    # ---------------------------------------------------------- C (28 Takte)
    # Takte 0–11: Atempause. Ab Takt 12 (= 148 s Levelzeit) der Wurzelfresser.
    crash(S, 'kit', 'C', 0, 64)
    S.add('drone', 'C', 0, 0, 16, n('A1'), 82, bright=0.3, aux=3.0)
    pad(S, 'pad', 'C', 0, repeat_to(['Dm', 'Am', 'Bb', 'E7'], 12), vel=46, center=n('A2'),
        size=3, bright=0.14)
    arp(S, 'balafon', 'C', 0, repeat_to(['Dm', 'Am', 'Bb', 'E7'], 12), step=1.0, low=n('A4'),
        high=n('A5'), shape='broken', vel=48, human=hum)
    for i in range(12):
        S.add('kit', 'C', i, 2.75, .2, WOOD, 40 + (i % 4) * 5)
    for k in range(3):
        phrase(S, 'bassoon', 'C', k * 4, CRY, vel=66, human=hum)
    S.add('drone', 'C', 4, 0, 8, n('A2'), 76, bright=0.42, aux=2.8)
    S.add('kit', 'C', 11, 0, 4, TIMP_ROLL_LO, 92)

    # Miniboss (Takte 12–27): Stab-Motiv, Sub-Grollen, rhythmische Verdichtung
    crash(S, 'kit', 'C', 12, 108)
    S.add('boom', 'C', 12, 0, 4, n('A1'), 100)
    S.add('kit', 'C', 12, 0, 2, TIMP_LO, 118)
    S.add('kit', 'C', 12, 0, .3, CLASH, 98)
    for bar, k in grid(16, 4):
        h = repeat_to(HMINI, k)
        b = 12 + bar
        for i, ch in enumerate(h):
            root = voicing(ch, n('A1'), n('A2'))[0]
            for q in range(4):
                S.add('cbpizz', 'C', b + i, q, .3, root + (12 if q % 2 else 0), 100 if q == 0 else 82)
            S.add('sub', 'C', b + i, 0, 1.6, root - 12, 78)
            for s in range(8):
                S.add('balafon', 'C', b + i, s * 0.5, .25,
                      voicing(ch, n('D4'), n('A5'))[s % 5], 76 if s % 2 == 0 else 58)
        # Miniboss-Pad eine Oktave tiefer: die kleine Sekunde des Themas (Bb gegen A)
        # soll als Reibung hörbar sein, aber nicht als Cluster in der Melodielage.
        pad(S, 'pad', 'C', b, h, vel=62, center=n('A2'), size=4, bright=0.4)
        bassline(S, 'bass', 'C', b, h, 'drive', vel=98, bright=0.5)
    phrase(S, 'lead', 'C', 12, CRAWL + CRAWL, vel=92, transpose=-12, bright=0.6, human=hum)
    phrase(S, 'bassoon', 'C', 16, THEME_MIN, vel=92, transpose=-24, human=hum)
    phrase(S, 'clarinet', 'C', 20, THEME_INV, vel=78, transpose=12, human=hum)
    # (Der Loop oben deckt bereits alle 16 Miniboss-Takte ab: Pad und Bass hier NICHT
    #  ein zweites Mal anlegen – sonst liegen zwei Akkordfolgen übereinander und es
    #  entstehen Cluster wie D-E-F-Gis im selben Takt.)
    drums(S, 'kit', 'C', 12, 12, 'taiko', vel=100, human=hum)
    drums(S, 'kit', 'C', 24, 4, 'tribal', vel=100, human=hum, fill='timp')
    for b in range(4):
        S.add('sub', 'C', 24 + b, 0, 1.2, n('E1'), 84)
        S.add('sub', 'C', 24 + b, 2, 1.0, n('A1'), 78)
    S.add('riser', 'C', 26, 0, 8, n('Bb1'), 84)
    S.add('kit', 'C', 26, 0, 8, SWELL4, 92)

    # ---------------------------------------------------------- D (25 Takte)
    crash(S, 'kit', 'D', 0, 110)
    S.add('boom', 'D', 0, 0, 6, n('A1'), 94)
    S.add('choir', 'D', 0, 0, 16, n('E3'), 90, bright=0.4, aux=1)
    S.add('drone', 'D', 0, 0, 16, n('A1'), 106, bright=0.6, aux=3.9)
    phrase(S, 'lead', 'D', 0, THEME, vel=90, transpose=-12, bright=0.5, human=hum)
    phrase(S, 'bassoon', 'D', 0, THEME, vel=88, transpose=-24, human=hum)
    pad(S, 'pad', 'D', 0, repeat_to(H2, 8), vel=56, center=n('A2'), size=4, bright=0.4)
    arp(S, 'balafon', 'D', 0, repeat_to(H2, 8), step=0.25, low=n('D4'), high=n('F6'), vel=54,
        human=hum, ring=1.3)
    bassline(S, 'bass', 'D', 0, repeat_to(H2, 8), 'pop', vel=98, bright=0.5)
    bassline(S, 'cbpizz', 'D', 0, repeat_to(H2, 8), 'roots', vel=92)
    drums(S, 'kit', 'D', 0, 8, 'taiko', vel=96, human=hum, fill='timp')

    crash(S, 'kit', 'D', 8, 96)
    S.add('choir', 'D', 8, 0, 16, n('C4'), 80, bright=0.3, aux=2)
    for i in range(4):
        phrase(S, 'clarinet', 'D', 8 + i * 2, CRY, vel=86, human=hum)
        phrase(S, 'bassoon', 'D', 9 + i * 2, ANSWER, vel=76, transpose=-12, human=hum, legato=1.3)
    pad(S, 'pad', 'D', 8, repeat_to(H4, 8), vel=58, center=n('A2'), size=4, bright=0.42)
    arp(S, 'balafon', 'D', 8, repeat_to(H4, 8), step=0.5, low=n('D4'), high=n('A5'), vel=58, human=hum)
    bassline(S, 'bass', 'D', 8, repeat_to(H4, 8), 'pop', vel=96, bright=0.48)
    drums(S, 'kit', 'D', 8, 8, 'tribal', vel=96, human=hum, fill='timp')

    crash(S, 'kit', 'D', 16, 104)
    S.add('choir', 'D', 16, 0, 8, n('E4'), 92, bright=0.55, aux=0)
    phrase(S, 'lead', 'D', 16, leitmotiv('A', 'harm'), vel=96, transpose=-12, bright=0.6, human=hum)
    phrase(S, 'bassoon', 'D', 16, leitmotiv('A', 'harm'), vel=88, transpose=-24, human=hum)
    pad(S, 'pad', 'D', 16, repeat_to(H5, 8), vel=62, center=n('A2'), size=4, bright=0.55)
    bassline(S, 'bass', 'D', 16, repeat_to(H5, 8), 'drive', vel=100, bright=0.55)
    bassline(S, 'cbpizz', 'D', 16, repeat_to(H5, 8), 'drive', vel=94)
    drums(S, 'kit', 'D', 16, 8, 'taiko', vel=102, human=hum, fill='roll')
    for b in range(8):
        S.add('sub', 'D', 16 + b, 0, 1.4, n('A1'), 76)

    S.add('kit', 'D', 24, 0, 4, TIMP_ROLL_MID, 102)
    S.add('riser', 'D', 23, 0, 8, n('A1'), 74)
    S.add('kit', 'D', 23, 0, 8, SWELL4, 86)

    # ---------------------------------------------------------- E (21 Takte)
    # Pulsierendes Grollen, das sich eingräbt.
    crash(S, 'kit', 'E', 0, 82)
    S.add('drone', 'E', 0, 0, 16, n('A1'), 100, bright=0.4, aux=2.2)
    pad(S, 'pad', 'E', 0, repeat_to(HGROLL, 16), vel=50, center=n('A2'), size=3, bright=0.22)
    for b in range(16):
        for s in range(4):
            S.add('sub', 'E', b, s, 0.9, n('A1'), 76 if s % 2 == 0 else 68)
        if b % 2 == 0:
            S.add('kit', 'E', b, 0, 1.2, TIMP_LO, 90)
            S.add('kit', 'E', b, 2, 1.2, LOG_LO, 82)
        S.add('kit', 'E', b, 3.5, .2, WOOD, 54)
    phrase(S, 'clarinet', 'E', 0, THEME_AUG, vel=74, transpose=-12, human=hum)
    phrase(S, 'bassoon', 'E', 4, fragment(leitmotiv('A', 'phryg'), 8, 12), vel=80, transpose=-24,
           human=hum)
    bassline(S, 'bass', 'E', 0, repeat_to(HGROLL, 16), 'pulse', vel=86, bright=0.32)
    bassline(S, 'cbpizz', 'E', 4, repeat_to(HGROLL, 12), 'half', vel=80)

    # Takte 16–20: Riser und Abriss in die Bossmusik
    crash(S, 'kit', 'E', 16, 94)
    S.add('drone', 'E', 16, 0, 5, n('A1'), 110, bright=0.7, aux=4.4)
    for b in range(4):
        S.add('kit', 'E', 16 + b, 0, .5, TIMP_LO, 108)
        S.add('kit', 'E', 16 + b, 2, .5, TIMP_LO, 102)
        S.add('cbpizz', 'E', 16 + b, 0, .4, n('A2'), 98)
        S.add('cbpizz', 'E', 16 + b, 2, .4, n('Bb2'), 92)
    phrase(S, 'lead', 'E', 16, fragment(leitmotiv('A', 'phryg'), 8, 8), vel=100, transpose=-12,
           bright=0.7, human=hum)
    pad(S, 'pad', 'E', 16, repeat_to(HGROLL, 4), vel=66, center=n('A2'), size=4, bright=0.6)
    drums(S, 'kit', 'E', 16, 4, 'taiko', vel=106, human=hum, fill='roll')
    S.add('kit', 'E', 17, 0, 8, SNARE_ROLL, 104)
    S.add('riser', 'E', 16, 0, 16, n('A1'), 94)
    S.add('kit', 'E', 16, 0, 16, SWELL4, 98)
    for b in range(3):
        S.add('sub', 'E', 16 + b, 0, 1.4, n('A1'), 86)

    # ---------------------------------------------------------- Ankündigung (1,25 s): Auftakt
    # Kein Schlussakkord: Wirbel und Basshinführung münden auf dem nächsten Schlag in die
    # Bossmusik (boss2, Grundton A), die genau dann mit der Ankunft des Bosses einsetzt.
    leadin_spec = lead_in(S, 'A')

    mixspec = {
        'kit':      {'engine': 'sfz', 'inst': 'kit', 'gain': -0.5, 'rev': 0.16},
        'cbpizz':   {'engine': 'sfz', 'inst': 'cb_pizz', 'gain': -2.5, 'pan': -0.1, 'rev': 0.2},
        'bassoon':  {'engine': 'sfz', 'inst': 'bassoon', 'gain': -2.0, 'pan': -0.18, 'rev': 0.32},
        'clarinet': {'engine': 'sfz', 'inst': 'clarinet', 'gain': -4.0, 'pan': 0.22, 'rev': 0.36},
        'balafon':  {'engine': 'sfz', 'inst': 'balafon', 'gain': -8.5, 'pan': 0.32, 'rev': 0.3, 'dly': 0.14},
        'drone':    {'engine': 'cs', 'instr': 'drone', 'gain': -4.0, 'rev': 0.22, 'lp': 5200},
        'pad':      {'engine': 'cs', 'instr': 'pad', 'gain': -10.0, 'rev': 0.38, 'hp': 70, 'width': 1.25},
        'bass':     {'engine': 'cs', 'instr': 'bass', 'gain': -2.0, 'lp': 2100},
        'lead':     {'engine': 'cs', 'instr': 'lead', 'gain': -1.0, 'pan': -0.05, 'rev': 0.24, 'dly': 0.18},
        'sub':      {'engine': 'cs', 'instr': 'sub', 'gain': -5.0, 'lp': 120},
        'choir':    {'engine': 'cs', 'instr': 'choir', 'gain': -6.0, 'rev': 0.42, 'hp': 150, 'width': 1.3},
        'riser':    {'engine': 'cs', 'instr': 'riser', 'gain': -10.0, 'rev': 0.2},
        'boom':     {'engine': 'cs', 'instr': 'boom', 'gain': -5.0, 'rev': 0.12},
    }
    mixspec.update(leadin_spec)
    return song, mixspec, {'file': 'level2', 'title': 'Level 2 – Wurzelreich', 'reverb': 2.6}
