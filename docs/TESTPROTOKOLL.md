# Stingforge – Testprotokoll

## Aktuelle Zusatzrunde

Der aktuelle Stand heißt **Stingforge – Evolve. Adapt. Strike.**. Balance,
Fähigkeiten, Bosskollisionen, eigener HUD-Bereich und Spielerbiene wurden gezielt
überarbeitet. Die früheren Unverändert-Aussagen weiter unten beziehen sich nur
auf die damaligen UI-Runden.

Aktueller Gesamtlauf: `python3 tools/verify_stingforge.py`.
Speicherübernahme: `python3 tools/verify_stingforge_branding.py`.
Bildprüfung: `python3 tests/stingforge_visual_checks.py --screenshots`.

Final: **24/24 Suiten**, **91 Waffen-/Ereignisprüfungen**, **1.153 Matrixprüfungen**,
**418 Welt-/Bossprüfungen** und drei Speicherübernahmefälle grün. Neun echte
HUD-Bildvergleiche: null verdeckte Spielfeldpixel. Endgültige Einzeldateien
starten (Linux nativ im Fenster, Windows unter Wine). Lastmessung 1920×1080 mit
397 Geschossen/20 Gegnern unter llvmpipe: 65,1 fps, Prozessmittel 11,26 ms.

Aktuelle Messwerte und Grenzen: [Stingforge-Bericht](<STINGFORGE.md>),
[Waffenprüfung](<STINGFORGE_ABILITIES.md>), [Weltprüfung](<STINGFORGE_WORLD.md>),
[Darstellung](<STINGFORGE_VISUAL.md>).

---

## Historische Teststände


Alle Prüfungen wurden auf dem Entwicklungsrechner ausgeführt (Ryzen 7 9800X3D,
RTX 4090, 60 GB RAM, Arch Linux, Godot 4.7.2). Die Anzeige der Testumgebung ist
eine virtuelle Ausgabe mit 1600×900 ohne echte GPU; gerendert wird über Mesa
llvmpipe (Software-OpenGL).

Vier Stufen, wie im Auftrag verlangt:

* **implementiert** – Code vorhanden, aber nicht automatisch geprüft.
* **automatisiert geprüft** – ein Prüfskript hat es ohne Fehler durchlaufen.
* **im laufenden Spiel geprüft** – im laufenden Fenster beobachtet (Screenshot,
  Messung), nicht nur im Kopflauf.
* **mangels Umgebung offen** – hier nicht prüfbar, mit Grund.

---

## 0. Aktueller Nachtrag: ausschließlich UI/HUD modernisiert

Der aktuelle Oberflächenstand ersetzt die älteren UI-Bilder weiter unten;
Spielablauf und Balance stammen unverändert aus dem vorherigen Stand.

| Prüfung | Ergebnis | Stand |
|---|---|---|
| Quellschutz | 18 Dateien aus Spiellogik/Autoloads/Projektkonfiguration und 42 Eingabe-/Zustandsfunktionen der Oberfläche unverändert gegenüber der Sicherung | automatisiert geprüft |
| Tastatur-/Xbox-Anzeige | `UI_PROMPTS_OK`: 573 Prüfungen, aktuelle Belegung, farbige Xbox-Tasten, beide Geräte unabhängig vom zuletzt genutzten Gerät, kein Schreiben in Save oder InputMap | automatisiert geprüft |
| Menüs und Schriftgrößen | `UI_MODERN_OK`: 99 Prüfungen ohne Renderer bzw. 116 im Fenster einschließlich 17 Bildnachweisen; 100/120/160 Prozent, Fußleisten und Detailkarten innerhalb der Zeichenfläche | automatisiert und im laufenden Fenster geprüft |
| HUD | `HUD_OK`: 63 Prüfungen für Schriftanpassung, Auflösungsfaktoren, Belegungshinweise und unveränderten Spielzustand beim Zeichnen | automatisiert geprüft |
| Maus, Anzeige, Geometrie | `MAUS_OK`, `ANZEIGE_OK`, `LAYOUT_OK` aus der gemeinsamen UI-Runde; das neu komponierte Hauptmenü wird zusätzlich im strengeren Referenz-Prüflauf gemessen | im laufenden Fenster geprüft |
| Hauptmenü nach Bildvorlage | `MENU_REFERENCE_OK`: 506 Headless-Prüfungen bzw. 524 im Fenster, echte Kampagnen-/Profilwerte, sieben Zustände, 100/120/160 Prozent Schrift, Sperren und funktionierende Menüaktionen; Originalhintergrund unverändert | automatisiert und im laufenden Fenster geprüft |
| Bestehende Abläufe | 16 Headless-Suiten einschließlich der drei UI-Prüfungen; echter Prozess-Exitcode und Skriptfehlermeldungen werden ausgewertet | automatisiert geprüft |
| Physisches Xbox-Gamepad | Kein angeschlossener Controller; Darstellung und gespeicherte Belegungen geprüft, Hardwaretasten/Stickgefühl/Vibration nicht neu von Hand geprüft | mangels Umgebung offen |

