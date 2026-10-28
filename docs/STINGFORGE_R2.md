# Stingforge R2 – Spielregeln und Änderungen

**Evolve. Adapt. Strike.**

## Was sich praktisch ändert

- **Mehr Spielfeld:** oben nur noch 56, unten 64 logische Pixel Bedienanzeige. Der aktuelle Level bleibt sichtbar. Bossleiste, Keyboard- und Xbox-Hinweise liegen außerhalb des Gefahrenfelds.
- **Taktik wird pro Level neu aufgebaut:** alle acht gekauften Zusatzfähigkeiten starten nach einem Levelabschluss wieder auf 0. Die kostenlose Basiswaffe bleibt verfügbar. Werkstatt und bereits erhaltene Evolutionen bleiben erhalten. Das Zurücksetzen geschieht bereits beim Abschluss, nicht erst beim nächsten Klick.
- **Schilde müssen gekauft werden:** Stufe 0 gibt keinerlei Schild; Stufen 1/2/3 geben genau 1/2/3 Ladungen, unabhängig von der Schwierigkeit. Die Werkstatt verbessert Schutzzeit und Regeneration, schenkt aber keine Ladung und schaltet keinen Schild frei. Bastion beschleunigt nur einen tatsächlich gekauften Schild.
- **Sichtbare Schildladungen:** ein bis drei dünne Pentagramme drehen sich rechts-/links-/rechtsherum um die Biene. Verlorene Ladungen verschwinden; reduzierte Effekte verstecken den Status nicht.
- **Orbit ist früher nützlich:** die Radien betragen jetzt 110/142/166 statt 62/86/86 logische Pixel. Bestehende Begleiter-Kombinationen bleiben bestehen.
- **Acht Tiefenebenen:** zusätzliche Dunst-, Schilf- und Wurzelebenen, reparierte Bodenanschlüsse und ausreichend Kachelkopien auch an Scrollnähten. Vorhandene Motive wurden nicht pauschal übermalt.
- **Gravitation wirkt wirklich nach unten:** senkrechte Feldlinien und Pfeile statt waagerechter Striche. Stärkerer Zug, aber auch diagonal beziehungsweise mit analogem Gegensteuern bleibt Aufstieg möglich. Überlagerte Felder vervielfachen den Zug nicht.
- **Mehr Leveldruck:** Gegnerzahl, Schussfolge, Gegnerleben und Bossleben steigen separat mit dem Level; die bestehende unterlineare Waffenanpassung bleibt. Auf Level 10 erreicht der zusätzliche Faktor für Bossleben etwa 2,53 gegenüber Level 1.
- **Zahlenkreise entfernt:** sie waren funktionslose Platzhalter, keine geheime Abschussreihenfolge. Jetzt erscheinen echte bekämpfbare Generatoren. Eine bestimmte Reihenfolge ist nicht nötig.
- **Glas ist vorhersehbar:** vier kurze Rahmenblitze während einer Sekunde Vorwarnung. Vorher keinerlei Kollision; danach fängt die aktive Fläche Schüsse ab und hat keinen leuchtenden Warnrahmen mehr. Umfliegen bleibt möglich.
- **Kurze Trefferpartikel:** kleine materialfarbene Splitter und Staub, ungefähr 120–210 ms sichtbar, mit festen Obergrenzen und Berücksichtigung der Effekteinstellungen.
- **Feste Run-Schwierigkeit:** Auswahl beim Start von Kampagne oder Boss-Rush. In den Optionen gibt es keinen nachträglichen Schwierigkeitsregler mehr.

## Highscores

Im Hauptmenü gibt es **Highscores**: getrennte Ranglisten für Kampagne und Boss-Rush, Filter nach Schwierigkeit, Top 10 oder Top 20.

Gezählt werden **verdiente Gesamtpunkte**, nicht das nach Werkstattkäufen verbleibende Guthaben. Nektarumrechnung zählt genau einmal dazu. Training zählt nicht. Eingetragen wird beim endgültigen Game Over, beim ausdrücklichen Beenden oder beim vollständigen Sieg. Ein Continue bleibt derselbe Run; wiederholte Abschlussaufrufe erzeugen keine Dubletten.

