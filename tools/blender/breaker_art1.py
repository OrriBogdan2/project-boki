"""Breaker (ART-1): the sculpt to a game mesh on the contract armature with a painted atlas, saved as a .blend for
tools/blender/breaker_anims.py, which keys the clips and exports the .glb:
  blender -b --factory-startup --python tools/blender/breaker_art1.py -- WORKDIR
Shapes: breaker_sculpt.py; paint: breaker_paint.py. Budget: 20k triangles, weapon and shield included."""
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


def lowpoly(name, fld, tris, outer=None):
    """Surface nets, then a decimate down to `tris`, dropping specks. outer: keep only the side of a thin shell that
    faces away from this field (a mantle over a body), as a clean open sheet: decimating both skins of a thin
    cloth bridges them into tents."""
    v, q = S.surface_nets(fld)
    fn = np.cross(v[q[:, 1]] - v[q[:, 0]], v[q[:, 2]] - v[q[:, 0]])
    cn = v[q].mean(1)
    gr = fld.grad(cn.astype(np.float32))
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
    bm.to_mesh(ob.data)
    bm.free()
    nt = sum(len(pl.vertices) - 2 for pl in ob.data.polygons)
    print(name, "dense", nt, "->", tris, flush=True)
    m = ob.modifiers.new("d", "DECIMATE")
    m.ratio = min(1.0, tris / max(nt, 1))
    m.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = ob
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


