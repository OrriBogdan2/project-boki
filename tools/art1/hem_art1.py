"""Hem / Lisette (ART-1, item 108 + 76b): the fitted Meshy scan (hem_source.py) for the body and outfit, scripted geometry for the head, hair, hands, scarf and gear, on
the contract armature with one painted atlas; saved as a .blend for tools/art1/hem_clips.py, which keys the clips and exports the .glb:
  blender -b --factory-startup --python tools/art1/hem_art1.py -- WORKDIR SOURCE.blend SCAN_BASE_COLOR.png HEAD.blend HEAD_BASE_COLOR.png FACE_PLATE.png
Shapes: hem_sculpt.py; paint: hem_paint.py. Budget: 15k triangles, the bow included (S1). The bow is skinned in the .glb on
x_weapon (hand.L); the nocked needle stays a separate piece on x_arrow, resting in the quiver (item 76b).
tools/blender/breaker_art1.py is the pattern (sculpt_kit's chart seams, density-scaled unwrap, per-texel paint)."""
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import hem_paint as P
import hem_sculpt as H
import imgio
import hem_sdf as S
import warden_kit as K

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
_a = sys.argv[sys.argv.index("--") + 1:]
WORK, SOURCE, SCAN_TEX, HEAD, HEAD_TEX, PLATE = _a[0], _a[1], _a[2], _a[3], _a[4], _a[5]
ATLAS = 2048
RELIEF = 2.6            # slope of the relief map per unit of painted height
F = np.float32
LSLOT = {H.SKIN: "skin", 0: "skin", H.LID: "skin", H.NAIL: "skin", H.LIP: "skin", H.EAR_IN: "skin", H.HAIR: "hair", H.NEEDLE: "metal",
         H.PORC: "leather", H.GOLD: "cloth", H.SCARF: "cloth", H.FEATHER: "leather", H.PAULDRON: "cloth", H.CORSET: "cloth", H.CORSET_SEAM: "cloth", H.TROUSER: "cloth", H.BOOT: "leather",
         H.BOOT_TOP: "leather", H.LACE: "leather", H.JACKET: "cloth", H.JACKET_DK: "cloth", H.CUFF: "cloth", H.TAPE: "leather",
         H.LEATHER: "leather", H.BUCKLE: "metal", H.STEEL: "metal", H.THREAD: "cloth"}


class ScanPaint:
    """Colours from the fitted scan: the nearest point on its surface, by texel. (mathutils' BVH, one query a texel.)"""

    def __init__(self, me, tex, tri_keep=None):
        me.calc_loop_triangles()
        n = len(me.vertices)
        co = np.empty(n * 3, np.float64)
        me.vertices.foreach_get("co", co)
        self.v = co.reshape(-1, 3)
        lt = me.loop_triangles
        self.t = np.empty(len(lt) * 3, np.int32)
        lt.foreach_get("vertices", self.t)
        self.t = self.t.reshape(-1, 3)
        li = np.empty(len(lt) * 3, np.int32)
        lt.foreach_get("loops", li)
        uv = np.empty(len(me.loops) * 2, F)
        me.uv_layers.active.data.foreach_get("uv", uv)
        self.uv = uv.reshape(-1, 2)[li.reshape(-1, 3)]
        if tri_keep is not None:
            keep = tri_keep(self.t)
            self.t, self.uv = self.t[keep], self.uv[keep]
        self.bvh = BVHTree.FromPolygons(self.v.tolist(), self.t.tolist(), all_triangles=True)
        self.tex = tex

    def sample(self, pts):
        N = len(pts)
        hit = np.empty((N, 3), F)
        tri = np.empty(N, np.int32)
        fn = self.bvh.find_nearest
        for i, q in enumerate(pts.tolist()):
            h = fn(q)
            hit[i] = h[0]
            tri[i] = h[2]
        a, b, c = [self.v[self.t[tri, j]] for j in range(3)]
        v0, v1, v2 = b - a, c - a, hit - a
        d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
        d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
        den = np.maximum(d00 * d11 - d01 * d01, 1e-14)
        w1 = (d11 * d20 - d01 * d21) / den
        w2 = (d00 * d21 - d01 * d20) / den
        w0 = 1 - w1 - w2
        uv = self.uv[tri]
        u = uv[:, 0, :] * w0[:, None] + uv[:, 1, :] * w1[:, None] + uv[:, 2, :] * w2[:, None]
        h, w = self.tex.shape[:2]
        return self.tex[np.clip(((1 - u[:, 1]) % 1) * h, 0, h - 1).astype(int), np.clip((u[:, 0] % 1) * w, 0, w - 1).astype(int)]


def arm_weight(ob):
    """Per vertex, its share on the arm bones. (Fitted, the arms hang through the hips, so paint and tests keep them apart.)"""
    arm = {g.index for g in ob.vertex_groups if g.name.startswith(("upper_arm", "forearm", "hand"))}
    return np.array([sum(g.weight for g in v.groups if g.group in arm) for v in ob.data.vertices], F)


