"""Breakables and chests (docs/AUDIO.md, content/sfx/breakables.json): a smashed prop, a powder keg and a
chest lid opening.

    cd tools && python3 gen_sfx_breakables.py      (then: godot --headless --import)

  break_wood         a crate or barrel splintering: a hard crack, the box's hollow knock, planks clattering (3 takes)
  break_clay         a pot shattering: a bright smash, the pot's dull pok, shards tinkling away (3 takes)
  break_metal        a keg's iron hoops bursting off: a dull clang, a second hoop landing, staves rattling (3 takes)
  keg_fuse           a powder keg lit by a hit: a clink, the flame catching, a fizz climbing to the blast. Exactly
                     as long as the keg's fuse in content/rules/breakables.json, so the game plays it faster to end
                     on the blast of a shorter chain fuse
  keg_blast          the keg blowing: a sharp crack, a deep powder thump, a rolling rumble with debris (3 takes)
  chest_creak_plain  a chest lid opening, by the chest's tier (content/rules/keys.json chest.creak): worn wooden hinges
  chest_creak_rich   an iron-bound lid: a lower creak, a hinge whine, the fittings rattling as it lands
  chest_creak_grand  the heaviest lid: a long groan, a deep thud and a brass clank
Original synthesis, no samples.
"""
import json, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, bpf, env, mix, at, sat, kick, click, crack, sub, tail, reflections, ring, grains, shape

S.reseed(5523)

_RULES = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'content', 'rules', 'breakables.json')
FUSE = json.load(open(_RULES))['kinds']['keg']['explosive']['fuse']     # s: keg_fuse lasts exactly the keg's fuse


def knock(f, decay, bright, d=0.12):
    """One short knock of a hard body (a plank, a stave): a noise tick through its band plus its ringing tone at f Hz."""
    tick = bpf(noise(d), f * 1.5, bright) * env(N(d), 0.0004, decay * 0.4)
    tone = np.sin(2 * np.pi * f * T(d) + S.rng.uniform(0, 6.28)) * env(N(d), 0.0008, decay)
    return tick + 0.6 * tone


def tink(f, decay, d=0.06):
    """A ceramic shard landing: a click and two inharmonic partials."""
    t = T(d)
    tone = np.sin(2 * np.pi * f * t + S.rng.uniform(0, 6.28)) + 0.45 * np.sin(2 * np.pi * f * 1.53 * t + S.rng.uniform(0, 6.28))
    return mix(tone * env(N(d), 0.0003, decay), 0.5 * click(0.002, 3000, 10000))


def clatter(count, start, gap, gain, fade, f_lo, f_hi, bright):
    """Pieces landing one after another: `count` knocks from `start` s, `gap` s apart (jittered), each quieter."""
    out = []
    t0 = start
    for k in range(count):
        g = gain * fade ** k
        out.append(at(knock(S.rng.uniform(f_lo, f_hi), S.rng.uniform(0.018, 0.032), bright), t0) * g)
        t0 += S.rng.uniform(gap * 0.6, gap * 1.4)
    return out


# ------------------------------------------------------------------ the one-hit props, one sound per material
def wood(i):
    hit = mix(crack(0.09, 700, 5200, 0.011) * 1.4, 0.8 * click(0.004, 2500, 9000))
    box = kick(150 + 14 * i, 70, 0.3, drop=0.018, decay=0.05, drive=1.5) * 0.9
    boards = bpf(noise(0.2), 220, 900) * env(N(0.2), 0.0006, 0.035) * 0.8
    splinter = grains(0.3, 260, 1600, 6500, 0.0008, 0.0035, fall=0.05) * 0.5
    planks = clatter(5, 0.05 + 0.02 * S.rng.random(), 0.075, 0.75, 0.72, 260, 520, 3200)
    dust = tail(0.45, 1500, 0.09, delay=0.02) * 0.12
    return mix(hit, box, boards, splinter, *planks, dust)


def clay(i):
    f = 410 + 30 * i
    smash = mix(crack(0.07, 1400, 9500, 0.008) * 1.5, click(0.003, 3000, 10000))
    t = T(0.12)
    pok = np.sin(2 * np.pi * f * t) * env(N(0.12), 0.0005, 0.022) + 0.4 * np.sin(2 * np.pi * f * 2.31 * t) * env(N(0.12), 0.0005, 0.012)
    thud = kick(210, 120, 0.12, drop=0.012, decay=0.028, drive=1.4) * 0.5
    shards = []
    for _ in range(11):
        t0 = 0.025 + S.rng.exponential(0.09)
        if t0 < 0.55:
            shards.append(at(tink(S.rng.uniform(2300, 5200), S.rng.uniform(0.006, 0.02)), t0) * S.rng.uniform(0.25, 0.6) * np.exp(-t0 / 0.25))
    grit = grains(0.35, 380, 3500, 9500, 0.0006, 0.0025, fall=0.07) * 0.35
    return mix(smash, pok * 0.9, thud, *shards, grit)


def metal(i):
    f0 = 235 + 18 * i
    burst = lpf(noise(0.15), 5000) * env(N(0.15), 0.0006, 0.035)
    clang = lpf(ring([f0, f0 * 2.32, f0 * 4.25, f0 * 6.63], 0.6, [0.14, 0.12, 0.08, 0.05], [0.6, 0.7, 0.5, 0.3]), 6000) * 0.55
    f1 = f0 * 1.37
    hoop = at(ring([f1, f1 * 2.41, f1 * 4.4], 0.35, [0.12, 0.06, 0.035], [0.7, 0.35, 0.15]), 0.13 + 0.03 * S.rng.random()) * 0.45
    staves = clatter(4, 0.07 + 0.02 * S.rng.random(), 0.08, 0.6, 0.7, 230, 420, 2600)
    rattle = at(S.rattle(0.25, 34, 2000, 6500, 0.4, decay=0.07), 0.06) * 0.45
    return mix(burst, clang, hoop, *staves, rattle)


