#!/usr/bin/env python3
"""R2: reproduzierbare Regressionen, unveränderter R1-Kern und eingefrorene Quellen."""
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
BASE = ROOT / 'build/stingforge-round2-baseline'
LOGS = ROOT / 'build/logs/stingforge-r2'
CHANGED = {
    'scripts/autoload/app.gd', 'scripts/autoload/save.gd', 'scripts/autoload/data.gd',
    'scripts/autoload/loc.gd', 'scripts/game/background.gd', 'scripts/game/boss.gd',
    'scripts/game/director.gd', 'scripts/game/enemy.gd', 'scripts/game/fx.gd',
    'scripts/game/game.gd', 'scripts/game/player.gd', 'scripts/game/shop_data.gd',
    'scripts/screens/main_menu.gd', 'scripts/screens/settings_screen.gd',
    'scripts/screens/difficulty_screen.gd', 'scripts/screens/hud.gd',
    'scripts/screens/nectar_convert_screen.gd',
}
NEW_SCRIPTS = {'scripts/game/shield_rings.gd', 'scripts/game/boss_reborn_visual.gd',
               'scripts/screens/highscore_screen.gd'}
REPAIRED = {f'assets/bg/l{level:02}_near.png' for level in (1, 3, 4, 5, 7, 8)}
REPAIRED |= {name+'.import' for name in tuple(REPAIRED)}
R2 = {
    'stingforge_r2_player': ('STINGFORGE_R2_PLAYER_OK', 'player'),
    'stingforge_r2_world': ('STINGFORGE_R2_WORLD_OK', 'world'),
    'stingforge_r2_world_builds': ('STINGFORGE_R2_WORLD_OK', 'world'),
    'stingforge_r2_final': ('STINGFORGE_R2_FINAL_OK', 'final'),
    'stingforge_r2_scores': ('STINGFORGE_R2_SCORES_OK', 'scores'),
    'stingforge_r2_scores_reload': ('STINGFORGE_R2_SCORES_RELOAD_OK', 'scores'),
    'stingforge_r2_flow': ('STINGFORGE_R2_FLOW_OK', 'flow'),
    'stingforge_r2_frontend': ('STINGFORGE_R2_FRONTEND_OK', 'frontend'),
    'stingforge_r2_hud_probe': ('STINGFORGE_R2_HUD_OK', 'hud'),
    'stingforge_r2_parallax_probe': ('STINGFORGE_R2_PARALLAX_OK', 'parallax'),
}


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def production_manifest():
    paths = [ROOT/'project.godot', ROOT/'export_presets.cfg']
    for folder in ('scripts', 'scenes', 'assets'):
        paths.extend(p for p in (ROOT/folder).rglob('*') if p.is_file())
    return {str(p.relative_to(ROOT)): digest(p) for p in sorted(paths)}


def methods(text):
    starts = list(re.finditer(r'^func (\w+)\(', text, re.M))
    return {match.group(1): text[match.start():starts[i+1].start() if i+1 < len(starts) else len(text)].strip()
            for i, match in enumerate(starts)}


def source_guard():
    baseline = json.loads((BASE/'SHA256.json').read_text())
    errors = []
    unchanged = 0
    for name, wanted in baseline.items():
        if digest(BASE/name) != wanted:
            errors.append('Baseline verändert: '+name)
        if name == 'project.godot':
            expected = (BASE/name).read_text().replace('[file_customization]\n',
                '[filesystem]\n\nimport/blender/enabled=false\n\n[file_customization]\n')
            if (ROOT/name).read_text() != expected:
                errors.append('Projektkonfiguration außerhalb Blender-Importschalter geändert')
            continue
        protected = name.startswith(('scripts/', 'assets/')) or name == 'export_presets.cfg'
        if protected and name not in CHANGED | REPAIRED:
            if not (ROOT/name).exists() or digest(ROOT/name) != wanted:
                errors.append('Geschützte Quelldatei verändert: '+name)
            else:
                unchanged += 1
    for path in (ROOT/'scripts').rglob('*.gd'):
        name = str(path.relative_to(ROOT))
        if name not in baseline and name not in NEW_SCRIPTS:
            errors.append('Ungeplantes neues Produktionsskript: '+name)
    # Keine heimlichen Waffen-/Evo-Nerfs: sämtliche Zahlen/Daten bleiben gleich,
    # außer dem ausdrücklich entfernten kostenlosen Bastion-Schildtreffer.
    def canonical_data(text):
        text = re.sub(r'"(?:desc|mechanic_text)"\s*:\s*"(?:[^"\\]|\\.)*"', '"description":""', text)
        return text.replace('"shield_hits": 1, "shield_regen": 0.35', '"shield_regen": 0.35')
    if canonical_data((BASE/'scripts/autoload/data.gd').read_text()) != canonical_data((ROOT/'scripts/autoload/data.gd').read_text()):
        errors.append('Ungeplante Waffen-/Evolutions-/Schwierigkeitsdaten geändert')
    # Die sieben kauf-/eingaberelevanten HUD-Funktionen bleiben bytegleich.
    before = methods((BASE/'scripts/screens/hud.gd').read_text())
    after = methods((ROOT/'scripts/screens/hud.gd').read_text())
    protected_hud = ['_handle_input', '_process', '_state_text', '_state_short',
                     'maxed_out', 'boss_announce', 'show_banner']
    def code_only(text):
        return '\n'.join(line for line in text.splitlines() if line.strip() and not line.strip().startswith('#'))
    same_hud = [name for name in protected_hud if name in before and name in after
                and code_only(before[name]) == code_only(after[name])]
    if len(same_hud) != len(protected_hud):
        errors.append('HUD-Verhaltensfunktion geändert: '+str(set(protected_hud)-set(same_hud)))
    for name, wanted in {
        'assets/ui/menu/stingforge.png': '5cc4265e5d96055c4e822f6f2153c7f1b7b8ac6bdf01da1088535ecbc31a1a8e',
        'assets/ui/menu/hero.png': 'f7ed53f07903d81e3d428a56add3e12f4e082ce82fe4f57388156ff3e46c58a8',
    }.items():
        if digest(ROOT/name) != wanted:
            errors.append('Nutzerbild verändert: '+name)
    report = {'passed': not errors, 'errors': errors, 'baseline_files': len(baseline),
              'unchanged_protected_files': unchanged, 'unchanged_hud_methods': same_hud,
              'changed_scripts_allowed': sorted(CHANGED)}
    (LOGS/'source-guard.json').write_text(json.dumps(report, indent=2)+'\n')
    print('STINGFORGE_R2_SOURCE_GUARD', 'OK' if not errors else errors, flush=True)
    return not errors


