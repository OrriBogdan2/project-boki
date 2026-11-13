"""Synthesizes the shot flyby cues (a rival's shot passing close to you) into audio/flyby_<family>.wav:
bullet, arrow, bolt, orb, fire, ice, rock. Each is a short pass-by: it swells in, peaks and fades, with a
falling pitch like a Doppler pass, 0.15 to 0.35 s. Levelled to the quiet "dash" category (they sit under
the real shots and hits). Own random stream, so no other generator's output moves.

    python3 tools/gen_flyby_sfx.py      (then: godot --headless --import)
"""
import sfx_lib as S
from sfx_lib import bpf, lpf, mix, noise, shape, sweep, soft_in, hiss, fm


def swell(d, x):
    """A pass-by: the sound builds to its peak at 40% and falls away."""
    return soft_in(x[:S.N(d)] * shape(d, d * 0.4, 0.0, d * 0.6))


def bullet(i):
    d = 0.15
    return swell(d, bpf(noise(d), 2400, 7500) + 0.5 * sweep(5200, 3000, d) * 0.3)


def arrow(i):
    d = 0.26
    return swell(d, bpf(noise(d), 900, 3200) + 0.35 * sweep(1500, 800, d, 'saw') * 0.3)


def bolt(i):
    d = 0.2
    return swell(d, bpf(noise(d), 1500, 5000) * 0.8 + 0.5 * fm(900, 1.41, 3.0, d, 0.15))


def orb(i):
    d = 0.34
    return swell(d, 0.9 * sweep(420, 260, d) + 0.35 * sweep(840, 520, d) + 0.25 * bpf(noise(d), 300, 1400))


def fire(i):
    d = 0.32
    return swell(d, lpf(noise(d), 1700) * (0.7 + 0.3 * sweep(14, 9, d)) + 0.3 * hiss(d, 2500, 6500, 0.05, 0.2))


def ice(i):
    d = 0.26
    return swell(d, bpf(noise(d), 4000, 9500) * 0.6 + 0.6 * S.chime(3300, d, 0.12))


def rock(i):
    d = 0.34
    return swell(d, bpf(noise(d), 120, 700) * 1.4 + 0.7 * sweep(180, 90, d))


if __name__ == '__main__':
    S.reseed(2611)
    for name, fn in [('bullet', bullet), ('arrow', arrow), ('bolt', bolt), ('orb', orb), ('fire', fire),
                     ('ice', ice), ('rock', rock)]:
        S.save_cat('flyby_' + name, fn(0), 'dash')
    print('flyby cues written')
