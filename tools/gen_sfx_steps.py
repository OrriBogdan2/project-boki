"""Footsteps on sand, shallow water and metal, one set per weight class (docs/AUDIO.md, "Footsteps").
Run from tools/: python3 gen_sfx_steps.py. Writes audio/step_<surface>_<light|medium|heavy>(.wav, _1..3.wav).

Synthesised in code (no outside sound), the same short, dry level as the grass/stone/wood/snow steps so a
run never clutters a fight. A light Hunter is quick and high, a heavy one longer and lower with a body thud.
The Hunters have no steps of their own on these surfaces yet, so Juice.footstep falls back to these.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf, noise
from sfx_combat import kick, click, crack, ring, grains

S.reseed(5871)
# weight class: (pitch multiplier, length multiplier, body thud level)
WEIGHT = {'light': (1.3, 0.8, 0.35), 'medium': (1.0, 1.0, 0.55), 'heavy': (0.75, 1.3, 0.9)}


def sand(w, i):
    p, L, body = WEIGHT[w]
    d = 0.2 * L
    shh = bpf(noise(d), 900 * p, 4200 * p) * env(N(d), 0.012, 0.05 * L)
    grit = grains(0.14 * L, 500, 1800 * p, 6000, 0.001, 0.004, fall=0.04 * L)
    return mix(shh * 0.9, grit * 0.7, kick((120 + 8 * i) * p, 65 * p, d, 0.012, 0.03 * L, 1.4) * body)


def water(w, i):
    p, L, body = WEIGHT[w]
    d = 0.3 * L
    t = T(0.12 * L)
    slosh = bpf(noise(d), 350 * p, 2600 * p) * env(N(d), 0.006, 0.07 * L)
    bubble = np.sin(2 * np.pi * np.cumsum((500 + 90 * i + 1800 * t / (0.12 * L)) * p) / S.SR) * env(N(0.12 * L), 0.003, 0.03)
    drops = grains(0.2 * L, 60, 1500 * p, 5000, 0.001, 0.003, fall=0.07 * L)
    return mix(slosh * 0.9, at(bubble, 0.012) * 0.35, at(drops, 0.03) * 0.4, kick(95 * p, 55 * p, d, 0.015, 0.04 * L, 1.3) * body)


def metal(w, i):
    p, L, body = WEIGHT[w]
    d = 0.3 * L
    f = (330 + 25 * i) * p
    clank = ring((f, f * 2.76, f * 5.4), d, (0.07 * L, 0.04 * L, 0.02 * L), (0.7, 0.4, 0.2))
    return mix(click(0.003, 2000, 8000) * 1.2, clank, crack(d, 800 * p, 4500, 0.012) * 0.6,
               kick(140 * p, 70 * p, 0.15 * L, 0.01, 0.03 * L, 1.5) * body)


if __name__ == '__main__':
    for surf, fn in (('sand', sand), ('water', water), ('metal', metal)):
        for w in WEIGHT:
            S.takes_cat('step_%s_%s' % (surf, w), lambda i, fn=fn, w=w: fn(w, i), 3, 'step')
    print('step surface sfx written')
