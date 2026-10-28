# Stingforge Runde 2 – Spieler und Schild

## Umfang und Schutz der Baseline

Produktionsänderungen ausschließlich in [player.gd](<../scripts/game/player.gd>),
[shop_data.gd](<../scripts/game/shop_data.gd>) und dem neuen Zeichenmodul
[shield_rings.gd](<../scripts/game/shield_rings.gd>). Keine App-, Game-, Data-,
HUD-, BulletField- oder Grafikasset-Änderung durch diesen Arbeitsbereich.
Keine Grafikimporte, kein Blender und kein Cache-Reset.

Die unveränderliche [Baseline](<../build/stingforge-round2-baseline/>) wurde gegen
[ihre Prüfsummen](<../build/stingforge-round2-baseline/SHA256.json>) geprüft:
**1095 Dateien, 0 fehlend, 0 verändert.**

## Schildvertrag

- Ausschließlich `upgrades.shield > 0` schaltet ein Schild frei.
- Taktische Stufen 0/1/2/3 bedeuten exakt 0/1/2/3 Kapazität, unabhängig von
  Difficulty, Werkstatt und Evolutionen. Alte Difficulty-/Bastion-Kapazitätswerte
  werden vom Player nicht mehr verwendet.
- Jeder erfolgreiche taktische Kauf gibt genau **eine** Ladung und erhöht die
  Kapazität auf die neue Stufe. Ein leeres Schild 1 → 2 hat danach eine Ladung,
  nicht automatisch zwei.
- Nach Kauf bleibt automatische Regeneration erhalten: Basis 12 Sekunden je
  Ladung, Werkstatt-Schildaufladung unverändert 8/6/4 Sekunden.
- Bastion wirkt nur mit gekauftem Schild: 35 % kürzere Ladezeit = 7,8 Sekunden
  ohne weitere Werkstatt, plus vorhandener Gegenimpuls.
- Nektarstau füllt ausschließlich gekauftes Schild bis zu dessen Kapazität.
  Der unveränderte Punktebonus bleibt auch ohne Schild verfügbar.
- `shield_active()` bleibt bei gekauftem, leerem Schild wahr. Ohne Kauf bleiben
  Ladefortschritt, Ladungen, Timer und Sternanzeige null/aus.
- `setup`, `try_buy`, `apply_shop_changes` und `reset_for_checkpoint` beachten
  dieselben Gates. Werkstattstufen werden dadurch nicht aus dem Save entfernt.

## Werkstatt: Schildstabilität

Die Save-ID `extra_shield` und die Preise bleiben erhalten. Anzeigename jetzt
**Schildstabilität**; keine freie Ladung oder Kapazität mehr.

| Werkstattstufe | `shield_grace` | Gemessener Schutz nach verlorener Ladung |
| --- | --- | --- |
| 1 | +0,25 s | 0,80 s |
| 2 | +0,50 s | 1,05 s |
| 3 | +0,85 s | 1,40 s |

Die Zeiten enthalten die bisherigen 0,55 Sekunden Schildschutz. Sie gelten nach
jeder verlorenen Ladung, auch der letzten. HP-Trefferschutz/Nachbrenner werden
nicht damit vermischt. Ohne taktischen Kauf entsteht daraus kein Schutz.

## Neue Sternanzeige

[shield_rings.gd](<../scripts/game/shield_rings.gd>) zeichnet pro vorhandener
Ladung ein echtes geschlossenes Pentagramm mit fünf Kanten (jede zweite Spitze
verbunden). Keine alte `icon_shieldbar`-Spriteaura, keine Texturimporte.

- Radien 34/44/54 Pixel; transparente Mint-/Goldlinien.
- Drehrichtung innen nach außen: Uhrzeigersinn / Gegenuhrzeigersinn /
  Uhrzeigersinn. Ruhige Winkelgeschwindigkeit 0,20 / −0,16 / 0,12 rad/s.
- `set_status(charges, reduce_effects)` synchronisiert Status und fordert ein
  Neuzeichnen an. `advance(delta)` verwendet Spielzeit statt Wandzeit.
- `lines()` liefert genau die Geometrie, die der Zeichenpfad verwendet.
- Reduzierte Effekte entfernen nur den weichen Glanz; Anzahl und Kontrast der
  Statuslinien bleiben gleich. Ladungsverlust, Kauf, Nektarstau, Checkpoint und
  Shop-Anwendung aktualisieren die Anzeige ohne zusätzlichen Physiktick.
- Biene bleibt 40 × 32 Pixel, unskaliert; Trefferkreis weiterhin 4,6 Pixel.
  Die Fluggrenzen lesen die gemeinsamen App-Konstanten passiv.

## Kreisflug und zusätzliche World-Schnittstelle

Kreisflug-Radien jetzt **110/142/166 Pixel**; Stufe 3 behält die schnellere
Winkelgeschwindigkeit 3,6 gegenüber 2,4. Hauptwaffen-/Spiralprofile sowie
Komposition mit Welle und Zielsuche bleiben erhalten und werden über den echten
Player → Game → BulletField-Weg geprüft.

Die separat abgestimmte optionale `Game.gravity_pull()`-Kraft wird nicht durch den
bestehenden 72%-Windgegenfilter abgeschwächt. Bei aktiver Abwärtsgravitation und
Aufwärtsinput wird die gesamte vertikale Umgebungskraft auf 90 % der tatsächlich
angeforderten Aufwärtsgeschwindigkeit begrenzt: auch analog, diagonal und im
Präzisionsmodus bleibt Aufwärtsbewegung möglich. Ohne Methode bleibt das frühere
Windverhalten unverändert. World-Tests/World-API liegen im anderen Arbeitsbereich.

