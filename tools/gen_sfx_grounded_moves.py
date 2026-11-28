"""The grounded pass on every Hunter's own steps and dashes (docs/AUDIO.d/1127-grounded-moves.md).

    cd tools && python3 gen_sfx_grounded_moves.py [--out DIR]       (then: godot --headless --import)

Run it AFTER the group scripts (gen_sfx_kael.py, gen_sfx_vex.py, ...) and gen_sfx_dash.py: it rewrites
<arch>_step_<surface>, <arch>_dash and <arch>_dash_air over theirs. --out writes somewhere else (the listening pack).

Same recipe as gen_sfx_grounded.py (wave 1, the shared step0-2 / dash_ground / dash_air): transient + body + tail,
weight in the lower mids, foley not tones, no band above ~4.5 kHz, a light dark room, 4 takes each with their own
layer gains. What changes per Hunter is the body (MASS: how heavy the heel and push-off land, how long the skid
runs) and one bit of gear foley (GEAR: Kael's plate, Vex's holster leather, Grimble's junk). Surfaces keep their
material: grass a soft swish, stone a hard tap and grit, wood a hollow knock, snow a packed crunch.
Kept as ruled: the air dash never touches the ground (no heel, no skid: wind, cloth and the Hunter's own trail),
so it stays distinct from the ground dash. Gil's dashes (he swims) and water_dash are left to their own scripts.
"""

import argparse, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, env, mix, at, lpf, bpf, noise, kick, crack, sub, tail, grains
from gen_sfx_grounded import g, room, air

S.reseed(11271)

# arch -> (mass 0 light .. 1 heavy, gear foley, air-dash trail)
KITS = {
    "gunslinger": (0.45, "leather", None),  # Vex
    "juggernaut": (0.95, "plate", "flame"),  # Kael
    "bulwark": (1.0, "plate", None),
    "dolm": (0.9, "stone", None),
    "dredge": (0.8, "junk", "junk"),
    "ashwick": (0.55, "cloth", None),
    "tender": (0.5, "cloth", None),
    "gil": (0.55, "wet", None),
    "archer": (0.3, "leather", None),
    "thief": (0.2, "cloth", None),
    "mage": (0.3, "cloth", "zap"),
    "rimewright": (0.35, "cloth", "ice"),
    "ostra": (0.3, "cloth", None),
}
NO_STEPS = {"ostra"}  # no step files of her own (falls back to step0-2)
NO_DASH = {"gil"}  # swims: gil_dash / gil_dash_air stay his water sounds
SURFACES = ("grass", "stone", "wood", "snow")


def gear(kind, d, m):
    """One small foley layer the Hunter's kit adds to a step or push-off (kept low and dark)."""
    if kind == "plate":  # plate shifting on plate: a dull clank, no ring
        return at(
            lpf(crack(0.06, 500, 2200, 0.012), 2400) * 0.5 * g() + kick(220, 160, 0.06, 0.004, 0.02, 1.2) * 0.12, 0.012
        )
    if kind == "leather":  # holster and strap creak
        return at(S.creak(0.07, 140, 110, 0.5, 1600) * 0.1 * g(), 0.01)
    if kind == "junk":  # loose scrap knocking
        return at(S.rattle(0.12, 45, 500, 2000, 0.6, 0.06) * 0.25 * g(), 0.008)
    if kind == "stone":  # a stone body settling: low grind
        return at(lpf(grains(0.1, 120, 200, 900, 0.002, 0.006, fall=0.05), 1200) * 0.5 * g(), 0.006)
    if kind == "wet":  # a damp slap
        return at(bpf(noise(0.05), 300, 1400) * env(N(0.05), 0.002, 0.015) * 0.5 * g(), 0.004)
    return at(bpf(noise(0.08), 250, 1600) * env(N(0.08), 0.01, 0.03) * 0.25 * g(), 0.01)  # cloth brush


