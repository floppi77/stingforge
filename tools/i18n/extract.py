#!/usr/bin/env python3
"""Sammelt alle sichtbaren deutschen Texte aus den Spielskripten (Literale und Loc-Tabelle).

Aufruf: python3 tools/i18n/extract.py [--missing]
Ohne Schalter: Liste aller Kandidaten. Mit --missing: nur Texte ohne Eintrag in
assets/i18n/en.json (Deutsch -> Englisch).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EN = ROOT / 'assets/i18n/en.json'
LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')
GERMAN = re.compile(r'[äöüÄÖÜß]|\b(der|die|das|den|dem|des|und|oder|mit|nicht|ein|eine|einen|einem|zur|zum|auf|für|bei|vom|von|im|ist|sind|wird|werden|kein|keine|noch|nur|alle|jede|jeder|Stufe|Leben|Schuss|Schüsse|Gegner|Treffer|Biene|Punkte|Blütenstaub|Werkstatt|Evolution|Waffe|Schild|Bombe|Drohne|Tempo|Reparatur|Basis|Fächer|Blitz|Zurück|Weiter|Menü|Einstellungen|Beenden|Fortsetzen|Neuer|Neue|Spiel|Stufe|Wahl|Verschmelz\w*|Taste|Steuerung|Lautstärke|Musik|Effekte|Grafik|Anzeige|Fenster|Vollbild|Auflösung|Sprache|aus|an|Aus|An)\b')
SKIP = re.compile(r'^(res|user)://|^[a-z0-9_.:/%-]+$|^#[0-9a-fA-F]{3,8}$|^[A-Z0-9_]+$')
DIRS = ['scripts']
# Kein Anzeigetext: Knotennamen, Klassen, Godot-Konstanten, Schriftnamen, Ein-Wort-Englisch der Engine.
NOT_TEXT = re.compile(r'^(Tutorial|Background|Fx|Player|Enemy|Boss|Game|Node2D|Control|Label|Variant|Engine|Godot.*|Jersey.*|Silkscreen.*|Nunito.*|Oxanium.*|Pixelify.*|Master|Music|SFX|UI|STINGFORGE|Stingforge|OK|PNG|JSON|GDPC|Escape|Shift|Space|Enter|Tab|Ctrl|Alt|Left|Right|Up|Down)$')
NO_FILES = {'scripts/screens/debug_screen.gd'}


def candidates() -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for f in sorted(ROOT.glob('scripts/**/*.gd')):
        rel = str(f.relative_to(ROOT))
        if rel in NO_FILES:
            continue
        for n, line in enumerate(f.read_text().splitlines(), 1):
            code = line.split('#', 1)[0] if not line.strip().startswith('"') else line
            if line.strip().startswith('#'):
                continue
            for m in LIT.finditer(code):
                s = m.group(1).encode().decode('unicode_escape').encode('latin-1').decode('utf-8') if '\\u' in m.group(1) else m.group(1)
                s = s.replace('\\n', '\n').replace('\\"', '"').replace('\\t', '\t')
                if len(s) < 2 or SKIP.match(s):
                    continue
                if not (GERMAN.search(s) or re.search(r'[A-Za-zÄÖÜäöüß]{2}', s) and (' ' in s or re.match(r'^[A-ZÄÖÜ]', s))):
                    continue
                if NOT_TEXT.match(s):
                    continue
                out.setdefault(s, []).append(f'{rel}:{n}')
    return out


def main() -> int:
    cands = candidates()
    en = json.loads(EN.read_text()) if EN.exists() else {}
    missing = '--missing' in sys.argv
    shown = 0
    for s, where in cands.items():
        if missing and s in en:
            continue
        shown += 1
        print(json.dumps(s, ensure_ascii=False), '\t', where[0])
    print(f'# {shown} von {len(cands)} Texten', file=sys.stderr)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
