# Sicherheit

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
