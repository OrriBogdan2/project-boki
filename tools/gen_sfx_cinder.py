"""Cinder's sounds (id ashwick, the Ashen Kiss): a flame lance fed from a fuel tank on her back, a
bellows that blows her about, and a voice a little cracked by the Blight she drank.

    cd tools && python3 gen_sfx_cinder.py      (then: godot --headless --import)

Signatures: the flame roar (lw_roar, the Torch Lance) and the tank hiss (ashwick_tank_hiss, the valve
venting when she lets go). Fire here is built from turbulent low noise (the body), a mid whoosh, a
low rumble and soft crackle, kept under 6 kHz so a held lance never turns into hiss. Every sound is
levelled to its category (docs/AUDIO.md). The kit's older lw_* / as_ignite files are rebuilt under their
own names (content/sfx/ashwick.json "replaces"). Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, T, noise, lpf, hpf, bpf, env, mix, at, kick, click, crack, sub, grains, shape, soft_in

S.reseed(4417)


# ------------------------------------------------------------------ building blocks
def slow(d, rate, depth):
    """A smooth random wobble around 1 (turbulence): `rate` new values a second."""
    pts = max(4, int(d * rate) + 3)
    v = S.rng.standard_normal(pts)
    x = np.interp(np.arange(N(d)) / S.SR * rate, np.arange(pts), v)
    return np.clip(1.0 + depth * lpf(x, 40) / (np.std(x) + 1e-9), 0.05, None)


def sweep_noise(d, f0, f1, width=0.35):
    """Noise whose band glides f0 -> f1 (a bank of bands crossfaded along the glide: air rushing past)."""
    n = N(d); u = np.arange(n) / max(1, n - 1)
    lf = np.log(f0) + (np.log(f1) - np.log(f0)) * u
    out = np.zeros(n); src = noise(d)
    for fc in np.geomspace(120, 7000, 16):
        g = np.exp(-((np.log(fc) - lf) / width) ** 2)
        if g.max() < 0.02:
            continue
        out += bpf(src, fc * 0.8, fc * 1.25) * g
    return out


def flame(d, bright=2400, rumble=1.0, crackle=1.0):
    """A body of fire: turbulent low roar, a mid whoosh, low rumble and soft crackle."""
    core = lpf(noise(d), 700) * slow(d, 14, 0.45) * 1.6
    mid = bpf(noise(d), 500, bright) * slow(d, 22, 0.6) * 0.55
    low = lpf(noise(d), 140) * slow(d, 6, 0.3) * 2.2 * rumble
    pops = grains(d, 70 * crackle, 700, 3800, 0.0015, 0.005) * 0.6
    return mix(core, mid, low, pops)


def snap_ring(freqs, d, dec, g):
    """A small metal ring (the tank, a buckle, the nozzle)."""
    return S.ring(freqs, d, [dec * (1.0 - 0.15 * k) for k in range(len(freqs))], [g / (k + 1) for k in range(len(freqs))])


# ------------------------------------------------------------------ LMB: Torch Lance
def pilot():
    """The igniter ticks, gas hisses and the cyan pilot catches with a soft fwump."""
    d = 0.42
    tick = mix(click(0.003, 3000, 8000) * 1.2, snap_ring((3900, 6100), 0.05, 0.012, 0.25))
    gas = S.hiss(d, 1500, 5000, 0.03, 0.08) * 0.35
    catch = mix(kick(170, 65, 0.3, 0.04, 0.07, 1.6) * 0.5, lpf(noise(0.3), 1200) * env(N(0.3), 0.012, 0.09) * 1.4)
    lick = flame(0.32, 1800, 0.5, 0.5) * shape(0.32, 0.03, 0.05, 0.22) * 0.6
    return mix(tick, at(gas, 0.008), at(catch, 0.05), at(lick, 0.06))


def roar(i):
    """One breath of the held lance (the kit plays one every 0.4 s; each overlaps the next)."""
    d = 0.66
    body = flame(d, 2200 + 150 * i, 1.1, 0.9) * shape(d, 0.11, 0.3, 0.25)
    jet = sweep_noise(d, 900 + 60 * i, 650, 0.5) * shape(d, 0.08, 0.32, 0.25) * 0.5
    return mix(body, jet)


def tank_hiss(i):
    """The tank's valve vents as she lets go: a pressure pop, a falling hiss, the flame sputtering out."""
    d = 0.75
    pop = mix(kick(320 + 15 * i, 140, 0.12, 0.01, 0.025, 1.8) * 0.35, click(0.003, 2000, 6000) * 0.6)
    vent = sweep_noise(d, 3500 - 150 * i, 1500, 0.4) * env(N(d), 0.006, 0.22) * 1.2
    whistle = S.sweep(2900 + 120 * i, 2300, d) * env(N(d), 0.01, 0.12) * 0.05
    tank = snap_ring((520 + 20 * i, 1180, 1990), 0.5, 0.18, 0.12)
    sputter = grains(0.5, 40, 300, 1600, 0.004, 0.012, fall=0.15) * 0.8
    out = lpf(flame(0.3, 1500, 0.6, 0.3), 1800) * shape(0.3, 0.005, 0.02, 0.25) * 0.5
    return mix(pop, at(vent, 0.004), at(whistle, 0.01), tank, at(sputter, 0.05), out)