Die neuen UI-/Tastenprüfungen enden ohne Enginewarnungen. Einige ältere
Kurztests und die mit `--quit-after` beendeten Export-Starttests melden weiterhin
Audio-Ressourcen beim Aufräumen; die Exitcodes sind 0, es gibt keine Skript- oder
Parserfehler. Beide Einzeldateien wurden nach dem Neubau gestartet (Linux und
Windows unter Wine; Linux im Fenster, Windows headless). Die Bildprüfung erfolgt separat im
laufenden Godot-Fenster. Native Windows-Hardware wurde nicht geprüft.

Reproduzierbarer Gesamtlauf: `python3 tools/verify_ui_redesign.py`.
Einzelprotokolle liegen unter `build/logs/ui-regression/`, aktuelle Bilder unter
[UI-Bildnachweise](<ui-modern/>), für das aktuelle Hauptmenü unter
[Referenzmenü-Bilder](<ui-reference/>). Umfang und Grenzen im
[UI-Redesign-Bericht](<UI_REDESIGN.md>).

## 1. Automatisierte Prüfläufe

| Prüfung | Befehl | Ergebnis | Stand |
|---|---|---|---|
| Funktionstest | `godot --headless --path . res://tests/smoke.tscn` | `SMOKE_OK`, 46 Prüfungen, 0 Fehler | automatisiert geprüft |
| Inhaltsprüfung | `godot --headless --path . res://tests/content.tscn` | `CONTENT_OK`, 1124 Prüfungen, 0 Fehler | automatisiert geprüft |
| Oberflächentexte | `godot --headless --path . res://tests/ui_text.tscn` | `UI_OK`, 262 Prüfungen, 0 Fehler | automatisiert geprüft |
| Spielmechanik | `godot --headless --path . res://tests/mechanics.tscn` | `MECHANIK_OK`, 35 Prüfungen, 0 Fehler | automatisiert geprüft |
| Ablauf am Levelende | `godot --headless --path . res://tests/flowprobe.tscn` | `ABLAUF_OK`, 6 Prüfungen, 0 Fehler | automatisiert geprüft |
| Mausbedienung | `godot --path . res://tests/mouseprobe.tscn` | `MAUS_OK`, 5 Prüfungen, 0 Fehler | im laufenden Spiel geprüft |
| Bildprüfung der Nachbesserungen | `godot --path . res://tests/fixprobe.tscn` | `FIXES_OK`, 6 Bilder in `docs/` | im laufenden Spiel geprüft |
| Kampagne komplett | `godot --headless --path . res://tests/campaign.tscn` | `CAMPAIGN_OK`, 10/10 Level, 10 Evolutionen, `completed=true` | automatisiert geprüft |
| Abspann + Boss-Rush | `godot --headless --path . res://tests/ending.tscn` | `ENDING_OK`, 10 Bosse, Freischaltung gesetzt | automatisiert geprüft |
| Drei Builds | `godot --headless --path . res://tests/builds.tscn` | `BUILDS_OK`, Abschüsse 8 / 6 / 4 | automatisiert geprüft |
| Werkstatt, Debugmenü, Bossankündigung, Plasma | `godot --headless --path . res://tests/shopprobe.tscn` | `SHOP_OK`, 32 Upgrades, Kauf/Vorbedingung/Preis, Debugmenü, Boss-Intro, Plasma-Spread 15,5° = 28 % des Fächers | automatisiert geprüft |
| Alle 33 Werkstatt-Upgrades einzeln | `godot --headless --path . res://tests/upgradeprobe.tscn` | `UPGRADE_OK` – 33 Prüfungen, 0 Fehler (dreimal hintereinander wiederholt); je Upgrade ein Messwert (z. B. Kreisradius 86 px, Wellenauslenkung 17 px, Auslenkung mit *Weite Wellen* 72 statt 44 px, Salve 2 Projektile, Splitter 4, Krit 33 %, Bossbonus 150 statt 100) | automatisiert geprüft |
| Sperren der Grundform | derselbe Lauf, Abschnitt `groups` | `UPGRADE_OK` – nach *Kreisflug* werden *Wellenschuss* und *Zielsuche* abgelehnt und als gesperrt geführt | automatisiert geprüft |
| Parallax-Hintergrund | `godot --path . res://tests/bgprobe.tscn` | `BG_OK` – 5 Ebenen, 10 Kacheln, Ferne 12,6 px gegen Vordergrund 183,7 px in 0,5 s; Bild `docs/bg_01_parallax.png` | im laufenden Spiel geprüft |
| Weicher Boss-Phasenwechsel | `godot --headless --path . res://tests/bossprobe.tscn` | `BOSS_OK` – Phasenwechsel 0 → 1, erster Schritt 0,1 px, größter Satz 2,4 px je Bild, Geschosse der alten Phase 3 → 6 (nichts gelöscht) | automatisiert geprüft |
| Schriftbild | `godot --path . res://tests/fontshot.tscn` | `FONTBILDER_OK` – `docs/font_01_hauptmenue.png`, `docs/font_02_werkstatt.png` | im laufenden Spiel geprüft |
| Bilder der fünften Runde | `godot --path . res://tests/r5shots.tscn` | `R5BILDER_OK` – `docs/r5_01_geschosse_nektar.png`, `docs/r5_02_werkstatt_sperre.png`, `docs/r5_03_boss_uebergang.png` | im laufenden Spiel geprüft |
| Balance der Bewaffnung | `godot --headless --path . res://tests/balanceprobe.tscn` | `BALANCE_OK` – vier Ausbaustufen (Start, Mitte, Alles, Alles+): Angriffskraft 125 → 1.843 Schaden je Sekunde (14,7-fach), Kugeln je Sekunde 15 → 107 (gedeckelt), Lebenspunkte einer Motte 34 → 625, rechnerische Abschusszeit 0,27 s bis 0,34 s – kein Gegner fällt mehr im ersten Bild | automatisiert geprüft |
| Gedränge im laufenden Spiel | `godot --headless --path . res://tests/liveprobe.tscn` | `LIVE_OK` – je 40 s gespieltes Level: Start bis 12 Gegner gleichzeitig im Bild (Ø 4,4), voll ausgebaut 6 (Ø 1,7), kein Gegner unter 0,35 s Lebensdauer | automatisiert geprüft |
| Game Over und Weitermachen | `godot --headless --path . res://tests/gameoverprobe.tscn` | `GAMEOVER_OK` – 16 Prüfungen: Zähler 1/2/3, Weiter setzt Leiste zurück (Fächer 2 → 0, Waffe Grundform, Nektar 0), Werkstatt-Mods und Evolutionen bleiben, nach dem dritten Game Over kein Weiter-Eintrag, Run beenden löscht die Kampagne | automatisiert geprüft |
| Bilder Game Over | `godot --path . res://tests/goshot.tscn` | `GOBILDER_OK` – `docs/go_01_gameover.png`, `docs/go_02_kein_weiter.png`, `docs/go_03_hauptmenue_nach_run.png`; im Hauptmenü ist „Fortsetzen“ gesperrt und der Untertitel meldet „Run beendet“ | im laufenden Spiel geprüft |
| Preistabelle | `godot --headless --path . res://tests/pointstable.tscn` | `PUNKTE_OK` – erreichbare Punkte je Level aus den Leveldaten (35.370 bis 87.583, gesamt 523.924) | automatisiert geprüft |
| Anzeige-Einstellungen | `godot --path . res://tests/displayprobe.tscn` | `ANZEIGE_OK`, 23 Prüfungen, 0 Fehler | im laufenden Spiel geprüft |
| Bildschirmaufteilung | `godot --path . res://tests/layoutprobe.tscn` | `LAYOUT_OK` – Hauptmenü 280 von 287 Punkten Höhe (alle acht Einträge ohne Scrollen), Einstellungen 316 von 340 | im laufenden Spiel geprüft |
| Anzeige-Bilder | `godot --path . res://tests/setshot.tscn` | `display_01` … `display_03` in `docs/` | im laufenden Spiel geprüft |
| Leistungsmessung | `godot --path . res://tests/perf.tscn [-- --stress] [-- --maxed]` | 144,9 fps bei 1920 × 1080 (Software-Darstellung) mit **allen** Werkstatt-Upgrades auf Stufe 3 nach dem UI-Redesign; 339 Geschosse, 1.887 Objekte, Prozesszeit Ø 1,62 ms, Median 1,43 ms, p95 3,16 ms (nicht mit GPU-Bildzeit gleichzusetzen) | im laufenden Spiel geprüft |
| Screenshots | `godot --path . res://tests/shots.tscn` | 9 Bilder in `docs/shots/` | im laufenden Spiel geprüft |
| Hauptmenü-Bild | `godot --path . res://tests/menushot.tscn` | `docs/menu_neu.png` | im laufenden Spiel geprüft |
| Bilder der Umrechnung | `godot --path . res://tests/convshot.tscn` | `docs/conv_01_umrechnung.png`, `docs/conv_02_gutschrift.png` | im laufenden Spiel geprüft |

