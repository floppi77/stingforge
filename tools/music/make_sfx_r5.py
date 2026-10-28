"""Neue Soundeffekte (R5): Bossphase, Glasscheibe in Level 6.

  phase_roar   Orchester-Schlag (Hörner, Pauke, Becken) mit tiefem Brüllen
  glass_warn   vier helle Glockentöne im Takt des Warnblinkens (1,6 s)
  glass_hit    kurzer Glasklick bei Treffern auf die Scheibe
  glass_break  Zersplittern: Riss, Scherbenregen, Nachklingeln

Aufruf: python3 tools/music/make_sfx_r5.py   (schreibt nach assets/audio/sfx/)
Akustische Anteile kommen aus den CC0-Bibliotheken über sfizz, der Rest ist synthetisch.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sfz  # noqa: E402
from score import ROOT, Section, Song, n  # noqa: E402

SR = 44100
OUT = ROOT / 'assets/audio/sfx'
WORK = HERE / 'build/sfx'
rng = np.random.default_rng(55)


def sfizz_notes(inst: str, notes: list[tuple[float, float, int, int]], length: float) -> np.ndarray:
    """Kurze Notenfolge (Start s, Dauer s, Ton, Anschlag) über sfizz rendern -> Mono."""
    WORK.mkdir(parents=True, exist_ok=True)
    song = Song([Section('A', 0.0, 8, 4.0, 0.5)], length)
    for t, d, p, v in notes:
        song.add_abs('x', t, d, p, v)
    mid = WORK / f'{inst}.mid'
    wav = WORK / f'{inst}.wav'
    song.write_midi('x', mid)
    path = sfz.OUT / f'{inst}.sfz'
    if not path.exists():
        sfz.build(inst)
    subprocess.run(['sfizz_render', '--sfz', str(path), '--midi', str(mid), '--wav', str(wav), '-s', str(SR)],
                   check=True, capture_output=True)
    x, _ = sf.read(wav, always_2d=True)
    x = x.mean(axis=1)[:int(length * SR)]
    return np.pad(x, (0, max(0, int(length * SR) - len(x))))


def norm(x: np.ndarray, peak_db: float = -1.0) -> np.ndarray:
    return x / (np.abs(x).max() + 1e-12) * 10 ** (peak_db / 20)


def env_exp(n_s: int, decay: float) -> np.ndarray:
    return np.exp(-np.arange(n_s) / (decay * SR))


def bandnoise(length: float, lo: float, hi: float) -> np.ndarray:
    sos = signal.butter(4, [lo, hi], btype='band', fs=SR, output='sos')
    return signal.sosfilt(sos, rng.standard_normal(int(length * SR)))


def ping(freq: float, decay: float, length: float) -> np.ndarray:
    t = np.arange(int(length * SR)) / SR
    partials = (1.0, 2.76, 5.4)
    out = sum(np.sin(2 * np.pi * freq * k * t) * (0.7 ** i) for i, k in enumerate(partials))
    return out * np.exp(-t / decay)


def place(buf: np.ndarray, x: np.ndarray, at: float, gain: float = 1.0) -> None:
    i = int(at * SR)
    k = min(len(x), len(buf) - i)
    if k > 0:
        buf[i:i + k] += x[:k] * gain


def phase_roar() -> np.ndarray:
    length = 2.2
    horns = sfizz_notes('horn', [(0.0, 1.4, n('C2'), 120), (0.0, 1.4, n('G2'), 118), (0.0, 1.4, n('C3'), 118),
                                 (0.0, 1.4, n('Db3'), 110)], length)
    kit = sfizz_notes('kit', [(0.0, 1.0, 41, 127), (0.0, 1.0, 49, 127), (0.02, 1.0, 36, 127)], length)
    t = np.arange(int(length * SR)) / SR
    # Brüllen: tiefer Sägezahn mit Formantfiltern, Tonhöhe fällt, Rauheit durch FM
    f0 = 70 * np.exp(-t * 0.5) * (1 + 0.04 * np.sin(2 * np.pi * 23 * t))
    saw = signal.sawtooth(2 * np.pi * np.cumsum(f0) / SR)
    growl = sum(signal.sosfilt(signal.butter(2, [f * 0.8, f * 1.25], btype='band', fs=SR, output='sos'), saw) * g
                for f, g in ((380, 1.0), (820, 0.6), (2300, 0.25)))
    growl *= np.minimum(1, t / 0.08) * np.exp(-t / 0.9)
    growl = np.tanh(growl * 3.0)
    out = norm(horns) * 0.7 + norm(kit) * 0.8 + norm(growl) * 0.45
    out = signal.sosfilt(signal.butter(2, 30, btype='high', fs=SR, output='sos'), out)
    return norm(out, -0.8)


def glass_warn() -> np.ndarray:
    length = 1.9
    notes = [(i * 0.4, 0.6, n(p), 100) for i, p in enumerate(('E6', 'B6', 'E6', 'B6'))]
    glock = sfizz_notes('glock', notes, length)
    shimmer = np.zeros(int(length * SR))
    for i in range(4):
        place(shimmer, ping(2637 * (1.5 if i % 2 else 1.0), 0.25, 0.6), i * 0.4, 0.35)
    return norm(norm(glock) + norm(shimmer) * 0.5, -3.0)


def glass_hit() -> np.ndarray:
    length = 0.16
    x = np.zeros(int(length * SR))
    place(x, bandnoise(0.01, 3000, 12000) * env_exp(int(0.01 * SR), 0.003), 0.0, 1.0)
    for _ in range(3):
        place(x, ping(rng.uniform(3200, 6500), rng.uniform(0.02, 0.05), 0.12), rng.uniform(0, 0.01), 0.4)
    return norm(x, -4.0)


def glass_break() -> np.ndarray:
    length = 1.6
    x = np.zeros(int(length * SR))
    # Riss und Schlag
    place(x, bandnoise(0.04, 1500, 14000) * env_exp(int(0.04 * SR), 0.012), 0.0, 2.2)
    t = np.arange(int(0.25 * SR)) / SR
    place(x, np.sin(2 * np.pi * 90 * t * np.exp(-t * 3)) * np.exp(-t / 0.06), 0.0, 0.8)
    # Scherbenregen: viele kurze Glasklänge, dichter am Anfang
    for _ in range(170):
        at = abs(rng.exponential(0.22))
        if at > length - 0.2:
            continue
        place(x, ping(rng.uniform(2200, 9500), rng.uniform(0.015, 0.09), 0.2), at, rng.uniform(0.15, 0.5))
    # Prasseln (Rauschkörner)
    grains = bandnoise(length, 4000, 16000) * (rng.random(int(length * SR)) > 0.9985)
    place(x, signal.lfilter([1], [1, -0.9], grains), 0.0, 0.6)
    # Nachklingeln mit echten Glockenspielproben, hoch und leise
    tinkle = sfizz_notes('glock', [(0.25 + i * 0.11 + rng.uniform(0, 0.04), 0.3, n(p), 70 - i * 6)
                                   for i, p in enumerate(('A7', 'E7', 'C8', 'G7', 'D7', 'B7'))], length)
    out = norm(x) + norm(tinkle) * 0.3
    out *= np.minimum(1.0, (length - np.arange(len(out)) / SR) / 0.2)
    return norm(out, -1.0)


def main() -> None:
    for name, fn in (('phase_roar', phase_roar), ('glass_warn', glass_warn), ('glass_hit', glass_hit),
                     ('glass_break', glass_break)):
        x = fn()
        sf.write(OUT / f'{name}.wav', x.astype(np.float32), SR, subtype='PCM_16')
        print(name, f'{len(x) / SR:.2f} s')


if __name__ == '__main__':
    main()
