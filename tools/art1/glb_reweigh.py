"""Skin weights that do not stretch, on a finished Hero .glb (docs/art/wardens/STRETCH.md, tools/stretch_check.gd).
skin_relax.reweigh's rules (Grimble's bake) for a v95-swapped Hero, run on the game .glb itself, so no bake input is needed:
only the body mesh's vertices, weights and triangles change; every clip, the skeleton, the anchors and the props are the
same data (the binary is repacked, so their byte offsets move; their bytes do not).
- The body is welded (the .glb splits vertices at UV and material seams): weights are solved per welded point, so both
  copies of a seam vertex get the same weights and no seam opens.
- `heat`: Blender bone-heat weights on the body bones, as in reweigh; `keep`: the weights the swap gave it.
- `near`: a vertex weights only its main bone, that bone's parent and its children: no torso vertex follows a forearm or a
  shin, no thigh follows an arm (reweigh's keep_apart, for any rig).
- `rip`: where faces of two APART parts meet (the scan fused a hand to a thigh, a forearm to the waist), each side gets its
  own vertices (reweigh's rip); nothing is deleted, no hole opens at rest.
- then the edges still over LIMIT in some clip blend their weights toward their neighbours' (skin_relax.relax, no cuts).
Prints the worst stretch per clip before and after, and writes OUT.json beside OUT_GLB with both tables.
Run: blender -b --factory-startup --python tools/art1/glb_reweigh.py -- IN_GLB OUT_GLB [heat|keep] [relax_passes]
(CLIPS=run,hail in the environment: only those clips, for a quick look.)"""
import json
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils.kdtree import KDTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import glb_add_clips as G
import skin_relax as R

LIMIT = float(os.environ.get("LIMIT", 1.5))   # x rest length: edges over it in some clip get relaxed
RULE = os.environ.get("RULE", "part")          # part: no weight on a part APART from the main bone's; part1: and one joint per
#                                               vertex (one_joint); near: the main bone's neighbours only; strict: all three; band: part1 and
#                                               `band`; partband: part and `band`;
#                                               armnear: part, `near` on arm verts, `band`; none
RIP = os.environ.get("RIP", "1") == "1"
BAND = float(os.environ.get("BAND", 0.3))       # of a limb bone's length: the blend zone at each of its ends (`band`)
BAND_BONES = os.environ.get("BAND_BONES", "")    # e.g. "upper_arm,forearm": `band` on those limb bones only (default all)
RULE_AT = float(os.environ.get("RULE_AT", 0))  # the rule only touches verts on edges past this in some clip (0: every body vertex)
R.RINGS = int(os.environ.get("RINGS", R.RINGS))      # rings round a bad vertex that blend with it (wider bands)
WELD = 1e-5          # m: seam copies sit at the very same point
HEAT_WELD = 0.002    # m: the heat copy also joins the scan's near-doubled seams (reweigh's WELD)
LIMB = {"upper_arm.L": "ua.L", "forearm.L": "la.L", "hand.L": "la.L", "upper_arm.R": "ua.R", "forearm.R": "la.R", "hand.R": "la.R",
        "thigh.L": "leg.L", "shin.L": "leg.L", "foot.L": "leg.L", "thigh.R": "leg.R", "shin.R": "leg.R", "foot.R": "leg.R"}
PARTS = ["trunk", "ua.L", "la.L", "ua.R", "la.R", "leg.L", "leg.R"]
TOUCH = {("trunk", "ua.L"), ("trunk", "ua.R"), ("ua.L", "la.L"), ("ua.R", "la.R"), ("trunk", "leg.L"), ("trunk", "leg.R"),
         ("leg.L", "leg.R")}    # parts that meet at a joint; every other pair is APART
if os.environ.get("LEGS_APART") == "1":
    TOUCH.discard(("leg.L", "leg.R"))
ATTRS = ("POSITION", "NORMAL", "TEXCOORD_0", "TEXCOORD_1", "COLOR_0", "JOINTS_0", "WEIGHTS_0", "TANGENT",
         "indices", "input", "output", "inverseBindMatrices")
