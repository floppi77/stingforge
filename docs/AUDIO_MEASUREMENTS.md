# Audio-Messwerte

Automatisch erzeugt von `tools/audio/verify.py` (nicht von Hand pflegen).
Alle Werte sind an der ausgelieferten Datei gemessen, also am dekodierten OGG.

## Musik

| Titel | Dauer | BPM | Tonart | Peak (OGG) | RMS | Crest | Loopnaht Δ | Sprung | Spektralzentrum | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| boss | 48.61 s | 158 | F harmonic_minor | -1.44 dBFS | -14.56 dBFS | 13.1 dB | +3.3 dB | 0.78 | 809 Hz | OK |
| boss1 | 51.20 s | 150 | F harmonic_minor | -1.53 dBFS | -14.80 dBFS | 13.3 dB | +3.0 dB | 0.42 | 836 Hz | OK |
| boss10 | 44.08 s | 196 | G# harmonic_minor | -1.48 dBFS | -14.56 dBFS | 13.1 dB | -1.2 dB | 0.58 | 935 Hz | OK |
| boss2 | 49.23 s | 156 | C harmonic_minor | -1.48 dBFS | -14.54 dBFS | 13.1 dB | +2.7 dB | 1.02 | 730 Hz | OK |
| boss3 | 47.41 s | 162 | G dorian | -1.34 dBFS | -14.55 dBFS | 13.2 dB | +2.7 dB | 0.11 | 861 Hz | OK |
| boss4 | 45.71 s | 168 | A phrygian | -1.26 dBFS | -14.55 dBFS | 13.3 dB | +1.7 dB | 0.67 | 887 Hz | OK |
| boss5 | 44.14 s | 174 | D harmonic_minor | -1.36 dBFS | -14.57 dBFS | 13.2 dB | +1.6 dB | 0.45 | 784 Hz | OK |
| boss6 | 44.65 s | 172 | E lydian | -1.67 dBFS | -14.51 dBFS | 12.8 dB | +1.9 dB | 0.08 | 762 Hz | OK |
| boss7 | 43.64 s | 176 | B minor | -1.65 dBFS | -14.55 dBFS | 12.9 dB | +1.2 dB | 0.11 | 972 Hz | OK |
| boss8 | 41.74 s | 184 | C# phrygian | -1.40 dBFS | -14.55 dBFS | 13.2 dB | +0.0 dB | 0.82 | 714 Hz | OK |
| boss9 | 40.85 s | 188 | F# phrygian | -1.66 dBFS | -14.56 dBFS | 12.9 dB | +1.2 dB | 0.43 | 836 Hz | OK |
| ending | 66.21 s | 116 | Bb major | -1.83 dBFS | -15.50 dBFS | 13.7 dB | +7.5 dB | 0.04 | 1196 Hz | OK |
| level1 | 58.18 s | 132 | D major | -1.21 dBFS | -15.11 dBFS | 13.9 dB | +4.5 dB | 0.13 | 965 Hz | OK |
| level10 | 57.31 s | 134 | D harmonic_minor | -1.40 dBFS | -15.05 dBFS | 13.7 dB | +3.2 dB | 0.85 | 815 Hz | OK |
| level2 | 65.08 s | 118 | A minor | -1.59 dBFS | -15.02 dBFS | 13.4 dB | +6.3 dB | 0.13 | 574 Hz | OK |
| level3 | 55.65 s | 138 | G major | -1.96 dBFS | -15.01 dBFS | 13.0 dB | +4.1 dB | 0.62 | 627 Hz | OK |
| level4 | 68.57 s | 112 | F# dorian | -1.77 dBFS | -15.00 dBFS | 13.2 dB | +7.6 dB | 0.38 | 694 Hz | OK |
| level5 | 51.20 s | 150 | E minor | -1.46 dBFS | -15.09 dBFS | 13.6 dB | +6.0 dB | 0.59 | 982 Hz | OK |
| level6 | 60.00 s | 128 | B major | -1.95 dBFS | -15.00 dBFS | 13.1 dB | +6.0 dB | 0.64 | 1016 Hz | OK |
| level7 | 62.95 s | 122 | C minor | -1.71 dBFS | -15.40 dBFS | 13.7 dB | +9.7 dB | 0.71 | 666 Hz | OK |
| level8 | 54.86 s | 140 | G minor | -1.79 dBFS | -15.01 dBFS | 13.2 dB | +5.9 dB | 0.04 | 667 Hz | OK |
| level9 | 52.60 s | 146 | A mixolydian | -1.42 dBFS | -15.08 dBFS | 13.7 dB | +3.9 dB | 0.25 | 1171 Hz | OK |
| level_clear | 15.00 s | 128 | C major | -2.18 dBFS | -15.18 dBFS | 13.0 dB | +8.1 dB | 0.92 | 694 Hz | OK |
| menu | 57.60 s | 100 | C lydian | -2.40 dBFS | -16.98 dBFS | 14.6 dB | +11.4 dB | 0.11 | 513 Hz | OK |

