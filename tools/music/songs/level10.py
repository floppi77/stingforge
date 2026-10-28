"""Level 10 – Kern der Verwandlung: feierlich, schwer, endgültig.

d-Moll harmonisch (Cis als Leitton) · 128 BPM. Orgel, großer Chor, Blech und
Streicher tragen das Leitmotiv in seiner verwandelten Gestalt: erst gedehnt
(Orgel, 16 Takte), dann in Umkehrung, zuletzt beides gleichzeitig. Darunter
schlägt ein Herzschlag aus Sub und Taiko, der im Finale schneller wird und
abreißt.

Form: A 29 · B 32 · C 32 · D 30 · E 25 Takte. Miniboss bei Levelzeit 142 s =
Takt 14 von C.
"""
from __future__ import annotations

from score import Song, n
from songs._kit import (CLASH, CRASH, FRAME_HI, FRAME_LO, GONG, Human, SNARE_ROLL, SWELL4,
                        TIMP_LO, TIMP_MID, TIMP_ROLL_LO, TOM_LO, WOOD, arp, bassline, close, crash,
                        drums, grid, pad, phrase, repeat_to, voicing)
from songs._themes import augment, fragment, invert, leitmotiv, mechanize, second_theme

BPM = 128

# ------------------------------------------------------------------ Harmonik
H1 = ['Dm', 'Bb', 'Gm', 'A7']          # A7 mit Cis = harmonisches Moll
H2 = ['Dm', 'A7', 'Dm', 'Bb']
H3 = ['Gm', 'Dm', 'Bb', 'A7']
H4 = ['Bb', 'C', 'Dm', 'A7']
H5 = ['Dm', 'Gm', 'A7', 'Dm']
HMINI = ['Dm', 'Dm', 'Bb', 'A7']

# ------------------------------------------------------------------ Motive
THEME = leitmotiv('D', 'harm')                       # 8 Takte
THEME_HEAD = leitmotiv('D', 'harm', part='head')
THEME_TAIL = leitmotiv('D', 'harm', part='tail')
THEME_AUG = augment(THEME_HEAD, 2.0)                 # 8 Takte gedehnt
THEME_INV = invert(leitmotiv('D', 'harm'))           # 8 Takte, Umkehrung
TRANSFORM = THEME_HEAD + invert(THEME_TAIL)          # 8 Takte: Kopf echt, Antwort gespiegelt
SECOND = second_theme('D', 'harm')
MECH = mechanize(leitmotiv('D', 'harm', part='head'), 0.25)[:64]
HEART = [('D2', .5), (None, 1.25), ('D2', .5), (None, 1.75)]        # 1 Takt Herzschlag


