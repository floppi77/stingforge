"""Level 8 – Maschinenherz: treibend, metallisch, unerbittlich.

g-Moll mit Dur-Dominante (Fis in D7) · 140 BPM. Die Musik ist ein Schichtaufbau:
alle vier Takte kommt eine Maschine dazu. Ein 7/8-Akzentmuster läuft gegen den
4/4-Takt („Stottern"), Ringe aus Arpeggien drehen sich über Anvil und Bremstrommel.

Form: A 33 · B 36 · C 35 · D 32 · E 27 Takte. Miniboss bei Levelzeit 146 s =
Takt 15 von C. Am Ende fallen die Maschinen aus, das Stottern bleibt.
"""
from __future__ import annotations

from score import Song, n
from songs._kit import (ANVIL1, ANVIL2, ANVIL3, BRAKE1, BRAKE2, BRAKE_SUSP, CLASH, CRASH,
                        FRAME_LO, GONG, Human, LOG_HI, LOG_LO, SNARE_ROLL, SWELL4, TIMP_LO,
                        TIMP_ROLL_LO, TRI, WOOD, arp, bassline, close, crash, drums, grid, pad,
                        phrase, repeat_to, voicing)
from songs._themes import fragment, invert, leitmotiv, mechanize, second_theme

BPM = 140

# ------------------------------------------------------------------ Harmonik
H1 = ['Gm', 'Gm', 'Eb', 'D7']          # D7 = Fis, die Maschine zieht an
H2 = ['Gm', 'Bb', 'Eb', 'D7']
H3 = ['Cm', 'Gm', 'Eb', 'D7']
H4 = ['Eb', 'Bb', 'Cm', 'D7']
H5 = ['Gm', 'Eb', 'Bb', 'F']           # natürliche Moll: kalt und gleichförmig
HMINI = ['Gm', 'Gm', 'Eb', 'D7']

# ------------------------------------------------------------------ Motive
THEME = leitmotiv('G', 'min')                       # 8 Takte
THEME_HEAD = leitmotiv('G', 'min', part='head')
THEME_TAIL = leitmotiv('G', 'min', part='tail')
THEME_MECH = mechanize(leitmotiv('G', 'min'), 0.25)[:128]      # 8 Takte 16tel
SECOND = second_theme('G', 'min')
THEME_INV = invert(leitmotiv('G', 'min'))
RING = [('G5', .25), ('Bb5', .25), ('D6', .25), ('F6', .25), ('D6', .25), ('Bb5', .25),
        ('G5', .25), ('D5', .25)]                                # 2 Schläge, kreisend


def stutter(S: Song, part: str, sec: str, bar0: int, bars: int, key: int, vel: int = 84,
            period: float = 3.5, dur: float = 0.22, offset: float = 0.0) -> None:
    """7/8-Akzente gegen den 4/4-Takt: alle 3½ Schläge ein Schlag."""
    total = bars * 4
    t = offset
    while t < total:
        S.add(part, sec, bar0, t, dur, key, vel)
        t += period


def ring_arp(S: Song, part: str, sec: str, bar0: int, bars: int, ch: list[str], low: int,
             high: int, vel: int = 60, step: float = 0.25) -> None:
    """Ringsalve: Akkordtöne kreisen auf- und abwärts."""
    tones = []
    for c in ch:
        tones += [p for p in close(c, low, 4) if low <= p <= high]
    if not tones:
        return
    seq = tones + tones[-2:0:-1]
    steps = int(round(bars * 4 / step))
    for i in range(steps):
        S.add(part, sec, bar0, i * step, step * 0.9, seq[i % len(seq)], vel if i % 4 == 0 else int(vel * 0.8))


