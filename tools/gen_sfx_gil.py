"""Gil's sounds (id gil, the Novice Mage): a pet fish a spell stood up on two legs, fencing with a
swordfish, throwing whatever bottle comes out of the bag, swimming through the ground.

    cd tools && python3 gen_sfx_gil.py      (then: python3 gen_sfx_dash.py, godot --headless --import)

Signatures: the swordfish thrust (gil_thrust) and the Beached flop (gil_beached). Everything is water,
glass and a small wet body: thin blade swishes with a fin flick, glass that breaks five ways (one per
potion), bubbles, spray and surf. Every move and phase has its own sound (the list is in
content/sfx/gil.json; content/vfx/gil.json says which move plays it), each one's attack on the beat its
keyed pose (scripts/match/kmoves_gil.gd) puts the point out or lets the bottle go. Every sound is levelled
to its category (docs/AUDIO.md). Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, sub, grains, shape, soft_in

S.reseed(5153)


# ------------------------------------------------------------------ building blocks
def slow(d, rate, depth):
    """A smooth random wobble around 1 (turbulence): `rate` new values a second."""
    pts = max(4, int(d * rate) + 3)
    v = S.rng.standard_normal(pts)
    x = np.interp(np.arange(N(d)) / S.SR * rate, np.arange(pts), v)
    return np.clip(1.0 + depth * lpf(x, 40) / (np.std(x) + 1e-9), 0.05, None)


def sweep_noise(d, f0, f1, width=0.35):
    """Noise whose band glides f0 -> f1 (air or water rushing past)."""
    n = N(d)
    u = np.arange(n) / max(1, n - 1)
    lf = np.log(f0) + (np.log(f1) - np.log(f0)) * u
    out = np.zeros(n)
    src = noise(d)
    for fc in np.geomspace(120, 9000, 18):
        g = np.exp(-((np.log(fc) - lf) / width) ** 2)
        if g.max() < 0.02:
            continue
        out += bpf(src, fc * 0.8, fc * 1.25) * g
    return out


def bubble(f, d=0.06, rise=1.6):
    """One bubble: a sine whose pitch climbs as it rises and pops (the plink of water)."""
    t = T(d)
    ph = 2 * np.pi * np.cumsum(f * rise ** (t / d)) / S.SR
    return np.sin(ph) * env(N(d), 0.002, d * 0.35)


def bubbles(d, count, lo, hi, g=0.4):
    """A handful of bubbles scattered over d seconds."""
    out = np.zeros(N(d))
    for _ in range(count):
        t0 = S.rng.uniform(0.0, d * 0.8)
        out = mix(out, at(bubble(S.rng.uniform(lo, hi), S.rng.uniform(0.03, 0.08)) * S.rng.uniform(0.4, 1.0) * g, t0))
    return out[:N(d)]


def spray(d, lo=2500, hi=9000, decay=0.12):
    """Droplets and fine spray: dense high grains over a soft hiss."""
    return mix(grains(d, 220, lo, hi, 0.001, 0.003, fall=decay) * 0.5, S.hiss(d, lo, hi, 0.005, decay) * 0.35)


def glass(d, base=2600, shards=9):
    """A bottle breaking: a sharp crack, then shards ringing and skittering (inharmonic, high first)."""
    snap = mix(click(0.003, 3500, 11000) * 1.4, crack(0.12, 1500, 9000, 0.02) * 1.6)
    out = np.zeros(N(d))
    for _ in range(shards):
        f = base * S.rng.uniform(0.8, 2.6)
        pin = S.ring((f, f * 2.41, f * 3.93), 0.25, (0.06, 0.04, 0.025), (0.3, 0.15, 0.08))
        out = mix(out, at(pin * S.rng.uniform(0.4, 1.0), S.rng.uniform(0.0, d * 0.5)))
    return mix(snap, out[:N(d)])


def wet_slap(d=0.16, lo=300, hi=2600):
    """A wet body hitting something: a damp smack with a short spatter."""
    smack = crack(d, lo, hi, 0.018) * 1.6
    thud = kick(180, 90, d, 0.01, 0.03, 1.4) * 0.5
    return mix(smack, thud, at(spray(0.12, 2000, 6000, 0.04) * 0.5, 0.006))


# ------------------------------------------------------------------ LMB: Fencer (the swordfish)
def thrust(i):
    """A rapier thrust: a thin fast swish with a fin flick off the swordfish's tail."""
    d = 0.24
    swish = sweep_noise(0.16, 2200 + 200 * i, 5200, 0.3) * shape(0.16, 0.025, 0.03, 0.1) * 1.2
    zing = S.sweep(3100 + 140 * i, 4200, 0.1) * env(N(0.1), 0.004, 0.03) * 0.06
    flick = at(bpf(noise(0.05), 700, 2400) * env(N(0.05), 0.002, 0.012) * 0.5, 0.11)
    return soft_in(mix(swish, zing, flick, at(bubble(900 + 60 * i, 0.04) * 0.12, 0.13)))