def main():
    t0 = time.time()
    K.reset()
    rig = K.load_rig(os.path.join(REPO, "art/wardens/src/breaker_rig.json"))
    J = B.joints(os.path.join(REPO, "art/wardens/src/breaker_rig.json"))
    if abs(float(J["upper_arm.R"][0]) - 0.3239) < 0.01:      # (a rig json from before the build change)
        k = 1.4 / 1.18
        for n in J:
            if n.split(".")[0] in ("upper_arm", "forearm", "hand", "pauldron", "thigh", "shin"):
                J[n][0] *= k
        for n, b in rig["bones"].items():
            if n.split(".")[0] in ("upper_arm", "forearm", "hand", "pauldron", "thigh", "shin"):
                b["head"][0] *= k
    sx = float(J["hand.R"][0])
    print("sculpting", flush=True)
    skin = B.body(J)
    hd = B.head(J)
    print("body+head", time.time() - t0, flush=True)
    man = B.mantle(J, skin)
    sho = B.shorts(J, skin)
    rg = B.rags(J, skin)
    brd, plaits, rings = B.beard(J)
    ic = B.ice(J, skin, man)
    kl = B.kelp(J, skin)
    hI, hM, hW, zc = B.hammer()
    sW, sM, sI = B.shield()
    print("clothes", time.time() - t0, flush=True)

    # ----------------------------------------------------- where the weapon and the shield rest
    # the hammer's local frame -> model: its long axis (x) up, its haft (z) forward, through the fist
    G = np.array((sx - 0.014, 0.0, 0.5), np.float32)
    H_R = np.array(((0, 1, 0), (0, 0, 1), (1, 0, 0)), np.float32)      # columns: local x -> +Z ...
    H_R = np.array(((0, 1, 0), (0, 0, 1), (1, 0, 0)), np.float32)
    H_M = lambda p: (p @ np.array(((0, 0, 1), (1, 0, 0), (0, 1, 0)), np.float32)) + G
    # the shield's frame -> model: its face (-y) outward (-x), up stays up, on the left forearm
    Sh = np.array((-sx - 0.135, 0.02, 0.66), np.float32)
    S_M = lambda p: np.stack((p[:, 1], -p[:, 0], p[:, 2]), 1) + Sh

    parts = []     # {ob, slot, paint, xf, fields...}

    def part(name, fld, tris, slot, paint, density=1.0, xf=None, group="body", fld2=None, outer=None):
        ob = lowpoly(name, fld, tris, outer)
        parts.append({"ob": ob, "slot": slot, "paint": paint, "density": density, "xf": xf, "group": group, "f": fld,
                      "f2": fld2, "aux": None, "name": name})
        return parts[-1]

    pb = part("skin_body", skin, 6000, "skin", "skin", 1.0)
    ph = part("skin_head", hd, 3300, "skin", "head", 3.2)
    pm = part("mantle", man, 1300, "cloth", "mantle", 0.9, fld2=skin, outer=skin)
    ps = part("shorts", sho, 500, "cloth", "shorts", 0.6, fld2=skin, outer=skin)
    prf = part("rag_front", rg["front"], 450, "cloth", "rag", 0.7)
    prb = part("rag_back", rg["back"], 400, "cloth", "rag", 0.5)
    pbd = part("beard", brd, 1500, "hair", "beard", 2.0)
    pic = part("ice_body", ic, 500, "ice", "ice", 0.7)
    pkl = part("kelp", kl, 160, "leather", "kelp", 0.8)
    t_at = (sx - 0.095, 0.27, 0.615)
    td = B.teddy(t_at)
    ptd = part("teddy", td, 260, "leather", "teddy", 1.6)
    c_at = (-0.17, 0.0, 1.13)
    c_at = B.onsurf(man, [(-0.2, 0.34, 1.1)], 0.012)[0]
    c_n = man.grad(np.array([c_at], np.float32))[0]
    cp = B.compass(c_at, c_n)
    pcp = part("compass", cp, 130, "brass", "compass", 2.0)
    pcp["normal"], pcp["centre"] = c_n, c_at
    phi = part("hammer_ice", hI, 480, "ice", "hammer_ice", 1.3, H_M, "hammer")
    phm = part("hammer_iron", hM, 380, "metal", "iron", 1.0, H_M, "hammer")
    phw = part("hammer_wood", hW, 120, "leather", "wood", 0.9, H_M, "hammer")
    psw = part("shield_wood", sW, 950, "leather", "shield", 1.3, S_M)
    psm = part("shield_iron", sM, 420, "metal", "iron", 1.0, S_M)
    psi = part("shield_ice", sI, 180, "ice", "ice", 0.9, S_M)
    for r_i, (c, r) in enumerate(rings):
        pass
    print("low parts", time.time() - t0, flush=True)

    # rings and eyes: small clean parts
    rf = S.Field((-0.2, 0.28, 0.93), (0.2, 0.45, 1.14), 0.0014)
    for c, r in rings:
        rf.add(S.cyl(tuple(c), "z", r + 0.0065, 0.0125, 0.003), 0.0, 1, "head")
    prn = part("rings", rf, 160, "metal", "ring", 1.5)
    ef = S.Field((-0.1, 0.1, 1.41), (0.1, 0.175, 1.49), 0.0012)
    for c, r in B.eyes(J):
        ef.add(S.ell(c, (r * 1.1, r * 0.95, r * 0.5), (0, 0.32 if c[0] < 0 else -0.32, 0)), 0.0, 1, "head")
    pey = part("eyes", ef, 90, "eyes", "eyes", 2.0)

    # ropes, on the surfaces
    ropes = []
    def rope(name, pts, r, bone=None, on=None, off=0.0, step=0.05, hold=None):
        pp = B.onsurf(on, pts, off) if on is not None else np.array(pts, np.float32)
        ob, aux = tube(name, pp, r, step=step)
        p = {"ob": ob, "slot": "leather", "paint": "rope", "density": 0.7, "xf": hold, "group": "hammer" if hold else "body", "f": None,
             "f2": None, "aux": aux, "name": name, "bone": bone}
        parts.append(p)
        ropes.append(p)
        return p
    belt = B.ring_at(skin, 0.625, 34, off=0.014, zf=lambda a: -0.02 * math.cos(a))
    rope("belt1", belt, 0.017, step=0.1)
    rope("belt2", B.ring_at(skin, 0.655, 34, off=0.014, zf=lambda a: -0.022 * math.cos(a)), 0.017, step=0.1)
    # the cross ropes: over each shoulder, crossing on the belly, ending at the opposite hip
    for s in (-1, 1):
        n = 12
        pts = []
        for i in range(n + 1):
            t = i / n
            x = s * (0.33 * (1 - t) ** 1.0 - 0.27 * t)
            z = 1.24 * (1 - t) + 0.67 * t
            pts.append((x, 0.34, z))
        rope("cross" + ("R" if s > 0 else "L"), pts, 0.0145, on=skin, off=0.03, step=0.06)
    # the rope round the shoulders and back
    rope("back_rope", [(0.47 - 0.94 * t, -0.34 + 0.03 * math.sin(t * 3.14), 1.12 + 0.13 * math.sin(t * 3.14)) for t in np.linspace(0, 1, 11)],
         0.0135, on=man, off=0.012, step=0.08)
    # the knot on the belly and its two hanging loops
    kn = (0.015, 0.3, 0.62)
    kn = tuple(B.onsurf(skin, [(0.015, 0.34, 0.62)], 0.03)[0])
    k = np.array(kn, np.float32)
    rope("knot", [k + (0.035 * math.cos(a), 0.012 * math.sin(a * 2), 0.03 * math.sin(a)) for a in np.linspace(0, 6.6, 12)], 0.021, step=0.02)
    for s, l in ((-1, 0.2), (1, 0.27)):
        rope("loop" + str(s), [k + (s * (0.02 + 0.05 * t), 0.02, -l * math.sin(t * 3.14) * 1.0) for t in np.linspace(0, 1, 9)], 0.0125, bone="spring_apronF_1", step=0.05)
    # the teddy's cord
    rope("teddy_cord", [(sx - 0.14, 0.2, 0.655), (sx - 0.118, 0.25, 0.64), t_at], 0.005, step=0.05)
    # the lacing on the shoulder
    for s in (-1, 1):
        rope("lace" + str(s), B.onsurf(man, [(s * (0.29 + 0.11 * t), 0.07 + 0.04 * math.sin(t * 19), 1.27 - 0.1 * t) for t in np.linspace(0, 1, 11)], 0.008), 0.006, step=0.03)
    print("ropes", time.time() - t0, flush=True)

    # ----------------------------------------------------- UVs: smart project per part, scaled to the shared density
    bpy.ops.object.select_all(action="DESELECT")
    total = 0.0
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
        ob.select_set(False)
        me = ob.data
        lv = np.empty(len(me.loops), np.int32)
        me.loops.foreach_get("vertex_index", lv)
        uv = np.empty(len(me.loops) * 2, np.float32)
        me.uv_layers.active.data.foreach_get("uv", uv)
        uv = uv.reshape(-1, 2)
        vs = verts(ob)
        a3, a2 = 0.0, 0.0
        t3 = vs[lv.reshape(-1, 3)]
        tu = uv.reshape(-1, 3, 2)
        a3 = np.linalg.norm(np.cross(t3[:, 1] - t3[:, 0], t3[:, 2] - t3[:, 0]), axis=1).sum() * 0.5
        e1, e2 = tu[:, 1] - tu[:, 0], tu[:, 2] - tu[:, 0]
        a2 = np.abs(e1[:, 0] * e2[:, 1] - e1[:, 1] * e2[:, 0]).sum() * 0.5
        k = math.sqrt(a3 * p["density"] ** 2 / max(a2, 1e-9))
        me.uv_layers.active.data.foreach_set("uv", (uv * k).ravel())
        total += a3 * p["density"] ** 2
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
        # normals: the sculpt's, for smooth toon light on the decimated mesh
        f = p["f"]
        if f is not None:
            nrm = f.grad(vs.astype(np.float32), f.vox * 1.5)
        else:
            me.update()
            nn = np.empty(len(vs) * 3, np.float32)
            me.vertices.foreach_get("normal", nn)
            nrm = nn.reshape(-1, 3)
        aux3 = None
        if p["aux"] is not None:
            aux3 = p["aux"][tri]
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
        ctx = {"f": f, "f2": p["f2"], "aux": rt["a"][idx] if aux3 is not None else None, "part": p, "skin": skin, "man": man}
        rgb = P.paint(p["paint"], pts, nn, ctx)
        atlas[idx] = rgb
        mask |= m
        # finally: world positions and normals
        if p["xf"] is not None:
            set_verts(ob, p["xf"](vs))
            nrm = (p["xf"](nrm) - p["xf"](np.zeros((1, 3), np.float32)))
        p["nrm"] = nrm
        print("painted", p["name"], len(tri), int(m.sum()), round(time.time() - t0, 1), flush=True)
    img = S.dilate(atlas, mask, 10)
    os.makedirs(WORK, exist_ok=True)
    png = os.path.join(WORK, "breaker_atlas.png")
    imgio.save(img[::-1], png)
    print("atlas coverage %.3f" % mask.mean(), flush=True)

    # ----------------------------------------------------- the armature, with Breaker's clip bones
    arm = K.build_armature(rig)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    Hk = B.HAND
    for s, n in ((1, "R"), (-1, "L")):
        hx = s * sx
        k = np.array((hx + s * 0.03 * Hk, 0, 0.61 + (0.49 - 0.61) * Hk), np.float32)
        tip = k + np.array((0, 0, -0.07), np.float32)
        add_bone(arm, "x_fing." + n, k, tip, "hand." + n, (0, 1, 0))
        add_bone(arm, "x_fing2." + n, tip, tip + np.array((-s * 0.05, 0, -0.06), np.float32), "x_fing." + n, (0, 1, 0))
        th = np.array((hx - s * 0.02 * Hk, 0.07 * Hk, 0.61 + (0.59 - 0.61) * Hk), np.float32)
        add_bone(arm, "x_thumb." + n, th, th + np.array((-s * 0.02, 0.08, -0.08), np.float32), "hand." + n, (0, 0, 1))
        add_bone(arm, "x_foot." + n, (s * float(J["shin.R"][0]), 0, 0.09), (s * float(J["shin.R"][0]), 0.2, 0.05), "shin." + n, (0, 0, 1))
        add_bone(arm, "x_lid." + n, (s * 0.056, 0.12, 1.462), (s * 0.056, 0.18, 1.462), "head", (0, 0, 1))
        add_bone(arm, "x_brow." + n, (s * 0.06, 0.1, 1.49), (s * 0.06, 0.16, 1.49), "head", (0, 0, 1))
    add_bone(arm, "x_jaw", (0, 0.03, 1.385), (0, 0.15, 1.34), "head", (0, 0, 1))
    add_bone(arm, "x_weapon", tuple(G), tuple(G + np.array((0, 0.25, 0), np.float32)), "hand.R", (0, 0, 1))
    add_bone(arm, "x_shield", tuple(Sh), tuple(Sh + np.array((0, 0, 0.25), np.float32)), "hand.L", (-1, 0, 0))
    chains = {}
    for nm, top, ring, tip in plaits:
        top, ring, tip = [np.array(a, np.float32) for a in (top, ring, tip)]
        mid = (top + ring) * 0.5
        js = [top, mid, ring, tip]
        chains[nm] = js
        for i in range(3):
            add_bone(arm, "spring_%s_%d" % (nm, i), js[i], js[i + 1], "head" if i == 0 else "spring_%s_%d" % (nm, i - 1))
        add_bone(arm, "spring_%s_3" % nm, js[3], js[3] + (js[3] - js[2]) * 0.3, "spring_%s_2" % nm)
    for nm, y, par in (("apronF", 0.37, "hips"), ("apronB", -0.33, "hips")):
        js = [np.array((0, y * 0.98, z), np.float32) for z in (0.66, 0.5, 0.37, 0.22)]
        chains[nm] = js
        for i in range(3):
            add_bone(arm, "spring_%s_%d" % (nm, i), js[i], js[i + 1], par if i == 0 else "spring_%s_%d" % (nm, i - 1))
        add_bone(arm, "spring_%s_3" % nm, js[3], js[3] + (js[3] - js[2]) * 0.3, "spring_%s_2" % nm)
    t = np.array(t_at, np.float32)
    add_bone(arm, "spring_teddy_0", t, t + (0, 0, -0.17), "hips")
    add_bone(arm, "spring_teddy_1", t + (0, 0, -0.17), t + (0, 0, -0.24), "spring_teddy_0")
    bpy.ops.object.mode_set(mode="OBJECT")

    # ----------------------------------------------------- skin
    body_allow = grp_allow
    for p in parts:
        ob = p["ob"]
        vs = verts(ob)
        nm = p["name"]
        if p["group"] == "hammer":
            W = {"x_weapon": np.ones(len(vs), np.float32)}
        elif nm.startswith("shield"):
            W = {"x_shield": np.ones(len(vs), np.float32)}
        elif nm in ("skin_body", "mantle", "shorts", "ice_body", "kelp") or nm.startswith(("belt", "cross", "back_rope", "knot", "lace", "teddy_cord")):
            W = skin.weights(vs, 0.03, body_allow)
            if nm == "shorts":      # cloth never takes the toes
                W.pop("x_foot.L", None), W.pop("x_foot.R", None)
            if nm in ("mantle", "ice_body", "kelp", "back_rope") or nm.startswith("lace"):
                for k2 in list(W):
                    if k2.startswith(("forearm", "hand", "x_", "thigh", "shin")):
                        W.pop(k2)
                if nm == "ice_body":
                    W2 = ic.weights(vs, 0.02)
                    W = {k2: np.maximum(W.get(k2, 0), W2.get(k2, 0) * 4) for k2 in set(W) | set(W2)}
            W = {k2: w for k2, w in W.items() if w.max() > 1e-4}
        elif nm == "skin_head":
            W = hd.weights(vs, 0.012)
            W["head"] = np.maximum(W.get("head", 0), 0.02)
            z = vs[:, 2]
            W["hips"] = 3.0 * S.smooth(1.31, 1.25, z)
        elif nm == "beard":
            W = {"head": 3.0 * S.smooth(1.33, 1.28, vs[:, 2]) + 0.0}
            for pn, js in chains.items():
                if pn.startswith("braid"):
                    W2 = chain(js, ["spring_%s_%d" % (pn, i) for i in range(3)], vs)
                    near = np.exp(-np.maximum(np.abs(vs[:, 0] - js[1][0]) - 0.03, 0) / 0.015)
                    for k2, w in W2.items():
                        W[k2] = w * near * S.smooth(1.33, 1.25, vs[:, 2])
        elif nm == "rings":
            W = {}
            for pn, js in chains.items():
                if pn.startswith("braid"):
                    near = np.linalg.norm(vs - js[2], axis=1) < 0.08
                    W["spring_%s_2" % pn] = near.astype(np.float32)
        elif nm.startswith("rag"):
            pn = "apronF" if nm.endswith("front") else "apronB"
            W = chain(chains[pn], ["spring_%s_%d" % (pn, i) for i in range(3)], np.stack((vs[:, 0] * 0, np.full(len(vs), chains[pn][0][1]), vs[:, 2]), 1))
            W["hips"] = 2.0 * S.smooth(0.6, 0.66, vs[:, 2])
        elif nm == "teddy":
            W = {"spring_teddy_0": np.ones(len(vs), np.float32)}
        elif nm == "compass":
            W = {"hips": np.ones(len(vs), np.float32)}
        elif nm == "eyes":
            W = {"head": np.ones(len(vs), np.float32)}
        elif nm.startswith("loop"):
            W = {"spring_apronF_0": S.smooth(0.3, 0.6, vs[:, 2]), "spring_apronF_1": S.smooth(0.6, 0.3, vs[:, 2])}
        else:
            W = {"hips": np.ones(len(vs), np.float32)}
        add_weights(ob, W)

    # lids and brows, added by distance on the head mesh after the fact
    ob = ph["ob"]
    vs = verts(ob)
    for s, n in ((1, "R"), (-1, "L")):
        c = np.array((s * 0.058, 0.135, 1.482), np.float32)
        w = np.exp(-(np.linalg.norm((vs - c) * (1, 0.8, 1.6), axis=1) / 0.032) ** 2)
        vg = ob.vertex_groups.new(name="x_brow." + n)
        for i in np.nonzero(w > 0.05)[0].tolist():
            vg.add([i], float(w[i]) * 0.8, "REPLACE")
    ob.vertex_groups.active = ob.vertex_groups["head"]

    # ----------------------------------------------------- materials (one atlas), slots, join
    image = bpy.data.images.load(png)
    image.name = "breaker_atlas"
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

    body_obs, hammer_obs = [], []
    for p in parts:
        ob = p["ob"]
        ob.data.materials.append(mat(p["slot"]))
        for pl in ob.data.polygons:
            pl.use_smooth = True
        n = p["nrm"]
        n = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
        ob.data.normals_split_custom_set_from_vertices(n.tolist())
        (hammer_obs if p["group"] == "hammer" else body_obs).append(ob)
    # join: the body in one object per nothing but slots (materials), the hammer alone so it can leave the hand
    def join(obs, name):
        bpy.ops.object.select_all(action="DESELECT")
        for o in obs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        o.name = o.data.name = name
        return o
    bd = join(body_obs, "breaker")
    hm = join(hammer_obs, "hammer")
    for o in (bd, hm):
        o.parent = arm
        md = o.modifiers.new("Armature", "ARMATURE")
        md.object = arm
    # empties: the anchors, the seat the hammer takes on the rig's pivot, and the `weapon` / `shield` markers
    z = rig["land"]["crown"] if isinstance(rig["land"], dict) else 1.54
    K.anchor(arm, "head", "anchor_head_top", (0, 0.03, float(z) + 0.02))
    K.anchor(arm, "hips", "anchor_chest", (0, 0.26, 1.02))
    K.anchor(arm, "x_weapon", "anchor_hammer_head", tuple(H_M(np.array([[0, 0, zc]], np.float32))[0]))
    K.anchor(arm, "x_weapon", "anchor_weapon_tip", tuple(H_M(np.array([[0.34, 0, zc]], np.float32))[0]))
    K.anchor(arm, "x_weapon", "anchor_hammer_grip", tuple(G))
    K.anchor(arm, "x_shield", "anchor_shield_face", tuple(S_M(np.array([[0, -0.08, 0.05]], np.float32))[0]))
    K.anchor(arm, "x_shield", "anchor_prow_crack", tuple(S_M(np.array([[0.05, -0.04, -0.2]], np.float32))[0]))
    # the procedural Hammer pivot's frame as the skinned hammer rests: its origin on the grip, its -Z along the haft
    # toward the head and its +Y along the block's long axis (the swing), so a procedural move can carry the bone
    seat = K.anchor(arm, "x_weapon", "seat_x_weapon", tuple(G))
    M = Matrix(((1, 0, 0, G[0]), (0, 0, 1, G[1]), (0, -1, 0, G[2]), (0, 0, 0, 1)))    # pivot x,y,z -> model
    M = Matrix(((-1, 0, 0, G[0]), (0, 0, -1, G[1]), (0, 1, 0, G[2]), (0, 0, 0, 1)))
    M = Matrix(((1, 0, 0, G[0]), (0, 0, -1, G[1]), (0, 1, 0, G[2]), (0, 0, 0, 1)))
    seat.matrix_world = M
    w = bpy.data.objects.new("weapon", None)
    bpy.context.scene.collection.objects.link(w)
    w.parent = arm
    tn = K.tris([bd, hm])
    print("tris", tn, "body", K.tris([bd]), "hammer", K.tris([hm]), time.time() - t0, flush=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "breaker_art1.blend"))


main()
