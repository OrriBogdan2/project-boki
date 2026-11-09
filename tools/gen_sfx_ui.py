"""The UI sound palette (docs/AUDIO.md): soft, warm, one family. Run from tools/: python3 gen_sfx_ui.py

Everything is a felt-mallet pluck (a marimba or kalimba tine: a sine with a quiet 4x partial, a 2-3 ms
fade-in, a short fall) in C major pentatonic, low-passed to stay round, with a small room behind it.
Press = a short tap, hover = a tiny high tick, confirm = a rising pair, back = a falling pair, deny = a
muted low double bump, open/close = an airy rise or fall under a pluck, tabs = a wood tick.
Several of these replace the older gameplay-era files under the same names (click, hover, pickup,
unlock, ping, level_up); reset_a/b/c are untouched (tools/gen_reset_sfx.py).
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf, noise

S.reseed(7741)
NOTE = {'C4': 262, 'D4': 294, 'E4': 330, 'G4': 392, 'A4': 440, 'C5': 523, 'D5': 587, 'E5': 659, 'G5': 784,
        'A5': 880, 'C6': 1047, 'D6': 1175, 'E6': 1319, 'G6': 1568}


def pluck(f, d=0.25, decay=0.07, warm=1.0, a=0.0025):
    """A felt-mallet tine: the note, a quiet 4x partial that dies fast, and a soft thud of the mallet."""
    n = N(d); t = T(d)
    body = np.sin(2 * np.pi * f * t) * env(n, a, decay)
    over = 0.22 * np.sin(2 * np.pi * f * 4.0 * t + 0.7) * env(n, a, decay * 0.3) * warm
    thud = 0.18 * lpf(noise(0.012), 900) * env(N(0.012), 0.002, 0.004)
    return body + over + np.concatenate([thud, np.zeros(n - len(thud))])


def room(x, amt=0.5):
    """A small soft room: dark early reflections, enough to take the dryness off."""
    return S.reflections(x, ((0.021, 0.20 * amt, 2200), (0.043, 0.14 * amt, 1600), (0.071, 0.09 * amt, 1100)))


def finish(x, cut=4200):
    return lpf(x, cut)


def jit(i, spread=0.012):
    """Take i drifts a little in pitch so repeats never sound identical."""
    return 1.0 + (0 if i == 0 else S.rng.uniform(-spread, spread))


# ---------------------------------------------------------------- the core controls
def click(i):
    f = 560 * jit(i, 0.03)
    tap = mix(pluck(f, 0.09, 0.022, 0.7), 0.5 * pluck(f * 1.5, 0.07, 0.015, 0.4))
    thump = S.sweep(190, 120, 0.05) * env(N(0.05), 0.003, 0.014) * 0.7
    return finish(room(mix(tap, thump), 0.3), 3600)


def hover(i):
    return finish(pluck(NOTE['E6'] * jit(i, 0.02), 0.06, 0.012, 0.3), 5000)


def confirm(i):
    j = jit(i)
    return finish(room(mix(pluck(NOTE['D5'] * j, 0.3, 0.07), at(pluck(NOTE['A5'] * j, 0.45, 0.13), 0.075)), 0.6))


def back(i):
    j = jit(i)
    return finish(room(mix(pluck(NOTE['G5'] * j, 0.22, 0.05), at(pluck(NOTE['D5'] * j, 0.34, 0.09), 0.07)), 0.5), 3600)


def deny(i):
    j = jit(i)

    def bump(f):
        return (S.sweep(f * 1.15, f, 0.12) * env(N(0.12), 0.004, 0.04)
                + 0.25 * pluck(f * 2.0, 0.12, 0.02, 0.3))
    return finish(room(mix(bump(165 * j), at(bump(150 * j), 0.1)), 0.3), 1800)


def tab(i):
    f = 880 * jit(i, 0.04)
    return finish(mix(pluck(f, 0.1, 0.02, 0.5), 0.4 * pluck(f * 0.5, 0.1, 0.03, 0.2)), 3800)


def swell(rise, d, lo, hi):
    """A breath of air through a band that opens (rise) or closes (not rise), soft at both ends."""
    n = N(d); u = np.arange(n) / n
    air = bpf(noise(d), lo, hi) * np.sin(np.pi * u) ** 2
    return lpf(air, 3000) * (0.6 + 0.4 * (u if rise else 1 - u))


def open_(i):
    j = jit(i)
    return finish(room(mix(swell(True, 0.28, 500, 2400) * 0.35, at(pluck(NOTE['G5'] * j, 0.3, 0.08), 0.14),
                           at(pluck(NOTE['C6'] * j, 0.4, 0.1), 0.2)), 0.5), 3800)


def close_(i):
    j = jit(i)
    return finish(room(mix(swell(False, 0.24, 450, 2000) * 0.3, pluck(NOTE['C6'] * j, 0.22, 0.05),
                           at(pluck(NOTE['G5'] * j, 0.3, 0.08), 0.07)), 0.5), 3600)


def toast(i):
    j = jit(i)
    return finish(room(mix(pluck(NOTE['E6'] * j, 0.35, 0.09, 0.6),
                           at(pluck(NOTE['G6'] * j, 0.45, 0.12, 0.5), 0.08) * 0.8), 0.7), 5200)


# ---------------------------------------------------------------- rewards and alerts
def pickup(i):
    j = jit(i, 0.02)
    return finish(room(mix(pluck(NOTE['G5'] * j, 0.2, 0.05), at(pluck(NOTE['C6'] * j, 0.3, 0.09), 0.055)), 0.4), 4400)


def unlock(i):
    arp = [at(pluck(NOTE[n], 0.5 if k < 4 else 1.0, 0.1 if k < 4 else 0.3), 0.085 * k)
           for k, n in enumerate(['C5', 'E5', 'G5', 'C6', 'E6'])]
    sparkle = at(S.chime(NOTE['C6'] * 2, 0.9, 0.3, ((1.0, 0.6), (2.76, 0.2))) * 0.25, 0.34)
    return finish(room(mix(*arp, sparkle), 0.8), 5600)


def level_up(i):
    arp = [at(pluck(NOTE[n], 0.5, 0.1), 0.07 * k) for k, n in enumerate(['G4', 'C5', 'E5', 'G5', 'C6'])]
    top = at(mix(pluck(NOTE['C6'], 1.1, 0.3), pluck(NOTE['G5'], 1.1, 0.3) * 0.7,
                 pluck(NOTE['E6'], 1.1, 0.3) * 0.5), 0.35)
    glow = at(S.chime(NOTE['G6'], 1.1, 0.4, ((1.0, 0.6), (2.76, 0.15))) * 0.22, 0.36)
    return finish(room(mix(*arp, top, glow), 0.9), 5600)


def ping(i):
    return finish(room(mix(pluck(NOTE['A5'] * jit(i, 0.01), 0.6, 0.18, 0.8),
                           0.4 * pluck(NOTE['A5'] * 1.5, 0.4, 0.1, 0.3)), 0.7), 4800)


def charge(i):
    """A held-button swell that rises in pitch, soft; the caller pitch-scales it as the hold grows."""
    d = 0.5; n = N(d); u = np.arange(n) / n
    low = S.sweep(330, 520, d) * np.sin(np.pi * u * 0.5 + 0.1) * u ** 0.6
    high = S.sweep(660, 1040, d) * u ** 1.5
    return finish(mix(low * 0.5, high * 0.2, pluck(NOTE['G5'], d, 0.4, 0.2) * 0.15 * u), 3000)


# ---------------------------------------------------------------- garden reactions
# The farm's own cues (what you hear most at home): short, warm, one per kind, so `unlock` stays for real unlocks.
def feed(i):
    """Two soft munches (a low tine and a crumb of noise) and a pleased rising tine."""
    j = jit(i, 0.03)

    def munch(f):
        return mix(pluck(f, 0.1, 0.03, 0.2), 0.5 * lpf(noise(0.05), 1400) * env(N(0.05), 0.003, 0.02))
    return finish(room(mix(munch(NOTE['C4'] * j), at(munch(NOTE['D4'] * j), 0.1),
                           at(pluck(NOTE['G5'] * j, 0.35, 0.1), 0.22)), 0.5), 3800)


def pet(i):
    """A purr: a low tone with a quick tremolo, rounded off, and one warm tine on top."""
    d = 0.5; n = N(d); t = T(d)
    f = 150 * jit(i, 0.04)
    purr = np.sin(2 * np.pi * f * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 24 * t)) * np.sin(np.pi * np.arange(n) / n) ** 1.5
    return finish(room(mix(purr * 0.6, at(pluck(NOTE['E5'] * jit(i, 0.02), 0.4, 0.12, 0.4), 0.05)), 0.5), 2600)


def friend(i):
    """Two tines a fifth apart ring together (a handshake), then a bright third above."""
    return finish(room(mix(pluck(NOTE['G4'], 0.5, 0.14), pluck(NOTE['D5'], 0.5, 0.14),
                           at(pluck(NOTE['G5'], 0.7, 0.2), 0.12), at(pluck(NOTE['D6'], 0.8, 0.26), 0.2)), 0.8), 5200)


def trait(i):
    """A shimmer rising through a pentatonic climb, ending in a chime: something about it changed."""
    sw = S.sweep(420, 1250, 0.4) * env(N(0.4), 0.05, 0.2) * 0.25
    steps = [at(pluck(NOTE[nm], 0.4, 0.09), 0.06 * k) for k, nm in enumerate(['D5', 'E5', 'G5', 'A5'])]
    chime = at(S.chime(NOTE['D6'], 0.9, 0.3, ((1.0, 0.6), (2.76, 0.2))) * 0.3, 0.26)
    return finish(room(mix(sw, *steps, chime), 0.8), 5400)


def egg(i):
    """A hollow wooden tock (a shell settling in straw) and a small warm bell."""
    tock = (S.sweep(420, 210, 0.09) * env(N(0.09), 0.002, 0.03)
            + 0.3 * S.pad(bpf(noise(0.04), 900, 1800) * env(N(0.04), 0.002, 0.012), 0.09))
    return finish(room(mix(tock, at(pluck(NOTE['E5'], 0.55, 0.16, 0.5), 0.07), at(pluck(NOTE['A5'], 0.6, 0.18, 0.4), 0.17)), 0.7), 4200)


def toy(i):
    """A rubber bounce: a pitch that hops up twice, each hop smaller, with a tine on the last."""
    def hop(f, d):
        return S.sweep(f, f * 1.7, d) * env(N(d), 0.003, d * 0.5)
    return finish(room(mix(hop(330, 0.1), at(hop(400, 0.08), 0.12) * 0.7, at(pluck(NOTE['C6'], 0.3, 0.08), 0.22)), 0.4), 4600)


# ---------------------------------------------------------------- write
def main():
    S.takes_cat('click', click, 3, 'ui')
    S.takes_cat('hover', hover, 3, 'ui')
    S.takes_cat('ui_confirm', confirm, 2, 'ui')
    S.takes_cat('ui_back', back, 2, 'ui')
    S.takes_cat('ui_deny', deny, 2, 'ui')
    S.takes_cat('ui_tab', tab, 3, 'ui')
    S.takes_cat('ui_open', open_, 2, 'ui')
    S.takes_cat('ui_close', close_, 2, 'ui')
    S.takes_cat('ui_toast', toast, 2, 'ui')
    S.takes_cat('pickup', pickup, 3, 'ui')
    S.save_cat('unlock', unlock(0), 'ui')
    S.save_cat('level_up', level_up(0), 'ui')
    S.takes_cat('ping', ping, 2, 'ui')
    S.save_cat('ui_charge', charge(0), 'ui')
    S.takes_cat('garden_feed', feed, 2, 'ui')
    S.takes_cat('garden_pet', pet, 3, 'ui')
    S.save_cat('garden_friend', friend(0), 'ui')
    S.save_cat('garden_trait', trait(0), 'ui')
    S.save_cat('garden_egg', egg(0), 'ui')
    S.save_cat('garden_toy', toy(0), 'ui')


if __name__ == '__main__':
    main()