def thrust_hit():
    """The swordfish's bill lands: a pointed tock, a short wet stab and a few drops."""
    d = 0.3
    tip = mix(click(0.003, 3000, 9000) * 1.2, crack(0.12, 900, 5000, 0.014) * 1.5)
    stab = mix(kick(260, 120, 0.18, 0.01, 0.03, 2.0) * 0.6,
               bpf(noise(0.1), 500, 2200) * env(N(0.1), 0.002, 0.025) * 0.8)
    return mix(tip, stab, at(spray(0.18, 2500, 7000, 0.05) * 0.4, 0.01))


def thrust_low(i):
    """The second thrust drives lower and turns the wrist over: a swish that dips, then a twist of the bill."""
    d = 0.26
    swish = sweep_noise(0.15, 2600 + 150 * i, 1500, 0.32) * shape(0.15, 0.02, 0.03, 0.1) * 1.2
    twist = at(sweep_noise(0.08, 1800, 3600, 0.3) * shape(0.08, 0.01, 0.02, 0.05) * 0.6, 0.06)
    flick = at(bpf(noise(0.04), 600, 2000) * env(N(0.04), 0.002, 0.01) * 0.45, 0.12)
    return soft_in(mix(swish, twist, flick, at(bubble(760 + 50 * i, 0.04) * 0.12, 0.15)))[:N(d)]


def lunge():
    """The third: a fencer's full lunge, the front foot stamped down and the whole body behind the point
    (the point is out at 0.06 s)."""
    stamp = mix(kick(150, 70, 0.16, 0.006, 0.03, 1.6) * 0.6, wet_slap(0.12, 280, 1800) * 0.35)
    drive = sweep_noise(0.24, 1500, 4800, 0.35) * shape(0.24, 0.05, 0.04, 0.15) * 1.3
    zing = S.sweep(2600, 4400, 0.14) * env(N(0.14), 0.005, 0.05) * 0.07
    return soft_in(mix(at(drive, 0.01), at(zing, 0.04), at(stamp, 0.05), at(spray(0.16, 2500, 7000, 0.05) * 0.3, 0.07)))


def lunge_hit():
    """The lunge lands: the bill drives in deeper than a thrust, a wet thump behind the tip."""
    tip = mix(click(0.003, 2600, 8000) * 1.1, crack(0.14, 700, 4200, 0.02) * 1.5)
    body = mix(kick(200, 80, 0.26, 0.012, 0.05, 2.2) * 0.75, lpf(noise(0.14), 1200) * env(N(0.14), 0.003, 0.04) * 0.9)
    return mix(tip, body, at(spray(0.24, 2000, 6500, 0.07) * 0.5, 0.012))


# ------------------------------------------------------------------ LMB held: Tide Lunge
def tide_wind():
    """Held past the tap: he sinks back and the water is drawn up onto the bill (a sucked-in swirl, bubbles)."""
    d = 0.5
    draw = sweep_noise(d, 500, 2400, 0.4) * slow(d, 14, 0.3) * shape(d, 0.18, 0.2, 0.12) * 0.9
    lap = lpf(noise(d), 700) * slow(d, 20, 0.7) * shape(d, 0.1, 0.25, 0.15) * 0.6
    return soft_in(mix(draw, lap, at(bubbles(0.4, 6, 350, 900, 0.3), 0.06)), 8)


