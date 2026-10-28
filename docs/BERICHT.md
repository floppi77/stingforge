# Stingforge – Abschlussbericht

**Evolve. Adapt. Strike.**

Der aktuelle Zusatzauftrag und seine Messwerte stehen im
[Stingforge-Bericht](<STINGFORGE.md>). Er ersetzt die historische Balanceformel
und die Aussagen zu unveränderter Spiellogik aus den vorherigen UI-Runden weiter
unten. Aktuell sind Verfolger, Fähigkeiten und Bosskollisionen korrigiert, das
HUD besitzt einen eigenen Bereich, Spielerbiene und Branding sind erneuert.
Vorhandene Spielstände werden nicht-destruktiv übernommen.

Ein modernes horizontales Shoot'em Up als Nachfolger des Amiga-Klassikers *Apidya*:
Yuri, eine Feldbiene, fliegt durch zehn Reiche gegen eine Welt aus Stahl, Sporen und
Maschinen. Ausgeliefert als zwei lauffähige Einzeldateien.

* **Windows:** `release/Stingforge.exe` (133.0 MiB, PCK eingebettet)
* **Linux:** `release/Stingforge.x86_64` (98.9 MiB, PCK eingebettet)
* Prüfsummen: `release/SHA256SUMS.txt`

Beide Dateien starten ohne Installation und ohne weitere Dateien.

---

## 1. Was gebaut wurde

### Spiel

| Bereich | Umfang |
|---|---|
| Level | 10 handgebaute Level, je 5 Abschnitte, 276–282 s Niveauzeit + Boss (rund 6–7 Minuten Spielzeit je Level) |
| Kampagne | Zwischensequenzen, Zwischenbosse, Checkpoints, Levelabschluss mit Wertung, Abspann – 60–90 Minuten |
| Gegner | 25 Typen, 17 Verhaltensmuster, 30 Formationsdefinitionen |
| Bosse | 10 Endbosse mit 2–3 Phasen, je 6–8 Angriffsmustern; einige mit Zusatzmodulen |
| Mechaniken | 10 Levelmechaniken: Blüten, Wurzeln, Wasser, Sporen, Wind, Glas, Strömung, Ordnung, kombiniert, Kern |
| Waffenleiste | 9 Einträge, 3 Stufen je Waffe, Nektar als Währung, bleibt über Level und Checkpoints |
| Evolutionen | 36 in 6 Familien, 3 Angebote je Levelabschluss, ein Neuwurf, 3 Starttalente, Profilfreischaltung |
| Modi | Neue Kampagne, Fortsetzen, Training (getrennt), Boss-Rush (10 Bosse), Einstellungen, Credits |
| Schwierigkeit | Entspannt (4 HP), Normal (3 HP), Experte (3 HP, schnellere Muster) |
| Einstellungen | 6 Kategorien, ~40 Einzeloptionen, Umbelegung, Zugänglichkeit, Rücknahme der Anzeige nach 15 s |

### Technik

* Godot 4.7.2, GL-Compatibility-Renderer, GDScript.
* Welt in einem `SubViewport` mit 960×540 logischen Pixeln, ganzzahlig auf 16:9
  skaliert (1280×720 bis 3840×2160), Nearest-Filter, UI in Canvas-Einheiten.
* Sechs Autoloads (`Loc`, `Data`, `Save`, `Bindings`, `Audio`, `App`), Bildschirme
  als Stapel mit Eingabesperre: jede bestätigende Taste muss losgelassen werden,
  bevor sie in einem neuen Kontext wirkt.
* Trigger mit Hysterese (Auslösen ab 60 %, erneut scharf unter 30 %), ein Kauf je
  Druck; Präzisionsflug auf LT.
* Speicherstände als JSON (Profil, Kampagne, Einstellungen), Belohnungen genau
  einmal je Level, offene Evolutionsentscheidung wird wiederhergestellt.

### Inhalte (alle selbst erzeugt)

| Art | Umfang | Quelle |
|---|---|---|
| Sprites | 68 (Animationen als Streifen, `manifest.json`) | Aseprite, `tools/aseprite/gen_sprites.lua`, 68 `.aseprite`-Quellen |
| Hintergründe | 30 Ebenen (3 pro Level, 960×540, kachelbar) | Blender 5.2 (`assets/blender/l01–l10.blend`), Palettenreduktion |
| Musik | 14 Stücke (10 Level, Menü, Boss, Abspann, Levelabschluss) als OGG | eigene Synthese (`tools/audio/songs/*.py`) |
| Effekte | 26 WAV | eigene Synthese (`tools/audio/synth.py`) |
| UI | Logo, Icon, Leisten-Icons, Rahmen | Aseprite |

