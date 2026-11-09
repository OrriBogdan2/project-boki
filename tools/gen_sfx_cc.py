"""Crowd-control cues (docs/AUDIO.md): one short sound when a status lands. Run from tools/: python3 gen_sfx_cc.py

  cc_stun   a bright ring: a struck bell with a dizzy beat between two close partials
  cc_root   a bind: a rope snapping tight, a wooden knock under it
  cc_slow   a drag: a low tone sinking in pitch with a muffled scrape
  cc_daze   a wobble: a sine whose pitch swings slowly, fading
  cc_thud   a ground thud: a soft low hit with a dull rubble tick (Grounded)
Original synthesis, no samples. Played by scripts/combat/status_sfx.gd.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf, noise

S.reseed(5120)


def stun(i):
    f = 1180 * (1.0 + 0.02 * i)
    d = 0.55; t = T(d)
    a = np.sin(2 * np.pi * f * t) + np.sin(2 * np.pi * f * 1.035 * t)        # the close pair beats ~40 Hz
    a += 0.35 * np.sin(2 * np.pi * f * 2.76 * t)
    return lpf(a * env(N(d), 0.002, 0.16), 6000)


def root(i):
    d = 0.32
    snap = bpf(noise(0.05), 1500, 5000) * env(N(0.05), 0.001, 0.012)
    cord = S.sweep(420 * (1 + 0.05 * i), 140, 0.2, curve=0.6) * env(N(0.2), 0.004, 0.07) * 0.6
    knock = S.sweep(180, 90, 0.12) * env(N(0.12), 0.002, 0.05)
    return S.pad(mix(snap, at(cord, 0.01), at(knock, 0.05)), d)


def slow(i):
    d = 0.5
    sink = S.sweep(300 * (1 + 0.04 * i), 95, d, curve=0.8) * S.shape(d, 0.03, 0.1, 0.35)
    scrape = bpf(noise(d), 300, 1100) * S.shape(d, 0.05, 0.1, 0.35) * 0.5
    return lpf(mix(sink, scrape), 1800)


def daze(i):
    d = 0.6; n = N(d); t = T(d)
    f = (520 + 40 * i) * (1.0 + 0.09 * np.sin(2 * np.pi * 5.0 * t))           # the pitch swings
    ph = 2 * np.pi * np.cumsum(f) / S.SR
    x = np.sin(ph) + 0.3 * np.sin(2 * ph)
    return lpf(x * S.shape(d, 0.03, 0.1, 0.45), 3000)


def thud(i):
    d = 0.3
    body = S.sweep(150 * (1 + 0.05 * i), 52, 0.22, curve=0.7) * env(N(0.22), 0.002, 0.08)
    grit = lpf(noise(0.09), 1400) * env(N(0.09), 0.001, 0.03) * 0.5
    return S.pad(lpf(mix(body, grit), 1600), d)


def main():
    S.takes_cat('cc_stun', stun, 2, 'cast')
    S.takes_cat('cc_root', root, 2, 'cast')
    S.takes_cat('cc_slow', slow, 2, 'cast')
    S.takes_cat('cc_daze', daze, 2, 'cast')
    S.takes_cat('cc_thud', thud, 2, 'impact')


if __name__ == '__main__':
    main()
