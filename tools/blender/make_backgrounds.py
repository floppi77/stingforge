"""make_backgrounds.py -- Erzeugt die 30 Parallax-Ebenen (10 Level x far/mid/near).

Aufruf (headless):
  blender --background --python tools/blender/make_backgrounds.py -- \
      [--levels 1,2,3] [--layers far,mid,near] [--samples 20] \
      [--no-post] [--no-render] [--outdir assets/bg]

Ablauf pro Level:
  1. .blend-Datei mit drei Szenen (L01_far/L01_mid/L01_near) bauen und unter
     assets/blender/lNN.blend speichern (bearbeitbar).
  2. Jede Szene nach tools/blender/_raw/lNN_<ebene>.png rendern.
Danach (ausser --no-post): Pixel-Nachbearbeitung + QA (siehe pixelize.py).
"""

import argparse
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy  # noqa: E402
import random  # noqa: E402

import bg_lib as L  # noqa: E402
from bg_lib import blend_hex  # noqa: E402
import levels  # noqa: E402
import palettes as P  # noqa: E402

LAYERS = ("far", "mid", "near")

LIGHT_PRESETS = {
    "far": dict(sun=1.6, world=0.9, rim=0.0, fill=0.0, sun_rot=(46.0, 0.0, 18.0)),
    "mid": dict(sun=3.6, world=0.22, rim=1.4, fill=0.55, sun_rot=(56.0, 0.0, 34.0)),
    "near": dict(sun=2.4, world=0.12, rim=1.2, fill=0.5, sun_rot=(58.0, 0.0, 36.0)),
}


def seed_for(level, layer):
    return level * 1000 + LAYERS.index(layer) * 137 + 7


def setup_lights(scene, level, layer):
    pal = P.BY_ID[level]["ramps"]
    sky_ref = pal.get("sky", pal.get("glow", ["#888888"]))[-1]
    accent = pal.get("accent", pal.get("glow", ["#ffffff"]))[-1]
    glow = pal.get("glow", pal.get("light", ["#ffffff"]))
    cfg = LIGHT_PRESETS[layer]
    L.set_world(scene, sky_ref, cfg["world"])
    sun_col = blend_hex(accent, "#fff6ec", 0.62) if layer != "far" else 1.0
    L.add_sun(scene, energy=cfg["sun"], rot_deg=cfg["sun_rot"],
              angle_deg=3.0 if layer != "far" else 6.0,
              color_hex=sun_col if layer != "far" else sky_ref)
    if cfg["rim"] > 0:
        # Gegenlicht von hinten: trennt Silhouetten vom Hintergrund
        L.add_area(scene, "Rim", loc=(0.0, 260.0, 40.0), size=2400.0,
                   energy=cfg["rim"] * 220.0, color_hex=glow[-1],
                   rot_deg=(-90.0, 0.0, 0.0), size_y=700.0)
    if cfg["fill"] > 0:
        L.add_area(scene, "Fill", loc=(-350.0, -520.0, 180.0), size=1800.0,
                   energy=cfg["fill"] * 200.0, color_hex=sky_ref,
                   rot_deg=(70.0, 0.0, -18.0), size_y=900.0)


def build_level(level, outdir_blend, rawdir, samples, render=True):
    builders = levels.LEVEL_BUILDERS[level]
    key = P.BY_ID[level]["key"]
    L.reset_file()
    scenes = {}
    t0 = time.time()
    for layer in LAYERS:
        scene = L.make_scene("L%02d_%s" % (level, layer),
                             transparent=(layer != "far"), samples=samples)
        rnd = random.Random(seed_for(level, layer))
        builders[layer](scene, rnd)
        setup_lights(scene, level, layer)
        scenes[layer] = scene
    t_build = time.time() - t0

    blend_path = os.path.join(outdir_blend, "%s.blend" % key)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path, compress=True)
    print("[build] %s gebaut in %.1fs -> %s" % (key, t_build, blend_path))

    if render:
        # Aus der gespeicherten Datei neu laden: nur dann sind alle
        # Weltmatrizen (u. a. der Wrap-Kopien) garantiert ausgewertet und die
        # Kacheln schliessen nahtlos aneinander an.
        bpy.ops.wm.open_mainfile(filepath=blend_path)
        scenes = {l: bpy.data.scenes["L%02d_%s" % (level, l)] for l in LAYERS}
        for layer in LAYERS:
            scene = scenes[layer]
            path = os.path.join(rawdir, "%s_%s.png" % (key, layer))
            scene.render.filepath = path
            t1 = time.time()
            with bpy.context.temp_override(scene=scene):
                bpy.ops.render.render(write_still=True)
            print("[render] %s_%s in %.1fs" % (key, layer, time.time() - t1))
    return scenes


def main():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    root = os.path.dirname(os.path.dirname(HERE))  # .../Apidya
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="1,2,3,4,5,6,7,8,9,10")
    ap.add_argument("--layers", default="far,mid,near")
    ap.add_argument("--samples", type=int, default=20)
    ap.add_argument("--no-render", action="store_true")
    ap.add_argument("--no-post", action="store_true")
    ap.add_argument("--outdir", default="assets/bg")
    ap.add_argument("--blenddir", default="assets/blender")
    ap.add_argument("--rawdir", default="tools/blender/_raw")
    args = ap.parse_args(argv)

    level_ids = [int(v) for v in args.levels.split(",") if v.strip()]
    global LAYERS
    LAYERS = tuple(v.strip() for v in args.layers.split(",") if v.strip())

    outdir = os.path.join(root, args.outdir)
    blenddir = os.path.join(root, args.blenddir)
    rawdir = os.path.join(root, args.rawdir)
    for d in (outdir, blenddir, rawdir):
        os.makedirs(d, exist_ok=True)

    t_start = time.time()
    for lv in level_ids:
        if lv not in levels.LEVEL_BUILDERS:
            print("[skip] Level %d hat noch keinen Builder" % lv)
            continue
        build_level(lv, blenddir, rawdir, args.samples,
                    render=not args.no_render)
    print("[time] Rendern gesamt: %.1fs" % (time.time() - t_start))

    if not args.no_post:
        import pixelize
        pixelize.run(root, outdir, rawdir, level_ids=level_ids)


if __name__ == "__main__":
    main()
