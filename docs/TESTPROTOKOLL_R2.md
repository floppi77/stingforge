# Stingforge R2 – abschließendes Testprotokoll

## Ergebnis

**34/34 Start-/Regressionssuiten erfolgreich**, jeweils echter Exit 0, exakter Endmarker, keine Script-/Parse-/Compilefehler und keine allgemeinen Laufzeitfehler. Der reine alte Punkte-Diagnoselauf enthält keine Assertions; er wird nicht als Highscore- oder Balancingbeweis ausgegeben.

[Gesamtergebnis](<../build/logs/stingforge-r2/summary.json>) · [eingefrorener Quellstand](<../build/logs/stingforge-r2/tested-sources.json>) · [Quellschutz](<../build/logs/stingforge-r2/source-guard.json>)

Nach der letzten Konfigurationsänderung wurde der gesamte Satz erneut ausgeführt. Der Quellstand blieb währenddessen und während der Export-/Bildabnahme unverändert. Die Baseline mit 1.095 manifestierten Dateien blieb unverändert.

## Wichtige fachliche Prüfungen

| Bereich | Tatsächlich geprüft |
|---|---|
| Legacy-Regression | 24 alte Suiten, 4.729 gezählte Assertions; unveränderte Kugelgrenzen, Waffen-/Shop-Kombinationen, Proc-Schutz und Balanceprüfungen. Veraltete Erwartungen einzeln dokumentiert, nicht pauschal gelockert. |
| Player | 201 Checks: Schild 0 ohne Kauf, exakt 1/2/3 nach Kauf, Werkstatt-/Bastion-Gates, Schutzzeit und Regeneration, Orbit, Gravitation, Punkteerfassung. |
| World | 272 Checks plus 71 Build-/Leveldruckchecks; echte Spawn-/Feuertakte und HP, Glas-Segmente, Trefferfarben, Partikelobergrenzen, Death-Continue. |
| Endboss | 186 Checks: natürlicher Übergang, neue Form, 175 % MaxHP, drei eigene Phasen, echte Alpha-Trefferflächen; kein Sieg/Reward beim ersten Tod. Kampagne und Boss-Rush beobachten die zweite Form zusätzlich im Gesamtablauf. |
| Highscores | 149 Checks und 13 weitere in einem neuen Engineprozess: Schreiben/Neuladen, Sortierung, Filter, monotone Dublettenvermeidung, beschädigte Daten, Wiederherstellung und echte Menüroute. |
| Parent-Integration | 79 Checks: alle drei Schwierigkeiten, Levelreset sofort gespeichert, Werkstatt/Evos bleiben; echte Player-Credits, endgültiges Game Over, Abbruch, Abschlussbonus 1.050 Punkte, Restore ohne Doppelbonus; Rush mit eigener Identität und unverändertem Hash der Originalkampagne. |
| Vordergrund | 10 Level und Scrollnähte; 10.097 native Headless-Checks ohne Bodenlücken. Zusätzlich 100 deterministische reale Godot-Zeitabläufe und 250 Alpha-Fälle. Hypothesis war nicht installiert: ausdrücklich deterministischer Seed-Fallback, keine behauptete Hypothesis-Ausführung. |
| HUD | 27 Layoutvarianten, reale Textmaße, Training-/Rush-Leveldaten, Schild 0–3, neue Bossform Phasen 1–3. |

Einzelberichte: [Regressionen](<STINGFORGE_R2_REGRESSION.md>) · [Player](<STINGFORGE_R2_PLAYER.md>) · [World](<STINGFORGE_R2_WORLD.md>) · [Finale](<STINGFORGE_R2_FINAL.md>) · [Scores](<STINGFORGE_R2_SCORES.md>) · [Parallax](<STINGFORGE_R2_PARALLAX.md>) · [HUD](<STINGFORGE_R2_HUD.md>)

## Tatsächliche Bilder, nicht nur Headless-Marker

Der abschließende Grafiklauf verwendet Wayland und Software-OpenGL, keine erfundenen Screenshots:

- Neun neue HUD-/Ohne-HUD-Paare, Spielfeldgrenzen exakt 56/476: **10.065.600 verglichene native Feldpixel, exakt 0 Abweichungen**. Zusätzlich unabhängiger PNG-Vergleich. Leere Felder oder unsichtbares HUD werden als falsch zurückgewiesen.
- Glas: neun native Pixelprüfungen über vier An-/vier Aus-Phasen und den aktiven Zustand ohne Warnrahmen.
- Schild-Pentagramme für 0/1/2/3 Ladungen, auch mit reduzierten Effekten.
- Neuer Kernorganismus in Form 2, Phase 3/3; Vordergrund mit tatsächlich sichtbarem Geschoss unterhalb der früheren HUD-Unterkante.
- Hauptmenü mit neun Aktionen; Highscores mit Testeinträgen bei normaler und 160-%-Schrift. Diese Testwerte sind keine persönlichen Spielergebnisse.
- 32 zusätzliche unveränderte Art-/Aseprite-Roundtripprüfungen.

