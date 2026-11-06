"""Ryzz the Storm Chaser (mage): every sound her kit plays, synthesised and levelled (docs/AUDIO.md).

    cd tools && python3 gen_sfx_ryzz.py      (then: godot --headless --import)

Ryzz is a street kid with the Wyrm's storm inside her: hot-pink lightning thrown straight from her
hands, copper coils at her wrists, a leather jacket, jewellery, and bubblegum. Her palette is dry
crackling electricity (bright, jittery, never a pure sine), copper, thunder for the big ones, and one
cheeky rubbery pop. Her voice is a young woman's, bright and brash.

  vv_bolt (fire, 3 takes)    the finger bolt: a snap and a jagged crack
  mage_zap (3 takes)         SIGNATURE: the electric zap of a Static stack jumping onto a foe
  mage_bubble_pop            SIGNATURE: her gum popping as she snaps back out of a Wirerun
  vv_static_full             the 4th stack: a sky bolt onto them
  vv_surge_charge / _go      Wirerun: the charge building / the streak
  mage_dash                  the body of the streak (the shared dash slot)
  vv_rod_summon/_full/_throw Storm Rod: appears, fully charged, thrown
  mage_rod_hit               Storm Rod striking a foe
  vv_orb                     a charge orb appearing or bursting
  vv_sky_place/_count/_strike  Skycall: placed, counting down, the strike
  vv_ult_rise/_hum/_slam     Kitefall: launch, hanging in the air, the strike down
  mage_step_<surface>        light boots, bangles, a static tick (3 takes each)
  mage_hurt/down/death       wordless voice

It also writes the kit's vv_* files (content/sfx/mage.json lists them under "replaces"). Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import (N, T, noise, lpf, hpf, bpf, env, mix, at, sat, kick, click, crack, sub, tail,
                     reflections, ring, grains, pad)

S.reseed(7741)


# ------------------------------------------------------------------ shared helpers
def swoosh(d, f0, f1, q=2.0, curve=1.0, shape=1.5):
    """Air pushed aside: noise through a resonant band-pass sweeping f0 -> f1, a smooth swell and fade."""
    n = N(d); u = np.arange(n) / max(1, n - 1)
    f = f0 * (f1 / f0) ** (u ** curve)
    x = noise(d); out = np.empty(n); low = band = 0.0; damp = 1.0 / q
    for k in range(n):
        g = 2.0 * np.sin(np.pi * min(f[k], S.SR / 6.5) / S.SR)
        low += g * band
        band += g * (x[k] - low - damp * band)
        out[k] = band
    return out * np.sin(np.pi * u) ** shape


def soft(x, ms=4.0):
    """A short raised-cosine fade-in, so a layer never starts on a hard edge."""
    k = min(len(x), N(ms / 1000.0))
    x = x.copy(); x[:k] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(k) / max(1, k))
    return x


def fo(x, frac=0.35):
    """A raised-cosine fade over the last `frac` of a layer, so no layer stops on an edge mid-sound."""
    k = max(1, int(len(x) * frac))
    x = x.copy(); x[-k:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(k) / k)
    return x


def crackle(d, rate, lo=1800, hi=6500, cluster=0.6, fall=None):
    """Electric crackle: tiny bright discharges arriving in clusters (a spark jumping, not rain)."""
    n = N(d); out = np.zeros(n); t = 0.0
    while True:
        t += S.rng.exponential(1.0 / rate) * (0.25 if S.rng.random() < cluster else 1.6)
        if t >= d: break
        if fall and S.rng.random() > np.exp(-t / fall): continue
        g = N(S.rng.uniform(0.0006, 0.0025)); s0 = min(N(t), n - g - 1)
        out[s0:s0 + g] += bpf(S.rng.standard_normal(g + 48), lo, hi)[48:] * np.hanning(g) * S.rng.uniform(0.4, 1.0)
    return out


def buzz(d, f, jitter=0.08, bright=4200):
    """An arc's buzz: a saw whose pitch jitters like a bad contact, filtered and driven."""
    n = N(d)
    j = lpf(S.rng.standard_normal(n), 60) * 12 * jitter
    ph = np.cumsum(f * (1 + j)) / S.SR
    saw = 2.0 * (ph % 1.0) - 1.0
    return sat(bpf(saw, 120, bright) * 1.5, 1.8)


