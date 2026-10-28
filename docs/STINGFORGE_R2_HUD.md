# Stingforge Round 2: schmales HUD und aktuelle Levelanzeige

## Umfang und gemeinsame Grenzen

Produktionsänderungen betreffen ausschließlich [HUD](</home/floppi/Dokumente/DSH/Workspaces/Apidya/scripts/screens/hud.gd>). App, Game, Player, Background, Daten und Bienenassets werden durch diesen Arbeitsstrang nicht verändert. Die Round-2-Baseline bleibt unverändert.

Der gemeinsame Vertrag auf 960×540 lautet:

| Bereich | Logische Koordinaten |
|---|---|
| Oberes Instrumentenband | y0 bis ausschließlich y56 |
| Fünf Instrumentenkarten | y4 bis ausschließlich y41, 37px hoch |
| Level-/Bossrail | y42 bis ausschließlich y54, 12px hoch |
| Zwei innere Trennstreifen | y54..55 und y55..56 |
| Spielfeld | y56 bis ausschließlich y476, 420px hoch |
| Unteres HUD-Band | y476 bis ausschließlich y540, 64px hoch |
| Unterer Status samt Eingabehinweisen | y478..494 |
| Neun taktische Karten | y496..538, 42px hoch |

`App.PLAY_TOP=56` und `App.PLAY_BOTTOM=476` werden vom zuständigen App-Arbeitsstrang gesetzt. Die untere Geometrie liest weiterhin die gemeinsame App-Grenze. Die Tests erzwingen zusätzlich die neuen literalen Werte 56/476, statt einen veralteten App-Wert blind als Erwartung zu übernehmen. Gefüllte Randstreifen liegen innen; keine zentrierte Grenzlinie ragt einen Pixel in das Feld.

## Level, Boss und Meldungen

- Ein eigener, fester 112px-Levelbadge zeigt beispielsweise **LEVEL03/10**. Er bleibt unabhängig von Bossname, HP, Phasenstatus, Bossalarm und Kaufmeldung sichtbar.
- Ohne Boss folgt daneben der Name aus `Data.level(...)`, beispielsweise **· Schilf und Teich**; eine Meldung besitzt rechts einen getrennten Platz. Training/Rush werden beim Namen kenntlich gemacht.
- Kampagne und Training lesen den tatsächlich geladenen `Game.level_index`, nicht den gespeicherten Kampagnenstand.
- Boss-Rush lädt die Level-10-Bühne, bekämpft aber Bosse verschiedener Level. Das HUD ordnet die aktive Boss-ID der zugehörigen Leveldatenzeile zu. Zwischen Bossen dient die aktuelle Rush-Sequenzposition als Quelle. `Boss.level_index` ist hierfür ungeeignet, weil er im Rush auch einen Bedrohungswert repräsentiert.
- Bossname, HP-Rail und Meldungs-/Phasenspalte besitzen eigene, nicht überlappende Rechtecke. HP liest bei jedem Zeichnen `b.hp / b.max_hp`, der Phasenzähler `b.phase + 1` und `b.phase_defs.size()`; es gibt keine fest eingebaute Phasenzahl.
- Bossalarm und die jeweils jüngste Meldung bleiben im Rail. Es gibt keinen HUD-Vollbildblitz und keinen wachsenden Textstapel über dem Spielfeld.

## Schild: Player-API ist alleinige Quelle

Das HUD verwendet `shield_active()`, `shield_max`, `shield_hits`, `shield_regen_duration()` und `shield_regen_progress()` des Players. Es berechnet keine eigene Kapazitäts- oder Regenerationsformel und wertet keine Shopfreischaltung als Schildquelle aus.

| Taktische Stufe | Kapazität und Darstellung |
|---|---|
| 0 | Keine Pips, keine gefüllte Ladung, kein Ladetrack; auch nicht mit permanentem Werkstattkauf oder alter Ladungszahl |
| 1 | Exakt ein Pip |
| 2 | Exakt zwei Pips |
| 3 | Exakt drei Pips |

Ein leeres, aber taktisch gekauftes Schild bleibt aktiv. Der Fortschritt wird direkt aus der API als Prozentstand und Track dargestellt; eine nachgerechnete Ladezeit ist nicht nötig.

## Lesbarkeit und Eingaben

Icons und Schriftfelder wurden für beide schmalen Bänder komprimiert. Die Nutzergrößen 0,8 / 1,0 / 1,6 werden durch echte Schriftbreite und -höhe an die festen Felder angepasst. Die Layoutprüfung umfasst zusätzlich 960×540, 1600×900 und einen versetzten 1920×1080-Zeichenbereich.

Tastatur **und** Xbox stehen stets gleichzeitig an allen fünf Hinweisen: Menü, Autofeuer, vorherige/nächste Karte und Nutzen. Alle neun Karten, Preise, Stufen und Aktivzustände bleiben vorhanden. Sieben Eingabe-/Kauffunktionen werden normalisiert mit der Round-2-Baseline verglichen und sind unverändert: `_handle_input`, `_process`, `_state_text`, `_state_short`, `maxed_out`, `boss_announce`, `show_banner`.

## Reproduzierbare Tests

Eigene, neue Dateien:

- [Prüfprogramm](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_r2_hud_checks.py>)
- [Echter Spiel-/Layout-/Pixelprobe](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_r2_hud_probe.gd>) und [Testszene](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_r2_hud_probe.tscn>)
- [Test-only Zeichenbeobachter](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_r2_hud_recording.gd>): delegiert jeden Zeichenschritt unverändert an das Produktions-HUD; protokolliert tatsächliche Textmetrics, duale Hinweise und Schildpips.

