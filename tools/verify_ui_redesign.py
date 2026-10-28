#!/usr/bin/env python3
"""Isolierte UI-Regressionen mit echten Prozess-Exitcodes und Quellschutz."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LOGS = ROOT / "build" / "logs" / "ui-regression"
DATA = ROOT / "build" / "ui-regression-data"
BACKUP = ROOT / "build" / "ui-redesign-backup"
SUITES = {
    "ui_prompts_probe": "UI_PROMPTS_OK", "ui_modern_probe": "UI_MODERN_OK",
    "main_menu_reference_probe": "MENU_REFERENCE_OK",
    "smoke": "SMOKE_OK", "content": "CONTENT_OK", "ui_text": "UI_OK",
    "mechanics": "MECHANIK_OK", "flowprobe": "ABLAUF_OK", "shopprobe": "SHOP_OK",
    "upgradeprobe": "UPGRADE_OK", "bossprobe": "BOSS_OK", "balanceprobe": "BALANCE_OK",
    "gameoverprobe": "GAMEOVER_OK", "pointstable": "PUNKTE_OK",
    "ending": "ENDING_OK", "builds": "BUILDS_OK",
}


def function_source(text, name):
    match = re.search(r"^func " + re.escape(name) + r"\(.*?(?=^func |\Z)", text, re.M | re.S)
    if not match:
        raise ValueError(f"Funktion fehlt: {name}")
    return "\n".join(line for line in match[0].splitlines() if line.strip() and not line.strip().startswith("#"))


def source_guard():
    manifest = json.loads((BACKUP / "gameplay-sha256.json").read_text())
    changed = [str(p) for p, digest in manifest.items()
               if hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != digest]
    protected = {
        "scripts/core/ui_screen.gd": ["_process", "_activate", "_adjust", "_back", "_move_focus", "_grid_move", "_on_row_input"],
        "scripts/screens/hud.gd": ["_ready", "set_view_rect", "_scale", "_game", "_player", "_add_initial_entries", "_process", "_handle_input", "boss_announce", "show_banner", "_state_text", "_bar_top", "maxed_out", "_state_short"],
        "scripts/screens/nectar_convert_screen.gd": ["setup", "_ready", "_process", "_finish"],
        "scripts/screens/main_menu.gd": ["on_activate", "_open_new_campaign", "_choose_difficulty", "do_back"],
        "scripts/screens/shop_screen.gd": ["_activate", "_buy", "_on_next", "do_back"],
        "scripts/screens/settings_screen.gd": ["_input", "_try_bind", "_process", "on_adjust", "_adjust_choice", "_adjust_slider", "_toggle", "apply_staged_display", "do_back"],
    }
    for file, names in protected.items():
        old = (BACKUP / file).read_text()
        new = (ROOT / file).read_text()
        changed.extend(f"{file}:{name}" for name in names if function_source(old, name) != function_source(new, name))
    if changed:
        print("QUELLSCHUTZ FEHLER", changed, flush=True)
        return False
    print(f"QUELLSCHUTZ_OK: {len(manifest)} Dateien der Spiellogik + {sum(map(len, protected.values()))} UI-Eingabe-/Zustandsfunktionen unverändert", flush=True)
    return True


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    DATA.mkdir(parents=True, exist_ok=True)
    good = source_guard()
    env = dict(os.environ, XDG_DATA_HOME=str(DATA))
    results = []
    for suite, marker in SUITES.items():
        suite_env = env
        if suite == "main_menu_reference_probe":
            reference_data = ROOT / "build" / "reference-menu-testdata"
            suite_env = dict(env, XDG_DATA_HOME=str(reference_data / "data"),
                             XDG_CONFIG_HOME=str(reference_data / "config"),
                             XDG_CACHE_HOME=str(reference_data / "cache"))
        try:
            run = subprocess.run(["godot", "--headless", "--path", str(ROOT), f"res://tests/{suite}.tscn"],
                                 cwd=ROOT, env=suite_env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 text=True, timeout=150)
            text, code = run.stdout, run.returncode
        except subprocess.TimeoutExpired as exc:
            text, code = str(exc.stdout), 124
        (LOGS / f"{suite}.log").write_text(text)
        errors = [line for line in text.splitlines() if "SCRIPT ERROR:" in line or "Parse Error:" in line]
        passed = code == 0 and marker in text.splitlines() and not errors
        results.append({"suite": suite, "exit": code, "passed": passed, "script_errors": errors})
        print(f"{suite}: {'OK' if passed else 'FEHLER'} exit={code}", flush=True)
        good = good and passed
    (LOGS / "summary.json").write_text(json.dumps(results, indent=2))
    print("UI_REGRESSION_OK" if good else "UI_REGRESSION_FAILED", flush=True)
    return 0 if good else 1


if __name__ == "__main__":
    sys.exit(main())