# ------------------------------------------------------------------ RMB: Cinder Shot
def bolt():
    """A cinder lobbed from the gun hand: a mortar thoomp and the ember whirring away."""
    d = 0.55
    thoomp = mix(click(0.003, 2500, 7000) * 1.0, kick(170, 58, d, 0.02, 0.07, 2.6) * 0.75, sub(80, 45, d, 0.08) * 0.3)
    away = sweep_noise(0.45, 700, 2600, 0.35) * shape(0.45, 0.04, 0.05, 0.3) * 0.6
    flutter = flame(0.4, 2000, 0.3, 1.2) * env(N(0.4), 0.01, 0.12) * 0.45
    return mix(thoomp, at(away, 0.02), at(flutter, 0.01))


def bolt_hit():
    """The cinder bursts on a foe: a wet fiery splat, a flare and crackle settling."""
    d = 0.75
    smack = mix(click(0.003, 2500, 8000) * 1.1, kick(230, 70, 0.4, 0.012, 0.05, 2.6) * 0.6,
                crack(0.3, 250, 2200, 0.035) * 1.6)
    flare = flame(d, 2600, 0.8, 1.0) * shape(d, 0.006, 0.04, 0.45) * 0.9
    embers = grains(d, 60, 900, 3500, 0.002, 0.006, fall=0.25) * 0.7
    return mix(smack, flare, at(embers, 0.03), sub(70, 40, 0.4, 0.07) * 0.3)


# ------------------------------------------------------------------ Char: Ablaze and Flashover
def ignite():
    """A foe goes Ablaze: a rising whoomp as the Char catches."""
    d = 0.85
    catch = sweep_noise(0.3, 250, 1600, 0.45) * shape(0.3, 0.06, 0.04, 0.2) * 0.9
    whoomp = mix(kick(125, 48, 0.5, 0.04, 0.12, 2.0) * 0.7, lpf(noise(0.5), 1400) * env(N(0.5), 0.015, 0.14) * 1.6)
    burn = flame(0.6, 2000, 0.8, 1.2) * shape(0.6, 0.02, 0.1, 0.45) * 0.7
    return mix(catch, at(whoomp, 0.08), at(burn, 0.1))


def blaze():
    """Flashover: the burn bursts fiercer. A deep double whoomp, a bright flare and a long crackling tail."""
    d = 1.1
    hit = mix(click(0.004, 2000, 7000) * 1.2, kick(140, 40, d, 0.03, 0.16, 2.8) * 0.8, sub(65, 32, d, 0.2) * 0.45)
    second = kick(100, 38, 0.6, 0.04, 0.12, 2.2) * 0.45
    flare = flame(d, 3000, 1.2, 1.4) * shape(d, 0.01, 0.12, 0.7) * 1.0
    rise = sweep_noise(0.4, 400, 2800, 0.45) * shape(0.4, 0.02, 0.05, 0.3) * 0.6
    return mix(hit, at(second, 0.11), flare, rise)


