"""Stingforge-Soundtrack: Partitur-Grundlagen.

Ein Song ist eine Folge von Abschnitten mit eigener Taktart und eigenem Tempo.
Die Tempokarte wird so gerechnet, dass jeder Spielabschnitt (Checkpoint) exakt
eine ganze Zahl Takte lang ist: Abschnittswechsel fallen auf Taktanfänge und
liegen sample-genau an der Levelzeit.

Zeiten in der Partitur sind Schläge (Viertel) relativ zum Abschnittsanfang;
`Song.sec()` rechnet in Sekunden um. Noten werden als `Note` gesammelt und je
Stimme als MIDI (für sfizz) oder als Csound-Partitur (für Synthesizer) ausgegeben.
"""
from __future__ import annotations

import math
import re
from dataclasses import dataclass, field
from pathlib import Path

import mido

ROOT = Path(__file__).resolve().parents[2]
PPQ = 960

NOTE_NAMES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def n(name) -> int:
    """'C4' -> 60, 'F#5' -> 78, 'Bb3' -> 58. Zahlen werden unverändert durchgereicht."""
    if isinstance(name, int):
        return name
    m = re.fullmatch(r'([A-G])([#b]?)(-?\d)', name)
    if not m:
        raise ValueError(name)
    pc = NOTE_NAMES[m.group(1)] + {'#': 1, 'b': -1, '': 0}[m.group(2)]
    return 12 * (int(m.group(3)) + 1) + pc


def level_timeline(level: int) -> dict:
    """Abschnittslängen, Miniboss-Zeit, Intro und Ankündigung aus dem Spielcode."""
    src = (ROOT / 'scripts/autoload/data.gd').read_text(encoding='utf-8')
    m = re.search(r'"id": %d, "name": "([^"]+)".*?"sections": \[(.*?)\n\t\t\],\n\t\t"miniboss": \{"t": ([\d.]+)'
                  % level, src, re.S)
    if not m:
        raise ValueError(f'Level {level} nicht gefunden')
    durs = [float(x) for x in re.findall(r'"dur": ([\d.]+)', m.group(2))]
    director = (ROOT / 'scripts/game/director.gd').read_text(encoding='utf-8')
    intro = float(re.search(r'const INTRO_TIME := ([\d.]+)', director).group(1))
    game = (ROOT / 'scripts/game/game.gd').read_text(encoding='utf-8')
    announce = float(re.search(r'func _on_boss_triggered.*?create_timer\(([\d.]+), false\)', game, re.S).group(1))
    return {'name': m.group(1), 'sections': durs, 'miniboss': float(m.group(3)),
            'intro': intro, 'announce': announce,
            'length': intro + sum(durs) + announce}


@dataclass
class Section:
    name: str
    start: float          # Sekunden
    bars: int
    beats_per_bar: float  # in Vierteln (5/8 = 2.5)
    spb: float            # Sekunden je Viertel

    @property
    def bpm(self) -> float:
        return 60.0 / self.spb

    @property
    def beats(self) -> float:
        return self.bars * self.beats_per_bar

    @property
    def end(self) -> float:
        return self.start + self.beats * self.spb


@dataclass
class Note:
    t: float        # Sekunden
    dur: float      # Sekunden
    pitch: int
    vel: int = 96
    extra: dict = field(default_factory=dict)


