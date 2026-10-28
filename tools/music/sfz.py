"""SFZ-Instrumente aus den CC0-Bibliotheken (VSCO 2 CE, VCSL) erzeugen.

Die Bibliotheken liegen als reine WAV-Sammlungen in tools/audio/samples/. Dieser
Baustein liest Tonhöhe, Dynamikstufe und Round-Robin aus den Dateinamen und
schreibt je Instrument eine SFZ-Datei nach tools/music/build/sfz/.
Schlagzeug und Effekte werden über feste Tastenbelegungen (KITS) abgebildet.
"""
from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path

from score import ROOT, n

LIB = ROOT / 'tools/audio/samples'
OUT = ROOT / 'tools/music/build/sfz'
VSCO = LIB / 'VSCO-2-CE'
VCSL = LIB / 'VCSL'
DYN = {'ppp': 1, 'pp': 2, 'p': 3, 'mp': 4, 'mf': 5, 'f': 6, 'ff': 7, 'fff': 8}

# name: (Ordner, Dateifilter, Optionen)
PITCHED = {
    'harp': (VSCO / 'Strings/Harp', None, {'ampeg_release': 2.2}),
    'flute': (VSCO / 'Woodwinds/Flute/susvib', None, {'ampeg_attack': 0.03, 'ampeg_release': 0.35}),
    'flute_stac': (VSCO / 'Woodwinds/Flute/stac', None, {'ampeg_release': 0.2}),
    'piccolo': (VSCO / 'Woodwinds/Piccolo/Sus', None, {'ampeg_attack': 0.02, 'ampeg_release': 0.3}),
    'oboe': (VSCO / 'Woodwinds/Oboe/Vib', None, {'ampeg_attack': 0.03, 'ampeg_release': 0.3}),
    'clarinet': (VSCO / 'Woodwinds/Clarinet/susLong', None, {'ampeg_attack': 0.03, 'ampeg_release': 0.3}),
    'bassoon': (VSCO / 'Woodwinds/Bassoon/vib', None, {'ampeg_attack': 0.03, 'ampeg_release': 0.3}),
    'vln_sus': (VSCO / 'Strings/Violin Section/susVib', None, {'ampeg_attack': 0.12, 'ampeg_release': 0.6}),
    'vln_pizz': (VSCO / 'Strings/Violin Section/Pizz', None, {'ampeg_release': 0.6}),
    'vln_spic': (VSCO / 'Strings/Violin Section/Spic', None, {'ampeg_release': 0.25}),
    'vla_sus': (VSCO / 'Strings/Viola Section/susvib', None, {'ampeg_attack': 0.12, 'ampeg_release': 0.6}),
    'vc_sus': (VSCO / 'Strings/Cello Section/susvib', None, {'ampeg_attack': 0.12, 'ampeg_release': 0.6}),
    'vc_pizz': (VSCO / 'Strings/Cello Section/pizzT', None, {'ampeg_release': 0.6}),
    'cb_pizz': (VSCO / 'Strings/Solo Contrabass/Pizz', None, {'ampeg_release': 0.6}),
    'horn': (VSCO / 'Brass/F Horn/sus', None, {'ampeg_attack': 0.06, 'ampeg_release': 0.5}),
    'glock': (VSCO / 'Percussion/Glock', None, {'ampeg_release': 2.5}),
    'marimba': (VSCO / 'Percussion/Marimba', None, {'ampeg_release': 1.2}),
    'xylo': (VSCO / 'Percussion/Xylo', None, {'ampeg_release': 0.8}),
    'kalimba': (VCSL / 'Idiophones/Plucked Idiophones/Kalimba, Kenya', None, {'ampeg_release': 1.8}),
    'vibes': (VCSL / 'Idiophones/Struck Idiophones/Vibraphone', None, {'ampeg_release': 2.5}),
    'celesta': (VCSL / 'Idiophones/Struck Idiophones/Tubular Glockenspiel', None, {'ampeg_release': 2.5}),
    'piano': (VCSL / 'Chordophones/Zithers/Upright Piano, Yamaha', None, {'ampeg_release': 0.9}),
    # Blech für Level 5 (Streicher-Ostinati gegen Blechstöße)
    'tuba': (VSCO / 'Brass/Tuba/sus', None, {'ampeg_attack': 0.05, 'ampeg_release': 0.45}),
    'trb_sus': (VSCO / 'Brass/Tenor Trombone/sus', None, {'ampeg_attack': 0.04, 'ampeg_release': 0.35}),
    'trb_stac': (VSCO / 'Brass/Tenor Trombone/stac', None, {'ampeg_release': 0.25}),
    'tpt_stac': (VSCO / 'Brass/Trumpet/stac', None, {'ampeg_release': 0.22}),
    # Balafon (Level 2: afrikanisches Holzstabinett) und Röhrenglocken (Level 10)
    'balafon': (VCSL / 'Idiophones/Struck Idiophones/Balafon/Hard Mallet', None, {'ampeg_release': 1.4}),
    'balafon_s': (VCSL / 'Idiophones/Struck Idiophones/Balafon/Soft Mallet', None, {'ampeg_release': 1.4}),
    'tubular': (VCSL / 'Idiophones/Struck Idiophones/Tubular Bells 1', None, {'ampeg_release': 3.0}),
}

