# Stingforge R3 – Pause, Laufzeitleiste, Fehlerkorrekturen und UI-Feinschliff

Stand: 27.10.2026. Grundlage ist der abgenommene R2-Stand. Eine Sicherung der
R2-Quellen liegt unter `build/claude-backup-20261027-2315/`, die vorherigen
Spieldateien unter `build/stingforge-r3-previous-release/`.

## Behobene Fehler

| Fehler | Ursache | Korrektur |
|---|---|---|
| **Pause hielt das Spiel nicht an.** Gegner, Geschosse, Hintergrund, Spawn- und Leveltimer liefen hinter dem Pausenmenü weiter (gemessen: 1,0 s Spielzeit je 1,0 s Pause). | Die Spielwelt hängt unter dem App-Knoten, der für Menüs immer laufen muss. Die Welt erbte diesen Modus, die Engine-Pause griff deshalb nicht. | Der Welt-Viewport ist jetzt ausdrücklich pausierbar ([app.gd](../scripts/autoload/app.gd)). Gilt auch für Fokusverlust, Controller-Trennung und das Debugmenü. |
| Boss erschien nach **„Am Checkpoint neu starten“** während der Boss-Ankündigung trotzdem. | Ein laufender Timer der Ankündigung wurde beim Neustart nicht verworfen. | Jeder Checkpoint-Neustart macht veraltete Ankündigungen ungültig ([game.gd](../scripts/game/game.gd)). |
| Boss erschien nach einem Neustart während der **Miniboss-Wartezeit** am Levelende. | Die 6-Sekunden-Wartezeit war ein Engine-Timer außerhalb der Spielzeit. | Die Wartezeit läuft jetzt als Spielzeit in der Regie und wird beim Neustart zurückgesetzt ([director.gd](../scripts/game/director.gd)). |
| Fokusverlust kurz **nach einem Levelsieg** legte ein Pausenmenü über die Ergebnisfolge. | Die Pause prüfte nicht, ob das Level schon beendet war. | Keine Pause mehr nach Levelende. |
| Laser-Gegner konnten **während der Pause** feuern. | Nicht pausierbarer Vorwarn-Timer. | Pausierbarer Timer ([enemy.gd](../scripts/game/enemy.gd)). |
| **Build-Übersicht** in der Pause zeigte veraltete Werte (Nektar, Punkte, Waffe vom letzten Checkpoint). | Sie las den gespeicherten Stand statt des laufenden Spiels. | Im Spiel zählen die Live-Werte ([build_overview_screen.gd](../scripts/screens/build_overview_screen.gd)). |
| Der Zwischentext vor einem Level stand **doppelt** auf dem Bildschirm. | Der Text war gleichzeitig Untertitel und Inhalt. | Ab Level 2 nur noch einmal ([story_screen.gd](../scripts/screens/story_screen.gd)). |
| Mögliche Endlosschleife bzw. ungültiger Zugriff, wenn **keine Evolution** mehr angeboten werden kann. | Zufallsauswahl aus leerer Liste. | Abbruch bei leerer Liste ([app.gd](../scripts/autoload/app.gd)). |

## Neu: Laufzeitleiste

In der schmalen Zeile unter den Instrumenten steht jetzt eine Leiste vom Levelstart
bis zum Boss ([level_progress.gd](../scripts/core/level_progress.gd)):

* Rauten markieren die Checkpoints (gefüllt = erreicht), ein rotes Dreieck den
  Miniboss, die goldene Raute am Ende den Boss.
* Daneben die geschätzte Restzeit „Boss in 1:24“, danach „Boss naht“ bzw.
  „Bosskampf“. Im Boss-Rush „Boss 3 / 10“.
* Die Schätzung kommt aus der Levelregie (`Director.eta()`): geplante
  Abschnittsdauern, Einflug und Miniboss-Wartezeit. Sie zählt nur gespielte Zeit;
  Pause, Tod und Schonfrist halten sie an.
