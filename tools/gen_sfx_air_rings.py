"""The air rings' sounds (docs/AUDIO.md, docs/AIR_RINGS.md, content/sfx/air_rings.json).

    cd tools && python3 gen_sfx_air_rings.py      (then: godot --headless --import)

  air_ring_pass   through a glide ring: a rush of air through the hoop under a bright glassy note (E5);
                  the game plays each ring of one run along a lane a step higher (AirRingSfx.STEPS)
  air_ring_lift   into a lift ring: a soft bloom of air as the updraft takes you, then a warm chord and a
                  rush that swell and climb
  air_ring_hum    loop: the quiet hum a ring gives off, so you can find one by ear (the game plays a lift
                  ring's a fourth lower)
Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, hpf, bpf, env, mix, at, ring, grains, shape, soft_in, sweep, sweep_noise

S.reseed(5127)

PASS_HZ = 659.3     # E5: the first ring of a run; the sixth sounds an octave up
HUM_HZ = 220.0      # A3: the hum's root (its partials and beats repeat exactly over the 2 s loop)


def ring_pass():
    d = 0.5
    f = PASS_HZ
    note = ring([f, 2 * f, 3 * f, 4.02 * f], d, [0.17, 0.1, 0.06, 0.04], [1.0, 0.38, 0.16, 0.07], a=0.004)
    glint = ring([6.1 * f], d, [0.03], [0.12], a=0.002)
    rush = sweep_noise(0.34, 700, 3600, 0.45) * shape(0.34, 0.035, 0.02, 0.26)
    return soft_in(mix(note * 0.9, glint, rush * 1.3), 1.0)


def ring_lift():
    d = 1.7
    bloom = lpf(bpf(noise(0.3), 90, 600), 600) * env(N(0.3), 0.006, 0.09) * 3.2
    root = 196.0     # G3, gliding up an octave as the swell builds
    chord = sum(g * lpf(sweep(root * k, 2 * root * k, d, 'saw', curve=0.8), 2400)
                for k, g in ((1.0, 1.0), (1.5, 0.55), (2.0, 0.35)))
    swell = shape(d, 0.9, 0.25, 0.55)
    rush = sweep_noise(d, 320, 3200, 0.5) * shape(d, 0.85, 0.3, 0.55)
    sparkle = lpf(grains(d, 18, 3500, 7500, 0.006, 0.012), 7000) * shape(d, 1.1, 0.2, 0.4) * 0.3
    return soft_in(mix(bloom, chord * swell * 0.35, rush * 0.9, sparkle), 1.0)


def ring_hum():
    d = 2.0
    t = T(d)
    tone = np.zeros(N(d))
    for k, g in ((1.0, 1.0), (1.5, 0.45), (2.0, 0.28), (3.0, 0.12)):
        f = HUM_HZ * k
        tone += g * (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * (f + 0.5) * t))
    breath = 1.0 + 0.12 * np.sin(2 * np.pi * 0.5 * t)
    air = bpf(noise(d), 1800, 5200) * 0.04
    return lpf(tone * breath, 1600) + air


def build():
    S.save_cat('air_ring_pass', ring_pass(), 'cast')
    S.save_cat('air_ring_lift', ring_lift(), 'cast')
    S.save_loop('air_ring_hum', ring_hum(), 'loop')


if __name__ == '__main__':
    build()
    print('gen_sfx_air_rings: done')
