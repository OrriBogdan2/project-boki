"""Planted paws for a Boki's walk and run. Each paw's path is keyed in the model's space: while it is down it goes
back along the ground in a straight line at one speed (the ground's, so it does not slide), while it is up it lifts
and swings forward, leaving and meeting the ground at that same speed. The leg's own two angles are then solved to
put the paw there, through whatever the body above it does (bob, pitch, sway). docs/art/kin/RIGGED_BOKI.md."""
import math

import numpy as np

STEPS = 14         # solver passes per paw and pose: a pass moves the angles by their least-squares step
NUDGE = 1e-4       # rad: the finite step the solver measures each angle's pull on the paw with
DAMP = 1e-4        # keeps a step small where the leg is straight (m^2)
MAX_STEP = 0.2     # rad per pass: past the leg's reach the paw goes as near as it can instead of flailing
MATCH = 1.0        # how much of the stance speed the paw keeps as it leaves and meets the ground (0..1)
CARRY = 5          # how soon a swing's paw loses the stance speed: a higher power keeps it nearer the ground
CLIP_SCALE = 0.95  # boki_rig.CLIP_SCALE (that module needs Blender): the clips' offsets in the build's metres
SNAP = 1.0 / 3.0   # the lift's shape: under 1 the paw is up off the ground (past half its lift) within a frame or two
REACH = 0.97       # of the leg's length: a paw aimed further from the hip is aimed this far instead, along the same
                   # line (a short leg under a body that is up in the air tucks rather than whirls round the hip)


def _rot(rx, ry, rz):
    """The clips' euler in the creature's axes (boki_rig.quat_of): turn, then lift, then roll."""
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    turn = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    lift = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    roll = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return turn @ lift @ roll


def where(bones, pose, bone):
    """A bone's head in model space under `pose` (bones: name -> (head, tail, parent), as the rig is built)."""
    at = np.array(bones[bone][0], float)
    while bone:
        head, _, parent = bones[bone]
        rot = pose.get(bone, (0, 0, 0))
        q = _rot(*((0, 0, 0) if rot == "on" else rot))
        at = q @ ((at - head) * pose.get(bone + "_sc", 1.0)) + head
        if parent is None or bone == "hips":
            at = at + np.array(pose.get(bone + "_at", (0, 0, 0)), float) * CLIP_SCALE
        bone = parent
    return at


def path(u, duty, reach, lift):
    """A paw's (back, up) from its rest place at phase u (0..1): down for the first `duty`, swept back from
    reach/2 ahead to reach/2 behind; then up, an eased arc forward that leaves and lands moving back."""
    if u < duty:
        return reach * (u / duty - 0.5), 0.0
    w = (u - duty) / (1.0 - duty)
    pace = MATCH * reach / duty * (1.0 - duty)      # the stance speed, in the swing's own time
    keep = w * (1.0 - w) ** CARRY - (1.0 - w) * w ** CARRY      # that speed at both ends, gone soon after
    return reach * (0.5 - w * w * (3.0 - 2.0 * w)) + pace * keep, lift * math.sin(math.pi * w) ** SNAP


def solve(bones, pose, foot, aim, setter, guess):
    """The leg's two angles (a, b) that put `foot` at `aim` (model space: back and up); setter(pose, a, b) sets
    them. Damped least squares from `guess`, which picks the knee's side."""
    ab = np.array(guess, float)

    def miss(v):
        p = dict(pose)
        setter(p, v[0], v[1])
        return where(bones, p, foot)[1:] - aim

    for _ in range(STEPS):
        e = miss(ab)
        jac = np.stack([(miss(ab + d) - e) / NUDGE for d in np.eye(2) * NUDGE], 1)
        step = np.linalg.solve(jac.T @ jac + DAMP * np.eye(2), jac.T @ e)
        ab -= step * min(1.0, MAX_STEP / max(np.linalg.norm(step), 1e-9))
    return ab


