# Stingforge

**Evolve. Adapt. Strike.**

## Fertige Versionen

- [Windows – Stingforge.exe](<../release/Stingforge.exe>)
- [Linux – Stingforge.x86_64](<../release/Stingforge.x86_64>)
- [SHA-256-Prüfsummen](<../release/SHA256SUMS.txt>)

Beide Programme enthalten alle Spieldaten. Die bisherigen Auslieferungen werden
als Sicherung aufbewahrt. Echte Nutzerspielstände wurden bei der Entwicklung
nicht verwendet oder verändert.

## Was sich praktisch geändert hat

### Fairere Gegner und sichtbares Feuer

Die verfolgende Wespe wurde durch eine doppelte Bewegung tatsächlich mit 330
statt 230 Pixeln pro Sekunde bewegt. Sie fliegt jetzt mit 138, bei Verstärkungen
höchstens 160. Spätere Pressen-Verfolger sind ebenso korrigiert: 126, höchstens
145. Beide wählen nach ihrer Warnphase einen Anflug, kehren nicht um und
verfolgen die Biene nicht endlos. Unsere Biene behält ihr Grundtempo 252.

**Entspannt und Normal erhalten zentral vier statt fünf angeforderte
Gegnergeschosse** – im Test exakt 800 aus 1.000. Experte bleibt bei 1.000 aus
1.000. Das gilt auch für Bosse und Module und berücksichtigt die Schwierigkeit
des tatsächlich laufenden Spiels, nicht eine abweichende Menüeinstellung.

Gegnergeschosse haben einen stabilen dunklen Rand und hellen Kern. Kein neues
Blinken; ihre Treffergröße wurde dafür nicht vergrößert.

### Schild verständlich und wiederaufladbar

Das Schild lädt **automatisch** nach: normalerweise eine Ladung in zwölf
Sekunden, mit passenden Fähigkeiten schneller. Die Kaufstufe bleibt nach einem
Treffer deshalb bestehen. Höhere taktische Stufen erweitern die Kapazität und
füllen beim Kauf sofort eine Ladung auf. Auch ein nur in der Werkstatt
freigeschalteter Schild regeneriert korrekt.

Gefüllte/leere Schildsymbole, Ladebalken und Restzeit zeigen den echten Zustand.

### Fähigkeiten wirken zusammen

- Kreisflug, Welle und Zielsuche dürfen gemeinsam gekauft werden. Die alte
  gegenseitige Sperre entfällt; echte Kaufvoraussetzungen bleiben bestehen.
- Kreisschüsse stapeln sich nicht mehr auf derselben Position. Spirale und
  Zusatzläufe übernehmen das Profil der aktiven Waffe: auch Plasma-Flächenschaden
  und Blitzketten bleiben erhalten.
- Jeder Werkstatt-Radius addiert sich zur Waffe. Plasma plus erste Splitterwolke
  verbessert den Radius tatsächlich von 28 auf 48, statt bei 28 zu bleiben.
- Schnellfeuer oberhalb der Mengen-/Taktgrenze bringt zusätzliche Wucht statt
  einer wirkungslosen Stufe. Begrenzungen gegen Kugelflut bleiben bestehen.
- Mehr Waffenschaden wird nicht mehr durch überproportional höhere Gegner-HP
  aufgehoben. Beispiel: doppelter Schaden erzeugt etwa 1,57-fache statt
  2,30-fache HP – die Aufrüstung verkürzt den Kampf wirklich.
- Kritische Treffer, Blitz-/Werkstattketten und Flächentreffer verstärken sich
  nachvollziehbar. Splitter und Schwarm können keine unendlichen Nachkommenketten
  mehr auslösen.
- Eigene Pollen verletzen die Biene nicht. Ihre Flächenwirkung, anfliegende
  Geschosse in Aura/Wolken, Checkpoint-Heilung, kleine Nektarboni, zusätzliche
  Drohnen und gespeicherte Lebensboni sind korrigiert.

Alle 32 Werkstattartikel und alle 36 Evolutionen wurden auf ihre Wirkungspfade
geprüft. Nicht jede theoretisch mögliche Gesamtkombination ist vollständig
getestet; die konkreten Testmengen und die Trennung zwischen Verhaltenstests und
Quelltextabdeckung sind im [Fähigkeitenbericht](<STINGFORGE_ABILITIES.md>) dokumentiert.

### Bosskörper und freies Spielfeld