Loopnaht Δ = Pegel der letzten 50 ms minus Pegel der ersten 50 ms.
Sprung = Sprunghöhe an der Naht im Verhältnis zur 99-%-Sample-Differenz im Stück (< 1 heißt: unauffälliger als ein normaler Sample-Schritt).

### Energiekurve je Titel (1-s-Fenster)

**boss**  `++++++++++++*########*###*+*#+*#+*#+*****#******`

Viertel-RMS: -17.8 / -13.6 / -14.9 / -14.1 dBFS; lauteste Stelle bei 32s (-13.2 dBFS); Steigerung zum dritten Viertel

**boss1**  `++++++++++++**#*#***#***###****+#*+**+****#*******#`

Viertel-RMS: -17.9 / -14.1 / -15.1 / -14.5 dBFS; lauteste Stelle bei 33s (-13.4 dBFS); Steigerung zum dritten Viertel

**boss10**  `+++++++++*###########+#**#+#*+++++*#########`

Viertel-RMS: -17.7 / -13.7 / -15.7 / -13.7 dBFS; lauteste Stelle bei 23s (-12.8 dBFS); Steigerung zum dritten Viertel

**boss2**  `++++++++++++*#*##*#*##*###+*#**#**#****####*#*###`

Viertel-RMS: -17.8 / -13.7 / -14.8 / -13.8 dBFS; lauteste Stelle bei 29s (-12.8 dBFS); Steigerung zum dritten Viertel

**boss3**  `++++++++++++#######*#####**#**#+*#+**##*#******`

Viertel-RMS: -18.4 / -13.7 / -14.6 / -14.2 dBFS; lauteste Stelle bei 28s (-12.7 dBFS); Steigerung zum dritten Viertel

**boss4**  `++++++=++=+*##*#*##*####**#**#+*#+*####*##*##`

Viertel-RMS: -18.5 / -13.8 / -14.6 / -14.0 dBFS; lauteste Stelle bei 27s (-12.9 dBFS); Steigerung zum dritten Viertel

**boss5**  `+++++++++++############**#**#+**+**#*##*##*#`

Viertel-RMS: -18.9 / -13.4 / -15.0 / -13.7 dBFS; lauteste Stelle bei 23s (-13.0 dBFS); Steigerung zum dritten Viertel

**boss6**  `+++=+++++++*#**#*######*+#*+#**#**##########`

Viertel-RMS: -18.8 / -13.7 / -14.8 / -13.4 dBFS; lauteste Stelle bei 40s (-13.0 dBFS); Steigerung zum dritten Viertel

**boss7**  `+++++++++++############**#+#*+#***#*##*##*#`

Viertel-RMS: -18.5 / -13.9 / -14.5 / -14.0 dBFS; lauteste Stelle bei 22s (-13.1 dBFS); Steigerung zum dritten Viertel

**boss8**  `++++++++++*#*#########+**+#**#****#*#**#*`

