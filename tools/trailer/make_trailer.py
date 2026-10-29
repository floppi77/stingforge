"""Stingforge-Trailer schneiden (ffmpeg).

Voraussetzung: Szenen aufgenommen mit tests/trailer_capture.tscn (Movie Maker,
build/trailer/raw/<clip>.avi) und das Musikbett build/trailer/musik.wav.

Aufruf: python3 tools/trailer/make_trailer.py
Ergebnis: build/trailer/stingforge_trailer.mp4 (1920×1080, 60 fps, H.264 + AAC)

Schnitt im Takt des Musikbetts:
  0,0–9,0   ruhiger Einstieg (Level 1, Flötenthema)     Menü, Blütenmeer
  9,0–27,55 Weltenmontage (Level 5, B-Teil, 152 BPM)     Welten im Wechsel mit Bullet-Hell
  27,55–32,48 Auftakt Level 10                            Werkstatt
  32,48     Ankunft der Bossmusik (harter Schnitt, Blitz) Bosse und Sperrfeuer im Kern
  56,98–62,48 Endkarte, Musik klingt aus
"""
from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
T = ROOT / 'build/trailer'
RAW = T / 'raw'
FONT = ROOT / 'assets/ui/fonts/pixel/Jersey10-Regular.ttf'
LOGO = ROOT / 'assets/ui/title/logo_px.png'
FPS = 60

# (Clip, Startzeit im Clip, Dauer im Trailer)
SHOTS = [
    ('menu', 0.3, 4.5),
    ('l1', 0.8, 4.5),
    ('l3', 0.8, 3.09), ('bh_fungus', 2.4, 3.09), ('l5', 0.6, 3.09),
    ('bh_glass', 2.2, 3.09), ('l8', 0.6, 3.09), ('bh_hive', 2.4, 3.10),
    ('shop', 0.0, 4.93),
    ('boss_larva', 1.2, 5.5), ('bh_core', 1.2, 4.5), ('boss_pike', 1.8, 4.5),
    ('boss_queen', 1.0, 4.5), ('boss_core', 0.9, 5.5),
]
END_CARD = 5.5
BOSS_CUT = 32.48

# (Text, von, bis, Größe, Farbe, Lage) – Lage: "mid" mittig, "low" im unteren Balken
TITLES = [
    ('Eine Biene gegen eine Welt aus Stahl', 0.8, 4.2, 56, '#fff4dc', 'low'),
    ('EVOLVE.', 5.0, 8.6, 150, '#ffd666', 'mid'),
    ('Zehn Welten', 9.4, 12.0, 64, '#fff4dc', 'low'),
    ('ADAPT.', 18.4, 21.4, 150, '#52d6c4', 'mid'),
    ('Werkstatt  ·  Evolutionen  ·  Verschmelzungen', 27.9, 32.2, 56, '#fff4dc', 'low'),
    ('STRIKE.', 32.7, 35.6, 150, '#ff5c84', 'mid'),
    ('Sperrfeuer bis an den Bildrand', 38.4, 41.9, 56, '#fff4dc', 'low'),
    ('Zehn Bosse  ·  Phasen mit Auftritt', 43.0, 46.4, 56, '#fff4dc', 'low'),
]


