# Stingforge: Waffen, Werkstatt und Evolutionen

## Ergebnis und Zuständigkeit

**91 gezielte Regression-/Ereignisprüfungen und 1.153 Matrixprüfungen sind grün**, jeweils mit echtem Returncode 0. Die Matrix umfasst **4 Hauptwaffen × 32 Werkstattartikel × 3 Kaufstufen = 384 Konfigurationen**, **192 Form-/Zusatzmusterpaarungen**, 2.560 kontrollierte Treffer für den Splitterkern und vier zehnsekündige Maximalbuild-Simulationen. Alle 36 Evolutionen sind explizit auf Verbrauchsstellen abgebildet; diese **Quelltext-/Aggregationsabdeckung ist getrennt von semantischen Ereignistests** zu verstehen.

Geändert wurden in diesem Auftrag ausschließlich [Player](</home/floppi/Dokumente/DSH/Workspaces/Apidya/scripts/game/player.gd>), [BulletField](</home/floppi/Dokumente/DSH/Workspaces/Apidya/scripts/game/bullets.gd>) und [Werkstattdaten](</home/floppi/Dokumente/DSH/Workspaces/Apidya/scripts/game/shop_data.gd>) sowie die unten genannten eigenen Tests und dieses Dokument. Welt-/Boss-Kollisionen, Datenbanktexte, HUD, Manifest und Grafik waren fremde Zuständigkeiten. Die damit abgestimmten Schnittstellen sind weiter unten beschrieben.

## Reproduzierbare Prüfung

Aus dem Projektstamm, Godot **4.7.2**, ohne Editorstart oder Grafikimport:

```bash
XDG_DATA_HOME="$PWD/build/stingforge-testdata-weapons" \
  godot --headless --audio-driver Dummy --path "$PWD" \
  res://tests/stingforge_weapons_probe.tscn

XDG_DATA_HOME="$PWD/build/stingforge-testdata-weapons" \
  godot --headless --audio-driver Dummy --path "$PWD" \
  res://tests/stingforge_weapons_matrix.tscn
```

- [Gezielte Probe](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_weapons_probe.gd>) / [Startszene](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_weapons_probe.tscn>): `STINGFORGE_WEAPONS checks=91 failures=0`, `STINGFORGE_WEAPONS_OK`, Exit 0.
- [Vollmatrix](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_weapons_matrix.gd>) / [Startszene](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_weapons_matrix.tscn>): `STINGFORGE_WEAPONS_MATRIX checks=1153 failures=0`, `STINGFORGE_WEAPONS_MATRIX_OK`, Exit 0.
- [Messwerte](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge_weapons_metrics.json>): jede Waffenstufe, alle 384 Werkstatt-Outcomes, alle 192 Paarungen mit Schaden/Schusszahl/Endpositionen nach einer halben Sekunde und die Maximalbuildwerte. Die Datei wird bei jedem Matrixlauf erneuert.
- Zusätzlich selbst ausgeführt: [Welt-Synergieprüfung](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_world_synergy.gd>) / [Szene](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_world_synergy.tscn>), **60/60 grün**, `STINGFORGE_WORLD_SYNERGY_OK`, Exit 0. Diese Tests und die zugehörigen Weltänderungen stammen vom Welt-Agenten.

Es wurden ausschließlich eigene Vordergrundprozesse gestartet; es bleiben keine eigenen Hintergrundjobs offen. Spielstände liegen nur im isolierten XDG-Unterordner. Gelegentliche `ObjectDB`-/`resources still in use`-Meldungen beim Dummy-Audio-Shutdown wurden mit `--verbose` auf Audio-Playbacks eingegrenzt; sie sind **keine Script-/Parsefehler**. Die letzten Matrixläufe waren auch beim Shutdown sauber. Die Tests prüfen ihre Assertions und echte Returncodes, nicht nur eine Erfolgsausgabe.

