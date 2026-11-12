"""Pickup sounds by item category, plus the tonic drink and the armour-kit repair (briefs/SFX_AUDIT.md
rows 12 and 14). Run from tools/: python3 gen_sfx_pickups.py

One short cue per kind of thing you pick up (content/rules/pickup_sfx.json says which item gets which):
armour clink (two small metal knocks), weapon heft (a low thud and a short steel slide), gem chime (two
glassy bells), consumable pop (a bubble that pops), generic (a soft wooden tap pair). The tonic is three
swallows falling in pitch; the kit repair is three ratchet taps rising, then a bolt seating.
Original synthesis, no samples. The key cue (key_get) is untouched (tools/gen_key_sfx.py).
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, hpf, bpf, noise

S.reseed(5120)


def jit(i, spread=0.02):
    """Take i drifts a little in pitch so repeats never sound identical."""
    return 1.0 + (0 if i == 0 else S.rng.uniform(-spread, spread))


def knock(f, d=0.12, decay=0.03):
    """A small metal knock: an inharmonic ring with a bright click on the front."""
    ring = S.ring([f, f * 2.41, f * 4.1], d, [decay, decay * 0.6, decay * 0.35], [1.0, 0.5, 0.25])
    return mix(ring, 0.5 * S.click(0.003, 3000, 9000, 0.001))


def armor(i):
    j = jit(i, 0.04)
    return lpf(mix(knock(1500 * j), at(knock(1130 * j, 0.14, 0.04) * 0.8, 0.07)), 7000)


def weapon(i):
    j = jit(i, 0.04)
    thud = S.kick(150 * j, 62, 0.16, 0.03, 0.07)
    slide = bpf(noise(0.12), 2200 * j, 7000) * env(N(0.12), 0.03, 0.04) * 0.35
    ring = S.ring([2100 * j, 3400 * j], 0.2, [0.07, 0.04], [0.4, 0.2])
    return lpf(mix(thud, at(slide, 0.03), at(ring, 0.06)), 6500)


def gem(i):
    j = jit(i, 0.02)
    return mix(S.chime(1760 * j, 0.45, 0.22), at(S.chime(2349 * j, 0.6, 0.3) * 0.8, 0.07))


def consumable(i):
    j = jit(i, 0.05)
    bub = S.sweep(380 * j, 1150 * j, 0.09) * env(N(0.09), 0.004, 0.05)
    pop = S.click(0.004, 1500, 6000, 0.003) * 0.6
    return lpf(mix(bub, at(pop, 0.085), at(S.sweep(900 * j, 600, 0.05) * env(N(0.05), 0.002, 0.02) * 0.3, 0.09)), 5200)


def tap(f):
    return mix(S.ring([f, f * 2.0], 0.12, [0.035, 0.015], [1.0, 0.25]), 0.3 * S.click(0.003, 800, 4000, 0.002))


def generic(i):
    j = jit(i, 0.03)
    return lpf(mix(tap(520 * j), at(tap(690 * j) * 0.8, 0.07)), 4200)


def tonic(i):
    """Three swallows, each a short falling gulp, then a small breath out."""
    j = jit(i, 0.04)
    out = []
    for k in range(3):
        g = S.sweep((460 - 40 * k) * j, (210 - 20 * k) * j, 0.11) * env(N(0.11), 0.01, 0.06)
        wet = lpf(noise(0.11), 1600) * env(N(0.11), 0.01, 0.04) * 0.25
        out.append(at(mix(g, wet), 0.16 * k))
    breath = bpf(noise(0.25), 1200, 4000) * env(N(0.25), 0.05, 0.1) * 0.18
    return lpf(mix(*out, at(breath, 0.5)), 3800)


def kit_repair(i):
    """Three ratchet taps rising in pitch, then a bolt seating with a low knock."""
    j = jit(i, 0.03)
    taps = [at(knock((1700 + 260 * k) * j, 0.07, 0.015) * 0.7, 0.09 * k) for k in range(3)]
    seat = S.kick(190, 85, 0.14, 0.02, 0.05) + 0.6 * knock(980 * j, 0.14, 0.05)
    return lpf(mix(*taps, at(seat, 0.3)), 7000)


def main():
    for name, fn in (('pickup_armor', armor), ('pickup_weapon', weapon), ('pickup_gem', gem),
                     ('pickup_consumable', consumable), ('pickup_generic', generic)):
        S.takes_cat(name, fn, 3, 'ui')
    S.takes_cat('use_tonic', tonic, 2, 'cast')
    S.takes_cat('use_armor_kit', kit_repair, 2, 'cast')


if __name__ == '__main__':
    main()
