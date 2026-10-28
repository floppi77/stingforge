"""Gemeinsame Bausteine für die Levelsongs: Akkorde, Voicings, Muster.

Konventionen:
  * Zeiten in Schlägen (Viertel) relativ zum Takt, Takte relativ zum Abschnitt.
  * Akkordnamen wie 'D', 'Bm7', 'Gmaj7', 'A7sus', 'F#7b9', 'Db/C' (Slash = Bassnote).
  * Eine Harmoniezeile ist eine Liste je Takt; 'G|A7' teilt den Takt in zwei Hälften.
"""
from __future__ import annotations

import random
import re

from score import Song, n

QUAL = {
    '': [0, 4, 7], 'm': [0, 3, 7], '7': [0, 4, 7, 10], 'm7': [0, 3, 7, 10], 'maj7': [0, 4, 7, 11],
    'sus2': [0, 2, 7], 'sus4': [0, 5, 7], '7sus': [0, 5, 7, 10], 'add9': [0, 4, 7, 14],
    'madd9': [0, 3, 7, 14], 'm6': [0, 3, 7, 9], '6': [0, 4, 7, 9], 'dim': [0, 3, 6], 'm7b5': [0, 3, 6, 10],
    '7b9': [0, 4, 7, 10, 13], 'maj9': [0, 4, 7, 11, 14], 'm9': [0, 3, 7, 10, 14], '5': [0, 7],
}
PC = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def parse(name: str) -> tuple[int, list[int], int]:
    """'Bm7' -> (Grundton-PC, Intervalle, Bass-PC)."""
    body, _, slash = name.partition('/')
    m = re.fullmatch(r'([A-G])([#b]?)(.*)', body)
    root = (PC[m.group(1)] + {'#': 1, 'b': -1, '': 0}[m.group(2)]) % 12
    iv = QUAL[m.group(3)]
    bass = root
    if slash:
        sm = re.fullmatch(r'([A-G])([#b]?)', slash)
        bass = (PC[sm.group(1)] + {'#': 1, 'b': -1, '': 0}[sm.group(2)]) % 12
    return root, iv, bass


def transpose_name(name: str, semis: int) -> str:
    names = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B']

    def tr(tok: str) -> str:
        m = re.fullmatch(r'([A-G])([#b]?)(.*)', tok)
        pc = (PC[m.group(1)] + {'#': 1, 'b': -1, '': 0}[m.group(2)] + semis) % 12
        return names[pc] + m.group(3)
    body, _, slash = name.partition('/')
    return tr(body) + ('/' + tr(slash) if slash else '')


