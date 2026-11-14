"""Breaker, the Barnacle Knight (ART-1): the sculpt to a game mesh on the contract armature with a painted atlas, saved as a .blend for
tools/art1/breaker_anims.py, which keys the clips and exports the .glb:
  blender -b --factory-startup --python tools/art1/breaker_art1.py -- WORKDIR
Shapes: breaker_sculpt.py; paint: breaker_paint.py. Budget: 20k triangles, weapon and shield included."""
import faulthandler
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

faulthandler.enable()
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import breaker_paint as P
import breaker_sculpt as B
import imgio
import sculpt_kit as S
import warden_kit as K

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
WORK = sys.argv[sys.argv.index("--") + 1]
ATLAS = 2048


def ob_from(name, v, q):
    me = bpy.data.meshes.new(name)
    me.vertices.add(len(v))
    me.vertices.foreach_set("co", v.astype(np.float32).ravel())
    n = q.shape[1]
    me.loops.add(len(q) * n)
    me.polygons.add(len(q))
    me.loops.foreach_set("vertex_index", q.astype(np.int32).ravel())
    me.polygons.foreach_set("loop_start", np.arange(0, len(q) * n, n, dtype=np.int32))
    me.update(calc_edges=True)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def lowpoly(name, fld, tris, outer=None, blur=0.0):
    """Surface nets, then a decimate down to `tris`, dropping specks. outer: keep only the side of a thin shell that
    faces away from this field (a mantle over a body), as a clean open sheet: decimating both skins of a thin
    cloth bridges them into tents."""
    keep_d = fld.d
    fld.d = S.blurred(fld.d, int(round(blur / fld.vox)))
    v, q = S.surface_nets(fld)
    fn = np.cross(v[q[:, 1]] - v[q[:, 0]], v[q[:, 2]] - v[q[:, 0]])
    cn = v[q].mean(1)
    gr = fld.grad(cn.astype(np.float32))
    fld.d = keep_d
    if (fn * gr).sum(1).mean() < 0:      # (outward winding)
        q = q[:, ::-1]
        fn = -fn
    if outer is not None:
        q = q[(fn * outer.grad(cn.astype(np.float32))).sum(1) > 0.0]
        used, inv = np.unique(q, return_inverse=True)
        v, q = v[used], inv.reshape(-1, 4)
    ob = ob_from(name, v, q)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    # drop floaters (tears leave crumbs)
    seen = set()
    isl = []
    for vv in bm.verts:
        if vv.index in seen:
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
    keep = max(len(c) for c in isl) * 0.004
    bmesh.ops.delete(bm, geom=[a for c in isl if len(c) < max(keep, 40) for a in c], context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)      # (every island outward: small ones hide behind a flipped wall)
    bm.to_mesh(ob.data)
    bm.free()
    nt = sum(len(pl.vertices) - 2 for pl in ob.data.polygons)
    print(name, "dense", nt, "->", tris, flush=True)
    m = ob.modifiers.new("d", "DECIMATE")
    m.ratio = min(1.0, tris / max(nt, 1))
    m.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="d")
    # (a sharp sculpt leaves non-manifold knots that stop the collapse: weld them and go again)
    for _ in range(3):
        nt = len(ob.data.polygons)
        if nt <= tris * 1.15:
            break
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.002)
        bmesh.ops.holes_fill(bm, edges=bm.edges, sides=8)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bm.to_mesh(ob.data)
        bm.free()
        m = ob.modifiers.new("d", "DECIMATE")
        m.ratio = min(1.0, tris / max(len(ob.data.polygons), 1))
        bpy.ops.object.modifier_apply(modifier="d")
    return ob


AXES = np.array(((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)), np.float32)


