"""Ability clips for the native Hunters on Meshy's own skeleton: art/wardens/<art>/<art>_clips.glb.

  /home/boki/venv-img/bin/python3 tools/meshy/ability_clips.py ART [--sheet DIR]     (ART: tarek ostra sable gil)

Each clip is keyed by hand from poses (tools/meshy/clip_rig.py, no retarget), timed on the kit: the contact frame
(the boulder leaves the hand, the fist lands, the slam hits) sits where the kit fires it, taken from the contract
clips' own contact times in content/rules/warden_anim/<art>.json and from the kit's cast times and docs/heroes/*.md.
The clip names carry the art's prefix; content/rules/warden_native.json maps them to slots.
"""

import math
import os
import sys

from clip_rig import Rig, sheet, write_glb

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "art", "wardens")


def pose(**kw):
    return kw


def over(p, **kw):
    return dict(p, **kw)


def mirror(keys):
    """Keys authored for the right hand, turned onto the left (sides swap, turns and the side shift negate)."""
    out = []
    for t, p, e in keys:
        m = {}
        for k, v in p.items():
            if k[0] in "lr" and k[1:] in ("ho", "hu", "hf", "pu", "fo", "ff", "fu", "fy", "fp"):
                k = ("r" if k[0] == "l" else "l") + k[1:]
            m[k] = -v if k in ("yaw", "roll", "spin", "hyaw", "hx") or k[1:] in ("fy",) else v
        out.append((t, m, e))
    return out


def tarek():
    """Tenzo. His right gauntlet throws and punches; both fists slam. Contacts: throw out at 0.07 s, punch out at
    0.05 s, slam smash at 0.75 s (the contract clips' own, warden_anim/tarek.json), Stone Row's tell 0.2 s."""
    rest = pose(yaw=0, hy=-0.02, lean=2, lho=0.4, lhu=-0.85, lhf=0.1, rho=0.4, rhu=-0.85, rhf=0.1, gap=0.05)
    out = {}
    # LMB tap: the underarm side hurl from the right gauntlet, the boulder leaves at 0.07 s
    cock = over(rest, yaw=-38, lean=6, hy=-0.07, rho=0.55, rhu=-0.55, rhf=-0.55, lho=0.35, lhu=-0.1, lhf=0.7, hyaw=10)
    rel = over(rest, yaw=30, lean=14, hy=-0.05, rho=0.25, rhu=0.0, rhf=1.0, lho=0.6, lhu=-0.55, lhf=-0.15, rff=0.18)
    out["tarek_throw"] = (
        0.55,
        mirror(
            [
                (0.0, cock, "lin"),
                (0.07, rel, "snap"),
                (0.2, over(rel, rhu=0.1, lean=10), "smooth"),
                (0.55, rest, "smooth"),
            ]
        ),
    )
    # LMB hold, let go: the fist drives straight out of the held crouch, a 0.5 body-height step, out at 0.05 s
    draw = over(rest, yaw=-30, lean=18, hy=-0.2, rho=0.15, rhu=-0.5, rhf=-0.75, lho=0.3, lhu=-0.25, lhf=0.6, gap=0.1)
    drive = over(rest, yaw=34, lean=20, hy=-0.1, hz=0.2, rho=0.05, rhu=-0.05, rhf=1.05, lho=0.5, lhu=-0.5, lhf=-0.1)
    drive["lff"] = 0.38
    out["tarek_punch"] = (
        0.6,
        mirror(
            [
                (0.0, draw, "lin"),
                (0.05, drive, "snap"),
                (0.22, over(drive, rhf=0.95, hz=0.2), "lin"),
                (0.6, rest, "smooth"),
            ]
        ),
    )
    # RMB Quakefall: a short gather, the hop with both fists high, the smash at 0.75 s, the landing held, up
    gather = over(rest, hy=-0.2, lean=14, lho=0.3, lhu=-0.8, lhf=-0.3, rho=0.3, rhu=-0.8, rhf=-0.3, gap=0.12)
    up = over(rest, hy=0.0, lean=-6, lho=0.2, lhu=0.9, lhf=0.3, rho=0.2, rhu=0.9, rhf=0.3, lfu=0.18, rfu=0.12, lff=0.1)
    peak = over(up, lean=-12, lhu=0.95, rhu=0.95, lfu=0.22, rfu=0.2)
    smash = over(rest, hy=-0.24, lean=34, lho=0.22, lhu=-0.9, lhf=0.55, rho=0.22, rhu=-0.9, rhf=0.55, gap=0.15, lff=0.1)
    out["tarek_slam"] = (
        1.4,
        [
            (0.0, rest, "lin"), (0.16, gather, "smooth"), (0.3, up, "snap"), (0.5, peak, "smooth"),
            (0.75, smash, "in"), (0.95, over(smash, lean=30), "smooth"), (1.4, rest, "smooth"),
        ],
    )  # fmt: skip
    # E Stone Row: the red flash on the ground (0.2 s tell), the fists thrust down ahead, then heaved up as rocks rise
    point = over(rest, hy=-0.15, lean=26, lho=0.15, lhu=-0.85, lhf=0.7, rho=0.15, rhu=-0.85, rhf=0.7, gap=0.1)
    heave = over(rest, hy=0.02, lean=-10, lho=0.3, lhu=0.55, lhf=0.7, rho=0.3, rhu=0.55, rhf=0.7)
    out["tarek_row"] = (
        0.93,
        [(0.0, rest, "lin"), (0.2, point, "snap"), (0.4, point, "lin"), (0.58, heave, "snap"), (0.93, rest, "smooth")],
    )
    # R Basalt Spine: both fists up, driven into the ground at the press (0.2 s tell), held while the ridge rises
    high = over(rest, hy=0.0, lean=-8, lho=0.2, lhu=0.95, lhf=0.25, rho=0.2, rhu=0.95, rhf=0.25)
    drive2 = over(rest, hy=-0.3, lean=40, lho=0.25, lhu=-0.95, lhf=0.5, rho=0.25, rhu=-0.95, rhf=0.5, gap=0.18)
    out["tarek_spine"] = (
        1.4,
        [
            (0.0, rest, "lin"), (0.14, high, "snap"), (0.22, drive2, "in"), (0.8, over(drive2, lean=36), "smooth"),
            (1.4, rest, "smooth"),
        ],
    )  # fmt: skip
    return out


