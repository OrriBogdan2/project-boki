"""The Hunter Wisp's hum (DECISIONS 2026-11-09 outline rule, docs/AUDIO.md). Run from tools/: python3 gen_wisp_sfx.py

A downed Hunter's Wisp is slow, heavy and low with a steady glow, so it sounds that way: a low, round,
unchanging hum with no attack and no high end. The Boki wisps are the opposite (quick chirps from 1 to
2.3 kHz, tools/gen_sfx_wisps.py), so the two never read alike.
  wisp_hum      a 2 s seamless loop: A1 (55 Hz) with its 2nd and 3rd partials, a second voice 0.5 Hz
                off the root so it beats once per loop, and a faint 4th; nothing above 220 Hz
  wisp_hum_end  the soft fall-away when the Wisp is done (revived or bled out): the same hum sinking an
                octave and fading over 0.9 s
Every partial is a whole number of cycles per loop (multiples of 0.5 Hz), so the loop needs no filter
and has no seam. Original synthesis, no samples.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env

S.reseed(9131)
ROOT = 55.0
LOOP_S = 2.0
PARTS = ((1.0, 1.0), (2.0, 0.55), (3.0, 0.3), (4.0, 0.08))


def hum_loop():
    t = T(LOOP_S)
    x = sum(g * np.sin(2 * np.pi * ROOT * r * t) for r, g in PARTS)
    x += 0.6 * np.sin(2 * np.pi * (ROOT + 0.5) * t + 0.9)        # beats once per loop
    return x * (0.85 + 0.15 * np.sin(2 * np.pi * 0.5 * t))       # a slow, steady swell


def hum_end():
    d = 0.9
    t = T(d)
    f = ROOT * (2.0 - 1.0 * np.minimum(t / d, 1.0) ** 0.7)       # 110 Hz sinking to 55 Hz
    ph = 2 * np.pi * np.cumsum(f) / S.SR
    x = sum(g * np.sin(ph * r) for r, g in PARTS[:3])
    return x * env(N(d), 0.03, 0.28)


def main():
    S.save_loop('wisp_hum', hum_loop(), 'loop')
    S.takes_cat('wisp_hum_end', lambda i: hum_end(), 0, 'loop')


if __name__ == '__main__':
    main()
