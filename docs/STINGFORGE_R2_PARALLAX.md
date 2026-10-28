# Stingforge R2: verankerter Parallax-Vordergrund

## Auftrag und unveränderte Bereiche

Änderungen ausschließlich an [Background](../scripts/game/background.gd), Hintergrund-PNGs, dem neuen [Vorbereitungstool](../tools/prepare_stingforge_parallax.py) und neuen Parallax-Tests. Kein Blender, kein Bildmodell, kein Grafikcache-Reset und kein eigener Importshuttle. Der Hauptagent führt einen gemeinsamen Import der 36 unten benannten PNGs aus. Die neue gemeinsame Spielgrenze kommt von `App.PLAY_TOP = 56` / `App.PLAY_BOTTOM = 476`; diese Konstanten werden hier nicht separat gepflegt oder geändert.

Die [Round2-Baseline](../build/stingforge-round2-baseline/) wird ausschließlich gelesen. Alle 1.095 im bestehenden SHA256-Manifest erfassten Baseline-Dateien sind abschließend unverändert geprüft, einschließlich der 30 Original-Landschaften. 24 aktuelle Landschafts-PNGs bleiben bytegleich zur Baseline; nur sechs `near`-Dateien erhalten gezielte Ergänzungen hinter den vorhandenen Pixeln. Kein vorhandener opaker Pixel wurde gelöscht oder farblich übermalt.

## Diagnose: rot vor grün

Vor Änderungen wurden die tatsächlichen Alpha-Silhouetten und die vorhandenen [Weltaufnahme](../build/stingforge-visual/default_world_without_hud.png) / [HUD-Aufnahme](../build/stingforge-visual/default_hud.png) mit `read_image` angesehen. Das bloße Ändern eines Screenshots ist ausdrücklich kein Bestehenskriterium.

Roter Befehl, **vor** dem Assetfix tatsächlich ausgeführt:

```sh
python3 tests/stingforge_r2_parallax_assets.py --originals-only \
  --output build/stingforge-r2-parallax/alpha-before.json
```

Ergebnis: Exit 1, acht Fehler; abgetrennte untere Alpha-Inseln in L01 (5), L03 (6), L04 (1), L05 (3), L07 (12), L08 (2). Sichtbare Bodenzeile `y=475` in L07 nur 21,0 %, L08 58,6 %. Die Analyse ist horizontal periodisch, damit ein über die Kachelnaht angeschlossenes Objekt nicht fälschlich als schwebend gilt. Sie ignoriert absichtlich an `y=0` angeschlossene Decken-/Canopy-Formen und kleine Ditherinseln unter 24 Pixeln.

Der anschließend ebenfalls rot ausgeführte echte Godot-Probe-Lauf zeigte fehlende Bodenpixel über mehrere Scrollpositionen. Zusätzlich war der allgemeine Vordergrund 512 px breit, aber nur zweimal kopiert: bei Offsets über 64 px reichten die tatsächlich vorhandenen Kopien nicht bis zum rechten 960-px-Feldrand. Das ist ein eigenständiger Scrollnahtfehler, kein Farbproblem. [Rotes Runtime-Protokoll](../build/stingforge-r2-parallax/runtime-red.log).

## Reparatur und Mapping

