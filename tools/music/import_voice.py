"""Sprachclips (z. B. aus ElevenLabs) für die Upgrade-Ansage aufbereiten.

Aufruf: python3 tools/music/import_voice.py <ordner oder eine Datei>

Eine einzelne Aufnahme (alle Wörter mit Pausen, Reihenfolge wie ORDER) wird an
den Pausen in neun Clips zerlegt. Alternativ Einzeldateien, erkannt nach Kennung
(upgrade_lightning.mp3) oder Wort (Blitz.mp3). Stille wird abgeschnitten, der Pegel
angeglichen, Ausgabe als mono OGG nach assets/audio/voice/upgrade_<id>.ogg.
Danach: tools/import_shuttle.sh assets/audio/voice/*.ogg
"""
from __future__ import annotations

import subprocess
import sys
import unicodedata
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/voice'
WORDS = {'basis': 'base', 'facher': 'fan', 'blitz': 'lightning', 'plasma': 'plasma', 'drohne': 'companion',
         'bombe': 'bombs', 'schild': 'shield', 'tempo': 'speed', 'reparatur': 'repair'}
IDS = set(WORDS.values())
## Reihenfolge der Wörter in der Sammelaufnahme (siehe docs/SPRACHANSAGEN.md).
ORDER = ['base', 'fan', 'lightning', 'plasma', 'companion', 'bombs', 'shield', 'speed', 'repair']
SR = 44100


def key(stem: str) -> str | None:
    s = unicodedata.normalize('NFKD', stem.lower()).encode('ascii', 'ignore').decode()
    s = s.removeprefix('upgrade_')
    if s in IDS:
        return s
    for word, uid in WORDS.items():
        if word in s:
            return uid
    return None


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def trim(x: np.ndarray, thresh_db: float = -45.0, pad: float = 0.02) -> np.ndarray:
    win = int(0.01 * SR)
    env = np.sqrt(np.convolve(x ** 2, np.ones(win) / win, mode='same'))
    idx = np.where(env > 10 ** (thresh_db / 20) * np.abs(x).max())[0]
    if idx.size == 0:
        return x
    a = max(0, idx[0] - int(pad * SR))
    b = min(len(x), idx[-1] + int(pad * 3 * SR))
    y = x[a:b].copy()
    fade = min(len(y) // 4, int(0.015 * SR))
    y[-fade:] *= np.linspace(1, 0, fade)
    return y


def split(x: np.ndarray, count: int) -> list[np.ndarray]:
    """Sammelaufnahme an den längsten Pausen in `count` Wörter teilen."""
    win = int(0.02 * SR)
    env = np.sqrt(np.convolve(x ** 2, np.ones(win) / win, mode='same'))
    loud = env > 10 ** (-40 / 20) * env.max()
    # Zusammenhängende stille Strecken finden
    gaps = []
    i = 0
    while i < len(loud):
        if not loud[i]:
            j = i
            while j < len(loud) and not loud[j]:
                j += 1
            if i > 0 and j < len(loud):
                gaps.append((j - i, i, j))
            i = j
        else:
            i += 1
    gaps = sorted(sorted(gaps, reverse=True)[:count - 1], key=lambda g: g[1])
    if len(gaps) < count - 1:
        raise SystemExit(f'nur {len(gaps) + 1} Wörter erkannt, erwartet {count}')
    cuts = [0] + [(a + b) // 2 for _, a, b in gaps] + [len(x)]
    return [x[cuts[k]:cuts[k + 1]] for k in range(count)]


def write(uid: str, y: np.ndarray, label: str) -> None:
    write_named(f'upgrade_{uid}', y, label)


def write_named(name: str, y: np.ndarray, label: str) -> None:
    """Clip aufbereiten und als assets/audio/voice/<name>.ogg ablegen."""
    y = trim(y)
    # Spitzenpegel -3 dBFS: deutlich über SFX/Musik hörbar, ohne zu übersteuern.
    y = y / (np.abs(y).max() + 1e-12) * 10 ** (-3 / 20)
    tmp = OUT / f'_{name.replace("/", "_")}.wav'
    (OUT / name).parent.mkdir(parents=True, exist_ok=True)
    sf.write(tmp, y, SR, subtype='PCM_16')
    out = OUT / f'{name}.ogg'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(tmp), '-c:a', 'libvorbis', '-q:a', '5', str(out)],
                   check=True)
    tmp.unlink()
    print(f'{label} -> {out.relative_to(ROOT)} ({len(y) / SR:.2f} s)')


def main() -> int:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT / 'eingang'
    OUT.mkdir(parents=True, exist_ok=True)
    audio = [f for f in ([src] if src.is_file() else sorted(src.iterdir()))
             if f.suffix.lower() in ('.mp3', '.wav', '.ogg', '.flac', '.m4a')]
    if len(audio) == 1 and key(audio[0].stem) is None:
        for uid, part in zip(ORDER, split(decode(audio[0]), len(ORDER))):
            write(uid, part, f'{audio[0].name} [{uid}]')
        return 0
    done = set()
    for f in audio:
        if f.suffix.lower() not in ('.mp3', '.wav', '.ogg', '.flac', '.m4a'):
            continue
        uid = key(f.stem)
        if uid is None:
            print('übersprungen (kein Upgrade erkannt):', f.name)
            continue
        write(uid, decode(f), f.name)
        done.add(uid)
    missing = IDS - done
    if missing:
        print('fehlt noch:', ', '.join(sorted(missing)))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
