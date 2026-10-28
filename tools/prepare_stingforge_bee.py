#!/usr/bin/env python3
"""Draw the Stingforge bee, with an editable layered Aseprite as source of truth.

No generated imagery or model is used. Shapes, wing veins, fur clusters and eye
facets are deliberately placed in a fixed 40x32 registration. Re-running is
fully deterministic. Only bee.png / bee.aseprite and the visual evidence folder
are written. Godot import is deliberately left to the coordinated import pass.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import shutil
import struct
import subprocess
import zlib

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SIZE = (40, 32)
FRAMES = 6
FPS = 14
S = 4  # Subpixel ink for translucent veins; the actual delivered art is 40x32.
LAYERS = ("01 Translucent veined wings", "02 Articulated legs", "03 Gold fur and dark bands",
          "04 Compound eye and face", "05 Fine antennae")
INK = (24, 22, 24, 255)
GOLD = (232, 163, 50, 255)
LIGHT = (255, 220, 126, 255)


def canvas() -> Image.Image:
    return Image.new("RGBA", (SIZE[0] * S, SIZE[1] * S))


def xy(points):
    return [(round(x * S), round(y * S)) for x, y in points]


def line(draw, points, color, width=0.5):
    draw.line(xy(points), fill=color, width=max(1, round(width * S)), joint="curve")


def ellipse(draw, box, fill, outline=None, width=0.5):
    draw.ellipse(tuple(round(v * S) for v in box), fill=fill, outline=outline,
                 width=max(1, round(width * S)))


def polygon(draw, points, fill):
    draw.polygon(xy(points), fill=fill)


def finish(image):
    return image.resize(SIZE, Image.Resampling.LANCZOS)


def wing(draw, root, tip, breadth, tint):
    """Tapered translucent membrane with branching anatomical veins."""
    rx, ry = root
    tx, ty = tip
    dx, dy = tx - rx, ty - ry
    length = math.hypot(dx, dy)
    nx, ny = -dy / length * breadth, dx / length * breadth
    point = lambda t, n=0: (rx + dx * t + nx * n, ry + dy * t + ny * n)
    outline = [point(0), point(.35, .56), point(.72, .66), point(.96, .3),
               point(1), point(.94, -.3), point(.68, -.57), point(.28, -.32)]
    polygon(draw, outline, tint)
    line(draw, outline + [outline[0]], (220, 230, 209, 160), .42)
    line(draw, [root, point(.5, -.08), tip], (244, 229, 178, 175), .38)
    # Thin ribs: intentional lines, not noisy white pixels.
    for t in (.35, .56, .76):
        line(draw, [point(t, -.06), point(min(.94, t + .15), .54)], (176, 190, 173, 140), .28)
        line(draw, [point(t, -.06), point(min(.94, t + .1), -.46)], (189, 205, 192, 125), .28)
    line(draw, [point(.3, .4), point(.55, .43), point(.75, .44), point(.92, .2)],
         (255, 244, 206, 150), .3)


def wings(frame):
    image = canvas()
    d = ImageDraw.Draw(image)
    # Six unique flap poses; body/eye registration never bobs or scales.
    near_tips = [(9, 1.8), (6.5, 5.5), (5, 12), (10, 28), (7, 22), (8, 7.5)]
    far_tips = [(30.5, 2.3), (33, 5), (35, 11), (31.8, 26.8), (35, 20.5), (32.5, 7)]
    wing(d, (23, 14), far_tips[frame], 2.7, (171, 202, 191, 95))
    wing(d, (21, 14.5), near_tips[frame], 3.2, (216, 229, 214, 120))
    # Warm roots visually connect wings to the thorax, not floating shards.
    ellipse(d, (20, 12, 24, 16), (170, 132, 69, 200))
    return finish(image)


def legs(frame):
    image = canvas()
    d = ImageDraw.Draw(image)
    # Delicate hooked legs stay within the original 40x32 cell.
    posed = [([(12, 22), (10.3, 26), (13.5, 28.2), (15.2, 27.4)], .4),
             ([(21, 22), (20, 27), (22.5, 30), (25, 29.3)], -.25),
             ([(27, 21), (30, 24), (29, 27), (32, 27.4)], .2)]
    for points, amount in posed:
        pts = [(x, y + math.sin(frame * math.tau / FRAMES) * amount) for x, y in points]
        line(d, pts, (15, 17, 21, 255), 1.3)
        line(d, [(x - .25, y - .3) for x, y in pts[:-1]], (192, 131, 57, 255), .45)
        ellipse(d, (pts[1][0] - .7, pts[1][1] - .7, pts[1][0] + .7, pts[1][1] + .7), INK)
    return finish(image)


def abdomen_mask():
    mask = Image.new("L", (SIZE[0] * S, SIZE[1] * S))
    d = ImageDraw.Draw(mask)
    ellipse(d, (3.3, 12.5, 23.2, 25.7), 255)
    return mask


def body():
    image = canvas()
    d = ImageDraw.Draw(image)
    # Tail/sting, back silhouette, and an amber underlit abdomen.
    polygon(d, [(1, 21.5), (5.4, 19.6), (5.2, 22.8)], INK)
    line(d, [(1.7, 21.3), (5, 20.6)], (239, 177, 76, 255), .45)
    mask = abdomen_mask()
    fill = Image.new("RGBA", image.size)
    px = fill.load()
    for y in range(image.height):
        for x in range(image.width):
            fx, fy = x / S, y / S
            # Cool ventral shadows; warm pale fur toward the key light.
            lit = max(0, min(1, 1 - (fy - 13) / 14))
            curved = fx + .10 * (fy - 18) ** 2
            dark = (7.1 < curved < 9.9) or (13.1 < curved < 16.5) or curved < 4.5
            if dark:
                px[x, y] = (round(27 + lit * 27), round(24 + lit * 23), round(25 + lit * 14), 255)
            else:
                px[x, y] = (round(142 + lit * 108), round(78 + lit * 126), round(25 + lit * 58), 255)
    image.paste(fill, (0, 0), mask)
    d = ImageDraw.Draw(image)
    # Broad lit arc and fine fur along each dark-band boundary.
    line(d, [(5.2, 16.7), (7, 14.9), (11.2, 13.7), (16.8, 13.7), (20.5, 15)], LIGHT, .5)
    for x, y in [(5, 15.7), (6, 15), (10.3, 14.1), (11.4, 13.5), (12.3, 13.5),
                 (17, 14), (18.1, 14.2), (4.4, 18), (5, 23), (10.5, 24.5), (17.4, 24)]:
        line(d, [(x - .5, y + .7), (x + .4, y - .6)], (255, 207, 108, 255), .45)
    # Thorax: a strong gold-furred mass, with darker tucked underside.
    ellipse(d, (16, 10.7, 28.2, 24.7), (72, 46, 25, 255))
    ellipse(d, (16.3, 10.6, 27.5, 23.4), GOLD)
    ellipse(d, (17.5, 11.2, 25.9, 20.5), (244, 190, 74, 255))
    ellipse(d, (18.2, 12, 24.4, 17.9), (251, 210, 109, 255))
    # Deliberate radial fur tufts (stable seed, no per-frame surface crawl).
    rng = random.Random(76014)
    for i in range(40):
        angle = math.tau * i / 40
        cx, cy = 22, 17.2
        rx, ry = 5.5, 6.1
        x, y = cx + math.cos(angle) * rx, cy + math.sin(angle) * ry
        length = rng.uniform(.55, 1.25)
        color = LIGHT if math.sin(angle) < .1 else (186, 117, 34, 255)
        line(d, [(x - math.cos(angle) * .5, y - math.sin(angle) * .5),
                 (x + math.cos(angle) * length, y + math.sin(angle) * length)], color, .4)
    for x, y in [(18.5, 14), (21, 12), (23, 13), (19.3, 17), (23, 16), (20.7, 19),
                 (24.4, 19), (18.7, 21), (23, 21.5)]:
        line(d, [(x - .4, y + .6), (x + .3, y - .6)], (255, 223, 143, 255), .45)
    # Head contour and golden cheeks. Eye is separate and editable.
    ellipse(d, (24, 10, 35.8, 23), (36, 29, 25, 255))
    ellipse(d, (24.6, 10.4, 35.1, 22.5), (220, 149, 41, 255))
    ellipse(d, (25, 10.8, 32.5, 20.2), (246, 191, 70, 255))
    line(d, [(26.2, 12), (27.3, 10.6), (29.1, 10.1)], LIGHT, .7)
    return finish(image)


def face():
    image = canvas()
    d = ImageDraw.Draw(image)
    # Large dark compound eye is the focal point, not a bright cartoon pupil.
    ellipse(d, (28.1, 11, 34.3, 20.8), (17, 19, 25, 255))
    ellipse(d, (28.4, 11.4, 33.6, 20.1), (28, 32, 41, 255))
    ellipse(d, (28.7, 11.7, 32.7, 18.8), (39, 44, 53, 255))
    for x, y in [(29.8, 15.1), (31.2, 15.8), (32, 17.4), (30.3, 18.1), (31.7, 13.4)]:
        polygon(d, [(x, y - .45), (x + .45, y), (x, y + .45), (x - .45, y)],
                (67, 70, 75, 255))
    ellipse(d, (29.1, 12.1, 30.9, 14.3), (223, 233, 228, 255))
    ellipse(d, (29.4, 12.3, 30.4, 13.3), (255, 247, 211, 255))
    line(d, [(33.2, 16.1), (33, 18.3), (31.9, 19.6)], (75, 79, 84, 255), .4)
    # Tucked mandibles and forward golden muzzle, with no changed muzzle origin.
    polygon(d, [(33.5, 19.3), (37.1, 20.2), (36, 22.1), (33.1, 22.5), (31.8, 21.1)], GOLD)
    line(d, [(34.2, 21), (36, 21.3), (35.1, 23), (33.8, 23.3)], INK, .8)
    line(d, [(34.8, 19.8), (36.2, 20.2)], LIGHT, .45)
    return finish(image)


def antennae():
    image = canvas()
    d = ImageDraw.Draw(image)
    for pts in [[(29, 11), (29.1, 7.9), (32.5, 5.2), (34.9, 5.7)],
                [(32.8, 12), (35.3, 8.9), (38.1, 9.4)]]:
        line(d, pts, (16, 20, 24, 255), 1.15)
        line(d, [(x, y - .25) for x, y in pts], (209, 176, 106, 255), .35)
        x, y = pts[-1]
        ellipse(d, (x - .5, y - .5, x + .5, y + .5), (50, 40, 28, 255))
    return finish(image)


def chunk(kind, data):
    return struct.pack("<IH", len(data) + 6, kind) + data


def ase_string(text):
    raw = text.encode("utf8")
    return struct.pack("<H", len(raw)) + raw


def write_aseprite(path, frames):
    """Small standards-based RGBA encoder: independent compressed layered cels."""
    blocks = []
    durations = []
    for index, layers in enumerate(frames):
        chunks = []
        duration = round((index + 1) * 1000 / FPS) - round(index * 1000 / FPS)
        durations.append(duration)
        if index == 0:
            for name in LAYERS:
                chunks.append(chunk(0x2004, struct.pack("<HHHHHHB3x", 1, 0, 0, 0, 0, 0, 255) + ase_string(name)))
            tag = struct.pack("<H8xHHBH6x3BB", 1, 0, FRAMES - 1, 0, 0, 243, 203, 117, 0) + ase_string("flight")
            chunks.append(chunk(0x2018, tag))
        for layer, image in enumerate(layers):
            cel = struct.pack("<HhhBHh5xHH", layer, 0, 0, 255, 2, 0, *SIZE)
            chunks.append(chunk(0x2005, cel + zlib.compress(image.tobytes(), 9)))
        data = b"".join(chunks)
        blocks.append(struct.pack("<IHHH2xI", len(data) + 16, 0xF1FA, len(chunks), duration, 0) + data)
    header = bytearray(128)
    struct.pack_into("<IHHHHHI", header, 0, 128 + sum(map(len, blocks)), 0xA5E0,
                     FRAMES, *SIZE, 32, 1)
    struct.pack_into("<H", header, 18, durations[0])
    struct.pack_into("<BB", header, 34, 1, 1)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + b"".join(blocks))
    return durations


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-root", type=Path, default=ROOT)
    args = parser.parse_args()
    root = args.output_root.resolve()
    evidence = root / "build/stingforge-visual"
    evidence.mkdir(parents=True, exist_ok=True)
    src = root / "assets/aseprite/bee.aseprite"
    png = root / "assets/sprites/bee.png"
    png.parent.mkdir(parents=True, exist_ok=True)
    fixed_body, fixed_face, fixed_antennae = body(), face(), antennae()
    frames = [[wings(i), legs(i), fixed_body, fixed_face, fixed_antennae] for i in range(FRAMES)]
    durations = write_aseprite(src, frames)
    aseprite = shutil.which("aseprite")
    if not aseprite:
        raise SystemExit("Aseprite CLI is required for source-identical final export; no PNG was exported.")
    subprocess.run([aseprite, "--batch", str(src), "--sheet-type", "horizontal",
                    "--sheet", str(png)], check=True)
    sheet = Image.open(png).convert("RGBA")
    if sheet.size != (SIZE[0] * FRAMES, SIZE[1]):
        raise SystemExit(f"Unexpected sheet dimensions: {sheet.size}")
    # Evidence is generated at native resolution; inspection tools can enlarge it.
    # An animated evidence GIF is intentionally separate from the production files.
    gif_frames = []
    for i in range(FRAMES):
        background = Image.new("RGBA", SIZE, (21, 37, 44, 255))
        background.alpha_composite(sheet.crop((i * 40, 0, (i + 1) * 40, 32)))
        gif_frames.append(background.convert("RGB"))
    gif_frames[0].save(evidence / "bee-flight.gif", save_all=True, append_images=gif_frames[1:],
                       duration=durations, loop=0)
    report = {"size": list(SIZE), "sheet": list(sheet.size), "frames": FRAMES,
              "game_fps": FPS, "aseprite_durations_ms": durations, "layers": list(LAYERS),
              "registration": [20, 16], "hit_radius_unchanged": 4.6,
              "png_sha256": hashlib.sha256(png.read_bytes()).hexdigest(),
              "source_sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
              "import_required": "assets/sprites/bee.png"}
    (evidence / "bee-build.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
