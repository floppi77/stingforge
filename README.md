# Stingforge

**Evolve. Adapt. Strike.**

Ein horizontales Bienen-Shoot’em-up: Yuri fliegt durch zehn Reiche gegen eine Welt
voller Stahl, Sporen und Maschinen. Waffen, Werkstatt-Upgrades und Evolutionen
lassen sich zu unterschiedlichen Builds kombinieren.

## Fertige Spieldateien

- [Windows](<release/Stingforge.exe>) – ohne Installation, alle Spieldaten eingebettet.
- [Linux](<release/Stingforge.x86_64>) – ohne Installation, gegebenenfalls als ausführbar markieren.
- [Prüfsummen](<release/SHA256SUMS.txt>).

Vorhandene Spielstände der früheren Version werden beim ersten Start nach
Stingforge kopiert. Die alten Originaldateien bleiben erhalten; vorhandene
Stingforge-Spielstände werden nicht überschrieben.

## Losspielen

1. **Neue Kampagne** → Schwierigkeit → Starttalent.
2. Fliegen: **WASD/Pfeile** oder linker Stick; schießen: **Leertaste/A** halten.
3. Waffenleiste: **Q/E** bzw. **LB/RB**; kaufen/aktivieren: **F/RT**; Pause: **Esc/Start**.
4. Nach einem Level eine Evolution wählen und Werkstatt-Punkte investieren.
5. Taktische Käufe werden nach jedem Level auf 0 zurückgesetzt; Werkstatt und
   Evolutionen bleiben. Die kostenlose Basiswaffe ist immer verfügbar.
6. Schild erst kaufen: Stufe 1/2/3 gibt genau 1/2/3 Ladungen. Verlorene Ladungen
   regenerieren; die Pentagramme um die Biene zeigen den aktuellen Vorrat.
7. **Highscores** zeigt verdiente Run-Gesamtpunkte, getrennt nach Kampagne und Boss-Rush.
   Die Schwierigkeit wird beim Runstart gewählt und bleibt danach fest.

Tastatur und Xbox werden gleichzeitig angezeigt. Alle Belegungen sind einstellbar.
**F4/Back** öffnet das Debugmenü für gezieltes Testen von Leveln und Builds.

## Diese Überarbeitung (R4)

- **Pixellook in 1920 × 1080:** neues Pixel-Titelbild und -Logo, Pixelschriften
  (Jersey 10, Silkscreen), Rahmen und Menüs im Amiga-Stil mit Copperverläufen.
- **Ultrawide (21:9, 32:9) und 16:10:** Das Spielfeld bleibt 16:9, die Ränder zeigen
  die Levelkulisse weiter, die HUD-Bänder laufen über die volle Breite.
- **Flacheres HUD:** oben 40 statt 56, unten 44 statt 64 Weltpixel, gleiche
  Schriftgrößen, mehr Spielfeld.
- **Neu gezeichnete Bosse** und eine pixelgenaue Schwachpunktmarke.
- **Behoben:** Der Zwischengegner bleibt jetzt in jedem Level, bis er besiegt ist;
  Werkstatt- und Debuglisten springen nach einer Auswahl nicht mehr nach oben.
- **20 Starttalente**, bei jedem Start drei zufällig zur Wahl; **Schild** als Wabenhülle;
  **Blitz** feuert je Stufe eine Kugel mehr (2/3/4); schmalere Menüzeilen.
- **Bosse** bewegen sich ohne Zittern und wie ihr Tier; der **Endboss** täuscht seinen
  Tod vor; neue **Gegner** von hinten, von oben und vom Boden; **Highscore-Namen**;
  neu gestaltete **Hindernisse**, **Wind** und **Vordergrundebenen**; echter **Wellenschuss**.

Details: [R4-Bericht](<docs/STINGFORGE_R4.md>). Frühere Stände:
[R3](<docs/STINGFORGE_R3.md>) · [R2](<docs/STINGFORGE_R2.md>) · [R1](<docs/STINGFORGE.md>).

## Dokumentation

- [Handbuch](<docs/HANDBUCH.md>) – Steuerung und Spielsysteme.
- [Build-Anleitung](<docs/BUILD.md>) – Engine, Import und Exporte.
- [R2-Testprotokoll](<docs/TESTPROTOKOLL_R2.md>) – aktuelle vollständige Abnahme.
- [Historische Prüfungen](<docs/TESTPROTOKOLL.md>) – frühere Entwicklungsstände.
- [Abschlussbericht](<docs/BERICHT.md>) – Projektumfang.
- [Audio](<docs/AUDIO.md>) und [Messungen](<docs/AUDIO_MEASUREMENTS.md>).

## Quellen bauen und prüfen

```bash
export XDG_DATA_HOME="$PWD/.godot_data"
export XDG_CONFIG_HOME="$PWD/.godot_config"
export XDG_CACHE_HOME="$PWD/.godot_cache"
godot --headless --path . --export-release Linux build/linux/Stingforge.x86_64
godot --headless --path . --export-release Windows build/windows/Stingforge.exe
python3 tools/verify_stingforge_r3.py
python3 tools/verify_stingforge_r3_exports.py
```

Neue Bilder werden in dieser Umgebung mit dem [Import-Hilfsskript](<tools/import_shuttle.sh>)
importiert, ohne den vorhandenen Godot-Cache zurückzusetzen. Die Prüfläufe verwenden
isolierte Speicherordner im Buildverzeichnis und verändern keine echten Nutzersaves.

## Aufbau

Godot-Autoloads verwalten Daten, Speicher und Eingaben; die Spielwelt liegt unter
[scripts/game](<scripts/game/>), Menüs und HUD unter [scripts/screens](<scripts/screens/>).
Grafik- und Audioressourcen liegen unter [assets](<assets/>), automatisierte Prüfungen
unter [tests](<tests/>). Der fremde Projektordner Astra bleibt unberührt und ist vom
Export ausgeschlossen.
