"""The terrain hazards' sounds (docs/AUDIO.md, content/sfx/hazards.json, played by scripts/match/hazard_sfx.gd).

    cd tools && python3 gen_sfx_hazards.py      (then: godot --headless --import)

  hazard_bed_lava       loop: a low churning rumble with thick bubbles popping and the odd crack
  hazard_bed_water      loop: a river running: broad wash, small gurgles
  hazard_bed_ice        loop: thin cold air over the sheet, the ice ticking and groaning now and then
  hazard_bed_static     loop: a dry electric hum that wavers, sparse fizzing ticks
  hazard_bed_bramble    loop: twigs and leaves stirring, a faint insect whirr
  hazard_lava_burn      (3 takes) a short sizzle at your feet: the burn ticking
  hazard_wade           (3 takes) a heavy slosh: wading where you can't swim (also the splash going in)
  hazard_swim           (3 takes) a light stroke through the water: swimming with a Boki or perk that can
  hazard_breath         a tight gasp and a low throb: breath running out, drowning is close
  hazard_ice_skid       (3 takes) a scraping slide on ice
  hazard_static_crackle (3 takes) the ground's shock going through you: a snap and a fizz
  hazard_bramble_snag   (3 takes) thorns catching: a twig rasp and a little tear
  hazard_warded         a soft two-note shimmer: your Boki or perk keeps this ground off you (first time)
Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import (N, T, noise, lpf, hpf, bpf, env, mix, at, crack, grains, shape, soft_in, sub, tail,
                     chime, creak, hiss, voice, pad)

S.reseed(6113)
BED_S = 4.0          # s: one pass of a bed before it repeats


def wobble(d, rate, depth):
    """A smooth random level around 1, `rate` new values a second."""
    pts = max(4, int(d * rate) + 3)
    x = np.interp(np.arange(N(d)) / S.SR * rate, np.arange(pts), S.rng.standard_normal(pts))
    return np.clip(1.0 + depth * lpf(x, 40) / (np.std(x) + 1e-9), 0.1, None)


def scatter(d, count, make):
    """`count` copies of make(i) dropped at random times over d (kept inside it, so the loop seam is clean)."""
    out = np.zeros(N(d))
    for i in range(count):
        x = make(i)
        s0 = int(S.rng.uniform(N(0.1), max(N(0.1) + 1, N(d) - len(x) - N(0.1))))
        out[s0:s0 + len(x)] += x
    return out


# ------------------------------------------------------------------ beds
def bubble(_i):
    d = S.rng.uniform(0.08, 0.16)
    f0 = S.rng.uniform(140, 260)
    t = T(d)
    return np.sin(2 * np.pi * np.cumsum(f0 * (1 + 2.5 * t / d)) / S.SR) * env(N(d), 0.004, d * 0.4) * S.rng.uniform(0.4, 1.0)


def bed_lava():
    d = BED_S
    rumble = lpf(noise(d), 110) * wobble(d, 2, 0.35) * 2.2
    churn = bpf(noise(d), 120, 420) * wobble(d, 4, 0.5) * 0.35
    pops = scatter(d, 14, bubble) * 0.5
    cracks = scatter(d, 3, lambda i: crack(0.08, 900, 4000, 0.012) * 0.25)
    return mix(rumble, churn, pops, cracks)


def gurgle(_i):
    d = S.rng.uniform(0.05, 0.1)
    f0 = S.rng.uniform(500, 1100)
    t = T(d)
    return np.sin(2 * np.pi * np.cumsum(f0 * (1 + 1.2 * t / d)) / S.SR) * env(N(d), 0.003, d * 0.35) * S.rng.uniform(0.2, 0.6)


def bed_water():
    d = BED_S
    wash = bpf(noise(d), 250, 2200) * wobble(d, 3, 0.3)
    low = lpf(noise(d), 250) * wobble(d, 1.5, 0.3) * 0.8
    return mix(wash, low, scatter(d, 22, gurgle) * 0.35)


def ice_tick(_i):
    return crack(0.03, 2500, 9000, 0.004) * S.rng.uniform(0.3, 0.8)


def bed_ice():
    d = BED_S
    air = bpf(noise(d), 1800, 6000) * wobble(d, 2, 0.4) * 0.5
    low = lpf(noise(d), 180) * 0.25
    groan = pad(creak(1.2, 70, 48, 0.3, 700) * 0.6, d)
    groan = np.roll(groan, N(1.3))
    return mix(air, low, groan, scatter(d, 9, ice_tick) * 0.6)


def bed_static():
    d = BED_S
    t = T(d)
    hum = (np.sin(2 * np.pi * 75 * t) + 0.5 * np.sin(2 * np.pi * 150 * t + 0.4) + 0.25 * np.sin(2 * np.pi * 225 * t))
    hum = hum * wobble(d, 3, 0.25) * 0.35
    buzz = bpf(np.sign(np.sin(2 * np.pi * 75 * t)) * noise(d) * 0.4, 600, 3000) * wobble(d, 6, 0.6) * 0.25
    fizz = scatter(d, 8, lambda i: grains(0.12, 220, 2500, 9000, 0.001, 0.004) * 0.5)
    return mix(hum, buzz, fizz)


def twig(_i):
    return crack(0.04, 1500, 6000, 0.008) * S.rng.uniform(0.2, 0.5)


def bed_bramble():
    d = BED_S
    leaves = bpf(noise(d), 1200, 4500) * wobble(d, 2.5, 0.6) * 0.35
    t = T(d)
    whirr = np.sin(2 * np.pi * 2900 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 28 * t)) * wobble(d, 1, 0.5) * 0.03
    low = lpf(noise(d), 200) * 0.2
    return mix(leaves, whirr, low, scatter(d, 10, twig))


# ------------------------------------------------------------------ contact cues
def burn(_i):
    d = 0.32
    sizzle = hiss(d, 2200, 9000, 0.004, 0.12) * 0.9
    spit = grains(d, 60, 1500, 6000, 0.001, 0.004, 0.08) * 0.6
    thump = sub(90, 60, 0.12, 0.05) * 0.4
    return soft_in(mix(sizzle, spit, thump), 1.0)


def wade(_i):
    d = 0.42
    slosh = lpf(bpf(noise(d), 200, 1800), 1600) * env(N(d), 0.03, 0.14) * 1.2
    drops = at(grains(0.3, 50, 900, 4000, 0.003, 0.009, 0.1) * 0.5, 0.06)
    plunge = sub(110, 70, 0.15, 0.06) * 0.35
    return soft_in(mix(slosh, drops, plunge), 1.0)


def swim(_i):
    d = 0.32
    stroke = bpf(noise(d), 500, 2600) * shape(d, 0.08, 0.04, 0.18) * 0.8
    drips = at(grains(0.22, 40, 1500, 5000, 0.002, 0.006, 0.08) * 0.4, 0.1)
    return soft_in(mix(stroke, drips), 1.0)


def breath():
    gasp = voice(0.38, 300, 360, 'ah', breath=0.9, rasp=0.15, a=0.03)
    throb = mix(sub(70, 55, 0.45, 0.08), at(sub(70, 55, 0.45, 0.08) * 0.7, 0.32)) * 0.8
    return soft_in(mix(gasp * 0.8, at(throb, 0.3)), 1.0)


def skid(_i):
    d = 0.5
    scrape = bpf(noise(d), 2500, 8000) * shape(d, 0.02, 0.18, 0.28) * wobble(d, 25, 0.5) * 0.7
    body = bpf(noise(d), 400, 1200) * shape(d, 0.02, 0.1, 0.3) * 0.4
    return soft_in(mix(scrape, body), 1.0)


def crackle(_i):
    d = 0.4
    snap = crack(0.05, 1800, 9000, 0.008) * 1.2
    fizz = grains(d, 160, 2500, 9000, 0.001, 0.004, 0.12) * 0.8
    t = T(d)
    zz = bpf(np.sign(np.sin(2 * np.pi * 110 * t)) * noise(d), 800, 4000) * env(N(d), 0.002, 0.08) * 0.35
    return soft_in(mix(snap, fizz, zz), 0.5)


def snag(_i):
    d = 0.3
    rasp = bpf(noise(d), 1500, 6000) * shape(d, 0.01, 0.05, 0.15) * wobble(d, 60, 0.7) * 0.6
    tear = at(crack(0.06, 1000, 5000, 0.015) * 0.7, 0.08)
    twigs = grains(0.2, 50, 1200, 4500, 0.002, 0.006, 0.06) * 0.4
    return soft_in(mix(rasp, tear, twigs), 1.0)


def warded():
    d = 1.0
    a = chime(880, d, 0.4) * 0.5
    b = at(chime(1320, d - 0.12, 0.45) * 0.45, 0.12)
    air = hiss(d, 3000, 9000, 0.1, 0.3) * 0.06
    return soft_in(mix(a, b, air), 2.0)


def build():
    for name, fn in [('lava', bed_lava), ('water', bed_water), ('ice', bed_ice), ('static', bed_static),
                     ('bramble', bed_bramble)]:
        S.save_loop('hazard_bed_' + name, fn(), 'loop')
    S.takes_cat('hazard_lava_burn', burn, 3, 'dash')
    S.takes_cat('hazard_wade', wade, 3, 'dash')
    S.takes_cat('hazard_swim', swim, 3, 'dash')
    S.save_cat('hazard_breath', breath(), 'grunt')
    S.takes_cat('hazard_ice_skid', skid, 3, 'dash')
    S.takes_cat('hazard_static_crackle', crackle, 3, 'impact')
    S.takes_cat('hazard_bramble_snag', snag, 3, 'dash')
    S.save_cat('hazard_warded', warded(), 'ui')


if __name__ == '__main__':
    build()
    print('gen_sfx_hazards: done')
