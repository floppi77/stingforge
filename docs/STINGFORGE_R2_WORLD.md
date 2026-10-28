# Stingforge R2 – Weltmechaniken, Leveldruck und Trefferfeedback

## Klare Antwort: Was waren die Kreise mit Zahlen?

**Die Zahlenkreise waren funktionslose Platzhalter, keine lösbare Reihenfolge und keine echte Boss-Voraussetzung.** Der bisherige `order_marker` erhöhte nur einen Zähler und zeichnete eine Zahl. `order_target` wurde nicht ausgewertet; der Bossstart blieb zeitgesteuert. Daneben existierten echte Generator-Gegner, deren `anchor`-Verhalten sie allerdings bei ihren Startpositionen rechts außerhalb des Bildes festhielt.

Jetzt erscheinen anstelle der Zahlen **echte abschießbare Generatoren**, die sichtbar einfliegen und schießen. Höchstens zwei leben gleichzeitig; vorhandene Generatoren werden mitgezählt. Das Banner erklärt ausdrücklich: „Generator-Verstärkung – zerstören, Reihenfolge frei“. Es gibt weder eine versteckte Strafreihenfolge noch ein neues Boss-Gate. Nach Bossbeginn kommt keine solche Verstärkung mehr. Das Generator-Ereignis hat neun Sekunden Grundabstand.

## Zuständigkeit und stabile Schnittstellen

Produktionsänderungen dieser World-Arbeit betreffen ausschließlich [Game](<../scripts/game/game.gd>), [Enemy](<../scripts/game/enemy.gd>), [Director](<../scripts/game/director.gd>) und [Fx](<../scripts/game/fx.gd>). [Boss](<../scripts/game/boss.gd>) wurde von World nur gelesen und anschließend ausdrücklich stabil an den separaten Boss-Agenten übergeben. Player, HUD, App, ShopData, Data und Background wurden hier nicht verändert. Die Round2-Baseline unter `build/stingforge-round2-baseline` wurde nicht bearbeitet; keine Grafikimporte, kein Blender und kein Cache-Reset durch World.

Die vereinbarten Live-Test-Seams sind echte Hazard-Spawns/Ticks, `current_push`/`gravity_pull` samt Player-Bewegung, Director-Spawns, Enemy-Kadenz, tatsächliche Boss-Erzeugung, durchflogene Bulletsegmente und Fx-Update/Partikellast. Es gibt keine Quelltext-Assertions als Ersatz für Verhalten.

### Gravitation und Wind sind bewusst getrennt

- `Game.current_push()` bleibt Wind/Strömung mit der bisherigen Grenze `252 × 0,62 = 156,24`. Die bestehende Player-Gegensteuerung reduziert die entgegenwirkende Windkomponente weiterhin um 72 Prozent.
- **Neu: `Game.gravity_pull() -> Vector2`.** Aktive `gravity_field`-Gefahren liefern abwärts `0,90 × Player._speed()`. In den letzten 0,6 Sekunden läuft die Kraft aus. Mehrere Felder addieren sich nicht zur Bewegungsfalle.
- Der abgestimmte Player-Verbrauch addiert Gravitation **ohne** Wind-Gegenfilter. Bei Aufwärtseingabe begrenzt er die gesamte abwärts gerichtete Umgebungskraft auf 90 Prozent der tatsächlich angeforderten Aufwärtsgeschwindigkeit. Das gilt auch diagonal, analog und im Präzisionsflug.
- Grundflug: Kraft 226,8 und verbleibender Aufstieg 25,2 Pixel/s. Präzisionsflug: Kraft 102,06 und Aufstieg 11,34 Pixel/s. Tempo-Upgrades bleiben wirksam.
- Der frühere Kern-`gravity_pulse` ist kein expandierender Schadensring mehr, sondern ein 3,4 Sekunden wirkendes Kraftfeld. Die Gravitation verursacht keinen eigenen Kontaktschaden.
- Wind behält seine eigene Auf-/Abwärtsrichtung. Das vorher doppelt multiplizierte Vorzeichen ist korrigiert: negativer Wind drückt wirklich nach oben.

