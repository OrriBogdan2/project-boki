"""Skin-weight relax (ART-1): no clip may stretch a triangle edge past LIMIT times its rest length.
Evaluates linear-blend skinning in numpy for every action of the armature (the same maths as the game's skin), finds the
edges that stretch past LIMIT, and blends the weights of their vertices toward their neighbours'. Edges that weights alone cannot
save (a hook that leaves the wrist, a crouch that pulls the belly apart) are then cut: their triangles go, each hole is closed again
with a flat cap on its own side (cut()), and the edges the caps add are checked the same way. Compression is not stretch.
Use: skin_relax.relax(arm) from a clips script, before the export. Blender only (bpy, numpy)."""
import bmesh
import bpy
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
        s = Skin(s.ob, arm)
        print("relax %s: cut round %d: %d triangles out" % (s.ob.name, rnd + 1, count), flush=True)
    return s


def relax(arm):
    """Relaxes every mesh skinned to `arm`; prints the worst stretch per action before and after. Returns the edges left over."""
    poses = pose_matrices(arm)
    skins = [Skin(o, arm) for o in bpy.data.objects if o.type == "MESH" and any(m.type == "ARMATURE" and m.object == arm for m in o.modifiers)]
    left = 0
    for s in skins:
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
        print("relax %s: edges over 1.3: %d, over 2: %d, over 5: %d" % (s.ob.name, (before > 1.3).sum(), (before > 2).sum(), (before > 5).sum()))
        print("relax %-14s verts %5d edges over %.2f: %d -> %d after %d passes, worst %.2f -> %.2f"
              % (s.ob.name, len(s.w), LIMIT, bad0, int((before > LIMIT).sum()), it, first, max(per)), flush=True)
        s.store()
        s = cut(s, poses, arm)
        before, per = s.stretch(poses)
        left += int((before > LIMIT).sum())
        print("relax %s after cuts: edges over %.2f: %d, worst %.2f" % (s.ob.name, LIMIT, (before > LIMIT).sum(), max(per)), flush=True)
    return left