# ------------------------------------------------------------------ LMB: the finger bolt
def bolt(i):
    """A finger snap, then a jagged pink bolt cracking out: snap, crack, a short buzzing whip."""
    d = 0.42
    snap = mix(click(0.002, 1800, 6000) * 1.2, bpf(noise(0.03), 1200, 3500) * env(N(0.03), 0.0003, 0.006) * 1.4)
    crk = at(mix(crack(0.2, 1500, 7000, 0.012) * 2.0, crackle(0.25, 260, fall=0.06) * 1.4), 0.008)
    whip = at(sat(bpf(S.sweep(1400 + 80 * i, 220, 0.18, 'saw', 0.6), 200, 5000) * 1.3, 1.6)
              * env(N(0.18), 0.001, 0.05) * 0.5, 0.006)
    hum = at(buzz(0.25, 110 + 6 * i, 0.12) * env(N(0.25), 0.003, 0.07) * 0.25, 0.01)
    punch = at(kick(260, 120, 0.12, 0.006, 0.02, 2.0) * 0.35, 0.008)
    return lpf(pad(mix(soft(snap, 0.5), crk, whip, hum, punch), d), 9500)


# ------------------------------------------------------------------ signatures
def zap(i):
    """The Static stack jumping onto a foe: a tight electric zap with a jittery buzz and sparks."""
    d = 0.32
    core = sat(bpf(S.sweep(2600 + 200 * i, 600, 0.09, 'saw', 0.5), 300, 6000) * 1.5, 1.8) * env(N(0.09), 0.0006, 0.03)
    z = buzz(0.16, 140 + 15 * i, 0.15) * env(N(0.16), 0.002, 0.045) * 0.6
    sparks = crackle(0.28, 140, fall=0.08) * 1.1
    pin = at(ring((3300 + 150 * i,), 0.15, (0.04,), (0.12,)), 0.004)
    return lpf(pad(mix(core, z, sparks, pin), d), 9500)


def bubble_pop():
    """Her gum: a rubbery stretch, a round wet pop, a tiny elastic flap and a fizz of static."""
    d = 0.5
    t = T(0.16)
    stretch = np.sin(2 * np.pi * np.cumsum(260 * (1.9 ** (t / 0.16))) / S.SR) * 0.5
    stretch = mix(stretch, bpf(noise(0.16), 400, 1400) * 0.25) * np.sin(np.pi * np.clip(t / 0.16, 0, 1)) ** 0.8
    stretch = stretch * np.minimum(1, t / 0.05) * 0.35
    pop = mix(kick(1100, 380, 0.06, 0.004, 0.012, 2.2) * 0.9,
              bpf(noise(0.03), 900, 3200) * env(N(0.03), 0.0003, 0.005) * 1.6,
              lpf(click(0.002, 500, 2500), 3000) * 1.0)
    flap = at(kick(240, 130, 0.08, 0.008, 0.018, 1.6) * 0.35, 0.012)
    fizz = at(crackle(0.25, 70, 2500, 6500, fall=0.1) * 0.35, 0.03)
    return pad(mix(soft(stretch, 3), at(mix(pop, flap, fizz), 0.15)), d)


# ------------------------------------------------------------------ passive: the 4th stack
def static_full():
    """A bolt straight out of the sky onto a Live foe: crack, a bright tearing zap, a short thunder."""
    d = 0.9
    crk = mix(click(0.003, 2500, 9000) * 1.8, crack(d, 1200, 7500, 0.01) * 2.2)
    tear = sat(bpf(S.sweep(3200, 300, 0.22, 'saw', 0.5), 200, 6500) * 1.5, 1.8) * env(N(0.22), 0.0006, 0.07)
    sparks = crackle(0.5, 220, fall=0.12) * 1.2
    thunder = mix(kick(150, 50, d, 0.02, 0.1, 2.8) * 0.6, lpf(noise(d), 700) * env(N(d), 0.01, 0.22) * 1.4)
    sparkle = at(fo(S.chime(2637, 0.6, 0.13), 0.5) * 0.18, 0.02)
    return lpf(mix(crk, tear, sparks, thunder, sparkle, sub(60, 38, d, 0.12) * 0.35), 10000)