# ------------------------------------------------------------------ Shift: Soot Ram and the poof
def bash():
    """The burner whooshes and lights as she throws herself head first."""
    d = 0.55
    light = mix(click(0.003, 3000, 7000) * 0.8, S.hiss(0.08, 1500, 5000, 0.004, 0.03) * 0.5)
    rush = sweep_noise(0.45, 450, 2800, 0.38) * shape(0.45, 0.05, 0.12, 0.25) * 1.0
    fire = flame(0.5, 2200, 0.9, 0.8) * shape(0.5, 0.03, 0.15, 0.3) * 0.8
    return mix(light, at(rush, 0.01), at(fire, 0.03), at(kick(150, 70, 0.3, 0.03, 0.06, 1.6) * 0.3, 0.03))


def bash_hit():
    """The ram lands: a dull fiery thump, a flare, and her boots scraping on the recoil."""
    d = 0.7
    thump = mix(click(0.004, 2000, 6000) * 1.0, kick(140, 44, d, 0.03, 0.1, 3.0) * 0.9,
                crack(0.35, 200, 1800, 0.04) * 1.8, sub(70, 38, d, 0.12) * 0.45)
    flare = flame(0.5, 2200, 0.6, 1.0) * shape(0.5, 0.005, 0.03, 0.4) * 0.8
    scrape = bpf(noise(0.16), 700, 3200) * slow(0.16, 120, 0.8) * shape(0.16, 0.02, 0.05, 0.09) * 0.5
    return mix(thump, flare, at(scrape, 0.11))


def hop():
    """The bellows' poof: a puff of air and flame blown out behind her, with a short hiss."""
    d = 0.45
    puff = mix(lpf(noise(0.3), 1300) * env(N(0.3), 0.008, 0.07) * 1.8, kick(115, 60, 0.25, 0.03, 0.05, 1.5) * 0.45)
    blow = sweep_noise(0.35, 1400, 500, 0.4) * shape(0.35, 0.01, 0.05, 0.25) * 0.8
    lick = flame(0.35, 1800, 0.4, 0.8) * shape(0.35, 0.01, 0.03, 0.3) * 0.5
    return mix(puff, blow, lick, at(S.hiss(0.2, 2000, 5000, 0.01, 0.06) * 0.12, 0.08))


def dash(i):
    """The shared dash, Cinder's way: a quick bellows whoosh and the tank knocking on her back."""
    d = 0.4
    rush = sweep_noise(0.32, 500 + 40 * i, 2200, 0.4) * shape(0.32, 0.03, 0.05, 0.22) * 1.0
    lick = flame(0.3, 1600, 0.3, 0.6) * shape(0.3, 0.02, 0.04, 0.22) * 0.35
    knock = at(mix(snap_ring((470, 1060), 0.25, 0.08, 0.25), kick(220, 120, 0.1, 0.01, 0.02, 1.2) * 0.15), 0.03)
    return mix(rush, lick, knock)


# ------------------------------------------------------------------ E: Furnace Cloak
def cloak():
    """The bellows draw in, then the furnace blasts out round her."""
    d = 1.3
    draw = sweep_noise(0.2, 300, 1500, 0.4) * shape(0.2, 0.14, 0.02, 0.04) * 0.6
    blast = mix(click(0.004, 1800, 6000) * 1.0, kick(115, 36, 1.0, 0.04, 0.18, 3.0) * 0.85,
                sub(60, 30, 1.0, 0.22) * 0.5, lpf(noise(0.6), 1800) * env(N(0.6), 0.004, 0.12) * 1.8)
    furnace = flame(1.0, 2400, 1.4, 1.3) * shape(1.0, 0.01, 0.15, 0.8) * 0.9
    return mix(draw, at(blast, 0.18), at(furnace, 0.19))


def cloak_hit():
    """The blast sears a foe: a smack and a sizzle (once a cast, at the first foe it caught)."""
    d = 0.55
    smack = mix(click(0.003, 2500, 7000) * 0.9, kick(210, 80, 0.3, 0.01, 0.04, 2.4) * 0.6, crack(0.25, 300, 2000, 0.03) * 1.4)
    sizzle = bpf(noise(d), 1800, 5000) * slow(d, 60, 0.9) * env(N(d), 0.01, 0.16) * 0.4
    sear = flame(0.45, 2000, 0.5, 1.4) * shape(0.45, 0.005, 0.05, 0.35) * 0.6
    return mix(smack, sizzle, sear)