def chart_seams(ob, min_faces=24):
    """Seams for a clean unwrap: each face goes to the axis it faces, the labels are smoothed over neighbours and small
    islands merged, so the charts follow the form instead of the decimated triangles."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    n = len(bm.faces)
    nrm = np.array([f.normal for f in bm.faces], np.float32)
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


def verts(ob):
    a = np.empty(len(ob.data.vertices) * 3, np.float32)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def set_verts(ob, v):
    ob.data.vertices.foreach_set("co", v.astype(np.float32).ravel())
    ob.data.update()


def tube(name, pts, r, sides=4, step=0.05, tw=9.0):
    """A low rope: rings along a path. Returns the object; `aux` holds (along, round) for the paint's lay."""
    pts = np.array(pts, np.float32)
    L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    n = max(2, int(L[-1] / step) + 1)
    ts = np.linspace(0, L[-1], n)
    c = np.stack([np.interp(ts, L, pts[:, i]) for i in range(3)], 1)
    tg = np.gradient(c, axis=0)
    tg /= np.maximum(np.linalg.norm(tg, axis=1, keepdims=True), 1e-6)
    up = np.array((0.123, 0.456, 0.88), np.float32)
    v, f, aux = [], [], []
    a = np.cross(tg[0], up)
    a /= np.linalg.norm(a)
    for i in range(n):
        a = a - tg[i] * (a @ tg[i])
        a /= np.linalg.norm(a)
        b = np.cross(tg[i], a)
        for j in range(sides):
            t = j / sides * math.tau
            v.append(c[i] + (a * math.cos(t) + b * math.sin(t)) * r)
            aux.append((ts[i], j / sides))
    for i in range(n - 1):
        for j in range(sides):
            k = (j + 1) % sides
            f.append((i * sides + j, i * sides + k, (i + 1) * sides + k, (i + 1) * sides + j))
    ob = ob_from(name, np.array(v), np.array(f))
    return ob, np.array(aux, np.float32)


def grp_allow(pg, bone, g, pts):
    """Skin weights: a limb's verts take only that limb's bones, plus the joint's trunk bones near the joint."""
    z = pts[:, 2]
    m = (g == pg).astype(np.float32)
    if pg == 0:      # a trunk prim on a limb vert: only at the shoulder or the hip
        return m + (g != 0) * ((g <= 2) * (z > 1.0) + (g >= 3) * (z > 0.5))
    if bone.startswith(("upper_arm", "pauldron")):
        return m + (g == 0) * (z > 0.98)
    if bone.startswith("thigh"):
        return m + (g == 0) * (z < 0.68)
    return m


def add_weights(ob, W):
    """{bone: array}, top 4 per vertex, normalised."""
    names = list(W)
    a = np.stack([W[n] for n in names], 1)
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
    """Weights along a chain of joints: each vert between its two nearest joints."""
    pts = np.array(pts, np.float32)
    ab = pts[1:] - pts[:-1]
    best = np.full(len(p), 9.0, np.float32)
    seg = np.zeros(len(p), int)
    tt = np.zeros(len(p), np.float32)
    for i in range(len(ab)):
        t = np.clip(((p - pts[i]) @ ab[i]) / float(ab[i] @ ab[i]), 0, 1)
        d = np.linalg.norm(p - (pts[i] + ab[i] * t[:, None]), axis=1)
        m = d < best
        best[m], seg[m], tt[m] = d[m], i, t[m]
    W = {n: np.zeros(len(p), np.float32) for n in names}
    n = len(names)
    u = seg + tt - 0.5
    for i, nm in enumerate(names):
        W[nm] = np.clip(1 - np.abs(u - i), 0, 1)
    W[names[0]] = np.maximum(W[names[0]], (u <= 0) * 1.0)
    W[names[-1]] = np.maximum(W[names[-1]], (u >= n - 1) * 1.0)
    return W


def add_bone(arm, name, head, tail, parent, roll_to=None):
    e = arm.data.edit_bones.new(name)
    e.head, e.tail = Vector(head), Vector(tail)
    if roll_to is not None:
        e.align_roll(Vector(roll_to))
    e.parent = arm.data.edit_bones[parent]
    return e


def rigid(n, bone):
    return {bone: np.ones(n, np.float32)}


