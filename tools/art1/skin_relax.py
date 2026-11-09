"""Skin weights that do not stretch (ART-1): no clip may pull a triangle edge far past its rest length (tools/stretch_check.gd).
The scan fit's weights (grimble_source.seg_weights: distance to capsules) leak wherever the scan fused parts: the arms hang
against the torso, the hook's claw lies along the right shin, so torso verts followed the arms and the claw followed the leg
(up to 26x in a clip). reweigh() replaces them on the body with Blender's bone-heat weights, solved on a clean body-only copy
of the mesh (the full scan has open, doubled and loose parts, where heat finds no solution), then:
- an arm vertex never follows a leg or the other forearm, and the reverse (LIMBS, APART);
- where faces of two such limbs meet (a weld in the scan) the mesh is ripped: each side gets its own vertices, so the claw
  can leave the shin without dragging it. Nothing is deleted, no hole opens at rest.
Then measure() prints the worst stretch per action. Use: skin_relax.reweigh(arm, ob) from a clips script, before the export.
Blender only (bpy, numpy). Grimble only for now: the bone names below are his."""
import bmesh
import bpy
import numpy as np
from mathutils.kdtree import KDTree

STEP = 3             # frames between samples of a clip (the last frame is always sampled)
MIN_EDGE = 0.008     # m: shorter rest edges say nothing about stretch (as in the check)
MAX_INFL = 4         # bones per vertex the glTF exporter keeps
WELD = 0.002         # m: verts this close are merged in the heat copy (the scan's doubled seams)
BODY = ["root", "hips", "head", "skirt", "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hook",
        "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R"]
LIMBS = [["forearm.L", "hand.L"], ["forearm.R", "hook"], ["thigh.L", "shin.L", "foot.L"], ["thigh.R", "shin.R", "foot.R"],
         ["upper_arm.L"], ["upper_arm.R"]]
# limb pairs that never share a vertex (the upper arms may: they meet over the hump)
APART = {(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3), (4, 2), (4, 3), (5, 2), (5, 3), (0, 5), (1, 4)}
APART |= {(j, i) for i, j in APART}


def pose_matrices(arm):
    """The skinning matrices [bone, 4, 4] (rest to pose, armature space) of every sampled frame, with the action's name."""
    inv = [b.matrix_local.inverted() for b in arm.data.bones]
    out = []
    keep = arm.animation_data.action
    for act in bpy.data.actions:
        arm.animation_data.action = act
        a, b = (int(round(x)) for x in act.frame_range)
        for f in sorted(set(range(a, b + 1, STEP)) | {b}):
            bpy.context.scene.frame_set(f)
            bpy.context.view_layer.update()
            out.append((act.name, np.array([np.array(pb.matrix @ inv[i]) for i, pb in enumerate(arm.pose.bones)])))
    arm.animation_data.action = keep
    return out