### Was der Funktionstest (46 Prüfungen) abdeckt

Kampagnenstart mit drei gleichwertigen Starttalenten, Schießen und Dauerfeuer,
Gegnerspawn, Abschuss, Punkte, Checkpoint setzen und wiederherstellen,
Bosserscheinung, Bossangriff, Phasenwechsel, Bossbesiegung, Evolutionsangebot mit
drei **verschiedenen** Evolutionen aus mehreren Familien, Speichern und
Freischalten, keine Doppelbelohnung, fünf Saatwerte mit unterschiedlichen
Angeboten, Pause und Fortsetzen, Einstellungsänderung, automatische
Rücknahme der Anzeige, Kauf über die Leiste, kostenlose Reparatur bei vollen
Leben, waffenabhängige Evolution inaktiv ohne Waffe, Training ohne Fortschritt.

### Was die Inhaltsprüfung (1124 Prüfungen) abdeckt

* 36 Evolutionen in 6 Familien (je ≥ 5), eindeutige IDs, gültige Verweise
  (`req`, `synergy`, `weapon`), genau drei Grundtalente.
* Neun Einträge der Waffenleiste mit Kostenliste passend zur Maximalstufe.
* 25 Gegnertypen mit vorhandenem Sprite und HP > 0.
* 10 Bosse mit mindestens zwei Phasen, jeder mit HP-Anteil und Mustern.
* 10 Level mit Name, Boss, Musik, Mechanik, mindestens vier Abschnitten; jede
  Formation im Level existiert in `Director.FORMATIONS`.