HOT = "leather-wood-hot"
MATS = {"wood": HOT, "iron": "metal-atlas", "brass": "brass-atlas", "soft": "cloth-atlas", "face": "brass-compass-hot",
        "lure": "glow-lure", "eyes": "eyes-mood", "moss": "cloth-moss", "scan": "leather-art-hot"}


def main():
    t0 = time.time()
    K.reset()
    rig_path = os.path.join(REPO, "art/wardens/src/breaker_rig.json")
    rig = K.load_rig(rig_path)
    J = B.joints(rig_path)
    sx = float(J["hand.R"][0])
    print("sculpting", flush=True)
    parts = []

    def part(name, fld, tris, mat, paint, density=1.0, xf=None, group="body", bone="hips", outer=None, blur=0.0, **kw):
        ob = lowpoly(name, fld, tris, outer, blur)
        for pr, lab, bn in getattr(fld, "rv", []):      # (the rivets: on the paint's field, not the mesh)
            fld.add(pr, 0.0015, lab, bn)
        p = {"ob": ob, "slot": mat, "paint": paint, "density": density, "xf": xf, "group": group, "f": fld, "f2": None,
             "aux": None, "name": name, "bone": bone, "blur": blur}
        p.update(kw)
        parts.append(p)
        return p

    hl = B.hull(J)
    part("hull", hl, 2200, "scan", "scanpaint", 3.2)
    scn = np.load(os.path.join(WORK, "scan_low.npz"))
    c_at, c_n = B.compass_on(scn["v"])
    dl = S.Field(c_at - 0.16, c_at + 0.16, 0.0022)
    rot = np.array(((1, 0, 0), (0, c_n[2], c_n[1]), (0, -c_n[1], c_n[2])), np.float32)    # (local z on the chest's normal)
    dl.add(S.cyl(c_at - c_n * 0.012, rot, 0.1, 0.018, 0.006), 0.0, 1)     # a flat dial, 0.1 m: the art's compass, 30 px at 1600
    part("compass_dial", dl, 120, "brass", "dial", 3.0, centre=c_at)
    hm, cl = B.helmet()
    part("helmet", hm, 1300, "brass", "helmet", 2.6, bone="head", blur=0.003)
    part("collar", cl, 700, "brass", "collar", 2.0, blur=0.006)
    part("helmglass", B.helm_glass(), 160, "lure", "lure", 1.0, bone="head")
    ms = B.moss(hl, None)
    part("moss", ms, 500, "moss", "moss", 1.0)
    mt = B.masts()
    part("masts", mt, 450, "wood", "mast", 0.9)
    sl = B.sails()
    part("sails", sl, 130, "soft", "sail", 0.8)
    print("trunk", time.time() - t0, flush=True)
    for s, n in ((1, "R"), (-1, "L")):
        pd, up, fa, fi = B.arm(J, s)
        part("pauldron" + n, pd, 300, "scan", "pauldron", 1.6, bone="pauldron." + n, side=s)
        part("upper" + n, up, 240, "scan", "limb", 1.5, bone="upper_arm." + n, side=s, blur=0.008)
        part("fore" + n, fa, 620, "scan", "limb", 1.5, bone="forearm." + n, side=s, blur=0.006)
        pf = part("fist" + n, fi, 380, "scan", "fist", 1.6, bone=None, sd=n, side=s)
        th, sn, ft = B.leg(J, s)
        part("thigh" + n, th, 90, "scan", "leg", 0.9, bone="thigh." + n, side=s)
        part("shin" + n, sn, 150, "scan", "leg", 0.9, bone="shin." + n, side=s)
        part("foot" + n, ft, 140, "scan", "leg", 0.9, bone="x_foot." + n, side=s)
    wc = B.wrist_chain(J)
    part("wristchain", wc, 460, "iron", "iron", 1.0, bone="forearm.R")
    print("limbs", time.time() - t0, flush=True)

    # where the weapon and the shield rest
    G = np.array((sx, 0.0, 0.215), np.float32)
    WK, SK = 0.83, 0.62      # the sheets' measure: hammer 0.79 of his height, shield 0.71 (breaker_FINAL_sheet front view)
    H_M = lambda p: (p * WK) @ np.array(((0, 0, 1), (1, 0, 0), (0, 1, 0)), np.float32) + G
    Sh = np.array((-sx - 0.16, 0.0, 0.31), np.float32)
    S_M = lambda p: np.stack((p[:, 1], -p[:, 0], p[:, 2]), 1) * SK + Sh + (0, 0, -0.06)
    hW, hM, hC, zc = B.hammer()
    part("hammer_wood", hW, 380, "wood", "drum", 1.3, xf=H_M, group="hammer", bone="x_weapon", blur=0.008)
    part("hammer_iron", hM, 480, "iron", "iron", 1.2, xf=H_M, group="hammer", bone="x_weapon")
    part("hammer_chain", hC, 1000, "iron", "iron", 1.0, xf=H_M, group="hammer", bone="x_weapon")
    sW, sM = B.shield()
    part("shield_wood", sW, 500, "scan", "door", 2.2, xf=S_M, bone="x_shield", blur=0.005)
    part("shield_iron", sM, 280, "iron", "iron", 1.1, xf=S_M, bone="x_shield")
    fs, lure_at = B.fish()
    part("fish", fs, 320, "soft", "fish", 2.0, bone="x_fish")
    lf = S.Field(lure_at - 0.03, lure_at + 0.03, 0.0016)
    lf.add(S.sph(tuple(lure_at), 0.0135), 0.0, 1)
    part("lure", lf, 40, "lure", "lure", 1.2, bone="x_fish")
    print("weapons", time.time() - t0, flush=True)

    # the retopologised scan replaces the scripted hull, moss, arms and legs, with its own baked maps
    drop = ("hull", "moss", "pauldron", "upper", "fore", "thigh", "shin", "foot")
    for p in [q for q in parts if q["name"].startswith(drop)]:
        bpy.data.objects.remove(p["ob"])
        parts.remove(p)

    # ropes
    def rope(name, pts, r, bone, step=0.05):
        ob, aux = tube(name, np.array(pts, np.float32), r, step=step)
        parts.append({"ob": ob, "slot": "soft", "paint": "rope", "density": 0.7, "xf": None, "group": "body", "f": None, "f2": None,
                      "aux": aux, "name": name, "bone": bone})
    rope("rig1", [(0.64, -0.17, 1.31), (0.46, -0.17, 1.2), (0.2, -0.16, 1.04)], 0.0065, "hips", 0.09)
    rope("rig2", [(0.62, -0.17, 1.14), (0.64, -0.17, 1.31)], 0.0055, "hips", 0.12)
    rope("rig3", [(-0.54, -0.15, 0.93), (-0.4, -0.16, 1.09), (-0.28, -0.17, 1.05)], 0.0065, "hips", 0.09)
    T = np.array(B.MAST_TIP, np.float32)
    FT = np.array(B.FISH_AT, np.float32) + (0, 0, 0.085)
    js = [T + (FT - T) * t for t in (0.0, 0.34, 0.67, 1.0)]
    rope("line", [tuple(j) for j in js], 0.0034, "chain", 0.08)

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
        if p["aux"] is None:
            chart_seams(ob, 24 if len(ob.data.polygons) > 300 else 8)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        if p["aux"] is None:
            ob.data.uv_layers.new(name="UVMap") if not ob.data.uv_layers else None
            bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=0.0, correct_aspect=False)
        else:
            bpy.ops.uv.smart_project(angle_limit=math.radians(85), island_margin=0.0)
        bpy.ops.object.mode_set(mode="OBJECT")
        me = ob.data
        if p["aux"] is None:
            # (a closed chart has no seam and fails to solve: its faces come back with no UV area)
            cu = np.empty(len(me.loops) * 2, np.float32)
            me.uv_layers.active.data.foreach_get("uv", cu)
            tq = cu.reshape(-1, 3, 2)
            e1, e2 = tq[:, 1] - tq[:, 0], tq[:, 2] - tq[:, 0]
            # (the door's relief folds an angle-based chart over itself, and the fold paints wood onto her face)
            if p["name"] == "shield_wood" or (np.abs(e1[:, 0] * e2[:, 1] - e1[:, 1] * e2[:, 0]) < 1e-10).mean() > 0.002:
                print("smart project", p["name"], flush=True)
                bpy.ops.object.mode_set(mode="EDIT")
                bpy.ops.mesh.select_all(action="SELECT")
                bpy.ops.uv.smart_project(angle_limit=math.radians(64), island_margin=0.0)
                bpy.ops.object.mode_set(mode="OBJECT")
        ob.select_set(False)
        lv = np.empty(len(me.loops), np.int32)
        me.loops.foreach_get("vertex_index", lv)
        uv = np.empty(len(me.loops) * 2, np.float32)
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
    bpy.ops.uv.pack_islands(rotate=True, scale=True, margin=0.0035, shape_method="CONCAVE")
    bpy.ops.object.mode_set(mode="OBJECT")
    print("uvs", time.time() - t0, flush=True)

    # ----------------------------------------------------- paint, texel by texel
    atlas = np.zeros((ATLAS, ATLAS, 3), np.float32)
    mask = np.zeros((ATLAS, ATLAS), bool)
    for p in parts:
        ob = p["ob"]
        me = ob.data
        lv = np.empty(len(me.loops), np.int32)
        me.loops.foreach_get("vertex_index", lv)
        uv = np.empty(len(me.loops) * 2, np.float32)
        me.uv_layers.active.data.foreach_get("uv", uv)
        vs = verts(ob)
        tri = lv.reshape(-1, 3)
        f = p["f"]
        if f is not None:
            nrm = f.grad(vs.astype(np.float32), max(f.vox * 1.5, p.get("blur", 0.0)))
        else:
            me.update()
            nn = np.empty(len(vs) * 3, np.float32)
            me.vertices.foreach_get("normal", nn)
            nrm = nn.reshape(-1, 3)
        aux3 = p["aux"][tri] if p["aux"] is not None else None
        rt = S.raster(uv.reshape(-1, 3, 2), vs[tri], nrm[tri], tri, ATLAS, part=1, out=None) if aux3 is None else \
            P.raster_aux(uv.reshape(-1, 3, 2), vs[tri], nrm[tri], aux3, ATLAS)
        m = rt["id"] >= 0
        idx = np.nonzero(m)
        pts = rt["p"][idx]
        nn = rt["n"][idx]
        nn /= np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-6)
        if f is not None:
            pts = f.project(pts, 2)
            nn = f.grad(pts, f.vox * 0.9)
        ctx = {"f": f, "aux": rt["a"][idx] if aux3 is not None else None, "part": p, "hull": hl}
        atlas[idx] = P.paint(p["paint"], pts, nn, ctx)
        mask |= m
        if p["xf"] is not None:
            set_verts(ob, p["xf"](vs))
            nrm = (p["xf"](nrm) - p["xf"](np.zeros((1, 3), np.float32)))
        p["nrm"] = nrm
        print("painted", p["name"], len(tri), int(m.sum()), round(time.time() - t0, 1), flush=True)
    img = S.dilate(atlas, mask, 10)
    sa = imgio.load(os.path.join(WORK, "scan_albedo.png"))
    imgio.save(P.key_scan(sa.reshape(-1, 3)).reshape(sa.shape), os.path.join(WORK, "scan_albedo_key.png"))
    os.makedirs(WORK, exist_ok=True)
    png = os.path.join(WORK, "breaker_atlas.png")
    imgio.save(img[::-1], png)
    print("atlas coverage %.3f" % mask.mean(), flush=True)

    # ----------------------------------------------------- the armature, with his clip bones
    arm = K.build_armature(rig)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    zw = float(J["hand.R"][2])
    for s, n in ((1, "R"), (-1, "L")):
        hx = s * sx
        k = np.array((hx + s * 0.05, 0, zw - 0.115), np.float32)
        tip = k + np.array((0, 0, -0.06), np.float32)
        add_bone(arm, "x_fing." + n, k, tip, "hand." + n, (0, 1, 0))
        add_bone(arm, "x_fing2." + n, tip, tip + np.array((-s * 0.06, 0, -0.03), np.float32), "x_fing." + n, (0, 1, 0))
        th = np.array((hx - s * 0.05, 0.13, zw - 0.03), np.float32)
        add_bone(arm, "x_thumb." + n, th, th + np.array((0, 0.03, -0.08), np.float32), "hand." + n, (0, 0, 1))
        fx = s * float(J["shin.R"][0])
        add_bone(arm, "x_foot." + n, (fx, 0, 0.06), (fx, 0.2, 0.05), "shin." + n, (0, 0, 1))
    add_bone(arm, "x_weapon", tuple(G), tuple(G + np.array((0, 0.25, 0), np.float32)), "hand.R", (0, 0, 1))
    add_bone(arm, "x_shield", tuple(Sh), tuple(Sh + np.array((0, 0, 0.25), np.float32)), "hand.L", (-1, 0, 0))
    for i in range(3):
        add_bone(arm, "spring_hangfish_%d" % i, js[i], js[i + 1], "hips" if i == 0 else "spring_hangfish_%d" % (i - 1))
    add_bone(arm, "spring_hangfish_3", js[3], js[3] + (0, 0, -0.06), "spring_hangfish_2")
    add_bone(arm, "x_fish", js[3], js[3] + (0, 0, -0.1), "spring_hangfish_2")
    bpy.ops.object.mode_set(mode="OBJECT")

    # ----------------------------------------------------- skin: rigid pieces
    for p in parts:
        ob = p["ob"]
        vs = verts(ob)
        b = p["bone"]
        if p["name"].startswith("fist"):
            sd = p["sd"]
            W = {(k + "." + sd): v for k, v in p["f"].weights(vs, 0.004).items()}
        elif b == "chain":
            W = chain(js, ["spring_hangfish_%d" % i for i in range(3)], vs)
        else:
            W = rigid(len(vs), b)
        add_weights(ob, W)

    # the porthole: its own disc and 0..1 UVs, drawn by shaders/warden_mood.gdshader
    n = 28
    c = np.array((0, B.PORT_Y + 0.008, B.PORT_C[1]), np.float32)
    r = B.PORT_R * 0.74
    v = [c + (0, 0.012, 0)]
    for i in range(n):
        a = i / n * math.tau
        v.append(c + np.array((r * math.cos(a), 0, r * math.sin(a)), np.float32))
    f2 = [(0, (i + 1) % n + 1, i + 1) for i in range(n)]
    pe = ob_from("eyes", np.array(v), np.array(f2))
    uv = pe.data.uv_layers.new(name="UVMap")
    vv = np.array(v)
    for pl in pe.data.polygons:
        for li in pl.loop_indices:
            q = vv[pe.data.loops[li].vertex_index]
            uv.data[li].uv = ((q[0] - c[0]) / r * 0.5 + 0.5, (q[2] - c[2]) / r * 0.5 + 0.5)
    add_weights(pe, rigid(len(v), "head"))
    parts.append({"ob": pe, "slot": "eyes", "group": "body", "nrm": np.tile((0, 1, 0), (len(v), 1)).astype(np.float32), "name": "eyes"})

    so = ob_from("scanbody", scn["v"], scn["tri"])
    so.data.uv_layers.new(name="UVMap").data.foreach_set("uv", scn["uv"].ravel())
    add_weights(so, {str(b): scn["w"][:, i] for i, b in enumerate(scn["bones"])})
    so.data.update()
    sn = np.empty(len(scn["v"]) * 3, np.float32)
    so.data.vertices.foreach_get("normal", sn)
    parts.append({"ob": so, "slot": "body", "group": "body", "nrm": sn.reshape(-1, 3), "name": "scanbody"})

    # ----------------------------------------------------- materials (one atlas), join
    image = bpy.data.images.load(png)
    image.name = "breaker_atlas"
    mats = {}

    def scan_mat():
        m = bpy.data.materials.new("leather-scan-hot")
        m.use_nodes = True
        bs = m.node_tree.nodes["Principled BSDF"]
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(os.path.join(WORK, "scan_albedo_key.png"))
        m.node_tree.links.new(t.outputs[0], bs.inputs[0])
        tn = m.node_tree.nodes.new("ShaderNodeTexImage")
        tn.image = bpy.data.images.load(os.path.join(WORK, "scan_normal.png"))
        tn.image.colorspace_settings.name = "Non-Color"
        nm = m.node_tree.nodes.new("ShaderNodeNormalMap")
        m.node_tree.links.new(tn.outputs[0], nm.inputs["Color"])
        m.node_tree.links.new(nm.outputs[0], bs.inputs["Normal"])
        return m

    def mat(slot):
        if slot == "body":
            if slot not in mats:
                mats[slot] = scan_mat()
            return mats[slot]
        if slot not in mats:
            m = bpy.data.materials.new(MATS[slot])
            m.use_nodes = True
            bs = m.node_tree.nodes["Principled BSDF"]
            t = m.node_tree.nodes.new("ShaderNodeTexImage")
            t.image = image
            m.node_tree.links.new(t.outputs[0], bs.inputs[0])
            bs.inputs["Roughness"].default_value = 0.8
            mats[slot] = m
        return mats[slot]

    body_obs, hammer_obs = [], []
    for p in parts:
        ob = p["ob"]
        ob.data.materials.append(mat(p["slot"]))
        for pl in ob.data.polygons:
            pl.use_smooth = True
        nv = p["nrm"]
        nv = nv / np.maximum(np.linalg.norm(nv, axis=1, keepdims=True), 1e-6)
        ob.data.normals_split_custom_set_from_vertices(nv.tolist())
        (hammer_obs if p["group"] == "hammer" else body_obs).append(ob)

    def join(lst, name):
        bpy.ops.object.select_all(action="DESELECT")
        for o in lst:
            o.select_set(True)
        bpy.context.view_layer.objects.active = lst[0]
        bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        o.name = o.data.name = name
        return o
    bd = join(body_obs, "breaker")
    hmr = join(hammer_obs, "hammer")
    for o in (bd, hmr):
        o.parent = arm
        md = o.modifiers.new("Armature", "ARMATURE")
        md.object = arm
    Hc = H_M(np.array([[0, 0, zc]], np.float32))[0]
    K.anchor(arm, "head", "anchor_head_top", (0, 0.03, B.HELM_TOP + 0.06))
    K.anchor(arm, "hips", "anchor_chest", tuple(c_at))
    K.anchor(arm, "x_weapon", "anchor_hammer_head", tuple(Hc))
    K.anchor(arm, "x_weapon", "anchor_weapon_tip", tuple(H_M(np.array([[0.295, 0, zc]], np.float32))[0]))
    K.anchor(arm, "x_weapon", "anchor_hammer_grip", tuple(G))
    K.anchor(arm, "x_weapon", "weapon_muzzle", tuple(Hc))
    K.anchor(arm, "x_weapon", "weapon_thrown", tuple(G))
    K.anchor(arm, "x_shield", "anchor_shield_face", tuple(S_M(np.array([[0, -0.08, 0.3]], np.float32))[0]))
    K.anchor(arm, "x_fish", "anchor_lure", tuple(lure_at))
    w = bpy.data.objects.new("shield", None)      # (a marker: the loader hides the procedural prow)
    bpy.context.scene.collection.objects.link(w)
    w.parent = arm
    print("tris", K.tris([bd, hmr]), "body", K.tris([bd]), "hammer", K.tris([hmr]), time.time() - t0, flush=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "breaker_art1.blend"))


main()
