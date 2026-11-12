"""The glove active sounds (docs/AUDIO.md, content/sfx/gloves.json). Run from tools/: python3 gen_sfx_gloves.py

One cast sound per glove, plus an impact where the glove has one (Blink's slash, Barrier's hit, Hook's catch
and wall bite, Mirror's reflect, Fissure's eruption, Vortex's blast). The names sit in each glove's
content/gear/<id>.json under "sfx"; Effects, Verbs and Match.use_gear read them there. Original synthesis.
"""
import numpy as np
import sfx_lib as S
from sfx_lib import N, T, env, mix, at, lpf, bpf, noise, kick, crack, sub, sat

S.reseed(5151)


def jit(i, spread=0.03):
    """Take i drifts a little in pitch so repeats never sound identical."""
    return 1.0 + (0 if i == 0 else S.rng.uniform(-spread, spread))


def swish(d, f0, f1, width=0.5, a=0.03):
    """Air moving past: band noise whose centre glides from f0 to f1."""
    n = N(d); u = np.linspace(0, 1, n)
    out = np.zeros(n); k = 6
    for s in range(k):
        lo = f0 * (f1 / f0) ** (s / k) ; hi = lo * (1 + width)
        seg = slice(int(n * s / k), int(n * (s + 1) / k))
        out[seg] = bpf(noise(d), lo, hi)[seg]
    return lpf(out, 9000) * S.shape(d, a, d * 0.15, d * 0.6)


# ---------------------------------------------------------------- Blink: a snap out, a snap in; a slash
def blink(i):
    j = jit(i)
    out = S.sweep(1500 * j, 300, 0.09) * env(N(0.09), 0.002, 0.03)
    back = at(S.sweep(300, 1900 * j, 0.1) * env(N(0.1), 0.002, 0.04), 0.07)
    air = swish(0.2, 2500, 6000, 0.6, 0.01) * 0.5
    return mix(out * 0.7, back * 0.8, air, at(S.chime(2600 * j, 0.25, 0.1) * 0.25, 0.14))


def blink_hit(i):
    j = jit(i)
    cut = swish(0.16, 7000 * j, 2500, 0.8, 0.004) * 1.2
    tick = crack(0.05, 2500, 9000, 0.012) * 0.9
    return mix(cut, tick, at(kick(180, 70, 0.14, 0.03, 0.05) * 0.6, 0.02))


# ---------------------------------------------------------------- Barrier: a slab rising from the ground
def barrier(i):
    j = jit(i)
    rumble = lpf(noise(0.5), 220) * S.shape(0.5, 0.05, 0.1, 0.35) * 2.2
    thud = kick(110 * j, 45, 0.3, 0.05, 0.12, 2.5) * 1.0
    grit = crack(0.25, 600, 3000, 0.1) * 0.5
    seat = at(mix(kick(90, 50, 0.2, 0.03, 0.07), crack(0.08, 300, 1800, 0.03) * 0.6), 0.32)
    return mix(rumble, at(thud, 0.12), at(grit, 0.1), seat)


def barrier_hit(i):
    j = jit(i)
    return mix(kick(150 * j, 60, 0.18, 0.03, 0.06, 3.0), crack(0.07, 400, 2400, 0.02) * 0.7,
               S.chime(520 * j, 0.3, 0.09, ((1.0, 0.5), (2.3, 0.25))) * 0.3)


# ---------------------------------------------------------------- Hook: ratchet, whip, chain
def hook(i):
    j = jit(i)
    ratchet = S.rattle(0.16, 90, 1400, 3200, 0.3, 0.08) * 0.7
    whip = at(swish(0.18, 1500, 7000 * j, 0.7, 0.004) * 1.1, 0.12)
    crackle = at(crack(0.025, 3000, 9000, 0.006) * 1.2, 0.2)
    chain = at(S.rattle(0.35, 55, 2200, 6500, 0.5, 0.16) * 0.35, 0.2)
    return mix(ratchet, whip, crackle, chain)


def hook_catch(i):
    j = jit(i)
    clank = S.ring([420 * j, 1130 * j, 2050 * j], 0.35, [0.12, 0.08, 0.04], [1.0, 0.5, 0.3]) * 0.6
    thump = kick(130 * j, 55, 0.2, 0.03, 0.08, 2.5)
    return mix(clank, thump, crack(0.06, 800, 5000, 0.02) * 0.6, at(S.rattle(0.2, 60, 2200, 6000, 0.5, 0.1) * 0.3, 0.05))


