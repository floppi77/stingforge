#!/usr/bin/env python3
"""Messung und Sichtpruefung der gerenderten Apidya-Audiodateien.

Prueft (nichts wird geschaetzt, alles gemessen):
  * Existenz und Dauer aller 13 OGG-Musiktitel und 26 SFX-WAVs (ffprobe)
  * Peak, RMS, Crest, Clipping-Anzahl, DC-Offset je Titel (numpy auf dem
    dekodierten OGG - also auf der Datei, die Godot tatsaechlich abspielt)
  * Loop-Naht: 50-ms-Vergleich Ende/Anfang, Sprunghaftigkeit an der Naht
    gegen die typische Sample-Differenz, Energie- und Spektralvergleich
  * Spektralbaender (8 Baender) und spektraler Schwerpunkt - erkennt leere,
    flache oder schrille Mischungen
  * Energiekurve pro Sekunde (fuer die Beschreibung von Intro/Steigerung)
  * Spektrogramm-PNG je Titel (ffmpeg) inkl. Pruefung, dass es nicht leer ist

Aufruf:
    python3 verify.py                 # alles
    python3 verify.py --only level1,boss
"""

from __future__ import annotations

import argparse
import json
import math
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

TOOL_DIR = Path(__file__).resolve().parent
ROOT = TOOL_DIR.parents[1]
MUSIC = ROOT / "assets" / "audio" / "music"
SFX = ROOT / "assets" / "audio" / "sfx"
BUILD = TOOL_DIR / "build"
SPEC = BUILD / "spectrograms"
SR = 44100
PEAK_LIMIT = -1.0        # dBFS (Obergrenze)
RMS_LO, RMS_HI = -18.0, -14.0
MIN_MUSIC_S = 40.0
# Kurze Cues: absichtlich kuerzer als ein Leveltitel (das Spiel ruft sie als Musik).
MIN_LEN = {"level_clear": 12.0}

SONG_BPM = {
    "level1": 132, "level2": 118, "level3": 138, "level4": 112, "level5": 150,
    "level6": 128, "level7": 122, "level8": 140, "level9": 146, "level10": 134,
    "menu": 100, "boss": 158, "ending": 116, "level_clear": 128,
}

SFX_EXPECTED = [
    "shot_base", "shot_fan", "shot_lightning", "shot_plasma", "hit",
    "explosion_small", "explosion_big", "player_hit", "shield_hit", "shield_break",
    "bomb", "pickup_nectar", "pickup_heart", "purchase", "deny", "ui_move",
    "ui_ok", "ui_back", "boss_warn", "phase_change", "boss_death", "level_clear",
    "game_over", "checkpoint", "low_hp_warn", "combo_ready",
]


def db(x):
    return 20.0 * math.log10(max(float(x), 1e-12))


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def ffprobe(path):
    r = run(["ffprobe", "-v", "error", "-show_entries",
             "format=duration,size:stream=codec_name,sample_rate,channels",
             "-of", "json", str(path)])
    if r.returncode != 0:
        return None
    return json.loads(r.stdout)


def load_audio(path, channels=None):
    """Dekodiert die Datei so, wie sie in Godot ankommt (kein Up-/Downmix)."""
    if channels is None:
        m = ffprobe(path)
        channels = int(m["streams"][0].get("channels", 2)) if m else 2
    r = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path),
                        "-f", "f32le", "-ac", str(channels), "-ar", str(SR), "-"],
                       capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(f"ffmpeg decode fehlgeschlagen: {path}: {r.stderr[:400]}")
    x = np.frombuffer(r.stdout, dtype="<f4").astype(np.float64)
    if x.size % channels:
        x = x[: x.size - (x.size % channels)]
    return x.reshape(-1, channels)