Bosse verwenden ihren sichtbaren Körper einschließlich lebender Module, des
aktuellen Animationsbildes und der Drehung statt eines kleinen Zentralkreises.
Transparente Löcher/Ecken sind frei. Geschosse treffen entlang ihrer tatsächlichen
Flugstrecke. Durch den sichtbaren Bosskörper zu fliegen kostet jetzt Schild oder
Leben; vorhandene Schutzzeiten gelten weiterhin.

Das HUD besitzt ein eigenes opakes Band in den oberen 76 von 540 logischen
Zeilen. Auch Bossleiste und Meldungen bleiben darin; die taktische Leiste beginnt
weiterhin bei Zeile 452. Biene und Gegner werden entsprechend begrenzt, damit
keine erreichbaren Körper hinter der Anzeige verschwinden. Tastatur und Xbox
bleiben gleichzeitig sichtbar.

### Neuer Name und neue Biene

Dein transparentes Stingforge-Logo und der bisherige Hintergrund sind bytegleich
übernommen. Titel, Untertitel, Menükennzeichnung, Credits und Programmdateien
heißen jetzt Stingforge. Die animierte Spielerbiene hat kräftigen Goldpelz,
dunkle Bänder, ein größeres dunkles Auge und transparente geäderte Flügel – bei
unverändertem Bildformat und unveränderter kleiner Spieler-Trefferzone.

[Hauptmenü](<stingforge/main_menu.png>) ·
[HUD und Boss](<stingforge/high_boss.png>) ·
[Projektile im hellen Level](<stingforge/projectiles_bright.png>) ·
[Projektile im dunklen Level](<stingforge/projectiles_dark.png>)

## Alte Spielstände

Beim ersten Start werden fehlende Speicherdateien aus dem früheren Ordner
**Apidya Reimagined** in den neuen Stingforge-Ordner kopiert. Alte Originale
bleiben unverändert; bereits vorhandene Stingforge-Dateien gewinnen immer.
Bei einer defekten alten Hauptdatei wird eine gültige alte Sicherung übernommen.
Profil, Kampagne, Werkstattstufen, Einstellungen und Game-Over-Zähler bleiben
erhalten. Alle drei Fälle wurden in getrennten Testordnern geprüft.

## Prüfung und Grenzen

- **24/24 Gesamtsuiten grün**, einschließlich Kampagnenablauf durch zehn Level,
  Käufen, Game Over, Boss-Rush, Menüs, Belegungen und den neuen Regressionen.
- **91 gezielte Waffen-/Ereignisprüfungen** und **1.153 Matrixprüfungen**:
  384 Waffen/Werkstatt-Stufen-Konfigurationen und 192 Form-/Zusatzmusterpaarungen.
- **418 Welt-/Boss-/Synergieprüfungen**, unter anderem alle zehn Bosse in beiden
  Bildern, Treffer aus mehreren Richtungen und Kontakt mit äußeren Modulen.
- **54 Speicherübernahme-Prüfungen** in drei echten Engineprozessen; Hashvergleich
  bestätigt unveränderte alte Dateien.
- **Neun strenge Bildvergleiche: null überdeckte Spielfeldpixel.** Schriftstufen
  0,8/1,0/1,6, Boss-/Hinweisanzeigen, helle/dunkle Projektilbilder und ein
  unabhängiger Aseprite-Roundtrip sind geprüft.
- Neue Einzeldateien gestartet: Linux nativ im Fenster, Windows unter Wine.
  Kein nativer Windows-PC und kein physisches Xbox-Gamepad verfügbar.
- Reale Lastmessung bei 1920×1080, maximaler Werkstatt und zusätzlichem Stress:
  **65,1 fps**, bis zu **397 Geschosse und 20 Gegner**; Prozesszeit im Mittel
  11,26 ms. Gemessen mit Software-OpenGL/llvmpipe, nicht der RTX-GPU. Einzelne kurze
  Engineprüfungen melden beim Beenden bekannte Dummy-Audio-Ressourcenreste;
  Script-/Parsefehler werden nicht toleriert. Der Export meldet weiterhin den
  vorhandenen Hinweis auf einen nicht konfigurierten Blender-Importer; benutzt
  und gepackt werden die bereits importierten PNG-Grafiken, keine Blender-Szenen.

Nachweise: [Gesamtergebnis](<../build/logs/stingforge/summary.json>),
[Speicherübernahme](<../build/logs/stingforge/branding-summary.json>),
[Exportstarts](<../build/logs/stingforge/binaries-summary.json>),
[Darstellungsbericht](<STINGFORGE_VISUAL.md>),
[Weltbericht](<STINGFORGE_WORLD.md>).

```bash
python3 tools/verify_stingforge.py
python3 tools/verify_stingforge_branding.py
python3 tools/verify_stingforge_exports.py
```
