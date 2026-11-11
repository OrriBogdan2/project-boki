"""Moving through water (docs/AUDIO.md, "Movement sounds"): set `water`, played by WaterSfx and HomeWater.
Run from tools/: python3 gen_sfx_water.py. Writes audio/water_land_<light|medium|heavy>, water_dash and
water_stroke (each .wav plus _1..3.wav) and the seamless loop water_wade.wav.

Synthesised in code (no outside sound). A landing splash is a slap on the surface, a body of churned water,
the bubble of the air pulled under (it rises in pitch as the cavity closes) and the drops falling back; the
heavier the Hunter or Boki, the lower, longer and bigger it is. A dash throws up a bright, short spray. The
wading loop is legs pushing through shin-deep water, two pushes per loop so it follows a stride; the game
sets its level and pitch from speed. A swim stroke is a hand going in and a pull under the surface.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, bpf, lpf, noise, grains, kick

S.reseed(6113)
# weight class: (pitch multiplier, length multiplier, body thud level)
WEIGHT = {'light': (1.3, 0.75, 0.3), 'medium': (1.0, 1.0, 0.55), 'heavy': (0.72, 1.35, 0.9)}


def bubble(f0, f1, d, a=0.004, decay=0.05):
    """A bubble's ring: a sine gliding f0 -> f1 over d."""
    t = T(d)
    f = f0 + (f1 - f0) * (t / d) ** 0.6
    return np.sin(2 * np.pi * np.cumsum(f) / S.SR) * env(N(d), a, decay)


def land(w, i):
    p, L, body = WEIGHT[w]
    d = 0.7 * L
    slap = bpf(noise(0.05), 700 * p, 5200 * p) * env(N(0.05), 0.001, 0.012)
    churn = bpf(noise(d), 260 * p, 2400 * p) * env(N(d), 0.01, 0.16 * L)
    gulp = bubble((260 + 30 * i) * p, (900 + 60 * i) * p, 0.16 * L, decay=0.06 * L)
    drops = grains(0.55 * L, 70, 1400 * p, 6000 * p, 0.001, 0.004, fall=0.2 * L)
    return mix(slap * 1.1, churn, at(gulp, 0.03) * 0.45, at(drops, 0.12 * L) * 0.5,
               kick(80 * p, 45 * p, 0.3 * L, 0.02, 0.07 * L, 1.4) * body)


def dash(i):
    d = 0.38
    t = T(d)
    hiss = bpf(noise(d), 1500 + 200 * i, 7000) * env(N(d), 0.02, 0.09)
    hiss *= 0.6 + 0.4 * np.sin(np.pi * np.clip(t / d, 0, 1))
    wash = bpf(noise(d), 400, 1800) * env(N(d), 0.008, 0.06)
    drops = grains(0.35, 110, 2000, 7500, 0.001, 0.003, fall=0.12)
    return mix(hiss, wash * 0.6, at(drops, 0.05) * 0.45)


def wade():
    d = 1.2                           # one loop: two pushes (a left and a right stride)
    out = np.zeros(N(d))
    for k, t0 in enumerate((0.0, 0.6)):
        push = bpf(noise(0.5), 240 + 40 * k, 1700) * S.shape(0.5, 0.12, 0.08, 0.3)
        lap = bubble(380 + 70 * k, 620 + 50 * k, 0.12, decay=0.04)
        drops = grains(0.4, 40, 1500, 5000, 0.001, 0.003, fall=0.15)
        seg = mix(push, at(lap, 0.1) * 0.25, at(drops, 0.08) * 0.3)
        out = mix(out, np.roll(S.pad(seg, d), N(t0)))[:N(d)]
    bed = lpf(noise(d), 900) * 0.25    # the water moving around the legs between pushes
    return out + bed


def stroke(i):
    d = 0.6
    entry = bpf(noise(0.12), 900, 5500) * env(N(0.12), 0.003, 0.03)
    pull = bpf(noise(0.45), 180, 900) * S.shape(0.45, 0.08, 0.1, 0.2)
    gurgle = bubble(300 + 40 * i, 520 + 40 * i, 0.2, decay=0.07)
    drops = grains(0.3, 50, 1600, 5500, 0.001, 0.003, fall=0.1)
    return mix(entry, at(pull, 0.06) * 0.8, at(gurgle, 0.12) * 0.3, at(drops, 0.02) * 0.35, np.zeros(N(d)))


if __name__ == '__main__':
    for w in WEIGHT:
        S.takes_cat('water_land_' + w, lambda i, w=w: land(w, i), 3, 'dash')
    S.takes_cat('water_dash', dash, 3, 'dash')
    S.takes_cat('water_stroke', stroke, 3, 'step')
    S.save_loop('water_wade', wade(), 'loop')
    print('water sfx written')
