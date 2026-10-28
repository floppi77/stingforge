# Stingforge – Kurzanleitung

Ein modernes horizontales Shoot'em Up. Du fliegst Yuri, eine Feldbiene, durch zehn
Reiche gegen Stahl, Sporen und Maschinen. Alles, was du zum Spielen brauchst, steht
auf dieser Seite.

---

## 1. Starten

**Windows:** `Stingforge.exe` doppelklicken. Keine Installation nötig.
**Linux:** `Stingforge.x86_64` als Programm starten (ggf. vorher
`chmod +x Stingforge.x86_64`). Ebenfalls ohne Installation.

Die Programme enthalten alle Daten (Grafik, Musik, Level) in einer einzigen Datei.
Beim ersten Start legt das Spiel einen Speicherordner an:

* Windows: `%APPDATA%\Godot\app_userdata\Stingforge\`
* Linux: `~/.local/share/godot/app_userdata/Stingforge/`

Darin liegt der Unterordner `saves` mit `settings.save`, `profile.save` und
`campaign.save` sowie den jeweiligen `.bak`-Sicherungen. Beim ersten Start werden
vorhandene Dateien aus dem früheren Ordner **Apidya Reimagined** übernommen,
ohne alte Originale oder schon vorhandene Stingforge-Dateien zu überschreiben.

---

## 1a. Das Hauptmenü

Vor dem vom Betreiber gelieferten Bienen-/Ruinenmotiv steht links der goldene
Titel. Darunter: *Fortsetzen* (mit Levelstand), *Neue Kampagne*, *Training*,
*Boss-Rush*, *Werkstatt*, *Einstellungen*, *Credits* und *Spiel beenden*.
Nur die gewählte Zeile leuchtet gold. Gesperrte Einträge haben ein Schloss;
ohne Spielstand ist *Neue Kampagne* vorausgewählt.

Die transparente Karte unten rechts zeigt dein aktuelles Level und die
Schwierigkeit des gespeicherten Laufs, freigeschaltete Evolutionen, verfügbare
Werkstatt-Punkte und Bestpunkte aus dem Profil. Tastatur- und Xbox-Hinweise
stehen gemeinsam unten links. Bei Standardschrift passen alle acht Einträge
ohne Scrollen. Mit größerer Schrift scrollt die Auswahl zum gewählten Eintrag.

## 2. Steuerung

### Tastatur

| Aktion | Taste |
|---|---|
| Fliegen | `W` `A` `S` `D` oder Pfeiltasten |
| Schießen (gedrückt halten = Dauerfeuer) | `Leertaste` |
| Autofeuer ein/aus | `R` |
| Waffenleiste links / rechts | `Q` / `E` |
| Gewählten Eintrag kaufen bzw. aktivieren | `F` |
| Präzisionsflug (langsam, feines Ausweichen) | `Linke Umschalttaste` |
| Pause im Spiel / zurück | `Esc` |
| Menü bestätigen | `Leertaste` oder `Eingabe` |

### Debug (zum Testen)

| Taste | Wirkung |
|---|---|
| `F4` (Controller: `Back`) | Debugmenü: Spiel pausiert. Enthält *Zum Levelboss*, *Zum nächsten Level*, *Vollheilen* sowie **jedes** Taktik- und Kauf-Upgrade mit Beschreibung; links/rechts stellt die Stufe ein |
| `Esc` im Debugmenü | schließt und setzt das Spiel fort |

### Maus

Alle Menüs lassen sich zusätzlich mit der Maus bedienen: Zeiger auf einen
Eintrag bewegen hebt ihn hervor, **Linksklick** löst ihn aus (Schalter und
Regler schalten weiter), das **Mausrad** bewegt die Auswahl. Im laufenden Spiel
wird die Maus nicht gebraucht.

### Controller (Xbox-Layout, andere Layouts werden erkannt)

| Aktion | Taste |
|---|---|
| Fliegen | Linker Stick oder Steuerkreuz |
| Schießen (gedrückt halten = Dauerfeuer) | `A` |
| Autofeuer ein/aus | `X` |
| Waffenleiste links / rechts | `LB` / `RB` |
| Kaufen / aktivieren | `RT` |
| Präzisionsflug | `LT` |
| Pause / zurück | `Start` bzw. `B` |

Halten von Schießen ist **immer Dauerfeuer** – es gibt keine Aufladefunktion.
`RT` löst pro Druck genau einen Kauf aus (Hysterese: Auslösen über 60 %, erneut
scharf erst unter 30 %), damit ein durchgedrückter Trigger nicht mehrere Einträge
kauft. Nach jedem Kontextwechsel (Menü → Spiel, Pause → Spiel) muss die bestätigende
Taste erst losgelassen werden; sie wirkt nicht in den neuen Kontext hinein.

Alle Tasten und Controllertasten lassen sich in den Einstellungen unter **Steuerung**
neu belegen; Deadzone, Empfindlichkeit und Vibration sind dort ebenfalls einstellbar.

**Tastatur und Xbox werden immer gemeinsam angezeigt**, auch ohne angeschlossenen
Controller. In der Belegungsübersicht stehen beide in getrennten Spalten.
Tastaturtasten sind eckige Plaketten, die Xbox-Tasten A/B/X/Y farbige Kreise;
LB/RB und LT/RT sind Kapseln. Beim Blättern in der Waffenleiste mit LB/RB (bzw. `Q`/`E`)
wird das gewählte Upgrade angesagt, etwa „Blitz“. Abschaltbar unter Einstellungen › Audio. Angezeigt wird deine aktuelle Belegung, nicht nur
der Standard. `Leer` heißt Leertaste, `Eing.` Eingabe, `D` Steuerkreuz und `LS`
linker Stick. Größere Schrift lässt die Fußleiste umbrechen und ordnet die
beiden Geräteklassen in der Belegungsübersicht untereinander an.

---

## 3. Der Bildschirm

* **Oben:** ein eigenes, opakes Instrumentenband (40 von 540 Zeilen) mit Instrumenten für
  **Vitalwerte**, **Schild**, **Nektar** und **Punkte**; Etikett und Wert stehen nebeneinander. Das befliegbare Feld beginnt
  darunter; Gegnerkörper und unsere Biene bleiben vollständig außerhalb des HUD.
  Gefüllte und leere Schildsymbole zeigen Ladungen, ein Balken die Nachladezeit.
  Punkte werden mit Tausenderpunkten dargestellt.
* **Oben rechts:** kompakte Hinweise für Autofeuer und Pause, jeweils mit der
  aktuellen Tastatur- und Xbox-Belegung.
* **Unten:** die taktische Waffenleiste mit neun Einträgen, auf einer eigenen
  dunklen Fläche. **Dieser Bereich gehört nicht zum Spielfeld** – Spielfigur,
  Gegner und Geschosse enden an ihrer Oberkante (bei 496 von 540 Zeilen), damit
  nichts Unsichtbares mehr darunter passiert. Der hervorgehobene Eintrag wird
  mit `RT`/`F` gekauft. Die Zeile darüber nennt Kosten und Wirkung.
* **Laufzeitleiste (neu in R3):** In der schmalen Zeile unter den Instrumenten
  zeigt eine Leiste, wie weit das Level bis zum Boss fortgeschritten ist. Rauten
  markieren die Checkpoints (gefüllt = erreicht), ein rotes Dreieck den Miniboss,
  die goldene Raute am Ende den Boss. Rechts daneben steht die geschätzte Restzeit
  („Boss in 1:24“), danach „Boss naht“ bzw. „Bosskampf“. Die Zeit zählt nur
  gespielte Sekunden – Pause, Tod und Schonfrist halten sie an. Im Boss-Rush zeigt
  die Leiste stattdessen „Boss 3 / 10“.
* **Ultrawide:** Auf 21:9 und 32:9 bleibt das Spielfeld 16:9; links und rechts läuft die
  Levelkulisse gedimmt weiter. Die HUD-Bänder reichen über die volle Breite.
* **Zwischengegner** bleiben im Feld, bis sie besiegt sind, und stoßen regelmäßig
  angekündigt nach links vor.
* **Bosskampf:** Name, Lebensbalken, Phase und Panzerzustand stehen in der
  schmalen Zeile des oberen Instrumentenbandes, nicht über dem aktiven Feld.
* **Bosskontakt:** Der sichtbare Körper und lebende Module sind berührungsgefährlich.
  Durch transparente Sprite-Ecken darfst du hindurchfliegen; Schwachphasen und
  Panzerung beeinflussen weiterhin den angerichteten Waffenschaden.
* **Gegnerisches Feuer:** Auf Entspannt und Normal ungefähr 20 % weniger
  Projektile als im vorherigen Stand; auf Experte bleibt die Anzahl gleich.
  Helle, weißglühende Geschosse mit dunklem Rand und
  einem weichen Hof – sie stehen still in der Form (nichts blinkt) und sind
  dadurch auch auf bunten Hintergründen sofort zu erkennen.
* **Pause:** `Esc` oder `Start` öffnet jederzeit das Pausenmenü
  (Fortsetzen, Neustart vom Checkpoint, Einstellungen, Build-Übersicht,
  Hauptmenü, Spiel beenden). Die Spielwelt steht dabei vollständig still – auch
  bei Fokusverlust des Fensters oder getrenntem Controller. Hinter einem
  durchscheinenden Schleier bleibt die angehaltene Szene sichtbar; rechts zeigt
  eine Statusspalte Level, Laufzeitleiste, Vitalwerte, Nektar, Punkte und
  Spielzeit. Nach dem Fortsetzen folgt eine kurze Schonfrist.

---

## 3a. Tiefe im Bild: Parallax und Beleuchtung

Der Hintergrund besteht aus **fünf Ebenen**, die unterschiedlich schnell
vorbeiziehen – von fast stehenden Schwaden in der Ferne bis zu dunklen Halmen
direkt vor der Spielebene. Dadurch entsteht der Eindruck, tatsächlich zu fliegen,
statt nur auf der Stelle zu kämpfen. Die neuen Ebenen (Sporenschwaden, Halme und
hängende Blätter) sind nahtlos kachelbar und nehmen die Farben des jeweiligen
Levels an.

Darüber liegt eine **dezente Beleuchtung**: ein weicher Lichteinfall von oben und
eine leichte Abdunklung der Ränder (Vignette). Sammelobjekte haben einen weichen
Schein, damit Blütenstaub und Herzen sofort ins Auge fallen. Das alles bleibt
subtil und lässt sich unter **Einstellungen → Grafik → Beleuchtung & Schatten**
abschalten.

**Eigene Schüsse sind kalt gefärbt** (weiß mit eisblauem Rand), Blütenstaub und
Nektarblüten sind warm gold und leuchten. Damit ist auf einen Blick klar, was
dir gehört und was du einsammeln kannst – auch bei vollem Bild.

## 4. Waffenleiste (taktisch, mit Nektar)

Nektar fällt von Gegnern und liegt in Blüten. Er bleibt über Level und
Checkpoints erhalten – **bis zum Levelende**: dort wird der Rest mittig im Bild
in Punkte umgerechnet (**10 Punkte je Tropfen**), mit hochzählender Anzeige und
Ton. Das nächste Level beginnt mit 0 Blütenstaub, die Punkte bleiben.

| Eintrag | Wirkung | Stufen |
|---|---|---|
| Basisschuss | zwei präzise Stachelschüsse, immer verfügbar | 1 |
| Fächerschuss | breiter Fächer, mehr Trefferfläche | 3 |
| Blitzwaffe | schnelle Kugeln (Stufe 1/2/3: zwei, drei, vier); ein Treffer springt auf den nächsten Gegner im Umkreis (66 % Schaden) und von dort auf den übernächsten (33 %) | 3 |
| Plasmawaffe | langsam, hoher Schaden, kleine Streuung (etwa ein Viertel des Fächers), Flächenwirkung | 3 |
| Begleiter | automatisch feuernde Drohnen | 3 |
| Bomben | lösen automatisch aus, räumen gegnerisches Feuer | 3 |
| Schild | fängt Treffer ab, lädt sich wieder auf | 3 |
| Flugtempo | höheres Tempo; erneut kaufen senkt es wieder | 3 |
| — | *Wind und Strömung* drücken höchstens mit 62 % deines Flugtempos; **wer gegensteuert, kommt immer noch vorwärts** | — |
| Reparatur | ein Leben zurück; bei vollem Leben kostet es nichts | 1 |

Die Leiste zeigt **Kurznamen** (Basis, Fächer, Blitz, Plasma, Drohne, Bombe,
Schild, Tempo, Reparatur). Einträge, die du **jetzt nicht bezahlen kannst, bleiben
grau** – lesbar, aber ohne Leuchten. Sobald genug Blütenstaub da ist, färben sich
Rahmen, Name und Preis gold; dann lohnt der Druck auf `RT`/`F`.

**Schild:** Erst taktisch kaufen. Stufe 0 hat keinerlei Schild; Stufen 1/2/3
haben genau 1/2/3 Ladungen. Ein Treffer verbraucht eine Ladung, nicht die Kaufstufe.
Eine fehlende Ladung wächst nach etwa zwölf Sekunden nach; Werkstatt und Bastion
beschleunigen das. Werkstatt allein schaltet keinen Schild frei und erhöht
nicht die Kapazität. Ein bis drei gegenläufige Wabenringe um die Biene zeigen
den aktuellen Ladungsvorrat.

Gekaufte Waffen schaltest du um, indem du den Eintrag mit `RT`/`F` aktivierst –
Kauf und Aktivierung sind dieselbe Taste, die Stufe wird dabei **nicht** erhöht.

**Jedes neue Level beginnt ohne taktische Zusatzkäufe.** Alle acht gekauften
Zusätze fallen auf 0 zurück; nur die kostenlose Basiswaffe bleibt auf Stufe 1.
Nektar wird weiterhin in Punkte umgerechnet, nicht durch den Reset vernichtet.
Werkstatt und Evolutionen bleiben; du baust die taktische Leiste pro Level neu auf.

**Auch ein Game Over setzt die Leiste zurück** – Basis auf Stufe 1, alle anderen
taktischen Käufe und Nektar auf 0.
Was du in der Werkstatt gekauft hast und welche Evolutionen du besitzt, bleibt
davon unberührt (siehe Abschnitt 6b).

---

## 4a. Evolutionswahl am Levelende

Nach jedem Level (auch nach dem zehnten) erscheinen **drei Karten nebeneinander**,
ohne Scrollen:

* **A/D** oder **Pfeil links/rechts** beziehungsweise **Stick links/rechts** wählt
  zwischen den drei Karten.
* **S** oder **Pfeil runter** führt auf die Zeile *Angebot neu ziehen* – einmal
  pro Level darfst du neu würfeln, danach steht dort *An* statt einer neuen Wahl.
* **Leertaste** oder **A** bestätigt die hervorgehobene Karte, **Esc/B** geht
  zurück. Die Maus funktioniert weiterhin direkt.

Direkt zuvor rechnet das Spiel deinen restlichen Blütenstaub in Punkte um.

## 5. Evolutionen (dauerhaft)

Nach **jedem** Level – auch nach dem zehnten – wählst du aus **drei** Angeboten
**genau eine** Evolution. Es gibt 36 davon in sechs Familien (Stachel, Schwarm,
Pollen, Chitin, Resonanz, Nektar). Einmal pro Levelabschluss darfst du die drei
Angebote **einmal neu würfeln**; die Entscheidung selbst ist nicht überspringbar.

* Jede neue Kampagne bietet **drei zufällig gezogene Starttalente** aus einem Pool von 20 an, möglichst aus drei verschiedenen Familien.
* Weitere Talente sind **Profil-Freischaltungen**: sie erscheinen im Pool, werden
  aber erst in einer laufenden Kampagne wirksam.
* Evolutionen, die eine bestimmte Waffe brauchen, sind im Angebot markiert und
  **inaktiv**, solange diese Waffe nicht gekauft ist – sie leben wieder auf, sobald
  du die Waffe besitzt.
* Belohnungen werden nicht doppelt vergeben: Level, die schon belohnt wurden,
  liefern bei Wiederholung keine zweite Evolution.
* Die zehnte Evolution bleibt gespeichert und steht im **Boss-Rush** zur Verfügung.

---

## 5a. Werkstatt (Punkte, dauerhaft)

Nach der Evolutionswahl und der Levelabrechnung öffnet sich die **Werkstatt**.
Dort kaufst du mit **Punkten** – nicht mit Blütenstaub – dauerhafte Verbesserungen.
Sie bleiben für den ganzen Lauf und stapeln sich mit allem anderen.

* **32 Upgrades in fünf Gruppen**: Schussform, Wirkung, Tempo, Schutz, Ausbeute.
* **Jedes Upgrade hat drei Stufen.** Stufe 2 und 3 sind keine Prozentpunkte,
  sondern verändern das Spiel: Beim *Kreisflug* kreisen die Schüsse erst in
  mittlerem, dann in großem Radius um die Biene und laufen zuletzt schneller;
  beim *Wellenschuss* fliegen sie in einer Welle, die sich über die Zusatzstufen
  *Weite Wellen* und *Schnelle Wellen* weiter formen lässt.
* **Zielsuche** wirkt nur im Nahbereich (etwa ein Drittel der Bildbreite) und lenkt maßvoll.
* **Ketten**: Einige Upgrades werden erst frei, wenn ihr Vorläufer gekauft ist –
  *Schnelle Wellen* und *Weite Wellen* brauchen *Wellenschuss*, *Panzerbrecher*
  braucht *Schwere Geschosse*, *Starke Zielsuche* braucht *Zielsuche*.
  Gesperrte Einträge stehen grau mit der geforderten Vorbedingung da.
* **Kombinierbare Flugformen**: *Kreisflug*, *Wellenschuss* und *Zielsuche* lassen
  sich jetzt zusammen kaufen. Kreisgeschosse bleiben räumlich getrennt; Wellen
  modulieren ihre Bahn und Zielsuche wirkt weiterhin. Auch *Spiralschuss* bleibt
  wirksam. Die alte gegenseitige Sperre entfällt; echte Vorbedingungen für
  *Weite Wellen*, *Schnelle Wellen* und *Starke Zielsuche* bleiben bestehen.
* **Gemeinsames Waffenprofil**: Zusatzschüsse übernehmen die aktive Waffe:
  Plasma behält Flächenschaden und Wucht, Blitz seine Kettenwirkung. Begrenzte
  Mengen und Salvenabstände verhindern trotzdem eine neue Kugelflut.
* **Drei Spalten:** links die **Kategorien**, in der Mitte die **Upgrades** der
  gewählten Kategorie, rechts die **Beschreibung mit einer kleinen animierten
  Szene**, die zeigt, was der Effekt im Spiel macht. Sie zeigt Schussbahn, Schild
  oder Beute in der Stärke der nächsten Stufe. Darunter stehen Preis, Wirkung
  der nächsten Stufe und was du schon hast.
* **Preise**: erste Stufen 2.500–6.000 Punkte, zweite 5.500–13.000, dritte
  10.000–24.000. Ein Level spielt je nach Sorgfalt etwa 15.000–35.000 Punkte ein –
  eine erste Stufe ist also nach *einem* Level drin, die dritte will gespart sein.
  Alles auf einmal kaufen geht bewusst nicht.
* **Bedienung**:
  * `W`/`S` bzw. Stick wählt die Kategorie, und die Mitte zeigt sofort deren Upgrades.
  * **Leertaste/A** oder `→` springt in die Liste. Dort kauft **Leertaste/A**, `←` oder `Esc/B`
    führt zurück zu den Kategorien.
  * **Weiter** steht unten in der Kategoriespalte. `Esc/B` in den Kategorien verlässt die Werkstatt ebenfalls.
  * Mit der Maus zeigt Überfahren die Kategorie bzw. das Upgrade, ein Klick kauft.
  * Aus dem Hauptmenü führt der Eintrag **Werkstatt** jederzeit hinein.

<details>
<summary>Alle 32 Werkstatt-Upgrades im Überblick</summary>

**Schussform** – Kreisflug, Wellenschuss, Schnelle Wellen, Weite Wellen,
Heckstachel, Seitenstachel, Doppelläufe, Spiralschuss, Zielsuche, Starke Zielsuche

*Heckstachel*, *Seitenstachel* und *Doppelläufe* geben **eine begrenzte Zahl
zusätzlicher Schüsse** (zwei nach hinten, zwei zur Seite, ein Nebenlauf). Die
letzten Stufen erhöhen deshalb nicht die Kugelzahl, sondern die **Wucht** dieser
Schüsse: „Die Heckschüsse schlagen deutlich härter ein.“ So bleibt das Bild
lesbar, und der Kauf bringt trotzdem etwas.

**Wirkung** – Durchschlag, Splitterwolke, Kettenblitz, Schwere Geschosse,
Volltreffer, Splitterkern, Panzerbrecher

**Tempo** – Schnellfeuer, Hochgeschwindigkeit, Salve

**Schutz** – Schildaufladung, Schildstabilität, Zusätzliches Leben, Nachbrenner,
Bombenradius, Bombenlager

**Ausbeute** – Blütenstaub-Magnet, Reichere Beute, Streiftreffer, Serie,
Bessere Umrechnung, Frischer Nektar

</details>

---

## 5b. Bossankündigung

Kurz bevor ein Levelboss erscheint, rüttelt der Bildschirm, das Bild blitzt weiß
auf, ein großes **BOSS** steht über dem Geschehen und ein Warnton läuft. In dieser
Sekunde ist das Feld bereits geräumt (keine Gegnerkugeln, keine Wellen) – der Boss
selbst kommt erst danach. Bei Zwischenbossen gibt es weiterhin nur den Namen
mittig im Bild.

**Phasenwechsel mit Auftritt**:
* **Vor dem Banner:** Erreicht ein Boss seine nächste Phase, hält das Spiel kurz an (unter einer Sekunde).
  Der Boss glüht auf und pulsiert, Schockwellenringe laufen über das Feld und die fliegenden
  Gegnerkugeln zerplatzen. Dazu blitzt das Bild rot, es rüttelt kräftig und ein Brüllen ertönt.
* **Banner:** Ein großes Band **PHASE II** (bzw. III) mit einer Zeile zum Boss läuft durchs Bild.
* **Danach:** Der Boss gleitet aus seiner Lage ins neue Bewegungsmuster und bleibt sichtbar
  wütender eingefärbt.

---

## 6. Spielmodi

* **Neue Kampagne** – zehn Level mit Zwischensequenzen, Zwischenbossen und Endkampf.
  Dauer etwa 60–90 Minuten. Vor Bossen liegt jeweils ein Checkpoint.
* **Fortsetzen** – setzt am letzten Checkpoint des gespeicherten Laufs fort.
* **Training** – einzelne Level oder Bosse üben. Getrennt von der Kampagne: kein
  Fortschritt, keine Evolutionen, keine Belohnungen; der Kampagnenstand bleibt
  unverändert.
* **Boss-Rush** – wird nach dem Abspann freigeschaltet. Zehn Bosse in Folge mit einer
  Kopie deines vollständigen Builds; keine zusätzlichen Evolutionen.
* **Einstellungen**, **Credits**, **Spiel beenden**.

Im Hauptmenü beendet `Esc` das Spiel **nicht** – zum Beenden gibt es den Eintrag
`Spiel beenden` mit Rückfrage. Im Pausenmenü beenden beide Beenden-Einträge das
Spiel wirklich und speichern vorher.

**Pausenmenü:** Fortsetzen, Neustart am Checkpoint, Einstellungen, Build-Übersicht,
Zurück zum Hauptmenü, Spiel beenden. `Esc`/`Start` setzt das Spiel fort – auch aus
den Einstellungen heraus.

---

## 6a. Die zehn Bosse

Jeder Boss hat eigene Musik (sie beginnt erst, wenn er erscheint), ein eigenes
Bewegungsmuster und eigene Angriffe:

| Level | Boss | Bewegung | Besonderheit |
|---|---|---|---|
| 1 | Gepanzerter Rosenkäfer | Pendelbahn | Panzer klappt auf, dann ist der Rücken verwundbar |
| 2 | Grabende Riesenlarve | gräbt sich ein und bricht an anderer Stelle durch | Kopf nach dem Durchbruch ungeschützt. Erdsäulen-Tunnelfahrt, Deckeneinsturz mit freier Lücke, Madenbrut; drei Phasen |
| 3 | Schilfhecht | prescht in einer Bahn | Lanzenstoß, danach kurze Erholung |
| 4 | Parasitäres Pilzwesen | drifet in weiter Kreisbahn | setzt Sporenwolken, die den Sichtbereich einnebeln |
| 5 | Mantidenpaar | zwei Körper, schnelle Wechsel | beide Hälften müssen fallen |
| 6 | Mechanischer Bestäuber | kreist um einen Ankerpunkt | Panzerphasen wechseln mit Spiegelvolleys |
| 7 | Mutierter Wasserläufer | gleitet über eine Bahn | Wassermechanik: Strömung drückt dich mit |
| 8 | Insektenförmige Erntemaschine | prescht vor und zurück | Scanlinie, danach Sperrfeuer |
| 9 | Schwarmkönigin | Achterbahn | ruft Wächter, Spiralfeuer |
| 10 | Kernorganismus | erste Form, dann Wiedergeburt mit drei eigenen Phasen | neue Gestalt, 175 % der ersten Maximal-HP, kürzere Angriffspausen |

**Mit jedem Level steigen Verhalten und Lebenspunkte.** Zusätzlich zu den
verschiedenen Boss-Grundwerten wächst der unabhängige Boss-HP-Faktor bis etwa
2,53 auf Level 10. Die unterlineare Waffenanpassung nimmt Upgrades ihren Gewinn
nicht wieder vollständig weg. Daneben steigt die Bedrohungsstufe (1 bis 5):

| Stufe | Level | Was dazukommt |
|---|---|---|
| 1 | 1–2 | Grundverhalten, ein Bewegungsmuster |
| 2 | 3–4 | kürzere Pausen zwischen den Angriffen |
| 3 | 5–6 | eine zusätzliche Schlussphase mit dem härtesten Muster |
| 4 | 7–8 | jede Phase bekommt ein zweites Muster, der Boss wechselt alle 7,5 s die Bewegung |
| 5 | 9–10 | zwei Zusatzmuster in der Schlussphase, dichterer Takt, schnellere Kugeln |

Zusätzlich sinkt der Angriffstakt mit dem Level um bis zu 38 %, Gegnerkugeln
werden bis zu 31 % schneller, und die Bossmusik steigt von 150 auf 196 BPM.

## 6b. Game Over und Weitermachen

Stirbst du, läuft zwei Sekunden lang die Todesanzeige, danach erscheint der
**Game-Over-Bildschirm**. Er bietet zwei Wege:

| Eintrag | Wirkung |
|---|---|
| **Weiter am Kontrollpunkt** | Der Lauf geht am letzten Checkpoint weiter. **Die taktischen Upgrades der unteren Leiste starten neu** (gekaufte Zusätze 0, kostenlose Basis 1, Nektar 0). Werkstatt-Käufe und Evolutionen bleiben. |
| **Run beenden** | Der Lauf ist vorbei, die Kampagne wird gelöscht, du landest im Hauptmenü. Was im Profil steht (Evolutionen, Bestwerte, freigeschaltete Level), bleibt. Im Menü steht dann „Run beendet – die Evolutionen im Profil bleiben erhalten.“ und **Fortsetzen ist gesperrt**. |

**Drei Versuche pro Lauf.** Der Bildschirm zeigt „Game Over 1 von 3“. Nach dem
dritten Game Over gibt es **kein Weiter mehr** – es bleibt nur „Zum Hauptmenü“,
der Lauf ist vorbei. Der Zähler gilt für den ganzen Lauf und wird bei einer
neuen Kampagne zurückgesetzt.

Warum der Reset: Die Leiste ist die *taktische* Ebene – Aufbau, der innerhalb
eines Levels entsteht und wieder verfällt. Die Werkstatt ist die *dauerhafte*
Ebene, die du mit Punkten über den ganzen Lauf bezahlst. Ein Weiter, das beides
behielte, würde den Tod zur bloßen Zeitstrafe machen; ein Weiter, das beides
löschte, würde gekaufte Punkte verbrennen. Getrennt bleiben beide sinnvoll.

---

## 7. Schwierigkeit

| Stufe | Leben | Gegnerfeuer | Anmerkung |
|---|---|---|---|
| Entspannt | 4 | langsamer, weniger Gegner | zum Kennenlernen |
| Normal | 3 | Referenzwert | Standard |
| Experte | 3 | schneller, mehr Schaden, engere Unverwundbarkeit | für geübte Spieler |

Alle zehn Level und der Abspann sind in jeder Stufe spielbar.

---

## 7a. Warum die Gegner mithalten

Stärkere Bewaffnung führt zu einer **unterlinearen**, nicht vollständigen
Gegneranpassung. Mehr Schaden darf die Abschusszeit im selben Level verkürzen.
Evolutionen werden nicht durch pauschale Lebenspunktaufschläge neutralisiert.
Breitere Salven, Durchschlag, Kettenblitze und Flächenschaden helfen zusätzlich
gegen ganze Wellen.

Unabhängig davon wächst der **Leveldruck**: auf Level 10 bis zu 1,90-fache
Gegnerleben, 2,53-fache Bossleben, 1,45-fache Spawnrate und 1,36-facher Feuertakt.
Das ist der zusätzliche Level-Faktor, nicht die absolute Lebenspunktzahl jedes
unterschiedlichen Bosses.

Kugelzahlen und Kaskaden bleiben begrenzt, damit die Verbesserungen kombinierbar
bleiben, ohne das Spielfeld zu verdecken. Messungen mit tatsächlichen Builds
stehen im [R2-Weltbericht](<STINGFORGE_R2_WORLD.md>); ideale HP/DPS-Zeiten sind
keine behaupteten echten Bosskampfzeiten.

## 7b. Highscores

**Highscores** im Hauptmenü zeigt lokale Run-Ranglisten: Kampagne und Boss-Rush
getrennt, nach Schwierigkeit filterbar, als Top 10 oder Top 20. Gezählt werden
verdiente Gesamtpunkte, unabhängig davon, wie viel bereits in der Werkstatt
ausgegeben wurde. Der Nektarumrechnungsbonus zählt genau einmal dazu.

Einträge entstehen beim endgültigen Game Over, ausdrücklichen Runende oder Sieg.
Continues bleiben derselbe Run; Training zählt nicht. Alte Levelbestwerte werden
nicht zu erfundenen Runpunkten addiert. Schätzwerte eines fortgesetzten alten
Runs tragen einen Stern. Details: [R2-Bericht](<STINGFORGE_R2.md>).

---

## 8. Einstellungen

Sechs Kategorien, mit `LB`/`RB` bzw. `Q`/`E` erreichbar:

* **Anzeige** – Monitor, Auflösung, Fenster/Randlos/Vollbild, V-Sync,
  Bildratenbegrenzung, Skalierung, UI-Größe.

  **So änderst du die Auflösung:** Monitor, Auflösung und Fenstermodus mit
  **links/rechts** (A/D, Pfeiltasten, Stick) durchschalten. Der neue Wert
  erscheint sofort in der Zeile, mit einem **•** dahinter – übernommen ist er
  noch nicht. Mit **Leertaste bzw. A** auf einer dieser Zeilen (oder auf
  *Anzeige übernehmen* direkt darunter) wird die Änderung angewendet. Danach
  fragt das Spiel 15 Sekunden lang *„Anzeige behalten?“*: **A/Leertaste**
  behält sie, **B/Esc** stellt das vorherige Bild wieder her, ohne Antwort
  wird automatisch zurückgestellt.

  Angeboten werden nur Auflösungen, die auf den angeschlossenen Monitor passen –
  die Liste ist also je nach Bildschirm kürzer. Die Auflösung wirkt im
  Fenstermodus; randlos und Vollbild richten sich nach dem Monitor. V-Sync,
  Bildratenbegrenzung, Skalierung und UI-Größe wirken sofort.
* **Grafik** – Effekte, Partikel, Bildschirmwackeln, Blitze, Nachbearbeitung,
  **Beleuchtung & Schatten** (Lichteinfall und Vignette), optionaler CRT-Filter.
* **Audio** – Master, Musik, Effekte, UI getrennt; Stummschaltung bei Fensterverlust.
* **Steuerung** – Tastenbelegung für Tastatur und Controller, Deadzone,
  Empfindlichkeit, Vibration.
* **Spiel** – Autofeuer-Voreinstellung, Hinweise, Trefferzonenanzeige.
  Die Schwierigkeit wird ausschließlich beim Start von Kampagne oder Boss-Rush
  gewählt und bleibt während des Runs fest.
* **Zugänglichkeit** – Schriftgröße, reduzierte Effekte, Kontrastmarkierung
  gefährlicher Objekte.

Jede Kategorie hat **Standard wiederherstellen**. Audio- und Spieländerungen
werden beim Verlassen der Kategorie übernommen, Anzeigeänderungen erst mit
**Anzeige übernehmen** (oder wenn du die Einstellungen mit Esc verlässt).

---

## 8a. Schriftarten

Das Spiel nutzt zwei freie Schriften, die mitgeliefert werden und keine
Systemschrift voraussetzen:

* **Nunito** für Fließtext, Beschreibungen und Zahlen – freundlich und auch in
  kleiner Größe gut lesbar.
* **Oxanium** für Überschriften, Levelnamen und den BOSS-Schriftzug – technisch,
  kantig, passend zum Insekten-Setting.

Beide stehen unter der SIL Open Font License (die Lizenztexte liegen im Ordner
`assets/ui/fonts/`). Die Schriftgröße lässt sich unter **Einstellungen →
Zugänglichkeit → Schriftgröße** in Stufen verstellen; alle Bildschirme skalieren
mit.

---

## 9. Wenn etwas nicht läuft

* **Schwarzer Bildschirm nach Anzeigeänderung:** 15 Sekunden warten – die Änderung
  wird automatisch zurückgenommen.
* **Kein Ton:** im Abschnitt Audio prüfen, ob eine der vier Gruppen auf 0 steht.
  Das Spiel wird stumm, wenn das Fenster den Fokus verliert (einstellbar).
* **Controller wird nicht erkannt:** Controller anschließen und das Spiel neu
  starten; im Abschnitt Steuerung wird das erkannte Gerät angezeigt.
* **Speicherstand zurücksetzen:** `settings.json`, `profile.json`, `campaign.json`
  im oben genannten Ordner löschen.

Viel Erfolg – der Kern wartet.