---

## 2. Nachweise

Alles Folgende ist gemessen, nicht behauptet. Details im
[Testprotokoll](TESTPROTOKOLL.md).

| Prüfung | Ergebnis |
|---|---|
| Funktionstest (46 Prüfungen) | `SMOKE_OK` |
| Inhaltsprüfung (1124 Prüfungen: Daten, Assets, Ton, Texte, Code-Abdeckung) | `CONTENT_OK` |
| Oberflächentexte aller 15 Bildschirme (262 Prüfungen) | `UI_OK` |
| Spielmechanik der Nachbesserungen (35 Prüfungen) | `MECHANIK_OK` – Kettenblitz 66,0 %/33,0 %, Upgrade-Rücksetzung, zehn Boss-Titel, Bedrohungsstufen statt Lebenspunkten, helle stehende Geschosse, Gitternavigation, Gegnergrenzen, Gegensteuern im Wind, Dichte des Bossfeuers gemessen (45 statt 2 Kugeln gleichzeitig) |
| Anzeige-Einstellungen (23 Prüfungen) | `ANZEIGE_OK` – Schriftgröße unabhängig von der Fenstergröße, nur passende Auflösungen, Vormerken statt Sofort-Übernehmen, Rückfrage mit Countdown und links/rechts wählbar |
| Bildschirmaufteilung | `LAYOUT_OK` – kein Scrollen in Hauptmenü, Einstellungen, Credits, Evolutionswahl |
| Ablauf am Levelende (6 Prüfungen) | `ABLAUF_OK` – Umrechnung erscheint, Nektar auf 0, Punkte gutgeschrieben, Evolutionswahl, Abschlussbildschirm |
| Mausbedienung im laufenden Fenster (5 Prüfungen) | `MAUS_OK` – Hover, Klick, Mausrad, Zurück, Hauptmenü |
| Bildprüfung der Nachbesserungen (6 Bilder) | `FIXES_OK` |
| Kampagne komplett automatisch durchgespielt | `CAMPAIGN_OK` – 10/10 Level, 10 Evolutionen, `completed=true` |
| Abspann und Boss-Rush | `ENDING_OK` – Freischaltung gesetzt, 10 Bosse besiegt |
| Drei unterschiedliche Builds im Kampf | `BUILDS_OK` – Fächer/Schild 8, Plasma/Begleiter 6, Blitz/Bomben 4 Abschüsse in 14 s |
| Fünf Saatwerte für Evolutionsangebote | im Funktionstest geprüft, unterschiedliche Angebote |
| Bildrate (Software-OpenGL, 1600×900) | 144,9 fps; Prozessframe 0,58 ms im Mittel, p95 1,15 ms (auch mit 197 Geschossen und 16 Gegnern) |
| Linux-Binärdatei aus leerem Ordner | startet, Rückgabewert 0, keine Skriptfehler (26. Okt., 96,2 MiB) |
| Windows-Binärdatei unter Wine 11 | startet, Rückgabewert 0, keine Skriptfehler (26. Okt., 130,3 MiB) |
| Screenshots | 9 Bilder in `docs/shots/` aus Menü, Einstellungen, vier Leveln, zwei Bossen, Evolutionsauswahl, Levelabschluss |
| Musik | 24 vorgerenderte Titel, davon 10 eigene Boss-Titel; jeder Titel gemessen (Peak, RMS, Schleifennaht) |

---

### Hauptmenü nach gelieferter Bildvorlage

Der Betreiber hat die gewünschte Richtung mit einer konkreten Layoutgrafik und
anschließend einem sauberen Hintergrundmotiv präzisiert. Das Hauptmenü verwendet
nun genau diesen Hintergrund: große Biene im Sonnenlicht vor überwucherten
Industrieruinen, goldener Titel links oben, freie linke Menüliste, nur eine goldene
Fokuszeile und eine transparente Statuskarte unten rechts. Die Bildvorlage wurde
nicht als unbeweglicher Menü-Screenshot übernommen: alle Texte und Profilwerte
werden im Spiel gesetzt, alle Aktionen funktionieren weiterhin. Tastatur und
Xbox bleiben gleichzeitig sichtbar. Ohne Spielstand ist Fortsetzen gesperrt und
Neue Kampagne vorausgewählt.