def step(arch, surf, i):
    m, kind, _ = KITS[arch]
    d = 0.2 + 0.06 * m
    f = (150 - 45 * m) * g(0.94, 1.06)
    heel = kick(f, 70 - 15 * m, 0.09 + 0.05 * m, 0.008, 0.025 + 0.02 * m, 1.5) * (0.14 + 0.2 * m) * g()
    if surf == "grass":
        tex = mix(
            bpf(noise(0.14), 500, 2600) * env(N(0.14), 0.01, 0.05) * 1.3 * g(),
            at(grains(0.1, 50, 900, 2800, 0.001, 0.003, fall=0.04) * 0.25, 0.01),
        )
    elif surf == "stone":
        tex = mix(
            crack(d, 500, 2600, 0.025) * 2.2 * g(), at(grains(0.1, 40, 1000, 3200, 0.001, 0.002, fall=0.04) * 0.3, 0.01)
        )
    elif surf == "wood":
        knock = kick(260 * g(0.92, 1.08), 215, 0.12, 0.002, 0.04, 1.2) * 0.4 * g()
        tex = mix(knock, crack(0.06, 600, 2200, 0.01) * 1.0, at(S.creak(0.1, 130, 100, 0.4, 1200) * 0.1, 0.02))
    else:  # snow: packed crunch
        tex = lpf(grains(0.16, 280, 600, 3000, 0.001, 0.004, fall=0.07), 3200) * 1.1 * g()
    out = mix(heel, tex, gear(kind, d, m))
    # a light courtyard behind every step: short dark reflections plus a soft settling tail
    return lpf(mix(out, room(lpf(out, 1800) * 0.9), at(tail(0.2, 600, 0.06) * (0.06 + 0.04 * m), 0.03)), 4000)


def dash_ground(arch, i):
    m, kind, _ = KITS[arch]
    d = 0.26 + 0.1 * m
    push = kick((135 - 40 * m) * g(0.94, 1.06), 70, 0.12, 0.008, 0.03 + 0.02 * m, 1.6) * (0.25 + 0.3 * m) * g()
    # the skid starts bright on contact and darkens as it slows (never rises: that read as an arcade sweep)
    skid = S.sweep_noise(d, 1700, 450, 0.6, 150, 3200) * S.shape(d, 0.006, d * 0.15, d * 0.8) * 1.2 * g()
    grit = grains(d * 0.5, 110, 600, 2600, 0.001, 0.003, fall=0.06) * 0.3
    cloth = at(air(d * 0.8, 900, 380, 0.03, 0.02, d * 0.6, 0.5, 150, 2000) * 0.35, 0.005)
    out = mix(push, skid, grit, cloth, gear(kind, d, m))
    return lpf(mix(out, room(lpf(out, 1200) * 0.5, 0.7)), 3800)


def trail(kind, d):
    """The Hunter's own motion in the air, kept dark: Kael's flame roar, Grimble's junk, ice flecks, sparks."""
    if kind == "flame":
        return (
            lpf(noise(d), 1400) * S.shape(d, 0.03, d * 0.4, d * 0.5) * 0.9 + S.rattle(d, 50, 600, 2000, 0.5, 0.2) * 0.2
        )
    if kind == "junk":
        return S.rattle(d, 55, 500, 2200, 0.6, 0.2) * 0.35
    if kind == "ice":
        return S.rattle(d, 24, 1800, 4000, 0.5, 0.12) * 0.25
    if kind == "zap":
        return mix(*[at(crack(0.02, 900, 3200, 0.004) * 0.6, float(S.rng.uniform(0.0, d * 0.7))) for _ in range(5)])
    return None


def dash_air(arch, i):
    m, kind, tk = KITS[arch]
    d = 0.32 + 0.06 * m
    wind = air(d, (1300 - 300 * m) * g(0.9, 1.1), 450, 0.03, 0.03, d * 0.75, 0.55, 180, 2800)
    flap = at(S.rattle(0.2, 24 - 8 * m, 450, 2000, 0.5, 0.08) * 0.13, 0.03)
    whump = at(sub(85 - 20 * m, 60 - 15 * m, 0.12, 0.04, 0.01) * (0.12 + 0.15 * m) * g(), 0.0)
    layers = [wind, flap, whump]
    t = trail(tk, d)
    if t is not None:
        layers.append(at(t, 0.02))
    return lpf(mix(*layers), 3600)


def build():
    for arch in KITS:
        if arch not in NO_STEPS:
            for s in SURFACES:
                S.takes_cat("%s_step_%s" % (arch, s), lambda i, a=arch, s=s: step(a, s, i), 3, "step")
        if arch not in NO_DASH:
            S.takes_cat("%s_dash" % arch, lambda i, a=arch: dash_ground(a, i), 3, "dash")
            S.takes_cat("%s_dash_air" % arch, lambda i, a=arch: dash_air(a, i), 2, "dash")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", help="write here instead of audio/ (the listening pack)")
    args = ap.parse_args()
    if args.out:
        os.makedirs(args.out, exist_ok=True)
        S.C.OUT = args.out
    build()
    print("grounded move sfx written")
