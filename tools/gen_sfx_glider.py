"""The glider's sounds (docs/AUDIO.md, content/sfx/glider.json): canopy cloth and air, then fire.

    cd tools && python3 gen_sfx_glider.py      (then: godot --headless --import)

  glider_snap     the canopy filling as it opens: a cloth crack and a soft thud of air
  glider_wind     loop: air rushing past the canopy; the game pitches and levels it with glide speed
  glider_dive     the Ctrl plunge: the canopy folds and a rush climbs into a whoosh
  glider_crackle  the glider catching fire (overheat): a hiss of sparks and pops
  glider_burn     loop: the overheated canopy burning, low roar with pops
  glider_fold     the canopy folding shut on landing or when you let go
Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, noise, lpf, hpf, bpf, env, mix, at, crack, grains, shape, soft_in

S.reseed(9411)


def sweep_noise(d, f0, f1, width=0.4):
    """Noise whose band glides f0 -> f1 (a rush of air)."""
    n = N(d); u = np.arange(n) / max(1, n - 1)
    lf = np.log(f0) + (np.log(f1) - np.log(f0)) * u
    out = np.zeros(n); src = noise(d)
    for fc in np.geomspace(150, 8000, 18):
        g = np.exp(-((np.log(fc) - lf) / width) ** 2)
        if g.max() < 0.02:
            continue
        out += bpf(src, fc * 0.8, fc * 1.25) * g
    return out


def wobble(d, rate, depth):
    """A smooth random level around 1 (gusts), `rate` new values a second."""
    pts = max(4, int(d * rate) + 3)
    x = np.interp(np.arange(N(d)) / S.SR * rate, np.arange(pts), S.rng.standard_normal(pts))
    return np.clip(1.0 + depth * lpf(x, 40) / (np.std(x) + 1e-9), 0.1, None)


def snap():
    d = 0.3
    cloth = crack(d, 1200, 6500, 0.035) * 1.0
    air = lpf(bpf(noise(d), 120, 700), 700) * env(N(d), 0.004, 0.09) * 1.4
    flutter = bpf(noise(d), 500, 3000) * env(N(d), 0.02, 0.12) * (1 + 0.5 * np.sin(2 * np.pi * 38 * np.arange(N(d)) / S.SR)) * 0.35
    return soft_in(mix(cloth, air, at(flutter, 0.03)), 0.5)


def wind():
    d = 1.6
    body = bpf(noise(d), 350, 2600) * wobble(d, 5, 0.25)
    hiss_ = hpf(noise(d), 3000) * 0.18 * wobble(d, 7, 0.3)
    return body + hiss_


def dive():
    d = 0.8
    rush = sweep_noise(d, 350, 4200, 0.45) * shape(d, 0.35, 0.1, 0.35)
    fold = crack(0.12, 900, 4500, 0.03) * 0.5
    low = lpf(noise(d), 380) * shape(d, 0.3, 0.1, 0.4) * 0.9
    return soft_in(mix(rush * 1.6, fold, low), 1.0)


def crackle():
    d = 0.7
    sparks = grains(d, 70, 2500, 7500, 0.001, 0.005, 0.22) * 1.4
    hiss_ = hpf(noise(d), 2200) * env(N(d), 0.03, 0.2) * 0.3
    pops = mix(*[at(crack(0.05, 300, 2200, 0.012), float(t)) for t in (0.0, 0.07, 0.19, 0.33)])
    return soft_in(mix(sparks, hiss_, pops * 0.8), 0.5)


def burn():
    d = 1.4
    roar = bpf(noise(d), 110, 900) * wobble(d, 8, 0.45)
    pops = grains(d, 28, 400, 3500, 0.002, 0.007) * 1.2
    return roar * 1.2 + pops + hpf(noise(d), 2500) * 0.08


def fold():
    d = 0.4
    swish = sweep_noise(d, 2400, 500, 0.45) * shape(d, 0.02, 0.05, 0.3)
    flap = crack(0.08, 600, 3200, 0.025) * 0.6
    return soft_in(mix(swish, at(flap, 0.05)), 1.0)


def build():
    S.save_cat('glider_snap', snap(), 'cast')
    S.save_loop('glider_wind', wind(), 'loop')
    S.save_cat('glider_dive', dive(), 'cast')
    S.save_cat('glider_crackle', crackle(), 'fire')
    S.save_loop('glider_burn', burn(), 'loop')
    S.save_cat('glider_fold', fold(), 'dash')


if __name__ == '__main__':
    build()
    print('gen_sfx_glider: done')