# Gemessener Oktavversatz (Dateiname -> klingende Tonhöhe in Oktaven): die Bibliotheken
# benennen das eingestrichene C meist als C3. Kontrolliert mit Fundamentalfrequenz-Messung:
# Harfe 0, Klavier (Yamaha Upright) 2, alle übrigen +1. Röhrenglockenspiel (celesta) folgt
# einer unklaren Namenskonvention und wird nicht verwendet.
OCTAVE = {'harp': 0, 'piano': 2, 'celesta': 0}
DEFAULT_OCTAVE = 1

S = VCSL / 'Membranophones/Struck Membranophones'
I = VCSL / 'Idiophones/Struck Idiophones'
C = VSCO / 'VSCO 1 Percussion/varMetal/Cymbals'
# Tastenbelegung (General-MIDI-nah). Jede Taste: Liste von Dateigruppen je Dynamik.
KITS = {
    'kit': {
        36: [[S / 'Bass Drum 1' / f'BDrumNew_hit_v{v}_rr{r}_Sum.wav' for r in (1, 2)] for v in (2, 3, 5, 7)],
        38: [[S / 'Snare Drum, Modern 1' / f'Snare2_HitSN_v{v}_rr{r}_Mid.wav' for r in (1, 2)] for v in (3, 5, 7, 9)],
        37: [[S / 'Snare Drum, Modern 1' / f'Snare2_stick_v1_rr{r}_Mid.wav' for r in (1, 2)]],
        40: [[S / 'Snare Drum, Modern 1' / f'Snare2_taps_v4_rr{r}_Mid.wav' for r in (1, 2)]],
        39: [[I / 'Claps' / f'Clap_rr{r}.wav' for r in range(1, 7)]],
        42: [[I / 'Hi-Hat Cymbal' / f'HiHat_HitC_v{v}_rr{r}_Mid.wav' for r in (1, 2)] for v in (1, 2, 3, 4)],
        44: [[I / 'Hi-Hat Cymbal' / f'HiHat_Close_rr{r}_Mid.wav' for r in (1, 2)]],
        46: [[I / 'Hi-Hat Cymbal' / f'HiHat_HitO_rr{r}_Mid.wav' for r in (1, 2)]],
        49: [[C / 'crash_hit_mp_loose.wav'], [C / 'crash_hit_ff_loose.wav'], [C / 'crash_hit_fff_loose.wav']],
        51: [[I / 'Suspended Cymbal 1' / 'susCymb1_hit_stick_pp1.wav'],
             [I / 'Suspended Cymbal 1' / 'susCymb1_hit_stick_mp1.wav'],
             [I / 'Suspended Cymbal 1' / 'susCymb1_hit_stick_f1.wav']],
        52: [[I / 'Suspended Cymbal 1' / 'susCymb1_cresc_2s.wav']],
        53: [[I / 'Suspended Cymbal 1' / 'susCymb1_cresc_4s.wav']],
        57: [[I / 'Suspended Cymbal 1' / 'susCymb1_hit_fff1.wav']],
        54: [[I / 'Tambourine 1' / 'Tamb1_Hit_v1_rr1_Mid.wav'], [I / 'Tambourine 1' / 'Tamb1_Hit_v2_rr1_Mid.wav']],
        55: [[I / 'Tambourine 1' / f'Tamb1_Shake_rr{r}_Mid.wav' for r in (1, 2)]],
        70: [[I / 'Shaker, Small' / f'Mid_ShakerHighFaster_Down_rr{r}.wav' for r in (1, 2)]],
        69: [[I / 'Shaker, Small' / f'Mid_ShakerHighFaster_Up_rr{r}.wav' for r in (1, 2)]],
        71: [[I / 'Shaker, Small' / f'Mid_ShakerDouble_Down_rr{r}.wav' for r in (1, 2)]],
        81: [[I / 'Triangles' / p.name] for p in sorted((I / 'Triangles').glob('*.wav'))[:1]],
        84: [[I / 'Mark Trees' / 'windchimes_slowAsc1.wav']],
        85: [[I / 'Mark Trees' / 'windchimes_fastAsc1.wav']],
        86: [[I / 'Mark Trees' / 'windchimes_slowDesc1.wav']],
        # Pauken (fünf Kessel, ungestimmt verwendet: tief -> hoch)
        41: [[VSCO / 'Percussion/Timpani' / f'Timpani1_Hit_v{v}_rr{r}_Sum.wav' for r in (1, 2)] for v in (1, 3)],
        43: [[VSCO / 'Percussion/Timpani' / f'Timpani2_Hit_v{v}_rr{r}_Sum.wav' for r in (1, 2)] for v in (1, 3, 4)],
        45: [[VSCO / 'Percussion/Timpani' / f'Timpani3_Hit_v{v}_rr{r}_Sum.wav' for r in (1, 2)] for v in (1, 3, 4)],
        47: [[VSCO / 'Percussion/Timpani' / 'Timpani1_Roll_v5_rr1_Sum.wav']],
        48: [[VSCO / 'Percussion/Timpani' / 'Timpani2_Roll_v5_rr1_Sum.wav']],
        59: [[S / 'Snare Drum, Modern 1' / 'Snare2_rollSN_v5_rr2_Mid.wav']],
        58: [[S / 'Snare Drum, Modern 1' / 'Snare2_rollSN_v2_rr1_Mid.wav']],
        # --- Erweiterung für Level 2–10 ---------------------------------
        # Industrielles Metall (Level 8 Maschinenherz, Level 9 Schwarmstock)
        60: [[I / 'Anvil' / f'Anvil_Hit1_v{v}_rr1_Mid.wav'] for v in (1, 2, 3)],
        61: [[I / 'Anvil' / f'Anvil_Hit2_v{v}_rr1_Mid.wav'] for v in (1, 2, 3)],
        62: [[I / 'Anvil' / f'Anvil_Hit3_v{v}_rr1_Mid.wav'] for v in (1, 2, 3)],
        63: [[I / 'Brake Drum' / f'BrakeDrum1_Hammer_v{v}_rr1_Mid.wav'] for v in (1, 2, 3)],
        64: [[I / 'Brake Drum' / f'BrakeDrum2_Hammer1_v{v}_rr1_Mid.wav'] for v in (1, 2)],
        65: [[I / 'Brake Drum' / f'BrakeDrum1_Susp_v{v}_rr1_Mid.wav'] for v in (1, 3)],
        # Schlitztrommel und Rahmentrommel (Level 2 Wurzelreich, Level 9)
        66: [[I / 'Slit Drum' / f'LogDrumLo_MedM_v{v}_rr1_Sum.wav'] for v in (1, 2, 3)],
        67: [[I / 'Slit Drum' / f'LogDrumHi_MedM_v{v}_rr1_Sum.wav'] for v in (1, 2, 3)],
        68: [[S / 'Frame Drum' / f'HDrumL_Hit_v{v}_rr{r}_Sum.wav' for r in (1, 2)] for v in (2, 3)],
        72: [[S / 'Frame Drum' / f'HDrumS_Hit_v{v}_rr{r}_Sum.wav' for r in (1, 2)] for v in (2, 3)],
        # Gong, Holz, Ratsche, Darbuka/Conga/Toms
        73: [[I / 'Gong 1' / 'gong_mp.wav'], [I / 'Gong 1' / 'gong_f.wav'], [I / 'Gong 1' / 'gong_fff.wav']],
        74: [[I / 'Woodblock' / 'wood_click3_vl1.wav'], [I / 'Woodblock' / 'wood_click3_vl2.wav']],
        75: [[I / 'Ratchet' / 'Ratchet1_Fast_rr1_Mid.wav'], [I / 'Ratchet' / 'Ratchet1_Slow_rr1_Mid.wav']],
        76: [[S / 'Darbuka' / f'Darbuka_{k}_hit_vl{v}_rr{r}.wav' for r in (1, 2)] for k in (1, 2, 3) for v in (1, 2)],
        77: [[S / 'Conga' / f'Conga_HitN_v{v}_rr{r}_Sum.wav' for r in (1, 2)] for v in (1, 2, 3)],
        78: [[S / 'Conga' / f'Quinto_HitN_v{v}_rr{r}_Sum.wav' for r in (1, 2)] for v in (1, 2, 3)],
        79: [[S / 'Tom 2/Stick' / f'TomL_HitS_v{v}_rr{r}_Mid.wav' for r in (1, 2)] for v in (2, 3, 4)],
        80: [[S / 'Tom 1/Stick' / f'TomH_HitS_v{v}_rr{r}_Mid.wav' for r in (1, 2)] for v in (2, 3, 4)],
        82: [[S / 'Bass Drum 2' / p2] for p2 in ('bassdrum_hit_mf1.wav', 'bassdrum_hit_ff.wav')],
        83: [[I / 'Clash Cymbals 1' / p2] for p2 in ('cymbal_crash1_mf1.wav', 'cymbal_crash1_ff2.wav')],
    },
}

