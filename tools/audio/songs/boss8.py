"""Boss 8 - Machine Heart. Eigener Bosskampf-Track. C#-phrygian, 184 BPM."""

SONG = {
    "id": "boss8", "title": "Boss 8: Machine Heart", "bpm": 184,
    "key": "C#", "scale": "phrygian",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 1,
    "bars": 32, "chord_bars": 2,
    "chords": ['C#dim', 'A', 'F#m', 'G#7'],
    "motifs": {
        "a": [(0, 0, 1), (1, 1, 1), (2, 0, 1), (3, 3, 1), (4, 0, 1), (5, 1, 1), (6, 0, 1), (7, 3, 1), (8, 4, 2), (10, 3, 2), (12, 1, 2), (14, 0, 2), (16, 7, 1), (17, 6, 1), (18, 4, 1), (19, 3, 1), (20, 1, 2), (22, 0, 2), (24, 3, 4), (28, 0, 4)],
        "b": [(0, 1, 2), (2, 3, 2), (4, 6, 2), (6, 7, 2), (8, 6, 2), (10, 4, 2), (12, 3, 2), (14, 1, 2)],
    },
    "arp": [0, 1, 2, 3, 4, 3, 2, 1, 0, 1, 2, 3, 4, 5, 4, 3],
    "bass": "drive",
    "atmos": "machine",
    "kick_tune": 1.24,
    "presets": {'lead': 'lead_saw', 'arp': 'arp_pulse', 'bass': 'bass_drive', 'pad': 'pad_string'},
    "balance": {"bass": -2.5, "drums": -3.0},
    "rms_db": -14.5,
    "sections": [
        {"bars": 8, "drums": "sparse", "bass": "drive", "arp": True, "pad": True,
         "crash": True},
        {"bars": 8, "drums": "full", "bass": "drive", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "crash": True,
         "fill": "snare_roll"},
        {"bars": 8, "drums": "full", "bass": "boogie", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 4, "mel_gap": 2, "harm": 3,
         "crash": True, "fill": "tom_fill", "riser": True},
        {"bars": 8, "drums": "full", "bass": "drive", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "mel_oct": 1,
         "crash": True, "fill": "snare_roll", "riser": True},
    ],
}
