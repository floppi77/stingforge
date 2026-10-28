#!/usr/bin/env python3
"""Testet echte Save-Übernahme in getrennten Godot-Prozessen, nie echte Nutzerdaten."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--red', action='store_true', help='Einmaliger Vorher-Nachweis ohne Migrationsfix')
    args = parser.parse_args()
    run_dir = ROOT / 'build/stingforge-testdata-branding' / str(time.time_ns())
    results = []
    for mode in (['legacy'] if args.red else ['legacy', 'existing', 'backup']):
        data = run_dir / mode
        parent = data / 'godot/app_userdata'
        legacy = parent / 'Apidya Reimagined/saves'
        current = parent / 'Stingforge/saves'
        legacy.mkdir(parents=True)
        campaign = dict(version=1, level=4, checkpoint=2, points=43210, deaths=1,
                        difficulty='normal', shop={'orbit': 2}, upgrades={'base': 1},
                        evolutions=[{'id': 'pierce1', 'level': 1}], nectar=35)
        fixtures = {'settings': {'version': 1, 'audio': {'master': .37}},
                    'profile': {'version': 1, 'unlocked_evolutions': ['pierce1'], 'sentinel': 'untouched'},
                    'campaign': campaign}
        for name, values in fixtures.items():
            (legacy / (name + '.save')).write_text(json.dumps(values))
        (legacy / 'campaign.save.bak').write_text(json.dumps(campaign))
        if mode == 'backup':
            (legacy / 'campaign.save').write_text('unvollständiger JSON-Spielstand')
        if mode == 'existing':
            current.mkdir(parents=True)
            (current / 'settings.save').write_text(json.dumps({'version': 1, 'audio': {'master': .42}}))
            (current / 'campaign.save').write_text(json.dumps(dict(campaign, points=9988)))
        before = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in legacy.iterdir()}
        env = dict(os.environ, XDG_DATA_HOME=str(data), XDG_CONFIG_HOME=str(data/'config'),
                   XDG_CACHE_HOME=str(data/'cache'), STINGFORGE_MIGRATION_CASE=mode)
        result = subprocess.run(['godot', '--headless', '--audio-driver', 'Dummy', '--path', str(ROOT),
                                 'res://tests/stingforge_branding_probe.tscn'], env=env, cwd=ROOT,
                                capture_output=True, text=True, timeout=25)
        text = result.stdout + result.stderr
        logs = ROOT / 'build/logs/stingforge'; logs.mkdir(parents=True, exist_ok=True)
        (logs / ('branding-' + mode + ('-red' if args.red else '') + '.log')).write_text(text)
        after = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in legacy.iterdir()}
        unchanged = before == after
        valid_log = 'SCRIPT ERROR:' not in text and 'Parse Error:' not in text
        passed = result.returncode == 0 and 'STINGFORGE_BRANDING_OK' in text.splitlines() and valid_log and unchanged
        results.append({'case': mode, 'exit': result.returncode, 'passed': passed, 'legacy_unchanged': unchanged})
        print(mode, 'exit=', result.returncode, 'passed=', passed, 'alte Dateien unverändert=', unchanged, flush=True)
        if args.red:
            assert result.returncode == 1 and valid_log and 'STINGFORGE_BRANDING_FAILED' in text
            print('ROT_REPRODUZIERT: Umbenennung ohne Migration verliert vorhandenen Spielstand aus der Menüansicht.')
            return 0
    (ROOT/'build/logs/stingforge/branding-summary.json').write_text(json.dumps(results, indent=2))
    return 0 if all(r['passed'] for r in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
