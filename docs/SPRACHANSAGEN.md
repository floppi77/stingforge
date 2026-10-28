# Sprachansagen (Upgrade-Wahl mit LB/RB)

Beim Blättern in der Waffenleiste sagt das Spiel das gewählte Upgrade an.
Liegt ein Clip unter `assets/audio/voice/upgrade_<id>.ogg`, wird er abgespielt.
Sonst greift die Systemstimme (Windows: SAPI; Linux: nur mit speech-dispatcher).

## Benötigte Texte (9 Clips)

| Datei | Text |
|---|---|
| `upgrade_base` | Basis |
| `upgrade_fan` | Fächer |
| `upgrade_lightning` | Blitz |
| `upgrade_plasma` | Plasma |
| `upgrade_companion` | Drohne |
| `upgrade_bombs` | Bombe |
| `upgrade_shield` | Schild |
| `upgrade_speed` | Tempo |
| `upgrade_repair` | Reparatur |

Die Wörter entsprechen den Kurznamen in der Leiste. Ausrufezeichen am Wortende
(„Blitz!“) machen die Ansage meist knackiger. Das ist Geschmackssache, beide
Varianten funktionieren.

## Vorschlag für ElevenLabs

- **Modell:** *Eleven Multilingual v2* (gutes Deutsch).
- **Stimme:** eine der Standardstimmen im Konto, die auch im Gratis-Tarif nutzbar sind.
  - Empfehlung: **Daniel**, ruhig, tief und bestimmt, passt als „Bordcomputer“.
  - Alternativen: **Brian** (warm, tief) oder **Charlotte**, falls eine Frauenstimme gewünscht ist.
- **Einstellungen als Startpunkt:** Stability ca. 50 %, Similarity ca. 75 %,
  Style ca. 20 %, Speaker Boost an, Tempo 1,0–1,1.
- **Ablauf:** alles in **einem** Durchgang mit genau diesem Text (Reihenfolge nicht ändern):

```text
Basis! <break time="1.2s" /> Fächer! <break time="1.2s" /> Blitz! <break time="1.2s" /> Plasma! <break time="1.2s" /> Drohne! <break time="1.2s" /> Bombe! <break time="1.2s" /> Schild! <break time="1.2s" /> Tempo! <break time="1.2s" /> Reparatur!
```

  Die eine Datei zerlege ich mit `python3 tools/music/import_voice.py <datei>` an den Pausen.
- **Format:** egal (MP3, WAV oder OGG). Ich schneide Stille weg, gleiche die Lautheit an,
  wandle in OGG und lege die Dateien ab.

**Lizenz bitte selbst prüfen:** Nach meinem Stand verlangt der Gratis-Tarif von
ElevenLabs eine Namensnennung und erlaubt keine kommerzielle Nutzung. Für ein
veröffentlichtes oder verkauftes Spiel braucht es einen bezahlten Tarif. Das kann
sich geändert haben.

## Stand

Die Clips stammen aus ElevenLabs (eine Sammelaufnahme, am 28.10.2026 zerlegt).
Sie liegen als `assets/audio/voice/upgrade_*.ogg` im Spiel. Für eine neue Stimme
die Datei ersetzen und das Werkzeug erneut laufen lassen:

```bash
python3 tools/music/import_voice.py assets/audio/voice/eingang
```

```bash
tools/import_shuttle.sh assets/audio/voice/upgrade_*.ogg
```

## Übergabe

Lege die Dateien in einen Ordner, zum Beispiel `assets/audio/voice/eingang/`,
benannt wie oben (`upgrade_lightning.mp3` …) oder mit dem gesprochenen Wort
(`Blitz.mp3`). Ich ordne sie zu, bearbeite sie und baue sie ein.