**Darstellung:** senkrechte Feldlinien mit klaren Abwärtspfeilen für Gravitation; Wind zeigt senkrechte Pfeile seiner wirklichen Richtung. Die vom Renderer benutzte `Fx.field_geometry()` bleibt vollständig zwischen den gemeinsamen HUD-Grenzen **oben56/unten476**. Die Konstanten werden nur gelesen.

## Leveldruck: nicht bloß mehr Lebenspunkte

Die Diagnose zeigte: Bei identischem Build blieben Wellenabstand und Enemy-Feuertakt in Level1–10 gleich. Enemy-HP stiegen nur um fünf Prozent pro Level; Boss-HP hatten überhaupt keinen separaten Level-Faktor.

`Director.pressure_for_level()` ist jetzt die gemeinsame begrenzte Quelle für vier unabhängige Faktoren. Außerhalb1–10 wird der Level geklemmt.

| Level | Wellenfaktor | Enemy-Feuerfaktor | Enemy-HP-Level | Boss-HP-Level |
|---:|---:|---:|---:|---:|
| 1 | 1,00 | 1,00 | 1,00 | 1,00 |
| 2 | 1,05 | 1,04 | 1,10 | 1,17 |
| 3 | 1,10 | 1,08 | 1,20 | 1,34 |
| 4 | 1,15 | 1,12 | 1,30 | 1,51 |
| 5 | 1,20 | 1,16 | 1,40 | 1,68 |
| 6 | 1,25 | 1,20 | 1,50 | 1,85 |
| 7 | 1,30 | 1,24 | 1,60 | 2,02 |
| 8 | 1,35 | 1,28 | 1,70 | 2,19 |
| 9 | 1,40 | 1,32 | 1,80 | 2,36 |
| 10 | 1,45 | 1,36 | 1,90 | 2,53 |

Der Wellenabstand unterschreitet weiterhin nicht2,4s. Zusätzliche Abschnittswellen behalten ihre bisherigen begrenzten Chancen. Es werden ausschließlich die handgebauten Abschnittspools verwendet; eine Formation wiederholt sich nicht unmittelbar, wenn der Pool eine Alternative enthält. Spawn- und Feuertakt erzeugen zusätzlichen Druck, nicht neue Verfolgergeschwindigkeit.

**Unverändert:** Verfolger-Obergrenzen160/145; vier-von-fünf Enemy-Projektionen nur auf `relaxed`/`normal`, keine Reduktion auf `expert`; Boss-Bewegungs-/Patternlogik nicht von World geändert.

### Waffenverbesserungen werden nicht neutralisiert

Die Waffen-HP-Exponenten bleiben **0,55 für DPS und0,10 für Einzelschaden**. Der neue Level-Faktor ist davon unabhängig. Ein zusätzlicher offensiver Kauf im selben Level verbessert deshalb weiterhin die Tötungszeit; nichtoffensive Evolutionen erhalten keine pauschale Boss-HP-Steuer. Auch Boss-Rush verwendet den begrenzten HP-Level-Faktor, bezogen auf den Bossindex.

### Messung mit identischem Build, Level1–10

Echte Enemy-/Boss-Spawns und hundert Director-Wellenanforderungen je Level. Für die Wellentakt-Messung bleiben Abschnitt und Seed identisch, damit die Levelwirkung isoliert wird. Enemy ist jeweils derselbe `beetle_grunt`, Grundwaffe unverändert. Die realen HP enthalten zusätzlich den kleinen unveränderten Referenz-DPS-Effekt.

| Level | Enemy-HP | Enemy-Feuertakt s | mittlerer Wellenabstand s |
|---:|---:|---:|---:|
| 1 | 62,52 | 2,000 | 4,306 |
| 2 | 68,77 | 1,923 | 4,101 |
| 3 | 75,02 | 1,852 | 3,914 |
| 4 | 81,27 | 1,786 | 3,744 |
| 5 | 87,52 | 1,724 | 3,588 |
| 6 | 93,77 | 1,667 | 3,445 |
| 7 | 100,03 | 1,613 | 3,312 |
| 8 | 106,28 | 1,563 | 3,189 |
| 9 | 112,53 | 1,515 | 3,077 |
| 10 | 118,78 | 1,471 | 2,974 |