def tide_full():
    """Full charge: the gathered water rings on the point like a tapped bottle, and a drop falls off."""
    ring = S.chime(1320, 0.35, 0.12, ((1.0, 1.0), (2.41, 0.35), (3.93, 0.12))) * 0.45
    return mix(click(0.002, 3000, 9000) * 0.3, ring, at(bubble(1050, 0.06, 1.9) * 0.5, 0.05))


def tide_lunge():
    """Let go: he drives down the lane behind the point with the water: a stamp, a long rush, the spray after."""
    d = 0.6
    stamp = mix(kick(130, 55, 0.22, 0.01, 0.05, 2.0) * 0.7, wet_slap(0.14, 260, 1600) * 0.4)
    rush = sweep_noise(d, 450, 2600, 0.45) * slow(d, 16, 0.35) * shape(d, 0.03, 0.18, 0.38) * 1.2
    pierce = sweep_noise(0.2, 2000, 5200, 0.3) * shape(0.2, 0.03, 0.04, 0.12) * 0.8
    return soft_in(mix(at(stamp, 0.04), rush, at(pierce, 0.02), at(spray(0.45, 2200, 8000, 0.15) * 0.5, 0.1)))


def tide_hit():
    """The Tide Lunge runs a foe through: a deep wet stab and a sheet of water breaking over them."""
    stab = mix(click(0.004, 2200, 7000) * 1.0, kick(170, 60, 0.32, 0.015, 0.07, 2.4) * 0.8)
    sheet = lpf(noise(0.32), 2200) * env(N(0.32), 0.006, 0.09) * 1.3
    return mix(stab, at(sheet, 0.01), at(spray(0.35, 2500, 8000, 0.12) * 0.5, 0.03),
               at(bubbles(0.3, 4, 300, 800, 0.25), 0.08))


# ------------------------------------------------------------------ RMB: Grab Bag
def toss(i):
    """A bottle out of the bag: glass knocking in the bag, then the bottle flung end over end as the hand
    whips forward (0.08-0.16 s in gil_throw)."""
    d = 0.4
    knock = mix(S.chime(1900 + 120 * i, 0.12, 0.04, ((1.0, 1.0), (2.7, 0.4))) * 0.5,
                at(S.chime(2300 + 90 * i, 0.1, 0.03, ((1.0, 1.0), (2.9, 0.3))) * 0.35, 0.03))
    fling = sweep_noise(0.26, 700, 2600, 0.35) * shape(0.26, 0.04, 0.04, 0.18) * 0.9
    slosh = lpf(noise(0.2), 900) * slow(0.2, 25, 0.8) * shape(0.2, 0.02, 0.05, 0.13) * 0.4
    return soft_in(mix(knock, at(fling, 0.08), at(slosh, 0.1)))


def pop_thunder():
    """Thunder: the flask breaks and the bottled storm snaps loose (a zap crackle and a low thump)."""
    d = 0.7
    zap = S.rattle(0.35, 90, 2500, 9000, 0.6, 0.12) * 0.9
    arc = S.fm(620, 2.3, 5.0, 0.3, 0.08) * 0.25
    thump = mix(kick(150, 50, 0.5, 0.02, 0.1, 2.4) * 0.8, sub(75, 40, 0.5, 0.1) * 0.3)
    return mix(glass(d, 2700, 7), at(zap, 0.005), at(arc, 0.005), thump)


def pop_slime():
    """Slime: a squat jar cracks and a thick glob lands with a squelch and a few slow bubbles."""
    d = 0.75
    squelch = lpf(noise(0.32), 900) * slow(0.32, 30, 0.9) * shape(0.32, 0.01, 0.06, 0.25) * 1.5
    glob = mix(kick(140, 60, 0.3, 0.04, 0.06, 1.6) * 0.7, kick(110, 55, 0.25, 0.04, 0.05, 1.4) * 0.3)
    blub = bubbles(0.6, 6, 180, 420, 0.5)
    return mix(glass(d, 2000, 5) * 0.7, squelch, glob, at(blub, 0.08))


def pop_air():
    """Air: a tall bottle shatters and the gust inside bursts out in a ring."""
    d = 0.7
    burst = sweep_noise(0.5, 2600, 500, 0.45) * shape(0.5, 0.008, 0.05, 0.42) * 1.3
    puff = lpf(noise(0.2), 1200) * env(N(0.2), 0.004, 0.05) * 1.0
    return mix(glass(d, 3000, 8), puff, at(burst, 0.01))