# ------------------------------------------------------------------ Shift: Wirerun
def surge_charge():
    """The charge building in her: a buzz climbing, crackle thickening, held to the release."""
    d = 0.95; n = N(d); t = T(d)
    rise = S.sweep(90, 300, d, 'saw', 0.7)
    rise = sat(bpf(rise, 100, 3500) * 1.2, 1.6)
    whine = S.sweep(700, 2600, d, curve=0.8) * 0.18
    crk = crackle(d, 60 + 0, 1800, 6500) * (0.3 + 0.7 * t / d) * 0.9
    strike = mix(click(0.002, 2000, 8000) * 1.0, crackle(0.12, 400, fall=0.03) * 1.4)
    shape = np.minimum(1, t / 0.08) * (0.55 + 0.45 * t / d) * np.exp(-np.maximum(0, t - 0.82) / 0.04)
    return mix(soft(strike, 0.5), (rise * 0.6 + whine) * shape + crk * shape)


def surge_go():
    """Let go: a hard crack and she is lightning, a tearing zip falling away."""
    d = 0.6
    crk = mix(click(0.003, 2500, 9000) * 1.8, crack(0.3, 1200, 7000, 0.012) * 2.2)
    zip_ = sat(bpf(S.sweep(3600, 260, 0.4, 'saw', 0.55), 200, 6000) * 1.4, 1.8) * env(N(0.4), 0.0008, 0.12)
    sparks = crackle(0.5, 200, fall=0.15)
    return lpf(mix(crk, zip_ * 0.7, sparks, kick(200, 80, 0.2, 0.01, 0.04, 2.0) * 0.4), 10000)


def dash():
    """The streak's body: an electric whoosh with a hum riding it."""
    d = 0.42
    air = swoosh(d, 600, 3000, 1.6, 0.8)
    hum = buzz(d, 95, 0.1) * np.sin(np.pi * np.linspace(0, 1, N(d))) ** 1.5 * 0.25
    return mix(air, hum, crackle(d, 80, fall=0.15) * 0.4)


# ------------------------------------------------------------------ RMB: Storm Rod
def rod_summon():
    """The copper rod arrives in her hand: a shimmer-pop and a crackle off its tip."""
    d = 0.5
    pop = mix(kick(700, 300, 0.08, 0.006, 0.015, 1.8) * 0.5, crack(0.05, 1500, 5000, 0.006) * 1.2)
    shimmer = fo(S.sweep(800, 2200, 0.25, curve=0.6) * env(N(0.25), 0.01, 0.1)) * 0.25
    copper = fo(ring((1180, 2950, 4730), 0.45, (0.1, 0.05, 0.03), (0.3, 0.12, 0.05)), 0.5)
    return pad(mix(soft(pop, 0.5), shimmer, copper, crackle(0.3, 120, fall=0.1) * 0.6), d)


def rod_full():
    """Fully charged: a clean bright ping over a steady hum."""
    d = 0.9
    ping = fo(S.chime(2349, 0.85, 0.22), 0.5) * 0.7
    hum = fo(buzz(0.6, 120, 0.04, 2500) * env(N(0.6), 0.03, 0.2), 0.5) * 0.25
    return pad(mix(ping, hum, crackle(0.4, 60, fall=0.15) * 0.4), d)


def rod_throw():
    """The rod hurled: a whip crack, a zipping tail and air."""
    d = 0.55
    crk = mix(click(0.002, 2500, 9000) * 1.4, crack(0.12, 1500, 7000, 0.008) * 1.8)
    zip_ = sat(bpf(S.sweep(2400, 500, 0.35, 'saw', 0.7), 200, 6000) * 1.3, 1.7) * env(N(0.35), 0.001, 0.1) * 0.6
    air = swoosh(0.4, 900, 2600, 2.0, 0.8) * 0.7
    return lpf(mix(crk, zip_, air, crackle(0.4, 120, fall=0.1) * 0.6), 9500)


