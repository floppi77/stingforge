#!/usr/bin/env python3
"""Selbstprüfung der Sprite-Produktion.

Prüft:
  * manifest.json ist valides JSON und enthält alle geforderten Sprites
  * für jeden Eintrag: PNG existiert, Breite == w*frames, Höhe == h
  * jedes Frame enthält mindestens einen nicht-transparenten Pixel
  * jedes .aseprite-Quellfile existiert und ist nicht leer
  * Soll-Werte (Name, Größe, Frames, fps) aus der Aufgabenliste
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPR = ROOT / "assets" / "sprites"
ASE = ROOT / "assets" / "aseprite"

# Soll-Liste: name -> (w, h, frames, fps)
SPEC = {}


def add(w, h, frames, fps, names):
    for n in names.split():
        SPEC[n] = (w, h, frames, fps)


add(40, 32, 6, 14, "bee")
add(20, 20, 4, 10, "drone")
add(40, 28, 4, 10, "moth")
add(40, 32, 3, 9, "beetle")
add(36, 24, 3, 12, "wasp")
add(24, 20, 3, 10, "aphid")
add(32, 32, 4, 8, "pod")
add(40, 32, 3, 10, "ladybug")
add(40, 32, 4, 10, "borer")
add(48, 32, 4, 8, "grub")
add(44, 28, 3, 11, "dragonfly")
add(28, 20, 3, 12, "mosquito")
add(32, 28, 3, 9, "hopper")
add(44, 28, 3, 10, "pike")
add(32, 32, 4, 8, "spore")
add(40, 36, 3, 8, "mushroom")
add(32, 40, 4, 8, "vine")
add(44, 40, 3, 8, "mantis")
add(36, 28, 3, 10, "glassdrone")
add(32, 32, 4, 10, "mirrororb")
add(44, 32, 3, 9, "crawler")
add(40, 32, 4, 8, "sludge")
add(40, 32, 3, 10, "piston")
add(40, 44, 4, 8, "generator")
add(44, 36, 3, 10, "hiveguard")
add(36, 32, 4, 9, "acolyte")
add(28, 28, 4, 10, "shard")
add(176, 128, 2, 6, "boss_beetle")
add(176, 120, 2, 6, "boss_larva")
add(192, 112, 2, 6, "boss_pike")
add(176, 144, 2, 6, "boss_fungus")
add(192, 128, 2, 6, "boss_mantis")
add(176, 120, 2, 6, "boss_pollinator")
add(192, 120, 2, 6, "boss_skater")
add(184, 128, 2, 6, "boss_harvester")
add(176, 136, 2, 6, "boss_queen")
add(176, 144, 2, 6, "boss_core")
add(12, 8, 2, 12, "bullet_base bullet_fan")
add(16, 8, 2, 12, "bullet_lightning")
add(16, 16, 2, 12, "bullet_plasma")
add(12, 12, 2, 12, "ebullet_orb")
add(14, 6, 2, 12, "ebullet_needle")
add(10, 10, 2, 12, "ebullet_spore")
add(24, 8, 2, 12, "ebullet_laser")
add(20, 20, 2, 12, "bomb")
add(16, 16, 4, 10, "blossom")
add(10, 10, 2, 10, "nectar")
add(14, 14, 2, 4, "heart")
add(48, 48, 6, 18, "explode")
add(16, 16, 4, 16, "spark")
add(40, 40, 4, 8, "pollen")
add(64, 64, 6, 14, "ring")
add(24, 24, 1, 8, "icon_base icon_fan icon_lightning icon_plasma icon_companion "
                 "icon_bombs icon_shield icon_speed icon_repair")
add(16, 16, 1, 8, "icon_hp icon_nectar icon_shieldbar icon_autofire")
add(480, 120, 1, 8, "logo")
add(128, 128, 1, 8, "icon")

FPS_RANGE = {  # erlaubte fps-Bereiche laut Aufgabe
    "enemy": (8, 12),
}


def main() -> int:
    problems = []
    manifest_path = SPR / "manifest.json"
    try:
        man = json.loads(manifest_path.read_text())
    except Exception as exc:  # noqa: BLE001
        print(f"FEHLER: manifest.json nicht lesbar: {exc}")
        return 1

    spec_names = set(SPEC)
    man_names = set(man)
    missing = sorted(spec_names - man_names)
    extra = sorted(man_names - spec_names)
    if missing:
        problems.append(f"fehlende Manifest-Einträge: {missing}")
    if extra:
        problems.append(f"unerwartete Manifest-Einträge: {extra}")

    for name in sorted(spec_names & man_names):
        exp_w, exp_h, exp_frames, exp_fps = SPEC[name]
        m = man[name]
        if (m["w"], m["h"], m["frames"], m["fps"]) != (exp_w, exp_h, exp_frames, exp_fps):
            problems.append(f"{name}: Soll {exp_w}x{exp_h} {exp_frames}f @{exp_fps}, "
                            f"Manifest {m['w']}x{m['h']} {m['frames']}f @{m['fps']}")
        png = SPR / f"{name}.png"
        if not png.exists():
            problems.append(f"{name}: PNG fehlt")
            continue
        im = Image.open(png).convert("RGBA")
        if im.width != m["w"] * m["frames"] or im.height != m["h"]:
            problems.append(f"{name}: PNG {im.width}x{im.height} != "
                            f"{m['w'] * m['frames']}x{m['h']}")
            continue
        for fr in range(m["frames"]):
            frame = im.crop((fr * m["w"], 0, (fr + 1) * m["w"], m["h"]))
            alpha = frame.getchannel("A")
            if alpha.getbbox() is None:
                problems.append(f"{name}: Frame {fr + 1} ist leer")
            else:
                # Anteil sichtbarer Pixel als Plausibilitätsmaß
                hist = alpha.histogram()
                visible = sum(hist[16:])
                if visible < 6:
                    problems.append(f"{name}: Frame {fr + 1} fast leer ({visible} px)")
        ase = ASE / f"{name}.aseprite"
        if not ase.exists():
            problems.append(f"{name}: .aseprite fehlt")
        elif ase.stat().st_size < 200:
            problems.append(f"{name}: .aseprite verdächtig klein")

    # Icon-Kopie für Godot
    icon_copy = ROOT / "assets" / "ui" / "icon.png"
    if not icon_copy.exists():
        problems.append("assets/ui/icon.png fehlt (in project.godot referenziert)")

    contact = SPR / "_contact.png"
    if not contact.exists():
        problems.append("_contact.png fehlt")

    print(f"Manifest-Einträge: {len(man)}")
    print(f"Erwartet:          {len(SPEC)}")
    if problems:
        print(f"\n{len(problems)} PROBLEM(E):")
        for p in problems:
            print("  - " + p)
        return 1
    print("\nALLE PRÜFUNGEN BESTANDEN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
