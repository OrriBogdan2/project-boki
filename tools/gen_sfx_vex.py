"""Vex the Hired Gun (gunslinger): every sound her kit plays, synthesised and levelled (docs/AUDIO.md).

    cd tools && python3 gen_sfx_vex.py      (then: godot --headless --import)

Vex is a foundry kid with a siege engine's rotary cannon bolted to her shoulder: her palette is brass,
oiled steel, servo motors and ember-hot rounds. Her voice is an adult woman's, low and clipped (calm
under fire), with a faint servo under the bad moments.

  vn_rifle (fire, 3 takes)   the rotary cannon's round: crack, punch, bolt clack, brass
  gunslinger_spinup          SIGNATURE: the barrels winding up as a string starts
  gunslinger_grenade_thunk   SIGNATURE: the Burr Charge biting into a wall or the ground, its fuse armed
  vn_cock / vn_throw         Burr Charge armed in the hand / the side toss
  vn_blast (3 takes)         the charge's blast (direct hit and the cone)
  vn_slide, gunslinger_dash  Slipstep: the boot scrape / the body's whoosh and servo
  vn_stim                    Hot Streak: a knock gives Slipstep back
  vn_ion_charge / _fire      Longneedle: the capacitor whine / the beam
  vn_nuke_fire/_fall/_boom/_burn   Cinderfall: mortar thunk, whistle, impact, the burning patch
  gunslinger_step_<surface>  boots with a bandolier's jingle (3 takes each)
  gunslinger_hurt/down/death wordless voice

It also writes the kit's vn_* files (content/sfx/gunslinger.json lists them under "replaces"). Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import (N, T, noise, lpf, hpf, bpf, env, mix, at, sat, kick, click, crack, sub, tail,
                     reflections, ring, grains, pad)

S.reseed(5150)


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


def servo(d, f0, f1, a=0.01, decay=None, buzz=0.35):
    """A small motor: a gliding saw (soft-filtered) with a gear-tooth buzz riding on it."""
    tone = lpf(S.sweep(f0, f1, d, 'saw'), 2600) * 0.6 + S.sweep(f0 * 2, f1 * 2, d) * 0.25
    teeth = np.sign(S.sweep(f0 * 0.25, f1 * 0.25, d)) * buzz
    return (tone + lpf(teeth, 1800) * 0.3) * env(N(d), a, decay if decay else d)


def brass(d=0.35, f=3100, g=1.0):
    """A spent casing ringing on stone: a couple of short inharmonic bounces."""
    out = np.zeros(N(d))
    for k, (dl, amp) in enumerate(((0.0, 1.0), (0.07, 0.55), (0.12, 0.3))):
        c = ring((f * (1 + 0.02 * k), f * 2.71, f * 4.1), 0.12, (0.035, 0.02, 0.012), (0.6, 0.25, 0.1))
        out = mix(out, at(c * amp, dl))
    return pad(out, d)[:N(d)] * g


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


# ------------------------------------------------------------------ LMB: the rotary cannon
def rifle(i):
    d = 0.3
    punch = kick(330 + 15 * i, 105, d, 0.006, 0.018, 2.6) * 0.55
    snap = crack(d, 1100, 4800 + 200 * i, 0.009) * 2.2
    mid = crack(d, 260, 1100, 0.016) * 1.8
    clack = at(ring((1650 + 40 * i, 2480, 3900), 0.06, (0.012, 0.008, 0.005), (0.35, 0.2, 0.08)), 0.012)
    body = mix(click(0.002, 2500, 7500) * 1.2, punch, snap, mid, clack)
    room = reflections(tail(0.2, 1900, 0.04) * 0.7, ((0.035, 0.3, 1600), (0.07, 0.18, 1100), (0.11, 0.1, 800)))
    out = mix(body, room)
    if i in (1, 3):
        out = mix(out, at(brass(0.22, 2900 + 300 * i, 0.07), 0.09))
    return lpf(out, 9000)


def spinup():
    """The barrels winding up: a motor whine climbing, the barrel teeth rattling faster, a clunk to engage."""
    d = 0.6; n = N(d); t = T(d)
    whine = S.sweep(110, 720, d, 'saw', curve=0.6)
    whine = lpf(whine, 3200) * np.minimum(1.0, t / 0.08) * np.exp(-np.maximum(0, t - 0.45) / 0.06)
    # the barrel cluster's teeth: clicks whose rate climbs from 12 to 90 per second
    rate = 12 * (90 / 12) ** (t / d) ** 0.7
    ph = np.cumsum(rate) / S.SR
    ticks = (np.diff(np.floor(ph), prepend=0) > 0).astype(float)
    teeth = bpf(ticks, 900, 4200) * 3.0 * np.exp(-np.maximum(0, t - 0.48) / 0.05)
    teeth = mix(teeth, lpf(ticks, 600) * 2.0 * np.exp(-np.maximum(0, t - 0.48) / 0.05))
    hum = S.sweep(55, 110, d) * env(n, 0.05, 0.4) * 0.4
    engage = mix(kick(180, 90, 0.12, 0.01, 0.03, 2.0) * 0.6, crack(0.08, 600, 2600, 0.01) * 0.8,
                 ring((1240, 1980), 0.1, (0.03, 0.02), (0.25, 0.12)))
    air = bpf(noise(d), 1500, 5000) * np.minimum(1, t / 0.4) * np.exp(-np.maximum(0, t - 0.48) / 0.05) * 0.15
    return mix(soft(engage, 1.5), whine * 0.5, teeth * 0.45, hum, air)


# ------------------------------------------------------------------ RMB: Burr Charge
def grenade_thunk():
    """The spiked charge bites into a wall: a hollow steel thunk, the spikes' tick, then the fuse arms."""
    d = 0.85
    thunk = mix(kick(170, 70, 0.35, 0.012, 0.05, 2.8) * 0.8, crack(0.2, 180, 900, 0.03) * 2.0,
                bpf(noise(0.25), 280, 520) * env(N(0.25), 0.001, 0.05) * 1.6)
    shell = ring((410, 1093, 1780), 0.35, (0.09, 0.05, 0.03), (0.35, 0.18, 0.08))
    spikes = at(ring((2650, 3720), 0.12, (0.03, 0.02), (0.18, 0.08)), 0.004)
    arm = mix(at(click(0.002, 1800, 6000) * 0.5, 0.22), at(click(0.002, 1800, 6000) * 0.4, 0.29))
    fuse = at(S.hiss(0.55, 2200, 6000, 0.03, 0.25) * 0.25, 0.25)
    beep = at(S.chime(1760, 0.2, 0.06, ((1.0, 1.0), (2.0, 0.2))) * 0.18, 0.3)
    return mix(soft(thunk, 1.0), shell, spikes, arm, fuse, beep, sub(70, 50, 0.3, 0.06) * 0.35)


