# Stingforge – Spielwelt, Fairness und Bosskollision

## Zuständigkeit und Schnittstellen

Produktionsänderungen ausschließlich in [game.gd](../scripts/game/game.gd), [enemy.gd](../scripts/game/enemy.gd) und [boss.gd](../scripts/game/boss.gd). Spieler, Projektilverwaltung, HUD, Werkstattdaten und Grafik wurden nicht von World verändert. Keine Grafikimporte, kein Cache-Reset.

Mit Weapons abgestimmt:

- Jedes Projektil liefert `prev_p` als **wirkliche vorherige Position**, initial gleich `p`; Kollisionsstrecke ist `prev_p → p`, niemals eine vorausberechnete Strecke mit festem Delta.
- `proc_depth=0` bezeichnet Primärschüsse, `1` abgeleitete Splitter/Schwarmkugeln. Daraus entstehen keine weiteren Splitter oder Zielmarkierungs-Selbstschleifen.
- `Game.spawn_player_bullet(...)` gibt das tatsächlich angenommene Bullet-Dictionary zurück; bei vollem Feld `{}`. Abgewiesene Schüsse erhöhen weder Schussstatistik noch Weapons-DPS-Messung.
- HUD-Konstanten werden gelesen: `App.PLAY_TOP=76`, `PLAY_BOTTOM=452`. World setzt Spielergrenzen nicht selbst. Der integrierte Spieler nimmt wegen seiner sichtbaren 32px Höhe sogar 18px Abstand statt nur des vereinbarten Minimums von 10px.

## Verfolger und Weltgrenzen

Die aktuellen Gegnerdaten enthalten genau zwei frei nachführende Verfolger:

| ID | Verhalten | Datentempo | Vorher tatsächlich gemessen | Jetzt |
|---|---|---:|---:|---:|
| `wasp_dart` | `dive` | 230 | 330 | 138; Obergrenze 160 bei Multiplikatoren |
| `piston_drone` | `charge` | 210 | 310 | 126; Obergrenze 145 bei Multiplikatoren |

Ursache war zusätzlich zur ständigen Zielnachführung ein zweites horizontales Update im gemeinsamen Tick. Auch andere Muster bewegten ihre Position bereits selbst. Das zusätzliche Update ist für **alle** Muster entfernt; ihre Daten-Geschwindigkeiten gelten nun genau einmal.

Nach 0,35s beziehungsweise 1,0s Warn-/Anflugphase wird eine einzige Flugrichtung gewählt. Sie bleibt nach links gerichtet und wird nicht erneut auf den Spieler gedreht. Ein vorbeigeflogener Verfolger kehrt deshalb nicht zurück und verlässt das Spielfeld. Der Spieler-Grundwert 252 wurde nicht verändert. Level 1/5/10 und Tempo-Multiplikatoren 1,0/1,8 sind geprüft.

Gegnergrenzen berücksichtigen `max(Kollisionsradius, Spritehöhe/2)+2px`. Bereits beim Aufsetzen werden die Start-/Grundpositionen begrenzt. Bosse berücksichtigen die sichtbaren, transformierten Körper- und Modul-Ausdehnungen; auch Zeitplan-Teleports werden nach dem Timeline-Tick begrenzt. Header und Unterkante bleiben frei. Gegnerprojektile dürfen weiterhin von oberhalb des Headers in das sichtbare Feld einfliegen.

## Genau messbare Projektilreduktion

Der einzige Filter sitzt zentral in `Game.spawn_enemy_bullet`. Auf `relaxed` und `normal` nimmt ein ganzzahliger Akkumulator vier von fünf Anforderungen an: für jedes Präfix `n` entstehen `floor(0,8*n)` Projektile, also exakt 800 aus 1.000. Er wird nicht für jeden Gegner, Angriff oder jede Salve zurückgesetzt. Bei einem tatsächlichen Schwierigkeitswechsel beginnt eine neue Folge.

- Die Schwierigkeitsdefinition der **laufenden Game-Welt** hat Vorrang vor globalen Menüeinstellungen. Das gilt auch für Training/Rush mit `Save.active_campaign=false`; Save dient nur bei einer uninitialisierten Testwelt als Fallback.
- Alle regulären Gegner, Bosse und Module benutzen diesen zentralen Weg.
- `expert`: 1.000 aus 1.000, keine Filterung.
- Kein zusätzlicher RNG-Aufruf; gleiche Folge bei Wiederholung.
- Fire-Rate, Angriffstimer, bestehende Expertenfaktoren und Level-Projektilgeschwindigkeit bleiben unverändert.
- Der Test zählt echte Spawn-Zulassungen und leert nur zwischen Anforderungen das Testfeld, damit der bestehende 420-Objekt-Cap die Messung nicht abschneidet.

## Sichtbare Bossform statt Kreis58

`Boss.trace_hit(from, to, radius)` prüft das aktuelle Einzelbild des Körpers sowie alle lebenden Module. Alpha ≥0,2 bildet pro Bild gecachte horizontale Pixelläufe. Es gibt keine pauschalen Rechtecke oder Kreise um transparente Bereiche. Rotation, Spiegelung und die aktuellen Modulpositionen werden in die Kollisionsrechnung übernommen. Glow-/Telegraph-Effekte gehören nicht zur verletzenden Körperform.

