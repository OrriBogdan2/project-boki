"""Gives a borrowed-rig quadruped (or, with legs=2, biped) its real legs (fleg1/2, fpaw, hleg1/2, hpaw, .L/.R: the
names BokiPlant, BokiDna and BokiHomePoses already read on nettlynx and cairnback) and a trot for walk and run, straight
on its game glb. The model, its other clips and the face stay as they are; only the leg region's skin weights move to
the new bones.

  blender -b --factory-startup --python tools/boki/auto_legs.py -- <species> [top=0.42] [reach=1.0] [legs=2]

top: the belly's height as a share of the body's; reach: a multiple of the default stride.
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import boki_rig  # noqa: E402
import glb_tangents  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
QUAD = [("f", ".L"), ("f", ".R"), ("h", ".L"), ("h", ".R")]
BIPED = [("h", ".L"), ("h", ".R")]      # hleg only: the names BokiHomePoses reads on a two-legged rig
LEGS = QUAD
NEW = []
ANKLE = 0.12       # of the belly height: where the paw bone starts
# clip: (duty: share of a step the paw is down, half stride, lift, body drop, bob), the last four in belly heights.
# The drop crouches the body so a planted paw can reach the ground at both ends of its sweep.
GAITS = {"walk": (0.5, 0.30, 0.25, 0.11, 0.015), "run": (0.25, 0.40, 0.35, 0.16, 0.03)}


def smooth(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def legs_of(co, top):
    """Four leg centres (x, y) and radii from the verts under the belly. Verts along the midline are tail, snout
    or belly, not legs; each side's verts split front and back by a 2-means on y, and the two sides are mirrored."""
    low = co[co[:, 2] < top * 0.5][:, :2]
    low = low[np.abs(low[:, 0]) >= 0.35 * np.percentile(np.abs(low[:, 0]), 75)]
    if len(LEGS) == 2:
        cen, rad = [], []
        for sd in (-1, 1):
            pts = low[np.sign(low[:, 0]) == sd]
            c = np.array([sd * np.abs(low[:, 0]).mean(), low[:, 1].mean()])
            cen.append(c)
            rad.append(min(float(np.percentile(np.linalg.norm(pts - c, axis=1), 90)), top * 0.5))
        return np.array(cen), rad
    side = {}
    for sign in (-1, 1):
        pts = low[np.sign(low[:, 0]) == sign]
        cy = np.percentile(pts[:, 1], [20, 80])
        for _ in range(12):
            hi = np.abs(pts[:, 1] - cy[1]) < np.abs(pts[:, 1] - cy[0])
            cy = [pts[~hi][:, 1].mean() if (~hi).any() else cy[0], pts[hi][:, 1].mean() if hi.any() else cy[1]]
        hi = np.abs(pts[:, 1] - cy[1]) < np.abs(pts[:, 1] - cy[0])
        side[sign] = [pts[hi], pts[~hi]]            # front (+y), back
    cen, rad = [], []
    for i, (pre, sd) in enumerate(LEGS):
        both = [side[-1][0 if pre == "f" else 1], side[1][0 if pre == "f" else 1]]
        c = np.array([np.abs(np.vstack(both)[:, 0]).mean(), np.vstack(both)[:, 1].mean()])
        c[0] *= -1 if sd == ".L" else 1
        cen.append(c)
        mine = side[-1 if sd == ".L" else 1][0 if pre == "f" else 1]
        wide = float(np.percentile(np.linalg.norm(mine - c, axis=1), 90))
        rad.append(min(wide, top * 0.5))  # a leg is not wider than half its length
    return np.array(cen), rad


def build_bones(arm, cen, top):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    knee, ankle = top * 0.5, top * ANKLE
    for i, (pre, side) in enumerate(LEGS):
        x, y = cen[i]
        parent = eb["spine"] if pre == "f" else eb["hips"]
        a = eb.new(pre + "leg1" + side)
        a.head, a.tail, a.roll, a.parent = (x, y, top), (x, y, knee), 0.0, parent
        b = eb.new(pre + "leg2" + side)
        b.head, b.tail, b.roll, b.parent = (x, y, knee), (x, y, ankle), 0.0, a
        c = eb.new(pre + "paw" + side)
        c.head, c.tail, c.roll, c.parent = (x, y, ankle), (x, y + 0.04, 0.0), 0.0, b
    bpy.ops.object.mode_set(mode="OBJECT")