```bash
python3 tests/stingforge_r2_hud_checks.py
# Nur nach Abstimmung des gemeinsamen Wayland-Fensters:
python3 tests/stingforge_r2_hud_checks.py --screenshots
```

Alle XDG-Daten liegen ausschließlich unter `build/stingforge-r2-testdata-hud/{data,config,cache}`. Audio läuft mit Dummy-Treiber. Es werden keine Assetimporte oder Editorstarts ausgelöst. Für den Fensterlauf gelten `XDG_RUNTIME_DIR=/run/user/1000`, `WAYLAND_DISPLAY=wayland-1`, `GSETTINGS_BACKEND=memory`, `LIBGL_ALWAYS_SOFTWARE=1`, `GALLIUM_DRIVER=llvmpipe`.

Der initiale, zweimal reproduzierte Rot-Vertrag schlug exakt bei Headerhöhe, allen fünf Karten, Bossrail und fehlendem Levelraum fehl. Nach Umsetzung und dem ergänzten echten Form2-/Fokusvertrag bestand der Headless-Probe **2.095 Prüfungen ohne Fehler**. Er startet echte Spiele für L1/L8/L10, prüft Schildstufen 0..3 trotz permanentem `extra_shield=2`, den Bewegungsbereich und Training/Rush mit tatsächlichen Leveln 1/8/10.

Ein zusätzlicher Probe für den nachgereichten wiedergeborenen Endboss durchläuft den echten Formwechsel: neuer voller HP-Balken sowie **Phase1/3, Phase2/3, Phase3/3**, weiterhin mit Level10-Badge. Sein gesonderter Bildbeleg zählt nicht als zehntes Hauptpixelpaar.

Der koordinierte Renderlauf bestand **neun exakte A/B-Paare**: L1/L8/L10 × Schriftgröße 0,8/1/1,6. Enthalten sind normales HUD, Boss, Alarm vor Boss-Spawn und Bossalarm mit langer Kaufmeldung. Verglichen wird nur das neue Feld **[0,56,960,420]**, ohne Pixeltoleranz. Die Welttextur wird zwischen A und B festgehalten, damit Animation oder Shaderzeit nicht als HUD-Verdeckung fehlgemessen werden. Zusätzlich prüft Python die gespeicherten PNG-Paare unabhängig und verwirft leere Feldvergleiche oder ein vollständig unsichtbares HUD.

Ergebnisse landen unter `build/stingforge-r2-hud/`. Exitcode 0 ist nur zusammen mit **STINGFORGE_R2_HUD_OK** zulässig; Fehler ergeben **STINGFORGE_R2_HUD_FAIL** und Exitcode 1. Headless behauptet ausdrücklich keine ungerenderten Pixelprüfungen.

## Ergebnisstand

- Rot-Vertrag: reproduziert, anschließend grün.
- Headless: 2.095 Prüfungen, 0 Fehler, CodeStable gemeldet; letzter Lauf ohne Audio-/Ressourcenwarnung.
- Render: **3.278 Prüfungen, 0 Fehler**, alle neun Paare sowohl in Godot als auch unabhängig in Python grün. **10.065.600 verglichene Feldpixel insgesamt, exakt 0 Abweichungen.** Zusätzlich 531 tatsächlich gezeichnete Texte samt Schriftmetrics erfasst.
- Finaler Befehl: `python3 tests/stingforge_r2_hud_checks.py --screenshots` → **Exitcode0 / STINGFORGE_R2_HUD_OK**. Finaler Headless- und Renderlog enthalten keine Script-, Parse-, Audio- oder Ressourcenwarnung.
- Die unveränderte Round-2-Baseline besteht **1.095/1.095 SHA256-Prüfungen**. Der stabile HUD-Fingerabdruck lautet `bee08f160d1c180e7e1cb0d433a794a2081fd6b9466cc9bd902d64b9b2da7230`.
- Der erste Renderlauf deckte eine Fokusverlust-Pause im Testfenster auf. Das Produktions-HUD wurde dafür nicht geändert; der Test trennt ausschließlich sein eigenes Fokusverlust-Signal und prüft vor jeder Aufnahme, dass kein Menü/keine Pause über dem Spiel liegt. Die unabhängige PNG-Negativkontrolle wies das alte identische Pausebild ausdrücklich als falsche Grünmessung zurück.
- Zwischenzeitliche fremde Director-/Mainmenü-Parsefehler wurden nicht angefasst. Der Runner bricht mit `--quit-after 600` beschränkt ab und startet nach rotem Headless-Test kein Fenster.
- Dummy-Audio-Shutdownmeldungen werden nur separat eingeordnet, wenn der ausführliche Log ausschließlich Audio-/Ogg-Ressourcen und -Instanzen nachweist. Andere Ressourcen-, Script- und Parsefehler bleiben rot. Keine Mixer-Warteschleife, nur acht Cleanup-Frames.
- Eigener Hintergrundjob `bash-87062ca7a1e44cd9` wurde vollständig eingesammelt (damaliger Fremd-Parsefehler); aktuell keine offenen Jobs. Alle Fensterläufe sind beendet.

### Belege

- [Zusammenfassung mit Quellen-Fingerabdrücken](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-hud/checks-summary.json>)
- [Headlessbericht](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-hud/layout-report.json>) und [Renderbericht einschließlich Glyphenmetrics](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-hud/render-report.json>)
- [Unabhängiger PNG-Pixelbericht](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-hud/independent-pixel-report.json>)
- [Level1, Schildstufe0, Levelname und alle neun Karten](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-hud/L1_default.png>)
- [Level10, Bossalarm plus lange Meldung bei 160%](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-hud/L10_high_boss_notice.png>)
- [Level10, wiedergeborener Boss Phase3/3 mit eigenem Levelbadge](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-r2-hud/L10_high_form2_phase3.png>)