### Realistisch fortschreitende Builds, Level1–10

Die [Build-Messszene](<../tests/stingforge_r2_world_builds.gd>) prüft je Level zwei Fälle:

- **Einstieg:** kostenlose Basiswaffe aufStufe1, sämtliche gekauften taktischen Zusatzstufen0; ein fortschreitender persistenter Shop-/Evolutionsbuild bleibt erhalten.
- **Im Feld:** derselbe persistente Build plus plausible aufgesammelte Waffen: Basis → Fächer → Blitz → Plasma, mit begrenzten taktischen Stufen.

Das kumulative Shopbudget wird mit maximal16000 Punkten je bereits abgeschlossenem Level geprüft. Die Messung umfasst echte Salven, Bulletbewegung und Game-Kollision bis zum Tod desselben stationären Gegners bei80px Kugelweg. Das ist eine kontrollierte Trefferprobe, kein autonomer Durchspielnachweis.

| Level | Einstieg DPS | Feld DPS | echter Gegner-Kill s Einstieg/Feld | idealer Boss-Form1-Wert s Einstieg/Feld |
|---:|---:|---:|---:|---:|
| 1 | 143 | 143 | 0,63 / 0,63 | 25,9 / 25,9 |
| 2 | 154 | 154 | 0,63 / 0,63 | 34,8 / 34,8 |
| 3 | 211 | 222 | 0,57 / 1,40 | 38,3 / 36,1 |
| 4 | 233 | 327 | 0,57 / 0,82 | 44,6 / 36,9 |
| 5 | 323 | 402 | 0,80 / 1,05 | 44,3 / 39,0 |
| 6 | 370 | 290 | 0,80 / 0,90 | 43,2 / 47,1 |
| 7 | 435 | 472 | 0,68 / 0,67 | 48,0 / 45,3 |
| 8 | 469 | 1615 | 0,68 / 1,08 | 54,3 / 34,2 |
| 9 | 528 | 1820 | 0,70 / 0,78 | 56,0 / 35,3 |
| 10 | 564 | 1943 | 0,80 / 0,85 | 70,8 / 44,6 |

**Wichtig:** Der letzte Wert ist nur `erste Boss-HP / (nominale Salven-DPS × Bossbonus)`. Phasenpanzerung, Ausweichen, Flugzeit, Splash-/Kettennutzen und die gesondert ergänzte zweite Finalbossform sind darin **nicht** als Kampfzeit gemessen. Ein legitimer Waffensprung darf den Kampf verkürzen; die unabhängigen Leveldruck-Faktoren steigen trotzdem. Alle zwanzig Builds bestätigen, dass zusätzliche Wucht auf demselben Level noch einen TTK-Gewinn bringt.

Vollständige Zahlen und gekaufte Stufen: [Messdaten](<../build/stingforge-r2-world-metrics.json>), [Build-Protokoll](<../build/stingforge-r2-world-builds.log>).

## Glas: vier Pulse, danach erst wirksam

Vorher wirkte Glas sofort und prüfte nur die momentane Kugelposition; ein schneller Schuss konnte die Fläche zwischen zwei Frames durchqueren.

Jetzt:

1. Eine Sekunde Warnzeit: vier leuchtende cyanfarbene Rahmenpulse, jeweils0,125s an/0,125s aus.
2. Während **aller** On- und Off-Phasen keinerlei Geschosskollision.
3. Ab exakt1,0s normales transparentes Glas mit Materialstreifen, **ohne** leuchtenden Warnrahmen.
4. Kollision mit dem echten vergangenen Segment `prev_p → p`, einschließlich Kugelradius; außerhalb der Fläche bleibt der Schuss frei.

`Fx.is_warning()`, `Fx.warning_pulse_on()` und `Fx.panel_rect()` werden von Renderer und Game gemeinsam verwendet. Der Kollisionsbeginn hängt nicht von einer separat gezählten Blinkphase ab. Es gibt keine Vollbild-Weißblitze. Spawnposition und Rahmenabstand halten das gesamte Glas im Spielfeld. Das bestehende Glas-Abfangverhalten wird beibehalten; keine neue unangekündigte Rückschussmechanik.

