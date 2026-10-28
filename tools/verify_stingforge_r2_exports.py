#!/usr/bin/env python3
"""R2: prüft eingebettete Ressourcen, echte Binärstarts, Bilder und aktive Spiellast."""
from pathlib import Path
import importlib.util
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('r2_verifier', ROOT/'tools/verify_stingforge_r2.py')
r2 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r2)
LOGS = r2.LOGS
DATA = ROOT/'build/stingforge-r2-testdata-binaries'


def run_logged(name, command, env, cwd=ROOT, marker=None, prefix=False, timeout=90):
    log = LOGS/(name+'.log')
    with log.open('w') as stream:
        run = subprocess.run(command, env=env, cwd=cwd, stdout=stream,
                             stderr=subprocess.STDOUT, timeout=timeout)
    text = log.read_text(errors='replace')
    errors = [line for line in text.splitlines() if any(word in line for word in
              ('SCRIPT ERROR:', 'Parse Error:', 'Compile Error:', 'Lambda capture'))
              or (line.startswith('ERROR:') and not re.match(r'ERROR: \d+ resources still in use at exit', line))]
    matched = marker is None or any(line == marker or (prefix and line.startswith(marker+' ')) for line in text.splitlines())
    passed = run.returncode == 0 and not errors and matched
    print(name, 'exit=', run.returncode, 'passed=', passed, flush=True)
    assert passed, (name, errors, run.returncode, str(log))
    return text


def isolated(env, role):
    base = ROOT/('build/stingforge-r2-testdata-'+role)
    return dict(env, XDG_DATA_HOME=str(base/'data'), XDG_CONFIG_HOME=str(base/'config'),
                XDG_CACHE_HOME=str(base/'cache'))


def main():
    DATA.mkdir(parents=True, exist_ok=True)
    results = json.loads((LOGS/'summary.json').read_text())
    assert len(results) == 34 and all(row['passed'] for row in results)
    tested = json.loads((LOGS/'tested-sources.json').read_text())
    assert tested['stable'] and tested['files'] == r2.production_manifest()
    assert r2.source_guard()
    binaries = {'linux': ROOT/'build/linux/Stingforge.x86_64',
                'windows': ROOT/'build/windows/Stingforge.exe'}
    earliest = min(path.stat().st_mtime for path in binaries.values())
    assert all((ROOT/name).stat().st_mtime <= earliest for name in tested['files']), 'Quelle nach Export geändert'
    packed = [f'l{level:02}_{role}.png' for level in range(1, 11) for role in ('haze', 'reeds', 'roots')]
    packed += [f'boss_reborn_p{phase}.png' for phase in (1, 2, 3)]
    packed += ['highscore_screen.gdc', 'shield_rings.gdc', 'boss_reborn_visual.gdc']
    for platform, path in binaries.items():
        with path.open('rb') as stream:
            stream.seek(-4, 2)
            assert stream.read() == b'GDPC', 'Kein eingebetteter PCK: '+platform
        assert not path.with_suffix('.pck').exists(), 'Unerwarteter PCK-Begleiter'
        export_log = (LOGS/('export-'+platform+'.log')).read_text()
        for name in packed:
            assert any('savepack' in line and name in line for line in export_log.splitlines()), 'Nicht verpackt: '+name
    env = dict(os.environ, XDG_DATA_HOME=str(DATA/'data'), XDG_CONFIG_HOME=str(DATA/'config'),
               XDG_CACHE_HOME=str(DATA/'cache'), GSETTINGS_BACKEND='memory',
               LIBGL_ALWAYS_SOFTWARE='1', GALLIUM_DRIVER='llvmpipe',
               XDG_RUNTIME_DIR='/run/user/1000', WAYLAND_DISPLAY='wayland-1')
    starts = []
    for platform, command, child_env in [
        ('linux', [str(binaries['linux']), '--display-driver', 'wayland', '--audio-driver', 'Dummy', '--quit-after', '90'], env),
        ('windows', ['wine', str(binaries['windows']), '--headless', '--audio-driver', 'Dummy', '--quit-after', '60'],
         dict(env, WINEPREFIX=str(ROOT/'build/windows/.wineprefix'), WINEDEBUG='-all')),
    ]:
        run_logged('binary-'+platform+'-final', command, child_env, DATA, timeout=90)
        starts.append({'platform': platform, 'exit': 0, 'native': platform == 'linux',
                       'windowed': platform == 'linux', 'sha256': r2.digest(binaries[platform]),
                       'bytes': binaries[platform].stat().st_size, 'new_resources_checked': len(packed)})
    run_logged('branding-final', ['python3', 'tools/verify_stingforge_branding.py'], env)
    branding = json.loads((ROOT/'build/logs/stingforge/branding-summary.json').read_text())
    assert len(branding) == 3 and all(row['passed'] and row['legacy_unchanged'] for row in branding)
    (LOGS/'branding-summary.json').write_text(json.dumps(branding, indent=2)+'\n')
    run_logged('art-final', ['python3', 'tests/stingforge_visual_checks.py', '--art-only'], env,
               marker='STINGFORGE_VISUAL_CHECKS_OK')
    run_logged('parallax-assets-final', ['python3', 'tests/stingforge_r2_parallax_assets.py'], env,
               marker='PARALLAX_ASSETS OK:', prefix=True)
    run_logged('parallax-properties-final', ['python3', 'tests/stingforge_r2_parallax_properties.py'], env,
               marker='PARALLAX_PROPERTIES_OK', prefix=True)
    run_logged('hud-render-final', ['python3', 'tests/stingforge_r2_hud_checks.py', '--screenshots'], env,
               marker='STINGFORGE_R2_HUD_OK', timeout=90)
    for role, marker in [('player', 'STINGFORGE_R2_PLAYER_VISUAL_OK'), ('world', 'STINGFORGE_R2_WORLD_VISUAL_OK')]:
        run_logged(role+'-render-final', ['godot', '--display-driver', 'wayland', '--audio-driver', 'Dummy',
                   '--path', str(ROOT), 'res://tests/stingforge_r2_'+role+'_visual.tscn'], isolated(env, role),
                   marker=marker, timeout=45)
    text = run_logged('performance-final', ['godot', '--display-driver', 'wayland', '--audio-driver', 'Dummy',
                      '--path', str(ROOT), 'res://tests/perf.tscn', '--', '--maxed', '--stress'],
                      isolated(env, 'perf'), marker='PERF_MESSUNG_OK', timeout=45)
    lines = [line for line in text.splitlines() if line.startswith('PERF ')]
    for line in lines:
        print(line, flush=True)
    assert tested['files'] == r2.production_manifest(), 'Quellen nach Abnahme geändert'
    (LOGS/'binaries-summary.json').write_text(json.dumps(starts, indent=2)+'\n')
    (LOGS/'performance-summary.json').write_text(json.dumps({'lines': lines,
        'renderer': 'llvmpipe / Software-OpenGL', 'native_windows_tested': False,
        'physical_xbox_tested': False, 'paused_or_frozen_frames': 0}, indent=2)+'\n')
    print('STINGFORGE_R2_EXPORTS_OK', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