Viertel-RMS: -18.4 / -13.5 / -14.7 / -14.1 dBFS; lauteste Stelle bei 19s (-13.0 dBFS); Steigerung zum dritten Viertel

**boss9**  `+++==+++=+####*#######*#**#+#********#**`

Viertel-RMS: -19.2 / -13.4 / -14.6 / -14.0 dBFS; lauteste Stelle bei 16s (-12.8 dBFS); Steigerung zum dritten Viertel

**ending**  `****+=+=****+===*##%#********++++**++***+***++++++************++++`

Viertel-RMS: -18.1 / -14.6 / -16.7 / -15.5 dBFS; lauteste Stelle bei 20s (-10.9 dBFS); Steigerung zum dritten Viertel

**level1**  `==-=-=:=:====-*##########*++*##+*#**##*+**+**#*#*#*##**+++`

Viertel-RMS: -22.4 / -14.2 / -14.9 / -14.3 dBFS; lauteste Stelle bei 31s (-12.3 dBFS); Steigerung zum dritten Viertel

**level10**  `======-=====+=***#***#*#*****#*+##**#*+##**##########*+**`

Viertel-RMS: -20.8 / -14.6 / -14.7 / -14.0 dBFS; lauteste Stelle bei 41s (-12.7 dBFS); Steigerung zum dritten Viertel

**level2**  `+=+=+=+=+=+=+=+=*##*#######**++**#*+*##+*##++*****#######**#**+*+`

Viertel-RMS: -20.5 / -14.0 / -15.1 / -14.4 dBFS; lauteste Stelle bei 21s (-12.6 dBFS); Steigerung zum dritten Viertel

**level3**  `==-=-=-==-=-=+*###*##*##*++*#**##**#***+**#####*####*++`

Viertel-RMS: -21.4 / -14.6 / -14.7 / -14.0 dBFS; lauteste Stelle bei 36s (-12.1 dBFS); Steigerung zum dritten Viertel

**level4**  `***=+=+=+=+====+-**#**+++*****+=+=##%%%+++*####*+++###%%++++#****+++`

Viertel-RMS: -19.1 / -16.4 / -14.5 / -15.2 dBFS; lauteste Stelle bei 38s (-9.8 dBFS); Steigerung zum dritten Viertel; Breakdown bei 34s

**level5**  `+++++=++++++*#*+#*+##+##+*#**#*+#*+##+*#+*#++#*+#*+`

Viertel-RMS: -19.2 / -14.8 / -14.7 / -15.5 dBFS; lauteste Stelle bei 27s (-12.1 dBFS); Steigerung zum dritten Viertel

**level6**  `+====+=+=+=+=+=###*###*##*++++###*###*##*++++###*###*##*++++`

Viertel-RMS: -19.8 / -14.6 / -14.7 / -14.6 dBFS; lauteste Stelle bei 40s (-12.5 dBFS); Steigerung zum dritten Viertel

**level7**  `***=====-=-=-=-+##*###**##**+++*##+##*+##*+++++###**+++#*#*+++`

Viertel-RMS: -20.6 / -14.6 / -15.3 / -15.5 dBFS; lauteste Stelle bei 37s (-12.5 dBFS); Steigerung zum dritten Viertel

**level8**  `+++++++++++++*#*+##+*#*+#*+##**#*+*#+*#*+##+*#*+##+*#+`

Viertel-RMS: -18.3 / -14.7 / -14.9 / -15.1 dBFS; lauteste Stelle bei 15s (-11.9 dBFS); Steigerung zum dritten Viertel

**level9**  `+++++++++++++##+*#+*#*+#*+##+*#**#*+##+*#+*#*+#*+*#+`

Viertel-RMS: -18.4 / -15.3 / -14.5 / -15.3 dBFS; lauteste Stelle bei 31s (-12.3 dBFS); Steigerung zum dritten Viertel

**level_clear**  `***+******+**+*`