Die Strecke samt Projektilradius wird gegen diese Zeilenläufe geprüft. Ein Treffer liefert Einschlagposition und getroffenes Modul; ein äußerer Modultreffer beschädigt das tatsächlich sichtbare Modul statt immer das erste. Ein zerstörtes Modul hat keine verbleibende unsichtbare Hitbox.

Geprüft: alle zehn Bosse, beide Animationsbilder, sichtbare Extremitäten in 67–105px Entfernung vom Zentrum, transparente Ecken und Löcher, horizontale/vertikale/diagonale Durchquerung, Rotation und Außenmodule. Körper- und Modulkontakt verursacht jetzt Spieler-Verletzung über denselben sichtbaren Umriss. Bestehende Schutzzeiten und Schild werden dabei respektiert.

`b.hit` verhindert erneute direkte Berührung desselben Ziels durch dieselbe Kugel, auch bei Orbit-/Durchschlag-Projektilen. Ein Durchqueren mehrerer Körperteile löst nicht mehrfach den Primärtreffer aus.

## Aufrüstung und additive Synergien

### Härte wächst sublinear

Die bisherigen Exponenten 0,95 (DPS) und 0,25 (Einzelschaden) ergaben bei verdoppeltem Schaden `2^1,20=2,297`-fache Gegner-HP: Aufrüstung machte das Töten sogar langsamer.

Jetzt gelten 0,55 und 0,10: verdoppelter Schaden ergibt etwa 1,569-fache HP, die Tötungszeit sinkt auf rund 78,5%. Referenz-Mindestwerte, Grundhärte 2,4 und der Level-Faktor bleiben erhalten. Die zusätzliche Boss-HP-Steuer von 6% **pro Evolution unabhängig von deren Wirkung** entfällt; auch eine einzelne Crit-Evolution verbessert dadurch die Boss-Tötungszeit.

### Klar definierte Trefferpolicy

- Ein Crit-Wurf pro direktem Einschlag aus `clamp(Shop-Crit + Evolutions-Crit, 0, 1)`.
- Splitter, Splash und Ketten erben diese gewürfelte **Basis**. Boss-/Miniboss-Bonus kommt danach zielweise genau einmal hinzu. Geerbte Splitterbasis wird nicht nochmals kritisch gewürfelt.
- Verschiedene erworbene Effekte sind **additiv**: Shopkette, Blitzkette und Splash dürfen jeweils einmal zum selben Nachbarziel beitragen. Jeder Effekt bekommt dieselben Ausgangsausschlüsse. Effekte dürfen einander nicht durch ein global vorzeitig gefülltes Hit-Set verdrängen.
- Die abschließende Vereinigungsmenge verhindert spätere direkte Wiederberührungen. Das Ausgangsziel erhält keinen eigenen Splash-/Ketten-Zusatztreffer.
- Messbeispiel: bei Rohschaden10 und Bossbonus50% ergeben Shopkette55%, Blitzkette66% und Splash50% gemeinsam 25,65 auf den Nachbarboss. Ein weiterer Blitzsprung erhöht den dritten Nachbarschaden von5 auf6,65 statt ihn auf1,65 zu senken.

Splash berücksichtigt jetzt auch die sichtbare Bossoberfläche. Ein direkter Plasma-Bosstreffer löst wiederum Splash auf Nachbargegner aus, aber nicht auf den bereits direkt getroffenen Boss. Eigene Splitter ignorieren ihr Ursprungsziel, erzeugen keine rekursiven Splitter und sind auf maximal vier Evolutions- plus zwei Werkstatt-Splitter je Primärtreffer begrenzt. Zielmarkierung funktioniert auch am Boss; Schwarmkugeln zählen nicht erneut als markierende Primärschüsse. Markierungen verschwinden beim Gegnertod.

### Weitere echte Evolutions-/Werkstattpfade

- Chitin-Regeneration prüft die richtige Evolutions-ID und speichert den bereits geheilten Checkpoint-Zustand.
- Nektar-Drops verteilen ihre **gesamte** Wertsumme auf höchstens fünf Objekte. Hohe Basisdrops und Drop-Upgrades gehen nicht mehr durch den Objekt-Cap verloren.
- Eigene Pollen sind freundlich und verletzen den Spieler nicht. Gegnerische Sporen bleiben gefährlich.
- Windreiter übernimmt 65% der aktuellen Spielerbewegung in den Wolkendrift.
- Allergieaura reagiert auch auf später einfliegende Kugeln, verlangsamt im Umkreis auf0,55 und gibt außerhalb das vorherige Tempo zurück.
- Sichttrübung prüft gezielte Kugeln beim tatsächlichen Wolkenkontakt. Pro Kugel/Wolke gibt es genau einen40%-Versuch mit dem gesetzten Spiel-RNG, nicht jeden Frame neue Würfe bis zur faktischen100%-Chance.
- Bereits aufgelöste Kugeln werden im selben Tick nicht mehr als verletzend gewertet.
- Schwarm-Homing bekommt Ziele unabhängig davon, ob Shop-Homing gekauft wurde.
- Minibosse erhalten denselben zielweisen Boss-Schadensbonus.
- Freundliche Pollen treffen alle überlappenden Gegner und die sichtbare Bossoberfläche pro gemeinsamem0,4s-Tick. Der echte `delta` wird verwendet; kleine und große Zeitschritte liefern denselben Schaden. Der unveränderte initiale Burst verursacht weiterhin9/18 Schaden. Endliche Abschusskaskaden dürfen Nachbarn treffen; Listen werden dabei mutationssicher durchlaufen.
- Der Abschuss-Punktebonus gilt auch für die Bossbelohnung.