### Nachweis: vor dem jeweiligen Fix rot

Die gezielte Probe wurde schrittweise erweitert und vor jeder folgenden Produktionskorrektur ausgeführt:

| Roter Lauf | Fehler | Tatsächlich reproduzierte Ursache |
|---|---:|---|
| 7 Prüfungen | 7 | Plasma-Kreisstapel; frühes `continue` ignoriert Welle/Zielsuche; fehlendes echtes Segment; Basisprofil der Spirale; Orbit-/Wellen-`elif`; Formensperre |
| 19 Prüfungen | 11 | Schildkauf ohne Ladung, höhere Stufe ohne Kapazität, Grenze `>12` statt `>=12`, Shop-Aura/Reset/Gates, fehlendes HUD-API, Bastion/Shop, Nektarstau, Schnellfeuer-Cap, Rhythmusstufe2 und Endton |
| 25 Prüfungen | 5 | gespeichertes MaxHP doppelt bonifiziert; fünfte Drohne unsichtbar; Schwarmecho spiegelt nicht; Sammelinstinkt mit `*0.0` deaktiviert; Crit-Evolution fehlt im Angriffsmesswert |
| 32 Prüfungen | 7 | Ganzzahlrundung macht Panzerhaltung und Völlerei bei normalen 1er-Treffern/-Drops wirkungslos; Bossgeschenk fälschlich mit Pickupbonus |
| 34 Prüfungen | 2 | trotz abgewiesener Geschosse am 320er-Cap gezählter Schaden/Schusszahl |
| 86 Prüfungen | 3 | leere Salve fällt auf Vor-erster-Schuss-Schaden zurück; Winkeladdition dreht Heck nach vorn und Seiten an den falschen Ort |
| 87 Prüfungen | 1 | Rückwärtsflug verwendet wegen `abs(vel.x)` dieselbe Angriffsreihe wie Vorwärtsflug |
| 91 Prüfungen | 4 | HP-Persistenzfix unterschreitet die ausdrücklich vorgesehene Vierer-Basis des Boss Rush, auch nach Werkstatt-Neuberechnung/Reload |

Auch die Vollmatrix war zunächst rot: **Plasma + Splitterwolke Stufe1** blieb wegen `max(28,20)` wirkungslos. Jetzt addiert sich der Shopradius zur Waffe. Zwei Arten anfänglich roter **Testaliasing-Befunde** wurden am Messverfahren, nicht an der Produktion korrigiert: zwölf Salven unterscheiden die Perioden sechs/fünf nicht zuverlässig (jetzt 60); eine reine Endpunktsumme kann symmetrische Fächerwellen auslöschen (jetzt zusätzlich tatsächlich zurückgelegte Weglänge).

## Hauptwaffen und Zusatzmuster

Unveränderte nackte Hauptwaffen, ohne Schadens-/Tempo-Boni:

| Waffe | Stufen | Kugeln pro Salve | Rohschaden pro Salve | Eigenwirkung |
|---|---|---|---|---|
| Basis | 1 | 2 | 14,8 | zwei versetzte Stacheln, 760 px/s |
| Fächer | 1/2/3 | 3/4/5 | 15,6 / 20,8 / 26,0 | breitere Winkelabdeckung, 640 px/s |
| Blitz | 1/2/3 | 2/2/3 | 11,6 / 11,6 / 17,4 | ein eigener Durchschlag; 2/3/4 Kettensprünge, 940 px/s |
| Plasma | 1/2/3 | 1/2/3 | 18,4 / 36,8 / 55,2 | Radius28 Flächenschaden; kleine Fächerwinkel, 430 px/s |