Die eigenen Bildprüfungen zeigen aktive Kampagne, neues Profil, größere Schrift,
Run-Ende-Notiz und geänderte Speicherstände. 506 Prüfungen headless, 524 im Fenster.
Andere Menüs, HUD und sämtliche Spiellogik bleiben gegenüber dem vorigen Stand
unverändert. [Aktuelles Menübild](<ui-reference/showcase.png>).

### UI-Redesign: Menüs, HUD und Xbox-Tasten

Ausschließlich die Darstellung wurde überarbeitet: Petrolflächen mit dezentem
Wabenmuster, gerundete Karten, warme goldene Auswahl, klare Profilkarte,
optische Einstellungsreiter und ein neu gegliedertes HUD. Die variable
Schriftgewichtsachse wird nun mit dem von Godot erwarteten numerischen
OpenType-Tag angesprochen; damit sind normale, halbfette und fette Texte endlich
auch tatsächlich unterschiedlich kräftig.

Tastatur und Xbox-Gamepad stehen immer nebeneinander, nicht nur für das zuletzt
benutzte Gerät. Farbige A/B/X/Y-Kreise und Kapseln für LB/RB/LT/RT lesen die
aktuelle Belegung aus der bestehenden Eingabeschicht. Die Belegungsübersicht
zeigt zwei getrennte Spalten, bei großer Schrift zwei Zeilen pro Aktion.

Spielablauf, Balance, Gegner, Speicher- und Eingabelogik bleiben unangetastet.
Ein Quellvergleich sichert 18 unveränderte Dateien der Spiellogik und 42
unveränderte Eingabe-/Zustandsfunktionen in den UI-Dateien ab. Prüfskripte nutzen
separate Testspielstände. Details und Bildnachweise im
[UI-Redesign-Bericht](<UI_REDESIGN.md>).

### Nachbesserungen aus der Spielprüfung des Betreibers

Elf gemeldete Punkte wurden behoben und belegt (Details je Punkt in
`docs/TESTPROTOKOLL.md`, Abschnitt 5):

* Begleiterdrohnen sind sichtbar, der untere Leistenbereich ist kein Spielfeld
  mehr, Esc öffnet das Pausenmenü, die Kategorieleiste der Einstellungen bleibt
  beim Scrollen stehen, die Evolutionswahl zeigt drei Karten nebeneinander ohne
  Scrollen, die Blitzwaffe springt mit 66 % auf den nächsten und mit 33 % auf
  den übernächsten Gegner, jeder Boss hat eigene Musik die erst beim Boss
  beginnt, Bosse werden einfach dargestellt, sie unterscheiden sich in der
  Bewegung und werden je Level härter, gekaufte Upgrades starten in jedem neuen
  Level auf Stufe 1, und alle Menüs sind mit der Maus bedienbar.

Dabei kam ein grundsätzlicher Eingabefehler zum Vorschein: Tastendrücke gingen
verloren, wenn zwischen zwei Physikbildern kein Zeichenbild lag. Das betraf bei
Software-Darstellung auch Sprung, Kauf und Bestätigen. Der Auslöser bleibt jetzt
stehen, bis er verbraucht ist.

### Vierte Runde (Nachtrag)

**Der gemeldete Kauf-Fehler.** In der Werkstatt kaufte keine Taste etwas. Ursache
war eine Schnittstelle im Oberflächengerüst: Bei Auswahlzeilen leitet das
Bestätigen (`_activate`) auf `on_adjust(…, +1)` weiter, nicht auf `on_activate` –
die Kauf-Funktion hing aber an `on_activate` und wurde so nie erreicht. Der
Prüflauf hatte den Kauf direkt aufgerufen und den Eingabeweg damit übersprungen;
das ist die eigentliche Lehre daraus, und `shopprobe` drückt jetzt echte Tasten.
Neu: Bestätigen kauft (`_activate`), Pfeil links/rechts blättert nur und löst
keinen Kauf aus.

### Sechste Runde

**Zwei Meldungen, ein gemeinsamer Kern: das Spiel wurde in der Mitte zu leicht.**

