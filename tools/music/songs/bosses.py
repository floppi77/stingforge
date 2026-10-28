"""Bossmusik für alle zehn Level: ein Generator, zehn Fassungen.

Jeder Bosstrack schließt nahtlos an seinen Leveltrack an: gleiches Tempo, die
Tonart, auf die der Auftakt am Levelende (_kit.lead_in) hinführt, und eine
"Ankunft" auf dem ersten Schlag – genau dann, wenn der Boss erscheint.

Aufbau:  Ankunft (1 Takt, einmalig) | A (16 Takte) | B (16 Takte) → Loop zu A
  A  Ostinato, treibendes Schlagzeug, Leitmotiv des Bosses (zweimal, variiert)
  B  4 Takte Breakdown, 4 Takte Aufbau, 8 Takte Höhepunkt mit Blech/Gegenstimme;
     der letzte Takt führt per Wirbel zurück an den Loopanfang.
Der Loop beginnt nach der Ankunft (meta['loop_start']); render.py faltet den
Hallausklang des Loopendes an den Loopanfang zurück.
"""
from __future__ import annotations

from score import Section, Song, n
from songs._kit import (CRASH, Human, SNARE, SNARE_ROLL, SWELL2, TIMP_LO, TIMP_ROLL_LO, arp, bar_slots,
                        bass_note, bassline, close, crash, drums, pad, voicing)
from songs._themes import leitmotiv, second_theme

