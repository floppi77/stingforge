# Stingforge: HUD und Biene

## Ergebnis und gemeinsame Spielgrenze

Das HUD verdeckt keine begehbare Welt mehr. Der gemeinsame Vertrag ist `App.PLAY_TOP = 76`; es wurden **nicht mehr als 76 Weltpixel** angefordert. Alle Koordinaten beziehen sich auf 960 × 540, nicht auf die spätere Fensterauflösung.

| Bereich | Weltkoordinaten | Gestaltung |
|---|---:|---|
| Opakes Kopfband | y = 0 … 76 | Durchgängiges dunkles Petrol; keine Welt durchscheinend |
| Statuskarten | y = 6 … 57 | Vital, Schild, Nektar, Punkte und zweizeilige Bedienung |
| Boss-/Meldungszeile | y = 60 … 74 | Name, schlanke HP-Spur und Phase/Schwachpunkt; letzte Meldung rechts |
| Gold-Mint-Trennkante | y = 74 … 76 | Klarer Abschluss vor der Welt |
| Freies Spiel | y = 76 … 452 | Keine HUD-Karte, Bossleiste oder Meldung im Feld |
| Taktische Leiste | ab y = 452 | Gewohnte Auswahl und bewusster Kauf bleiben erhalten |

Auch Bossankündigungen und kurzzeitige Kauf-/Statusmeldungen bleiben im Kopfband. Der frühere Vollbildblitz und das große Boss-Popup entfallen dort zugunsten einer ruhigen Headerwarnung. Die untere Trennlinie wurde nach innen versetzt: eine zentrierte Linie genau auf y = 452 würde sonst noch einen halben Pixel des Feldes übermalen.

Implementierung: [HUD](</home/floppi/Dokumente/DSH/Workspaces/Apidya/scripts/screens/hud.gd>). Fremde Gameplay-, App-, Art- und Manifestdateien wurden durch diesen Visualauftrag nicht verändert. Die gemeinsame Topgrenze und Schild-API wurden von den zuständigen Agenten bereitgestellt.

## Lesbarkeit, Schild und Bedienung

- Geprüfte Schriftstufen: **0,8 / 1,0 / 1,6**. Karten bleiben in ihrem festen Band; Schriften wachsen bis zum verfügbaren Platz, längere Texte werden anhand tatsächlicher Fontmetriken eingepasst. Keine Vergrößerung des Spielrandes.
- Tastatur **und** Xbox-Badges sind immer gleichzeitig sichtbar, auch ohne Controller. Die Anzeige liest die aktuellen Belegungen; R/X, Esc/Menü sowie Q/LB, E/RB und F/RT bleiben die üblichen Standardhinweise.
- Schildladungen sind große, geometrische Schildpips: gefüllt mit dunklem Haken, leer mit Kontur, nächster regenerierender Pip mit Mintpunkt. Dazu zählen `1 / 3`, ein Fortschrittsbalken und `Lädt · 6s`.
- Ein ausschließlich durch `shield_add` aus der Werkstatt freigeschaltetes Schild wird korrekt als aktiv gezeigt – auch ohne taktisch gekaufte Schildstufe. Leere Ladungen bedeuten nicht „inaktiv“.
- Das HUD liest ausschließlich `shield_active()`, `shield_regen_duration()` und `shield_regen_progress()` des Players. Die etwa zwölf Sekunden Grundregeneration und ihre Modifikatoren werden nicht im HUD nachgebaut. Schildstufen werden weiterhin bewusst gekauft; keine automatische Kaufaktion wurde hinzugefügt.
- Eingabeverarbeitung, Kaufaufrufe, Kosten-/Stufentexte, Autofeuerumschaltung und Auswahlzustand sind gegen den gesicherten Baselinecode unverändert geprüft.

## Neue Biene

[Produktions-PNG](</home/floppi/Dokumente/DSH/Workspaces/Apidya/assets/sprites/bee.png>) und [editierbare Aseprite-Quelle](</home/floppi/Dokumente/DSH/Workspaces/Apidya/assets/aseprite/bee.aseprite>) sind pixelgleich synchronisiert.

- Unverändert: **40 × 32 pro Frame**, **240 × 32 Sheet**, **sechs Frames**, **14 fps im Spiel**, Anker **(20, 16)** und `HIT_RADIUS = 4.6`.
- Bewusst gezeichnete warme Goldpelzflächen, dunkle gebogene Hinterleibsbänder, großes dunkles facettiertes Auge mit kleinem Glanzpunkt, feine Fühler, gegliederte Beine und echte halbtransparente Flügelmembranen mit verzweigten Adern.
- Fünf editierbare Ebenen: Flügel, Beine, Körper/Pelz/Bänder, Auge/Gesicht, Fühler. Körper, Auge und Fühler bleiben über alle sechs Frames exakt registriert; nur Flügel und feine Beinbewegungen variieren. Keine doppelten Flügelposen am Loopende.
- Die kräftige Goldfläche beträgt im ersten Frame 244 opake Goldpixel statt 113 in der Baseline. Die filigranen Flügel sind bewusst transparenter, nicht größer oder deckender gemacht.
- Die Aseprite-Dauern wechseln 71/72 ms; der sechs Frames lange Umlauf wird damit auf Millisekunden genau an 14 fps angenähert. Das unveränderte Spielmanifest spielt exakt 14 fps.
- Keine Bildgenerierung, kein Blender. Reproduzierbarer Pillow-Entwurf mit realem Aseprite-Export: [Zeichenwerkzeug](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tools/prepare_stingforge_bee.py>).