## Trefferpartikel und begrenzte Last

`Fx.hit_spark()` verwendet einen kleineren0,10s-Funken und einen kurzen Materialburst:

- maximal sechs kleine Splitter/Staubteilchen pro Treffer;
- Lebensdauer120–210ms, Größe höchstens2,5px;
- Glas kühlblau, Metall blaugrau, Pflanzen grünlich und Chitin warm;
- keine schwarze Lochscheibe als Ersatz für Kugelkontrast;
- `graphics.particles=0` schaltet die **neuen** Partikel aus; der bestehende Kernfunke folgt weiterhin der Effektdichte;
- verringerter Partikelslider reduziert die Menge, `reduce_effects` halbiert sie;
- höchstens96 gleichzeitig lebende Trefferpartikel und192 Spriteeffekte;
- rein optische Streuung ohne zusätzliche Gameplay-RNG-Aufrufe, Kampfgeschosse oder rekursive Explosionen.

Die neue Materialwahl wird auch über einen echten Game-Projektiltreffer geprüft, nicht nur direkt am Fx-Helfer.

### CPU-Lastmessung

600 simulierte Frames mit je zehn Treffern, insgesamt6000 Treffer, einschließlich Fx-Update:

| Zustand | CPU-Zeit je simuliertem Frame |
|---|---:|
| vorheriger einzelner Funke | 27,98µs |
| neue begrenzte Partikel, Wiederholungen | 68,10–74,59µs |

Mehrkosten ungefähr0,04–0,05ms je Lastframe. Ein zusätzlicher unmittelbarer2000-Treffer-Stress prüft die Caps96/192. Nach Lastende verschwinden die Effekte wieder. Dies ist ein **CPU-Benchmark**, kein gemessenes GPU-/Render-FPS-Versprechen.

## Lauf-Schwierigkeit und Death-Reset

Enemy erhält die kanonische Schwierigkeit der laufenden Game-Welt. Director liest dieselbe Welt, ansonsten laufende Kampagnendaten; globale Menüoptionen dienen nur als Fallback ohne Run-Daten. Training/Rush behalten dadurch ihre Schwierigkeit trotz `active_campaign=false` und geänderter Optionen.

Am bestehenden Death-Reset war keine Produktionsänderung nötig: kostenlose **Basis1** bleibt, alle gekauften taktischen Stufen werden0. Der Live-Test kauft Schild1/2/3 wirklich, setzt über `continue_after_death()` zurück und bestätigt anschließend Schildkapazität/Ladungen/Regeneration0. Gekaufte Shopartikel und Evolutionen bleiben erhalten und schalten von sich aus keinen Schild frei.

## Rot → Grün und Wiederholbarkeit

Die Diagnose folgte jeweils einem tatsächlichen roten Enginepfad:

| Schritt | Roter Befund |
|---|---|
| Gravity/Wind-Vertrag | 7Checks,4Fehler: Schadensring, fehlende separate Kraft, falsches Windvorzeichen |
| Generatoren | 66Checks,3Fehler: Zahlenkreise, keine echten Generatoren, kein sichtbarer Einflug |
| Leveldruck und Glas | 124Checks,42Fehler: fehlender Boss-/Spawn-/Feuertaktdruck und fehlende Warn-/Segmentlogik |
| Fx und Run-Schwierigkeit | 221Checks,11Fehler: Partikelpfad/Cap fehlen und Optionsänderung beeinflusst laufende Welt |

Final:

- [World-Test](<../tests/stingforge_r2_world.gd>) / [Szene](<../tests/stingforge_r2_world.tscn>): **272Checks,0Fehler**, `STINGFORGE_R2_WORLD_OK`.
- [Build-Test](<../tests/stingforge_r2_world_builds.gd>) / [Szene](<../tests/stingforge_r2_world_builds.tscn>): **71Checks,0Fehler**, `STINGFORGE_R2_WORLD_BUILDS_OK` und `STINGFORGE_R2_WORLD_OK`.
- Die bisherigen **418** World-Checks erneut unverändert grün: Density52, Motion145, Boss160, Synergy61. Crit, Splash, Markierung, Proc-Tiefe, freundliche Pollen und echte Boss-Alpha-Hitmasken bleiben erhalten.