def ostra():
    """Motley. She stands on her jack-in-the-box, so the feet stay planted and the arms and spine do the casting.
    Contacts: orb out at 0.06 s (the hot orb's lead), Shard Snap's flick at 0.12 s, the Brimseed leaves the hand at
    its 0.25 s drop, Nightwell's 1.0 s tell: a locked cast (turn held after 0.25 s) that ends in the palms driven
    down as the well opens (docs/heroes/ostra.md)."""
    rest = pose(hy=-0.01, lean=3, lho=0.38, lhu=-0.85, lhf=0.1, rho=0.38, rhu=-0.85, rhf=0.1)
    out = {}
    pull = over(rest, yaw=-14, lean=-3, rho=0.2, rhu=-0.25, rhf=0.1, lho=0.35, lhu=-0.7, lhf=0.1)
    toss = over(rest, yaw=12, lean=7, rho=0.1, rhu=-0.05, rhf=1.0, lho=0.4, lhu=-0.75, lhf=-0.1, hyaw=0)
    out["ostra_orb"] = (
        0.4,
        [
            (0.0, pull, "lin"),
            (0.06, toss, "snap"),
            (0.18, over(toss, rhu=-0.12, rhf=0.9), "smooth"),
            (0.4, rest, "smooth"),
        ],
    )
    both = over(rest, lean=-5, rho=0.12, rhu=-0.2, rhf=0.2, lho=0.12, lhu=-0.2, lhf=0.2)
    burst = over(rest, lean=10, rho=0.22, rhu=0.0, rhf=1.0, lho=0.22, lhu=0.0, lhf=1.0, hy=-0.03)
    out["ostra_orb_hot"] = (
        0.5,
        [
            (0.0, both, "lin"),
            (0.05, burst, "snap"),
            (0.2, over(burst, rhf=0.9, lhf=0.9), "smooth"),
            (0.5, rest, "smooth"),
        ],
    )
    raise_ = over(rest, yaw=-10, rho=0.3, rhu=0.55, rhf=0.15, lho=0.4, lhu=-0.7, lhf=0.1)
    flick = over(rest, yaw=14, lean=6, rho=0.45, rhu=0.1, rhf=0.9, lho=0.4, lhu=-0.7, lhf=0.1)
    out["ostra_snap"] = (
        0.5,
        [
            (0.0, raise_, "lin"),
            (0.12, flick, "snap"),
            (0.26, over(flick, rhu=0.0, rho=0.55), "smooth"),
            (0.5, rest, "smooth"),
        ],
    )
    back = over(rest, yaw=-18, lean=14, hy=-0.04, rho=0.3, rhu=-0.75, rhf=-0.45, lho=0.4, lhu=-0.6, lhf=0.35)
    scoop = over(rest, yaw=16, lean=24, hy=-0.05, rho=0.2, rhu=-0.55, rhf=0.9, lho=0.45, lhu=-0.6, lhf=-0.1)
    out["ostra_seed"] = (
        0.8,
        [
            (0.0, rest, "lin"), (0.12, back, "smooth"), (0.25, scoop, "snap"),
            (0.42, over(scoop, rhu=-0.35, lean=18), "smooth"), (0.8, rest, "smooth"),
        ],
    )  # fmt: skip
    cup = over(rest, lean=-8, rho=0.5, rhu=0.7, rhf=0.1, lho=0.5, lhu=0.7, lhf=0.1, hpitch=-14)
    dome = over(rest, lean=-14, rho=0.18, rhu=0.95, rhf=0.2, lho=0.18, lhu=0.95, lhf=0.2, hpitch=-18)
    shake = over(dome, rho=0.16, lho=0.2, lean=-12)
    slam = over(rest, lean=24, hy=-0.07, rho=0.25, rhu=-0.55, rhf=0.85, lho=0.25, lhu=-0.55, lhf=0.85)
    out["ostra_well"] = (
        1.0,
        [
            (0.0, rest, "lin"), (0.25, cup, "smooth"), (0.5, dome, "smooth"), (0.65, shake, "smooth"),
            (0.8, dome, "smooth"), (0.92, slam, "in"), (1.0, over(slam, lean=22), "smooth"),
        ],
    )  # fmt: skip
    return out


