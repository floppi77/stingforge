"""Level 5 - Dornen im Sturm. Treibend, rasant, aggressiv. E-Moll, 150 BPM."""

SONG = {
    "id": "level5", "title": "Dornen im Sturm", "bpm": 150,
    "key": "E", "scale": "minor",
    "lead_oct": 5, "arp_oct": 5, "bass_oct": 2,
    "bars": 32, "chord_bars": 2,
    "chords": ["Em7", "Cmaj7", "G", "D7"],
    "motifs": {
        # 16tel-Keile, synkopiert
        "a": [(0, 4, 1), (1, 4, 1), (2, 7, 2), (4, 6, 1), (5, 4, 1), (6, 2, 2),
              (8, 0, 1), (9, 0, 1), (10, 2, 2), (12, 3, 2), (14, 4, 2)],
        "b": [(0, 9, 2), (2, 7, 2), (4, 6, 2), (6, 4, 2),
              (8, 2, 2), (10, 4, 2), (12, 7, 4)],
    },
    "arp": [0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 0, 1, 2, 3, 4, 5],
    "bass": "drive",
    "atmos": "wind",
    "presets": {"lead": "lead_saw", "arp": "arp_pulse",
                "bass": "bass_saw", "pad": "pad_string"},
    "balance": {"drums": -3.5},
    "sections": [
        {"bars": 8, "drums": "basic", "bass": "gallop", "arp": True, "pad": True,
         "crash": True},
        {"bars": 8, "drums": "drive", "bass": "drive", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "crash": True, "fill": "snare_roll"},
        {"bars": 8, "drums": "drive", "bass": "drive", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 4, "mel_gap": 2, "double": True,
         "crash": True, "fill": "tom_fill", "riser": True},
        {"bars": 8, "drums": "full", "bass": "drive", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "mel_oct": 1,
         "crash": True, "fill": "hat_roll", "riser": True},
    ],
}