Bereits vorhandene Levelbestwerte bleiben erhalten. Sie werden nicht nachträglich als erfundene Run-Gesamtpunkte ausgegeben. Ein fortgesetzter alter Run kann nur konservativ geschätzt werden; solche Einträge sind mit einem Stern gekennzeichnet.

Speichersicherheit wurde zusätzlich verbessert: freie Schlüssel bestehender Wörterbücher bleiben erhalten, gespeicherte Ganzzahlen werden nicht durch JSON-Zahltypen zurückgesetzt, gesunde Sicherungen bleiben bei Wiederherstellung erhalten und beendete Kampagnen können nicht aus einer alten Sicherungsdatei wiederauferstehen.

## Neuer Endkampf – Spoiler

Der Kernorganismus ist nach seiner ersten Niederlage **noch nicht tot**. Nach 1,65 Sekunden Übergang kehrt er sichtbar verändert zurück:

- eigene gepanzerte Gestalt mit Krone, sechs Flügeln und veränderter Silhouette;
- 175 % der bereits skalierten Lebenspunkte der ersten Form;
- drei eigene Phasen bei 100/66/33 %;
- 20 % kürzere Angriffspausen und zusätzliche Musterkombinationen.

Erst seine endgültige zweite Niederlage löst Belohnung, Levelabschluss und Sieg aus. Das gilt auch im Boss-Rush. Die anderen neun Bosse erhalten keine zusätzliche Lebensrunde.

[Neue Form und kompakte Anzeige](<../build/stingforge-r2-hud/L10_high_form2_phase3.png>) · [Schildstufen](<../build/stingforge-r2-testdata-player/shield-rings.png>)

## Bildbelege

- [Vordergrund und Spielfeld](<../build/stingforge-r2-parallax/integrated_l01.png>)
- [Glas während Vorwarnung](<../build/stingforge-r2-world-visual-pulse.png>) und [aktiv ohne Warnrahmen](<../build/stingforge-r2-world-visual-active.png>)
- [Hauptmenü mit neuer Ranglistenaktion](<../build/stingforge-r2-frontend/main_menu.png>)
- [Rangliste](<../build/stingforge-r2-frontend/highscores_top10_testdaten.png>) und [große Schrift](<../build/stingforge-r2-frontend/highscores_160_testdaten.png>) – ausdrücklich isolierte **Testeinträge**, keine persönlichen Spielergebnisse.

## Prüfung und Grenzen

Die Detailberichte dokumentieren reale Engineprüfungen und verbleibende Grenzen:

[Player](<STINGFORGE_R2_PLAYER.md>) · [Parallax](<STINGFORGE_R2_PARALLAX.md>) · [World](<STINGFORGE_R2_WORLD.md>) · [HUD](<STINGFORGE_R2_HUD.md>) · [Endboss](<STINGFORGE_R2_FINAL.md>) · [Highscores](<STINGFORGE_R2_SCORES.md>) · [Regressionen](<STINGFORGE_R2_REGRESSION.md>)

Sämtliche Tests verwenden isolierte Datenverzeichnisse. Persönliche Spielstände wurden nicht verändert. Die R1-Auslieferung bleibt als unveränderte Ausgangssicherung erhalten.

Bekannt: Manche kurzen Läufe mit stummem Test-Audiotreiber melden beim Beenden noch Audio-/Playback-Ressourcen. Das ist dokumentiert, nicht als behoben ausgegeben. Script-, Parse- oder allgemeine Laufzeitfehler gelten nicht als grüne Prüfung. Software-OpenGL-Messungen sind kein Versprechen für jede Grafikkarte. Kein physischer Xbox-Controller und kein nativer Windows-PC stehen für diese Prüfung zur Verfügung.

## Abgenommene Auslieferung

[Windows-Einzeldatei](<../release/Stingforge.exe>) · [Linux-Einzeldatei](<../release/Stingforge.x86_64>) · [Prüfsummen](<../release/SHA256SUMS.txt>)

**34/34 Start-/Regressionssuiten erfolgreich**, vollständige erneute Bild-/Exportabnahme, Linux nativ und Windows unter Wine gestartet. [Abschließendes Prüfprotokoll](<TESTPROTOKOLL_R2.md>).

Die bisherige Auslieferung wird vollständig archiviert. Vor einem Rückwechsel auf R1 den Spielstandordner sichern: der alte Programmstand kennt neue Highscore-Profilfelder nicht.