# ------------------------------------------------------------------ the powder keg
def fuse():
    d = FUSE
    n = N(d); u = T(d) / d
    clink = mix(ring([1720, 2830, 4310], 0.09, [0.025, 0.014, 0.008], [1.0, 0.55, 0.3]), 0.6 * click(0.003, 2500, 9000))
    catch = bpf(noise(0.07), 900, 5200) * shape(0.07, 0.008, 0.01, 0.05) * 0.7
    src = noise(d)
    fizz = bpf(src, 1100, 3200) * (1.0 - u) + bpf(src, 2000, 6000) * u          # the band climbs toward the blast
    flick = lpf(S.rng.standard_normal(n), 35)
    flick = 0.75 + 0.25 * flick / (np.max(np.abs(flick)) or 1.0)
    swell = (0.45 + 0.55 * u ** 1.3) * np.clip((T(d) - 0.012) / 0.03, 0.0, 1.0)
    sparks = bpf((S.rng.random(n) > 0.999 - 0.002 * u) * S.rng.standard_normal(n) * 5.0, 1500, 6000)
    out = mix(clink * 0.8, at(catch, 0.006), fizz * swell * flick * 0.55, sparks * 0.5)
    return S.pad(out, d)[:n]


def blast(i):
    snap = mix(crack(0.06, 900, 8000, 0.007) * 1.6, click(0.004, 2000, 10000))
    powder = crack(0.25, 700, 6000, 0.05) * 1.4                                       # the powder going up
    sparks = grains(0.5, 160, 1500, 6000, 0.001, 0.004, fall=0.12) * 0.6
    punch = kick(118 - 6 * i, 40, 0.6, drop=0.03, decay=0.1, drive=2.0) * 0.7
    low = sub(70, 30, 1.2, 0.4) * 0.4
    roar = lpf(noise(1.0), 3800) * env(N(1.0), 0.003, 0.11) * 1.6
    rumble = lpf(noise(1.5), 600) * env(N(1.5), 0.02, 0.42)
    whoomp = at(bpf(noise(0.5), 160, 1100) * shape(0.5, 0.03, 0.04, 0.4), 0.01)          # the powder catching at once
    debris = [lpf(x, 3500) for x in clatter(6, 0.18 + 0.04 * S.rng.random(), 0.12, 0.35, 0.75, 200, 450, 2600)]
    return sat(reflections(mix(snap, powder, sparks, punch, low, roar, rumble, whoomp, *debris)), 1.3)


# ------------------------------------------------------------------ chest lids, by tier
def creak_plain():
    latch = 0.6 * click(0.003, 1800, 7000)
    land = knock(240, 0.03, 2200) + kick(170, 90, 0.12, drop=0.01, decay=0.03, drive=1.3) * 0.6
    return mix(latch, at(S.creak(0.3, 260, 170, 0.5, 3000), 0.01) * 3.5, at(land, 0.29) * 0.25)


def creak_rich():
    latch = mix(0.7 * click(0.003, 1800, 7000), at(ring([2100, 3350], 0.05, [0.012, 0.008], [0.5, 0.3]), 0.002))
    whine = S.sweep(760, 560, 0.3) * shape(0.3, 0.06, 0.12, 0.12) * 0.25                 # the iron hinge singing
    land = mix(knock(200, 0.035, 2000), kick(150, 80, 0.16, drop=0.012, decay=0.04, drive=1.5) * 0.8)
    fittings = S.rattle(0.12, 55, 1600, 4800, 0.5, decay=0.04) * 0.3
    return mix(latch, at(S.creak(0.36, 190, 120, 0.65, 3000), 0.01) * 3.0, at(whine, 0.02), at(land, 0.33) * 0.3, at(fittings, 0.335))


def creak_grand():
    latch = mix(kick(300, 160, 0.06, drop=0.005, decay=0.015, drive=1.4) * 0.5, 0.6 * click(0.003, 1500, 6000))
    groan = lpf(S.sweep(330, 240, 0.36, 'saw'), 1100) * shape(0.36, 0.08, 0.13, 0.15) * 0.2
    land = mix(kick(125, 52, 0.3, drop=0.02, decay=0.08, drive=1.8), sub(80, 45, 0.3, 0.1) * 0.6, knock(170, 0.04, 1800))
    brass = ring([540, 1290, 2370, 3600], 0.5, [0.16, 0.09, 0.05, 0.03], [0.6, 0.35, 0.2, 0.1]) * 0.35
    return mix(latch, at(S.creak(0.4, 140, 85, 0.8, 2600), 0.012) * 3.2, at(groan, 0.02), at(land, 0.36) * 0.35, at(brass, 0.365))


def build():
    S.takes_cat('break_wood', wood, 2, 'impact')
    S.takes_cat('break_clay', clay, 2, 'impact')
    S.takes_cat('break_metal', metal, 2, 'impact')
    S.save_cat('keg_fuse', fuse(), 'cast')
    S.takes_cat('keg_blast', blast, 2, 'heavy_impact')
    S.save_cat('chest_creak_plain', creak_plain(), 'cast')
    S.save_cat('chest_creak_rich', creak_rich(), 'cast')
    S.save_cat('chest_creak_grand', creak_grand(), 'cast')


if __name__ == '__main__':
    build()
    print('gen_sfx_breakables: done')
