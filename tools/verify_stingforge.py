#!/usr/bin/env python3
"""Stingforge-Gesamtregression: gezielte Änderungsgrenzen, isolierte echte Engineprozesse."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / 'build/stingforge-baseline'
LOGS = ROOT / 'build/logs/stingforge'
PERMITTED = {
    'scripts/autoload/app.gd', 'scripts/autoload/loc.gd', 'scripts/autoload/save.gd', 'scripts/autoload/data.gd',
    'scripts/core/ui_screen.gd', 'scripts/screens/main_menu.gd', 'scripts/screens/hud.gd',
    'scripts/game/player.gd', 'scripts/game/bullets.gd', 'scripts/game/shop_data.gd',
    'scripts/game/enemy.gd', 'scripts/game/boss.gd', 'scripts/game/game.gd',
}


def function_source(text, name):
    match = re.search(r'^func ' + re.escape(name) + r'\(.*?(?=^(?:func|static func|var|const|signal|enum) |\Z)', text, re.M | re.S)
    if not match:
        raise ValueError('Funktion fehlt: ' + name)
    return '\n'.join(line for line in match[0].splitlines() if line.strip() and not line.strip().startswith('#'))


def source_guard():
    manifest = json.loads((BASELINE/'SHA256.json').read_text())
    violations = []
    unchanged = 0
    for path, digest in manifest.items():
        if not path.startswith('scripts/'):
            continue
        file = ROOT/path
        if file.is_file() and hashlib.sha256(file.read_bytes()).hexdigest() == digest:
            unchanged += 1
        elif path not in PERMITTED:
            violations.append(path)
    # Die App-Flows bleiben unverändert; Save erhält nur den Start-Migrationsschritt.
    for path, permitted_functions in [('scripts/autoload/app.gd', set()),
                                       ('scripts/autoload/save.gd', {'_ready'}),
                                       ('scripts/core/ui_screen.gd', {'_build_base'}),
                                       ('scripts/screens/main_menu.gd', set())]:
        old, new = (BASELINE/path).read_text(), (ROOT/path).read_text()
        for name in re.findall(r'^func (\w+)\(', old, re.M):
            if name not in permitted_functions and function_source(old, name) != function_source(new, name):
                violations.append(path + ':' + name)
    # Designdaten ändern nur präzisierte Beschreibungen, nicht etwa heimlich
    # Schwierigkeitstabellen, Shopwährung oder die 36 Evolutionseffekte.
    old_data = (BASELINE/'scripts/autoload/data.gd').read_text()
    new_data = (ROOT/'scripts/autoload/data.gd').read_text()
    descriptions = r'"desc": "(?:\\.|[^"\\])*"'
    if re.sub(descriptions, '"desc": "<Beschreibung>"', old_data) != re.sub(descriptions, '"desc": "<Beschreibung>"', new_data):
        violations.append('scripts/autoload/data.gd: unerwartete Änderung außerhalb Beschreibungen')
    for path in ['assets/ui/menu/hero.png', 'assets/sprites/manifest.json']:
        wanted = 'f7ed53f07903d81e3d428a56add3e12f4e082ce82fe4f57388156ff3e46c58a8' if path.endswith('hero.png') else manifest[path]
        if hashlib.sha256((ROOT/path).read_bytes()).hexdigest() != wanted:
            violations.append(path)
    if hashlib.sha256((ROOT/'assets/ui/menu/stingforge.png').read_bytes()).hexdigest() != '5cc4265e5d96055c4e822f6f2153c7f1b7b8ac6bdf01da1088535ecbc31a1a8e':
        violations.append('Nutzerlogo nicht bytegleich')
    print('STINGFORGE_QUELLSCHUTZ', 'OK' if not violations else violations,
          f'({unchanged} unveränderte Skript-/UID-Dateien, Menü-/Speicher-/Kampagnenrouten geschützt)', flush=True)
    return not violations


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--only', nargs='+', default=[])
    parser.add_argument('--guard-only', action='store_true')
    args = parser.parse_args()
    LOGS.mkdir(parents=True, exist_ok=True)
    good = source_guard()
    if args.guard_only:
        return 0 if good else 1
    spec = importlib.util.spec_from_file_location('ui_previous', ROOT/'tools/verify_ui_redesign.py')
    previous = importlib.util.module_from_spec(spec); spec.loader.exec_module(previous)
    suites = dict(previous.SUITES)
    suites.update({'campaign': 'CAMPAIGN_OK'})
    # Neue selbstständige Probes melden ihren exakten Endmarker hier; weitere
    # werden nach ihrem abgeschlossenen Rot/Grün-Nachweis ergänzt.
    extra = {
        'stingforge_weapons_probe': 'STINGFORGE_WEAPONS_OK',
        'stingforge_world_density': 'STINGFORGE_WORLD_DENSITY_OK',
        'stingforge_world_motion': 'STINGFORGE_WORLD_MOTION_OK',
        'stingforge_world_boss': 'STINGFORGE_WORLD_BOSS_OK',
        'stingforge_world_synergy': 'STINGFORGE_WORLD_SYNERGY_OK',
        'stingforge_weapons_matrix': 'STINGFORGE_WEAPONS_MATRIX_OK',
        'stingforge_visual_probe': 'STINGFORGE_VISUAL_OK',
    }
    suites.update({k: v for k, v in extra.items() if (ROOT/f'tests/{k}.tscn').exists()})
    if args.only:
        missing = set(args.only) - set(suites)
        assert not missing, missing
        suites = {k:v for k,v in suites.items() if k in args.only}
    results = []
    run_id = str(time.time_ns())
    for suite, marker in suites.items():
        base = ROOT/'build/stingforge-testdata-regression'/run_id/suite
        if suite == 'main_menu_reference_probe':
            base = ROOT/'build/reference-menu-testdata'/run_id
        if suite.startswith('stingforge_weapons'):
            base = ROOT/'build/stingforge-testdata-weapons'/run_id
        if suite.startswith('stingforge_world'):
            base = ROOT/'build/stingforge-testdata-world'/run_id/suite
        if suite.startswith('stingforge_visual'):
            base = ROOT/'build/stingforge-testdata-visual'/run_id
        base.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, XDG_DATA_HOME=str(base/'data'), XDG_CONFIG_HOME=str(base/'config'),
                   XDG_CACHE_HOME=str(base/'cache'))
        started = time.monotonic()
        try:
            run = subprocess.run(['godot','--headless','--audio-driver','Dummy','--path',str(ROOT),
                                  f'res://tests/{suite}.tscn'], cwd=ROOT, env=env,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
            text, code = run.stdout, run.returncode
        except subprocess.TimeoutExpired as exc:
            text = exc.stdout.decode(errors='replace') if isinstance(exc.stdout, bytes) else (exc.stdout or '')
            text += '\nPROCESS_TIMEOUT\n'; code = 124
        (LOGS/f'{suite}.log').write_text(text)
        errors = [line for line in text.splitlines() if any(x in line for x in ['SCRIPT ERROR:','Parse Error:', 'Compile Error:'])]
        passed = code == 0 and marker in text.splitlines() and not errors
        results.append({'suite': suite, 'exit': code, 'passed': passed, 'errors': errors,
                        'seconds': round(time.monotonic()-started, 2)})
        good = good and passed
        print(f'{suite}: {"OK" if passed else "FEHLER"} exit={code} {results[-1]["seconds"]}s', flush=True)
    name = 'summary' if not args.only else 'summary-' + '-'.join(args.only)
    (LOGS/(name+'.json')).write_text(json.dumps(results, indent=2)+'\n')
    print('STINGFORGE_REGRESSION_OK' if good else 'STINGFORGE_REGRESSION_FAILED', flush=True)
    return 0 if good else 1


if __name__ == '__main__':
    raise SystemExit(main())
