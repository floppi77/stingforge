"""Level 5 – Dornen im Sturm: hetzend, ruppig, mit Blech und Wind.

e-Moll harmonisch (mit D#) · 150 BPM. Streicherostinato in Achteln, tiefe
Blechstöße und ein Frage-Antwort-Kanon zweier Stimmen im Abstand von
eineinhalb Schlägen. Der Sturm heult als gefiltertes Rauschen dazwischen.

Form: A 34 · B 38 · C 38 · D 35 · E 29 Takte. Miniboss bei Levelzeit 142 s =
Takt 18 von C. Am Ende kreuzen sich beide Stimmen und landen gemeinsam auf E.
"""
from __future__ import annotations

from score import Song, n
from songs._kit import (lead_in, CLASH, CRASH, FRAME_HI, FRAME_LO, GONG, Human, SNARE_ROLL, SWELL4,
                        TIMP_LO, TIMP_MID, TIMP_ROLL_LO, TOM_LO, arp, bassline, close, crash,
                        drums, grid, pad, phrase, repeat_to, voicing)
from songs._themes import fragment, invert, leitmotiv, mechanize, second_theme

BPM = 150

# ------------------------------------------------------------------ Harmonik
H1 = ['Em', 'Em', 'C', 'B7']
H2 = ['Em', 'Am', 'B7', 'Em']
H3 = ['C', 'B7', 'Em', 'Am']
H4 = ['Am', 'Em', 'C', 'B7']
H5 = ['Em', 'C', 'Am', 'B7']
HMINI = ['Em', 'C', 'B7', 'Em']

# ------------------------------------------------------------------ Motive
THEME = leitmotiv('E', 'harm')                       # 8 Takte
THEME_HEAD = leitmotiv('E', 'harm', part='head')
THEME_TAIL = leitmotiv('E', 'harm', part='tail')
SECOND = second_theme('E', 'harm')
CALL = [('E5', 1), ('F#5', .5), ('G5', .5), ('A5', 1), ('B5', 1)]          # 1 Takt Frage
ANSWER = [('B5', 1), ('A5', .5), ('G5', .5), ('F#5', 1), ('E5', 1)]        # 1 Takt Antwort
STOSS = [('E2', .5), ('E3', .5), (None, .5), ('E2', .5),
         (None, .5), ('E2', .5), ('E3', .5), (None, .5)]                   # 1 Takt Blechstoß


def ostinato(S: Song, part: str, sec: str, bar0: int, bars: int, ch: list[str], vel: int = 88,
             offsets=(0, 7, 0, 12), dur: float = .42) -> None:
    """Achtel-Ostinato: Grundton, Quinte, Grundton, Oktave – je Takt."""
    for b in range(bars):
        root = voicing(ch[b % len(ch)], n('E2'), n('E3'))[0]
        for s in range(8):
            p = root + offsets[s % 4]
            S.add(part, sec, bar0 + b, s * 0.5, dur, p, vel if s % 2 == 0 else int(vel * 0.78))


def blech(S: Song, part: str, sec: str, bar0: int, bars: int, ch: list[str], vel: int = 92,
          dur: float = .5) -> None:
    """Tiefe Blechstöße auf 1 und 3, kurz und trocken."""
    for b in range(bars):
        for beat in (0, 2, 3.5):
            for p in close(ch[b % len(ch)], n('E2'), 3):
                S.add(part, sec, bar0 + b, beat, dur, p, vel if beat == 0 else int(vel * 0.8))


