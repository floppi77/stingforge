# Sprachansagen

Das Spiel sagt das gewählte Upgrade an, wenn du mit LB/RB (Tastatur Q/E) in der
Waffenleiste blätterst, und meldet „Zu wenig Blütenstaub“, wenn ein Kauf daran
scheitert. Abschaltbar unter Einstellungen › Audio › Sprachansagen.

## Erzeugung mit Piper (lokal, offline)

- **Werkzeug:** [Piper](https://github.com/rhasspy/piper) in einer eigenen Python-Umgebung
  unter `tools/tts/.venv`. Das ist keine Systeminstallation und liegt nicht in Git.
- **Stimme:** *Thorsten* (high) aus `rhasspy/piper-voices`.
  - Die Sprachdaten von [Thorsten-Voice](https://github.com/thorstenMueller/Thorsten-Voice)
    stehen unter CC0.
  - Das Modell wurde aus der englischen „lessac“-Stimme feintrainiert. Vor einer kommerziellen
    Veröffentlichung deren Bedingungen prüfen.

Einrichten:

```bash
tools/tts/setup.sh
```

Ansagen erzeugen:

```bash
python3 tools/tts/make_voice.py
```

Ins Spiel importieren:

```bash
tools/import_shuttle.sh assets/audio/voice/*.ogg
```

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

Neue Ansagen: Zeile in `LINES` in `tools/tts/make_voice.py` ergänzen und im Spiel
`Audio.voice("<datei>", "<Text>")` aufrufen.

Fremde Aufnahmen, etwa aus einem anderen Sprachdienst, verarbeitet weiterhin
`tools/music/import_voice.py`, auch eine einzelne Sammelaufnahme mit Pausen.