# Boss: Tempo und Tonart gleich dem Levelende, Harmonik und Besetzung je Tier.
BOSSES = {
    1: {'title': 'Rosenkäfer', 'bpm': 120, 'key': 'F', 'mode': 'harm',
        'A': ['Fm', 'Db', 'Bbm', 'C7', 'Fm', 'Db', 'Bbm|C7', 'Fm'],
        'B': ['Db', 'Eb', 'Cm', 'Fm', 'Db', 'Bbm', 'G7|C7', 'C7'],
        'ost': ('sfz', 'vln_spic', 0.5), 'lead': ('sfz', 'horn'), 'lead2': ('sfz', 'trb_sus'),
        'stab': ('sfz', 'trb_stac'), 'pad': ('cs', 'pad'), 'bass': 'bass', 'drums': ('boss', 'taiko')},
    2: {'title': 'Riesenlarve', 'bpm': 112, 'key': 'A', 'mode': 'phryg',
        'A': ['Am', 'Bb', 'Am', 'Gm', 'Am', 'Bb', 'C|Bb', 'Am'],
        'B': ['F', 'Gm', 'Am', 'Am', 'F', 'Gm', 'Bb', 'E7'],
        'ost': ('sfz', 'cb_pizz', 0.5), 'lead': ('sfz', 'bassoon'), 'lead2': ('sfz', 'tuba'),
        'stab': ('sfz', 'trb_stac'), 'pad': ('cs', 'drone'), 'bass': 'sub', 'drums': ('taiko', 'tribal')},
    3: {'title': 'Schilfhecht', 'bpm': 96, 'key': 'G', 'mode': 'dorian',
        'A': ['Gm', 'F', 'Eb', 'F', 'Gm', 'C', 'Eb|F', 'Gm'],
        'B': ['Cm', 'Gm', 'Eb', 'F', 'Cm', 'Gm', 'Am7b5|D7', 'D7'],
        'ost': ('sfz', 'marimba', 0.25), 'lead': ('sfz', 'flute'), 'lead2': ('sfz', 'vibes'),
        'stab': ('sfz', 'vln_pizz'), 'pad': ('cs', 'pad'), 'bass': 'bass', 'drums': ('boss', 'tribal')},
    4: {'title': 'Pilzwesen', 'bpm': 90, 'key': 'F#', 'mode': 'dorian',
        'A': ['F#m', 'E', 'F#m', 'B', 'F#m', 'E', 'D|E', 'F#m'],
        'B': ['Bm', 'C#m', 'D', 'E', 'Bm', 'C#m', 'D|C#7', 'C#7'],
        'ost': ('sfz', 'vibes', 0.5), 'lead': ('sfz', 'clarinet'), 'lead2': ('cs', 'glass'),
        'stab': ('sfz', 'vln_pizz'), 'pad': ('cs', 'choir'), 'bass': 'sub', 'drums': ('boss', 'trip')},
    5: {'title': 'Mantidenpaar', 'bpm': 150, 'key': 'E', 'mode': 'harm',
        'A': ['Em', 'C', 'Am', 'B7', 'Em', 'C', 'Am|B7', 'Em'],
        'B': ['C', 'D', 'Bm', 'Em', 'C', 'Am', 'F#m7b5|B7', 'B7'],
        'ost': ('sfz', 'vln_spic', 0.5), 'lead': ('sfz', 'oboe'), 'lead2': ('sfz', 'flute'),
        'stab': ('sfz', 'tpt_stac'), 'pad': ('cs', 'pad'), 'bass': 'bass', 'drums': ('boss', 'taiko'),
        'canon': 1.5},
    6: {'title': 'Mechanischer Bestäuber', 'bpm': 120, 'key': 'B', 'mode': 'min',
        'A': ['Bm', 'C', 'Bm', 'A', 'Bm', 'C', 'D|C', 'Bm'],
        'B': ['G', 'A', 'Bm', 'F#7', 'G', 'Em', 'C|F#7', 'F#7'],
        'ost': ('cs', 'pluck', 0.25), 'lead': ('sfz', 'glock'), 'lead2': ('cs', 'lead'),
        'stab': ('sfz', 'tpt_stac'), 'pad': ('cs', 'glass'), 'bass': 'bass', 'drums': ('boss', 'glitch')},
    7: {'title': 'Wasserläufer', 'bpm': 100, 'key': 'C', 'mode': 'min',
        'A': ['Cm', 'Ab', 'Eb', 'Bb', 'Cm', 'Ab', 'Fm|G7', 'Cm'],
        'B': ['Fm', 'Gm', 'Ab', 'Bb', 'Fm', 'Ab', 'Dm7b5|G7', 'G7'],
        'ost': ('sfz', 'vc_pizz', 0.5), 'lead': ('cs', 'lead'), 'lead2': ('sfz', 'clarinet'),
        'stab': ('sfz', 'trb_stac'), 'pad': ('cs', 'drone'), 'bass': 'sub', 'drums': ('boss', 'dub')},
    8: {'title': 'Erntemaschine', 'bpm': 140, 'key': 'G', 'mode': 'phryg',
        'A': ['Gm', 'Ab', 'Gm', 'F', 'Gm', 'Ab', 'Bb|Ab', 'Gm'],
        'B': ['Eb', 'F', 'Gm', 'D7', 'Eb', 'Cm', 'Ab|D7', 'D7'],
        'ost': ('cs', 'pluck', 0.25), 'lead': ('sfz', 'trb_sus'), 'lead2': ('sfz', 'horn'),
        'stab': ('sfz', 'tpt_stac'), 'pad': ('cs', 'organ'), 'bass': 'bass', 'drums': ('industrial', 'industrial')},
    9: {'title': 'Schwarmkönigin', 'bpm': 146, 'key': 'A', 'mode': 'phryg',
        'A': ['Am', 'Bb', 'Am', 'G', 'Am', 'Bb', 'C|Bb', 'Am'],
        'B': ['F', 'G', 'Am', 'E7', 'F', 'Dm', 'Bb|E7', 'E7'],
        'ost': ('sfz', 'vln_spic', 0.25), 'lead': ('sfz', 'horn'), 'lead2': ('cs', 'lead'),
        'stab': ('sfz', 'trb_stac'), 'pad': ('cs', 'choir'), 'bass': 'bass', 'drums': ('boss', 'taiko')},
    10: {'title': 'Kernorganismus', 'bpm': 128, 'key': 'D', 'mode': 'harm',
         'A': ['Dm', 'Bb', 'Gm', 'A7', 'Dm', 'Bb', 'Gm|A7', 'Dm'],
         'B': ['Bb', 'C', 'Am', 'Dm', 'Bb', 'Gm', 'Em7b5|A7', 'A7'],
         'ost': ('sfz', 'vln_spic', 0.5), 'lead': ('sfz', 'trb_sus'), 'lead2': ('sfz', 'horn'),
         'stab': ('sfz', 'tpt_stac'), 'pad': ('cs', 'organ'), 'bass': 'sub', 'drums': ('boss', 'taiko')},
}

# Mischung je Rolle; Instrument kommt aus der Bosskonfiguration.
GAIN = {'ost': -5.0, 'lead': -1.0, 'lead2': -5.0, 'stab': -5.0, 'pad': -9.0, 'bass': -3.0,
        'kit': -1.0, 'fx': -9.0, 'boom': -6.0, 'riser': -11.0}


def _melody(song: Song, part: str, sec: str, bar: float, notes, vel: int, shift: int, hum: Human,
            legato: float = 0.95, **extra) -> None:
    """Wie _kit.phrase, aber für MIDI-Nummern (leitmotiv() liefert Zahlen)."""
    beat = 0.0
    for p, d in notes:
        if p is not None:
            accent = 6 if beat % 4 == 0 else (2 if beat % 1 == 0 else -2)
            song.add(part, sec, bar, beat, d * legato, int(p) + shift, hum.v(vel + accent, 4), **extra)
        beat += d


