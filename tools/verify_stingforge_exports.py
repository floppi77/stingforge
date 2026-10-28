#!/usr/bin/env python3
"""Startet die fertigen Einzeldateien, prüft Grafik und misst echte Spiellast."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
LOGS = ROOT/'build/logs/stingforge'
DATA = ROOT/'build/stingforge-testdata-binaries'


def run_logged(name, command, env, cwd, marker=None, timeout=60):
    log = LOGS/(name+'.log')
    with log.open('w') as stream:
        run = subprocess.run(command, env=env, cwd=cwd, stdout=stream,
                             stderr=subprocess.STDOUT, timeout=timeout)
    text = log.read_text(errors='replace')
    errors = [line for line in text.splitlines()
              if any(word in line for word in ['SCRIPT ERROR:', 'Parse Error:', 'Compile Error:'])]
    passed = run.returncode == 0 and not errors and (marker is None or marker in text.splitlines())
    print(name, 'exit=',run.returncode,'passed=',passed,flush=True)
    assert passed, (name,errors,run.returncode,log)
    return text


def main():
    DATA.mkdir(parents=True,exist_ok=True); LOGS.mkdir(parents=True,exist_ok=True)
    env = dict(os.environ, XDG_DATA_HOME=str(DATA/'data'), XDG_CONFIG_HOME=str(DATA/'config'),
               XDG_CACHE_HOME=str(DATA/'cache'), GSETTINGS_BACKEND='memory',
               LIBGL_ALWAYS_SOFTWARE='1',GALLIUM_DRIVER='llvmpipe',
               XDG_RUNTIME_DIR='/run/user/1000', WAYLAND_DISPLAY='wayland-1')
    report = []
    for platform,args,child_env in [
        ('linux',[str(ROOT/'build/linux/Stingforge.x86_64'),'--display-driver','wayland',
                  '--audio-driver','Dummy','--quit-after','60'],env),
        ('windows',['wine',str(ROOT/'build/windows/Stingforge.exe'),'--headless',
                    '--audio-driver','Dummy','--quit-after','30'],dict(env,
                    WINEPREFIX=str(ROOT/'build/windows/.wineprefix'),WINEDEBUG='-all'))]:
        run_logged('binary-'+platform+'-final',args,child_env,DATA)
        executable = ROOT/('build/linux/Stingforge.x86_64' if platform=='linux' else 'build/windows/Stingforge.exe')
        report.append({'platform':platform,'exit':0,'native':platform=='linux',
                       'windowed':platform=='linux','sha256':hashlib.sha256(executable.read_bytes()).hexdigest(),
                       'bytes':executable.stat().st_size})
    run_logged('visual-final',['python3','tests/stingforge_visual_checks.py','--screenshots'],
               env,ROOT,'STINGFORGE_VISUAL_CHECKS_OK',60)
    perf_env = dict(env,XDG_DATA_HOME=str(ROOT/'build/stingforge-testdata-perf'),
                    XDG_CONFIG_HOME=str(ROOT/'build/stingforge-testdata-perf/config'),
                    XDG_CACHE_HOME=str(ROOT/'build/stingforge-testdata-perf/cache'))
    text = run_logged('performance-final',['godot','--display-driver','wayland','--audio-driver','Dummy',
                      '--path',str(ROOT),'res://tests/perf.tscn','--','--maxed','--stress'],
                      perf_env,ROOT,'PERF_MESSUNG_OK',45)
    perf_lines = [line for line in text.splitlines() if line.startswith('PERF ')]
    for line in perf_lines: print(line,flush=True)
    (LOGS/'binaries-summary.json').write_text(json.dumps(report,indent=2)+'\n')
    (LOGS/'performance-summary.json').write_text(json.dumps({'lines':perf_lines,
        'renderer':'llvmpipe / Software-OpenGL','native_windows_tested':False},indent=2)+'\n')
    print('STINGFORGE_EXPORTS_OK',flush=True)
    return 0


if __name__=='__main__':
    raise SystemExit(main())