# ------------------------------------------------------------------ X: Flue Flight
def jet():
    """Lift-off: the bellows jet roars up, holds through the 1.8 s flight and dies away."""
    d = 1.9
    burst = mix(click(0.005, 1800, 6000) * 1.0, kick(120, 38, d, 0.04, 0.2, 3.0) * 0.8, sub(58, 30, d, 0.3) * 0.5)
    lift = sweep_noise(0.5, 300, 2200, 0.45) * shape(0.5, 0.03, 0.1, 0.35) * 0.9
    body = flame(d, 2400, 1.4, 1.0) * shape(d, 0.05, 1.2, 0.6) * 1.0
    thrum = lpf(noise(d), 90) * (1 + 0.5 * np.sin(2 * np.pi * 7.0 * T(d))) * shape(d, 0.1, 1.1, 0.6) * 1.6
    return mix(burst, lift, body, thrum)


def jet_land():
    """Down off the flight: a heavy landing and the jet snuffing out."""
    d = 0.7
    thud = mix(click(0.004, 1500, 5000) * 0.8, kick(110, 42, d, 0.03, 0.09, 2.8) * 0.9, sub(65, 35, d, 0.1) * 0.4,
               crack(0.25, 150, 1200, 0.04) * 1.4)
    snuff = sweep_noise(0.45, 1500, 300, 0.4) * shape(0.45, 0.005, 0.05, 0.38) * 0.7
    embers = grains(0.6, 35, 600, 2800, 0.002, 0.006, fall=0.2) * 0.6
    return mix(thud, snuff, at(embers, 0.05))


def trail(i):
    """The molten carpet: lava blooping and sizzling as it is laid."""
    d = 0.75
    out = np.zeros(N(d))
    for _ in range(5 + i):
        t0 = S.rng.uniform(0.0, 0.45)
        f0 = S.rng.uniform(140, 320)
        out = mix(out, at(kick(f0 * 1.6, f0, 0.12, 0.015, 0.03, 1.4) * S.rng.uniform(0.25, 0.5), t0))
    sizzle = bpf(noise(d), 1200, 4200) * slow(d, 40, 0.8) * shape(d, 0.06, 0.25, 0.4) * 0.35
    burn = flame(d, 1600, 0.8, 0.6) * shape(d, 0.08, 0.25, 0.4) * 0.5
    return mix(out, sizzle, burn)


# ------------------------------------------------------------------ footsteps
def step(surface, i):
    """A quick light patter (heavy kit, short strides), the pack clinking on every other step."""
    d = 0.22
    heel = kick(150 + 10 * i, 80, d, 0.008, 0.02, 1.6) * 0.5
    if surface == 'grass':
        tex = mix(bpf(noise(d), 600, 3500) * env(N(d), 0.004, 0.035) * 0.8, grains(0.08, 300, 1500, 4000, 0.001, 0.003) * 0.3)
        heel *= 0.7
    elif surface == 'stone':
        tex = mix(click(0.003, 2000, 6000) * 0.9, crack(d, 800, 3500, 0.012) * 1.0, grains(0.05, 200, 2500, 5500, 0.001, 0.002) * 0.25)
    elif surface == 'wood':
        tex = mix(click(0.003, 1500, 5000) * 0.6, S.ring((210 + 9 * i, 470 + 15 * i), d, (0.05, 0.03), (0.5, 0.25)),
                  crack(d, 400, 1800, 0.015) * 0.7)
    else:
        tex = mix(grains(0.12, 600, 600, 2600, 0.002, 0.006, fall=0.05) * 0.8, lpf(noise(d), 1500) * env(N(d), 0.008, 0.04) * 0.6)
        heel *= 0.6
    clink = at(snap_ring((1520 + 40 * i, 2410, 3630), 0.18, 0.05, 0.13), 0.025) if i % 2 == 1 else np.zeros(1)
    return soft_in(mix(heel, tex, clink))


# ------------------------------------------------------------------ voice: a woman, cracked by the Blight
def cvoice(d, *args, **kw):
    """Her voice, its tail eased to silence (never cut off)."""
    return S.voice(d, *args, **kw) * shape(d, 0.0, d * 0.55, d * 0.45)


