# Stingforge R2 – persistente Run-Ranglisten

## Ergebnis und Zuständigkeit

Echte lokale Run-Gesamtpunkte statt einer umbenannten Levelbestenliste. Kampagne und Boss Rush haben getrennte Ranglisten. Beide bieten die Filter **Alle / Entspannt / Normal / Experte** sowie **Top 10 / Top 20**. Training zählt nicht.

Implementierung ausschließlich in [save.gd](../scripts/autoload/save.gd), dem neuen [highscore_screen.gd](../scripts/screens/highscore_screen.gd), den neuen [Scoretests](../tests/stingforge_r2_scores.gd), [Reloadtests](../tests/stingforge_r2_scores_reload.gd) und diesem Dokument. Die zugehörigen Testszenen sind [Scores](../tests/stingforge_r2_scores.tscn) und [Reload](../tests/stingforge_r2_scores_reload.tscn).

App-, Hauptmenü-, Spieler-, Umrechnungs-, Data- und HUD-Änderungen wurden vom koordinierenden Agenten beziehungsweise den anderen zuständigen Bearbeitern integriert, nicht durch diese Änderung. Die [Round-2-Baseline](../build/stingforge-round2-baseline/) wurde nicht bearbeitet.

## Regeln der Rangliste

- Sechs unabhängige Buckets: `campaign` / `rush`, jeweils `relaxed`, `normal`, `expert`.
- Dauerhaft maximal 20 sichtbare Ergebnisse je Bucket, also maximal 120 Ranglistenzeilen. `all` mischt nur Schwierigkeiten des ausgewählten Modus, niemals beide Modi.
- Reihenfolge: **Score absteigend → abgeschlossen vor nicht abgeschlossen → höchstes Level → früheste Erfassungssequenz → Run-ID**. Die Systemuhr beeinflusst Gleichstände nicht.
- Derselbe `run_id` erzeugt keine zweite Zeile. Verbesserte Wiederholungsaufrufe aktualisieren den bestehenden Lauf; Score und Level können dabei nicht sinken, ein Sieg bleibt ein Sieg.
- Eine kleine dauerhafte Run-Quittung erhält Bucket, Sequenz und maximalen Fortschritt auch nach Verdrängung aus Top 20. Ein verdrängter Run kann deshalb weder seine Schwierigkeit wechseln noch beim späteren Wiedereintritt einen bereits erreichten Sieg verlieren. Diese Quittungen wachsen mit der Anzahl echter Runs; die Ranglistenzeilen selbst bleiben auf 120 begrenzt.
- Ungültige Modi, Schwierigkeiten, negative/nicht ganzzahlige/nicht endliche Scores sowie ungültige Level werden zurückgewiesen. Ganzzahlen bis `9007199254740991` sind beim JSON-Roundtrip exakt darstellbar. Die laufende Punktsumme wird an dieser technischen Grenze gesättigt, nicht überlaufen.
- Standardpilot ist **Yuri**. Kein Netzwerk, kein Konto, keine Namenseingabe, keine Cloud-Synchronisierung und keine Anti-Cheat-Garantie für manuell veränderte lokale Daten.

## API und Integration

### `Save.ensure_run_score() -> void`

Ergänzt `campaign.run_id` und `campaign.run_score`, falls fehlend oder unbrauchbar. Die ID ist zufällig und unabhängig von Seed, Uhrzeit oder Pilot. Neue Kampagnen haben eine neue ID und starten bei null. Fortsetzen beziehungsweise Neuladen behält die ID.

Bei alten Kampagnen wird einmalig `max(points, sum(level_stats.score))` als Startschätzung importiert. `legacy_score_estimate=true` macht die Unsicherheit sichtbar. Eine vorhandene valide kumulative Summe wird nicht erneut importiert. Laden sichert eine reparierte ID sofort, reguläres Sichern ergänzt fehlende Felder ebenfalls. Die Schema-Versionsnummer bleibt **1**.

### `Save.add_run_score(amount: int) -> void`