def reweight(body, cen, rad, top):
    me = body.data
    for n in NEW:
        body.vertex_groups.new(name=n)
    gid = {g.name: g.index for g in body.vertex_groups}
    knee, ankle = top * 0.5, top * ANKLE
    for v in me.vertices:
        x, y, z = v.co
        if z > top * 1.3:
            continue
        d = [math.hypot(x - c[0], y - c[1]) for c in cen]
        i = int(np.argmin(d))
        wxy = float(smooth((rad[i] * 1.6 - d[i]) / (rad[i] * 0.8)))
        wz = float(smooth((top * 1.3 - z) / (top * 0.5)))
        w = wxy * wz
        if w <= 0.0:
            continue
        pre, side = LEGS[i]
        upper = float(smooth((z - knee + top * 0.1) / (top * 0.2)))
        paw = float(smooth((ankle + top * 0.06 - z) / (top * 0.12)))
        parts = {pre + "leg1" + side: upper * (1 - paw), pre + "leg2" + side: (1 - upper) * (1 - paw),
                 pre + "paw" + side: paw}
        old = [(g.group, g.weight) for g in v.groups if g.group not in (gid[n] for n in NEW)]
        for gi, gw in old:
            body.vertex_groups[gi].add([v.index], gw * (1 - w), "REPLACE")
        for n, pw in parts.items():
            if pw > 1e-4:
                body.vertex_groups[n].add([v.index], w * pw, "REPLACE")


def set_curve(act, path, index, frames, values, group):
    for fc in [f for f in act.fcurves if f.data_path == path and f.array_index == index]:
        act.fcurves.remove(fc)
    fc = act.fcurves.new(data_path=path, index=index, action_group=group)
    fc.keyframe_points.add(len(frames))
    for k, (f, v) in zip(fc.keyframe_points, zip(frames, values)):
        k.co = (f, v)
        k.interpolation = "LINEAR"
    fc.update()


def quat_curves(act, bone, frames, values):
    """values: one (angle about local X) per frame."""
    path = 'pose.bones["%s"].rotation_quaternion' % bone
    for fc in [f for f in act.fcurves if f.data_path == path]:
        act.fcurves.remove(fc)
    for idx in range(4):
        fc = act.fcurves.new(data_path=path, index=idx, action_group=bone)
        fc.keyframe_points.add(len(frames))
        for k, (f, a) in zip(fc.keyframe_points, zip(frames, values)):
            q = Quaternion((1, 0, 0), a)
            k.co = (f, q[idx])
            k.interpolation = "LINEAR"
        fc.update()


def ik(dy, dz, l1, l2):
    """Planar two-bone IK, knee forward: the ankle at (dy forward, dz down) from the hip -> (hip, knee) angles
    about the bones' X, + swinging the paw forward; the leg's reach is respected."""
    d = min(math.hypot(dy, dz), (l1 + l2) * 0.995)
    phi = math.atan2(dy, dz)
    alpha = math.acos((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))
    beta = math.acos((l2 * l2 + d * d - l1 * l1) / (2 * l2 * d))
    return phi + alpha, -(alpha + beta)


def stride_at(u, duty, half, lift):
    """The ankle's (forward offset, lift) at phase u: back along the ground at one speed while it is down, then a
    lifted swing forward that leaves and lands moving back at that speed (a Hermite arc), the paw up within a frame
    or two."""
    if u < duty:
        return half - 2 * half * u / duty, 0.0
    s = (u - duty) / (1 - duty)
    v = -2 * half / duty * (1 - duty)         # the ground's speed, per unit of the swing
    h00, h10, h01, h11 = 2 * s ** 3 - 3 * s ** 2 + 1, s ** 3 - 2 * s ** 2 + s, -2 * s ** 3 + 3 * s ** 2, s ** 3 - s ** 2
    return h00 * -half + h10 * v + h01 * half + h11 * v, lift * math.sin(math.pi * s) ** 0.4


