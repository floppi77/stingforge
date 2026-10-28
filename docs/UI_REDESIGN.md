# UI-Redesign – historische Entwicklungsrunden

> Dieses Dokument beschreibt die früheren, rein optischen Runden. Der aktuelle
> Stingforge-Zusatzauftrag ändert ausdrücklich auch Balance, Fähigkeiten,
> Trefferzonen und HUD-Grenzen. Aktueller Umfang und Nachweise stehen im
> [Stingforge-Bericht](<STINGFORGE.md>). Die folgenden Unverändert-Aussagen gelten
> ausschließlich für die damaligen UI-Runden.

## Umfang

Diese Überarbeitung betrifft ausschließlich Menüs und HUD. Spielablauf, Balance,
Gegner, Leveldaten, Audio, Kollisionsgrenzen, Kaufregeln, Speicherformat und die
zentrale Eingabeverarbeitung bleiben unverändert. Auch die Grenze des Spielfelds
bei 452 von 540 logischen Zeilen bleibt gleich.

## Aktueller Stand: Hauptmenü nach Bildvorlage

Das Hauptmenü folgt jetzt der vom Betreiber gelieferten Layoutvorlage:

- Der anschließend gelieferte Bienen-/Ruinenhintergrund wird unverändert verwendet
  (SHA-256 `f7ed53f07903d81e3d428a56add3e12f4e082ce82fe4f57388156ff3e46c58a8`).
- Der goldene Titel ist als transparente Grafik aus der Layoutvorlage isoliert.
- Links stehen freie Menüzeilen statt einer Liste gerundeter Kacheln; nur die
  aktive Zeile erhält goldenen Rahmen, Lichtsaum und transparentes Gold.
- Fortsetzen steht oben; ohne Spielstand ist es gesperrt und Neue Kampagne wird
  vorausgewählt. Gesperrte Einträge haben ein Schloss, Boss-Rush eine Erklärung.
- Die transparente Statuskarte sitzt unten rechts unterhalb der Biene. Level,
  Schwierigkeit, Punkte, Profil-Evolutionen und Bestpunkte werden aus dem echten
  Spielstand gelesen. Die Bestpunkte verwenden das tatsächlich vorhandene
  Profilfeld `best`, die Schwierigkeit den gespeicherten Lauf.
- Alle acht Einträge passen bei Standardschrift ohne Scrollen. Bei größerer
  Schrift bleibt die Liste scrollbar, und die Auswahl scrollt zum gewählten Ziel.
- Tastatur und Xbox bleiben gemeinsam sichtbar. Es sind funktionierende
  Menüelemente, keine übernommene Bildschirmaufnahme mit festen Zahlen.

Nur das Hauptmenü und seine Grafiken wurden in diesem Nachtrag geändert.
Andere Menüs, HUD, Spielablauf und Balance bleiben auf dem zuvor geprüften Stand.
Der neue isolierte Prüflauf umfasst 506 Headless-Prüfungen für echte Spielstände,
Freischaltungen, Maus-/Menürouten und 100/120/160 Prozent Schriftgröße.

[Aktuelles Hauptmenü](<ui-reference/showcase.png>) ·
[Referenz-Prüfbilder](<ui-reference/>)

## Gemeinsamer Stil der übrigen Menüs und des HUD

- Dunkles Petrol, warme goldene Auswahl, mintfarbene Zusatzinformationen.
- Gerundete Karten, ruhige Flächen und ein dezentes Wabenmuster in den Menüs.
- Kräftigere und tatsächlich angewendete variable Schriftgewichte. Der bisherige
  String-Schlüssel für die Schriftachse wurde von Godot ignoriert; nun wird der
  numerische OpenType-Tag verwendet.
- Hauptmenü mit kompakter Profilkarte, Levelstand, Bestpunkten und
  Evolutionsfortschritt aus den bestehenden Speicherdaten.
- Einstellungen mit optischen Reitern, Wertpfeilen, Statuspunkten und visuellen
  Prozentbalken. Die bestehenden Wertbereiche und Übernahmefunktionen bleiben gleich.
