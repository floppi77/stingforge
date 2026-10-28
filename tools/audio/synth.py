#!/usr/bin/env python3
"""Apidya Reimagined - deterministischer Tracker/Synthesizer (Python + numpy).

Erzeugt die komplett vorgerenderte Musik (OGG) und alle Soundeffekte (WAV).

Warum kein LMMS/FluidSynth?
    LMMS ist auf diesem System nicht installiert, FluidSynth 2.6.1 ist vorhanden,
    aber es gibt keinen SoundFont (.sf2/.sf3) im System - MIDI->FluidSynth ist
    damit nicht nutzbar. Details und Begruendung: docs/AUDIO.md.

Aufbau
    songs/*.py      Kompositionsdaten (Tempo, Tonart, Akkorde, Motive, Arrangement)
    songs/_lib.py   Notationshelfer: Skalen, Akkorde, Drum-/Bass-Patterns
    synth.py        diese Datei: Komponist + Synthese-Engine + Mix + Mastering
    verify.py       Messung (Peak/RMS/Loop-Naht/Spektrogramme)
    render.sh       Aufruf von synth.py + verify.py

Determinismus
    Alle Zufallsquellen sind numpy-Generatoren mit festen, aus der Song-ID
    abgeleiteten Seeds (zlib.crc32). Zwei Laeufe erzeugen bitgleiche WAVs.

Klangweg (pro Stimme)
    polyBLEP-Saegezahn/Puls (bandbegrenzt, kein Aliasing) -> Unison/Detune
    -> Ton-Blende (Filteroeffnung ueber Envelope) -> ADSR -> Pan
Bus
    Delay (punktierte Achtel, Ping-Pong) + synthetischer FFT-Hall
Master
    Hochpass, Pegel auf Ziel-RMS, Soft-Knee-Limiter (Peak <= -1 dBFS)
Loop
    Der Ueberhang (Hall, Delay, ausklingende Noten) wird additiv an den Anfang
    gefaltet -> samplegenau schleifbar, kein Klick, keine Stille am Anfang.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import os
import shutil
import subprocess
import sys
import wave
import zlib
from pathlib import Path

import numpy as np

# --------------------------------------------------------------------------
# Pfade / Konstanten
# --------------------------------------------------------------------------

TOOL_DIR = Path(__file__).resolve().parent
ROOT = TOOL_DIR.parents[1]                      # .../Apidya
SONG_DIR = TOOL_DIR / "songs"
MUSIC_OUT = ROOT / "assets" / "audio" / "music"
SFX_OUT = ROOT / "assets" / "audio" / "sfx"
BUILD_DIR = TOOL_DIR / "build"
BUILD_MUSIC = BUILD_DIR / "music"

sys.path.insert(0, str(Path(__file__).resolve().parent / "songs"))
import _lib as L  # noqa: E402  (Notationshelfer der Songdaten)

SR = 44100
TAIL_S = 2.6            # Ueberhang, der in den Loopanfang gefaltet wird
PEAK_CEIL = 0.7244      # -2.8 dBFS im Master (Reserve fuer Vorbis-Ueberschwinger)
TARGET_RMS_DB = -15.0
TWO_PI = 2.0 * np.pi


def dbamp(x):
    return 10.0 ** (x / 20.0)


def ampdb(x):
    return 20.0 * math.log10(max(float(x), 1e-9))


def midi_freq(m):
    return 440.0 * 2.0 ** ((float(m) - 69.0) / 12.0)


# --------------------------------------------------------------------------
# Bausteine: Oszillatoren (bandbegrenzt), Filter, Huellkurven
# --------------------------------------------------------------------------

def _blep(t, dt):
    """PolyBLEP-Korrektur fuer die Diskontinuitaet bei Phase 0."""
    out = np.zeros_like(t)
    m = t < dt
    if m.any():
        x = t[m] / np.maximum(dt[m], 1e-12)
        out[m] = 2.0 * x - x * x - 1.0
    m2 = t > (1.0 - dt)
    if m2.any():
        x = (t[m2] - 1.0) / np.maximum(dt[m2], 1e-12)
        out[m2] = x * x + 2.0 * x + 1.0
    return out


def _phasor(freq, n, detune_cents=0.0, vib=None):
    t = np.arange(n) / SR
    f = np.full(n, float(freq) * 2.0 ** (detune_cents / 1200.0))
    if vib:
        rate, depth, delay = vib
        if delay > 0:
            ramp = np.clip((t - delay) / 0.22, 0.0, 1.0)
        else:
            ramp = 1.0
        f = f * (1.0 + depth * np.sin(TWO_PI * rate * t) * ramp)
    dt = f / SR
    ph = np.cumsum(dt) % 1.0
    return ph, dt


def _saw(ph, dt):
    return 2.0 * ph - 1.0 - _blep(ph, dt)


def _pulse(ph, dt, width=0.5):
    width = float(np.clip(width, 0.05, 0.95))
    ph2 = (ph + width) % 1.0
    # Rechteck = Saege minus um die Impulsbreite verschobene Saege
    return _saw(ph, dt) - _saw(ph2, dt)


def _tri(ph):
    return 2.0 * np.abs(2.0 * (ph % 1.0) - 1.0) - 1.0


def fft_filter(x, fc, mode="lp", order=2):
    """Statischer Butterworth-Betragsfilter (nullphasig), 1D oder 2D (Achse 0)."""
    n = x.shape[0]
    if n < 8:
        return x
    if not isinstance(fc, (tuple, list)) and fc <= 0:
        return x
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f = np.maximum(f, 1e-6)
    if mode == "lp":
        h = 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))
    elif mode == "hp":
        h = 1.0 / np.sqrt(1.0 + (fc / f) ** (2 * order))
    else:  # band
        lo, hi = fc
        h = 1.0 / np.sqrt(1.0 + (lo / f) ** (2 * order))
        h *= 1.0 / np.sqrt(1.0 + (f / hi) ** (2 * order))
    if x.ndim == 1:
        return np.fft.irfft(np.fft.rfft(x) * h, n)
    return np.fft.irfft(np.fft.rfft(x, axis=0) * h[:, None], n, axis=0)


def env_adsr(n, dur, a, d, s, r):
    """Stueckweise lineare ADSR-Huellkurve, exakt 0 am Anfang und Ende."""
    t = np.arange(n) / SR
    dur = max(dur, 0.03)
    a = min(max(a, 0.0008), dur * 0.5)
    d = min(max(d, 0.001), max(dur * 0.9, 0.002))
    if a + d > dur:
        d = max(dur - a, 0.001)
    r = max(r, 0.01)
    return np.interp(t, [0.0, a, a + d, dur, dur + r], [0.0, 1.0, s, s, 0.0])


def env_perc(n, tau, attack=0.0015):
    t = np.arange(n) / SR
    return np.exp(-t / max(tau, 0.005)) * (1.0 - np.exp(-t / max(attack, 1e-4)))


# --------------------------------------------------------------------------
# Klangfarben (Presets)
# --------------------------------------------------------------------------
# kind: saw | pulse | saw_pulse | tri | sine | fm
# unison/detune: Verstimmung, pw: Impulsbreite, tone: Tiefpass-Eckfrequenz,
# dark: Anteil gefilterter Signale in der Sustainphase, sweep: Oeffnung im Attack
# vib: (rate, relative Tiefe, Verzoegerung), tau: perkussiver Zerfall

PRESETS = {
    # ---- Lead ----
    "lead_pulse": dict(kind="pulse", pw=0.34, unison=2, detune=9.0, tone=6300,
                       dark=0.55, sweep=0.45, a=0.006, d=0.15, s=0.62, r=0.11,
                       level=0.85, vib=(5.6, 0.0045, 0.16), sub=0.10),
    "lead_saw": dict(kind="saw_pulse", pw=0.30, unison=3, detune=11.0, tone=5400,
                     dark=0.50, sweep=0.5, a=0.007, d=0.18, s=0.70, r=0.13,
                     level=0.80, vib=(5.2, 0.005, 0.18), sub=0.08, width=0.55),
    "lead_soft": dict(kind="saw", unison=2, detune=6.0, tone=3000, dark=0.78,
                      sweep=0.35, a=0.028, d=0.22, s=0.72, r=0.22, level=0.82,
                      vib=(4.8, 0.004, 0.2)),
    "lead_flute": dict(kind="tri", unison=2, detune=4.0, tone=3600, dark=0.70,
                       sweep=0.30, a=0.045, d=0.2, s=0.80, r=0.20, level=0.86,
                       vib=(5.0, 0.006, 0.18), sub=0.18),
    "lead_organ": dict(kind="pulse", pw=0.5, unison=1, tone=4400, dark=0.58,
                       sweep=0.25, a=0.010, d=0.10, s=0.86, r=0.09, level=0.80,
                       sub=0.22, vib=(0.0, 0.0, 0.0)),
    "lead_bell": dict(kind="fm", ratio=2.0, index=1.5, mod_tau=0.35, tone=7000,
                      dark=0.35, sweep=0.2, a=0.004, d=0.35, s=0.55, r=0.32,
                      level=0.72, vib=(4.5, 0.003, 0.3)),
    "lead_brass": dict(kind="saw", unison=2, detune=5.0, tone=5500, dark=0.5,
                       sweep=0.55, a=0.045, d=0.10, s=0.82, r=0.16, level=0.84,
                       vib=(5.4, 0.005, 0.25)),
    # ---- Arpeggien ----
    "arp_pluck": dict(kind="pulse", pw=0.25, unison=1, tone=6400, dark=0.48,
                      sweep=0.6, tau=0.115, level=0.60, filt_p=0.5),
    "arp_pulse": dict(kind="pulse", pw=0.5, unison=1, tone=6000, dark=0.5,
                      sweep=0.5, tau=0.085, level=0.55),
    "arp_bell": dict(kind="fm", ratio=3.01, index=1.1, mod_tau=0.12, tone=8000,
                     dark=0.28, sweep=0.1, tau=0.26, level=0.42),
    "arp_glass": dict(kind="sine", unison=2, detune=3.0, tone=9000, dark=0.18,
                      sweep=0.0, tau=0.30, level=0.40),
    "arp_soft": dict(kind="tri", unison=1, tone=3400, dark=0.8, sweep=0.25,
                     tau=0.20, level=0.42),
    # ---- Flaechen ----
    "pad_soft": dict(kind="saw", unison=4, detune=13.0, tone=1900, dark=0.92,
                     sweep=0.10, a=0.65, d=0.4, s=0.85, r=0.85, level=0.36,
                     width=0.9, vib=(3.1, 0.0025, 0.0)),
    "pad_warm": dict(kind="saw", unison=3, detune=9.0, tone=1450, dark=0.94,
                     sweep=0.08, a=0.5, d=0.4, s=0.88, r=0.8, level=0.36,
                     width=0.8),
    "pad_air": dict(kind="tri", unison=3, detune=7.0, tone=2700, dark=0.80,
                    sweep=0.12, a=0.85, d=0.5, s=0.9, r=1.0, level=0.30,
                    width=0.9, sub=0.12),
    "pad_drone": dict(kind="saw", unison=3, detune=18.0, tone=900, dark=0.96,
                      sweep=0.05, a=1.1, d=0.5, s=0.9, r=1.1, level=0.32,
                      width=0.7, sub=0.2),
    "pad_string": dict(kind="saw_pulse", pw=0.45, unison=4, detune=12.0, tone=2100,
                       dark=0.80, sweep=0.16, a=0.38, d=0.3, s=0.88, r=0.7,
                       level=0.34, width=0.85, vib=(4.2, 0.003, 0.3)),
    "pad_glass": dict(kind="fm", ratio=1.005, index=0.55, mod_tau=2.0, tone=5200,
                      dark=0.35, sweep=0.0, a=0.9, d=0.5, s=0.9, r=1.0,
                      level=0.24, width=0.8, unison=2, detune=4.0),
    # ---- Bass ----
    "bass_saw": dict(kind="saw_pulse", pw=0.42, unison=1, tone=1250, dark=0.72,
                     sweep=0.55, a=0.004, d=0.11, s=0.52, r=0.07, level=0.95,
                     sub=0.55, mono=True),
    "bass_sub": dict(kind="sine", unison=1, tone=800, dark=0.3, sweep=0.0,
                     a=0.006, d=0.12, s=0.75, r=0.09, level=0.95,
                     sub=0.35, mono=True),
    "bass_round": dict(kind="tri", unison=1, tone=900, dark=0.6, sweep=0.2,
                       a=0.005, d=0.10, s=0.62, r=0.08, level=0.92,
                       sub=0.45, mono=True),
    "bass_drive": dict(kind="saw", unison=1, tone=1700, dark=0.62, sweep=0.6,
                       a=0.003, d=0.10, s=0.58, r=0.07, level=0.98,
                       sub=0.6, mono=True, drive=1.9),
    # ---- Einzelklaenge ----
    "bell_shimmer": dict(kind="fm", ratio=4.02, index=0.8, mod_tau=0.2, tone=9000,
                         dark=0.2, sweep=0.0, tau=0.45, level=0.26),
    "bell_soft": dict(kind="sine", unison=2, detune=2.0, tone=6000, dark=0.25,
                      sweep=0.0, tau=0.6, level=0.26),
}


def render_voice(preset, midi, dur, vel, pan=0.0):
    """Eine Note -> Stereoarray (n,2), float32."""
    p = PRESETS[preset] if isinstance(preset, str) else preset
    freq = midi_freq(midi)
    rel = p.get("r", p.get("tau", 0.2) * 4.0)
    dur = max(float(dur), 0.035)
    n = int((dur + rel + 0.03) * SR)
    kind = p.get("kind", "saw")
    unison = int(p.get("unison", 1))
    detune = float(p.get("detune", 0.0))
    width = float(p.get("width", 0.0))
    vib = p.get("vib")
    if vib and vib[0] <= 0.0:
        vib = None
    pw = float(p.get("pw", 0.5))

    sig = np.zeros((n, 2), dtype=np.float64)
    for k in range(unison):
        det = 0.0 if unison == 1 else (k - (unison - 1) / 2.0) * detune
        if kind == "fm":
            ph, dt = _phasor(freq, n, det, vib)
            t = np.arange(n) / SR
            idx = float(p.get("index", 1.0)) * np.exp(-t / max(p.get("mod_tau", 0.3), 0.01))
            w = np.sin(TWO_PI * ph + idx * np.sin(TWO_PI * ph * float(p.get("ratio", 2.0))))
        else:
            ph, dt = _phasor(freq, n, det, vib)
            if kind in ("saw", "saw_pulse"):
                w = _saw(ph, dt)
                if kind == "saw_pulse":
                    w = 0.68 * w + 0.46 * _pulse(ph, dt, pw)
                if p.get("sub") and kind == "saw":
                    w = w + float(p["sub"]) * 0.6 * np.sin(TWO_PI * ph)
            elif kind == "pulse":
                w = _pulse(ph, dt, pw)
                if p.get("sub"):
                    w = w + float(p["sub"]) * np.sin(TWO_PI * ph)
            elif kind == "tri":
                w = _tri(ph)
                if p.get("sub"):
                    w = w + float(p["sub"]) * np.sin(TWO_PI * ph)
            else:  # sine
                w = np.sin(TWO_PI * ph)
                if p.get("sub"):
                    w = w + float(p["sub"]) * np.sin(TWO_PI * ph * 2.0)
        if unison > 1:
            spread = width if width > 0 else 0.35
            pos = 0.0 if unison == 1 else ((k / max(unison - 1, 1)) - 0.5) * spread
        else:
            pos = 0.0
        ang = (np.clip(pos + pan, -1.0, 1.0) + 1.0) * np.pi / 4.0
        sig[:, 0] += w * np.cos(ang)
        sig[:, 1] += w * np.sin(ang)
    sig /= math.sqrt(max(unison, 1))

    # Tiefpass-Blende: Sustain dunkler, Attack heller (Filteroeffnung)
    fc = float(p.get("tone", 4000.0))
    filt = fft_filter(sig, fc, "lp", 2)
    dark = float(p.get("dark", 0.6))
    sweep = float(p.get("sweep", 0.3))
    if sweep > 0 and "tau" not in p:
        t = np.arange(n) / SR
        bright = np.exp(-t / 0.16)
        wmix = np.clip(dark * (1.0 - sweep * bright), 0.0, 0.99)[:, None]
    else:
        wmix = dark
    out = sig * (1.0 - wmix) + filt * wmix

    # Huellkurve
    if "tau" in p:
        env = env_perc(n, float(p["tau"]))
    else:
        env = env_adsr(n, dur, float(p.get("a", 0.01)), float(p.get("d", 0.1)),
                       float(p.get("s", 0.7)), float(p.get("r", 0.15)))
    out *= env[:, None]

    if p.get("drive"):
        g = float(p["drive"])
        out = np.tanh(out * g) / math.tanh(g)

    dev = float(p.get("level", 0.6)) * float(vel)
    return (out * dev).astype(np.float32)


# --------------------------------------------------------------------------
# Drum-Synthese
# --------------------------------------------------------------------------

def drum_kick(vel, rng, tune=1.0, dur=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 54.0 * tune + 165.0 * tune * np.exp(-t / 0.022)
    ph = np.cumsum(TWO_PI * f / SR)
    body = np.sin(ph) * np.exp(-t / 0.145)
    click = rng.standard_normal(n) * np.exp(-t / 0.0032) * 0.38
    click = fft_filter(click, 5200.0, "lp", 2)
    y = body + click
    y = np.tanh(y * 1.35) * 0.72
    return (y * vel / max(np.abs(y).max(), 1e-9) * 0.70).astype(np.float64)


def drum_snare(vel, rng, tune=1.0, dur=0.30):
    n = int(dur * SR)
    t = np.arange(n) / SR
    body = (np.sin(TWO_PI * 186.0 * tune * t) * 0.6
            + np.sin(TWO_PI * 278.0 * tune * t) * 0.35) * np.exp(-t / 0.055)
    noise = rng.standard_normal(n)
    noise = fft_filter(noise, (900.0, 7200.0), "band", 2) * np.exp(-t / 0.075)
    y = 0.55 * body + 0.8 * noise
    y = np.tanh(y * 1.3) * 0.6
    return (y * vel / max(np.abs(y).max(), 1e-9) * 0.62).astype(np.float64)


def drum_clap(vel, rng, dur=0.22):
    n = int(dur * SR)
    y = np.zeros(n)
    for k, off in enumerate((0.0, 0.010, 0.021, 0.033)):
        i = int(off * SR)
        m = n - i
        t = np.arange(m) / SR
        burst = rng.standard_normal(m) * np.exp(-t / (0.012 + 0.004 * k))
        y[i:i + m] += burst
    y = fft_filter(y, (1000.0, 4200.0), "band", 2)
    y = np.tanh(y * 1.1)
    return (y * vel / max(np.abs(y).max(), 1e-9) * 0.40).astype(np.float64)


def drum_hat(vel, rng, open_=False, dur=None):
    d = dur if dur is not None else (0.30 if open_ else 0.055)
    n = int(d * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # metallisch: hochfrequent gefiltertes Rauschen + inharmonische Anteile
    y = fft_filter(noise, 7600.0, "hp", 3)
    met = np.zeros(n)
    for f in (6300.0, 8700.0, 10400.0):
        met += np.sin(TWO_PI * f * t + rng.random() * TWO_PI)
    y = y + 0.22 * fft_filter(met / 3.0, 9000.0, "hp", 2)
    tau = 0.075 if open_ else 0.016
    y *= np.exp(-t / tau)
    return (y * vel / max(np.abs(y).max(), 1e-9) * 0.40).astype(np.float64)


def drum_crash(vel, rng, dur=1.6):
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    y = fft_filter(noise, 4200.0, "hp", 2)
    met = np.zeros(n)
    for f in (3150.0, 4620.0, 5900.0, 7310.0, 8820.0):
        met += np.sin(TWO_PI * f * t + rng.random() * TWO_PI)
    y = y + 0.3 * fft_filter(met / 5.0, 3000.0, "hp", 2)
    y *= np.exp(-t / 0.52) * (1.0 - np.exp(-t / 0.004))
    return (y * vel / max(np.abs(y).max(), 1e-9) * 0.34).astype(np.float64)


def drum_tom(vel, rng, midi=52, dur=0.4):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = midi_freq(midi)
    f = f0 * (1.0 + 0.7 * np.exp(-t / 0.05))
    ph = np.cumsum(TWO_PI * f / SR)
    y = np.sin(ph) * np.exp(-t / 0.13)
    y += 0.12 * rng.standard_normal(n) * np.exp(-t / 0.02)
    return (y * vel / max(np.abs(y).max(), 1e-9) * 0.42).astype(np.float64)


# --------------------------------------------------------------------------
# FX: Hall, Delay, Riser
# --------------------------------------------------------------------------

def make_ir(seed, dur=1.65, lp=6800.0):
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal((n, 2))
    ir *= np.exp(-t / 0.34)[:, None]
    ir = fft_filter(ir, lp, "lp", 2)
    ir = fft_filter(ir, 180.0, "hp", 2)
    # ein paar diskrete Fruehreflexionen fuer Groesse
    for delay_ms, g in ((11.0, 0.5), (19.0, 0.36), (31.0, 0.28), (47.0, 0.2)):
        i = int(delay_ms * SR / 1000.0)
        if i < n:
            ir[i:, 0] += g * rng.standard_normal(n - i) * np.exp(-t[: n - i] / 0.5)
            ir[i:, 1] += g * rng.standard_normal(n - i) * np.exp(-t[: n - i] / 0.5)
    ir *= 0.55 / math.sqrt((ir ** 2).sum(axis=0).mean())
    return ir.astype(np.float32)


def convolve_stereo(x, ir):
    n = x.shape[0]
    m = ir.shape[0]
    size = 1 << int(math.ceil(math.log2(n + m)))
    out = np.zeros((n, 2), dtype=np.float32)
    for ch in range(2):
        X = np.fft.rfft(x[:, ch], size)
        H = np.fft.rfft(ir[:, ch], size)
        out[:, ch] = np.fft.irfft(X * H, size)[:n].astype(np.float32)
    return out


def delay_stereo(x, time_s, feedback=0.34, taps=4, mix=0.28):
    n = x.shape[0]
    d = int(time_s * SR)
    wet = np.zeros_like(x)
    src = x
    for k in range(1, taps + 1):
        sh = k * d
        if sh >= n:
            break
        g = feedback ** k
        wet[sh:, 0] += g * src[:-sh, 1] * 0.9
        wet[sh:, 1] += g * src[:-sh, 0] * 0.9
    return (x + mix * wet * 2.0).astype(np.float32)


def riser(dur_s, seed, f_lo=400.0, f_hi=9000.0):
    """Rausch-Sweep (Reverse-Cymbal-Ersatz), steigende Helligkeit."""
    rng = np.random.default_rng(seed)
    n = int(dur_s * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    lo = fft_filter(noise, f_lo, "lp", 2)
    hi = fft_filter(noise, (f_hi * 0.35, f_hi), "band", 2)
    x = np.clip((t / dur_s) ** 1.6, 0.0, 1.0)
    y = lo * (1.0 - x) + hi * x * 1.4
    env = (t / dur_s) ** 1.8 * (1.0 - np.clip((t - dur_s * 0.97) / (dur_s * 0.03), 0, 1))
    y *= env
    y /= max(np.abs(y).max(), 1e-9)
    return y.astype(np.float64) * 0.30


# --------------------------------------------------------------------------
# Komposition
# --------------------------------------------------------------------------

def load_song(path):
    spec = importlib.util.spec_from_file_location("song_" + path.stem, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.SONG


def song_seed(song_id):
    return zlib.crc32(song_id.encode("utf-8")) & 0x7FFFFFFF


def compose(song, rng):
    """Songdaten -> Stem-Buffer (Stereo, Laenge loop+tail)."""
    bpm = float(song["bpm"])
    beat = 60.0 / bpm
    step = beat / 4.0
    bar = beat * 4.0
    bars = int(song["bars"])
    loop_n = int(round(bars * bar * SR))
    tail_n = int(round(TAIL_S * SR))
    total = loop_n + tail_n

    stems = {k: np.zeros((total, 2), dtype=np.float32)
             for k in ("lead", "pad", "arp", "bass", "drums", "atmos")}

    def place(stem, t_sec, sig_mono_or_stereo, pan=0.0, gain=1.0):
        start = int(round(t_sec * SR))
        if isinstance(sig_mono_or_stereo, tuple):
            y = sig_mono_or_stereo
        elif sig_mono_or_stereo.ndim == 1:
            ang = (np.clip(pan, -1, 1) + 1.0) * np.pi / 4.0
            y = (sig_mono_or_stereo * np.cos(ang), sig_mono_or_stereo * np.sin(ang))
            y = np.stack(y, axis=1)
        else:
            y = sig_mono_or_stereo
        n = y.shape[0]
        if start >= total:
            return
        if start + n > total:
            y = y[: total - start]
            n = y.shape[0]
        stems[stem][start:start + n] += (y * gain).astype(np.float32)

    key = song["key"]
    scale = song["scale"]
    kpc = L.key_pc(key)
    lead_oct = int(song.get("lead_oct", 5))
    arp_oct = int(song.get("arp_oct", 4))
    bass_oct = int(song.get("bass_oct", 2))
    presets = song["presets"]
    chords = song["chords"]
    chord_bars = int(song.get("chord_bars", 2))
    motifs = song.get("motifs", {})
    arp_pat = song.get("arp", [0, 2, 1, 3])
    arp_len = max(len(arp_pat), 1)
    arp_iv = max(16 // arp_len, 1)

    def chord_at(bar_idx):
        ci = (bar_idx // chord_bars) % len(chords)
        spec = chords[ci]
        root, offs = chord_spec(spec)
        return root, offs

    def deg_note(degree, oct_off=0):
        return 12 * lead_oct + kpc + L.deg_semitone(scale, degree) + 12 * oct_off

    bar_i = 0
    sections = song["sections"]
    for sec_idx, sec in enumerate(sections):
        is_final_section = (sec_idx == len(sections) - 1)
        sec_bars = int(sec.get("bars", 8))
        for b in range(sec_bars):
            gi = bar_i + b
            t_bar = gi * bar
            root, offs = chord_at(gi)

            # ---- Pad: Akkord pro chord_bars Takte
            if sec.get("pad") and gi % chord_bars == 0:
                pdur = bar * chord_bars * 0.99
                for j, o in enumerate(offs):
                    m = 12 * (arp_oct + 1) + root + o
                    pv = render_voice(presets["pad"], m, pdur,
                                      0.8 + 0.1 * (j == len(offs) - 1),
                                      pan=(j / max(len(offs) - 1, 1) - 0.5) * 0.35)
                    place("pad", t_bar, pv)

            # ---- Bass
            bpat_name = sec.get("bass")
            if bpat_name:
                pat = L.BASS_PATTERNS[bpat_name] if isinstance(bpat_name, str) else bpat_name
                for (st, semi, ln) in pat:
                    m = 12 * bass_oct + root + semi
                    d = ln * step * 0.92
                    bv = render_voice(presets["bass"], m, d, 0.85 + 0.15 * (st % 4 == 0))
                    place("bass", t_bar + st * step, bv)

            # ---- Arpeggio
            if sec.get("arp"):
                stack = []
                for o in offs:
                    stack.append(12 * arp_oct + root + o)
                for o in offs:
                    stack.append(12 * (arp_oct + 1) + root + o)
                for i in range(16 // arp_iv):
                    st = i * arp_iv
                    idx = arp_pat[(gi * (16 // arp_iv) + i) % arp_len]
                    m = stack[idx % len(stack)]
                    acc = 0.62 if st % 4 == 0 else 0.46
                    av = render_voice(presets["arp"], m, arp_iv * step * 0.85, acc)
                    place("arp", t_bar + st * step, av)

            # ---- Drums
            dpat_name = sec.get("drums")
            fill = L.FILL_PATTERNS[sec["fill"]] if sec.get("fill") else None
            is_last = (b == sec_bars - 1)
            if dpat_name:
                dpat = L.DRUM_PATTERNS[dpat_name]
                use_fill = fill if (is_last and sec.get("fill_at_end", True)) else None
                layers = dict(dpat)
                if use_fill:
                    for k, v in use_fill.items():
                        layers[k] = list(layers.get(k, [])) + list(v)
                for inst, hits in layers.items():
                    for (st, vel) in hits:
                        if vel <= 0:
                            continue
                        t_hit = t_bar + st * step
                        pan = {"hat": 0.35, "ohat": 0.4, "crash": -0.2,
                               "tom": -0.25, "clap": 0.15}.get(inst, 0.0)
                        if inst == "kick":
                            y = drum_kick(vel, rng, tune=song.get("kick_tune", 1.0))
                        elif inst == "snare":
                            y = drum_snare(vel, rng, tune=song.get("snare_tune", 1.0))
                        elif inst == "hat":
                            y = drum_hat(vel, rng, False)
                        elif inst == "ohat":
                            y = drum_hat(vel, rng, True)
                        elif inst == "crash":
                            y = drum_crash(vel, rng)
                        elif inst == "tom":
                            y = drum_tom(vel, rng, midi=50 + int(st % 3) * 3)
                        elif inst == "clap":
                            y = drum_clap(vel, rng)
                        else:
                            continue
                        place("drums", t_hit, y, pan=pan)

            # ---- Uebergaenge: Crash am Abschnittsanfang, Riser am Abschnittsende
            if b == 0 and sec.get("crash") and gi > 0:
                place("drums", t_bar, drum_crash(0.55, rng), pan=-0.15)
            if b == sec_bars - 1 and sec.get("riser"):
                place("drums", t_bar + 8 * step, riser(bar * 0.5, song_seed(song["id"]) + gi),
                      pan=0.0, gain=0.55)

            # ---- Turnaround in den Loopanfang: Bass-Pickup + Snare auf die letzte 16tel
            if (b == sec_bars - 1 and is_final_section
                    and sec.get("turnaround", True)):
                if sec.get("bass"):
                    r_end, _o = chord_at(gi)
                    bv = render_voice(presets["bass"], 12 * bass_oct + r_end + 7,
                                      3 * step * 0.85, 0.72)
                    place("bass", t_bar + 13 * step, bv)
                place("drums", t_bar + 14 * step, drum_kick(0.88, rng), pan=0.0)
                place("drums", t_bar + 15 * step, drum_snare(0.62, rng, tune=1.05), pan=0.05)
                # Becken auf die letzte Zaehlzeit: klingt ueber die Loopnaht und
                # wird durch die Faltung am Anfang nahtlos fortgesetzt.
                cr = float(sec.get("turnaround_crash", song.get("turnaround_crash", 0.42)))
                if cr > 0:
                    place("drums", t_bar + 12 * step, drum_crash(cr, rng), pan=-0.25)
        # ---- Melodie: Motiv(e) pro Abschnitt, kann mehrere Takte spannen
        mel = sec.get("melody")
        if mel:
            motif = motifs.get(mel)
            if motif:
                reps = int(sec.get("mel_reps", 1))
                gap = int(sec.get("mel_gap", 4))
                start = int(sec.get("mel_start", 0))
                trans = int(sec.get("mel_transpose", 0))
                oct_off = int(sec.get("mel_oct", 0))
                for rep in range(reps):
                    t0 = (bar_i + start + rep * gap) * bar
                    for (st, degree, ln) in motif:
                        if st >= sec_bars * 16:
                            continue
                        m = deg_note(degree, oct_off) + trans
                        d = ln * step * 0.95
                        vel = 0.92 if st % 4 == 0 else 0.76
                        lv = render_voice(presets["lead"], m, d, vel, pan=0.0)
                        place("lead", t0 + st * step, lv)
                        if sec.get("harm"):
                            hv = render_voice(presets["lead"], m + int(sec["harm"]),
                                              d, vel * 0.50, pan=0.35)
                            place("lead", t0 + st * step, hv)
                        if sec.get("double"):
                            m2 = deg_note(degree + 7, oct_off) + trans
                            dv = render_voice(presets["lead"], m2, d, vel * 0.32,
                                              pan=-0.30)
                            place("lead", t0 + st * step, dv)
        bar_i += sec_bars

    # ---- Atmosphaere (periodisch gemacht, damit die Loopnaht sauber bleibt)
    atmos = song.get("atmos")
    if atmos:
        rng2 = np.random.default_rng(song_seed(song["id"]) + 99)
        n = loop_n
        t = np.arange(n) / SR
        noise = rng2.standard_normal((n, 2))
        if atmos == "air":
            y = fft_filter(noise, (1200.0, 5200.0), "band", 2) * 0.028
        elif atmos == "water":
            y = fft_filter(noise, 620.0, "lp", 2) * 0.05
            y *= (0.6 + 0.4 * np.sin(TWO_PI * 0.13 * t))[:, None]
        elif atmos == "wind":
            y = fft_filter(noise, (280.0, 1400.0), "band", 2) * 0.055
            y *= (0.45 + 0.55 * np.sin(TWO_PI * 0.07 * t + 1.1))[:, None]
        elif atmos == "buzz":
            hum = np.sin(TWO_PI * 92.0 * t)[:, None]
            y = fft_filter(noise, (150.0, 900.0), "band", 2) * 0.03 + hum * 0.012
        elif atmos == "machine":
            y = fft_filter(noise, (90.0, 480.0), "band", 2) * 0.05
            y += (np.sin(TWO_PI * 55.0 * t) * (0.5 + 0.5 * np.sign(np.sin(TWO_PI * 1.4 * t))))[:, None] * 0.012
        else:
            y = noise * 0.02
        # Enden ueberblenden -> exakt periodisch
        xf = int(0.12 * SR)
        ramp = np.linspace(0.0, 1.0, xf)[:, None]
        y[:xf] = y[:xf] * ramp + y[-xf:] * (1.0 - ramp)
        stems["atmos"][:n] += y.astype(np.float32)

    return stems, loop_n, total


def chord_spec(spec):
    return L.chord(spec)


# --------------------------------------------------------------------------
# Mixdown / Mastering
# --------------------------------------------------------------------------

def soft_limit(x, knee=0.62, ceiling=PEAK_CEIL):
    a = np.abs(x)
    over = a > knee
    if not over.any():
        return x
    y = x.copy()
    span = ceiling - knee
    y[over] = np.sign(x[over]) * (knee + span * np.tanh((a[over] - knee) / span))
    return y


# Zielbalance relativ zur Melodiestimme (dB). Wird aus den tatsaechlich
# gerenderten Stems gemessen und automatisch eingestellt, damit kein Titel
# von der Basslinie zugedeckt wird. Songs koennen per "balance" abweichen.
BALANCE_DB = {"lead": 0.0, "arp": -6.0, "pad": -9.0, "bass": -4.0,
              "drums": -3.0, "atmos": -26.0}


def auto_balance(song, stems, loop_n):
    bal = dict(BALANCE_DB)
    bal.update(song.get("balance", {}))
    rms = {}
    for k in ("lead", "arp", "pad", "bass", "drums", "atmos"):
        y = stems[k][:loop_n].astype(np.float64)
        rms[k] = float(np.sqrt(np.mean(y ** 2))) if y.size else 0.0
    ref = max(rms["lead"], 1e-6)
    gains = {}
    for k, target in bal.items():
        have = rms[k]
        if have <= 1e-7:
            gains[k] = 0.0
            continue
        g_db = target - (ampdb(have) - ampdb(ref))
        gains[k] = float(dbamp(max(min(g_db, 14.0), -28.0)))
    trim = song.get("mix", {})
    for k, v in trim.items():
        gains[k] = gains.get(k, 0.0) * float(v)
    return gains, rms


def mix_and_master(song, stems, loop_n):
    gains, stem_rms = auto_balance(song, stems, loop_n)
    song["_gains"] = {k: round(v, 4) for k, v in gains.items()}
    song["_stem_rms_db"] = {k: round(ampdb(v), 1) for k, v in stem_rms.items()}
    total = stems["atmos"].shape[0]

    dry = np.zeros((total, 2), dtype=np.float32)
    for k, g in gains.items():
        dry += stems[k] * float(g)

    # Delay-Send (punktierte Achtel), Ping-Pong
    beat = 60.0 / float(song["bpm"])
    d_send = (stems["arp"] * 0.40 + stems["lead"] * 0.28) * 0.5
    wet_delay = delay_stereo(d_send.astype(np.float32), beat * 0.75, 0.33, 4, 0.55)

    # Hall-Send
    r_send = (stems["lead"] * 0.42 + stems["pad"] * 0.55 + stems["arp"] * 0.5
              + stems["drums"] * 0.16 + stems["bass"] * 0.05
              + stems["atmos"] * 0.4).astype(np.float32)
    ir = make_ir(song_seed(song["id"]) + 7)
    wet_rev = convolve_stereo(r_send, ir)

    mix = dry + wet_delay * 0.32 + wet_rev * 0.55
    mix = fft_filter(mix, 27.0, "hp", 2).astype(np.float32)
    # Presence: sanfte Anhebung ab ~2.5 kHz (Tracker-Mitten sonst zu boxig)
    mix = mix + 0.30 * fft_filter(mix, 2600.0, "hp", 2).astype(np.float32)
    mix = fft_filter(mix, 17500.0, "lp", 2).astype(np.float32)

    # Loop: Ueberhang additiv an den Anfang falten
    out = np.array(mix[:loop_n], copy=True)
    tail = mix[loop_n:]
    out[: tail.shape[0]] += tail

    # Pegel: zuerst auf Ziel-RMS, dann weicher Limiter als Peak-Schutz
    tgt = dbamp(float(song.get("rms_db", TARGET_RMS_DB)))
    rms0 = float(np.sqrt(np.mean(out.astype(np.float64) ** 2)))
    g = tgt / max(rms0, 1e-9)
    work = soft_limit(out * g)

    for _ in range(5):
        pk = float(np.abs(work).max())
        rms = float(np.sqrt(np.mean(work.astype(np.float64) ** 2)))
        delta_db = ampdb(tgt) - ampdb(rms)
        if abs(delta_db) < 0.5 and pk <= PEAK_CEIL * 0.995:
            break
        if delta_db > 0.5:
            # Limiter hat Pegel gekostet: etwas nachlegen (max +1.5 dB pro Runde)
            g *= dbamp(min(delta_db, 1.5))
        elif delta_db < -0.5:
            g *= dbamp(max(delta_db, -1.5))
        else:
            break
        work = soft_limit(out * g)

    pk = float(np.abs(work).max())
    if pk > PEAK_CEIL:
        work *= PEAK_CEIL * 0.999 / pk
    out = work
    return out.astype(np.float32)


# --------------------------------------------------------------------------
# WAV schreiben
# --------------------------------------------------------------------------

def write_wav16(path, x, dither_seed=1234):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    x = np.clip(x, -1.0, 1.0)
    rng = np.random.default_rng(dither_seed)
    d = (rng.random(x.shape) - rng.random(x.shape)) * (0.5 / 32768.0)
    y = np.clip(np.round((x + d) * 32767.0), -32768, 32767).astype("<i2")
    ch = y.shape[1] if y.ndim == 2 else 1
    with wave.open(str(path), "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(y.tobytes())
    return path


def encode_ogg(wav_path, ogg_path, quality=5):
    ogg_path = Path(ogg_path)
    ogg_path.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
           "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", str(quality),
           "-ar", str(SR), str(ogg_path)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"ffmpeg fehlgeschlagen: {r.stderr.strip()}")
    return ogg_path


# --------------------------------------------------------------------------
# Song rendern
# --------------------------------------------------------------------------

def decoded_ogg_peak(path, channels=2):
    """Spitze der dekodierten OGG-Datei (das, was Godot hoert)."""
    import subprocess
    r = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path),
                        "-f", "f32le", "-ac", str(channels), "-"],
                       capture_output=True)
    if r.returncode != 0 or not r.stdout:
        return 0.0
    x = np.frombuffer(r.stdout, dtype="<f4")
    return float(np.abs(x).max()) if x.size else 0.0


def render_song(song_path, to_ogg=True, verbose=True):
    song = load_song(song_path)
    sid = song["id"]
    rng = np.random.default_rng(song_seed(sid))
    stems, loop_n, total = compose(song, rng)
    out = mix_and_master(song, stems, loop_n)
    peak = float(np.abs(out).max())
    rms = float(np.sqrt(np.mean(out.astype(np.float64) ** 2)))
    if peak >= 1.0:
        raise RuntimeError(f"{sid}: Clipping im Master (peak={peak})")
    wav = BUILD_MUSIC / f"{sid}.wav"
    ogg = MUSIC_OUT / f"{sid}.ogg"
    write_wav16(wav, out, dither_seed=song_seed(sid))
    decoded_peak = None
    if to_ogg:
        encode_ogg(wav, ogg, 5)
        # Vorbis kann Spitzen ueber den Quellpeak hinaus anheben. Deshalb wird die
        # tatsaechlich dekodierte Spitze gemessen und der Pegel nachgezogen, bis
        # die ausgelieferte Datei sicher unter -1 dBFS bleibt.
        target = dbamp(-1.2)
        for _ in range(4):
            decoded_peak = decoded_ogg_peak(ogg)
            if decoded_peak <= target:
                break
            out = (out * (target / decoded_peak) * 0.998).astype(np.float32)
            write_wav16(wav, out, dither_seed=song_seed(sid))
            encode_ogg(wav, ogg, 5)
        decoded_peak = decoded_ogg_peak(ogg)
        peak = float(np.abs(out).max())
        rms = float(np.sqrt(np.mean(out.astype(np.float64) ** 2)))
    info = {"id": sid, "title": song.get("title", ""), "bpm": song["bpm"],
            "key": f"{song['key']} {song['scale']}", "duration": loop_n / SR,
            "peak_dbfs": round(ampdb(peak), 2), "rms_dbfs": round(ampdb(rms), 2),
            "decoded_peak_dbfs": (round(ampdb(decoded_peak), 2)
                                  if decoded_peak is not None else None),
            "wav": str(wav.relative_to(ROOT)), "ogg": str(ogg.relative_to(ROOT))}
    if verbose:
        dp = info["decoded_peak_dbfs"]
        print(f"  {sid:8s} {info['duration']:6.2f}s  {song['bpm']:3.0f} BPM  "
              f"{info['key']:16s} peak {info['peak_dbfs']:6.2f} dBFS  "
              f"RMS {info['rms_dbfs']:6.2f} dBFS"
              + (f"  OGG-peak {dp:6.2f} dBFS" if dp is not None else ""), flush=True)
    return info


# ==========================================================================
# Soundeffekte
# ==========================================================================

def _tt(n):
    return np.arange(n) / SR


def _sweep(n, f0, f1, curve=1.7, phase0=0.0):
    t = _tt(n)
    k = np.clip(t / max(t[-1], 1e-9), 0.0, 1.0) ** curve
    f = f0 * (f1 / f0) ** k
    return np.sin(phase0 + np.cumsum(TWO_PI * f / SR))


def _bell(freq, dur, index=1.4, ratio=3.0, tau=0.09, attack=0.002):
    n = int(dur * SR)
    t = _tt(n)
    idx = index * np.exp(-t / (tau * 0.55))
    y = np.sin(TWO_PI * freq * t + idx * np.sin(TWO_PI * freq * ratio * t))
    return y * np.exp(-t / tau) * (1.0 - np.exp(-t / max(attack, 1e-4)))


def _fade(x, fin=0.0015, fout=0.006):
    n = x.shape[0]
    fi = min(int(fin * SR), n // 2)
    fo = min(int(fout * SR), n // 2)
    if fi > 0:
        ramp = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, fi))
        if x.ndim == 1:
            x[:fi] *= ramp
        else:
            x[:fi] *= ramp[:, None]
    if fo > 0:
        ramp = 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, fo))
        if x.ndim == 1:
            x[-fo:] *= ramp
        else:
            x[-fo:] *= ramp[:, None]
    return x


def _norm(x, peak_db):
    x = x - x.mean(axis=0)
    m = float(np.abs(x).max())
    if m <= 1e-9:
        return x
    return x * (dbamp(peak_db) / m)


def _mix_at(dst, src, at_sec, gain=1.0):
    i = int(at_sec * SR)
    n = min(src.shape[0], dst.shape[0] - i)
    if n <= 0:
        return
    if dst.ndim == 1:
        dst[i:i + n] += src[:n] * gain
    else:
        dst[i:i + n] += src[:n] * gain


# --- einzelne Effekte -----------------------------------------------------

def sfx_shot_base(rng):
    n = int(0.075 * SR)
    t = _tt(n)
    y = _sweep(n, 1500.0, 420.0, 1.5) * np.exp(-t / 0.020)
    y += 0.35 * fft_filter(rng.standard_normal(n), 5200.0, "lp", 2) * np.exp(-t / 0.004)
    y = fft_filter(y, 5200.0, "lp", 2)
    return y


def sfx_shot_fan(rng):
    n = int(0.105 * SR)
    y = np.zeros(n)
    for k, (f0, f1, at) in enumerate(((980.0, 700.0, 0.0), (1220.0, 860.0, 0.012),
                                     (1470.0, 1010.0, 0.024))):
        seg = int((0.055) * SR)
        ts = _tt(seg)
        b = _sweep(seg, f0, f1, 1.4) * np.exp(-ts / 0.016)
        _mix_at(y, b, at, 0.7 - 0.12 * k)
    y += 0.25 * fft_filter(rng.standard_normal(n), (2600.0, 7000.0), "band", 2) * np.exp(-_tt(n) / 0.02)
    y = fft_filter(y, 6000.0, "lp", 2)
    return y


def sfx_shot_lightning(rng):
    n = int(0.115 * SR)
    t = _tt(n)
    noise = fft_filter(rng.standard_normal(n), (1400.0, 8000.0), "band", 2)
    crack = noise * (0.35 + 0.65 * np.abs(np.sin(TWO_PI * 190.0 * t))) * np.exp(-t / 0.045)
    zap = _sweep(n, 3400.0, 1500.0, 0.8) * np.exp(-t / 0.030) * 0.5
    y = crack * 0.8 + zap
    return fft_filter(y, 7600.0, "lp", 2)


def sfx_shot_plasma(rng):
    n = int(0.135 * SR)
    t = _tt(n)
    thump = _sweep(n, 330.0, 105.0, 1.2) * np.exp(-t / 0.035)
    air = fft_filter(rng.standard_normal(n), 2400.0, "lp", 2) * np.exp(-t / 0.026)
    y = thump + 0.45 * air
    return fft_filter(y, 3200.0, "lp", 2)


def sfx_hit(rng):
    n = int(0.055 * SR)
    t = _tt(n)
    body = np.sin(TWO_PI * 880.0 * t) * np.exp(-t / 0.012)
    noise = fft_filter(rng.standard_normal(n), (1200.0, 6200.0), "band", 2) * np.exp(-t / 0.010)
    return fft_filter(body * 0.6 + noise * 0.9, 7000.0, "lp", 2)


def sfx_explosion_small(rng):
    n = int(0.42 * SR)
    t = _tt(n)
    rumble = fft_filter(rng.standard_normal(n), 1150.0, "lp", 2) * np.exp(-t / 0.115)
    sub = _sweep(n, 140.0, 46.0, 1.1) * np.exp(-t / 0.15)
    crackle = fft_filter(rng.standard_normal(n), (1800.0, 7000.0), "band", 2) * np.exp(-t / 0.028)
    y = 0.95 * rumble + 0.75 * sub + 0.25 * crackle
    y = np.tanh(y * 1.15)
    return fft_filter(y, 6500.0, "lp", 2)


def sfx_explosion_big(rng):
    n = int(0.95 * SR)
    t = _tt(n)
    y = np.zeros((n, 2))
    for ch in range(2):
        nz = rng.standard_normal(n)
        rumble = fft_filter(nz, 900.0, "lp", 2) * np.exp(-t / 0.32)
        sub = _sweep(n, 88.0, 27.0, 1.0) * np.exp(-t / 0.42)
        debris = fft_filter(rng.standard_normal(n), (1600.0, 7500.0), "band", 2) * np.exp(-t / 0.13)
        y[:, ch] = 0.95 * rumble + 0.8 * sub + 0.18 * debris
    y = np.tanh(y * 1.2)
    y = fft_filter(y, 6000.0, "lp", 2)
    # Stereobreite: kurze Laufzeitdifferenz der Rauschanteile
    return y


def sfx_player_hit(rng):
    n = int(0.38 * SR)
    t = _tt(n)
    y = np.zeros((n, 2))
    for ch, det in ((0, 0.0), (1, 7.0)):
        saw = np.zeros(n)
        f0 = 540.0 + det
        f = f0 * (0.16 ** np.clip(t / 0.30, 0, 1))
        saw = _saw_from_freq(f)
        y[:, ch] = np.tanh(saw * 2.2) * np.exp(-t / 0.13)
    y += 0.25 * fft_filter(rng.standard_normal((n, 2)), (600.0, 5000.0), "band", 2) * np.exp(-t / 0.05)[:, None]
    return fft_filter(y, 5000.0, "lp", 2)


def _saw_from_freq(f):
    ph = np.cumsum(f / SR) % 1.0
    return 2.0 * ph - 1.0


def sfx_shield_hit(rng):
    n = int(0.17 * SR)
    t = _tt(n)
    y = np.zeros(n)
    for f, g, tau in ((1450.0, 0.55, 0.045), (2130.0, 0.4, 0.035), (2890.0, 0.3, 0.028)):
        y += g * np.sin(TWO_PI * f * t + rng.random() * 0.4) * np.exp(-t / tau)
    y += 0.3 * fft_filter(rng.standard_normal(n), 4200.0, "hp", 2) * np.exp(-t / 0.006)
    return y


def sfx_shield_break(rng):
    n = int(0.5 * SR)
    t = _tt(n)
    y = np.zeros(n)
    for k in range(9):
        f = 2100.0 + 900.0 * rng.random()
        at = rng.random() * 0.20
        seg = int(0.16 * SR)
        b = _bell(f, 0.16, index=0.7, ratio=4.0, tau=0.045)
        _mix_at(y, b, at, 0.55 * (0.6 + 0.6 * rng.random()))
    burst = fft_filter(rng.standard_normal(n), 3200.0, "hp", 2) * np.exp(-t / 0.07)
    return y + 0.55 * burst


def sfx_bomb(rng):
    n = int(1.05 * SR)
    t = _tt(n)
    y = np.zeros((n, 2))
    # Anlauf: aufsteigendes Rauschen
    rise_n = int(0.11 * SR)
    rise = fft_filter(rng.standard_normal(rise_n), (500.0, 6000.0), "band", 2)
    rise *= np.linspace(0, 1, rise_n) ** 2 * 0.7
    for ch in range(2):
        y[:, ch] = 0.0
        _mix_at(y[:, ch], rise, 0.0, 1.0)
        nz = rng.standard_normal(n)
        boom = fft_filter(nz, 800.0, "lp", 2) * np.exp(-np.maximum(t - 0.11, 0) / 0.28)
        sub = _sweep(n, 74.0, 26.0, 0.9) * np.exp(-np.maximum(t - 0.11, 0) / 0.34)
        gate = (t >= 0.11).astype(np.float64)
        y[:, ch] += (0.95 * boom + 0.85 * sub) * gate
        y[:, ch] += 0.15 * fft_filter(rng.standard_normal(n), 5000.0, "hp", 2) * \
            np.exp(-np.maximum(t - 0.11, 0) / 0.05) * gate
    y = np.tanh(y * 1.3)
    return fft_filter(y, 6500.0, "lp", 2)


def sfx_pickup_nectar(rng):
    n = int(0.14 * SR)
    y = np.zeros(n)
    _mix_at(y, _bell(1046.5, 0.10, 1.1, 2.0, 0.055), 0.0, 0.8)
    _mix_at(y, _bell(1568.0, 0.10, 0.9, 2.0, 0.050), 0.035, 0.7)
    return y


def sfx_pickup_heart(rng):
    n = int(0.24 * SR)
    t = _tt(n)
    y = np.zeros(n)
    for k, f in enumerate((880.0, 1108.7, 1318.5)):
        _mix_at(y, _bell(f, 0.20, 0.7, 2.0, 0.11), 0.012 * k, 0.55 - 0.08 * k)
    return fft_filter(y, 8000.0, "lp", 2)


def sfx_purchase(rng):
    n = int(0.38 * SR)
    y = np.zeros(n)
    for k, f in enumerate((1046.5, 1318.5, 1568.0)):
        _mix_at(y, _bell(f, 0.22, 1.0, 3.0, 0.12), 0.055 * k, 0.6)
    _mix_at(y, _bell(2093.0, 0.28, 0.6, 2.0, 0.16), 0.14, 0.35)
    return y


def sfx_deny(rng):
    n = int(0.19 * SR)
    t = _tt(n)
    y = np.zeros(n)
    for k, (f, at) in enumerate(((233.1, 0.0), (196.0, 0.075))):
        seg = int(0.085 * SR)
        ts = _tt(seg)
        sq = _pulse((np.cumsum(np.full(seg, f) / SR)) % 1.0,
                    np.full(seg, f / SR), 0.4)
        b = fft_filter(sq, 1100.0, "lp", 2) * np.exp(-ts / 0.05)
        _mix_at(y, b, at, 0.8)
    return y


def sfx_ui_move(rng):
    n = int(0.05 * SR)
    t = _tt(n)
    y = np.sin(TWO_PI * 2480.0 * t) * np.exp(-t / 0.010)
    return fft_filter(y, 9000.0, "lp", 2)


def sfx_ui_ok(rng):
    n = int(0.10 * SR)
    y = np.zeros(n)
    for k, (f, at) in enumerate(((1318.5, 0.0), (1975.5, 0.045))):
        seg = int(0.06 * SR)
        ts = _tt(seg)
        b = np.sin(TWO_PI * f * ts) * np.exp(-ts / 0.022)
        _mix_at(y, b, at, 0.7)
    return y


def sfx_ui_back(rng):
    n = int(0.09 * SR)
    y = np.zeros(n)
    for k, (f, at) in enumerate(((1568.0, 0.0), (1046.5, 0.040))):
        seg = int(0.055 * SR)
        ts = _tt(seg)
        b = np.sin(TWO_PI * f * ts) * np.exp(-ts / 0.020)
        _mix_at(y, b, at, 0.65)
    return y


def sfx_boss_warn(rng):
    n = int(1.25 * SR)
    t = _tt(n)
    y = np.zeros(n)
    for k in range(8):
        f = 466.2 if k % 2 == 0 else 349.2
        at = k * 0.145
        seg = int(0.13 * SR)
        ts = _tt(seg)
        sq = _pulse((np.cumsum(np.full(seg, f) / SR)) % 1.0,
                    np.full(seg, f / SR), 0.5)
        sq = fft_filter(sq, 1900.0, "lp", 2)
        env = np.minimum(1.0, ts / 0.008) * np.exp(-ts / 0.20)
        _mix_at(y, sq * env, at, 0.55)
    sub = np.sin(TWO_PI * 58.0 * t) * (0.6 + 0.4 * np.sin(TWO_PI * 1.0 * t))
    y = y + 0.22 * sub
    return fft_filter(y, 2400.0, "lp", 2)


def sfx_phase_change(rng):
    n = int(0.85 * SR)
    t = _tt(n)
    y = np.zeros(n)
    r = riser(0.62, 4242, 300.0, 9000.0)
    _mix_at(y, r * 1.5, 0.02, 1.0)
    # Aufprall am Ende des Risers
    imp_n = int(0.5 * SR)
    ts = _tt(imp_n)
    imp = _sweep(imp_n, 160.0, 40.0, 1.1) * np.exp(-ts / 0.12)
    imp += 0.6 * fft_filter(rng.standard_normal(imp_n), 1200.0, "lp", 2) * np.exp(-ts / 0.10)
    _mix_at(y, np.tanh(imp * 1.4), 0.60, 0.95)
    return y


def sfx_boss_death(rng):
    n = int(1.9 * SR)
    t = _tt(n)
    y = np.zeros((n, 2))
    for k, at in enumerate((0.0, 0.18, 0.33, 0.55, 0.9)):
        e = fft_filter(rng.standard_normal(int(0.8 * SR)), 1000.0, "lp", 2)
        ts = _tt(e.shape[0])
        e = e * np.exp(-ts / (0.22 - 0.02 * k))
        e += _sweep(e.shape[0], 120.0 - 8 * k, 32.0, 1.0) * np.exp(-ts / 0.25)
        pan = -0.5 + 0.25 * k
        ang = (pan + 1.0) * np.pi / 4.0
        _mix_at(y[:, 0], e, at, 0.9 * np.cos(ang))
        _mix_at(y[:, 1], e, at, 0.9 * np.sin(ang))
    sweep_down = _sweep(n, 200.0, 26.0, 2.2) * np.exp(-t / 0.9) * 0.5
    y[:, 0] += sweep_down
    y[:, 1] += sweep_down
    y = np.tanh(y * 1.25)
    return fft_filter(y, 5500.0, "lp", 2)


def sfx_level_clear(rng):
    n = int(1.65 * SR)
    t = _tt(n)
    y = np.zeros((n, 2))
    notes = (523.25, 659.25, 783.99, 1046.5)
    for k, f in enumerate(notes):
        b = _bell(f, 0.75, 0.9, 3.0, 0.26)
        _mix_at(y[:, 0], b, 0.10 + 0.13 * k, 0.6)
        _mix_at(y[:, 1], b, 0.10 + 0.13 * k, 0.6)
    # Schlussakkord
    for f in (523.25, 659.25, 783.99, 1046.5):
        b = _bell(f, 0.85, 0.5, 2.0, 0.32)
        _mix_at(y[:, 0], b, 0.66, 0.33)
        _mix_at(y[:, 1], b, 0.66, 0.33)
    pad = np.zeros(n)
    for f in (523.25, 783.99):
        pad += np.sin(TWO_PI * f * t) * 0.18
    pad *= np.clip((t - 0.66) / 0.05, 0, 1) * np.exp(-np.maximum(t - 0.66, 0) / 0.5)
    y[:, 0] += pad
    y[:, 1] += pad
    return y


def sfx_game_over(rng):
    n = int(1.9 * SR)
    t = _tt(n)
    y = np.zeros((n, 2))
    seq = ((440.0, 0.0), (415.3, 0.42), (392.0, 0.84), (329.6, 1.26))
    for f, at in seq:
        nseg = int(0.55 * SR)
        ts = _tt(nseg)
        v = (np.sin(TWO_PI * f * ts) * 0.6
             + np.sin(TWO_PI * f * 2.0 * ts) * 0.2
             + _tri((np.cumsum(np.full(nseg, f / 2.0) / SR)) % 1.0) * 0.25)
        v *= np.minimum(1.0, ts / 0.03) * np.exp(-ts / 0.32)
        _mix_at(y[:, 0], v, at, 0.55)
        _mix_at(y[:, 1], v, at, 0.55)
    drone = (np.sin(TWO_PI * 110.0 * t) * 0.16 + np.sin(TWO_PI * 164.8 * t) * 0.1)
    drone *= np.exp(-t / 1.1) * np.clip(t / 0.2, 0, 1)
    y[:, 0] += drone
    y[:, 1] += drone
    return fft_filter(y, 4200.0, "lp", 2)


def sfx_checkpoint(rng):
    n = int(0.75 * SR)
    y = np.zeros(n)
    _mix_at(y, _bell(783.99, 0.35, 0.8, 2.0, 0.16), 0.0, 0.55)
    _mix_at(y, _bell(1046.5, 0.45, 0.7, 2.0, 0.20), 0.11, 0.5)
    _mix_at(y, _bell(1568.0, 0.35, 0.4, 2.0, 0.16), 0.24, 0.22)
    return y


def sfx_low_hp_warn(rng):
    n = int(0.32 * SR)
    t = _tt(n)
    y = np.zeros(n)
    for at in (0.0, 0.165):
        seg = int(0.10 * SR)
        ts = _tt(seg)
        sq = _pulse((np.cumsum(np.full(seg, 880.0) / SR)) % 1.0,
                    np.full(seg, 880.0 / SR), 0.45)
        b = fft_filter(sq, 2600.0, "lp", 2) * np.exp(-ts / 0.055)
        _mix_at(y, b, at, 0.55)
    return y


def sfx_combo_ready(rng):
    n = int(0.28 * SR)
    y = np.zeros(n)
    for k, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        _mix_at(y, _bell(f, 0.14, 0.8, 2.0, 0.06), 0.035 * k, 0.5 - 0.06 * k)
    return y


# Name -> (Generator, Ziel-Peak in dBFS, Stereo?)
SFX_SPECS = {
    "shot_base":      (sfx_shot_base,      -12.5, False),
    "shot_fan":       (sfx_shot_fan,       -12.5, False),
    "shot_lightning": (sfx_shot_lightning, -12.5, False),
    "shot_plasma":    (sfx_shot_plasma,    -12.5, False),
    "hit":            (sfx_hit,            -11.0, False),
    "explosion_small": (sfx_explosion_small, -7.5, False),
    "explosion_big":  (sfx_explosion_big,  -5.5, True),
    "player_hit":     (sfx_player_hit,     -8.0, True),
    "shield_hit":     (sfx_shield_hit,     -9.5, False),
    "shield_break":   (sfx_shield_break,   -8.0, False),
    "bomb":           (sfx_bomb,           -4.5, True),
    "pickup_nectar":  (sfx_pickup_nectar,  -14.0, False),
    "pickup_heart":   (sfx_pickup_heart,   -13.5, False),
    "purchase":       (sfx_purchase,       -13.0, False),
    "deny":           (sfx_deny,           -13.0, False),
    "ui_move":        (sfx_ui_move,        -20.0, False),
    "ui_ok":          (sfx_ui_ok,          -18.0, False),
    "ui_back":        (sfx_ui_back,        -18.5, False),
    "boss_warn":      (sfx_boss_warn,      -8.0, False),
    "phase_change":   (sfx_phase_change,   -6.5, False),
    "boss_death":     (sfx_boss_death,     -4.5, True),
    "level_clear":    (sfx_level_clear,    -6.0, True),
    "game_over":      (sfx_game_over,      -7.0, True),
    "checkpoint":     (sfx_checkpoint,     -11.0, False),
    "low_hp_warn":    (sfx_low_hp_warn,    -9.0, False),
    "combo_ready":    (sfx_combo_ready,    -12.0, False),
}


def build_sfx(only=None, verbose=True):
    rows = []
    for i, (name, (fn, peak_db, stereo)) in enumerate(SFX_SPECS.items()):
        if only and name not in only:
            continue
        rng = np.random.default_rng(zlib.crc32(name.encode()) & 0x7FFFFFFF)
        y = fn(rng)
        if y.ndim == 1:
            y = y[:, None] if stereo else y
        if stereo and y.ndim == 1:
            y = np.stack([y, y], axis=1)
        if not stereo and y.ndim == 2:
            y = y.mean(axis=1)
        y = _norm(y, peak_db)
        y = _fade(y, 0.0008, 0.008 if y.shape[0] > int(0.03 * SR) else 0.004)
        y = np.clip(y, -1.0, 1.0)
        path = SFX_OUT / f"{name}.wav"
        write_wav16(path, y if y.ndim == 2 else y[:, None], dither_seed=i + 77)
        pk = float(np.abs(y).max())
        rms = float(np.sqrt(np.mean(y.astype(np.float64) ** 2)))
        dur = y.shape[0] / SR
        rows.append({"name": name, "dur": round(dur, 4),
                     "peak_dbfs": round(ampdb(pk), 2),
                     "rms_dbfs": round(ampdb(rms), 2),
                     "channels": 2 if y.ndim == 2 else 1})
        if verbose:
            print(f"  {name:16s} {dur*1000:7.1f} ms  peak {ampdb(pk):6.2f} dBFS  "
                  f"RMS {ampdb(rms):6.2f} dBFS  {'st' if y.ndim == 2 else 'mo'}",
                  flush=True)
    return rows


# ==========================================================================
# CLI
# ==========================================================================

def song_paths():
    return sorted(SONG_DIR.glob("*.py"))


def main(argv=None):
    ap = argparse.ArgumentParser(description="Apidya Reimagined Audio-Renderer")
    ap.add_argument("mode", choices=["music", "sfx", "all", "list"], nargs="?", default="all")
    ap.add_argument("--only", default="", help="Komma-Liste von IDs/Namen")
    ap.add_argument("--jobs", type=int, default=min(6, os.cpu_count() or 2))
    ap.add_argument("--no-ogg", action="store_true")
    args = ap.parse_args(argv)

    only = [s.strip() for s in args.only.split(",") if s.strip()]
    MUSIC_OUT.mkdir(parents=True, exist_ok=True)
    SFX_OUT.mkdir(parents=True, exist_ok=True)
    BUILD_MUSIC.mkdir(parents=True, exist_ok=True)

    report = {"music": [], "sfx": []}

    if args.mode in ("music", "all", "list"):
        songs = [p for p in song_paths() if not p.name.startswith("_")]
        sel = []
        for p in songs:
            s = load_song(p)
            if only and s["id"] not in only:
                continue
            sel.append(p)
        if args.mode == "list":
            for p in sel:
                s = load_song(p)
                print(f"{s['id']:9s} {s.get('title',''):28s} {s['bpm']:4.0f} BPM "
                      f"{s['key']:>3s} {s['scale']:14s} {s.get('bars',32):2d} Takte")
            return 0
        print(f"Musik: {len(sel)} Titel -> {MUSIC_OUT}")
        if args.jobs > 1 and len(sel) > 1:
            from multiprocessing import Pool
            with Pool(args.jobs) as pool:
                res = pool.starmap(render_song,
                                   [(p, not args.no_ogg, True) for p in sel])
            report["music"] = res
        else:
            for p in sel:
                report["music"].append(render_song(p, not args.no_ogg, True))

    if args.mode in ("sfx", "all"):
        names = set(SFX_SPECS)
        if only:
            names &= set(only)
        print(f"SFX: {len(names)} Dateien -> {SFX_OUT}")
        report["sfx"] = build_sfx(names if only else None, True)

    report_path = BUILD_DIR / "render_report.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    if report_path.exists():
        try:
            old = json.loads(report_path.read_text())
            for key in ("music", "sfx"):
                merged = {r["id" if key == "music" else "name"]: r for r in old.get(key, [])}
                for r in report[key]:
                    merged[r["id" if key == "music" else "name"]] = r
                report[key] = sorted(merged.values(),
                                     key=lambda r: r["id" if key == "music" else "name"])
        except Exception:
            pass
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False))
    print(f"\nBericht: {report_path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
