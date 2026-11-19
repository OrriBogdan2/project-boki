"""Skin-weight relax (ART-1): no clip may stretch a triangle edge past LIMIT times its rest length.
Evaluates linear-blend skinning in numpy for every action of the armature (the same maths as the game's skin), finds the
edges that stretch past LIMIT, and blends the weights of their vertices toward their neighbours'. Edges that weights alone cannot
save (a hook that leaves the wrist, a crouch that pulls the belly apart) are then cut: their triangles go, each hole is closed again
with a flat cap on its own side (cut()), and the edges the caps add are checked the same way. Compression is not stretch.
Use: skin_relax.relax(arm) from a clips script, before the export (Blender: bpy, numpy). A built .glb with no
bake to re-run is relaxed in place by tools/art1/glb_relax.py, which drives Skin and settle() with numpy alone."""
import numpy as np

LIMIT = 1.22         # x rest length: the target, under the game's 1.3 check (tools/stretch_check.gd)
BLEND = 0.6          # how far a bad vertex's weights move toward its neighbours' per pass
CUT_LIMIT = 1.3      # the cut takes the edges still over this after the weights are done
MAX_ITER = 60
RINGS = 1            # rings of vertices around the bad ones that relax with them (the band the stretch spreads over widens)
STEP = 3             # frames between samples of a clip (the last frame is always sampled)
MIN_EDGE = 0.008     # m: shorter rest edges say nothing about stretch (as in the check)
CUTS = 3             # rounds of cut and cap; the last only cuts
HOLE_SIDES = 400     # biggest hole (edges round it) that is capped
MAX_INFL = 4         # bones per vertex the glTF exporter keeps
SOLVE_TARGET = 1.15  # x rest length solve() pulls the edges under: room below LIMIT for the poses it did not look at
SOLVE_POSES = 64     # poses a round of solve() looks at: each clip's worst, then the worst of the rest
SOLVE_ROUNDS = (4, 4)  # rounds with the neighbours' bones open to a vertex, then rounds on the MAX_INFL it keeps
SOLVE_STEPS = 60     # steps a round
SOLVE_RATE = 0.02    # weight a step may move
SOLVE_HOLD = 2.0     # pull back to the weights it started from (per unit of weight moved)


def pose_matrices(arm):
    """The skinning matrices [bone, 4, 4] (rest to pose, armature space) of every sampled frame, with the action's name."""
    import bpy
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

    def __init__(self, rest, w, edges, ob=None, groups=()):
        self.rest, self.w, self.ob, self.groups = rest, w, ob, groups
        ln = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
        self.edges, self.len = edges[ln >= MIN_EDGE], ln[ln >= MIN_EDGE]

    @classmethod
    def of_object(cls, ob, arm):
        """The Skin of a Blender mesh object on its armature."""
        me = ob.data
        bones = arm.data.bones.keys()
        groups = [(g, bones.index(g.name)) for g in ob.vertex_groups if g.name in bones]
        bone_of = {g.index: bi for g, bi in groups}
        n = len(me.vertices)
        co = np.empty(n * 3)
        me.vertices.foreach_get("co", co)
        m = np.array(arm.matrix_world.inverted() @ ob.matrix_world)
        w = np.zeros((n, len(bones)))
        for v in me.vertices:
            for ge in v.groups:
                if ge.group in bone_of:
                    w[v.index, bone_of[ge.group]] = ge.weight
        ed = np.empty(len(me.edges) * 2, dtype=np.int64)
        me.edges.foreach_get("vertices", ed)
        return cls(co.reshape(n, 3) @ m[:3, :3].T + m[:3, 3], w, ed.reshape(-1, 2), ob, groups)

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

    def relax_once(self, bad_edges):
        """Blend the weights of every vertex on the bad edges toward the mean of their neighbours."""
        n = len(self.w)
        acc, cnt = np.zeros_like(self.w), np.zeros(n)
        for a, b in ((0, 1), (1, 0)):
            np.add.at(acc, self.edges[:, a], self.w[self.edges[:, b]])
            np.add.at(cnt, self.edges[:, a], 1)
        pick = np.unique(self.edges[bad_edges])
        if RINGS:
            near = np.zeros(n, bool)
            near[pick] = True
            for _ in range(RINGS):
                hit = near[self.edges[:, 0]] | near[self.edges[:, 1]]
                near[self.edges[hit].ravel()] = True
            pick = np.nonzero(near)[0]
        mean = acc[pick] / np.maximum(cnt[pick], 1)[:, None]
        w = self.w[pick] * (1 - BLEND) + mean * BLEND
        top = np.argsort(-w, axis=1)[:, MAX_INFL:]
        np.put_along_axis(w, top, 0.0, axis=1)
        self.w[pick] = w / np.maximum(w.sum(1, keepdims=True), 1e-9)

    def store(self):
        """Write the weights back to the vertex groups."""
        for g, bi in self.groups:
            g.remove(range(len(self.w)))
            for v in np.nonzero(self.w[:, bi] > 1e-4)[0].tolist():
                g.add([v], float(self.w[v, bi]), "REPLACE")