def legacy_suites():
    spec = importlib.util.spec_from_file_location('previous_ui', ROOT/'tools/verify_ui_redesign.py')
    previous = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(previous)
    suites = dict(previous.SUITES)
    suites.update({'campaign': 'CAMPAIGN_OK', 'stingforge_weapons_probe': 'STINGFORGE_WEAPONS_OK',
        'stingforge_world_density': 'STINGFORGE_WORLD_DENSITY_OK',
        'stingforge_world_motion': 'STINGFORGE_WORLD_MOTION_OK',
        'stingforge_world_boss': 'STINGFORGE_WORLD_BOSS_OK',
        'stingforge_world_synergy': 'STINGFORGE_WORLD_SYNERGY_OK',
        'stingforge_weapons_matrix': 'STINGFORGE_WEAPONS_MATRIX_OK',
        'stingforge_visual_probe': 'STINGFORGE_VISUAL_OK'})
    return suites


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--only', nargs='+', default=[])
    parser.add_argument('--guard-only', action='store_true')
    args = parser.parse_args()
    LOGS.mkdir(parents=True, exist_ok=True)
    good = source_guard()
    if args.guard_only:
        return 0 if good else 1
    suites = legacy_suites()
    suites.update({name: value[0] for name, value in R2.items()})
    if args.only:
        assert not (set(args.only) - set(suites)), 'Unbekannte Suite'
        suites = {name: marker for name, marker in suites.items() if name in args.only}
    fingerprint = production_manifest()
    results = []
    run_id = str(time.time_ns())
    for suite, marker in suites.items():
        base = ROOT/'build/stingforge-testdata-regression'/run_id/suite
        if suite == 'main_menu_reference_probe':
            base = ROOT/'build/reference-menu-testdata'/run_id
        elif suite in R2:
            base = ROOT/('build/stingforge-r2-testdata-'+R2[suite][1])
        elif suite.startswith('stingforge_weapons'):
            base = ROOT/'build/stingforge-testdata-weapons'/run_id
        elif suite.startswith('stingforge_world'):
            base = ROOT/'build/stingforge-testdata-world'/run_id/suite
        elif suite.startswith('stingforge_visual'):
            base = ROOT/'build/stingforge-testdata-visual'/run_id
        base.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, XDG_DATA_HOME=str(base/'data'), XDG_CONFIG_HOME=str(base/'config'),
                   XDG_CACHE_HOME=str(base/'cache'))
        started = time.monotonic()
        log = LOGS/(suite+'.log')
        with log.open('w') as stream:
            try:
                run = subprocess.run(['godot', '--headless', '--audio-driver', 'Dummy', '--path', str(ROOT),
                                      f'res://tests/{suite}.tscn'], cwd=ROOT, env=env,
                                     stdout=stream, stderr=subprocess.STDOUT, timeout=180)
                code = run.returncode
            except subprocess.TimeoutExpired:
                code = 124
        text = log.read_text(errors='replace')
        errors = [line for line in text.splitlines() if any(word in line for word in
                  ('SCRIPT ERROR:', 'Parse Error:', 'Compile Error:', 'Lambda capture', 'PROCESS_TIMEOUT'))
                  or (line.startswith('ERROR:') and not re.match(r'ERROR: \d+ resources still in use at exit', line))]
        passed = code == 0 and marker in text.splitlines() and not errors
        row = {'suite': suite, 'exit': code, 'passed': passed, 'errors': errors,
               'seconds': round(time.monotonic()-started, 2), 'log': str(log.relative_to(ROOT))}
        results.append(row)
        good = good and passed
        print(f'{suite}: {"OK" if passed else "FEHLER"} exit={code} {row["seconds"]}s', flush=True)
    stable = production_manifest() == fingerprint
    good = good and stable
    suffix = '' if not args.only else '-'+'-'.join(args.only)
    (LOGS/('summary'+suffix+'.json')).write_text(json.dumps(results, indent=2)+'\n')
    (LOGS/('tested-sources'+suffix+'.json')).write_text(json.dumps({'stable': stable, 'files': fingerprint}, indent=2)+'\n')
    print('STINGFORGE_R2_REGRESSION_OK' if good else 'STINGFORGE_R2_REGRESSION_FAILED', flush=True)
    return 0 if good else 1


if __name__ == '__main__':
    raise SystemExit(main())