* Die Pause-Statusspalte und der Zwischentext („Flugzeit bis zum Boss: etwa 4:43“ in Level 1)
  nutzen dieselbe Grundlage.

## UI-Feinschliff

* **Pause, Game Over und Rückfragen im Spiel** liegen als durchscheinender Schleier
  über der eingefrorenen Szene statt auf einer Vollbildkulisse. Rechts zeigt eine
  Statusspalte Level, Laufzeitleiste, Vital, Schild, Nektar, Punkte, Spielzeit und
  Schwierigkeit ([ui_veil.gd](../scripts/core/ui_veil.gd),
  [ui_run_status.gd](../scripts/core/ui_run_status.gd)). Game Over ist rot getönt.
* **Levelergebnis** mit großer Wertungsanzeige und Kennzahlen mit Tausenderpunkten.
* **Menüs:** warmer Fokusschein, feine Oberkanten an Zeilen und Panels,
  Hintergrund mit Verlauf, Lichthof und Pollenpunkten
  ([ui_theme.gd](../scripts/core/ui_theme.gd), [ui_backdrop.gd](../scripts/core/ui_backdrop.gd)).
* **HUD:** Levelbadge „LEVEL 03 / 10“, Glanzkante an den Instrumenten, Boss-Lebensbalken
  mit sichtbarer Fassung und Farbwechsel von Gold zu Rot bei niedrigem Leben.

Spielbalance, Waffen- und Evolutionsdaten sind unverändert.

## Prüfung

* `python3 tools/verify_stingforge_r3.py`: alle 34 bisherigen Suiten plus neue
  Pause-/Laufzeitprüfung [r3_pause_probe](../tests/r3_pause_probe.gd), headless, mit
  isolierten Testdaten. Ergebnis: **35 / 35 grün**
  ([Zusammenfassung](../build/logs/stingforge-r3/summary.json)).
* Die Pauseprüfung war **vor** der Korrektur nachweislich rot
  ([Rotlog](../build/logs/r3/pause-red.log)): Spielzeit, Regie, Hintergrund, Gegner und
  Spawn-Timer liefen in der Pause weiter, Boss nach Checkpoint-Neustart, Pause nach
  Levelende.
* `python3 tools/verify_stingforge_r3_exports.py`: Export Linux und Windows,
  eingebetteter PCK, neue Skripte verpackt, Start der Linux-Datei und der
  Windows-Datei unter Wine (jeweils ohne Fenster).
* Bildnachweise des HUD, der Pause und der Menüs: `build/r3-shots/`
  (Vorher-Stand: `build/r3-shots-vorher/`). Die Bilder entstanden vor zwei kleinen
  Textkorrekturen: In der Pause-Statusspalte steht jetzt „Abschnitt 1 / 5“ statt
  „Checkpoint 0 / 4“, und der Zwischentext erscheint nur noch einmal. Das Bild des
  Zwischentexts wird deshalb nicht ausgeliefert.

### Grenzen

* Die Restzeit ist eine Schätzung bis zum Bosskampf; die Dauer des Bosskampfs
  hängt vom Build ab und wird bewusst nicht vorhergesagt.
* Windows nur unter Wine geprüft, nicht nativ. Kein physischer Controller.
* Einige ältere, zeitkritische Eingabetests (z. B. `shopprobe`) stolpern gelegentlich
  unter hoher fremder Rechnerlast. Ein Vergleich alter gegen neuer Code unter gleichen
  Bedingungen war je 4/4 grün. Der R3-Prüfer wiederholt eine Suite höchstens zweimal und
  protokolliert jeden Versuch; im Abnahmelauf war keine Wiederholung nötig.
* Der R2-Quellwächter (eingefrorene Quelldateien) gilt für R3 nicht mehr, weil R3
  Pause, HUD und Menüs bewusst ändert.