```bash
python3 tools/prepare_stingforge_bee.py
```

Das Werkzeug importiert nichts in Godot. Der einzige notwendige Assetimport ist `assets/sprites/bee.png`; er wurde dem Hauptagenten gemeldet und von ihm im gemeinsamen Import ausgeführt.

## Bildbelege

Alle Belege sind echte 1600 × 900 Spielrenderings. Sie wurden mit `read_image` angesehen; keine nachträgliche HUD-/Projektilmontage.

| Schrift | Ohne Boss | Mit Boss |
|---|---|---|
| Low 0,8 | [HUD](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/low_hud.png>) | [Boss](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/low_boss.png>) |
| Default 1,0 | [HUD](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/default_hud.png>) | [Boss](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/default_boss.png>) |
| High 1,6 | [HUD](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/high_hud.png>) | [Boss](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/high_boss.png>) |

Zusätzlich:

- [High: Bossalarm und Kaufmeldung](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/high_boss_notice.png>) – auch dann kein Overlay im Feld.
- [Projektile im hellen/bunten Blütenmeer](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/projectiles_bright.png>) und [Projektile im dunklen Pilzwald](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/projectiles_dark.png>): je **alle vier Gegnerarttypen × drei Bildhöhen**, insgesamt zwölf feindliche und zwölf freundliche Geschosse. Gerendert durch das echte `BulletField`, mit opakem dunklem Rand und hellem Kern. Aufstellung für vergleichbare Bildbelege eingefroren, Größen unverändert.
- [Bienen-Flugzyklus](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/bee-flight.gif>) und [Quell-Roundtrip](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/bee-source-roundtrip.png>).

## Reproduzierbare Prüfung

[Prüfläufer](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_visual_checks.py>) und [Godot-Probe](</home/floppi/Dokumente/DSH/Workspaces/Apidya/tests/stingforge_visual_probe.gd>) schreiben ausschließlich isolierte XDG-Testdaten unter `build/stingforge-testdata-visual` und Belege unter `build/stingforge-visual`. Audio verwendet den Dummy-Treiber. Es gibt keinen eigenen Importshuttle oder Releaseexport.

```bash
# Aseprite-PNG-Roundtrip, Artvertrags- und headless Layouttests:
python3 tests/stingforge_visual_checks.py

# Zusätzlich echte Wayland-Bilder und strenger HUD-Pixelvergleich:
python3 tests/stingforge_visual_checks.py --screenshots
```

Der Läufer setzt bei Bedarf `WAYLAND_DISPLAY=wayland-1`, Software-OpenGL und `GSETTINGS_BACKEND=memory`; somit werden weder Benutzerspielstände noch Desktop-Einstellungen verändert.

**Ergebnis:** Exit 0, **44 Prüfungen im Läufer**, **122 headless Layout-/Schnittstellenprüfungen**, **141 gerenderte Prüfungen**, jeweils null Fehlschläge. Der unabhängige Aseprite-Roundtrip stimmt pixelgenau mit der Produktions-PNG überein. Keine Script-/Parsefehler. Beim grafischen Godot-Shutdown erscheinen gelegentlich vier ObjectDB-/zwei Resource-Restmeldungen; der Bild- und Assertionslauf selbst ist erfolgreich. Der finale headless Lauf ist sauber.

Der wichtigste Nachweis ist kein bloßer Rechtecktest: Für **neun Varianten** wird die eingefrorene echte Spielwelt einmal mit und einmal ohne HUD aufgenommen. Der komplette native Bildausschnitt zwischen den beiden Spielgrenzen wird bytegenau verglichen, ohne Farb-/Pixelabweichungstoleranz. **Jede Variante hat `changed_pixels = 0`.** Die Umrechnung von logischen Canvas-Koordinaten in native Screenshotpixel erfolgt explizit.

Nachweise: [Zusammenfassung](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/checks-summary.json>), [Layoutbericht](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/layout-report.json>), [Render-/Pixelbericht](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/render-report.json>), [Headless-Log](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/headless.log>), [Render-Log](</home/floppi/Dokumente/DSH/Workspaces/Apidya/build/stingforge-visual/render.log>). Alle eigenen Hintergrundjobs wurden eingesammelt.
