#!/usr/bin/env python3
"""Veröffentlicht ausschließlich den getesteten R2-Stand; archiviert R1 vollständig."""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import importlib.util
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT/'release'
ARCHIVE = ROOT/'build/stingforge-r2-previous-release'
spec = importlib.util.spec_from_file_location('r2_verifier', ROOT/'tools/verify_stingforge_r2.py')
r2 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r2)
LOGS = r2.LOGS


def main():
    assert RELEASE.resolve() == ROOT/'release'
    assert ARCHIVE.resolve() == ROOT/'build/stingforge-r2-previous-release'
    results = json.loads((LOGS/'summary.json').read_text())
    assert len(results) == 34 and all(row['passed'] for row in results)
    sources = json.loads((LOGS/'tested-sources.json').read_text())
    assert sources['stable'] and sources['files'] == r2.production_manifest()
    assert r2.source_guard()
    starts = json.loads((LOGS/'binaries-summary.json').read_text())
    assert {row['platform'] for row in starts} == {'linux', 'windows'}
    binaries = {row['platform']: ROOT/('build/linux/Stingforge.x86_64' if row['platform'] == 'linux' else 'build/windows/Stingforge.exe') for row in starts}
    for row in starts:
        assert row['exit'] == 0 and r2.digest(binaries[row['platform']]) == row['sha256']
    old_hashes = {name: r2.digest(ROOT/'build/stingforge-round2-baseline/release'/name)
                  for name in ('Stingforge.exe', 'Stingforge.x86_64')}
    if not ARCHIVE.exists():
        for name, wanted in old_hashes.items():
            assert r2.digest(RELEASE/name) == wanted, 'Unbekannte alte Auslieferung'
        assert not any(path.is_symlink() for path in RELEASE.rglob('*')), 'Ungeprüfter Archiv-Symlink'
        size = sum(path.stat().st_size for path in RELEASE.rglob('*') if path.is_file())
        assert shutil.disk_usage(ROOT).free > size + sum(path.stat().st_size for path in binaries.values()) + 50*1024**2
        shutil.copytree(RELEASE, ARCHIVE)
    for name, wanted in old_hashes.items():
        assert r2.digest(ARCHIVE/name) == wanted, 'R1-Archiv verändert'
    packaged = []
    for row in starts:
        source = binaries[row['platform']]
        destination = RELEASE/source.name
        if destination.exists():
            assert r2.digest(destination) in (old_hashes[source.name], row['sha256']), 'Unbekannter Zielstand'
        shutil.copy2(source, destination)
        assert r2.digest(destination) == row['sha256']
        packaged.append({'file': destination.name, 'bytes': destination.stat().st_size, 'sha256': row['sha256']})
    images = RELEASE/'screenshots/stingforge-r2'
    images.mkdir(parents=True, exist_ok=True)
    shots = []
    for folder in ('build/stingforge-r2-hud', 'build/stingforge-r2-parallax',
                   'build/stingforge-r2-frontend', 'build/stingforge-r2-testdata-player'):
        shots.extend((ROOT/folder).glob('*.png'))
    shots.extend((ROOT/'build').glob('stingforge-r2-world-visual-*.png'))
    mapping = {}
    for source in shots:
        destination = images/source.name
        if source.name in mapping:
            assert r2.digest(source) == r2.digest(mapping[source.name]), 'Bildnamenskollision'
        mapping[source.name] = source
        shutil.copy2(source, destination)
        assert r2.digest(source) == r2.digest(destination)
    verification = RELEASE/'verification'
    verification.mkdir(exist_ok=True)
    for source in LOGS.glob('*.json'):
        shutil.copy2(source, verification/source.name)
    for source in LOGS.glob('*.log'):
        shutil.copy2(source, verification/source.name)
    shutil.copy2(ROOT/'build/stingforge-r2-hud/independent-pixel-report.json', verification/'independent-pixel-report.json')
    docs = ['STINGFORGE_R2.md', 'TESTPROTOKOLL_R2.md', 'STINGFORGE_R2_PLAYER.md',
            'STINGFORGE_R2_PARALLAX.md', 'STINGFORGE_R2_WORLD.md', 'STINGFORGE_R2_HUD.md',
            'STINGFORGE_R2_FINAL.md', 'STINGFORGE_R2_SCORES.md', 'STINGFORGE_R2_REGRESSION.md',
            'HANDBUCH.md', 'BUILD.md']
    for name in docs:
        text = (ROOT/'docs'/name).read_text()
        for basename, source in mapping.items():
            target = 'screenshots/stingforge-r2/'+basename
            text = text.replace(str(source), target)
            text = text.replace('../'+str(source.relative_to(ROOT)), target)
        text = text.replace('../build/logs/stingforge-r2/', 'verification/')
        text = text.replace('../build/stingforge-r2-hud/independent-pixel-report.json', 'verification/independent-pixel-report.json')
        text = text.replace('<../release/', '<')
        (RELEASE/name).write_text(text)
    (RELEASE/'README.md').write_text('''# Stingforge R2

**Evolve. Adapt. Strike.**

[Windows](<Stingforge.exe>) · [Linux](<Stingforge.x86_64>)

Jeweils eine vollständige Spieldatei, keine Installation und kein zusätzliches PCK nötig. Unter Linux gegebenenfalls „Als Programm ausführen“ erlauben.

R2: acht Tiefenebenen und reparierter Vordergrund, kompakter HUD mit Levelanzeige, Taktikkäufe pro Level auf0, exakt1/2/3 gekaufte Schildladungen samt Pentagrammen, größerer Orbit, stärkere überwindbare Gravitation, vier Glas-Warnpulse und kurze Trefferpartikel. Leveldruck/Bossleben steigen. Schwierigkeit nur beim Runstart. Neue lokale Highscores und eine stärkere wiedergeborene Endbossform mit drei eigenen Phasen.

Werkstatt und Evolutionen bleiben beim Levelreset erhalten; die kostenlose Basiswaffe bleibt verfügbar. Vorhandene Spielstände werden übernommen. Frühere Levelbestwerte bleiben; alte Run-Gesamtpunkte werden nicht erfunden.

**34/34 Start-/Regressionssuiten erfolgreich.** Neun echte HUD-Feldvergleiche exakt0 abweichende Pixel. Linux nativ gestartet; Windows unter Wine, nicht nativ auf Windows und ohne Windows-Grafikbenchmark. Kein physisches Xbox-Gamepad verfügbar. Bekannte Audio-Cleanupmeldungen kurzer Testprozesse sind dokumentiert.

[Änderungen](<STINGFORGE_R2.md>) · [Prüfprotokoll](<TESTPROTOKOLL_R2.md>) · [Handbuch](<HANDBUCH.md>) · [Prüfsummen](<SHA256SUMS.txt>)

Die alte Auslieferung ist im Projekt archiviert. Vor einem Rückwechsel auf R1 den Spielstandordner sichern: R1 kennt neue Highscore-Profilfelder noch nicht. Persönliche Spielstände wurden während der Entwicklung nicht angefasst.
''')
    sums = ''.join(row['sha256']+'  '+row['file']+'\n' for row in packaged)
    (RELEASE/'SHA256SUMS.txt').write_text(sums)
    (ROOT/'build/SHA256SUMS-R2.txt').write_text(sums)
    report = {'files': packaged, 'suites_passed': len(results), 'source_manifest_unchanged': True,
              'previous_release_preserved': str(ARCHIVE.relative_to(ROOT)), 'screenshots': len(mapping),
              'published_at': datetime.now(ZoneInfo('Europe/Berlin')).isoformat(timespec='seconds')}
    (LOGS/'package-summary.json').write_text(json.dumps(report, indent=2)+'\n')
    (verification/'package-summary.json').write_text(json.dumps(report, indent=2)+'\n')
    for row in packaged:
        print(row['file'], row['bytes'], row['sha256'], flush=True)
    print('STINGFORGE_R2_RELEASE_OK', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
