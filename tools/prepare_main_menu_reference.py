#!/usr/bin/env python3
"""Übernimmt Nutzergrafik unverändert und isoliert den Titel der Layoutvorlage.

Kein generierter Hintergrund und keine eingebrannten Menü-/Profilwerte.
Die Titelmaske entsteht aus dem Unterschied zur vom Nutzer gelieferten
identischen Hintergrundaufnahme.
"""
from pathlib import Path
import argparse
import hashlib
import shutil
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("background", type=Path)
    p.add_argument("layout", type=Path)
    args = p.parse_args()
    target = ROOT / "assets/ui/menu"
    docs = ROOT / "docs/ui-reference"
    target.mkdir(parents=True, exist_ok=True)
    docs.mkdir(parents=True, exist_ok=True)
    bg = Image.open(args.background).convert("RGB")
    reference = Image.open(args.layout).convert("RGB")
    assert bg.size == reference.size == (1672, 941)
    # Beide Bilder zeigen exakt dieselbe Szene. Nur der eigentliche Titel wird
    # übernommen, nicht der Untertitel und keine Bedienelemente.
    bounds = (34, 38, 704, 239)
    base = np.asarray(bg.crop(bounds)).astype(np.int16)
    logo = np.asarray(reference.crop(bounds)).astype(np.int16)
    diff = np.max(np.abs(logo - base), axis=2)
    r, g, b = logo[:, :, 0], logo[:, :, 1], logo[:, :, 2]
    gold = (r > 52) & (r > g * 0.98) & (g > b * 1.07)
    highlight = (r > 185) & (g > 165) & (r >= g * 0.96) & (b > 100)
    gold |= highlight
    yy, xx = np.indices(diff.shape)
    region = (xx + bounds[0] >= 55) & (xx + bounds[0] <= 678) & (yy + bounds[1] >= 48) & (yy + bounds[1] <= 229)
    alpha = np.where((diff > 3) & gold & region, 255, 0).astype(np.uint8)
    # Schmale dunkle Metallfasen erhalten und Löcher in hellen Glanzkanten schließen.
    alpha = np.asarray(Image.fromarray(alpha).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3)))
    alpha = np.where(region, alpha, 0).astype(np.uint8)
    # Die Layoutaufnahme ist leicht nachbearbeitet: zusätzlich den Goldfarbbereich
    # isolieren, damit keine Blätter oder rechteckige Hintergrundreste mitkommen.
    rgba = np.dstack([logo.astype(np.uint8), alpha])
    Image.fromarray(rgba).save(target / "title_gold.png")
    shutil.copyfile(args.background, target / "hero.png")
    shutil.copyfile(args.background, docs / "background_source.png")
    shutil.copyfile(args.layout, docs / "layout_reference.png")
    print("Hintergrund bytegleich:", hashlib.sha256((target / "hero.png").read_bytes()).hexdigest())
    print("Titel:", bounds, "sichtbare Pixel:", int((alpha > 0).sum()))


if __name__ == "__main__":
    main()