class Skin:
    """One skinned mesh: rest vertices (armature space), dense weights [vertex, bone], the long-enough edges and their rest lengths."""

    def __init__(self, ob, arm):
        me = ob.data
        bones = arm.data.bones.keys()
        self.ob = ob
        self.groups = [(g, bones.index(g.name)) for g in ob.vertex_groups if g.name in bones]
        bone_of = {g.index: bi for g, bi in self.groups}
        n = len(me.vertices)
        co = np.empty(n * 3)
        me.vertices.foreach_get("co", co)
        m = np.array(arm.matrix_world.inverted() @ ob.matrix_world)
        self.rest = co.reshape(n, 3) @ m[:3, :3].T + m[:3, 3]
        self.w = np.zeros((n, len(bones)))
        for v in me.vertices:
            for ge in v.groups:
                if ge.group in bone_of:
                    self.w[v.index, bone_of[ge.group]] = ge.weight
        ed = np.empty(len(me.edges) * 2, dtype=np.int64)
        me.edges.foreach_get("vertices", ed)
        ed = ed.reshape(-1, 2)
        ln = np.linalg.norm(self.rest[ed[:, 0]] - self.rest[ed[:, 1]], axis=1)
        self.edges, self.len = ed[ln >= MIN_EDGE], ln[ln >= MIN_EDGE]

    def stretch(self, poses):
        """Worst ratio of each edge over all poses [edge], and each pose's worst ratio [pose]."""
        top = np.argsort(-self.w, axis=1)[:, :MAX_INFL]
        wt = np.take_along_axis(self.w, top, 1)
        wt = wt / np.maximum(wt.sum(1, keepdims=True), 1e-9)
        vh = np.c_[self.rest, np.ones(len(self.rest))]
        worst = np.zeros(len(self.edges))
        per = []
        for _, mats in poses:
            m = np.einsum("nk,nkij->nij", wt, mats[top])
            p = np.einsum("nij,nj->ni", m[:, :3], vh)
            g = np.maximum(1.0, np.linalg.norm(m[:, :3, :3], axis=1).min(1))   # growth on all three axes (the junk ball) is not stretch
            r = np.linalg.norm(p[self.edges[:, 0]] - p[self.edges[:, 1]], axis=1) / self.len / (0.5 * (g[self.edges[:, 0]] + g[self.edges[:, 1]]))
            worst = np.maximum(worst, r)
            per.append(r.max())
        return worst, per

    def store(self):
        """Write the weights back to the vertex groups."""
        for g, bi in self.groups:
            g.remove(range(len(self.w)))
            for v in np.nonzero(self.w[:, bi] > 1e-4)[0].tolist():
                g.add([v], float(self.w[v, bi]), "REPLACE")


def heat(arm, ob, s, body):
    """Bone-heat weights [vertex, bone] for the `body` verts: solved on a copy holding only them, welded, at rest; each vertex
    takes the inverse-distance mean of its four nearest copy verts."""
    names = arm.data.bones.keys()
    pos, deform = arm.data.pose_position, {b.name: b.use_deform for b in arm.data.bones}
    arm.data.pose_position = "REST"
    cp = ob.copy()
    cp.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(cp)
    cp.modifiers.clear()
    cp.vertex_groups.clear()
    cp.parent = None
    cp.matrix_world = ob.matrix_world
    bm = bmesh.new()
    bm.from_mesh(cp.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not body[v.index]], context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD)
    bm.to_mesh(cp.data)
    bm.free()
    for b in arm.data.bones:
        b.use_deform = b.name in BODY
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    cp.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    P = np.zeros((len(cp.data.vertices), len(names)))
    for v in cp.data.vertices:
        for g in v.groups:
            nm = cp.vertex_groups[g.group].name
            if nm in names:
                P[v.index, names.index(nm)] = g.weight
    m = np.array(arm.matrix_world.inverted() @ cp.matrix_world)
    pc = np.array([v.co[:] for v in cp.data.vertices]) @ m[:3, :3].T + m[:3, 3]
    kd = KDTree(len(pc))
    for i, c in enumerate(pc):
        kd.insert(c, i)
    kd.balance()
    H = np.zeros((len(s.w), len(names)))
    for vi in np.nonzero(body)[0]:
        nb = kd.find_n(s.rest[vi], 4)
        ww = np.array([1 / max(d, 1e-4) for _, _, d in nb])
        H[vi] = (ww[:, None] * P[[i for _, i, _ in nb]]).sum(0) / ww.sum()
    bpy.data.meshes.remove(cp.data)
    arm.data.pose_position = pos
    for b in arm.data.bones:
        b.use_deform = deform[b.name]
    return H


def limb_of(names):
    """[bone] -> its LIMBS index, -1 for the trunk."""
    grp = np.full(len(names), -1)
    for i, L in enumerate(LIMBS):
        for b in L:
            grp[names.index(b)] = i
    return grp


