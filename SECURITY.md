# Sicherheit

*Deutsch zuerst · [English below](#security-english)*

## Unterstützte Versionen

Sicherheitskorrekturen gibt es nur für das jeweils neueste Release.

## Schwachstelle melden

Bitte keine öffentlichen Issues für Sicherheitsprobleme. Stattdessen:

- auf GitHub unter **Security › Report a vulnerability** eine private Meldung anlegen
  (verfügbar, sobald das Repository öffentlich ist), oder
- den Maintainer [@floppi77](https://github.com/floppi77) direkt über GitHub kontaktieren.

Hilfreich sind betroffene Version und Plattform, Schritte zum Nachstellen und die
mögliche Auswirkung. Eine erste Antwort kommt in der Regel innerhalb einer Woche.

## Downloads prüfen

Jedes Release enthält `SHA256SUMS.txt`. Im Download-Ordner:

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing
```

Für öffentliche Releases gibt es zusätzlich einen signierten Herkunftsnachweis. Er belegt,
dass die Datei von der CI dieses Repositorys aus dem getaggten Stand gebaut wurde:

```bash
gh attestation verify Stingforge.exe --repo floppi77/stingforge
```

## Automatische Prüfungen

| Prüfung | Wann | Was |
|---|---|---|
| Gitleaks | jeder Push und PR, wöchentlich | Geheimnisse in der gesamten Git-Historie |
| Bandit | jeder Push und PR, wöchentlich | Sicherheitsanalyse der Python-Werkzeuge |
| zizmor | jeder Push und PR, wöchentlich | Sicherheit der GitHub-Workflows |
| CodeQL | Push und PR auf `main`, wöchentlich | Quellcode-Analyse (Python, Workflows), sobald öffentlich |
| OpenSSF Scorecard | Push auf `main`, wöchentlich | Projektverwaltung und Lieferkette, sobald öffentlich |
| Dependabot | laufend | Updates und Warnungen für die gepinnten GitHub Actions |
| Release-Build | jedes Tag `v*` | Build in der CI, Prüfsummen, Herkunftsnachweis, optional VirusTotal |

Alle Actions sind auf Commit-SHAs gepinnt, heruntergeladene Werkzeuge (Godot, Gitleaks)
werden gegen die veröffentlichten Prüfsummen geprüft, und jeder Job bekommt nur die
Rechte, die er braucht.

---

# Security (English)

## Supported versions

Security fixes are provided for the latest release only.

## Reporting a vulnerability

Please do not open public issues for security problems. Instead:

- create a private report on GitHub under **Security › Report a vulnerability**
  (available once the repository is public), or
- contact the maintainer [@floppi77](https://github.com/floppi77) directly on GitHub.

Helpful details are the affected version and platform, steps to reproduce and the possible
impact. You will usually get a first answer within a week.

## Verifying downloads

Every release contains `SHA256SUMS.txt`. In the download folder:

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing
```

Public releases additionally come with a signed build provenance attestation proving that
the file was built by this repository's CI from the tagged source:

```bash
gh attestation verify Stingforge.exe --repo floppi77/stingforge
```

## Automated checks

| Check | When | What |
|---|---|---|
| Gitleaks | every push and PR, weekly | secrets in the entire Git history |
| Bandit | every push and PR, weekly | security analysis of the Python tools |
| zizmor | every push and PR, weekly | security of the GitHub workflows |
| CodeQL | push and PR on `main`, weekly | source code analysis (Python, workflows), once public |
| OpenSSF Scorecard | push on `main`, weekly | project governance and supply chain, once public |
| Dependabot | continuously | updates and alerts for the pinned GitHub Actions |
| Release build | every `v*` tag | CI build, checksums, provenance, optional VirusTotal |

All actions are pinned to commit SHAs, downloaded tools (Godot, Gitleaks) are verified
against their published checksums, and every job only gets the permissions it needs.
