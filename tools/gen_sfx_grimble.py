"""Grimble's sounds (id dredge, the Scrap King): a skinny, wiry, greedy junk-hoarder monster with a towering
hoard on his back, a gaff hook on a chain (the Abyssal Hand), a scrap fist and a junk blunderbuss.

    cd tools && python3 gen_sfx_grimble.py      (then: godot --headless --import)

Signatures: the coin jingle (dredge_coin_jingle: Salvage stacks and a hauled foe; dredge_pickup when he
pockets loot) and the junk clatter (dredge_junk_clatter: his hoard rattling on every barge). His voice is
wheezy and creaturely: a thin rasping throat, more breath than tone. Metal here is built from small
inharmonic rings (coins, bells, tin) and FM clanks (iron), wood from short knocks. The kit's older dr_*
files are rebuilt under their own names (content/sfx/dredge.json "replaces"). Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, sub, grains, shape, soft_in

S.reseed(7351)


# ------------------------------------------------------------------ building blocks
def slow(d, rate, depth):
    """A smooth random wobble around 1: `rate` new values a second."""
    pts = max(4, int(d * rate) + 3)
    v = S.rng.standard_normal(pts)
    x = np.interp(np.arange(N(d)) / S.SR * rate, np.arange(pts), v)
    return np.clip(1.0 + depth * lpf(x, 40) / (np.std(x) + 1e-9), 0.05, None)


def sweep_noise(d, f0, f1, width=0.35):
    """Noise whose band glides f0 -> f1 (air rushing past)."""
    n = N(d); u = np.arange(n) / max(1, n - 1)
    lf = np.log(f0) + (np.log(f1) - np.log(f0)) * u
    out = np.zeros(n); src = noise(d)
    for fc in np.geomspace(120, 7000, 16):
        g = np.exp(-((np.log(fc) - lf) / width) ** 2)
        if g.max() < 0.02:
            continue
        out += bpf(src, fc * 0.8, fc * 1.25) * g
    return out


def bell(f, d, decay, partials=((1.0, 1.0), (2.76, 0.45), (5.4, 0.22))):
    """A small ring (a coin, a hoard bell) with a 1.5 ms attack and a tail faded to silence, so a pile of
    them never ticks on a random phase or cuts off mid-ring."""
    t = T(d); out = np.zeros(N(d))
    for k, g in partials:
        out += g * np.sin(2 * np.pi * f * k * t + S.rng.uniform(0, 6.28)) * np.exp(-t / (decay / k ** 0.5))
    return out * shape(d, 0.0015, d * 0.5, d * 0.5 - 0.0015)


def coin(f=None):
    """One coin landing: a tick and a short bright inharmonic ring (kept mostly under 6 kHz)."""
    f = f or S.rng.uniform(1500, 2800)
    ring = bell(f, 0.3, S.rng.uniform(0.05, 0.11), ((1.0, 1.0), (1.47, 0.55), (2.09, 0.3), (2.56, 0.12)))
    return mix(click(0.002, 2500, 6000) * 0.35, ring)


def coins(d, count, fall=0.18, gain=1.0):
    """A handful of coins: hits bunched at the start and thinning out (a jingle, a spill)."""
    out = np.zeros(N(d))
    for _ in range(count):
        t0 = min(S.rng.exponential(fall), d - 0.25)
        out = mix(out, at(coin() * S.rng.uniform(0.35, 1.0), max(0.0, t0)))
    return out * gain


def clank(f, decay=0.12, index=2.5):
    """A piece of iron or tin struck: FM with a non-integer ratio, and a thud under it."""
    ratio = S.rng.uniform(1.31, 2.73)
    return mix(S.fm(f, ratio, index, decay * 4, decay), kick(f * 0.9, f * 0.5, 0.08, 0.005, 0.015, 1.4) * 0.25)


def knock(f):
    """A wooden crate or barrel knocked."""
    return mix(kick(f * 1.6, f, 0.12, 0.006, 0.025, 1.6) * 0.6, bpf(noise(0.06), f * 2, f * 6) * env(N(0.06), 0.001, 0.012) * 0.6)


def clatter(d, count, fall=0.15, low=1.0):
    """Junk shifting in a hoard: iron clanks, tin, crate knocks, a little bell, a couple of coins."""
    out = np.zeros(N(d))
    for _ in range(count):
        t0 = max(0.0, min(S.rng.exponential(fall), d - 0.3))
        kind = S.rng.integers(0, 5)
        if kind == 0:
            x = clank(S.rng.uniform(260, 700) * low, S.rng.uniform(0.06, 0.14))
        elif kind == 1:
            x = clank(S.rng.uniform(700, 1500), S.rng.uniform(0.03, 0.07), 1.5) * 0.6
        elif kind == 2:
            x = knock(S.rng.uniform(140, 320) * low)
        elif kind == 3:
            x = bell(S.rng.uniform(900, 1400), 0.4, 0.12) * 0.35
        else:
            x = coin() * 0.5
        out = mix(out, at(x * S.rng.uniform(0.45, 1.0), t0))
    return out


def chain(d, rate=90, decay=None):
    """Chain links paying out or snapping taut."""
    return S.rattle(d, rate, 1300, 4200, 0.5, decay) * 1.2


def wheeze(d, f_lo=900, f_hi=2600, a=0.05):
    """A thin wheezing breath (a creature's narrow throat)."""
    return bpf(noise(d), f_lo, f_hi) * slow(d, 30, 0.5) * shape(d, a, d * 0.4, d * 0.5) * 0.6


def gvoice(d, f0, f1, vowel='eh', rasp=0.7, breath=0.65, scale=1.06, a=0.012):
    """Grimble's voice: a thin, rasping, breathy throat (its tail eased to silence, never cut off)."""
    return S.voice(d, f0, f1, vowel, breath=breath, rasp=rasp, vib=0.01, scale=scale, a=a) * shape(d, 0.0, d * 0.55, d * 0.45)


# ------------------------------------------------------------------ LMB: the scattergun
def shot(i):
    """The junk blunderbuss: a fat boom, a tinny tube ring and scrap rattling out with the slugs."""
    d = 0.75
    boom = mix(click(0.004, 2200, 7000) * 1.3, kick(190 + 10 * i, 58, d, 0.016, 0.06, 2.8) * 0.75,
               crack(d, 250, 3200 + 150 * i, 0.03) * 2.2, sub(70, 40, d, 0.09) * 0.4)
    tube = S.ring((410 + 15 * i, 1120 + 30 * i, 1730), 0.4, (0.09, 0.06, 0.04), (0.18, 0.1, 0.05))
    scrap = S.rattle(0.18, 160, 1500, 4500, 0.6, 0.05) * 0.5
    tail = S.reflections(S.tail(0.5, 1500, 0.1) * 0.9)
    return mix(boom, tube, at(scrap, 0.01), tail)


# ------------------------------------------------------------------ RMB: Abyssal Hand
# Timed to the kit (content/archetypes/dredge.json rmb, DredgeKit.HAUL_T): a WIND_T wind-back, the hook out in
# about FLY_T, slowing as the arm runs out; hand-over-hand hauls every HAUL_T from HAUL_AT after the catch.
WIND_T = 0.1
FLY_T = 0.4
HAUL_T = 0.26
HAUL_AT = 0.18


class own_stream:
    """Runs a sound on its own seeded random stream and gives the shared one back untouched, so reworking it
    never re-rolls the rest of his set."""
    def __init__(self, seed): self.seed = seed
    def __enter__(self):
        self.keep = (S.rng, S.C.rng)
        S.rng = S.C.rng = np.random.default_rng(self.seed)
    def __exit__(self, *_):
        S.rng, S.C.rng = self.keep


def payout(d, gap0, gap1, f_lo=1100, f_hi=4200):
    """The arm's links running out: clicks whose spacing widens gap0 -> gap1 (fast, then slowing)."""
    out = np.zeros(N(d)); t = 0.0
    while t < d - 0.03:
        u = t / d
        link = mix(click(0.002, f_lo, f_hi) * 0.8, clank(S.rng.uniform(1400, 2200), 0.012, 1.0) * 0.25)
        out = mix(out, at(link * (1.0 - 0.6 * u) * S.rng.uniform(0.6, 1.0), t))
        t += gap0 + (gap1 - gap0) * u * u
    return out


def throw():
    """The arm cocks back (a flesh-and-chain creak, a sucked breath), then whips: a sharp crack and a fast
    falling whoosh, the links rattling out and slowing as the arm runs out, the abyss moaning under it."""
    with own_stream(7361):
        d = WIND_T + FLY_T + 0.25
        coil = S.creak(0.16, 120, 85, 0.7, 1500) * shape(0.16, 0.02, 0.06, 0.08) * 0.7
        breath = bpf(noise(0.12), 600, 1800) * shape(0.12, 0.05, 0.02, 0.05) * 0.35
        snap = mix(click(0.003, 1800, 6000) * 1.1, crack(0.06, 900, 4000, 0.012) * 0.9)
        whoosh = sweep_noise(0.34, 3000, 420, 0.38) * shape(0.34, 0.006, 0.03, 0.3) * 1.5
        links = payout(FLY_T, 0.016, 0.07)
        thump = kick(150, 70, 0.22, 0.015, 0.04, 1.6) * 0.45
        moan = lpf(S.sweep(90, 62, d - WIND_T, 'saw'), 420) * shape(d - WIND_T, 0.03, 0.2, 0.3) * 0.22
        return mix(coil, breath, at(mix(snap, whoosh, thump, moan), WIND_T), at(links, WIND_T + 0.02))


def grab():
    """The hook bites: a heavy iron clank on a deep thud, a wet crunch, and the arm snapping taut."""
    with own_stream(7362):
        d = 0.7
        hit = mix(click(0.003, 2000, 6500) * 1.2, kick(180, 52, 0.5, 0.01, 0.07, 3.0) * 0.85,
                  crack(0.25, 300, 2600, 0.025) * 1.6, sub(62, 36, 0.55, 0.11) * 0.55)
        iron = mix(clank(240, 0.2, 3.4) * 0.75, clank(510, 0.1, 2.2) * 0.4)
        crunch = lpf(noise(0.12), 900) * env(N(0.12), 0.001, 0.03) * 0.6
        taut = at(mix(chain(0.14, 240, 0.035), click(0.002, 3000, 7000) * 0.6), 0.03)
        return mix(hit, iron, crunch, taut)


def reel():
    """The yank: a jolt and a taut groan, then a hand-over-hand haul every HAUL_T (a chain drag, the arm's
    creak and a low knock each), the links ratcheting in between."""
    with own_stream(7363):
        d = 1.2
        jolt = mix(kick(130, 55, 0.3, 0.01, 0.06, 2.2) * 0.6, chain(0.12, 200, 0.04) * 0.8)
        out = mix(np.zeros(N(d)), jolt)
        t = HAUL_AT
        while t < d - 0.2:
            drag = chain(0.18, 140, 0.07) * shape(0.18, 0.01, 0.03, 0.14) * 0.7
            heave = S.creak(0.2, 95, 70, 0.6, 1400) * shape(0.2, 0.02, 0.05, 0.13) * 0.55
            haul = mix(drag, heave, knock(S.rng.uniform(110, 150)) * 0.45)
            out = mix(out, at(haul, t))
            t += HAUL_T
        links = payout(d - 0.1, 0.05, 0.035, 900, 3200) * 0.35
        return mix(out, at(links, 0.06))


# ------------------------------------------------------------------ E: Anchor Drop (the scrap fist)
def anchor_wind():
    """The scrap fist hauled up: grinding scrap, the hoard shifting, a low rising swell."""
    d = 0.7
    grind = S.creak(d, 60, 120, 0.8, 2200) * 0.9
    swell = sweep_noise(d, 160, 700, 0.45) * shape(d, 0.3, 0.25, 0.15) * 0.7
    shift = clatter(d, 6, 0.25) * 0.45
    return mix(grind, swell, shift)


def anchor():
    """The fist slams down: a heavy thud and crunch, an iron clang, and junk raining off his back."""
    d = 1.2
    slam = mix(click(0.005, 1500, 5500) * 1.2, kick(115, 34, d, 0.035, 0.15, 3.2) * 0.9, sub(60, 30, d, 0.2) * 0.5,
               crack(0.5, 150, 2000, 0.05) * 2.0)
    crunch = grains(0.35, 220, 500, 3500, 0.002, 0.008, fall=0.08) * 1.0
    clang = clank(190, 0.25, 3.5) * 0.55
    junk = at(clatter(0.8, 10, 0.18), 0.05) * 0.6
    return mix(slam, crunch, clang, junk)


def dive():
    """The air smash: dropping like a sack of scrap, the wind rushing up past the hoard."""
    d = 0.65
    fall = sweep_noise(d, 1600, 380, 0.4) * shape(d, 0.06, 0.3, 0.28) * 1.0
    rattle = clatter(d, 7, 0.3) * 0.4
    return mix(fall, rattle, at(gvoice(0.22, 210, 260, 'ah', 0.8, 0.6) * 0.35, 0.02))


def quake():
    """The air smash lands: the ground caves, iron rings, the hoard crashes and debris rains."""
    d = 1.4
    slam = mix(click(0.006, 1400, 5000) * 1.3, kick(95, 28, d, 0.045, 0.2, 3.5) * 0.95, sub(55, 26, d, 0.3) * 0.6,
               crack(0.6, 120, 1800, 0.07) * 2.2)
    debris = grains(1.0, 120, 400, 3200, 0.003, 0.01, fall=0.25) * 0.9
    clang = clank(150, 0.3, 4.0) * 0.5
    junk = at(clatter(1.1, 14, 0.25, 0.85), 0.04) * 0.55
    return mix(slam, debris, clang, junk)


# ------------------------------------------------------------------ Shift: Barge
def scrabble(d, n_claws=4):
    """Claws raking the ground in quick strokes."""
    out = np.zeros(N(d))
    for k in range(n_claws):
        g = S.rng.uniform(0.03, 0.06)
        x = bpf(noise(g), 900, 3600) * shape(g, 0.004, g * 0.3, g * 0.6) * S.rng.uniform(0.5, 1.0)
        out = mix(out, at(x, k * d / (n_claws + 0.5) + S.rng.uniform(0, 0.015)))
    return out


def barge():
    """A low monster lunge: claws raking, the body heaving forward."""
    d = 0.5
    heave = sweep_noise(0.4, 300, 1500, 0.4) * shape(0.4, 0.03, 0.08, 0.28) * 0.9
    body = kick(130, 60, 0.3, 0.03, 0.06, 1.8) * 0.4
    return mix(heave, body, scrabble(0.35, 4) * 0.9, at(gvoice(0.14, 190, 160, 'uh', 0.8, 0.7) * 0.3, 0.01))


def junk_clatter(i):
    """His hoard rattling as he throws himself about."""
    return mix(clatter(0.75, 9 + i, 0.12), chain(0.3, 50, 0.08) * 0.3)


def hop():
    """The pounce: a spring off the claws, the wind and the hoard bouncing."""
    d = 0.45
    spring = mix(scrabble(0.12, 2) * 0.8, kick(150, 70, 0.25, 0.02, 0.05, 1.6) * 0.4)
    air = sweep_noise(0.35, 500, 1800, 0.4) * shape(0.35, 0.03, 0.05, 0.25) * 0.8
    return mix(spring, at(air, 0.03), at(clatter(0.4, 4, 0.1) * 0.35, 0.05))


def dash(i):
    """The shared dash, Grimble's way: a skittering scramble and a jangle off the hoard."""
    d = 0.4
    air = sweep_noise(0.32, 450 + 30 * i, 1700, 0.4) * shape(0.32, 0.03, 0.05, 0.22) * 0.8
    return mix(air, scrabble(0.28, 3) * 0.7, at(clatter(0.35, 3, 0.08) * 0.35, 0.03))


# ------------------------------------------------------------------ X: Brass Broadside
def blast_charge():
    """Loading the broadside: junk crammed down the barrel, a crank ratcheting, a whine and rumble rising."""
    d = 1.2
    cram = clatter(0.5, 8, 0.12) * 0.6
    out = np.zeros(N(d)); t = 0.25; gap = 0.09
    while t < d - 0.12:
        out = mix(out, at(mix(click(0.002, 1400, 4200) * 0.6, clank(S.rng.uniform(700, 900), 0.02, 1.2) * 0.3), t))
        t += gap; gap = max(0.035, gap * 0.9)
    whine = lpf(S.sweep(160, 620, d, 'saw', 0.7), 1400) * shape(d, 0.4, 0.6, 0.2) * 0.25
    rumble = lpf(noise(d), 160) * shape(d, 0.6, 0.4, 0.2) * 1.4
    return mix(cram, out, whine, rumble)


def blast():
    """A broadside wave: a huge blunderbuss boom and a spray of scrap shrapnel."""
    d = 1.3
    boom = mix(click(0.006, 1800, 6500) * 1.4, kick(150, 36, d, 0.03, 0.14, 3.4) * 0.9, sub(58, 28, d, 0.25) * 0.55,
               crack(d, 200, 3500, 0.06) * 2.6)
    spray = S.rattle(0.5, 140, 1200, 4500, 0.6, 0.12) * 0.6
    junk = clatter(0.9, 8, 0.2) * 0.3
    tail = S.reflections(S.tail(1.0, 1300, 0.2) * 1.2, ((0.07, 0.35, 1300), (0.15, 0.25, 900), (0.26, 0.15, 700)))
    return mix(boom, at(spray, 0.02), at(junk, 0.08), tail)


# ------------------------------------------------------------------ coins: Salvage and loot
def coin_jingle(i):
    """A fistful of coins shaken: Salvage stacking up, a foe hauled in."""
    pouch = lpf(noise(0.15), 900) * env(N(0.15), 0.004, 0.04) * 0.5
    return mix(pouch, coins(0.7, 12 + 2 * i, 0.09))


def pickup(i):
    """Loot pocketed into the hoard: coins pouring in, a clunk of junk and a greedy wheezy chuckle."""
    stuff = mix(knock(220 + 20 * i) * 0.6, clank(520 + 40 * i, 0.08, 2.0) * 0.4)
    pour = coins(0.7, 10 + i, 0.12) * 0.8
    chuckle = np.zeros(1)
    for k in range(2):
        chuckle = mix(chuckle, at(gvoice(0.09, 260 - 15 * k, 220, 'eh', 0.6, 0.8, 1.08, 0.006) * 0.45, 0.11 * k))
    return mix(stuff, at(pour, 0.04), at(chuckle, 0.28))


# ------------------------------------------------------------------ footsteps
def step(surface, i):
    """Skittery: two quick claw clicks and a light pad, a jangle off the hoard now and then."""
    d = 0.22
    pad = kick(170 + 10 * i, 95, d, 0.006, 0.015, 1.4) * 0.35
    claws = mix(click(0.002, 1800, 5000) * 0.55, at(click(0.002, 2000, 5500) * 0.4, 0.028 + 0.006 * i))
    if surface == 'grass':
        tex = bpf(noise(0.09), 700, 3200) * env(N(0.09), 0.003, 0.025) * 0.6
        claws *= 0.5
    elif surface == 'stone':
        tex = crack(d, 1200, 4200, 0.008) * 0.6
    elif surface == 'wood':
        tex = S.ring((260 + 10 * i, 590), d, (0.04, 0.025), (0.4, 0.2))
    else:
        tex = grains(0.09, 500, 600, 2400, 0.002, 0.005, fall=0.04) * 0.7
        claws *= 0.4
    jangle = at(clatter(0.25, 2, 0.03) * 0.25, 0.03) if i in (1, 3) else np.zeros(1)
    return soft_in(mix(pad, claws, tex, jangle))


# ------------------------------------------------------------------ voice: wheezy, rasping, creaturely
def hurt(i):
    v = ('eh', 'ah', 'uh', 'eh')[i]
    f0 = (205, 225, 190, 240)[i]
    yelp = gvoice(0.17 + 0.02 * (i % 2), f0, f0 * 0.8, v, 0.75)
    return mix(yelp, at(wheeze(0.22, 1000, 2800) * 0.45, 0.17))


def down():
    """Knocked flat: a long wheezing groan and coins spilling out of the hoard."""
    groan = gvoice(0.8, 200, 120, 'uh', 0.85, 0.7, 1.04, 0.03)
    return mix(groan, at(wheeze(0.45, 800, 2400), 0.75), at(coins(0.8, 9, 0.2) * 0.45, 0.2))


def death():
    """The end: a rattling cry trailing into a wheeze, and the whole hoard crashing down."""
    cry = gvoice(1.0, 250, 110, 'ah', 0.9, 0.7, 1.05, 0.02)
    hoard = at(clatter(1.2, 18, 0.3, 0.9) * 0.5, 0.45)
    spill = at(coins(1.0, 14, 0.3) * 0.4, 0.55)
    return mix(cry, at(wheeze(0.6, 700, 2200), 0.95), hoard, spill)


def build():
    S.takes_cat('dr_shot', shot, 3, 'fire')
    S.save_cat('dr_throw', throw(), 'cast')
    S.save_cat('dr_grab', grab(), 'impact')
    S.save_cat('dr_reel', reel(), 'cast')
    S.save_cat('dr_anchor_wind', anchor_wind(), 'cast')
    S.save_cat('dr_anchor', anchor(), 'impact')
    S.save_cat('dr_dive', dive(), 'cast')
    S.save_cat('dr_quake', quake(), 'impact')
    S.save_cat('dr_barge', barge(), 'cast')
    S.takes_cat('dredge_junk_clatter', junk_clatter, 3, 'signature')
    S.save_cat('dr_hop', hop(), 'dash')
    S.takes_cat('dredge_dash', dash, 3, 'dash')
    S.save_cat('dr_blast_charge', blast_charge(), 'cast')
    S.save_cat('dr_blast', blast(), 'impact')
    S.takes_cat('dredge_coin_jingle', coin_jingle, 3, 'signature')
    S.takes_cat('dredge_pickup', pickup, 3, 'signature')
    for s in ('grass', 'stone', 'wood', 'snow'):
        S.takes_cat('dredge_step_' + s, lambda i, s=s: step(s, i), 3, 'step')
    S.takes_cat('dredge_hurt', hurt, 3, 'grunt')
    S.save_cat('dredge_down', down(), 'grunt')
    S.save_cat('dredge_death', death(), 'grunt')


if __name__ == '__main__':
    build()
    print('gen_sfx_grimble: done')
