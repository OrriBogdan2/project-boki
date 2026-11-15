"""The hit ticks by weapon family (docs/AUDIO.md): the sound of your own shot or swing landing.

    cd tools && python3 gen_sfx_hits.py      (then: godot --headless --import)

Each Hunter's left-click weapon names one in its "hit" field (content/weapons/<id>.json); Match plays
it in place of the shared `hit` tick. A crit still plays `crit`; slash_hit, armor_hit and hit_heavy
still layer on top in Juice. Each is levelled to the old `hit` tick (-18 dB RMS), so nothing gets louder.

  hit_gun     rapid gun       a dry, tight snap with a small body (the shortest: it plays many times a second)
  hit_bow     bow             a dull wooden thock, the shaft's low thrum under it
  hit_blade   blade           a bright steel tick and a thin slice of air
  hit_blunt   blunt           a low thud with a dull crack, no ring
  hit_magic   magic           a glassy zap: bright inharmonic partials falling in pitch
  hit_thrown  thrown          a light double tick, a pebble and a small clink
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, mix, at, kick, click, crack, ring, bpf

S.reseed(5603)
HIT_DB = -18.0        # dB RMS: the level of the shared `hit` tick these replace


def gun(i):
    d = 0.14
    return mix(click(0.002, 3200, 11000) * 1.8, kick(320 + 20 * i, 140, d, 0.005, 0.016, 2.4) * 0.4,
               crack(d, 1200, 4800 + 300 * i, 0.01) * 2.6)


def bow(i):
    d = 0.2
    return mix(click(0.003, 900, 3500) * 1.2, kick(230 + 12 * i, 95, d, 0.012, 0.035, 2.6) * 0.8,
               ring((520 + 25 * i, 1130), d, (0.05, 0.025), (0.22, 0.08)), crack(d, 300, 1400, 0.02) * 1.6)


def blade(i):
    d = 0.2
    return mix(click(0.002, 4000, 12000) * 1.6, bpf(S.noise(d), 2200, 8000) * S.env(N(d), 0.004, 0.035) * 1.3,
               ring((2300 + 90 * i, 3350 + 60 * i), d, (0.06, 0.035), (0.35, 0.14)), kick(260, 130, d, 0.006, 0.02, 2.0) * 0.25)


def blunt(i):
    d = 0.24
    return mix(click(0.004, 1200, 5000) * 1.1, kick(170 + 10 * i, 62, d, 0.015, 0.06, 3.0) * 0.9,
               crack(d, 150, 800, 0.03) * 2.2, S.sub(80, 45, d, 0.08) * 0.3)


def magic(i):
    d = 0.24
    f = 1900 + 150 * i
    glass = ring((f, f * 1.47, f * 2.19, f * 3.1), d, (0.09, 0.06, 0.04, 0.025), (0.6, 0.35, 0.22, 0.12))
    return mix(click(0.002, 3500, 12000) * 1.3, glass, crack(d, 2500, 9000, 0.02) * 1.0,
               kick(520, 260, d, 0.02, 0.03, 1.8) * 0.25)


def thrown(i):
    d = 0.2
    return mix(click(0.003, 2000, 8000) * 1.5, kick(300 + 15 * i, 150, d, 0.006, 0.018, 2.2) * 0.45,
               at(click(0.002, 3000, 9000) * 0.9, 0.022), at(ring((1250 + 60 * i, 2010), 0.15, (0.04, 0.02), (0.3, 0.1)), 0.02),
               crack(d, 500, 3000, 0.014) * 1.8)


def main():
    for name, make in (("hit_gun", gun), ("hit_bow", bow), ("hit_blade", blade),
                       ("hit_blunt", blunt), ("hit_magic", magic), ("hit_thrown", thrown)):
        S.C.takes(name, make, 3, rms_db=HIT_DB, peak_db=S.PEAK_DB)


if __name__ == '__main__':
    main()