DT = {5120: "<i1", 5121: "<u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Mesh:
    """The welded body as skin_relax.Skin's methods want it: rest [n, 3] (armature space), w [n, bone], edges [e, 2], len [e]."""
    stretch = R.Skin.stretch
    relax_once = R.Skin.relax_once

    def __init__(self, rest, w, faces):
        self.rest, self.w, self.faces = rest, w, faces
        ed = np.sort(np.r_[faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]], 1)
        ed = np.unique(ed[ed[:, 0] != ed[:, 1]], axis=0)
        ln = np.linalg.norm(rest[ed[:, 0]] - rest[ed[:, 1]], axis=1)
        self.edges, self.len = ed[ln >= R.MIN_EDGE], ln[ln >= R.MIN_EDGE]


def per_clip(s, poses):
    acts = {}
    for n, m in poses:
        _, per = s.stretch([(n, m)])
        acts[n] = max(acts.get(n, 0.0), float(per[0]))
    return acts


def part_of(arm, names):
    """[bone] -> PARTS index (a bone under a limb bone is that limb's: fingers, the bow, the gun); the trunk otherwise."""
    out = np.zeros(len(names), int)
    for i, b in enumerate(arm.data.bones):
        p = b
        while p and p.name not in LIMB:
            p = p.parent
        out[i] = PARTS.index(LIMB[p.name]) if p else 0
    return out


def skin_parent(arm, names):
    """[bone] -> its parent's index for skinning, -1 for none: the rigs hang the thighs off `root`, but they bend from the hips."""
    out = []
    for b in arm.data.bones:
        p = b.parent.name if b.parent else None
        if p == "root" and b.name != "hips" and "hips" in names:
            p = "hips"
        out.append(names.index(p) if p else -1)
    return np.array(out)


def near(w, arm, names):
    """Zeroes every weight off the vertex's main bone, its (skinning) parent and its children."""
    par = skin_parent(arm, names)
    ok = np.eye(len(names), dtype=bool)
    for i, p in enumerate(par):
        if p >= 0:
            ok[i, p] = ok[p, i] = True
    w = w * ok[np.argmax(w, 1)]
    return w / np.maximum(w.sum(1, keepdims=True), 1e-9)


def keep_apart(w, part):
    """Zeroes every weight on a bone of a part APART from the vertex's main bone's part (skin_relax.reweigh's keep_apart)."""
    ok = np.array([[not apart(a, b) for b in part] for a in range(len(PARTS))])
    w = w * ok[part[np.argmax(w, 1)]]
    return w / np.maximum(w.sum(1, keepdims=True), 1e-9)


def one_joint(w, arm, names):
    """A vertex blends across one joint of its main bone only: weight on both its parent and a child keeps the bigger side."""
    par = skin_parent(arm, names)
    m = np.argmax(w, 1)
    up = np.where(par[m] >= 0, w[np.arange(len(w)), np.maximum(par[m], 0)], 0)
    down = (w * (par[None, :] == m[:, None])).sum(1)
    cut_up = (up > 0) & (down > up)
    cut_down = (down > 0) & (up >= down)
    w = w.copy()
    w[np.nonzero(cut_up)[0], par[m][cut_up]] = 0
    w[cut_down[:, None] & (par[None, :] == m[:, None])] = 0
    return w / np.maximum(w.sum(1, keepdims=True), 1e-9)


def band(w, rest, arm, names):
    """A limb vertex shares weight with its bone's parent only within BAND of the bone's head, and with its children only
    within BAND of its tail (the share fades to nothing at the band's edge): no thigh weight half way down a shin."""
    par = skin_parent(arm, names)
    m = np.argmax(w, 1)
    w = w.copy()
    for bi, b in enumerate(arm.data.bones):
        on = np.nonzero(m == bi)[0]
        if b.name not in LIMB or not len(on) or (BAND_BONES and b.name.split(".")[0] not in BAND_BONES.split(",")):
            continue
        h, t = np.array(b.head_local), np.array(b.tail_local)
        u = ((rest[on] - h) @ (t - h)) / max((t - h) @ (t - h), 1e-9)
        for side, cap in ((par[None, :] == bi, np.clip((u - (1 - BAND)) / BAND, 0, 1) * 0.5),      # children
                          (np.arange(len(names))[None, :] == par[bi], np.clip((BAND - u) / BAND, 0, 1) * 0.5)):
            cols = np.nonzero(side[0])[0]
            if not len(cols):
                continue
            got = w[np.ix_(on, cols)].sum(1)
            scale = np.where(got > cap, cap / np.maximum(got, 1e-9), 1.0)
            w[np.ix_(on, cols)] *= scale[:, None]
    return w / np.maximum(w.sum(1, keepdims=True), 1e-9)


