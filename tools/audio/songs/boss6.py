"""Boss 6 - Glass Wasp. Eigener Bosskampf-Track. E-lydian, 172 BPM."""

SONG = {
    "id": "boss6", "title": "Boss 6: Glass Wasp", "bpm": 172,
    "key": "E", "scale": "lydian",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 1,
    "bars": 32, "chord_bars": 2,
    "chords": ['Emaj7', 'C#m7', 'Amaj7', 'B7'],
    "motifs": {
        "a": [(0, 7, 2), (2, 9, 2), (4, 11, 2), (6, 9, 2), (8, 7, 4), (12, 4, 4), (16, 11, 2), (18, 9, 2), (20, 7, 2), (22, 4, 2), (24, 2, 4), (28, 4, 4)],
        "b": [(0, 4, 4), (4, 6, 4), (8, 9, 4), (12, 11, 4)],
    },
    "arp": [0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 4, 3, 2, 1, 2, 0],
    "bass": "ostinato",
    "atmos": "air",
    "kick_tune": 1.18,
    "presets": {'lead': 'lead_bell', 'arp': 'arp_bell', 'bass': 'bass_saw', 'pad': 'pad_glass'},
    "balance": {"bass": -2.5, "drums": -3.0},
    "rms_db": -14.5,
    "sections": [
        {"bars": 8, "drums": "sparse", "bass": "ostinato", "arp": True, "pad": True,
         "crash": True},
        {"bars": 8, "drums": "basic", "bass": "ostinato", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "crash": True,
         "fill": "snare_roll"},
        {"bars": 8, "drums": "basic", "bass": "boogie", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 4, "mel_gap": 2, "harm": 3,
         "crash": True, "fill": "tom_fill", "riser": True},
        {"bars": 8, "drums": "full", "bass": "ostinato", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "mel_oct": 1,
         "crash": True, "fill": "snare_roll", "riser": True},
    ],
}
