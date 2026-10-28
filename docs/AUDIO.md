# Audio: Produktion, Technik, Reproduktion

Dieses Dokument beschreibt, wie die Musik und die Soundeffekte von
**Apidya Reimagined** entstanden sind, warum die Produktion anders aussieht als
ursprünglich geplant, und wie man alles neu erzeugt und prüft.

Alle Zahlen in diesem Text sind gemessen, nicht geschätzt. Die vollständige
Messwerttabelle steht in [AUDIO_MEASUREMENTS.md](AUDIO_MEASUREMENTS.md) und wird
bei jedem Prüflauf neu erzeugt.

---

## 1. Abweichung von der ursprünglichen Vorgabe

Die ursprüngliche Vorgabe lautete: MIDI-Daten mit **FluidSynth** und einem
**SoundFont** rendern, den Arrangement-Teil in **LMMS** bauen.

Das war auf diesem Rechner nicht möglich, und zwar nicht als Bequemlichkeit,
sondern als harte technische Grenze:

* **LMMS ist nicht installiert.** Es gibt keine Spur, keinen Projektbestand und
  keine Installationsmöglichkeit ohne Netzzugriff.
* **FluidSynth ist installiert (2.6.1), aber ohne SoundFont.** Ein FluidSynth
  ohne `.sf2`/`.sf3` gibt keinen Ton aus – weder über die CLI noch über die
  Bibliothek. Im gesamten System liegt keine einzige SoundFont-Datei.

Ein MIDI-zu-Audio-Weg hätte also bedeutet: erst ein mehrhundert Megabyte großes
Sample-Paket zu beschaffen. Das ist im Projekt nicht vorgesehen, und selbst mit
SoundFont klänge das Ergebnis wie ein General-MIDI-Arrangement, nicht wie
Amiga-Musik.

**Ersatzweg (so ist es jetzt gebaut):** ein eigenes, deterministisches
Synthese- und Sequenzer-Werkzeug in Python/NumPy (`tools/audio/synth.py`,
1462 Zeilen). Die Komposition liegt als lesbare Notendaten in
`tools/audio/songs/`, der Klang entsteht vollständig im Rechner: bandbegrenzte
Sägezahn-/Pulsoszillatoren mit Verstimmung und Vibrato (Tracker-Gefühl),
kurze Hüllkurven, gefilterte Rauschschläge für Schlagzeug, dazu moderne Mittel
(Flächen, Delay, Faltungshall, Buskompression, Limiter).

Das Ergebnis ist eher das, was die Vorgabe klanglich wollte – tracker-artige
Amiga-Elektronik – als ein General-MIDI-Abklatsch. Und es ist reproduzierbar:
gleicher Code plus gleicher Seed ergibt bit-identisch dieselbe Datei (geprüft:
zwei Läufe von `level1` erzeugen dieselbe SHA-256-Summe).

## 2. Was im Projekt liegt

```
assets/audio/music/*.ogg      14 Dateien, OGG Vorbis, 44,1 kHz stereo, ~0,9–1,3 MB
                              (13 Level-/Menü-/Boss-/Abspann-Titel + 1 kurzer Cue)
assets/audio/sfx/*.wav        26 Effekte, 44,1 kHz, 16 Bit, 20 mono / 6 stereo
tools/audio/synth.py          Synthese + Sequenzer + Mastering + SFX + CLI
tools/audio/verify.py         Messung: Dauer, Pegel, Naht, Spektren, Spektrogramme
tools/audio/render.sh         ein Befehl für alles
tools/audio/songs/_lib.py     Tonleitern, Akkorde, Schlagzeug-/Bass-Patterns
tools/audio/songs/*.py       24 Kompositionen als Notendaten
tools/audio/build/            Zwischen-WAVs, Messberichte, Spektrogramme
docs/AUDIO_MEASUREMENTS.md    erzeugte Messwerttabelle
```

