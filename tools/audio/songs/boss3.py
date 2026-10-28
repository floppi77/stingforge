"""Boss 3 - Toad Sovereign. Eigener Bosskampf-Track. G-dorian, 162 BPM."""

SONG = {
    "id": "boss3", "title": "Boss 3: Toad Sovereign", "bpm": 162,
    "key": "G", "scale": "dorian",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 1,
    "bars": 32, "chord_bars": 2,
    "chords": ['Gm', 'Bb', 'Eb', 'D7'],
    "motifs": {
        "a": [(0, 2, 2), (2, 4, 2), (4, 2, 2), (6, 0, 2), (8, 4, 4), (12, 5, 4), (16, 2, 2), (18, 4, 2), (20, 7, 2), (22, 5, 2), (24, 4, 4), (28, 2, 4)],
        "b": [(0, 0, 4), (4, 2, 4), (8, 4, 4), (12, 7, 4)],
    },
    "arp": [0, 1, 2, 1, 0, 2, 3, 2, 0, 1, 2, 3, 4, 3, 2, 1],
    "bass": "boogie",
    "atmos": "water",
    "kick_tune": 1.09,
    "presets": {'lead': 'lead_pulse', 'arp': 'arp_pluck', 'bass': 'bass_round', 'pad': 'pad_soft'},
    "balance": {"bass": -2.5, "drums": -3.0},
    "rms_db": -14.5,
    "sections": [
        {"bars": 8, "drums": "basic", "bass": "boogie", "arp": True, "pad": True,
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