def head_slot(c, z):
    """A surface per triangle of the head scan: hair black, the cowl and tie red, the rest skin."""
    return np.where(c.max(1) < 0.22, 1, np.where((c[:, 0] > c[:, 1] * 2.6) & (c[:, 1] < 0.2), 2, 0))


def ob_from(name, v, q):
    me = bpy.data.meshes.new(name)
    me.vertices.add(len(v))
    me.vertices.foreach_set("co", np.asarray(v, F).ravel())
    n = q.shape[1]
    me.loops.add(len(q) * n)
    me.polygons.add(len(q))
    me.loops.foreach_set("vertex_index", q.astype(np.int32).ravel())
    me.polygons.foreach_set("loop_start", np.arange(0, len(q) * n, n, dtype=np.int32))
    me.update(calc_edges=True)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def verts(ob):
    a = np.empty(len(ob.data.vertices) * 3, F)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def set_verts(ob, v):
    ob.data.vertices.foreach_set("co", np.asarray(v, F).ravel())
    ob.data.update()


def lowpoly(name, fld, tris, cull=None, keep=None):
    """Surface nets, drop what never shows (cull(points) -> True), specks gone, then decimate to `tris`.
    keep(points) -> 0..1: where to hold the detail (the eyes)."""
    v, q = S.surface_nets(fld)
    ob = ob_from(name, v, q)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    if cull is not None:
        gone = cull(v)
        bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(gone)[0].tolist()], context="VERTS")
    seen = set()
    isl = []
    for vv in bm.verts:
        if vv.index in seen or not vv.is_valid:
            continue
        st = [vv]
        seen.add(vv.index)
        cur = []
        while st:
            a = st.pop()
            cur.append(a)
            for e in a.link_edges:
                o = e.other_vert(a)
                if o.index not in seen:
                    seen.add(o.index)
                    st.append(o)
        isl.append(cur)
    mx = max(len(c) for c in isl)
    bmesh.ops.delete(bm, geom=[a for c in isl if len(c) < max(mx * 0.004, 30) for a in c], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    nt = sum(len(pl.vertices) - 2 for pl in ob.data.polygons)
    print(name, "dense", nt, "->", tris, flush=True)
    m = ob.modifiers.new("d", "DECIMATE")
    m.ratio = min(1.0, tris / max(nt, 1))
    m.use_collapse_triangulate = True
    if keep is not None:
        vg = ob.vertex_groups.new(name="keep")
        w = keep(verts(ob))
        for i in range(len(w)):
            vg.add([i], float(w[i]), "REPLACE")
        m.vertex_group = "keep"
        m.vertex_group_factor = 8.0
        m.invert_vertex_group = False
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="d")
    if keep is not None:
        ob.vertex_groups.clear()
    orient(ob, fld)
    return ob