* **Code-Abdeckung:** jedes Boss-Muster (39), jeder Bewegungsstil (10), jeder
  Mechanik-Auslöser (10) und jedes Gegnerverhalten (17) hat eine Umsetzung im Code.
* Assets: alle Icons, Geschosse, Effekte; 30 Hintergrundebenen; 24 Musikstücke;
  26 Effekte.
* Übersetzungen: alle Bildschirmtexte, Level- und Storytexte, Evolutionsfamilien.

### Was die Oberflächenprüfung (262 Prüfungen) abdeckt

Alle 15 Bildschirme (Hauptmenü, Credits, Schwierigkeit, Training, Starttalent,
Build-Übersicht, Rückfrage, Zwischensequenz, Levelabschluss, Abspann, Evolution,
Einstellungen in allen sechs Kategorien) werden aufgebaut und jedes angezeigte
Textfeld geprüft: kein roher Textschlüssel, kein ungefüllter Platzhalter.

---

## 2. Im laufenden Spiel geprüft

* Neun Screenshots aus Hauptmenü, Einstellungen, Level 1, 3, 8, Levelabschluss,
  Evolutionsauswahl, Boss Level 5 und Boss Level 10 (`docs/shots/`).
* Parallax-Hintergründe aller zehn Level sichtbar, drei Ebenen, kachelbar.
* HUD: Leben, Nektar, Punkte, Autofeuer-Anzeige, Waffenleiste mit neun Feldern,
  Auswahlhervorhebung, Kosten, Stufenpunkte, Detailzeile, Bossleiste mit Phase.
* Bildrate (Software-OpenGL, 1600×900): **144,9 fps** ohne und mit Zusatzlast
  (197 Geschosse, 16 Gegner); Prozessframe im Mittel 0,58 ms, p95 1,15 ms.
* Linux-Binärdatei startet aus einem leeren Ordner ohne Fehler (Rückgabewert 0).
* Windows-Binärdatei startet unter Wine 11 im Kopflauf ohne Fehler
  (nur zwei Aufräummeldungen der Engine beim Beenden).

---

## 3. Steuerung

| Anforderung | Stand | Nachweis |
|---|---|---|
| Linker Stick und Steuerkreuz bewegen | implementiert | Achsen- und Tastenbindungen in `Bindings.DEFAULTS` |
| Start pausiert | implementiert | `menu`-Aktion auf `JOY_BUTTON_START` und `Esc` |
| A tippen/halten feuert (kein Aufladen) | automatisiert geprüft | Dauerfeuer im Funktionstest |
| X schaltet Autofeuer | automatisiert geprüft | Autofeuer-Zustand wird gespeichert und angezeigt |
| LB/RB wählen Leistenfeld | automatisiert geprüft | `upgrade_prev`/`upgrade_next` im Test genutzt |
| RT kauft, Hysterese 0,6 / 0,3, ein Kauf je Druck | implementiert | Trigger-Hysterese in `bindings.gd` |
| B zurück | implementiert | `ui_cancel` auf `JOY_BUTTON_B` |
| LT Präzisionsflug | implementiert | `precision` auf `JOY_AXIS_TRIGGER_LEFT` |
| Tastatur vollständig | automatisiert geprüft | WASD/Pfeile, Esc, Leertaste, R, Q/E, F, Shift |
| Kein Eingabe-Übertrag zwischen Kontexten | automatisiert geprüft | `consume`/`block_until_release` im Funktionstest |
| Echte Controller-Hardware | **mangels Umgebung offen** | im Prüfrechner ist kein Gamepad angeschlossen |

Die Hysterese und die Einmal-Auslösung sind im Code nachvollziehbar, aber nicht
mit einem physischen Trigger gemessen – das steht unter „offen“.

---

## 4. Was offen bleibt (und warum)

| Punkt | Grund |
|---|---|
| Spielen mit echtem Gamepad | kein Controller an der Testmaschine |
| Interaktives Durchspielen von Hand | kein interaktives Fenster (Compositor liefert keine Bilder); Steuerung wird über die Automatik geprüft |
| Bildrate auf echter GPU in 1920×1080 | nur Software-Rendering verfügbar; die Messung fällt sehr hoch aus, ist aber nicht repräsentativ für Hardware |
| Windows nativ | nur Wine 11 verfügbar; als Wine-Test gekennzeichnet |
| Ton subjektiv beurteilen | keine hörbare Ausgabe in der Testumgebung; Effekte und Musik sind gemessen (Pegel, Länge, Format) |
| Auflösungen über 1600×900 | Anzeige der Testumgebung ist auf 1600×900 begrenzt; die Einstellungen reichen bis 3840×2160 |

---

## 5. Gefundene und behobene Fehler (Auszug)

Beim Prüfen gefundene echte Fehler, jeweils mit Ursache und Behebung:

1. **Kein einziges Menü war bedienbar sichtbar** – Bildschirme lagen in einer
   `CanvasLayer`, wo Anker nicht greifen; sie hatten Größe 0. Jetzt wird die
   Canvas-Größe beim Aufbau gesetzt und bei Größenänderung nachgeführt.