def rod_hit():
    """The rod strikes: a copper clang inside a gold blast of sparks, the foe shoved back."""
    d = 0.8
    hit = mix(click(0.003, 2000, 8000) * 1.6, kick(220, 70, d, 0.012, 0.06, 2.8) * 0.75,
              crack(0.3, 400, 3500, 0.025) * 2.2)
    clang = fo(ring((880, 2390, 3950), 0.7, (0.15, 0.08, 0.04), (0.35, 0.15, 0.06)), 0.5)
    z = sat(bpf(S.sweep(2000, 400, 0.15, 'saw'), 200, 5500) * 1.4, 1.7) * env(N(0.15), 0.0008, 0.05) * 0.5
    return lpf(mix(hit, clang, z, crackle(0.5, 200, fall=0.12) * 0.9, sub(70, 45, 0.4, 0.07) * 0.35), 9500)


def orb():
    """A charge orb: a soft hum-pop with a fizz around it."""
    d = 0.6
    pop = mix(kick(520, 260, 0.1, 0.008, 0.02, 1.6) * 0.6, S.sweep(500, 900, 0.08) * env(N(0.08), 0.003, 0.03) * 0.3)
    hum = fo(buzz(0.5, 220, 0.05, 2200) * env(N(0.5), 0.02, 0.15), 0.5) * 0.3
    glint = at(fo(S.chime(1760, 0.55, 0.12), 0.5) * 0.3, 0.02)
    return pad(mix(soft(pop, 1), hum, glint, crackle(0.5, 70, fall=0.18) * 0.5), d)


# ------------------------------------------------------------------ E: Skycall
def sky_place():
    """The circle dropped: a low tick, a breath of static."""
    d = 0.45
    tick = mix(kick(300, 160, 0.08, 0.004, 0.012, 1.8) * 0.6, click(0.002, 1500, 5000) * 0.7)
    breath = bpf(noise(0.4), 1500, 5000) * env(N(0.4), 0.04, 0.1) * 0.18
    return pad(mix(soft(tick, 0.5), breath, crackle(0.35, 60, fall=0.12) * 0.5), d)


def sky_count():
    """The 0.8 s before the strike: a tone climbing under a gathering crackle and a far rumble."""
    d = 0.82; n = N(d); t = T(d)
    tone = S.sweep(160, 720, d, 'saw', 0.9)
    tone = sat(bpf(tone, 140, 3000), 1.4) * 0.35
    rumble = lpf(noise(d), 220) * 0.9
    crk = crackle(d, 140) * (t / d) ** 1.5
    shape = np.minimum(1, t / 0.15) * (0.4 + 0.6 * t / d) * np.exp(-np.maximum(0, t - 0.78) / 0.02)
    return (tone + rumble + crk) * shape


def sky_strike(i):
    """The strike: a sky-splitting crack, a tearing zap and a thunder roll."""
    d = 1.4
    crk = mix(click(0.004, 2500, 9500) * 2.0, crack(d, 1000, 7500, 0.012) * 2.6)
    tear = sat(bpf(S.sweep(4000 - 200 * i, 250, 0.3, 'saw', 0.5), 200, 6500) * 1.5, 1.8) * env(N(0.3), 0.0006, 0.08)
    body = kick(150 - 8 * i, 42, d, 0.025, 0.12, 3.0) * 0.8
    roll = reflections(fo(tail(1.2, 800, 0.32, 0.01), 0.5) * 1.3, ((0.1, 0.4, 700), (0.22, 0.3, 550), (0.38, 0.2, 450)))
    sparks = crackle(0.8, 240, fall=0.15)
    return lpf(mix(crk, tear * 0.8, body, roll, sparks, sub(56, 32, d, 0.25) * 0.5), 10000)


