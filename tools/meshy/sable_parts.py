"""Sable's (thief) pieces built in Blender by script on the fitted Meshy body (tools/meshy/fit_warden.py `scripted`),
from the art (ext/imagegen docs/art/gen/wardens_r2/sable_head_sheet + SABLE_REFS.md):

- side_hair(): the long white hair that frames both sides of her face, from the temples under the mask down past
  the jaw to the shoulders (the scan's hair is a cap that stops at the temples). Chunky tapered locks side by side,
  draped clear of the head, rigid on the head.
- headband(): the black band behind the domino mask, over the crown and down the sides of the head to the ears:
  a flat strip laid on the scan's hair by rays from inside the head, rigid on the head.

All in the fitted frame: Blender, +Z up, her front +Y, her right +X, soles on Z = 0.
"""
import math

import bpy
import numpy as np
from mathutils import Vector

import warden_parts as WP
import warden_props as WPR


def log(*a):
    print("SABLEPARTS", *a, flush=True)


def _hair_atlas(name, stops, size=128):
    """A gradient (v 0 root .. 1 tip) with fine strand lines across u: the locks' only texture."""
    img = bpy.data.images.new(name, size, size, alpha=False)
    px = np.ones((size, size, 4), np.float32)
    vs = np.array([s[0] for s in stops])
    cs = np.array([WP.hexcol(s[1]) for s in stops])
    lines = 0.9 + 0.1 * np.sin(np.arange(size) * 2.3) * np.sin(np.arange(size) * 0.7 + 1.0)
    for y in range(size):
        col = np.array([np.interp(y / (size - 1), vs, cs[:, k]) for k in range(3)])
        px[y, :, :3] = col[None, :] * lines[:, None]
    img.pixels = px.ravel()
    img.pack()
    return img


def side_hair(body, arm, sp):
    bvh = WP.body_bvh([body])
    rng = np.random.default_rng(5)
    bld = WP.Builder()
    nl = int(sp.get("locks", 6))
    r0 = float(sp.get("r", 0.013))
    for side in ("L", "R"):
        sx = 1.0 if side == "R" else -1.0           # (her right +X)
        front = np.asarray(sp["front"], float)      # control points of the front lock (her right side's)
        back = np.asarray(sp["back"], float)        # ... and of the back lock
        for k in range(nl):
            u = k / max(nl - 1, 1)
            ctrl = front * (1.0 - u) + back * u
            ctrl = ctrl * np.array([sx, 1.0, 1.0])
            ctrl = ctrl + np.array([0.0, 0.0, 1.0]) * rng.uniform(-0.01, 0.01) * np.linspace(0, 1, len(ctrl))[:, None]
            p, _ = WP.resample([tuple(c) for c in ctrl], int(sp.get("samples", 24)))
            for _it in range(2):
                p[1:-1] = p[1:-1] * 0.5 + (p[:-2] + p[2:]) * 0.25
            p = WP.drape(bvh, [tuple(c) for c in p], len(p), float(sp.get("clear", 0.012)), iters=8, smooth=0.1,
                         length=None)
            s_arr = WP.arclen(p)
            L = s_arr[-1]
            rk = r0 * rng.uniform(0.85, 1.15)
            radii = []
            for s in s_arr:
                f = s / max(L, 1e-6)
                radii.append(max(0.0015, rk * (0.75 + 0.5 * math.sin(math.pi * min(1.0, f * 1.4))) * (1.0 - 0.8 * f ** 3)))
            bld.tube(p, radii, 6, 0.02, 0.98, 0.02, 0.98, "lock", list(s_arr), cap_start=True, cap_end=True)
    ob = bld.object("SideHair")
    img = _hair_atlas("sidehair_atlas", sp.get("colours", [(0.0, "9a9cb4"), (0.35, "dcdcea"), (1.0, "f6f6fc")]))
    ob.data.materials.append(WPR._mat("hair-sidehair", img))
    WPR._skin(ob, arm, {sp.get("bone", "head"): range(len(ob.data.vertices))})
    log("side hair: %d locks a side, %d tris" % (nl, sum(len(f) - 2 for f in bld.f)))
    return ob


