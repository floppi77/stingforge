#!/usr/bin/env python3
"""Veröffentlicht nur geprüfte Einzeldateien; vorherige Auslieferung bleibt gesichert."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT/'release'
ARCHIVE = ROOT/'build/stingforge-baseline/previous-release'
LOGS = ROOT/'build/logs/stingforge'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    results = json.loads((LOGS/'summary.json').read_text())
    assert len(results) == 24 and all(row['passed'] for row in results)
    branding = json.loads((LOGS/'branding-summary.json').read_text())
    assert len(branding) == 3 and all(row['passed'] and row['legacy_unchanged'] for row in branding)
    starts = json.loads((LOGS/'binaries-summary.json').read_text())
    binaries = {'linux': ROOT/'build/linux/Stingforge.x86_64',
                'windows': ROOT/'build/windows/Stingforge.exe'}
    for row in starts:
        assert row['exit'] == 0 and digest(binaries[row['platform']]) == row['sha256']
    assert len(starts) == 2
    earliest_export = min(p.stat().st_mtime for p in binaries.values())
    production = list((ROOT/'scripts').rglob('*.gd')) + [ROOT/'project.godot', ROOT/'export_presets.cfg',
        ROOT/'assets/sprites/bee.png', ROOT/'assets/ui/menu/stingforge.png']
    assert all(p.stat().st_mtime <= earliest_export for p in production), 'Quelländerung nach Export'
    RELEASE.mkdir(exist_ok=True)
    ARCHIVE.mkdir(parents=True,exist_ok=True)
    assert ARCHIVE.resolve().is_relative_to((ROOT/'build/stingforge-baseline').resolve())
    # Vorhandene Begleitdateien zuerst aufbewahren, nichts aus der Baseline ersetzen.
    for old in list(RELEASE.glob('*.md')) + list(RELEASE.glob('SHA256SUMS.txt')):
        backup = ARCHIVE/old.name
        if not backup.exists():
            shutil.copy2(old,backup)
    legacy = {'Apidya_Reimagined.x86_64':'2bd3fecfd7425a63ec41834e9d6a43ec01cfc8e54467f15666ebbad0d4b040a4',
              'Apidya_Reimagined.exe':'8290534ac8ec94186f6dcfa556194aee9437b078d079f8e0fc6b8cf21b773363'}
    for name,wanted in legacy.items():
        source, destination = RELEASE/name, ARCHIVE/name
        if source.exists():
            # Vor JEDEM Move die aufgelösten absoluten Endpunkte und Originalhash prüfen.
            assert source.resolve().parent == RELEASE.resolve() and source.name in legacy
            assert destination.resolve().parent == ARCHIVE.resolve() and not destination.exists()
            assert digest(source) == wanted
            print('Geprüfter Archiv-Move:',source.resolve(),'->',destination.resolve(),flush=True)
            shutil.move(str(source),str(destination))
    packaged = []
    for platform,source in binaries.items():
        destination = RELEASE/source.name
        if destination.exists():
            assert digest(destination) == digest(source), 'Unbekannter neuer Zielstand'
        shutil.copy2(source,destination)
        assert digest(source) == digest(destination)
        packaged.append({'file':destination.name,'bytes':destination.stat().st_size,'sha256':digest(destination)})
    images = ROOT/'docs/stingforge';images.mkdir(exist_ok=True)
    shots = ['low_hud.png','default_hud.png','high_hud.png','low_boss.png','default_boss.png',
             'high_boss.png','high_boss_notice.png','projectiles_bright.png','projectiles_dark.png','bee-flight.gif']
    for name in shots:
        shutil.copy2(ROOT/'build/stingforge-visual'/name,images/name)
    release_images = RELEASE/'screenshots/stingforge';release_images.mkdir(parents=True,exist_ok=True)
    for name in shots+['main_menu.png']:
        shutil.copy2(images/name,release_images/name)
    docs = ['BUILD.md','BERICHT.md','HANDBUCH.md','TESTPROTOKOLL.md','UI_REDESIGN.md',
            'STINGFORGE.md','STINGFORGE_ABILITIES.md','STINGFORGE_WORLD.md','STINGFORGE_VISUAL.md']
    for name in docs:
        text = (ROOT/'docs'/name).read_text()
        text = text.replace('<stingforge/','<screenshots/stingforge/')
        text = text.replace('<../release/','<')
        text = text.replace(str(ROOT/'build/stingforge-visual')+'/', 'screenshots/stingforge/')
        text = text.replace('(<ui-reference/','(<screenshots/ui-reference/')
        text = text.replace('(<ui-modern/','(<screenshots/ui-modern/')
        (RELEASE/name).write_text(text)
    (RELEASE/'README.md').write_text('''# Stingforge\n\n**Evolve. Adapt. Strike.**\n\n[Windows](<Stingforge.exe>) · [Linux](<Stingforge.x86_64>)\n\nAlle Spieldaten sind eingebettet, keine Installation nötig. Linux-Datei gegebenenfalls als ausführbar markieren.\n\nVorhandene Spielstände der früheren Version werden beim ersten Start kopiert, nicht verschoben. Bereits vorhandene Stingforge-Dateien werden nicht überschrieben.\n\nLeicht/Normal: 20 % weniger Gegnerprojektile; langsamere, faire Verfolger. Fähigkeiten, Boss-Trefferzonen und Schildaufladung korrigiert. Neues HUD und neue Biene.\n\n[Änderungen und Prüfungen](<STINGFORGE.md>) · [Handbuch](<HANDBUCH.md>) · [Prüfsummen](<SHA256SUMS.txt>)\n\n24/24 Prüfsuiten grün. Linux nativ gestartet; Windows unter Wine, nicht auf einem nativen Windows-PC geprüft. Kein physisches Xbox-Gamepad verfügbar.\n''')
    (RELEASE/'SHA256SUMS.txt').write_text(''.join(row['sha256']+'  '+row['file']+'\n' for row in packaged))
    (ROOT/'build/SHA256SUMS.txt').write_text(''.join(digest(path)+'  '+str(path.relative_to(ROOT/'build'))+'\n' for path in binaries.values()))
    (LOGS/'package-summary.json').write_text(json.dumps({'files':packaged,'suites_passed':len(results),
        'previous_release_preserved':str(ARCHIVE.relative_to(ROOT)),'screenshots':len(shots)+1},indent=2)+'\n')
    for row in packaged:
        print(row['file'],row['bytes'],'Bytes',row['sha256'],flush=True)
    print('STINGFORGE_RELEASE_OK',flush=True)
    return 0


if __name__=='__main__':
    raise SystemExit(main())