Heck, Seite, Nebenlauf, Spirale und Salve übernehmen **ein Einzelgeschossprofil der ausgerüsteten Waffe**, niemals den gesamten Fächer erneut. Plasma behält Art/Flächenwirkung, Blitz behält Durchschlag und Blitzkette; relative Musterschäden und Geschwindigkeitsverhältnisse bleiben unterscheidbar. Schwarmecho spiegelt ebenfalls dieses Einzelprofil. Normale Drohnen bleiben als Drohnenstachel erkennbar, erhalten aber die gekauften globalen Projektilmodifikatoren.

Mengengrenzen bleiben erhalten:

- höchstens **2 Heck**, **1 je Seite**, **1 Nebenlauf**;
- **1 Spiralkugel jede dritte Salve**, Winkel wird über den Salvenzähler weitergedreht;
- **2 Burst-Zusätze jede sechste/fünfte/vierte Salve**; die dritte Stufe war zuvor durch `max(5, burst)` unsichtbar;
- höchstens **5 sichtbare Drohnen** aus drei taktischen und zwei Evolutionsstufen;
- `MAX_PLAYER=320`, `MAX_ENEMY=420`, `MAX_RATE_BONUS=0.30`, `MIN_INTERVAL=0.095` unverändert.

### Komponierte Flugbahnen

Eine Trägerbewegung (`path_p`, `travel_v`) ist von der tatsächlichen Tangente (`v`) getrennt. Dadurch verstärkt eine Welle nicht irrtümlich ihre eigene Geschwindigkeitsableitung. Sie schwingt quer zur **ursprünglichen bzw. gelenkten Schussrichtung**, nicht nur entlang der Welt-Y-Achse. Gearbeitet wird mit zurückgelegtem Weg und Wellenlänge.

Im Kreisflug bleiben Schussrichtung und transversaler Mündungsoffset erhalten. Ein separater Salvenwinkel und Mindestabstand der Phasen verhindern identische Stapel. Heck startet hinten, Seite oben/unten; eine Addition zweier absoluter Winkel würde einen Heckschuss irrtümlich um eine ganze Umdrehung nach vorne setzen. Der Eintritt in den Kreis erfolgt über 160 ms statt mit einem Teleport.

- **Kreis + Welle:** Welle moduliert den Kreisradius.
- **Kreis + Zielsuche:** begrenzter Zielzug beeinflusst die Kreisphase, die Kreisbewegung bleibt erhalten.
- **Welle + Zielsuche:** Zielsuche lenkt die Trägerbahn, Welle liegt quer dazu.
- **Alle drei:** beide Modifikationen werden angewendet; kein früher Abbruch.
- **Spirale + Kreis**, insbesondere **Plasma + Spirale + Kreis:** die gerichtete Spiralkugel wird tatsächlich in dieselbe Formkomposition aufgenommen und behält Plasma-Splash.

Die alte exklusive `form`-Gruppe ist deshalb aufgehoben. Bestehende Stände mit mehreren Formen verlieren keine gekaufte Fähigkeit. Die Gruppen-Hilfsfunktionen bleiben für bestehende Aufrufer kompatibel.

**Numerische Gegenprobe:** `(300,400)` px/s, Start `(200,200)`, Wellenlänge100, Amplitude20 ergeben nach 0,05 s exakt `(199,232)` und nach 0,10 s `(230,240)`. Eine reine Welt-Y-Welle könnte diese bekannte Diagonalbahn nicht erfüllen.

## Werkstatt: sämtliche Modifikatoren

Jeder Artikel wurde mit **jeder Hauptwaffe auf allen drei Stufen** gegen die vorherige Stufe verglichen. Benötigte Grundfähigkeiten werden im Test bereitgestellt; Frischer Nektar wird absichtlich bei niedrigen HP und erhöhter MaxHP-Grenze geprüft. So kann ein voller Lebensbalken keine scheinbare Wirkungslosigkeit vortäuschen.