def band_energies(y, nbands=8):
    """Energie in 8 logarithmischen Baendern (dB relativ zur Gesamtenergie)."""
    mono = y.mean(axis=1)
    n = mono.shape[0]
    spec = np.abs(np.fft.rfft(mono * np.hanning(n))) ** 2
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    edges = [40, 80, 160, 320, 640, 1280, 2560, 5120, 16000]
    out = []
    for i in range(nbands):
        m = (freqs >= edges[i]) & (freqs < edges[i + 1])
        e = spec[m].sum()
        out.append(round(10.0 * math.log10(e / max(spec.sum(), 1e-12) + 1e-12), 1))
    cent = float((freqs * spec).sum() / max(spec.sum(), 1e-12))
    return out, cent


def _min_window_db(y, center, half_ms=80, win_ms=10):
    """Kleinste RMS in 10-ms-Fenstern um `center` (Pegeleinschnitt-Loch) in dBFS."""
    sr = SR
    n = y.shape[0]
    w = max(int(win_ms * sr / 1000), 16)
    lo = max(0, center - int(half_ms * sr / 1000))
    hi = min(n, center + int(half_ms * sr / 1000))
    vals = []
    for i in range(lo, max(lo + 1, hi - w), w):
        seg = y[i:i + w]
        if seg.shape[0] < w:
            break
        vals.append(float(np.sqrt(np.mean(seg ** 2))))
    return db(min(vals)) if vals else -120.0


def narrowband_dominance(y, fmin=100.0, fmax=16000.0, bands_per_octave=12):
    """Groesster Anteil eines 1/12-Oktav-Bands an der Gesamtenergie.

    Eine schrille Resonanz (Filterpfeifen, schwingender Regler) zeigt sich als
    einzelnes schmales Band, das einen grossen Teil der Gesamtenergie traegt.
    Musikalische Grundtoene liegen typisch bei 2-8 %.
    """
    mono = y.mean(axis=1)
    n = mono.shape[0]
    spec = np.abs(np.fft.rfft(mono * np.hanning(n))) ** 2
    f = np.fft.rfftfreq(n, 1.0 / SR)
    total = float(spec.sum()) + 1e-20
    edges = fmin * 2.0 ** (np.arange(0, bands_per_octave * np.log2(fmax / fmin) + 2)
                           / bands_per_octave)
    best = (0.0, 0.0)
    best_hi = (0.0, 0.0)
    for i in range(len(edges) - 1):
        m = (f >= edges[i]) & (f < edges[i + 1])
        if not m.any():
            continue
        share = float(spec[m].sum()) / total * 100.0
        c = 0.5 * (edges[i] + edges[i + 1])
        if share > best[0]:
            best = (share, c)
        if c >= 1500.0 and share > best_hi[0]:
            best_hi = (share, c)
    return {"max_band_share_pct": round(best[0], 2),
            "max_band_hz": round(best[1], 0),
            "max_hi_band_share_pct": round(best_hi[0], 2),
            "max_hi_band_hz": round(best_hi[1], 0)}