def orient(ob, fld):
    """Faces outward, whichever way surface nets wound them: the field's gradient decides."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    cen = np.array([f.calc_center_median() for f in bm.faces], F)
    nrm = np.array([f.normal for f in bm.faces], F)
    g = fld.grad(cen)
    if (np.sum(nrm * g, axis=1) > 0).mean() < 0.5:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


AXES = np.array(((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)), F)


def chart_seams(ob, min_faces=24):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    n = len(bm.faces)
    nrm = np.array([f.normal for f in bm.faces], F)
    lab = np.argmax(nrm @ AXES.T, axis=1)
    nb = [[e2.index for e in f.edges for e2 in e.link_faces if e2.index != f.index] for f in bm.faces]
    for _ in range(4):
        new = lab.copy()
        for i in range(n):
            c = np.bincount(lab[nb[i]], minlength=6) if nb[i] else None
            if c is not None and c.max() >= 2:
                new[i] = int(np.argmax(c))
        lab = new
    for _ in range(6):
        seen = np.zeros(n, bool)
        changed = False
        for i in range(n):
            if seen[i]:
                continue
            st, comp = [i], []
            seen[i] = True
            while st:
                a = st.pop()
                comp.append(a)
                for b in nb[a]:
                    if not seen[b] and lab[b] == lab[a]:
                        seen[b] = True
                        st.append(b)
            if len(comp) < min_faces:
                out = [lab[b] for a in comp for b in nb[a] if lab[b] != lab[a]]
                if out:
                    lab[comp] = int(np.bincount(out).argmax())
                    changed = True
        if not changed:
            break
    for e in bm.edges:
        fs = e.link_faces
        e.seam = len(fs) == 2 and lab[fs[0].index] != lab[fs[1].index]
    bm.to_mesh(ob.data)
    bm.free()


def grid_mesh(name, P3, close=False):
    """A sheet from a rows x cols grid of points, as an object."""
    r, c = P3.shape[:2]
    v = P3.reshape(-1, 3)
    q = []
    for i in range(r - 1):
        for j in range(c - 1):
            q.append((i * c + j, (i + 1) * c + j, (i + 1) * c + j + 1, i * c + j + 1))
    return ob_from(name, v, np.array(q, np.int32))


def tube(name, pts, r, sides=4, close=False):
    pts = np.array(pts, F)
    tg = np.gradient(pts, axis=0)
    tg /= np.maximum(np.linalg.norm(tg, axis=1, keepdims=True), 1e-6)
    a = np.cross(tg[0], (0.123, 0.456, 0.88))
    a /= np.linalg.norm(a)
    v, f = [], []
    n = len(pts)
    for i in range(n):
        a = a - tg[i] * (a @ tg[i])
        a /= np.linalg.norm(a)
        b = np.cross(tg[i], a)
        for j in range(sides):
            t = j / sides * math.tau
            v.append(pts[i] + (a * math.cos(t) + b * math.sin(t)) * r)
    for i in range(n - 1):
        for j in range(sides):
            k = (j + 1) % sides
            f.append((i * sides + j, i * sides + k, (i + 1) * sides + k, (i + 1) * sides + j))
    return ob_from(name, np.array(v), np.array(f, np.int32))


def ribbon_grid(path, flip=0.0):
    """A scarf tail as a strip: rows along its path, three columns across, gently twisted, tapering to a point."""
    c = spline(np.array(path, F), 13)
    w = np.interp(np.linspace(0, 1, 13), np.linspace(0, 1, len(H.SCARF_W)), np.array(H.SCARF_W, F))
    tg = np.gradient(c, axis=0)
    tg /= np.linalg.norm(tg, axis=1, keepdims=True)
    P3 = np.zeros((13, 3, 3), F)
    side = np.array((1.0, 0.0, 0.0), F)
    for i in range(13):
        side = side - tg[i] * float(side @ tg[i])          # (carried along the path: it never flips where the path falls straight)
        side /= np.linalg.norm(side)
        nrm = np.cross(side, tg[i])
        tw = 0.10 * math.sin(i * 0.7)
        sd = side * math.cos(tw) + nrm * math.sin(tw)
        off = np.cross(tg[i], sd)
        for j in range(3):
            P3[i, j] = c[i] + sd * w[i] * (j - 1) + off * flip + off * 0.008 * (1 if j == 1 else 0)
    return P3


def add_weights(ob, W):
    names = list(W)
    a = np.stack([W[n] for n in names], 1).astype(F)
    idx = np.argsort(-a, axis=1)[:, :4]
    top = np.take_along_axis(a, idx, 1)
    top[top < top[:, :1] * 0.04] = 0
    top /= np.maximum(top.sum(1, keepdims=True), 1e-6)
    for i, n in enumerate(names):
        vg = ob.vertex_groups.new(name=n)
        rows = np.nonzero((idx == i) & (top > 0))
        for v, c in zip(rows[0].tolist(), rows[1].tolist()):
            vg.add([v], float(top[v, c]), "REPLACE")


def chain(pts, names, p):
    pts = np.array(pts, F)
    ab = pts[1:] - pts[:-1]
    best = np.full(len(p), 9.0, F)
    seg = np.zeros(len(p), int)
    tt = np.zeros(len(p), F)
    for i in range(len(ab)):
        t = np.clip(((p - pts[i]) @ ab[i]) / float(ab[i] @ ab[i]), 0, 1)
        d = np.linalg.norm(p - (pts[i] + ab[i] * t[:, None]), axis=1)
        m = d < best
        best[m], seg[m], tt[m] = d[m], i, t[m]
    n = len(names)
    u = seg + tt - 0.5
    W = {}
    for i, nm in enumerate(names):
        W[nm] = np.clip(1 - np.abs(u - i), 0, 1)
    W[names[0]] = np.maximum(W[names[0]], (u <= 0) * 1.0)
    W[names[-1]] = np.maximum(W[names[-1]], (u >= n - 1) * 1.0)
    return W


def add_bone(arm, name, head, tail, parent, roll_to=None):
    e = arm.data.edit_bones.new(name)
    e.head, e.tail = Vector(tuple(float(a) for a in head)), Vector(tuple(float(a) for a in tail))
    if roll_to is not None:
        e.align_roll(Vector(roll_to))
    e.parent = arm.data.edit_bones[parent]
    return e


def spline(pts, n):
    pts = np.array(pts, F)
    L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    ts = np.linspace(0, L[-1], n)
    return np.stack([np.interp(ts, L, pts[:, i]) for i in range(3)], 1).astype(F)


def grp_allow(pg, bone, g, pts):
    """A leg's verts take only that leg's bones, plus the trunk's near the hip."""
    z = pts[:, 2]
    m = (g == pg).astype(F)
    if pg == 0:
        return m + (g != 0) * (z > 0.74)
    if bone.startswith("thigh"):
        return m + (g == 0) * (z < 0.86)
    return m