| Artikel | Sämtliche Schlüssel | Beobachteter Nachweis / Consumer |
|---|---|---|
| Kreisflug | `orbit, orbit_r, orbit_w` | andere reale Bahn und Weglänge, Radius-/Drehgeschwindigkeitssteigerung |
| Wellenschuss | `wave, wave_amp, wave_len` | reale Bahn/Weglänge; auch beim Fächer ohne Summenaliasing |
| Schnelle Wellen | `wave_speed` | höhere räumliche Frequenz, veränderte Bahn/Weglänge |
| Weite Wellen | `wave_amp_add, dmg` | Auslenkung und Salvenschaden steigen |
| Heckstachel | `back_n, back_dmg` | zusätzliche Rückschüsse, danach mehr Rückschaden statt weiterer Kugeln |
| Seitenstachel | `side_n, side_dmg` | je eine fliegende Seitenkugel, höhere Stufen steigern deren Schaden |
| Doppelläufe | `lanes_add, lane_dmg` | ein versetzter Einzel-Waffenlauf, danach mehr Wucht |
| Spiralschuss | `spiral` | verschiedene Richtungen/Endpositionen bei unveränderter begrenzter Frequenz |
| Zielsuche | `homing` | echte Wendung zu festem Ziel |
| Starke Zielsuche | `homing_add` | messbar stärkere Wendung mit bereitgestellter Grundzielsuche |
| Durchschlag | `pierce_add` | zusätzliches Durchschlagbudget am echten Projektil; Welt verbraucht es beim Treffer |
| Splitterwolke | `splash` | zusätzlich20/32/46 Radius; auch Plasma steigt von28 auf48/60/74 |
| Kettenblitz | `chain` | zusätzliches Kettenbudget; Welt-Synergieprüfung misst reale Nachbartreffer |
| Schwere Geschosse | `big, dmg` | Skalierung/Trefferradius und Schaden; Rendergröße nur einmal skaliert |
| Volltreffer | `crit` | 600 tatsächliche Schadenswürfe je Konfiguration, gepinnter Seed |
| Panzerbrecher | `boss_dmg` | tatsächlicher Boss-Schadensaufruf; auch Miniboss in Weltprüfung |
| Schnellfeuer | `fire_rate` | Schaden pro Takt steigt auf jeder Stufe, Taktlimit bleibt bestehen |
| Hochgeschwindigkeit | `bullet_speed` | real zurückgelegte Strecke; im Orbit proportional höhere Drehgeschwindigkeit |
| Salve | `burst` | 60 Salven unterscheiden Perioden6/5/4; zwei begrenzte Zusatzkugeln |
| Splitterkern | `splinter_chance` | 160 kontrollierte Treffer pro Waffen-/Stufenfall, reale freigesetzte Fragmente |
| Schildaufladung | `shield_regen` | einheitliche reale Nachladedauer12/8/6/4 s je nach Kaufstand |
| Zweiter Schild | `shield_add` | aktuelle Ladungen und maximale Kapazität |
| Zusätzliches Leben | `max_hp_add` | tatsächliches MaxHP, auch persistenz- und Rush-geprüft |
| Nachbrenner | `iframe_add` | reale Treffer-Unverwundbarkeitsdauer |
| Bombenradius | `bomb_radius` | Welt-API für tatsächlichen Radius150/210/255/300; Text sagt jetzt Radius statt Fläche |
| Bombenlager | `bomb_rate` | tatsächlicher automatischer Bombenzyklus |
| Blütenstaub-Magnet | `magnet` | tatsächliche Welt-Anziehungsreichweite |
| Reichere Beute | `nectar_plus` | tatsächliche Dropmenge; Weltprüfung erhält Werte auch oberhalb des Objektcaps |
| Streiftreffer | `graze` | reale Punkte nach knapp verfehlendem Gegnerprojektil |
| Serie | `combo` | reale Abschusspunkte; Bossbelohnung zusätzlich in Weltprüfung |
| Bessere Umrechnung | `convert_bonus` | echte Setup-Berechnung der Umrechnung für100 Nektar |
| Frischer Nektar | `start_heal` | tatsächliche Start-HP bei verletztem Build |

