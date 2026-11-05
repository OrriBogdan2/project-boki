"""Grimble (ART-1, 76b): the sculpt to a game mesh on the contract armature, a painted atlas, saved as a .blend for grimble_clips.py:
  blender -b --factory-startup --python tools/art1/grimble_art1.py -- WORK
Shapes: grimble_sculpt.py; paint: grimble_paint.py. Budget: 20k triangles, hoard and weapons included. The hook is skinned on bone
`hook` (hand.R), the blunderbuss on `gun` (a swivel on root), the hoard on `hoard`, the junk ball on `ball` (shrunk into the sack at
rest, the roll scales it up). Method: tools/art1/hem_art1.py."""
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import grimble_paint as P
import grimble_sculpt as G
import hem_sdf as S
import imgio
import warden_kit as K

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
WORK = sys.argv[sys.argv.index("--") + 1]
ONLY = sys.argv[sys.argv.index("--") + 2] if len(sys.argv) > sys.argv.index("--") + 2 else ""
ATLAS = 2048
F = np.float32


def slot_of(lb):
    lb = int(lb)
    if lb >= G.HOARD_BASE:
        k = G.HOARD[lb - G.HOARD_BASE]["kind"]
        return "metal" if k in ("plate", "ballplate") else "leather"
    return {G.SKIN: "skin", G.LIP: "skin", G.MOUTH: "skin", G.TOOTH: "skin", G.IRON: "metal", G.RUST: "metal", G.ROPE: "metal", G.GLASS: "metal",
            G.BRASS: "brass", G.GOLD: "brass", G.LEATHER: "leather", G.WOOD: "leather", G.DARK: "leather", G.LOIN: "cloth", G.BURLAP: "cloth",
            G.EYE: "glow", G.LAMP: "glow"}.get(lb, "skin")


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


def orient(ob, fld):
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