def seam_metrics(y, bpm=None):
    """Loopnaht: 50-ms-Vergleich, Klicksprung, Pegelloch, Klangfarbe.

    Der 50-ms-Vergleich allein ist nur ein Indiz: bar-32-Schluss und
    bar-1-Downbeat sind musikalisch verschiedene Momente. Entscheidend fuer
    Klickfreiheit sind der Sample-Sprung an der Naht (gegen die typische
    Differenz im Stueck) und ob an der Naht ein Pegelloch entsteht.
    """
    n50 = int(0.050 * SR)
    head = y[:n50]
    tail = y[-n50:]
    r_head = float(np.sqrt(np.mean(head ** 2)))
    r_tail = float(np.sqrt(np.mean(tail ** 2)))

    d = np.abs(np.diff(y[:, 0]))
    typical = float(np.percentile(d, 99.0))
    step = float(np.abs(y[0, 0] - y[-1, 0]))

    hb, _ = band_energies(head)
    tb, _ = band_energies(tail)
    hv = np.array(hb, dtype=float)
    tv = np.array(tb, dtype=float)
    cos = float((hv @ tv) / max(np.linalg.norm(hv) * np.linalg.norm(tv), 1e-9))

    # Naht als echte Schleife pruefen: Datei an sich selbst haengen
    doubled = np.concatenate([y[:, 0], y[:, 0]])
    seam_min = _min_window_db(doubled, y.shape[0], half_ms=80, win_ms=10)
    # Vergleich: dieselbe Kennzahl an normalen Taktgrenzen im Stueck
    beat_positions = []
    if bpm:
        bar_s = 4.0 * 60.0 / float(bpm)
        k = 1
        while k * bar_s < y.shape[0] / SR - 0.5:
            beat_positions.append(int(k * bar_s * SR))
            k += 1
    ref = [_min_window_db(y[:, 0], pos, 80, 10) for pos in beat_positions] or [-120.0]
    ref_med = float(np.median(ref))

    return {
        "head_rms_db": round(db(r_head), 2),
        "tail_rms_db": round(db(r_tail), 2),
        "rms_delta_db": round(db(r_head) - db(r_tail), 2),
        "boundary_step": round(step, 6),
        "boundary_step_db": round(db(step) if step > 0 else -120.0, 1),
        "typical_step_p99_db": round(db(typical), 1),
        "step_ratio": round(step / max(typical, 1e-9), 2),
        "band_cosine": round(cos, 4),
        "head_rms_first20ms_db": round(db(float(np.sqrt(np.mean(y[:int(0.02 * SR)] ** 2)))), 2),
        "seam_min_window_db": round(seam_min, 1),
        "bar_boundary_min_window_db": round(ref_med, 1),
        "seam_vs_bar_db": round(seam_min - ref_med, 1),
    }


def energy_curve(y, win=1.0):
    n = int(win * SR)
    m = y.shape[0] // n
    mono = y[:m * n].mean(axis=1).reshape(m, n)
    rms = np.sqrt(np.mean(mono ** 2, axis=1))
    return np.array([db(v) for v in rms])


def sparkline(vals, lo=None, hi=None):
    chars = " .:-=+*#%@"
    lo = float(np.min(vals)) if lo is None else lo
    hi = float(np.max(vals)) if hi is None else hi
    span = max(hi - lo, 1e-9)
    out = []
    for v in vals:
        k = int(np.clip((v - lo) / span, 0, 1) * (len(chars) - 1))
        out.append(chars[k])
    return "".join(out)


def spectrogram(path, png):
    png.parent.mkdir(parents=True, exist_ok=True)
    r = run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(path),
             "-lavfi", "showspectrumpic=s=1400x700:mode=combined:color=fire:"
             "scale=log:fscale=log:gain=4:legend=1", "-frames:v", "1", str(png)])
    return r.returncode == 0 and png.exists()


def image_is_informative(png):
    im = Image.open(png).convert("L")
    a = np.asarray(im, dtype=np.float64) / 255.0
    return {"std": round(float(a.std()), 4),
            "nonblack_frac": round(float((a > 0.06).mean()), 4),
            "size": im.size}