def pop_fire():
    """Fire: the teardrop breaks and catches with a whoomp, then crackles."""
    d = 0.8
    whoomp = mix(kick(130, 45, 0.5, 0.03, 0.12, 2.2) * 0.75, lpf(noise(0.45), 1400) * env(N(0.45), 0.012, 0.14) * 1.5)
    catch = sweep_noise(0.3, 300, 1800, 0.45) * shape(0.3, 0.03, 0.05, 0.2) * 0.7
    crackle = grains(0.6, 70, 800, 3500, 0.0015, 0.005, fall=0.25) * 0.6
    return mix(glass(d, 2400, 6) * 0.8, at(whoomp, 0.01), catch, at(crackle, 0.06))


def pop_zeep():
    """Super Zeep (the rare one): a fizzing fuse, then a big frothy blast and a fountain of bubbles."""
    d = 1.1
    fizz = S.hiss(0.12, 3000, 9000, 0.02, 0.05) * 0.4
    blast = mix(click(0.005, 1800, 7000) * 1.1, kick(120, 36, 0.9, 0.04, 0.18, 3.0) * 0.9,
                sub(60, 30, 0.9, 0.2) * 0.5, lpf(noise(0.5), 2200) * env(N(0.5), 0.004, 0.12) * 1.6)
    froth = bubbles(0.9, 22, 300, 1500, 0.4)
    return mix(fizz, at(glass(0.8, 2500, 12), 0.1), at(blast, 0.1), at(froth, 0.18), at(spray(0.6) * 0.6, 0.12))


def mark():
    """Fish Out of Water counts a new mark (1/3, 2/3): a tiny tink of glass and one fat drop."""
    tink = S.chime(2350, 0.18, 0.05, ((1.0, 1.0), (2.9, 0.3))) * 0.4
    return mix(tink, at(bubble(880, 0.07, 2.0) * 0.6, 0.02), at(spray(0.08, 3000, 8000, 0.02) * 0.2, 0.02))


def beached():
    """Fish Out of Water: a foe flops twice on dry land, then a bright bubbly gulp (the Beached pop)."""
    flop = mix(wet_slap(0.18, 300, 2400), at(wet_slap(0.16, 380, 2800) * 0.8, 0.14))
    gulp = mix(bubble(520, 0.12, 2.2) * 0.6, at(bubble(780, 0.1, 2.0) * 0.5, 0.06))
    bell = S.chime(1568, 0.5, 0.18, ((1.0, 1.0), (2.0, 0.35), (3.0, 0.12))) * 0.35
    return mix(flop, at(gulp, 0.3), at(bell, 0.32))


# ------------------------------------------------------------------ Shift: Ground Swim
def dash(i):
    """Diving into the ground: a crouch, the earthy splash as his head goes in (0.07 s in gil_dive), the fin
    rushing off under the surface."""
    d = 0.45
    dive = mix(lpf(noise(0.18), 1400) * env(N(0.18), 0.004, 0.05) * 1.4,
               kick(160 + 10 * i, 70, 0.2, 0.02, 0.04, 1.5) * 0.5)
    rush = sweep_noise(0.36, 400 + 40 * i, 1500, 0.4) * shape(0.36, 0.03, 0.08, 0.24) * 0.9
    splash = spray(0.2, 2000, 6000, 0.05) * 0.5
    crouch = bpf(noise(0.04), 400, 1800) * env(N(0.04), 0.002, 0.012) * 0.3
    return mix(crouch, at(dive, 0.05), at(splash, 0.055), at(rush, 0.09), at(bubbles(0.35, 4, 250, 600, 0.3), 0.13))


def surface():
    """Bursting up out of the ground: a deep plop, a column of spray, foes thrown up."""
    d = 0.7
    plop = mix(kick(140, 50, 0.4, 0.03, 0.08, 2.4) * 0.8, sub(70, 40, 0.4, 0.08) * 0.35)
    up = sweep_noise(0.4, 500, 3200, 0.4) * shape(0.4, 0.01, 0.06, 0.3) * 1.1
    return mix(plop, up, at(spray(0.55, 2500, 9000, 0.18) * 0.8, 0.02), at(bubbles(0.5, 6, 300, 900, 0.35), 0.05))