Schnellfeuerüberschuss wird mit `max(1, angeforderter_Takt × tatsächliches_Intervall / BASE_INTERVAL)` in Wucht umgerechnet. Das frühere harte Abschneiden machte Stufe3 wirkungslos. Wegen des zusätzlichen Mindestintervalls ist die praktisch höchste Taktsteigerung ungefähr24,2 %, nicht eine unbeschränkte30/45 %. Zusätzlicher Kaufwert wird nicht in eine neue Feuerquelle umgewandelt.

## Evolutionen: 36 nachvollziehbare Wirkungspfade

**E = semantischer Ereignis-/Verhaltenstest vorhanden**, **T = konkreter bestehender Consumer plus geprüfte Maxstufenaggregation**. T ist ausdrücklich kein Beweis für jede erdenkliche Interaktion. Zusätzlich läuft jede Evolution im gemeinsamen Maximalbuild. „Welt“ bezeichnet die separat ausgeführte Welt-Synergieprüfung bzw. ihre realen Produktionsverbrauchsstellen.

| Evolution | Wirkung und konkrete Verbrauchsstelle | Nachweis |
|---|---|---|
| Durchschlagstachel `pierce1` | `pierce` → Haupt-/Zusatz-/Resonanzgeschoss → Welt-Durchschlagverbrauch | T; Projektilbudget messbar |
| Splittstachel `splinter` | Treffer → begrenzte sekundäre Splitter; zwei je Evolutionsstufe | E Welt: keine Ursprungswiederholung/Rekursion, Shop ergänzt statt verdrängt |
| Gezielter Stich `crit` | `crit_chance` → kombinierte Critchance und Angriffsmesswerte | E: Erwartungswert im Player, tausende Würfe in Welt |
| Stakkato `stinger_rapid` | `fire_rate_mult, dmg_mult` → `fire_interval`, Wuchtkonversion, Schaden | T; Takt-/Maxbuildmessung |
| Schwerer Stachel `heavy_sting` | `dmg_mult, fire_rate_mult` → mehr Einzelschaden und langsamerer Takt | T; reale Damage-/Taktverbrauchsstellen |
| Nadelkette `pierce_master` | weitere zwei `pierce` → dieselben realen Projektilpfade | T; Budget addiert statt ersetzt |
| Formationsbegleiter `companion_form` | `companion_position`: Vorflug Angriffsreihe, Ruhe/Rückflug Kreis | E: beide Richtungen, nur mit freigeschalteter Drohne |
| Brutbegleiter `companion_add` | `companion_add` → Zahl aktiver Drohnen und Schützen | E: fünf sichtbare, fünf feuernde Einheiten; ohne Drohne inaktiv |
| Zielmarkierung `swarm_mark` | sechs Primärtreffer → `Game._mark_hit` → Schwarmangriff | E Welt: auch Boss, Markierung bei Tod bereinigt |
| Schwarmecho `swarm_echo` | `companion_rate` und Spiegelung eines Einzel-Waffenprofils | E: Plasma-Art und Splash kommen tatsächlich an |
| Opferdrohne `drone_sacrifice` | `drone_shield` → Intercept-Aufruf, acht Sekunden Cooldown | T: Player- und Welt-Interceptpfad |
| Schwarmruf `swarm_call` | fünf Abschüsse in drei Sekunden → `_swarm_strike` | T: Killzeitfenster und expliziter Eventconsumer |
| Pollenschleier `pollen_trail` | Bewegungsereignis → `spawn_pollen`, Stärke je Stufe | E Player; E Welt: Fläche, Timing, kein Selbstschaden |
| Staubexplosion `pollen_burst` | Killereignis → Pollen-Burst, direkter Nachbarschaden je Stufe | T: `_on_enemy_killed`, `spawn_pollen`; Flächensystem zusätzlich E Welt |
| Allergieaura `pollen_shield` | räumlicher Auraeintritt → Faktor0,55 für Gegnergeschosse | E Welt: späterer Eintritt und Austritt, keine Dauerfremdbremse |
| Sammelinstinkt `pollen_economy` | Magnetradius und zusätzliche Nektarwerte je Pickup | E Player: gewöhnlicher Drop1 wird auf Stufe2 zu3; E API Magnet |
| Sichttrübung `pollen_blind` | gezielte Kugel betritt Pollen → einmalige40%-Probe | E Welt:395/1000, kein erneutes Hochwürfeln, ungezielte Kugeln bleiben |
| Windreiter `wind_rider` | `speed_mult` → Flugtempo; Pollen driften in Flugrichtung | E Welt Drift; T Tempokonsum |
| Chitinpanzer `chitin_plate` | `hp` → einmalig berechnete maximale HP | E: gespeicherter Endwert wird nicht erneut bonifiziert; Rush separat |
| Häutung `chitin_regen` | `iframes` → Schutzdauer, `heal_checkpoint` → tatsächlicher Checkpoint | E Welt: heilt und speichert den geheilten Stand |
| Stachelhaut `chitin_thorns` | Kontaktkollision → Gegnerschaden24 plus Rückstoß | T: tatsächlicher Körperkollisionszweig |
| Leichtbau `chitin_light` | `hitbox` → Welt-Trefferradius; `speed_mult` → Player-Flugtempo | T: zwei konkrete Consumer, keine Spritegrößenänderung |
| Panzerhaltung `chitin_guard` | Präzision → ganzzahlige HP mit bleibender Bruchschadensbank | E: vier 1er-Treffer kosten3 HP, vier 2er kosten6; Toggle setzt Bank nicht zurück |
| Bastion `chitin_bastion` | `shield_hits, shield_regen` → Kapazität/Dauer; Schildtreffer → Gegenimpuls | E: auch Shop-Schild aktiviert Werte; T Gegenimpuls |
| Taktgeber `resonance_beat` | Resonanzintervall12/6 statt versehentlich12/24 | E: eine/zwei Resonanzkugeln in zwölf Salven |
| Kettenresonanz `resonance_chain` | `rhythm_chain` → Resonanzprojektil → reale Welt-Kette | T: Projektil-/Kettenconsumer |
| Ruhepol `resonance_calm` | fortgesetztes Feuern → bis20% mehr Schaden; Pause baut ab | E: Auf-/Abbau und Limit |
| Druckwelle `resonance_pulse` | drei Sekunden Dauerfeuer → genau ein Impuls, sechs Sekunden Cooldown | E: tatsächliches Ereignis und Cooldown |
| Stimmung `resonance_tuning` | echter Waffenwechsel → zwei Sekunden25% mehr Schaden | E: Ausrüsten auf Maxstufe und Auslaufen nach2s |
| Endton `resonance_final` | Resonanzmultiplikator ×2; `fire_rate_mult=-0.1` | E: tatsächlich doppelter Resonanzschaden; T Tempoanteil |
| Nektarstau `nectar_overflow` | maximale Waffenstufe → zusätzliche Punkte/Schild beim Pickup | E: Schildquelle regeneriert auch allein; T Punkteconsumer |
| Umwandlung `nectar_convert` | alle20s zehn Nektar gegen ein fehlendes HP | E: tatsächlicher Verbrauch/Heilung |
| Duftspur `nectar_scent` | `nectar_drop_chance` → 10 % je Stufe auf einen Blütenstaub mehr (verschmolzen ×1,5) | E Welt: Dropwert bleibt bei maximal fünf Objekten erhalten |
| Völlerei `nectar_gluttony` |20% Nektarbonus mit Bruchrest,10% langsamerer Takt | E: fünf Einzelpickups ergeben6; mit Sammelinstinkt2 insgesamt18 statt15 |
| Handel `nectar_bargain` | `cost_mult` → tatsächlicher Upgradepreis | E: erster Fächer kostet weniger als30 |
| Nektarquelle `nectar_font` | Bossphasenereignis →15 Nektar, kein Pickup-/Völlereiproc | E: echte Player-Ereignisfunktion |