PITCH_RE = re.compile(r'(?:^|_)([A-G](?:#|b)?-?\d)(?=_|\.wav$)')
VEL_RE = re.compile(r'_v(?:l)?(\d+)')
DYN_RE = re.compile(r'_(ppp|pp|p|mp|mf|f|ff|fff)(?=_|\.wav$)')


def _parse(path: Path):
    name = path.name
    m = PITCH_RE.search(name)
    if not m:
        return None
    pitch = n(m.group(1))
    v = VEL_RE.search(name)
    d = DYN_RE.search(name)
    layer = int(v.group(1)) if v else (DYN[d.group(1)] if d else 5)
    return pitch, layer


def _header(opts: dict) -> str:
    return '<group> ' + ' '.join(f'{k}={v}' for k, v in opts.items())


def build_pitched(name: str) -> Path:
    folder, flt, opts = PITCHED[name]
    files = sorted(p for p in folder.rglob('*.wav') if flt is None or re.search(flt, p.name))
    table: dict[int, dict[int, list[Path]]] = defaultdict(lambda: defaultdict(list))
    shift = 12 * OCTAVE.get(name, DEFAULT_OCTAVE)
    for p in files:
        parsed = _parse(p)
        if parsed:
            table[parsed[1]][parsed[0] + shift].append(p)
    if not table:
        raise SystemExit(f'{name}: keine Samples in {folder}')
    layers = sorted(table)
    lines = [f'// {name} – automatisch erzeugt aus {folder.relative_to(LIB)}',
             _header({'ampeg_attack': 0.002, 'amp_veltrack': 82, **opts})]
    for li, layer in enumerate(layers):
        lovel = 1 + (127 * li) // len(layers)
        hivel = (127 * (li + 1)) // len(layers)
        pitches = sorted(table[layer])
        for pi, pitch in enumerate(pitches):
            lo = 0 if pi == 0 else (pitches[pi - 1] + pitch) // 2 + 1
            hi = 127 if pi == len(pitches) - 1 else (pitch + pitches[pi + 1]) // 2
            rrs = table[layer][pitch]
            for ri, p in enumerate(rrs):
                rand = f' lorand={ri / len(rrs):.4f} hirand={(ri + 1) / len(rrs):.4f}' if len(rrs) > 1 else ''
                lines.append(f'<region> sample={p} pitch_keycenter={pitch} lokey={lo} hikey={hi} '
                             f'lovel={lovel} hivel={hivel}{rand}')
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f'{name}.sfz'
    out.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return out


