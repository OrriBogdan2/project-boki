"""Wind roads and updrafts (docs/AUDIO.md): the two loops of scripts/match/current_sound.gd.
Run from tools/: python3 gen_sfx_wind.py

current_bed: the air of a current heard from a way off. A low, dark rush with a slow swell (whole cycles
  per loop, so it repeats without a dip) and a thin hollow band on top, so you hear it before you see it.
current_ride: riding it. Brighter, faster air that streams past the ears with a faint whistle; the game
  raises its pitch with your speed, so a noisy band plus a tone (which pitch moves audibly) make it.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, lpf, bpf, noise

S.reseed(5120)


def swell(t, d, cycles, depth):
    """A slow level wobble that lands back where it started at the end of the loop."""
    return 1.0 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * cycles * t / d))


def bed():
    d = 4.0; t = T(d)
    low = lpf(noise(d), 420) * 1.6 * swell(t, d, 2, 0.45)
    hollow = bpf(noise(d), 520, 1100) * 0.7 * swell(t, d, 3, 0.6)
    air = bpf(noise(d), 1800, 3600) * 0.12 * swell(t, d, 5, 0.5)
    return lpf(low + hollow + air, 2800)


def ride():
    d = 3.0; t = T(d)
    rush = bpf(noise(d), 900, 3200) * swell(t, d, 4, 0.35)
    streak = bpf(noise(d), 2400, 5200) * 0.35 * swell(t, d, 7, 0.6)
    whistle = 0.16 * np.sin(2 * np.pi * (640 * t + 14 * np.sin(2 * np.pi * 3 * t / d) * d / (2 * np.pi * 3)))
    return lpf(rush + streak + whistle, 6000)


def build():
    S.save_loop('current_bed', bed(), 'loop')
    S.save_loop('current_ride', ride(), 'loop')


if __name__ == '__main__':
    build()