Waffen-/Supportbindung ist bewusst an **Besitz/Freischaltung**, nicht an aktuell ausgewählte Hauptwaffe gebunden. Drohnenfähigkeiten benötigen die taktische Drohne. Schildfähigkeiten erkennen auch einen Werkstatt-Schild. Das Abdeckungsregister prüft jede Evolution auf Maxstufenaggregation und einen expliziten Consumer; es behauptet nicht36 vollständig isolierte End-to-End-Szenarien.

## Schild, Rundung und HP-Persistenz

- `shield_active()` bedeutet **freigeschaltet**, auch wenn momentan keine Ladung übrig ist. Quellen: taktisches Schild, Werkstatt, aktive Schild-Evolution, Nektarstau oder vorhandene anderweitig gewährte Ladung.
- `shield_regen_duration()` liefert einheitlich zwölf Sekunden, verkürzt durch Evolution und Werkstatt. `shield_regen_progress()` liefert0…1 bzw.1 bei vollem Schild. Das HUD muss diese Formeln nicht nachbauen.
- **Kaufstufe bleibt erhalten.** Treffer vermindern nur `shield_hits`. Jeder taktische Kauf gewährt unmittelbar eine Ladung und erweitert ab Stufe2 die Kapazität. Werkstatt-/Bastion-Ladungen erscheinen auch in Aura und Checkpointreset.
- Kapazität: Schwierigkeitsschild + `max(0,taktische_Stufe-1)` + Werkstatt + aktive Schild-Evolution. Kein Herabsetzen von Kaufstufen.
- Nachladung gilt ab **`>=` Dauer**, übernimmt Restzeit und überschreitet die Kapazität nicht. Volles/inaktives Schild hält keinen alten Regenerationstimer vor.
- Panzerhaltung speichert Bruchschaden: bei vier1er-Treffern ergibt `.75+.75+.75+.75` genau drei HP Schaden; der erste kleine Treffer kann abgefangen werden. Die Bank bleibt über Präzisionswechsel bestehen.
- Völlerei speichert Nektarbruchwerte über Pickups; ein20%-Bonus wird nicht an jedem einzelnen1er-Drop abgerundet. Bossphasengeschenke nehmen nicht an Pickupboni teil.
- MaxHP wird aus unveränderlicher Schwierigkeitsbasis plus Boni berechnet, **nicht** erneut aus gespeichertem bereits bonifiziertem MaxHP. Boss Rush behält mindestens vier Basisleben; Werkstatt-Neuberechnung und wiederholtes Laden bleiben konstant.

