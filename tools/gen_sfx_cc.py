"""Crowd control landing on you (docs/AUDIO.md, content/sfx/cc.json): one short cue per kind, played by CcSfx.

    python3 tools/gen_sfx_cc.py      (then: godot --headless --import)

  cc_stun    a struck ring with a dizzy beat between two close partials
  cc_root    a cord snapping tight over a wooden knock
  cc_ground  a dull thud with the cords rattling round the legs (Grounded: no dash, jump or glide)
  cc_slow    a low tone sinking under a muffled scrape
  cc_daze    a sine whose pitch wobbles, fading
Each has a cc_<kind>_mate: the same cue low-passed and a category quieter, for a squadmate's CC nearby.
Original synthesis, no samples. Its own seed: running it re-rolls nothing else.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf, noise

S.reseed(5121)
MATE_LPF = 1600     # Hz: a squadmate's cue keeps its shape but loses its edge, so your own stays the clear one


def stun():
    d = 0.5; t = T(d); f = 1180
    a = np.sin(2 * np.pi * f * t) + np.sin(2 * np.pi * f * 1.035 * t)        # the close pair beats ~40 Hz
    a += 0.35 * np.sin(2 * np.pi * f * 2.76 * t)
    return lpf(a * env(N(d), 0.002, 0.15), 6000)


def root():
    snap = bpf(noise(0.05), 1500, 5000) * env(N(0.05), 0.001, 0.012)
    cord = S.sweep(420, 140, 0.2, curve=0.6) * env(N(0.2), 0.004, 0.07) * 0.6
    knock = S.sweep(180, 90, 0.12) * env(N(0.12), 0.002, 0.05)
    return S.pad(mix(snap, at(cord, 0.01), at(knock, 0.05)), 0.32)


def ground():
    body = S.sweep(150, 52, 0.22, curve=0.7) * env(N(0.22), 0.002, 0.08)
    grit = lpf(noise(0.09), 1400) * env(N(0.09), 0.001, 0.03) * 0.5
    cords = S.rattle(0.18, rate=30, lo=900, hi=3000) * 0.35
    return S.pad(mix(lpf(mix(body, grit), 1600), at(cords, 0.04)), 0.34)


def slow():
    d = 0.45
    sink = S.sweep(300, 95, d, curve=0.8) * S.shape(d, 0.03, 0.1, 0.3)
    scrape = bpf(noise(d), 300, 1100) * S.shape(d, 0.05, 0.1, 0.3) * 0.5
    return lpf(mix(sink, scrape), 1800)


def daze():
    d = 0.55; t = T(d)
    f = 540 * (1.0 + 0.09 * np.sin(2 * np.pi * 5.0 * t))                      # the pitch swings
    ph = 2 * np.pi * np.cumsum(f) / S.SR
    return lpf((np.sin(ph) + 0.3 * np.sin(2 * ph)) * S.shape(d, 0.03, 0.1, 0.4), 3000)


def build():
    for kind, fn in (('stun', stun), ('root', root), ('ground', ground), ('slow', slow), ('daze', daze)):
        x = fn()
        S.save_cat('cc_' + kind, x, 'cast')
        S.save_cat('cc_%s_mate' % kind, lpf(x, MATE_LPF), 'ui')


if __name__ == '__main__':
    build()