def animate(arm, top, gaits):
    """gaits: {clip: (duty, half stride, lift, body drop, bob)}, all but the duty in belly heights `top`."""
    sign = {n: 1.0 if arm.data.bones[n].matrix_local.to_3x3().col[0][0] >= 0 else -1.0 for n in NEW}
    up = arm.data.bones["root"].matrix_local.to_3x3().inverted() @ Vector((0, 0, 1))
    knee, ankle = top * 0.5, top * ANKLE
    l1, l2 = top - knee, knee - ankle
    for act in bpy.data.actions:
        keyed = [fc for fc in act.fcurves if fc.data_path.startswith("pose.bones")]
        base = max(keyed, key=lambda f: len(f.keyframe_points))
        frames = [k.co[0] for k in base.keyframe_points]
        span = frames[-1] - frames[0]
        gait = gaits.get(act.name, (0, 0, 0, 0, 0))
        duty, half, lift, drop, bob = [v * (top if i else 1.0) for i, v in enumerate(gait)]
        drop = max(drop, (l1 + l2) - math.sqrt(((l1 + l2) * 0.97) ** 2 - half ** 2) + top * 0.02)   # reach both ends

        def body_drop(u):
            """The crouch and its bob: lowest in mid-stance, twice a cycle."""
            return drop + bob * math.cos(math.tau * 2 * (u - duty / 2))

        if act.name in gaits:
            # the borrowed rig's walk surges and squashes the whole body, which no planted paw can follow: hold it
            for idx in range(3):
                set_curve(act, 'pose.bones["root"].location', idx, frames,
                          [-body_drop(((f - frames[0]) / span) % 1.0) * up[idx] for f in frames], "root")
                set_curve(act, 'pose.bones["root"].scale', idx, frames, [1.0] * len(frames), "root")
        for i, (pre, side) in enumerate(LEGS):
            phase = 0.0 if (pre == "f") == (side == ".L") else 0.5       # a trot: the diagonal pair together
            if len(LEGS) == 2:
                phase = 0.0 if side == ".L" else 0.5
            vals = {"leg1": [], "leg2": [], "paw": []}
            for f in frames:
                u0 = ((f - frames[0]) / span) % 1.0 if span else 0.0
                u = (u0 + phase) % 1.0
                t1 = t2 = 0.0
                if act.name in gaits:
                    dy, z = stride_at(u, duty, half, lift)
                    t1, t2 = ik(dy, top - body_drop(u0) - ankle - z, l1, l2)
                vals["leg1"].append(t1)
                vals["leg2"].append(t2)
                vals["paw"].append(-(t1 + t2))
            for part, v in vals.items():
                quat_curves(act, pre + part + side, frames, [x * sign[pre + part + side] for x in v])


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    species = args[0]
    opt = dict(a.split("=") for a in args[1:])
    top_share = float(opt.get("top", 0.42))
    scale = float(opt.get("reach", 1.0))      # the stride's half length, as a multiple of the default
    path = os.path.join(REPO, "art/kin", species, species + ".glb")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30       # the clips are keyed at 30 fps: the importer's 24 would re-time them
    bpy.ops.import_scene.gltf(filepath=path)
    global LEGS
    LEGS = BIPED if opt.get("legs") == "2" else QUAD
    NEW[:] = [p + n + sd for p, sd in LEGS for n in ("leg1", "leg2", "paw")]
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    body = bpy.data.objects["Body"]
    co = np.array([v.co[:] for v in body.data.vertices])
    top = float(co[:, 2].max()) * top_share
    cen, rad = legs_of(co, top)
    print("LEGS", species, "top", round(top, 3), "centres", cen.round(3).tolist(), "radii", np.round(rad, 3).tolist())
    build_bones(arm, cen, top)
    reweight(body, cen, rad, top)
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    gaits = {n: (g[0], g[1] * scale, *g[2:]) for n, g in GAITS.items()}
    animate(arm, top, gaits)
    boki_rig.export(path, tangents=True)
    glb_tangents.fix(path)
    print("LEGS built", species)


main()