def hook_bite(i):
    j = jit(i)
    return mix(crack(0.04, 1500, 8000, 0.01) * 1.1, S.ring([880 * j, 1900 * j, 3300 * j], 0.3, [0.1, 0.06, 0.03], [1.0, 0.6, 0.3]) * 0.5,
               kick(100 * j, 55, 0.15, 0.03, 0.05) * 0.8)


# ---------------------------------------------------------------- Rocket: ignition, a rising roar, thrust
def rocket(i):
    j = jit(i)
    boom = kick(95 * j, 38, 0.45, 0.07, 0.2, 3.0)
    roar = lpf(noise(0.7), 2200) * S.shape(0.7, 0.03, 0.15, 0.5)
    roar = bpf(roar, 150, 2200) * 2.0
    whine = S.sweep(260, 900 * j, 0.6, 'saw') * S.shape(0.6, 0.05, 0.1, 0.4) * 0.25
    pop = crack(0.04, 1200, 6000, 0.012) * 0.8
    return mix(boom, roar, whine, pop)


# ---------------------------------------------------------------- Mirror: glass, a bright ring
def mirror(i):
    j = jit(i)
    notes = [at(S.chime(f * j, 0.7, 0.3, ((1.0, 1.0), (2.76, 0.4), (5.4, 0.15))) * 0.7, 0.05 * k) for k, f in enumerate([880, 1320, 1760])]
    return mix(*notes, swish(0.25, 3000, 8000, 0.7, 0.02) * 0.4)


def mirror_hit(i):
    j = jit(i)
    return mix(S.chime(1480 * j, 0.5, 0.2, ((1.0, 1.0), (2.76, 0.5), (5.4, 0.25))), crack(0.03, 3000, 9000, 0.008) * 0.8,
               at(S.chime(2220 * j, 0.4, 0.15) * 0.4, 0.04))


# ---------------------------------------------------------------- Ice Bridge: frost creeping out
def ice(i):
    j = jit(i)
    grow = S.rattle(0.6, 70, 3500, 9000, 0.6, 0.35) * 0.5 * S.shape(0.6, 0.15, 0.2, 0.25)
    shimmer = [at(S.chime((1400 + 330 * k) * j, 0.5, 0.2) * 0.35, 0.06 * k) for k in range(5)]
    crunch = lpf(crack(0.35, 1200, 5000, 0.12), 6000) * 0.5
    return mix(grow, *shimmer, crunch)


# ---------------------------------------------------------------- Gust, Hover: air
def gust(i):
    j = jit(i)
    whoosh = swish(0.6, 400, 3200 * j, 0.9, 0.08) * 2.2
    body = lpf(noise(0.5), 500) * S.shape(0.5, 0.06, 0.1, 0.3) * 1.3
    return mix(whoosh, body, at(kick(120, 60, 0.15, 0.03, 0.05) * 0.4, 0.02))


def hover(i):
    j = jit(i)
    puff = swish(0.22, 700, 2600 * j, 0.8, 0.02) * 1.4
    spring = S.sweep(380, 760 * j, 0.15) * env(N(0.15), 0.004, 0.07) * 0.4
    return mix(puff, spring, at(S.chime(1500 * j, 0.25, 0.1) * 0.25, 0.1))


# ---------------------------------------------------------------- Ledge: a stone step set in the air
def ledge(i):
    j = jit(i)
    slab = mix(kick(140 * j, 60, 0.25, 0.04, 0.1, 2.5), crack(0.12, 300, 2200, 0.05) * 0.7)
    spark = [at(S.chime((1100 + 280 * k) * j, 0.4, 0.15) * 0.3, 0.05 * k) for k in range(3)]
    return mix(slab, lpf(noise(0.25), 400) * env(N(0.25), 0.02, 0.1) * 0.6, *spark)


# ---------------------------------------------------------------- Fissure: the ground tears open
def quake(i):
    j = jit(i)
    rumble = lpf(noise(0.9), 160) * S.shape(0.9, 0.05, 0.3, 0.5) * 3.0
    tear = S.creak(0.6, 110 * j, 55, 0.8, 1800) * 0.8
    cracks = S.rattle(0.7, 25, 400, 2200, 0.6, 0.35) * 0.6
    return mix(rumble, tear, cracks, kick(70, 35, 0.5, 0.08, 0.25, 3.0) * 0.9)


