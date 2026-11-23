"""The squad rocket drop's sounds (docs/AUDIO.md, content/sfx/rocket.json): a small rocket's thrust and air.

    cd tools && python3 gen_sfx_rocket.py      (then: godot --headless --import)

  rocket_ignite     the launch off the skyship: a clamp release, a pop of flame and the thrust catching
  rocket_ride       loop: the thrust roar; the game pitches and levels it with the leader's steering
  rocket_jump       jumping out: the hatch clack and the rocket's roar tearing past you
  drop_fall_wind    loop: free-fall air with buffeting; the game raises it with fall speed, then the
                    glider's open sound takes over
  rocket_land       the rocket coming down: a short, clean thud with a metal tick and a puff of dust
Original synthesis, no samples.
"""

import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import (
    N,
    noise,
    lpf,
    bpf,
    env,
    mix,
    at,
    kick,
    click,
    crack,
    tail,
    ring,
    shape,
    soft_in,
    sweep_noise,
    wobble,
)

S.reseed(6127)


def thrust(d):
    """A rocket motor: a low roar with fast flicker, a buzz at the flame's pulse and a thin top hiss."""
    t = np.arange(N(d)) / S.SR
    roar = bpf(noise(d), 70, 650) * wobble(d, 22, 0.35)
    buzz = lpf(np.sign(np.sin(2 * np.pi * 52 * t)) * (0.6 + 0.4 * wobble(d, 9, 0.5)), 900) * 0.18
    top = bpf(noise(d), 2500, 7000) * wobble(d, 14, 0.4) * 0.12
    return roar * 1.3 + buzz + top


def ignite():
    d = 0.9
    clamp = mix(crack(0.05, 900, 5000, 0.012) * 0.8, ring([1650, 2730], 0.2, [0.04, 0.03], [0.12, 0.06]))
    pop = kick(140, 60, 0.25, drop=0.02, decay=0.07, drive=1.6) * 0.7
    catch = thrust(d) * shape(d, 0.12, 0.35, 0.4)
    return soft_in(mix(clamp, at(pop, 0.04), at(catch, 0.05)), 1.0)


def ride():
    return thrust(1.8)


def jump():
    d = 0.7
    hatch = mix(click(0.006, 1500, 6000, 0.002), crack(0.04, 700, 3800, 0.01) * 0.6)
    past = sweep_noise(d, 2600, 300, 0.5) * shape(d, 0.03, 0.08, 0.5) * 1.3
    roar = bpf(noise(d), 80, 500) * env(N(d), 0.01, 0.18) * 0.8
    return soft_in(mix(hatch, at(past, 0.02), at(roar, 0.02)), 1.0)


def fall_wind():
    d = 2.0
    rush = bpf(noise(d), 180, 1800) * wobble(d, 4, 0.3)
    buffet = lpf(noise(d), 260) * wobble(d, 11, 0.6) * 0.9
    flap = bpf(noise(d), 600, 2400) * np.clip(np.sin(2 * np.pi * 13 * np.arange(N(d)) / S.SR), 0, 1) * 0.25
    return rush + buffet + flap


def land():
    d = 0.6
    thud = kick(110, 48, 0.35, drop=0.025, decay=0.09, drive=1.4)
    tick_ = ring([2100, 3480], 0.25, [0.05, 0.035], [0.18, 0.08])
    dust = tail(d, 1400, 0.14, delay=0.01) * 0.5
    return soft_in(mix(thud, tick_, dust), 0.5)


def build():
    S.save_cat("rocket_ignite", ignite(), "cast")
    S.save_loop("rocket_ride", ride(), "loop")
    S.save_cat("rocket_jump", jump(), "dash")
    S.save_loop("drop_fall_wind", fall_wind(), "loop")
    S.save_cat("rocket_land", land(), "impact")


if __name__ == "__main__":
    build()
    print("gen_sfx_rocket: done")
