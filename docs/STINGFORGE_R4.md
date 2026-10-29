# Stingforge R4 – Pixellook, 1080p, Ultrawide und neue Bosse

Stand: 28.10.2026. Grundlage ist R3. Eine Sicherung der R3-Quellen und -Sprites liegt
unter `build/claude-backup-r4-20261028-0014/`, die vorherigen Spieldateien unter
`build/stingforge-r4-previous-release/`.

## Auflösung und Ultrawide

* **Grundauflösung 1920 × 1080.** Die Welt wird im doppelt so feinen Viewport gerendert
  (Kamera-Zoom 2), die Spiellogik bleibt unverändert im 960 × 540-Raster. Bewegungen
  und Effekte werden dadurch weicher, die Pixelkunst bleibt scharf.
* **Ultrawide (21:9, 32:9) und 16:10:** Das Spielfeld bleibt 16:9 und damit fair. Links
  und rechts läuft dieselbe Levelkulisse gedimmt weiter (eigener Hintergrund-Viewport,
  synchron gescrollt), mit weichem Übergang und feiner Feldkante. Die beiden HUD-Bänder
  laufen über die volle Breite. Gegner und Geschosse erscheinen nur im Spielfeld.
* Neue Auflösungen in den Einstellungen: 2560 × 1080, 3440 × 1440, 5120 × 1440 (nur
  angeboten, wenn der Monitor sie darstellen kann).

## Pixel-UI

* **Pixelschriften (OFL, Google Fonts):** Jersey 10 für Texte und Titel, Silkscreen für
  kleine Versalien-Etiketten, ohne Kantenglättung gerendert. Pixelify Sans wurde
  getestet, verformt in diesem Build aber Buchstaben und wird nicht genutzt.
  Lizenzen: `assets/ui/fonts/pixel/OFL-*.txt`.
* **UI-Kit** ([make_ui_kit.py](../tools/make_ui_kit.py)): pixelgenaue 9-Slice-Rahmen mit
  abgeschrägten Ecken, Lichtkante und Nieten, goldener Fokus, Slots, Pfeilmarke,
  Wabenmuster, Zierlinie und Amiga-Copperverläufe mit geordnetem Dithering.
* **Hauptmenü:** neues Pixel-Titelbild (Biene im Sonnenuntergang über Blüten, im
  Hintergrund eine überwucherte Fabrik) mit 480 × 270 Grafikpixeln in ganzzahliger
  Vergrößerung, neues Pixel-Logo, schwebend animiert, treibende Pollen.
  Die alten Bilder `assets/ui/menu/hero.png` und `stingforge.png` sind unverändert
  erhalten.
* **Alle Menüs** (Einstellungen, Werkstatt, Evolution, Ergebnis, Pause, Game Over,
  Rückfragen …) nutzen das neue Theme. Tastenhinweise sind Pixel-Tastenkappen.

## HUD

* **Flachere Bänder:** oben 40 statt 56, unten 44 statt 64 Weltpixel (bei 1080p:
  80 / 88 statt 112 / 128 Bildpunkte). Werte stehen neben ihren Etiketten statt
  darunter; Schriftgrößen blieben gleich. Das Spielfeld ist dadurch 36 Zeilen höher.
* Instrumente mit vertieften Feldern, große Zahlen mit Pixelschatten, doppelt große
  Herzen und Symbole in ganzzahliger Vergrößerung, sechseckige Schildladungen,
  pulsierender Goldrahmen um den gewählten Waffenslot, segmentierter Boss-Lebensbalken,
  Messing-Levelplakette und Laufzeitleiste im Pixelstil.

## Bosse

Alle zehn Bosse und die drei Stufen der Endboss-Wiedergeburt sind neu gezeichnet. Die
Vorlagen kamen aus dem lokalen Bildserver (Qwen-Image). Sie wurden mit
[pixelize.py](../tools/pixelize.py) freigestellt, auf die bisherige Spritegröße gerechnet,
auf 26–34 Farben reduziert, Amiga-typisch gedithert und mit Kontur versehen
([make_bosses.py](../tools/make_bosses.py)). Die Vorlagen liegen unter
`assets/aseprite/generated/` (nicht im Export).

* Trefferzonen folgen weiterhin automatisch der Deckkraft der Grafik.
* Die Schwachpunktmarke ist eine pulsierende Pixel-Zielmarke statt eines unscharf
  vergrößerten Funkenbilds.