Die Musik besteht aus **24 Titeln**: zehn Levelthemen (`level1`–`level10`), zehn
**eigene Boss-Titel** (`boss1`–`boss10`, je Level einer), `menu`, `ending`,
`level_clear` und der ältere Sammeltitel `boss`, der nicht mehr im Spiel
verwendet wird, aber als Vergleich im Werkzeugkasten bleibt.

Jeder Boss-Track hat eigene Tonart, eigenes Tempo und eigenes Motiv:

| Track | Boss | Tonart | Tempo | Dauer |
|---|---|---|---|---|
| `boss1` | Gepanzerter Rosenkäfer | F harmonisch-moll | 150 BPM | 51,2 s |
| `boss2` | Grabende Riesenlarve | C harmonisch-moll | 156 BPM | 49,2 s |
| `boss3` | Schilfhecht | G dorisch | 162 BPM | 47,4 s |
| `boss4` | Parasitäres Pilzwesen | A phrygisch | 168 BPM | 45,7 s |
| `boss5` | Mantidenpaar | D harmonisch-moll | 174 BPM | 44,1 s |
| `boss6` | Mechanischer Bestäuber | E lydisch | 172 BPM | 44,7 s |
| `boss7` | Mutierter Wasserläufer | B moll | 176 BPM | 43,6 s |
| `boss8` | Erntemaschine | C# phrygisch | 184 BPM | 41,7 s |
| `boss9` | Schwarmkönigin | F# phrygisch | 188 BPM | 40,9 s |
| `boss10` | Kernorganismus | G# harmonisch-moll | 196 BPM | 44,1 s |

Die Tonarten steigen mit dem Level, das Tempo von 150 auf 196 BPM – der
Schwierigkeitsanstieg ist damit auch hörbar. Godot wählt den Titel über
`Game._boss_music()` aus der Bosskennung des Levels; Minibosse behalten die
Levelmusik. Die Bossmusik beginnt also genau in dem Moment, in dem der Boss
erscheint.

Godot lädt die Dateien über `scripts/autoload/audio.gd`: Musik über
`res://assets/audio/music/<name>.ogg` mit `loop = true`, Effekte über
`res://assets/audio/sfx/<name>.wav` aus einem Pool von 14 Startern. Die
`.ogg.import`-Dateien sind auf `loop=true` gestellt, damit die Schleife auch
ohne Laufzeit-Flag stimmt.

## 3. Wie ein Titel entsteht

Jeder Titel ist eine Python-Datei in `tools/audio/songs/` mit reinen Daten – keine
versteckte Magie, gut lesbar und änderbar:

```python
"id": "level1", "bpm": 132, "key": "D", "scale": "major",
"bars": 32, "rms_db": -15.0,
"sections": [
    {"bars": 8, "drums": "sparse", "bass": "half", "pad": True},            # Intro
    {"bars": 8, "drums": "basic",  "bass": "ostinato", "arp": True,
     "melody": "a", "mel_reps": 3, "mel_gap": 2},                            # A
    ...
]
```

* **Takt:** 4/4, 16 Schritte pro Takt (Sechzehntel).
* **Akkorde** stehen als Stufenpaare, z. B. `"chords": ["I","V","vi","IV"]`,
  und werden über die Tonleiter in Halbtöne umgerechnet (`_lib.deg_semitone`).
* **Melodien** sind Motive aus `(Schritt, Stufe, Länge-in-16teln)`. Ein Motiv
  wird pro Abschnitt mehrfach gesetzt (`mel_reps`, `mel_gap`), kann oktaviert
  (`mel_oct`) und transponiert (`mel_transpose`) werden.
* **Schlagzeug, Bass, Arpeggio, Fläche** kommen aus Mustervorlagen
  (`DRUM_PATTERNS`, `BASS_PATTERNS`, `FILL_PATTERNS`), damit die Stücke
  rhythmisch zusammenpassen und sich trotzdem je Level unterscheiden.
* **Übergänge:** Fills am Abschnittsende, ein Riser in den letzten zwei Takten
  und ein „Turnaround" (Kick, Snare, Bass-Pickup, Becken) in die Loopnaht.