_WINDOW_CACHE: dict[str, tuple[int, int]] = {}


def pitch_window(name: str) -> tuple[int, int]:
    """Spielbare MIDI-Keys einer Stimme: echte Samples inklusive Oktavversatz.

    Außerhalb dieses Fensters streckt sfizz die Randprobe – das klingt gequetscht
    und verstimmt. Komponisten sollten hier prüfen, nicht hören.
    """
    if name in KITS:
        return (0, 127)
    if name in _WINDOW_CACHE:
        return _WINDOW_CACHE[name]
    folder, flt, _opts = PITCHED[name]
    shift = 12 * OCTAVE.get(name, DEFAULT_OCTAVE)
    lo = hi = None
    for f in folder.rglob('*.wav'):
        if flt is not None and not re.search(flt, f.name):
            continue
        parsed = _parse(f)
        if not parsed:
            continue
        k = parsed[0] + shift
        lo = k if lo is None else min(lo, k)
        hi = k if hi is None else max(hi, k)
    if lo is None:
        raise SystemExit(f'{name}: keine Samples für die Lage gefunden')
    _WINDOW_CACHE[name] = (lo, hi)
    return (lo, hi)


def _resolve(p: Path) -> Path | None:
    """Datei direkt oder in einem Unterordner (z. B. Timpani/Rolls) finden."""
    if p.exists():
        return p
    hits = list(p.parent.rglob(p.name))
    return hits[0] if hits else None