* Einschränkung: Das „Mantidenpaar“ zeigt eine einzelne große Mantis.

## Zwischengegner bleibt bis besiegt

Bisher nutzte der Zwischengegner das Flugmuster seines normalen Gegnertyps. Nur in
Level 1, 4, 8 und 9 war das zufällig ein Schwebemuster, in Level 2, 3, 5, 6, 7 und 10
flog er links aus dem Bild. Jetzt hat er ein eigenes Muster: einfliegen, rechts
patrouillieren, der Biene in der Höhe folgen und alle 6,5 s angekündigt vorstoßen
([enemy.gd](../scripts/game/enemy.gd)).
Nachweis: [r4_miniboss_probe](../tests/r4_miniboss_probe.gd), mit altem Code 6 von 10
Leveln rot ([Rotlog](../build/logs/r3/r4-miniboss-red.log)), jetzt 10 von 10 grün.

## Nachträge

* **Listen springen nicht mehr:** Nach einem Kauf in der Werkstatt oder einer Änderung
  im Debugmenü (F4) baute sich die Liste neu auf. Die noch nicht angeordneten Zeilen
  ließen die Liste ganz nach oben springen. Das Menügerüst hält jetzt Höhe und
  Scrollposition, bis die neuen Zeilen stehen, und scrollt nur, wenn der Fokus
  außerhalb liegt ([ui_screen.gd](../scripts/core/ui_screen.gd)). Behoben ist dabei auch:
  Abstandshalter zwischen Listengruppen wurden nie entfernt, die Liste wuchs mit jedem
  Neuaufbau.
* **Schmalere Menüzeilen:** Listen sind standardmäßig rund 680 Pixel breit (1080p)
  statt bildschirmbreit. Einstellungen 1040 Pixel, im Reiter Steuerung 1400 Pixel
  wegen der beiden Belegungsspalten.
* **20 Starttalente:** Der Pool umfasst jetzt 20 Evolutionen ohne Voraussetzung und
  Waffenbindung (Stachel 5, Pollen 4, Chitin 4, Resonanz 3, Schwarm 2, Nektar 2). Bei
  jedem Kampagnenstart werden drei zufällig angeboten, möglichst aus drei
  verschiedenen Familien ([start_talent_screen.gd](../scripts/screens/start_talent_screen.gd)).
  Die frühere Profilsperre für Leichtbau entfällt.
* **Schild als Wabenhülle:** Statt der Pentagramme zeigt jede Schildladung einen
  sechseckigen Ring aus Waben-Platten mit Fugen, Konturen und Eckknoten, abwechselnd
  rotierend, in Türkis und Gold, mit wanderndem Glanz
  ([shield_rings.gd](../scripts/game/shield_rings.gd)). Reduzierte Effekte behalten
  alle Ringe.
* **Blitz-Stufen:** Stufe 1 und 2 feuerten beide zwei Kugeln. Der einzige Unterschied
  war ein dritter Kettensprung mit einem Sechstel Schaden, praktisch unsichtbar. Jetzt
  feuern die Stufen 2, 3 und 4 Kugeln, mit Salvenschaden 11,6 / 17,4 / 23,2
  (vorher 11,6 / 11,6 / 17,4). Der Blitz bleibt unter dem Fächer (26,0 auf Stufe 3),
  hat aber Durchschlag und Kette. Das ist eine bewusste Stärkung der Stufen 2 und 3.
* Nachweis: [r4_ui_probe](../tests/r4_ui_probe.gd) (Werkstatt und Debugmenü bleiben
  stehen, Listenhöhe stabil, 20 Starttalente, 40 Ziehungen mit drei Familien,
  Anwendung des gewählten Talents, Zeilenbreite) und die angepasste Waffenmatrix.

## Zweite Nachtragsrunde

