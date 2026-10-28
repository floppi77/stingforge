"""Level 3 - Schilf und Teich. Fließend, wiegend, mit Wasser-Atmosphaere.
G-Dur, 138 BPM."""

SONG = {
    "id": "level3", "title": "Schilf und Teich", "bpm": 138,
    "key": "G", "scale": "major",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 2,
    "bars": 32, "chord_bars": 2,
    "chords": ["Gmaj7", "Em7", "Cmaj7", "D7"],
    "motifs": {
        # triolisch wiegend (6/8-Feeling im 4/4-Raster)
        "a": [(0, 4, 3), (3, 6, 3), (6, 7, 2), (8, 9, 3), (11, 7, 3), (14, 6, 2),
              (16, 4, 3), (19, 2, 3), (22, 4, 2),
              (24, 7, 3), (27, 9, 3), (30, 7, 2)],
        "b": [(0, 9, 4), (4, 11, 4), (8, 9, 2), (10, 7, 2), (12, 4, 4)],
    },
    "arp": [0, 2, 3, 5, 3, 2],
    "bass": "boogie",
    "atmos": "water",
    "presets": {"lead": "lead_flute", "arp": "arp_bell",
                "bass": "bass_round", "pad": "pad_air"},
    "balance": {"pad": -5.5},
    "sections": [
        {"bars": 8, "drums": "sparse", "bass": "half", "arp": False, "pad": True},
        {"bars": 8, "drums": "basic", "bass": "boogie", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_gap": 2, "crash": True, "fill": "hat_roll"},
        {"bars": 8, "drums": "four", "bass": "boogie", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 3, "mel_gap": 2, "harm": 7,
         "crash": True, "fill": "tom_fill", "riser": True},
        {"bars": 8, "drums": "basic", "bass": "ostinato", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_gap": 2, "mel_oct": 1,
         "crash": True, "fill": "snare_roll", "riser": True},
    ],
}
