"""Boss 7 - Canal Crawler. Eigener Bosskampf-Track. B-minor, 176 BPM."""

SONG = {
    "id": "boss7", "title": "Boss 7: Canal Crawler", "bpm": 176,
    "key": "B", "scale": "minor",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 1,
    "bars": 32, "chord_bars": 2,
    "chords": ['Bm', 'G', 'Em', 'F#7'],
    "motifs": {
        "a": [(0, 0, 2), (3, 2, 2), (6, 4, 2), (8, 2, 2), (10, 0, 2), (12, 4, 4), (16, 7, 2), (18, 6, 2), (20, 4, 2), (22, 2, 2), (24, 0, 4), (28, 4, 4)],
        "b": [(0, 2, 4), (4, 4, 4), (8, 6, 4), (12, 7, 4)],
    },
    "arp": [0, 2, 1, 2, 0, 2, 1, 2, 0, 2, 1, 3, 2, 1, 2, 0],
    "bass": "drive",
    "atmos": "water",
    "kick_tune": 1.21,
    "presets": {'lead': 'lead_pulse', 'arp': 'arp_pulse', 'bass': 'bass_drive', 'pad': 'pad_drone'},
    "balance": {"bass": -2.5, "drums": -3.0},
    "rms_db": -14.5,
    "sections": [
        {"bars": 8, "drums": "sparse", "bass": "drive", "arp": True, "pad": True,
         "crash": True},
        {"bars": 8, "drums": "drive", "bass": "drive", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "crash": True,
         "fill": "snare_roll"},
        {"bars": 8, "drums": "drive", "bass": "boogie", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 4, "mel_gap": 2, "harm": 3,
         "crash": True, "fill": "tom_fill", "riser": True},
        {"bars": 8, "drums": "full", "bass": "drive", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 4, "mel_gap": 2, "mel_oct": 1,
         "crash": True, "fill": "snare_roll", "riser": True},
    ],
}
