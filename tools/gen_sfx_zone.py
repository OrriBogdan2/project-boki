"""The closing zone's sounds (docs/decisions/0060-shrinking-zone.md; scripts/match/zone_sfx.gd). Run from tools/.

The zone's wall is a cold blue band of light, so its sounds are electric and glassy: a tonal buzz, never the
Blight tide's dark noise rumble (gen_sfx_tide.py), and never a clock tick (the Ways Out countdown is the only
countdown). All our own synthesis:
  zone_warn   cast    a close is 20 s away: the wall's buzz charging up under two cold pings a fourth apart (1.5 s)
  zone_hum    loop    the wall itself, placed on its nearest point to you and carrying 60 m: a low buzz on
                      73.5 Hz beating against 74 Hz; the distance roll-off makes it grow as you near the wall
  zone_cross  cast    you pass through the wall: a whoosh, a zap and a soft thump at the membrane (0.7 s);
                      ZoneSfx plays it lower going out and brighter coming back in
  zone_tick   impact  the zone's damage lands on you: a short sizzle and an electric bite (0.3 s, 4 takes),
                      a burn on the skin, not a blow (a hit taken plays the Hunter's hurt voice instead)
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, mix, at, lpf, bpf

S.reseed(2611)

HUM_F = 73.5        # Hz: whole cycles in the 4 s loop (294), as are its harmonics and the 74 Hz partner


def buzz(f, d, top=9, cut=1200.0):
    """A band-limited buzz on f (harmonics 1..top falling as 1/n), low-passed at cut: the harmonics carry it
    on small speakers that drop the 73.5 Hz itself."""
    t = T(d)
    return lpf(sum(np.sin(2 * np.pi * f * n * t) / n for n in range(1, top + 1)), cut)


def hum():
    d = 4.0; t = T(d)
    body = buzz(HUM_F, d) + 0.6 * buzz(74.0, d, 5)            # 0.5 Hz beating: the wall throbs
    fizz = bpf(S.noise(d), 2500, 7000) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.75 * t)) * 0.08
    return body + fizz


def warn():
    d = 1.5; t = T(d)
    f = HUM_F * (1.5 ** np.clip(t / 1.2, 0.0, 1.0))           # the buzz rising a fifth over 1.2 s
    ph = 2 * np.pi * np.cumsum(f) / S.SR
    rise = lpf(sum(np.sin(ph * n) / n ** 1.3 for n in range(1, 8)), 1400) * S.shape(d, 0.9, 0.1, 0.5)
    air = bpf(S.noise(d), 1200, 6000) * S.shape(d, 1.0, 0.0, 0.5) * 0.12
    cold = ((1.0, 1.0), (2.0, 0.35), (4.1, 0.12))
    pings = mix(at(S.chime(880.0, 0.8, 0.3, cold), 0.3), at(S.chime(1175.0, 0.9, 0.35, cold), 0.62))
    return mix(rise * 0.55, air, pings * 1.1)


def cross():
    d = 0.7
    whoosh = bpf(S.noise(d), 400, 4000) * S.shape(d, 0.25, 0.05, 0.4) * 0.6
    zap = S.fm(140.0, 2.01, 6.0, 0.3, decay=0.12) * 0.5
    thump = S.kick(110.0, 50.0, 0.3, drop=0.03, decay=0.07, drive=1.4) * 0.6
    return mix(whoosh, at(zap, 0.24), at(thump, 0.26))


def tick(i):
    d = 0.3
    sizzle = S.grains(0.26, 140, 2500, 8000, fall=0.08) * 1.4
    bite = S.fm(96.0 + 5.0 * i, 3.0, 4.0, 0.22, decay=0.07) * 0.5
    body = S.kick(150.0, 75.0, 0.12, drop=0.02, decay=0.03, drive=1.3) * 0.35
    return S.pad(mix(S.soft_in(sizzle), bite, body), d) * S.shape(d, 0.002, 0.12, 0.17)


def main():
    S.save_cat('zone_warn', warn(), 'cast')
    S.save_loop('zone_hum', hum(), 'loop')
    S.save_cat('zone_cross', cross(), 'cast')
    S.takes_cat('zone_tick', tick, 3, 'impact')


if __name__ == '__main__':
    main()
