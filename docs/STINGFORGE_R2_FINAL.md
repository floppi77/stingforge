# Stingforge R2 – Wiedergeburt des letzten Bosses

## Ergebnis und Änderungsgrenze

Der echte letzte Datenboss ist **`core_organism` in Level 10 „Kern der Verwandlung“**. Derselbe Boss beendet den Boss-Rush. `hive_core` ist keine aktuelle Boss-ID.

Der Encounter bleibt ein Bossobjekt mit zwei Formen. Nach dem ersten HP0 schrumpft/verblasst die alte Hülle für **1,65 Spielsekunden**, während ein lokaler Kronen-Telegraph die Wiedergeburt ankündigt. Währenddessen ist der Boss unverwundbar und verursacht keinen Körperkontakt-Schaden. Der alte Angriffszeitplan sowie gegnerische Kugeln werden sofort entfernt, gegnerische Kugeln beim Formstart nochmals bereinigt. Es gibt kein vorzeitiges `defeated`, keine Belohnung, keinen Levelabschluss und kein vorzeitiges Freigeben des Bossobjekts. Eine Spielunterbrechung hält auch die Wiedergeburt an.

Erst der Tod der zweiten Form emittiert genau einmal `defeated`; der unveränderte Game-Pfad vergibt daraufhin genau eine Bossbelohnung und beendet Level/Rush. Geprüft ist der tatsächliche Game-Aufruf bis `on_level_complete`, kein künstlicher separater Reward-Zähler. Die finale Menü-/Ending-Darstellung und Wayland-Bildaufnahme liegen beim koordinierenden Main/HUD-Agenten.

Produktionsänderung nur in [boss.gd](/home/floppi/Dokumente/DSH/Workspaces/Apidya/scripts/game/boss.gd), nach explizitem `HANDOFFSTABLE`. Neu sind der [lokale Visual-Helfer](/home/floppi/Dokumente/DSH/Workspaces/Apidya/scripts/game/boss_reborn_visual.gd), die unten genannten Grafiken, der [Generator](/home/floppi/Dokumente/DSH/Workspaces/Apidya/tools/prepare_stingforge_reborn.py) und die [Regression](/home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_r2_final.gd) samt [Szene](/home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_r2_final.tscn). Keine eigenen Änderungen an Game, Player, Data, Art, Manifest, HUD oder Parallax. Die [vorige Baseline](/home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-round2-baseline/README.md) wurde nur gelesen, nicht verändert. Im Projekt gibt es keine Git-Metadaten und keinen vorhandenen Graphify-Report; die Prüfung erfolgte durch gezielte Datei-/Methodensuche und Live-Godot-Tests.

## Zweite Form: drei Phasen, nicht vier

`first_form_max_hp` merkt den **bereits** von Game nach Level, Schwierigkeit und Ausrüstung skalierten Anfangswert. Die zweite Form bekommt exakt **1,75 × diesen Wert**. Es erfolgt kein erneuter Aufruf der HP-Skalierung und keine erneute Threat-/Enrage-Aufbereitung. Die bisherigen Power-Exponenten und der neue World-Level-Faktor bleiben vollständig bei Game.

| Phase | HP-Schwelle | Bewegung | Neue Kombinationen | Basisintervall vor bestehendem Level-Takt |
|---|---:|---|---|---:|
| 1 | 1,00 | Orbit | Kronenring + gezielter Fächer; Kernlanze + Zweifachzielsalve | 0,92 s |
| 2 | 0,66 | Achterbahn | Flügelorbit + gezielter Fächer; Lanzen-/Kronenwechsel | 0,72 s |
| 3 | 0,33 | Finalflug | Final-Fury + Kernlanze; Flügel-/Lanzenwechsel | 0,48 s |

Die Intervalle sind jeweils **20 % kürzer** als die entsprechenden ursprünglichen Kernphasen. Alle Geschosse laufen weiterhin ausschließlich über `Game.spawn_enemy_bullet`: unveränderter Cap **420**, kumulative Zulassung **0,8 bei relaxed/normal**, **1,0 bei expert**. Kein zweiter Filter und keine direkte BulletField-Umgehung.

Die erste Form behält ihre bisherigen Datenphasen einschließlich der bestehenden Level10-Enrage-Phase. Alle neun anderen Bosse bleiben Einform-Encounter und behalten ihre ursprünglichen Muster/Masken. Die neuen Form2-Phasen leeren zusätzlich ihre vorherige Combo-Timeline. `phase_changed(0/1/2)` sowie `hp_changed(hp,max_hp)` melden der bestehenden Anzeige den neuen Zähler 1/3 und den neuen HP-Höchstwert; Boss-ID und Level10 bleiben unverändert.

## Grafik und tatsächliche Trefferform

- [Phase 1](/home/floppi/Dokumente/DSH/Workspaces/Apidya/assets/sprites/boss_reborn_p1.png)
- [Phase 2](/home/floppi/Dokumente/DSH/Workspaces/Apidya/assets/sprites/boss_reborn_p2.png)
- [Phase 3](/home/floppi/Dokumente/DSH/Workspaces/Apidya/assets/sprites/boss_reborn_p3.png)
- [Editierbare Aseprite-Quelle](/home/floppi/Dokumente/DSH/Workspaces/Apidya/assets/aseprite/boss_reborn.aseprite)