2. **Spielfeld nur halb hoch, alles verschoben** – die Layoutberechnung nutzte
   Gerätepixel statt Canvas-Einheiten; der Stretch-Modus skalierte doppelt.
3. **Hintergrund nur als Farbverlauf** – die Ebenen wurden über ein
   Sprite-Manifest gesucht, in dem sie nicht stehen. Jetzt werden
   `assets/bg/*.png` direkt geladen.
4. **Hintergrund nur 270 px hoch** – Zeichenskalierung 0,5 auf 1920×540-Ebenen.
   Ebenen werden nun in 960×540 geliefert und 1:1 gezeichnet.
5. **Wurzelmechanik wirkungslos** – Auslöser hieß `root_spikes`, die Behandlung
   `root_spike`. Namen angeglichen, jetzt durch die Inhaltsprüfung abgesichert.
6. **Schwierigkeitsbildschirm stürzte ab** – `d.desc` existiert in den Daten
   nicht; Beschreibung wird jetzt aus `diff.<stufe>.desc` gelesen.
7. **Rohe Textschlüssel in den Einstellungen** (`set.pixel_plus_ui`,
   `set.requires_restart`) – Skalierungsnamen werden übersetzt, Hinweise in der
   Wertspalte angezeigt und übersetzt.
8. **Vier Level nannten Formationen, die es nicht gab** (`pollen_pod`,
   `sluice_current`, `press_wall`, `core_pulse`) – Formationen ergänzt.
9. **Evolution mit ungültigem Synergieverweis** (`chitin_bastion` → `shield`)
   – auf `chitin_guard` korrigiert.
10. **Bossleiste überlappte die Detailzeile** – Bossleiste nach oben verschoben.

### Nachbesserungen nach der Spielprüfung des Betreibers

Elf gemeldete Punkte, jeder mit Ursache, Behebung und Nachweis:

| # | Meldung | Ursache | Behebung | Nachweis |
|---|---|---|---|---|
| 1 | Begleiter nicht sichtbar | Die Begleiter feuerten nur, es gab keinen Körper; zusätzlich zeigte `Sprite2D` den ganzen Bildstreifen | Vier Drohnenknoten je Begleiter, Position aus `companion_position`, Test prüft Sichtbarkeit | `fixprobe` 1, `mechanics` |
| 2 | Bereich der Leiste war Spielbereich | Spielfeld ging bis y=524, die Leiste lag darüber | `App.PLAY_BOTTOM = 452`, Grenzen für Spieler, Gegner, Gefahren, Kugeln; Leiste ist eine eigene dunkle Fläche | `fixprobe` 1, `mechanics` |
| 3 | Esc öffnet kein Menü | Niemand las die Menü-Taste im Spiel; zusätzlich gingen Tastendrücke verloren, wenn zwischen zwei Physikbildern kein Zeichenbild lag | Pause-Abfrage in `App._tick_pause_input`, Eingabe bleibt bis zum Verbrauch stehen | `fixprobe` 2, `smoke` |
| 4 | Kategorieleiste verschwand beim Scrollen | Die Leiste war eine Zeile im Scrollbereich | Leiste steht jetzt in der festen Kopfzeile (`header_note`) | `fixprobe` 5, `mouseprobe` |
| 5 | Evolutionswahl zu groß, Scrollen nötig | Karten untereinander in einer Liste | Dreispaltiges Gitter (`columns = 3`), kompakte Karten, Rewurf darunter; passt ohne Scrollen | `fixprobe` 4, Bild `fix_04_evolution.png` |
| 6 | Blitzwaffe ohne Mehrwert | Blitzschuss war nur ein schneller Schuss | Kettenblitz: 66 % auf den nächsten Gegner im Umkreis, von dort 33 %, sichtbarer Blitzbogen | `mechanics` (gemessen 66,0 % / 33,0 %) |
| 7 | Bossmusik startete mitten im Level | Der Miniboss spielte den Boss-Track, und alle Bosse teilten einen Titel | Miniboss behält die Levelmusik; jeder Boss hat einen eigenen Track `boss1`–`boss10` | `mechanics`, `docs/AUDIO.md` |
| 8 | Bosse doppelt dargestellt | `Sprite2D` zeichnete den 2-Bilder-Streifen als zwei Körper | Boss mit `AnimatedSprite2D` und Einzelbildern; ebenso Kugeln, Effekte, Pickups | `mechanics` (Bildbreite = ein Bild), `fix_03_boss.png` |
| 9 | Bosse zu ähnlich, nicht schwerer | Fünf Bosse teilten zwei Bewegungstypen, keine Levelskalierung | Fünf neue Bewegungsmuster (`guard_sweep`, `drifter`, `orbit`, `ram_line`, `weave`), pro Level +8 % Leben, Angriffstakt bis −38 %, Kugeln bis +31 % schneller | `mechanics` |
| 10 | Upgrades blieben über Level hinweg | Werte wurden ins Kampagnenprofil geschrieben | `App.reset_upgrades_for_new_level()` setzt gekaufte Upgrades auf Stufe 1, nicht gekaufte bleiben 0 | `mechanics` (fünf Prüfungen) |
| 11 | Menüs nicht mit der Maus bedienbar | Bildschirme kannten nur Tastatur/Gamepad | Zeiger hebt hervor, Klick löst aus, Rad bewegt den Fokus; Schalter reagieren auf Klick wie auf „rechts“ | `mouseprobe` (5 Prüfungen) |