class Song:
    """Abschnitte + Stimmen. Stimmen sind Listen von Noten (Sekunden)."""

    def __init__(self, sections: list[Section], length: float):
        self.sections = sections
        self.length = length
        self.parts: dict[str, list[Note]] = {}
        self.cc: dict[str, list[tuple[float, int, int]]] = {}

    @classmethod
    def for_level(cls, level: int, bpm: float, intro_beats: float = 4.0,
                  tail_beats: float = 2.5) -> 'Song':
        tl = level_timeline(level)
        secs = []
        t = 0.0
        # Intro (Spiel steht noch): ein freier Auftakt passender Länge.
        secs.append(Section('intro', t, 1, intro_beats, tl['intro'] / intro_beats))
        t += tl['intro']
        for i, dur in enumerate(tl['sections']):
            bars = max(1, round(dur * bpm / 240.0))
            secs.append(Section('ABCDEFG'[i], t, bars, 4.0, dur / (bars * 4.0)))
            t += dur
        secs.append(Section('tail', t, 1, tail_beats, tl['announce'] / tail_beats))
        song = cls(secs, tl['length'])
        song.timeline = tl
        return song

    def sec(self, name: str, bar: float = 0.0, beat: float = 0.0) -> float:
        s = self.section(name)
        return s.start + (bar * s.beats_per_bar + beat) * s.spb

    def section(self, name: str) -> Section:
        for s in self.sections:
            if s.name == name:
                return s
        raise KeyError(name)

    def beat_len(self, name: str, beats: float) -> float:
        return beats * self.section(name).spb

    def add(self, part: str, section: str, bar: float, beat: float, dur_beats: float,
            pitch: int, vel: int = 96, **extra) -> None:
        s = self.section(section)
        self.parts.setdefault(part, []).append(
            Note(self.sec(section, bar, beat), dur_beats * s.spb, pitch, vel, extra))

    def add_abs(self, part: str, t: float, dur: float, pitch: int, vel: int = 96, **extra) -> None:
        self.parts.setdefault(part, []).append(Note(t, dur, pitch, vel, extra))

    def add_cc(self, part: str, t: float, cc: int, value: int) -> None:
        self.cc.setdefault(part, []).append((t, cc, value))

    # ------------------------------------------------------------- Ausgabe
    def _ticks(self, t: float) -> int:
        """Sekunden -> MIDI-Ticks entlang der Tempokarte."""
        ticks = 0.0
        for s in self.sections:
            if t <= s.start:
                break
            span = min(t, s.end) - s.start
            ticks += span / s.spb * PPQ
        return int(round(ticks))

    def write_midi(self, part: str, path: Path, program: int | None = None,
                   pitch_map=None) -> None:
        mf = mido.MidiFile(ticks_per_beat=PPQ)
        tr = mido.MidiTrack()
        mf.tracks.append(tr)
        events: list[tuple[int, int, mido.Message]] = []
        for s in self.sections:
            events.append((self._ticks(s.start), 0,
                           mido.MetaMessage('set_tempo', tempo=int(round(s.spb * 1e6)))))
        if program is not None:
            events.append((0, 1, mido.Message('program_change', program=program)))
        for t, cc, val in self.cc.get(part, []):
            events.append((self._ticks(t), 2, mido.Message('control_change', control=cc, value=val)))
        pm = pitch_map or (lambda p: p)
        for note in self.parts.get(part, []):
            on = self._ticks(note.t)
            off = max(on + 1, self._ticks(note.t + note.dur))
            pitch = max(0, min(127, int(pm(note.pitch))))
            events.append((on, 4, mido.Message('note_on', note=pitch, velocity=max(1, min(127, note.vel)))))
            events.append((off, 3, mido.Message('note_off', note=pitch, velocity=0)))
        end = self._ticks(self.length) + PPQ * 16  # Ausklang nicht abschneiden
        events.append((end, 9, mido.MetaMessage('end_of_track')))
        events.sort(key=lambda e: (e[0], e[1]))
        last = 0
        for tick, _, msg in events:
            if msg.type == 'end_of_track':
                tr.append(msg.copy(time=tick - last))
                break
            tr.append(msg.copy(time=tick - last))
            last = tick
        mf.save(path)

    def describe(self) -> str:
        rows = []
        for s in self.sections:
            rows.append(f'{s.name:5s} {s.start:8.3f}s  {s.bars:3d} Takte  {s.bpm:7.3f} BPM')
        rows.append(f'Länge {self.length:.3f}s')
        return '\n'.join(rows)


def midi_to_hz(p: float) -> float:
    return 440.0 * 2 ** ((p - 69) / 12)


def chord(root: str, quality: str = 'maj', inversion: int = 0) -> list[int]:
    r = n(root)
    iv = {'maj': [0, 4, 7], 'min': [0, 3, 7], 'maj7': [0, 4, 7, 11], 'min7': [0, 3, 7, 10],
          '7': [0, 4, 7, 10], 'sus2': [0, 2, 7], 'sus4': [0, 5, 7], 'add9': [0, 4, 7, 14],
          'madd9': [0, 3, 7, 14], 'dim': [0, 3, 6], 'aug': [0, 4, 8], 'm7b5': [0, 3, 6, 10],
          '6': [0, 4, 7, 9], 'min6': [0, 3, 7, 9], 'maj9': [0, 4, 7, 11, 14]}[quality]
    notes = [r + i for i in iv]
    for _ in range(inversion):
        notes = notes[1:] + [notes[0] + 12]
    return notes


def humanize(seed: int):
    """Kleine, deterministische Abweichungen für Zeit (s) und Anschlag."""
    import random
    rng = random.Random(seed)

    def f(t_amount: float = 0.006, v_amount: int = 6):
        return rng.uniform(-t_amount, t_amount), rng.randint(-v_amount, v_amount)
    return f


def db(x: float) -> float:
    return 10 ** (x / 20.0)


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


__all__ = ['Song', 'Section', 'Note', 'n', 'chord', 'midi_to_hz', 'humanize', 'db', 'clamp',
           'level_timeline', 'ROOT', 'math']
