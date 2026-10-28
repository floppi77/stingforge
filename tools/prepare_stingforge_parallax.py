#!/usr/bin/env python3
"""Prepare only R2 parallax additions and six pinpoint foreground repairs.

No Blender, network, import, cache operation or random image model. Original artwork
is read from the immutable round2 baseline. Pillow shapes are authored below and
repeatable from fixed level seeds. Existing far/mid + four near assets are untouched.
"""
from __future__ import annotations
import argparse
from collections import deque
import hashlib
import json
import math
from pathlib import Path
import random
import numpy as np
from PIL import Image, ImageDraw, ImageColor

ROOT = Path(__file__).resolve().parents[1]
W, H, SOIL = 960, 540, 475
REPAIRS = (1, 3, 4, 5, 7, 8)
ROLES = ('haze', 'reeds', 'roots')


def rgba(color, alpha=255):
    return (*ImageColor.getrgb(color), alpha)


def islands(mask):
    """Independent flood-fill implementation; select true lowest stem endpoints."""
    seen = np.zeros(mask.shape, dtype=bool)
    h, w = mask.shape
    result = []
    for y, x in zip(*np.nonzero(mask)):
        if seen[y, x]:
            continue
        q = deque([(int(x), int(y))])
        seen[y, x] = True
        area, top, bottom, feet = 0, int(y), int(y), []
        while q:
            xx, yy = q.pop()
            area += 1
            top = min(top, yy)
            if yy > bottom:
                bottom, feet = yy, [xx]
            elif yy == bottom:
                feet.append(xx)
            for dx, dy in ((-1,-1),(0,-1),(1,-1),(-1,0),(1,0),(-1,1),(0,1),(1,1)):
                nx, ny = (xx + dx) % w, yy + dy
                if 0 <= ny < h and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((nx, ny))
        if area >= 24 and top >= 160 and bottom < SOIL:
            result.append((area, top, bottom, sorted(feet)[len(feet)//2]))
    return result


def repair_near(source, palette, level):
    original = Image.open(source).convert('RGBA')
    a = np.array(original)
    support = Image.new('RGBA', original.size)
    d = ImageDraw.Draw(support)
    dark = palette['ramps']['dark']
    stems = []
    # Existing disconnected canopy crossing y=0 is intentionally not touched.
    for area, top, bottom, x in islands(a[:SOIL+1, :, 3] >= 24):
        color = tuple(int(v) for v in a[bottom, x])
        if color[3] < 24:
            color = rgba(dark[min(1, len(dark)-1)])
        width = 3 if level not in (7, 8) else 2
        # Continue the existing anatomy, widening slightly where roots enter soil.
        end = x + (4 if level in (1, 3, 5) else 0)
        for shift in (-W, 0, W):
            d.polygon([(x+shift-width//2, bottom-1), (x+shift+width//2, bottom-1),
                       (end+shift+width, SOIL+2), (end+shift-width-1, SOIL+2)], fill=color)
            d.line([(end+shift-5, SOIL), (end+shift, SOIL-5), (end+shift+6, SOIL)],
                   fill=color, width=2)
        stems.append({'x': x, 'from_y': bottom, 'to_y': SOIL, 'island_area': area})
    # Only two source assets have a floor that is still below the new HUD boundary.
    # Raise a slim continuous material ledge, not an opaque full-screen fallback.
    if level in (7, 8):
        material = rgba(dark[-1])
        for x in range(W):
            top = 468 + round(2 * math.sin(2*math.pi*x/(W-1)))
            d.line((x, top, x, H-1), fill=material)
    # Support is BEHIND the existing pixels: artwork/shading never repainted.
    support.alpha_composite(original)
    return support, stems


def leaf(d, x, y, lean, height, width, color):
    # A leaf always includes its own stalk down to y (the shared root socket).
    d.polygon([(x-2,y), (x+2,y), (x+lean+width//2,y-height//2),
               (x+lean,y-height), (x+lean-width//2,y-height//2)], fill=color)


def motif(d, n, x, soil, rng, material, light, large):
    """Ten deliberate silhouettes: leaf, root, reed, cap, thorn, pot, pipe, beam, cell, crystal."""
    height = rng.randint(38, 86) if large else rng.randint(12, 29)
    if n in (1, 3, 5):
        for blade in range(3 if large else 2):
            lean = rng.randint(-22, 22)
            h = height + rng.randint(-10, 9)
            leaf(d, x+blade*4, soil, lean, h, 11 if n == 1 else 4, material)
            if n == 3 and blade == 1:
                tip = (x+blade*4+lean, soil-h)
                d.rounded_rectangle((tip[0]-2,tip[1]-10,tip[0]+2,tip[1]+2), 2, fill=light)
            if n == 5:
                d.line((x, soil+1, x, soil-h//2), fill=material, width=3)
                d.polygon([(x,soil-h//2),(x+13,soil-h//2-8),(x+3,soil-h//2+5)], fill=material)
    elif n == 2:
        # Tapered branching root crown; both arch ends enter the soil.
        d.line([(x-25,soil+4),(x-12,soil-height//2),(x,soil-height),
                (x+14,soil-height//2),(x+30,soil+4)], fill=material, width=7 if large else 4)
        d.line([(x,soil-height),(x-8,soil-height+4),(x-32,soil-height+14)],fill=material,width=3)
    elif n == 4:
        d.polygon([(x-4,soil+3),(x+4,soil+3),(x+2,soil-height-4),(x-2,soil-height-4)],fill=material)
        d.pieslice((x-19,soil-height-12,x+19,soil-height+8),180,360,fill=material)
        d.line((x-12,soil-height-5,x+7,soil-height-8),fill=light,width=2)
    elif n == 6:
        pot = soil-13
        d.polygon([(x-12,pot),(x+12,pot),(x+8,soil+2),(x-8,soil+2)],fill=material)
        leaf(d,x,pot+2,-9,height-10,12,material)
        leaf(d,x+2,pot+2,12,height-17,10,light)
    elif n == 7:
        d.line([(x-15,soil+3),(x-15,soil-height),(x+15,soil-height),(x+15,soil+3)],fill=material,width=6)
        d.line((x-12,soil-height+2,x+12,soil-height+2),fill=light,width=1)
        d.rectangle((x-20,soil-4,x+20,soil+3),fill=material)
    elif n == 8:
        d.polygon([(x-17,soil+3),(x-11,soil-height),(x-5,soil-height),
                   (x+1,soil+3)],fill=material)
        d.polygon([(x+2,soil+3),(x+10,soil-height+8),(x+16,soil-height+8),
                   (x+20,soil+3)],fill=material)
        d.rectangle((x-19,soil-height+8,x+22,soil-height+13),fill=material)
        d.ellipse((x-7,soil-height+9,x-3,soil-height+13),fill=light)
    elif n == 9:
        cy, r = soil-height+19, 18 if large else 10
        pts=[(x+round(math.cos(k*math.pi/3)*r),cy+round(math.sin(k*math.pi/3)*r)) for k in range(6)]
        d.line(pts+[pts[0]],fill=material,width=4)
        d.polygon([(x-4,cy+r-2),(x+4,cy+r-2),(x+8,soil+3),(x-8,soil+3)],fill=material)
    else:
        d.polygon([(x-13,soil+3),(x-8,soil-height//2),(x+2,soil-height),
                   (x+10,soil-height//2),(x+17,soil+3)],fill=material)
        d.line((x+2,soil-height+5,x+8,soil-9),fill=light,width=2)


def depth_asset(n, role, palette):
    img=Image.new('RGBA',(W,H))
    d=ImageDraw.Draw(img)
    ramps=palette['ramps']
    rng=random.Random(72191+n*107+ROLES.index(role)*7919)
    if role == 'haze':
        # Broad distant vapour ribbons, not a duplicated ground silhouette.
        color=rgba(ramps['sky'][-2], 45)
        for band in range(3):
            points=[]
            for x in range(W):
                y=184+band*43+round(7*math.sin(2*math.pi*x/(W-1)+band)+3*math.sin(6*math.pi*x/(W-1)))
                points.append((x,y))
            d.polygon(points+[(x,y+4+band*2) for x,y in reversed(points)],fill=color)
    else:
        material=rgba(ramps['dark'][-1] if role=='roots' else ramps.get('ground',ramps['sky'])[0])
        accent=ramps.get('reed',ramps.get('leaf',ramps.get('frame',ramps.get('hive',ramps.get('crystal',ramps['sky'])))))
        light=rgba(accent[min(1,len(accent)-1)])
        for x in range(W):
            top=467+round(3*math.sin(4*math.pi*x/(W-1))+2*math.sin(10*math.pi*x/(W-1))) if role=='reeds' else 470+round(2*math.sin(6*math.pi*x/(W-1)))
            d.line((x,top,x,H-1),fill=material)
        spacing=145 if role=='reeds' else 105
        for x in range(-20,W+30,spacing):
            # Wrap one authored motif, including its random shape, at both boundaries.
            state=rng.getstate()
            for shift in (-W,0,W):
                rng.setstate(state)
                motif(d,n,x+shift,471,rng,material,light,role=='reeds')
    # Pixel art is periodic at the exact first/last texel (no filtering seam).
    img.paste(img.crop((0,0,1,H)),(W-1,0))
    return img


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,default=ROOT/'build/stingforge-round2-baseline/assets/bg')
    p.add_argument('--output',type=Path,default=ROOT/'assets/bg')
    p.add_argument('--report',type=Path,default=ROOT/'build/stingforge-r2-parallax/prepare.json')
    args=p.parse_args()
    source=args.source.resolve()
    output=args.output.resolve()
    baseline=(ROOT/'build/stingforge-round2-baseline').resolve()
    if source == output or source in output.parents or output == baseline or baseline in output.parents:
        p.error('Output must not be the immutable baseline or inside it')
    palettes=json.loads((source/'palettes.json').read_text(encoding='utf-8'))
    output.mkdir(parents=True,exist_ok=True)
    report={'seed':72191,'soil_row':SOIL,'repairs':{},'files':[]}
    for n in range(1,11):
        key=f'l{n:02d}'
        pal=palettes[key]
        if n in REPAIRS:
            image, stems=repair_near(source/f'{key}_near.png',pal,n)
            dest=output/f'{key}_near.png'
            image.save(dest)
            report['repairs'][dest.name]=stems
            report['files'].append(str(dest))
        for role in ROLES:
            dest=output/f'{key}_{role}.png'
            depth_asset(n,role,pal).save(dest)
            report['files'].append(str(dest))
    report['sha256']={str(Path(x).relative_to(output)):hashlib.sha256(Path(x).read_bytes()).hexdigest() for x in report['files']}
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(f'Prepared {len(report["files"])} PNGs; baseline untouched; no Godot import performed.')


if __name__=='__main__':
    main()
