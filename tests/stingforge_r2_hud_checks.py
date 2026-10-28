#!/usr/bin/env python3
"""Owned R2 HUD checks: no asset imports; isolated save/config/cache.

Default runs headless. --screenshots additionally opens one coordinated Wayland
window and requires exactly nine zero-tolerance field pixel comparisons at 56/476.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/stingforge-r2-hud"
DATA = ROOT / "build/stingforge-r2-testdata-hud"
RESULTS = []


def check(ok, message):
    RESULTS.append({"passed": bool(ok), "check": message})
    print(("OK " if ok else "FAIL ") + message, flush=True)


def behavior_contract():
    baseline = (ROOT / "build/stingforge-round2-baseline/scripts/screens/hud.gd").read_text()
    current = (ROOT / "scripts/screens/hud.gd").read_text()
    for name in ("_handle_input", "_process", "_state_text", "_state_short", "maxed_out", "boss_announce", "show_banner"):
        def normalized(text):
            match = re.search(r"^func " + re.escape(name) + r"\(.*?(?=^func |\Z)", text, re.M | re.S)
            assert match, name
            return "\n".join(line for line in match[0].splitlines() if line.strip() and not line.strip().startswith("#"))
        check(normalized(baseline) == normalized(current), "Eingabe/Kaufverhalten unverändert: " + name)


def immutable_contract():
    baseline = ROOT / "build/stingforge-round2-baseline"
    hashes = json.loads((baseline / "SHA256.json").read_text())
    changed = [name for name, digest in hashes.items()
               if not (baseline / name).is_file() or hashlib.sha256((baseline / name).read_bytes()).hexdigest() != digest]
    check(not changed, "Round2-Baseline vollständig unverändert: " + str(len(hashes)) + " Prüfsummen")
    if changed:
        print("Baseline-Abweichungen: " + ", ".join(changed[:10]), flush=True)
    manifest = json.loads((ROOT / "assets/sprites/manifest.json").read_text())
    check(manifest["bee"]["w"] == 40 and manifest["bee"]["h"] == 32 and manifest["bee"]["frames"] == 6,
          "Bienenmanifest bleibt40x32/6Frames")
    with Image.open(ROOT / "assets/sprites/bee.png") as bee:
        check(bee.size == (240, 32), "Bienenblatt bleibt240x32 ohne Assetimporte")


def independent_pixels(rows):
    proofs = []
    for row in rows:
        with Image.open(OUT / row["with_hud"]) as source:
            shown = source.convert("RGBA")
        with Image.open(OUT / row["without_hud"]) as source:
            naked = source.convert("RGBA")
        x, y, width, height = row["native_playfield"]
        crop = (x, y, x + width, y + height)
        a, b = shown.crop(crop), naked.crop(crop)
        diff = ImageChops.difference(a, b)
        changed = sum(any(pixel) for pixel in diff.get_flattened_data())
        check(changed == 0, row["case"] + ": unabhängiger PNG-Pixelvergleich exakt0")
        # An all-screen black/empty comparison would otherwise be a false green.
        check(len(set(a.get_flattened_data())) > 100, row["case"] + ": echtes nichtleeres Spielfeld verglichen")
        check(ImageChops.difference(shown, naked).getbbox(alpha_only=False) is not None,
              row["case"] + ": HUD ist außerhalb des Felds tatsächlich sichtbar")
        proofs.append({"case": row["case"], "changed_pixels": changed,
                       "compared_pixels": width * height,
                       "with_hud_sha256": hashlib.sha256((OUT / row["with_hud"]).read_bytes()).hexdigest(),
                       "without_hud_sha256": hashlib.sha256((OUT / row["without_hud"]).read_bytes()).hexdigest()})
    (OUT / "independent-pixel-report.json").write_text(json.dumps(proofs, indent=2) + "\n")


def engine_check(rendered):
    first_result = len(RESULTS)
    env = dict(os.environ)
    for kind in ("data", "config", "cache"):
        path = DATA / kind
        path.mkdir(parents=True, exist_ok=True)
        env["XDG_" + kind.upper() + "_HOME"] = str(path)
    env.update(XDG_RUNTIME_DIR="/run/user/1000", WAYLAND_DISPLAY="wayland-1",
               GSETTINGS_BACKEND="memory", LIBGL_ALWAYS_SOFTWARE="1", GALLIUM_DRIVER="llvmpipe")
    command = ["godot", "--verbose", "--quit-after", "600", "--audio-driver", "Dummy", "--path", str(ROOT)]
    command += ["--display-driver", "wayland"] if rendered else ["--headless"]
    command.append("res://tests/stingforge_r2_hud_probe.tscn")
    mode = "render" if rendered else "headless"
    try:
        run = subprocess.run(command, env=env, cwd=ROOT, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True, timeout=90)
        code, output = run.returncode, run.stdout
    except subprocess.TimeoutExpired as exc:
        code = 124
        output = exc.stdout.decode(errors="replace") if isinstance(exc.stdout, bytes) else str(exc.stdout)
    (OUT / (mode + ".log")).write_text(output)
    resources = [line for line in output.splitlines() if line.startswith("Resource still in use: ")]
    leaked = [line for line in output.splitlines() if line.startswith("Leaked instance: ")]
    audio_only_shutdown = bool(resources) and bool(leaked) and all(
        line.startswith("Resource still in use: res://assets/audio/") for line in resources) and all(
        re.match(r"Leaked instance: (AudioStream|OggPacketSequence)", line) for line in leaked)
    known_shutdown = [line for line in output.splitlines() if audio_only_shutdown and
                      re.match(r"^ERROR: \d+ resources still in use at exit\b", line)]
    errors = [line for line in output.splitlines() if ("ERROR:" in line or "Parse Error:" in line) and line not in known_shutdown]
    if known_shutdown:
        print("WARN " + mode + ": ausschließlich bekannte Dummy-Audio-Shutdownreferenzen; Details im Log", flush=True)
        (OUT / (mode + "-audio-shutdown.json")).write_text(json.dumps(
            {"scope": "test-host Dummy audio shutdown only", "errors": known_shutdown, "resources": resources, "leaked": leaked}, indent=2) + "\n")
    check(code == 0 and "STINGFORGE_R2_HUD_OK" in output.splitlines() and not errors,
          "Godot " + mode + " exit=" + str(code))
    for line in output.splitlines():
        if line not in known_shutdown and (line.startswith("FAIL ") or "ERROR:" in line or "Parse Error:" in line):
            print(line, flush=True)
    if code == 0 and not errors:
        report = json.loads((OUT / ("render-report.json" if rendered else "layout-report.json")).read_text())
        check(report.get("passed") and report.get("checks", 0) >= 2000 and len(report.get("layouts", [])) == 27,
              mode + ": vollständiger Layoutvertrag, mindestens2000 Prüfungen/27 Varianten")
        rows = report.get("playfield_pixel_comparisons", [])
        if rendered:
            check(len(rows) == 9 and all(row["changed_pixels"] == 0 for row in rows),
                  "Exakt neun Feldvergleiche, exakt null veränderte Pixel")
            check(all(row["world_playfield"] == [0, 56, 960, 420] for row in rows), "Alle Pixelvergleiche verwenden56/476")
            independent_pixels(rows)
        else:
            check(not rows, "Headless behauptet keine nicht gerenderten Pixelvergleiche")
    return all(row["passed"] for row in RESULTS[first_result:])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--screenshots", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    try:
        immutable_contract()
        behavior_contract()
        headless_ok = engine_check(False)
        if args.screenshots:
            if headless_ok:
                engine_check(True)
            else:
                check(False, "Fensterlauf ausgelassen: Headless-/Schnittstellenvertrag ist noch rot")
    except Exception as exc:
        check(False, type(exc).__name__ + ": " + str(exc))
    passed = bool(RESULTS) and all(row["passed"] for row in RESULTS)
    owned_sources = [ROOT / "scripts/screens/hud.gd", *sorted((ROOT / "tests").glob("stingforge_r2_hud*"))]
    fingerprint = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                   for path in owned_sources if path.is_file()}
    (OUT / "checks-summary.json").write_text(json.dumps(
        {"passed": passed, "screenshots_requested": args.screenshots,
         "source_sha256": fingerprint, "results": RESULTS}, indent=2) + "\n")
    print("STINGFORGE_R2_HUD_OK" if passed else "STINGFORGE_R2_HUD_FAIL")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
