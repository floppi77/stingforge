#!/usr/bin/env python3
"""Hand-authored pixel composition of the existing core into a crowned winged form.

Only new boss_reborn PNG/ASEPRITE assets are written. No Godot import, manifest
or cache edit. Six RGBA cels (three phases, two poses) in a layered Aseprite file.
Crown, wings and spikes are opaque body pixels, hence participate in Boss masks.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct
import zlib
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SIZE = (224, 224)
LAYERS = ("01 Articulated six wings", "02 Original core chassis", "03 Crown and broken shell", "04 Exposed heart and etched seams")
INK = "#151523"
STEEL = "#45465c"
EDGE = "#858c99"
GOLD = "#ba7946"
LIT = "#f4d493"
PINK = "#d957b8"
PALE = "#ffd7ec"


def empty():
    return Image.new("RGBA", SIZE)


def plate(draw, points, fill, shine=LIT):
    draw.polygon(points, fill=INK)
    cx = sum(x for x, y in points) / len(points)
    cy = sum(y for x, y in points) / len(points)
    inset = [(round(cx + (x - cx) * .84), round(cy + (y - cy) * .84)) for x, y in points]
    draw.polygon(inset, fill=fill)
    draw.line(inset[:3], fill=shine, width=2)


def wings(phase, frame):
    im = empty()
    d = ImageDraw.Draw(im)
    lift = [-3, 3][frame]
    # Three physical vanes on each side, with a darker rib and tapered bright edge.
    for side in (-1, 1):
        def p(x, y):
            return (112 + side * x, y)
        spread = phase * 3
        shapes = [
            [p(28, 84), p(60, 51 + lift), p(98 + spread, 34 + lift), p(86, 70), p(47, 106)],
            [p(35, 107), p(85, 83 - lift), p(104, 91 - lift), p(91, 116), p(43, 126)],
            [p(32, 128), p(83, 139 + lift), p(98 + spread, 178 + lift), p(65, 165), p(27, 145)],
        ]
        for n, poly in enumerate(shapes):
            plate(d, poly, ("#634363", "#69375e", "#543953")[n], EDGE)
            root = p(34, 104 + n * 7)
            tip = poly[2]
            d.line([root, tip], fill=GOLD, width=3)
            d.line([(root[0], root[1]-2), (tip[0], tip[1]-2)], fill=LIT, width=1)
            mid = ((root[0]+tip[0])//2, (root[1]+tip[1])//2)
            for off in (-4, 4):
                d.line([mid, (mid[0]+side*12, mid[1]+off)], fill=PINK, width=2)
        # Joint housings attach the new vanes to the old chassis.
        for y in (88, 114, 140):
            x = 112 + side * 46
            d.ellipse((x-6, y-6, x+6, y+6), fill=INK, outline=EDGE, width=2)
    return im


def crown(phase, frame):
    im = empty()
    d = ImageDraw.Draw(im)
    # Not a halo: connected chitin crown and hooked lower shell form a new body.
    for side in (-1, 1):
        def p(x, y):
            return (112 + side*x, y)
        plate(d, [p(8, 65), p(21, 26), p(39, 48), p(46, 15-phase*3), p(55, 61), p(42, 77)], GOLD)
        plate(d, [p(13, 153), p(39, 158), p(55, 190), p(31, 180), p(17, 197+phase*4), p(7, 172)], STEEL, EDGE)
        plate(d, [p(46, 79), p(75, 64), p(68, 93), p(50, 105)], STEEL, LIT)
        plate(d, [p(48, 125), p(77, 132), p(65, 154), p(39, 145)], STEEL, EDGE)
        if phase >= 1:
            plate(d, [p(45, 107), p(92, 109), p(75, 122), p(42, 120)], GOLD)
        if phase == 2:
            plate(d, [p(18, 59), p(8, 8), p(1, 41), p(0, 66)], "#96579e", PALE)
    # Central crest grows and splits in the final phase.
    plate(d, [(96, 64), (103, 31-phase*4), (112, 13), (122, 30-phase*4), (128, 64)], STEEL, LIT)
    for x in (100, 124):
        d.line([(x, 69), (x, 52)], fill=PINK if frame == 0 else PALE, width=2)
    return im


def heart(phase, frame):
    im = empty()
    d = ImageDraw.Draw(im)
    # New angular reactor shield wraps the recognizable circular original core.
    plate(d, [(80, 85), (101, 74), (133, 74), (146, 94), (140, 129), (123, 146), (97, 141), (78, 123)], "#452746", GOLD)
    r = 22 + frame
    d.ellipse((112-r, 111-r, 112+r, 111+r), fill=INK, outline=PALE, width=2)
    d.ellipse((94, 93, 130, 129), fill="#a9328d", outline=PINK, width=3)
    d.ellipse((101, 100, 123, 122), fill="#fa7ac7", outline=PALE, width=2)
    d.ellipse((106, 103, 117, 114), fill="#fff2e6")
    d.line([(97, 132), (112, 140), (127, 132)], fill=LIT, width=2)
    # Three independent engraving patterns, not just hue changes.
    for side in (-1, 1):
        x = 112 + side*29
        for n in range(phase+1):
            y = 89+n*14
            d.line([(x, y), (x+side*10, y+4), (x+side*14, y+1)], fill=PALE, width=2)
    if phase >= 1:
        for side in (-1, 1):
            x = 112+side*42
            d.polygon([(x-3, 102), (x+3, 102), (x+5, 121), (x, 129), (x-5, 121)], fill="#8fd5ca", outline=INK)
    if phase == 2:
        d.line([(98, 77), (107, 86), (105, 94)], fill=PALE, width=2)
        d.line([(130, 77), (121, 86), (124, 94)], fill=PALE, width=2)
    return im


def chunk(kind, data):
    return struct.pack("<IH", len(data)+6, kind)+data


def text(value):
    raw = value.encode("utf8")
    return struct.pack("<H", len(raw))+raw


def write_aseprite(path, frames):
    blocks = []
    for index, layers in enumerate(frames):
        chunks = []
        if index == 0:
            for name in LAYERS:
                chunks.append(chunk(0x2004, struct.pack("<HHHHHHB3x", 1, 0, 0, 0, 0, 0, 255)+text(name)))
            tags = struct.pack("<H8x", 3)
            for phase in range(3):
                tags += struct.pack("<HHBH6x3BB", phase*2, phase*2+1, 0, 0, 245, 190, 130, 0)+text(f"phase_{phase+1}")
            chunks.append(chunk(0x2018, tags))
        for layer, image in enumerate(layers):
            cel = struct.pack("<HhhBHh5xHH", layer, 0, 0, 255, 2, 0, *SIZE)
            chunks.append(chunk(0x2005, cel+zlib.compress(image.tobytes(), 9)))
        data = b"".join(chunks)
        blocks.append(struct.pack("<IHHH2xI", len(data)+16, 0xF1FA, len(chunks), 180 if index % 2 == 0 else 140, 0)+data)
    header = bytearray(128)
    struct.pack_into("<IHHHHHI", header, 0, 128+sum(map(len, blocks)), 0xA5E0, 6, *SIZE, 32, 1)
    struct.pack_into("<H", header, 18, 180)
    struct.pack_into("<BB", header, 34, 1, 1)
    path.write_bytes(header+b"".join(blocks))


def main():
    source = Image.open(ROOT / "assets/sprites/boss_core.png").convert("RGBA")
    frames = []
    report = []
    for phase in range(3):
        strip = Image.new("RGBA", (448, 224))
        for frame in range(2):
            original = empty()
            original.alpha_composite(source.crop((frame*176, 0, (frame+1)*176, 144)), (24, 40))
            layers = [wings(phase, frame), original, crown(phase, frame), heart(phase, frame)]
            frames.append(layers)
            composite = empty()
            for layer in layers:
                composite.alpha_composite(layer)
            strip.alpha_composite(composite, (frame*224, 0))
        path = ROOT / f"assets/sprites/boss_reborn_p{phase+1}.png"
        strip.save(path)
        report.append({"path": str(path.relative_to(ROOT)), "size": list(strip.size), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    ase = ROOT / "assets/aseprite/boss_reborn.aseprite"
    write_aseprite(ase, frames)
    print(json.dumps({"assets": report, "aseprite": str(ase.relative_to(ROOT)), "frame_size": list(SIZE), "frames_per_phase": 2, "import": "MAIN ONLY"}, indent=2))


if __name__ == "__main__":
    main()
