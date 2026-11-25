"""Wall kick, ledge grab and mantle sounds, one set per weight class (docs/AUDIO.md, "Climbing sounds").
Run from tools/: python3 gen_sfx_climb.py. Writes audio/<move>_<light|medium|heavy>(.wav, _1..3.wav).

  wallkick_*  a foot planted on the wall and pushed off: a dry scuff, a short thud, a push of air
  ledgegrab_* a hand slapping the lip and gripping it: a palm tap, then a gritty grip
  mantle_*    the body hauled over the lip: a cloth and stone drag ending in a belly and knee thump (no voice)

Synthesised in code (no outside sound), at the footstep level (category "step") so they never clutter a
fight. A light Hunter is quick and high, a heavy one longer and lower with more body.
"""

import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, bpf, lpf, noise
from sfx_combat import kick, click, crack, grains

S.reseed(7731)
# weight class: (pitch multiplier, length multiplier, body thud level)
WEIGHT = {"light": (1.3, 0.8, 0.35), "medium": (1.0, 1.0, 0.55), "heavy": (0.75, 1.3, 0.9)}


def wallkick(w, i):
    p, L, body = WEIGHT[w]
    d = 0.24 * L
    scuff = bpf(noise(d), 500 * p, 4200 * p) * env(N(d), 0.002, 0.05 * L)
    push = bpf(noise(0.2 * L), 900 * p, 2400 * p) * env(N(0.2 * L), 0.05 * L, 0.09 * L)
    return mix(
        click(0.003, 2200, 7000) * 1.1,
        scuff * 0.9,
        kick((150 + 12 * i) * p, 70 * p, 0.14 * L, 0.012, 0.05 * L, 1.4) * body,
        at(push, 0.03) * 0.35,
    )


def ledgegrab(w, i):
    p, L, body = WEIGHT[w]
    tap = bpf(noise(0.06 * L), 700 * p, 3800 * p) * env(N(0.06 * L), 0.001, 0.02 * L)
    grip = grains(0.16 * L, 140, 1200 * p, 6000, 0.001, 0.004, fall=0.06 * L)
    return mix(
        click(0.003, 1800, 6000),
        tap * 0.9,
        at(grip, 0.025) * 0.5,
        kick((200 + 15 * i) * p, 110 * p, 0.1 * L, 0.01, 0.03 * L, 1.2) * body * 0.7,
    )


def mantle(w, i):
    p, L, body = WEIGHT[w]
    d = 0.34 * L
    drag = lpf(bpf(noise(d), 250 * p, 2400 * p), 3000 * p) * env(N(d), 0.1 * L, 0.18 * L)
    belly = kick((105 + 8 * i) * p, 55 * p, 0.18 * L, 0.02, 0.07 * L, 1.3) * body
    knee = crack(0.1 * L, 600 * p, 3500 * p, 0.02) * 0.45
    return mix(drag * 0.8, at(belly, 0.2 * L), at(knee, 0.27 * L))


if __name__ == "__main__":
    for name, fn in (("wallkick", wallkick), ("ledgegrab", ledgegrab), ("mantle", mantle)):
        for w in WEIGHT:
            S.takes_cat("%s_%s" % (name, w), lambda i, fn=fn, w=w: fn(w, i), 3, "step")
    print("climb sfx written")
