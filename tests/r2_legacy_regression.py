#!/usr/bin/env python3
"""R2 legacy regression: execute the previous runner's suite inventory, without its R1 source guard.
Each Godot attempt runs serially with fresh XDG paths. Exit, exact marker and script errors all matter.
"""
from pathlib import Path
import argparse
import ast
import hashlib
import json
import os
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]

def inventory():
    suites = {}
    for path, variable in [(ROOT / 'tools/verify_ui_redesign.py', 'SUITES'),
                           (ROOT / 'tools/verify_stingforge.py', 'extra')]:
        for node in ast.walk(ast.parse(path.read_text())):
            if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == variable for t in node.targets):
                suites.update(ast.literal_eval(node.value))
    suites['campaign'] = 'CAMPAIGN_OK'
    return suites

def fingerprint():
    base = ROOT / 'build/stingforge-round2-baseline'
    return {str(p.relative_to(base)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(base.rglob('*')) if p.is_file()}

def production_fingerprint():
    files = [ROOT / 'project.godot'] + list((ROOT / 'scripts').rglob('*.gd')) + list((ROOT / 'tools').glob('*.py'))
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--only', nargs='+', default=[])
    parser.add_argument('--label', default='baseline')
    args = parser.parse_args()
    suites = inventory()
    if args.only:
        unknown = set(args.only) - set(suites)
        if unknown:
            raise SystemExit('Unknown suites: ' + str(unknown))
        suites = {k: v for k, v in suites.items() if k in args.only}
    run_id = str(time.time_ns())
    logdir = ROOT / 'build/stingforge-r2-testdata-regression' / (args.label + '-' + run_id)
    logdir.mkdir(parents=True)
    before = fingerprint()
    production_before = production_fingerprint()
    (logdir / 'production-sha256-before.json').write_text(json.dumps(production_before, indent=2) + '\n')
    (logdir / 'baseline-sha256-before.json').write_text(json.dumps(before, indent=2) + '\n')
    results = []
    for suite, marker in suites.items():
        base = logdir / suite
        if suite == 'main_menu_reference_probe':
            base = ROOT / 'build/reference-menu-testdata' / ('r2-legacy-' + run_id)
        base.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, XDG_DATA_HOME=str(base / 'data'),
                   XDG_CONFIG_HOME=str(base / 'config'), XDG_CACHE_HOME=str(base / 'cache'))
        command = ['godot', '--headless', '--audio-driver', 'Dummy', '--path', str(ROOT),
                   'res://tests/' + suite + '.tscn']
        started = time.monotonic()
        try:
            run = subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True, timeout=180)
            text, code = run.stdout, run.returncode
        except subprocess.TimeoutExpired as exc:
            text = exc.stdout.decode(errors='replace') if isinstance(exc.stdout, bytes) else (exc.stdout or '')
            text += '\nPROCESS_TIMEOUT\n'
            code = 124
        (logdir / (suite + '.log')).write_text(text)
        errors = [line for line in text.splitlines() if any(x in line for x in ['SCRIPT ERROR:', 'Parse Error:', 'Compile Error:'])]
        diagnostics = [line for line in text.splitlines() if 'ERROR:' in line or 'WARNING:' in line]
        runtime_errors = [line for line in diagnostics if 'ERROR:' in line and 'resources still in use at exit' not in line]
        exact_marker = marker in text.splitlines()
        passed = code == 0 and exact_marker and not errors and not runtime_errors
        result = {'suite': suite, 'exit': code, 'marker': marker, 'marker_found': exact_marker,
                  'passed': passed, 'script_errors': errors, 'runtime_errors': runtime_errors,
                  'engine_diagnostics': diagnostics,
                  'seconds': round(time.monotonic() - started, 2),
                  'log': str(logdir / (suite + '.log')), 'command': command, 'xdg': str(base)}
        results.append(result)
        (logdir / 'summary.json').write_text(json.dumps(results, indent=2) + '\n')
        print(f'{suite}: {"OK" if passed else "FAILED"} exit={code} marker={exact_marker} script_errors={len(errors)} runtime_errors={len(runtime_errors)} {result["seconds"]}s', flush=True)
        if not passed:
            print('\n'.join(line for line in text.splitlines() if any(x in line for x in ['FAIL', 'Error', 'ERROR', 'TIMEOUT'])), flush=True)
    production_after = production_fingerprint()
    changed_sources = sorted(k for k in production_before.keys() | production_after.keys()
                             if production_before.get(k) != production_after.get(k))
    (logdir / 'production-stability.json').write_text(json.dumps({'unchanged': not changed_sources, 'changed': changed_sources}, indent=2) + '\n')
    print('PRODUCTION_STABLE=' + str(not changed_sources), flush=True)
    unchanged = before == fingerprint()
    (logdir / 'baseline-unchanged.json').write_text(json.dumps({'unchanged': unchanged, 'files': len(before)}, indent=2) + '\n')
    print('BASELINE_UNCHANGED=' + str(unchanged), flush=True)
    print('RESULT_DIR=' + str(logdir), flush=True)
    return 0 if unchanged and not changed_sources and all(x['passed'] for x in results) else 1

if __name__ == '__main__':
    raise SystemExit(main())