def cock():
    """Arming the charge in the hand: a pin snap, a spring, a little ember catching."""
    d = 0.4
    snap = mix(click(0.002, 2000, 7000) * 1.0, ring((2350, 3540), 0.1, (0.02, 0.012), (0.3, 0.12)))
    spring = at(S.sweep(900, 1500, 0.06) * env(N(0.06), 0.002, 0.02) * 0.18, 0.05)
    latch = at(mix(click(0.002, 1500, 5000) * 0.9, kick(400, 220, 0.05, 0.004, 0.01, 1.5) * 0.3), 0.1)
    ember = at(S.hiss(0.25, 1800, 5500, 0.03, 0.1) * 0.35, 0.11)
    return pad(mix(snap, spring, latch, ember), d)


def throw():
    """The low side toss: a quick swoosh, the scarf's flap and the charge's spikes catching air."""
    d = 0.32
    air = swoosh(d, 350, 2400, 1.8, 0.8)
    cloth = bpf(noise(d), 200, 900) * np.sin(np.pi * np.linspace(0, 1, N(d))) ** 3 * 0.5
    grunt = at(lpf(S.voice(0.1, 260, 210, 'uh', breath=0.6, scale=1.12), 2500) * 0.12, 0.01)
    return mix(air, cloth, grunt)


def blast(i):
    """The cone blast: a hard bang, a shove of air, spike shrapnel rattling."""
    d = 0.95
    bang = mix(click(0.004, 1500, 7500) * 1.6, crack(d, 450, 4200 + 200 * i, 0.025) * 2.6,
               kick(150 + 10 * i, 45, d, 0.025, 0.09, 3.0) * 0.8)
    roar = bpf(noise(d), 180, 2200) * env(N(d), 0.004, 0.14) * 1.8
    rumble = lpf(noise(d), 500) * env(N(d), 0.008, 0.28) * 1.6
    shrap = grains(0.7, 140, 2200, 6000, 0.002, 0.006, fall=0.12) * 0.5
    ting = at(ring((3150 + 120 * i, 4420), 0.3, (0.05, 0.03), (0.12, 0.05)), 0.03)
    return lpf(mix(bang, roar, rumble, shrap, ting, sub(60, 34, d, 0.18) * 0.5), 9500)


