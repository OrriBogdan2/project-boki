"""Leg bones for a Meshy scan on the borrowed Glomwort rig (root, hips, spine, neck, head: no legs, so its legs rode the
body and never stepped). Finds the scan's four feet on the ground, adds the shared four-legged chain to the file's
armature (fleg1/fleg2/fpaw and hleg1/hleg2/hpaw, .L/.R, under spine and hips, as boki_gait.four_legs wants) and moves
each leg's vertices onto it, faded into the body's own weights at the belly. The file's bones are not moved, renamed
or dropped, and the mesh is not touched: only weights are added. Called by reclip.py for a module with SCAN_LEGS.

SCAN_LEGS: {"top": belly height in the file's metres, where a leg meets the body (read off its slices), "band": m it
fades over above that (optional)}."""
import bpy
import numpy as np

FOOT_CUT = 0.025     # m above the lowest vertex: the slice the feet are found in
SLICE = 0.01         # m between the slices a leg's middle is followed up through
GRIP = 1.25          # x the foot's radius: a vertex this near the leg's middle is all leg
FADE = 1.7           # x the foot's radius: past this it is all body
ANKLE = 0.03         # m: the ankle's height
HIP_IN = 0.04        # m the hip sits above the belly, inside the body
TOE = 0.04           # m: the paw bone's length, forward


def _feet(v, z0):
    """The four foot clusters on the ground: k-means from the four corners of the slice (x: side, y: forward)."""
    f = v[v[:, 2] < z0 + FOOT_CUT][:, :2]
    c = np.array([[f[:, 0].max(), f[:, 1].max()], [f[:, 0].min(), f[:, 1].max()],
                  [f[:, 0].max(), f[:, 1].min()], [f[:, 0].min(), f[:, 1].min()]])
    for _ in range(40):
        lab = ((f[:, None] - c[None]) ** 2).sum(-1).argmin(1)
        c = np.array([f[lab == j].mean(0) for j in range(4)])
    r = np.array([np.percentile(np.linalg.norm(f[lab == j] - c[j], axis=1), 90) for j in range(4)])
    return c, r


def _column(v, c, r, z0, top):
    """The leg's middle (x, y) at each slice from the ground to its top, followed up from the foot."""
    zs = np.arange(z0, top + SLICE, SLICE)
    mids = []
    at = c.copy()
    for z in zs:
        s = v[(v[:, 2] >= z) & (v[:, 2] < z + SLICE)]
        near = s[np.linalg.norm(s[:, :2] - at, axis=1) < r * GRIP]
        if len(near) > 8:
            at = 0.6 * at + 0.4 * near[:, :2].mean(0)
        mids.append(at.copy())
    return zs, np.array(mids)


def fit(v, spec):
    """legs: name prefix and side -> foot (x, y), radius, slices, middles; from the body's world vertices."""
    z0 = float(v[:, 2].min())
    top = z0 + spec["top"]
    c, r = _feet(v, z0)
    front = np.argsort(-c[:, 1])[:2]
    legs = {}
    for j in range(4):
        pre = "f" if j in front else "h"
        sd = "L" if c[j, 0] < 0 else "R"      # vespyx_sides: L is -x
        zs, mids = _column(v, c[j], r[j], z0, top)
        legs[(pre, sd)] = {"foot": c[j], "r": float(r[j]), "zs": zs, "mids": mids, "z0": z0, "top": top}
    assert len(legs) == 4, "the feet did not split into one per corner: %s" % sorted(legs)
    return legs


def _bones(leg, pre, sd):
    """head, tail and parent of the leg's three bones, in the file's (Blender) axes."""
    z0, top, mids = leg["z0"], leg["top"], leg["mids"]
    hip = np.array([*mids[-1], top + HIP_IN])
    ankle = np.array([*leg["foot"], z0 + ANKLE])
    knee = 0.5 * (hip + ankle)
    knee[1] += -0.006 if pre == "f" else 0.012     # wrists fold back, hocks forward (four_legs' bend)
    toe = ankle + np.array([0, TOE, -ANKLE * 0.6])
    par = "spine" if pre == "f" else "hips"
    n1, n2, paw = "%sleg1.%s" % (pre, sd), "%sleg2.%s" % (pre, sd), "%spaw.%s" % (pre, sd)
    return [(n1, hip, knee, par), (n2, knee, ankle, n1), (paw, ankle, toe, n2)]