def planted(body, bones, legs, duty, reach, lift, drop=0.0, steps=1, guess=(0.0, 0.3)):
    """A walk or run clip of `steps` steps: `body(t)` poses all but the legs (any leg keys it has are replaced),
    lowered `drop` m so the legs bend enough to reach; legs: (foot bone, phase, setter[, back]). Each leg's paw
    follows `path` round its rest place (moved `back` m, for a leg already at full stretch forward or back),
    `phase` of a step late."""
    def clip(t):
        pose = body(t)
        x, y, z = pose.get("root_at", (0.0, 0.0, 0.0))
        pose["root_at"] = (x, y - drop, z)
        for foot, ph, setter, *back in legs:
            aim_back, up = path((t * steps - ph) % 1.0, duty, reach, lift)
            rest = np.array(bones[foot][0], float)
            aim = np.array((rest[1] + up, rest[2] + aim_back + sum(back)))
            if hasattr(setter, "hip"):
                aim = within(bones, pose, setter.hip, foot, aim)
            ab = solve(bones, pose, foot, aim, setter, guess)
            setter(pose, ab[0], ab[1])
        return pose

    def refit(moved):
        """The same clip on the same rig with its bones moved (a Meshy scan's fit, boki_scan): the paws are aimed
        from the moved rest places, and the stride, lift and drop scale with the first leg's new length."""
        foot, _, setter = legs[0][:3]
        k = _long(moved, setter.hip, foot) / _long(bones, setter.hip, foot) if hasattr(setter, "hip") else 1.0
        return planted(body, moved, [leg[:3] + tuple(b * k for b in leg[3:]) for leg in legs], duty, reach * k,
                       lift * k, drop * k, steps, guess)
    clip.refit = refit
    return clip


def _long(bones, hip, foot):
    """The leg's length from `hip` down its chain to `foot`'s head."""
    long = 0.0
    while foot != hip:
        parent = bones[foot][2]
        long += float(np.linalg.norm(np.array(bones[foot][0], float) - np.array(bones[parent][0], float)))
        foot = parent
    return long


def within(bones, pose, hip, foot, aim):
    """`aim` (model space: up, back), pulled in toward the hip to REACH of the leg's length if it is past that. For a
    leg that swings in that plane (two_bone's, which names its `hip`); a leg splayed out to the side reaches further."""
    at = where(bones, pose, hip)[1:]
    long = _long(bones, hip, foot)
    off = aim - at
    far = float(np.linalg.norm(off))
    return aim if far <= REACH * long else at + off * (REACH * long / far)


def two_bone(leg1, leg2, paw, fold):
    """A setter for a leg of two bones swung about x: `a` from the hip, `b` bends the knee to its `fold` side
    (1 or -1); the paw stays level with the ground."""
    def put(pose, a, b):
        pose[leg1] = (a, 0.0, 0.0)
        pose[leg2] = (fold * b, 0.0, 0.0)
        pose[paw] = (-a - fold * b, 0.0, 0.0)
    put.hip = leg1
    return put


def four_legs(front, hind, right):
    """The legs of the shared four-legged rig (fleg1/fleg2/fpaw, hleg1/hleg2/hpaw) for planted: the forepaws step
    at phase `front`, the hind feet at `hind`, each right one `right` after its left; wrists fold back, hocks
    forward."""
    out = []
    for sd, late in (("L", 0.0), ("R", right)):
        out.append(("fpaw." + sd, front + late, two_bone("fleg1." + sd, "fleg2." + sd, "fpaw." + sd, -1.0)))
        out.append(("hpaw." + sd, hind + late, two_bone("hleg1." + sd, "hleg2." + sd, "hpaw." + sd, 1.0)))
    return out


def hind_legs(left, right, fold=-1.0):
    """A two-legged rig's legs (hleg1/hleg2/hpaw) for planted: the left foot steps at phase `left`, the right at
    `right`; `fold` is the knee's side."""
    return [("hpaw." + sd, ph, two_bone("hleg1." + sd, "hleg2." + sd, "hpaw." + sd, fold))
            for sd, ph in (("L", left), ("R", right))]
