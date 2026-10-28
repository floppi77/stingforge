# Apidya Reimagined – Produktionsplan und Projektstatus

Stand: laufend aktualisiert. Arbeitstitel: **Apidya Reimagined**.

## 1. Referenzanalyse (Apidya, Kaiko/Play Byte 1992, Amiga)

- Horizontal-Shooter mit frei beweglicher Spielfigur (Biene), scrolling von links nach rechts.
- Amiga-typisch: hohes Tempo, dichte Gegnerformationen, harte aber faire Lesbarkeit,
  Chris-Hülsbeck-Soundtrack mit treibenden Melodien.
- Waffenleiste unten am Bildschirm: mehrere Symbole, per Taste weitergeschaltet, mit
  Ressource bezahlt; Basisschuss immer vorhanden.
- Weltreise: Blumenwiese/Teich/Natur -> Kanalisation/Industrie -> humanoide Endwelt.
  Organische Gegner (Insekten, Fische) weichen zunehmend Maschinen.
- Bosse sind große, mehrphasige Kreaturen mit klaren Angriffsmustern.
- Übernommen: Waffenleisten-Konzept, Ressourcenökonomie, Natur->Maschine-Dramaturgie,
  Bossdramaturgie. **Bewusst geändert (Vorgabe):** Halten der Feuertaste = Dauerfeuer,
  keine Aufladefunktion. Zusätzlich modern: Evolutionssystem, Checkpoints, Zugänglichkeit.

## 2. Technische Entscheidungen

| Punkt | Entscheidung | Begründung |
|---|---|---|
| Engine | Godot 4.7.2 stable, GDScript | vorhanden, MCP-Anbindung, 2D |
| Renderer | GL Compatibility | stabile 60 fps, Wine-freundlich, kein 3D nötig |
| Logische Auflösung | 960x540, UI in Ausgabeauflösung skaliert | Vorgabe, passt zu 16:9-Kette |
| Skalierung | canvas_items + keep aspect, ganzzahlig bevorzugt | Arena bleibt 16:9 |
| Audio | eigene numpy-Synthese -> OGG/WAV, Godot-Audiobusse | LMMS nicht installiert, kein SoundFont vorhanden (FluidSynth ohne .sf2 unbrauchbar) |
| Grafik | Aseprite (Pixel) + Blender-Renderings (Tiefenebenen), in Palette überführt | Vorgabe, konsistente Ästhetik |
| Export | Linux + Windows, `embed_pck=true`, Einzeldatei | Vorgabe, früh geprüft |

### Abweichungen / Ersatzwege (dokumentiert)
- **LMMS ist auf dem System nicht installiert** (`which lmms` leer). FluidSynth 2.6.1 ist
  vorhanden, aber es existiert **kein SoundFont** im System. Damit ist die bevorzugte
  MIDI->FluidSynth-Pipeline nicht nutzbar. Ersatz: eigener deterministischer
  Tracker/Synthesizer in Python+numpy (tools/audio/synth.py) erzeugt Musik und SFX,
  Quellen (Notendaten + Skript) bleiben erhalten. Alles wird vorgerendert, Godot spielt
  nur fertige Dateien.
- Aseprite-MCP hat ein festes Workspace-Verzeichnis außerhalb des Projekts. MCP wird für
  Autoring/Prüfung zentraler Assets genutzt, die Dateien werden anschließend ins Projekt
  kopiert; Massenproduktion läuft über Aseprite-CLI mit Lua-Skripten (dieselbe Aseprite-
  Installation, .aseprite-Quellen bleiben erhalten).

## 3. Meilensteine

1. [x] Bestandsaufnahme, Referenzanalyse, Entscheidungen
2. [x] Früher Ein-Datei-Exporttest Linux+Windows (embed_pck) erfolgreich
3. [ ] Level 1 vollständig spielbar (Grafik, Audio, Boss, Pause, Waffenleiste, Evolution)
4. [ ] Kritische Prüfung Spielgefühl/Eingaben, Schwächen beheben
5. [ ] Alle 10 Level, 36 Evolutionen, Speicherung, Schwierigkeitsgrade, Zusatzmodi
6. [ ] Durchspielen, Balance, Leistung, Release-Endkontrolle

## 4. Systemarchitektur

- Autoloads: `Loc`, `Data`, `Save`, `Bindings`, `Audio`, `App`.
- `App` besitzt den Screen-Stack (Hauptmenü, Einstellungen, Spiel, Pause, Evolution,
  Ergebnis) und die Kampagnen-/Run-Zustandsmaschine.
- `Data` hält alle Tabellen (Level, Gegner, Bosse, Waffen, Evolutionen) als GDScript-
  Dictionaries – keine verstreuten Konstanten in der Spiellogik.
- Spiel: `Game` (Wurzel), `Player`, `Projectile`, `Enemy`, `Boss`, `Director`, `HUD`,
  `Background`, `Pickup`.
- Eingaben laufen ausschließlich über `Bindings` (InputMap-Aktionen, Neubelegung,
  Hysterese für Trigger, Gerätewechsel). Ein `InputGate` erzwingt Loslassen nach
  Kontextwechsel.
- UI ist ein eigenes, fokusbasiertes Menüframework (keine Maus nötig, volle Kontrolle
  über Sperren/Freigeben von Eingaben).

## 5. Bekannte offene Punkte
- (wird laufend gepflegt)
