"""Level 8 - Maschinenherz. Mechanisch, praezise, hart. G-Moll, 140 BPM."""

SONG = {
    "id": "level8", "title": "Maschinenherz", "bpm": 140,
    "key": "G", "scale": "minor",
    "lead_oct": 4, "arp_oct": 4, "bass_oct": 2,
    "bars": 32, "chord_bars": 2,
    "chords": ["Gm7", "Bbmaj7", "Ebmaj7", "D7"],
    "motifs": {
        # 16tel-Maschine: ein Zellmotiv, repetitiv
        "a": [(0, 0, 1), (1, 0, 1), (2, 3, 2), (4, 0, 1), (5, 0, 1), (6, 2, 2),
              (8, 3, 1), (9, 3, 1), (10, 4, 2), (12, 3, 2), (14, 2, 2)],
        "b": [(0, 7, 2), (2, 7, 2), (4, 6, 2), (6, 4, 2),
              (8, 3, 2), (10, 4, 2), (12, 7, 4)],
    },
    "arp": [0, 0, 2, 3, 0, 0, 2, 1, 0, 0, 2, 3, 4, 3, 2, 1],
    "bass": "drive",
    "atmos": "machine",
    "presets": {"lead": "lead_organ", "arp": "arp_pulse",
                "bass": "bass_drive", "pad": "pad_string"},
    "balance": {"drums": -3.0, "bass": -3.5},
    "sections": [
        {"bars": 8, "drums": "basic", "bass": "drive", "arp": True, "pad": True,
         "crash": True},
        {"bars": 8, "drums": "drive", "bass": "drive", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "crash": True,
         "fill": "snare_roll"},
        {"bars": 8, "drums": "drive", "bass": "drive", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 4, "mel_gap": 2, "double": True,
         "crash": True, "fill": "tom_fill", "riser": True},
        {"bars": 8, "drums": "full", "bass": "drive", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "mel_oct": 1,
         "crash": True, "fill": "hat_roll"},
    ],
}
