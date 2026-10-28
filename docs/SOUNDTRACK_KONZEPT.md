# Soundtrack-Konzept: ein Song je Level, ohne Loops

Stand: 28.10.2026 · Vorschlag zur Freigabe – es ist noch nichts installiert oder gerendert.

## 1. Grundidee

- **Ein durchkomponierter Track je Level**, der exakt so lang ist wie der Weg vom Levelstart bis
  zum Einsatz der Bossmusik. Kein Loop, keine Wiederholungsnaht.
- **Form folgt dem Level:** Die fünf Abschnitte (= Checkpoints) sind die fünf Teile des Songs.
  Der Miniboss bekommt einen festen musikalischen Einschnitt, die letzten 1,25 s (Bossankündigung
  mit Warnton und Bildschirmrütteln) sind ein Riser mit hartem Abriss in die Bossmusik.
- **Leitmotiv:** Ein kurzes Stingforge-Thema (4 Takte) wird in Level 1 vorgestellt und zieht sich
  verwandelt durch alle Level: in Dur, in Moll, rhythmisch verschoben, mechanisiert. In Level 9
  kehren die Motive aller Level zurück, in Level 10 erscheint das Thema in seiner „verwandelten“ Form.
- **Hommage, keine Kopie:** Klangfarben dürfen an die Amiga-Ära erinnern (helle Arpeggien,
  knackige Bässe, Ping-Pong-Echos), Melodien und Harmonien sind eigenständig.
- **Tempokarte:** Jeder Abschnittswechsel fällt exakt auf einen Taktanfang. Wo die Abschnittslänge
  nicht aufgeht, korrigiert die Tempokarte um 1–2 BPM (unhörbar).

## 2. Ziellängen (aus `scripts/autoload/data.gd` und `director.gd`)

Länge = Intro 2,2 s + Summe der Abschnitte + 1,25 s Bossankündigung.

| Level | Abschnitte (s) | Miniboss bei | Tracklänge |
|---|---|---|---|
| 1 Blütenmeer | 56 · 62 · 60 · 54 · 48 | 150 s | **283,45 s** (4:43) |
| 2 Wurzelreich | 60 · 62 · 60 · 54 · 46 | 148 s | **285,45 s** (4:45) |
| 3 Schilf und Teich | 56 · 62 · 60 · 54 · 46 | 146 s | **281,45 s** (4:41) |
| 4 Pilzwald | 56 · 62 · 60 · 54 · 48 | 148 s | **283,45 s** (4:43) |
| 5 Dornen im Sturm | 54 · 60 · 60 · 56 · 46 | 142 s | **279,45 s** (4:39) |
| 6 Gläsernes Gewächshaus | 56 · 62 · 60 · 54 · 46 | 146 s | **281,45 s** (4:41) |
| 7 Verlorene Kanalisation | 56 · 62 · 60 · 54 · 46 | 146 s | **281,45 s** (4:41) |
| 8 Maschinenherz | 56 · 62 · 60 · 54 · 46 | 144 s | **281,45 s** (4:41) |
| 9 Schwarmstock | 56 · 62 · 60 · 54 · 46 | 144 s | **281,45 s** (4:41) |
| 10 Kern der Verwandlung | 54 · 60 · 60 · 56 · 46 | 140 s | **279,45 s** (4:39) |

Miniboss-Zeiten zählen ab Ende des Intros (im Track also +2,2 s).

## 3. Level für Level

### Level 1 – Blütenmeer
- **Stimmung:** sonnig, leicht, Aufbruch. Der Spieler soll lächeln.
- **Harmonik:** D-Dur mit lydischer Färbung (erhöhte Quarte) für ein Glitzern; Kadenzen über IV–V–vi.
- **Tempo/Takt:** 120 BPM, 4/4. Bei 120 BPM ergibt jede gerade Abschnittslänge ganze Takte.
- **Klang:** Harfen- und Kalimba-Arpeggien als „Pollenflug“, Flöte als Melodie, warme Pads,
  Glockenspiel-Akzente, leichter Breakbeat. Ein weicher FM-„Summton“ als Bienenfarbe.