def sable():
    """Sable. Daggers, the Bola and the Vault cartwheel. Contacts: the dagger leaves at 0.1 s (the contract's
    thf_lmb_r cut is 0.45 s), the Bola after one whirl at 0.24 s (the kit throws on the press), Shadow Knife at
    0.1 s, the Vault 0.48 s, Encore 2 s (ring 0.4 s, a blade every 0.2 s). The Vault is a sideways cartwheel to her
    right: the body rolls about her forward axis, the hands take the ground one after the other (the clip is in
    place, so the contact sweeps back along her side as the game carries her), the legs follow the body."""
    rest = pose(hy=-0.02, lean=2, lho=0.38, lhu=-0.85, lhf=0.1, rho=0.38, rhu=-0.85, rhf=0.1, gap=0.04)
    out = {}
    cock = over(rest, yaw=-24, lean=4, rho=0.35, rhu=0.25, rhf=0.0, lho=0.35, lhu=-0.55, lhf=0.3)
    flick = over(rest, yaw=22, lean=10, rho=0.2, rhu=0.1, rhf=1.0, lho=0.5, lhu=-0.6, lhf=-0.1, lff=0.1)
    out["sable_dagger"] = (
        0.45,
        [(0.0, cock, "lin"), (0.1, flick, "snap"), (0.2, over(flick, rhu=0.0), "smooth"), (0.45, rest, "smooth")],
    )
    out["sable_knife"] = (
        0.47,
        [
            (0.0, over(cock, rhu=0.7, rhf=-0.2, yaw=-30), "lin"), (0.1, over(flick, rhu=0.35, yaw=26, lean=12), "snap"),
            (0.22, over(flick, rhu=0.2), "smooth"), (0.47, rest, "smooth"),
        ],
    )  # fmt: skip
    whirl = []  # the bola over her head in the right hand, one turn in 0.2 s (a circle in her side plane)
    for k in range(9):
        a = math.radians(-90 + 45 * k)
        h = dict(rho=0.3 + 0.35 * math.sin(a), rhu=0.5 - 0.4 * math.cos(a), rhf=0.1, yaw=-8 + 2 * k)
        whirl.append((0.02 + 0.025 * k, over(rest, **h), "lin"))
    throw = over(rest, yaw=26, lean=14, rho=0.25, rhu=0.2, rhf=1.0, lho=0.5, lhu=-0.6, lhf=-0.1, lff=0.1)
    out["sable_bola"] = (
        0.73,
        [(0.0, rest, "lin")] + whirl + [(0.24, throw, "snap"), (0.36, over(throw, rhu=0.1), "smooth"), (0.73, rest, "smooth")],
    )  # fmt: skip
    # Vault: crouch and tip over, hands down one after the other, legs over the head, back on her feet at 0.48 s
    load = over(rest, hy=-0.1, lean=6, roll=-6, rho=0.55, rhu=0.7, rhf=0.1, lho=0.55, lhu=0.7, lhf=0.1)
    q1 = over(
        rest, spin=90, hy=0.02, fb=1.0, rho=0.2, rhu=0.95, rhf=0.2, lho=0.5, lhu=0.55, lhf=0.1, lfo=0.15, rfo=0.15
    )
    q2 = over(q1, spin=180, hy=0.06, rho=0.3, rhu=0.7, lho=0.2, lhu=0.95, lfo=0.3, rfo=0.3, lfu=0.0, rfu=0.0)
    q3 = over(q2, spin=270, hy=0.02, rho=0.45, rhu=0.55, lho=0.2, lhu=0.95)
    land = over(rest, spin=360, hy=-0.12, fb=1.0, lho=0.45, lhu=0.5, rho=0.45, rhu=0.5)
    out["sable_vault"] = (
        0.48,
        [
            (0.0, load, "lin"), (0.08, q1, "smooth"), (0.19, q2, "lin"), (0.3, q3, "lin"),
            (0.4, land, "smooth"), (0.48, over(rest, spin=360, hy=-0.06), "smooth"),
        ],
    )  # fmt: skip
    out["sable_encore"] = (2.0, encore_keys(rest))
    return out


