#!/usr/bin/env python3
"""R3: alle bisherigen Regressionssuiten plus Pause-/Laufzeitprüfung, nacheinander.

Der R2-Quellwächter (eingefrorene Quellen) entfällt bewusst: R3 ändert Pause,
HUD und Menüs. Stattdessen muss jede Suite grün sein und die Quellen dürfen sich
während des Laufs nicht ändern.
"""
from pathlib import Path
import argparse
import importlib.util
import json
import os
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
LOGS = ROOT / 'build/logs/stingforge-r3'
R3 = {'r3_pause_probe': 'R3_PAUSE_OK', 'r4_miniboss_probe': 'R4_MINIBOSS_OK', 'r4_ui_probe': 'R4_UI_OK',
      'r4_boss_probe': 'R4_BOSS_OK', 'r5_music_probe': 'R5_MUSIC_OK', 'r5_gameplay_probe': 'R5_GAME_OK', 'r6_probe': 'R6_OK', 'r7_probe': 'R7_OK', 'r8_probe': 'R8_OK'}


def load_r2():
    spec = importlib.util.spec_from_file_location('r2', ROOT / 'tools/verify_stingforge_r2.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_suite(r2, suite, marker, run_id, attempt):
    base = ROOT / 'build/r3-testdata' / run_id / f'{suite}-{attempt}'
    if suite in r2.R2:
        # Einige R2-Suiten prüfen den Namen ihres isolierten Datenordners.
        base = ROOT / ('build/stingforge-r2-testdata-' + r2.R2[suite][1])
    elif suite == 'main_menu_reference_probe':
        base = ROOT / 'build/reference-menu-testdata' / f'{run_id}-{attempt}'
    elif suite.startswith('stingforge_weapons'):
        base = ROOT / 'build/stingforge-testdata-weapons' / f'{run_id}-{attempt}'
    elif suite.startswith('stingforge_visual'):
        base = ROOT / 'build/stingforge-testdata-visual' / f'{run_id}-{attempt}'
    base.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, XDG_DATA_HOME=str(base / 'data'), XDG_CONFIG_HOME=str(base / 'config'),
               XDG_CACHE_HOME=str(base / 'cache'))
    started = time.monotonic()
    log = LOGS / (suite + ('' if attempt == 0 else f'-versuch{attempt + 1}') + '.log')
    with log.open('w') as stream:
        try:
            code = subprocess.run(['godot', '--headless', '--audio-driver', 'Dummy', '--path', str(ROOT),
                                   f'res://tests/{suite}.tscn'], cwd=ROOT, env=env, stdout=stream,
                                  stderr=subprocess.STDOUT, timeout=240).returncode
        except subprocess.TimeoutExpired:
            code = 124
    text = log.read_text(errors='replace')
    errors = [line for line in text.splitlines() if any(word in line for word in
              ('SCRIPT ERROR:', 'Parse Error:', 'Compile Error:', 'Lambda capture', 'PROCESS_TIMEOUT',
               'FEHLER', 'FAIL'))
              or (line.startswith('ERROR:') and not re.match(r'ERROR: \d+ resources still in use at exit', line))]
    hard = [line for line in errors if not ('FEHLER' in line or 'FAIL' in line)]
    passed = code == 0 and marker in text.splitlines() and not hard
    return {'suite': suite, 'exit': code, 'passed': passed, 'errors': errors[:12],
            'seconds': round(time.monotonic() - started, 2), 'log': str(log.relative_to(ROOT))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--only', nargs='+', default=[])
    # Zeitkritische Eingabetests können unter fremder Rechnerlast stolpern. Jeder
    # Wiederholungsversuch wird protokolliert; grün ist nur ein vollständiger Lauf.
    parser.add_argument('--retries', type=int, default=2)
    args = parser.parse_args()
    LOGS.mkdir(parents=True, exist_ok=True)
    r2 = load_r2()
    suites = r2.legacy_suites()
    suites.update({name: value[0] for name, value in r2.R2.items()})
    suites.update(R3)
    if args.only:
        assert not (set(args.only) - set(suites)), 'Unbekannte Suite'
        suites = {name: marker for name, marker in suites.items() if name in args.only}
    fingerprint = r2.production_manifest()
    run_id = str(time.time_ns())
    results, good = [], True
    for suite, marker in suites.items():
        attempts = []
        for attempt in range(1 + max(0, args.retries)):
            row = run_suite(r2, suite, marker, run_id, attempt)
            attempts.append(row)
            if row['passed']:
                break
        row = dict(attempts[-1], attempts=len(attempts),
                   earlier_failures=[a['errors'] or ['exit=%d' % a['exit']] for a in attempts[:-1]])
        good = good and row['passed']
        results.append(row)
        note = '' if len(attempts) == 1 else f' (Versuch {len(attempts)})'
        print(f'{suite}: {"OK" if row["passed"] else "FEHLER"} exit={row["exit"]} {row["seconds"]}s{note}', flush=True)
    stable = r2.production_manifest() == fingerprint
    good = good and stable
    suffix = '' if not args.only else '-' + '-'.join(args.only)
    (LOGS / ('summary' + suffix + '.json')).write_text(json.dumps(
        {'stable_sources': stable, 'results': results}, indent=2) + '\n')
    print('STINGFORGE_R3_REGRESSION_OK' if good else 'STINGFORGE_R3_REGRESSION_FAILED', flush=True)
    return 0 if good else 1


if __name__ == '__main__':
    raise SystemExit(main())
