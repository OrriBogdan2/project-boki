"""Squad alert stingers (docs/AUDIO.md): four short cues you hear for your own squad even off-screen.
Run from tools/: python3 gen_sfx_squad.py

squad_down   a teammate goes down: two sharp falling pulses, urgent
squad_up     a teammate is back up: a warm rising pair, relief
squad_wipe   your squad wiped a rival squad: a low hit under a bright rising fifth
squad_last   you are the last one standing: a heartbeat double thump under a thin held tone
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, hpf

S.reseed(5128)


def pulse(f0, f1, d=0.16):
    """A buzzy falling blip: a saw sweep with a thump under it."""
    body = lpf(S.sweep(f0, f1, d, 'saw'), 2600) * env(N(d), 0.002, d * 0.45)
    return body + 0.5 * S.kick(f1 * 0.7, f1 * 0.4, d, 0.04, 0.08)


def down(i=0):
    return mix(pulse(740, 520), at(pulse(660, 440), 0.17), 0.25 * S.hiss(0.12, 3000, 8000, 0.01, 0.05))


def up(i=0):
    return mix(S.chime(523, 0.7, 0.3), at(S.chime(784, 0.9, 0.4), 0.12), 0.3 * at(S.chime(1047, 0.9, 0.4), 0.24))


def wipe(i=0):
    hit = S.kick(150, 55, 0.4, 0.05, 0.14)
    return mix(hit, at(S.chime(659, 0.8, 0.35), 0.05), at(S.chime(988, 1.0, 0.45), 0.13))


def last(i=0):
    beat = S.kick(110, 50, 0.3, 0.04, 0.07)
    t = T(0.9)
    tone = 0.35 * np.sin(2 * np.pi * 880 * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t)) * S.shape(0.9, 0.12, 0.2, 0.5)
    return mix(beat, at(0.8 * beat, 0.22), at(beat, 0.62), at(0.8 * beat, 0.84), tone)


def main():
    S.save_cat('squad_down', down(), 'signature')
    S.save_cat('squad_up', up(), 'signature')
    S.save_cat('squad_wipe', wipe(), 'signature')
    S.save_cat('squad_last', last(), 'signature')


if __name__ == '__main__':
    main()
