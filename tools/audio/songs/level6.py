"""Level 6 - Glaesernes Gewaechshaus. Hell, glasig, schwebend. B-Dur, 128 BPM."""

SONG = {
    "id": "level6", "title": "Glaesernes Gewaechshaus", "bpm": 128,
    "key": "B", "scale": "major",
    "lead_oct": 5, "arp_oct": 5, "bass_oct": 2,
    "bars": 32, "chord_bars": 2,
    "chords": ["Bmaj7", "G#m7", "Emaj7", "F#7"],
    "motifs": {
        # glockig, weit oben, fallende Toene
        "a": [(0, 4, 2), (2, 7, 2), (4, 11, 2), (6, 9, 2), (8, 7, 2), (10, 4, 2),
              (12, 9, 4),
              (16, 11, 2), (18, 9, 2), (20, 7, 4), (24, 4, 8)],
        "b": [(0, 2, 2), (2, 4, 2), (4, 7, 2), (6, 9, 4),
              (12, 11, 4), (16, 9, 4), (20, 7, 2), (22, 4, 2)],
    },
    "arp": [0, 1, 2, 3, 4, 5, 6, 7],
    "bass": "quarter",
    "atmos": "air",
    "presets": {"lead": "lead_bell", "arp": "arp_glass",
                "bass": "bass_round", "pad": "pad_glass"},
    "balance": {"pad": -5.5, "drums": -5.0},
    "turnaround_crash": 0.3,
    "sections": [
        {"bars": 8, "drums": "sparse", "bass": "half", "arp": True, "pad": True},
        {"bars": 8, "drums": "four", "bass": "quarter", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_gap": 2, "crash": True},
        {"bars": 8, "drums": "four", "bass": "boogie", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 3, "mel_gap": 2, "harm": 7, "crash": True,
         "fill": "hat_roll", "riser": True},
        {"bars": 8, "drums": "full", "bass": "quarter", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_gap": 2, "crash": True, "fill": "snare_roll"},
    ],
}
