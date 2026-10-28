#!/usr/bin/env python3
"""Alpha/wrapping property tests plus schedules through real Godot.

Use installed Hypothesis when present; otherwise explicit seeded no-install mode.
No import, cache clearing, editor or window is started here. Runtime schedules are
batch-executed (not shrunk); Hypothesis source-alpha properties are shrinkable.
"""
from __future__ import annotations
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import random
import numpy as np
from PIL import Image
try:
    from hypothesis import given, settings, strategies as st
    HAVE_HYPOTHESIS = True
except ImportError:
    HAVE_HYPOTHESIS = False

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/stingforge-r2-parallax'
MASKS = {}
for n in range(1, 11):
    for role in ('near','reeds','roots'):
        MASKS[n, role] = np.array(Image.open(ROOT/f'assets/bg/l{n:02d}_{role}.png').convert('RGBA'))[:,:,3]
SAMPLES = []


def check_soil(n, role, offset, x):
    alpha = MASKS[n, role]
    source_x = math.floor(x + offset) % alpha.shape[1]
    assert alpha[475, source_x] >= 24, (n,role,offset,x,source_x)
    assert alpha[475, (source_x+1) % alpha.shape[1]] >= 24


if HAVE_HYPOTHESIS:
    soil_survives_arbitrary_scroll_seams = settings(max_examples=250, derandomize=True, database=None, deadline=None)(
        given(n=st.integers(1,10), role=st.sampled_from(('near','reeds','roots')),
              offset=st.floats(-100000,100000,allow_nan=False,allow_infinity=False),
              x=st.integers(0,959))(check_soil))

    @st.composite
    def schedules(draw):
        # Integer microseconds keep sum(parts) equal to total.
        level=draw(st.integers(1,10))
        ticks=draw(st.integers(1,10000000))
        cuts=sorted(set([0,ticks]+draw(st.lists(st.integers(0,ticks),min_size=0,max_size=18))))
        return {'level':level,'start':draw(st.floats(-10000,10000,allow_nan=False,allow_infinity=False)),
                'speed':draw(st.floats(0,250,allow_nan=False,allow_infinity=False)),
                'bonus':draw(st.floats(-0.5,1.5,allow_nan=False,allow_infinity=False)),
                'total':ticks/1000000,'parts':[(b-a)/1000000 for a,b in zip(cuts,cuts[1:])]}

    @settings(max_examples=100, derandomize=True, database=None, deadline=None)
    @given(sample=schedules())
    def generate_runtime_schedules(sample):
        SAMPLES.append(sample)
else:
    # Explicit no-install fallback: repeatable seeded cases, NOT called Hypothesis.
    def soil_survives_arbitrary_scroll_seams():
        rng=random.Random(272104)
        for _ in range(250):
            check_soil(rng.randint(1,10),rng.choice(('near','reeds','roots')),rng.uniform(-100000,100000),rng.randrange(960))

    def generate_runtime_schedules():
        rng=random.Random(272105)
        for i in range(100):
            ticks=rng.randint(1,10000000)
            cuts=sorted(set([0,ticks]+[rng.randrange(ticks+1) for _ in range(rng.randint(1,18))]))
            SAMPLES.append({'level':i%10+1,'start':rng.uniform(-10000,10000),
                            'speed':rng.uniform(0,250),'bonus':rng.uniform(-0.5,1.5),
                            'total':ticks/1000000,'parts':[(b-a)/1000000 for a,b in zip(cuts,cuts[1:])]})


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    soil_survives_arbitrary_scroll_seams()
    generate_runtime_schedules()
    sample_file=OUT/'hypothesis-schedules.json'
    sample_file.write_text(json.dumps(SAMPLES,indent=2),encoding='utf-8')
    env=os.environ.copy()
    for suffix,name in [('DATA','data'),('CONFIG','config'),('CACHE','cache')]:
        path=ROOT/'build/stingforge-r2-testdata-parallax'/name
        path.mkdir(parents=True,exist_ok=True)
        env[f'XDG_{suffix}_HOME']=str(path)
    command=[shutil.which('godot') or 'godot','--headless','--path',str(ROOT),'--audio-driver','Dummy',
             '--scene','res://tests/stingforge_r2_parallax_probe.tscn','--','--parallax-properties-only',
             '--parallax-samples='+str(sample_file)]
    run=subprocess.run(command,cwd=ROOT,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    (OUT/'hypothesis-runtime.log').write_text(run.stdout,encoding='utf-8')
    print(run.stdout)
    assert run.returncode == 0, 'Real Background.update failed generated delta schedules'
    assert 'STINGFORGE_R2_PARALLAX_OK' in run.stdout
    assert not any(word in run.stdout for word in ('SCRIPT ERROR:', 'ERROR:', 'WARNING:'))
    engine='HYPOTHESIS' if HAVE_HYPOTHESIS else 'SEEDED_NO_HYPOTHESIS_INSTALLED'
    print(f'PARALLAX_PROPERTIES_OK ({engine}): 250 alpha cases + {len(SAMPLES)} real Godot schedules')


if __name__=='__main__':
    main()
