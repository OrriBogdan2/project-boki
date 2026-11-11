"""Boon of the Hunt cues (docs/AUDIO.md, content/sfx/boon.json): the squad a lair boss or Watcher kill pays hears it.

    python3 tools/gen_sfx_boon.py      (then: godot --headless --import)

boon_gain: a short bright rising pair with a shimmer on top (the squad that gets the Boon).
boon_lost: a softer falling pair, dark and round (the squad that loses it to a steal).
boon_tick: one dry wood tick (5 s before the Boon ends).
Original synthesis, no samples. Its own seed: running it re-rolls nothing else.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, bpf, env, mix, at

S.reseed(8161)


def note(f, d, decay):
    """A round tine: the note and a quiet octave."""
    t = T(d)
    return (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t)) * env(N(d), 0.004, decay)


def gain(i):
    shimmer = S.sweep(900, 2400, 0.3, curve=2.0) * np.sin(np.pi * np.arange(N(0.3)) / N(0.3)) ** 2 * 0.12
    return mix(note(440, 0.5, 0.12), at(note(660, 0.5, 0.16), 0.11), at(S.chime(1320, 0.4, 0.2) * 0.22, 0.11), shimmer)


def lost(i):
    return lpf(mix(note(330, 0.5, 0.1), at(note(247, 0.5, 0.16), 0.13)), 2200)


def tick(i):
    return mix(bpf(noise(0.02), 1500, 3500) * env(N(0.02), 0.001, 0.006), np.sin(2 * np.pi * 1100 * T(0.04)) * env(N(0.04), 0.001, 0.012) * 0.5)


def main():
    S.save_cat('boon_gain', gain(0), 'cast')
    S.save_cat('boon_lost', lost(0), 'ui')
    S.save_cat('boon_tick', tick(0), 'ui')


if __name__ == '__main__':
    main()
