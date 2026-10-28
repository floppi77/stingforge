"""Boss 2 - Root Warden. Eigener Bosskampf-Track. C-harmonic_minor, 156 BPM."""

SONG = {
    "id": "boss2", "title": "Boss 2: Root Warden", "bpm": 156,
    "key": "C", "scale": "harmonic_minor",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 1,
    "bars": 32, "chord_bars": 2,
    "chords": ['Cm', 'Ab', 'Fm', 'G7'],
    "motifs": {
        "a": [(0, 0, 3), (3, 1, 3), (6, 4, 2), (8, 3, 4), (12, 2, 4), (16, 0, 3), (19, 1, 3), (22, 4, 2), (24, 7, 4), (28, 4, 4)],
        "b": [(0, 4, 6), (6, 3, 2), (8, 2, 4), (12, 0, 4)],
    },
    "arp": [0, 2, 1, 3, 1, 2, 0, 4, 0, 2, 1, 3, 2, 1, 0, 3],
    "bass": "ostinato",
    "atmos": "machine",
    "kick_tune": 1.06,
    "presets": {'lead': 'lead_pulse', 'arp': 'arp_pluck', 'bass': 'bass_saw', 'pad': 'pad_drone'},
    "balance": {"bass": -2.5, "drums": -3.0},
    "rms_db": -14.5,
    "sections": [
        {"bars": 8, "drums": "basic", "bass": "ostinato", "arp": True, "pad": True,
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
