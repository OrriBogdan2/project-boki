"""Status cues (StatusSfx, content/rules/status_sfx.json): a short start sound per status, and a quiet
loop for the two long ones. Written to audio/st_*.wav.

    cd tools && python3 gen_status_sfx.py      (then: godot --headless --import)

  st_ignite_loop               a low fire crackle (the start cue is Cinder's as_ignite)
  st_chill                     a glassy frost chime and a rime hiss
  st_static_loop               a thin electric buzz (the start cue is Sparkle's mage_zap, higher per stack)
  st_slow                      a heavy falling thud, like wading into mud
  st_stun                      a dull ring and a low wobble, stars circling
  st_root                      wood and earth gripping: a creak and a low crunch
  st_ground                    cords snapping tight: a taut twang and a rattle
  st_daze                      a woozy descending two-note whistle
  st_antiheal                  the heal chime going sour: a falling detuned pair

Original synthesis, no samples. Each is short and sits under the combat sounds (the game plays it at a
lower volume still); the loops are seamless (sfx_lib.save_loop).
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, hpf, bpf, env, mix, at, kick, ring, grains

S.reseed(5502)


def ignite_loop():
    d = 1.6
    pops = grains(d, 38, 1800, 7500, 0.002, 0.007)
    return mix(pops * 1.0, lpf(noise(d), 700) * 0.25)


def chill():
    return mix(ring([1760, 2349, 3520], 0.5, [0.22, 0.17, 0.1], [1.0, 0.6, 0.35]),
               hpf(noise(0.3), 5000) * env(N(0.3), 0.02, 0.07) * 0.5)


def static_loop():
    d = 1.2
    t = T(d)
    buzz = np.sign(np.sin(2 * np.pi * 120 * t)) * 0.3 + np.sin(2 * np.pi * 240 * t) * 0.2
    return mix(bpf(buzz, 150, 1400), grains(d, 14, 3000, 9000, 0.001, 0.004) * 0.8, hpf(noise(d), 4000) * 0.04)


def slow():
    return mix(kick(110, 45, 0.35, 0.1, 0.12, 1.5), lpf(noise(0.3), 400) * env(N(0.3), 0.01, 0.1) * 0.6)


def stun():
    t = T(0.5)
    wob = np.sin(2 * np.pi * 200 * t + 3.0 * np.sin(2 * np.pi * 9 * t)) * env(N(0.5), 0.004, 0.14)
    return mix(wob * 0.8, ring([880, 1318], 0.4, [0.12, 0.1], [0.5, 0.3]))


def root():
    return mix(S.creak(0.3, 110, 70, 0.7, 1800) * 0.8, kick(90, 50, 0.2, 0.05, 0.06, 1.6), lpf(noise(0.2), 500) * env(N(0.2), 0.005, 0.05) * 0.5)


def ground():
    return mix(ring([520, 780, 1040], 0.35, [0.12, 0.09, 0.06], [1.0, 0.5, 0.3]), at(S.rattle(0.25, 45, 2500, 6000, 0.4, 0.09), 0.03) * 0.6)


def daze():
    return mix(S.sweep(880, 700, 0.18, 'sin') * env(N(0.18), 0.01, 0.12), at(S.sweep(660, 440, 0.3, 'sin') * env(N(0.3), 0.01, 0.2), 0.16))


def antiheal():
    return mix(ring([1320, 1334], 0.4, [0.2, 0.2], [1.0, 0.9]), at(ring([990, 1004], 0.45, [0.25, 0.25], [0.8, 0.8]), 0.12),
               lpf(noise(0.4), 600) * env(N(0.4), 0.05, 0.15) * 0.25)


def build():
    for name, fn in (('chill', chill), ('slow', slow), ('stun', stun),
                     ('root', root), ('ground', ground), ('daze', daze), ('antiheal', antiheal)):
        S.save_cat('st_' + name, fn(), 'cast')
    S.save_loop('st_ignite_loop', ignite_loop(), 'loop')
    S.save_loop('st_static_loop', static_loop(), 'loop')


if __name__ == '__main__':
    build()
    print('gen_status_sfx: done')