**Die Ursache war messbar.** Es gab keine Kopplung zwischen Bewaffnung und
Gegnern: ein Gegner hatte immer dieselben Lebenspunkte, egal ob die Biene die
Grundwaffe trug oder eine voll ausgebaute Werkstatt. Gemessen an einer Salve:
Grundbewaffnung 125 Schaden je Sekunde, mit allem Gekauften **1.449** – das
Elffache, gegen unveränderte 14 Lebenspunkte einer Motte. Die fiel damit in
0,01 Sekunden, also noch vor dem ersten sichtbaren Bild. Dazu kamen **19 Kugeln
je Salve** bei 12 Salven je Sekunde: 246 Kugeln die Sekunde. Das Spiel war nicht
schwer oder leicht, es war entwertet.

**Die Kopplung.** Das Spiel misst jetzt laufend die eigene **Angriffskraft**
(Schaden aller Kugeln einer Salve geteilt durch die Schussfolge, mit
Volltreffer-Erwartung) und setzt die Lebenspunkte neuer Gegner ins Verhältnis:
`2,4 × (Angriffskraft / 125)^0,95 × (Schaden je Kugel / 7,4)^0,25 × Ebenenfaktor`.
Der Rate-Exponent ist absichtlich knapp unter 1 – Verbesserungen sollen sich in
kürzeren Kämpfen zeigen, aber nicht im Nichts. Der zweite Faktor zählt den
**Schaden je Kugel** mit: wenige starke Kugeln sind etwas anderes als viele
schwache, auch bei gleichem Gesamtschaden. Bosse und Zwischenbosse hängen an derselben Kennzahl; bisher wuchsen
sie nur mit den Evolutionen (6 % je Evolution) und waren mit voller Werkstatt in
anderthalb Sekunden erledigt.

**Gedeckelt statt gestrichen.** Kugelzahl und Schussfolge haben jetzt Obergrenzen:
zwei Heckschüsse, zwei Seitenstacheln, ein Nebenlauf, Spirale nur jede dritte
Salve, Salve nur jede fünfte, höchstens etwa zehn Salven je Sekunde. Wichtig
dabei: die betroffenen Werkstatt-Einträge **verkaufen keine wirkungslosen
Stufen** mehr. Wo die dritte Stufe keine weitere Kugel mehr hinzufügen darf,
gibt sie **Wucht** – „Die Heckschüsse schlagen deutlich härter ein“. Damit bleibt
jeder Kauf etwas wert, und das Bild bleibt lesbar.

**Gemessen statt geschätzt.** Zwei neue Prüfläufe:
`balanceprobe` rechnet vier Ausbaustufen durch (Angriffskraft 125 → 1.843 das
14,7-fache, Kugeln je Sekunde 15 → 107, Lebenspunkte einer Motte 34 → 625,
Abschusszeit 0,27 s bis 0,34 s), `liveprobe` spielt je 40 Sekunden echtes Level
und zählt das Gedränge: Start bis zu 12 Gegner gleichzeitig im Bild (Ø 4,4),
voll ausgebaut 6 (Ø 1,7), **kein** Gegner unter 0,35 Sekunden Lebensdauer. Der Gegner kommt also an, schießt und wird bekämpft.

**Game Over mit drei Versuchen.** Bisher lief das Spiel nach dem Tod still am
Kontrollpunkt weiter – ohne Grenze, ohne Entscheidung. Jetzt gibt es einen
Game-Over-Bildschirm:

* **Weiter am Kontrollpunkt** – aber die **taktischen Upgrades der unteren Leiste
  starten neu** (Stufe 1, Nektar 0). Werkstatt-Käufe und Evolutionen bleiben.
* **Run beenden** – Kampagne gelöscht, zurück ins Hauptmenü, Profil bleibt.
* **Nach dem dritten Game Over** gibt es kein Weiter mehr; der Bildschirm bietet
  nur noch „Zum Hauptmenü“, der Lauf ist vorbei.

Der Schnitt zwischen den beiden Ebenen ist der Punkt: die Leiste ist Aufbau
*innerhalb* eines Levels und darf verfallen, die Werkstatt ist mit Punkten über
den ganzen Lauf bezahlt und darf es nicht. Geprüft in `gameoverprobe` (16
Prüfungen) und auf zwei Bildern (`docs/go_01_gameover.png`,
`docs/go_02_kein_weiter.png`).

**Nebenbefund.** Der Prüflauf „Gegner kann zerstört werden“ verließ sich darauf,
dass die erste Welle des Levels in der Schusslinie vorbeikommt – das tat sie
nicht immer. Er setzt jetzt einen eigenen Gegner in die Schusslinie; damit ist die
Prüfung reproduzierbar (dreimal hintereinander grün).