- **Form:**
  - **A:** Arpeggio allein, dann das Leitmotiv auf der Flöte.
  - **B:** Bass und voller Beat setzen ein.
  - **C:** Bei 150 s, zum „Blütengeschütz“, Pizzicato-Staccato plus Trommelwirbel. Danach Rückung nach E-Dur.
  - **D:** breite Reprise.
  - **E:** Moll-Eintrübung als Vorbote des Rosenkäfers, Riser, Abriss.

### Level 2 – Wurzelreich
- **Stimmung:** unterirdisch, erdig, tastend-bedrohlich, aber nicht hoffnungslos.
- **Harmonik:** A-Moll mit phrygischer kleiner Sekunde (b2) als „Grabgeräusch“-Reibung.
- **Tempo/Takt:** 112 BPM, Halftime-Gefühl.
- **Klang:** tiefe Taikos und Schlitztrommel, Kontrabass-Pizzicato, eine Drohne mit Formantfilter
  (didgeridoo-artig), Fagott und Bassklarinette, Holz-Knarzgeräusche.
  Ausfahrende Wurzeln bekommen ein wiederkehrendes perkussives „Stab“-Motiv.
- **Form:**
  - **A/B:** Die Drohne wächst langsam zum Groove.
  - **C:** Miniboss bei 148 s, mit Sub-Bass-Grollen und rhythmischer Verdichtung.
  - **E:** Pulsierendes Grollen, das sich „eingräbt“, als Vorbote der Larve. Riser, Abriss.

### Level 3 – Schilf und Teich
- **Stimmung:** fließend, glitzernd, verspielt mit plötzlichen Sprüngen; zwei Welten (über und unter Wasser).
- **Harmonik:** G-Dur mit mixolydischen Wendungen. Die Melodie springt in Oktaven (Hechtsprünge).
- **Tempo/Takt:** 96 BPM im 12/8-Gefühl (wiegend), Hi-Hats in Triolen.
- **Klang:** Marimba und Vibraphon, gezupfte Gitarre, Wassertropfen als resonante Filter-Blips,
  hauchige Rohrflöte. Unter der Wasserlinie: tiefpassgefilterte Fassung desselben Materials,
  musikalisch „abtauchen“.
- **Form:**
  - **Wechsel:** Die Abschnitte pendeln zwischen „über“ (hell, offen) und „unter“ Wasser (dumpf, hallig).
  - **C:** Miniboss bei 146 s.
  - **E:** Der Bass macht Oktavsprünge und kündigt den Hecht an.

### Level 4 – Pilzwald
- **Stimmung:** mysteriös, schwebend, leicht psychedelisch; giftig-schön.
- **Harmonik:** Fis-dorisch mit Ganzton-Einschüben. Akkorde ohne Terz bleiben offen und unentschieden.
- **Tempo/Takt:** 90 BPM, Trip-Hop-Groove. Wandernde Sporenfelder als feiner 3-gegen-4-Polyrhythmus.
- **Klang:** granulare Pads, Glasharmonika, Celesta, ein verstimmter „Ah“-Chor,
  Bitcrush-Partikel für Sporen und ein leichtes Tape-Wobble (Tonhöhenschwanken).
- **Form:**
  - **A–B:** Nebel lichtet sich langsam.
  - **C:** Miniboss bei 148 s.
  - **D:** Der Chor wächst.
  - **E:** Drei Glockentöne als Vorbote der „drei Angriffsknoten“ des Pilzwesens.

### Level 5 – Dornen im Sturm
- **Stimmung:** dramatisch, getrieben, Gefahr. Hier zieht das Spiel an.
- **Harmonik:** E-Moll / harmonisch Moll, scharfe Leittöne.
- **Tempo/Takt:** 150 BPM.
- **Klang:** Streicher-Ostinati (Spiccato), Taiko, tiefe Blechbläser-Stöße, Sägezahn-Lead.
  Wind als gefiltertes Rauschen, dessen Panorama und Filter mit den Windzonen „drücken“.
- **Form:**
  - **Gesamt:** Zwei Stimmen im Frage-Antwort-Kanon (das Mantis-Paar).
  - **C:** Miniboss bei 142 s.
  - **E:** Die Kanonstimmen fallen auf einen gemeinsamen Schlag zusammen („Kreuzhieb“). Riser, Abriss.

