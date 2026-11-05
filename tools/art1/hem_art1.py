"""Hem (ART-1, item 108 + 76b): the sculpt to a game mesh on the contract armature with a painted atlas, saved as a .blend
for tools/art1/hem_anims.py, which keys the clips and exports the .glb:
  blender -b --factory-startup --python tools/art1/hem_art1.py -- WORKDIR
Shapes: hem_sculpt.py; paint: hem_paint.py. Budget: 20k triangles, the bow included. The bow is skinned in the .glb on
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
WORK = sys.argv[sys.argv.index("--") + 1]
ATLAS = 2048
F = np.float32
LSLOT = {H.SKIN: "skin", 0: "skin", H.LID: "skin", H.NAIL: "skin", H.LIP: "skin", H.EAR_IN: "skin", H.HAIR: "hair", H.NEEDLE: "metal",
         H.PORC: "leather", H.GOLD: "cloth", H.SCARF: "cloth", H.FEATHER: "leather", H.PAULDRON: "cloth", H.CORSET: "cloth", H.CORSET_SEAM: "cloth", H.TROUSER: "cloth", H.BOOT: "leather",
         H.BOOT_TOP: "leather", H.LACE: "leather", H.JACKET: "cloth", H.JACKET_DK: "cloth", H.CUFF: "cloth", H.TAPE: "leather",
         H.LEATHER: "leather", H.BUCKLE: "metal", H.STEEL: "metal", H.THREAD: "cloth"}


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


def face_chart(ob):
    """The face as one chart, seam-free: every seam through it goes, its edge becomes the seam. -> its polygon indices."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    front = np.array([f.calc_center_median().y > 0.015 and f.normal.y > -0.2 and f.calc_center_median().z > 1.43 for f in bm.faces], bool)
    for e in bm.edges:
        fs = e.link_faces
        if len(fs) == 2:
            a, b = front[fs[0].index], front[fs[1].index]
            e.seam = (a != b) or (e.seam and not a)
    bm.to_mesh(ob.data)
    bm.free()
    return np.nonzero(front)[0]


