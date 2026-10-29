## Download

| System | Datei | Hinweis |
|---|---|---|
| Windows | `Stingforge.exe` | eine Datei, keine Installation |
| Linux | `Stingforge.x86_64` | eine Datei; ggf. „Als Programm ausführen“ erlauben |
| macOS (Intel und Apple Silicon) | `Stingforge-macOS.zip` | entpacken, `Stingforge.app` nach „Programme“ ziehen |

Die Mac-App ist ad-hoc signiert, aber nicht von Apple notarisiert. Beim ersten Start daher im
Finder Rechtsklick › „Öffnen“ wählen. Meldet macOS „beschädigt“, hilft im Terminal:
`xattr -cr /Applications/Stingforge.app`

## Downloads prüfen

Alle Dateien sind in der CI aus dem getaggten Stand gebaut worden.

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing
```

Mehr dazu in [SECURITY.md](https://github.com/floppi77/stingforge/blob/main/SECURITY.md).