def rule(w, arm, names, part, rest=None):
    if RULE == "armnear":       # part; and an arm vertex weights only its bone's neighbours, banded (Lace: hair and waist on the arms)
        w = keep_apart(w, part)
        arms = np.isin(np.argmax(w, 1), [names.index(n) for n in names if n.split(".")[0] in ("upper_arm", "forearm")])
        w[arms] = near(w[arms], arm, names)
        return band(w, rest, arm, names)
    if RULE == "partband":
        return band(keep_apart(w, part), rest, arm, names)
    if RULE == "band":
        return band(one_joint(keep_apart(w, part), arm, names), rest, arm, names)
    if RULE == "strict":
        return one_joint(near(keep_apart(w, part), arm, names), arm, names)
    if RULE == "part1":
        return one_joint(keep_apart(w, part), arm, names)
    return near(w, arm, names) if RULE == "near" else keep_apart(w, part) if RULE == "part" else w


def heat(arm, rest, faces, body, bones, names):
    """Bone heat on a copy of the `body` verts (welded at HEAT_WELD, at rest); each vertex takes the inverse-distance mean of
    its four nearest copy verts (skin_relax.reweigh's heat())."""
    deform = {b.name: b.use_deform for b in arm.data.bones}
    arm.data.pose_position = "REST"
    keep = np.nonzero(body)[0]
    re = -np.ones(len(rest), int)
    re[keep] = np.arange(len(keep))
    fk = faces[body[faces].all(1)]
    me = bpy.data.meshes.new("heat")
    me.from_pydata(rest[keep].tolist(), [], re[fk].tolist())
    cp = bpy.data.objects.new("heat", me)
    bpy.context.scene.collection.objects.link(cp)
    cp.matrix_world = arm.matrix_world
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=HEAT_WELD)
    bm.to_mesh(me)
    bm.free()
    for b in arm.data.bones:
        b.use_deform = b.name in bones
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    cp.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    P = np.zeros((len(me.vertices), len(names)))
    for v in me.vertices:
        for g in v.groups:
            nm = cp.vertex_groups[g.group].name
            if nm in names:
                P[v.index, names.index(nm)] = g.weight
    pc = np.array([v.co[:] for v in me.vertices])
    kd = KDTree(len(pc))
    for i, c in enumerate(pc):
        kd.insert(c, i)
    kd.balance()
    H = np.zeros((len(rest), len(names)))
    for vi in keep:
        nb = kd.find_n(rest[vi], 4)
        ww = np.array([1 / max(d, 1e-4) for _, _, d in nb])
        H[vi] = (ww[:, None] * P[[i for _, i, _ in nb]]).sum(0) / ww.sum()
    arm.data.pose_position = "POSE"
    for b in arm.data.bones:
        b.use_deform = deform[b.name]
    return H


def apart(a, b):
    return a != b and (PARTS[a], PARTS[b]) not in TOUCH and (PARTS[b], PARTS[a]) not in TOUCH


