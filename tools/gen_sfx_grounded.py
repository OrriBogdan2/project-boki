"""The grounded pass on the eight most-heard sounds (docs/AUDIO.d/1126-grounded-sfx.md): less arcade, more weight.

    cd tools && python3 gen_sfx_grounded.py [--out DIR]       (then: godot --headless --import)

Run it AFTER gen_sfx.py, gen_sfx_vex.py, gen_sfx_kael.py, gen_sfx_hits.py, gen_sfx_glider.py, gen_sfx_dash.py and
gen_sfx_ui.py: it rewrites these names over theirs (they stay for the other sounds in those groups). --out writes
somewhere else (the old-vs-new listening pack) instead of audio/.

Each sound is layered transient + body + tail, weighted into the lower mids (no band above ~6 kHz), with real foley
instead of tones: the crack and the thump of a shot, cloth and air for a swing, boot leather and grit for a step.
Nothing is a pitched sweep or a bell. Every sound has 3-4 takes so a repeat is never the same sample; each take
also draws its own layer gains and timings. Play-time pitch and volume jitter is Sfx.play (docs/AUDIO.md).

  vn_rifle(+_hold)   Vex's rifle        a dull crack on a chest thump, a woody bolt clack, a dark room behind
  juggernaut_blade_hiss  Kael's swing   moved air and a low mass whump with leather grip foley, a faint heat hiss
  hit_gun, hit_blade your hit confirms  a meaty thud with a dry slap; a cloth-rip slice on a thunk, no steel ting
  step0-2            shared footstep    a boot heel on packed earth: low thump, grit, leather
  jump               push-off           scuff, leg thump and an effort breath (it used to rise in pitch)
  glider_snap        glide opens        canopy cloth cracking taut on a low thud of air, then a flutter settling
  dash_ground/air    shared dashes      ground: skid grit + push-off thump; air: wind and cloth only, no ground
  click              UI press           a dry felt-and-wood tick (the old one was a tuned mallet note)
"""

import argparse, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, bpf, noise, kick, click, crack, sub, tail, grains

S.reseed(11261)
HIT_DB = -18.0  # dB RMS: the level of the hit ticks (tools/gen_sfx_hits.py)


def g(lo=0.8, hi=1.2):
    """A take's own layer gain, so the takes differ in balance and not only in noise."""
    return S.rng.uniform(lo, hi)


def room(x, wet=1.0):
    """A light, dark room: reflections that fall off fast and lose their highs (a courtyard, not a hall)."""
    return S.reflections(x, ((0.026, 0.22 * wet, 1500), (0.058, 0.14 * wet, 1100), (0.104, 0.08 * wet, 800)))


def air(d, f0, f1, a, hold, rel, width=0.55, lo=150, hi=3200):
    """Moved air: a band of noise gliding f0 -> f1 under a soft swell."""
    return S.sweep_noise(d, f0, f1, width, lo, hi) * S.shape(d, a, hold, rel)


# ------------------------------------------------------------------ Vex: the rifle
def rifle(i, held=False):
    d = 0.14 if held else 0.34
    rd = 0.014 if held else 0.022
    thump = kick(175 + 14 * i, 64, d, 0.018, 0.018 if held else 0.045, 1.8) * (0.3 if held else 0.5) * g()
    punch = crack(d, 170, 800, rd) * 1.4 * g()
    snap = crack(d, 650, 3300 - 120 * i, 0.009 if held else 0.007) * 2.6 * g()
    tick = click(0.0015, 1500, 5200) * 0.8
    bolt = at(bpf(noise(0.05), 450, 1900) * env(N(0.05), 0.001, 0.009) * 0.5 * g(), 0.015 + 0.002 * i)
    knock = at(kick(250, 130, 0.06, 0.01, 0.012, 1.2) * 0.4 * g(), 0.016)
    wet = 0.5 if held else 1.0
    body = mix(tick, thump, punch, snap, bolt, knock)
    out = mix(body, room(tail(0.08 if held else 0.3, 1100, 0.03 if held else 0.075) * 0.8 * wet))
    if i in (1, 3) and not held:  # a case hitting the ground: soft clinks, not a ring
        out = mix(out, at(grains(0.08, 70, 1600, 3600, 0.001, 0.003, fall=0.03) * 0.1, 0.13))
    return lpf(out, 6000)


def rifle_hold(i):
    return rifle(i, True)


# ------------------------------------------------------------------ Kael: the greatsword swing
def blade_hiss(i):
    swing = air(0.5, 900 * g(0.9, 1.1), 300, 0.15, 0.05, 0.3, 0.6, 120, 3600) * 1.3
    mass = sub(92, 58, 0.45, 0.17, 0.12) * 0.22 * S.shape(0.45, 0.12, 0.05, 0.28) * g()
    grip = bpf(noise(0.14), 500, 2200) * env(N(0.14), 0.02, 0.04) * 0.22 * g()
    edge = at(S.hiss(0.3, 2400, 5200, 0.06, 0.12) * 0.05, 0.05)  # the white-hot blade: a thin heat, well back
    return lpf(mix(swing, mass, grip, edge, room(swing * 0.25)), 5500)


# ------------------------------------------------------------------ your hit confirms
def hit_gun(i):
    d = 0.15
    thud = kick(150 + 10 * i, 68, d, 0.012, 0.025, 1.8) * 0.3 * g()
    slap = crack(d, 400, 2600, 0.016) * 2.6 * g()
    tick = click(0.0015, 1500, 4500) * 0.7
    return lpf(mix(tick, thud, slap, room(tail(0.1, 1000, 0.03) * 0.3)), 5500)


