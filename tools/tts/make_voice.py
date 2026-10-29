"""Sprachansagen mit Piper (lokal, offline) erzeugen.

Einrichtung: tools/tts/setup.sh (Python-Umgebung + Stimme Thorsten, high).
Aufruf:      python3 tools/tts/make_voice.py
Danach:      tools/import_shuttle.sh assets/audio/voice/*.ogg

Jede Zeile in LINES wird einzeln gesprochen, Stille abgeschnitten, Pegel
angeglichen und als assets/audio/voice/<id>.ogg abgelegt (über import_voice).
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tools/music'))
import import_voice as iv  # noqa: E402

PIPER = HERE / '.venv/bin/piper'
MODEL = HERE / 'voices/de_DE-thorsten-high.onnx'

# Kennung -> gesprochener Text. Kurz und klar: die Ansage soll das Spiel nicht aufhalten.
LINES = {
    'upgrade_base': 'Basis!',
    'upgrade_fan': 'Fächer!',
    'upgrade_lightning': 'Blitz!',
    'upgrade_plasma': 'Plasma!',
    'upgrade_companion': 'Drohne!',
    'upgrade_bombs': 'Bombe!',
    'upgrade_shield': 'Schild!',
    'upgrade_speed': 'Tempo!',
    'upgrade_repair': 'Reparatur!',
    'nectar_low': 'Zu wenig Blütenstaub.',
    'upgrade_max': 'Voll ausgebaut!',
}
# Etwas zügiger als normal (1.0), damit schnelles Blättern verständlich bleibt.
LENGTH_SCALE = '0.88'


def main() -> int:
    if not PIPER.exists() or not MODEL.exists():
        print('Piper oder Stimme fehlt – zuerst tools/tts/setup.sh ausführen.', file=sys.stderr)
        return 1
    work = ROOT / 'tools/music/build/voice'
    work.mkdir(parents=True, exist_ok=True)
    for key, text in LINES.items():
        raw = work / f'{key}.wav'
        subprocess.run([str(PIPER), '-m', str(MODEL), '-f', str(raw), '--length-scale', LENGTH_SCALE],
                       input=text, text=True, check=True, capture_output=True)
        iv.write_named(key, iv.decode(raw), f'{text} ({key})')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
