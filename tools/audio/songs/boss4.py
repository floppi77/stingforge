"""Boss 4 - Fungus Mind. Eigener Bosskampf-Track. A-phrygian, 168 BPM."""

SONG = {
    "id": "boss4", "title": "Boss 4: Fungus Mind", "bpm": 168,
    "key": "A", "scale": "phrygian",
    "lead_oct": 5, "arp_oct": 4, "bass_oct": 1,
    "bars": 32, "chord_bars": 2,
    "chords": ['Am', 'F', 'Dm', 'E7'],
    "motifs": {
        "a": [(0, 0, 2), (1, 1, 2), (4, 0, 2), (6, 3, 2), (8, 4, 4), (12, 1, 2), (14, 0, 2), (16, 5, 2), (18, 4, 2), (20, 3, 2), (22, 1, 2), (24, 0, 8)],
        "b": [(0, 1, 4), (4, 3, 4), (8, 4, 4), (12, 6, 4)],
    },
    "arp": [0, 1, 0, 1, 2, 1, 0, 1, 0, 1, 0, 1, 3, 2, 1, 0],
    "bass": "drive",
    "atmos": "buzz",
    "kick_tune": 1.12,
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