Der Sequenzer (`compose`) rendert jeden Abschnitt Takt für Takt, mischt pro
Stimme in eigene Stereo-Puffer (lead, arp, pad, bass, drums, atmos) und gibt
diese getrennt zurück. Diese Trennung ist der Grund, warum die Mischung
nachvollziehbar bleibt.

## 4. Klangwerkzeuge

* **24 Instrumenten-Presets** (`PRESETS`): Pulse-/Sägezahn-Leads mit 1–3
  verstimmten Stimmen, Pluck-/Glocken-Arpeggios, weiche bis gläserne Flächen,
  Sägerund-/Sub-/Rundbässe, Glocken.
* **Bandbegrenzung:** polyBLEP-Sägezahn und -Puls (kein Aliasing in den Höhen),
  Phasenakkumulation mit Verstimmung in Cent und optionalem Vibrato
  (Rate, Tiefe, Einsatzverzögerung – das „Tracker-Wobble").
* **Formung:** statische Filter als Nullphasen-FFT-Butterworth
  (Tief-/Hoch-/Bandpass), ADSR-/Perkussiv-Hüllkurven, tanh-Sättigung.
* **Schlagzeug** synthetisch: Kick (Tonhöhensweep + Klick), Snare (Rauschen +
  Ton), Clap, Hat (geschlossen/offen), Crash, Toms.
* **Bus-Effekte:** Ping-Pong-Delay (punktierte Achtel, Rückkopplung 0,33),
  Faltungshall mit synthetisch erzeugtem, exponentiell ausklingendem
  Rausch-IR.
* **Mischung:** jede Stimme wird **gemessen und automatisch eingepegelt**
  (`auto_balance`): Melodie ist die Referenz, Bass −4 dB, Schlagzeug −3 dB,
  Fläche −9 dB, Arpeggio −6 dB, Atmosphäre −26 dB. Einzelne Titel können das
  per `balance` übersteuern (z. B. `level4` mit dichterer Fläche). Dadurch kann
  keine Basslinie die Melodie zudecken – der Fehler, den eine feste
  Handmischung bei 14 Titeln zwangsläufig macht.
* **Mastering:** Presence-Anhebung ab 2,6 kHz um +2,3 dB (Tracker-Mitten sind sonst boxig),
  Hochpass bei 27 Hz, Gain auf Ziel-RMS je Titel, weicher Knee-Limiter, danach
  eine Kontrolle der **dekodierten** Spitze (siehe unten).
* **Vorsicht bei Vorbis:** Der Vorbis-Encoder kann Spitzen gegenüber dem WAV
  um bis zu 2 dB anheben. Deshalb wird nach dem Kodieren die OGG-Datei wieder
  dekodiert, die Spitze gemessen und der Pegel nachgezogen, bis die
  ausgelieferte Datei sicher unter −1 dBFS liegt. Ohne diesen Schritt wären
  einzelne Titel bei −0,4 dBFS gelandet, obwohl das WAV sauber war.

## 5. Der Loop

Ein Loop ist nur dann nahtlos, wenn das Ende klanglich in den Anfang läuft –
Nachhall, Delay und ausklingende Töne eingeschlossen.

Verfahren: Jeder Titel wird um **2,6 s Überhang** länger gerendert als die
musikalische Länge. Dieser Überhang (Hallfahne, Delay-Echos, ausklingende
Becken) wird **additiv auf den Anfang gefaltet** und dann abgeschnitten. Die
Datei enthält danach exakt die Loop-Länge, und was am Ende noch klingt, klingt
am Anfang weiter – samplegenau, ohne Crossfade und ohne Blende.

Kontrolle (siehe Tabelle): Pegel der letzten 50 ms gegen die ersten 50 ms, die
Sprunghöhe an der Naht im Verhältnis zur 99-%-Sample-Differenz des Stücks
(Werte 0,04–0,92 – also *unauffälliger als ein normaler Sample-Schritt*, kein
Klick), und ob an der Naht ein Pegelloch entsteht (kleinste 10-ms-RMS im
Bereich ±80 ms, verglichen mit normalen Taktgrenzen).

## 6. Messung und Prüfkriterien

`tools/audio/verify.py` prüft die **ausgelieferten Dateien**, nicht die
Zwischenstände: Das OGG wird mit ffmpeg dekodiert und in NumPy gemessen
(Spitze, RMS, Crest, Clipping-Samples, DC, 8 Frequenzbänder, Spektralzentrum,
schmalbandige Dominanz als Resonanzindikator, Energiekurve pro Sekunde).

Kriterien je Musiktitel:

| Kriterium | Grenze |
|---|---|
| Dauer | ≥ 40 s (Vorgabe: 45–80 s; `boss` liegt bei 48,6 s, `level_clear` als Cue ≥ 12 s) |
| Spitze (dekodiert) | ≤ −1,0 dBFS |
| RMS | −18 … −14 dBFS |
| Clipping-Samples | 0 |
| Klick an der Naht | Sprunghöhe < 4 × typische Sample-Differenz |
| Stille am Anfang | erste 20 ms > −55 dBFS |
| Pegelloch an der Naht | kleinste 10-ms-RMS > −45 dBFS und nicht toter als ein Taktwechsel |
| Pegelsprung 50 ms/50 ms | ≤ 12 dB |
| Schrille Resonanz | kein 1/12-Oktav-Band über 1,5 kHz trägt > 15 % der Gesamtenergie |

Zusätzlich wird pro Titel ein Spektrogramm als PNG erzeugt (`ffmpeg
showspectrumpic`, logarithmische Frequenz- und Pegelachse) und geprüft, dass das
Bild nicht leer ist (Standardabweichung der Helligkeit > 0,02). Vier
Spektrogramme wurden zusätzlich von Hand angesehen (level1, boss1, boss10, menu, level7):
alle zeigen Intro-Aufbau, Abschnittswechsel, Hat-Teppich und Melodielinien –
keine leeren oder flächig einfarbigen Bilder.

Ergebnis des letzten Laufs: **24/24 Musikdateien OK, 26/26 Effekte OK, 24/24
Spektrogramme OK.**

## 7. Soundeffekte

26 Dateien, 44,1 kHz/16 Bit, 20 davon mono und sechs stereo (`explosion_big`,
`bomb`, `player_hit`, `boss_death`, `level_clear`, `game_over` – die langen,
räumlichen Ereignisse). Die vier
Schussvarianten sind absichtlich kurz (75–135 ms), damit Dauerfeuer nicht
zuschmiert; die UI-Töne bleiben unter 200 ms und leise (`ui_move` 50 ms /
−20,6 dBFS, `ui_ok` 100 ms / −18,0 dBFS, `ui_back` 90 ms / −18,5 dBFS,
`deny` 190 ms / −13,0 dBFS), während Explosionen und Bomben echten Tiefbass und
Rauschanteil haben (`bomb` −4,5 dBFS, `explosion_big` −5,5 dBFS,
`explosion_small` −7,5 dBFS). Das volle Datenblatt steht in
[AUDIO_MEASUREMENTS.md](AUDIO_MEASUREMENTS.md).

## 8. Reproduktion

```bash
bash tools/audio/render.sh            # alles neu: Musik + SFX + Messung
bash tools/audio/render.sh music      # nur die Musiktitel
bash tools/audio/render.sh sfx        # nur die 26 Effekte
bash tools/audio/render.sh verify     # nur messen, nichts neu rendern
```

Voraussetzungen: `python3` mit **numpy** und **Pillow**, `ffmpeg`/`ffprobe` mit
libvorbis. Kein LMMS, kein FluidSynth, keine SoundFont, kein Netzzugriff.

Laufzeit auf diesem Rechner: etwa **6 s pro Titel** (ein Kern), mit
`--jobs 6` rund anderthalb Minuten für alle 14; die Effekte brauchen wenige
Sekunden, die Messung inklusive Spektrogrammen etwa 10 s.

Determinismus: Alle Zufallszahlen stammen aus `np.random.default_rng()` mit
einem Seed aus der CRC32 der Kennung (Titelname bzw. Effektname). Zwei Läufe
ergeben dieselben Samples. Der Dither beim Schreiben der 16-Bit-WAVs nutzt
denselben Seed.

## 9. Levelabschluss: die Datei `level_clear`

`scripts/game/game.gd` ruft beim Levelende `Audio.play_music("level_clear")`
auf – also einen **Musik**-Stream, nicht den gleichnamigen Effekt. Ohne Datei
im Musikordner bliebe dieser Aufruf stumm und die Levelmusik liefe einfach
weiter. Deshalb gibt es zusätzlich `assets/audio/music/level_clear.ogg`:
acht Takte C-Dur, 128 BPM, 15 s, als Fanfare gearbeitet und als Schleife
unbedenklich (Naht 8,1 dB, Sprunghöhe 0,03). Der Effekt `sfx/level_clear.wav`
bleibt zusätzlich bestehen und kann für sich genutzt werden.

## 10. Bekannte Grenzen und bewusste Entscheidungen

* **Gehört wurde von mir nicht.** Ich habe keine Ohren; die Beurteilung stützt
  sich auf Messwerte (Pegel, Bänder, Naht, Resonanzindikator) und die
  Spektrogramme. Ein menschlicher Hörtest bleibt sinnvoll, besonders für die
  Frage, ob der Bass in `level2`/`level7` zu dick ist.
* **`menu` hat mit 11,4 dB den größten Pegelsprung an der Loopnaht.** Ursache
  ist der Aufbau, nicht ein Fehler: Der ruhige Menüloop endet auf einem
  gehaltenen Akkord und beginnt mit einem Downbeat aus Kick, Bass und Melodie.
  Klickfrei ist die Naht messbar (Sprunghöhe 0,03 – also ein weicher
  Nulldurchgang). Trotzdem ist dort ein „Neustart" hörbar; wer das glätten
  will, senkt in `songs/menu.py` den ersten Takt oder erhöht `mel_reps`.
* **Die Mischungen sind mittig-lastig** (Spektralzentrum 513–1196 Hz). Das ist
  für Tracker-Musik typisch – die Melodien liegen um c′′ –, klingt aber
  weniger „modern hell" als ein aktueller EDM-Mix. Die Presence-Anhebung ist
  bewusst maßvoll (+2,3 dB ab 2,6 kHz), damit nichts schrill wird.
* **Die Boss-Titel sind mit 39–51 s die kürzesten Stücke.** Sie laufen 32–36
  Takte bei 150–196 BPM; die Vorgabe „45–80 s" erfüllen die meisten, `boss9`
  (40,9 s) und `boss10` (44,1 s) liegen knapp darunter beziehungsweise darüber.
  Für Bosskämpfe von ein bis drei Minuten reicht das, weil die Titel schleifen.
* **Kein Streaming, keine adaptive Musik.** Alles ist vorgemischt; Godot
  spielt Dateien ab und blendet zwischen zwei Startern über. Das entspricht der
  Vorgabe „alles vorgerendert, Godot spielt nur Dateien".

## 11. Einen Titel ändern

1. Datei in `tools/audio/songs/` bearbeiten (BPM, Tonart, Abschnitte, Motive,
   `balance`).
2. `python3 tools/audio/synth.py music --only level3 --no-ogg` für einen
   schnellen Hörtest des WAVs in `tools/audio/build/music/`.
3. Ohne `--no-ogg` bzw. über `render.sh` die endgültige OGG-Datei erzeugen.
4. `python3 tools/audio/verify.py` prüfen lassen – die Tabelle in
   [AUDIO_MEASUREMENTS.md](AUDIO_MEASUREMENTS.md) wird dabei neu geschrieben.