def rip(s, part, body):
    """Splits the welded mesh between faces of APART parts. A face's part is the most common of its verts' parts; a body
    vertex on faces of a part APART from its own gets a copy for that part, weighted as its neighbours there.
    Returns the new Mesh, each vertex's source vertex and the number of copies."""
    vp = part[np.argmax(s.w, 1)]
    fp = np.array([max(set(t), key=list(t).count) for t in vp[s.faces].tolist()])
    rest, w, src = list(s.rest), list(s.w), list(range(len(s.w)))
    faces = s.faces.copy()
    made = {}
    vf = {}
    for f, tri in enumerate(s.faces.tolist()):
        for v in tri:
            vf.setdefault(v, []).append(f)
    for f, (tri, p) in enumerate(zip(s.faces.tolist(), fp.tolist())):
        for c, v in enumerate(tri):
            if not body[v] or not apart(vp[v], p):
                continue
            if (v, p) not in made:
                nb = {u for g in vf[v] if fp[g] == p for u in s.faces[g] if u != v and vp[u] == p}
                made[(v, p)] = len(rest)
                rest.append(s.rest[v])
                w.append(np.mean([s.w[u] for u in nb], 0) if nb else s.w[v])
                src.append(v)
            faces[f, c] = made[(v, p)]
    return Mesh(np.array(rest), np.array(w), faces), np.array(src), len(made)