def planar_uv(ob, polys):
    """Those polygons' UVs straight from the front (x, z): no folds, so nothing overlaps; the unwrap scale stays."""
    me = ob.data
    uv = me.uv_layers.active.data
    for pi in polys.tolist():
        pl = me.polygons[pi]
        for li in pl.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv[li].uv = (co.x, co.z)


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
    hd = H.head()
    mk = H.mask(hd)
    hr = H.hair(hd)
    locks = {k: H.lock(v, H.LOCK_R[k][0], H.LOCK_R[k][1], spread=0.0 if k == "tail" else 0.0085) for k, v in H.LOCKS.items()}
    ey = H.eyes()
    hn = H.needle_field(H.HAIR_NEEDLES, 0.0012, 0.0095, 0.030)
    tr = H.figure(J)
    H.legs(tr, J)
    H.dress(tr)
    armR, armL = H.arm(J, 1, "R"), H.arm(J, -1, "L")
    hR, hinfo = H.right_hand(J)
    hL = H.left_hand(J)
    qv = H.quiver()
    qn = H.quiver_arrows()
    cw = H.cowl()
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

    def head_cull(v):
        th = np.degrees(np.arctan2(np.abs(v[:, 0]), v[:, 1] - 0.01))
        zh = H.S_interp(th, H.HAIRLINE[:, 0], H.HAIRLINE[:, 1])
        return (v[:, 2] > zh + 0.012) | (v[:, 2] < 1.40)

    def eye_keep(v):
        a = np.array((H.EYE[0], H.EYE[1] + 0.012, H.EYE[2] + 0.004), F)
        d = np.minimum(np.linalg.norm((v - a * (1, 1, 1)) * (1, 1, 1.1), axis=1), np.linalg.norm((v - a * (-1, 1, 1)) * (1, 1, 1.1), axis=1))
        mouth = np.linalg.norm((v - np.array((0, 0.094, 1.552), F)) * (0.8, 1, 1), axis=1)
        nose = np.linalg.norm((v - np.array((0, 0.100, 1.590), F)) * (1.3, 1, 0.8), axis=1)
        return np.clip(np.maximum(1.15 - d / 0.03, np.maximum(1.0 - mouth / 0.034, 0.9 - nose / 0.03)), 0.02, 1)

    part("skin_head", hd, 5000, "head", 3.6, hxf, "head", "skin", head_cull, eye_keep)
    part("mask", mk, 520, "mask", 2.4, hxf, "head", None)
    part("hair", hr, 1900, "hair", 1.4, hxf, "head", None)
    part("lockR", locks["lockR"], 320, "lock", 0.6, hxf, "lockR", "hair")
    part("lockL", locks["lockL"], 320, "lock", 0.6, hxf, "lockL", "hair")
    part("tail", locks["tail"], 700, "lock", 0.8, hxf, "tail", "hair")
    part("eyes", ey, 220, "eyes", 5.0, hxf, "head", "skin")   # (on the skin slot: the eyes slot would take the player's tint, hers stay green)
    part("hair_needles", hn, 120, "needle", 1.0, hxf, "head", "metal")
    part("trunk", tr, 3800, "trunk", 1.0, None, "trunk", None, lambda v: (v[:, 2] > 1.40))
    part("armR", armR, 900, "trunk", 1.0, None, "arm")
    part("armL", armL, 900, "trunk", 1.0, None, "arm")
    part("handR", hR, 1150, "handR", 2.0, None, "hand")
    part("handL", hL, 750, "handL", 1.7, None, "hand")
    part("cowl", cw, 560, "scarf", 1.0, None, "gear", "cloth")
    part("quiver", qv, 340, "quiver", 0.9, None, "gear")
    part("quiver_arrows", qn, 340, "gearlab", 1.0, None, "gear")
    part("shears", sh, 240, "gearlab", 1.0, H.shears_to_model, "gear")
    bxf = lambda p: H.bow_to_model(p, J)
    pb = part("bow", bw, 1150, "bow", 1.2, bxf, "bow")
    # the arrow: at rest it stands in the quiver as one more needle, eye up (x_arrow's rest)
    a, b = H.QUIVER_A, H.QUIVER_B
    u = (b - a) / np.linalg.norm(b - a)
    side = np.cross(u, (0, -1, 0))
    side = side / np.linalg.norm(side)
    ar_at = b + u * 0.30 + side * 0.008        # the nock
    ar_y = -u
    ar_x = np.cross(ar_y, (0.3, 0.6, 0.74))
    ar_x /= np.linalg.norm(ar_x)
    ar_z = np.cross(ar_x, ar_y)
    arxf = lambda p: ar_at + np.asarray(p, F)[..., 0:1] * ar_x + np.asarray(p, F)[..., 1:2] * ar_y + np.asarray(p, F)[..., 2:3] * ar_z
    part("arrow", ar, 200, "gearlab", 1.4, arxf, "arrow")
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
        chart_seams(ob, 24 if len(ob.data.polygons) > 300 else 8)
        face = face_chart(ob) if p["name"] == "skin_head" else None
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        if not ob.data.uv_layers:
            ob.data.uv_layers.new(name="UVMap")
        bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=0.0, correct_aspect=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        ob.select_set(False)
        if face is not None:
            planar_uv(ob, face)
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
            if p["name"] == "trunk":
                lab = H.dress_labels(pts, lab)
        nm = p["paint"]
        if nm == "head":
            rgb = P.head(pts, nn, lab, f)
        elif nm == "mask":
            rgb = P.mask(pts, nn, lab, f)
        elif nm == "hair":
            rgb = P.hairc(pts, nn, f, lab)
        elif nm == "lock":
            rgb = P.lockc(pts, nn)
        elif nm == "eyes":
            rgb = P.eyes(pts, nn)
        elif nm == "needle":
            rgb = P.needle(pts, nn)
        elif nm == "trunk":
            rgb = P.trunk(pts, nn, lab, f, None)
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
        if f is not None and not p["slot"]:
            cen = vs[tri].mean(1).astype(F)
            p["tri_lab"] = f.label(f.project(cen, 1))
            if p["name"] == "trunk":
                p["tri_lab"] = H.dress_labels(cen, p["tri_lab"])
        if p["xf"] is not None:
            set_verts(ob, p["xf"](vs))
            nrm = (p["xf"](nrm) - p["xf"](np.zeros((1, 3), F)))
        p["nrm"] = nrm
        if p["name"] == "string":      # (one solid red: every loop on the island's middle, so nothing bleeds in dashes)
            cu = uv.reshape(-1, 2).mean(0)
            me.uv_layers.active.data.foreach_set("uv", np.tile(cu, len(uv) // 2).astype(F))
        print("painted", p["name"], len(tri), int(m.sum()), round(time.time() - t0, 1), flush=True)
    img = S.dilate(atlas, mask, 10)
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
    for nm in ("lockR", "lockL", "tail"):
        pts = hxf(np.array(H.LOCKS[nm], F))
        i0 = 2 if nm != "tail" else 2
        js = spline(pts[i0:], 5 if nm != "tail" else 7)
        chains[nm] = js
        count = len(js) - 1
        for i in range(count):
            add_bone(arm, "spring_%s_%d" % (nm, i), js[i], js[i + 1], "head" if i == 0 else "spring_%s_%d" % (nm, i - 1))
        add_bone(arm, "spring_%s_%d" % (nm, count), js[-1], js[-1] + (js[-1] - js[-2]) * 0.3, "spring_%s_%d" % (nm, count - 1))
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
        if grp in ("lockR", "lockL", "tail"):
            ch = chains[nm]
            names = ["spring_%s_%d" % (nm, i) for i in range(len(ch) - 1)]
            W = chain(ch, names, vs)
            # the root rides the head
            near = 1.0 - S.smooth(0.0, 0.05, (vs - ch[0]) @ ((ch[1] - ch[0]) / np.linalg.norm(ch[1] - ch[0])))
            W["head"] = near * 2.0
        elif nm == "skin_head":
            W = {"head": S.smooth(1.385, 1.445, vs[:, 2]) + 1e-3, "hips": S.smooth(1.445, 1.385, vs[:, 2])}
        elif grp == "head":
            W = {"head": one}
        elif grp in ("scarftailR", "scarftailL"):
            W = chain(chains[grp], ["spring_%s_%d" % (grp, i) for i in range(6)], vs)
            W["hips"] = S.smooth(0.09, 0.03, np.linalg.norm(vs - chains[grp][0], axis=1)) * 3.0
        elif nm == "trunk":
            W = tr.weights(vs, 0.03, grp_allow)
            W = {k2: w for k2, w in W.items() if w.max() > 1e-4}
        elif nm in ("armR", "armL"):
            f = p["f"]
            W = f.weights(vs, 0.02)
            s = "R" if nm == "armR" else "L"
            W["hips"] = 0.0 * one
            W = {k2: w for k2, w in W.items() if w.max() > 1e-4}
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
    mats = {}

    def mat(slot):
        if slot not in mats:
            m = bpy.data.materials.new(slot + "-atlas")
            m.use_nodes = True
            b = m.node_tree.nodes["Principled BSDF"]
            t = m.node_tree.nodes.new("ShaderNodeTexImage")
            t.image = image
            m.node_tree.links.new(t.outputs[0], b.inputs[0])
            b.inputs["Roughness"].default_value = 0.8
            mats[slot] = m
        return mats[slot]

    for p in parts:
        ob = p["ob"]
        me = ob.data
        if p["slot"]:
            me.materials.append(mat(p["slot"]))
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

    ROOM = {"lockR": 0.25, "lockL": 0.25, "tail": 0.5, "hair_needles": 0.0, "quiver_arrows": 0.0, "arrow": 0.0, "shears": 0.1, "string": 0.0,
            "skin_head": 0.1, "mask": 0.1, "eyes": 0.0, "handR": 0.3, "handL": 0.3, "bow": 0.0, "scarftailR": 0.3, "scarftailL": 0.3, "scarftailR_in": 0.0, "scarftailL_in": 0.0}
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