- Untere abgetrennte Silhouetten bekommen schmale Fortsetzungen ihrer vorhandenen Stiel-/Stammenden bis in den Boden. Vorhandene Farben und Motivpixel liegen unverändert darüber.
- L07/L08 erhalten zusätzlich einen schmalen zusammenhängenden Materialsaum ab etwa `y=468`, weil ihre bisherige Bodenbasis unter der sichtbaren HUD-Grenze lag.
- `near`, `reeds`, `roots` verwenden dieselbe entworfene Bodenreferenz 476; die Bildposition wird daraus relativ zu `App.PLAY_BOTTOM` bestimmt.
- Der bestehende allgemeine Vordergrund bleibt als PNG unverändert. Seine Bildunterkante liegt jetzt an `PLAY_BOTTOM` (bei 540 px Bildhöhe also `y=-64`). Die dekorativen oberen Rechtecke dieses Bilds liegen dadurch außerhalb des sichtbaren Felds, und die unteren Halme sind sichtbar mit dem Rand verbunden.
- Die Zahl der Bildkopien ist `ceil(960 / Bildbreite) + 1`: für 960-px-Bilder zwei, für den 512-px-Vordergrund drei. Die Positionen bleiben an Scrollnähten lückenlos.
- Eine fehlende Ferne bekommt einen palettenbasierten Himmel. Fehlende zusätzliche Ebenen bleiben im Flugkorridor transparent; Boden-Fallbacks besitzen nur einen unteren Saum. Kein fehlendes Blattbild erzeugt mehr eine deckende Vollbildfläche.
- Wiederholtes `setup` entfernt alte Ebenen und Partikel; bei Partikelstufe null wird kein ungültiger Null-Partikel-Emitter angelegt.

### Reparaturumfang, statisch gemessen

| PNG | Geänderte Pixel | Anteil der Bildfläche | ergänzte Verbindungen |
|---|---:|---:|---:|
| [l01_near](../assets/bg/l01_near.png) | 1272 | 0,2454 % | 5 |
| [l03_near](../assets/bg/l03_near.png) | 1239 | 0,2390 % | 6 |
| [l04_near](../assets/bg/l04_near.png) | 26 | 0,0050 % | 1 |
| [l05_near](../assets/bg/l05_near.png) | 445 | 0,0858 % | 3 |
| [l07_near](../assets/bg/l07_near.png) | 13868 | 2,6752 % | 12 |
| [l08_near](../assets/bg/l08_near.png) | 9094 | 1,7542 % | 2 |

[Maschinenlesbare Messwerte](../build/stingforge-r2-parallax/static-metrics.json). Alle 36 Tool-Ausgaben wurden erneut im Speicher berechnet und bytegleich mit den gespeicherten PNGs verglichen. Die Baseline wurde dabei nicht geschrieben.

## Drei eigenständige zusätzliche Tiefenebenen

| Rolle | Tempo px/s bei Basisfaktor 1 | z lokal | Inhalt |
|---|---:|---:|---|
| far, bestehend | 26 | -70 | Original-Ferne |
| **haze, neu** | **44** | **-66** | Niedrig deckende, breite periodische Dunstbänder |
| clouds, bestehend | 62 | -62 | Bestehende Atmosphäre |
| mid, bestehend | 120 | -55 | Original-Landschaft |
| **reeds, neu** | **174** | **-50** | Eigene, thematisch passende Bodenmotive |
| near, gezielt repariert | 235 | -45 | Original-Vordergrund |
| **roots, neu** | **302** | **-41** | Kleinerer, dichterer Wurzel-/Sockelsaum mit anderer Geometrie |
| front, bestehend umverankert | 380 | -38 | Schnelle dunkle Randhalme |

Alle Ebenen bleiben hinter der Spielebene (`z < 0`). Das bestehende Geschosssystem wird nicht geändert. Die drei neuen Bilder pro Level unterscheiden sich tatsächlich in Geometrie und Transparenz, nicht nur in der Geschwindigkeit. Paletten stammen aus den vorhandenen levelbezogenen Farbrampen. Die Motive folgen dem Level: Blätter, Wurzelbögen, Schilf, Pilzkappen, Dornen, Pflanzgefäße, Abflussrohre, Maschinenträger, Wabensockel und Kristalle. Kein identisches Bild wird als zusätzliche Ebene wiederverwendet.

### Exakte Importliste

Neu: je `l01` bis `l10` genau die drei Suffixe `haze`, `reeds`, `roots` unter `assets/bg/` (30 PNGs).

