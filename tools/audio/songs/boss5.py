"""Boss 5 - Mantidenpaar. Eigener Bosskampf-Track. D-harmonic_minor, 174 BPM."""

SONG = {
    "id": "boss5", "title": "Boss 5: Mantidenpaar", "bpm": 174,
    "key": "D", "scale": "harmonic_minor",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 1,
    "bars": 32, "chord_bars": 2,
    "chords": ['Dm', 'Bb', 'Gm', 'A7'],
    "motifs": {
        "a": [(0, 0, 2), (2, 2, 2), (4, 4, 2), (6, 2, 2), (8, 7, 4), (12, 5, 2), (14, 4, 2), (16, 2, 4), (20, 0, 2), (22, 2, 2), (24, 4, 4), (28, 7, 4)],
        "b": [(0, 5, 4), (4, 4, 4), (8, 2, 4), (12, 0, 4)],
    },
    "arp": [0, 2, 4, 2, 0, 2, 4, 6, 0, 2, 4, 2, 6, 4, 2, 0],
    "bass": "drive",
    "atmos": "wind",
    "kick_tune": 1.15,
    "presets": {'lead': 'lead_saw', 'arp': 'arp_pulse', 'bass': 'bass_round', 'pad': 'pad_string'},
    "balance": {"bass": -2.5, "drums": -3.0},
    "rms_db": -14.5,
    "sections": [
        {"bars": 8, "drums": "sparse", "bass": "drive", "arp": True, "pad": True,
         "crash": True},
        {"bars": 8, "drums": "march", "bass": "drive", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "crash": True,
         "fill": "snare_roll"},
        {"bars": 8, "drums": "march", "bass": "boogie", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 4, "mel_gap": 2, "harm": 3,
         "crash": True, "fill": "tom_fill", "riser": True},
        {"bars": 8, "drums": "full", "bass": "drive", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "mel_oct": 1,
         "crash": True, "fill": "snare_roll", "riser": True},
    ],
}
