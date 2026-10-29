#!/usr/bin/env bash
# Qwen3-TTS lokal einrichten (ohne Systeminstallation, NVIDIA-GPU empfohlen):
# Python-3.12-Umgebung in tools/tts/.venv-qwen, Modelle (je ~4,3 GB) in tools/tts/models.
# Modelle: Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign und -Base, beide Apache-2.0.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
uv venv -p 3.12 "$HERE/.venv-qwen"
uv pip install -p "$HERE/.venv-qwen/bin/python" qwen-tts soundfile
for m in VoiceDesign Base; do
	"$HERE/.venv-qwen/bin/python" -c "from huggingface_hub import snapshot_download as d; \
d('Qwen/Qwen3-TTS-12Hz-1.7B-$m', local_dir='$HERE/models/Qwen3-TTS-12Hz-1.7B-$m')"
done
echo "Qwen3-TTS bereit: $HERE/.venv-qwen/bin/python $HERE/make_voice_qwen.py"
