"""Mob and boss attack sounds (docs/AUDIO.md): a cue when each mob kind strikes and one when it lands, and a
wind-up tell for each boss, so a lair fight can be dodged by ear.

    cd tools && python3 gen_sfx_mob.py      (then: godot --headless --import)

mob_<kind>_atk is the strike (a lunge, a spit, a slam, a blast, a volley); mob_<kind>_hit plays on whoever it
lands on. boss_<kind>_tell swells with the telegraph and peaks as the hit comes; boss_slam, boss_throw,
boss_boulder, boss_spit and boss_glob are the release and the landing. Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, sub, tail, shape, soft_in

S.reseed(6417)


def rise(d, k=2.0):
    """A swell that peaks at the end, so a tell is loudest as the strike lands."""
    return (np.arange(N(d)) / N(d)) ** k


def whoosh(d, f0, f1, q=2.0):
    """Air through a sweeping band: a lunge, a throw."""
    n = N(d); x = noise(d); out = np.zeros(n); k = 6
    for i in range(k):
        a, b = i * n // k, (i + 1) * n // k
        fc = f0 * (f1 / f0) ** ((i + 0.5) / k)
        out[a:b] = bpf(x, fc / q, fc * q)[a:b]
    return out * shape(d, d * 0.3, 0.0, d * 0.6)


def splat(d, lo, hi, thump):
    """Something wet landing: a soft slap, a bubbling tail."""
    body = bpf(noise(d), lo, hi) * env(N(d), 0.002, d * 0.22)
    pop = S.sweep(thump * 1.6, thump * 0.6, d) * env(N(d), 0.002, d * 0.18)
    return mix(body, 0.7 * pop, 0.35 * S.grains(d, 90, 900, 3500, fall=d * 0.4))


def stone(d, f0, f1, crack_lo, crack_hi, rumble=0.9):
    """A heavy stone strike: a sub drop, a crack and falling grit."""
    return mix(rumble * sub(f0, f1, d, d * 0.3), crack(d, crack_lo, crack_hi, 0.05) * 0.8, 0.5 * tail(d, 1800, d * 0.25, delay=0.03), 0.4 * S.grains(d, 60, 800, 3000, fall=d * 0.3))


def save(name, x, cat):
    S.save_cat(name, soft_in(x), cat)


# ---- mob strikes (cat fire) and landings (cat impact)
d = 0.28
save('mob_skitter_atk', mix(whoosh(d, 700, 2600), 0.5 * S.rattle(d, rate=70, lo=2500, hi=6500, decay=0.12)), 'fire')
d = 0.18
save('mob_skitter_hit', mix(click(), 0.9 * crack(d, 1500, 5500, 0.03), 0.6 * kick(300, 140, d, decay=0.05)), 'impact')

d = 0.34
save('mob_spitter_atk', mix(splat(d, 500, 2600, 260), 0.5 * S.fm(520, 1.5, 3.0, d, decay=0.12)), 'fire')
d = 0.3
save('mob_spitter_hit', splat(d, 350, 1800, 170), 'impact')

d = 0.6
save('mob_brute_atk', mix(0.5 * whoosh(0.3, 200, 600), at(stone(d - 0.12, 95, 42, 400, 2200), 0.12)), 'fire')
d = 0.4
save('mob_brute_hit', mix(kick(160, 50, d, decay=0.14), 0.6 * crack(d, 200, 1400, 0.05)), 'impact')

d = 0.55
save('mob_bomber_atk', mix(kick(150, 38, d, decay=0.2), 1.1 * crack(d, 300, 3200, 0.08), 0.6 * tail(d, 2400, 0.2), 0.5 * S.grains(d, 60, 1200, 5000, fall=0.18)), 'fire')
d = 0.3
save('mob_bomber_hit', mix(crack(d, 800, 4200, 0.05), 0.6 * kick(220, 80, d, decay=0.1), 0.4 * S.hiss(d, 3000, 8000, decay=0.12)), 'impact')

d = 0.32
save('mob_sentinel_atk', mix(*[0.5 * at(S.fm(1400 - 120 * i, 2.01, 2.5, 0.2, decay=0.06), 0.045 * i) for i in range(3)], 0.6 * click()), 'fire')
d = 0.26
save('mob_sentinel_hit', mix(S.fm(2100, 1.5, 3.0, d, decay=0.07), 0.6 * crack(d, 2500, 8000, 0.015)), 'impact')

d = 0.8
save('mob_warden_atk', mix(0.5 * whoosh(0.35, 150, 500), at(stone(d - 0.15, 75, 30, 300, 1800, 1.1), 0.15)), 'fire')
d = 0.5
save('mob_warden_hit', mix(kick(130, 38, d, decay=0.2), 0.7 * crack(d, 150, 1000, 0.06), 0.4 * S.ring([110, 163], d, [0.25, 0.2], [1.0, 0.6])), 'impact')


# ---- boss tells (cat cast): each swells to its peak as the strike lands
d = 1.0
g = S.creak(d, 45, 90, 0.7, 1200) * rise(d, 1.5)
save('boss_colossus_tell', mix(g, 0.8 * sub(40, 70, d, d * 2) * rise(d, 2), 0.35 * S.rattle(d, rate=30, lo=300, hi=1500) * rise(d, 2.5)), 'cast')
d = 1.0
whine = lpf(S.sweep(260, 1900, d, 'saw', 1.4), 5000) * rise(d, 1.6)
buzz = 0.4 * S.fm(1200, 1.01, 6.0, d, decay=2.0) * rise(d, 2.2)
save('boss_serpent_tell', mix(whine * 0.7, buzz, 0.25 * hpf(noise(d), 4000) * (np.random.default_rng(3).random(N(d)) > 0.7) * rise(d, 3)), 'cast')
d = 1.0
gurgle = S.voice(d, 70, 130, 'uh', breath=0.5, rasp=0.9, vib=0.04, scale=0.8) * rise(d, 1.3)
save('boss_brood_tell', mix(gurgle, 0.5 * S.grains(d, 140, 400, 2500, fall=d * 0.9) * rise(d, 1.2), 0.3 * bpf(noise(d), 300, 1400) * rise(d, 2)), 'cast')

# ---- boss releases and landings
d = 0.9
save('boss_slam', stone(d, 70, 28, 250, 1800, 1.2), 'heavy_impact')
d = 0.4
save('boss_throw', whoosh(d, 250, 900, 1.6) * 1.0, 'fire')
d = 0.8
save('boss_boulder', mix(stone(d, 85, 34, 300, 2600, 1.0), 0.3 * S.grains(d, 100, 600, 2200, fall=0.35)), 'heavy_impact')
d = 0.4
save('boss_spit', mix(splat(d, 400, 2000, 150), 0.6 * S.hiss(d, 1500, 5000, decay=0.2)), 'fire')
d = 0.5
save('boss_glob', mix(splat(d, 250, 1500, 110), 0.5 * kick(130, 50, d, decay=0.12)), 'impact')
# ---- the Blight: ash and embers, lower and drier than their island cousins
d = 0.3
save('mob_bl_skitter_atk', mix(whoosh(d, 400, 1500), 0.6 * S.grains(d, 120, 600, 2600, fall=0.15)), 'fire')
d = 0.2
save('mob_bl_skitter_hit', mix(click(), 0.8 * crack(d, 700, 3000, 0.03), 0.5 * kick(220, 90, d, decay=0.06)), 'impact')
d = 0.45
save('mob_bl_warden_atk', mix(0.7 * S.hiss(d, 900, 4000, decay=0.25), 0.6 * sub(110, 55, d, 0.2), 0.3 * S.grains(d, 80, 1500, 5000, fall=0.3)), 'fire')
d = 0.4
save('mob_bl_warden_hit', mix(crack(d, 600, 3500, 0.04), 0.6 * S.hiss(d, 2000, 7000, decay=0.18), 0.4 * kick(180, 60, d, decay=0.1)), 'impact')
d = 1.2
save('mob_bl_shriek', mix(lpf(S.sweep(900, 2600, d, 'saw', 1.2), 6000) * shape(d, 0.05, 0.0, 0.9), 0.5 * bpf(noise(d), 1500, 5000) * env(N(d), 0.01, 0.6)), 'cast')

print('wrote the mob and boss attack sounds')