def main():
    t0 = time.time()
    K.reset()
    rig_path = os.path.join(REPO, "art/wardens/src/hem_rig.json")
    rig = K.load_rig(rig_path)
    J = H.joints(rig_path)
    print("sculpting", flush=True)
    needle = [((-0.108, -0.080, 1.822), (0.128, -0.070, 1.694), 0.0040)]         # the silver pin, through the tie, eye up to her left
    hn = H.needle_field(needle, 0.0012, 0.0095, 0.030)
    with bpy.data.libraries.load(SOURCE) as (df, dt):
        dt.objects = ["Src", "Low"]
    src_me, low = dt.objects[0].data, dt.objects[1]
    bpy.context.scene.collection.objects.link(low)
    for mi in low.modifiers:
        low.modifiers.remove(mi)
    low.data.materials.clear()
    low.parent = None
    print("scan paint", flush=True)
    tex = imgio.load(SCAN_TEX)
    aw = arm_weight(dt.objects[0])
    sp_body = ScanPaint(src_me, tex, lambda t: aw[t].mean(1) <= 0.5)
    sp_arm = ScanPaint(src_me, tex, lambda t: aw[t].mean(1) > 0.5)
    low_aw = arm_weight(low)
    with bpy.data.libraries.load(HEAD) as (df, dh):
        dh.objects = ["HSrc", "HLow"]
    hlow = dh.objects[1]
    bpy.context.scene.collection.objects.link(hlow)
    hlow.data.materials.clear()
    sp_head = ScanPaint(dh.objects[0].data, imgio.load(HEAD_TEX))
    P.PLATE = imgio.load(PLATE)
    hR, hinfo = H.right_hand(J)
    hL = H.left_hand(J)
    qv = H.quiver()
    qn = H.quiver_arrows()
    bw = H.bow()
    ar = H.arrow()
    sh = H.shears()
    print("fields", time.time() - t0, flush=True)

    parts = []

    def part(name, fld, tris, paint, density=1.0, xf=None, group="body", slot=None, cull=None, keep=None, ob=None):
        o = ob if ob is not None else lowpoly(name, fld, tris, cull, keep)
        parts.append({"ob": o, "slot": slot, "paint": paint, "density": density, "xf": xf, "group": group, "f": fld, "name": name})
        return parts[-1]

    hxf = H.head_xf
    part("skin_head", None, 0, "headscan", 3.4, None, "headscan", None, ob=hlow)
    part("hair_needles", hn, 110, "needle", 2.6, None, "head", "metal")
    th = tube("pin_thread", [(-0.108, -0.080, 1.822), (-0.124, -0.082, 1.795), (-0.132, -0.085, 1.760), (-0.122, -0.090, 1.728)], 0.0015, 3)
    part("pin_thread", None, 0, "string", 0.15, None, "head", "glow", ob=th)
    part("Low", None, 0, "scan", 1.25, None, "scan", None, ob=low)
    part("handR", hR, 800, "handR", 2.0, None, "hand")
    part("handL", hL, 500, "handL", 1.7, None, "hand")
    part("quiver", qv, 240, "quiver", 0.9, None, "gear")
    part("quiver_arrows", qn, 240, "gearlab", 1.0, None, "gear")
    part("shears", sh, 140, "gearlab", 1.0, H.shears_to_model, "gear")
    bxf = lambda p: H.bow_to_model(p, J)
    pb = part("bow", bw, 850, "bow", 1.2, bxf, "bow")
    # the arrow: at rest it stands in the quiver as one more needle, eye up (x_arrow's rest)
    a, b = H.QUIVER_A, H.QUIVER_B
    u = (b - a) / np.linalg.norm(b - a)
    side = np.cross(u, (0, -1, 0))
    side = side / np.linalg.norm(side)
    ar_at = b + u * 0.42 + side * 0.008        # the nock
    ar_y = -u
    ar_x = np.cross(ar_y, (0.3, 0.6, 0.74))
    ar_x /= np.linalg.norm(ar_x)
    ar_z = np.cross(ar_x, ar_y)
    arxf = lambda p: ar_at + np.asarray(p, F)[..., 0:1] * ar_x + np.asarray(p, F)[..., 1:2] * ar_y + np.asarray(p, F)[..., 2:3] * ar_z
    part("arrow", ar, 120, "gearlab", 1.4, arxf, "arrow")
    print("low parts", time.time() - t0, flush=True)

    # the scarf's tails, each two-sided
    for tail in ("scarftailR", "scarftailL"):
        for nm, g, dens in ((tail, ribbon_grid(H.SCARF_PATHS[tail], 0.0), 0.7), (tail + "_in", ribbon_grid(H.SCARF_PATHS[tail], -0.004), 0.45)):
            ob = grid_mesh(nm, g)
            bm = bmesh.new()
            bm.from_mesh(ob.data)
            bm.faces.ensure_lookup_table()
            out = sum(float(Vector(f.normal).y) for f in bm.faces)
            if (out > 0) != nm.endswith("_in"):     # (the outer side faces back, away from her)
                bmesh.ops.reverse_faces(bm, faces=bm.faces)
            bm.to_mesh(ob.data)
            bm.free()
            part(nm, None, 0, "ribbon", dens, None, tail, "cloth", ob=ob)
    # the glowing string
    Y = H.STRING_Y
    Zs = H.STRING_Z
    st = tube("string", [(0, Y, Zs), (0, Y, 0.0), (0, Y, -Zs)], 0.0032, 4)
    part("string", None, 0, "string", 0.15, bxf, "string", "glow", ob=st)

    # ----------------------------------------------------- UVs
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        ob = p["ob"]
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.quads_convert_to_tris()
        bpy.ops.object.mode_set(mode="OBJECT")
        if p["group"] not in ("scan", "headscan"):
            chart_seams(ob, 24 if len(ob.data.polygons) > 300 else 8)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        if not ob.data.uv_layers:
            ob.data.uv_layers.new(name="UVMap")
        if p["group"] in ("scan", "headscan"):      # (charts by facing folded over themselves here, two triangles sharing paint: smart project never overlaps)
            bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.0, correct_aspect=False)
        else:
            bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=0.0, correct_aspect=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        ob.select_set(False)
        me = ob.data
        lv = np.empty(len(me.loops), np.int32)
        me.loops.foreach_get("vertex_index", lv)
        uv = np.empty(len(me.loops) * 2, F)
        me.uv_layers.active.data.foreach_get("uv", uv)
        uv = uv.reshape(-1, 2)
        vs = verts(ob)
        t3 = vs[lv.reshape(-1, 3)]
        tu = uv.reshape(-1, 3, 2)
        a3 = np.linalg.norm(np.cross(t3[:, 1] - t3[:, 0], t3[:, 2] - t3[:, 0]), axis=1).sum() * 0.5
        e1, e2 = tu[:, 1] - tu[:, 0], tu[:, 2] - tu[:, 0]
        a2 = np.abs(e1[:, 0] * e2[:, 1] - e1[:, 1] * e2[:, 0]).sum() * 0.5
        k = math.sqrt(a3 * p["density"] ** 2 / max(a2, 1e-9))
        me.uv_layers.active.data.foreach_set("uv", (uv * k).ravel())
    obs = [p["ob"] for p in parts]
    for ob in obs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, scale=True, margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    print("uvs", time.time() - t0, flush=True)

    # ----------------------------------------------------- paint
    atlas = np.zeros((ATLAS, ATLAS, 3), F)
    mask = np.zeros((ATLAS, ATLAS), bool)
    relief = np.zeros((ATLAS, ATLAS), F)
    for p in parts:
        ob = p["ob"]
        me = ob.data
        lv = np.empty(len(me.loops), np.int32)
        me.loops.foreach_get("vertex_index", lv)
        uv = np.empty(len(me.loops) * 2, F)
        me.uv_layers.active.data.foreach_get("uv", uv)
        vs = verts(ob)
        tri = lv.reshape(-1, 3)
        f = p["f"]
        if f is not None:
            nrm = f.grad(vs.astype(F), f.vox * 1.5)
        else:
            me.update()
            nn = np.empty(len(vs) * 3, F)
            me.vertices.foreach_get("normal", nn)
            nrm = nn.reshape(-1, 3)
        arm_tri = low_aw[tri].mean(1) > 0.5 if p["paint"] == "scan" else None
        rt = S.raster(uv.reshape(-1, 3, 2), vs[tri], nrm[tri], tri, ATLAS, part=1)
        m = rt["id"] >= 0
        idx = np.nonzero(m)
        pts = rt["p"][idx]
        nn = rt["n"][idx]
        nn /= np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-6)
        lab = np.zeros(len(pts), np.int32)
        if f is not None:
            pts = f.project(pts, 2)
            nn = f.grad(pts, f.vox * 0.9)
            lab = f.label(pts)
        nm = p["paint"]
        if nm == "headscan":
            rgb = P.headscan(sp_head.sample(pts), pts, nn)
        elif nm == "needle":
            rgb = P.needle(pts, nn)
        elif nm == "scan":
            on_arm = S.raster(uv.reshape(-1, 3, 2)[arm_tri], vs[tri][arm_tri], nrm[tri][arm_tri], tri[arm_tri], ATLAS, part=1)["id"][idx] >= 0
            c0 = np.empty((len(pts), 3), F)
            c0[on_arm] = sp_arm.sample(pts[on_arm])
            c0[~on_arm] = sp_body.sample(pts[~on_arm])
            rgb = P.scan(c0, pts, nn)
        elif nm in ("handR", "handL"):
            rgb = P.skin_hand(pts, nn, lab, f)
        elif nm == "quiver":
            rgb = P.quiver(pts, nn, lab, f)
        elif nm == "bow":
            rgb = P.bowc(pts, nn, lab, f)
        elif nm == "ribbon_placeholder":
            rgb = None
        elif nm == "scarf":
            rgb = P.scarf(pts, nn, f)
        elif nm == "ribbon":
            rgb = P.scarf(pts, nn, None)
        elif nm == "gearlab":
            rgb = P.gearlab(pts, nn, lab)
        else:
            rgb = P.string(pts, nn)
        atlas[idx] = rgb
        mask |= m
        if p["paint"] in ("scan", "quiver"):
            relief[idx] = 1.0
        if p["group"] == "headscan":
            p["tri_slot"] = head_slot(sp_head.sample(vs[tri].mean(1)), vs[tri].mean(1)[:, 2])
        if f is not None and not p["slot"]:
            cen = vs[tri].mean(1).astype(F)
            p["tri_lab"] = f.label(f.project(cen, 1))
        if p["xf"] is not None:
            set_verts(ob, p["xf"](vs))
            nrm = (p["xf"](nrm) - p["xf"](np.zeros((1, 3), F)))
        p["nrm"] = nrm
        if p["name"] == "scarftailR":  # (a texel in the middle of the scarf's island: the string samples solid red, at every mip)
            mi = len(idx[0]) // 2
            mid_uv = ((idx[1][mi] + 0.5) / ATLAS, (idx[0][mi] + 0.5) / ATLAS)
        print("painted", p["name"], len(tri), int(m.sum()), round(time.time() - t0, 1), flush=True)
    for so in [p["ob"] for p in parts if p["name"] in ("string", "pin_thread")]:
        so.data.uv_layers.active.data.foreach_set("uv", np.tile(np.array(mid_uv, F), len(so.data.loops)))
    img = S.dilate(atlas, mask, 10)
    # fine relief: a normal map from the paint, in atlas space (tangent +U, bitangent +V): red stitches stand up, dark seams sink
    lum = img @ np.array((0.3, 0.55, 0.15), F)
    red = np.clip((img[:, :, 0] - img[:, :, 1] * 1.6) * 3.0, 0, 1)
    hgt = (lum * 0.55 + red * 0.9) * relief
    hgt = (hgt + np.roll(hgt, 1, 0) + np.roll(hgt, -1, 0) + np.roll(hgt, 1, 1) + np.roll(hgt, -1, 1)) / 5.0
    du = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * RELIEF
    dv = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * RELIEF
    nm = np.stack((-du, -dv, np.ones(du.shape, F)), 2)
    nm /= np.linalg.norm(nm, axis=2, keepdims=True)
    nrm_png = os.path.join(WORK, "normal.png")
    imgio.save((nm * 0.5 + 0.5)[::-1], nrm_png)
    os.makedirs(WORK, exist_ok=True)
    png = os.path.join(WORK, "atlas.png")
    imgio.save(img[::-1], png)
    print("atlas coverage %.3f" % mask.mean(), flush=True)

    # ----------------------------------------------------- the armature and Hem's own bones
    arm = K.build_armature(rig)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    sx = float(J["hand.R"][0])
    kn, tp = hinfo["knuckles"], hinfo["tips"]
    z0 = (0, 1, 0)
    add_bone(arm, "fing_a1.R", kn["a"][0], kn["a"][1], "hand.R", z0)
    add_bone(arm, "fing_a2.R", kn["a"][1], kn["a"][3], "fing_a1.R", z0)
    add_bone(arm, "fing_b1.R", kn["r"][0], kn["r"][1], "hand.R", z0)
    add_bone(arm, "fing_b2.R", kn["r"][1], kn["r"][3], "fing_b1.R", z0)
    t = hinfo["thumb"]
    add_bone(arm, "thumb1.R", t[0], t[1], "hand.R", (0, 0, 1))
    add_bone(arm, "thumb2.R", t[1], t[3], "thumb1.R", (0, 0, 1))
    for s, n in ((1, "R"), (-1, "L")):
        hx = s * float(J["shin.R"][0])
        add_bone(arm, "foot." + n, (hx, 0, 0.082), (hx, 0.17, 0.03), "shin." + n, (0, 0, 1))
        e = hxf(np.array((s * H.EYE[0], H.EYE[1], H.EYE[2]), F))
        add_bone(arm, "lid." + n, e, e + (s * 0.03, 0, 0), "head", (0, 0, 1))
        b0 = hxf(np.array((s * 0.041, 0.086, 1.6465), F))
        add_bone(arm, "brow." + n, b0, b0 + (0, 0.03, 0), "head", (0, 0, 1))
    # the bow: on the left hand, the limbs bend, the string's nock comes back to the right hand
    c, A, Sd = H.grip_frame(J)
    add_bone(arm, "bow", c, c + A * 0.1, "hand.L", tuple(Sd))
    add_bone(arm, "bow_t", bxf(np.array((0, 0.02, 0.11), F)), bxf(np.array((0, Y, Zs), F)), "bow", tuple(Sd))
    add_bone(arm, "bow_b", bxf(np.array((0, 0.02, -0.11), F)), bxf(np.array((0, Y, -Zs), F)), "bow", tuple(Sd))
    add_bone(arm, "bow_s", bxf(np.array((0, Y, 0), F)), bxf(np.array((0, Y - 0.05, 0), F)), "bow", tuple(A))
    add_bone(arm, "arrow", ar_at, ar_at + ar_y * 0.2, "hips", tuple(ar_z))
    chains = {}
    # the ponytail's chain, down the scan's own hair
    hv = verts(hlow)
    tail_m = (hv[:, 1] < -0.115) & (hv[:, 2] < 1.73) & (head_slot(sp_head.sample(hv), hv[:, 2]) == 1)
    zs = np.linspace(1.72, hv[tail_m, 2].min() + 0.006, 7)
    js = []
    for i in range(7):
        q = tail_m & (np.abs(hv[:, 2] - zs[i]) < 0.03)
        js.append(hv[q].mean(0))
    js = np.array(js, F)
    chains["tail"] = js
    for i in range(6):
        add_bone(arm, "spring_tail_%d" % i, js[i], js[i + 1], "head" if i == 0 else "spring_tail_%d" % (i - 1))
    add_bone(arm, "spring_tail_6", js[-1], js[-1] + (js[-1] - js[-2]) * 0.3, "spring_tail_5")
    # the scarf's chains
    for tail in ("scarftailR", "scarftailL"):
        js = spline(np.array(H.SCARF_PATHS[tail], F), 7)
        chains[tail] = js
        for i in range(6):
            add_bone(arm, "spring_%s_%d" % (tail, i), js[i], js[i + 1], "hips" if i == 0 else "spring_%s_%d" % (tail, i - 1))
        add_bone(arm, "spring_%s_6" % tail, js[-1], js[-1] + (js[-1] - js[-2]) * 0.3, "spring_%s_5" % tail)
    bpy.ops.object.mode_set(mode="OBJECT")
    print("armature", time.time() - t0, flush=True)

    # ----------------------------------------------------- skin
    for p in parts:
        ob = p["ob"]
        vs = verts(ob)
        nm, grp = p["name"], p["group"]
        one = np.ones(len(vs), F)
        if grp == "scan":
            continue                # (its weights came with the fit)
        if grp == "headscan":
            cc = sp_head.sample(vs)
            cowl = (head_slot(cc, vs[:, 2]) == 2) & (vs[:, 2] < 1.60)
            tail = (vs[:, 1] < -0.115) & (vs[:, 2] < 1.73) & (head_slot(cc, vs[:, 2]) == 1)
            hd_w = S.smooth(1.455, 1.50, vs[:, 2]) * (~cowl) + 1e-3
            W = chain(chains["tail"], ["spring_tail_%d" % i for i in range(6)], vs)
            W = {k: w * tail for k, w in W.items()}
            roots = S.smooth(1.70, 1.62, vs[:, 2]) * tail
            W["spring_tail_0"] = W["spring_tail_0"] * (1 - S.smooth(1.72, 1.68, vs[:, 2]) * 0 )
            W["head"] = hd_w * (~tail) + tail * (1 - roots)
            W["hips"] = (1 - S.smooth(1.455, 1.50, vs[:, 2])) * (~tail) + cowl * 1.0
        elif grp == "head":
            W = {"head": one}
        elif grp in ("scarftailR", "scarftailL"):
            W = chain(chains[grp], ["spring_%s_%d" % (grp, i) for i in range(6)], vs)
            W["hips"] = S.smooth(0.09, 0.03, np.linalg.norm(vs - chains[grp][0], axis=1)) * 3.0
        elif nm == "handR":
            W = p["f"].weights(vs, 0.006)
        elif nm == "handL":
            W = {"hand.L": one}
        elif grp == "gear":
            W = {"hips": one}
        elif grp == "arrow":
            W = {"arrow": one}
        elif nm == "bow":
            f = H.bow_to_model
            c0 = vs - c
            zz = c0 @ A
            W = {"bow": S.smooth(0.14, 0.08, np.abs(zz)), "bow_t": S.smooth(0.08, 0.14, zz), "bow_b": S.smooth(-0.08, -0.14, zz)}
        elif nm == "string":
            zz = (vs - c) @ A
            W = {"bow_s": (np.abs(zz) < 0.1) * 1.0, "bow_t": (zz >= 0.1) * 1.0, "bow_b": (zz <= -0.1) * 1.0}
        else:
            W = {"hips": one}
        add_weights(ob, W)
    # lids and brows on the head mesh
    ph = next(p for p in parts if p["name"] == "skin_head")
    ob = ph["ob"]
    vs = verts(ob)
    for s, n in ((1, "R"), (-1, "L")):
        e = hxf(np.array((s * H.EYE[0], H.EYE[1], H.EYE[2]), F))
        up = (vs[:, 2] > e[2] + 0.001 * 0) & (np.linalg.norm((vs - e) * (0.9, 1, 1), axis=1) < 0.027)
        vl = ob.vertex_groups.new(name="lid." + n)
        d = np.linalg.norm((vs - e) * (0.85, 1, 1.0), axis=1)
        w = S.smooth(0.0265, 0.0185, d) * S.smooth(e[2] - 0.0015, e[2] + 0.0025, vs[:, 2])
        for i in np.nonzero(w > 0.02)[0].tolist():
            vl.add([i], float(w[i]) * 0.95, "REPLACE")
            ob.vertex_groups["head"].add([i], 1.0 - float(w[i]) * 0.95, "REPLACE")
        b0 = hxf(np.array((s * 0.041, 0.086, 1.6465), F))
        w = np.exp(-(np.linalg.norm((vs - b0) * (0.72, 1, 1.5), axis=1) / 0.027) ** 2) * (vs[:, 1] > 0.05) * (vs[:, 2] > e[2] + 0.006)
        vb = ob.vertex_groups.new(name="brow." + n)
        for i in np.nonzero(w > 0.04)[0].tolist():
            vb.add([i], float(w[i]) * 0.9, "REPLACE")
            ob.vertex_groups["head"].add([i], 1.0 - float(w[i]) * 0.9, "REPLACE")

    # ----------------------------------------------------- materials (one atlas), slots, join
    image = bpy.data.images.load(png)
    image.name = "atlas"
    nimg = bpy.data.images.load(nrm_png)
    nimg.name = "normal"
    nimg.colorspace_settings.name = "Non-Color"
    mats = {}

    def mat(slot):
        if slot not in mats:
            m = bpy.data.materials.new(slot + "-atlas")
            m.use_nodes = True
            b = m.node_tree.nodes["Principled BSDF"]
            t = m.node_tree.nodes.new("ShaderNodeTexImage")
            t.image = image
            m.node_tree.links.new(t.outputs[0], b.inputs[0])
            tn = m.node_tree.nodes.new("ShaderNodeTexImage")
            tn.image = nimg
            nn = m.node_tree.nodes.new("ShaderNodeNormalMap")
            m.node_tree.links.new(tn.outputs[0], nn.inputs["Color"])
            m.node_tree.links.new(nn.outputs[0], b.inputs["Normal"])
            b.inputs["Roughness"].default_value = 0.8
            mats[slot] = m
        return mats[slot]

    for p in parts:
        ob = p["ob"]
        me = ob.data
        if p["slot"]:
            me.materials.append(mat(p["slot"]))
        elif p["group"] == "headscan":
            for sl in ("skin", "hair", "cloth"):
                me.materials.append(mat(sl))
            me.polygons.foreach_set("material_index", p["tri_slot"].astype(np.int32))
        elif p["group"] == "scan":
            me.materials.append(mat("cloth"))       # (one surface: slots picked per triangle cut jagged edges round the skin)
        else:
            # per triangle, from the sculpt's labels (read before the part moved)
            lab = p["tri_lab"]
            slots = sorted({LSLOT.get(int(a), "cloth") for a in np.unique(lab)})
            for s in slots:
                me.materials.append(mat(s))
            ix = np.array([slots.index(LSLOT.get(int(a), "cloth")) for a in lab], np.int32)
            me.polygons.foreach_set("material_index", ix)
        for pl in me.polygons:
            pl.use_smooth = True
        n = p["nrm"]
        n = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
        me.normals_split_custom_set_from_vertices(n.tolist())

    ROOM = {"hair_needles": 0.0, "pin_thread": 0.0, "quiver_arrows": 0.0, "arrow": 0.0, "shears": 0.1, "string": 0.0,
            "skin_head": 0.0, "Low": 0.55, "handR": 0.3, "handL": 0.3, "bow": 0.0, "scarftailR": 0.3, "scarftailL": 0.3, "scarftailR_in": 0.0, "scarftailL_in": 0.0}
    for p in parts:
        me = p["ob"].data
        at = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        a = np.ones(len(me.vertices) * 4, F)
        a[3::4] = ROOM.get(p["name"], 0.7)
        at.data.foreach_set("color", a)

    def join(obs, name):
        bpy.ops.object.select_all(action="DESELECT")
        for o in obs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        o.name = o.data.name = name
        return o

    bd = join([p["ob"] for p in parts if p["group"] not in ("bow", "string", "arrow")], "hem")
    bo = join([p["ob"] for p in parts if p["group"] in ("bow", "string")], "bow_mesh")
    aro = join([p["ob"] for p in parts if p["group"] == "arrow"], "arrow_mesh")
    for o in (bd, bo, aro):
        o.parent = arm
        md = o.modifiers.new("Armature", "ARMATURE")
        md.object = arm
    # empties: anchors, the FX points on the bow, the seat the bow takes on the rig's Gun node
    crown = float(rig["land"]["crown"])
    K.anchor(arm, "head", "anchor_head_top", (0, 0.0, float(H.head_xf(np.array((0, 0, 1.81), F))[2])))
    K.anchor(arm, "hips", "anchor_chest", (0, 0.11, 1.17))
    K.anchor(arm, "bow", "anchor_nock", tuple(bxf(np.array((0, Y, 0), F))))
    K.anchor(arm, "bow", "weapon_muzzle", tuple(bxf(np.array((0, 0.05, 0.0), F))))
    K.anchor(arm, "bow", "anchor_bow_root", tuple(bxf(np.array((0, -0.10, 0.0), F))))
    K.anchor(arm, "bow_t", "halo_bow_top", tuple(bxf(np.array((0, Y, Zs), F))))
    K.anchor(arm, "bow", "halo_bow_mid", tuple(bxf(np.array((0, Y, 0.0), F))))
    K.anchor(arm, "bow_b", "halo_bow_low", tuple(bxf(np.array((0, Y, -Zs), F))))
    for ob in (bd, bo, aro):
        ob.data.validate(clean_customdata=False)
    for nm, ob in (("hem", bd), ("bow", bo), ("arrow", aro)):
        print("tris", nm, K.tris([ob]), flush=True)
    print("tris total", K.tris([bd, bo, aro]), time.time() - t0, flush=True)
    # (for anims) key points
    bpy.context.scene["pinch"] = [float(a) for a in kn["a"][2]]
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "hem_art1.blend"))


def H_P(fn, flip):
    return fn(flip)


main()