# ------------------------------------------------------------------ E: Riptide
def spin(i):
    """One turn of the swordfish spin (the kit plays one every 0.25 s, pitch climbing as it builds)."""
    d = 0.3
    turn = sweep_noise(d, 900 + 80 * i, 2600, 0.45) * (0.55 + 0.45 * np.sin(np.pi * np.arange(N(d)) / N(d))) ** 2
    water = spray(d, 1800, 6000, 0.1) * 0.35
    return soft_in(mix(turn * shape(d, 0.03, 0.1, 0.16), water))


def spout():
    """The waterspout leaves: a churning rush of water down the line."""
    d = 0.8
    push = mix(kick(120, 55, 0.4, 0.03, 0.08, 1.8) * 0.6, lpf(noise(0.3), 900) * env(N(0.3), 0.01, 0.08) * 1.0)
    rush = sweep_noise(d, 350, 1800, 0.5) * slow(d, 18, 0.4) * shape(d, 0.04, 0.3, 0.42) * 1.0
    return mix(push, rush, at(spray(0.6, 2200, 8000, 0.2) * 0.5, 0.05), at(bubbles(0.6, 8, 200, 700, 0.3), 0.1))


# ------------------------------------------------------------------ X: Tidal Wave
def wave():
    """The wave rises under him and he surfs its crest for a second."""
    d = 1.2
    swell = lpf(noise(d), 260) * slow(d, 5, 0.3) * shape(d, 0.25, 0.6, 0.35) * 2.0
    crest = sweep_noise(d, 400, 1500, 0.55) * slow(d, 12, 0.4) * shape(d, 0.1, 0.7, 0.4) * 0.9
    foam = spray(d, 2500, 8000, 0.6) * shape(d, 0.2, 0.6, 0.4) * 0.7
    return mix(swell, crest, foam, sub(55, 45, d, 0.6) * 0.25)


def wave_land():
    """The wave breaks as he jumps off it: a crash, a hiss of foam running out, a few bubbles."""
    d = 0.9
    crash = mix(kick(110, 40, 0.6, 0.03, 0.12, 2.4) * 0.8, lpf(noise(0.5), 1800) * env(N(0.5), 0.005, 0.14) * 1.5)
    hiss = spray(d, 2000, 8000, 0.35) * 0.8
    return mix(crash, at(hiss, 0.02), at(bubbles(0.7, 8, 250, 800, 0.3), 0.12))


# ------------------------------------------------------------------ the recast (RecastCue)
def recast_open():
    """Riptide's spin is up and E will send the spout: two bubbles rising into a clear drop."""
    a = bubble(660, 0.09, 1.8) * 0.6
    b = bubble(990, 0.09, 1.8) * 0.6
    drop = S.chime(1760, 0.3, 0.1, ((1.0, 1.0), (2.0, 0.25))) * 0.35
    return mix(a, at(b, 0.07), at(drop, 0.12))


def recast_tick():
    """The window is closing: a single quick drip (played rising, one per tick)."""
    return mix(bubble(1300, 0.05, 1.5) * 0.8, click(0.002, 3000, 8000) * 0.3)


# ------------------------------------------------------------------ footsteps
def step(surface_name, i):
    """Small damp feet: a soft heel and a wet little slap, the slap brighter on hard floors."""
    d = 0.2
    heel = kick(170 + 10 * i, 95, d, 0.006, 0.016, 1.4) * 0.4
    slap = bpf(noise(0.05), 500, 2600) * env(N(0.05), 0.001, 0.01) * 0.6
    if surface_name == 'grass':
        tex = bpf(noise(d), 700, 3500) * env(N(d), 0.004, 0.03) * 0.6
        slap *= 0.5
    elif surface_name == 'stone':
        tex = mix(click(0.002, 2000, 6000) * 0.5, crack(d, 900, 3800, 0.008) * 0.8)
    elif surface_name == 'wood':
        tex = mix(S.ring((240 + 9 * i, 520 + 14 * i), d, (0.04, 0.025), (0.4, 0.2)), crack(d, 500, 2000, 0.01) * 0.5)
    else:
        tex = mix(grains(0.1, 500, 700, 2600, 0.002, 0.005, fall=0.04) * 0.7,
                  lpf(noise(d), 1500) * env(N(d), 0.006, 0.03) * 0.5)
        slap *= 0.4
    drip = at(bubble(1100 + 90 * i, 0.03) * 0.08, 0.04) if i % 2 == 1 else np.zeros(1)
    return soft_in(mix(heel, slap, tex, drip))