[Pixelbeleg](<../build/stingforge-r2-hud/independent-pixel-report.json>) · [Grafiklauf](<../build/logs/stingforge-r2/hud-render-final.log>)

## Export und echte Startversuche

Beide Dateien enthalten ihren PCK eingebettet. Packfooter und Exportverzeichnisse geprüft; alle 30 neuen Tiefentexturen, drei Bossblätter und drei neuen Produktionsmodule sind in beiden Paketen vorhanden. Start aus einem separaten Arbeitsordner, nicht durch lose Projektdateien gerettet.

| Ausgabe | Größe | Startprüfung |
|---|---:|---|
| Linux x86_64 | 103.834.128 Bytes | nativ mit echtem Wayland-Fenster, Exit 0 |
| Windows x86_64 | 139.583.200 Bytes | unter Wine headless, Exit 0; kein nativer Windows-PC |

[Binärnachweis samt SHA-256](<../build/logs/stingforge-r2/binaries-summary.json>) · [Linux-Start](<../build/logs/stingforge-r2/binary-linux-final.log>) · [Windows-Start](<../build/logs/stingforge-r2/binary-windows-final.log>)

Die drei alten Save-Migrationsfälle wurden erneut geprüft; Originaldateien bleiben jeweils bytegleich. Alle Testdaten liegen unter isolierten Buildverzeichnissen beziehungsweise einem eigenen Wine-Präfix. Persönliche Spielstände wurden nicht verändert.

## Lastmessung

Abschließender echter Spielbetrieb: Level 5, Maximalwerkstatt, Dauerfeuer, zusätzliche Gegner und 160 zusätzliche Geschosse; 1920×1080, VSync an, kein FPS-Limit. Unverwundbarer Testspieler, damit kein Game Over die Messung ersetzt.

- 554 Bilder in 10,00 Sekunden: **55,4 FPS** mit **llvmpipe / Software-OpenGL**, nicht mit einer RTX-Grafikkarte.
- Prozessframe durchschnittlich 15,18 ms, p95 16,22 ms.
- Spitze 285 Geschosse und 20 Gegner, 190 Drawcalls.
- **0 pausierte/gefrorene Frames**; kein Menü als scheinbar schneller Spielbetrieb gemessen.

[Messwerte](<../build/logs/stingforge-r2/performance-summary.json>) · [Rohlog](<../build/logs/stingforge-r2/performance-final.log>)

Dies ist weder ein GPU-Benchmarkversprechen noch eine gemessene Abschusszeit des Endbosses. Ideale HP/DPS-Abschätzungen im Weltbericht sind ausdrücklich keine Livebosszeiten.

## Ehrlich verbleibende Grenzen und rote Vorversuche

- Bekannte Audio-/Playback-Ressourcenmeldungen beim Beenden kurzer Dummy-Audio-Prozesse bleiben dokumentiert. Sie werden nicht als behoben behauptet. Alle anderen Engine-ERRORs führen zu rot.
- Kein physischer Xbox-Controller; Controllerbelegung und Ereigniswege automatisiert geprüft. Windows nur unter Wine, nicht nativ und nicht als Windows-Grafikbenchmark.
- Der erste Export hatte trotz Prozesscode 0 einen Blender-Konfigurations-ERROR. Der strenge Prüfer wies ihn zurück. Ursache: unnötig aktivierter 3D-Importer; nur dessen Projektschalter wurde deaktiviert. Kein Blender-Aufruf, keine Neuberechnung/Änderung der Grafiken, kein Cache-Reset. Beide finalen Exporte sind frei von diesem Fehler.
- Eine zusätzliche neue Benchmark-Sicherheitsabfrage verwendete zunächst einen falschen Eigenschaftsnamen. Der fehlerhafte Testlauf wurde verworfen und archiviert, auf die tatsächliche Spiel-API korrigiert und anschließend einschließlich vollständiger Exportabnahme erneut grün ausgeführt. Keine Produktionsänderung dafür.
- Alte Smoke-Test-Lambda und zwei weitere Testfixture-Zwischenfehler samt Rotlogs sind im Legacybericht nachvollziehbar, nicht als Spielkorrekturen ausgegeben.

[Export-Rotnachweis](<../build/logs/stingforge-r2/export-linux-red.log>) · [Benchmark-Harness-Rotnachweis](<../build/logs/stingforge-r2/performance-red-harness.log>)

## Reproduzieren

Aus dem Projektordner:

```bash
python3 tools/verify_stingforge_r2.py
export XDG_DATA_HOME="$PWD/.godot_data"
export XDG_CONFIG_HOME="$PWD/.godot_config"
export XDG_CACHE_HOME="$PWD/.godot_cache"
godot --headless --path . --export-release Linux build/linux/Stingforge.x86_64
godot --headless --path . --export-release Windows build/windows/Stingforge.exe
python3 tools/verify_stingforge_r2_exports.py
python3 tools/package_stingforge_r2_release.py
```

Keine zweite Serverinstanz, keine globale Installation und kein Löschen des Godot-Caches erforderlich.
