; Stingforge-Soundtrack: Csound-Instrumente (offline, 48 kHz, Stereo).
; Partiturfelder: p4 = Tonhöhe (Hz), p5 = Lautstärke 0..1, p6 = Helligkeit 0..1,
; p7 = Zusatz (je Instrument), p8 = Panorama -1..1.

sr = 48000
ksmps = 16
nchnls = 2
0dbfs = 1
seed 7

giSine ftgen 0, 0, 16384, 10, 1

opcode Pan, aa, ak
  ain, kpan xin
  kp = (kpan + 1) * 0.5
  xout ain * cos(kp * 1.5708), ain * sin(kp * 1.5708)
endop

; --- Pad: fünf leicht verstimmte Sägezähne, weicher Tiefpass, langsamer Ein-/Ausklang
instr pad
  ifrq = p4
  iamp = p5 * 0.16
  ibr = p6
  iatk = min(p3 * 0.35, 0.9)
  irel = 1.2
  p3 = p3 + irel
  kenv linsegr 0, iatk, 1, p3 - iatk - irel, 0.85, irel, 0
  klfo lfo 0.18, 0.21
  a1 vco2 1, ifrq * cent(-11 + klfo * 3)
  a2 vco2 1, ifrq * cent(-4)
  a3 vco2 1, ifrq
  a4 vco2 1, ifrq * cent(5)
  a5 vco2 1, ifrq * cent(12 - klfo * 3)
  asub vco2 0.5, ifrq * 0.5, 12
  aL = (a1 + a2 * 0.8 + a3 * 0.5 + asub * 0.6)
  aR = (a5 + a4 * 0.8 + a3 * 0.5 + asub * 0.6)
  kcut = 500 + ibr * 3400 + kenv * 900 + klfo * 300
  aL moogladder aL, kcut, 0.12
  aR moogladder aR, kcut, 0.12
  outs aL * kenv * iamp, aR * kenv * iamp
endin

; --- Bass: Sägezahn + Sinus-Sub, Filterhüllkurve, kurz und rund
instr bass
  ifrq = p4
  iamp = p5 * 0.42
  ibr = p6
  irel = 0.08
  p3 = p3 + irel
  kenv linsegr 0, 0.004, 1, 0.12, 0.75, p3, 0.6, irel, 0
  kfenv expseg 1, 0.18, 0.25, p3, 0.2
  asaw vco2 1, ifrq
  asub oscili 1, ifrq, giSine
  afilt moogladder asaw, 180 + ibr * 1600 * kfenv + 120, 0.25
  aout = (afilt * 0.75 + asub * 0.55) * kenv * iamp
  outs aout, aout
endin

; --- Summ-Lead (Biene): FM mit Vibrato, leichter Hauch, sanftes Gleiten
instr lead
  ifrq = p4
  iamp = p5 * 0.2
  ibr = p6
  irel = 0.18
  p3 = p3 + irel
  kenv linsegr 0, 0.03, 1, 0.2, 0.8, p3, 0.7, irel, 0
  kvdel linseg 0, 0.25, 0, 0.35, 1
  kvib lfo 0.006 * kvdel, 5.6
  kfrq = ifrq * (1 + kvib)
  kidx = 1.2 + ibr * 2.2 * kenv
  afm foscili 1, kfrq, 1, 2.001, kidx, giSine
  abuzz vco2 0.25, kfrq, 2, 0.32
  abuzz butterbp abuzz, kfrq * 3, kfrq * 2
  anoise rand 0.03
  anoise butterbp anoise, kfrq * 4, kfrq
  asig = (afm + abuzz + anoise) * kenv * iamp
  asig butterlp asig, 6500
  aL, aR Pan asig, p8
  outs aL, aR
endin

; --- Pluck: helles Zupfen (Pollenfunken)
instr pluck
  ifrq = p4
  iamp = p5 * 0.22
  ibr = p6
  p3 = max(p3, 0.4) + 0.6
  aenv expsegr 1, p3, 0.001, 0.3, 0.001
  a1 vco2 1, ifrq, 10
  a2 vco2 0.6, ifrq * 2.003, 10
  kcut expseg 800 + ibr * 7000, 0.25, 600, p3, 400
  asig moogladder a1 + a2, kcut, 0.2
  asig = asig * aenv * iamp
  aL, aR Pan asig, p8
  outs aL, aR
endin

; --- Riser: gefiltertes Rauschen + steigender Ton, p3 = Dauer
instr riser
  iamp = p5 * 0.22
  kenv expseg 0.001, p3 * 0.92, 1, p3 * 0.08, 0.001
  kfrq expseg 300, p3, 7000
  anoise rand 1
  an butterbp anoise, kfrq, kfrq * 0.6
  kp expseg p4, p3, p4 * 4
  aston vco2 0.3, kp
  aston butterlp aston, kfrq
  asig = (an + aston) * kenv * iamp
  aL = asig
  aR delay asig, 0.007
  outs aL, aR