def build_kit(name: str) -> Path:
    lines = [f'// {name} – Schlagzeug/Effekte, feste Belegung',
             _header({'loop_mode': 'one_shot', 'amp_veltrack': 70, 'ampeg_release': 0.4})]
    for key, layers in sorted(KITS[name].items()):
        layers = [[q for q in (_resolve(p) for p in group) if q is not None] for group in layers]
        layers = [g for g in layers if g]
        if not layers:
            raise SystemExit(f'{name}: Taste {key} ohne Samples')
        for li, group in enumerate(layers):
            lovel = 1 + (127 * li) // len(layers)
            hivel = (127 * (li + 1)) // len(layers)
            for ri, p in enumerate(group):
                rand = f' lorand={ri / len(group):.4f} hirand={(ri + 1) / len(group):.4f}' if len(group) > 1 else ''
                lines.append(f'<region> sample={p} key={key} lovel={lovel} hivel={hivel}{rand}')
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f'{name}.sfz'
    out.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return out


def build(name: str) -> Path:
    return build_kit(name) if name in KITS else build_pitched(name)


if __name__ == '__main__':
    for nm in list(PITCHED) + list(KITS):
        p = build(nm)
        print(nm, sum(1 for line in p.read_text().splitlines() if line.startswith('<region>')), 'Regionen')
