# Stingforge – Build-Anleitung

**Evolve. Adapt. Strike.** Aktuelle Änderungen und Prüfläufe:
[R2-Bericht](<STINGFORGE_R2.md>) und [R2-Prüfprotokoll](<TESTPROTOKOLL_R2.md>).
Die Größen und Prüfsummen unten gehören zum abgenommenen R2-Build.
R2 verwendet fertige Rastergrafiken und benötigt keinen Blender-Aufruf; der
unbenötigte Blender-Importer ist in der Projektkonfiguration deaktiviert.

Diese Anleitung beschreibt, wie aus den Quellen im Projektordner die ausgelieferten
Dateien für Linux, Windows und macOS entstehen. Alles läuft auf Linux; für Windows und
macOS werden Godots Exportvorlagen verwendet (kein Kreuzcompiler, kein Mac nötig).

---

## 1. Werkzeuge und Versionen

| Werkzeug | Version im Projekt | Verwendung |
|---|---|---|
| Godot | 4.7.2 stable | Engine, Export (Renderer: GL Compatibility) |
| Godot-Exportvorlagen | 4.7.2 stable | `linux_release.x86_64`, `windows_release_x86_64.exe`, `macos.zip` |
| Blender | nur optionale historische Quellen | Für R2 nicht verwendet und nicht erforderlich |
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
nicht löschen** – er enthält alle 542 importierten Ressourcen; ein Neuanlegen
erzeugt hier einen leeren Import-Ordner.

## 2. Projekt importieren

Godot muss die Assets einmal importieren (Import-Cache `.godot/`):

```bash
cd /pfad/zu/Apidya
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

| Datei | Größe | SHA-256 |
|---|---|---|
| [Linux](<../build/linux/Stingforge.x86_64>) | 99.0 MiB | `57dae4c5b963e73a3de9a5948b21c96593dad844a0fb721e50cd6c09a0e3c117` |
| [Windows](<../build/windows/Stingforge.exe>) | 133.1 MiB | `ab3954a233c379d0e38858d7dfa4dca98ad7f660c473f2da03c444db6bbabeaf` |

Die Werte stammen vom aktuellen Stingforge-Zusatz-Build. Beide Dateien enthalten den
PCK eingebettet und laufen ohne weitere Dateien.

Prüfsummen nach dem Build erzeugen:

```bash
sha256sum build/linux/Stingforge.x86_64 build/windows/Stingforge.exe
```

---

## 4. Assets reproduzieren (optional)

Alle Assets sind bereits im Projekt. Wer sie neu erzeugen will:

**Sprites** (68 Sprites, Manifest, Kontaktbogen):

```bash
aseprite -b --script tools/aseprite/gen_sprites.lua      # alle Sprites + manifest.json
APIDYA_ONLY="bee,boss_core" aseprite -b --script tools/aseprite/gen_sprites.lua
# Der historische Generator liefert die frühere Biene; danach Stingforge erneuern:
python3 tools/prepare_stingforge_bee.py
python3 tools/prepare_stingforge_branding.py docs/stingforge/logo_source.png
python3 tools/make_contact.py && python3 tools/check_sprites.py
```

**Hintergründe** (30 Ebenen, 3 pro Level):

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

**Musik und Effekte** (14 OGG, 26 WAV, deterministisch):

```bash
bash tools/audio/render.sh          # alles
bash tools/audio/render.sh music    # nur Musik
bash tools/audio/render.sh verify   # Messbericht neu schreiben
```

---

## 5. Tests

Aktueller vollständiger Satz mit getrennten Test-Spielständen:

```bash
python3 tools/verify_stingforge_r2.py
python3 tools/verify_stingforge_branding.py
python3 tools/verify_stingforge_r2_exports.py
python3 tools/package_stingforge_r2_release.py
```

Die alten Einzeltests sind weiterhin verfügbar:

```bash
export XDG_DATA_HOME="$PWD/.godot_data"

# Funktionstest (Kampagne, Kampf, Boss, Evolution, Pause, Einstellungen, Training)
godot --headless --path . res://tests/smoke.tscn

# Inhaltsprüfung (Daten, Assets, Ton, Übersetzungen, Formationen)
godot --headless --path . res://tests/content.tscn

# Screenshots erzeugen (braucht eine Anzeige)
godot --path . res://tests/shots.tscn
```

Beide Prüfskripte geben bei Erfolg `SMOKE_OK` bzw. `CONTENT_OK` aus und enden mit
Rückgabewert 0.

---

## 6. Veröffentlichung ohne Editor prüfen

```bash
mkdir -p /tmp/testlauf && cp build/linux/Stingforge.x86_64 /tmp/testlauf/
cd /tmp/testlauf && ./Stingforge.x86_64 --headless --quit-after 120
```

Läuft das Programm ohne Fehlermeldung durch, sind PCK und Projektstand gültig.
Ein echtes Fenster braucht eine Grafikausgabe (X11/Wayland); ohne Anzeige lässt
sich das Spiel nur mit `--headless` starten.
