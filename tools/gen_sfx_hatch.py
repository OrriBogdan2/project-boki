"""Hatch sounds (docs/AUDIO.md): the first-day egg, from wobble to first chirp. Run from tools/.

Wobble = a soft shell knock. Crack 1 = a small dry snap, crack 2 = a bigger, higher one (they rise).
Pop = the shell splitting open. Chirp = the hatchling's first sound, one per starter type
(venom, prism, spore). The black mystery egg has its own set: lower, hollow and slow, with a curious
upward question for a chirp. All at the Boki loudness (content/rules/sfx_levels.json).
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, bpf, noise

S.reseed(8113)


def room(x):
    return S.reflections(x, ((0.02, 0.16, 2400), (0.047, 0.1, 1700), (0.09, 0.06, 1200)))


def knock(f, d=0.12, decay=0.03, cut=2600):
    """A knock on a hollow shell: a short falling tone and a tap of noise."""
    return lpf(mix(S.kick(f * 1.5, f, d, 0.02, decay, 1.4), 0.35 * S.click(0.004, 1500, 5000)), cut)


def snap(f, d, lo, hi, decay):
    """A dry crack: a bright noise snap over a short tone."""
    return mix(S.crack(d, lo, hi, decay), 0.5 * S.kick(f * 1.3, f, d, 0.015, decay, 1.2))


def squeak(f, d, scoop, a=0.008):
    """A small chirp: pitch scoops into f with a little wobble."""
    n = N(d); u = np.arange(n) / n; t = u * d
    ff = f * (1 + scoop * np.exp(-u * 8)) * (1 + 0.02 * np.sin(2 * np.pi * 9 * t))
    ph = 2 * np.pi * np.cumsum(ff) / S.SR
    return (np.sin(ph) + 0.2 * np.sin(2 * ph)) * env(n, a, d * 0.4)


# ---------------------------------------------------------------- the starter egg
def wobble(i):
    return room(knock(260 * (1 + 0.03 * i)))


def crack_1(i):
    return room(lpf(mix(snap(700, 0.14, 1800, 6500, 0.02), at(snap(900, 0.08, 2200, 7000, 0.012), 0.07)), 5200))


def crack_2(i):
    first = snap(1000, 0.16, 2200, 8000, 0.03)
    return room(lpf(mix(first, at(snap(1250, 0.1, 2600, 8500, 0.016), 0.06), at(snap(1500, 0.08, 3000, 9000, 0.012), 0.11)), 6000))


def pop(i):
    burst = S.crack(0.22, 900, 6000, 0.05)
    body = S.kick(420, 150, 0.25, 0.04, 0.07, 1.6)
    shards = S.grains(0.3, 60, 3000, 8000, fall=0.08)
    return room(lpf(mix(burst, 0.8 * body, 0.4 * shards), 6500))


# chirp: (base Hz, scoop, length s); venom is sharp and quick, prism glassy, spore soft and low
CHIRPS = {'venom': (1250, 0.2, 0.16), 'prism': (1500, 0.14, 0.2), 'spore': (980, 0.12, 0.22)}


def chirp(kind):
    f, scoop, d = CHIRPS[kind]
    def fn(i):
        x = squeak(f * (1 + 0.03 * i), d, scoop)
        return room(lpf(mix(x, at(0.5 * squeak(f * 1.26, d * 0.7, scoop), d * 0.55)), 5200))
    return fn


# ---------------------------------------------------------------- the black mystery egg
def m_wobble(i):
    return room(lpf(knock(150 * (1 + 0.03 * i), 0.2, 0.06), 1500))


def m_crack_1(i):
    return room(lpf(mix(snap(420, 0.18, 700, 3200, 0.035), 0.6 * S.sub(110, 70, 0.25, 0.08)), 3600))


def m_crack_2(i):
    return room(lpf(mix(snap(620, 0.2, 900, 4000, 0.04), at(snap(760, 0.12, 1000, 4200, 0.02), 0.08), 0.6 * S.sub(130, 80, 0.3, 0.1)), 4200))


def m_pop(i):
    return room(lpf(mix(S.crack(0.25, 500, 3800, 0.06), S.kick(300, 90, 0.35, 0.05, 0.1, 1.5),
                        0.4 * S.grains(0.35, 40, 1800, 5000, fall=0.1)), 4200))


def m_chirp(i):
    """A low, curious question: a slow rise that tips up at the end, with a soft hum under it."""
    d = 0.42; n = N(d); u = np.arange(n) / n
    f = 360 * (1 + 0.1 * u + 0.5 * np.clip(u - 0.6, 0, 1) ** 1.5)
    ph = 2 * np.pi * np.cumsum(f) / S.SR
    x = (np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)) * env(n, 0.05, 0.22)
    return room(lpf(mix(x, 0.25 * S.sweep(180, 190, d) * env(n, 0.06, 0.2)), 3000))


def main():
    for name, fn, takes in (('hatch_wobble', wobble, 3), ('hatch_crack_1', crack_1, 1), ('hatch_crack_2', crack_2, 1),
                            ('hatch_pop', pop, 1), ('hatch_mystery_wobble', m_wobble, 3),
                            ('hatch_mystery_crack_1', m_crack_1, 1), ('hatch_mystery_crack_2', m_crack_2, 1),
                            ('hatch_mystery_pop', m_pop, 1), ('hatch_mystery_chirp', m_chirp, 1)):
        if takes > 1:
            S.takes_cat(name, fn, takes, 'boki')
        else:
            S.save_cat(name, fn(0), 'boki')
    for kind in CHIRPS:
        S.takes_cat('hatch_chirp_' + kind, chirp(kind), 2, 'boki')


if __name__ == '__main__':
    main()
