"""The incoming-hit cue (docs/AUDIO.md, content/sfx/incoming.json).

    python3 tools/gen_sfx_incoming.py      (then: godot --headless --import)

hit_in plays from where a hit on you came from (IncomingHit), so a hit from behind or off screen tells you
which way to turn. It is a short rush of air that ends in a snap, bright and broadband on purpose: the ear
places a wide-band transient best. Its small knock sits under your hurt voice, so the cue reads as a
direction and not as a second hit. Four takes (hit_in, hit_in_1..3). Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, noise, bpf, hpf, mix, at, crack, kick

S.reseed(7731)


def hit_in(i):
    rise = 0.028 + 0.005 * i                       # s: the rush toward you, a little longer each take
    whoosh = np.linspace(0.0, 1.0, N(rise)) ** 2
    cut = np.exp(-np.arange(N(0.02)) / N(0.005))
    rush = bpf(noise(rise + 0.02), 1300 + 250 * i, 6800) * np.concatenate([whoosh, cut])
    snap = crack(0.05, 1900, 8500, 0.011)
    knock = kick(200 - 15 * i, 95, 0.07, decay=0.025) * 0.3
    return hpf(mix(rush * 0.7, at(snap, rise), at(knock, rise)), 140)


S.takes_cat('hit_in', hit_in, 3, 'impact')