def cut(s, poses, arm):
    """Deletes the triangles on edges still over CUT_LIMIT and caps each hole (no new vertices: the weights stay as they are).
    Up to CUTS rounds; the last one only deletes. Returns the Skin of the cut mesh."""
    import bmesh
    for rnd in range(CUTS):
        worst, _ = s.stretch(poses)
        bad = {tuple(sorted(e)) for e in s.edges[worst > CUT_LIMIT].tolist()}
        if not bad:
            break
        bm = bmesh.new()
        bm.from_mesh(s.ob.data)
        bm.faces.ensure_lookup_table()
        gone = [f for f in bm.faces if any(tuple(sorted((e.verts[0].index, e.verts[1].index))) in bad for e in f.edges)]
        mat, count = gone[0].material_index, len(gone)
        bmesh.ops.delete(bm, geom=gone, context="FACES_ONLY")
        bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context="EDGES")
        if rnd < CUTS - 1:
            rim = [e for e in bm.edges if len(e.link_faces) == 1]
            new = bmesh.ops.holes_fill(bm, edges=rim, sides=HOLE_SIDES)["faces"]
            new = bmesh.ops.triangulate(bm, faces=new)["faces"]
            bmesh.ops.recalc_face_normals(bm, faces=new)
            for f in new:
                f.material_index = mat
        bm.to_mesh(s.ob.data)
        bm.free()
        s.ob.data.update()
        s = Skin.of_object(s.ob, arm)
        print("relax %s: cut round %d: %d triangles out" % (s.ob.name, rnd + 1, count), flush=True)
    return s


def settle(s, poses):
    """Relaxes one Skin's weights until no edge is over LIMIT in any pose, or MAX_ITER passes.
    Returns [edges over LIMIT before, after, passes, worst ratio before, after]."""
    before, per = s.stretch(poses)
    first, bad0 = max(per), int((before > LIMIT).sum())
    live = poses
    for it in range(MAX_ITER):
        if it % 8 == 0:        # every few passes, look at every pose again; in between, only at those that were over
            before, per = s.stretch(poses)
            live = [p for p, r in zip(poses, per) if r > LIMIT] or poses
        bad = before > LIMIT
        if not bad.any():
            if live is poses:
                break
            live = poses
            before, per = s.stretch(poses)
            continue
        s.relax_once(bad)
        before, per = s.stretch(live)
    before, per = s.stretch(poses)
    return [bad0, int((before > LIMIT).sum()), it, first, max(per)]


def solve_poses(poses, per):
    """Indices of the SOLVE_POSES poses to solve on: the worst of each clip, then the worst of the rest."""
    order = np.argsort(-np.asarray(per))
    seen = set()
    first = [i for i in order if not (poses[i][0] in seen or seen.add(poses[i][0]))]
    rest = [i for i in order if i not in set(first)]
    return (first + rest)[:SOLVE_POSES]


