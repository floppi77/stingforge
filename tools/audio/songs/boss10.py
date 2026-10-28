"""Boss 10 - Kernorganismus. Eigener Bosskampf-Track. G#-harmonic_minor, 196 BPM."""

SONG = {
    "id": "boss10", "title": "Boss 10: Kernorganismus", "bpm": 196,
    "key": "G#", "scale": "harmonic_minor",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 1,
    "bars": 36, "chord_bars": 2,
    "chords": ['G#m', 'E', 'C#m', 'D#7'],
    "motifs": {
        "a": [(0, 0, 2), (2, 0, 2), (4, 3, 2), (6, 0, 2), (8, 7, 2), (10, 6, 2), (12, 4, 4), (16, 0, 2), (18, 1, 2), (20, 3, 2), (22, 4, 2), (24, 7, 4), (28, 3, 4)],
        "b": [(0, 7, 2), (2, 8, 2), (4, 7, 2), (6, 4, 2), (8, 3, 4), (12, 0, 4)],
    },
    "arp": [0, 2, 3, 2, 0, 2, 3, 4, 0, 2, 3, 2, 5, 4, 3, 2],
    "bass": "drive",
    "atmos": "machine",
    "kick_tune": 1.30,
    "presets": {'lead': 'lead_saw', 'arp': 'arp_pulse', 'bass': 'bass_drive', 'pad': 'pad_string'},
    "balance": {"bass": -2.5, "drums": -3.0},
    "rms_db": -14.5,
    "sections": [
        {"bars": 8, "drums": "sparse", "bass": "drive", "arp": True, "pad": True,
         "crash": True},
        {"bars": 8, "drums": "full", "bass": "drive", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "crash": True,
         "fill": "snare_roll"},
        {"bars": 12, "drums": "full", "bass": "boogie", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 4, "mel_gap": 2, "harm": 3,
         "crash": True, "fill": "tom_fill", "riser": True},
        {"bars": 8, "drums": "full", "bass": "drive", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "mel_oct": 1,
         "crash": True, "fill": "snare_roll", "riser": True},
    ],
}
