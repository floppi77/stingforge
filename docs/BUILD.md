# Stingforge – Build-Anleitung

**Evolve. Adapt. Strike.** Aktuelle Änderungen stehen in
[STINGFORGE_R4.md](<STINGFORGE_R4.md>). Das Spiel verwendet fertige Rastergrafiken und
benötigt keinen Blender-Aufruf; der Blender-Importer ist in der Projektkonfiguration
deaktiviert.

Veröffentlichte Releases baut die CI (siehe Abschnitt 6). Diese Anleitung beschreibt
den lokalen Build, etwa zum Testen eigener Änderungen.

Diese Anleitung beschreibt, wie aus den Quellen im Projektordner die ausgelieferten
Dateien für Linux, Windows und macOS entstehen. Alles läuft auf Linux; für Windows und
macOS werden Godots Exportvorlagen verwendet (kein Kreuzcompiler, kein Mac nötig).

---

## 1. Werkzeuge und Versionen

| Werkzeug | Version im Projekt | Verwendung |
|---|---|---|
| Godot | 4.7.2 stable | Engine, Export (Renderer: GL Compatibility) |
| Godot-Exportvorlagen | 4.7.2 stable | `linux_release.x86_64`, `windows_release_x86_64.exe`, `macos.zip` |
| Blender | nur optionale historische Quellen | für den Build nicht erforderlich |
| Aseprite | 1.3.18.6-dev | Sprites (`.aseprite`-Quellen, Lua-Generator) |
| Python | 3.14 + numpy, Pillow | Audio-Synthese, Prüfskripte |
| ffmpeg / ffprobe | 7.x mit libvorbis | OGG-Kodierung und -Messung |
| Wine | 11.x | optionaler Test der Windows-Datei unter Linux |

Die Exportvorlagen müssen für Godot sichtbar sein. Im Projekt wird ein eigener
Datenordner benutzt, damit nichts außerhalb des Projektordners geschrieben wird:

```bash
export XDG_DATA_HOME="$PWD/.godot_data"
export XDG_CONFIG_HOME="$PWD/.godot_config"
export XDG_CACHE_HOME="$PWD/.godot_cache"
# Erwartet: .godot_data/godot/export_templates/4.7.2.stable/
```

Fehlen die Vorlagen, lädt man sie einmalig über den Godot-Editor
(*Editor → Vorlagen verwalten*) oder entpackt
`Godot_v4.7.2-stable_export_templates.tpz` nach
`.godot_data/godot/export_templates/4.7.2.stable/`.

---

## 1a. Wichtig: neue Bilder einlesen (Arbeitsumgebung ohne Editor)

Godot importiert neu hinzugelegte Bilder hier nur über einen Umweg. `godot --import`
und `--headless --editor` laufen durch, legen aber **keine** Importdateien an
(Zählwerk der Dateisystem-Aktualisierung); ein Fensterstart mit `--editor` scheitert
an der Wayland-Einbettung. Deshalb gibt es ein kleines Hilfsskript:

```bash
./tools/import_shuttle.sh assets/sprites/neu.png [weitere.png ...]
```

Es legt ein Wegwerfprojekt unter `tests/_shuttle` an, lässt dort dieselben
`res://`-Pfade importieren und kopiert die erzeugte `.import`-Datei sowie die
Importdateien (`.ctex`, `.fontdata`, `.md5`, …) nach `.godot/imported/` zurück.
Danach findet das Spiel die neuen Bilder ohne Editorstart. **Den Ordner `.godot`
nicht löschen** – er enthält alle importierten Ressourcen; ein Neuanlegen
erzeugt hier einen leeren Import-Ordner. (In der CI genügt `godot --headless --import`,
weil dort alle `.import`-Dateien schon im Repository liegen.)

## 2. Projekt importieren

Godot muss die Assets einmal importieren (Import-Cache `.godot/`):

```bash
cd /pfad/zu/stingforge
XDG_DATA_HOME="$PWD/.godot_data" godot --headless --path . --import
```

