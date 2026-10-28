# Stingforge R2 – ehrliche Migration der Legacy-Regression

## Umfang und Sicherheitsgrenzen

Projekt: `/home/floppi/Dokumente/DSH/Workspaces/Apidya`, Engine `4.7.2.stable.official.ed1daf0bf`. Die 24 vorherigen Suiten wurden aus den unveränderten Runnerquellen [verify_ui_redesign.py](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tools/verify_ui_redesign.py>) (`SUITES`) und [verify_stingforge.py](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tools/verify_stingforge.py>) (`extra` plus Kampagne) übernommen. Deren R1-Produktionsquellschutz ist kein R2-Spezifikationsvertrag und wurde nicht umgeschrieben.

Geändert wurden ausschließlich die unten genannten elf bestehenden Legacy-GDs, der neue erlaubte [Legacy-Runner](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/r2_legacy_regression.py>) und dieser Bericht. Keine Produktionsdatei, kein Tool, kein `stingforge_r2_*`, kein [perf.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/perf.gd>) geändert. Keine Fensterstarts, Imports, Cache-Resets, Git-, Graphify- oder Blender-Aufrufe. Alle selbst gestarteten Engineversuche liefen einzeln und seriell mit `--headless --audio-driver Dummy`.

Jeder Versuch besitzt frische XDG-Daten-, Konfigurations- und Cacheverzeichnisse unter `build/stingforge-r2-testdata-regression`; allein die Sicherheitsprüfung des Menü-Referenztests verlangt und erhält einen Unterordner von `build/reference-menu-testdata`. Keine echten Nutzersaves. Die bestehende Round2-Baseline blieb in allen Durchläufen bytegleich: **1096 Dateien** geprüft, [Baseline-Nachweis](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-testdata-regression/before-1793131585783211592/baseline-unchanged.json>).

## Vorher: unveränderte Tests tatsächlich ausgeführt

[Unveränderte Baseline-Ergebnisse](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-testdata-regression/before-1793131585783211592/summary.json>): **17/24 Suiten** nach bisherigem Kriterium grün, **7/24 rot**, **46 fehlgeschlagene Assertions**, überall **0 Script-/Parse-/Compile-Errors**. Jeder echte Prozesscode und der exakte Endmarker wurden geprüft, nicht nur ein beliebiges `OK` im Text.

| Suite | Unverändert rot | Ursache |
|---|---:|---|
| Menüreferenz | 6 | Acht statt neun Menüaktionen erwartet. |
| Mechanics | 4 | Gekaufte Taktiken sollten auf 1 statt 0 fallen; alte untere HUD-Grenze. |
| Upgradeprobe | 1 | `extra_shield` sollte drei Kapazitäten freischalten. |
| Gameover | 1 | Privater Levelstart setzte den tatsächlichen Kampagnenmodus nicht. Strenger Abbruchschutz unterscheidet inzwischen echte Kampagne und temporäre Modi. |
| Weapons-Probe | 4 | Werkstatt/Bastion/Nektarstau fälschlich als eigenständige Schildquellen. |
| Waffenmatrix | 13 | 12 Kapazitäts-Wirkungsmessungen, einmal alter Bastion-Consumer. |
| Visual-Probe | 17 | Alte Schildquellen/76px-Header, Regeneration ohne Kauf, zwölf alte Hint-Höhen. |

