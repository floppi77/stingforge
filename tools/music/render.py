"""Stingforge-Soundtrack: Stimmen rendern, mischen, mastern, messen.

Aufruf:  python3 tools/music/render.py level01 [--stems-only] [--keep]

Ablauf je Song (tools/music/songs/<name>.py liefert build() -> (Song, MIX)):
  1. SFZ-Stimmen: MIDI schreiben, sfizz_render -> Stem-WAV (48 kHz)
  2. Csound-Stimmen: Partitur aus den Noten, csound -> Stem-WAV
  3. Mix (numpy): Filter, Pegel, Panorama, Sidechain, Hall- und Delay-Bus
  4. Master: Hochpass, Bus-Kompressor, Lautheit auf Ziel-LUFS, True-Peak-Limiter
  5. Exakte Länge (sample-genau), OGG Vorbis, Messbericht + Spektrogramm
"""
from __future__ import annotations

import argparse
import importlib
import json
import math
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal
from scipy.ndimage import maximum_filter1d

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from score import ROOT, Song, midi_to_hz  # noqa: E402
import sfz  # noqa: E402

SR = 48000
BUILD = HERE / 'build'
TARGET_LUFS = -16.0
TARGET_TP = -1.0
OUT_DIR = ROOT / 'assets/audio/music'


# ------------------------------------------------------------------ Rendern
# Ziel-Lagen der Csound-Synthesestimen (keine Proben, also eine Satzentscheidung):
# Stimme -> (tiefster, höchster geschriebener Ton). Außerhalb klingt es entweder
# mulmig (zu tief) oder schrill (zu hoch).
CS_BAND = {
    # Nur Stimmen, deren Lage eine Satzentscheidung ist. Bass, Sub, Boom, Drone und
    # Riser bleiben unangetastet: dort ist die tiefe Lage gewollt.
    'pad': (36, 84), 'choir': (45, 79), 'organ': (36, 84),
    'lead': (55, 84), 'pluck': (55, 88), 'glass': (67, 100), 'wind': (60, 96),
}


REGISTER_INFO: dict[str, dict] = {}
PITCH_MAPS: dict[str, object] = {}