endin

; --- Boom: tiefer Einschlag mit Tonhöhenfall und kurzem Rauschtransienten
instr boom
  iamp = p5 * 0.8
  p3 = max(p3, 2.4)
  kfrq expseg p4 * 2, 0.08, p4, p3, p4 * 0.6
  aenv expseg 1, p3, 0.0005
  asine oscili 1, kfrq, giSine
  asine = tanh(asine * 1.6)
  anoise rand 1
  kntenv expseg 1, 0.06, 0.001, p3, 0.001
  anoise butterlp anoise, 1800
  asig = (asine * aenv + anoise * kntenv * 0.35) * iamp
  outs asig, asig
endin

; --- Swell: Rauschwelle (umgekehrtes Becken), p3 = Dauer
instr swell
  iamp = p5 * 0.14
  kenv expseg 0.001, p3 * 0.97, 1, p3 * 0.03, 0.001
  anoise rand 1
  aL butterhp anoise, 3000
  anoise2 rand 1, 0.37
  aR butterhp anoise2, 3000
  outs aL * kenv * iamp, aR * kenv * iamp
endin

; =====================================================================
; Erweiterung für Level 2–10 (additiv, Level 1 unberührt)
; =====================================================================

; --- Orgel: additive Register, leichtes Chorus-Schweben, langsames Tremolo
;     p6 = Helligkeit (Zugriegel der Oberstimmen), p7 = Anteil der 16'-Lage
instr organ
  ifrq = p4
  iamp = p5 * 0.16
  ibr = p6
  isub16 = p7
  irel = 0.45
  p3 = p3 + irel
  iatk = min(p3 * 0.08, 0.25)
  kenv linsegr 0, iatk, 1, p3 - iatk - irel, 0.82, irel, 0
  ktr lfo 0.14, 0.23
  kdet = 1 + ktr * 0.0012
  a16 oscili 0.55 * isub16, ifrq * 0.5 * kdet, giSine
  a8 oscili 0.70, ifrq, giSine
  a8b oscili 0.45, ifrq * 1.0016, giSine
  a4 oscili 0.40 + ibr * 0.25, ifrq * 2, giSine
  a3 oscili 0.16 + ibr * 0.30, ifrq * 3, giSine
  a2 oscili 0.10 + ibr * 0.30, ifrq * 4, giSine
  a1 oscili 0.06 + ibr * 0.28, ifrq * 6, giSine
  a1b oscili 0.04 + ibr * 0.20, ifrq * 8, giSine
  asig = (a16 + a8 + a8b + a4 + a3 + a2 + a1 + a1b) * kenv * iamp
  kles lfo 1, 5.5
  aL, aR Pan asig, p8
  kair = 0.85 + kles * 0.15
  outs aL * kair, aR * (1.7 - kair) * 0.59
endin

; --- Chor: drei verstimmte Sägezähne mit Vokalformanten und Hauch
;     p7 = Vokal (0 = "ah", 1 = "oh", 2 = "uu")
instr choir
  ifrq = p4
  iamp = p5 * 0.38
  ibr = p6
  ivow = p7
  irel = 0.6
  p3 = p3 + irel
  iatk = min(p3 * 0.22, 1.1)
  kenv linsegr 0, iatk, 1, p3 - iatk - irel, 0.8, irel, 0
  kvib lfo 0.0042, 4.9
  kf = ifrq * (1 + kvib)
  a1 vco2 1, kf * cent(-9)
  a2 vco2 1, kf
  a3 vco2 1, kf * cent(8)
  asrc = (a1 + a2 * 1.1 + a3) * 0.42
  if ivow == 0 then
    kf1 = 700
    kf2 = 1180
    kf3 = 2600
    kg3 = 0.30 + ibr * 0.30
  elseif ivow == 1 then
    kf1 = 450
    kf2 = 810
    kf3 = 2560
    kg3 = 0.18 + ibr * 0.22
  else
    kf1 = 330
    kf2 = 700
    kf3 = 2500
    kg3 = 0.12 + ibr * 0.16
  endif
  aF1 butterbp asrc, kf1 * 2, 260
  aF2 butterbp asrc, kf2 * 2, 320
  aF3 butterbp asrc, kf3 * 2, 900
  anoise rand 0.06
  abreath butterbp anoise, 2400, 2200
  asig = (aF1 * 1.0 + aF2 * 0.72 + aF3 * kg3 + abreath * 0.35) * kenv * iamp
  asig butterlp asig, 7000
  aL, aR Pan asig, p8
  aR delay aR, 0.012
  outs aL, aR