* **Bosse ohne Zittern, mit Tierverhalten:** Das Zittern des Rosenkäfers hatte zwei
  Ursachen. Beim Rammen setzte ein Zeitplan die Position alle 45 ms nach vorn,
  während die Grundbewegung jedes Bild zurückzog; danach sprang der Boss zurück.
  Außerdem maß die Feldbegrenzung die Grafik in jedem Bild neu, einschließlich
  Schaukeldrehung und schwingender Module. Jetzt gibt es ein Bewegungssystem mit
  geskripteten, weich interpolierten Bewegungen (Ansturm, Sprung, Abtauchen,
  Innehalten nach dem Aufprall) und einer stabilen Begrenzung. Jeder Boss hat eine
  Grundbewegung passend zu seinem Tier:
  * **Käfer:** träger, tiefer Flug.
  * **Larve:** kriecht am Boden und gräbt sich ein, statt zu teleportieren.
  * **Hecht:** schwimmt und springt im Bogen aus dem Wasser, dazu ein Torpedostoß.
  * **Pilz:** wurzelt und atmet.
  * **Mantis:** lauert, richtet sich aus, springt (neu: Sprungangriff).
  * **Bestäuber:** Rotorflug.
  * **Wasserläufer:** gleitet ruckartig zwischen Bahnen (neu: Gleitstoß).
  * **Erntemaschine:** rollt am Boden (neu: Rammfahrt).
  * **Königin:** Achterflug (neu: Stachelsturz).
  * **Kern:** schwebt und pulsiert.

  Nachweis: [r4_boss_probe](../tests/r4_boss_probe.gd), alle zehn Bosse ohne
  Ruckler, Teleportsprünge oder Ausbrüche aus dem Feld. Der alte Code hatte beim
  Rosenkäfer 56 Ruckler und bei Larve und Hecht Teleportsprünge.
* **Endboss-Scheinsieg:** Der Kern geht wie jeder Boss unter, mit Explosionen. Lebensbalken
  und Kern verschwinden, „KERNORGANISMUS BESIEGT!“ und Siegesmusik folgen. Nach drei
  Sekunden Ruhe verstummt die Musik, es grollt und bebt, „… DER KERN LEBT!“, und die
  neue Gestalt bildet sich (insgesamt 8,6 s). Bei reduzierten Effekten läuft alles ohne Blitzen.
* **Hindernisse und Felder:**
  * **Level 2:** Dornige Pixel-Wurzeln brechen mit Erdhügel, springenden Brocken und
    Warnsaum aus dem Boden. Grafik- und Trefferhöhe sind jetzt beide 80 Pixel, vorher 70 bzw. 80.
  * **Level 3:** Wasserfontänen mit Blasenringen als Vorwarnung, schäumender Säule und Gischt.
  * **Level 4:** Wabernde violette Sporenwolken mit treibenden Sporen.
  * **Level 5:** Wind als geschwungene Böen mit taumelnden Blättern.
  * **Level 7 und 10:** Strömung als Wasserschlieren, Schwerkraft als fallende Lichtpartikel.
  * Die eigene Pollenwolke der Biene erscheint als goldene Ballen.
* **Wellenschuss:** Die Wellenlänge war mit 80–104 Pixeln bei 760 Pixeln pro Sekunde
  so kurz, dass die Kugeln nur flackerten. Jetzt sind es 300–360 Pixel, aufeinanderfolgende
  Kugeln schwingen gegenphasig (Doppelhelix) und ziehen eine Leuchtspur.
* **Parallax:** Die vorderen Silhouettenebenen aller zehn Level sind neu gezeichnet
  ([make_near_layers.py](../tools/make_near_layers.py)). Sie sind nahtlos kachelbar,
  passen zum jeweiligen Thema und haben eine Gegenlichtkante. Das abgehackte Schilf in
  Level 3, die harten Balken in Level 5 und 6 und die abgeschnittenen Kanten sind weg.
  Die alten Ebenen liegen unter `build/near-layers-original/`.
* **Neue Gegner:**
  * **In ruhigen Passagen** (höchstens zwei Gegner im Bild) kommen
    **Hornissen von hinten**, nach einer Pfeilwarnung am linken Rand, oder
    **Kreuzspinnen**, die sich am Faden von oben abseilen.
  * **Am Boden** laufen **Ameisenkanoniere**, und **Maulwurfsgrillen** brechen aus der Erde.
  * Eine eigene Zufallsquelle sorgt dafür, dass die bisherigen Wellen gleich bleiben.
* **Highscore-Namen:** Lauf in den Top 20 → bei der Rückkehr ins Hauptmenü erscheint eine
  Arcade-Namenseingabe (Tastatur tippen oder Gamepad-Zeichenwahl), der Name wird
  gespeichert und beim nächsten Mal vorgeschlagen.

## Dritte Nachrunde: Werkstatt, Soundtrack-Konzept, Git