def analyse_music(name):
    ogg = MUSIC / f"{name}.ogg"
    res = {"name": name, "exists": ogg.exists()}
    if not ogg.exists():
        res["ok"] = False
        return res
    meta = ffprobe(ogg)
    res["duration"] = round(float(meta["format"]["duration"]), 3)
    res["codec"] = meta["streams"][0].get("codec_name")
    res["sample_rate"] = int(meta["streams"][0].get("sample_rate", 0))
    res["channels"] = int(meta["streams"][0].get("channels", 0))
    res["bytes"] = int(meta["format"]["size"])

    y = load_audio(ogg, 2)
    pk = float(np.abs(y).max())
    rms = float(np.sqrt(np.mean(y ** 2)))
    res["peak_dbfs"] = round(db(pk), 2)
    res["rms_dbfs"] = round(db(rms), 2)
    res["crest_db"] = round(db(pk) - db(rms), 2)
    res["clipping_samples"] = int(np.sum(np.abs(y) >= 0.999))
    res["dc_offset"] = round(float(y.mean()), 6)
    bands, cent = band_energies(y)
    res["bands_db"] = bands
    res["centroid_hz"] = round(cent, 1)
    bpm = SONG_BPM.get(name)
    res["seam"] = seam_metrics(y, bpm=bpm)
    res["narrowband"] = narrowband_dominance(y)
    ec = energy_curve(y)
    res["energy_curve_db"] = [round(float(v), 1) for v in ec]
    res["energy_sparkline"] = sparkline(ec, -34, -8)
    res["structure"] = describe_structure(ec)
    res["_rms_ok"] = RMS_LO <= res["rms_dbfs"] <= RMS_HI
    res["_peak_ok"] = res["peak_dbfs"] <= PEAK_LIMIT
    res["_dur_ok"] = res["duration"] >= MIN_LEN.get(name, MIN_MUSIC_S)
    sm = res["seam"]
    res["_seam_ok"] = bool(
        sm["step_ratio"] < 4.0                      # kein Klick am Uebergang
        and sm["head_rms_first20ms_db"] > -55.0     # keine Stille am Anfang
        and sm["seam_min_window_db"] > -45.0        # kein Loch an der Naht
        and sm["seam_vs_bar_db"] > -9.0             # Naht nicht toter als ein Taktwechsel
        and sm["band_cosine"] > 0.5                 # Klangfarbe bleibt verwandt
        and abs(sm["rms_delta_db"]) <= 12.0         # kein Pegelsturz von 50 ms auf 50 ms
        and res["narrowband"]["max_hi_band_share_pct"] < 15.0  # keine schrille Resonanz >1.5 kHz
    )
    res["ok"] = bool(res["_rms_ok"] and res["_peak_ok"] and res["_dur_ok"]
                     and res["_seam_ok"] and res["clipping_samples"] == 0)
    return res