Zählt ausschließlich positive Einnahmen zu `campaign.run_score`. Werkstattausgaben verändern nur das ausgebbare Guthaben, nicht diese Summe. Training wird über den aktiven App-Kontext abgefangen; Boss Rush funktioniert auch bei `active_campaign=false`.

Der koordinierte Spieler-Aufrufer zählt reguläre Punkte, der koordinierte Umrechnungs-Aufrufer zählt Nektargutschriften. **Keine zusätzlichen Levelgesamtsummen am Levelende addieren**, sonst würden dieselben Einnahmen doppelt gezählt. Die Methode schreibt nicht bei jedem Kill auf die Platte: laufende Einnahmen werden über die bestehenden Kampagnen-/Checkpoint-Speicherpunkte dauerhaft. Ein Absturz vor dem nächsten Speicherpunkt kann entsprechend den letzten ungesicherten Fortschritt verlieren.

### `Save.record_highscore(entry: Dictionary) -> bool`

Speichert einen neuen oder verbesserten Lauf beziehungsweise seine Quittung unmittelbar im Profil. `true` bedeutet erfolgreich dauerhaft übernommen, auch wenn ein neuer Lauf unterhalb der sichtbaren Top 20 liegt. `false` bedeutet unveränderte Wiederholung, ungültige Eingabe oder gescheiterter Schreibvorgang; Schreibfehler werden gemeldet und die In-Memory-Änderung zurückgenommen.

Felder:

| Feld | Bedeutung |
| --- | --- |
| `run_id` | Stabile eindeutige Laufkennung, nicht leer |
| `mode` | `campaign` oder `rush` |
| `difficulty` | `relaxed`, `normal` oder `expert`; `all` ist nur ein Filter |
| `score` | Kumulativ verdiente Run-Punkte, nicht aktuelles Werkstattguthaben |
| `level` | Erreichtes Level 1–10, Standard 1 |
| `completed` | Echter Laufabschluss, Standard `false` |
| `seed` | Laufseed, Standard 0 |
| `pilot` | Standard `Yuri`, begrenzt auf 32 einzeilige Zeichen |
| `legacy_score_estimate` | Optionaler Hinweis auf einen geschätzten Altstand |

Explizites `training=true` oder ein aktiver Trainingskontext verbietet die Aufnahme. Die Methode entscheidet nicht selbst, wann ein Run beendet ist: Der koordinierte App-Fluss meldet Aufgabe/letztes Game Over, vollständigen Boss-Rush-Sieg und den Kampagnenabschluss **nach** der finalen Nektarumrechnung. Ein Zwischenlevel ist kein abgeschlossener Run.

Boss Rush muss vor dem Start eine **eigene** Run-ID und `run_score=0` bekommen, nicht die ID oder Summe aus einer kopierten Kampagne. Danach `ensure_run_score()` aufrufen. Das ursprüngliche Kampagnen-Snapshot bleibt separat.

### `Save.get_highscores(mode = "campaign", difficulty = "all", limit = 10) -> Array`

Liefert sortierte **tiefe Kopien**. Änderungen an der Rückgabe können die gespeicherten Werte nicht verändern. Das Limit ist höchstens 20; null/negative Limits und unbekannte Filter ergeben eine leere Liste.

### Bildschirm öffnen

Der koordinierte Menüeintrag `scores` öffnet den eigenständigen Bildschirm:

```gdscript
app.push_screen("res://scripts/screens/highscore_screen.gd", {
    "mode": "campaign", "difficulty": "all", "limit": 10,
})
```

Der Bildschirm erbt vollständig von UiScreen und verwendet dessen moderne Gestaltung, Fokus, Scrollleiste und Bindings. Alle drei Filter sind `kind="choice"` und reagieren über `on_adjust` auf links/rechts sowie Bestätigen; keine Kaufbedingung und kein Punktverbrauch. Keyboard- und Xbox-Prompts werden gleichzeitig angezeigt. Zurück stellt den vorherigen Screen wieder her. Leere Filter erhalten einen Klartexthinweis; alte Levelbestwerte werden ausdrücklich nicht als Run-Gesamtergebnis ausgegeben. Ein Stern markiert geschätzte Altstände.

## Bestandserhalt und behobene Speicherfehler