* **Werkstatt dreispaltig** (`scripts/screens/shop_screen.gd`):
  * Links stehen die Kategorien mit Fortschritt (gekaufte/mögliche Stufen, gold = etwas bezahlbar)
    und „Weiter“.
  * Die Mitte zeigt die Upgrades der gewählten Kategorie schon beim Überfahren
    (Maus, Tastatur, Gamepad).
  * Bestätigen oder → springt hinein, ← oder Zurück wieder heraus.
  * Rechts stehen Name, Stufe, eine **animierte Erklärszene** (`scripts/core/upgrade_illustration.gd`,
    eine Szene je Upgrade in Spielgrafik und in der Stärke der nächsten Stufe), Preis,
    Wirkung und Sperren.
  * Mausbewegung schaltet auf Zeigerbedienung um, damit eine neu aufgebaute Liste unter einem
    ruhenden Zeiger keinen Moduswechsel auslöst.
* **Soundtrack:** Konzept und Softwarevorschlag in `docs/SOUNDTRACK_KONZEPT.md`
  (noch nichts installiert).
* **Soundtrack, alle zehn Level:** Level 1 als Muster von mir. Level 2–10 entstanden parallel
  mit derselben Pipeline (Leitmotiv-Verwandlungen in `songs/_themes.py`). Ich habe sie geprüft,
  Stimmen außerhalb des Sample-Umfangs werden jetzt automatisch oktaviert. Alle zehn sind neu
  gerendert, gemessen und als `level1`–`level10.ogg` eingebaut.
* **Pipeline-Details:**
  * Pipeline in `tools/music/`: Partitur in Python, Tempokarte mit Abschnittsgrenzen auf Taktanfängen,
    SFZ-Instrumente aus VSCO 2 CE und VCSL (CC0, Oktavversatz je Instrument gemessen), Csound-Synthesizer,
    Mix, Master auf −16 LUFS und −1 dBTP, Messbericht und Spektrogramm.
  * `level1.ogg` ist 283,45 s lang, exakt bis zum Einsatz der Bossmusik.
  * Leveltracks ab 2 Minuten laufen ohne Loop und folgen der Levelzeit: Pause hält sie an,
    Checkpoint-Neustart springt an die Abschnittsgrenze, Abweichungen über 0,3 s werden nachgestellt
    (`Director.music_pos()`, `Audio.sync_music()`).
* **Larven-Boss (Level 2):** drei Phasen. Neu sind Tunnelfahrt (Erdsäulen-Reihe am Boden), Deckeneinsturz
  (angekündigte Brocken in Bahnen, immer eine Lücke) und Brut (Maden am Boden). Am Boden kleben
  lohnt sich nicht mehr.
* **Fontänen (Level 3):** 240 statt 80 Punkte hoch, 3,6 statt 1,8 s. Die Vorwarnung zeigt die ganze
  spätere Säule.
* **Zielsuche:** Lenkkraft etwa halbiert (1,2/1,8/2,5 plus 0,8/1,3/1,8), Reichweite 320 Punkte.
* **Glas (Level 6):**
  * Ankündigung 1,6 s mit Kristallwachstum, Eckwinkeln, Warnzeichen und Glockenton.
  * Aktiv kräftig getönt mit dunkler Kontur.
  * Zerbrechlich: Haltbarkeit 2,4 s Dauerfeuer der aktuellen Bewaffnung, Risse und Schadensbalken.
    Beim Bruch fliegen Scherben mit Klang, dazu gibt es 250 Bonuspunkte.
* **Bossphasen:** 0,85 s Stillstand, Boss glüht und pulsiert (Brüllen), Schockwellenringe,
  Geschosse zerplatzen, Rot-Blitz, starkes Rütteln, Banner „PHASE II“ mit Bosszeile.
  Danach bleibt der Boss in zunehmender Wutfärbung.
* **Upgrade-Ansage:** LB/RB sagt das gewählte Upgrade an, z. B. „Blitz“. Abschaltbar unter
  Einstellungen › Audio.
  * Spielt Clips aus `assets/audio/voice/upgrade_<id>.ogg`, falls vorhanden, sonst die
    Systemstimme (Windows: SAPI; Linux: nur mit speech-dispatcher).
* **Git:** Repository mit `.gitignore` angelegt. Ausgeschlossen sind Astra, Godot-Caches, Builds,
  Releases, Testablagen und lokale MCP-Konfiguration.

## Vierte Nachrunde: Tutorial, Bossmusik, Verschmelzungen, Balance