def build():
    song = Song.for_level(8, BPM)
    hum = Human(808)
    S = song

    # ---------------------------------------------------------- Intro (2,2 s)
    S.add('kit', 'intro', 0, 0, 3, TIMP_LO, 100)
    S.add('boom', 'intro', 0, 0, 3, n('G1'), 84)
    for i, p in enumerate((n('G2'), n('D3'), n('G3'), n('Bb3'))):
        S.add('bass', 'intro', 0, i * 0.5, 0.8, p, 100, bright=0.6)
    S.add('kit', 'intro', 0, 0, .3, ANVIL1, 90)

    # ---------------------------------------------------------- A (33 Takte)
    # Schichtaufbau: alle vier Takte eine Maschine mehr.
    S.add('drone', 'A', 0, 0, 16, n('G1'), 84, bright=0.3, aux=3.0)
    for b in range(8):                                   # 0–7: Puls und Metall
        S.add('kit', 'A', b, 0, .5, TIMP_LO, 92)
        S.add('kit', 'A', b, 2, .5, TIMP_LO, 86)
        stutter(S, 'kit', 'A', b, 1, BRAKE1, 62, period=3.5)
        S.add('kit', 'A', b, 3.5, .2, WOOD, 60)
    bassline(S, 'bass', 'A', 8, repeat_to(H1, 8), 'drive', vel=86, bright=0.5)
    pad(S, 'pad', 'A', 8, repeat_to(H1, 8), vel=46, center=n('G3'), size=3, bright=0.24)
    drums(S, 'kit', 'A', 8, 8, 'industrial', vel=70, human=hum)
    stutter(S, 'kit', 'A', 8, 8, BRAKE2, 66)

    arp(S, 'pluck', 'A', 16, repeat_to(H2, 8), step=0.25, low=n('G4'), high=n('G6'), vel=44, human=hum)
    phrase(S, 'lead', 'A', 16, THEME_HEAD, vel=80, bright=0.5, human=hum)
    phrase(S, 'trb_stac', 'A', 16, THEME_HEAD, vel=76, transpose=-24, human=hum)
    pad(S, 'pad', 'A', 16, repeat_to(H2, 8), vel=48, center=n('G3'), size=4, bright=0.28)
    bassline(S, 'bass', 'A', 16, repeat_to(H2, 8), 'drive', vel=90, bright=0.54)
    drums(S, 'kit', 'A', 16, 8, 'industrial', vel=76, human=hum)
    stutter(S, 'kit', 'A', 16, 8, ANVIL3, 64)

    ring_arp(S, 'glock', 'A', 24, 6, H3, n('G4'), n('D6'), vel=56, step=0.25)
    phrase(S, 'lead', 'A', 24, THEME_TAIL, vel=84, bright=0.54, human=hum)
    phrase(S, 'vln_sus', 'A', 24, THEME_TAIL, vel=64, transpose=-12, human=hum)
    pad(S, 'pad', 'A', 24, repeat_to(H3, 6), vel=52, center=n('G4'), size=4, bright=0.34)
    bassline(S, 'bass', 'A', 24, repeat_to(H3, 6), 'drive', vel=92, bright=0.56)
    drums(S, 'kit', 'A', 24, 6, 'industrial', vel=84, human=hum, fill='timp')
    stutter(S, 'kit', 'A', 24, 6, BRAKE1, 70)
    S.add('riser', 'A', 30, 0, 12, n('G1'), 66)
    S.add('kit', 'A', 30, 0, 12, SWELL4, 74)

    # ---------------------------------------------------------- B (36 Takte)
    crash(S, 'kit', 'B', 0, 88)
    S.add('drone', 'B', 0, 0, 16, n('G1'), 96, bright=0.42, aux=3.4)
    phrase(S, 'lead', 'B', 0, THEME, vel=92, bright=0.6, human=hum)
    phrase(S, 'trb_stac', 'B', 0, THEME, vel=80, transpose=-24, human=hum)
    ring_arp(S, 'glock', 'B', 0, 8, H2, n('G4'), n('D6'), vel=58, step=0.25)
    pad(S, 'pad', 'B', 0, repeat_to(H2, 8), vel=52, center=n('G3'), size=4, bright=0.32)
    bassline(S, 'bass', 'B', 0, repeat_to(H2, 8), 'drive', vel=94, bright=0.6)
    drums(S, 'kit', 'B', 0, 8, 'industrial', vel=88, human=hum)
    stutter(S, 'kit', 'B', 0, 8, BRAKE2, 78)

    crash(S, 'kit', 'B', 8, 84)
    phrase(S, 'lead', 'B', 8, THEME_MECH, vel=90, bright=0.64, human=hum, legato=0.8)
    phrase(S, 'vln_sus', 'B', 8, SECOND, vel=70, human=hum)
    ring_arp(S, 'glock', 'B', 8, 8, H3, n('G4'), n('D6'), vel=60, step=0.25)
    pad(S, 'pad', 'B', 8, repeat_to(H3, 8), vel=52, center=n('G4'), size=4, bright=0.34)
    bassline(S, 'bass', 'B', 8, repeat_to(H3, 8), 'pulse', vel=94, bright=0.58)
    drums(S, 'kit', 'B', 8, 8, 'industrial', vel=86, human=hum, fill='snare')
    stutter(S, 'kit', 'B', 8, 8, ANVIL2, 74)

    crash(S, 'kit', 'B', 16, 88)
    for b in range(8):                                  # Takte 16–23: Stottern verdichtet
        stutter(S, 'kit', 'B', 16 + b, 1, BRAKE1, 80, period=3.5, offset=0.5)
        stutter(S, 'kit', 'B', 16 + b, 1, ANVIL1, 72, period=1.75)
    phrase(S, 'lead', 'B', 16, THEME, vel=94, bright=0.62, human=hum)
    phrase(S, 'glock', 'B', 16, THEME, vel=76, transpose=12, human=hum, legato=1.1)
    ring_arp(S, 'glock', 'B', 16, 8, H4, n('G4'), n('Eb6'), vel=58, step=0.25)
    pad(S, 'pad', 'B', 16, repeat_to(H4, 8), vel=54, center=n('G4'), size=4, bright=0.38)
    bassline(S, 'bass', 'B', 16, repeat_to(H4, 8), 'drive', vel=96, bright=0.62)
    drums(S, 'kit', 'B', 16, 8, 'industrial', vel=90, human=hum, fill='timp')

    for b in range(24, 36):                             # Takte 24–35: Hochlaufen
        S.add('kit', 'B', b, 0, .5, TIMP_LO, 100 + (b - 24) * 2)
        S.add('kit', 'B', b, 2, .5, TIMP_LO, 94 + (b - 24) * 2)
        stutter(S, 'kit', 'B', b, 1, BRAKE2, 76 + (b - 24) * 2, period=3.5)
    phrase(S, 'lead', 'B', 24, invert(leitmotiv('G', 'min')), vel=96, bright=0.66, human=hum)
    phrase(S, 'vln_sus', 'B', 24, invert(leitmotiv('G', 'min')), vel=80, transpose=-12, human=hum)
    ring_arp(S, 'glock', 'B', 24, 12, H5, n('G4'), n('D6'), vel=60, step=0.25)
    pad(S, 'pad', 'B', 24, repeat_to(H5, 12), vel=58, center=n('G4'), size=4, bright=0.44)
    bassline(S, 'bass', 'B', 24, repeat_to(H5, 12), 'drive', vel=98, bright=0.66)
    drums(S, 'kit', 'B', 24, 12, 'industrial', vel=94, human=hum, fill='roll')
    S.add('riser', 'B', 32, 0, 16, n('G1'), 84)
    S.add('kit', 'B', 32, 0, 16, SWELL4, 88)

    # ---------------------------------------------------------- C (35 Takte)
    # Takte 0–14: die Maschine läuft warm. Ab Takt 15 (= 146 s) der Miniboss.
    S.add('drone', 'C', 0, 0, 16, n('G1'), 90, bright=0.34, aux=3.2)
    for b in range(15):
        S.add('kit', 'C', b, 0, .5, TIMP_LO, 82)
        S.add('kit', 'C', b, 2.5, .3, BRAKE_SUSP, 62)
        stutter(S, 'kit', 'C', b, 1, WOOD, 54, period=3.5)
    arp(S, 'pluck', 'C', 0, repeat_to(H1, 15), step=0.5, low=n('G4'), high=n('G6'), vel=42, human=hum)
    pad(S, 'pad', 'C', 0, repeat_to(H1, 15), vel=42, center=n('G3'), size=3, bright=0.18)
    phrase(S, 'glock', 'C', 4, fragment(THEME, 0, 12), vel=60, human=hum, legato=1.3)
    bassline(S, 'bass', 'C', 0, repeat_to(H1, 15), 'roots', vel=76, bright=0.3)
    S.add('kit', 'C', 14, 0, 4, TIMP_ROLL_LO, 88)

    # Miniboss (Takte 15–34)
    crash(S, 'kit', 'C', 15, 100)
    S.add('kit', 'C', 15, 0, .3, CLASH, 98)
    S.add('boom', 'C', 15, 0, 4, n('G1'), 104)
    for bar, k in grid(20, 4):
        b = 15 + bar
        h = repeat_to(HMINI, k)
        pad(S, 'pad', 'C', b, h, vel=56, center=n('G4'), size=4, bright=0.42)
        bassline(S, 'bass', 'C', b, h, 'drive', vel=96, bright=0.64)
        drums(S, 'kit', 'C', b, k, 'industrial', vel=92, human=hum)
        ring_arp(S, 'glock', 'C', b, k, h, n('G4'), n('D6'), vel=58, step=0.25)
        for i in range(k):
            for s in range(7):
                S.add('kit', 'C', b + i, s * 0.5, .2,
                      (BRAKE1, ANVIL2, BRAKE2, ANVIL1, LOG_HI, BRAKE1, ANVIL3)[s], 78 if s == 0 else 58)
    phrase(S, 'lead', 'C', 15, THEME_MECH, vel=96, bright=0.68, human=hum, legato=0.85)
    phrase(S, 'vln_sus', 'C', 19, THEME, vel=82, transpose=-12, human=hum)
    phrase(S, 'trb_stac', 'C', 23, THEME, vel=84, transpose=-24, human=hum)
    phrase(S, 'lead', 'C', 27, invert(leitmotiv('G', 'harm')), vel=98, bright=0.7, human=hum)
    ring_arp(S, 'glock', 'C', 27, 8, H4, n('G4'), n('D6'), vel=62, step=0.25)
    for b in range(4):
        S.add('kit', 'C', 31 + b, 0, .3, FRAME_LO, 110)
        S.add('kit', 'C', 31 + b, 1.5, .3, FRAME_LO, 96)
        S.add('kit', 'C', 31 + b, 2.5, .3, FRAME_LO, 104)
    S.add('riser', 'C', 31, 0, 16, n('G1'), 92)
    S.add('kit', 'C', 31, 0, 16, SWELL4, 94)

    # ---------------------------------------------------------- D (32 Takte)
    crash(S, 'kit', 'D', 0, 104)
    S.add('drone', 'D', 0, 0, 16, n('G1'), 104, bright=0.5, aux=3.6)
    S.add('choir', 'D', 0, 0, 16, n('G3'), 78, bright=0.44, aux=0)
    phrase(S, 'lead', 'D', 0, THEME, vel=96, bright=0.64, human=hum)
    phrase(S, 'vln_sus', 'D', 0, THEME, vel=84, transpose=-12, human=hum)
    phrase(S, 'glock', 'D', 0, THEME, vel=78, transpose=12, human=hum, legato=1.1)
    ring_arp(S, 'glock', 'D', 0, 8, H2, n('G4'), n('D6'), vel=60, step=0.25)
    pad(S, 'pad', 'D', 0, repeat_to(H2, 8), vel=58, center=n('G4'), size=4, bright=0.44)
    bassline(S, 'bass', 'D', 0, repeat_to(H2, 8), 'drive', vel=98, bright=0.64)
    drums(S, 'kit', 'D', 0, 8, 'industrial', vel=94, human=hum, fill='timp')
    stutter(S, 'kit', 'D', 0, 8, BRAKE1, 82)

    crash(S, 'kit', 'D', 8, 98)
    phrase(S, 'lead', 'D', 8, SECOND, vel=94, bright=0.62, human=hum)
    phrase(S, 'glock', 'D', 8, SECOND, vel=76, transpose=12, human=hum, legato=1.1)
    pad(S, 'pad', 'D', 8, repeat_to(H3, 8), vel=58, center=n('G4'), size=4, bright=0.46)
    bassline(S, 'bass', 'D', 8, repeat_to(H3, 8), 'drive', vel=96, bright=0.62)
    drums(S, 'kit', 'D', 8, 8, 'industrial', vel=92, human=hum, fill='snare')
    ring_arp(S, 'glock', 'D', 8, 8, H3, n('G4'), n('D6'), vel=58, step=0.25)

    for b in range(16, 32):                             # Takte 16–31: alle Maschinen
        S.add('kit', 'D', b, 0, .4, TIMP_LO, 104)
        S.add('kit', 'D', b, 2, .4, FRAME_LO, 96)
        stutter(S, 'kit', 'D', b, 1, ANVIL1, 78 + ((b - 16) % 4) * 4, period=3.5)
    phrase(S, 'lead', 'D', 16, invert(leitmotiv('G', 'min')), vel=98, bright=0.68, human=hum)
    phrase(S, 'vln_sus', 'D', 16, invert(leitmotiv('G', 'min')), vel=86, transpose=-12, human=hum)
    phrase(S, 'glock', 'D', 24, fragment(mechanize(leitmotiv('G', 'min', part='head'), 0.25), 0, 64),
           vel=80, transpose=12, human=hum, legato=0.9)
    ring_arp(S, 'glock', 'D', 16, 16, H5, n('G4'), n('Eb6'), vel=60, step=0.25)
    pad(S, 'pad', 'D', 16, repeat_to(H5, 16), vel=60, center=n('G4'), size=4, bright=0.5)
    bassline(S, 'bass', 'D', 16, repeat_to(H5, 16), 'drive', vel=100, bright=0.7)
    drums(S, 'kit', 'D', 16, 16, 'industrial', vel=96, human=hum, fill='roll')
    S.add('riser', 'D', 28, 0, 16, n('G1'), 90)
    S.add('kit', 'D', 28, 0, 16, SWELL4, 92)

    # ---------------------------------------------------------- E (27 Takte)
    # Die Maschinen fallen nacheinander aus; das Stottern bleibt stehen.
    crash(S, 'kit', 'E', 0, 88)
    S.add('drone', 'E', 0, 0, 16, n('G1'), 96, bright=0.4, aux=3.2)
    for bar, k in grid(24, 4):                          # Ausfall: Layer verschwinden
        decay = 1.0 - bar / 24.0
        if bar < 16:
            pad(S, 'pad', 'E', bar, repeat_to(H5, k), vel=int(30 + 24 * decay), center=n('G3'),
                size=3, bright=0.2 + 0.2 * decay)
            bassline(S, 'bass', 'E', bar, repeat_to(H5, k), 'drive' if bar < 8 else 'roots',
                     vel=int(80 + 12 * decay), bright=0.4 + 0.2 * decay)
        for i in range(k):
            stutter(S, 'kit', 'E', bar + i, 1, ANVIL1 if bar < 12 else WOOD, int(50 + 28 * decay))
    phrase(S, 'lead', 'E', 0, fragment(THEME, 0, 12), vel=86, bright=0.5, human=hum)
    phrase(S, 'glock', 'E', 4, fragment(THEME, 12, 12), vel=70, transpose=12, human=hum, legato=1.2)
    phrase(S, 'lead', 'E', 8, fragment(invert(leitmotiv('G', 'min')), 0, 16), vel=78, bright=0.44,
           human=hum)
    drums(S, 'kit', 'E', 0, 8, 'industrial', vel=76, human=hum)
    ring_arp(S, 'glock', 'E', 0, 8, H1, n('G4'), n('D6'), vel=52, step=0.5)

    for b in range(16, 24):                             # Takte 16–23: nur noch Mechanik
        S.add('kit', 'E', b, 0, .3, TIMP_LO, 88)
        stutter(S, 'kit', 'E', b, 1, BRAKE_SUSP, 62, period=3.5)
    for b in range(24, 27):                             # Takte 24–26: Abriss
        S.add('kit', 'E', b, 0, .5, TIMP_LO, 112)
        S.add('kit', 'E', b, 2, .5, TIMP_LO, 106)
        for p in close('Gm', n('G2'), 3):
            S.add('vln_sus', 'E', b, 0, 2.0, p, 96)
            S.add('vc_sus', 'E', b, 0, 2.0, p - 12, 96)
    S.add('riser', 'E', 23, 0, 16, n('G1'), 96)
    S.add('kit', 'E', 23, 0, 16, SWELL4, 98)
    S.add('kit', 'E', 24, 0, 12, SNARE_ROLL, 98)

    # ---------------------------------------------------------- Ankündigung (1,25 s)
    S.add('kit', 'tail', 0, 0, 2.5, TIMP_LO, 127)
    S.add('kit', 'tail', 0, 0, 2.5, CLASH, 116)
    S.add('boom', 'tail', 0, 0, 2.5, n('G1'), 112)
    for p in close('Gm', n('G2'), 4):
        S.add('trb_sus', 'tail', 0, 0, 1.2, p, 116)
        S.add('tuba', 'tail', 0, 0, 1.2, p - 12, 108)
    S.add('kit', 'tail', 0, 0, 1.2, TIMP_LO, 112)

    mixspec = {
        'kit':      {'engine': 'sfz', 'inst': 'kit', 'gain': -0.5, 'rev': 0.18},
        'vln_sus':  {'engine': 'sfz', 'inst': 'vln_sus', 'gain': -6.0, 'pan': -0.2, 'rev': 0.26},
        'vc_sus':   {'engine': 'sfz', 'inst': 'vc_sus', 'gain': -6.0, 'pan': 0.16, 'rev': 0.26},
        'glock':    {'engine': 'sfz', 'inst': 'glock', 'gain': -9.0, 'pan': 0.3, 'rev': 0.3, 'dly': 0.16},
        'trb_stac': {'engine': 'sfz', 'inst': 'trb_stac', 'gain': -5.0, 'pan': 0.14, 'rev': 0.18},
        'trb_sus':  {'engine': 'sfz', 'inst': 'trb_sus', 'gain': -5.0, 'pan': 0.14, 'rev': 0.22},
        'tuba':     {'engine': 'sfz', 'inst': 'tuba', 'gain': -4.0, 'pan': -0.06, 'rev': 0.14},
        'lead':     {'engine': 'cs', 'instr': 'lead', 'gain': -2.0, 'pan': -0.08, 'rev': 0.2, 'dly': 0.16},
        'pluck':    {'engine': 'cs', 'instr': 'pluck', 'gain': -11.0, 'pan': 0.26, 'rev': 0.3, 'dly': 0.2},
        'pad':      {'engine': 'cs', 'instr': 'pad', 'gain': -10.0, 'rev': 0.36, 'hp': 120, 'width': 1.2},
        'choir':    {'engine': 'cs', 'instr': 'choir', 'gain': -7.0, 'rev': 0.44, 'hp': 150, 'width': 1.3},
        'bass':     {'engine': 'cs', 'instr': 'bass', 'gain': -1.5, 'lp': 2900},
        'drone':    {'engine': 'cs', 'instr': 'drone', 'gain': -5.0, 'rev': 0.2, 'lp': 3000},
        'riser':    {'engine': 'cs', 'instr': 'riser', 'gain': -9.0, 'rev': 0.18},
        'boom':     {'engine': 'cs', 'instr': 'boom', 'gain': -5.0, 'rev': 0.12},
    }
    return song, mixspec, {'file': 'level8', 'title': 'Level 8 – Maschinenherz', 'reverb': 2.3}