Zusätzlich enthielt bereits der **unveränderte** [Smoke-Log](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-testdata-regression/before-1793131585783211592/smoke.log#L4-L7>) einen allgemeinen Engine-Laufzeitfehler trotz Exit 0 und grünem Marker: `Lambda capture ... was freed`. Dieser Fehler wurde nicht als Spezänderung abgetan; siehe unten.

## Pro verändertem Test: alte gegen neue Spezifikation

Alle Nachherzahlen beziehen sich auf den abschließenden Stand; ein Check ist eine Assertion, soweit der jeweilige Alt-Test einen Zähler besitzt.

| Test | Konkrete Migration / unverändert erhaltene Schranke | Vorher → Nachher |
|---|---|---|
| [main_menu_reference_probe.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/main_menu_reference_probe.gd>) | Acht IDs → exakt `continue,new,training,rush,shop,scores,settings,credits,quit`. Scores immer freigegeben, navigierbar, echte Route und Rückkehr. **Alle neun Standardzeilen ohne Scrollen**; Sichtbarkeit, Statuskarte, Überlappungen und Rechteckgrenzen nicht abgeschwächt. | 518 Checks / 6 Fehler → **554 / 0** |
| [mechanics.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/mechanics.gd>) | Frühere Rückstufung gekaufter Taktiken auf 1 → alle acht Käufe exakt 0. Kostenlose BASIS1 bleibt, Waffe `base`, Tempo 0, Shop/Evos bleiben. Falsche Fixture-ID `bomb` → tatsächliches `bombs`. Alte HUD-Untergrenze → exakt **56/476**. Andere Boss-, Projektil-, Bewegungs- und Eingabeprüfungen bleiben. | 35 / 4 → **41 / 0** |
| [gameoverprobe.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/gameoverprobe.gd>) | Direkter Teststart setzt explizit `App.mode=campaign`, von Main bestätigt. Kampagnenlöschung nach Abbruch **weiterhin zwingend**, nicht entfernt. Tod prüft nun alle acht Käufe 0, BASIS1, Tempo0, Schild inaktiv/cap0/hits0 sowie Shop/Evos erhalten. | 16 Assertions / 1 Fehler → **25 / 0** |
| [upgradeprobe.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/upgradeprobe.gd>) | Kreisflug-Radius nicht nur alter Mindestwert80, sondern tatsächlich **110/142/166** je Kaufstufe. `extra_shield` misst keine Zusatzkapazität mehr: reale Schildverluste ergeben **0.55/0.8/1.05/1.4s** Schutz für Shop0/1/2/3. Weitere Treffer unmittelbar vor Ablauf geblockt, danach exakt1HP Schaden; Kapazität bleibt1. Regeneration nur nach echtem taktischem Kauf, bei Shop3 nach4s statt12s; ohne Kauf nie Ladungen. | 33 insgesamt, davon32 bestanden / 1 Fehler → **47 / 0** |
| [stingforge_weapons_probe.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_weapons_probe.gd>) | Taktik1/2/3 exakt cap/hits1/2/3. Shop allein: keine Aura, kein Schild, kein Reset-Nachladen. Bastion ohne Kauf bleibt inaktiv; gekauft nur Dauer×0.65 und echter einzelner Gegenimpuls, keine Kapazität. Auch Shop+Bastion+Nektarstau ohne Kauf bleiben0; Nektarstau füllt nur bereits gekaufte Kapazität. | 91 / 4 → **95 / 0** |
| [stingforge_weapons_matrix.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_weapons_matrix.gd>) | 12 alte `extra_shield`-Kapazitätsmessungen → tatsächliche Schutzzeit nach gekauftem Schild plus echte Treffer vor/nach Timerende. Regenerationsartikel nach tatsächlichem Kauf und beobachteter Rückladung. Bastion-Consumer `shield_hits` → `shield_regen`; explizites **Negativgate ohne Kauf** zusätzlich vorhanden. Keine Fallmatrix oder Projektilgrenze entfernt. | Tatsächlicher aktueller Vorlauf **1152 / 13** → **1153 / 0** |
| [stingforge_visual_probe.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_visual_probe.gd>) | Gefälschte Werkstattkapazität → echte taktische Käufe; Leerstand bleibt nur nach Kauf aktiv, ohne Kauf trotz Werkstatt cap/hits0. Header56, Unterkante476; neues Levelbadge, alle Status-/Boss-/Meldungsräume, alle neun Karten vollständig in den Bändern. Hint-Checks messen tatsächliche neue Positionen y2/19 und16px-Höhe statt alter26+20. **Pixelgleichheit mit/ohne HUD bleibt exakt, Toleranz0.** | 122 / 17 → **275 / 0**, headless |
| [smoke.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/smoke.gd>) | Gemeinsamer Defeatpfad plus tatsächlich gestartetes Level10: erster Tod kein Sieg, natürlicher Übergang, Form2 mit1.75×erster MaxHP und exakt3Phasen, danach erneut besiegen. Kein direkter Aufruf einer Revival-Endfunktion. Zusätzlich separat freigegebener WeakRef-Harnessfix, siehe unten. | 46 / 0 Assertions → **54 / 0**, allgemeiner Alt-Laufzeitfehler separat behoben |
| [campaign.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/campaign.gd>) | Alle zehn Level/Evolutionsangebote bleiben. Beim finalen Boss wird während realer Häutung nicht weiter in Übergangszustände eingegriffen; erste Häutung und zweite Form müssen beobachtet werden, MaxHP×1.75/3Phasen geprüft, erst zweiter Tod beendet Level. | **10 Level / 10 Evolutionswahlen**, nachher zusätzlich beide finale Zustände zwingend |
| [ending.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/ending.gd>) | Gesamter zehnteiliger Boss-Rush bleibt. Finaler Boss muss natürlich häuten und Form2 mit×1.75/3Phasen erneut besiegt werden; erster Tod darf keinen Abschluss melden. | **10 Bosse**, finale Beobachtungen **true/true**, 0 Fehler |
| [ui_text.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/ui_text.gd>) | Neuer echter Highscore-Screen in bestehende Prüfung gegen rohe Schlüssel/ungefüllte Platzhalter aufgenommen. | 265 / 0 → **274 / 0** |

**Matrix-Zählung ehrlich:** Die historische R1-Angabe1153 ist nicht das Ergebnis des unveränderten aktuellen Vorlaufs: durch das spezifikationsgemäß entfernte Bastion-`shield_hits`-Datenfeld hatte die datengesteuerte Effektiteration tatsächlich1152 Checks. Ein ausdrücklich ergänztes, wirksames Negativgate stellt1153 her, statt die entfallene Aussage schweigend zu verlieren. Unverändert: **384 Waffen×Shop-Fälle, 192 Form-/Musterfälle, 2560 Proc-Versuche, 36 Evolutions-Consumer, Spielerlimit320/Gegnerlimit420**.

## Allgemeiner Fehler: nicht hinter grünem Marker versteckt

Der alte Smoke-Test capturte den Gegner direkt in seiner Warte-Lambda. Wird dieser Gegner korrekt zerstört und freigegeben, beanstandet die Engine bereits den Lambda-Aufruf. Rangfolge vor dem Testfix: freigegebener direkter Node-Capture, alternativ vorzeitiger App-/Szenenabbau, danach Engine-Eigenheit. Der [strenge rote Nachweis](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-testdata-regression/runtime-red-1793132309429823575/smoke.log>) führte bei Engine-Exit0/korrektem Marker bewusst zu **Runner-Exit1** wegen genau eines allgemeinen Laufzeitfehlers.

Main erlaubte den minimalen Harnessfix ausdrücklich: nur dieser Capture wird mit `weakref(dummy)` gehalten und vor Zugriff aufgelöst. Der eigentliche Abschuss und sein Erfolgskriterium bleiben unverändert. Der neue Runner lässt allgemeine Laufzeit-ERRORs ebenso wie Script-/Parse-/Compile-Errors rot werden. Nur die bereits vorher vorhandenen Exit-Cleanup-Meldungen `resources still in use at exit` werden gesondert ausgewiesen, nicht als verlorener Testfehler verborgen. Die alten Logs bleiben bestehen.

Der erste WeakRef-Gesamtnachlauf erkannte zusätzlich einen selbst verursachten Parsefehler: `:= weakref(...)` löste die projektweit strenge Variant-Typwarnung aus. Der Versuch wurde mit ParseError/fehlendem Marker/Timeout180 eindeutig rot protokolliert, nicht als Produktionsfehler etikettiert. Nur der Test wurde auf die explizite Deklaration `dummy_ref: WeakRef` korrigiert; anschließend wurde ein weiterer vollständiger24-Suiten-Lauf erfolgreich ausgeführt. Die übrigen23 Suiten des fehlgeschlagenen Freeze-Versuchs hatten jeweils Exit0/Marker/0 ScriptErrors/0 allgemeine RuntimeErrors. Auch dieser Fehlversuch bleibt im [Smoke-Log des ersten Freeze-Laufs](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-testdata-regression/frozen-final-1793132336025687834/smoke.log>) erhalten.

Ein Zwischenlauf enthielt außerdem einen selbst verursachten falschen neuen Testpfad `scores_screen.gd`. Nach Prüfung der tatsächlichen Menüroute wurde er auf den realen [highscore_screen.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/scripts/screens/highscore_screen.gd>) berichtigt. Dies war **kein Produktionsfehler**; [Zwischenlauf](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-testdata-regression/migrated-1793132022926364023/summary.json>) bleibt nachvollziehbar.

## Unveränderte Kriterien und Zusatzprüfungen

- Die komplette alte [Balanceprobe](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/balanceprobe.gd>) war bereits grün und wurde **nicht verändert**: keine pauschal gelockerten TTK-, Kugel- oder Leistungsgrenzen. Der Leveldruck legitimiert keine Abschwächung. Die unveränderte Welt-Synergie misst Upgradegewinne im selben Level1/5/10, inklusive sublinearer Gegner-/Boss-HP-Skalierung.
- [pointstable.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/pointstable.gd>) ist **nur Diagnose, kein Assertionstest**: Er druckt stets `PUNKTE_OK` und rechnet mit früheren festen Spawnintervallen. Sein alter Schätzwert523924 ist kein Beweis für das neue Leveldruck-Einkommen oder die echte Highscore-Persistenz. Nicht als Produktionskorrektheit ausgegeben und nicht durch Grenzlockerung verändert; Main wurde informiert.
- Der unveränderte [Visual-Pythoncheck](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_visual_checks.py>) mit `--art-only`: **32/32**, Exit0, Marker `STINGFORGE_VISUAL_CHECKS_OK`. Echter Aseprite-Roundtrip pixelgleich, Manifest40×32/6/14 und sieben bestehende HUD-Eingabe-/Verhaltensquellverträge erhalten. Keine Python-Dateiänderung nötig.
- Keine Highscore-Datenverlustannahme eingeführt, kein neuer Save-OpenDict-/Numeric-Fix oder Shader-/Designdatenzweig zurückgesetzt. Die eigenen `stingforge_r2_*`-Suiten der anderen Agents wurden weder geändert noch als eigene Prüfergebnisse ausgegeben.

## Abschließender strenger Lauf

**Abgeschlossen: 24/24 Runner-Einträge grün; alle24 echten Engine-Exitcodes0, alle24 exakten Endmarker vorhanden, 0 Script-/Parse-/Compile-Errors und 0 allgemeine Runtime-Errors.** Der frühere Smoke-Lambda-Fehler ist nicht mehr vorhanden. **4729 gezählte Assertions** aus den17 Suiten mit auswertbarem Zähler/Ergebniszeilen; die übrigen Altprüfungen werden nicht mit erfundenen Checkzahlen aufgefüllt. Insbesondere bleibt `pointstable` ein Diagnoseeintrag ohne Assertions.

[Finale Einzelergebnisse](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-testdata-regression/frozen-clean-1793132717420002006/summary.json>) · [Prüfzähler und vollständige Exitdiagnostik](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-testdata-regression/frozen-clean-1793132717420002006/checks-audit.json>) · [Quellen während des kompletten Laufs stabil](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-testdata-regression/frozen-clean-1793132717420002006/production-stability.json>) · [1096 Baseline-Dateien unverändert](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-testdata-regression/frozen-clean-1793132717420002006/baseline-unchanged.json>).

| Suite | Anzahl / tatsächlicher Aussageumfang | Ergebnis |
|---|---|---|
| `ui_prompts_probe` | 573 Checks | OK |
| `ui_modern_probe` | 99 Checks | OK |
| `main_menu_reference_probe` | 554 Checks; neun Standardzeilen ohne Scrollen | OK |
| `smoke` | 54 Checks; natürliche Finalform; WeakRef ohne Laufzeitfehler | OK |
| `content` | 1115 Checks | OK |
| `ui_text` | 274 Checks; inklusive Highscore-Screen | OK |
| `mechanics` | 41 Checks | OK |
| `flowprobe` | 6 Checks | OK |
| `shopprobe` | Bestehende Daten-, Kauf-, Eingabe-, Effekt- und Flowbedingungen; kein Zähler | OK |
| `upgradeprobe` | 47 Checks | OK |
| `bossprobe` | Bestehende Übergangs-/Bewegungs-/Projektilbedingungen; kein Zähler | OK |
| `balanceprobe` | Vier unveränderte Buildmessungen und alle alten Grenzen | OK |
| `gameoverprobe` | 25 positive Ergebniszeilen / Assertions | OK |
| `pointstable` | Zehn Levelberechnungen, **0 Assertions**, Diagnose-only | Marker/Exit OK |
| `ending` | Zehn Rush-Bosse, finale Häutung/Form2 tatsächlich beobachtet | OK |
| `builds` | Drei bestehende Live-Builds | OK |
| `stingforge_weapons_probe` | 95 Checks | OK |
| `stingforge_world_density` | 52 Checks | OK |
| `stingforge_world_motion` | 145 Checks | OK |
| `stingforge_world_boss` | 160 Checks | OK |
| `stingforge_world_synergy` | 61 Checks, Upgradegewinne im selben Level | OK |
| `stingforge_weapons_matrix` | 1153 Checks, unveränderte384/192/2560-Fallmatrix | OK |
| `stingforge_visual_probe` | 275 Checks, ausschließlich headless | OK |
| `campaign` | Zehn Level / zehn Evolutionswahlen, beide finale Formen zwingend | OK |

**Nicht verschwiegen:**22 der24 Suiten melden weiterhin die schon vorher vorhandenen ObjectDB-/Ressourcen-Diagnosen beim Prozessende. Sie stehen vollständig im Audit und den Rohlogs. Das Ergebnis bedeutet nicht „keinerlei Engine-Warnung“, sondern keine Script- oder allgemeinen Laufzeitfehler und keine fehlgeschlagenen Testbedingungen. Deren Cleanup liegt außerhalb dieser Spezmigration. Sämtliche selbst gestarteten Jobs wurden vollständig abgeholt; keine Engineprozesse zurückgelassen.

Reproduzierbar aus dem exakten Projektverzeichnis:

```sh
python3 tests/r2_legacy_regression.py --label frozen-clean
```

Die vorherige volle [24-Suiten-Auswertung](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-testdata-regression/final-1793132124746625266/summary.json>) war bereits nach bisherigem Marker/Exit/ScriptError-Kriterium24/24; der allgemeine Smoke-Capture-ERROR darin ist ausdrücklich **nicht** der saubere Endnachweis. Während des anschließenden roten Smoke-Nachweises änderte Main bewusst nur die L6/L10-Beschreibungstexte; [Stabilitätsnachweis](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-testdata-regression/runtime-red-1793132309429823575/production-stability.json>) benennt ausschließlich [data.gd](</home/floppi/Dokumente/DSH/Workspaces/Apidya/scripts/autoload/data.gd>). Der erste Freeze-Versuch sah daneben nur die parallel neu angelegte Main-Runnerdatei [verify_stingforge_r2.py](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tools/verify_stingforge_r2.py>) als Fingerprintänderung, keine Produktions-GD-Änderung; [Stabilitätsprotokoll](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-testdata-regression/frozen-final-1793132336025687834/production-stability.json>). Danach erneut kompletter strenger Rerun mit dem aktuellen Main-Toolstand; transiente Änderungen werden nicht durch eigene Produktionspatches kaschiert.

### Grenzen der Aussage

Dies ist eine **Headless-Regression**, kein neuer Screenshot- oder GPU-/FPS-Beweis. `rendered=false`: Es wurden hier keine Feldpixel gerendert und verglichen. Der unverändert exakte Neun-Varianten-Pixelvergleich ist im Fensterpfad vorhanden, wurde wegen Fokuskoordination ohne Go nicht gestartet. Verbleibende Prozessende-Ressourcen-/ObjectDB-Meldungen werden mit Rohlogs ausgewiesen. Endgültige visuelle Abnahme und ParentFlow-/Produktionsentscheidungen liegen bei Main.