### Fünfte Runde

**Sechs Meldungen, vier davon Fehler.** Der Bericht des Betreibers nach der
vierten Runde war ungewöhnlich konkret – das war hilfreich, weil drei der Punkte
dieselbe Wurzel hatten: Dinge, die gebaut, aber nie aufgerufen oder nie gemessen
wurden.

**Kaufen in der Werkstatt.** Der Kauf hing an der falschen Stelle im
Oberflächengerüst; behoben und mit echten Tastendrücken geprüft.

**Wellenschuss und Seitenstacheln.** Die Welle wurde über die Zeit statt über
den zurückgelegten Weg gerechnet und zerfiel damit bei Geschwindigkeitswechseln
zu einem Zittern; die Seitenstacheln bekamen keine Bahn zugewiesen und standen
still. Beides behoben.

**Sämtliche Werkstatt-Upgrades einzeln geprüft.** Das ist der eigentliche Kern
dieser Runde: ein neuer Prüflauf `upgradeprobe` misst **jedes** der 33 Upgrades
einzeln im laufenden Spiel – nicht „ist der Wert gesetzt“, sondern „was macht das
Geschoss tatsächlich“. Beispiele: Kreisradius 86 px, Wellenauslenkung 17 px bei
266 px Flug, Auslenkung mit *Weite Wellen* 72 statt 44 px, drei Heckschüsse, zwei
von vier Seitenstacheln unterwegs (die anderen zwei sind die Rückseite), Salve mit
2 Projektilen, 4 Splitter, Krit 33 % (Sollwert 30 %), Bossbonus 150 statt 100,
Feuerrate 0,081 s statt 0,118 s, Schildaufladung 3,0 statt 1,0, Bombenladezeit
10,3 statt 17,0 s, Magnetradius 210 statt 70, Serienfenster 75 statt 60 Bilder.
33 von 33 bestanden.

Dabei kam eine echte Unverträglichkeit heraus: *Kreisflug*, *Wellenschuss* und
*Zielsuche* legen alle dieselbe Sache fest – die Flugbahn der Hauptschüsse.
Zusammen ergeben sie kein Muster, sondern ein Durcheinander. Deshalb gibt es jetzt
die Gruppe **Grundform**: die erste gekaufte Form **sperrt** die anderen für den
restlichen Lauf. Das ist keine Verlegenheitslösung, sondern die ehrliche Antwort
auf „wenn es nicht funktioniert, muss es gesperrt werden“ – und zwar sichtbar:
Gesperrte Einträge stehen rot mit „Gesperrt für diesen Lauf“, und **vor** dem Kauf
steht im Beschreibungsfeld rot, was der Kauf sperrt. Im Debug-Menü (`F4`) gelten
die Sperren nicht, damit sich Kombinationen weiter testen lassen.

**Parallax.** Der wichtigste Befund dieser Runde war unangenehm: `Background.update()`
wurde **überhaupt nie aufgerufen**. Der Hintergrund stand also nicht nur langsam,
er stand still – kein Wunder, dass sich Fliegen wie Stehen anfühlte. Jetzt läuft er
mit **fünf Ebenen** (Ferne 26 px/s, Sporenschwaden 62, Landschaft 120, Vordergrund
235, dunkle Halme 380) und zwei neuen, nahtlos kachelbaren Ebenen. Die Ebenen
werden aus dem Levelschlüssel bzw. aus zwei neuen Bildern geladen und nehmen die
Farben des Levels an. Gemessen: in einer halben Sekunde 12,6 px in der Ferne gegen
183,7 px ganz vorn.

**Geschosse gegen Blütenstaub.** Beides war goldgelb – auf einem vollen Bild nicht
zu unterscheiden. Die vier Geschosstypen sind neu gezeichnet (Aseprite, Pixel für
Pixel): weißer Kern, eisblauer Rand, dunkle Kante, also kalt; Blütenstaub und
Nektarblüten bleiben warm und bekommen einen weichen Schein.

**Beleuchtung, dezent.** Ein weicher Lichteinfall von oben und eine leichte
Vignette fassen das Bild, Sammelobjekte leuchten. Alles über einen Schalter
abschaltbar (**Einstellungen → Grafik → Beleuchtung & Schatten**).