# ------------------------------------------------------------------ Shift: Slipstep
def slide():
    """A low slide on boots and a knee plate: a gritty scrape that rises and wears out."""
    d = 0.6; n = N(d); t = T(d)
    grit = bpf(noise(d), 300, 2600) * (0.75 + 0.25 * np.abs(S.rng.standard_normal(n)) ** 1.5)
    grit = lpf(grit, 4000)
    shape = np.minimum(1, t / 0.03) * np.exp(-t / 0.28)
    plate = bpf(noise(d), 2300, 3400) * (0.6 + 0.4 * np.sin(2 * np.pi * 37 * t)) * 0.18
    rumble = lpf(noise(d), 260) * 0.8
    stones = grains(d, 70, 1500, 5000, 0.002, 0.006, fall=0.25) * 0.4
    return mix((grit + plate + rumble) * shape, stones)


def dash():
    """Her body's push: a short whoosh and the shoulder cannon's servo bracing."""
    d = 0.38
    return mix(swoosh(d, 500, 1900, 1.6, 0.7) * 1.0, servo(0.22, 260, 520, 0.02, 0.09) * 0.12,
               at(ring((1880, 2930), 0.12, (0.025, 0.015), (0.1, 0.05)), 0.05))


def stim():
    """Hot Streak: a fast cannon cycle-clack, then a bright brass two-note as the slide comes back."""
    d = 1.05
    clack = mix(click(0.002, 1800, 6000) * 0.9, kick(380, 200, 0.06, 0.004, 0.012, 1.6) * 0.4,
                ring((1540, 2310), 0.08, (0.02, 0.012), (0.25, 0.1)))
    n1 = at(S.chime(1318, 0.8, 0.14) * 0.5, 0.06)
    n2 = at(S.chime(1975, 0.9, 0.16) * 0.55, 0.13)
    whirr = at(servo(0.12, 400, 900, 0.01, 0.05) * 0.1, 0.0)
    return pad(mix(clack, whirr, n1, n2), d)


# ------------------------------------------------------------------ E: Longneedle
def ion_charge():
    """The beam's capacitor: a whine climbing to a held edge, a hum, crackle thickening."""
    d = 0.68; n = N(d); t = T(d)
    whine = S.sweep(240, 2100, d, curve=0.8) * 0.45 + S.sweep(480, 4200, d, curve=0.8) * 0.08
    hum = lpf(S.sweep(70, 140, d, 'saw'), 700) * 0.4
    crk = lpf(grains(d, 160, 2000, 6500, 0.001, 0.003), 6000) * (t / d) ** 2 * 0.6
    shape = np.minimum(1, t / 0.12) ** 1.5 * (0.5 + 0.5 * t / d)
    shape *= np.exp(-np.maximum(0, t - 0.62) / 0.02)
    return (whine + hum) * shape + crk * shape


def ion_fire():
    """The Longneedle lets go: a hard crack, a deep kick and recoil, a beam that roars and thins."""
    d = 1.15
    crk = mix(click(0.004, 2500, 8500) * 1.8, crack(d, 900, 6000, 0.012) * 2.4)
    body = kick(190, 48, d, 0.02, 0.11, 3.0) * 0.8
    beam = (lpf(S.sweep(220, 150, d, 'saw'), 2400) * 0.35 + S.fm(110, 2.01, 3.0, d, 0.25) * 0.25)
    beam = beam * env(N(d), 0.004, 0.32)
    roar = bpf(noise(d), 300, 4500) * env(N(d), 0.003, 0.18) * 1.5
    room = reflections(tail(0.8, 1300, 0.2, 0.01) * 1.1, ((0.07, 0.35, 1100), (0.15, 0.25, 800), (0.26, 0.14, 600)))
    return lpf(mix(crk, body, beam, roar, room, sub(58, 36, d, 0.2) * 0.5), 10000)