Ausführung ausschließlich mit isolierten Testdaten und Dummy-Audio:

```bash
XDG_DATA_HOME="$PWD/build/stingforge-r2-testdata-world" \
  godot --headless --path "$PWD" --audio-driver Dummy \
  res://tests/stingforge_r2_world.tscn
```

Für die Buildmessung die Szene durch `res://tests/stingforge_r2_world_builds.tscn` ersetzen. Die World-Suite prüft zusätzlich, dass alle Teilsuiten wirklich ihr Ende erreichen: Godot kann nach einem Scriptfehler sonst in einem Aufrufer weiterlaufen und fälschlich einen Teil-Erfolg ausgeben. Marker **plus** Exit0 **plus keine Script-/Parsefehler** sind das Erfolgskriterium.

Protokolle: [World final](<../build/stingforge-r2-world-final.log>), [Level/Glas rot](<../build/stingforge-r2-world-pressure-red.log>), [Fx/Run-Diff rot](<../build/stingforge-r2-world-impact-red.log>), [Verbose](<../build/stingforge-r2-world-verbose.log>), [R1 Density](<../build/stingforge-r2-world-regression-density.log>), [R1 Motion](<../build/stingforge-r2-world-regression-motion.log>), [R1 Boss](<../build/stingforge-r2-world-regression-boss.log>), [R1 Synergy](<../build/stingforge-r2-world-regression-synergy.log>).

## Native Fensterzeichnung: vier Pulse im Framebuffer bestätigt

Die [Fenster-Testszene](<../tests/stingforge_r2_world_visual.gd>) / [Szene](<../tests/stingforge_r2_world_visual.tscn>) lief über Wayland mit Dummy-Audio und Mesa/llvmpipe. Sie liest den tatsächlichen nativen Framebuffer, kein nachgebautes Bild. Vier On- und vier Off-Zeitpunkte sowie der aktive Zustand nach1,06s liefern **9Pixelprüfungen,0Fehler**, `STINGFORGE_R2_WORLD_VISUAL_OK`, Exit0.

Alle drei1600×900-PNGs wurden anschließend mit dem Bildlesewerkzeug geprüft:

- [Warnpuls an](<../build/stingforge-r2-world-visual-pulse.png>): leuchtender cyanfarbener Rahmen, senkrechte Gravitationslinien mit Abwärtspfeilen.
- [Warnpuls aus](<../build/stingforge-r2-world-visual-pause.png>): kein Rahmen, weiterhin noch kein aktives Glas.
- [Glas aktiv](<../build/stingforge-r2-world-visual-active.png>): transparentes Glas mit Materialstreifen, ausdrücklich ohne leuchtenden Rahmen. Kleine kühle Trefferpartikel rechts bleiben lokal.

[Renderprotokoll](<../build/stingforge-r2-world-visual.log>). Der Zeitplan der Testaufnahme wird explizit gesetzt, damit das Betriebssystem-On/Off-Screenshots nicht durch Frame-Scheduling vertauscht; das Rendering selbst bleibt der echte Fx-Zeichenpfad. Das Fenster schließt selbstständig. Keine Grafikimporte waren nötig.

### Verbleibende Engine-Abschlusswarnungen

Der Verbose-Lauf endet mit0Scriptfehlern, meldet beim Dummy-Audio-Shutdown aber weiterhin referenzierte Ogg-/WAV-/Playback-Ressourcen. Die gemeldeten Typen sind Audioobjekte, keine Fx-Partikel, Weltobjekte oder Bossmasken. Dieses bereits aus R1 bekannte Shutdown-Thema wurde innerhalb der World-Zuständigkeit nicht durch Audio-Produktionsänderungen oder einen Cache-Reset verdeckt.

Alle eigenen gestarteten Hintergrundjobs wurden beendet und ihre Resultate eingesammelt. Zwei frühe Läufe fielen in parallele noch unvollständige Autoload-/Testschreibstände; sie wurden nicht als grüne Messung gewertet und anschließend ersetzt.