def solve_round(s, poses, open_, w0, state):
    """SOLVE_STEPS steps down the slope of sum((ratio - SOLVE_TARGET)^2) over the over-target edges of the picked poses.
    A vertex's place is linear in its weights, so the slope is exact; `open_` [vertex, bone] says which weights may be non-zero.
    `state` is [steps, mean slope, mean squared slope] of the rounds so far on the same `open_` (the step is Adam's)."""
    cols = np.nonzero(open_.any(0))[0]
    free = open_[:, cols]
    w, base = s.w[:, cols], w0[:, cols]
    vh = np.c_[s.rest, np.ones(len(s.rest))]
    under = np.stack([np.einsum("bij,vj->vbi", poses[i][1][cols, :3], vh) for i in solve_poses(poses, s.stretch(poses)[1])]).astype(np.float32)
    k, n = len(under), len(w)
    slot = ((np.arange(k)[:, None, None] * 3 + np.arange(3)) * n)       # [pose, 1, axis]: where a pose's axis starts in the flat sum
    a, b = (slot + s.edges[:, c][None, :, None] for c in (0, 1))
    for _ in range(SOLVE_STEPS):
        p = np.einsum("vb,kvbi->kvi", w.astype(np.float32), under)
        d = p[:, s.edges[:, 0]] - p[:, s.edges[:, 1]]
        ln = np.linalg.norm(d, axis=2)
        pull = (2 * np.maximum(0.0, ln / s.len - SOLVE_TARGET) / s.len / np.maximum(ln, 1e-9))[:, :, None] * d
        at = (np.bincount(a.ravel(), pull.ravel(), k * 3 * n) - np.bincount(b.ravel(), pull.ravel(), k * 3 * n)).reshape(k, 3, n)
        g = np.einsum("kiv,kvbi->vb", at.astype(np.float32), under) + SOLVE_HOLD * (w - base)
        g = np.where(free, g, 0.0)
        g -= np.where(free, g.sum(1, keepdims=True) / np.maximum(free.sum(1, keepdims=True), 1), 0.0)     # the weights of a vertex keep their sum
        state[0] += 1
        state[1] = 0.9 * state[1] + 0.1 * g
        state[2] = 0.999 * state[2] + 0.001 * g * g
        w = w - SOLVE_RATE * (state[1] / (1 - 0.9 ** state[0])) / (np.sqrt(state[2] / (1 - 0.999 ** state[0])) + 1e-6)
        w = np.where(free, np.maximum(w, 0.0), 0.0)
        w /= np.maximum(w.sum(1, keepdims=True), 1e-9)
    s.w[:] = 0.0
    s.w[:, cols] = w


def solve(s, poses, rounds=SOLVE_ROUNDS, say=None):
    """Moves one Skin's weights to where the clips stretch its edges least (settle() only blends neighbours, which leaves
    a bleed the neighbours share: an arm bone's share of hip skin). First with every bone of a vertex's neighbours open to
    it, then on the MAX_INFL heaviest it keeps. Growth on all three axes is not taken out here (stretch() does that).
    Returns [edges over LIMIT before, after, steps, worst ratio before, after]."""
    before, per = s.stretch(poses)
    w0 = s.w.copy()
    open_ = w0 > 1e-4
    grown = open_.copy()
    np.logical_or.at(grown, s.edges[:, 0], open_[s.edges[:, 1]])
    np.logical_or.at(grown, s.edges[:, 1], open_[s.edges[:, 0]])
    for phase, count in enumerate(rounds):
        if phase:
            np.put_along_axis(s.w, np.argsort(-s.w, axis=1)[:, MAX_INFL:], 0.0, axis=1)
            s.w /= np.maximum(s.w.sum(1, keepdims=True), 1e-9)
            grown = s.w > 1e-4
        state = [0, 0.0, 0.0]
        for r in range(count):
            solve_round(s, poses, grown, w0, state)
            if say:
                say("solve: phase %d round %d of %d" % (phase + 1, r + 1, count))
    after, per2 = s.stretch(poses)
    return [int((before > LIMIT).sum()), int((after > LIMIT).sum()), sum(rounds) * SOLVE_STEPS, max(per), max(per2)]


def relax(arm):
    """Relaxes every mesh skinned to `arm`; prints the worst stretch per action before and after. Returns the edges left over."""
    import bpy
    poses = pose_matrices(arm)
    skins = [Skin.of_object(o, arm) for o in bpy.data.objects
             if o.type == "MESH" and any(m.type == "ARMATURE" and m.object == arm for m in o.modifiers)]
    left = 0
    for s in skins:
        done = settle(s, poses)
        before, per = s.stretch(poses)
        print("relax %s: edges over 1.3: %d, over 2: %d, over 5: %d" % (s.ob.name, (before > 1.3).sum(), (before > 2).sum(), (before > 5).sum()))
        print("relax %-14s verts %5d edges over %.2f: %d -> %d after %d passes, worst %.2f -> %.2f"
              % (s.ob.name, len(s.w), LIMIT, *done), flush=True)
        s.store()
        s = cut(s, poses, arm)
        before, per = s.stretch(poses)
        left += int((before > LIMIT).sum())
        print("relax %s after cuts: edges over %.2f: %d, worst %.2f" % (s.ob.name, LIMIT, (before > LIMIT).sum(), max(per)), flush=True)
    return left