def add(arm, body, spec):
    """Adds the leg bones to `arm` and moves the legs' weights of `body` onto them. Returns the new bones' names."""
    mw = np.array(body.matrix_world)
    v = np.array([list(p.co) + [1.0] for p in body.data.vertices]) @ mw.T
    v = v[:, :3]
    legs = fit(v, spec)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    inv = np.array(arm.matrix_world.inverted())
    new = []
    for (pre, sd), leg in legs.items():
        for name, head, tail, par in _bones(leg, pre, sd):
            e = arm.data.edit_bones.new(name)
            e.head = (inv @ np.append(head, 1.0))[:3].tolist()
            e.tail = (inv @ np.append(tail, 1.0))[:3].tolist()
            e.parent = arm.data.edit_bones[par]
            e.roll = 0.0
            new.append(name)
    bpy.ops.object.mode_set(mode="OBJECT")
    _weights(body, v, legs, spec.get("band", 0.05))
    return new


def _weights(body, v, legs, band):
    """Each vertex low enough and near enough a leg's middle goes to that leg: paw below the ankle, the shin up to the
    knee, the thigh above, blended across each joint; faded into its own weights over `band` above the belly and
    between GRIP and FADE radii out from the middle."""
    n = len(v)
    best = np.full(n, np.inf)
    owner = np.full(n, -1)
    keys = list(legs)
    for k, key in enumerate(keys):
        leg = legs[key]
        i = np.clip(((v[:, 2] - leg["z0"]) / SLICE).astype(int), 0, len(leg["mids"]) - 1)
        d = np.linalg.norm(v[:, :2] - leg["mids"][i], axis=1) / leg["r"]
        closer = d < best
        best[closer] = d[closer]
        owner[closer] = k
    groups = {g.index: g for g in body.vertex_groups}
    for k, key in enumerate(keys):
        leg = legs[key]
        pre, sd = key
        z0, top = leg["z0"], leg["top"]
        ankle, knee = z0 + ANKLE, 0.5 * (z0 + ANKLE + top + HIP_IN)
        sel = np.nonzero((owner == k) & (best < FADE) & (v[:, 2] < top + band))[0]
        g1 = body.vertex_groups.new(name="%sleg1.%s" % (pre, sd))
        g2 = body.vertex_groups.new(name="%sleg2.%s" % (pre, sd))
        gp = body.vertex_groups.new(name="%spaw.%s" % (pre, sd))
        for i in sel:
            z = v[i, 2]
            radial = np.clip((FADE - best[i]) / (FADE - GRIP), 0.0, 1.0)
            height = np.clip((top + band - z) / band, 0.0, 1.0)
            w = float(radial * height)
            if w <= 0.01:
                continue
            paw = np.clip((ankle + 0.012 - z) / 0.024, 0.0, 1.0)
            thigh = np.clip((z - (knee - 0.015)) / 0.03, 0.0, 1.0)
            shin = 1.0 - paw - thigh * (1.0 - paw)
            thigh *= 1.0 - paw
            vert = body.data.vertices[i]
            for e in vert.groups:
                groups[e.group].add([int(i)], e.weight * (1.0 - w), "REPLACE")
            for g, part in ((gp, paw), (g2, shin), (g1, thigh)):
                if part * w > 0.005:
                    g.add([int(i)], float(part * w), "REPLACE")


def game_bones(arm, scale):
    """The armature's bones as boki_gait wants them: name -> (head, tail, parent) in game axes (build_boki.bl back)."""
    out = {}
    for b in arm.data.bones:
        h, t = arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local
        out[b.name] = ((h.x / scale, h.z / scale, -h.y / scale), (t.x / scale, t.z / scale, -t.y / scale),
                       b.parent.name if b.parent else None)
    return out