## Rot → Grün: reale Engineprüfungen

Die Test-Seams wurden vorab mit dem koordinierenden Agenten abgestimmt: echte zentrale Spawn-Aufrufe, echte Enemy-Ticks, Game-Kollisionspfad mit realen Bullet-Dictionaries und Boss-Sprites, tatsächliche Upgrade-/Splash-/Pollen-/Pickup-Pfade. Keine Quelltext-Assertions als Ersatz für Verhalten.

| Suite | Gezielter Rotbeleg | Final |
|---|---|---|
| [Density](../tests/stingforge_world_density.gd) / [Szene](../tests/stingforge_world_density.tscn) | 14 Fehler bei49Checks; zuletzt2 zusätzliche Training/Rush-Kontextfehler | 52Checks,0Fehler |
| [Motion](../tests/stingforge_world_motion.gd) / [Szene](../tests/stingforge_world_motion.tscn) | 85 Fehler bei137Checks; danach8 zusätzliche Doppelbewegungsfehler | 145Checks,0Fehler |
| [Boss](../tests/stingforge_world_boss.gd) / [Szene](../tests/stingforge_world_boss.tscn) | 121 Fehler bei152Checks | 160Checks,0Fehler |
| [Synergy](../tests/stingforge_world_synergy.gd) / [Szene](../tests/stingforge_world_synergy.tscn) | sukzessive9HP-,3Splash-,3Crit-,7Evo-,3Proc-,4aktiveAbwehr-,3Admission-,5Policy-,6Flächen-/Reward- und1Geistertrefferfehler | 61Checks,0Fehler |

Insgesamt sind **418 Verhaltensprüfungen** grün. Die späteren Stufen wurden jeweils zuerst rot ausgeführt und danach grün. Einzelne zusätzliche Sicherheits-/Modul-/Benchmark-Checks erweitern die primären Rotbelege. Finale Szenen liefern nur bei null Fehlern ihren exakten Endmarker `STINGFORGE_WORLD_<SUITE>_OK` und Exit0.

Ausführung aus dem Projektverzeichnis, ohne Importlauf:

```bash
XDG_DATA_HOME="$PWD/build/stingforge-testdata-world" \
  godot --headless --path "$PWD" --audio-driver Dummy \
  res://tests/stingforge_world_density.tscn
```

Für die übrigen Szenen `density` durch `motion`, `boss` oder `synergy` ersetzen. Das isolierte XDG-Verzeichnis hält echte Nutzerspielstände aus dem Test heraus.

Finale Protokolle: [Density](../build/stingforge-world-density-final.log), [Motion](../build/stingforge-world-motion-final.log), [Boss](../build/stingforge-world-boss-final.log), [Synergy](../build/stingforge-world-synergy-final.log). Ein gesonderter [Verbose-Audiobefund](../build/stingforge-world-leaks.log) ordnet die Shutdown-Warnungen zu.

## Performance und verbleibende Grenzen

Auf Godot4.7.2 wurden nach Masken-Warmup je Boss30 Frames mit je320 Projektilabfragen gemessen. Normale Körper: ungefähr0,93–1,22ms je320Abfragen; Bosse mit drei Modulen: maximal rund3,0ms. Das ist ein **CPU-Kollisionsbenchmark**, kein gemessenes Render-FPS-Versprechen. Masken werden nur einmal je Einzelbild eingelesen; es werden keine Bilder pro Geschoss heruntergeladen oder neu importiert.

Alle vier finalen Engineprüfungen enden mit Exit0 und ohne Script-/Parsefehler. Godots Dummy-Audio meldet beim Shutdown weiterhin referenzierte Audio-Playback-/Ogg-/WAV-Ressourcen (bereits im ursprünglichen Rotlauf sichtbar). Verbose zeigt Audioressourcen, nicht Bossmasken oder Weltobjekte. Explizites Stoppen und Freigeben der Test-Audiostreams mit kurzem Engine-Nachlauf beseitigt diese Engine-Shutdownwarnung hier nicht. Sie wird ausdrücklich nicht als Grafik-/Cacheproblem ausgegeben.

Zwei durch parallele, noch unvollständige Weapons-Dateischreibstände blockierte frühe Enginejobs wurden beendet und ihre Jobresultate eingesammelt. Alle endgültigen Prüfungen liefen danach erneut. Keine eigenen Hintergrundjobs bleiben aktiv.