- **Tutorial (Übungsflug):** ein eigener Modus auf einer Kopie des Spielstands.
  - Neun Stationen, jeweils mit angehaltenem Spiel und Bildfenster.
  - Danach folgen die echte Blütenstaub-Umrechnung, die Werkstatt im Übungsmodus und der
    Hinweis auf Evolutionen.
  - Code: `scripts/game/tutorial.gd`, `scripts/screens/tutorial_tip_screen.gd`.
- **Bossmusik neu:** je Level ein eigener Bosstrack (`tools/music/songs/bosses.py`).
  - Gleiches Tempo, die Tonart, auf die der Leveltrack hinführt, und eine „Ankunft“ auf dem
    ersten Schlag.
  - Danach ein 32-taktiger Loop; `assets/audio/music/loops.json` liefert den Loopstart.
  - Die Fanfare am Levelende und der Warnton entfallen. Der Leveltrack endet mit einem Auftakt,
    und der Wechsel erfolgt als harter Schnitt im Takt.
- **Verschmelzungen:** Synergiepaare wirken jetzt wirklich. Werte steigen um +50 %, Zählwerte
  um +1, Schwellen sinken um −25 %; Nachteile bleiben. Entdeckungen landen im Profil, die
  Übersicht steht im Hauptmenü.
- **Angekündigt heißt umgesetzt:**
  - Käfer: Glut und Glutsalven.
  - Hecht: Wassersäulen im Kampf.
  - Pilz: zerplatzende Knoten.
  - Erntemaschine: vier Module.
  - Königin: Hofstaat.
  - Larve, Phase 3: Dauer-Felsregen mit Lichtschacht-Lücke.
- **Level 3:** Wassersäulen als Brunnenfontäne; die Trefferform ist genau die sichtbare Säule
  samt Krone (`Fx.geyser_shape`).
- **Balance:**
  - Zielsuche nochmals schwächer (0,6/0,9/1,25, Reichweite 240), Starke Zielsuche erst ab Zielsuche 3.
  - Reichere Beute: echte Chance von 15/20/30 %.
  - Fächer: 4/5/6 Stacheln in gestaffelten Bahnen.
- **Werkstatt und Highscore:**
  - Werkstatt-Ausgaben senken den Highscore.
  - Die Werkstatt ist nicht mehr im Hauptmenü; der Knopf sagt „Weiter mit Level N+1“.
- **Evolutionsbildschirm:** „Angebote mischen (1×)“ als schmaler, mittiger Knopf; der veraltete
  Hinweis entfällt.
- **Sprache:**
  - Die Ansagen kommen jetzt von Piper (Stimme Thorsten), neu ist „Zu wenig Blütenstaub“.
  - Nachtrag: Piper klang zu dunkel und abgehackt. Die Ansagen kommen inzwischen von Qwen3-TTS
    (Stimme „Heldin“), siehe [Sprachansagen](SPRACHANSAGEN.md).
  - Sichtbare Texte nennen die Währung einheitlich **Blütenstaub**.

## Prüfung

* `python3 tools/verify_stingforge_r3.py`: alle Suiten einschließlich Pause-, Zwischengegner-
  UI- und Bossprüfung, **38 / 38 grün**
  ([Zusammenfassung](../build/logs/stingforge-r3/summary.json)).
* Angepasste Prüfungen, weil der Entwurf das bewusst ändert: Bandmaße 40/496 statt
  56/476, HUD-Geometrie der neuen Einzeilen-Instrumente, Schriftprüfung an der
  Versalhöhe (Pixelschrift mit großem Zeilenabstand), Fußleistenbreiten im 1920er-Canvas.
* Echter Fehler, den die Prüfung fand und der behoben ist: Bei 120 und 160 % Schrift
  scrollte das Hauptmenü nicht bis „Spiel beenden“.
* `python3 tools/verify_stingforge_r3_exports.py`: Linux- und Windows-Export, eingebettetes
  PCK, neue Skripte, Schriften und Bilder verpackt, Startprobe beider Dateien (Windows
  unter Wine).
* Bildnachweise: `build/r4-shots/` (1920 × 1080) und `build/r4-uw/` (2560 × 1080).

### Grenzen

* Spielergrafik, normale Gegner und Levelhintergründe sind unverändert. Sie passen
  zum Pixelstil, sind aber nicht so detailreich wie die neuen Bosse.
* Windows nur unter Wine geprüft, kein physischer Controller.