# ------------------------------------------------------------------ X: Kitefall
def ult_rise():
    """Launching up out of reach: a whoosh climbing, a crackle pulled along under her."""
    d = 0.65
    air = swoosh(d, 400, 3800, 2.2, 0.7, 1.2)
    lift = sat(bpf(S.sweep(120, 520, d, 'saw', 0.8), 120, 3500), 1.4) * env(N(d), 0.02, 0.4) * 0.3
    kickoff = kick(200, 70, 0.25, 0.012, 0.05, 2.4) * 0.5
    return mix(soft(kickoff, 1), air, lift, crackle(d, 150, fall=0.3) * 0.7)


def ult_hum():
    """Hanging in the storm: an electric hum that swells and fades, sparks flickering round it."""
    d = 2.2; n = N(d); t = T(d)
    h1 = buzz(d, 110, 0.05, 2400) * 0.4 + buzz(d, 165.5, 0.05, 2400) * 0.2
    shim = S.sweep(1200, 1500, d) * (0.5 + 0.5 * np.sin(2 * np.pi * 3.3 * t)) * 0.06
    shape = np.minimum(1, t / 0.25) * np.exp(-np.maximum(0, t - 1.5) / 0.3)
    return (h1 + shim + crackle(d, 50) * 0.5) * shape


def ult_slam():
    """The strike down: a sharp crack straight into a deep thunder boom, debris and sparks."""
    d = 2.0; n = N(d)
    crk = mix(click(0.005, 2000, 9500) * 2.2, crack(d, 900, 7000, 0.015) * 2.8)
    tear = sat(bpf(S.sweep(3500, 200, 0.3, 'saw', 0.5), 200, 6500) * 1.5, 1.8) * env(N(0.3), 0.0006, 0.09) * 0.8
    body = kick(130, 34, d, 0.035, 0.16, 3.4) * 0.85
    rumble = lpf(noise(d), 650) * env(n, 0.01, 0.5) * 1.8
    debris = grains(1.2, 70, 1500, 5000, fall=0.3) * 0.7
    roll = reflections(fo(tail(1.6, 800, 0.4, 0.02), 0.5), ((0.12, 0.4, 700), (0.26, 0.3, 550), (0.42, 0.2, 400)))
    return lpf(mix(crk, tear, body, rumble, debris, roll, crackle(1.0, 160, fall=0.25) * 0.7,
                   sub(50, 26, d, 0.4) * 0.6), 9500)


# ------------------------------------------------------------------ footsteps
def footstep(surface, i):
    """A light boot heel then toe; the surface; her bangles on some takes and now and then a static tick."""
    def hit(g):
        if surface == 'grass':
            body = kick(140, 80, 0.1, 0.008, 0.015, 1.5) * 0.4
            tex = mix(lpf(grains(0.1, 450, 800, 3800, 0.001, 0.004, fall=0.03), 4500) * 0.6,
                      fo(bpf(noise(0.09), 300, 1800) * env(N(0.09), 0.003, 0.02)) * 0.5)
        elif surface == 'stone':
            body = kick(200, 110, 0.08, 0.005, 0.01, 1.6) * 0.4
            tex = mix(click(0.002, 2000, 7000) * 0.9, crack(0.05, 900, 4200, 0.006) * 1.0,
                      grains(0.04, 220, 2500, 7000, 0.001, 0.003, fall=0.01) * 0.2)
        elif surface == 'wood':
            body = kick(170, 95, 0.12, 0.006, 0.016, 1.6) * 0.4
            tex = mix(click(0.002, 1500, 5500) * 0.7,
                      fo(ring((215 + 7 * i, 480, 990), 0.14, (0.025, 0.018, 0.012), (0.5, 0.45, 0.25)), 0.5))
        else:
            body = lpf(kick(120, 70, 0.1, 0.008, 0.016, 1.3), 900) * 0.35
            tex = mix(lpf(grains(0.14, 800, 900, 3800, 0.001, 0.003, fall=0.04), 5000) * 0.65,
                      fo(lpf(noise(0.12), 1400) * env(N(0.12), 0.006, 0.03)) * 0.5)
        return mix(soft(body, 1.0), tex) * g
    out = mix(hit(1.0), at(hit(0.4), 0.032 + 0.005 * i))
    if i in (0, 2):
        out = mix(out, at(fo(ring((3520, 4180, 5270), 0.12, (0.03, 0.025, 0.02), (0.06, 0.05, 0.03))), 0.015))
    if i == 3:
        out = mix(out, at(crackle(0.06, 200, 2500, 6000) * 0.12, 0.02))
    return lpf(lpf(pad(out, 0.2), 7000), 9000)