def describe_structure(ec):
    """Grobe, aber ehrliche Beschreibung der Energiekurve (1-s-Fenster)."""
    n = len(ec)
    if n < 8:
        return "zu kurz fuer eine Strukturanalyse"
    seg = max(n // 4, 1)
    q = [float(np.mean(ec[i * seg:(i + 1) * seg])) for i in range(4)]
    peak_i = int(np.argmax(ec))
    dip_i = int(np.argmin(ec[seg:3 * seg])) + seg if n > 2 * seg else 0
    parts = [f"Viertel-RMS: {q[0]:.1f} / {q[1]:.1f} / {q[2]:.1f} / {q[3]:.1f} dBFS",
             f"lauteste Stelle bei {peak_i + 1}s ({ec[peak_i]:.1f} dBFS)"]
    if q[2] - q[0] >= 1.0:
        parts.append("Steigerung zum dritten Viertel")
    elif q[1] - q[0] >= 1.0:
        parts.append("Steigerung nach dem Intro")
    else:
        parts.append("gleichmaessiger Pegel")
    if q[3] < q[2] - 1.0:
        parts.append("Ruecknahme zum Loopende (Uebergang in den Anfang)")
    if ec[dip_i] < max(ec) - 8.0:
        parts.append(f"Breakdown bei {dip_i + 1}s")
    return "; ".join(parts)


def analyse_sfx(name):
    path = SFX / f"{name}.wav"
    res = {"name": name, "exists": path.exists()}
    if not path.exists():
        res["ok"] = False
        return res
    meta = ffprobe(path)
    res["duration"] = round(float(meta["format"]["duration"]), 4)
    st = meta["streams"][0]
    res["codec"] = st.get("codec_name")
    res["sample_rate"] = int(st.get("sample_rate", 0))
    res["channels"] = int(st.get("channels", 0))
    y = load_audio(path, res["channels"])
    pk = float(np.abs(y).max())
    rms = float(np.sqrt(np.mean(y ** 2)))
    res["peak_dbfs"] = round(db(pk), 2)
    res["rms_dbfs"] = round(db(rms), 2)
    res["clipping_samples"] = int(np.sum(np.abs(y) >= 0.999))
    res["edge_first"] = round(float(np.abs(y[0]).max()), 5)
    res["edge_last"] = round(float(np.abs(y[-1]).max()), 5)
    res["ok"] = bool(res["clipping_samples"] == 0 and res["duration"] <= 2.1
                     and res["edge_first"] < 0.02 and res["edge_last"] < 0.02
                     and res["sample_rate"] == SR and res["channels"] in (1, 2))
    return res


def write_markdown(report):
    """Messwerte als Markdown-Tabelle (reproduzierbar aus dem Bericht erzeugt)."""
    meta = {}
    rp = BUILD / "render_report.json"
    if rp.exists():
        try:
            rr = json.loads(rp.read_text())
            for m in rr.get("music", []):
                meta[m["id"]] = m
        except Exception:
            meta = {}
    lines = ["# Audio-Messwerte", "",
             "Automatisch erzeugt von `tools/audio/verify.py` (nicht von Hand pflegen).",
             "Alle Werte sind an der ausgelieferten Datei gemessen, also am dekodierten OGG.",
             "", "## Musik", "",
             "| Titel | Dauer | BPM | Tonart | Peak (OGG) | RMS | Crest | Loopnaht Δ | Sprung | "
             "Spektralzentrum | Status |",
             "|---|---|---|---|---|---|---|---|---|---|---|"]
    for m in report["music"]:
        if not m.get("exists"):
            lines.append(f"| {m['name']} | – | – | – | – | – | – | – | – | – | FEHLT |")
            continue
        md = meta.get(m["name"], {})
        sm = m["seam"]
        lines.append(
            f"| {m['name']} | {m['duration']:.2f} s | {md.get('bpm', '–')} | "
            f"{md.get('key', '–')} | {m['peak_dbfs']:.2f} dBFS | {m['rms_dbfs']:.2f} dBFS | "
            f"{m['crest_db']:.1f} dB | {sm['rms_delta_db']:+.1f} dB | "
            f"{sm['step_ratio']:.2f} | {m['centroid_hz']:.0f} Hz | "
            f"{'OK' if m['ok'] else 'PRUEFEN'} |")
    lines += ["", "Loopnaht Δ = Pegel der letzten 50 ms minus Pegel der ersten 50 ms.",
              "Sprung = Sprunghöhe an der Naht im Verhältnis zur 99-%-Sample-Differenz im Stück "
              "(< 1 heißt: unauffälliger als ein normaler Sample-Schritt).", "",
              "### Energiekurve je Titel (1-s-Fenster)", ""]
    for m in report["music"]:
        if m.get("exists"):
            lines += [f"**{m['name']}**  `{m['energy_sparkline']}`", "",
                      f"{m['structure']}", ""]
    lines += ["## Soundeffekte", "",
              "| Name | Dauer | Peak | RMS | Format | Status |", "|---|---|---|---|---|---|"]
    for m in report["sfx"]:
        if not m.get("exists"):
            lines.append(f"| {m['name']} | – | – | – | – | FEHLT |")
            continue
        lines.append(f"| {m['name']} | {m['duration']*1000:.0f} ms | {m['peak_dbfs']:.2f} dBFS | "
                     f"{m['rms_dbfs']:.2f} dBFS | {m['sample_rate']} Hz / {m['channels']} ch | "
                     f"{'OK' if m['ok'] else 'PRUEFEN'} |")
    out = ROOT / "docs" / "AUDIO_MEASUREMENTS.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n")
    return out


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--no-spec", action="store_true")
    args = ap.parse_args(argv)
    only = [s.strip() for s in args.only.split(",") if s.strip()]

    BUILD.mkdir(parents=True, exist_ok=True)
    songs = sorted(p.stem for p in MUSIC.glob("*.ogg"))
    if only:
        songs = [s for s in songs if s in only]

    report = {"music": [], "sfx": [], "spectrograms": {}}
    print(f"\n=== MUSIK ({len(songs)} Titel) ===")
    print(f"{'Titel':8s} {'Dauer':>7s} {'Peak':>7s} {'RMS':>7s} {'Crest':>6s} "
          f"{'Clip':>5s} {'Naht':>6s} {'Zentrum':>8s}  Status")
    for s in songs:
        r = analyse_music(s)
        report["music"].append(r)
        if not r["exists"]:
            print(f"{s:8s}  FEHLT")
            continue
        seam_ok = "ok" if r["_seam_ok"] else "!"
        print(f"{s:8s} {r['duration']:6.2f}s {r['peak_dbfs']:6.2f} "
              f"{r['rms_dbfs']:6.2f} {r['crest_db']:5.1f} {r['clipping_samples']:5d} "
              f"{r['seam']['rms_delta_db']:+5.1f}{seam_ok} {r['centroid_hz']:7.0f}Hz  "
              f"{'OK' if r['ok'] else 'PRUEFEN'}")
        print(f"         Bands 40-80-160-320-640-1k3-2k6-5k1+: "
              + " ".join(f"{b:5.1f}" for b in r["bands_db"]))
        print(f"         Energie  {r['energy_sparkline']}")
        print(f"         Struktur {r['structure']}")
        nb = r["narrowband"]
        print(f"         schmales 1/12-Okt-Band: max {nb['max_band_share_pct']:.1f} % "
              f"({nb['max_band_hz']:.0f} Hz), >1.5 kHz: {nb['max_hi_band_share_pct']:.1f} % "
              f"({nb['max_hi_band_hz']:.0f} Hz)")

    print(f"\n=== SFX ({len(SFX_EXPECTED)} Dateien) ===")
    for name in SFX_EXPECTED:
        r = analyse_sfx(name)
        report["sfx"].append(r)
        if not r["exists"]:
            print(f"  {name:16s} FEHLT")
            continue
        print(f"  {name:16s} {r['duration']*1000:7.1f} ms  peak {r['peak_dbfs']:6.2f}  "
              f"RMS {r['rms_dbfs']:6.2f}  {r['sample_rate']} Hz/{r['channels']}ch  "
              f"{'OK' if r['ok'] else 'PRUEFEN'}")

    if not args.no_spec:
        print(f"\n=== SPEKTROGRAMME -> {SPEC.relative_to(ROOT)} ===")
        for s in songs:
            png = SPEC / f"{s}.png"
            ok = spectrogram(MUSIC / f"{s}.ogg", png)
            info = image_is_informative(png) if ok else {"std": 0, "nonblack_frac": 0,
                                                         "size": (0, 0)}
            report["spectrograms"][s] = {"ok": bool(ok and info["std"] > 0.02),
                                         "path": str(png.relative_to(ROOT)), **info}
            print(f"  {s:8s} {'ok' if report['spectrograms'][s]['ok'] else 'LEER'}"
                  f"  std={info['std']:.3f}  Anteil heller Pixel={info['nonblack_frac']:.2f}")

    n_music_ok = sum(1 for r in report["music"] if r.get("ok"))
    n_sfx_ok = sum(1 for r in report["sfx"] if r.get("ok"))
    n_spec_ok = sum(1 for r in report["spectrograms"].values() if r.get("ok"))
    summary = {
        "music_ok": n_music_ok, "music_total": len(report["music"]),
        "sfx_ok": n_sfx_ok, "sfx_total": len(report["sfx"]),
        "spectrograms_ok": n_spec_ok,
        "all_ok": bool(n_music_ok == len(report["music"])
                       and n_sfx_ok == len(report["sfx"])
                       and (args.no_spec or n_spec_ok == len(report["spectrograms"]))),
    }
    report["summary"] = summary
    out = BUILD / "verify_report.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False))
    md = write_markdown(report)
    print(f"Markdown-Tabelle: {md.relative_to(ROOT)}")
    print(f"\nErgebnis: {n_music_ok}/{len(report['music'])} Musik, "
          f"{n_sfx_ok}/{len(report['sfx'])} SFX, {n_spec_ok} Spektrogramme -> "
          f"{out.relative_to(ROOT)}")
    print("GESAMT:", "OK" if summary["all_ok"] else "NICHT OK")
    return 0 if summary["all_ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
