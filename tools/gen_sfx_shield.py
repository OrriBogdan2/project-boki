"""Shield sounds: a dull block thunk when a hit lands on a shield, a glassy crack when it breaks.

    cd tools && python3 gen_sfx_shield.py      (then: godot --headless --import)

One family per shield material (Hunter.shield_kind, played by ShieldSfx):
  ward    the plain energy shield of heals and Boki shields: a padded thud, a thin pane breaking
  cloak   Cinder's Furnace Cloak: a muffled thump with embers snapping, a crack that scatters sparks
  molten  Tenzo's Molten Guard: a heavy basalt thud, a stone-and-glass split with a low rumble
Each name has takes (_1.._3); every file is levelled to the impact category (docs/AUDIO.md).
Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, grains

S.reseed(5206)

# material: (thunk body f0, f1, thunk noise lowpass Hz, pane partials in Hz, ember/grit grain rate per s)
MATERIALS = {
    'ward': (230, 105, 900, (3100, 4700, 6300), 0),
    'cloak': (190, 90, 700, (2400, 3500, 5100), 90),
    'molten': (140, 58, 520, (1500, 2300, 3700), 40),
}


def block(kind, i):
    """A dull thunk: a low body, a muffled noise pad, a short damped ring; never bright."""
    f0, f1, lp, _, grit = MATERIALS[kind]
    d = 0.26
    body = kick(f0 * (1.0 + 0.04 * i), f1, d, 0.025, 0.07, 1.6) * 0.8
    pad = lpf(noise(d), lp) * env(N(d), 0.002, 0.05) * 1.6
    ring = S.ring((f1 * 3.1, f1 * 4.9), d, (0.03, 0.02), (0.25, 0.12))
    snaps = grains(d, max(grit, 1), 600, 2600, 0.001, 0.003, 0.05) * (0.5 if grit else 0.0)
    return mix(body, pad, ring, snaps)


def shatter(kind, i):
    """A glassy crack: a sharp transient, an inharmonic pane ringing out, a falling tone and the debris."""
    f0, f1, lp, pane, grit = MATERIALS[kind]
    d = 0.7
    snap = mix(click(0.004, 2500, 12000) * 1.5, crack(d, 900, 8000, 0.02) * 2.2)
    glass = S.ring(tuple(f * (1.0 + 0.03 * i) for f in pane), d, (0.22, 0.14, 0.08), (0.45, 0.3, 0.18))
    fall = kick(f0 * 1.6, f1 * 0.7, d, 0.12, 0.16, 1.4) * 0.7
    rubble = grains(d, 160 + 2 * grit, 1500, 7000, 0.001, 0.004, 0.18) * 0.6
    low = lpf(noise(d), lp * 0.6) * env(N(d), 0.004, 0.14) * 0.9
    return mix(snap, at(glass, 0.003), fall, at(rubble, 0.01), low)


def build():
    for kind in MATERIALS:
        S.takes_cat('shield_%s_hit' % kind, lambda i, k=kind: block(k, i), 3, 'impact')
        S.takes_cat('shield_%s_break' % kind, lambda i, k=kind: shatter(k, i), 3, 'impact')


if __name__ == '__main__':
    build()
    print('gen_sfx_shield: done')
