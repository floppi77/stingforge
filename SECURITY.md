# Sicherheit

*Deutsch zuerst · [English below](#security-english)*

## Unterstützte Versionen

Sicherheitskorrekturen gibt es nur für das jeweils neueste Release.

## Schwachstelle melden

Bitte keine öffentlichen Issues für Sicherheitsprobleme. Stattdessen:

- auf GitHub unter **Security › Report a vulnerability** eine private Meldung anlegen, oder
- den Maintainer [@floppi77](https://github.com/floppi77) direkt über GitHub kontaktieren.

Hilfreich sind betroffene Version und Plattform, Schritte zum Nachstellen und die
mögliche Auswirkung. Eine erste Antwort kommt in der Regel innerhalb einer Woche.

## Downloads prüfen

Jedes Release enthält `SHA256SUMS.txt`. Im Download-Ordner:

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing
```

Ab v0.6.1 gibt es zusätzlich einen signierten Herkunftsnachweis (v0.6.0 und älter wurden
gebaut, bevor das Repository öffentlich war). Er belegt, dass die Datei von der CI dieses
Repositorys aus dem getaggten Stand gebaut wurde:

```bash
gh attestation verify Stingforge.exe --repo floppi77/stingforge
```

## Automatische Prüfungen

| Prüfung | Wann | Was |
|---|---|---|
| Gitleaks | jeder Push und PR, wöchentlich | Geheimnisse in der gesamten Git-Historie |
| Bandit | jeder Push und PR, wöchentlich | Sicherheitsanalyse der Python-Werkzeuge |
| zizmor | jeder Push und PR, wöchentlich | Sicherheit der GitHub-Workflows |
| Regression | Push und PR auf `main` | alle Prüfsuiten des Spiels headless mit Godot |
| CodeQL | Push und PR auf `main`, wöchentlich | Quellcode-Analyse (Python, Workflows) |
| OpenSSF Scorecard | Push auf `main`, wöchentlich | Projektverwaltung und Lieferkette |
| Secret Scanning | laufend, mit Push-Schutz | blockiert Pushes mit erkannten Zugangsdaten |
| Dependabot | laufend | Updates und Warnungen für Actions und Prüfwerkzeuge |
| Release-Build | jedes Tag `v*` | Build in der CI, Prüfsummen, Herkunftsnachweis, optional VirusTotal |

Alle Actions sind auf Commit-SHAs gepinnt, Python-Prüfwerkzeuge per Hash
(`.github/requirements`), heruntergeladene Werkzeuge (Godot, Gitleaks) werden gegen die
veröffentlichten Prüfsummen geprüft, und jeder Job bekommt nur die Rechte, die er braucht.

Veröffentlichte Releases sind unveränderlich: Dateien und Tag lassen sich danach nicht mehr
austauschen. `main` ist gegen Force-Pushes und Löschen geschützt.

---

# Security (English)

## Supported versions

Security fixes are provided for the latest release only.

## Reporting a vulnerability

Please do not open public issues for security problems. Instead:

- create a private report on GitHub under **Security › Report a vulnerability**, or
- contact the maintainer [@floppi77](https://github.com/floppi77) directly on GitHub.

Helpful details are the affected version and platform, steps to reproduce and the possible
impact. You will usually get a first answer within a week.

## Verifying downloads

Every release contains `SHA256SUMS.txt`. In the download folder:

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing
```

From v0.6.1 on, releases additionally come with a signed build provenance attestation (v0.6.0
and older were built before the repository went public). It proves that the file was built by
this repository's CI from the tagged source:

```bash
gh attestation verify Stingforge.exe --repo floppi77/stingforge
```

## Automated checks

| Check | When | What |
|---|---|---|
| Gitleaks | every push and PR, weekly | secrets in the entire Git history |
| Bandit | every push and PR, weekly | security analysis of the Python tools |
| zizmor | every push and PR, weekly | security of the GitHub workflows |
| Regression | push and PR on `main` | all of the game's test suites, headless with Godot |
| CodeQL | push and PR on `main`, weekly | source code analysis (Python, workflows) |
| OpenSSF Scorecard | push on `main`, weekly | project governance and supply chain |
| Secret scanning | continuously, with push protection | blocks pushes containing detected credentials |
| Dependabot | continuously | updates and alerts for actions and check tools |
| Release build | every `v*` tag | CI build, checksums, provenance, optional VirusTotal |

All actions are pinned to commit SHAs, the Python check tools by hash
(`.github/requirements`), downloaded tools (Godot, Gitleaks) are verified against their
published checksums, and every job only gets the permissions it needs.

Published releases are immutable: their files and tag cannot be replaced afterwards. `main` is
protected against force pushes and deletion.