def acc(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    assert "byteStride" not in bv
    o0 = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = a["count"] * NC[a["type"]]
    dt = np.dtype(DT[a["componentType"]])
    arr = np.frombuffer(bytes(b[o0:o0 + n * dt.itemsize]), dt)
    return arr.reshape(a["count"], -1) if NC[a["type"]] > 1 else arr


def put(j, b, like, arr):
    """A new accessor like accessor `like` holding arr, at the end of the binary. Returns its index."""
    old = j["accessors"][like]
    arr = np.ascontiguousarray(arr).astype(DT[old["componentType"]])
    raw = arr.tobytes()
    b.extend(b"\0" * (-len(b) % 4))
    bv = {"buffer": 0, "byteOffset": len(b), "byteLength": len(raw)}
    if "target" in j["bufferViews"][old["bufferView"]]:
        bv["target"] = j["bufferViews"][old["bufferView"]]["target"]
    j["bufferViews"].append(bv)
    b.extend(raw)
    a = {k: v for k, v in old.items() if k not in ("byteOffset", "min", "max")}
    a["bufferView"], a["count"] = len(j["bufferViews"]) - 1, len(arr)
    if "min" in old:
        flat = arr.reshape(len(arr), -1)
        a["min"], a["max"] = flat.min(0).tolist(), flat.max(0).tolist()
    j["accessors"].append(a)
    return len(j["accessors"]) - 1


def _refs(x, fn):
    if isinstance(x, dict):
        for k, v in x.items():
            if k in ATTRS and isinstance(v, int):
                x[k] = fn(v)
            else:
                _refs(v, fn)
    elif isinstance(x, list):
        for v in x:
            _refs(v, fn)


def pack(j, b):
    """Drops the accessors and buffer views nothing uses and lays the rest out again in order; their bytes are unchanged."""
    used = set()
    tops = [j.get(k, []) for k in ("meshes", "animations", "skins")]
    _refs(tops, lambda v: used.add(v) or v)
    amap = {i: n for n, i in enumerate(sorted(used))}
    accs = [j["accessors"][i] for i in sorted(used)]
    imgs = {im["bufferView"] for im in j.get("images", []) if "bufferView" in im}
    live = imgs | {a["bufferView"] for a in accs}
    vmap, views, nb = {}, [], bytearray()
    for i, v in enumerate(j["bufferViews"]):
        if i in live:
            nb.extend(b"\0" * (-len(nb) % 4))
            o = v.get("byteOffset", 0)
            views.append(dict(v, byteOffset=len(nb)))
            nb.extend(b[o:o + v["byteLength"]])
            vmap[i] = len(views) - 1
    for a in accs:
        a["bufferView"] = vmap[a["bufferView"]]
    for im in j.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = vmap[im["bufferView"]]
    _refs(tops, lambda v: amap[v])
    j["accessors"], j["bufferViews"] = accs, views
    nb.extend(b"\0" * (-len(nb) % 4))
    j["buffers"][0]["byteLength"] = len(nb)
    return nb


def stage(s, poses, tag, names):
    worst, per = s.stretch(poses)
    e = s.edges[np.argmax(worst)]
    show = lambda v: " ".join("%s:%.2f" % (names[k], s.w[v, k]) for k in np.argsort(-s.w[v])[:3] if s.w[v, k] > 0)
    print("stage %-6s worst %.2f in %s | %s || %s" % (tag, worst.max(), poses[int(np.argmax(per))][0], show(e[0]), show(e[1])), flush=True)


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    src, out = a[0], a[1]
    mode = a[2] if len(a) > 2 else "heat"
    passes = int(a[3]) if len(a) > 3 else 120
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src, merge_vertices=False)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    if not arm.animation_data:
        arm.animation_data_create()
    names = arm.data.bones.keys()
    bones = [n for n in names if n in ("root", "hips", "head") or n in LIMB]
    part = part_of(arm, names)
    if os.environ.get("CLIPS"):
        for act in [x for x in bpy.data.actions if not any(x.name.startswith(c) for c in os.environ["CLIPS"].split(","))]:
            bpy.data.actions.remove(act)
    poses = R.pose_matrices(arm)

    j, b = G.read(src)
    jn = [j["nodes"][n]["name"] for n in j["skins"][0]["joints"]]
    col = np.array([jn.index(nm) if nm in jn else -1 for nm in names])
    nv = [sum(j["accessors"][p["attributes"]["POSITION"]]["count"] for p in me["primitives"]) for me in j["meshes"]]
    mesh_i = nv.index(max(nv))        # the body: the biggest mesh
    node = next(n for n in j["nodes"] if n.get("mesh") == mesh_i)
    ob = bpy.data.objects[node["name"]]
    m = np.array(arm.matrix_world.inverted() @ ob.matrix_world)
    prims = []
    for p in j["meshes"][mesh_i]["primitives"]:
        P = acc(j, b, p["attributes"]["POSITION"]).astype(float)
        P = np.c_[P[:, 0], -P[:, 2], P[:, 1]] @ m[:3, :3].T + m[:3, 3]
        prims.append((p, P, acc(j, b, p["indices"]).reshape(-1, 3).astype(int)))
    # weld every primitive's vertices into one mesh
    allP = np.concatenate([P for _, P, _ in prims])
    base = np.cumsum([0] + [len(P) for _, P, _ in prims])
    W0 = np.zeros((len(allP), len(names)))
    for k, (p, P, _) in enumerate(prims):
        J, Wt = acc(j, b, p["attributes"]["JOINTS_0"]), acc(j, b, p["attributes"]["WEIGHTS_0"]).astype(float)
        for bi in range(len(names)):
            if col[bi] >= 0:
                W0[base[k]:base[k + 1], bi] = (Wt * (J == col[bi])).sum(1)
    # seam copies share point and weights; a swap `detach` cut shares only the point and stays apart
    key = np.c_[np.round(allP / WELD), np.round(W0 * 1000)].astype(np.int64)
    _, first, wid = np.unique(key, axis=0, return_index=True, return_inverse=True)
    wid = wid.ravel()
    faces = np.concatenate([wid[F + base[k]] for k, (_, _, F) in enumerate(prims)])
    s = Mesh(allP[first], W0[first], faces)
    before = per_clip(s, poses)
    body = np.isin(np.argmax(s.w, 1), [names.index(x) for x in bones]) & (s.w.sum(1) > 0)
    print("reweigh %s: %d verts welded to %d, %d body, %d faces" % (ob.name, len(allP), len(s.w), body.sum(), len(faces)), flush=True)
    stage(s, poses, "start", names)
    if mode == "heat":
        H = heat(arm, s.rest, s.faces, body, bones, names)
        got = body & (H.sum(1) > 1e-6)
        s.w[got] = H[got] / H[got].sum(1, keepdims=True)
        stage(s, poses, "heat", names)
    def grow(mask, edges, rings=1):
        for _ in range(rings):
            hit = mask[edges[:, 0]] | mask[edges[:, 1]]
            mask = mask.copy()
            mask[edges[hit].ravel()] = True
        return mask
    fix = body.copy()
    if RULE_AT > 0:          # leave the regions the swap already got right as they are
        worst, _ = s.stretch(poses)
        fix = np.zeros(len(s.w), bool)
        fix[s.edges[worst > RULE_AT].ravel()] = True
        fix = grow(fix, s.edges) & body
    s.w[fix] = rule(s.w[fix], arm, names, part, s.rest[fix])
    stage(s, poses, RULE, names)
    ncopy = 0
    if RIP:
        s, srcv, ncopy = rip(s, part, body)
        body, fix = body[srcv], fix[srcv]
        s.w[fix] = rule(s.w[fix], arm, names, part, s.rest[fix])
        stage(s, poses, "rip", names)
    it = 0
    best = (np.inf, s.w.copy())
    for it in range(passes):
        if it % 8 == 0:
            worst, per = s.stretch(poses)
            live = [p for p, r in zip(poses, per) if r > LIMIT] or poses
            if max(per) < best[0]:      # the blend is blind: keep the weights whose worst clip was the best seen
                best = (max(per), s.w.copy())
        else:
            worst, _ = s.stretch(live)
        bad = (worst > LIMIT) & body[s.edges].all(1)
        if not bad.any():
            break
        keep = s.w.copy()
        s.relax_once(bad)
        s.w[~body] = keep[~body]
        if RULE_AT > 0:
            hot = np.zeros(len(s.w), bool)
            hot[s.edges[bad & (worst > RULE_AT)].ravel()] = True
            fix |= grow(hot, s.edges, R.RINGS) & body
        s.w[fix] = rule(s.w[fix], arm, names, part, s.rest[fix])
    if max(s.stretch(poses)[1]) > best[0]:
        s.w = best[1]
    top = np.argsort(-s.w, axis=1)[:, R.MAX_INFL:]
    np.put_along_axis(s.w, top, 0.0, axis=1)
    s.w /= np.maximum(s.w.sum(1, keepdims=True), 1e-9)
    stage(s, poses, "relax", names)
    after = per_clip(s, poses)
    print("reweigh %s: %d copies ripped, %d relax passes; worst %.2f -> %.2f"
          % (ob.name, ncopy, it, max(before.values()), max(after.values())), flush=True)
    for k in sorted(before, key=lambda k: -before[k]):
        print("  %-24s %6.2f -> %5.2f" % (k, before[k], after[k]))
    # each glTF corner -> its face's welded (or ripped) vertex; a glTF vertex used by two of those is copied
    fo = 0
    for k, (p, P, F) in enumerate(prims):
        tgt = s.faces[fo:fo + len(F)]
        fo += len(F)
        A = p["attributes"]
        use, newF, rows = {}, F.copy(), []
        for f in range(len(F)):
            for c in range(3):
                vt = (int(F[f, c]), int(tgt[f, c]))
                if vt not in use:
                    use[vt] = len(rows)
                    rows.append(vt)
                newF[f, c] = use[vt]
        rv = np.array([r[0] for r in rows])
        Jn = np.zeros((len(rows), 4), int)
        Wn = np.zeros((len(rows), 4))
        for q, (_, t) in enumerate(rows):
            row = s.w[t]
            order = [x for x in np.argsort(-row)[:4] if row[x] > 0 and col[x] >= 0]
            for c, x in enumerate(order):
                Jn[q, c], Wn[q, c] = col[x], row[x]
        Wn /= np.maximum(Wn.sum(1, keepdims=True), 1e-9)
        for an, i in list(A.items()):
            A[an] = put(j, b, i, Jn if an == "JOINTS_0" else Wn if an == "WEIGHTS_0" else acc(j, b, i)[rv])
        p["indices"] = put(j, b, p["indices"], newF.ravel())
        print("reweigh prim %d: %d -> %d verts" % (k, len(P), len(rows)))
    G.write(out, j, pack(j, b))
    print("reweigh: wrote %s" % out, flush=True)
    json.dump({"mode": mode, "rule": RULE, "rip": RIP, "limit": LIMIT, "passes": it, "rule_at": RULE_AT, "band": BAND,
               "band_bones": BAND_BONES, "legs_apart": ("leg.L", "leg.R") not in TOUCH, "before": before, "after": after, "ripped": ncopy},
              open(os.path.splitext(out)[0] + ".json", "w"), indent=1, sort_keys=True)


main()
