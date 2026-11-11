"""Mixing Bowl sounds (briefs/design/GARDEN_MODERN.md 1.4, scripts/home/bowl_sfx.gd, docs/AUDIO.md). Run from tools/.

A wooden bowl, a spoon and small bells; soft and close, nothing hard.
  bowl_plop_snack   a snack going in: a wet, round plop         bowl_plop_treat   a nut or a pearl: a hard clunk and a tink
  bowl_plop_bun     a bun going in: a dull, doughy thump
  bowl_stir         a loop: a wooden spoon going round the bowl (about 1 s)
  bowl_done_1 / _2 / _3   the mix is ready, by recipe tier: one bell; two bells up a fifth; three rising bells and a shimmer
  bowl_fizzle       an unstable pair shares a bun: a short fizz, a small pop and a wobbling "oop"
  bowl_taste        a Boki tasting a bowl item: three quick munches and a happy "mm" (pitched by size at play time)
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, hpf, bpf, noise
import gen_sfx_boki as B

S.reseed(6173)


def j(i, s=0.05):
    return B.j(i, s)


def tink(f, d=0.25, decay=0.08):
    """A tiny bell: the note and a bright partial."""
    t = S.T(d); n = N(d)
    return (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2.76 * t)) * env(n, 0.002, decay)


def plop_snack(i):
    """A drop into soft stuff: a pitch that falls fast, a splash of noise and a second small bubble."""
    d = 0.22; n = N(d)
    drop = S.sweep(520 * j(i), 170, 0.16) * env(N(0.16), 0.002, 0.05)
    splash = bpf(noise(d), 700, 2600) * env(n, 0.001, 0.03) * 0.35
    bubble = at(S.sweep(380, 560, 0.07) * env(N(0.07), 0.003, 0.02) * 0.4, 0.11)
    return B.soft(B.room(mix(S.pad(drop, d)[:n], splash, bubble), 0.3), 4200)


def plop_treat(i):
    """A hard nut or pearl landing in a wooden bowl: a knock, then a small bell from the rim."""
    knock = mix(np.sin(2 * np.pi * 260 * j(i) * S.T(0.09)) * env(N(0.09), 0.001, 0.025),
                0.5 * bpf(noise(0.09), 1200, 3800) * env(N(0.09), 0.001, 0.012))
    return B.soft(B.room(mix(knock, at(0.5 * tink(1760 * j(i, 0.03), 0.22, 0.07), 0.025)), 0.3), 5600)


def plop_bun(i):
    """A soft round bun: a low, dull thump with almost no top."""
    d = 0.2; n = N(d)
    thump = S.sweep(210 * j(i), 95, d) * env(n, 0.004, 0.06)
    return lpf(B.room(mix(thump, 0.2 * lpf(noise(d), 700) * env(n, 0.002, 0.03)), 0.25), 1800)


def stir():
    """A wooden spoon round a bowl, 1.2 s and seamless: a slow swish of noise with two soft knocks on the rim."""
    d = 1.2; n = N(d); u = np.arange(n) / n
    swish = bpf(noise(d), 500, 2200) * (0.55 + 0.45 * np.sin(2 * np.pi * 2 * u)) * 0.5
    knocks = mix(*[at(np.sin(2 * np.pi * 330 * S.T(0.05)) * env(N(0.05), 0.001, 0.015) * 0.6, t0) for t0 in (0.15, 0.75)])
    return lpf(mix(swish, S.pad(knocks, d)[:n]), 3000)


def done(notes, ring):
    def make(i):
        bells = [at(tink(f * j(i, 0.01), ring if k == len(notes) - 1 else 0.3, 0.12 if k == len(notes) - 1 else 0.07), 0.09 * k)
                 for k, f in enumerate(notes)]
        if len(notes) > 2:
            bells.append(at(0.12 * hpf(noise(0.5), 4500) * S.shape(0.5, 0.3, 0.0, 0.2), 0.09 * (len(notes) - 1)))
        return B.soft(B.room(mix(*bells), 0.4), 6200)
    return make


def fizzle(i):
    """A short fizz of fine noise, a small pop, and the Boki's wobbling 'oop' dropping away: it still works, just fizzily."""
    d = 0.5
    fiz = hpf(noise(0.32), 3500) * (0.5 + 0.5 * np.sin(2 * np.pi * 22 * S.T(0.32))) * S.shape(0.32, 0.1, 0.1, 0.1) * 0.5
    pop = at(S.sweep(900, 300, 0.05) * env(N(0.05), 0.001, 0.015), 0.3)
    oop = at(0.5 * B.vowel(480 * j(i, 0.03), 300, 0.2, 'oh', 1.3, breath=0.1), 0.32)
    return B.soft(B.room(mix(S.pad(fiz, d)[:N(d)], pop, oop), 0.3), 5000)


def taste(i):
    """Three quick munches (a damp chew each) and a happy rising 'mm'."""
    chews = [at(0.8 * mix(bpf(noise(0.07), 500, 1800) * env(N(0.07), 0.003, 0.025),
                          np.sin(2 * np.pi * 170 * S.T(0.06)) * env(N(0.06), 0.002, 0.02) * 0.5), 0.11 * k) for k in range(3)]
    mm = at(B.vowel(300 * j(i, 0.04), 380, 0.3, 'uh', 1.3, breath=0.08) * 0.8, 0.36)
    chirp = at(0.4 * B.squeak(1100 * j(i, 0.04), 0.12, 0.14), 0.5)
    return B.soft(B.room(mix(*chews, mm, chirp), 0.35), 5200)


def main():
    S.takes_cat('bowl_plop_snack', plop_snack, 2, 'ui')
    S.takes_cat('bowl_plop_treat', plop_treat, 2, 'ui')
    S.takes_cat('bowl_plop_bun', plop_bun, 2, 'ui')
    S.save_loop('bowl_stir', stir(), 'loop')
    S.takes_cat('bowl_done_1', done([1175], 0.5), 1, 'ui')
    S.takes_cat('bowl_done_2', done([988, 1480], 0.6), 1, 'ui')
    S.takes_cat('bowl_done_3', done([784, 988, 1319], 0.8), 1, 'ui')
    S.takes_cat('bowl_fizzle', fizzle, 2, 'boki')
    S.takes_cat('bowl_taste', taste, 2, 'boki')


if __name__ == '__main__':
    main()
