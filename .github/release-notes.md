## Deutsch

### Download

| System | Datei | Hinweis |
|---|---|---|
| Windows | `Stingforge.exe` | eine Datei, keine Installation |
| Linux | `Stingforge.x86_64` | eine Datei; ggf. „Als Programm ausführen“ erlauben |
| macOS (Intel und Apple Silicon) | `Stingforge-macOS.zip` | entpacken, `Stingforge.app` nach „Programme“ ziehen |

Die Mac-App ist ad-hoc signiert, aber nicht von Apple notarisiert. Beim ersten Start daher im
Finder Rechtsklick › „Öffnen“ wählen. Meldet macOS „beschädigt“, hilft im Terminal:
`xattr -cr /Applications/Stingforge.app`

### Downloads prüfen

Alle Dateien sind in der CI aus dem getaggten Stand gebaut worden.

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing
```

Mehr dazu in [SECURITY.md](https://github.com/floppi77/stingforge/blob/main/SECURITY.md).

### Unterstützen

Gefällt dir Stingforge? Über einen Kaffee auf [Ko-fi](https://ko-fi.com/floppi77) freue ich mich.

### Lizenz

Frei für nicht-kommerzielle Zwecke: Code unter
[PolyForm Noncommercial 1.0.0](https://github.com/floppi77/stingforge/blob/main/LICENSE),
Inhalte unter [CC BY-NC-SA 4.0](https://github.com/floppi77/stingforge/blob/main/LICENSE-ASSETS.md).
Die Spieldateien enthalten die Godot Engine (MIT), siehe
[THIRD_PARTY_NOTICES.md](https://github.com/floppi77/stingforge/blob/main/THIRD_PARTY_NOTICES.md).

Das Spiel spricht Deutsch und Englisch – umschalten per Flagge im Hauptmenü.


---

## English

### Download

| System | File | Note |
|---|---|---|
| Windows | `Stingforge.exe` | a single file, no installation |
| Linux | `Stingforge.x86_64` | a single file; allow “Run as program” if needed |
| macOS (Intel and Apple Silicon) | `Stingforge-macOS.zip` | unzip, drag `Stingforge.app` into “Applications” |

The Mac app is ad-hoc signed but not notarised by Apple. On first launch, right-click it in
the Finder › “Open”. If macOS reports it as “damaged”, run in the Terminal:
`xattr -cr /Applications/Stingforge.app`

The game speaks German and English – switch with the flags in the main menu.

### Verify downloads

All files were built by CI from the tagged source.

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing
```

More in [SECURITY.md](https://github.com/floppi77/stingforge/blob/main/SECURITY.md).

### Support

Enjoying Stingforge? A coffee on [Ko-fi](https://ko-fi.com/floppi77) is much appreciated.

### Licence

Free for non-commercial use: code under
[PolyForm Noncommercial 1.0.0](https://github.com/floppi77/stingforge/blob/main/LICENSE),
content under [CC BY-NC-SA 4.0](https://github.com/floppi77/stingforge/blob/main/LICENSE-ASSETS.md).
The game files contain the Godot Engine (MIT), see
[THIRD_PARTY_NOTICES.md](https://github.com/floppi77/stingforge/blob/main/THIRD_PARTY_NOTICES.md).