### Level 6 – Gläsernes Gewächshaus
- **Stimmung:** kühl, kristallin, präzise; schön, aber steril.
- **Harmonik:** H-Dur lydisch, schwebende Sus-Akkorde.
- **Tempo/Takt:** 120 BPM, strenges 16tel-Raster.
- **Klang:** FM-Glocken, Glasharmonika, Pluck-Arpeggien, Sequencer-Bass, feine Glitch-Klicks.
  Die Glasflächen „blinken viermal“, dazu wird ein Vier-Schlag-Glockenmotiv zum Leitbaustein.
- **Form:**
  - **Gesamt:** Phasenverschobene Arpeggien, die sich langsam gegeneinander drehen,
    als Vorbote der rotierenden Panzerung des Bestäubers.
  - **C:** Miniboss bei 146 s.

### Level 7 – Verlorene Kanalisation
- **Stimmung:** dunkel, feucht, verlassen, weiter Hall.
- **Harmonik:** C-Moll / phrygisch, sparsame Harmonik.
- **Tempo/Takt:** 100 BPM, Dub- und Industrial-Groove.
- **Klang:** metallische Perkussion (Rohre, Tropfen), Dub-Delay, Sub-Bass, leicht verstimmtes
  Klavier im Fernhall. Ein periodischer Pumpenpuls (Schleusen); die Strömung als langsame Filterfahrt.
- **Form:**
  - **Gesamt:** Ein gleitender Portamento-Lead als Vorbote des Wasserläufers.
  - **C:** Miniboss bei 146 s.
  - **E:** Die Pumpen setzen aus, Stille und Tropfen, dann Riser.

### Level 8 – Maschinenherz
- **Stimmung:** mechanisch, unerbittlich, Fabrikhalle.
- **Harmonik:** G-Moll.
- **Tempo/Takt:** 140 BPM, gelegentliche 7/8-Takte als „stotternde Maschine“.
- **Klang:** Acid-Sequencer-Bass, Industrial-Drums (Hammer, Kolben, Amboss), metallische FM-Stöße,
  Chorpads. Ringsalven der Generatoren werden zu kreisenden Arpeggien.
- **Form:**
  - **Gesamt:** Module kommen Schicht für Schicht hinzu, wie bei der Erntemaschine.
  - **C:** Miniboss bei 144 s.
  - **E:** Alles rastet auf einen Schlag ein.

### Level 9 – Biomechanischer Schwarmstock
- **Stimmung:** Bedrohung durch die Masse; Chitin und Stahl.
- **Harmonik:** A-phrygisch gegen A-mixolydisch, Reibung zwischen Natur und Maschine.
- **Tempo/Takt:** 146 BPM.
- **Klang:** ein Schwarm aus vielen verstimmten Sägezähnen (Summen), Chor, Industrial-Percussion
  plus Taikos, Streicher.
- **Form:**
  - **Gesamt:** Wie das Level („alle bisherigen Muster kehren kombiniert zurück“) zitiert jeder
    Abschnitt Motive zweier früherer Level.
  - **C:** Miniboss bei 144 s.
  - **E:** Ein hymnisches Chormotiv für die Königin.

### Level 10 – Kern der Verwandlung
- **Stimmung:** episch, final, organisch-kosmisch; die Schwerkraft zieht.
- **Harmonik:** D-harmonisch Moll. Das Leitmotiv aus Level 1 (D-Dur) kehrt verwandelt in Moll zurück.
- **Tempo/Takt:** 128 BPM.
- **Klang:** Orgel, großer Chor, ein Herzschlag-Puls als Kick („Der Kern schlägt“),
  Sub-Drops für die Schwerkraftfelder, Orchester-Tutti.
- **Form:**
  - **C:** Miniboss bei 140 s.
  - **E:** Der Herzschlag beschleunigt, setzt kurz aus, dann Abriss in die Bossmusik.

## 4. Nötige Spielanpassungen (nach Freigabe, klein)

Damit Musik ohne Loop sicher passt, folgt sie der Levelzeit statt der Uhr:

