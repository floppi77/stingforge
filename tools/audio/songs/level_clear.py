"""Level geschafft - kurzer Jubel-Loop (Fanfare + Groove), C-Dur, 128 BPM.

Das Spiel ruft beim Levelabschluss `Audio.play_music("level_clear")` auf
(scripts/game/game.gd). Diese Datei fuellt diesen Aufruf: acht Takte, die als
Fanfare funktionieren und als Schleife weiterlaufen koennen, ohne weh zu tun.
"""

SONG = {
    "id": "level_clear", "title": "Level geschafft", "bpm": 128,
    "key": "C", "scale": "major",
    "lead_oct": 5, "arp_oct": 5, "bass_oct": 2,
    "bars": 8, "chord_bars": 2,
    "chords": ["C", "F", "G", "C"],
    "motifs": {
        # Fanfare: C-E-G-C, dann Antwortphrase
        "a": [(0, 0, 2), (2, 2, 2), (4, 4, 2), (6, 7, 4), (10, 4, 2), (12, 7, 4),
              (16, 9, 4), (20, 11, 4), (24, 12, 8)],
        "b": [(0, 12, 4), (4, 11, 2), (6, 12, 2), (8, 9, 4), (12, 7, 4)],
    },
    "arp": [0, 2, 3, 1, 2, 3],
    "bass": "drive",
    "atmos": "air",
    "presets": {"lead": "lead_bell", "arp": "arp_bell",
                "bass": "bass_round", "pad": "pad_glass"},
    "balance": {"pad": -6.0, "drums": -4.0},
    "rms_db": -15.2,
    "turnaround_crash": 0.35,
    "sections": [
        {"bars": 2, "drums": "sparse", "bass": "half", "pad": True,
         "melody": "a", "mel_reps": 1},
        {"bars": 2, "drums": "basic", "bass": "drive", "arp": True, "pad": True,
         "melody": "a", "mel_reps": 1},
        {"bars": 4, "drums": "four", "bass": "drive", "arp": True, "pad": True,
         "melody": "b", "mel_reps": 2, "mel_gap": 2, "crash": True,
         "riser": True},
    ],
}
