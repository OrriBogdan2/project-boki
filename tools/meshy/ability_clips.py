"""Ability clips for the native Hunters on Meshy's own skeleton: art/wardens/<art>/<art>_clips.glb.

  /home/boki/venv-img/bin/python3 tools/meshy/ability_clips.py ART [--sheet DIR]     (ART: tarek ostra sable gil)

Each clip is keyed by hand from poses (tools/meshy/clip_rig.py, no retarget), timed on the kit: the contact frame
(the boulder leaves the hand, the fist lands, the slam hits) sits where the kit fires it, taken from the contract
clips' own contact times in content/rules/warden_anim/<art>.json and from the kit's cast times and docs/heroes/*.md.
The clip names carry the art's prefix; content/rules/warden_native.json maps them to slots.
"""

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
        mirror([(0.0, cock, "lin"), (0.07, rel, "snap"), (0.2, over(rel, rhu=0.1, lean=10), "smooth"), (0.55, rest, "smooth")]),
    )
    # LMB hold, let go: the fist drives straight out of the held crouch, a 0.5 body-height step, out at 0.05 s
    draw = over(rest, yaw=-30, lean=18, hy=-0.2, rho=0.15, rhu=-0.5, rhf=-0.75, lho=0.3, lhu=-0.25, lhf=0.6, gap=0.1)
    drive = over(rest, yaw=34, lean=20, hy=-0.1, hz=0.2, rho=0.05, rhu=-0.05, rhf=1.05, lho=0.5, lhu=-0.5, lhf=-0.1)
    drive["lff"] = 0.38
    out["tarek_punch"] = (
        0.6,
        mirror([(0.0, draw, "lin"), (0.05, drive, "snap"), (0.22, over(drive, rhf=0.95, hz=0.2), "lin"), (0.6, rest, "smooth")]),
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
    return {}


def sable():
    return {}


def gil():
    return {}


HUNTERS = {"tarek": tarek, "ostra": ostra, "sable": sable, "gil": gil}


def main():
    args = sys.argv[1:]
    if not args or args[0] not in HUNTERS:
        sys.exit(__doc__)
    art = args[0]
    rig = Rig(os.path.join(ROOT, art, art + "_meshy.glb"))
    clips = HUNTERS[art]()
    if "--sheet" in args:
        sheet(rig, clips, args[args.index("--sheet") + 1])
    write_glb(rig, clips, os.path.join(ROOT, art, art + "_clips.glb"), art)


if __name__ == "__main__":
    main()
