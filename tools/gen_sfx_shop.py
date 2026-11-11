"""The in-match shop sounds (docs/AUDIO.md, content/sfx/shop.json): one family, the vendor's counter.
Run from tools/: python3 gen_sfx_shop.py

Everything is built from three things a stall has: its little brass lantern bell (inharmonic chime), the
wooden counter (a short dark knock) and coins (tiny bright metal clinks). In A major pentatonic, under
the UI palette's register so a shop never sounds like a menu.
  shop_near    the lantern bell stirring as you come within reach: two soft high bell notes, no knock
  shop_open    the shutter lifts: a wood knock, a rising bell pair
  shop_close   the shutter drops: a falling bell pair, a softer knock
  shop_buy_s   a cheap buy: one coin on the counter and a bell
  shop_buy_m   a middling buy: a few coins and a rising pair
  shop_buy_l   a big buy: a small pour of coins and a rising bell triad
  shop_broke   can't afford it: an empty purse tapped on wood, dull and low, no bell
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, hpf, bpf, noise

S.reseed(5307)
NOTE = {'A4': 440, 'C#5': 554, 'E5': 659, 'F#5': 740, 'A5': 880, 'B5': 988, 'C#6': 1109, 'E6': 1319}
BELL = ((1.0, 1.0), (2.4, 0.35), (4.1, 0.12))        # a thin brass bell, softer upper partials than S.chime's


def jit(i, spread=0.012):
    """Take i drifts a little in pitch so repeats never sound identical."""
    return 1.0 + (0 if i == 0 else S.rng.uniform(-spread, spread))


def bell(f, d=0.7, decay=0.3):
    return lpf(S.chime(f, d, decay, BELL), 5200)


def knock(f=180, d=0.09, amt=1.0):
    """The counter: a damped wooden thud with a little grain on the attack."""
    body = S.sweep(f * 1.3, f, d) * env(N(d), 0.002, d * 0.25)
    grain = lpf(noise(0.02), 2400) * env(N(0.02), 0.001, 0.005) * 0.4
    return amt * lpf(mix(body, np.concatenate([grain, np.zeros(N(d) - len(grain))])), 2000)


def coin(f):
    """One small coin: a very short bright two-partial ring and a tick."""
    d = 0.16; t = T(d)
    ring = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.71 * t)) * np.exp(-t / 0.035)
    tick = hpf(noise(0.006), 3000) * env(N(0.006), 0.0005, 0.002) * 0.6
    return bpf(mix(ring * 0.5, np.concatenate([tick, np.zeros(N(d) - len(tick))])), 1800, 9000)


def coins(k, spread, f0=3600):
    """k coins landing over `spread` seconds, each a little different."""
    return mix(*[at(coin(f0 * S.rng.uniform(0.85, 1.2)) * S.rng.uniform(0.6, 1.0),
                    spread * (j / max(k - 1, 1)) + S.rng.uniform(0, 0.012)) for j in range(k)])


def room(x, amt=0.5):
    return S.reflections(x, ((0.019, 0.22 * amt, 2400), (0.041, 0.15 * amt, 1700), (0.067, 0.1 * amt, 1200)))


def near(i):
    j = jit(i, 0.02)
    return room(mix(bell(NOTE['E6'] * j, 0.9, 0.35) * 0.6, at(bell(NOTE['B5'] * j, 1.0, 0.4) * 0.5, 0.11)), 0.7)


def open_(i):
    j = jit(i)
    return room(mix(knock(170 * j), at(bell(NOTE['C#6'] * j, 0.5, 0.18) * 0.5, 0.05),
                    at(bell(NOTE['E6'] * j, 0.7, 0.25) * 0.55, 0.12)), 0.5)


def close_(i):
    j = jit(i)
    return room(mix(bell(NOTE['E6'] * j, 0.4, 0.14) * 0.45, at(bell(NOTE['C#6'] * j, 0.55, 0.2) * 0.45, 0.07),
                    at(knock(150 * j, amt=0.8), 0.13)), 0.4)


def buy_s(i):
    j = jit(i)
    return room(mix(coins(1, 0.0), at(bell(NOTE['A5'] * j, 0.5, 0.18) * 0.45, 0.04)), 0.4)


def buy_m(i):
    j = jit(i)
    return room(mix(coins(3, 0.09), at(bell(NOTE['A5'] * j, 0.5, 0.18) * 0.45, 0.1),
                    at(bell(NOTE['E6'] * j, 0.7, 0.26) * 0.45, 0.18)), 0.5)


def buy_l(i):
    j = jit(i)
    pour = coins(7, 0.22, 3300)
    triad = [at(bell(NOTE[n] * j, 0.6 if k < 2 else 1.0, 0.2 if k < 2 else 0.38) * 0.42, 0.14 + 0.08 * k)
             for k, n in enumerate(['A5', 'C#6', 'E6'])]
    return room(mix(knock(140 * j, amt=0.6), pour, *triad), 0.7)


def broke(i):
    j = jit(i, 0.03)
    purse = lpf(noise(0.05), 700) * env(N(0.05), 0.003, 0.015) * 0.5
    return lpf(room(mix(knock(120 * j, 0.11), at(knock(105 * j, 0.1, 0.6), 0.075),
                        np.concatenate([purse, np.zeros(N(0.11) - len(purse))])), 0.25), 1300)


def main():
    S.takes_cat('shop_near', near, 2, 'ui')
    S.takes_cat('shop_open', open_, 2, 'ui')
    S.takes_cat('shop_close', close_, 2, 'ui')
    S.takes_cat('shop_buy_s', buy_s, 2, 'ui')
    S.takes_cat('shop_buy_m', buy_m, 2, 'ui')
    S.takes_cat('shop_buy_l', buy_l, 2, 'ui')
    S.takes_cat('shop_broke', broke, 2, 'ui')


if __name__ == '__main__':
    main()
