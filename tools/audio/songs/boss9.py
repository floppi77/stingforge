"""Boss 9 - Biomech Swarm. Eigener Bosskampf-Track. F#-phrygian, 188 BPM."""

SONG = {
    "id": "boss9", "title": "Boss 9: Biomech Swarm", "bpm": 188,
    "key": "F#", "scale": "phrygian",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 1,
    "bars": 32, "chord_bars": 2,
    "chords": ['F#m', 'D', 'Bm', 'C#7'],
    "motifs": {
        "a": [(0, 0, 2), (2, 3, 2), (4, 0, 2), (6, 5, 2), (8, 4, 2), (10, 3, 2), (12, 2, 2), (14, 0, 2), (16, 7, 2), (18, 5, 2), (20, 4, 2), (22, 3, 2), (24, 2, 2), (26, 1, 2), (28, 0, 4)],
        "b": [(0, 4, 4), (4, 5, 4), (8, 7, 4), (12, 4, 4)],
    },
    "arp": [0, 1, 0, 2, 0, 1, 0, 2, 0, 1, 0, 3, 4, 3, 1, 0],
    "bass": "boogie",
    "atmos": "buzz",
    "kick_tune": 1.27,
    "presets": {'lead': 'lead_saw', 'arp': 'arp_pluck', 'bass': 'bass_round', 'pad': 'pad_drone'},
    "balance": {"bass": -2.5, "drums": -3.0},
    "rms_db": -14.5,
    "sections": [
        {"bars": 8, "drums": "sparse", "bass": "boogie", "arp": True, "pad": True,
         "crash": True},
        {"bars": 8, "drums": "drive", "bass": "boogie", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "crash": True,
         "fill": "snare_roll"},
        {"bars": 8, "drums": "drive", "bass": "boogie", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 4, "mel_gap": 2, "harm": 3,
         "crash": True, "fill": "tom_fill", "riser": True},
        {"bars": 8, "drums": "full", "bass": "boogie", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "mel_oct": 1,
         "crash": True, "fill": "snare_roll", "riser": True},
    ],
}
