"""Level 4 - Pilzwald. Dunkel, sparsam, schwebend. Fis-Dorisch, 112 BPM."""

SONG = {
    "id": "level4", "title": "Pilzwald", "bpm": 112,
    "key": "F#", "scale": "dorian",
    "lead_oct": 4, "arp_oct": 4, "bass_oct": 2,
    "bars": 32, "chord_bars": 2,
    "chords": ["F#m7", "G#m7", "A", "B7"],
    "motifs": {
        # lange Toene, viel Raum zwischen den Phrasen
        "a": [(0, 0, 6), (6, 4, 4), (10, 2, 6),
              (16, 4, 4), (20, 6, 4), (24, 7, 8)],
        "b": [(0, 9, 8), (8, 6, 4), (12, 4, 4), (16, 2, 8), (24, 0, 8)],
    },
    "arp": [0, 2, 1, 3],
    "bass": "half",
    "atmos": "air",
    "kick_tune": 0.85,
    "presets": {"lead": "lead_organ", "arp": "arp_glass",
                "bass": "bass_sub", "pad": "pad_drone"},
    "balance": {"pad": -3.5, "drums": -6.5, "arp": -9.0},
    "turnaround_crash": 0.25,
    "sections": [
        {"bars": 8, "drums": "sparse", "bass": "half", "arp": False, "pad": True},
        {"bars": 8, "drums": "halftime", "bass": "half", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "crash": True},
        {"bars": 8, "drums": "halftime", "bass": "quarter", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 3, "mel_oct": 1, "harm": 7, "crash": True,
         "fill": "hat_roll"},
        {"bars": 8, "drums": "basic", "bass": "half", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "riser": True, "fill": "tom_fill"},
    ],
}