**Wichtig:** Die Ordner `assets/blender/` und `assets/aseprite/` enthalten
`.blend`- bzw. `.aseprite`-Quellen und liegen absichtlich hinter einer
`.gdignore`-Datei. Ohne diese Ausnahme bricht Godots Importer den gesamten
Importvorgang ab, sobald er ein `.blend` ohne konfigurierten Blender-Pfad findet
(Symptom: `.godot/imported/` bleibt leer, Schriften und Bilder fehlen zur Laufzeit).

---

## 3. Export

Die Presets stehen in `export_presets.cfg`: Linux und Windows mit
`binary_format/embed_pck = true` und Architektur x86_64, macOS als App-Bündel
(Universal: Intel und Apple Silicon). Alle Presets nehmen alle Ressourcen außer den
Quellordnern.

```bash
mkdir -p build/linux build/windows build/macos

# Linux
XDG_DATA_HOME="$PWD/.godot_data" godot --headless --path . \
  --export-release "Linux" build/linux/Stingforge.x86_64

# Windows
XDG_DATA_HOME="$PWD/.godot_data" godot --headless --path . \
  --export-release "Windows" build/windows/Stingforge.exe

# macOS
XDG_DATA_HOME="$PWD/.godot_data" godot --headless --path . \
  --export-release "macOS" build/macos/Stingforge-macOS.zip
```

**macOS:**
- Der Export ergibt ein ZIP mit `Stingforge.app`, das PCK liegt in `Contents/Resources`.
- Für Apple Silicon verlangt Godot die Projekteinstellung *ETC2/ASTC importieren*
  (`rendering/textures/vram_compression/import_etc2_astc`). Sie ist aktiv. Alle Texturen
  sind verlustfrei importiert, das Bild ändert sich dadurch nicht.
- Signatur: Godots eingebaute Ad-hoc-Signatur. Für eine Notarisierung bräuchte es eine
  Apple-Developer-ID. Ohne sie muss man die App beim ersten Start per Rechtsklick ›
  „Öffnen“ freigeben.
- Bundle-ID: `io.github.floppi77.stingforge`.

**Wichtig für den Export:** Alles, was im Projektordner liegt und nicht
ausgeschlossen ist, landet im PCK. Die Ausschlussliste in `export_presets.cfg`
enthält deshalb neben Werkzeugen und Tests auch `.godot_data/*` (Testdaten,
Exportvorlagen) und `Astra/*` (ein fremder Projektordner). Fehlt ein Eintrag,
wächst die fertige Datei schnell um mehrere hundert Megabyte.

Ergebnis für Linux und Windows: je eine Datei mit eingebettetem PCK – keine weiteren
Dateien nötig. Für macOS ein ZIP mit dem App-Bündel.

Größen und Prüfsummen ändern sich mit jedem Build. Für veröffentlichte Versionen stehen
sie in `SHA256SUMS.txt` des jeweiligen Releases (dort auch der signierte Herkunftsnachweis,
siehe [SECURITY.md](<../SECURITY.md>)). Für einen lokalen Build:

```bash
sha256sum build/linux/Stingforge.x86_64 build/windows/Stingforge.exe build/macos/Stingforge-macOS.zip
```

---

## 4. Assets reproduzieren (optional)

Alle Assets sind bereits im Projekt. Wer sie neu erzeugen will:

**Sprites** (Manifest, Kontaktbogen):

```bash
aseprite -b --script tools/aseprite/gen_sprites.lua      # alle Sprites + manifest.json
APIDYA_ONLY="bee,boss_core" aseprite -b --script tools/aseprite/gen_sprites.lua
# Der historische Generator liefert die frühere Biene; danach Stingforge erneuern:
python3 tools/prepare_stingforge_bee.py
python3 tools/prepare_stingforge_branding.py docs/stingforge/logo_source.png
python3 tools/make_contact.py && python3 tools/check_sprites.py
```

**Hintergründe** (historische Blender-Quellen; heute ersetzt durch die Pixel-Ebenen in `assets/bg/`):

```bash
# .blend-Quellen liegen in assets/blender/, Ergebnis in assets/bg/
blender -b assets/blender/l01.blend -P tools/blender/render_layers.py
```

