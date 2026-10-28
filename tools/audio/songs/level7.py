"""Level 7 - Verlorene Kanalisation. Modrig, eng, chromatisch. C-Moll, 122 BPM."""

SONG = {
    "id": "level7", "title": "Verlorene Kanalisation", "bpm": 122,
    "key": "C", "scale": "minor",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 2,
    "bars": 32, "chord_bars": 2,
    "chords": ["Cm7", "Abmaj7", "Eb", "Bb7"],
    "motifs": {
        # kleine Sekunde als Tropfen, dazwischen Tiefe
        "a": [(0, 0, 4), (4, 1, 2), (6, 0, 2), (8, 3, 4),
              (12, 2, 2), (14, 0, 2),
              (16, -1, 4), (20, 0, 4), (24, 3, 8)],
        "b": [(0, 4, 4), (4, 3, 4), (8, 1, 2), (10, 0, 2), (12, -2, 8)],
    },
    "arp": [0, 2, 3, 1, 0, 2, 4, 2],
    "bass": "gallop",
    "atmos": "water",
    "kick_tune": 0.92,
    "presets": {"lead": "lead_pulse", "arp": "arp_pluck",
                "bass": "bass_sub", "pad": "pad_drone"},
    "balance": {"bass": -5.0, "pad": -7.0},
    "sections": [
        {"bars": 8, "drums": "sparse", "bass": "half", "arp": False, "pad": True},
        {"bars": 8, "drums": "basic", "bass": "gallop", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_gap": 2, "crash": True},
        {"bars": 8, "drums": "march", "bass": "gallop", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 3, "mel_gap": 2, "harm": 7,
         "fill": "tom_fill", "crash": True, "riser": True},
        {"bars": 8, "drums": "basic", "bass": "march", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_oct": 1, "fill": "hat_roll"},
    ],
}