| 22 | „Kaufen in der Werkstatt funktioniert nicht“ – Leertaste, `F`, Klick und Bestätigen lösten keinen Kauf aus | Rückmeldung des Betreibers nach der vierten Runde. Ursache: `ui_screen` leitet das Bestätigen bei Auswahlzeilen an `on_adjust(…, +1)` weiter und **nicht** an `on_activate`; die Kauf-Funktion hing aber an `on_activate`. Der Prüflauf hatte den Kauf direkt aufgerufen und deckte den Eingabeweg nicht ab | Kauf hängt jetzt an der Bestätigen-Route (`_activate` in der Werkstatt), Pfeil links/rechts blättert nur und kauft nie. Prüfung um echte Tastendrücke erweitert (Leertaste kauft, zweiter Druck hebt die Stufe, Pfeil rechts kauft nicht, Kauf nach einem Level kommt im nächsten Level an) | `shopprobe` (`SHOP: Leertaste kauft, Restpunkte 14500`), Bild `docs/shop_08_gekauft.png` (Punkte 26.000 → 20.500, Stufe 1/3) |
| 21 | Nach der Evolutionswahl fehlt eine Möglichkeit, Punkte in dauerhafte Verbesserungen zu stecken; „Fächerschu“/„Plasmawaff“ sind in der Leiste abgeschnitten; Plasma hat weder Streuung noch Wucht; F4 fehlt; der Boss erscheint ohne Ankündigung | Wunschliste des Auftraggebers (Runde 4) | Neue **Werkstatt** mit 32 Upgrades in drei Stufen und Vorbedingungsketten (`shop_data.gd`, `shop_screen.gd`), Preise an der ausgerechneten Levelausbeute ausgerichtet; **Kurznamen** in der Leiste, nicht bezahlbare Einträge grau; Plasma mit 15,5° Streuung und 18,4 Schaden; **Debugmenü auf F4**; **Bossankündigung** mit Rütteln, Weißblitz, Schriftzug und Warnton | `shopprobe`, `pointstable`, Bilder `docs/shop_01_werkstatt.png` … `docs/shop_03_boss.png` |
| 20 | Auflösung: Skalierung und Auswahl passen nicht, rechts springt sofort auf „Behalten/Standard“ | Drei Fehler zusammen: **(a)** Die Oberflächenskalierung wurde aus der Fensterhöhe berechnet, obwohl die Zeichenfläche immer 960 × 540 ist – im großen Fenster war die Oberfläche doppelt vergrößert und lief über den Rand. **(b)** Jeder Schritt links/rechts hat sofort übernommen und die Rückfrage geöffnet, die den Fokus übernahm. **(c)** Der Countdown-Text hatte keinen `%d`-Platzhalter, es gab also in jedem Bild einen Skriptfehler – die Rückfrage reagierte überhaupt nicht. | **(a)** feste Grundskala 1,0, neuer Helfer `pad()` für kleine Abstände, kompakte Zeilen; Menü und Einstellungen passen jetzt ohne Scrollen. **(b)** Werte werden nur vorgemerkt (Zeile zeigt den neuen Wert mit **•**, darunter *Anzeige übernehmen*), übernommen mit Leertaste/A; erst dann kommt die Rückfrage. **(c)** Countdown steht in der Fußzeile, Titel bleibt kurz, links/rechts wählt zwischen *Behalten* und *Zurück zum vorherigen Bild*. Zusätzlich: nur Auflösungen, die auf den Monitor passen, Fenster nie größer als der Monitor, „Anzeige testen“ entfällt (das Übernehmen zeigt die Rückfrage bereits) | `displayprobe` (23 Prüfungen), `layoutprobe`, Bilder `display_01_einstellungen.png`, `display_02_grosses_fenster.png`, `display_03_rueckfrage.png` |

### Zweite Runde: acht weitere Meldungen