def keep_apart(w, grp):
    """Zeroes every weight a vertex has on a limb APART from its own main bone's limb."""
    g = grp[np.argmax(w, 1)]
    for i, j in APART:
        w[np.ix_(g == i, grp == j)] = 0
    return w / np.maximum(w.sum(1, keepdims=True), 1e-9)


def rip(ob, grp, w, names):
    """Splits the mesh along the edges between faces of two APART limbs (a face belongs to its verts' most common limb).
    Each split vertex's weights become its side's: the mean of its neighbours there. Returns the number of edges split."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    vg = grp[np.argmax(w, 1)]
    fg = {}
    for f in bm.faces:
        gs = [int(vg[v.index]) for v in f.verts]
        fg[f.index] = max(set(gs), key=gs.count)
    seam = [e for e in bm.edges if len(e.link_faces) == 2 and (fg[e.link_faces[0].index], fg[e.link_faces[1].index]) in APART]
    if seam:
        bmesh.ops.split_edges(bm, edges=seam)
    dl = bm.verts.layers.deform.verify()
    gl = {g.index: int(grp[names.index(g.name)]) if g.name in names else -1 for g in ob.vertex_groups}

    def limb(v):
        d = v[dl]
        return gl.get(max(d.keys(), key=lambda k: d[k]), -1) if len(d) else -1
    for v in bm.verts:
        sides = {fg[f.index] for f in v.link_faces}
        mine = limb(v)
        if len(sides) != 1 or mine in sides or (mine, next(iter(sides))) not in APART:
            continue
        side = next(iter(sides))       # this copy sits on faces of another limb: take that limb's weights from its neighbours
        nb = [o for e in v.link_edges for o in [e.other_vert(v)] if limb(o) == side]
        acc = {}
        for o in nb:
            for k, x in o[dl].items():
                acc[k] = acc.get(k, 0.0) + x / len(nb)
        if acc:
            v[dl].clear()
            for k, x in acc.items():
                v[dl][k] = x
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return len(seam)


def measure(arm, ob, poses, tag):
    """Prints the edges over 1.3 and the worst stretch per action. Returns the worst."""
    s = Skin(ob, arm)
    acts, allw = {}, np.zeros(len(s.edges))
    for n, m in poses:
        w1, _ = s.stretch([(n, m)])
        allw = np.maximum(allw, w1)
        acts[n] = max(acts.get(n, 0), w1.max())
    print("skin %s %s: edges over 1.3: %d, over 2: %d, worst %.2f" % (ob.name, tag, (allw > 1.3).sum(), (allw > 2).sum(), allw.max()))
    print("skin %s %s per clip: %s" % (ob.name, tag, " ".join("%s=%.2f" % kv for kv in sorted(acts.items(), key=lambda x: -x[1]))), flush=True)
    return allw.max()


def reweigh(arm, ob):
    """Heat weights on the body, limbs kept apart, welds ripped. Returns the worst stretch left."""
    poses = pose_matrices(arm)
    names = arm.data.bones.keys()
    measure(arm, ob, poses, "before")
    s = Skin(ob, arm)
    body = np.isin(np.argmax(s.w, 1), [names.index(b) for b in BODY])
    H = heat(arm, ob, s, body)
    got = body & (H.sum(1) > 1e-6)
    print("skin %s: heat weights on %d of %d body verts" % (ob.name, got.sum(), body.sum()))
    s.w[got] = H[got] / H[got].sum(1, keepdims=True)
    grp = limb_of(names)
    s.w = keep_apart(s.w, grp)
    top = np.argsort(-s.w, axis=1)[:, MAX_INFL:]
    np.put_along_axis(s.w, top, 0.0, axis=1)
    s.w /= np.maximum(s.w.sum(1, keepdims=True), 1e-9)
    s.store()
    print("skin %s: ripped %d weld edges" % (ob.name, rip(ob, grp, s.w, names)))
    return measure(arm, ob, poses, "after")
