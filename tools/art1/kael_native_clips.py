"""Kael's own move clips on his Meshy skeleton: art/wardens/kael/kael_clips.glb (a clips-only file; kael_meshy.glb is
never touched). Run: python3 -I tools/art1/kael_native_clips.py [out.glb]

Each clip runs on the kit's clock (clip second 0 = the second the kit starts the move, kmove_t) so the contact pose
sits on the kit's hit time (docs/heroes/juggernaut.md "Animation timing": the hit times are the HIT table below).
A pose is a few numbers in his body frame (x his left, y up, z ahead; the origin on the ground under his hips): the
hips' height and turn, the chest's twist and lean, both feet, the sword hand, the way the blade points (the blade
runs along the hand bone) and the free hand. Poses between two keys are those numbers eased, solved every frame
(two-bone IK for the legs and arms, tools/art1/meshy_rig.py), so a hit pose is exactly what it says at its key."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from meshy_rig import FPS, Rig, axis_angle, qinv, qmul, qrot, slerp, unit  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "..", "art", "wardens", "kael", "kael_meshy.glb")
OUT = os.path.join(HERE, "..", "..", "art", "wardens", "kael", "kael_clips.glb")

ANKLE = 0.155  # m: Meshy's ankle over a flat foot
HAND_BACK = 0.14  # m: the free hand's place on the hilt, behind the sword hand along the blade
TRUNK = [("Spine02", 0.25), ("Spine01", 0.30), ("Spine", 0.45)]  # the chest's twist and lean shared over its bones

# a pose's numbers and their ready values; a key names only what it changes
READY = {
    "h": 1.03,  # hips height
    "yaw": 0.0,
    "lean": 0.0,
    "roll": 0.0,  # the whole body, degrees (yaw left +, lean ahead +, roll right +)
    "at": (0.0, 0.0),  # where the hips are over the ground (x, z)
    "twist": 0.0,
    "clean": 0.0,
    "croll": 0.0,  # the chest over the hips
    "look": (0.0, 0.0),  # the head's yaw and pitch from straight ahead of the body
    "lf": (0.17, ANKLE, 0.08),
    "rf": (-0.17, ANKLE, -0.10),  # ankles
    "lfy": 8.0,
    "rfy": -8.0,  # the feet's turn out
    "rh": (-0.27, 0.96, 0.24),
    "blade": (0.10, -0.55, 0.83),
    "bt": 0.0,  # sword hand, blade direction, its roll
    "rpole": (-0.5, -0.6, -0.4),
    "lpole": (0.5, -0.6, -0.4),
    "lh": (0.30, 0.95, 0.12),
    "grip": 0.0,  # free hand; grip 1 puts it on the hilt
    "knee": 0.15,  # the knees' bend out and ahead
}
EASE = {
    "lin": lambda x: x,
    "io": lambda x: x * x * (3 - 2 * x),
    "in": lambda x: x * x,
    "out": lambda x: 1 - (1 - x) * (1 - x),
    "snap": lambda x: 1 - (1 - x) ** 3,
}


def lerp(a, b, k):
    if isinstance(a, tuple):
        return tuple(lerp(x, y, k) for x, y in zip(a, b))
    return a + (b - a) * k


def at_time(keys, t):
    """The pose numbers at second t of a clip: keys [(second, {numbers}, ease into it)], each key on top of the last."""
    full, now = [], dict(READY)
    for sec, nums, ease in keys:
        now = dict(now, **nums)
        full.append((sec, now, ease))
    if t <= full[0][0]:
        return full[0][1]
    for (t0, a, _), (t1, b, ease) in zip(full, full[1:]):
        if t <= t1:
            k = EASE[ease]((t - t0) / (t1 - t0))
            return {n: lerp(a[n], b[n], k) for n in a}
    return full[-1][1]


def rot_y(deg):
    return axis_angle((0, 1, 0), deg)


def solve(rig, base, p):
    """The pose numbers p -> (bone locals, the Hips' place)."""
    yaw = rot_y(p["yaw"])

    def world(v):
        return qrot(yaw, v)

    def point(v):  # body frame -> world, the origin on the ground under the hips
        w = world(v)
        return (p["at"][0] + w[0], w[1], p["at"][1] + w[2])

    body = qmul(yaw, qmul(axis_angle((0, 0, 1), p["roll"]), axis_angle((1, 0, 0), p["lean"])))
    spec = {"Hips": {"q": body}}
    chest = qmul(rot_y(p["twist"]), qmul(axis_angle((0, 0, 1), p["croll"]), axis_angle((1, 0, 0), p["clean"])))
    total = body
    for bone, share in TRUNK:
        part = slerp((0.0, 0.0, 0.0, 1.0), chest, share)
        spec[bone] = {"q": qmul(yaw, qmul(part, qinv(yaw)))}
        total = qmul(qmul(yaw, qmul(part, qinv(yaw))), total)
    ly, lp = p["look"]
    spec["Head"] = {"q": qmul(qmul(yaw, qmul(rot_y(ly), axis_angle((1, 0, 0), lp))), qmul(qinv(yaw), qinv(total)))}
    blade = world(unit(p["blade"]))
    hand = point(p["rh"])
    ik = {"RightHand": {"at": hand, "pole": world(p["rpole"])}}
    spec["RightHand"] = {"aim": blade, "twist": p["bt"]}
    if p["grip"]:
        free = tuple(
            lerp(a, b, p["grip"]) for a, b in zip(point(p["lh"]), tuple(h - HAND_BACK * d for h, d in zip(hand, blade)))
        )
        spec["LeftHand"] = {"aim": blade}
    else:
        free = point(p["lh"])
    ik["LeftHand"] = {"at": free, "pole": world(p["lpole"])}
    for side, sx, key in (("Left", 1, "lf"), ("Right", -1, "rf")):
        foot = (p["at"][0] + p[key][0], p[key][1], p["at"][1] + p[key][2])  # (planted: they do not turn with the body)
        out = p["lfy" if sx > 0 else "rfy"]
        toe = world((math.sin(math.radians(out)) * 0.7, -0.7, math.cos(math.radians(out)) * 0.7))
        ik[side + "Foot"] = {"at": foot, "pole": world((sx * p["knee"], 0.1, 1.0))}
        spec[side + "Foot"] = {"aim": toe}
    spec["ik"] = ik
    hips = point((0.0, p["h"], 0.0))
    return rig.pose(base, spec, hips)


def clip(rig, base, keys, hold=None, hits=()):
    """Samples a clip at 30 fps plus the exact hit seconds."""
    end = keys[-1][0]
    times = sorted({round(i / FPS, 4) for i in range(int(end * FPS) + 1)} | {round(end, 4)} | set(hits))
    rot = {b: [] for b in rig.rest}
    pos = {"Hips": []}
    for t in times:
        local, place = solve(rig, base, at_time(keys, t))
        for b in rot:
            rot[b].append(tuple(round(x, 6) for x in local[b]))
        pos["Hips"].append(tuple(round(x, 5) for x in place["Hips"]))
    return {"t": times, "rot": rot, "pos": pos}


# ------------------------------------------------------------------------------------------------- the moves
# (second, numbers, ease into the key). Hit seconds are the kit's (docs/heroes/juggernaut.md "Animation timing").
HIT = {
    "slash_r": 0.033,
    "slash_l": 0.033,
    "wave": 0.033,
    "slam": 0.583,
    "lunge": 0.217,
    "chain": 0.02,
    "reel": 0.017,
    "riposte": 0.117,
}


def stand(**kw):
    return dict(kw)


CLIPS = {
    # LMB tap, forehand: cocked behind the right shoulder, the cut across the front on the hit, through to his left
    "slash_r": [
        (
            0.0,
            {
                "yaw": -28,
                "twist": -18,
                "clean": 4,
                "h": 0.99,
                "rh": (-0.42, 1.42, -0.06),
                "blade": (-0.35, 0.55, -0.75),
                "lh": (0.30, 1.15, 0.30),
                "lf": (0.20, ANKLE, 0.20),
                "rf": (-0.20, ANKLE, -0.22),
            },
            "lin",
        ),
        (0.033, {"yaw": -8, "twist": -2, "rh": (-0.18, 1.28, 0.42), "blade": (0.08, 0.05, 1.0)}, "in"),
        (0.10, {"yaw": 18, "twist": 14, "rh": (0.18, 1.22, 0.42), "blade": (0.92, 0.0, 0.40)}, "out"),
        (
            0.18,
            {"yaw": 34, "twist": 20, "rh": (0.34, 1.12, 0.22), "blade": (0.95, -0.15, -0.20), "lh": (-0.1, 1.2, 0.4)},
            "out",
        ),
        (0.27, dict(READY), "io"),
    ],
    # LMB tap, backhand: from across his left, cut to his right
    "slash_l": [
        (
            0.0,
            {
                "yaw": 28,
                "twist": 18,
                "clean": 4,
                "h": 0.99,
                "rh": (0.12, 1.22, 0.30),
                "blade": (0.92, 0.15, -0.30),
                "lh": (0.35, 1.1, 0.2),
                "lf": (0.20, ANKLE, 0.22),
                "rf": (-0.20, ANKLE, -0.20),
            },
            "lin",
        ),
        (0.033, {"yaw": 8, "twist": 2, "rh": (-0.20, 1.26, 0.44), "blade": (-0.10, 0.05, 1.0)}, "in"),
        (0.10, {"yaw": -20, "twist": -14, "rh": (-0.46, 1.20, 0.28), "blade": (-0.95, 0.0, 0.30)}, "out"),
        (0.18, {"yaw": -34, "twist": -18, "rh": (-0.50, 1.10, 0.0), "blade": (-0.90, -0.15, -0.40)}, "out"),
        (0.27, dict(READY), "io"),
    ],
    # LMB held: gathering, the blade drawn back low to his right, the chest coiled, hold on the last pose
    "wave_wind": [
        (0.0, dict(READY), "lin"),
        (
            0.30,
            {
                "yaw": -26,
                "twist": -16,
                "clean": 6,
                "h": 0.92,
                "rh": (-0.46, 1.05, -0.20),
                "blade": (-0.45, 0.15, -0.88),
                "lh": (0.30, 1.30, 0.50),
                "lf": (0.22, ANKLE, 0.30),
                "rf": (-0.22, ANKLE, -0.28),
            },
            "out",
        ),
        (0.50, {"yaw": -30, "twist": -20, "h": 0.90, "rh": (-0.50, 1.08, -0.24)}, "io"),
    ],
    # LMB released: the wide sweep from the coil across the whole front to his left
    "wave": [
        (
            0.0,
            {
                "yaw": -30,
                "twist": -20,
                "clean": 6,
                "h": 0.90,
                "rh": (-0.50, 1.08, -0.24),
                "blade": (-0.45, 0.15, -0.88),
                "lh": (0.30, 1.30, 0.50),
                "lf": (0.22, ANKLE, 0.30),
                "rf": (-0.22, ANKLE, -0.28),
            },
            "lin",
        ),
        (0.033, {"yaw": -24, "twist": -14, "rh": (-0.46, 1.12, 0.10), "blade": (-0.70, 0.10, 0.70)}, "in"),
        (0.12, {"yaw": 0, "twist": 6, "h": 0.94, "rh": (-0.10, 1.18, 0.46), "blade": (0.05, 0.05, 1.0)}, "snap"),
        (
            0.24,
            {"yaw": 40, "twist": 26, "rh": (0.30, 1.14, 0.30), "blade": (1.0, -0.05, 0.20), "lh": (-0.2, 1.25, 0.4)},
            "out",
        ),
        (0.36, {"yaw": 55, "twist": 28, "rh": (0.36, 1.08, 0.10), "blade": (0.95, -0.2, -0.35)}, "out"),
        (0.60, dict(READY), "io"),
    ],
    # RMB tap: the blade raised over his head and laid back behind it, then the overhead smash into the ground ahead
    "slam": [
        (0.0, dict(READY), "lin"),
        (0.18, {"h": 1.02, "rh": (-0.20, 1.35, 0.28), "blade": (-0.05, 0.9, 0.4), "grip": 1.0, "lean": -3}, "out"),
        (
            0.45,
            {
                "h": 1.08,
                "lean": -14,
                "clean": -10,
                "rh": (-0.10, 1.88, -0.06),
                "blade": (0.0, 0.30, -0.95),
                "lf": (0.20, ANKLE, 0.15),
                "rf": (-0.20, ANKLE, -0.15),
            },
            "out",
        ),
        (0.50, {"h": 1.09, "lean": -16}, "io"),
        (
            0.583,
            {
                "h": 0.88,
                "lean": 24,
                "clean": 12,
                "rh": (-0.10, 0.98, 0.78),
                "blade": (0.0, -0.72, 0.69),
                "lf": (0.20, ANKLE, 0.40),
                "rf": (-0.20, ANKLE, -0.25),
                "at": (0.0, 0.10),
            },
            "in",
        ),
        (0.70, {}, "lin"),
        (1.15, dict(READY, at=(0.0, 0.0)), "io"),
    ],
    # RMB held: a crouched coil, the blade drawn back and pointed at the mark, hold on the last pose
    "lunge_wind": [
        (0.0, dict(READY), "lin"),
        (
            0.30,
            {
                "yaw": -22,
                "twist": -8,
                "lean": 8,
                "h": 0.86,
                "rh": (-0.30, 1.08, -0.02),
                "blade": (0.0, 0.08, 1.0),
                "lh": (0.30, 1.25, 0.55),
                "grip": 0.0,
                "lf": (0.20, ANKLE, 0.48),
                "rf": (-0.22, ANKLE, -0.32),
                "knee": 0.3,
            },
            "out",
        ),
        (0.45, {"h": 0.84}, "io"),
    ],
    # RMB released: the coil holds through the first of the travel, the thrust runs out straight on the arrival
    "lunge": [
        (
            0.0,
            {
                "yaw": -22,
                "twist": -8,
                "lean": 8,
                "h": 0.84,
                "rh": (-0.30, 1.08, -0.02),
                "blade": (0.0, 0.08, 1.0),
                "lh": (0.30, 1.25, 0.55),
                "lf": (0.20, ANKLE, 0.48),
                "rf": (-0.22, ANKLE, -0.32),
                "knee": 0.3,
            },
            "lin",
        ),
        (0.12, {"h": 0.82, "lean": 12, "at": (0.0, 0.08)}, "io"),
        (
            0.217,
            {
                "yaw": -4,
                "twist": 0,
                "lean": 28,
                "h": 0.92,
                "at": (0.0, 0.30),
                "rh": (-0.24, 1.22, 0.74),
                "blade": (0.0, 0.10, 1.0),
                "lh": (0.40, 1.15, -0.10),
                "lf": (0.22, ANKLE, 0.78),
                "rf": (-0.24, 0.30, -0.60),
                "knee": 0.2,
            },
            "in",
        ),
        (0.30, {}, "lin"),
        (0.48, dict(READY), "io"),
    ],
    # E throw: the free hand flings the hook out and holds it pointed at the mark
    "chain": [
        (
            0.0,
            {"yaw": 8, "twist": 10, "lh": (0.40, 1.22, -0.18), "rh": (-0.28, 0.92, 0.0), "blade": (-0.1, -0.6, 0.8)},
            "lin",
        ),
        (0.02, {"yaw": -12, "twist": -12, "lh": (0.20, 1.40, 0.62)}, "in"),
        (0.183, {"lh": (0.20, 1.42, 0.68)}, "lin"),
        (0.40, dict(READY), "io"),
    ],
    # E recast: pulled in, leaning into the chain, flying; hold on the last pose
    "reel": [
        (
            0.0,
            {"yaw": -12, "twist": -12, "lh": (0.20, 1.42, 0.68), "rh": (-0.28, 0.92, 0.0), "blade": (-0.1, -0.6, 0.8)},
            "lin",
        ),
        (
            0.10,
            {
                "yaw": -4,
                "twist": -4,
                "lean": 26,
                "h": 0.92,
                "at": (0.0, 0.12),
                "lh": (0.22, 1.30, 0.80),
                "lf": (0.18, 0.45, 0.30),
                "rf": (-0.18, 0.30, -0.45),
                "rh": (-0.30, 1.0, -0.12),
                "blade": (-0.1, -0.35, 0.9),
            },
            "out",
        ),
        (0.25, {"lean": 30, "h": 0.90}, "io"),
    ],
    # X / R guard: the blade stood upright before him on a wide, planted stance; hold on the last pose
    "guard": [
        (0.0, dict(READY), "lin"),
        (
            0.20,
            {
                "h": 0.92,
                "yaw": -12,
                "lean": 2,
                "rh": (-0.13, 1.28, 0.40),
                "blade": (0.04, 0.97, 0.22),
                "grip": 1.0,
                "lf": (0.26, ANKLE, 0.22),
                "rf": (-0.26, ANKLE, -0.22),
                "knee": 0.35,
            },
            "out",
        ),
    ],
    # the step in: the blade dropped low behind, then the upward cleave, to the second the kit lands it
    "riposte": [
        (
            0.0,
            {
                "h": 0.92,
                "yaw": -12,
                "lean": 2,
                "rh": (-0.13, 1.28, 0.40),
                "blade": (0.04, 0.97, 0.22),
                "grip": 1.0,
                "lf": (0.26, ANKLE, 0.22),
                "rf": (-0.26, ANKLE, -0.22),
                "knee": 0.35,
            },
            "lin",
        ),
        (
            0.06,
            {
                "yaw": -34,
                "lean": 14,
                "h": 0.84,
                "rh": (-0.32, 0.86, 0.0),
                "blade": (-0.2, -0.1, -0.97),
                "grip": 0.4,
                "lf": (0.24, ANKLE, 0.42),
                "rf": (-0.26, ANKLE, -0.30),
            },
            "io",
        ),
        (
            0.117,
            {
                "yaw": -8,
                "lean": 22,
                "h": 0.88,
                "at": (0.0, 0.22),
                "rh": (-0.24, 1.02, 0.66),
                "blade": (0.0, 0.82, 0.57),
                "grip": 0.0,
                "lf": (0.24, ANKLE, 0.78),
                "rf": (-0.26, ANKLE, -0.34),
            },
            "in",
        ),
    ],
    # the follow-through of the cleave and the settle
    "ult_recover": [
        (
            0.0,
            {
                "yaw": -8,
                "lean": 22,
                "h": 0.88,
                "at": (0.0, 0.22),
                "rh": (-0.24, 1.02, 0.66),
                "blade": (0.0, 0.82, 0.57),
                "lf": (0.24, ANKLE, 0.78),
                "rf": (-0.26, ANKLE, -0.34),
            },
            "lin",
        ),
        (
            0.10,
            {"yaw": 6, "lean": 8, "h": 0.98, "at": (0.0, 0.10), "rh": (-0.16, 1.72, 0.24), "blade": (0.0, 0.95, -0.30)},
            "out",
        ),
        (0.35, dict(READY, at=(0.0, 0.0)), "io"),
    ],
}


def main(dest):
    rig = Rig(SRC)
    base = dict(rig.rest)
    idle, _ = rig.sample("Idle", 0.0)
    for b in rig.rest:
        if "Hand" in b and b not in ("LeftHand", "RightHand"):  # (Meshy's relaxed fingers)
            base[b] = idle[b]
    clips = {}
    for name, keys in CLIPS.items():
        clips[name] = clip(rig, base, keys, hits=(HIT[name],) if name in HIT else ())
        print(name, "%.3f s" % clips[name]["t"][-1], len(clips[name]["t"]), "frames")
    print("wrote", dest, rig.write_clips(dest, clips), "bytes")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else OUT)
