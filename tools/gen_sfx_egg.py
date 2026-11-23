"""Egg sounds (docs/AUDIO.md): an egg nearing its hatch says so by sound, not by a pop-up. Run from tools/.

Small and close, for one egg in its cradle or nest; played at the egg by scripts/home/egg_sfx.gd.
  egg_knock   half warm: the shell rocks twice on its straw and settles, then two faint muffled taps
              from inside
  egg_crack   nearly ready (every few seconds while you are near): a tiny shell fracture, a few dry
              ticks over a hollow tick
  egg_ready   ready: four glassy notes rising, a soft shimmer and a muffled chirp from inside the shell
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, hpf, bpf, noise
import gen_sfx_boki as B

S.reseed(7140)


def j(i, s=0.04):
    return B.j(i, s)


def rock(d, f):
    """The shell rolling over straw: a low hush with a rise and fall, and the soft bump of it settling."""
    rub = bpf(noise(d), 250, 1400) * S.shape(d, d * 0.45, 0.0, d * 0.55)
    bump = S.sweep(f * 1.25, f, 0.09) * env(N(0.09), 0.004, 0.025)
    return mix(rub, at(0.8 * bump, d * 0.55))


def tap(f):
    """One knock from inside: a hollow shell note, damped and muffled by the shell."""
    d = 0.12
    body = np.sin(2 * np.pi * f * S.T(d)) * env(N(d), 0.0015, 0.022)
    knock = mix(body, 0.25 * bpf(noise(d), 600, 1800) * env(N(d), 0.001, 0.008))
    return lpf(knock, 1600)


def knock(i):
    """A gentle wobble (left, right, a smaller settle) and a faint tap-tap from the Boki inside."""
    sway = S.rng.uniform(0.0, 0.03)
    lean = [rock(0.2, 190 * j(i)), at(0.75 * rock(0.18, 205 * j(i)), 0.22 + sway),
            at(0.45 * rock(0.15, 180), 0.42 + sway)]
    f = 560 * j(i, 0.06)
    taps = [at(0.55 * tap(f), 0.68), at(0.4 * tap(f * 0.94), 0.82 + S.rng.uniform(0.0, 0.04))]
    return B.soft(B.room(mix(*lean, *taps), 0.25), 4200)


def shell_crack(i):
    """A tiny eggshell fracture: a hollow tick, then three to five dry ticks spreading over 80 ms."""
    d = 0.22
    hollow = np.sin(2 * np.pi * 2400 * j(i, 0.08) * S.T(0.05)) * env(N(0.05), 0.0004, 0.012)
    body = np.sin(2 * np.pi * 430 * j(i) * S.T(0.05)) * env(N(0.05), 0.0008, 0.015)
    ticks = [at(S.crack(0.012, 2500, 8000, 0.0015) * S.rng.uniform(0.4, 0.9), S.rng.uniform(0.01, 0.09))
             for _ in range(3 + i % 3)]
    return B.room(S.pad(mix(0.6 * hollow, 0.5 * body, *ticks), d), 0.2)


def ready(i):
    """Four glassy notes up a major chord, a shimmer under them and the Boki's muffled chirp at the top."""
    notes = [1047, 1319, 1568, 2093]
    bells = [at(S.chime(f * j(i, 0.01), 0.9, 0.32) * (0.7 if k < 3 else 0.9), 0.1 * k) for k, f in enumerate(notes)]
    shimmer = hpf(noise(1.0), 4500) * S.shape(1.0, 0.35, 0.1, 0.55) * 0.06
    chirp = lpf(B.squeak(1180 * j(i), 0.14, 0.18), 1500)
    return B.soft(B.room(mix(*bells, at(shimmer, 0.15), at(0.5 * chirp, 0.42)), 0.5), 6400)


def main():
    S.takes_cat('egg_knock', knock, 1, 'step')
    S.takes_cat('egg_crack', shell_crack, 3, 'step')
    S.takes_cat('egg_ready', ready, 1, 'boki')


if __name__ == '__main__':
    main()
