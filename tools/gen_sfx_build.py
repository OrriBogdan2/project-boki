"""The build and decorate sounds (docs/AUDIO.md): soft, dull and woody, in the UI family's loudness.
Run from tools/: python3 gen_sfx_build.py

build_pick    a felt lift: a small rising pluck over a breath of air (a piece comes off the ground)
build_rotate  a dry wood tick, one per quarter turn
build_place_wood / build_place_stone   a thunk: a low body and a knock; the stone one lower, with a short grit
build_store   a pop into a bag: a quick bubble rise, a cloth rustle
build_move    a soft slide that ends in a light set-down
build_blocked a single dull knock (a muffled low tap), nothing pitched
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, bpf, noise
from gen_sfx_ui import pluck, room, finish, jit

S.reseed(5120)


def pick(i):
    j = jit(i, 0.03)
    air = bpf(noise(0.14), 500, 2200) * env(N(0.14), 0.05, 0.05) * 0.35
    return finish(room(mix(pluck(392 * j, 0.2, 0.05, 0.5), at(pluck(587 * j, 0.22, 0.06, 0.4), 0.05), air), 0.4), 3400)


def rotate(i):
    j = jit(i, 0.05)
    tick = S.crack(0.03, 700 * j, 2600, 0.006)
    body = S.sub(260 * j, 170, 0.05, 0.016)
    return finish(mix(tick, 0.8 * body), 3000)


def thunk(body_hz, knock_lo, knock_hi, grit):
    def make(i):
        j = jit(i, 0.04)
        low = S.kick(body_hz * 1.6 * j, body_hz * j, 0.22, drop=0.035, decay=0.075, drive=1.2)
        knock = S.crack(0.05, knock_lo, knock_hi, 0.012)
        rough = grit * S.crack(0.03, 1800, 5000, 0.006)
        return finish(room(mix(low, 0.6 * knock, rough), 0.4), 2600)
    return make


def store(i):
    j = jit(i, 0.04)
    pop = S.sweep(300 * j, 950 * j, 0.07) * env(N(0.07), 0.004, 0.022)
    rustle = bpf(noise(0.1), 1500, 5000) * env(N(0.1), 0.004, 0.03) * 0.3
    return finish(room(mix(pop, at(0.5 * pluck(1175 * j, 0.1, 0.02, 0.2), 0.045), at(rustle, 0.03)), 0.3), 3800)


def move(i):
    j = jit(i, 0.04)
    slide = bpf(noise(0.16), 300, 1400) * env(N(0.16), 0.09, 0.03) * 0.5
    set_down = mix(0.9 * S.sub(190 * j, 130, 0.09, 0.03), 0.4 * S.crack(0.03, 500, 1600, 0.008))
    return finish(room(mix(slide, at(set_down, 0.12)), 0.3), 2400)


def blocked(i):
    j = jit(i, 0.03)
    return lpf(mix(S.sub(150 * j, 95, 0.12, 0.035), 0.5 * S.crack(0.03, 300, 900, 0.01)), 900)


def main():
    S.takes_cat('build_pick', pick, 2, 'ui')
    S.takes_cat('build_rotate', rotate, 3, 'ui')
    S.takes_cat('build_place_wood', thunk(120, 350, 1200, 0.0), 3, 'ui')
    S.takes_cat('build_place_stone', thunk(85, 700, 2600, 0.5), 3, 'ui')
    S.takes_cat('build_store', store, 2, 'ui')
    S.takes_cat('build_move', move, 2, 'ui')
    S.takes_cat('build_blocked', blocked, 2, 'ui')


if __name__ == '__main__':
    main()
