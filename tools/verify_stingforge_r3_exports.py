#!/usr/bin/env python3
"""R3: exportiert Linux und Windows aus den abgenommenen Quellen und prüft die Dateien.

Voraussetzung ist ein grüner Lauf von tools/verify_stingforge_r3.py. Der Export nutzt
die projektinternen Godot-Ordner (.godot_data/.godot_config/.godot_cache), die
Startproben laufen mit isolierten Testdaten und berühren keine Nutzersaves.
"""
from pathlib import Path
import hashlib
import importlib.util
import json
import os
import re
import subprocess

## Anzahl der Regressionssuiten (R2-Bestand + R3/R4 + R5 Musik/Gameplay + R6).
SUITE_COUNT = 41

ROOT = Path(__file__).resolve().parents[1]
LOGS = ROOT / 'build/logs/stingforge-r3'
DATA = ROOT / 'build/r3-testdata/binaries'
BINARIES = {'linux': ROOT / 'build/linux/Stingforge.x86_64', 'windows': ROOT / 'build/windows/Stingforge.exe'}
PRESETS = {'linux': 'Linux', 'windows': 'Windows'}
# Neue R3-Skripte müssen tatsächlich im eingebetteten Paket landen.
PACKED = ['level_progress.gdc', 'ui_veil.gdc', 'ui_run_status.gdc', 'hud.gdc', 'director.gdc', 'app.gdc',
          'side_shade.gdc', 'weak_point_marker.gdc', 'Jersey10-Regular.ttf', 'hero_px.png', 'logo_px.png', 'panel.png']


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def errors_in(text):
    return [line for line in text.splitlines() if any(word in line for word in
            ('SCRIPT ERROR:', 'Parse Error:', 'Compile Error:'))
            or (line.startswith('ERROR:') and not re.match(r'ERROR: \d+ resources still in use at exit', line))]


def run(name, command, env, timeout):
    log = LOGS / (name + '.log')
    with log.open('w') as stream:
        code = subprocess.run(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT,
                              timeout=timeout).returncode
    text = log.read_text(errors='replace')
    errors = errors_in(text)
    print(name, 'exit=', code, 'errors=', len(errors), flush=True)
    assert code == 0 and not errors, (name, code, errors[:5], str(log))
    return text


def main():
    spec = importlib.util.spec_from_file_location('r2', ROOT / 'tools/verify_stingforge_r2.py')
    r2 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(r2)
    summary = json.loads((LOGS / 'summary.json').read_text())
    assert summary['stable_sources'] and all(row['passed'] for row in summary['results']), 'Regression nicht grün'
    assert len(summary['results']) == SUITE_COUNT, 'Unvollständiger Regressionslauf'
    tested = r2.production_manifest()
    godot_env = dict(os.environ, XDG_DATA_HOME=str(ROOT / '.godot_data'),
                     XDG_CONFIG_HOME=str(ROOT / '.godot_config'), XDG_CACHE_HOME=str(ROOT / '.godot_cache'))
    for platform, preset in PRESETS.items():
        BINARIES[platform].parent.mkdir(parents=True, exist_ok=True)
        text = run('export-' + platform, ['godot', '--headless', '--verbose', '--path', str(ROOT),
                   '--export-release', preset, str(BINARIES[platform].relative_to(ROOT))], godot_env, 600)
        for name in PACKED:
            assert any('savepack' in line and name in line for line in text.splitlines()), 'Nicht verpackt: ' + name
        assert not any('res://Astra' in line and 'savepack' in line for line in text.splitlines()), 'Astra verpackt'
    starts = []
    DATA.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, XDG_DATA_HOME=str(DATA / 'data'), XDG_CONFIG_HOME=str(DATA / 'config'),
               XDG_CACHE_HOME=str(DATA / 'cache'))
    for platform, path in BINARIES.items():
        with path.open('rb') as stream:
            stream.seek(-4, 2)
            assert stream.read() == b'GDPC', 'Kein eingebetteter PCK: ' + platform
        assert not path.with_suffix('.pck').exists(), 'Unerwarteter PCK-Begleiter'
    # Ohne Fenster starten: kein Fenster über anderen Anwendungen des Nutzers.
    run('binary-linux', [str(BINARIES['linux']), '--headless', '--audio-driver', 'Dummy', '--quit-after', '240'],
        env, 120)
    run('binary-windows', ['wine', str(BINARIES['windows']), '--headless', '--audio-driver', 'Dummy',
                           '--quit-after', '180'],
        dict(env, WINEPREFIX=str(ROOT / 'build/windows/.wineprefix'), WINEDEBUG='-all'), 180)
    for platform, path in BINARIES.items():
        starts.append({'platform': platform, 'bytes': path.stat().st_size, 'sha256': digest(path),
                       'embedded_pck': True, 'start_ok': True, 'native': platform == 'linux'})
    assert r2.production_manifest() == tested, 'Quellen während des Exports geändert'
    (LOGS / 'binaries-summary.json').write_text(json.dumps(starts, indent=2) + '\n')
    print('STINGFORGE_R3_EXPORTS_OK', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
