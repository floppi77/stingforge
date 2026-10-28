#!/usr/bin/env bash
# Apidya Reimagined - Audioproduktion komplett neu rendern und pruefen.
#
#   bash tools/audio/render.sh              # alles: Musik + SFX + Messbericht
#   bash tools/audio/render.sh music        # nur Musik
#   bash tools/audio/render.sh sfx          # nur Soundeffekte
#   bash tools/audio/render.sh verify       # nur messen (nichts neu rendern)
#
# Voraussetzungen: python3 mit numpy und Pillow, ffmpeg (mit libvorbis).
# Ergebnis:
#   assets/audio/music/*.ogg        13 Titel, loopbar
#   assets/audio/sfx/*.wav          26 Effekte, 44,1 kHz/16 Bit
#   tools/audio/build/              Zwischen-WAVs, Messberichte, Spektrogramme
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

MODE="${1:-all}"
JOBS="${JOBS:-6}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "FEHLT: $1" >&2; exit 1; }; }
need python3
need ffmpeg
need ffprobe

python3 - <<'PY' || { echo "python3 braucht numpy und Pillow" >&2; exit 1; }
import numpy, PIL  # noqa: F401
PY

case "$MODE" in
  music)   python3 synth.py music --jobs "$JOBS" ;;
  sfx)     python3 synth.py sfx ;;
  verify)  python3 verify.py ;;
  all)
    python3 synth.py music --jobs "$JOBS"
    python3 synth.py sfx
    python3 verify.py
    ;;
  *) echo "Unbekannter Modus: $MODE (music|sfx|verify|all)" >&2; exit 2 ;;
esac

echo
echo "Dateien:"
ls -1 ../../assets/audio/music/*.ogg | wc -l | xargs echo "  Musik-OGG:"
ls -1 ../../assets/audio/sfx/*.wav  | wc -l | xargs echo "  SFX-WAV:  "
echo "Messbericht: tools/audio/build/verify_report.json"