Zusätzliche Runscore-Abstimmung: `Player.add_points(n)` schreibt bei echtem
Game-Parent in `campaign`/`rush` zusätzlich über `Save.add_run_score(n)` den
kumulativen Verdienst fort. Nektarstau verwendet denselben Weg mit unverändert
8 Punkten je Nektar. Training und reine Player-Vorschauen erhalten keine
Run-Credits; Werkstattausgaben senken den Runscore nicht. Null/negative Beträge
werden nicht als Einkommen gewertet. Save-Speicherung/Identität gehören zum
separaten Save-Arbeitsbereich.

## Neue owned Tests und Rot-/Grünnachweise

[Spielerprobe](<../tests/stingforge_r2_player.gd>) mit
[Testszene](<../tests/stingforge_r2_player.tscn>) verwendet echte Player-Methoden,
reale Game/BulletField-Objekte und feste Simulationszeit am Physics-Callback.
Keine Produktionsobjekte oder Timer werden durch Test-Doubles ersetzt.

Nachweise vor dem jeweiligen Fix:

1. Kauf-Gate: **4 Checks / 4 Fehler**, Phantom-Schild aus Shop/Evo/Nektarstau.
2. Schildstabilität: **117 Checks / 25 Fehler**, fehlender Zeitbonus/Schutzzeit.
3. Eigene Sternanzeige: **118 Checks / 1 Fehler**, alte Spriteaura.
4. Kreisflug: **168 Checks / 10 Fehler**, alte Reichweite.
5. Runscore-Einnahme: **201 Checks / 8 Fehler**, fehlende Weiterleitung der
   Spieler-/Nektarstaupunkte an den kumulativen Laufverdienst.

Aktueller grüner Stand: **201 Checks / 0 Fehler**, Exitcode 0,
exakte Erfolgszeile `STINGFORGE_R2_PLAYER_OK`. Umfasst alle drei Difficulties,
alle taktischen Stufen, Kauf aus leerem Schild, Checkpoint/Shop-Apply,
Regenerationsgrenzen, Nektarstau, sämtliche Stabilitätsstufen mit Schutzzeitende,
Sterngeometrie/-richtung/-anzahl, Reduce-Effects, Bienenmaße, Kreisflug sowie
Bastion-Gegenimpuls und Regeneration auf jeder taktischen Stufe sowie Runscore
für Kampagne/Boss Rush einschließlich Trainingsausschluss und Nektarstau.

```bash
XDG_DATA_HOME="$PWD/build/stingforge-r2-testdata-player/data" \
XDG_CONFIG_HOME="$PWD/build/stingforge-r2-testdata-player/config" \
XDG_CACHE_HOME="$PWD/build/stingforge-r2-testdata-player/cache" \
godot --headless --audio-driver Dummy --path . res://tests/stingforge_r2_player.tscn
```

Die zusätzliche [Renderprobe](<../tests/stingforge_r2_player_visual.gd>) mit
[Szene](<../tests/stingforge_r2_player_visual.tscn>) stellt 0–3 Ladungen mit/ohne
Glanz nebeneinander dar. Sie benötigt einen echten Render-Displaytreiber und
meldet im Headless-Modus ausdrücklich Exitcode 2 statt einen falschen Bild-Erfolg.

Der echte Wayland-/llvmpipe-Lauf mit DummyAudio ist abgeschlossen: **Exitcode 0**,
`STINGFORGE_R2_PLAYER_VISUAL_OK`. Das erzeugte
[Bild mit 0–3 Ladungen und reduzierten Effekten](<../build/stingforge-r2-testdata-player/shield-rings.png>)
wurde tatsächlich geöffnet und geprüft: richtige Sternanzahl, getrennte Radien,
transparenter Mint-/Goldlook, gleiche Statuslinien bei reduzierten Effekten.
Kein nachträglicher Produktions-Tweak nötig. Das
[Renderprotokoll](<../build/stingforge-r2-testdata-player/player-visual-wayland.log>)
enthält beim Prozessende 4 ObjectDB-/2 Ressourcen-Leakmeldungen, aber keinen
Render-/PNG-Schreibfehler; dieser Shutdown-Hinweis wird nicht als fehlerfreies Log
verschwiegen. Der Prozess ist beendet, es bleiben keine eigenen Hintergrundjobs.

## Bestehende Regressionen / Übergabe

Bestehende Tests wurden hier **nicht editiert**. Beim ersten Regressionslauf:

- World-Synergy im vorliegenden Quellstand: **61 Checks / 0 Fehler**.
- Weapons-Matrix: **1153 Checks / 13 Fehler**. Davon 12 alte Erwartungen für
  freie `extra_shield`-Kapazität (4 Waffen × 3 Stufen) und 1 alter Bastion-Consumer
  ohne taktischen Kauf. Die übrigen 1140 Checks einschließlich Schusskomposition
  und Maxbuilds bestanden. Diese 13 Erwartungen müssen im anderen Arbeitsbereich
  auf die neue Spezifikation umgestellt werden, nicht durch freie Kapazität im
  Player wieder grün gemacht werden.

Externe Text-/Datenanforderungen: Bastion-Beschreibung/Effect ohne `shield_hits`,
35 % kürzere Regeneration + Gegenimpuls, gekauftes Schild als Voraussetzung.
Gemeinsame App-Grenzen 56/476 sowie Levelreset (Basis bereit, übrige Taktik 0)
werden außerhalb dieses Dateiscopes integriert. Alte Kampagnen behalten gekaufte
Taktik bis zum nächsten Level. Keine Änderung am Kontrollpunkt-Kaufvertrag nötig.
