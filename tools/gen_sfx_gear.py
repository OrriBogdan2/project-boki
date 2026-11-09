"""Pickup and glove sounds (docs/AUDIO.md). Run from tools/: python3 gen_sfx_gear.py

Pickups, one short cue per kind of thing (PickupSfx): armour = a dull plate clank, weapon or glove = a
steel snick, supply (tonic, armour kit, seed, belt item) = a glass clink and cork pop, gem or gold = a
rising bright chime, key = two ringing falling metal notes.
Gloves, own sounds for four of them: Blink (a pitch-dropping pop out and a bright swish in), Barrier
(stone rising out of the ground), Hook (a rope whip, then a hard grab), Rocket (ignition then a roar).
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, hpf, bpf, noise

S.reseed(5120)


def jit(i, spread=0.02):
    """Take i drifts a little in pitch so repeats never sound identical."""
    return 1.0 + (0 if i == 0 else S.rng.uniform(-spread, spread))


def room(x, amt=0.5):
    return S.reflections(x, ((0.017, 0.18 * amt, 2600), (0.037, 0.12 * amt, 1800), (0.061, 0.07 * amt, 1200)))


# ---------------------------------------------------------------- pickups
def pickup_armor(i):
    j = jit(i)
    plate = S.fm(210 * j, 1.47, 2.2, 0.28, 0.07) * 0.8
    thud = S.kick(120 * j, 60, 0.12, 0.03, 0.05) * 0.9
    scrape = bpf(noise(0.05), 900, 3200) * env(N(0.05), 0.002, 0.012) * 0.3
    return lpf(room(mix(plate, thud, scrape), 0.4), 3800)


def pickup_arms(i):
    j = jit(i)
    snick = S.click(0.006, 2800, 8000, 0.002) * 0.9
    slide = bpf(noise(0.11), 2500 * j, 7500) * env(N(0.11), 0.01, 0.04) * np.linspace(0.3, 1.0, N(0.11)) * 0.5
    lock = at(S.fm(1250 * j, 2.3, 1.2, 0.12, 0.03) * 0.55, 0.075)
    return room(mix(snick, slide, lock), 0.3)


def pickup_supply(i):
    j = jit(i)
    clink = S.chime(1750 * j, 0.22, 0.08, ((1.0, 1.0), (2.4, 0.35))) * 0.7
    pop = at(S.sweep(300 * j, 640 * j, 0.07) * env(N(0.07), 0.003, 0.025), 0.07) * 0.8
    return lpf(room(mix(clink, pop), 0.4), 5200)


def pickup_gem(i):
    j = jit(i, 0.015)
    notes = [at(S.chime(f * j, 0.45, 0.16, ((1.0, 1.0), (2.76, 0.3), (5.4, 0.12))), 0.05 * k)
             for k, f in enumerate((1320, 1760, 2349))]
    glint = at(S.chime(3520 * j, 0.5, 0.18, ((1.0, 1.0),)) * 0.35, 0.15)
    return room(mix(*notes, glint), 0.5)


def pickup_key(i):
    j = jit(i)
    hi = S.fm(1480 * j, 3.1, 1.8, 0.4, 0.12)
    lo = at(S.fm(990 * j, 3.1, 1.6, 0.4, 0.14), 0.09)
    jingle = at(S.rattle(0.12, 70, 3000, 7500, 0.4, 0.04), 0.01) * 0.35
    return room(mix(hi, lo, jingle), 0.4)


# ---------------------------------------------------------------- gloves
def blink_cast(i):
    j = jit(i)
    pop = S.sweep(900 * j, 140, 0.16, curve=0.6) * env(N(0.16), 0.002, 0.05)
    swish = S.hiss(0.25, 2500, 9500, 0.03, 0.09) * np.linspace(0.2, 1.0, N(0.25)) * 0.6
    return room(mix(pop, at(swish, 0.06)), 0.4)


def blink_hit(i):
    j = jit(i)
    snap = S.crack(0.09, 2000, 9000, 0.03) * 0.8
    bell = S.chime(1560 * j, 0.5, 0.2, ((1.0, 1.0), (2.76, 0.4), (5.4, 0.2))) * 0.6
    boom = S.sweep(380, 90, 0.2) * env(N(0.2), 0.002, 0.07) * 0.9
    return room(mix(snap, bell, boom), 0.5)


def barrier_cast(i):
    j = jit(i)
    rumble = S.sub(70 * j, 38, 0.55, 0.22, 0.04)
    grind = S.creak(0.5, 110 * j, 70, 0.8, 1800) * 0.7
    grit = S.grains(0.5, 180, 300, 1600, 0.004, 0.012, 0.2) * 0.5
    slam = at(S.kick(95 * j, 45, 0.18, 0.04, 0.09), 0.38) * 1.2
    return lpf(room(mix(rumble, grind, grit, slam), 0.5), 3000)


def hook_cast(i):
    j = jit(i)
    whip = bpf(noise(0.18), 1800 * j, 8500) * np.linspace(0.2, 1.0, N(0.18)) ** 2 * env(N(0.18), 0.01, 0.07)
    crack = at(S.crack(0.06, 2500, 9500, 0.02), 0.16)
    rope = S.sweep(420, 260 * j, 0.3) * env(N(0.3), 0.01, 0.1) * 0.3
    return room(mix(whip, crack * 0.9, rope), 0.3)


def hook_hit(i):
    j = jit(i)
    clank = S.fm(520 * j, 1.9, 2.0, 0.22, 0.05) * 0.7
    thud = S.kick(150 * j, 55, 0.18, 0.04, 0.08, 2.5)
    tug = bpf(noise(0.15), 300, 1400) * env(N(0.15), 0.01, 0.05) * 0.4
    return lpf(room(mix(clank, thud, tug), 0.4), 4200)


def rocket_cast(i):
    j = jit(i, 0.03)
    ign = S.crack(0.05, 1200, 6000, 0.02) * 0.9
    roar = lpf(noise(0.7), 1800) * env(N(0.7), 0.05, 0.28) * np.linspace(0.6, 1.0, N(0.7))
    rise = S.sweep(130 * j, 520, 0.7, 'saw', 1.5) * env(N(0.7), 0.04, 0.3) * 0.25
    low = S.sub(60, 90, 0.6, 0.3, 0.02)
    return room(mix(ign, roar, rise, low), 0.4)


def main():
    for name, fn in (('pickup_armor', pickup_armor), ('pickup_arms', pickup_arms), ('pickup_supply', pickup_supply),
                     ('pickup_gem', pickup_gem), ('pickup_key', pickup_key)):
        S.takes_cat(name, fn, 3, 'ui')
    S.takes_cat('glove_blink_cast', blink_cast, 2, 'cast')
    S.takes_cat('glove_blink_hit', blink_hit, 2, 'impact')
    S.takes_cat('glove_barrier_cast', barrier_cast, 2, 'cast')
    S.takes_cat('glove_hook_cast', hook_cast, 2, 'cast')
    S.takes_cat('glove_hook_hit', hook_hit, 2, 'impact')
    S.takes_cat('glove_rocket_cast', rocket_cast, 2, 'cast')


if __name__ == '__main__':
    main()