Jeder PNG-Streifen ist 448 × 224 Pixel groß und enthält zwei 224 × 224 Atlas-Einzelbilder. Der handgeschriebene PIL-Generator kombiniert das vorhandene Kernchassis mit sechs zusätzlichen gegliederten Flügeln, einer verbundenen Krone, Hakenpanzerung und einem neu gefassten Herz. Phase2 öffnet zusätzliche Seitenklingen und Kühlkerne; Phase3 erhält weitere Kronenspitzen und sichtbare Kernrisse. Das ist eine andere Silhouette und Komposition, nicht bloß ein Farbtausch. Alle sechs Posen unterscheiden sich tatsächlich.

Die Aseprite-Quelle enthält vier benannte Layer, sechs RGBA-Frames und drei Phasentags. Ein unabhängiger Binär-/Pixelvergleich bestätigte, dass alle sechs zusammengesetzten Aseprite-Cels pixelgleich zu den PNG-Einzelbildern sind. Keine KI-Bildgenerierung, kein Blender, kein Grafik-Shuttle und kein Cache-Reset. Die drei PNG-Importe wurden ausschließlich durch Main koordiniert.

Der Helfer baut SpriteFrames mit zwei AtlasTextures pro Phase und lädt die Pfade optional zur Laufzeit; keine PNG-Preloads und keine Manifeständerung. Die bestehende Alpha-Maske liest unmittelbar die **aktuelle** Body-Textur und den aktuellen Frame. Krone, Flügel und Panzer gehören zur opaken Bodygrafik und kollidieren daher wirklich; transparente Ecken bleiben frei. Die dünnen lokalen Warnbögen sind ausdrücklich nur kosmetisch und gehören nicht zur Kontaktform. Neue Form und Module bleiben zwischen `App.PLAY_TOP=56` und `App.PLAY_BOTTOM=476`. Die Wiedergeburt macht bei Bedarf weich Platz für den größeren Körper, statt ihn zu teleportieren.

`access.reduce_effects` oder ausgeschaltete `graphics.flashes` unterdrücken die neuen Trefferblitze und reduzieren den lokalen Telegraphen. Die Wiedergeburt selbst bleibt ruhig und lokal; kein Vollbildblitz wird hinzugefügt.

## Rot → Grün und Reproduktion

Die vorab vereinbarten Testgrenzen sind Boss-Schaden/Physics, der echte Game-Abschluss-/Reward-Pfad, Rush und die aktuelle Sprite-Alpha-Kollision.

1. Vor Produktionsänderungen: **7 Checks, 6 gezielte Fehler, Exit1**. Erster HP0 emittierte schon Sieg/Reward, Timeline blieb erhalten, Revival-Invuln fehlte.
2. Nach Encounter-Zustand: **7/7 grün**.
3. Erweiterter echter Physicslauf: **14 Checks, genau 1 gezielter visueller Fehler**, weil der alte Body noch aktiv war. Ein zunächst ungültiger Positions-Testaufbau wurde berichtigt, bevor der verbleibende visuelle Rotbeleg wiederholt wurde.
4. Nach Grafik-/Combo-Anbindung: zunächst **167/167 grün**, danach mit originalen Form1-Gates, wirksamer Ausrüstungsskalierung, Schutzoptionen und Freeze **186/186 grün**.
5. Bestehende Boss-/Modul-/Maskenkompatibilität: **160/160 grün**. Zusammen **346 Verhaltensprüfungen**, beide Engine-Rückgabecodes0.

```bash
XDG_DATA_HOME="$PWD/build/stingforge-r2-testdata-final" \
  godot --headless --path "$PWD" --audio-driver Dummy \
  res://tests/stingforge_r2_final.tscn
```

Endmarker nur bei null Fehlern:

```text
STINGFORGE_R2_FINAL checks=186 failures=0
STINGFORGE_R2_FINAL_OK
GODOT_EXIT_CODE=0
```

Vollständiger [finaler Lauf](/home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-final.log). Laufzeitumgebung: **Godot 4.7.2.stable.official.ed1daf0bf**, Dummy-Audio, isoliertes XDG-Verzeichnis ohne echte Nutzerspielstände. Die Suite wartet im Kampagnen- und Rush-Pfad auf echte Engine-Physicsframes, durchläuft beide positiven HP-Phasenschwellen und deren Unverwundbarkeit, statt HP künstlich auf0 zu setzen oder Gates zu überspringen. Weitere gezielte Standalone-Ticks prüfen alle Schwierigkeiten und die bisherigen Form1-Gates.

Die bestehende Kompatibilitätssuite ist mit `res://tests/stingforge_world_boss.tscn` und separatem XDG-Unterordner `compat` ausgeführt worden. Ihr maximaler ursprünglicher Maskenwert lag bei etwa2,94ms für320Abfragen; das ist kein Render-FPS-Versprechen und kein Benchmark der neuen Form. Dort erschienen die bereits bekannten Audio-Resource-/ObjectDB-Warnungen beim Shutdown; Exit0, keine Script-/Parsefehler. Der finale neue 186-Check-Lauf endete ohne solche Warnungen.

## Kurzer Schnittstellenbericht

- Neue beobachtbare Bosszustände: `encounter_form=1/2`, `reviving`, `revive_t`, `first_form_max_hp`.
- `dead` bleibt während der Wiedergeburt **false**; `trace_hit` liefert dann leer und `take_damage` ignoriert Treffer.
- Bestehende Signale und Game-Reward-/Ending-API unverändert. Neue volle HP und Phase0 werden erst beim tatsächlichen Form2-Start gemeldet.
- Bullet-Cleanup verwendet nur die vorhandene optionale Elternmethode `clear_enemy_bullets`.
- Keine Änderungen weiterer Besitzerdateien, keine Debug-Instrumentierung und keine unbeaufsichtigten eigenen Fenster-/Grafikjobs. Alle eigenen Hintergrundprüfungen wurden eingesammelt.
