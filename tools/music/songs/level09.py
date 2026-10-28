"""Level 9 – Schwarmstock: wimmelnd, vielstimmig, aufgeladen.

a-Moll · 146 BPM. Der Schwarm ist ein Chor aus verstimmten Sägezähnen in drei
Lagen; darin tauchen die Motive der früheren Level auf, jeweils in die Tonart des
Schwarms gerückt: Level 1 mixolydisch (G), Level 2 phrygisch (Bb), Level 5 als
Achtelostinato, Level 6 als Phasing-Arpeggio. Im Finale singt der Chor die
gedehnte Königin-Fassung.

Form: A 34 · B 38 · C 36 · D 33 · E 28 Takte. Miniboss bei Levelzeit 146 s =
Takt 16 von C.
"""
from __future__ import annotations

from score import Song, n
from songs._kit import (lead_in, BRAKE1, CLASH, CRASH, FRAME_HI, FRAME_LO, GONG, Human, LOG_HI, SNARE_ROLL,
                        SWELL4, TIMP_LO, TIMP_ROLL_LO, TOM_LO, arp, bassline, close, crash, drums,
                        grid, pad, phrase, repeat_to, voicing)
from songs._themes import (augment, fragment, invert, leitmotiv, mechanize, second_theme,
                           transposed)

BPM = 146

# ------------------------------------------------------------------ Harmonik
HMIX = ['A', 'G', 'D', 'A']            # Mixolydisch: das große G
HPHR = ['Am', 'Bb', 'Am', 'E7']        # Phrygisch: das kleine B
H1 = ['Am', 'G', 'F', 'E7']
H2 = ['Am', 'Bb', 'F', 'E7']
H3 = ['Dm', 'Am', 'Bb', 'E7']
H4 = ['C', 'G', 'Am', 'E7']
HMINI = ['Am', 'Bb', 'Am', 'Bb']

# ------------------------------------------------------------------ Motive
# Level-1-Thema in den Schwarm gerückt (mixolydisch), Level-2-Thema phrygisch.
Q1 = leitmotiv('A', 'mixo')
Q1_HEAD = leitmotiv('A', 'mixo', part='head')
Q2 = leitmotiv('A', 'phryg')
Q2_TAIL = leitmotiv('A', 'phryg', part='tail')
Q3 = second_theme('A', 'min')
QUEEN = augment(leitmotiv('A', 'min'), 2.0)          # 16 Takte, gedehnt
BUZZ = mechanize(leitmotiv('A', 'min', part='head'), 0.125)[:128]        # 4 Takte 32tel
STING = [('A5', .25), (None, .75), ('Bb5', .25), (None, .75),
         ('A5', .25), (None, .5), ('G5', .25), (None, 1.0)]               # 1 Takt


def swarm_pad(S: Song, part: str, sec: str, bar0: int, bars: int, ch: list[str], vel: int,
              center: int, bright: float) -> None:
    pad(S, part, sec, bar0, repeat_to(ch, bars), vel=vel, center=center, size=4, bright=bright)


def ostinato(S: Song, part: str, sec: str, bar0: int, bars: int, ch: list[str], vel: int = 90,
             offsets=(0, 7, 0, 12), dur: float = .3) -> None:
    """Achtelostinato (Zitat aus Level 5)."""
    for b in range(bars):
        root = voicing(ch[b % len(ch)], n('A1'), n('A2'))[0]
        for s in range(8):
            S.add(part, sec, bar0 + b, s * 0.5, dur, root + offsets[s % 4], vel if s % 2 == 0 else int(vel * 0.78))


def phased(S: Song, part: str, sec: str, bar0: int, bars: int, pool: list[int], stride: int,
           vel: int = 54, step: float = 0.25) -> None:
    """Phasing-Arpeggio (Zitat aus Level 6)."""
    steps = int(round(bars * 4 / step))
    for i in range(steps):
        S.add(part, sec, bar0, i * step, step * 0.9, pool[(i * stride) % len(pool)],
              vel if i % 4 == 0 else int(vel * 0.8))