def _fit(notes, inst_kind: str, inst: str, prefer_center: int) -> int:
    """Lage wählen: Melodie in den Samplebereich (sfz) bzw. um prefer_center (Synth)."""
    ps = [int(p) for p, _ in notes if p is not None]
    if not ps:
        return 0
    if inst_kind == 'sfz':
        import sfz
        lo, hi = sfz.pitch_window(inst)
        best = min((0, -12, 12, -24, 24, -36),
                   key=lambda sh: (-sum(1 for p in ps if lo + 2 <= p + sh <= hi - 2), abs(sum(ps) / len(ps) + sh - prefer_center)))
        return best
    mid = sum(ps) / len(ps)
    return int(round((prefer_center - mid) / 12.0)) * 12


def make(level: int):
    cfg = BOSSES[level]
    spb = 60.0 / cfg['bpm']
    secs = [Section('arrive', 0.0, 1, 4.0, spb)]
    t = 4 * spb
    for name in ('A', 'B'):
        secs.append(Section(name, t, 16, 4.0, spb))
        t += 16 * 4 * spb
    song = Song(secs, t)
    hum = Human(9000 + level)
    S = song
    key, mode = cfg['key'], cfg['mode']
    tonic = cfg['A'][0]
    spec: dict = {}

    def part(role: str, extra: dict | None = None) -> str:
        kind, inst = cfg[role][0], cfg[role][1]
        name = role
        spec[name] = ({'engine': 'sfz', 'inst': inst} if kind == 'sfz' else {'engine': 'cs', 'instr': inst})
        spec[name].update({'gain': GAIN[role], 'rev': 0.25})
        if extra:
            spec[name].update(extra)
        return name

    ost = part('ost', {'pan': -0.2, 'rev': 0.18})
    lead = part('lead', {'pan': 0.05, 'rev': 0.28, 'dly': 0.12})
    lead2 = part('lead2', {'pan': 0.25, 'rev': 0.3})
    stab = part('stab', {'pan': -0.1, 'rev': 0.22})
    pd = part('pad', {'hp': 140, 'rev': 0.35, 'width': 1.2})
    spec['bass'] = {'engine': 'cs', 'instr': cfg['bass'], 'gain': GAIN['bass'], 'lp': 2400}
    spec['kit'] = {'engine': 'sfz', 'inst': 'kit', 'gain': GAIN['kit'], 'rev': 0.14}
    spec['fx'] = {'engine': 'sfz', 'inst': 'kit', 'gain': GAIN['fx'], 'rev': 0.3}
    spec['boom'] = {'engine': 'cs', 'instr': 'boom', 'gain': GAIN['boom'], 'rev': 0.1}
    spec['riser'] = {'engine': 'cs', 'instr': 'riser', 'gain': GAIN['riser'], 'rev': 0.2}
    step = cfg['ost'][2]
    main_style, alt_style = cfg['drums']

    # ------------------------------------------------ Ankunft: Boss erscheint
    crash(S, 'kit', 'arrive', 0, 120)
    S.add('kit', 'arrive', 0, 0, 2, TIMP_LO, 124)
    S.add('boom', 'arrive', 0, 0, 3, bass_note(tonic) - 12 if bass_note(tonic) >= n('E1') + 12 else bass_note(tonic), 104)
    S.add('bass', 'arrive', 0, 0, 1.8, bass_note(tonic), 110, bright=0.6)
    for p in close(tonic, n('A3'), 3):
        S.add(stab, 'arrive', 0, 0, 0.6, p, 112)
    arp(S, ost, 'arrive', 0, [tonic], step=step, low=n('D3'), high=n('D5'), vel=70, human=hum, ring=1.2)
    for i in range(8):
        S.add('kit', 'arrive', 0, 2.0 + i * 0.25, 0.25, SNARE, 60 + i * 7)

    head = leitmotiv(key, mode, part='head')
    tail = leitmotiv(key, mode, part='tail')
    theme2 = second_theme(key, mode)
    sh = _fit(head + tail, cfg['lead'][0], cfg['lead'][1], n('A4'))

    # ------------------------------------------------ A: Ostinato + Leitmotiv
    A = cfg['A'] * 2
    arp(S, ost, 'A', 0, A, step=step, low=n('D3'), high=n('D5'), shape='broken', vel=74, human=hum, ring=1.1)
    bassline(S, 'bass', 'A', 0, A, 'drive', vel=96, human=hum, bright=0.55)
    pad(S, pd, 'A', 0, A, vel=56, center=n('F#4'), bright=0.35)
    drums(S, 'kit', 'A', 0, 7, main_style, vel=100, human=hum)
    drums(S, 'kit', 'A', 7, 1, main_style, vel=100, human=hum, fill='snare')
    drums(S, 'kit', 'A', 8, 7, main_style, vel=104, human=hum)
    drums(S, 'kit', 'A', 15, 1, main_style, vel=104, human=hum, fill='timp')
    crash(S, 'kit', 'A', 8, 100)
    _melody(S, lead, 'A', 0, head, 96, sh, hum)
    _melody(S, lead, 'A', 4, tail, 92, sh, hum)
    _melody(S, lead, 'A', 8, head, 100, sh, hum)
    _melody(S, lead, 'A', 12, tail, 96, sh, hum)
    canon = cfg.get('canon')
    sh2 = _fit(head + tail, cfg['lead2'][0], cfg['lead2'][1], n('E5'))
    if canon:
        # Mantidenpaar: zweite Klinge antwortet um anderthalb Schläge versetzt.
        _melody(S, lead2, 'A', 8 + canon / 4.0, head, 84, sh2, hum)
        _melody(S, lead2, 'A', 12 + canon / 4.0, tail, 80, sh2, hum)
    else:
        _melody(S, lead2, 'A', 8, head, 74, sh2 + 12 if sh2 + 12 <= 24 else sh2, hum)

    # ------------------------------------------------ B: Breakdown, Aufbau, Höhepunkt
    B = cfg['B'] * 2
    pad(S, pd, 'B', 0, B[:8], vel=62, center=n('A4'), bright=0.25)
    arp(S, ost, 'B', 0, B[:4], step=step * 2, low=n('D3'), high=n('A4'), shape='up', vel=64, human=hum)
    for b, slots in enumerate(bar_slots(B[:4])):
        S.add('bass', 'B', b, 0, 3.6, bass_note(slots[0][2]), 84, bright=0.3)
    drums(S, 'kit', 'B', 0, 4, alt_style, vel=88, human=hum)
    sh3 = _fit(theme2, cfg['lead2'][0], cfg['lead2'][1], n('D5'))
    _melody(S, lead2, 'B', 0, theme2[:len(theme2) // 2], 82, sh3, hum)
    # Aufbau: Ostinato verdichtet, Wirbel, Riser
    arp(S, ost, 'B', 4, B[4:8], step=step, low=n('D3'), high=n('D5'), shape='updown', vel=72, human=hum, ring=1.1)
    bassline(S, 'bass', 'B', 4, B[4:8], 'pulse', vel=90, bright=0.5)
    drums(S, 'kit', 'B', 4, 4, 'march', vel=96, human=hum)
    S.add('riser', 'B', 6, 0, 8, n(key + '2'), 80)
    S.add('fx', 'B', 6, 0, 8, SWELL2, 90)
    # Höhepunkt: volle Besetzung, Leitmotiv im Blech, Stöße
    crash(S, 'kit', 'B', 8, 118)
    S.add('boom', 'B', 8, 0, 3, bass_note(B[8]), 100)
    arp(S, ost, 'B', 8, B[8:], step=step, low=n('D3'), high=n('D5'), shape='broken', vel=78, human=hum, ring=1.1)
    bassline(S, 'bass', 'B', 8, B[8:], 'drive', vel=100, human=hum, bright=0.6)
    pad(S, pd, 'B', 8, B[8:], vel=64, center=n('F#4'), bright=0.5)
    drums(S, 'kit', 'B', 8, 7, main_style, vel=108, human=hum)
    _melody(S, lead, 'B', 8, head, 104, sh, hum)
    _melody(S, lead, 'B', 12, tail, 100, sh, hum)
    for b, slots in enumerate(bar_slots(B[8:])):
        for p in close(slots[0][2], n('G3'), 3):
            S.add(stab, 'B', 8 + b, 0, 0.45, p, 108)
            S.add(stab, 'B', 8 + b, 2.5, 0.35, p, 96)
    # Letzter Takt: Wirbel zurück an den Loopanfang (A beginnt auf der Tonika)
    S.add('kit', 'B', 15, 0, 4, SNARE_ROLL, 104)
    S.add('kit', 'B', 15, 2, 2, TIMP_ROLL_LO, 100)

    meta = {'file': f'boss{level}', 'title': f'Boss {level} – {cfg["title"]}', 'reverb': 2.2,
            'loop_start': secs[1].start}
    return song, spec, meta