## Maximalbuild und Grenzen der Aussage

Je Waffe: alle Werkstattartikel Stufe3, alle Evolutionen auf Maxstufe, taktische Drohne/Schild/Bombe Stufe3, zehn simulierte Sekunden mit120 Bewegungsschritten/s. Enthalten sind echtes Timer-/Feuer-/Drohnen-/BulletField-Verhalten und feste Homingziele.

| Waffe | Maximale gleichzeitig aktive Kugeln | Größte beobachtete Salve | Intervall |
|---|---:|---:|---:|
| Basis |222|10|0,095s|
| Fächer |291|13|0,095s|
| Blitz |245|11|0,095s|
| Plasma |245|11|0,095s|

Keine dieser Simulationen sättigt den320er-Cap; sämtliche Bahnen bleiben endlich. Die 1.200 Simulationsschritte je Waffe benötigten im letzten Headless-Lauf ungefähr0,61/0,73/0,66/0,67 Sekunden; dies ist **kein GPU-FPS-Benchmark**.

Die 192 Kombinationen sind alle acht Teilmengen von Kreis/Welle/Zielsuche × sechs Muster (ohne Zusatz, Spirale, Heck, Seite, Nebenlauf, Burst) × vier Waffen. Jede wird eine halbe Sekunde bewegt und auf Eigenschaften, Schaden, endliche Bahn, tatsächliche Bewegung und echte Segmente geprüft. Burst und Spirale werden dabei auf der vierten Salve mit tatsächlich aktivem Zusatz geprüft.

