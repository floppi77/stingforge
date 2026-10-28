"""Level 2 - Wurzelreich. Erdige, tiefe Melancholie. A-Moll, 118 BPM."""

SONG = {
    "id": "level2", "title": "Wurzelreich", "bpm": 118,
    "key": "A", "scale": "minor",
    "lead_oct": 4, "arp_oct": 4, "bass_oct": 2,
    "bars": 32, "chord_bars": 2,
    "chords": ["Am7", "Fmaj7", "C", "G"],
    "motifs": {
        # absteigend, schwer, mit Sext als Farbtupfer
        "a": [(0, 0, 4), (4, 3, 2), (6, 2, 2), (8, 0, 4),
              (12, -2, 2), (14, 0, 2),
              (16, 2, 4), (20, 4, 4),
              (24, 3, 4), (28, 2, 2), (30, 0, 2)],
        "b": [(0, 4, 4), (4, 7, 4), (8, 6, 2), (10, 4, 2), (12, 3, 4)],
    },
    "arp": [0, 1, 2, 1, 3, 1, 2, 1],
    "bass": "march",
    "atmos": "wind",
    "kick_tune": 0.9,
    "presets": {"lead": "lead_soft", "arp": "arp_soft",
                "bass": "bass_sub", "pad": "pad_warm"},
    "balance": {"bass": -3.0, "pad": -5.5},
    "sections": [
        {"bars": 8, "drums": "halftime", "bass": "half", "arp": False, "pad": True},
        {"bars": 8, "drums": "march", "bass": "march", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_gap": 2, "fill": "tom_fill", "crash": True},
        {"bars": 8, "drums": "march", "bass": "boogie", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 3, "mel_gap": 2, "double": True,
         "fill": "snare_roll", "crash": True},
        {"bars": 8, "drums": "basic", "bass": "march", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_gap": 2, "mel_oct": 1, "riser": True},
    ],
}