**Nebenbefund beim Prüfen der Bilder.** Mit der neuen Schrift brauchte das
Hauptmenü 296 Punkte Höhe bei 287 verfügbaren – der letzte Eintrag *Spiel
beenden* war wieder halb abgeschnitten. Die kompakten Zeilen haben jetzt 3 statt
4 Punkte Rand oben und unten; gemessen 280 von 287, also ohne Scrollbalken.

**Schriften.** Statt der Godot-Standardschrift jetzt **Nunito** für Text und
**Oxanium** für Überschriften – beide frei (SIL Open Font License) und
mitgeliefert, also ohne Systemschrift. Die variable Achse steht bei Text auf 420,
sonst wirkt die Schrift zu dünn.

**Boss-Phasenwechsel (Zusatzauftrag).** Zwei Dinge störten: Der Boss sprang beim
Phasenwechsel an eine Ausgangsposition, und alle Gegnerkugeln der alten Phase
verschwanden. Jetzt blendet die Bewegung über 0,9 Sekunden vom aktuellen Ort ins
neue Muster ein (Tempolimit 165 px/s) und **keine** Kugel wird mehr gelöscht –
gemessen: erster Schritt 0,1 px, größter Satz 2,4 px je Bild, Kugeln 3 → 6.

### Vierte Runde

**Werkstatt.** Nach der Evolutionswahl und der Levelabrechnung öffnet sich ein
Shop, in dem **Punkte** (nicht Blütenstaub) in dauerhafte Verbesserungen fließen.
32 Upgrades, jedes in drei Stufen, in fünf Gruppen. Die Stufen sind bewusst keine
Prozentpunkte: *Kreisflug* lässt die Schüsse erst in mittlerem, dann in großem
Radius um die Biene kreisen und zuletzt schneller laufen; *Wellenschuss* schickt
sie in einer Welle, die über die Zusatzketten *Weite Wellen* und *Schnelle Wellen*
weiter geformt wird. Vier Einträge sind über Vorbedingungen verkettet
(*Wellenschuss → Schnelle/Weite Wellen*, *Schwere Geschosse → Panzerbrecher*,
*Zielsuche → Starke Zielsuche*); gesperrte Zeilen nennen die Bedingung.

Die Preise stehen auf einer **Rechnung** statt auf Bauchgefühl: ein Prüfskript
summiert aus den Leveldaten (Wellenpläne × Gegnerwert + Nektarumrechnung +
Bossprämie), was ein Level höchstens einbringt – 35.370 (Level 1) bis 87.583
(Level 10), zusammen 523.924 Punkte. Die Werkstatt kostet komplett 905.000
Punkte, also rund das 1,7-fache eines perfekten Durchlaufs und etwa das
3,6-fache eines guten. Damit ist eine erste Stufe (2.500–6.000) nach *einem*
Level drin, die dritte (10.000–24.000) will gespart sein, und „alles kaufen“ geht
bewusst nicht.

**Waffenleiste.** Die Namen sind jetzt kurz (Basis, Fächer, Blitz, Plasma, Drohne,
Bombe, Schild, Tempo, Reparatur) und passen in die Felder. Einträge, die du im
Moment nicht bezahlen kannst, bleiben **grau, aber lesbar**; sobald genug
Blütenstaub da ist, leuchten Rahmen, Name und Preis gold.

**Plasmawaffe.** Sie streut jetzt leicht – 15,5° gesamt gegen 55° beim
Fächerschuss, also 28 % davon – und macht mit 18,4 je Kugel deutlich mehr Schaden
als vorher (15,0).

**Debugmenü auf F4.** Das Spiel hält an, eine Liste bietet *Zum Levelboss*, *Zum
nächsten Level*, *Vollheilen* sowie **jedes** Taktik- und Kauf-Upgrade mit
Beschreibung in der rechten Spalte; links/rechts stellt die Stufe ein, Änderungen
gelten sofort und landen im Spielstand.

**Bossankündigung.** Vor dem Boss rüttelt der Bildschirm, das Bild blitzt weiß
auf, ein großes **BOSS** steht im Bild und ein Warnton läuft; das Feld ist dabei
geräumt, der Boss kommt erst danach.

**Leistung.** Mit *allen* 32 Werkstatt-Upgrades auf Stufe 3, Bosskampf, 337
Geschossen und 1.954 Objekten gleichzeitig läuft das Spiel bei 1920 × 1080 mit
**96,0 Bildern je Sekunde** – auch auf der Software-Darstellung dieser Umgebung
(Mesa llvmpipe, keine GPU).