| # | Meldung | Ursache | Behebung | Nachweis |
|---|---|---|---|---|
| 12 | Gegnerprojektile blinken und sind schlecht zu sehen | Die Geschosssprites haben zwei Bilder mit einem *rotierten* Muster; bei 14 Bildern/s wirkte das wie Blinken. Die Farben liefen zudem über eine dunkle Rampe mit fast schwarzem Rand | Geschosse stehen jetzt still (immer Einzelbild 0) und bekommen einen weichen Hof; die vier Geschosssprites wurden in Aseprite neu erzeugt: heller Körper (Mittelhelligkeit 0,74–0,93 statt ~0,3), weißer Kern, heller Rand | `mechanics`: „kein Einzelbildwechsel“, „hell und kontrastreich“ für alle vier; Bild `fix_03_boss.png` |
| 13 | Evolutionswahl reagiert auf hoch/runter statt links/rechts | Die Auswahl bewegte den Fokus linear durch die Liste, auch im dreispaltigen Gitter | Eigene Gitternavigation: links/rechts wandert zwischen den Karten, runter führt zur Zeile *Angebot neu ziehen*, hoch zurück in die letzte Kartenzeile; Hinweiszeile nennt die neuen Tasten | `mechanics`: Fokus 0→1→2→1 und runter auf 3 |
| 14 | Bosse wurden nur über mehr Leben härter | `max_hp` wuchs um 8 % je Level | Lebenspunkte sind jetzt levelunabhängig; die Härte kommt aus einer Bedrohungsstufe 1–5: dichterer Takt, zusätzliche Schlussphase, zweites Muster je Phase, Bewegungswechsel alle 7,5 s, mehr Kugeln | `mechanics`: gleiche HP, Stufe 1→5, mehr Phasen, mehr Muster, kürzere Pausen; gemessen 45 statt 2 gleichzeitige Kugeln |
| 15 | Hauptmenü wirkte wie ein Prototyp | Eine lange Liste über die volle Breite mit Scrollbalken, Beenden abgeschnitten | Kopfbereich in eine linke Spalte, Liste kompakt, rechts eine Statuskarte (Level, Evolutionen, Bestpunkte, Schwierigkeit, Fortschritt) mit Bienenbild; alles ohne Scrollen | Bild `docs/menu_neu.png`, `mouseprobe` |
| 16 | Schwerkraft/Strömung zu stark, kein Aufsteigen möglich | Der Wind schob mit bis zu 450 Einheiten/s bei 252 Flugtempo – Gegensteuern war wirkungslos | Strömung schiebt höchstens mit 62 % des Flugtempos, und wer gegensteuert, spürt nur noch 28 % davon | `mechanics`: „Gegensteuern fliegt bergauf“ (y 270 → 114) |
| 17 | Kein Punktegewinn aus übrigem Blütenstaub | Nektar wurde nur für Upgrades genutzt | Am Levelende rechnet ein mittig eingeblendetes Fenster den Rest in Punkte um (10 je Tropfen), zählt mit Ton hoch, zeigt *Punkte gutgeschrieben* und den neuen Punktestand; danach startet das nächste Level mit 0 Nektar | `flowprobe` (6 Prüfungen), Bilder `conv_01`, `conv_02` |
| 18 | Grashüpfer sprang unter die Upgradleiste | Nur ein Bewegungsmuster begrenzte die Höhe; Sprung- und Verfolgungsmuster setzten `position.y` frei | Jede Gegnerbewegung wird jetzt auf den Spielbereich begrenzt (Ausnahme: wer aus dem Boden bricht, darf kurz darunter starten), Startbahnen der Formationen sind ebenfalls begrenzt | `mechanics`: 8 Bewegungsmuster, tiefster Wert 445 < 450 |
| 26 | Kaufen in der Werkstatt tat nichts | Die Zeilenart *choice* wurde auf `on_adjust` geleitet, der Kauf lief ins Leere | Eigene `_activate()`-Behandlung in der Werkstatt; die Prüfung drückt jetzt echte Tasten | `shopprobe` (`SHOP_OK`) |
| 27 | Wellenschuss unsichtbar, Seitenstacheln blieben stehen | Die Welle wurde zeitbasiert gerechnet und die Seitenstacheln bekamen keine Bahn zugewiesen | Welle räumlich über den zurückgelegten Weg, jede Schussform mit eigener Bahn; 33 Einzelprüfungen | `upgradeprobe` (`UPGRADE_OK`) |
| 28 | Werkstatt-Upgrades ließen sich beliebig mischen | Kreisflug + Wellenschuss gleichzeitig ergab kein lesbares Muster | Gruppe *Grundform*: die erste gekaufte Form sperrt die anderen für den Lauf; rote Sperrliste im Tooltip, Hinweis vor dem Kauf | `upgradeprobe`, Bild `docs/r5_02_werkstatt_sperre.png` |
| 29 | Gefühl, auf der Stelle zu stehen | Der Hintergrund lief gar nicht – `Background.update()` wurde nie aufgerufen, und es gab nur drei langsame Ebenen | Fünf Ebenen mit eigenen Geschwindigkeiten (26 bis 380 px/s), zwei neue nahtlose Ebenen (Sporenschwaden, Halme/Blätter), Aufruf in der Spielschleife | `bgprobe` (`BG_OK`) |
| 30 | Eigene Schüsse sahen aus wie Blütenstaub | Beides war goldgelb | Vier neue, in Aseprite gezeichnete Geschosse in Weiß/Eisblau/Cyan mit dunkler Kante; Sammelobjekte leuchten warm | Bild `docs/r5_01_geschosse_nektar.png` |
| 31 | Boss „teleportierte“ beim Phasenwechsel, alte Kugeln verschwanden | `_apply_phase()` löschte alle Gegnerkugeln und die Bewegung sprang sofort auf das neue Musterziel | Weicher Übergang: 0,9 s Einblendung vom aktuellen Ort, Tempolimit 165 px/s, keine Kugeln mehr gelöscht | `bossprobe` (`BOSS_OK`) |
| 32 | Standardschriften wirkten beliebig | Godot-Standardschrift in allen Bildschirmen | Nunito (Text) und Oxanium (Überschriften) als freie Schriften mitgeliefert, variable Achse auf 420 gestellt, damit der Text nicht zu dünn wirkt | `fontshot`, Bilder `docs/font_01/02` |
| 33 | „In der Mitte zu leicht, Gegner sterben direkt beim Eintreten, Schüsse zu schnell, zu viele, zu viel Schaden“ – Meldung des Betreibers nach der fünften Runde | Es gab keine Kopplung zwischen Bewaffnung und Gegnern. Gemessen: Grundwaffe 125 Schaden je Sekunde, voll ausgebaute Werkstatt 1.449 (elf Mal so viel) gegen unveränderte 14 Lebenspunkte einer Motte – Abschuss in 0,01 s, noch vor dem ersten sichtbaren Bild. Dazu 19 Kugeln je Salve bei 12 Salven je Sekunde (246 Kugeln die Sekunde) | Lebenspunkte aller Gegner (auch Bosse und Zwischenbosse) hängen jetzt an der gemessenen Angriffskraft: `2,4 × (Angriffskraft/125)^0,95 × Ebenenfaktor`. Kugelzahl und Schussfolge sind gedeckelt (zwei Heckschüsse, zwei Seitenstacheln, ein Nebenlauf, Spirale jede dritte, Salve jede fünfte Salve, rund zehn Salven je Sekunde) | `BALANCE_OK` (Angriffskraft 125 → 1.449, Kugeln je Sekunde 15 → 107, Abschusszeit 0,27 s gegen 0,26 s), `LIVE_OK` (Start bis 12 Gegner gleichzeitig, voll ausgebaut 6, kein Gegner unter 0,35 s) |
| 34 | Werkstatt-Stufen wären nach dem Deckel wirkungslos geworden (Nebenbefund beim Prüfen von 33) | *Heckstachel* Stufe 3, *Seitenstachel* Stufe 2/3 und *Doppelläufe* Stufe 2/3 hätten Kugeln dazugelegt, die der Deckel nicht zulässt – der Käufer hätte Punkte für nichts bezahlt | Diese Stufen geben jetzt **Wucht**: eigene Mods `back_dmg`, `side_dmg`, `lane_dmg`; Beschreibungen im Shop entsprechend geändert | `UPGRADE_OK` 33/33 – „2 Heckschüsse“, „2 Seitenstacheln fliegen (von 2)“, „3 Geschosse gegen 2 ohne Doppelläufe“ |
| 35 | Nach dem Tod lief das Spiel ohne Grenze und ohne Entscheidung am Kontrollpunkt weiter; kein Game Over, kein Zurücknehmen der Leiste | Der Ablauf kannte nur „nach zwei Sekunden wiederherstellen“; es gab keinen Zähler und keinen Bildschirm | Game-Over-Bildschirm mit **Weiter am Kontrollpunkt** (setzt die taktischen Upgrades zurück, Werkstatt und Evolutionen bleiben) und **Run beenden**. Zähler `deaths` in der Kampagne, nach dem dritten Game Over kein Weiter mehr | `GAMEOVER_OK` (16 Prüfungen), Bilder `docs/go_01_gameover.png`, `docs/go_02_kein_weiter.png` |
| 36 | Prüflauf „Gegner kann zerstört werden“ war unzuverlässig (ein Fehlschlag von drei Läufen) | Er wartete auf die erste Welle des Levels; die fliegt je nach Zufall ober- oder unterhalb der Schusslinie vorbei. Zusätzlich zählte er Bilder statt Zeit, im Kopflos-Lauf laufen die Bilder aber viel schneller als 60 je Sekunde | Der Prüflauf setzt einen eigenen Gegner in die Schusslinie und wartet zeitbasiert (12 s) | `SMOKE_OK`, dreimal hintereinander 46 von 46 Prüfungen |

