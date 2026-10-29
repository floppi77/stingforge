#!/usr/bin/env python3
"""Veröffentlicht den getesteten R3-Stand nach release/; archiviert vorher die R2-Dateien."""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib
import json
import shutil

## Anzahl der Regressionssuiten (R2-Bestand + R3/R4 + R5 Musik/Gameplay + R6 + R7 + R8 + R9).
SUITE_COUNT = 46

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / 'release'
ARCHIVE = ROOT / 'build/stingforge-r4-previous-release'
LOGS = ROOT / 'build/logs/stingforge-r3'
BINARIES = {'linux': ROOT / 'build/linux/Stingforge.x86_64', 'windows': ROOT / 'build/windows/Stingforge.exe',
            'macos': ROOT / 'build/macos/Stingforge-macOS.zip'}


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    summary = json.loads((LOGS / 'summary.json').read_text())
    assert summary['stable_sources'] and len(summary['results']) == SUITE_COUNT
    assert all(row['passed'] for row in summary['results'])
    starts = {row['platform']: row for row in json.loads((LOGS / 'binaries-summary.json').read_text())}
    assert set(starts) == set(BINARIES)
    for platform, path in BINARIES.items():
        assert digest(path) == starts[platform]['sha256'], 'Export nach Prüfung verändert: ' + platform
    # Bisherige Auslieferung einmalig sichern (nur Spieldateien und Prüfsummen).
    if not ARCHIVE.exists():
        ARCHIVE.mkdir(parents=True)
        for name in ('Stingforge.x86_64', 'Stingforge.exe', 'SHA256SUMS.txt', 'README.md'):
            shutil.copy2(RELEASE / name, ARCHIVE / name)
    packaged = []
    for platform, source in BINARIES.items():
        destination = RELEASE / source.name
        shutil.copy2(source, destination)
        assert digest(destination) == starts[platform]['sha256']
        packaged.append({'file': destination.name, 'bytes': destination.stat().st_size,
                         'sha256': starts[platform]['sha256']})
    images = RELEASE / 'screenshots/stingforge-r4'
    images.mkdir(parents=True, exist_ok=True)
    # 12_story zeigt noch den behobenen Doppeltext und wird nicht ausgeliefert.
    shots = sorted((ROOT / 'build/r4-shots').glob('*.png')) + sorted((ROOT / 'build/r4-uw').glob('*.png'))
    for source in shots:
        prefix = 'ultrawide_' if source.parent.name == 'r4-uw' else ''
        shutil.copy2(source, images / (prefix + source.name))
    verification = RELEASE / 'verification/r3'
    verification.mkdir(parents=True, exist_ok=True)
    for source in list(LOGS.glob('*.json')) + [ROOT / 'build/logs/r3/pause-red.log',
                                               ROOT / 'build/logs/stingforge-r3/r3_pause_probe.log',
                                               ROOT / 'build/logs/r3/r4-miniboss-red.log',
                                               ROOT / 'build/logs/stingforge-r3/r4_miniboss_probe.log']:
        shutil.copy2(source, verification / source.name)
    for name in ('STINGFORGE_R4.md', 'STINGFORGE_R3.md', 'HANDBUCH.md'):
        text = (ROOT / 'docs' / name).read_text()
        text = text.replace('../build/logs/stingforge-r3/', 'verification/r3/')
        text = text.replace('../build/logs/r3/', 'verification/r3/')
        (RELEASE / name).write_text(text)
    (RELEASE / 'README.md').write_text('''# Stingforge R4

**Evolve. Adapt. Strike.** – eine Pixel-Hommage an Apidya.

[Windows](<Stingforge.exe>) · [Linux](<Stingforge.x86_64>) · [macOS](<Stingforge-macOS.zip>)

Windows und Linux: jeweils eine vollständige Spieldatei, keine Installation und kein
zusätzliches PCK nötig. Unter Linux gegebenenfalls „Als Programm ausführen“ erlauben.

macOS (Intel und Apple Silicon, ab macOS 11 bzw. 10.12): ZIP entpacken und Stingforge.app
in „Programme“ ziehen. Die App ist nur ad-hoc signiert, nicht von Apple notarisiert. Beim
ersten Start daher im Finder Rechtsklick › „Öffnen“, oder unter Systemeinstellungen ›
Datenschutz & Sicherheit „Dennoch öffnen“. Meldet macOS „beschädigt“, entfernt dieser
Befehl im Terminal nur die Download-Sperre:
`xattr -dr com.apple.quarantine /Applications/Stingforge.app`.

R4: Neuer Pixellook in 1920 × 1080 mit Ultrawide-Unterstützung (21:9, 32:9: das
Spielfeld bleibt 16:9, die Ränder zeigen die Levelkulisse). Pixel-Titelbild und
-Logo, Pixelschriften, neu gestaltete Menüs, flacheres HUD mit mehr Spielfeld,
neu gezeichnete Bosse. Der Zwischengegner bleibt jetzt in jedem Level, bis er
besiegt ist. Spielstände werden übernommen.

Neu in dieser Fassung:
- Tutorial (Übungsflug) mit Erklärfenstern, Verschmelzungen von Evolutionen.
- Neue Bossmusik je Level, nahtlos an die Levelmusik anschließend, im Kampf geloopt.
- Ein eigener, durchkomponierter Soundtrack je Level, exakt bis zum Bosseinsatz.
- Dreispaltige Werkstatt mit animierten Erklärgrafiken.
- Upgrade-Ansage per Sprache (neue, hellere Stimme mit Qwen3-TTS).
- Erstmals eine macOS-Fassung.
- Spannenderer Larven-Boss mit drei Phasen und Bossphasen mit Auftritt.
- Zerbrechliches Glas in Level 6.
- Höhere Fontänen in Level 3.
- Maßvollere Zielsuche.

**{SUITE_COUNT}/{SUITE_COUNT} Regressionssuiten erfolgreich.** Linux-Datei gestartet, Windows-Datei unter
Wine (nicht nativ auf Windows). Die macOS-App ist auf Aufbau, Architekturen und Signatur geprüft,
aber mangels Mac nicht gestartet. Kein physisches Xbox-Gamepad verfügbar.

[Änderungen](<STINGFORGE_R4.md>) · [Handbuch](<HANDBUCH.md>) · [Prüfsummen](<SHA256SUMS.txt>) ·
[Bilder](<screenshots/stingforge-r4/>) · [Vorgänger R3](<STINGFORGE_R3.md>)
'''.replace('{SUITE_COUNT}', str(SUITE_COUNT)))
    sums = ''.join(row['sha256'] + '  ' + row['file'] + '\n' for row in packaged)
    (RELEASE / 'SHA256SUMS.txt').write_text(sums)
    (ROOT / 'build/SHA256SUMS-R4.txt').write_text(sums)
    report = {'files': packaged, 'suites_passed': len(summary['results']), 'screenshots': len(shots),
              'previous_release_preserved': str(ARCHIVE.relative_to(ROOT)),
              'published_at': datetime.now(ZoneInfo('Europe/Berlin')).isoformat(timespec='seconds')}
    (LOGS / 'package-summary.json').write_text(json.dumps(report, indent=2) + '\n')
    (verification / 'package-summary.json').write_text(json.dumps(report, indent=2) + '\n')
    for row in packaged:
        print(row['file'], row['bytes'], row['sha256'], flush=True)
    print('STINGFORGE_R4_RELEASE_OK', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