def build():
    song = Song.for_level(9, BPM)
    hum = Human(909)
    S = song
    pool = [n(x) for x in ('A4', 'C5', 'E5', 'G5', 'Bb5', 'D6', 'E6', 'A6')]

    # ---------------------------------------------------------- Intro (2,2 s)
    for i, p in enumerate((n('A1'), n('E2'), n('A2'), n('Bb2'), n('A2'), n('E2'))):
        S.add('drone', 'intro', 0, i * 0.6, 2.4, p, 84 - i * 3, bright=0.45, aux=3.4)
    S.add('boom', 'intro', 0, 0, 3, n('A1'), 78)
    S.add('kit', 'intro', 0, 0, 3, TIMP_LO, 96)

    # ---------------------------------------------------------- A (34 Takte)
    # Der Schwarm sammelt sich; das Level-1-Motiv taucht auf.
    S.add('drone', 'A', 0, 0, 16, n('A1'), 96, bright=0.45, aux=3.4)
    swarm_pad(S, 'pad', 'A', 0, 8, HMIX, 52, n('A3'), 0.3)
    for b in range(8):
        S.add('glass', 'A', b, 2.5, .8, n('E6') if b % 2 else n('A6'), 42)
        S.add('kit', 'A', b, 0, .5, TIMP_LO, 88)
    arp(S, 'pluck', 'A', 4, repeat_to(HMIX, 4), step=0.125, low=n('A4'), high=n('A6'), vel=40, human=hum)

    phrase(S, 'lead', 'A', 8, Q1_HEAD, vel=84, bright=0.5, human=hum)
    phrase(S, 'vln_sus', 'A', 8, Q1_HEAD, vel=70, transpose=-12, human=hum)
    swarm_pad(S, 'pad', 'A', 8, 8, HMIX, 54, n('A4'), 0.34)
    swarm_pad(S, 'pad2', 'A', 8, 8, HMIX, 48, n('E3'), 0.3)
    bassline(S, 'bass', 'A', 8, repeat_to(HMIX, 8), 'drive', vel=86, bright=0.46)
    drums(S, 'kit', 'A', 8, 8, 'tribal', vel=78, human=hum)

    phrase(S, 'lead', 'A', 16, Q1, vel=88, bright=0.54, human=hum)
    phrase(S, 'vln_spic', 'A', 16, mechanize(Q1_HEAD, 0.5)[:32], vel=68, human=hum)
    swarm_pad(S, 'pad', 'A', 16, 8, H1, 56, n('A4'), 0.38)
    swarm_pad(S, 'pad2', 'A', 16, 8, H1, 50, n('E3'), 0.34)
    bassline(S, 'bass', 'A', 16, repeat_to(H1, 8), 'drive', vel=92, bright=0.5)
    arp(S, 'pluck', 'A', 16, repeat_to(H1, 8), step=0.25, low=n('A4'), high=n('A6'), vel=42, human=hum)
    drums(S, 'kit', 'A', 16, 8, 'tribal', vel=84, human=hum, fill='timp')

    for b in range(24, 34):                             # Takte 24–33: Verdichtung
        S.add('kit', 'A', b, 0, .4, FRAME_LO, 96)
        S.add('kit', 'A', b, 1.5, .3, FRAME_HI, 86)
        S.add('kit', 'A', b, 2.5, .4, FRAME_LO, 92)
        S.add('kit', 'A', b, 3.5, .2, LOG_HI, 74)
    phrase(S, 'vln_spic', 'A', 24, ostinato_notes(Q2_TAIL), vel=84, human=hum)
    swarm_pad(S, 'pad', 'A', 24, 10, H2, 58, n('A4'), 0.42)
    bassline(S, 'bass', 'A', 24, repeat_to(H2, 10), 'drive', vel=94, bright=0.54)
    drums(S, 'kit', 'A', 24, 10, 'tribal', vel=90, human=hum, fill='roll')
    S.add('riser', 'A', 31, 0, 12, n('A1'), 76)
    S.add('kit', 'A', 31, 0, 12, SWELL4, 82)

    # ---------------------------------------------------------- B (38 Takte)
    crash(S, 'kit', 'B', 0, 92)
    S.add('drone', 'B', 0, 0, 16, n('A1'), 104, bright=0.55, aux=3.8)
    phrase(S, 'lead', 'B', 0, Q2, vel=92, bright=0.58, human=hum)
    phrase(S, 'vln_sus', 'B', 0, Q2, vel=78, transpose=-12, human=hum)
    swarm_pad(S, 'pad', 'B', 0, 8, HPHR, 58, n('A4'), 0.42)
    swarm_pad(S, 'pad2', 'B', 0, 8, HPHR, 52, n('E3'), 0.38)
    bassline(S, 'bass', 'B', 0, repeat_to(HPHR, 8), 'drive', vel=94, bright=0.54)
    drums(S, 'kit', 'B', 0, 8, 'tribal', vel=90, human=hum, fill='timp')

    crash(S, 'kit', 'B', 8, 88)
    phrase(S, 'lead', 'B', 8, Q3, vel=90, bright=0.56, human=hum)
    phrase(S, 'vln_spic', 'B', 8, Q3, vel=74, transpose=12, human=hum)
    swarm_pad(S, 'pad', 'B', 8, 8, H3, 56, n('A4'), 0.4)
    bassline(S, 'bass', 'B', 8, repeat_to(H3, 8), 'drive', vel=92, bright=0.52)
    drums(S, 'kit', 'B', 8, 8, 'tribal', vel=88, human=hum, fill='snare')
    arp(S, 'pluck', 'B', 8, repeat_to(H3, 8), step=0.25, low=n('A4'), high=n('A6'), vel=44, human=hum)

    # Takte 16–23: das Ostinato aus Level 5
    crash(S, 'kit', 'B', 16, 94)
    ostinato(S, 'vln_spic', 'B', 16, 8, H4, vel=94)
    ostinato(S, 'bass', 'B', 16, 8, H4, vel=96, offsets=(0, 12, 7, 12), dur=.3)
    phrase(S, 'lead', 'B', 16, invert(leitmotiv('A', 'min')), vel=94, bright=0.62, human=hum)
    swarm_pad(S, 'pad', 'B', 16, 8, H4, 58, n('A4'), 0.44)
    swarm_pad(S, 'pad2', 'B', 16, 8, H4, 52, n('A3'), 0.4)
    drums(S, 'kit', 'B', 16, 8, 'tribal', vel=92, human=hum, fill='timp')

    # Takte 24–37: Schwarm kreist, Chor setzt ein
    crash(S, 'kit', 'B', 24, 96)
    S.add('choir', 'B', 24, 0, 16, n('A3'), 76, bright=0.4, aux=0)
    phrase(S, 'lead', 'B', 24, Q1, vel=96, bright=0.64, human=hum)
    phrase(S, 'glock', 'B', 24, Q1, vel=78, transpose=12, human=hum, legato=1.1)
    phased(S, 'glock', 'B', 24, 14, pool, 5, vel=56, step=0.25)
    swarm_pad(S, 'pad', 'B', 24, 14, H2, 60, n('A4'), 0.48)
    swarm_pad(S, 'pad2', 'B', 24, 14, H2, 54, n('E3'), 0.44)
    bassline(S, 'bass', 'B', 24, repeat_to(H2, 14), 'drive', vel=96, bright=0.58)
    drums(S, 'kit', 'B', 24, 14, 'tribal', vel=94, human=hum, fill='roll')
    S.add('riser', 'B', 34, 0, 16, n('A1'), 86)
    S.add('kit', 'B', 34, 0, 16, SWELL4, 90)

    # ---------------------------------------------------------- C (36 Takte)
    # Takte 0–15: der Schwarm summt unruhig. Ab Takt 16 (= 146 s) der Miniboss.
    S.add('drone', 'C', 0, 0, 16, n('A1'), 94, bright=0.42, aux=3.2)
    swarm_pad(S, 'pad', 'C', 0, 16, HPHR, 44, n('A3'), 0.2)
    phased(S, 'pluck', 'C', 0, 16, pool, 7, vel=38, step=0.25)
    for b in range(16):
        S.add('glass', 'C', b, float(b % 4) * 0.75, .5, n('E6') if b % 3 else n('Bb5'), 40)
        S.add('kit', 'C', b, 0, .4, TIMP_LO, 74)
        if b % 2 == 1:
            S.add('kit', 'C', b, 3.5, .2, LOG_HI, 64)
    phrase(S, 'lead', 'C', 0, fragment(Q2, 0, 12), vel=76, bright=0.44, human=hum)
    phrase(S, 'vln_sus', 'C', 6, fragment(Q2, 12, 12), vel=68, transpose=-12, human=hum)
    S.add('kit', 'C', 15, 0, 4, TIMP_ROLL_LO, 90)

    # Miniboss (Takte 16–35)
    crash(S, 'kit', 'C', 16, 104)
    S.add('kit', 'C', 16, 0, .3, CLASH, 100)
    S.add('boom', 'C', 16, 0, 4, n('A1'), 106)
    for bar, k in grid(20, 4):
        b = 16 + bar
        h = repeat_to(HMINI, k)
        ostinato(S, 'vln_spic', 'C', b, k, h, vel=96, dur=.28)
        phrase_loop_sting(S, 'glock', 'C', b, k, vel=66)
        swarm_pad(S, 'pad', 'C', b, k, h, 58, n('A4'), 0.46)
        swarm_pad(S, 'pad2', 'C', b, k, h, 52, n('E3'), 0.42)
        bassline(S, 'bass', 'C', b, h, 'drive', vel=96, bright=0.56)
        drums(S, 'kit', 'C', b, k, 'tribal', vel=94, human=hum)
        for i in range(k):
            S.add('kit', 'C', b + i, 1.75, .3, BRAKE1, 80)
            S.add('kit', 'C', b + i, 3.25, .3, LOG_HI, 78)
    phrase(S, 'lead', 'C', 16, BUZZ, vel=94, bright=0.7, human=hum, legato=0.8)
    phrase(S, 'vln_sus', 'C', 20, Q1, vel=88, transpose=-12, human=hum)
    phrase(S, 'lead', 'C', 24, Q2, vel=96, bright=0.66, human=hum)
    phrase(S, 'glock', 'C', 28, Q1_HEAD, vel=82, transpose=12, human=hum, legato=1.1)
    for b in range(4):
        S.add('kit', 'C', 32 + b, 0, .5, FRAME_LO, 108)
        S.add('kit', 'C', 32 + b, 1.5, .4, FRAME_HI, 96)
        S.add('kit', 'C', 32 + b, 2.5, .5, FRAME_LO, 102)
        S.add('kit', 'C', 32 + b, 3.5, .3, TOM_LO, 92)
    S.add('riser', 'C', 32, 0, 16, n('A1'), 94)
    S.add('kit', 'C', 32, 0, 16, SWELL4, 96)

    # ---------------------------------------------------------- D (33 Takte)
    crash(S, 'kit', 'D', 0, 100)
    S.add('drone', 'D', 0, 0, 16, n('A1'), 104, bright=0.5, aux=3.6)
    S.add('choir', 'D', 0, 0, 16, n('A3'), 84, bright=0.46, aux=0)
    S.add('choir', 'D', 0, 0, 16, n('E4'), 74, bright=0.38, aux=1)
    phrase(S, 'lead', 'D', 0, Q1, vel=94, bright=0.6, human=hum)
    phrase(S, 'vln_sus', 'D', 0, Q1, vel=82, transpose=-12, human=hum)
    phased(S, 'glock', 'D', 0, 8, pool, 3, vel=58, step=0.25)
    phased(S, 'pluck', 'D', 0, 8, pool, 5, vel=42, step=0.25)
    swarm_pad(S, 'pad', 'D', 0, 8, HMIX, 58, n('A4'), 0.46)
    bassline(S, 'bass', 'D', 0, repeat_to(HMIX, 8), 'drive', vel=96, bright=0.56)
    drums(S, 'kit', 'D', 0, 8, 'tribal', vel=94, human=hum, fill='timp')

    crash(S, 'kit', 'D', 8, 96)
    phrase(S, 'lead', 'D', 8, Q3, vel=92, bright=0.58, human=hum)
    phrase(S, 'glock', 'D', 8, Q3, vel=78, transpose=12, human=hum, legato=1.1)
    swarm_pad(S, 'pad', 'D', 8, 8, H3, 58, n('A4'), 0.46)
    swarm_pad(S, 'pad2', 'D', 8, 8, H3, 52, n('E3'), 0.42)
    bassline(S, 'bass', 'D', 8, repeat_to(H3, 8), 'drive', vel=94, bright=0.54)
    drums(S, 'kit', 'D', 8, 8, 'tribal', vel=92, human=hum, fill='snare')

    for b in range(16, 33):                             # Takte 16–32: alles kreist
        S.add('kit', 'D', b, 0, .45, FRAME_LO, 100 + (b % 4) * 3)
        S.add('kit', 'D', b, 2, .45, FRAME_LO, 96 + (b % 4) * 3)
        S.add('kit', 'D', b, 3.25, .3, BRAKE1, 78)
    phrase(S, 'lead', 'D', 16, invert(leitmotiv('A', 'min')), vel=98, bright=0.66, human=hum)
    phrase(S, 'vln_sus', 'D', 16, invert(leitmotiv('A', 'min')), vel=86, transpose=-12, human=hum)
    phrase(S, 'glock', 'D', 24, fragment(mechanize(Q1_HEAD, 0.25), 0, 32), vel=82, transpose=12,
           human=hum, legato=0.9)
    ostinato(S, 'vln_spic', 'D', 16, 16, H4, vel=96, dur=.26)
    swarm_pad(S, 'pad', 'D', 16, 16, H4, 60, n('A4'), 0.5)
    swarm_pad(S, 'pad2', 'D', 16, 16, H4, 54, n('A3'), 0.46)
    bassline(S, 'bass', 'D', 16, repeat_to(H4, 16), 'drive', vel=98, bright=0.6)
    drums(S, 'kit', 'D', 16, 16, 'tribal', vel=96, human=hum, fill='roll')
    S.add('riser', 'D', 30, 0, 12, n('A1'), 90)
    S.add('kit', 'D', 30, 0, 12, SWELL4, 94)

    # ---------------------------------------------------------- E (28 Takte)
    # Die Königin: der Chor singt das Thema gedehnt, der Schwarm fällt zurück.
    crash(S, 'kit', 'E', 0, 92)
    S.add('drone', 'E', 0, 0, 16, n('A1'), 100, bright=0.44, aux=3.0)
    S.add('choir', 'E', 0, 0, 16, n('A3'), 92, bright=0.5, aux=0)
    S.add('choir', 'E', 0, 0, 16, n('E4'), 82, bright=0.42, aux=1)
    phrase(S, 'vln_sus', 'E', 0, QUEEN, vel=86, human=hum)
    swarm_pad(S, 'pad', 'E', 0, 16, H4, 52, n('A4'), 0.38)
    ostinato(S, 'vln_spic', 'E', 0, 16, H4, vel=76, dur=.26)
    bassline(S, 'bass', 'E', 0, repeat_to(H4, 16), 'half', vel=88, bright=0.44)
    drums(S, 'kit', 'E', 0, 8, 'tribal', vel=84, human=hum)

    for b in range(16, 24):                             # Takte 16–23: Schwarm verhallt
        S.add('kit', 'E', b, 0, .4, FRAME_LO, 88 - (b - 16) * 3)
        if b < 20:
            S.add('kit', 'E', b, 2, .4, FRAME_HI, 82 - (b - 16) * 3)
    phrase(S, 'glock', 'E', 16, fragment(Q1, 0, 12), vel=72, transpose=12, human=hum, legato=1.4)
    phrase(S, 'lead', 'E', 18, fragment(Q1, 12, 12), vel=76, bright=0.4, human=hum)
    swarm_pad(S, 'pad', 'E', 16, 8, H1, 50, n('A3'), 0.3)
    bassline(S, 'bass', 'E', 16, repeat_to(H1, 8), 'roots', vel=82, bright=0.36)

    for b in range(24, 28):                             # Takte 24–27: Abriss
        S.add('kit', 'E', b, 0, .5, TIMP_LO, 112)
        S.add('kit', 'E', b, 2, .5, TIMP_LO, 106)
        for p in close('Am', n('A2'), 3):
            S.add('vln_sus', 'E', b, 0, 2.0, p, 96)
    S.add('riser', 'E', 22, 0, 24, n('A1'), 96)
    S.add('kit', 'E', 22, 0, 24, SWELL4, 100)
    S.add('kit', 'E', 23, 0, 20, SNARE_ROLL, 96)
    S.add('drone', 'E', 24, 0, 4, n('Bb2'), 100, bright=0.7, aux=4.2)

    # ---------------------------------------------------------- Ankündigung (1,25 s): Auftakt
    # Kein Schlussakkord: Wirbel und Basshinführung münden auf dem nächsten Schlag in die
    # Bossmusik (boss9, Grundton A), die genau dann mit der Ankunft des Bosses einsetzt.
    leadin_spec = lead_in(S, 'A')

    mixspec = {
        'kit':      {'engine': 'sfz', 'inst': 'kit', 'gain': -1.0, 'rev': 0.2},
        'vln_sus':  {'engine': 'sfz', 'inst': 'vln_sus', 'gain': -5.5, 'pan': -0.22, 'rev': 0.28},
        'vln_spic': {'engine': 'sfz', 'inst': 'vln_spic', 'gain': -6.0, 'pan': -0.3, 'rev': 0.22},
        'glock':    {'engine': 'sfz', 'inst': 'glock', 'gain': -9.5, 'pan': 0.3, 'rev': 0.32, 'dly': 0.18},
        'pad':      {'engine': 'cs', 'instr': 'pad', 'gain': -11.0, 'rev': 0.4, 'hp': 130, 'width': 1.35},
        'pad2':     {'engine': 'cs', 'instr': 'pad', 'gain': -9.0, 'rev': 0.42, 'hp': 100, 'width': 1.4},
        'choir':    {'engine': 'cs', 'instr': 'choir', 'gain': -4.5, 'rev': 0.46, 'hp': 140, 'width': 1.3},
        'lead':     {'engine': 'cs', 'instr': 'lead', 'gain': -2.0, 'pan': -0.06, 'rev': 0.24, 'dly': 0.16},
        'pluck':    {'engine': 'cs', 'instr': 'pluck', 'gain': -11.0, 'pan': 0.28, 'rev': 0.34, 'dly': 0.22},
        'glass':    {'engine': 'cs', 'instr': 'glass', 'gain': -13.0, 'pan': -0.28, 'rev': 0.46, 'dly': 0.24},
        'bass':     {'engine': 'cs', 'instr': 'bass', 'gain': -1.5, 'lp': 2700},
        'drone':    {'engine': 'cs', 'instr': 'drone', 'gain': -4.0, 'rev': 0.24, 'lp': 3000},
        'riser':    {'engine': 'cs', 'instr': 'riser', 'gain': -9.0, 'rev': 0.2},
        'boom':     {'engine': 'cs', 'instr': 'boom', 'gain': -5.0, 'rev': 0.14},
    }
    mixspec.update(leadin_spec)
    return song, mixspec, {'file': 'level9', 'title': 'Level 9 – Schwarmstock', 'reverb': 2.5}


def ostinato_notes(mel) -> list[tuple[str | None, float]]:
    """Melodie in Achtelwiederholungen umsetzen (Staccatokette)."""
    out = []
    for p, d in mel:
        if p is None:
            out.append((None, d))
            continue
        steps = max(1, int(round(d / 0.5)))
        for _ in range(steps):
            out.append((p, 0.5))
    return out


def phrase_loop_sting(S: Song, part: str, sec: str, bar0: int, bars: int, vel: int) -> None:
    """Kurzer Glockenruf am Taktanfang des Miniboss-Vamps."""
    for b in range(bars):
        S.add(part, sec, bar0 + b, 0, .5, n('A6'), vel)
        S.add(part, sec, bar0 + b, 2, .5, n('E6') if b % 2 else n('Bb6'), vel - 8)