def build():
    song = Song.for_level(10, BPM)
    hum = Human(1010)
    S = song

    def heart(sec, bar0, bars, vel=96, every=1.0):
        """Herzschlag: doppelter Sub-Schlag mit Taiko-Akzent."""
        t = 0.0
        total = bars * 4
        i = 0
        while t < total - 0.01:
            S.add('sub', sec, bar0, t, 0.6, n('D1'), vel)
            S.add('kit', sec, bar0, t, 0.6, FRAME_LO, vel + 6)
            S.add('sub', sec, bar0, t + 0.75, 0.45, n('D1'), int(vel * 0.7))
            S.add('kit', sec, bar0, t + 0.75, 0.4, FRAME_HI, int(vel * 0.6))
            t += 2.0 * every if every != 1.0 else 2.0
            i += 1

    # ---------------------------------------------------------- Intro (2,2 s)
    for i, p in enumerate((n('D2'), n('A2'), n('D3'), n('F3'))):
        S.add('organ', 'intro', 0, i * 0.55, 2.4, p, 78 - i * 3, bright=0.5)
    S.add('boom', 'intro', 0, 0, 3, n('D1'), 80)
    S.add('choir', 'intro', 0, 0, 3, n('D3'), 72, bright=0.4, aux=0)

    # ---------------------------------------------------------- A (29 Takte)
    # Die Orgel stellt das gedehnte Thema vor, das Herz beginnt zu schlagen.
    S.add('organ', 'A', 0, 0, 8, n('D2'), 88, bright=0.45, aux=0.5)
    S.add('organ', 'A', 0, 0, 8, n('A2'), 76, bright=0.4, aux=0.5)
    pad(S, 'pad', 'A', 0, repeat_to(H1, 8), vel=52, center=n('D4'), size=4, bright=0.3)
    S.add('choir', 'A', 0, 0, 8, n('D3'), 64, bright=0.36, aux=0)
    heart('A', 0, 8, vel=72)
    S.add('organ', 'A', 8, 0, 8, n('D2'), 94, bright=0.5, aux=0.5)
    phrase(S, 'organ', 'A', 8, THEME_AUG, vel=84, bright=0.5, human=hum)
    pad(S, 'vln_sus', 'A', 8, repeat_to(H2, 8), vel=54, center=n('D4'), size=4, bright=0.36)
    S.add('choir', 'A', 8, 0, 8, n('F3'), 72, bright=0.42, aux=1)
    heart('A', 8, 8, vel=84)
    bassline(S, 'bass', 'A', 8, repeat_to(H2, 8), 'roots', vel=84, bright=0.3)

    phrase(S, 'vln_sus', 'A', 16, THEME_HEAD, vel=76, human=hum)
    phrase(S, 'vc_sus', 'A', 16, THEME_HEAD, vel=72, transpose=-12, human=hum)
    pad(S, 'pad', 'A', 16, repeat_to(H3, 8), vel=56, center=n('D4'), size=4, bright=0.34)
    bassline(S, 'bass', 'A', 16, repeat_to(H3, 8), 'half', vel=86, bright=0.34)
    drums(S, 'kit', 'A', 16, 8, 'taiko', vel=74, human=hum)
    heart('A', 16, 8, vel=90)
    for b in range(24, 29):                             # Takte 24–28: zum ersten Höhepunkt
        S.add('kit', 'A', b, 0, .8, TIMP_LO, 96)
        S.add('organ', 'A', b, 0, 4, n('D2'), 96, bright=0.55, aux=0.5)
    arp(S, 'glock', 'A', 24, repeat_to(H4, 5), step=0.5, low=n('D5'), high=n('A6'), vel=56, human=hum)
    pad(S, 'pad', 'A', 24, repeat_to(H4, 5), vel=60, center=n('D4'), size=4, bright=0.44)
    bassline(S, 'bass', 'A', 24, repeat_to(H4, 5), 'drive', vel=92, bright=0.44)
    drums(S, 'kit', 'A', 24, 5, 'taiko', vel=88, human=hum, fill='timp')
    S.add('riser', 'A', 26, 0, 12, n('D1'), 74)
    S.add('kit', 'A', 27, 0, 8, SWELL4, 84)

    # ---------------------------------------------------------- B (32 Takte)
    crash(S, 'kit', 'B', 0, 100)
    S.add('boom', 'B', 0, 0, 4, n('D1'), 96)
    S.add('organ', 'B', 0, 0, 16, n('D2'), 100, bright=0.55, aux=0.5)
    S.add('organ', 'B', 0, 0, 16, n('D3'), 82, bright=0.45, aux=0.5)
    S.add('choir', 'B', 0, 0, 16, n('D4'), 88, bright=0.5, aux=0)
    S.add('choir', 'B', 0, 0, 16, n('A3'), 80, bright=0.42, aux=1)
    phrase(S, 'vln_sus', 'B', 0, THEME, vel=92, human=hum)
    phrase(S, 'vc_sus', 'B', 0, THEME, vel=86, transpose=-12, human=hum)
    pad(S, 'pad', 'B', 0, repeat_to(H1, 8), vel=58, center=n('D4'), size=4, bright=0.4)
    bassline(S, 'bass', 'B', 0, repeat_to(H1, 8), 'drive', vel=96, bright=0.5)
    bassline(S, 'sub', 'B', 0, repeat_to(H1, 8), 'roots', vel=80)
    drums(S, 'kit', 'B', 0, 8, 'taiko', vel=94, human=hum, fill='timp')

    crash(S, 'kit', 'B', 8, 96)
    phrase(S, 'organ', 'B', 8, SECOND, vel=88, bright=0.52, human=hum)
    phrase(S, 'trb_sus', 'B', 8, SECOND, vel=86, transpose=-12, human=hum)
    pad(S, 'pad', 'B', 8, repeat_to(H2, 8), vel=58, center=n('D4'), size=4, bright=0.42)
    bassline(S, 'bass', 'B', 8, repeat_to(H2, 8), 'drive', vel=94, bright=0.48)
    drums(S, 'kit', 'B', 8, 8, 'taiko', vel=92, human=hum, fill='snare')
    heart('B', 8, 8, vel=88)

    # Takte 16–23: Blech und Orgel, das Thema in Umkehrung
    crash(S, 'kit', 'B', 16, 100)
    for b in range(8):
        for p in close(H3[b % 4], n('D2'), 3):
            S.add('trb_sus', 'B', 16 + b, 0, 2.0, p, 88)
            S.add('tuba', 'B', 16 + b, 0, 1.6, p - 12, 88)
        S.add('kit', 'B', 16 + b, 0, .6, TIMP_LO, 104)
        S.add('kit', 'B', 16 + b, 2.5, .4, TIMP_LO, 94)
    phrase(S, 'lead', 'B', 16, THEME_INV, vel=94, bright=0.6, human=hum)
    phrase(S, 'vln_sus', 'B', 16, THEME_INV, vel=84, transpose=-12, human=hum)
    phrase(S, 'organ', 'B', 16, TRANSFORM, vel=86, bright=0.5, human=hum)
    pad(S, 'pad', 'B', 16, repeat_to(H3, 8), vel=60, center=n('D4'), size=4, bright=0.46)
    bassline(S, 'bass', 'B', 16, repeat_to(H3, 8), 'drive', vel=98, bright=0.54)
    drums(S, 'kit', 'B', 16, 8, 'taiko', vel=96, human=hum, fill='timp')

    for b in range(24, 32):                             # Takte 24–31: Hochlaufen
        S.add('kit', 'B', b, 0, .6, FRAME_LO, 104)
        S.add('kit', 'B', b, 1.5, .4, FRAME_HI, 92)
        S.add('kit', 'B', b, 2.5, .5, FRAME_LO, 100)
        S.add('organ', 'B', b, 0, 4, n('D2'), 100, bright=0.6, aux=0.5)
    phrase(S, 'lead', 'B', 24, leitmotiv('D', 'min'), vel=96, bright=0.62, human=hum)
    phrase(S, 'choir', 'B', 24, fragment(THEME_HEAD, 0, 12), vel=86, bright=0.5, aux=0)
    arp(S, 'glock', 'B', 24, repeat_to(H4, 8), step=0.25, low=n('D5'), high=n('A6'), vel=60, human=hum)
    pad(S, 'pad', 'B', 24, repeat_to(H4, 8), vel=62, center=n('D4'), size=4, bright=0.5)
    bassline(S, 'bass', 'B', 24, repeat_to(H4, 8), 'pulse', vel=98, bright=0.56)
    drums(S, 'kit', 'B', 24, 8, 'taiko', vel=98, human=hum, fill='roll')
    S.add('riser', 'B', 29, 0, 16, n('D1'), 86)
    S.add('kit', 'B', 29, 0, 16, SWELL4, 90)

    # ---------------------------------------------------------- C (32 Takte)
    # Takte 0–13: nur Orgel und Herz. Ab Takt 14 (= 142 s) der Miniboss.
    S.add('organ', 'C', 0, 0, 14, n('D2'), 92, bright=0.42, aux=0.5)
    S.add('organ', 'C', 0, 0, 14, n('A2'), 78, bright=0.36, aux=0.5)
    S.add('choir', 'C', 0, 0, 14, n('D3'), 70, bright=0.34, aux=0)
    heart('C', 0, 14, vel=88)
    pad(S, 'pad', 'C', 0, repeat_to(H5, 14), vel=48, center=n('D4'), size=3, bright=0.2)
    phrase(S, 'vln_sus', 'C', 2, fragment(THEME, 0, 12), vel=70, human=hum)
    for b in range(0, 14, 2):
        S.add('kit', 'C', b, 3.5, .3, WOOD, 56)
    S.add('kit', 'C', 13, 0, 4, TIMP_ROLL_LO, 90)

    # Miniboss (Takte 14–31)
    crash(S, 'kit', 'C', 14, 106)
    S.add('kit', 'C', 14, 0, .3, CLASH, 102)
    S.add('boom', 'C', 14, 0, 4, n('D1'), 108)
    for bar, k in grid(18, 4):
        b = 14 + bar
        h = repeat_to(HMINI, k)
        for i, ch in enumerate(h):
            for p in close(ch, n('D2'), 3):
                S.add('trb_sus', 'C', b + i, 0, 1.6, p, 90)
                S.add('tuba', 'C', b + i, 0, 1.4, p - 12, 90)
        pad(S, 'pad', 'C', b, h, vel=58, center=n('D4'), size=4, bright=0.44)
        bassline(S, 'bass', 'C', b, h, 'drive', vel=96, bright=0.54)
        drums(S, 'kit', 'C', b, k, 'taiko', vel=96, human=hum)
        arp(S, 'glock', 'C', b, h, step=0.25, low=n('D5'), high=n('A6'), vel=56, human=hum)
    phrase(S, 'lead', 'C', 14, MECH + MECH, vel=94, bright=0.66, human=hum, legato=0.9)
    phrase(S, 'choir', 'C', 18, THEME, vel=84, bright=0.46, aux=0)
    phrase(S, 'vln_sus', 'C', 22, THEME_INV, vel=86, human=hum)
    phrase(S, 'organ', 'C', 26, TRANSFORM, vel=92, bright=0.56, human=hum)
    heart('C', 14, 18, vel=94)
    for b in range(28, 32):
        S.add('kit', 'C', b, 0, .5, TIMP_LO, 108)
        S.add('kit', 'C', b, 1.5, .4, TIMP_MID, 96)
        S.add('kit', 'C', b, 2.5, .5, TIMP_LO, 104)
        S.add('kit', 'C', b, 3.5, .3, TOM_LO, 96)
    S.add('riser', 'C', 28, 0, 16, n('D1'), 94)
    S.add('kit', 'C', 28, 0, 16, SWELL4, 96)

    # ---------------------------------------------------------- D (30 Takte)
    crash(S, 'kit', 'D', 0, 104)
    S.add('boom', 'D', 0, 0, 6, n('D1'), 102)
    S.add('organ', 'D', 0, 0, 16, n('D2'), 104, bright=0.58, aux=0.5)
    S.add('organ', 'D', 0, 0, 16, n('D3'), 88, bright=0.5, aux=0.5)
    S.add('choir', 'D', 0, 0, 16, n('D4'), 94, bright=0.54, aux=0)
    S.add('choir', 'D', 0, 0, 16, n('A3'), 84, bright=0.46, aux=1)
    phrase(S, 'vln_sus', 'D', 0, THEME_AUG, vel=94, human=hum)
    phrase(S, 'vc_sus', 'D', 0, THEME_AUG, vel=88, transpose=-12, human=hum)
    pad(S, 'pad', 'D', 0, repeat_to(H1, 8), vel=60, center=n('D4'), size=4, bright=0.46)
    bassline(S, 'bass', 'D', 0, repeat_to(H1, 8), 'half', vel=96, bright=0.48)
    drums(S, 'kit', 'D', 0, 8, 'taiko', vel=96, human=hum, fill='timp')
    heart('D', 0, 8, vel=96)

    crash(S, 'kit', 'D', 8, 100)
    phrase(S, 'organ', 'D', 8, TRANSFORM, vel=96, bright=0.6, human=hum)
    phrase(S, 'trb_sus', 'D', 8, TRANSFORM, vel=90, transpose=-12, human=hum)
    phrase(S, 'glock', 'D', 8, THEME_HEAD, vel=84, transpose=12, human=hum, legato=1.2)
    arp(S, 'glock', 'D', 8, repeat_to(H2, 8), step=0.25, low=n('D5'), high=n('A6'), vel=60, human=hum)
    pad(S, 'pad', 'D', 8, repeat_to(H2, 8), vel=60, center=n('D4'), size=4, bright=0.5)
    bassline(S, 'bass', 'D', 8, repeat_to(H2, 8), 'drive', vel=98, bright=0.56)
    drums(S, 'kit', 'D', 8, 8, 'taiko', vel=98, human=hum, fill='snare')
    heart('D', 8, 8, vel=96)

    for b in range(16, 30):                             # Takte 16–29: alles zusammen
        S.add('kit', 'D', b, 0, .6, FRAME_LO, 108)
        S.add('kit', 'D', b, 1.5, .5, FRAME_HI, 96)
        S.add('kit', 'D', b, 2.5, .6, FRAME_LO, 104)
        S.add('kit', 'D', b, 3.5, .4, TOM_LO, 96)
        S.add('organ', 'D', b, 0, 4, n('D2'), 104, bright=0.6, aux=0.5)
    phrase(S, 'lead', 'D', 16, leitmotiv('D', 'harm'), vel=100, bright=0.68, human=hum)
    phrase(S, 'vln_sus', 'D', 16, leitmotiv('D', 'harm'), vel=92, transpose=-12, human=hum)
    phrase(S, 'choir', 'D', 24, QUEEN_FIX(), vel=90, bright=0.5, aux=0)
    arp(S, 'glock', 'D', 16, repeat_to(H3, 14), step=0.25, low=n('D5'), high=n('A6'), vel=58, human=hum)
    pad(S, 'pad', 'D', 16, repeat_to(H3, 14), vel=62, center=n('D4'), size=4, bright=0.52)
    bassline(S, 'bass', 'D', 16, repeat_to(H3, 14), 'drive', vel=100, bright=0.6)
    drums(S, 'kit', 'D', 16, 14, 'taiko', vel=100, human=hum, fill='roll')
    S.add('riser', 'D', 26, 0, 16, n('D1'), 92)
    S.add('kit', 'D', 26, 0, 16, SWELL4, 96)

    # ---------------------------------------------------------- E (25 Takte)
    # Der Herzschlag wird schneller, dann reißt alles ab.
    crash(S, 'kit', 'E', 0, 96)
    S.add('organ', 'E', 0, 0, 16, n('D2'), 100, bright=0.52, aux=0.5)
    S.add('choir', 'E', 0, 0, 16, n('D3'), 88, bright=0.46, aux=0)
    phrase(S, 'vln_sus', 'E', 0, THEME_AUG, vel=88, human=hum)
    pad(S, 'pad', 'E', 0, repeat_to(H5, 16), vel=54, center=n('D4'), size=3, bright=0.34)
    bassline(S, 'bass', 'E', 0, repeat_to(H5, 16), 'roots', vel=88, bright=0.36)

    for b in range(0, 16):                              # Herzschlag beschleunigt
        step = 2.0 if b < 6 else (1.5 if b < 10 else (1.0 if b < 13 else 0.75))
        t = 0.0
        while t < 4.0 - 0.01:
            S.add('sub', 'E', b, t, 0.5, n('D1'), 96 + b * 2)
            S.add('kit', 'E', b, t, 0.5, FRAME_LO, 100 + b * 2)
            S.add('sub', 'E', b, t + step * 0.45, 0.35, n('D1'), 82)
            S.add('kit', 'E', b, t + step * 0.45, 0.3, FRAME_HI, 74)
            t += step
    phrase(S, 'glock', 'E', 4, fragment(THEME, 0, 12), vel=76, transpose=12, human=hum, legato=1.3)
    phrase(S, 'lead', 'E', 8, fragment(THEME, 12, 12), vel=84, bright=0.5, human=hum)

    for b in range(16, 22):                             # Takte 16–21: Verdichtung kurz vor Schluss
        S.add('kit', 'E', b, 0, .5, TIMP_LO, 110)
        S.add('kit', 'E', b, 2, .5, TIMP_LO, 104)
        for p in close('Dm', n('D2'), 3):
            S.add('vc_sus', 'E', b, 0, 1.8, p, 98)
            S.add('trb_sus', 'E', b, 0, 1.6, p, 92)
    S.add('riser', 'E', 12, 0, 40, n('D1'), 100)
    S.add('kit', 'E', 16, 0, 24, SWELL4, 104)
    S.add('kit', 'E', 18, 0, 20, SNARE_ROLL, 102)
    S.add('choir', 'E', 18, 0, 7, n('D4'), 108, bright=0.62, aux=0)
    S.add('organ', 'E', 20, 0, 5, n('D2'), 110, bright=0.7, aux=0.5)
    phrase(S, 'lead', 'E', 20, fragment(THEME_HEAD, 0, 8), vel=104, bright=0.7, human=hum)

    # Letzte Takte: das Herz, ein letzter Schlag, Abriss
    for b in range(22, 25):
        S.add('kit', 'E', b, 0, .6, FRAME_LO, 112)
        S.add('sub', 'E', b, 0, 0.8, n('D1'), 108)
        S.add('kit', 'E', b, 2, .6, FRAME_LO, 96)
        S.add('sub', 'E', b, 2, 0.6, n('D1'), 92)

    # ---------------------------------------------------------- Ankündigung (1,25 s)
    S.add('kit', 'tail', 0, 0, 2.5, TIMP_LO, 127)
    S.add('kit', 'tail', 0, 0, 2.5, CLASH, 120)
    S.add('boom', 'tail', 0, 0, 2.5, n('D1'), 114)
    for p in close('Dm', n('D2'), 4):
        S.add('trb_sus', 'tail', 0, 0, 1.2, p, 118)
        S.add('tuba', 'tail', 0, 0, 1.2, p - 12, 112)
        S.add('organ', 'tail', 0, 0, 1.2, p, 108, bright=0.6)
    S.add('choir', 'tail', 0, 0, 1.2, n('D4'), 118, bright=0.6, aux=0)

    mixspec = {
        'kit':      {'engine': 'sfz', 'inst': 'kit', 'gain': -0.5, 'rev': 0.2},
        'vln_sus':  {'engine': 'sfz', 'inst': 'vln_sus', 'gain': -6.0, 'pan': -0.22, 'rev': 0.32},
        'vc_sus':   {'engine': 'sfz', 'inst': 'vc_sus', 'gain': -6.0, 'pan': 0.18, 'rev': 0.3},
        'trb_sus':  {'engine': 'sfz', 'inst': 'trb_sus', 'gain': -5.0, 'pan': 0.14, 'rev': 0.26},
        'tuba':     {'engine': 'sfz', 'inst': 'tuba', 'gain': -4.0, 'pan': -0.08, 'rev': 0.16},
        'glock':    {'engine': 'sfz', 'inst': 'glock', 'gain': -9.0, 'pan': 0.3, 'rev': 0.34, 'dly': 0.18},
        'organ':    {'engine': 'cs', 'instr': 'organ', 'gain': -8.0, 'rev': 0.34, 'hp': 70, 'width': 1.15},
        'choir':    {'engine': 'cs', 'instr': 'choir', 'gain': -4.0, 'rev': 0.46, 'hp': 130, 'width': 1.3},
        'pad':      {'engine': 'cs', 'instr': 'pad', 'gain': -10.0, 'rev': 0.4, 'hp': 120, 'width': 1.25},
        'lead':     {'engine': 'cs', 'instr': 'lead', 'gain': -2.0, 'pan': -0.06, 'rev': 0.24, 'dly': 0.16},
        'bass':     {'engine': 'cs', 'instr': 'bass', 'gain': -1.5, 'lp': 2500},
        'sub':      {'engine': 'cs', 'instr': 'sub', 'gain': -4.0, 'lp': 110},
        'riser':    {'engine': 'cs', 'instr': 'riser', 'gain': -9.0, 'rev': 0.2},
        'boom':     {'engine': 'cs', 'instr': 'boom', 'gain': -4.0, 'rev': 0.14},
    }
    return song, mixspec, {'file': 'level10', 'title': 'Level 10 – Kern der Verwandlung', 'reverb': 2.9}


def QUEEN_FIX():
    """Das Thema gedehnt als Schlussgesang (8 Takte)."""
    return augment(leitmotiv('D', 'harm', part='head'), 2.0)