**Neue Ebenen und Beleuchtung der fünften Runde:**

```bash
python3 tools/make_parallax.py    # assets/bg/bg_clouds.png, assets/bg/bg_front.png (nahtlos)
python3 tools/make_light.py       # assets/fx/vignette.png, light_top.png, glow.png
python3 tools/make_bullet_maps.py # Pixelkarten der Geschosse (JSON, Vorstufe für Aseprite)
```

Die vier Geschosse selbst sind in Aseprite gezeichnet; die Bearbeitungsstände
liegen als `assets/aseprite/bullets/*.aseprite` im Projekt (zwei Bilder je
Geschoss). Export als Streifen: die beiden Bilder eines Sprites nebeneinander
in eine PNG der doppelten Breite setzen (`bullet_base.png` = 24 × 8 aus
2 × 12 × 8) und den Eintrag im Manifest unverändert lassen.

**Musik:** Der Soundtrack entsteht über die Pipeline in `tools/music/`, beschrieben in
[SOUNDTRACK_KONZEPT.md](<SOUNDTRACK_KONZEPT.md>). Die frühere Synthese für Effekte liegt
weiterhin unter `tools/audio/`:

```bash
bash tools/audio/render.sh          # alles
bash tools/audio/render.sh verify   # Messbericht neu schreiben
```

---

## 5. Tests

Vollständiger Satz (45 Prüfsuiten, jede mit eigenem Test-Spielstand). Derselbe Lauf
läuft in der CI bei jedem Push auf `main` ([regression.yml](<../.github/workflows/regression.yml>)):

```bash
python3 tools/verify_stingforge_r3.py                  # alle Suiten
python3 tools/verify_stingforge_r3.py --only r10_probe # einzelne Suiten
python3 tools/verify_stingforge_r3_exports.py          # Export aller drei Plattformen + Startprobe
python3 tools/package_stingforge_r3_release.py         # lokale Auslieferung nach release/
```

Einzeltests lassen sich auch direkt starten:

```bash
export XDG_DATA_HOME="$PWD/.godot_data"

# Funktionstest (Run, Kampf, Boss, Evolution, Pause, Einstellungen, Boss-Rush)
godot --headless --path . res://tests/smoke.tscn

# Inhaltsprüfung (Daten, Assets, Ton, Übersetzungen, Formationen)
godot --headless --path . res://tests/content.tscn

# Screenshots erzeugen (braucht eine Anzeige)
godot --path . res://tests/shots.tscn
```

Beide Prüfskripte geben bei Erfolg `SMOKE_OK` bzw. `CONTENT_OK` aus und enden mit
Rückgabewert 0.

---

## 6. Release veröffentlichen

Releases entstehen in der CI ([release.yml](<../.github/workflows/release.yml>)):

1. Versionsnummer in `export_presets.cfg` anheben (`application/version` und
   `application/short_version`) und committen. Die CI bricht ab, wenn Tag und Version
   nicht übereinstimmen.
2. Tag setzen und pushen: `git tag vX.Y.Z && git push origin vX.Y.Z`.
3. Die CI baut alle drei Plattformen, prüft sie, erzeugt `SHA256SUMS.txt` und den
   Herkunftsnachweis und legt einen **Entwurf** an. Den Entwurf prüfen, dann veröffentlichen.
4. Veröffentlichte Releases sind unveränderlich. Korrekturen bekommen eine neue Version;
   ein erneuter Lauf für ein veröffentlichtes Tag bricht mit einer klaren Meldung ab.

## 7. Veröffentlichung ohne Editor prüfen

```bash
mkdir -p /tmp/testlauf && cp build/linux/Stingforge.x86_64 /tmp/testlauf/
cd /tmp/testlauf && ./Stingforge.x86_64 --headless --quit-after 120
```

Läuft das Programm ohne Fehlermeldung durch, sind PCK und Projektstand gültig.
Ein echtes Fenster braucht eine Grafikausgabe (X11/Wayland); ohne Anzeige lässt
sich das Spiel nur mit `--headless` starten.