# ------------------------------------------------------------------ voice: a young woman, bright and brash
def hurt(i):
    vowel = ('ah', 'eh', 'uh', 'ah')[i]
    d = 0.18 + 0.025 * (i % 2)
    v = S.voice(d, 330 + 15 * i, 255, vowel, breath=0.3, rasp=0.15, scale=1.2, a=0.007, decay=0.08)
    breath = at(fo(bpf(noise(0.18), 1200, 6000) * env(N(0.18), 0.03, 0.05), 0.6) * 0.06, d * 0.6)
    spark = at(crackle(0.08, 150, 2500, 6000) * 0.06, 0.01)
    return pad(mix(fo(lpf(v, 6000)), breath, spark), 0.36)


def down():
    v = S.voice(0.65, 320, 190, 'ah', breath=0.35, rasp=0.25, vib=0.025, scale=1.18, a=0.015, decay=0.3)
    gasp = at(fo(bpf(noise(0.28), 900, 6000) * env(N(0.28), 0.05, 0.09), 0.6) * 0.08, 0.58)
    fizzle = at(fo(crackle(0.5, 90, 2000, 6000, fall=0.2)) * 0.12, 0.08)
    return pad(mix(fo(lpf(v, 6000), 0.4), gasp, fizzle), 1.05)


def death():
    v = S.voice(0.95, 340, 150, 'oh', breath=0.35, rasp=0.22, vib=0.035, scale=1.18, a=0.012, decay=0.4)
    exhale = at(fo(bpf(noise(0.55), 700, 6000) * env(N(0.55), 0.08, 0.2), 0.6) * 0.07, 0.75)
    die = at(fo(sat(bpf(S.sweep(900, 60, 0.9, 'saw', 0.6), 100, 3000), 1.4) * env(N(0.9), 0.02, 0.35)) * 0.08, 0.1)
    out_ = at(crackle(0.6, 60, 2000, 6000, fall=0.25) * 0.18, 0.2)
    return pad(mix(fo(lpf(v, 6000), 0.4), exhale, die, out_), 1.6)


def build():
    S.takes_cat('vv_bolt', bolt, 3, 'fire')
    S.takes_cat('mage_zap', zap, 3, 'signature')
    S.save_cat('mage_bubble_pop', bubble_pop(), 'signature')
    S.save_cat('vv_static_full', static_full(), 'impact')
    S.save_cat('vv_surge_charge', surge_charge(), 'cast')
    S.save_cat('vv_surge_go', surge_go(), 'cast')
    S.save_cat('mage_dash', dash(), 'dash')
    S.save_cat('vv_rod_summon', rod_summon(), 'cast')
    S.save_cat('vv_rod_full', rod_full(), 'cast')
    S.save_cat('vv_rod_throw', rod_throw(), 'cast')
    S.save_cat('mage_rod_hit', rod_hit(), 'impact')
    S.save_cat('vv_orb', orb(), 'impact')
    S.save_cat('vv_sky_place', sky_place(), 'cast')
    S.save_cat('vv_sky_count', sky_count(), 'cast')
    S.takes_cat('vv_sky_strike', sky_strike, 2, 'impact')
    S.save_cat('vv_ult_rise', ult_rise(), 'cast')
    S.save_cat('vv_ult_hum', ult_hum(), 'loop')
    S.save_cat('vv_ult_slam', ult_slam(), 'impact')
    for surf in ('grass', 'stone', 'wood', 'snow'):
        S.takes_cat('mage_step_' + surf, lambda i, s=surf: footstep(s, i), 3, 'step')
    S.takes_cat('mage_hurt', hurt, 3, 'grunt')
    S.save_cat('mage_down', down(), 'grunt')
    S.save_cat('mage_death', death(), 'grunt')


if __name__ == '__main__':
    build()
    print('gen_sfx_ryzz: done')