def hurt(i):
    v = ('ah', 'eh', 'uh', 'ah')[i]
    f0 = (340, 310, 360, 325)[i]
    cry = cvoice(0.24 + 0.03 * (i % 2), f0, f0 * 0.74, v, breath=0.3, rasp=0.18, scale=1.16, a=0.008)
    gasp = cvoice(0.1, 260, 300, 'ee', breath=0.9, scale=1.2, a=0.01) * 0.25
    return mix(cry, at(gasp, 0.27))


def down():
    """Knocked down: a falling groan, then a breathless little unhinged laugh as the tank sputters."""
    groan = cvoice(0.7, 300, 175, 'uh', breath=0.35, rasp=0.3, vib=0.02, scale=1.14, a=0.02)
    laugh = np.zeros(1)
    for k in range(3):
        laugh = mix(laugh, at(cvoice(0.09, 390 - 22 * k, 330 - 22 * k, 'eh', breath=0.7, scale=1.18, a=0.006) * (0.55 - 0.1 * k), 0.13 * k))
    sputter = grains(0.6, 30, 300, 1500, 0.004, 0.01, fall=0.2) * 0.4
    return mix(groan, at(laugh, 0.78), at(sputter, 0.4))


def death():
    """A long falling cry; the tank vents and her flame goes out."""
    cry = cvoice(0.95, 380, 150, 'ah', breath=0.35, rasp=0.32, vib=0.025, scale=1.15, a=0.015)
    vent = at(tank_hiss(2) * 0.5, 0.55)
    gutter = at(flame(0.8, 1400, 0.8, 0.8) * shape(0.8, 0.05, 0.1, 0.6) * 0.35, 0.3)
    return mix(cry, vent, gutter)


# ------------------------------------------------------------------ cloak blast
def flashover_pop():
    """The flashover's flare: a bright crack over a low whump and a short gust of hot air."""
    return mix(crack(0.06, 1800, 9000, 0.02) * 0.9, kick(240, 55, 0.4, 0.05, 0.16) * 1.1,
               S.hiss(0.5, 600, 4200, 0.01, 0.14) * 0.5)


def cloak_shield():
    """The ember cloak closing round her: a rising warm sweep, a soft gust and a few settling sparks."""
    sw = lpf(S.sweep(160, 420, 0.38, 'saw'), 1500) * shape(0.38, 0.12, 0.05, 0.2)
    return mix(sw * 0.7, bpf(noise(0.4), 400, 2600) * shape(0.4, 0.1, 0.05, 0.22) * 0.5,
               at(S.rattle(0.25, 60, 2500, 6000, 0.5, 0.08) * 0.35, 0.12))


def build():
    S.save_cat('lw_pilot', pilot(), 'cast')
    S.takes_cat('lw_roar', roar, 3, 'fire')
    S.takes_cat('ashwick_tank_hiss', tank_hiss, 3, 'signature')
    S.save_cat('lw_bolt', bolt(), 'cast')
    S.save_cat('lw_bolt_hit', bolt_hit(), 'impact')
    S.save_cat('as_ignite', ignite(), 'impact')
    S.save_cat('lw_blaze', blaze(), 'impact')
    S.save_cat('lw_bash', bash(), 'cast')
    S.save_cat('lw_bash_hit', bash_hit(), 'impact')
    S.save_cat('lw_hop', hop(), 'dash')
    S.takes_cat('ashwick_dash', dash, 3, 'dash')
    S.save_cat('lw_shield', cloak(), 'cast')
    S.save_cat('ashwick_cloak_hit', cloak_hit(), 'impact')
    S.save_cat('lw_jet', jet(), 'cast')
    S.save_cat('lw_jet_land', jet_land(), 'impact')
    S.takes_cat('lw_trail', trail, 3, 'cast')
    for s in ('grass', 'stone', 'wood', 'snow'):
        S.takes_cat('ashwick_step_' + s, lambda i, s=s: step(s, i), 3, 'step')
    S.takes_cat('ashwick_hurt', hurt, 3, 'grunt')
    S.save_cat('ashwick_down', down(), 'grunt')
    S.save_cat('ashwick_death', death(), 'grunt')
    S.save_cat('ashwick_flashover', flashover_pop(), 'impact')
    S.save_cat('ashwick_cloak_shield', cloak_shield(), 'cast')


if __name__ == '__main__':
    build()
    print('gen_sfx_cinder: done')