def headband(body, arm, sp):
    """The band in a plane through `centre` holding X, its top tilted `tilt` rad toward the back; points every few
    degrees over +-`reach` deg from the top, each on the scan's outer surface along the ray from the centre, `out` m
    off it."""
    bvh = WP.body_bvh([body])
    c = np.asarray(sp["centre"], float)
    t = float(sp.get("tilt", 0.2))
    ex = np.array([1.0, 0.0, 0.0])
    ey = np.array([0.0, -math.sin(t), math.cos(t)])
    nrm = np.cross(ex, ey)
    out = float(sp.get("out", 0.004))
    w = float(sp.get("width", 0.022)) * 0.5
    th = float(sp.get("thick", 0.005))
    reach = math.radians(float(sp.get("reach", 85.0)))
    n = int(sp.get("samples", 41))
    pts, dirs = [], []
    for i in range(n):
        a = -reach + 2 * reach * i / (n - 1)
        d = math.sin(a) * ex + math.cos(a) * ey
        # (from outside in: the outermost surface, the scan's hair over the scalp; an ear in the way is a spike the
        # median below drops)
        hit = bvh.ray_cast(Vector((c + d * 0.4).tolist()), Vector((-d).tolist()))
        if hit[0] is None:
            continue
        pts.append(np.array(hit[0][:]) + d * out)
        dirs.append(d)
    pts = np.array(pts)
    # (a smooth curve: the scan's hair strands make the hit radius jitter)
    r = np.linalg.norm(pts - c, axis=1)
    r = np.array([np.median(r[max(0, i - 4):i + 5]) for i in range(len(r))])
    for _it in range(3):
        r[1:-1] = r[1:-1] * 0.5 + (r[:-2] + r[2:]) * 0.25
    pts = c + np.array(dirs) * r[:, None]
    cells = WPR.Cells({"band": sp.get("colour", "1a1820"), "edge": sp.get("edge", "3a3644")}, n=2, size=32)
    img = cells.image("headband_atlas")
    u0, v0, u1, v1 = cells.box["band"]
    bld = WP.Builder()
    base = len(bld.v)
    for i, p in enumerate(pts):
        d = dirs[i]
        for q in (p - nrm * w, p + nrm * w, p - d * th + nrm * w, p - d * th - nrm * w):
            bld.v.append(q)
            bld.uv.append((u0 + (u1 - u0) * i / max(len(pts) - 1, 1), (v0 + v1) * 0.5))
            bld.part.append("band")
            bld.s.append(0.0)
    for i in range(len(pts) - 1):
        a, b = base + i * 4, base + (i + 1) * 4
        for j in range(4):
            j2 = (j + 1) % 4
            bld.f.append((a + j, a + j2, b + j2, b + j))
    for i, flip in ((0, True), (len(pts) - 1, False)):
        a = base + i * 4
        bld.f.append((a + 3, a + 2, a + 1, a) if flip else (a, a + 1, a + 2, a + 3))
    ob = bld.object("Headband")
    ob.data.materials.append(WPR._mat("leather-headband", img))
    WPR._skin(ob, arm, {sp.get("bone", "head"): range(len(ob.data.vertices))})
    log("headband: %d points, r %.3f..%.3f, %d tris" % (len(pts), r.min(), r.max(), sum(len(f) - 2 for f in bld.f)))
    return ob


def build(body, arm, rig, K, spec):
    """fit_warden's `scripted` hook: every piece in spec, as skinned meshes."""
    out = []
    if spec.get("side_hair"):
        out.append(side_hair(body, arm, spec["side_hair"]))
    if spec.get("headband"):
        out.append(headband(body, arm, spec["headband"]))
    return out