def diatonic(notes: list[tuple[str | None, float]], key: str, transpose: int, steps: int,
             scale: tuple[int, ...] = (0, 2, 4, 5, 7, 9, 11)) -> list[tuple[str | None, float]]:
    """Melodie transponieren und um `steps` Leiterstufen verschieben (Terz = -2/+2).
    Leiterfremde Töne werden chromatisch um die passende Terz mitgeführt."""
    names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    tonic = PC[key[0]] + {'#': 1, 'b': -1}.get(key[1:2], 0)
    pcs = [(tonic + s) % 12 for s in scale]
    out = []
    for p, d in notes:
        if p is None:
            out.append((None, d))
            continue
        m = n(p) + transpose
        if m % 12 in pcs:
            idx = pcs.index(m % 12)
            octave = (m - (m % 12)) // 12
            j = idx + steps
            m2 = (octave + j // 7) * 12 + pcs[j % 7]
            if pcs[j % 7] < pcs[idx] and steps > 0 and j < 7:
                m2 += 12
            # Oktavfehler bei Leiterüberlauf ausgleichen: nächste Lage zum Original wählen
            while m2 - m > 7:
                m2 -= 12
            while m - m2 > 7:
                m2 += 12
        else:
            m2 = m + (-4 if steps < 0 else 3)
        out.append((names[m2 % 12] + str(m2 // 12 - 1), d))
    return out


def bar_slots(harmony: list[str]) -> list[list[tuple[float, float, str]]]:
    """Je Takt: Liste (Startschlag, Dauer, Akkord)."""
    out = []
    for cell in harmony:
        parts = cell.split('|')
        step = 4.0 / len(parts)
        out.append([(i * step, step, p) for i, p in enumerate(parts)])
    return out


def voicing(name: str, low: int, high: int) -> list[int]:
    """Enge Lage: alle Akkordtöne zwischen low und high, Grundton unten bevorzugt."""
    root, iv, _ = parse(name)
    pcs = {(root + i) % 12 for i in iv}
    return [p for p in range(low, high + 1) if p % 12 in pcs]


def close(name: str, center: int, size: int = 4) -> list[int]:
    """`size` Akkordtöne möglichst nah um `center` (für Pads/Streicher)."""
    cands = voicing(name, center - 12, center + 12)
    cands.sort(key=lambda p: abs(p - center))
    pick = sorted(cands[:size])
    return pick


def bass_note(name: str, low: int = n('E1'), high: int = n('D#2')) -> int:
    _, _, bass = parse(name)
    for p in range(low, high + 1):
        if p % 12 == bass:
            return p
    return low


class Human:
    def __init__(self, seed: int):
        self.rng = random.Random(seed)

    def t(self, amount: float = 0.012) -> float:
        return self.rng.uniform(-amount, amount)

    def v(self, vel: int, amount: int = 6) -> int:
        return max(1, min(127, vel + self.rng.randint(-amount, amount)))


# ------------------------------------------------------------------ Bausteine
def phrase(song: Song, part: str, sec: str, bar: float, notes: list[tuple[str | None, float]],
           vel: int = 92, transpose: int = 0, human: Human | None = None, legato: float = 0.96,
           **extra) -> float:
    """Melodie aus (Ton, Schläge); None = Pause. Gibt die Länge in Schlägen zurück."""
    beat = 0.0
    for i, (p, d) in enumerate(notes):
        if p is not None:
            accent = 6 if beat % 4 == 0 else (2 if beat % 1 == 0 else -2)
            v = vel + accent
            if human:
                v = human.v(v, 4)
            song.add(part, sec, bar, beat, d * legato, n(p) + transpose, v, **extra)
        beat += d
    return beat


def fit_octave(notes, inst: str, prefer: int = 0) -> int:
    """Oktavversatz wählen, der eine Melodie in die spielbare Lage legt.

    Damit landet jede Instrumentalstimme auf echten Proben statt auf einer
    gestreckten Randprobe (das klingt gequetscht und verstimmt). Die Melodie
    selbst bleibt unangetastet, nur ihre Lage ändert sich.
    """
    import sfz
    lo, hi = sfz.pitch_window(inst)
    ps = [n(p) for p, _ in notes if p is not None]
    if not ps:
        return 0
    best, best_sh = None, 0
    for sh in (0, -12, 12, -24, 24, -36, 36, -48, 48):
        inside = sum(1 for p in ps if lo <= p + sh <= hi)
        key = (-inside, abs(sh - prefer))
        if best is None or key < best:
            best, best_sh = key, sh
    return best_sh


def pad(song: Song, part: str, sec: str, bar0: int, harmony: list[str], vel: int = 70,
        center: int = n('F#4'), size: int = 4, **extra) -> None:
    for b, slots in enumerate(bar_slots(harmony)):
        for start, dur, ch in slots:
            for p in close(ch, center, size):
                song.add(part, sec, bar0 + b, start, dur, p, vel, **extra)


def arp(song: Song, part: str, sec: str, bar0: int, harmony: list[str], step: float = 0.5,
        low: int = n('D3'), high: int = n('A5'), shape: str = 'updown', vel: int = 72,
        human: Human | None = None, accent: int = 10, ring: float = 1.5, **extra) -> None:
    for b, slots in enumerate(bar_slots(harmony)):
        for start, dur, ch in slots:
            tones = voicing(ch, low, high)
            if shape == 'updown':
                seq = tones + tones[-2:0:-1]
            elif shape == 'down':
                seq = tones[::-1]
            elif shape == 'broken':
                seq = [x for pair in zip(tones[::2], tones[1::2]) for x in pair] or tones
            else:
                seq = tones
            k = 0
            t = 0.0
            while t < dur - 1e-6:
                p = seq[k % len(seq)]
                v = vel + (accent if (start + t) % 2 == 0 else 0)
                if human:
                    v = human.v(v)
                song.add(part, sec, bar0 + b, start + t, step * ring, p, v, **extra)
                k += 1
                t += step


def bassline(song: Song, part: str, sec: str, bar0: int, harmony: list[str], style: str = 'roots',
             vel: int = 96, human: Human | None = None, **extra) -> None:
    for b, slots in enumerate(bar_slots(harmony)):
        for start, dur, ch in slots:
            root = bass_note(ch)
            pattern: list[tuple[float, float, int]]
            if style == 'roots':
                pattern = [(0, dur * 0.95, 0)]
            elif style == 'half':
                pattern = [(0, min(2, dur) * 0.9, 0)] + ([(2, 1.8, 0)] if dur > 2 else [])
            elif style == 'drive':
                pattern = [(x * 0.5, 0.42, 12 if x % 2 else 0) for x in range(int(dur * 2))]
            elif style == 'pop':
                pattern = [(0, 0.9, 0), (1.5, 0.45, 0), (2, 0.9, 7), (3, 0.45, 12), (3.5, 0.45, 0)]
                pattern = [p for p in pattern if p[0] < dur]
            elif style == 'pulse':
                pattern = [(x * 0.5, 0.3, 0) for x in range(int(dur * 2))]
            else:
                raise ValueError(style)
            for off, d, iv in pattern:
                v = vel - (10 if off % 1 else 0)
                if human:
                    v = human.v(v, 4)
                song.add(part, sec, bar0 + b, start + off, d, root + iv, v, **extra)


# General-MIDI-nahe Belegung von sfz.KITS['kit']
KICK, STICK, SNARE, CLAP, TAPS = 36, 37, 38, 39, 40
HAT, HAT_SOFT, HAT_OPEN = 42, 44, 46
CRASH, RIDE, SWELL2, SWELL4, CHOKE = 49, 51, 52, 53, 57
TAMB, TAMB_SHAKE, SHAKE_A, SHAKE_B, SHAKE_C = 54, 55, 70, 69, 71
TIMP_LO, TIMP_MID, TIMP_HI, TIMP_ROLL_LO, TIMP_ROLL_MID = 41, 43, 45, 47, 48
SNARE_ROLL, SNARE_ROLL_SOFT, TRI, CHIMES_UP, CHIMES_FAST, CHIMES_DOWN = 59, 58, 81, 84, 85, 86
# Erweiterung für Level 2–10 (Metall, Holz, Fell)
ANVIL1, ANVIL2, ANVIL3 = 60, 61, 62
BRAKE1, BRAKE2, BRAKE_SUSP = 63, 64, 65
LOG_LO, LOG_HI = 66, 67
FRAME_LO, FRAME_HI = 68, 72
GONG, WOOD, RATCHET = 73, 74, 75
DARBUKA, CONGA, CONGA_HI = 76, 77, 78
TOM_LO, TOM_HI, BD_DEEP, CLASH = 79, 80, 82, 83


def drums(song: Song, part: str, sec: str, bar0: int, bars: int, style: str, vel: int = 96,
          human: Human | None = None, fill: str | None = None) -> None:
    h = human or Human(bar0 * 31 + len(sec))

    def hit(b, beat, key, v, dur=0.25):
        song.add(part, sec, b, beat + h.t(0.004) / song.section(sec).spb, dur, key, h.v(v, 5))

    for i in range(bars):
        b = bar0 + i
        last = i == bars - 1 and fill is not None
        if style == 'shaker':
            for s in range(16):
                hit(b, s * 0.25, SHAKE_A if s % 2 == 0 else SHAKE_B, int(vel * (0.62 if s % 4 == 0 else 0.42)))
        elif style == 'light':
            hit(b, 0, KICK, int(vel * 0.7)); hit(b, 2, KICK, int(vel * 0.6))
            hit(b, 1, STICK, int(vel * 0.6)); hit(b, 3, STICK, int(vel * 0.62))
            for s in range(16):
                hit(b, s * 0.25, SHAKE_A if s % 2 == 0 else SHAKE_B, int(vel * (0.55 if s % 4 == 2 else 0.38)))
        elif style == 'full':
            for k in (0, 1.5, 2, 2.75 if i % 2 else 3.5):
                hit(b, k, KICK, int(vel * (0.95 if k in (0, 2) else 0.75)))
            hit(b, 1, SNARE, vel); hit(b, 3, SNARE, vel)
            for s in range(8):
                if not (s == 7 and i % 4 == 3):
                    hit(b, s * 0.5, HAT, int(vel * (0.7 if s % 2 == 0 else 0.5)))
            if i % 4 == 3:
                hit(b, 3.5, HAT_OPEN, int(vel * 0.6))
            for s in range(16):
                hit(b, s * 0.25, SHAKE_A, int(vel * 0.28))
            hit(b, 1.5, TAMB, int(vel * 0.45)); hit(b, 3.5, TAMB, int(vel * 0.45))
        elif style == 'half':
            hit(b, 0, KICK, int(vel * 0.9)); hit(b, 2.5, KICK, int(vel * 0.6))
            hit(b, 2, SNARE, int(vel * 0.95))
            for s in range(4):
                hit(b, s, HAT, int(vel * 0.55))
            hit(b, 3.5, HAT_SOFT, int(vel * 0.4))
        elif style == 'march':
            for q in range(4):
                hit(b, q, KICK, int(vel * (0.9 if q == 0 else 0.7)))
            for s in range(16):
                if s in (4, 12):
                    hit(b, s * 0.25, SNARE, int(vel * 0.95))
                elif s % 2 == 0 or s in (13, 15):
                    hit(b, s * 0.25, TAPS, int(vel * (0.55 if s % 4 == 0 else 0.42)))
            hit(b, 0, TIMP_LO, int(vel * 0.8), 1.0)
        elif style == 'none':
            pass
        elif style == 'taiko':
            for k, fac in ((0, 1.0), (1.5, 0.5), (2, 0.8), (3.25, 0.45)):
                hit(b, k, FRAME_LO if k in (0, 2) else FRAME_HI, int(vel * fac), 1.0)
            hit(b, 0, TIMP_LO, int(vel * 0.7), 1.5)
            hit(b, 1, LOG_HI, int(vel * 0.5))
            hit(b, 3, LOG_HI, int(vel * 0.45))
            if i % 2 == 1:
                hit(b, 2.5, LOG_LO, int(vel * 0.55))
        elif style == 'tribal':
            hit(b, 0, DARBUKA, int(vel * 0.9))
            hit(b, 1.5, DARBUKA, int(vel * 0.6))
            hit(b, 2, CONGA, int(vel * 0.85))
            hit(b, 3, TOM_HI, int(vel * 0.7))
            for s in range(4):
                hit(b, s + 0.5, CONGA_HI, int(vel * 0.42))
            if i % 2 == 1:
                hit(b, 3.5, TOM_LO, int(vel * 0.55))
        elif style == 'trip':
            hit(b, 0, KICK, int(vel * 0.95))
            hit(b, 2.5, KICK, int(vel * 0.55))
            hit(b, 2, SNARE, int(vel * 0.85))
            for s in range(6):  # 3-gegen-4 als Sporenfeld
                hit(b, s * 2 / 3, SHAKE_A if s % 2 == 0 else SHAKE_B, int(vel * 0.3))
            hit(b, 3.5, HAT_SOFT, int(vel * 0.42))
            if i % 4 == 3:
                hit(b, 3.75, SHAKE_C, int(vel * 0.4))
        elif style == 'dub':
            hit(b, 0, KICK, int(vel * 1.0))
            hit(b, 2, SNARE, int(vel * 0.65))
            for s in range(8):
                if s != 6:
                    hit(b, s * 0.5, HAT_SOFT, int(vel * (0.36 if s % 2 == 0 else 0.24)))
            hit(b, 3.5, WOOD, int(vel * 0.4))
        elif style == 'industrial':
            for k in (0, 1.75, 2.5):
                hit(b, k, BD_DEEP, int(vel * (0.95 if k == 0 else 0.7)))
            hit(b, 1, ANVIL2, int(vel * 0.8), 0.5)
            hit(b, 3, ANVIL1, int(vel * 0.72), 0.5)
            for s in range(8):
                hit(b, s * 0.5, BRAKE1 if s % 4 == 2 else HAT, int(vel * (0.5 if s % 2 == 0 else 0.3)))
            if i % 4 == 3:
                hit(b, 3.5, BRAKE2, int(vel * 0.6), 0.5)
        elif style == 'glitch':
            # Gläsernes Gewächshaus: Klicks, Triangel, Holz – kein voller Beat
            hit(b, 0, TRI, int(vel * 0.85), 0.4)
            hit(b, 1.75, WOOD, int(vel * 0.7))
            hit(b, 2.5, TRI, int(vel * 0.6), 0.3)
            hit(b, 3.25, WOOD, int(vel * 0.55))
            if i % 2 == 0:
                hit(b, 0, KICK, int(vel * 0.55))
                hit(b, 2, KICK, int(vel * 0.45))
            if i % 4 == 2:
                hit(b, 1, CHIMES_FAST, int(vel * 0.4), 0.3)
            for s in range(16):
                hit(b, s * 0.25, SHAKE_A if s % 2 == 0 else SHAKE_B, int(vel * (0.42 if s % 4 == 0 else 0.24)))
        elif style == 'boss':
            # Bosskampf: doppeltes Tempo im Gefühl – Sechzehntel-Hats, Kick-Muster, Ghost-Notes
            for kk in ((0, 1.0), (0.75, 0.7), (1.5, 0.8), (2, 0.95), (2.75, 0.7), (3.5, 0.75)):
                if not (i % 2 == 1 and kk[0] == 3.5):
                    hit(b, kk[0], KICK, int(vel * kk[1]))
            hit(b, 1, SNARE, vel)
            hit(b, 3, SNARE, vel)
            for gn in (1.75, 3.25):
                hit(b, gn, SNARE, int(vel * 0.32))
            for s in range(16):
                hit(b, s * 0.25, HAT, int(vel * (0.58 if s % 4 == 0 else (0.42 if s % 2 == 0 else 0.3))))
            if i % 4 == 0:
                hit(b, 0, CRASH, int(vel * 0.8), 1.5)
            elif i % 2 == 1:
                hit(b, 3.5, HAT_OPEN, int(vel * 0.55))
        elif style == 'power':
            for q in range(4):
                hit(b, q, KICK, int(vel * (0.95 if q % 2 == 0 else 0.7)))
            hit(b, 1, CLAP, int(vel * 0.8))
            hit(b, 3, SNARE, int(vel * 0.95))
            for s in range(8):
                hit(b, s * 0.5, HAT, int(vel * (0.55 if s % 2 == 0 else 0.35)))
        else:
            raise ValueError(style)
        if last:
            _fill(song, part, sec, b, fill, vel, h)


def _fill(song, part, sec, b, kind, vel, h):
    if kind == 'snare':
        for s in range(8, 16):
            song.add(part, sec, b, s * 0.25, 0.25, SNARE, h.v(int(vel * (0.5 + 0.06 * (s - 8))), 3))
    elif kind == 'roll':
        song.add(part, sec, b, 0, 4, SNARE_ROLL, int(vel * 0.9))
    elif kind == 'timp':
        for s, key in enumerate((TIMP_HI, TIMP_HI, TIMP_MID, TIMP_MID, TIMP_LO, TIMP_LO)):
            song.add(part, sec, b, 2.5 + s * 0.25, 0.5, key, h.v(int(vel * (0.6 + 0.07 * s)), 3))
    elif kind == 'stop':
        pass


def crash(song: Song, part: str, sec: str, bar: int, vel: int = 100) -> None:
    song.add(part, sec, bar, 0, 2, CRASH, vel)


# ------------------------------------------------------------------ Raster
def grid(bars: int, cell_len: int = 4) -> list[tuple[int, int]]:
    """Taktblöcke einer Sektion: [(Starttakt, Takte)], letzter Block ggf. kürzer.
    Damit deckt ein Loop die Sektion immer exakt ab (keine Überläufe)."""
    out = []
    b = 0
    while b < bars:
        k = min(cell_len, bars - b)
        out.append((b, k))
        b += k
    return out


def take(harmony: list[str], bars: int) -> list[str]:
    """Die ersten `bars` Akkorde einer Zellenliste (für den verkürzten Restblock)."""
    return harmony[:bars]


def repeat_to(harmony: list[str], bars: int) -> list[str]:
    """Zellenliste auf genau `bars` Takte zyklisch auffüllen."""
    return [harmony[i % len(harmony)] for i in range(bars)]


def lead_in(song: Song, boss_root: str, kit_part: str = 'kit') -> dict:
    """Auftakt in den letzten 2,5 Schlägen (Bossankündigung): Wirbel-Crescendo,
    Beckenwelle und eine Basshinführung auf den Grundton der Bossmusik, die genau
    auf dem nächsten Schlag mit der Ankunft des Bosses einsetzt.
    Liefert den Mischeintrag für die Hinführungsstimme zurück."""
    sec = song.section('tail')
    steps = int(sec.beats / 0.25)
    for i in range(steps):
        song.add(kit_part, 'tail', 0, i * 0.25, 0.25, SNARE, min(127, 56 + i * 7))
    song.add(kit_part, 'tail', 0, 0, sec.beats, SWELL2, 96)
    root = bass_note(boss_root)
    for beat, iv, vel in ((sec.beats - 1.0, 7, 96), (sec.beats - 0.5, 11, 108)):
        song.add('leadin', 'tail', 0, beat, 0.45, root - 12 + iv if root - 12 + iv >= n('E1') else root + iv, vel, bright=0.55)
    return {'leadin': {'engine': 'cs', 'instr': 'bass', 'gain': -3.0, 'lp': 2400}}