def build():
    song = Song.for_level(5, BPM)
    hum = Human(505)
    S = song

    # ---------------------------------------------------------- Intro (2,2 s)
    S.add('wind', 'intro', 0, 0, 4, n('E4'), 84, bright=0.6)
    S.add('kit', 'intro', 0, 0, 3, TIMP_LO, 96)
    S.add('boom', 'intro', 0, 0, 3, n('E2'), 72)
    for p in close('Em', n('E2'), 3):
        S.add('vc_sus', 'intro', 0, 0, 3.6, p, 78)

    # ---------------------------------------------------------- A (34 Takte)
    S.add('wind', 'A', 0, 0, 16, n('E4'), 92, bright=0.55)
    pad(S, 'vc_sus', 'A', 0, repeat_to(H1, 8), vel=56, center=n('E2'), size=3, bright=0.3)
    for b in range(8):
        S.add('kit', 'A', b, 0, .8, TIMP_LO, 88 + (b % 3) * 4)
    ostinato(S, 'vln_spic', 'A', 8, 8, H2, vel=84)
    bassline(S, 'bass', 'A', 8, repeat_to(H2, 8), 'drive', vel=84, bright=0.4)
    pad(S, 'vla_sus', 'A', 8, repeat_to(H2, 8), vel=58, center=n('E3'), size=3, bright=0.34)
    drums(S, 'kit', 'A', 8, 8, 'power', vel=76, human=hum, fill='timp')

    blech(S, 'trb_stac', 'A', 16, 4, H3, vel=92)
    blech(S, 'tuba', 'A', 16, 4, H3, vel=84, dur=.6)
    phrase(S, 'vla_sus', 'A', 16, THEME_HEAD, vel=78, human=hum)
    ostinato(S, 'vln_spic', 'A', 16, 4, H3, vel=88)
    pad(S, 'vc_sus', 'A', 16, repeat_to(H3, 4), vel=56, center=n('E2'), size=3, bright=0.34)
    bassline(S, 'bass', 'A', 16, repeat_to(H3, 4), 'drive', vel=88, bright=0.44)
    drums(S, 'kit', 'A', 16, 4, 'power', vel=82, human=hum, fill='timp')

    for i in range(2):
        bar = 20 + i * 4
        phrase(S, 'vla_sus', 'A', bar, CALL + ANSWER, vel=80, human=hum)
        phrase(S, 'flute', 'A', bar + 1.375, CALL + ANSWER, vel=72, human=hum, legato=1.1)
        ostinato(S, 'vln_spic', 'A', bar, 4, H4, vel=88)
        blech(S, 'trb_stac', 'A', bar, 4, H4, vel=88)
        blech(S, 'tuba', 'A', bar, 4, H4, vel=82, dur=.6)
        pad(S, 'vc_sus', 'A', bar, repeat_to(H4, 4), vel=56, center=n('E2'), size=3, bright=0.36)
        bassline(S, 'bass', 'A', bar, repeat_to(H4, 4), 'drive', vel=90, bright=0.46)
        drums(S, 'kit', 'A', bar, 4, 'power', vel=84, human=hum, fill='timp')

    S.add('wind', 'A', 28, 0, 6, n('B4'), 104, bright=0.8)
    ostinato(S, 'vln_spic', 'A', 28, 6, H1, vel=94)
    for b in range(6):
        S.add('kit', 'A', 28 + b, 0, .6, FRAME_LO, 100 + b * 2)
        S.add('kit', 'A', 28 + b, 2.5, .4, FRAME_HI, 88 + b * 2)
    phrase(S, 'lead', 'A', 28, fragment(leitmotiv('E', 'harm'), 0, 8), vel=92, bright=0.6, human=hum)
    pad(S, 'vla_sus', 'A', 28, repeat_to(H1, 6), vel=62, center=n('E3'), size=4, bright=0.5)
    bassline(S, 'bass', 'A', 28, repeat_to(H1, 6), 'pulse', vel=94, bright=0.5)
    drums(S, 'kit', 'A', 28, 6, 'power', vel=92, human=hum, fill='roll')
    S.add('riser', 'A', 31, 0, 12, n('E2'), 70)
    S.add('kit', 'A', 32, 0, 8, SWELL4, 80)

    # ---------------------------------------------------------- B (38 Takte)
    crash(S, 'kit', 'B', 0, 92)
    S.add('wind', 'B', 0, 0, 16, n('E4'), 96, bright=0.62)
    phrase(S, 'vla_sus', 'B', 0, THEME, vel=88, human=hum)
    ostinato(S, 'vln_spic', 'B', 0, 8, H2, vel=92)
    blech(S, 'trb_stac', 'B', 0, 8, H2, vel=94)
    blech(S, 'tuba', 'B', 0, 8, H2, vel=86, dur=.6)
    pad(S, 'vc_sus', 'B', 0, repeat_to(H2, 8), vel=58, center=n('E2'), size=3, bright=0.4)
    bassline(S, 'bass', 'B', 0, repeat_to(H2, 8), 'drive', vel=94, bright=0.5)
    drums(S, 'kit', 'B', 0, 8, 'power', vel=90, human=hum, fill='timp')

    # Takte 8–15: Kanon – dieselbe Melodie 1½ Schläge versetzt
    crash(S, 'kit', 'B', 8, 88)
    phrase(S, 'flute', 'B', 8, SECOND, vel=86, human=hum)
    phrase(S, 'vla_sus', 'B', 8.375, SECOND, vel=82, transpose=-12, human=hum)
    phrase(S, 'lead', 'B', 8.75, fragment(SECOND, 0, 12), vel=78, bright=0.5, human=hum)
    ostinato(S, 'vln_spic', 'B', 8, 8, H3, vel=92)
    blech(S, 'trb_stac', 'B', 8, 8, H3, vel=92)
    pad(S, 'vc_sus', 'B', 8, repeat_to(H3, 8), vel=58, center=n('E2'), size=4, bright=0.42)
    bassline(S, 'bass', 'B', 8, repeat_to(H3, 8), 'drive', vel=92, bright=0.48)
    drums(S, 'kit', 'B', 8, 8, 'power', vel=88, human=hum, fill='snare')

    # Takte 16–23: Kreuzung der Stimmen, Blech und Streicher im Wechsel
    crash(S, 'kit', 'B', 16, 94)
    blech(S, 'trb_stac', 'B', 16, 8, H4, vel=96)
    blech(S, 'tuba', 'B', 16, 8, H4, vel=88, dur=.6)
    blech(S, 'tpt_stac', 'B', 16, 8, H4, vel=82, dur=.35)
    ostinato(S, 'vln_spic', 'B', 16, 8, H4, vel=94)
    phrase(S, 'lead', 'B', 16, THEME, vel=96, bright=0.65, human=hum)
    phrase(S, 'flute', 'B', 20, THEME_TAIL, vel=84, transpose=12, human=hum)
    phrase(S, 'vla_sus', 'B', 20, THEME_TAIL, vel=86, transpose=-12, human=hum)
    pad(S, 'vc_sus', 'B', 16, repeat_to(H4, 8), vel=60, center=n('E2'), size=4, bright=0.45)
    bassline(S, 'bass', 'B', 16, repeat_to(H4, 8), 'drive', vel=96, bright=0.52)
    drums(S, 'kit', 'B', 16, 8, 'power', vel=94, human=hum, fill='timp')

    # Takte 24–37: Steigerung mit Windböen und Tommelodien
    S.add('wind', 'B', 24, 0, 14, n('B4'), 100, bright=0.75)
    for b in range(14):
        S.add('kit', 'B', 24 + b, 0, .5, TIMP_LO, 104)
        S.add('kit', 'B', 24 + b, 2, .5, TOM_LO, 92)
        if b % 2:
            S.add('kit', 'B', 24 + b, 3.5, .3, TIMP_MID, 88)
    phrase(S, 'vla_sus', 'B', 24, mechanize(THEME_HEAD, 0.5)[:32], vel=88, human=hum)
    ostinato(S, 'vln_spic', 'B', 24, 14, H1, vel=96)
    blech(S, 'trb_stac', 'B', 28, 10, H5, vel=96, dur=.4)
    pad(S, 'vla_sus', 'B', 24, repeat_to(H1, 14), vel=62, center=n('E3'), size=4, bright=0.52)
    pad(S, 'vc_sus', 'B', 24, repeat_to(H5, 14), vel=60, center=n('E2'), size=3, bright=0.5)
    bassline(S, 'bass', 'B', 24, repeat_to(H1, 14), 'pulse', vel=96, bright=0.52)
    drums(S, 'kit', 'B', 24, 14, 'power', vel=96, human=hum, fill='roll')
    S.add('riser', 'B', 33, 0, 20, n('E2'), 86)
    S.add('kit', 'B', 32, 0, 24, SWELL4, 88)

    # ---------------------------------------------------------- C (38 Takte)
    # Takte 0–17: Wind legt sich, die Blechstöße entfernen sich.
    # Ab Takt 18 (= 142 s Levelzeit) der Dornenranken-Miniboss.
    S.add('wind', 'C', 0, 0, 18, n('E4'), 88, bright=0.45)
    ostinato(S, 'vln_spic', 'C', 0, 18, H1, vel=62)
    pad(S, 'vc_sus', 'C', 0, repeat_to(H1, 18), vel=48, center=n('E2'), size=3, bright=0.24)
    pad(S, 'vla_sus', 'C', 0, repeat_to(H1, 18), vel=46, center=n('E3'), size=3, bright=0.2)
    for b in range(0, 18, 2):
        S.add('kit', 'C', b, 0, 1.0, TIMP_LO, 72)
    phrase(S, 'flute', 'C', 2, CALL, vel=68, human=hum)
    phrase(S, 'vla_sus', 'C', 3.5, ANSWER, vel=64, transpose=-12, human=hum)
    phrase(S, 'flute', 'C', 10, fragment(leitmotiv('E', 'harm'), 0, 12), vel=68, human=hum)
    S.add('kit', 'C', 17, 0, 4, TIMP_ROLL_LO, 86)

    # Miniboss (Takte 18–37)
    crash(S, 'kit', 'C', 18, 104)
    S.add('kit', 'C', 18, 0, 2, TIMP_LO, 116)
    S.add('kit', 'C', 18, 0, .3, CLASH, 104)
    for bar, k in grid(20, 4):
        b = 18 + bar
        h = repeat_to(HMINI, k)
        ostinato(S, 'vln_spic', 'C', b, k, h, vel=96)
        blech(S, 'trb_stac', 'C', b, k, h, vel=98, dur=.4)
        blech(S, 'tuba', 'C', b, k, h, vel=90, dur=.55)
        pad(S, 'vc_sus', 'C', b, h, vel=60, center=n('E2'), size=3, bright=0.44)
        bassline(S, 'bass', 'C', b, h, 'drive', vel=96, bright=0.5)
        drums(S, 'kit', 'C', b, k, 'power', vel=96, human=hum)
        for i in range(k):
            S.add('kit', 'C', b + i, 1.75, .3, FRAME_HI, 88)
            S.add('kit', 'C', b + i, 3.25, .3, FRAME_LO, 92)
    phrase(S, 'lead', 'C', 18, THEME, vel=98, bright=0.68, human=hum)
    phrase(S, 'flute', 'C', 22, THEME, vel=84, transpose=12, human=hum)
    phrase(S, 'vla_sus', 'C', 26, invert(leitmotiv('E', 'harm')), vel=88, human=hum)
    phrase(S, 'tpt_stac', 'C', 30, fragment(mechanize(leitmotiv('E', 'min', part='head'), 0.5), 0, 24),
           vel=84, human=hum)
    S.add('riser', 'C', 34, 0, 16, n('E2'), 92)
    S.add('kit', 'C', 33, 0, 20, SWELL4, 94)

    # ---------------------------------------------------------- D (35 Takte)
    crash(S, 'kit', 'D', 0, 100)
    S.add('wind', 'D', 0, 0, 18, n('E4'), 94, bright=0.6)
    phrase(S, 'lead', 'D', 0, THEME, vel=94, bright=0.62, human=hum)
    phrase(S, 'vla_sus', 'D', 0, THEME, vel=86, transpose=-12, human=hum)
    ostinato(S, 'vln_spic', 'D', 0, 8, H2, vel=94)
    blech(S, 'trb_stac', 'D', 0, 8, H2, vel=96)
    blech(S, 'tuba', 'D', 0, 8, H2, vel=86, dur=.6)
    pad(S, 'vc_sus', 'D', 0, repeat_to(H2, 8), vel=60, center=n('E2'), size=3, bright=0.44)
    bassline(S, 'bass', 'D', 0, repeat_to(H2, 8), 'drive', vel=96, bright=0.52)
    drums(S, 'kit', 'D', 0, 8, 'power', vel=92, human=hum, fill='timp')

    crash(S, 'kit', 'D', 8, 96)
    phrase(S, 'flute', 'D', 8, SECOND, vel=88, human=hum)
    phrase(S, 'lead', 'D', 8.375, SECOND, vel=80, bright=0.5, human=hum)
    ostinato(S, 'vln_spic', 'D', 8, 8, H3, vel=94)
    blech(S, 'trb_stac', 'D', 8, 8, H3, vel=94)
    pad(S, 'vla_sus', 'D', 8, repeat_to(H3, 8), vel=60, center=n('E3'), size=4, bright=0.46)
    bassline(S, 'bass', 'D', 8, repeat_to(H3, 8), 'drive', vel=94, bright=0.5)
    drums(S, 'kit', 'D', 8, 8, 'power', vel=90, human=hum, fill='snare')

    for i in range(2):                                  # Takte 16–23: Ruf-Antwort im Kanon
        bar = 16 + i * 4
        phrase(S, 'vla_sus', 'D', bar, CALL + ANSWER, vel=86, human=hum)
        phrase(S, 'lead', 'D', bar + 0.375, CALL + ANSWER, vel=84, bright=0.6, human=hum)
        ostinato(S, 'vln_spic', 'D', bar, 4, H4, vel=94)
        blech(S, 'trb_stac', 'D', bar, 4, H4, vel=94)
        blech(S, 'tuba', 'D', bar, 4, H4, vel=86, dur=.6)
        pad(S, 'vc_sus', 'D', bar, repeat_to(H4, 4), vel=58, center=n('E2'), size=3, bright=0.46)
        bassline(S, 'bass', 'D', bar, repeat_to(H4, 4), 'drive', vel=94, bright=0.5)
        drums(S, 'kit', 'D', bar, 4, 'power', vel=92, human=hum, fill='timp')

    crash(S, 'kit', 'D', 24, 108)
    for b in range(11):
        S.add('kit', 'D', 24 + b, 0, .5, FRAME_LO, 104)
        S.add('kit', 'D', 24 + b, 2, .5, FRAME_HI, 96)
        S.add('kit', 'D', 24 + b, 3.5, .3, TOM_LO, 90)
    ostinato(S, 'vln_spic', 'D', 24, 11, H5, vel=100)
    blech(S, 'trb_stac', 'D', 24, 11, H5, vel=100, dur=.4)
    blech(S, 'tuba', 'D', 24, 11, H5, vel=92, dur=.55)
    blech(S, 'tpt_stac', 'D', 24, 11, H5, vel=84, dur=.3)
    phrase(S, 'lead', 'D', 24, invert(leitmotiv('E', 'harm')), vel=100, bright=0.7, human=hum)
    phrase(S, 'vla_sus', 'D', 24, invert(leitmotiv('E', 'harm')), vel=90, transpose=-12, human=hum)
    pad(S, 'vc_sus', 'D', 24, repeat_to(H5, 11), vel=62, center=n('E2'), size=4, bright=0.52)
    bassline(S, 'bass', 'D', 24, repeat_to(H5, 11), 'pulse', vel=98, bright=0.55)
    drums(S, 'kit', 'D', 24, 11, 'power', vel=98, human=hum, fill='roll')
    S.add('riser', 'D', 30, 0, 20, n('E2'), 90)
    S.add('kit', 'D', 31, 0, 20, SWELL4, 90)

    # ---------------------------------------------------------- E (29 Takte)
    # Die Stimmen kreuzen sich; am Ende beide unisono auf E.
    crash(S, 'kit', 'E', 0, 92)
    S.add('wind', 'E', 0, 0, 16, n('E4'), 92, bright=0.5)
    for bar, k in grid(24, 4):
        h = repeat_to(H5, k)
        ostinato(S, 'vln_spic', 'E', bar, k, h, vel=92)
        pad(S, 'vc_sus', 'E', bar, h, vel=58, center=n('E2'), size=3, bright=0.44)
        bassline(S, 'bass', 'E', bar, h, 'drive', vel=94, bright=0.5)
        drums(S, 'kit', 'E', bar, k, 'power', vel=90, human=hum)
        blech(S, 'trb_stac', 'E', bar, k, h, vel=90)
    phrase(S, 'lead', 'E', 0, THEME, vel=94, bright=0.6, human=hum)
    phrase(S, 'flute', 'E', 4, THEME, vel=82, transpose=12, human=hum)
    phrase(S, 'vla_sus', 'E', 8, THEME, vel=88, transpose=-12, human=hum)
    phrase(S, 'tuba', 'E', 12, fragment(THEME, 0, 8), vel=86, transpose=-24, human=hum)
    phrase(S, 'lead', 'E', 16, leitmotiv('E', 'harm', part='head'), vel=96, bright=0.7, human=hum)
    phrase(S, 'flute', 'E', 16.375, leitmotiv('E', 'harm', part='head'), vel=84, transpose=12, human=hum)
    phrase(S, 'vla_sus', 'E', 16.75, leitmotiv('E', 'harm', part='head'), vel=88, transpose=-12, human=hum)

    for b in range(24, 26):                             # Takte 24–25: alle zusammen auf E
        for p in (n('E3'), n('B3'), n('E4')):            # Lead
            S.add('lead', 'E', b, 0, 4, p, 104, bright=0.7)
        for p in (n('E5'), n('G5'), n('B5')):            # Bratschen und Violinen
            S.add('vla_sus', 'E', b, 0, 4, p, 94)
        S.add('kit', 'E', b, 0, 1.5, TIMP_LO, 118)
        S.add('kit', 'E', b, 0, .3, CLASH, 100)
        S.add('tuba', 'E', b, 0, 3.5, n('E1'), 100)
    for b in range(26, 29):                             # Takte 26–28: Riser, Abriss
        S.add('kit', 'E', b, 0, .5, TIMP_LO, 112)
        S.add('kit', 'E', b, 2, .5, TIMP_LO, 106)
        for p in close('Em', n('E2'), 3):
            S.add('vc_sus', 'E', b, 0, 1.6, p, 96, bright=0.5)
    S.add('riser', 'E', 25, 0, 16, n('E2'), 100)
    S.add('kit', 'E', 25, 0, 16, SWELL4, 100)
    S.add('kit', 'E', 26, 0, 12, SNARE_ROLL, 100)
    S.add('wind', 'E', 24, 0, 5, n('B4'), 112, bright=0.85)

    # ---------------------------------------------------------- Ankündigung (1,25 s): Auftakt
    # Kein Schlussakkord: Wirbel und Basshinführung münden auf dem nächsten Schlag in die
    # Bossmusik (boss5, Grundton E), die genau dann mit der Ankunft des Bosses einsetzt.
    leadin_spec = lead_in(S, 'E')

    mixspec = {
        'kit':      {'engine': 'sfz', 'inst': 'kit', 'gain': -0.5, 'rev': 0.16},
        'vln_spic': {'engine': 'sfz', 'inst': 'vln_spic', 'gain': -6.0, 'pan': -0.28, 'rev': 0.2},
        'vla_sus':  {'engine': 'sfz', 'inst': 'vla_sus', 'gain': -5.0, 'pan': -0.1, 'rev': 0.3},
        'vc_sus':   {'engine': 'sfz', 'inst': 'vc_sus', 'gain': -4.0, 'pan': 0.12, 'rev': 0.28},
        'flute':    {'engine': 'sfz', 'inst': 'flute', 'gain': -3.0, 'pan': 0.24, 'rev': 0.26, 'dly': 0.1},
        'trb_stac': {'engine': 'sfz', 'inst': 'trb_stac', 'gain': -4.0, 'pan': 0.18, 'rev': 0.2},
        'trb_sus':  {'engine': 'sfz', 'inst': 'trb_sus', 'gain': -5.0, 'pan': 0.16, 'rev': 0.24},
        'tpt_stac': {'engine': 'sfz', 'inst': 'tpt_stac', 'gain': -8.0, 'pan': 0.3, 'rev': 0.22},
        'tuba':     {'engine': 'sfz', 'inst': 'tuba', 'gain': -4.0, 'pan': -0.05, 'rev': 0.14},
        'lead':     {'engine': 'cs', 'instr': 'lead', 'gain': -1.5, 'pan': -0.1, 'rev': 0.2, 'dly': 0.14},
        'bass':     {'engine': 'cs', 'instr': 'bass', 'gain': -2.0, 'lp': 2400},
        'wind':     {'engine': 'cs', 'instr': 'wind', 'gain': -7.0, 'rev': 0.28},
        'riser':    {'engine': 'cs', 'instr': 'riser', 'gain': -9.0, 'rev': 0.18},
        'boom':     {'engine': 'cs', 'instr': 'boom', 'gain': -6.0, 'rev': 0.1},
    }
    mixspec.update(leadin_spec)
    return song, mixspec, {'file': 'level5', 'title': 'Level 5 – Dornen im Sturm', 'reverb': 2.2}
