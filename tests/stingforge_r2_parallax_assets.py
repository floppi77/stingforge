#!/usr/bin/env python3
"""Public asset contract: foreground anatomy must meet visible soil, also across tiles.

The seam is source PNG alpha + the world crop at PLAY_BOTTOM (agreed in R2).
No screenshot-changed assertion is accepted as a substitute for physical support.
"""
from __future__ import annotations
import argparse
from collections import deque
import json
from pathlib import Path
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BOTTOM = 476


def components(mask: np.ndarray) -> list[dict]:
    """8-connected alpha islands using run-length union; includes horizontal tile wrap."""
    parents, boxes, rows = [], [], []
    def root(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i
    def union(a, b):
        a, b = root(a), root(b)
        if a != b:
            parents[b] = a
    for y, row in enumerate(mask):
        edges = np.flatnonzero(np.diff(np.r_[False, row, False]))
        runs = []
        for x0, end in zip(edges[::2], edges[1::2]):
            i = len(parents)
            parents.append(i)
            boxes.append((int(x0), y, int(end - 1), y, int(end - x0)))
            runs.append((int(x0), int(end - 1), i))
        if runs and runs[0][0] == 0 and runs[-1][1] == mask.shape[1] - 1:
            union(runs[0][2], runs[-1][2])
        if rows:
            prev = rows[-1]
            j = 0
            for left, right, i in runs:
                while j < len(prev) and prev[j][1] < left - 1:
                    j += 1
                k = j
                while k < len(prev) and prev[k][0] <= right + 1:
                    union(i, prev[k][2])
                    k += 1
            # Diagonal neighbours across the horizontal scroll seam.
            if prev and runs:
                if runs[0][0] == 0 and prev[-1][1] == mask.shape[1] - 1:
                    union(runs[0][2], prev[-1][2])
                if prev[0][0] == 0 and runs[-1][1] == mask.shape[1] - 1:
                    union(prev[0][2], runs[-1][2])
        rows.append(runs)
    groups = {}
    for i, (x0, y0, x1, y1, area) in enumerate(boxes):
        key = root(i)
        if key not in groups:
            groups[key] = {"x0": x0, "y0": y0, "x1": x1, "y1": y1, "area": area}
        else:
            b = groups[key]
            b.update(x0=min(b['x0'], x0), y0=min(b['y0'], y0),
                     x1=max(b['x1'], x1), y1=max(b['y1'], y1), area=b['area'] + area)
    return list(groups.values())


def inspect(path: Path, ground_y: int = BOTTOM - 1, min_area: int = 24) -> dict:
    rgba = np.array(Image.open(path).convert('RGBA'))
    mask = rgba[:, :, 3] >= 24
    islands = components(mask[:ground_y + 1])
    floating = [b for b in islands if b['area'] >= min_area and b['y0'] >= 160
                and b['y1'] < ground_y]
    return {"path": str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path),
            "size": list(Image.open(path).size), "ground_row": ground_y,
            "ground_coverage": float(mask[ground_y].mean()),
            "floating": floating, "islands": len(islands)}


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument('--root', type=Path, default=ROOT)
    p.add_argument('--output', type=Path)
    p.add_argument('--originals-only', action='store_true')
    args = p.parse_args()
    errors, reports = [], []
    for n in range(1, 11):
        path = args.root / 'assets/bg' / f'l{n:02d}_near.png'
        r = inspect(path)
        reports.append(r)
        if r['ground_coverage'] != 1.0:
            errors.append(f"{path.name}: visible soil does not cover x=0..959 at y=475 ({r['ground_coverage']:.3f})")
        if r['floating']:
            errors.append(f"{path.name}: {len(r['floating'])} unsupported foreground islands: {r['floating'][:4]}")
    if not args.originals_only:
        hashes = set()
        for n in range(1, 11):
            for role in ('haze', 'reeds', 'roots'):
                path = args.root / 'assets/bg' / f'l{n:02d}_{role}.png'
                if not path.exists():
                    errors.append(f'{path.name}: missing depth asset')
                    continue
                rgba = np.array(Image.open(path).convert('RGBA'))
                if rgba.shape != (540, 960, 4):
                    errors.append(f'{path.name}: wrong canvas')
                if not np.array_equal(rgba[:, 0], rgba[:, -1]):
                    errors.append(f'{path.name}: RGBA tile edge mismatch')
                fingerprint = rgba.tobytes()
                if fingerprint in hashes:
                    errors.append(f'{path.name}: duplicate image reused as depth')
                hashes.add(fingerprint)
                if role != 'haze':
                    r = inspect(path)
                    reports.append(r)
                    if r['ground_coverage'] != 1.0 or r['floating']:
                        errors.append(f'{path.name}: unsupported geometry / soil gap: {r}')
                if rgba[56:360, :, 3].mean() > 24:
                    errors.append(f'{path.name}: opaque geometry intrudes into flight corridor')
    report = {"errors": errors, "assets": reports, "passed": not errors}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2), encoding='utf-8')
    for error in errors:
        print('PARALLAX_ASSET_FAIL:', error)
    print(f"PARALLAX_ASSETS {'OK' if not errors else 'RED'}: {len(reports)} measured assets, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