# ------------------------------------------------------------------ X: Cinderfall
def nuke_fire():
    """The shell leaves straight up: a hollow mortar thunk and a hiss climbing away."""
    d = 0.9
    thunk = mix(kick(140, 48, d, 0.02, 0.08, 3.0) * 0.85, bpf(noise(0.35), 160, 420) * env(N(0.35), 0.001, 0.07) * 2.0,
                crack(0.2, 400, 2500, 0.02) * 1.6, sub(62, 40, 0.5, 0.1) * 0.5)
    tube = ring((260, 610), 0.4, (0.1, 0.05), (0.3, 0.12))
    climb = at(swoosh(0.7, 700, 4200, 2.5, 0.6, 1.2) * 0.7, 0.04)
    return mix(soft(thunk, 1.0), tube, climb)


def nuke_fall():
    """The shell coming down over 1.6 s: a whistle dropping in pitch, the air thickening under it."""
    d = 1.62; n = N(d); t = T(d)
    f = 1900 * (650 / 1900) ** (t / d) * (1 + 0.006 * np.sin(2 * np.pi * 7 * t))
    tone = np.sin(2 * np.pi * np.cumsum(f) / S.SR)
    air = bpf(noise(d), 600, 2600) * 0.35
    shape = np.minimum(1, t / 0.4) ** 2 * (0.35 + 0.65 * (t / d) ** 1.5)
    return (tone * 0.6 + air) * shape


def nuke_boom():
    """Cinderfall lands: a deep crack and boom, a rolling rumble and burning debris."""
    d = 2.2; n = N(d)
    crk = mix(click(0.006, 1500, 8000) * 2.0, crack(d, 400, 4800, 0.03) * 2.8)
    body = kick(120, 34, d, 0.04, 0.18, 3.5) * 0.85
    roar = bpf(noise(d), 160, 2400) * env(n, 0.005, 0.2) * 2.0
    rumble = lpf(noise(d), 700) * env(n, 0.01, 0.55) * 1.8
    debris = grains(d, 80, 1500, 5500, fall=0.4) * 0.8
    roll = reflections(tail(1.6, 900, 0.4, 0.02) * 1.0, ((0.11, 0.4, 800), (0.24, 0.3, 600), (0.4, 0.2, 450)))
    return lpf(mix(crk, body, roar, rumble, debris, roll, sub(52, 26, d, 0.4) * 0.65), 9000)


def nuke_burn():
    """The burning patch: a low fire bed and crackling embers that die away over three seconds."""
    d = 3.1; n = N(d); t = T(d)
    bed = lpf(noise(d), 900) * (0.7 + 0.3 * lpf(np.abs(S.rng.standard_normal(n)), 6) * 4)
    pops = lpf(grains(d, 45, 800, 4500, 0.002, 0.007), 5000) * 1.2
    hisss = bpf(noise(d), 2500, 5500) * 0.08
    shape = np.minimum(1, t / 0.12) * np.exp(-t / 1.4)
    return (bed * 0.8 + pops + hisss) * shape


# ------------------------------------------------------------------ footsteps
def footstep(surface, i):
    """A medium boot heel then toe; the surface's texture; a bandolier's faint jingle on some takes."""
    def hit(g):
        if surface == 'grass':
            body = kick(120, 70, 0.12, 0.01, 0.02, 1.6) * 0.5
            tex = lpf(grains(0.12, 500, 700, 3600, 0.001, 0.004, fall=0.035), 4500) * 0.6
            tex = mix(tex, fo(bpf(noise(0.1), 300, 1800) * env(N(0.1), 0.003, 0.025)) * 0.6)
        elif surface == 'stone':
            body = kick(170, 90, 0.1, 0.006, 0.014, 1.8) * 0.5
            tex = mix(click(0.002, 1800, 6500) * 0.9, crack(0.06, 700, 3800, 0.008) * 1.1,
                      grains(0.05, 260, 2500, 7000, 0.001, 0.003, fall=0.012) * 0.25)
        elif surface == 'wood':
            body = kick(150, 85, 0.14, 0.008, 0.02, 1.7) * 0.5
            tex = mix(click(0.002, 1500, 5000) * 0.6,
                      fo(ring((185 + 6 * i, 420, 880), 0.16, (0.03, 0.022, 0.014), (0.55, 0.45, 0.25)), 0.5))
        else:
            body = lpf(kick(110, 65, 0.12, 0.01, 0.02, 1.4), 900) * 0.45
            tex = lpf(grains(0.17, 900, 900, 3800, 0.001, 0.003, fall=0.05), 5000) * 0.7
            tex = mix(tex, fo(lpf(noise(0.15), 1400) * env(N(0.15), 0.006, 0.04)) * 0.6)
        return mix(soft(body, 1.0), tex) * g
    heel = hit(1.0)
    toe = hit(0.45)
    out = mix(heel, at(toe, 0.04 + 0.006 * i))
    if i in (1, 3):
        out = mix(out, at(S.rattle(0.08, 50, 2400, 4800, decay=0.025) * 0.12, 0.02))
    return lpf(lpf(pad(out, 0.24), 7000), 9000)