**Nebenbefund.** Die taktische Stufe *Bomben* war seit Runde 1 kaufbar, hatte aber
keine Wirkung. Sie löst jetzt automatisch eine Druckwelle aus (17 s minus 2 s je
Stufe, Beschleunigung über *Bombenlager*), die gegnerisches Feuer im Umkreis
räumt.

### Dritte Runde

Die Anzeige-Einstellungen waren unbrauchbar, aus drei Gründen, die sich
gegenseitig verstärkt haben:

* Die **Oberflächenskalierung** wurde aus der Fensterhöhe berechnet, obwohl die
  Zeichenfläche fest 960 × 540 Punkte groß ist und das Fenster nur vergrößert
  wird. Auf einem hohen Fenster war die Oberfläche dadurch doppelt so groß wie
  gedacht und lief rechts und unten aus dem Bild – im Bild des Betreibers waren
  die Menüzeilen riesig und abgeschnitten. Die Grundskala ist jetzt fest 1,0; nur
  die Einstellung *UI-Größe* ändert sie noch.
* Jeder Druck auf links/rechts hat die Auflösung **sofort übernommen** und die
  Rückfrage geöffnet. Diese Rückfrage nahm den Fokus, also führte der nächste
  Druck nicht mehr zur Auflösungszeile. Jetzt werden Monitor, Auflösung und
  Fenstermodus nur **vorgemerkt** (sichtbar an einem **•** und der Zeile
  *Anzeige übernehmen*); übernommen wird mit Leertaste/A, und erst dann kommt die
  Rückfrage.
* Der Countdown der Rückfrage hatte keinen `%d`-Platzhalter im Text. Das erzeugt
  in jedem Bild einen Skriptfehler, wodurch die Rückfrage **gar nicht** auf
  Eingaben reagierte. Der Countdown steht jetzt in der Fußzeile, der Titel bleibt
  kurz, und links/rechts wählt zwischen *Behalten* und *Zurück zum vorherigen
  Bild*.

Dazu: angeboten werden nur Auflösungen, die auf den Monitor passen, das Fenster
wird nie größer als der Monitor, und die Zeilen sind so bemessen, dass Hauptmenü
(239 von 288 Punkten) und Anzeige-Einstellungen (340 von 341) **ohne Scrollen**
passen. Beim Prüfen fiel außerdem auf, dass ein fremder Projektordner
(`Astra/`, rund 1 GB) im Projektverzeichnis lag und mit in die fertigen Dateien
gepackt wurde – er ist jetzt vom Export ausgeschlossen.

### Zweite Runde

Acht weitere Punkte aus der Spielprüfung:

* **Gegnerprojektile** stehen still – sie blinkten, weil ein rotierendes
  Zweitbild durchlief – und sind deutlich heller: neu gezeichnet mit weißem Kern,
  hellem Rand und weichem Hof.
* Die **Evolutionswahl** wird mit links/rechts durchwandert, runter geht auf
  *Angebot neu ziehen*.
* **Bosse** werden nicht mehr über Lebenspunkte härter, sondern über eine
  Bedrohungsstufe 1–5: zusätzliche Schlussphase, zweites Muster je Phase,
  Bewegungswechsel im Kampf, dichterer Takt, mehr und schnellere Kugeln.
* Das **Hauptmenü** hat eine linke Spalte mit Logo und kompakter Liste und rechts
  eine Statuskarte; es passt ohne Scrollen.
* **Wind und Strömung** schieben höchstens mit 62 % des Flugtempos, Gegensteuern
  wirkt – die Biene kommt auch gegen starke Schwerkraft noch langsam nach oben.
* Am **Levelende** wird der restliche Blütenstaub mittig, animiert und mit Ton in
  Punkte umgerechnet (10 je Tropfen); das nächste Level startet bei 0.
* **Gegner** bleiben jetzt in jedem Bewegungsmuster über der Waffenleiste.

## 3. Was ausdrücklich offen bleibt

Ehrlich benannt, weil die Testumgebung es nicht hergibt:

1. **Spielen von Hand mit Gamepad.** An der Testmaschine ist kein Controller
   angeschlossen. Alle Eingabewege sind im Code vorhanden und werden automatisch
   durchlaufen, aber nicht mit echter Hardware gefühlt.