---

## 6. Reproduktion

```bash
export XDG_DATA_HOME="$PWD/.godot_data"
godot --headless --path . res://tests/smoke.tscn
godot --headless --path . res://tests/content.tscn
godot --headless --path . res://tests/ui_text.tscn
godot --headless --path . res://tests/campaign.tscn
godot --headless --path . res://tests/ending.tscn
godot --headless --path . res://tests/builds.tscn
godot --headless --path . res://tests/mechanics.tscn
godot --headless --path . res://tests/flowprobe.tscn
godot --headless --path . res://tests/shopprobe.tscn
godot --headless --path . res://tests/upgradeprobe.tscn
godot --headless --path . res://tests/bossprobe.tscn
godot --headless --path . res://tests/pointstable.tscn
godot --path . res://tests/mouseprobe.tscn        # braucht ein Fenster
godot --path . res://tests/fixprobe.tscn          # braucht ein Fenster
godot --path . res://tests/menushot.tscn          # Bild des Hauptmenüs
godot --path . res://tests/convshot.tscn          # Bilder der Umrechnung
XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 godot --path . res://tests/perf.tscn
XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 godot --path . res://tests/shots.tscn
XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 godot --path . res://tests/bgprobe.tscn
XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 godot --path . res://tests/fontshot.tscn
XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 godot --path . res://tests/r5shots.tscn
```

Jedes Prüfskript endet mit Rückgabewert 0 und einer `*_OK`-Zeile.