def register_fit(part: str, inst: str, pitches: list[int], engine: str = 'sfz') -> tuple:
    """Ganze Stimme oktavweise in die spielbare Lage rücken; Rest-Ausreißer falten.

    Außerhalb der Lage streckt sfizz die Randprobe: zu hoch klingt es gequetscht
    und schrill, zu tief stumpf und wackelig. Eine Oktavverschiebung der ganzen
    Stimme erhält die Melodie; erst wenn einzelne Töne danach immer noch nicht
    passen, werden sie einzeln oktaviert.
    """
    if engine == 'cs':
        if inst not in CS_BAND:
            REGISTER_INFO[part] = {'inst': inst, 'engine': engine, 'window': [0, 127], 'shift': 0,
                                   'folded': 0, 'notes': len(pitches), 'outside_after': 0}
            return lambda p: int(p)
        lo, hi = CS_BAND[inst]
    else:
        lo, hi = sfz.pitch_window(inst)
    shift, best = 0, None
    if engine == 'cs':
        # Synthese: keine Proben, also nur die ganze Stimme rücken (Median in die Lage).
        # Einzelne Töne zu falten würde die Melodie zerreissen.
        mid = sorted(pitches)[len(pitches) // 2] if pitches else 60
        for cand in (0, -12, 12, -24, 24, -36, 36, -48, 48):
            # erst „liegt in der Lage", dann möglichst kleiner Eingriff – nicht zur
            # Bandmitte ziehen, sonst wandert jede Stimme grundlos um Oktaven
            key = (0 if lo <= mid + cand <= hi else 1, abs(cand), abs(mid + cand - (lo + hi) / 2))
            if best is None or key < best:
                best, shift = key, cand

        def fold(p: int) -> int:
            return p
    else:
        for cand in (0, -12, 12, -24, 24, -36, 36, -48, 48):
            inside = sum(1 for p in pitches if lo <= p + cand <= hi)
            key = (-inside, abs(cand))
            if best is None or key < best:
                best, shift = key, cand

        def fold(p: int) -> int:
            while p < lo:
                p += 12
            while p > hi:
                p -= 12
            return p

    folded = sum(1 for p in pitches if fold(p + shift) != p + shift)
    REGISTER_INFO[part] = {'inst': inst, 'engine': engine, 'window': [lo, hi], 'shift': shift,
                           'folded': folded,
                           'notes': len(pitches),
                           'outside_after': sum(1 for p in pitches if not (lo <= fold(p + shift) <= hi))}
    if shift or folded:
        print(f'  Lage {part:10s} {inst:9s}: Oktavversatz {shift:+3d}, {folded} Einzeltöne gefaltet '
              f'(spielbar {lo}..{hi})')
    pm = (lambda p: fold(int(p) + shift))
    PITCH_MAPS[part] = pm
    return pm


def sample_range(sfz_path: Path) -> tuple[int, int] | None:
    centers = [int(x) for x in re.findall(r'pitch_keycenter=(\d+)', sfz_path.read_text(encoding='utf-8'))]
    return (min(centers), max(centers)) if centers else None


def fold_to_range(song: Song, part: str, rng: tuple[int, int], slack: int = 2) -> int:
    """Noten außerhalb des Sample-Umfangs oktavweise hereinholen: ein Instrument
    spielt nie tiefer/höher, als seine Aufnahmen reichen (kein Zerrklang)."""
    lo, hi = rng[0] - slack, rng[1] + slack
    moved = 0
    for note in song.parts.get(part, []):
        p = note.pitch
        while p < lo and p + 12 <= hi:
            p += 12
        while p > hi and p - 12 >= lo:
            p -= 12
        if p != note.pitch:
            note.pitch = p
            moved += 1
    return moved


def render_sfz(song: Song, part: str, inst: str, work: Path) -> Path:
    sfz_path = sfz.OUT / f'{inst}.sfz'
    if not sfz_path.exists():
        sfz.build(inst)
    if inst != 'kit':
        rng = sample_range(sfz_path)
        if rng:
            moved = fold_to_range(song, part, rng)
            if moved:
                print(f'  {part}: {moved} Noten in den Umfang von {inst} geholt')
    mid = work / f'{part}.mid'
    wav = work / f'{part}.wav'
    pitch_map = PITCH_MAPS.get(part) or register_fit(part, inst, [int(x.pitch) for x in song.parts.get(part, [])])
    song.write_midi(part, mid, pitch_map=pitch_map)
    run = subprocess.run(['sfizz_render', '--sfz', str(sfz_path), '--midi', str(mid), '--wav', str(wav),
                          '-s', str(SR), '-q', '3', '-p', '128'], capture_output=True, text=True, timeout=900)
    if run.returncode != 0 or not wav.exists():
        raise SystemExit(f'sfizz {part}: {run.stdout[-400:]} {run.stderr[-400:]}')
    return wav


def render_cs(song: Song, part: str, instr: str, work: Path) -> Path:
    pitch_map = PITCH_MAPS.get(part) or register_fit(part, instr, [int(x.pitch) for x in song.parts.get(part, [])], 'cs')
    lines = []
    for note in song.parts.get(part, []):
        x = note.extra
        hz = midi_to_hz(pitch_map(note.pitch))
        lines.append(f'i "{instr}" {note.t:.6f} {note.dur:.6f} {hz:.4f} {note.vel / 127:.4f} '
                     f'{x.get("bright", 0.5):.3f} {x.get("aux", 0):.3f} {x.get("pan", 0):.3f}')
    orc = (HERE / 'synth.orc').read_text(encoding='utf-8')
    wav = work / f'{part}.wav'
    csd = work / f'{part}.csd'
    csd.write_text('<CsoundSynthesizer>\n<CsOptions>\n-d -f -W -o ' + str(wav) +
                   ' -+rtaudio=null -+rtmidi=null --nodisplays -m0\n</CsOptions>\n<CsInstruments>\n' + orc +
                   '\n</CsInstruments>\n<CsScore>\n' + '\n'.join(lines) +
                   f'\ne {song.length + 6:.3f}\n</CsScore>\n</CsoundSynthesizer>\n', encoding='utf-8')
    run = subprocess.run(['csound', str(csd)], capture_output=True, text=True, timeout=900)
    if run.returncode != 0 or not wav.exists():
        raise SystemExit(f'csound {part}: {run.stderr[-1500:]}')
    return wav


def load_stem(path: Path, length: int) -> np.ndarray:
    data, sr = sf.read(path, dtype='float64', always_2d=True)
    if sr != SR:
        data = signal.resample_poly(data, SR, sr, axis=0)
    if data.shape[1] == 1:
        data = np.repeat(data, 2, axis=1)
    out = np.zeros((length, 2))
    k = min(length, len(data))
    out[:k] = data[:k, :2]
    return out


# ------------------------------------------------------------------ Mischen
def biquad(x: np.ndarray, kind: str, freq: float, q: float = 0.707, gain_db: float = 0.0) -> np.ndarray:
    """RBJ-Biquad (hp, lp, peak, lowshelf, highshelf) auf beide Kanäle."""
    w = 2 * math.pi * freq / SR
    a_ = 10 ** (gain_db / 40)
    alpha = math.sin(w) / (2 * q)
    cw = math.cos(w)
    if kind == 'lp':
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]; a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == 'hp':
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]; a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == 'peak':
        b = [1 + alpha * a_, -2 * cw, 1 - alpha * a_]; a = [1 + alpha / a_, -2 * cw, 1 - alpha / a_]
    elif kind in ('lowshelf', 'highshelf'):
        sq = 2 * math.sqrt(a_) * alpha
        if kind == 'lowshelf':
            b = [a_ * ((a_ + 1) - (a_ - 1) * cw + sq), 2 * a_ * ((a_ - 1) - (a_ + 1) * cw),
                 a_ * ((a_ + 1) - (a_ - 1) * cw - sq)]
            a = [(a_ + 1) + (a_ - 1) * cw + sq, -2 * ((a_ - 1) + (a_ + 1) * cw), (a_ + 1) + (a_ - 1) * cw - sq]
        else:
            b = [a_ * ((a_ + 1) + (a_ - 1) * cw + sq), -2 * a_ * ((a_ - 1) + (a_ + 1) * cw),
                 a_ * ((a_ + 1) + (a_ - 1) * cw - sq)]
            a = [(a_ + 1) - (a_ - 1) * cw + sq, 2 * ((a_ - 1) - (a_ + 1) * cw), (a_ + 1) - (a_ - 1) * cw - sq]
    else:
        raise ValueError(kind)
    b = np.array(b) / a[0]; a = np.array(a) / a[0]
    return signal.lfilter(b, a, x, axis=0)


