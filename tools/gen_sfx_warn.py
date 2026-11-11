"""Warning sounds (docs/AUDIO.md): a low-health heartbeat, the extraction countdown tick and the Blight rumble.
Run from tools/: python3 gen_sfx_warn.py

  warn_heartbeat  a soft two-beat pulse (lub-dub), felt more than heard, so it can run under a fight
  warn_tick       a dry little wood tick; played at a rising pitch for the last five seconds of an extraction
  blight_rumble   the ground turning over: a sub drop, a grinding band of noise and a few dark cracks
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, bpf, noise

S.reseed(8812)


def heartbeat(i):
    f = 1.0 + (0 if i == 0 else S.rng.uniform(-0.04, 0.04))
    lub = S.kick(95 * f, 48, 0.22, 0.03, 0.05, 1.3)
    dub = S.kick(80 * f, 42, 0.2, 0.03, 0.045, 1.3) * 0.7
    return lpf(mix(lub, at(dub, 0.17)), 420)


def tick(i):
    body = np.sin(2 * np.pi * 1250 * np.arange(N(0.07)) / S.SR) * env(N(0.07), 0.001, 0.016)
    knock = S.crack(0.03, 800, 3200, 0.006) * 0.5
    return lpf(mix(body, knock), 4200)


def rumble(i):
    d = 1.7; n = N(d); u = np.arange(n) / n
    swell = np.sin(np.pi * u ** 0.7) ** 1.5
    drop = S.sweep(64, 34, d) * swell
    grind = bpf(noise(d), 40, 230) * swell * (0.7 + 0.3 * np.sin(2 * np.pi * (5.5 + i) * u * d))
    cracks = [at(S.crack(0.09, 120, 700, 0.02) * g, dl) for g, dl in ((0.5, 0.3), (0.35, 0.72), (0.4, 1.05))]
    return lpf(mix(drop * 0.9, grind * 1.2, *cracks), 700)


def main():
    S.takes_cat('warn_heartbeat', heartbeat, 1, 'ui')
    S.takes_cat('warn_tick', tick, 0, 'ui')
    S.takes_cat('blight_rumble', rumble, 2, 'cast')


if __name__ == '__main__':
    main()
