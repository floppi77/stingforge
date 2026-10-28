"""Level 1 - Bluetenmeer. Hell, luftig, verspielt. D-Dur, 132 BPM."""

SONG = {
    "id": "level1", "title": "Bluetenmeer", "bpm": 132,
    "key": "D", "scale": "major",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 2,
    "bars": 32, "chord_bars": 2,
    "chords": ["Dmaj7", "Bm7", "Gmaj7", "A7"],
    "motifs": {
        # verspieltes Auf und Ab, 2 Takte
        "a": [(0, 4, 2), (2, 7, 2), (4, 6, 2), (6, 4, 4),
              (10, 2, 2), (12, 4, 4),
              (16, 7, 2), (18, 9, 2), (20, 8, 2), (22, 7, 4),
              (26, 4, 4), (30, 2, 2)],
        # ruhiger Gegenpart, 1 Takt
        "b": [(0, 7, 2), (2, 9, 2), (4, 11, 4), (8, 9, 2), (10, 8, 2), (12, 7, 4)],
    },
    "arp": [0, 2, 1, 3, 2, 4, 3, 1],   # Achtel
    "bass": "ostinato",
    "atmos": "air",
    "presets": {"lead": "lead_pulse", "arp": "arp_pluck",
                "bass": "bass_saw", "pad": "pad_soft"},
    "sections": [
        {"bars": 8, "drums": "sparse", "bass": "half", "arp": False, "pad": True},
        {"bars": 8, "drums": "basic", "bass": "ostinato", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_gap": 2, "fill": "snare_roll", "crash": True},
        {"bars": 8, "drums": "full", "bass": "ostinato", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 3, "mel_gap": 2, "harm": 7,
         "fill": "tom_fill", "crash": True, "riser": True},
        {"bars": 8, "drums": "basic", "bass": "gallop", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_gap": 2, "mel_oct": 1,
         "fill": "hat_roll", "crash": True, "riser": True},
    ],
}