def lowpoly(name, fld, tris, cull=None, keep=None):
    v, q = S.surface_nets(fld)
    ob = ob_from(name, v, q)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    if cull is not None:
        bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(cull(v))[0].tolist()], context="VERTS")
    seen, isl = set(), []
    for vv in bm.verts:
        if vv.index in seen or not vv.is_valid:
            continue
        st, cur = [vv], []
        seen.add(vv.index)
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
    bmesh.ops.delete(bm, geom=[a for c in isl if len(c) < max(mx * 0.004, 12) for a in c], context="VERTS")
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
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="d")
    if keep is not None:
        ob.vertex_groups.clear()
    orient(ob, fld)
    return ob


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
    """The face as one front-projected chart (seams were cracking the cheek and lip on Lisette)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    front = np.array([f.calc_center_median().y > G.HEAD_C[1] + 0.03 and f.normal.y > 0.12 for f in bm.faces], bool)
    for e in bm.edges:
        fs = e.link_faces
        if len(fs) == 2:
            a, b = front[fs[0].index], front[fs[1].index]
            e.seam = (a != b) or (e.seam and not a)
    bm.to_mesh(ob.data)
    bm.free()
    return np.nonzero(front)[0]


def planar_uv(ob, polys):
    me = ob.data
    uv = me.uv_layers.active.data
    for pi in polys.tolist():
        pl = me.polygons[pi]
        for li in pl.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv[li].uv = (co.x, co.z)


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


def add_bone(arm, name, head, tail, parent, roll_to=None):
    e = arm.data.edit_bones.new(name)
    e.head, e.tail = Vector(tuple(float(a) for a in head)), Vector(tuple(float(a) for a in tail))
    if roll_to is not None:
        e.align_roll(Vector(roll_to))
    e.parent = arm.data.edit_bones[parent]
    return e


def chain_links(name, pts, l=0.034, w=0.015, t=0.0042):
    """Real links along a polyline (each two sides of a thin hexagon ring, turned 90 degrees link to link)."""
    pts = np.array(pts, F)
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    run = np.r_[0, np.cumsum(seg)]
    n = max(2, int(run[-1] / (l * 1.5)))
    v, q = [], []
    for i in range(n):
        s = (i + 0.5) / n * run[-1]
        c = np.array([np.interp(s, run, pts[:, a]) for a in range(3)], F)
        ds = 0.02
        u = np.array([np.interp(s + ds, run, pts[:, a]) - np.interp(s - ds, run, pts[:, a]) for a in range(3)], F)
        u /= max(np.linalg.norm(u), 1e-6)
        a = np.cross(u, (0.17, 0.53, 0.83))
        a /= np.linalg.norm(a)
        b = np.cross(u, a)
        if i % 2:
            a, b = b, -a
        ring = 4
        base = len(v)
        for j in range(ring):
            th = j / ring * math.tau
            o = c + u * math.cos(th) * l * 0.9 + a * math.sin(th) * w
            nn = u * math.cos(th) + a * math.sin(th)
            for k in range(3):
                ph = k / 3 * math.tau
                v.append(o + nn * math.cos(ph) * t + b * math.sin(ph) * t)
        for j in range(ring):
            for k in range(3):
                j2, k2 = (j + 1) % ring, (k + 1) % 3
                q.append((base + j * 3 + k, base + j2 * 3 + k, base + j2 * 3 + k2, base + j * 3 + k2))
    return ob_from(name, np.array(v, F), np.array(q, np.int32))


def spline(pts, n):
    pts = np.array(pts, F)
    L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    ts = np.linspace(0, L[-1], n)
    return np.stack([np.interp(ts, L, pts[:, i]) for i in range(3)], 1).astype(F)


def main():
    t0 = time.time()
    K.reset()
    rig_path = os.path.join(REPO, "art/wardens/src/dredge_rig.json")
    rig = K.load_rig(rig_path)
    J = G.joints(rig_path)
    print("sculpting", flush=True)
    parts = []

    def part(name, fld, tris, paint, density=1.0, xf=None, group="body", slot=None, cull=None, keep=None, ob=None, skinned=None):
        o = ob if ob is not None else lowpoly(name, fld, tris, cull, keep)
        parts.append({"ob": o, "slot": slot, "paint": paint, "density": density, "xf": xf, "group": group, "f": fld, "name": name})
        print("part", name, round(time.time() - t0, 1), flush=True)
        return parts[-1]

    def face_keep(v):
        h = v - G.HEAD_C
        m = np.abs(h[:, 2] - G.grin_z(h[:, 0])) - G.grin_h(h[:, 0])
        d = np.linalg.norm(v - G.EYE_C, axis=1)
        return np.clip(np.maximum(1.1 - np.abs(m) / 0.018, 1.0 - d / 0.08), 0.03, 1)

    tr = G.figure(J)
    part("skin_head", G.head(), 2300, "head", 2.4, None, "head", None, None, face_keep)
    part("teeth", G.teeth(), 620, "tooth", 1.2, None, "head", "skin")
    part("eye", G.eye(), 110, "eye", 2.6, None, "eye", "glow")
    part("lid", G.lid(), 130, "skin", 1.4, None, "lid", "skin")
    part("monocle", G.monocle(), 560, "gear", 2.2, None, "head", None)
    part("body", tr, 4300, "skin", 1.0, None, "body", None)
    part("belt", G.belt(), 380, "gear", 1.0, None, "root", None)
    part("loin", G.loincloth(), 300, "loin", 0.9, None, "skirt", None)
    part("straps", G.straps(), 260, "gear", 0.9, None, "hips", None)
    part("cuffR", G.cuff(J, "R", 1), 240, "gear", 1.0, None, "forearm.R", None)
    part("cuffL", G.cuff(J, "L", -1), 240, "gear", 1.0, None, "forearm.L", None)
    gt = G.gauntlet(J)
    part("gauntlet", gt, 1150, "gear", 1.4, None, "gauntlet", None)
    part("hook", G.hook(J), 520, "gear", 1.3, None, "hook", None)
    part("gun", G.gun(), 420, "gear", 1.3, G.gun_xf, "gun", None)
    part("hoard", G.hoard(), 4600, "hoard", 1.0, None, "hoard", None)
    bl = G.bell()
    ln = G.lantern()
    TIP = {"R": np.array((0.475, -0.215, 1.640), F), "L": np.array((-0.475, -0.215, 1.640), F)}
    APEX = {"R": np.array((0.303, -0.215, 1.612), F), "L": np.array((-0.303, -0.215, 1.612), F)}
    LAMP_LEN, BELL_LEN = 0.27, 0.052
    ends = {}
    for n in "RL":
        ends["lamp" + n] = TIP[n] - (0, 0, LAMP_LEN)
        ends["bell" + n] = APEX[n] - (0, 0, BELL_LEN)
        tl = lambda p, c=ends["lamp" + n] + 0: np.asarray(p, F) + c
        tb = lambda p, c=ends["bell" + n] + 0: np.asarray(p, F) + c
        part("lantern" + n, ln, 180, "gear", 1.2, tl, "lamp" + n, None)
        part("bell" + n, bl, 170, "gear", 1.1, tb, "bell" + n, None)
        part("lampchain" + n, None, 0, "iron", 0.5, None, "lamp" + n, "metal", ob=chain_links("lampchain" + n, [TIP[n], ends["lamp" + n]], 0.024, 0.012, 0.0042))
    bf = G.ball()
    part("ball", bf, 1000, "hoard", 0.9, G.ball_xf, "ball", None)
    # the chains on the weapon and the eyepiece
    x, wz = float(J["hand.R"][0]), float(J["hand.R"][2])
    k = G.HOOK_SCALE
    cur = G.hook_curve()
    heel = cur[7]
    pr = [(x - 0.068, 0.0, wz - 0.040), (x - 0.095, -0.05, wz - 0.20), (x - 0.075, -0.075, wz - 0.42), (x - 0.03, 0.0, wz - 0.53), (x, float(heel[0]) * 0.8, wz + float(heel[1]) + 0.03)]
    part("hookchain", None, 0, "iron", 0.5, None, "hook", "metal", ob=chain_links("hookchain", spline(pr, 24), 0.030, 0.0165, 0.0058))
    MC = G.MONO_C + (G.MONO_R + 0.012, -0.004, -0.008)
    MJ = spline([MC, MC + (0.004, 0.0, -0.075), MC + (-0.002, -0.004, -0.14)], 4)
    part("monochain", None, 0, "gold", 0.5, None, "monochain", "brass", ob=chain_links("monochain", spline(MJ, 12), 0.0105, 0.0058, 0.0020))

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
        k2 = math.sqrt(a3 * p["density"] ** 2 / max(a2, 1e-9))
        me.uv_layers.active.data.foreach_set("uv", (uv * k2).ravel())
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
            lab = f.label(pts).astype(np.int32)
        nm = p["paint"]
        if nm == "head":
            rgb = P.head(pts, nn, lab, f)
        elif nm == "skin":
            rgb = P.skin(pts, nn, lab, f)
        elif nm == "tooth":
            rgb = P.tooth(pts, nn, lab, f)
        elif nm == "eye":
            rgb = P.eye(pts, nn)
        elif nm == "hoard":
            rgb = P.hoard(pts, nn, lab, f)
        elif nm == "loin":
            rgb = P.loincloth(pts, nn, lab, f)
        elif nm == "gear":
            rgb = P.gear(pts, nn, lab, f)
        else:
            rgb = P.flat(pts, nn, nm)
        atlas[idx] = rgb
        mask |= m
        if f is not None and not p["slot"]:
            cen = vs[tri].mean(1).astype(F)
            p["tri_lab"] = f.label(f.project(cen, 1)).astype(np.int32)
        if p["xf"] is not None:
            set_verts(ob, p["xf"](vs))
            nrm = (p["xf"](nrm) - p["xf"](np.zeros((1, 3), F)))
        p["nrm"] = nrm
        print("painted", p["name"], len(tri), flush=True)
    img = S.dilate(atlas, mask, 10)
    os.makedirs(WORK, exist_ok=True)
    png = os.path.join(WORK, "atlas.png")
    imgio.save(img[::-1], png)
    print("atlas coverage %.3f" % mask.mean(), flush=True)

    # ----------------------------------------------------- the armature and his own bones
    arm = K.build_armature(rig)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for s, n in ((1, "R"), (-1, "L")):
        hx = s * float(J["shin.R"][0])
        add_bone(arm, "foot." + n, (hx, 0, G.ANKLE), (hx, 0.17, 0.03), "shin." + n, (0, 0, 1))
    e = G.EYE_C
    add_bone(arm, "eye", e, e + (0, 0.03, 0), "head", (0, 0, 1))
    add_bone(arm, "lid", e, e + (0.03, 0, 0), "head", (0, 0, 1))
    b0 = G.HEAD_C + (0.038, 0.098, 0.052)
    add_bone(arm, "brow", b0, b0 + (0, 0.03, 0), "head", (0, 0, 1))
    j0 = G.HEAD_C + (0, -0.015, -0.020)
    add_bone(arm, "jaw", j0, j0 + (0, 0.08, -0.03), "head", (0, 0, 1))
    g = G.gauntlet_joints(J)
    add_bone(arm, "fingers.L", g["knuckle"], g["knuckle"] + (0, 0, -0.06), "hand.L", (1, 0, 0))
    add_bone(arm, "fingers2.L", g["knuckle"] + (0.006, 0, -0.062), g["knuckle"] + (0.05, 0, -0.13), "fingers.L", (1, 0, 0))
    add_bone(arm, "thumb.L", g["thumb"], g["thumb2"], "hand.L", (1, 0, 0))
    w = (float(J["hand.R"][0]), 0.0, float(J["hand.R"][2]))
    add_bone(arm, "hook", (w[0], 0, w[2] - 0.09), (w[0], 0, w[2] - 0.2), "hand.R", (0, 1, 0))
    add_bone(arm, "gun", G.GUN_AT, G.GUN_AT + G.GUN_R[:, 1] * 0.2, "root", tuple(G.GUN_R[:, 2]))
    add_bone(arm, "hoard", G.HB, G.HB + (0, 0, 0.2), "hips", (0, 1, 0))
    add_bone(arm, "ball", G.BALL_AT, G.BALL_AT + (0, 0, 0.1), "root", (0, 1, 0))
    chains = {}
    for n in "RL":
        chains["lamp" + n] = spline([TIP[n], ends["lamp" + n]], 4)
        chains["bell" + n] = spline([APEX[n], ends["bell" + n]], 2)
    chains["mono"] = MJ
    roots = {"mono": "head"}
    for nm, js in chains.items():
        parent = roots.get(nm, "hoard")
        for i in range(len(js) - 1):
            add_bone(arm, "spring_hang%s_%d" % (nm, i), js[i], js[i + 1], parent if i == 0 else "spring_hang%s_%d" % (nm, i - 1))
        c = len(js) - 1
        add_bone(arm, "spring_hang%s_%d" % (nm, c), js[-1], js[-1] + (js[-1] - js[-2]) * 0.4, "spring_hang%s_%d" % (nm, c - 1))
    bpy.ops.object.mode_set(mode="OBJECT")
    print("armature", time.time() - t0, flush=True)

    # ----------------------------------------------------- skin
    def allow(pg, bone, g2, pts):
        z = pts[:, 2]
        m = (g2 == pg).astype(F)
        if pg == 0:
            return m + (g2 >= 3) * (z > 0.64) + ((g2 == 1) | (g2 == 2)) * (z > 1.02)
        if bone.startswith("upper_arm"):
            sx = 1 if bone.endswith("R") else -1
            return m + (g2 == 0) * (z > 0.99) * (pts[:, 0] * sx > 0.13)
        if bone.startswith("thigh"):
            sx = 1 if bone.endswith("R") else -1
            return m + (g2 == 0) * (z < 0.76) * (pts[:, 0] * sx > 0.0)
        return m

    def chain_w(js, names, p2):
        pts = np.array(js, F)
        ab = pts[1:] - pts[:-1]
        best, seg, tt = np.full(len(p2), 9.0, F), np.zeros(len(p2), int), np.zeros(len(p2), F)
        for i in range(len(ab)):
            t = np.clip(((p2 - pts[i]) @ ab[i]) / float(ab[i] @ ab[i]), 0, 1)
            d = np.linalg.norm(p2 - (pts[i] + ab[i] * t[:, None]), axis=1)
            mm = d < best
            best[mm], seg[mm], tt[mm] = d[mm], i, t[mm]
        u = seg + tt - 0.5
        W = {}
        for i, nm2 in enumerate(names):
            W[nm2] = np.clip(1 - np.abs(u - i), 0, 1)
        W[names[0]] = np.maximum(W[names[0]], (u <= 0) * 1.0)
        W[names[-1]] = np.maximum(W[names[-1]], (u >= len(names) - 1) * 1.0)
        return W

    for p in parts:
        ob = p["ob"]
        vs = verts(ob)
        nm, grp = p["name"], p["group"]
        one = np.ones(len(vs), F)
        if nm == "skin_head":
            h = vs - G.HEAD_C
            neck = S.smooth(-0.125, -0.045, h[:, 1])
            lo = h[:, 2] - (G.grin_z(h[:, 0]) - G.grin_h(h[:, 0]) * 0.1)
            jw = S.smooth(0.0, -0.016, lo) * S.smooth(-0.015, 0.03, h[:, 1])
            br = np.exp(-(np.linalg.norm((vs - (G.HEAD_C + (0.042, 0.098, 0.052))) * (0.62, 1, 1.25), axis=1) / 0.040) ** 2) * (h[:, 2] > 0.018) * (h[:, 1] > 0.03)
            W = {"head": neck * (1 - jw) * (1 - br) + 1e-3, "hips": 1 - neck, "jaw": neck * jw, "brow": neck * br * (1 - jw)}
        elif nm == "teeth":
            h = vs - G.HEAD_C
            lower = (h[:, 2] < G.grin_z(h[:, 0])) * 1.0
            W = {"head": 1 - lower + 1e-4, "jaw": lower}
        elif grp == "eye":
            W = {"eye": one}
        elif grp == "lid":
            W = {"lid": one}
        elif grp == "head":
            W = {"head": one}
        elif nm == "body":
            W = tr.weights(vs, 0.024, allow)
            W = {k3: w3 for k3, w3 in W.items() if w3.max() > 1e-4}
        elif grp == "gauntlet":
            W = gt.weights(vs, 0.006)
            W = {k3: w3 for k3, w3 in W.items() if w3.max() > 1e-4}
        elif grp == "skirt":
            W = {"skirt": S.smooth(0.70, 0.60, vs[:, 2]) + 1e-3, "root": S.smooth(0.60, 0.70, vs[:, 2])}
        elif grp in ("lampR", "lampL", "bellR", "bellL"):
            js = chains[grp]
            names = ["spring_hang%s_%d" % (grp, i) for i in range(len(js))]
            if nm.startswith("lampchain"):
                W = chain_w(js, names[:-1], vs)
            else:
                W = {names[-1]: one}
        elif grp == "monochain":
            names = ["spring_hangmono_%d" % i for i in range(len(MJ) - 1)]
            W = chain_w(MJ, names, vs)
        else:
            W = {grp: one}
        add_weights(ob, W)

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
            lab = p["tri_lab"]
            slots = sorted({slot_of(a) for a in np.unique(lab)})
            for s in slots:
                me.materials.append(mat(s))
            ix = np.array([slots.index(slot_of(a)) for a in lab], np.int32)
            me.polygons.foreach_set("material_index", ix)
        for pl in me.polygons:
            pl.use_smooth = True
        n = p["nrm"]
        n = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
        me.normals_split_custom_set_from_vertices(n.tolist())

    ROOM = {"teeth": 0.0, "eye": 0.0, "lid": 0.0, "skin_head": 0.15, "monocle": 0.1, "monochain": 0.0, "hookchain": 0.0, "lampchainR": 0.0, "lampchainL": 0.0,
            "ball": 0.5, "hoard": 0.55, "hook": 0.9, "gauntlet": 0.5}
    for p in parts:
        me = p["ob"].data
        at = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        a = np.ones(len(me.vertices) * 4, F)
        a[3::4] = ROOM.get(p["name"], 0.7)
        at.data.foreach_set("color", a)

    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p["ob"].select_set(True)
    bpy.context.view_layer.objects.active = parts[0]["ob"]
    bpy.ops.object.join()
    bd = bpy.context.view_layer.objects.active
    bd.name = bd.data.name = "grimble"
    bd.parent = arm
    md = bd.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    # empties: anchors, FX points
    K.anchor(arm, "head", "anchor_head_top", (0, float(G.HEAD_C[1]), 1.285))
    K.anchor(arm, "hips", "anchor_chest", (0, 0.10, 1.02))
    K.anchor(arm, "gun", "weapon_muzzle", tuple(G.gun_xf(np.array((0, 0.30, 0.012), F))))
    K.anchor(arm, "gun", "anchor_gun_root", tuple(G.gun_xf(np.array((0, 0.0, 0.012), F))))
    K.anchor(arm, "hook", "anchor_claw", tuple(G.hook_mouth(J)))
    K.anchor(arm, "hook", "anchor_hook_tip", tuple(G.hook_tip(J)))
    K.anchor(arm, "hoard", "anchor_coins", (0.05, -0.14, 1.34))
    K.anchor(arm, "hoard", "anchor_hoard_top", (0.0, -0.32, 1.72))
    K.anchor(arm, "spring_hanglampR_2", "anchor_lamp_r", tuple(ends["lampR"] - (0, 0, 0.105)))
    K.anchor(arm, "spring_hanglampL_2", "anchor_lamp_l", tuple(ends["lampL"] - (0, 0, 0.105)))
    bd.data.validate(clean_customdata=False)
    print("tris total", K.tris([bd]), time.time() - t0, flush=True)
    bpy.context.scene["hook_len"] = 0.0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, "grimble_art1.blend"))


main()
