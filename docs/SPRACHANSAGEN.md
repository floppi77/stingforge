# Sprachansagen

Das Spiel sagt das gewählte Upgrade an, wenn du mit LB/RB (Tastatur Q/E) in der
Waffenleiste blätterst. Es meldet „Zu wenig Blütenstaub“, wenn ein Kauf daran
scheitert, und „Voll ausgebaut!“, wenn das Upgrade schon die höchste Stufe hat.
Abschaltbar unter Einstellungen › Audio › Sprachansagen.

## Erzeugung mit Qwen3-TTS (lokal, GPU)

- **Werkzeug:** [Qwen3-TTS](https://github.com/QwenLM/Qwen3-TTS) in einer eigenen
  Python-3.12-Umgebung unter `tools/tts/.venv-qwen`, Modelle unter `tools/tts/models`
  (je etwa 4,3 GB). Das ist keine Systeminstallation und liegt nicht in Git.
- **Modelle:** `Qwen3-TTS-12Hz-1.7B-VoiceDesign` und `Qwen3-TTS-12Hz-1.7B-Base`, beide
  Apache-2.0.
- **Stimme „Heldin“:** aus einer Beschreibung in Worten entworfen (warm, hell, verspielt,
  wie eine fröhliche Funkerin), sie gehört keinem echten Sprecher. Die Beschreibung und
  weitere Kandidaten stehen in `VOICES` in `tools/tts/make_voice_qwen.py`.

Zwei Schritte, damit alle Ansagen nach derselben Person klingen:

1. VoiceDesign spricht mit der beschriebenen Stimme einmal einen Referenzsatz
   (`tools/tts/voices/qwen_<stimme>.wav`).
2. Das Basismodell klont diese Referenz und spricht jede Zeile einzeln. Zeilen in
   `RETAKES` werden mehrfach gesprochen; genommen wird die Fassung, deren Tonhöhe den
   übrigen Ansagen am nächsten liegt. Das betrifft derzeit „Bombe!“, das sonst zu tief endet.

Einrichten:

```bash
tools/tts/setup_qwen.sh
```

Hörproben aller Kandidaten nach `build/stimmproben_qwen`:

```bash
tools/tts/.venv-qwen/bin/python tools/tts/make_voice_qwen.py --probe
```

Ansagen fürs Spiel erzeugen und importieren:

```bash
tools/tts/.venv-qwen/bin/python tools/tts/make_voice_qwen.py
```

```bash
tools/import_shuttle.sh assets/audio/voice/*.ogg
```

`--refresh` entwirft die Referenzstimme neu. Die Erzeugung ist mit festem Seed
wiederholbar.

## Texte

| Datei | Text |
|---|---|
| `upgrade_base` | Basis! |
| `upgrade_fan` | Fächer! |
| `upgrade_lightning` | Blitz! |
| `upgrade_plasma` | Plasma! |
| `upgrade_companion` | Drohne! |
| `upgrade_bombs` | Bombe! |
| `upgrade_shield` | Schild! |
| `upgrade_speed` | Tempo! |
| `upgrade_repair` | Reparatur! |
| `nectar_low` | Zu wenig Blütenstaub. |
| `upgrade_max` | Voll ausgebaut! |

Neue Ansagen:
1. Zeile in `LINES` in `tools/tts/make_voice.py` ergänzen.
2. Die Kennung in `SOLO` in `make_voice_qwen.py` eintragen, damit die freigegebenen Ansagen
   unverändert bleiben.
3. Nur die neue Zeile erzeugen: `make_voice_qwen.py --only=<kennung>`.
4. Im Spiel `Audio.voice("<datei>", "<Text>")` aufrufen.

## Ältere Wege

- **Piper** (`tools/tts/setup.sh`, `tools/tts/make_voice.py`, Stimme *Thorsten*, Datensatz CC0)
  läuft ohne GPU und bleibt als Rückfall erhalten. Die Stimme klang aber zu dunkel und
  abgehackt.
- Fremde Aufnahmen, etwa aus einem anderen Sprachdienst, verarbeitet weiterhin
  `tools/music/import_voice.py`, auch eine einzelne Sammelaufnahme mit Pausen.