Der Maximalbuildteil isoliert Bewegung/Emission bewusst von Gegnerkollisionen. Er ist **kein** Beweis für beliebige Proc-Last im vollen Level. Reale Kollisionen, zusätzliche Ketten-/Splash-Effekte, sekundäre Splitter-/Schwarm-Rekursion und Pollen prüft die verknüpfte Welt-Synergieprüfung gesondert. Dort sind Kinder `proc_depth=1`, neue Procs nur aus Primärgeschossen; Ursprungsziele werden nicht unmittelbar erneut getroffen. Der harte320/420-Cap wird zusätzlich direkt getestet. Abgewiesene Geschosse zählen weder Player-Salvenleistung noch Welt-Schussstatistik; nach einer vollständig abgewiesenen Salve wird kein fiktiver Grundschaden als „erster Schuss“ angenommen.

## Abgestimmte Schnittstellen und visuelle Belege

1. **BulletField → Welt:** `prev_p:Vector2` steht beim Spawn auf`p` und wird vor jedem Bewegungsschritt aller Spieler-/Gegnerformen gesetzt. Kollisionen verwenden das reale Segment`prev_p→p`, kein starres Zukunftssegment aus`v*0.0166`.
2. **Welt → Player:** `spawn_player_bullet(...) -> Dictionary` gibt das tatsächlich angenommene Projektil bzw.`{}` zurück. Nur angenommene Kugeln erhöhen Salven-/Schussmesswerte.
3. **Sekundärfeuer:** BulletField übernimmt `proc_depth:int` aus Optionen, Standard0; Welt kennzeichnet Splitter/Schwarm mit1 und verhindert rekursive Procs. Änderungen an Weltkollisionen und Splash einschließlich Bossoberfläche stammen vom Welt-Agenten.
4. **Player → HUD:** `shield_active`, `shield_regen_duration`, `shield_regen_progress`; siehe Schildvertrag oben. Gemeinsame Oberkante`App.PLAY_TOP=76`. Player-Zentrum respektiert mindestens`PLAY_TOP+10`; für die vorhandene32px-Framehöhe werden18px Einrückung gewählt: nominale Grenzen **y94…434**, X unverändert.
5. **Gegnergeschosse:** stabiler opaker dunkler Silhouettenrand und heller Kern, keine zeitabhängige Helligkeits-/Frameanimation. Bestehendes Kontrastprofil steuert Rand/Kerndicke; reduzierte Effekte entfernen diesen sicherheitsrelevanten Kontrast nicht. Trefferradius und Projektilgröße aus den Optionen bleiben unverändert. Die frühere doppelte Anwendung des Skalierungsfaktors im Renderpfad ist entfernt.

Die echten Renderings [helles Blütenmeer](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/projectiles_bright.png>) und [dunkler Pilzwald](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/projectiles_dark.png>) wurden auch im Waffenauftrag mit `read_image` angesehen: alle vier Gegnergeschossarten sind auf beiden Hintergründen durch dunklen Rand/hellen Kern klar erkennbar. Erzeugung und Pixel-/HUD-Prüfung sind im [Visualbericht](</home/floppi/Dokumente/DSH/Workspaces/Apidya/docs/STINGFORGE_VISUAL.md>) dokumentiert; es wurde dafür kein eigener paralleler Grafikimport gestartet.