def end_card(path: Path) -> None:
    img = Image.new('RGB', (1920, 1080), (8, 6, 16))
    logo = Image.open(LOGO).convert('RGBA')
    scale = 4
    logo = logo.resize((logo.width * scale, logo.height * scale), Image.NEAREST)
    img.paste(logo, ((1920 - logo.width) // 2, 230), logo)
    d = ImageDraw.Draw(img)
    for text, size, y, col in (('Evolve. Adapt. Strike.', 64, 860, (255, 214, 102)),
                               ('Eine Pixel-Hommage an Apidya  ·  Linux · Windows · macOS', 40, 950, (169, 172, 201))):
        f = ImageFont.truetype(str(FONT), size)
        w = d.textlength(text, font=f)
        d.text(((1920 - w) / 2 + 3, y + 3), text, font=f, fill=(40, 20, 8))
        d.text(((1920 - w) / 2, y), text, font=f, fill=col)
    img.save(path)


def alpha(a: float, b: float, fade: float = 0.35) -> str:
    return (f"if(lt(t,{a}),0,if(lt(t,{a + fade}),(t-{a})/{fade},"
            f"if(lt(t,{b - fade}),1,if(lt(t,{b}),({b}-t)/{fade},0))))")


def main() -> int:
    card = T / '_endkarte.png'
    end_card(card)
    inputs: list[str] = []
    chains: list[str] = []
    labels: list[str] = []
    # Kinolook: Spielfeld mittig auf 2,39:1 beschneiden, schwarze Balken, sanfte Farbkorrektur.
    look = ('crop=1920:804:0:138,scale=1920:804:flags=neighbor,eq=contrast=1.06:saturation=1.10,'
            'vignette=PI/5,pad=1920:1080:0:138:black,fps=60,format=yuv420p,setsar=1')
    # Menüs (Hauptmenü, Werkstatt) vollständig zeigen: verkleinert ins Breitbild gesetzt.
    look_ui = ('scale=1429:804:flags=lanczos,eq=contrast=1.04:saturation=1.06,'
               'pad=1920:1080:245:138:black,fps=60,format=yuv420p,setsar=1')
    for i, (clip, start, dur) in enumerate(SHOTS):
        inputs += ['-ss', f'{start}', '-t', f'{dur + 0.5}', '-i', str(RAW / f'{clip}.avi')]
        extra = ',tpad=stop_mode=clone:stop_duration=1' if clip == 'shop' else ''
        chosen = look_ui if clip in ('menu', 'shop') else look
        chains.append(f'[{i}:v]{chosen}{extra},trim=duration={dur},setpts=PTS-STARTPTS[v{i}]')
        labels.append(f'[v{i}]')
    n = len(SHOTS)
    inputs += ['-loop', '1', '-t', f'{END_CARD}', '-i', str(card)]
    chains.append(f'[{n}:v]scale=1920:1080,fps=60,format=yuv420p,setsar=1,fade=t=in:st=0:d=1.2[v{n}]')
    labels.append(f'[v{n}]')
    inputs += ['-i', str(T / 'musik.wav')]
    total = sum(s[2] for s in SHOTS) + END_CARD
    chains.append(''.join(labels) + f'concat=n={n + 1}:v=1:a=0[cut]')
    # Einblenden aus Schwarz, Blitz bei der Boss-Ankunft, Titel.
    post = [f'[cut]fade=t=in:st=0:d=0.8',
            f"eq=brightness='if(between(t,{BOSS_CUT},{BOSS_CUT + 0.25}),0.45*(1-(t-{BOSS_CUT})/0.25),0)':eval=frame"]
    for text, a, b, size, col, where in TITLES:
        y = '(h-text_h)/2' if where == 'mid' else '1080-138+(138-text_h)/2'
        post.append(f"drawtext=fontfile='{FONT}':text='{text}':fontsize={size}:fontcolor={col}:"
                    f"shadowcolor=0x3a1e0a:shadowx=4:shadowy=4:x=(w-text_w)/2:y={y}:alpha='{alpha(a, b)}'")
    post.append(f'fade=t=out:st={total - 1.0}:d=1.0')
    chains.append(','.join(post) + '[vout]')
    out = T / 'stingforge_trailer.mp4'
    cmd = ['ffmpeg', '-v', 'error', '-y', *inputs, '-filter_complex', ';'.join(chains),
           '-map', '[vout]', '-map', f'{n + 1}:a', '-c:v', 'libx264', '-preset', 'slow', '-crf', '17',
           '-pix_fmt', 'yuv420p', '-r', str(FPS), '-c:a', 'aac', '-b:a', '256k', '-shortest',
           '-movflags', '+faststart', str(out)]
    subprocess.run(cmd, check=True)
    # Kleinere Fassung zum Teilen (gleiches Bild, stärkere Kompression).
    web = T / 'stingforge_trailer_web.mp4'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(out), '-c:v', 'libx264', '-preset', 'slow',
                    '-crf', '23', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart',
                    str(web)], check=True)
    print(out, f'{total:.2f} s')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