- Werkstatt und Evolutionswahl mit klaren Karten und Detailspalten. Lange
  Beschreibungen können innerhalb der Karte scrollen, statt die Fußleiste aus
  dem Bild zu drücken. Dafür funktionieren Mausrad und rechter Stick (RS),
  ausschließlich im aktiven Menü; die Flugsteuerung bleibt unverändert.
- HUD mit Karten für Vitalwerte, Nektar und Punkte, Tausendertrennung,
  kompakten Menü-/Autofeuerhinweisen, farblich getrennten Ausrüstungszuständen und
  einer ruhigen Bossleiste.
- Die Nektarumrechnung erhält ebenfalls eine eingerahmte Karte mit Tastatur-
  und Gamepad-Hinweis; Gutschrift, Dauer und Weiterleitung bleiben unverändert.

## Tastatur und Xbox gleichzeitig

Die Anzeigen lesen die tatsächlich gespeicherten Bindungen aus der bestehenden
Eingabeschicht. Ein angeschlossenes oder zuletzt benutztes Gamepad ist dafür
nicht erforderlich. Es gibt keinen Wechsel zwischen einer Tastatur- und einer
Controlleransicht mehr.

- Tastatur: rechteckige, leicht erhabene Tastenplaketten.
- Xbox: A grün, B rot, X blau, Y gelb; Trigger und Schultertasten als Kapseln.
- Die Belegungsübersicht besitzt getrennte Spalten für Tastatur und Xbox-Gamepad.
- `D` bedeutet Steuerkreuz, `LS` linker Stick. In Fußleisten steht auch `D-Pad`.
- `Leer` bedeutet Leertaste, `Eing.` Eingabe. Die Aktionsbelegung selbst bleibt
  unverändert.
- Nach einer Neubelegung wird die Anzeige neu aufgebaut. Das HUD liest die
  Belegungen beim Zeichnen. Fehlende Bindungen stehen als `—` da und werden
  nicht durch erfundene Standardtasten ersetzt.
- Ab größerer Schrift werden die Belegungen pro Aktion untereinander angezeigt;
  die Fußleiste kann umbrechen. Die lange Liste bleibt scrollbar.

## Nachweise und Wiederholung

Die Prüfungen verwenden getrennte Testdaten unter dem Buildordner, nicht die
Spielstände des Betreibers.

```bash
python3 tools/verify_ui_redesign.py

# Bilder und Geometrie im laufenden Fenster, Software-OpenGL:
GSETTINGS_BACKEND=memory LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 \
XDG_DATA_HOME="$PWD/build/ui-window-tests" \
godot --display-driver wayland --path . res://tests/ui_modern_probe.tscn
```

Der Quellschutz vergleicht 18 unveränderte Dateien der Spiellogik,
Autoloads und Projektkonfiguration sowie 42 Menü-/HUD-Eingabe- und
Zustandsfunktionen mit der Sicherung vor dem Redesign.

Weitere Prüfläufe: Tastenplaketten, Schriften, große Belegungsanzeigen,
Mausbedienung, Anzeigeübernahme, Kauf, Pause, Continue, Game Over, Bosse,
Spielmechanik, drei Builds und die bestehenden Inhaltsprüfungen.

Bildnachweise liegen unter [UI-Bilder](<ui-modern/>), darunter
[Hauptmenü nach Vorlage](<ui-reference/showcase.png>),
[Tastatur und Xbox](<ui-modern/03_tastatur_xbox.png>),
[HUD](<ui-modern/13_hud.png>) und
[160 Prozent Schriftgröße](<ui-modern/16_belegung_160.png>).

## Grenzen der Prüfung

Die Oberfläche wird unter Linux mit Software-OpenGL tatsächlich gerendert und
anhand der Bilder geprüft. Physische Xbox-Tasten, Stickgefühl und Vibration
können ohne angeschlossenes Gamepad nicht neu von Hand geprüft werden. Deren
Eingabecode wurde nicht verändert. Ein Windows-Start unter Wine ersetzt keine
native Prüfung auf einem Windows-PC.

Die ursprüngliche Oberfläche ist im Buildordner gesichert. Sie wird nicht in
die ausführbaren Dateien exportiert.