# ------------------------------------------------------------------ voice: an adult woman, low and clipped
def hurt(i):
    vowel = ('uh', 'ah', 'eh', 'uh')[i]
    d = 0.2 + 0.03 * (i % 2)
    v = S.voice(d, 245 + 12 * i, 185, vowel, breath=0.3, rasp=0.18, scale=1.12, a=0.008, decay=0.09)
    breath = at(fo(bpf(noise(0.2), 1200, 6000) * env(N(0.2), 0.03, 0.06), 0.6) * 0.06, d * 0.6)
    gear = at(ring((2140, 3310), 0.1, (0.02, 0.012), (0.05, 0.02)), 0.01)
    return pad(mix(fo(lpf(v, 5500)), breath, gear), 0.4)


def down():
    v = S.voice(0.7, 235, 140, 'ah', breath=0.35, rasp=0.3, vib=0.02, scale=1.1, a=0.02, decay=0.32)
    gasp = at(fo(bpf(noise(0.3), 900, 6000) * env(N(0.3), 0.06, 0.1), 0.6) * 0.08, 0.62)
    sag = at(servo(0.55, 700, 180, 0.03, 0.25) * 0.06, 0.1)
    return pad(mix(fo(lpf(v, 5500), 0.4), gasp, fo(sag)), 1.15)


def death():
    v = S.voice(1.0, 250, 115, 'oh', breath=0.35, rasp=0.25, vib=0.03, scale=1.1, a=0.015, decay=0.42)
    exhale = at(fo(bpf(noise(0.6), 700, 6000) * env(N(0.6), 0.08, 0.22), 0.6) * 0.07, 0.8)
    wind = at(servo(1.1, 900, 70, 0.02, 0.5) * 0.09, 0.15)
    sputter = at(lpf(grains(0.5, 30, 900, 3500, 0.002, 0.006), 4000) * 0.25, 0.55)
    return pad(mix(fo(lpf(v, 5500), 0.4), exhale, fo(wind), sputter), 1.8)


def build():
    S.takes_cat('vn_rifle', rifle, 3, 'fire')
    S.save_cat('gunslinger_spinup', spinup(), 'signature')
    S.save_cat('gunslinger_grenade_thunk', grenade_thunk(), 'signature')
    S.save_cat('vn_cock', cock(), 'cast')
    S.save_cat('vn_throw', throw(), 'cast')
    S.takes_cat('vn_blast', blast, 3, 'impact')
    S.save_cat('vn_slide', slide(), 'dash')
    S.save_cat('gunslinger_dash', dash(), 'dash')
    S.save_cat('vn_stim', stim(), 'cast')
    S.save_cat('vn_ion_charge', ion_charge(), 'cast')
    S.save_cat('vn_ion_fire', ion_fire(), 'impact')
    S.save_cat('vn_nuke_fire', nuke_fire(), 'cast')
    S.save_cat('vn_nuke_fall', nuke_fall(), 'cast')
    S.save_cat('vn_nuke_boom', nuke_boom(), 'impact')
    S.save_cat('vn_nuke_burn', nuke_burn(), 'loop')
    for surf in ('grass', 'stone', 'wood', 'snow'):
        S.takes_cat('gunslinger_step_' + surf, lambda i, s=surf: footstep(s, i), 3, 'step')
    S.takes_cat('gunslinger_hurt', hurt, 3, 'grunt')
    S.save_cat('gunslinger_down', down(), 'grunt')
    S.save_cat('gunslinger_death', death(), 'grunt')


if __name__ == '__main__':
    build()
    print('gen_sfx_vex: done')