2. **Interaktives Durchspielen.** Die Testumgebung hat keine echte Grafikausgabe
   (Compositor liefert keine Bilder, gerendert wird per Software). Screenshots
   entstehen über einen erzwungenen Zeichenschritt; gespielt wird automatisiert.
3. **Bildrate auf echter GPU in 1920×1080.** Die 144,9 fps sind mit Software-Rendering
   gemessen und werden von der Bildwiederholrate begrenzt; sie belegen, dass die
   Prozesslast klein ist (unter 1,2 ms), ersetzen aber keine Messung auf einer
   RTX 4090. 60 fps bei 1920×1080 sind nach dieser Lastkurve sehr wahrscheinlich,
   aber nicht bewiesen.
4. **Windows ohne Wine.** Es steht nur Wine 11 zur Verfügung.
5. **Ton subjektiv.** Formate, Längen und Pegel sind gemessen und geprüft; wie das
   Spiel klingt, konnte hier niemand hören.
6. **Auflösungen oberhalb 1600×900.** Die Anzeige der Testumgebung ist begrenzt;
   die Einstellungen reichen bis 3840×2160, geprüft sind 1600×900.
7. **Zwei Aufräummeldungen beim Beenden** („resources still in use“) stammen von
   statischen Caches der Engine-Anbindung; sie treten in beiden Builds auf und
   beeinflussen das Spiel nicht.

---

## 4. Abweichungen vom Auftrag

* **Screenshot-Auflösung:** gewünscht 1920×1080, geliefert 1600×900 – das ist die
  maximale Ausgabe der Testumgebung. Das Spiel selbst läuft auf 1920×1080
  konfiguriert; die interne Welt ist ohnehin 960×540 und wird hochskaliert.
* **Leveldauer:** zunächst 3,5 Minuten je Level, nachgezogen auf rund 6–7 Minuten,
  damit die Vorgabe 6–9 Minuten erreicht wird.
* **Boss-Rush-Freischaltung** wird beim Abspann gesetzt (nicht schon beim Besiegen
  des letzten Bosses); wer nach dem letzten Boss abbricht, schaltet ihn beim
  nächsten Abspann frei.
* **Wasser-Mechanik** nutzt dieselbe Gefahrenklasse wie die Wurzelmechanik
  (Spitzen aus dem Boden) – funktional gleichwertig, optisch geteilt.
* Level 5 (Dornen im Sturm) und Level 6 (Glas) sind künstlerisch die schwächsten
  Hintergründe; Level 8 hat mit 30 % etwas viel Vordergrunddeckung.

---

## 5. Aufbau des Projekts

```
project.godot           Engine-Konfiguration (960×540, 16:9, GL Compatibility)
export_presets.cfg      Linux- und Windows-Preset, PCK eingebettet
scenes/main.tscn        Einstiegsszene
scripts/autoload/       Loc, Data, Save, Bindings, Audio, App
scripts/core/           Bildschirmbasis, Theme, Hilfsklassen
scripts/screens/        Menüs, HUD, Ergebnis, Evolution, Einstellungen
scripts/game/           Game, Player, Enemy, Boss, Director, Bullets, Background, Pickup, FX
assets/sprites/         68 Sprite-Streifen + manifest.json + Kontaktbogen
assets/aseprite/        68 .aseprite-Quellen (hinter .gdignore)
assets/blender/         10 .blend-Quellen (hinter .gdignore)
assets/bg/              30 Parallax-Ebenen, Paletten, QA-Bericht, Kachelbeweis
assets/audio/           music/*.ogg, sfx/*.wav
tools/                  Sprite-, Blender- und Audio-Werkzeuge, Prüfskripte
tests/                  smoke, content, ui_text, campaign, ending, builds, perf, shots
docs/                   HANDBUCH, BUILD, TESTPROTOKOLL, AUDIO, shots/
```

---

## 6. Benutzung

1. `Stingforge.exe` (Windows) oder `Stingforge.x86_64` (Linux) starten.
2. **Neue Kampagne** wählen, Schwierigkeit bestätigen, eines von drei Starttalenten
   nehmen.
3. Fliegen mit WASD/Pfeilen bzw. linkem Stick, schießen mit Leertaste/A (halten =
   Dauerfeuer), Leiste mit Q/E bzw. LB/RB wählen, kaufen mit F bzw. RT.
4. Nach jedem Level eine von drei Evolutionen wählen.

Vollständige Anleitung: [HANDBUCH.md](HANDBUCH.md). Bauen: [BUILD.md](BUILD.md).