Geändert: die oben verlinkten sechs `near`-PNGs. Der allgemeine Vordergrund und alle übrigen bestehenden PNGs sind unverändert. Diese Liste wurde dem Hauptagenten vor dem koordinierten Import übermittelt; es läuft kein eigener paralleler Import.

## Tests und Reproduktion

[PNG-Vertrag](../tests/stingforge_r2_parallax_assets.py): zehn Original-Vordergründe plus 20 neue bodentragende Ebenen, vollständige Bodenzeile, keine relevanten unteren schwebenden Alpha-Inseln, alle 30 neuen RGBA-Kachelränder exakt gleich, keine Bildduplikate und kein deckender neuer Flugkorridor.

[Godot-Probe](../tests/stingforge_r2_parallax_probe.gd) / [Probe-Szene](../tests/stingforge_r2_parallax_probe.tscn): echter `Background.setup/update`-Pfad für alle zehn Level, acht Geschwindigkeiten, negative z-Werte, importierte Texturen gegen PNG-Quelldaten, 32 systematische Scrollpositionen je Level einschließlich kurz vor/genau auf/kurz nach der Naht jeder Ebene. Geprüft werden reale Spriteabdeckung und Bodenalpha bei `PLAY_BOTTOM-1`, nicht bloß Modulo-Projektion in ein virtuell unendlich oft wiederholtes Bild. Zusätzlich 2 s einmal versus 240 Schritte à 1/120 s, Fallbacks und doppeltes Setup.

[Propertytests](../tests/stingforge_r2_parallax_properties.py): 250 zusätzliche Alpha-/Scrollfälle und 100 echte Godot-Delta-Partitionierungen. Falls Hypothesis installiert ist, wird es benutzt. In dieser Umgebung ist Hypothesis **nicht installiert**; ohne Installation wird ein ausdrücklich so benannter deterministischer Seed-Modus verwendet. Das ist kein behaupteter Hypothesis-Lauf. Die Native-Probe prüft unabhängig davon alle zehn Level und systematische Nahtpositionen.

Die isolierten XDG-Verzeichnisse liegen ausschließlich unter `build/stingforge-r2-testdata-parallax/{data,config,cache}`; Audio wird als Dummy gestartet. Kein Nutzer-Spielstand wird benutzt.

```sh
python3 tests/stingforge_r2_parallax_assets.py \
  --output build/stingforge-r2-parallax/alpha-after.json

export XDG_DATA_HOME="$PWD/build/stingforge-r2-testdata-parallax/data"
export XDG_CONFIG_HOME="$PWD/build/stingforge-r2-testdata-parallax/config"
export XDG_CACHE_HOME="$PWD/build/stingforge-r2-testdata-parallax/cache"
godot --headless --path "$PWD" --audio-driver Dummy \
  --scene res://tests/stingforge_r2_parallax_probe.tscn
python3 tests/stingforge_r2_parallax_properties.py

# Erst nach gemeinsamem Import und exklusiver Fensterfreigabe:
WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 \
GSETTINGS_BACKEND=memory LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
godot --path "$PWD" --display-driver wayland --audio-driver Dummy \
  --scene res://tests/stingforge_r2_parallax_probe.tscn
```

Nach dem vom Hauptagenten koordinierten Import bestanden: **10.097 native Headless-Prüfungen**, 1.284 Bodenzeilen-Stichproben (keine fehlenden Pixel), plus **4.838 Runtime-Prüfungen** aus 100 deterministischen Delta-Schedules und 250 zusätzlichen Alpha-Fällen. Beide Läufe endeten ohne Scriptfehler oder Ressourcenwarnungen. [Headless-Protokoll](../build/stingforge-r2-parallax/runtime-headless.log), [Headless-Messdaten](../build/stingforge-r2-parallax/runtime-headless.json), [Property-Protokoll](../build/stingforge-r2-parallax/properties.log), [Property-Messdaten](../build/stingforge-r2-parallax/runtime-properties.json). Die Testszene gibt ihre nicht benötigten Dummy-Audio-Menüdecoder vor dem Beenden frei; Produktionsaudio bleibt unverändert.

