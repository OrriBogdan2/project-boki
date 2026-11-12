"""Warning sounds (docs/AUDIO.md): the Blight rumble (the low-health heartbeat is LowHpCue's).
Run from tools/: python3 gen_sfx_warn.py

  blight_rumble   the ground turning over: a sub drop, a grinding band of noise and a few dark cracks
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, bpf, noise

S.reseed(8812)


def rumble(i):
    d = 1.7; n = N(d); u = np.arange(n) / n
    swell = np.sin(np.pi * u ** 0.7) ** 1.5
    drop = S.sweep(64, 34, d) * swell
    grind = bpf(noise(d), 40, 230) * swell * (0.7 + 0.3 * np.sin(2 * np.pi * (5.5 + i) * u * d))
    cracks = [at(S.crack(0.09, 120, 700, 0.02) * g, dl) for g, dl in ((0.5, 0.3), (0.35, 0.72), (0.4, 1.05))]
    return lpf(mix(drop * 0.9, grind * 1.2, *cracks), 700)


def main():
    S.takes_cat('blight_rumble', rumble, 2, 'cast')


if __name__ == '__main__':
    main()
