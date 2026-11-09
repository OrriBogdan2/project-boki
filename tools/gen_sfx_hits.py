"""Every Hunter's basic-attack hit sounds, synthesised and levelled (docs/AUDIO.md).

    cd tools && python3 gen_sfx_hits.py      (then: godot --headless --import)

Two sounds per Hunter, 3 takes each (Sfx picks a take; the call site adds a little pitch variation):
  <arch>_hit    hit confirm, heard by the attacker: bright and forward, the transient first, so a landed
                hit reads at once (a crack, a bite, a knock, a zap, per weapon)
  <arch>_taken  damage taken, heard by the victim from that attacker's weapon: the same material but
                low, dull and body-first, a thump that says "that one hurt" without matching the confirm
Each Hunter's palette lives in HUNTERS below. Original synthesis, no samples.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_lib as S
from sfx_lib import N, noise, lpf, hpf, bpf, env, mix, at, sat, kick, crack, sub, tail, ring, pad

S.reseed(1109)

# arch: cat, snap band (Hz), body (f0, f1, decay s), ring partials (Hz, empty = none), grit (0..1 noise tail), zap (0..1)
HUNTERS = {
    "gunslinger": ("heavy_impact", (3000, 9000), (190, 85, 0.05), (2300, 3900), 0.2, 0.0),    # Vex: bullet tick, steel ping
    "archer": ("impact", (2500, 8000), (260, 120, 0.04), (1700, 2900), 0.1, 0.0),             # Lace: arrow thwip and thunk
    "juggernaut": ("heavy_impact", (1200, 6000), (120, 55, 0.09), (), 0.55, 0.0),             # Kael: greatsword bite
    "bulwark": ("heavy_impact", (900, 4500), (95, 48, 0.12), (420, 1130), 0.15, 0.0),         # Mossy: hammer clang
    "mage": ("impact", (3500, 10000), (230, 110, 0.04), (), 0.1, 1.0),                        # Sparkle: bolt crackle
    "ashwick": ("impact", (2000, 7000), (210, 90, 0.05), (), 0.7, 0.0),                       # Cinder: spear pierce, ember hiss
    "dredge": ("heavy_impact", (700, 3800), (150, 60, 0.08), (640, 1480), 0.6, 0.0),          # Grimble: scrap clatter
    "tender": ("impact", (3200, 9000), (330, 170, 0.05), (1320, 1980), 0.0, 0.0),             # Meeko: soft chime pop
    "rimewright": ("impact", (4000, 11000), (280, 140, 0.035), (3100, 4700), 0.3, 0.0),       # Neve: ice tick
    "dolm": ("impact", (800, 3500), (140, 62, 0.1), (310,), 0.35, 0.0),                       # Tenzo: stone knock
    "ostra": ("impact", (1800, 6000), (400, 90, 0.07), (520, 780), 0.0, 0.0),                 # Motley: warped void pop
    "thief": ("impact", (3500, 11000), (240, 110, 0.03), (2600,), 0.45, 0.0),                 # Sable: quick double slice
}


def jitter(i, spread=0.07):
    """A take's own small detune (take 0 is the plain one)."""
    return 1.0 if i == 0 else float(S.rng.uniform(1 - spread, 1 + spread))


def snap(arch, i, taken):
    cat, band, body, rings, grit, zap = HUNTERS[arch]
    j = jitter(i)
    lo, hi = band
    f0, f1, dec = body
    if taken:                       # lower, duller, longer body; the transient is mostly gone
        lo, hi, f0, f1, dec = lo * 0.35, hi * 0.35, f0 * 0.6, f1 * 0.6, dec * 2.0
    parts = [crack(0.05, lo * j, hi * j, 0.006 if not taken else 0.012) * (1.0 if not taken else 0.55),
             kick(f0 * j, f1 * j, 0.22, drop=0.025, decay=dec, drive=2.2) * 1.1,
             sub(f1 * 1.5 * j, f1, 0.2, dec * 1.4) * (0.5 if not taken else 1.0)]
    if rings:
        gain = 0.35 if not taken else 0.12
        parts.append(ring([r * j * (0.7 if taken else 1.0) for r in rings], 0.25, [0.09] * len(rings), [gain] * len(rings)))
    if grit > 0:
        parts.append(tail(0.18, 5000 if not taken else 1500, 0.05 + 0.05 * grit, delay=0.004) * grit * 0.6)
    if zap > 0:
        parts.append(hpf(sat(S.fm(2600 * j, 1.7, 3.0, 0.14, decay=0.04), 2.5), 1500) * 0.5 * (0.4 if taken else 1.0))
    if arch == "thief":
        parts.append(at(crack(0.04, lo * j, hi * j, 0.005), 0.045) * 0.7)
    return mix(*parts)


for arch, spec in HUNTERS.items():
    S.takes_cat(arch + "_hit", lambda i, a=arch: snap(a, i, False), 3, spec[0])
    S.takes_cat(arch + "_taken", lambda i, a=arch: snap(a, i, True), 3, spec[0])
print("hit sounds written:", len(HUNTERS) * 2, "x 4 files")
