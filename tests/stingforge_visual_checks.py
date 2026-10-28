#!/usr/bin/env python3
"""Stingforge visual checks; no imports, release exports, or real save access.

Default: art round-trip plus headless HUD layout. Add --screenshots for a real
Wayland capture and exact with/without-HUD pixel comparison of the playfield.
All Godot XDG roots are under build/stingforge-testdata-visual.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import zlib

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/stingforge-visual"
DATA = ROOT / "build/stingforge-testdata-visual"
RESULTS = []


def check(ok, message):
    RESULTS.append({"passed": bool(ok), "check": message})
    print(("OK " if ok else "FAIL ") + message, flush=True)


def read_source():
    raw = (ROOT / "assets/aseprite/bee.aseprite").read_bytes()
    length, magic, count, width, height, depth = struct.unpack_from("<IHHHHH", raw)
    check(length == len(raw) and magic == 0xA5E0, "Aseprite native header valid")
    check((count, width, height, depth) == (6, 40, 32, 32), "Aseprite 40x32 RGBA / six frames")
    offset = 128
    layers = []
    frames = []
    durations = []
    for _ in range(count):
        frame_size, frame_magic, chunks, duration = struct.unpack_from("<IHHH", raw, offset)
        assert frame_magic == 0xF1FA
        durations.append(duration)
        cel_images = {}
        cursor = offset + 16
        for _ in range(chunks):
            size, kind = struct.unpack_from("<IH", raw, cursor)
            data = raw[cursor + 6:cursor + size]
            if kind == 0x2004:
                flags, layer_type = struct.unpack_from("<HH", data)
                n = struct.unpack_from("<H", data, 16)[0]
                layers.append(data[18:18 + n].decode())
                check(flags & 1 and layer_type == 0, "Editable visible normal layer: " + layers[-1])
            elif kind == 0x2005:
                layer, x, y, opacity, cel_type = struct.unpack_from("<HhhBH", data)
                w, h = struct.unpack_from("<HH", data, 16)
                assert (x, y, opacity, cel_type, w, h) == (0, 0, 255, 2, 40, 32)
                cel_images[layer] = zlib.decompress(data[20:])
            cursor += size
        frames.append(cel_images)
        offset += frame_size
    check(len(layers) == 5 and all(len(f) == 5 for f in frames), "Five editable layers, all six frames complete")
    check(all(f[2] == frames[0][2] and f[3] == frames[0][3] and f[4] == frames[0][4] for f in frames),
          "Body, eye and antennae fixed: no registration jitter")
    check(len({hashlib.sha256(f[0]).hexdigest() for f in frames}) == 6, "Six distinct wing poses, no duplicate loop frame")
    check(sum(durations) == round(6 * 1000 / 14), "Aseprite flight timing rounds the 14fps cycle correctly")
    alpha = Image.frombytes("RGBA", (40, 32), frames[0][0]).getchannel("A")
    check(sum(0 < a < 230 for a in alpha.get_flattened_data()) > 50, "Wing membrane genuinely translucent")


def art_checks():
    manifest = json.loads((ROOT / "assets/sprites/manifest.json").read_text())
    check(manifest["bee"] == {"w": 40, "h": 32, "frames": 6, "fps": 14}, "Existing manifest unchanged: 40x32 / 6 / 14")
    sheet = Image.open(ROOT / "assets/sprites/bee.png").convert("RGBA")
    check(sheet.size == (240, 32), "Production PNG exactly 240x32")
    baseline = Image.open(ROOT / "build/stingforge-baseline/assets/sprites/bee.png").convert("RGBA")
    check(sheet.tobytes() != baseline.tobytes(), "Production bee is visibly new, not the baseline")
    old = baseline.crop((0, 0, 40, 32))
    new = sheet.crop((0, 0, 40, 32))
    # Baseline wings are opaque. Total opacity would reward them over the
    # requested delicate translucent wings, rather than measuring the gold body.
    def gold_area(image):
        return sum(r > 120 and g > 80 and r > b * 1.5 and a > 230
                   for r, g, b, a in image.get_flattened_data())
    old_body, new_body = gold_area(old), gold_area(new)
    check(new_body > old_body * 1.5, "Stronger gold body: %d vs %d opaque gold pixels" % (new_body, old_body))
    for index in range(6):
        frame = sheet.crop((index * 40, 0, index * 40 + 40, 32))
        gold = sum(r > 120 and g > 80 and r > b * 1.5 and a > 230 for r, g, b, a in frame.get_flattened_data())
        eye = frame.crop((28, 11, 35, 21))
        dark = sum(max(r, g, b) < 100 and a > 230 for r, g, b, a in eye.get_flattened_data())
        check(gold > 100 and dark > 18, "Frame %d: golden body and large dark eye readable" % index)
    read_source()
    aseprite = shutil.which("aseprite")
    check(aseprite is not None, "Aseprite CLI available for independent round-trip")
    if aseprite:
        target = OUT / "bee-source-roundtrip.png"
        run = subprocess.run([aseprite, "--batch", str(ROOT / "assets/aseprite/bee.aseprite"),
                              "--sheet-type", "horizontal", "--sheet", str(target),
                              "--data", str(OUT / "bee-source-roundtrip.json")],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=30)
        (OUT / "aseprite-roundtrip.log").write_text(run.stdout)
        check(run.returncode == 0, "Editable source opens and exports in real Aseprite")
        if run.returncode == 0:
            source = Image.open(target).convert("RGBA")
            check(source.size == sheet.size and source.tobytes() == sheet.tobytes(),
                  "PNG is pixel-identical to flattened editable Aseprite")
    baseline_hud = (ROOT / "build/stingforge-baseline/scripts/screens/hud.gd").read_text()
    current_hud = (ROOT / "scripts/screens/hud.gd").read_text()
    for func in ["_handle_input", "_process", "_state_text", "_state_short", "maxed_out", "boss_announce", "show_banner"]:
        def normalized(text):
            match = re.search(r"^func " + re.escape(func) + r"\(.*?(?=^func |\Z)", text, re.M | re.S)
            assert match, func
            return "\n".join(line for line in match[0].splitlines() if line.strip() and not line.strip().startswith("#"))
        check(normalized(baseline_hud) == normalized(current_hud), "Existing inputs/purchase behavior untouched: " + func)


def engine_check(rendered):
    env = dict(os.environ)
    for kind in ("data", "config", "cache"):
        path = DATA / kind
        path.mkdir(parents=True, exist_ok=True)
        env["XDG_" + kind.upper() + "_HOME"] = str(path)
    env.update(GSETTINGS_BACKEND="memory", LIBGL_ALWAYS_SOFTWARE="1", GALLIUM_DRIVER="llvmpipe")
    command = ["godot", "--audio-driver", "Dummy", "--path", str(ROOT)]
    if rendered:
        env["WAYLAND_DISPLAY"] = env.get("WAYLAND_DISPLAY") or "wayland-1"
        command.extend(["--display-driver", "wayland"])
    else:
        command.append("--headless")
    command.append("res://tests/stingforge_visual_probe.tscn")
    name = "render" if rendered else "headless"
    try:
        run = subprocess.run(command, env=env, cwd=ROOT, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True, timeout=90)
        code, output = run.returncode, run.stdout
    except subprocess.TimeoutExpired as exc:
        code, output = 124, str(exc.stdout)
    (OUT / (name + ".log")).write_text(output)
    errors = [line for line in output.splitlines() if "SCRIPT ERROR:" in line or "Parse Error:" in line]
    check(code == 0 and "STINGFORGE_VISUAL_OK" in output.splitlines() and not errors,
          "Godot %s regression exit=%d" % (name, code))
    if errors:
        print("\n".join(errors), flush=True)
    if rendered and code == 0:
        for mode in ("low", "default", "high"):
            for state in ("hud", "boss"):
                check((OUT / (mode + "_" + state + ".png")).is_file(), mode + " " + state + " screenshot exists")
        for name in ("high_boss_notice", "projectiles_bright", "projectiles_dark"):
            check((OUT / (name + ".png")).is_file(), name + " screenshot exists")
        report = json.loads((OUT / "render-report.json").read_text())
        comparisons = report.get("playfield_pixel_comparisons", [])
        check(len(comparisons) == 9 and all(row["changed_pixels"] == 0 for row in comparisons),
              "All nine variants: exactly zero changed playfield pixels, no tolerance")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--screenshots", action="store_true")
    parser.add_argument("--art-only", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    try:
        art_checks()
        if not args.art_only:
            engine_check(False)
            if args.screenshots:
                engine_check(True)
    except Exception as exc:
        check(False, type(exc).__name__ + ": " + str(exc))
    passed = all(row["passed"] for row in RESULTS)
    summary = {"passed": passed, "checks": len(RESULTS), "results": RESULTS}
    (OUT / "checks-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print("STINGFORGE_VISUAL_CHECKS_OK" if passed else "STINGFORGE_VISUAL_CHECKS_FAILED")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