Erfolgs-Endmarker: `STINGFORGE_R2_PARALLAX_OK`. Das Vorbereitungstool ist absichtlich getrennt vom Import: `python3 tools/prepare_stingforge_parallax.py` zeichnet nur die drei neuen Ebenen und die sechs Reparaturen aus der unveränderten Baseline nach; es startet Godot nicht.

## Rendering und ehrliche Grenzen

Abschließend wurden **30 echte 960×540-Godot-Renderings** (zehn Level × drei Scrollzeiten) und **eine integrierte 1600×900-HUD-Aufnahme** im abgestimmten Wayland-/llvmpipe-Fensterslot gespeichert. Alle zehn Level wurden auch per `read_image` gesichtet. Der Fensterlauf bestand **10.128 Prüfungen**, darunter 1.284 vollständige Bodenzeilen und ein echter `BulletField`-Sichtbarkeitstest: Eine Kugel bei Weltposition `(480,464)` muss mindestens zwölf Pixel vor dem bodennahen Vordergrund sichtbar ändern. [Fenstermessdaten](../build/stingforge-r2-parallax/runtime-window.json), [Fensterprotokoll](../build/stingforge-r2-parallax/runtime-window.log).

**Ehrlicher Restbefund:** Nach dem erfolgreichen Endmarker und Exit 0 meldet dieser integrierte Fensterlauf noch vier ObjectDB-/zwei Ressourcen-Instanzen beim Beenden. Die reinen Headless-/Propertyläufe sind sauber. Die vorherige reduzierte Diagnose identifizierte Ogg-Menümusikdecoder; die erneute Warnung nach dem integrierten echten Spiel ist nicht separat mit `--verbose` identifiziert worden und wird deshalb nicht als bewiesener Parallaxfehler oder als behoben bezeichnet. Keine fremde Audiodatei wurde geändert, kein zweiter unkoordinierter Fensterlauf gestartet.

Die Rohbilder zeigen denselben echten Background-Pfad zu drei Scrollzeiten pro Level, nicht nachträglich montierte Motive. Sie enthalten die vollständige Welttextur einschließlich Bereichen, die das tatsächliche HUD verdeckt; maßgeblich sichtbar ist `y=56..475`.

### Tatsächliche integrierte Aufnahme

![Reparierter Bodenanschluss mit echtem HUD und sichtbarer Kugel unmittelbar vor dem Boden](../build/stingforge-r2-parallax/integrated_l01.png)

Weitere direkte Belege: [Blütenmeer bei Scrollzeit 13,1](../build/stingforge-r2-parallax/l01_t013.100.png), [Kanalisation bei Scrollzeit 2,526](../build/stingforge-r2-parallax/l07_t002.526.png), [Maschinenherz](../build/stingforge-r2-parallax/l08_t002.526.png). Die Kugel in der integrierten Aufnahme ist die tatsächliche Renderer-Ausgabe und keine nachträgliche Markierung.

Die bestehenden Landschaften sind geditherte Blender-Rastergrafiken; gegenüberliegende Farbrandpixel sind deshalb bereits in der Baseline nicht überall identisch. Dieser Auftrag glättet diese 30 alten Bilder nicht global. Exakte RGBA-Randgleichheit wird für sämtliche neuen Bilder erzwungen; für die alten Ebenen werden reale Spriteabdeckung und durchgehender Boden um die Scrollnaht geprüft. Die Alpha-Komponentenprüfung ist ein physischer Anschlussnachweis, aber keine Behauptung botanischer Perfektion oder einer vollständigen ästhetischen Bewertung jeder Ditherinsel.

Die ältere HUD-Aufnahme verwendet andere HUD-Grenzen und ist deshalb kein pixelregistriertes Vorher/Nachher-Differenzbild. Statische Anschlusswerte und tatsächliches Rendering werden getrennt ausgewiesen.
