"""Boss 1 - Rose Beetle. Eigener Bosskampf-Track. F-harmonic_minor, 150 BPM."""

SONG = {
    "id": "boss1", "title": "Boss 1: Rose Beetle", "bpm": 150,
    "key": "F", "scale": "harmonic_minor",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 1,
    "bars": 32, "chord_bars": 2,
    "chords": ['Fm', 'Db', 'Bbm', 'C7'],
    "motifs": {
        "a": [(0, 0, 2), (2, 0, 2), (4, 3, 2), (6, 0, 2), (8, 4, 2), (10, 3, 2), (12, 2, 4), (16, 0, 2), (18, 0, 2), (20, 7, 2), (22, 6, 2), (24, 4, 2), (26, 3, 2), (28, 2, 2), (30, 0, 2)],
        "b": [(0, 7, 4), (4, 6, 4), (8, 4, 4), (12, 3, 4)],
    },
    "arp": [0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 4, 2, 1, 0],
    "bass": "drive",
    "atmos": "machine",
    "kick_tune": 1.03,
    "presets": {'lead': 'lead_saw', 'arp': 'arp_pulse', 'bass': 'bass_drive', 'pad': 'pad_string'},
    "balance": {"bass": -2.5, "drums": -3.0},
    "rms_db": -14.5,
    "sections": [
        {"bars": 8, "drums": "basic", "bass": "drive", "arp": True, "pad": True,
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
