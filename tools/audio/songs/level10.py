"""Level 10 - Kern der Verwandlung. Episch, harmonisch-moll, gross.
D-Moll, 134 BPM."""

SONG = {
    "id": "level10", "title": "Kern der Verwandlung", "bpm": 134,
    "key": "D", "scale": "harmonic_minor",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 2,
    "bars": 32, "chord_bars": 2,
    "chords": ["Dm", "Gm", "Bb", "A7"],
    "motifs": {
        # grosse Geste mit erhoehter Septime (Cis)
        "a": [(0, 0, 4), (4, 3, 2), (6, 2, 2), (8, 4, 4), (12, 6, 4),
              (16, 7, 4), (20, 6, 2), (22, 4, 2),
              (24, 3, 4), (28, 2, 2), (30, 0, 2)],
        "b": [(0, 7, 4), (4, 11, 4), (8, 9, 2), (10, 7, 2), (12, 6, 4)],
    },
    "arp": [0, 2, 1, 3, 0, 2, 3, 1],
    "bass": "march",
    "atmos": "air",
    "presets": {"lead": "lead_pulse", "arp": "arp_bell",
                "bass": "bass_saw", "pad": "pad_string"},
    "balance": {"pad": -5.0, "drums": -3.0},
    "sections": [
        {"bars": 8, "drums": "halftime", "bass": "half", "arp": False, "pad": True},
        {"bars": 8, "drums": "march", "bass": "march", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_gap": 2, "crash": True},
        {"bars": 8, "drums": "drive", "bass": "march", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 4, "mel_gap": 2, "double": True,
         "crash": True, "fill": "tom_fill", "riser": True},
        {"bars": 8, "drums": "full", "bass": "boogie", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_gap": 2, "harm": 7,
         "crash": True, "fill": "snare_roll"},
    ],
}