`profile.best` bleibt vollständig separat; daraus werden **keine** angeblichen Run-Totals erzeugt. Das Profil erhält additiv `highscores`, `highscore_seq` und `highscore_runs`.

Vier vorhandene Probleme wurden am öffentlichen Speicherverhalten zunächst rot reproduziert und anschließend grün abgesichert:

1. Leere Standard-Dictionaries löschten beim Laden dynamische Schlüssel, unter anderem alte Levelbestwerte. Offene Dictionaries bleiben jetzt erhalten.
2. JSON liest ganze Zahlen auch als `float`; der bisherige strenge Typvergleich setzte dadurch Integerzähler auf Standardwerte zurück. Ganzzahlige Zahlenwerte werden jetzt korrekt übernommen.
3. Nach Backup-Wiederherstellung ersetzte der nächste Schreibvorgang die gesunde Sicherung durch die kaputte Hauptdatei. Jetzt bleibt die gesunde Sicherung erhalten; Rename-Fehler werden geprüft, nicht stillschweigend als Erfolg gemeldet.
4. Ein beendeter Run konnte nach Neustart aus der alten Kampagnen-Sicherung zurückkehren. `clear_campaign()` entfernt nun auch dessen Backup und temporäre Datei, ohne das Profil zu löschen.

Geschrieben wird weiterhin über verifiziertes temporäres JSON und Dateiumbenennung mit Sicherung. Beschädigte Daten werden defensiv geladen, ungültige/duplizierte Ranglistenzeilen aussortiert. Ein vollständiger Schutz gegen Stromverlust beziehungsweise Dateisystem-/Hardwaredefekte wird damit nicht behauptet.

## Tests und belegter Stand

Ausgeführt mit **Godot 4.7.2.stable.official.ed1daf0bf**, headless und Dummy-Audio. Sämtliche Dateien liegen in der isolierten Testumgebung unter `build/stingforge-r2-testdata-scores`; die Tests verweigern fremde Nutzerdatenpfade. Persönliche Spielstände wurden nicht verwendet.

Vom exakten Projektroot aus:

```bash
export XDG_DATA_HOME="$PWD/build/stingforge-r2-testdata-scores/data"
export XDG_CONFIG_HOME="$PWD/build/stingforge-r2-testdata-scores/config"
export XDG_CACHE_HOME="$PWD/build/stingforge-r2-testdata-scores/cache"
godot --headless --audio-driver Dummy --path "$PWD" res://tests/stingforge_r2_scores.tscn
godot --headless --audio-driver Dummy --path "$PWD" res://tests/stingforge_r2_scores_reload.tscn
```

**Ergebnis: 149 + 13 = 162 erfolgreiche Assertions, null Fehler.** Endmarker `STINGFORGE_R2_SCORES_OK` und `STINGFORGE_R2_SCORES_RELOAD_OK`. Der zweite Aufruf ist ein tatsächlich neuer Engineprozess und erzeugt seine Daten nicht selbst.

Abgedeckt sind alle Buckets/Filter/Limits, deterministische Gleichstände, Upsert einschließlich verdrängter Läufe, Trainingausschluss, echte Profildatei-/Neustartpersistenz, Backup-Korruption, alte Profilbestwerte/Zähler, kumulative Einnahmen gegenüber Ausgaben, Continue-ID, neue Run-ID, Ende ohne Backup-Wiederauferstehung und Legacy-Schätzung. UI-Prüfungen kontrollieren Wahlfilter ohne Punktverbrauch, leere Listen, Top-20-Scrollbar, horizontale Zeilengrenzen und dualen Footer bei 100 % und 160 % Schrift. Zusätzlich wird der koordinierte **echte Hauptmenü-Aktionshandler** aufgerufen und Öffnen/Zurück der tatsächlichen Screens geprüft.

**Nicht behauptet:** physischer Xbox-Test, native Windows-Ausführung, Gamepad-Hotplug oder gerenderte Screenshot-/Pixelprüfung. Headless-Screen-Hooks und Layoutmessungen ersetzen keine Hardwareabnahme. Es wurden keine Fenster geöffnet und kein Fokus anderer Bearbeiter gestört.
