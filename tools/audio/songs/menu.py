"""Hauptmenue. Ruhig, neugierig, einladend. C-lydisch, 100 BPM, 24 Takte."""

SONG = {
    "id": "menu", "title": "Hauptmenue", "bpm": 100,
    "key": "C", "scale": "lydian",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 2,
    "bars": 24, "chord_bars": 4,
    "chords": ["Cmaj7", "D", "Em7", "Fmaj7"],
    "motifs": {
        # fragend: endet offen auf der Sexte, Fis als Lydisch-Farbe
        "a": [(0, 4, 4), (4, 6, 2), (6, 7, 4), (10, 9, 4),
              (16, 7, 2), (18, 6, 2), (20, 4, 8), (28, 7, 4)],
        "b": [(0, 11, 6), (6, 9, 2), (8, 7, 4), (12, 6, 4)],
    },
    "arp": [0, 2, 1, 3],
    "bass": "half",
    "atmos": "air",
    "presets": {"lead": "lead_flute", "arp": "arp_bell",
                "bass": "bass_round", "pad": "pad_air"},
    "balance": {"pad": -4.5, "drums": -5.0, "arp": -9.0, "bass": -4.5},
    "rms_db": -17.0,
    "turnaround_crash": 0.40,
    "sections": [
        {"bars": 8, "drums": "sparse", "bass": "half", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3},
        {"bars": 8, "drums": "halftime", "bass": "quarter", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 3, "mel_gap": 2},
        {"bars": 8, "drums": "basic", "bass": "half", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_oct": 1, "fill": "hat_roll",
         "riser": True},
    ],
}