1. **Kein Loop** für `level1..10` (Bossmusik, Menü und Abspann bleiben geloopt).
2. **Pause pausiert die Musik** (heute läuft sie in der Pause weiter und würde sonst vorlaufen).
3. **Checkpoint-Neustart** springt im Track an die Checkpoint-Zeit, statt von vorn zu beginnen.
4. **Mitlaufkontrolle:** Weicht die Wiedergabe mehr als ca. 0,25 s von der Levelzeit ab
   (Ruckler, Ladezeit), wird nachgestellt. Zusätzlich schneidet die Bossmusik den Track ohnehin ab.

## 5. Software (Open Source, CachyOS/Arch-Repos)

Bewusst textbasiert und skriptbar: Ich kann diese Werkzeuge vollständig und reproduzierbar
bedienen. Grafische DAWs wie Ardour, LMMS oder MuseScore kann ich nicht zuverlässig bedienen,
sie sind daher nicht Teil des Vorschlags.

| Paket (pacman, Repo „extra“) | Zweck | Status |
|---|---|---|
| `csound` 6.18 | Hauptengine: Synthese, Sampler, Effekte, Mix; rendert offline sample-genau aus Textdateien | neu |
| `sfizz` 1.2.3 | SFZ-Sampler; `sfizz_render` macht MIDI → WAV ohne Oberfläche; für echte Instrumente (Harfe, Flöte, Streicher, Chor, Marimba) | neu |
| `python-mido` 1.3 | Komposition als Python-Skript → MIDI mit exakter Tempokarte | neu |
| `python-scipy`, `python-soundfile` | Messung: Länge, Pegel, Spektrogramm, Abschnittsgrenzen | neu |
| `sox`, `ffmpeg` | Schnitt, Lautheit (EBU R128), OGG-Export | vorhanden |
| `fluidsynth` | Ersatzweg für SF2-Klänge | vorhanden |

**Optional:**

| Paket | Zweck | Hinweis |
|---|---|---|
| `surge-xt` + `python-pedalboard` | Moderner Synthesizer, offline aus Python gehostet | sehr gute Synthesizerfarben; Hosting ohne Oberfläche vorher kurz testen |
| `supercollider` + `sc3-plugins` | Alternative zu Csound | nur nötig, wenn Csound an Grenzen kommt |

Installationsbefehl (nur nach Freigabe):

```bash
sudo pacman -S csound sfizz python-mido python-scipy python-soundfile
```

### Klangbibliotheken (Download, ebenfalls nur nach Freigabe)

Beide sind **CC0** (gemeinfrei): keine Namensnennung, keine Lizenzfragen für ein veröffentlichtes Spiel.

| Bibliothek | Inhalt | Lizenz |
|---|---|---|
| VSCO 2 Community Edition (SFZ) | Orchester: Streicher, Holz, Blech, Harfe, Perkussion | CC0 |
| Versilian Community Sample Library, VCSL (SFZ) | Kalimba, Marimba, Glockenspiel, Celesta, Ethno-Perkussion, Orgel u. a. | CC0 |

Ablage unter `tools/audio/samples/` (wird nicht ins Git aufgenommen).

## 6. Arbeitsweise und Qualitätssicherung

1. **Komposition** als Python-Skript je Level: Abschnitte, Tempokarte, Leitmotiv-Varianten → MIDI.
2. **Klang:** sfizz für akustische Instrumente, Csound für Synthesizer, Geräusche und Effekte.
3. **Mix und Master** in Csound: Bus-Hall und -Delay, Sidechain, Limiter.
   Ziel: -16 LUFS integriert und maximal -1 dBTP, über alle Level gleich laut.
4. **Messung mit Prüfprotokoll:**
   - Länge auf ±10 ms genau.
   - Abschnittsgrenzen liegen auf Taktanfängen.
   - Keine Übersteuerung, Lautheit eingehalten.
   - Spektrogramm je Track.
5. **Grenze:** Ich höre nicht selbst. Messwerte sichern die Technik ab; ob ein Track die Stimmung
   trifft, entscheidest du beim Anhören. Ich schlage vor, zuerst **Level 1 als Muster** zu
   produzieren und nach deinem Feedback die übrigen neun.