def encore_keys(rest):
    """Encore: a pirouette and a blade from alternate hands every 0.2 s (10 in 2 s), two turns, the legs turn with her."""
    keys = [(0.0, rest, "lin")]
    for k in range(10):
        t = 0.2 * k
        right = k % 2 == 0
        arm = (
            dict(rho=1.0, rhu=0.1, rhf=0.3, lho=0.5, lhu=-0.35, lhf=0.1)
            if right
            else dict(lho=1.0, lhu=0.1, lhf=0.3, rho=0.5, rhu=-0.35, rhf=0.1)
        )
        keys.append((t + 0.1, over(rest, yaw=720 * (t + 0.1) / 2.0, fb=1.0, hy=-0.05, lean=4, **arm), "lin"))
    keys.append((2.0, over(rest, yaw=720, fb=1.0), "smooth"))
    return keys


# The swordfish's line in the right hand's own frame: Meshy's Idle holds the hand hanging with the blade level and
# forward (read off the Idle clip's first frame of gil_meshy.glb: the hand's turn then, taken back onto +Z).
GIL_BLADE = (0.711, 0.423, 0.562)


def gil():
    """Gil. A small fencer with a swordfish in the right hand. Contacts: a thrust every 0.32 s with the point at
    0.08 s, the Tide Lunge out at 0.08 s from the held draw, the potion leaves the hand at 0.15 s, Riptide's spin
    (up to 2 s, then the spout), Tidal Wave's 1 s ride (stance held, arms out), the swim (0.55 s) flat and fast."""
    rest = pose(hk=1, hw=1, hy=-0.01, lean=3, lho=0.4, lhu=-0.85, lhf=0.1, rho=0.4, rhu=-0.85, rhf=0.1, gap=0.03)
    out = {}
    cock = over(rest, yaw=-22, lean=6, hy=-0.03, rho=0.3, rhu=-0.35, rhf=0.0, lho=0.4, lhu=-0.5, lhf=0.4)
    stab = over(
        rest,
        bp=16,
        yaw=24,
        lean=16,
        hy=-0.04,
        hz=0.1,
        rho=0.1,
        rhu=-0.05,
        rhf=1.0,
        lho=0.5,
        lhu=-0.55,
        lhf=-0.2,
        lff=0.2,
    )
    out["gil_thrust"] = (
        0.32,
        [(0.0, cock, "lin"), (0.08, stab, "snap"), (0.16, over(stab, rhf=0.95), "smooth"), (0.32, rest, "smooth")],
    )
    draw = over(rest, yaw=-34, lean=10, hy=-0.08, rho=0.25, rhu=-0.3, rhf=-0.65, lho=0.4, lhu=-0.4, lhf=0.5, gap=0.08)
    lunge = over(
        rest,
        bp=24,
        yaw=30,
        lean=24,
        hy=-0.1,
        hz=0.25,
        rho=0.05,
        rhu=-0.05,
        rhf=1.05,
        lho=0.55,
        lhu=-0.6,
        lhf=-0.25,
        lff=0.4,
    )
    out["gil_lunge"] = (
        0.5,
        [(0.0, draw, "lin"), (0.08, lunge, "snap"), (0.22, over(lunge, rhf=0.98), "lin"), (0.5, rest, "smooth")],
    )
    dip = over(rest, yaw=-10, lean=8, lho=0.45, lhu=-0.8, lhf=0.1, rho=0.35, rhu=-0.45, rhf=0.35)
    back = over(rest, yaw=-26, lean=-2, rho=0.45, rhu=0.7, rhf=-0.35, lho=0.4, lhu=-0.6, lhf=0.3)
    toss = over(rest, yaw=24, lean=14, rho=0.25, rhu=0.4, rhf=0.95, lho=0.45, lhu=-0.6, lhf=-0.1)
    out["gil_potion"] = (
        0.45,
        [(0.0, dip, "lin"), (0.08, back, "smooth"), (0.15, toss, "snap"), (0.28, over(toss, rhu=0.2), "smooth"), (0.45, rest, "smooth")],
    )  # fmt: skip
    spin = [
        (0.0, rest, "lin"),
        (0.1, over(rest, hy=-0.05, rho=0.95, rhu=0.15, rhf=0.1, lho=0.7, lhu=0.0, lhf=0.1), "smooth"),
    ]
    for k in range(1, 8):
        t = 0.1 + 0.2 * k
        spin.append((t, over(spin[1][1], yaw=1080 * (t - 0.1) / 1.9, fb=1.0), "lin"))
    spin += [
        (1.9, over(spin[1][1], yaw=1080, fb=1.0), "lin"),
        (
            2.0,
            over(rest, yaw=1080, hy=-0.04, lean=10, rho=0.2, rhu=0.0, rhf=1.0, lho=0.3, lhu=0.0, lhf=0.9, fb=1.0),
            "snap",
        ),
    ]
    out["gil_riptide"] = (2.0, spin)
    surf = over(
        rest, yaw=70, hy=-0.14, lean=10, rho=0.9, rhu=0.15, rhf=0.0, lho=0.9, lhu=0.1, lhf=0.1, gap=0.14, lff=0.0
    )
    out["gil_wave"] = (
        1.0,
        [
            (0.0, rest, "lin"),
            (0.15, surf, "smooth"),
            (0.85, over(surf, lean=14), "smooth"),
            (1.0, over(surf, lean=12), "lin"),
        ],
    )
    swim = over(
        rest,
        bp=88,
        lean=30,
        hl=60,
        hpitch=-5,
        hy=-0.12,
        hz=0.1,
        rho=0.15,
        rhu=-0.1,
        rhf=-0.95,
        lho=0.15,
        lhu=-0.1,
        lhf=-0.95,
        fb=1.0,
    )
    out["gil_swim"] = (0.55, [(0.0, rest, "lin"), (0.12, swim, "snap"), (0.55, over(swim, lean=34), "smooth")])
    return out


HUNTERS = {"tarek": tarek, "ostra": ostra, "sable": sable, "gil": gil}


def main():
    args = sys.argv[1:]
    if not args or args[0] not in HUNTERS:
        sys.exit(__doc__)
    art = args[0]
    rig = Rig(os.path.join(ROOT, art, art + "_meshy.glb"))
    if art == "gil":
        rig.blade = GIL_BLADE
    clips = HUNTERS[art]()
    if "--sheet" in args:
        sheet(rig, clips, args[args.index("--sheet") + 1])
    write_glb(rig, clips, os.path.join(ROOT, art, art + "_clips.glb"), art)


if __name__ == "__main__":
    main()