endin

; --- Drohne (didgeridoo-artig): tiefe Sägezahn, Formantfilter, Zirkularatem-Wobble
;     p3 = Dauer, p7 = Wobble-Rate in Hz
instr drone
  ifrq = p4
  iamp = p5 * 0.52
  ibr = p6
  irate = p7
  if irate <= 0 then
    irate = 3.4
  endif
  irel = 0.8
  p3 = p3 + irel
  iatk = min(p3 * 0.15, 1.6)
  kenv linsegr 0, iatk, 1, p3 - iatk - irel, 0.9, irel, 0
  kwob lfo 1, irate
  kamod = 0.72 + kwob * 0.24
  kf = ifrq * (1 + kwob * 0.004)
  a1 vco2 1, kf
  a2 vco2 0.7, kf * 1.004
  asub oscili 0.55, kf * 0.5, giSine
  asrc = (a1 + a2) * 0.5 + asub
  aform butterbp asrc, 380 + ibr * 520 + kwob * 60, 260
  alow moogladder asrc, 260 + ibr * 400, 0.18
  anoise rand 1
  atongue butterbp anoise, 900 + ibr * 900, 700
  ktenv expseg 1, 0.5, 0.35, p3, 0.2   ; Rauschanteil (Zunge, Atem)
  asig = (aform * 1.25 + alow * 0.8 + atongue * ktenv * 0.5) * kamod * kenv * iamp
  aL, aR Pan asig, p8
  outs aL, aR
endin

; --- Glas: FM-Glocke mit unharmonischem Verhältnis (Glasharmonika, Sequencer-Pings)
instr glass
  ifrq = p4
  iamp = p5 * 0.20
  ibr = p6
  irel = 2.2
  p3 = p3 + irel
  aenv expsegr 1, p3, 0.0008, 0.25, 0.0008
  kidx = 0.7 + ibr * 3.2
  a1 foscili 1, ifrq, 1, 3.53, kidx, giSine
  a2 foscili 0.35, ifrq * 2.0, 1, 1.41, kidx * 0.5, giSine
  a3 oscili 0.12, ifrq * 4.02, giSine
  asig = (a1 + a2 + a3) * aenv * iamp
  asig butterlp asig, 9000
  aL, aR Pan asig, p8
  outs aL, aR
endin

; --- Taiko: große Fell-Trommel, Tonhöhenfall und Fell-Rauschanteil
instr taiko
  ifrq = p4
  iamp = p5 * 0.50
  ibr = p6
  p3 = max(p3, 0.9)
  kfrq expseg ifrq * 1.7, 0.055, ifrq, p3, ifrq * 0.86
  kpenv expsegr 1, p3 * 0.75, 0.001, p3 * 0.25, 0.0005
  asine oscili 1, kfrq, giSine
  asine = tanh(asine * 2.2)
  anoise rand 1
  kndec expseg 1, 0.045, 0.004, p3, 0.001
  anoise butterlp anoise, 900 + ibr * 1400
  abody butterbp asine, ifrq * 1.6, ifrq * 0.9
  asig = (asine * kpenv * 1.0 + abody * 0.5 + anoise * kndec * 0.55) * iamp
  outs asig, asig
endin

; --- Sub-Drop: Sinus fällt ab (Schwerkraftfelder, Wucht der Maschine)
instr sub
  ifrq = p4
  iamp = p5 * 0.62
  p3 = max(p3, 0.8)
  kfrq expseg ifrq, p3 * 0.8, ifrq * 0.42, p3, ifrq * 0.38
  aenv linsegr 0, 0.02, 1, p3 * 0.35, 0.75, p3 * 0.6, 0
  asig oscili 1, kfrq, giSine
  asig = tanh(asig * 1.4) * aenv * iamp
  outs asig, asig
endin

; --- Wind: gefiltertes Rauschen, Panorama und Filtermitte wandern (Sturmzonen)
instr wind
  iamp = p5 * 0.22
  ibr = p6
  iatk = min(p3 * 0.3, 3.5)
  irel = min(p3 * 0.3, 3.0)
  kenv linsegr 0, iatk, 0.9, p3 - iatk - irel, 1, irel, 0
  ksway lfo 1, 0.085
  kpanpos = p8 + ksway * 0.55
  klfo lfo 1, 0.11
  kcf = 480 + ibr * 1500 + klfo * 260
  anoise rand 1
  anoise2 rand 1, 0.41
  a1 butterbp anoise, kcf, kcf * 0.75
  a2 butterbp anoise2, kcf * 1.05, kcf * 0.7
  a1 butterhp a1, 220
  a2 butterhp a2, 220
  aL, aR Pan (a1 + a2) * kenv * iamp, kpanpos
  outs aL, aR
endin