# ------------------------------------------------------------------ voice: a small, delighted fish
def gvoice(d, *args, **kw):
    """His voice, its tail eased to silence (never cut off), with a gurgle under it."""
    v = S.voice(d, *args, **kw) * shape(d, 0.0, d * 0.55, d * 0.45)
    return v * (1.0 + 0.25 * np.sin(2 * np.pi * 23 * T(d)))


def hurt(i):
    v = ('uh', 'ah', 'eh', 'uh')[i]
    f0 = (290, 270, 310, 280)[i]
    yelp = gvoice(0.2 + 0.03 * (i % 2), f0, f0 * 0.75, v, breath=0.25, rasp=0.12, scale=1.2, a=0.008)
    return mix(yelp, at(bubble(700 + 40 * i, 0.05) * 0.12, 0.2))


def down():
    """Knocked down: a falling 'oof', then a few dazed gulps for air."""
    oof = gvoice(0.55, 280, 170, 'uh', breath=0.3, rasp=0.2, vib=0.02, scale=1.18, a=0.015)
    gulps = mix(*[at(gvoice(0.08, 240, 300, 'mm', breath=0.5, scale=1.2, a=0.005) * 0.4, 0.12 * k) for k in range(3)])
    return mix(oof, at(gulps, 0.6))


def death():
    """A long falling cry that ends in a trail of bubbles."""
    cry = gvoice(0.85, 320, 140, 'ah', breath=0.3, rasp=0.25, vib=0.03, scale=1.18, a=0.015)
    return mix(cry, at(bubbles(0.7, 10, 250, 900, 0.25), 0.55))


def build():
    S.takes_cat('gil_thrust', thrust, 3, 'fire')
    S.save_cat('gil_thrust_hit', thrust_hit(), 'impact')
    S.takes_cat('gil_toss', toss, 3, 'cast')
    S.save_cat('gil_pop_thunder', pop_thunder(), 'impact')
    S.save_cat('gil_pop_slime', pop_slime(), 'impact')
    S.save_cat('gil_pop_air', pop_air(), 'impact')
    S.save_cat('gil_pop_fire', pop_fire(), 'impact')
    S.save_cat('gil_pop_zeep', pop_zeep(), 'impact')
    S.save_cat('gil_beached', beached(), 'signature')
    S.takes_cat('gil_dash', dash, 3, 'dash')
    S.save_cat('gil_surface', surface(), 'impact')
    S.takes_cat('gil_spin', spin, 3, 'cast')
    S.save_cat('gil_spout', spout(), 'cast')
    S.save_cat('gil_wave', wave(), 'cast')
    S.save_cat('gil_wave_land', wave_land(), 'impact')
    S.save_cat('gil_recast_open', recast_open(), 'ui')
    S.save_cat('gil_recast_tick', recast_tick(), 'ui')
    for s in ('grass', 'stone', 'wood', 'snow'):
        S.takes_cat('gil_step_' + s, lambda i, s=s: step(s, i), 3, 'step')
    S.takes_cat('gil_hurt', hurt, 3, 'grunt')
    S.save_cat('gil_down', down(), 'grunt')
    S.save_cat('gil_death', death(), 'grunt')
    # the rework's moves (gil-rework-1111), after the rest so the older sounds' random draws stay the same
    S.takes_cat('gil_thrust_low', thrust_low, 3, 'fire')
    S.save_cat('gil_lunge', lunge(), 'fire')
    S.save_cat('gil_lunge_hit', lunge_hit(), 'impact')
    S.save_cat('gil_tide_wind', tide_wind(), 'cast')
    S.save_cat('gil_tide_full', tide_full(), 'cast')
    S.save_cat('gil_tide_lunge', tide_lunge(), 'fire')
    S.save_cat('gil_tide_hit', tide_hit(), 'impact')
    S.save_cat('gil_mark', mark(), 'impact')


if __name__ == '__main__':
    build()
    print('gen_sfx_gil: done')