def quake_hit(i):
    j = jit(i)
    return mix(kick(115 * j, 45, 0.22, 0.03, 0.09, 3.0), crack(0.08, 200, 1800, 0.03) * 0.8,
               S.rattle(0.15, 60, 500, 2500, 0.5, 0.07) * 0.3)


# ---------------------------------------------------------------- Vortex: a throw, a suction, a collapse
def vortex(i):
    j = jit(i)
    spin = S.sweep(200, 650 * j, 0.4, 'saw') * S.shape(0.4, 0.05, 0.15, 0.2) * 0.3
    return mix(swish(0.35, 500, 2500, 0.8, 0.03) * 1.3, spin, at(S.chime(1000 * j, 0.3, 0.12) * 0.2, 0.2))


def vortex_pull(i):
    j = jit(i)
    inward = swish(0.45, 3600, 400 * j, 0.9, 0.04) * 1.8
    drone = S.sweep(500, 140, 0.45) * S.shape(0.45, 0.06, 0.1, 0.3) * 0.4
    return mix(inward, drone)


def vortex_blast(i):
    j = jit(i)
    thump = kick(105 * j, 38, 0.4, 0.06, 0.18, 3.5)
    burst = swish(0.3, 5000, 500, 1.0, 0.003) * 1.5
    return mix(thump, burst, crack(0.05, 800, 5000, 0.015) * 0.8)


# ---------------------------------------------------------------- Skyhook: a line fired up, a pull
def skyhook(i):
    j = jit(i)
    zing = S.sweep(500, 2400 * j, 0.14, curve=0.7) * env(N(0.14), 0.002, 0.07) * 0.6
    line = at(swish(0.3, 1200, 5000, 0.7, 0.01) * 1.1, 0.06)
    latch = at(mix(crack(0.03, 2000, 8000, 0.008), S.ring([700 * j, 1500 * j], 0.2, [0.08, 0.04], [1.0, 0.5]) * 0.5), 0.2)
    return mix(zing, line, latch)


# ---------------------------------------------------------------- Decoy: a puff of cloth and a ghost chime
def decoy(i):
    j = jit(i)
    puff = lpf(noise(0.3), 1400) * S.shape(0.3, 0.02, 0.05, 0.22) * 1.4
    ghost = [at(S.chime(f * j, 0.8, 0.35, ((1.0, 0.8), (2.0, 0.3))) * 0.3, 0.1 + 0.09 * k) for k, f in enumerate([740, 740, 740])]
    ghost = [g * (0.7 ** k) for k, g in enumerate(ghost)]
    return mix(puff, *ghost)


SOUNDS = [('gl_blink', blink, 'cast', 2), ('gl_blink_hit', blink_hit, 'impact', 2),
          ('gl_barrier', barrier, 'cast', 2), ('gl_barrier_hit', barrier_hit, 'impact', 2),
          ('gl_hook', hook, 'cast', 2), ('gl_hook_catch', hook_catch, 'impact', 2), ('gl_hook_bite', hook_bite, 'impact', 2),
          ('gl_rocket', rocket, 'cast', 2), ('gl_mirror', mirror, 'cast', 2), ('gl_mirror_hit', mirror_hit, 'impact', 2),
          ('gl_ice', ice, 'cast', 2), ('gl_gust', gust, 'cast', 2), ('gl_hover', hover, 'cast', 2),
          ('gl_ledge', ledge, 'cast', 2), ('gl_quake', quake, 'cast', 2), ('gl_quake_hit', quake_hit, 'impact', 2),
          ('gl_vortex', vortex, 'cast', 2), ('gl_vortex_pull', vortex_pull, 'cast', 2),
          ('gl_vortex_blast', vortex_blast, 'heavy_impact', 2), ('gl_skyhook', skyhook, 'cast', 2),
          ('gl_decoy', decoy, 'cast', 2)]


def main():
    for name, fn, cat, takes in SOUNDS:
        S.takes_cat(name, fn, takes, cat)


if __name__ == '__main__':
    main()
