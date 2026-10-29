"""Sprachansagen mit Qwen3-TTS (lokal, GPU) erzeugen.

Einrichtung: tools/tts/setup_qwen.sh (Python-Umgebung .venv-qwen + Modelle VoiceDesign/Base)
Aufruf:      tools/tts/.venv-qwen/bin/python tools/tts/make_voice_qwen.py [--probe] [--en] [--only=id,…] [stimme]
Danach:      tools/import_shuttle.sh assets/audio/voice/*.ogg

Zwei Schritte, damit alle Ansagen nach derselben Person klingen:
  1. VoiceDesign entwirft aus einer Beschreibung in Worten eine Stimme und spricht
     damit einen Referenzsatz (gespeichert unter tools/tts/voices/qwen_<stimme>.wav).
  2. Das Basismodell klont diese Referenz und spricht jede Zeile aus LINES einzeln.
--probe legt statt der Spielclips eine Hörprobe je Stimme in build/stimmproben_qwen ab.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import soundfile as sf
import torch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / 'tools/music'))
import import_voice as iv  # noqa: E402
from make_voice import LINES, LINES_EN  # noqa: E402

DESIGN_MODEL = HERE / 'models/Qwen3-TTS-12Hz-1.7B-VoiceDesign'
CLONE_MODEL = HERE / 'models/Qwen3-TTS-12Hz-1.7B-Base'
PROBE_DIR = ROOT / 'build/stimmproben_qwen'
SEED = 7

# Stimmbeschreibungen (Englisch versteht das Modell am genauesten).
VOICES = {
    'ansagerin': 'A young female arcade game announcer, bright clear high voice, energetic and enthusiastic, '
                 'with a smile in her voice. Short punchy exclamations, crisp articulation, native German speaker.',
    'ansager': 'A young male arcade game announcer in his twenties, bright tenor voice, excited and dynamic, '
               'crisp and punchy delivery like a retro video game voice-over, native German speaker.',
    'heldin': 'A confident, warm female voice-over artist, mid-pitched and bright, playful and lively, like a '
              'cheerful mission control voice in a colorful video game, clear German pronunciation.',
    'kobold': 'A small, cheeky, high-pitched voice of a friendly insect companion, fast, bubbly and expressive, '
              'very clear German pronunciation, cartoon video game style.',
}
VOICE = 'heldin'
# Zeilen, die mit dem festen Seed aus der Reihe fallen (z. B. zu tief): mehrere Fassungen
# sprechen und die nehmen, deren Tonhöhe den übrigen Ansagen am nächsten liegt.
RETAKES = {'upgrade_bombs'}
RETAKE_TRIES = 8
# Später ergänzte Zeilen: einzeln gesprochen (wie RETAKES), damit der Stapel der
# freigegebenen Ansagen unverändert bleibt.
SOLO = {'upgrade_max'}
# Referenzsatz: kurze Ausrufe mit Schwung, damit der Klon Tempo und Ausdruck übernimmt.
REF_TEXT = 'Achtung! Neue Waffe bereit! Schild hoch, Tempo rauf – und jetzt zeigen wir dem Schwarm, was wir können!'


def _load(path: Path):
    from qwen_tts import Qwen3TTSModel
    return Qwen3TTSModel.from_pretrained(str(path), device_map='cuda:0', dtype=torch.bfloat16,
                                         attn_implementation='sdpa')


def design(names: list[str], refresh: bool = False) -> dict[str, Path]:
    """Referenzaufnahme je Stimme entwerfen (vorhandene werden wiederverwendet)."""
    refs = {n: HERE / f'voices/qwen_{n}.wav' for n in names}
    todo = [n for n in names if refresh or not refs[n].exists()]
    if todo:
        model = _load(DESIGN_MODEL)
        refs[todo[0]].parent.mkdir(parents=True, exist_ok=True)
        for n in todo:
            torch.manual_seed(SEED)
            wavs, sr = model.generate_voice_design(text=REF_TEXT, language='German', instruct=VOICES[n])
            sf.write(refs[n], wavs[0], sr)
        del model
        torch.cuda.empty_cache()
    return refs


def pitch(w: np.ndarray, sr: int) -> float:
    """Mittlere Grundfrequenz (Autokorrelation) der lauten Abschnitte."""
    fr = int(sr * 0.03)
    w = w / (np.abs(w).max() + 1e-9)
    vals = []
    for i in range(0, len(w) - fr, fr // 2):
        s = w[i:i + fr] - w[i:i + fr].mean()
        if np.sqrt(np.mean(s ** 2)) < 0.03:
            continue
        ac = np.correlate(s, s, 'full')[fr - 1:]
        k = sr // 500 + int(np.argmax(ac[sr // 500:sr // 70]))
        if ac[k] > 0.5 * ac[0]:
            vals.append(sr / k)
    return float(np.median(vals)) if vals else 0.0


def speak(refs: dict[str, Path], lines: dict[str, str] = LINES, language: str = 'German',
          solo: set[str] = SOLO) -> dict[str, tuple[dict[str, np.ndarray], int]]:
    """Alle Zeilen mit der geklonten Referenzstimme sprechen."""
    model = _load(CLONE_MODEL)
    keys = [k for k in lines if k not in solo]
    texts = [lines[k] for k in keys]
    out = {}
    for n, ref in refs.items():
        prompt = model.create_voice_clone_prompt(ref_audio=str(ref), ref_text=REF_TEXT)
        torch.manual_seed(SEED)
        wavs, sr = model.generate_voice_clone(text=texts, language=[language] * len(texts),
                                              voice_clone_prompt=prompt * len(texts))
        wavs = list(wavs)
        target = float(np.median([pitch(w, sr) for k, w in zip(keys, wavs) if k not in RETAKES]))
        for k in solo & set(lines):
            keys.append(k)
            texts.append(lines[k])
            wavs.append(np.zeros(1, dtype=np.float32))
        for k in (RETAKES | solo) & set(keys):
            i = keys.index(k)
            tries = []
            for t in range(RETAKE_TRIES):
                torch.manual_seed(SEED + 100 + t)
                w, _ = model.generate_voice_clone(text=texts[i], language=language, voice_clone_prompt=prompt)
                tries.append(w[0])
            best = min(tries, key=lambda w: abs(pitch(w, sr) - target))
            print(f'{n}/{k}: {pitch(wavs[i], sr):.0f} Hz -> {pitch(best, sr):.0f} Hz (Ziel {target:.0f} Hz)')
            wavs[i] = best
        out[n] = (dict(zip(keys, wavs)), sr)
    return out


def main(argv: list[str]) -> int:
    probe = '--probe' in argv
    # --only=upgrade_max,nectar_low schreibt nur diese Clips (übrige bleiben unangetastet).
    only = {k for a in argv if a.startswith('--only=') for k in a[7:].split(',') if k}
    names = [a for a in argv if not a.startswith('--')] or (list(VOICES) if probe else [VOICE])
    # --en: englische Ansagen (gleiche Stimme, geklont), Ablage unter assets/audio/voice/en/.
    english = '--en' in argv
    lines = LINES_EN if english else LINES
    refs = design(names, refresh='--refresh' in argv)
    spoken = speak(refs, lines, 'English', set()) if english else speak(refs)
    for n, (wavs, sr) in spoken.items():
        if probe:
            PROBE_DIR.mkdir(parents=True, exist_ok=True)
            gap = np.zeros(int(sr * 0.45), dtype=np.float32)
            ref, rsr = sf.read(refs[n], dtype='float32')
            parts = [ref, np.zeros(int(rsr * 0.8), dtype=np.float32)]
            for key in lines:
                parts += [wavs[key].astype(np.float32), gap]
            name = f'{n}_en' if english else n
            sf.write(PROBE_DIR / f'{name}.wav', np.concatenate(parts), sr)
            print(f'Hörprobe {name}: {PROBE_DIR / (name + ".wav")}')
            continue
        tmp = ROOT / 'tools/music/build/voice'
        tmp.mkdir(parents=True, exist_ok=True)
        for key, text in lines.items():
            if only and key not in only:
                continue
            raw = tmp / f'{key}.wav'
            sf.write(raw, wavs[key], sr)
            iv.write_named(('en/' if english else '') + key, iv.decode(raw), f'{text} ({key})')
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
