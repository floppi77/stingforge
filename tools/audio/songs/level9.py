"""Level 9 - Biomechanischer Schwarmstock. Schwirrend, hybrid.
A-Mixolydisch, 146 BPM."""

SONG = {
    "id": "level9", "title": "Biomechanischer Schwarmstock", "bpm": 146,
    "key": "A", "scale": "mixolydian",
    "lead_oct": 5, "arp_oct": 5, "bass_oct": 2,
    "bars": 32, "chord_bars": 2,
    "chords": ["A7", "G", "D", "Am7"],
    "motifs": {
        # chromatische Schwarm-Bewegung, sehr rhythmisch
        "a": [(0, 4, 1), (1, 5, 1), (2, 4, 1), (3, 7, 1),
              (4, 5, 1), (5, 4, 1), (6, 2, 2),
              (8, 4, 1), (9, 5, 1), (10, 7, 2), (12, 9, 2), (14, 7, 2)],
        "b": [(0, 9, 2), (2, 8, 2), (4, 7, 2), (6, 5, 2),
              (8, 4, 2), (10, 2, 2), (12, 0, 4)],
    },
    "arp": [0, 1, 2, 3, 4, 3, 2, 1, 0, 1, 2, 3, 4, 5, 6, 5],
    "bass": "ostinato",
    "atmos": "buzz",
    "presets": {"lead": "lead_saw", "arp": "arp_pulse",
                "bass": "bass_saw", "pad": "pad_warm"},
    "balance": {"pad": -5.0, "arp": -7.0},
    "sections": [
        {"bars": 8, "drums": "basic", "bass": "ostinato", "arp": True, "pad": True,
         "crash": True},
        {"bars": 8, "drums": "full", "bass": "ostinato", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "crash": True, "fill": "snare_roll"},
        {"bars": 8, "drums": "drive", "bass": "boogie", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 4, "mel_gap": 2, "harm": 7,
         "crash": True, "fill": "tom_fill", "riser": True},
        {"bars": 8, "drums": "full", "bass": "ostinato", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "mel_oct": 1,
         "crash": True, "fill": "hat_roll"},
    ],
}