def hit_blade(i):
    d = 0.22
    slice_ = S.soft_in(S.sweep_noise(0.14, 3000, 900, 0.5, 400, 4200) * env(N(0.14), 0.001, 0.035)) * 2.2 * g()
    thunk = kick(132 + 8 * i, 62, d, 0.015, 0.045, 1.6) * 0.6 * g()
    steel = at(crack(0.1, 1300, 3000, 0.02) * 0.45 * g(), 0.004)  # a damped scrape, never a ring
    return lpf(mix(slice_, thunk, steel, room(tail(0.12, 900, 0.035) * 0.3)), 5500)


# ------------------------------------------------------------------ a boot on packed earth
def step(k, i):
    d = 0.16
    heel = kick(105 + 9 * k + 4 * i, 58, d, 0.012, 0.03, 1.5) * 0.55 * g()
    grit = crack(d, 250, 1500, 0.03) * 1.7 * g()
    leather = at(click(0.002, 900, 2800) * 0.3 * g(), 0.004)
    crumbs = at(grains(0.1, 28, 800, 2600, 0.001, 0.003, fall=0.04) * 0.18 * g(), 0.012)
    return lpf(mix(heel, grit, leather, crumbs), 3200)


# ------------------------------------------------------------------ jump
def jump(i):
    scuff = crack(0.1, 200, 1400, 0.03) * 1.2 * g()
    leg = kick(122 + 6 * i, 60, 0.22, 0.02, 0.05, 1.5) * 0.9 * g()
    cloth = at(air(0.22, 520, 900, 0.05, 0.02, 0.15, 0.5, 200, 2200) * 0.8, 0.01)
    effort = at(bpf(noise(0.12), 700, 2400) * env(N(0.12), 0.03, 0.04) * 0.22 * g(), 0.02)
    return lpf(mix(scuff, leg, cloth, effort), 4000)


# ------------------------------------------------------------------ the canopy opens
def glider_snap(i):
    crackle = crack(0.12, 500, 3500, 0.02) * 2.6 * g()
    pull = kick(96 + 5 * i, 55, 0.3, 0.02, 0.07, 1.7) * 0.8 * g()
    fill = at(air(0.4, 520, 1100, 0.08, 0.05, 0.25, 0.5, 200, 2600) * 0.5, 0.035)
    flutter = at(S.rattle(0.35, 26, 600, 2800, 0.5, 0.12) * 0.12, 0.05)
    return lpf(mix(crackle, pull, fill, flutter, room(tail(0.2, 1100, 0.05) * 0.2)), 4500)


# ------------------------------------------------------------------ the shared dashes
def dash_ground(i):
    skid = bpf(noise(0.28), 180, 1600) * S.shape(0.28, 0.01, 0.06, 0.18) * 1.0 * g()
    grit = grains(0.2, 90, 400, 2200, 0.001, 0.003, fall=0.08) * 0.3
    push = kick(115 + 6 * i, 58, 0.2, 0.012, 0.04, 1.6) * 0.9 * g()
    cloth = at(air(0.3, 900, 400, 0.05, 0.03, 0.2, 0.5, 150, 2200) * 0.5, 0.01)
    return lpf(mix(skid, grit, push, cloth), 3800)


def dash_air(i):
    wind = air(0.34, 1000 * g(0.9, 1.1), 450, 0.06, 0.04, 0.22, 0.55, 200, 3000) * 1.0
    flap = at(S.rattle(0.2, 24, 500, 2200, 0.5, 0.08) * 0.12, 0.03)
    whump = sub(75, 55, 0.25, 0.08, 0.02) * 0.45 * g()
    return lpf(mix(wind, flap, whump), 3600)


# ------------------------------------------------------------------ UI
def ui_click(i):
    f = 330 * g(0.94, 1.06)
    tick = bpf(noise(0.06), 1200, 3200) * env(N(0.06), 0.0008, 0.01) * 3.0
    thock = kick(f, 170, 0.07, 0.012, 0.01, 1.3) * 0.3
    return lpf(mix(tick, thock, room(tail(0.05, 1200, 0.015) * 0.1, 0.5)), 3200)


def build():
    S.takes_cat("vn_rifle", rifle, 3, "fire")
    S.takes_hold("vn_rifle_hold", rifle_hold, 3, "fire")
    S.takes_cat("juggernaut_blade_hiss", blade_hiss, 2, "signature")
    S.C.takes("hit_gun", hit_gun, 3, rms_db=HIT_DB, peak_db=S.PEAK_DB)
    S.C.takes("hit_blade", hit_blade, 3, rms_db=HIT_DB, peak_db=S.PEAK_DB)
    for k in range(3):
        S.takes_cat("step%d" % k, lambda i, k=k: step(k, i), 2, "step")
    S.takes_cat("jump", jump, 2, "dash")
    S.takes_cat("glider_snap", glider_snap, 2, "cast")
    S.takes_cat("dash_ground", dash_ground, 2, "dash")
    S.takes_cat("dash_air", dash_air, 2, "dash")
    S.takes_cat("click", ui_click, 3, "ui")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", help="write here instead of audio/ (the listening pack)")
    args = ap.parse_args()
    if args.out:
        os.makedirs(args.out, exist_ok=True)
        S.C.OUT = args.out
    build()
    print("grounded sfx written")