Viertel-RMS: -16.2 / -15.1 / -14.1 / -15.8 dBFS; lauteste Stelle bei 6s (-13.8 dBFS); Steigerung zum dritten Viertel; Ruecknahme zum Loopende (Uebergang in den Anfang)

**menu**  `#****=-=-+++**+-==-#******+=+**+=+==+=**+**+====*+***=-+=`

Viertel-RMS: -17.7 / -17.9 / -17.8 / -18.4 dBFS; lauteste Stelle bei 1s (-12.8 dBFS); gleichmaessiger Pegel; Breakdown bei 19s

## Soundeffekte

| Name | Dauer | Peak | RMS | Format | Status |
|---|---|---|---|---|---|
| shot_base | 75 ms | -13.12 dBFS | -25.42 dBFS | 44100 Hz / 1 ch | OK |
| shot_fan | 105 ms | -12.52 dBFS | -25.31 dBFS | 44100 Hz / 1 ch | OK |
| shot_lightning | 115 ms | -12.50 dBFS | -28.45 dBFS | 44100 Hz / 1 ch | OK |
| shot_plasma | 135 ms | -12.50 dBFS | -26.63 dBFS | 44100 Hz / 1 ch | OK |
| hit | 55 ms | -11.00 dBFS | -30.55 dBFS | 44100 Hz / 1 ch | OK |
| explosion_small | 420 ms | -7.50 dBFS | -18.72 dBFS | 44100 Hz / 1 ch | OK |
| explosion_big | 950 ms | -5.50 dBFS | -15.45 dBFS | 44100 Hz / 2 ch | OK |
| player_hit | 380 ms | -8.13 dBFS | -19.73 dBFS | 44100 Hz / 2 ch | OK |
| shield_hit | 170 ms | -9.50 dBFS | -28.84 dBFS | 44100 Hz / 1 ch | OK |
| shield_break | 500 ms | -8.00 dBFS | -24.64 dBFS | 44100 Hz / 1 ch | OK |
| bomb | 1050 ms | -4.50 dBFS | -14.83 dBFS | 44100 Hz / 2 ch | OK |
| pickup_nectar | 140 ms | -14.00 dBFS | -22.56 dBFS | 44100 Hz / 1 ch | OK |
| pickup_heart | 240 ms | -13.50 dBFS | -25.00 dBFS | 44100 Hz / 1 ch | OK |
| purchase | 380 ms | -13.00 dBFS | -23.90 dBFS | 44100 Hz / 1 ch | OK |
| deny | 190 ms | -13.00 dBFS | -21.79 dBFS | 44100 Hz / 1 ch | OK |
| ui_move | 50 ms | -20.58 dBFS | -33.23 dBFS | 44100 Hz / 1 ch | OK |
| ui_ok | 100 ms | -18.00 dBFS | -28.49 dBFS | 44100 Hz / 1 ch | OK |
| ui_back | 90 ms | -18.50 dBFS | -28.85 dBFS | 44100 Hz / 1 ch | OK |
| boss_warn | 1250 ms | -8.00 dBFS | -14.60 dBFS | 44100 Hz / 1 ch | OK |
| phase_change | 850 ms | -6.50 dBFS | -21.59 dBFS | 44100 Hz / 1 ch | OK |
| boss_death | 1900 ms | -4.50 dBFS | -13.83 dBFS | 44100 Hz / 2 ch | OK |
| level_clear | 1650 ms | -6.00 dBFS | -20.72 dBFS | 44100 Hz / 2 ch | OK |
| game_over | 1900 ms | -7.00 dBFS | -19.08 dBFS | 44100 Hz / 2 ch | OK |
| checkpoint | 750 ms | -11.00 dBFS | -21.80 dBFS | 44100 Hz / 1 ch | OK |
| low_hp_warn | 320 ms | -9.00 dBFS | -18.71 dBFS | 44100 Hz / 1 ch | OK |
| combo_ready | 280 ms | -12.00 dBFS | -22.18 dBFS | 44100 Hz / 1 ch | OK |
