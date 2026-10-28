"""Abspann / Ende. Aufgeloest, triumphierend, warm. B-Dur, 116 BPM."""

SONG = {
    "id": "ending", "title": "Ende", "bpm": 116,
    "key": "Bb", "scale": "major",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 2,
    "bars": 32, "chord_bars": 2,
    "chords": ["Bbmaj7", "F", "Gm7", "Eb"],
    "motifs": {
        # Hymne: aufsteigend, dann weit ausholend
        "a": [(0, 4, 4), (4, 7, 4), (8, 9, 2), (10, 11, 2), (12, 9, 4),
              (16, 7, 4), (20, 4, 4), (24, 7, 8)],
        "b": [(0, 11, 4), (4, 12, 4), (8, 11, 2), (10, 9, 2), (12, 7, 4)],
    },
    "arp": [0, 2, 3, 1, 2, 3],
    "bass": "walk",
    "atmos": "air",
    "presets": {"lead": "lead_brass", "arp": "arp_bell",
                "bass": "bass_round", "pad": "pad_warm"},
    "balance": {"pad": -5.0, "drums": -4.5},
    "rms_db": -15.5,
    "sections": [
        {"bars": 8, "drums": "sparse", "bass": "half", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3},
        {"bars": 8, "drums": "four", "bass": "walk", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_gap": 2},
        {"bars": 8, "drums": "march", "bass": "walk", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 3, "mel_gap": 2, "harm": 4,
         "crash": True, "fill": "tom_fill"},
        {"bars": 8, "drums": "four", "bass": "walk", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 3, "mel_gap": 2, "mel_oct": 1,
         "crash": True, "fill": "hat_roll"},
    ],
}