def pan(x: np.ndarray, p: float, width: float = 1.0) -> np.ndarray:
    mid = (x[:, 0] + x[:, 1]) * 0.5
    side = (x[:, 0] - x[:, 1]) * 0.5 * width
    l, r = mid + side, mid - side
    ang = (p + 1) * math.pi / 4
    return np.stack([l * math.cos(ang) * math.sqrt(2), r * math.sin(ang) * math.sqrt(2)], axis=1)


def envelope(x: np.ndarray, attack: float, release: float) -> np.ndarray:
    """Pegelverlauf (mono, Betrag) mit Attack/Release-Glättung."""
    lvl = np.abs(x).max(axis=1)
    a = math.exp(-1 / (attack * SR)); r = math.exp(-1 / (release * SR))
    # Spitzen über ein kurzes Fenster halten, dann einpolig glätten (schnell genug in numpy).
    held = maximum_filter1d(lvl, size=max(1, int(attack * SR)))
    return signal.lfilter([1 - r], [1, -r], held)


def reverb_ir(seconds: float, damp: float = 0.55, pre: float = 0.018, seed: int = 3) -> np.ndarray:
    """Synthetische Raumantwort: dekorreliertes Rauschen, frequenzabhängiger Ausklang."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = np.zeros((n + int(pre * SR), 2))
    for ch in range(2):
        noise = rng.standard_normal(n)
        bands = []
        for lo, hi, decay in ((60, 400, 1.0), (400, 2500, 0.85), (2500, 9000, 0.6 * (1 - damp) + 0.25),
                              (9000, 18000, 0.3 * (1 - damp) + 0.1)):
            sos = signal.butter(2, [lo, hi], btype='band', fs=SR, output='sos')
            bands.append(signal.sosfilt(sos, noise) * np.exp(-6.9 * t / (seconds * decay)))
        early = np.zeros(n)
        for k in range(14):
            idx = int(rng.uniform(0.004, 0.08) * SR)
            early[idx] += rng.uniform(0.2, 0.6) * (1 if rng.random() > 0.5 else -1)
        ir[int(pre * SR):, ch] = sum(bands) + early * 2.0
    ir /= np.sqrt((ir ** 2).sum(axis=0, keepdims=True))
    return ir


def convolve(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    out = np.zeros_like(x)
    for ch in range(2):
        out[:, ch] = signal.oaconvolve(x[:, ch], ir[:, ch])[:len(x)]
    return out


def delay(x: np.ndarray, seconds: float, feedback: float = 0.35, spread: float = 1.0) -> np.ndarray:
    """Ping-Pong-Delay mit abgedunkelten Wiederholungen."""
    d = int(seconds * SR)
    out = np.zeros_like(x)
    mono = x.mean(axis=1)
    tap = mono.copy()
    for i in range(1, 7):
        tap = biquad(np.stack([tap, tap], axis=1), 'lp', 4200)[:, 0] * feedback
        if i * d >= len(x):
            break
        ch = i % 2
        out[i * d:, ch] += tap[:len(x) - i * d]
        out[i * d:, 1 - ch] += tap[:len(x) - i * d] * (1 - spread)
    return out


STEM_REF_DB = -20.0


def active_rms_db(x: np.ndarray) -> float:
    """Pegel der klingenden Stellen: RMS über 100-ms-Fenster, nur die lautere Hälfte
    der aktiven Fenster. Unabhängig davon, wie lange eine Stimme pausiert."""
    hop = SR // 10
    frames = x[:len(x) // hop * hop].reshape(-1, hop, 2)
    rms = np.sqrt((frames ** 2).mean(axis=(1, 2)) + 1e-20)
    db = 20 * np.log10(rms)
    active = db[db > db.max() - 35]
    if active.size == 0:
        return -120.0
    top = np.sort(active)[len(active) // 2:]
    return float(20 * np.log10(np.sqrt(np.mean((10 ** (top / 20)) ** 2))))


def mix(song: Song, spec: dict, stems: dict[str, np.ndarray], length: int, reverb_s: float) -> np.ndarray:
    dry = np.zeros((length, 2))
    rev_bus = np.zeros((length, 2))
    dly_bus = np.zeros((length, 2))
    duck_src = None
    for part, cfg in spec.items():
        if cfg.get('duck_source') and part in stems:
            duck_src = envelope(stems[part], 0.002, 0.12)
    if duck_src is not None and duck_src.max() > 0:
        duck_src /= duck_src.max()
    for part, cfg in spec.items():
        if part not in stems:
            continue
        x = stems[part]
        # Stems auf gemeinsamen Bezugspegel; "gain" ist danach die Mischbalance.
        x = x * 10 ** ((STEM_REF_DB - active_rms_db(x)) / 20)
        for kind, freq, *rest in cfg.get('eq', []):
            x = biquad(x, kind, freq, *(rest or []))
        if cfg.get('hp'):
            x = biquad(x, 'hp', cfg['hp'])
        if cfg.get('lp'):
            x = biquad(x, 'lp', cfg['lp'])
        x = pan(x, cfg.get('pan', 0.0), cfg.get('width', 1.0)) * 10 ** (cfg.get('gain', 0.0) / 20)
        if cfg.get('duck') and duck_src is not None:
            x = x * (1 - cfg['duck'] * duck_src)[:, None]
        dry += x
        rev_bus += x * cfg.get('rev', 0.0)
        dly_bus += x * cfg.get('dly', 0.0)
    wet = convolve(biquad(rev_bus, 'hp', 220), reverb_ir(reverb_s))
    spb = song.section('A').spb
    echo = delay(biquad(dly_bus, 'hp', 300), spb * 0.75)
    return dry + wet * 0.9 + echo


# ------------------------------------------------------------------ Mastern
def lufs(path: Path) -> tuple[float, float]:
    run = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', str(path), '-af', 'ebur128=peak=true',
                          '-f', 'null', '-'], capture_output=True, text=True)
    txt = run.stderr
    i = float(re.findall(r'I:\s+(-?[\d.]+) LUFS', txt)[-1])
    tp = float(re.findall(r'Peak:\s+(-?[\d.]+) dBFS', txt)[-1])
    return i, tp


def compress(x: np.ndarray, threshold_db: float, ratio: float, attack: float, release: float,
             makeup_db: float = 0.0) -> np.ndarray:
    env = envelope(x, attack, release) + 1e-9
    lvl = 20 * np.log10(env)
    over = np.maximum(0.0, lvl - threshold_db)
    gain_db = -over * (1 - 1 / ratio) + makeup_db
    return x * (10 ** (gain_db / 20))[:, None]


def limit(x: np.ndarray, ceiling_db: float, lookahead: float = 0.004, release: float = 0.08) -> np.ndarray:
    """Lookahead-Limiter mit 4x überabgetasteter Spitzenerkennung (True Peak)."""
    ceil = 10 ** (ceiling_db / 20)
    up = signal.resample_poly(x, 4, 1, axis=0)
    peak = np.abs(up).max(axis=1).reshape(-1, 4).max(axis=1)[:len(x)]
    need = np.minimum(1.0, ceil / np.maximum(peak, 1e-9))
    la = int(lookahead * SR)
    need = -maximum_filter1d(-need, size=2 * la + 1)  # Minimum über das Fenster
    r = math.exp(-1 / (release * SR))
    gain = np.empty_like(need)
    g = 1.0
    for i in range(0, len(need), 64):
        blk = need[i:i + 64].min()
        g = blk if blk < g else g * r + blk * (1 - r)
        gain[i:i + 64] = g
    gain = signal.lfilter([0.05], [1, -0.95], gain)  # Knackfreie Glättung
    gain = np.minimum(gain, need)
    return x * gain[:, None]


def master(x: np.ndarray, work: Path) -> np.ndarray:
    x = biquad(x, 'hp', 28, 0.6)
    x = compress(x, -14, 1.8, 0.012, 0.25)
    tmp = work / '_pre.wav'
    # Der Limiter nimmt beim Nachregeln wieder etwas Pegel weg: mehr Durchläufe und
    # ein leichtes Zielplus sorgen dafür, dass die Endmessung auf -16 LUFS landet.
    for _ in range(5):
        sf.write(tmp, x, SR, subtype='FLOAT')
        i, _tp = lufs(tmp)
        x = x * 10 ** ((TARGET_LUFS + 0.1 - i) / 20)
        x = limit(x, TARGET_TP - 0.15)
    return x


# ------------------------------------------------------------------ Messen
def spectrogram(x: np.ndarray, song: Song, path: Path, title: str) -> None:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    mono = x.mean(axis=1)
    f, t, s = signal.spectrogram(mono, SR, nperseg=4096, noverlap=2048)
    fig, ax = plt.subplots(figsize=(16, 5), dpi=100)
    ax.pcolormesh(t, f, 10 * np.log10(s + 1e-12), shading='auto', cmap='magma', vmin=-120, vmax=-40)
    ax.set_yscale('symlog', linthresh=200)
    ax.set_ylim(30, 20000)
    for sec in song.sections:
        ax.axvline(sec.start, color='cyan', lw=0.8)
        ax.text(sec.start + 0.5, 22000, sec.name, color='cyan', fontsize=9, va='top')
    tl = getattr(song, 'timeline', None)
    if tl:
        ax.axvline(tl['intro'] + tl['miniboss'], color='lime', lw=0.8, ls='--')
    ax.set_title(title)
    ax.set_xlabel('s')
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('song')
    ap.add_argument('--only', nargs='*', help='nur diese Stimmen neu rendern')
    args = ap.parse_args()
    mod = importlib.import_module(f'songs.{args.song}')
    song, spec, meta = mod.build()
    work = BUILD / args.song
    work.mkdir(parents=True, exist_ok=True)
    REGISTER_INFO.clear()
    PITCH_MAPS.clear()
    length = int(round(song.length * SR))
    print(song.describe())

    for part, cfg in spec.items():           # Lagen immer bestimmen (auch bei --only)
        notes = song.parts.get(part) or []
        if not notes:
            continue
        eng = 'sfz' if cfg['engine'] == 'sfz' else 'cs'
        inst = cfg['inst'] if eng == 'sfz' else cfg['instr']
        register_fit(part, inst, [int(x.pitch) for x in notes], eng)

    def job(item):
        part, cfg = item
        wav = work / f'{part}.wav'
        if args.only is not None and part not in args.only and wav.exists():
            return part, wav
        if cfg['engine'] == 'sfz':
            return part, render_sfz(song, part, cfg['inst'], work)
        return part, render_cs(song, part, cfg['instr'], work)

    todo = [(p, c) for p, c in spec.items() if song.parts.get(p)]
    with ThreadPoolExecutor(max_workers=8) as pool:
        rendered = dict(pool.map(job, todo))
    stems = {p: load_stem(w, length) for p, w in rendered.items()}
    for p, s in stems.items():
        print(f'  Stem {p:10s} Spitze {20 * np.log10(np.abs(s).max() + 1e-12):6.1f} dBFS')
    loop_start = meta.get('loop_start')
    if loop_start is not None:
        # Loop: Ausklang (Hall, Noten über das Loopende) an den Loopanfang falten,
        # damit der Sprung vom Ende zum Loopanfang nahtlos klingt.
        tail_n = int(4.0 * SR)
        stems = {p: np.vstack([s, load_stem(rendered[p], length + tail_n)[length:]]) for p, s in stems.items()}
        mixed = mix(song, spec, stems, length + tail_n, meta.get('reverb', 2.2))
        over = mixed[length:]
        ls = int(round(loop_start * SR))
        mixed = mixed[:length].copy()
        mixed[ls:ls + len(over)] += over[:max(0, length - ls)]
    else:
        mixed = mix(song, spec, stems, length, meta.get('reverb', 2.2))
    out = master(mixed, work)
    if loop_start is None:
        fade = int(0.012 * SR)
        out[-fade:] *= np.linspace(1, 0, fade)[:, None]
    wav = work / f'{meta["file"]}.wav'
    sf.write(wav, out, SR, subtype='PCM_24')
    i, tp = lufs(wav)
    ogg = OUT_DIR / f'{meta["file"]}.ogg'
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(wav), '-c:a', 'libvorbis',
                    '-q:a', '6', str(ogg)], check=True)
    ogg_len = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of',
                                    'default=nw=1:nk=1', str(ogg)], capture_output=True, text=True).stdout)
    spectrogram(out, song, work / f'{meta["file"]}_spektrogramm.png', f'{meta["title"]} – {song.length:.2f} s')
    if loop_start is not None:
        # Loopstart für das Spiel (Audio liest assets/audio/music/loops.json).
        loops_path = OUT_DIR / 'loops.json'
        loops = json.loads(loops_path.read_text()) if loops_path.exists() else {}
        loops[meta['file']] = round(loop_start, 6)
        loops_path.write_text(json.dumps(loops, indent=1, sort_keys=True) + '\n')
    report = {
        'file': str(ogg.relative_to(ROOT)), 'title': meta['title'],
        'target_length_s': round(song.length, 4), 'wav_length_s': round(len(out) / SR, 4),
        'ogg_length_s': round(ogg_len, 4),
        'length_ok': abs(len(out) / SR - song.length) < 0.01 and abs(ogg_len - song.length) < 0.03,
        'lufs_integrated': i, 'true_peak_dbfs': tp,
        'loudness_ok': abs(i - TARGET_LUFS) <= 0.5 and tp <= TARGET_TP + 0.1,
        'sections': [{'name': s.name, 'start_s': round(s.start, 4), 'bars': s.bars, 'bpm': round(s.bpm, 3)}
                     for s in song.sections],
        'miniboss_s': round(song.timeline['intro'] + song.timeline['miniboss'], 3) if getattr(song, 'timeline', None) else None,
        'loop_start_s': meta.get('loop_start'),
        'stems': sorted(stems),
        'register': REGISTER_INFO,
    }
    (work / 'bericht.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps({k: report[k] for k in ('target_length_s', 'wav_length_s', 'ogg_length_s', 'length_ok',
                                              'lufs_integrated', 'true_peak_dbfs', 'loudness_ok')}, indent=1))
    return 0 if report['length_ok'] and report['loudness_ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
