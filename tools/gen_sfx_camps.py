"""Monster camp idle beds (docs/AUDIO.md, content/sfx/camps.json): a live camp heard before it is seen.

    cd tools && python3 gen_sfx_camps.py      (then: godot --headless --import)

  camp_bed_small  loop: two or so small monsters idling: a skitter's chitter runs and a spitter's gurgle
  camp_bed_camp   loop: a fuller camp: more chitter and gurgle, and a low grunt now and then
  camp_bed_great  loop: a big camp: dense chitter and gurgle over a brute's slow breathing grunts
  camp_relight    a cleared camp comes back: a chitter run that swells, a gurgle and a grunt waking up
Built from the same voices as the monsters' own calls (tools/gen_sfx.py skitter, spitter, brute), quieter
and scattered in time. Each loop's events wrap around its end, so it repeats with no gap. Original
synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, bpf, env, mix, at, voice

S.reseed(6206)

LOOP_S = 6.0      # s: each bed's length; long enough that its pattern does not read as a loop


def chitter(k):
    """A skitter's quick run of clicky mandible taps over a soft purr."""
    taps = [at(bpf(noise(0.03), 900 + 120 * k, 2200) * env(N(0.03), 0.002, 0.007), 0.032 * j + 0.006 * (j % 2))
            for j in range(3 + k % 3)]
    purr = voice(0.18, 170 + 20 * k, 140, 'eh', breath=0.3, scale=1.3, a=0.02) * 0.35
    return mix(purr, *taps)


def gurgle(k):
    """A spitter's wet throaty bubbling."""
    d = 0.4 + 0.05 * k
    n = N(d)
    v = voice(d, 115 + 8 * k, 92, 'oh', breath=0.2, rasp=0.25, a=0.04) * (0.5 + 0.5 * np.sin(2 * np.pi * (15 + 3 * k) * T(d)))
    return mix(v * 0.7, lpf(noise(d), 450) * env(n, 0.04, d * 0.4) * 0.6)


def grunt(k):
    """A brute's low breathing grunt."""
    return voice(0.38 + 0.04 * k, 84 + 6 * k, 62, 'uh', breath=0.3, rasp=0.5, scale=0.85, a=0.05)


def bed(chitters, gurgles, grunts, floor):
    """LOOP_S of idle voices scattered in time, over a breathy floor so the camp never drops to silence.
    Events past the end fold back onto the start (the loop repeats seamlessly)."""
    n = N(LOOP_S)
    out = lpf(noise(LOOP_S), 700) * floor
    for fn, count, gain in [(chitter, chitters, 0.5), (gurgle, gurgles, 0.6), (grunt, grunts, 0.8)]:
        for i in range(count):
            x = fn(int(S.rng.integers(0, 4))) * gain * S.rng.uniform(0.6, 1.0)
            t0 = int((i + S.rng.uniform(0.0, 0.8)) / count * n) % n
            end = min(n, t0 + len(x))
            out[t0:end] += x[:end - t0]
            out[:len(x) - (end - t0)] += x[end - t0:]
    return out


def relight():
    run = mix(*[at(chitter(k) * (0.4 + 0.15 * k), 0.09 * k) for k in range(4)])
    return mix(run, at(gurgle(2) * 0.7, 0.3), at(grunt(1), 0.5))


S.save_loop('camp_bed_small', bed(5, 3, 0, 0.05), 'loop')
S.save_loop('camp_bed_camp', bed(8, 5, 2, 0.07), 'loop')
S.save_loop('camp_bed_great', bed(12, 7, 5, 0.09), 'loop')
S.save_cat('camp_relight', relight(), 'grunt')
print('camp sounds written')
