#!/usr/bin/env bash
# Piper-Sprachsynthese lokal einrichten (ohne Systeminstallation):
# Python-Umgebung in tools/tts/.venv und deutsche Stimme "Thorsten" (high).
# Stimme: Datensatz Thorsten-Voice (CC0), Modell von rhasspy/piper-voices.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
python3 -m venv "$HERE/.venv"
"$HERE/.venv/bin/pip" install -q piper-tts
mkdir -p "$HERE/voices"
BASE="https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/thorsten/high"
for f in de_DE-thorsten-high.onnx de_DE-thorsten-high.onnx.json; do
	[ -f "$HERE/voices/$f" ] || curl -sL -o "$HERE/voices/$f" "$BASE/$f"
done
echo "Piper bereit: $HERE/.venv/bin/piper"
