"""A Boki body from a Meshy model of the owner's sheet (the raw files stay in ~/meshy/<id>/run1, never in git): the
model in game axes, its texture and smooth normals, a decimated copy for the game, the normal map that puts the
model's detail back on that copy, and MeshShape, which keeps a species' proxy primitives for the rig while its
surface questions go to the full Meshy surface. docs/art/kin/MESHY_BOKI_RECIPE.md is the recipe."""
import os

import numpy as np

from boki_sdf import Shape

TEX_PX = 4096
NORMAL_SMOOTH = 2        # rounds of neighbour averaging on the model's normals: Meshy's surface grain is not detail
FLAT = np.array([0.5, 0.5, 1.0])


def game_to_blender(n):
    return np.stack([n[..., 0], -n[..., 2], n[..., 1]], -1)


def smooth_normals(v, t, rounds):
    """Unit vertex normals of a triangle soup: seam twins share one, then `rounds` of neighbour averaging."""
    _, weld = np.unique(np.round(v * 2e5).astype(np.int64), axis=0, return_inverse=True)
    weld = weld.ravel()
    wt = weld[t]
    count = int(weld.max()) + 1

    def spread(per_corner):
        out = np.zeros((count, 3))
        for corner in range(3):
            for axis in range(3):
                out[:, axis] += np.bincount(wt[:, corner], per_corner[corner][:, axis], count)
        return out

    face = np.cross(v[t[:, 1]] - v[t[:, 0]], v[t[:, 2]] - v[t[:, 0]])
    n = spread([face, face, face])
    for _ in range(rounds):
        n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
        ring = n[wt].sum(1)
        n = spread([ring, ring, ring])
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    return n[weld]


class Meshy:
    """The Meshy model in game axes: the full surface (a BVH), its texture, and a decimated copy for the game."""
    _loaded = {}

    @classmethod
    def get(cls, src, height, sink=0.0):
        """The model in directory `src`, scaled to `height` game metres, then lowered by `sink` (feet that stand
        above a hanging tail); loaded once."""
        if src not in cls._loaded:
            cls._loaded[src] = cls(src, height, sink)
        return cls._loaded[src]

    def __init__(self, src, height, sink=0.0):
        import bpy
        from mathutils.bvhtree import BVHTree
        glb = os.path.join(src, "glb.glb")
        if not os.path.exists(glb):
            raise SystemExit("the raw Meshy model is not at %s (see docs/art/kin/MESHY_BOKI_RECIPE.md)" % glb)
        self.src, self.tag = src, "%d_%d" % (round(height * 1000), round(sink * 1000))
        before = {k: set(getattr(bpy.data, k)) for k in ("objects", "meshes", "materials", "images", "textures")}
        bpy.ops.import_scene.gltf(filepath=glb)
        o = next(o for o in bpy.data.objects if o.type == "MESH" and o not in before["objects"])
        me = o.data
        me.calc_loop_triangles()
        v = np.zeros(len(me.vertices) * 3)
        me.vertices.foreach_get("co", v)
        m = np.array(o.matrix_world)
        w = v.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]
        g = np.stack([-w[:, 0], w[:, 2], w[:, 1]], -1)     # game axes, facing -Z
        g[:, 1] -= g[:, 1].min()
        g *= height / g[:, 1].max()
        g[:, 0] -= (g[:, 0].max() + g[:, 0].min()) / 2
        g[:, 1] -= sink
        nt = len(me.loop_triangles)
        tv = np.zeros(nt * 3, dtype=np.int32)
        me.loop_triangles.foreach_get("vertices", tv)
        tl = np.zeros(nt * 3, dtype=np.int32)
        me.loop_triangles.foreach_get("loops", tl)
        uv = np.zeros(len(me.loops) * 2)
        me.uv_layers.active.data.foreach_get("uv", uv)
        self.v, self.t = g, tv.reshape(-1, 3)
        self.tuv = uv.reshape(-1, 2)[tl.reshape(-1, 3)]
        self.vn = smooth_normals(g, self.t, NORMAL_SMOOTH)
        self.bvh = BVHTree.FromPolygons(g.tolist(), self.t.tolist(), all_triangles=True)
        img = bpy.data.images.load(os.path.join(src, "tex0_base_color.png"))
        img.scale(TEX_PX, TEX_PX)
        px = np.zeros(TEX_PX * TEX_PX * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        self.tex = px.reshape(TEX_PX, TEX_PX, 4)[..., :3]
        for k, old in before.items():
            coll = getattr(bpy.data, k)
            for item in [i for i in coll if i not in old]:
                coll.remove(item)

    def nearest(self, p):
        """Closest surface points, their face normals and triangle ids."""
        loc = np.zeros((len(p), 3))
        nor = np.zeros((len(p), 3))
        idx = np.zeros(len(p), dtype=np.int64)
        f = self.bvh.find_nearest
        for i, q in enumerate(p.reshape(-1, 3).tolist()):
            hit = f(q)
            loc[i], nor[i], idx[i] = hit[0], hit[1], hit[2]
        return loc, nor, idx

    def hits(self, p):
        """Closest surface points as (triangle ids, barycentric weights)."""
        loc, _, idx = self.nearest(p)
        a, b, c = (self.v[self.t[idx, k]] for k in range(3))
        v0, v1, v2 = b - a, c - a, loc - a
        d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
        d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
        den = np.maximum(d00 * d11 - d01 * d01, 1e-18)
        bv = (d11 * d20 - d01 * d21) / den
        bw = (d00 * d21 - d01 * d20) / den
        return idx, np.stack([1 - bv - bw, bv, bw], -1)

    def colour(self, p, hit=None):
        idx, bary = hit or self.hits(p)
        uv = (self.tuv[idx] * bary[..., None]).sum(1)
        x = np.clip((uv[:, 0] % 1.0) * (TEX_PX - 1), 0, TEX_PX - 1).astype(int)
        y = np.clip((uv[:, 1] % 1.0) * (TEX_PX - 1), 0, TEX_PX - 1).astype(int)
        return self.tex[y, x]

    def normal(self, p, hit=None):
        """The model's smooth normal at the closest surface point."""
        idx, bary = hit or self.hits(p)
        n = (self.vn[self.t[idx]] * bary[..., None]).sum(1)
        return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)

    def decimated(self, target):
        """The game mesh: welded, collapsed to `target` triangles. Kept beside the raw model, as it takes minutes."""
        cache = os.path.join(self.src, "game_%d_%s.npz" % (target, self.tag))
        if os.path.exists(cache):
            got = np.load(cache)
            return got["v"], got["t"]
        import bmesh
        import bpy
        me = bpy.data.meshes.new("meshy_tmp")
        me.from_pydata(self.v.tolist(), [], self.t.tolist())
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new("meshy_tmp", me)
        bpy.context.scene.collection.objects.link(obj)
        bpy.context.view_layer.objects.active = obj
        mod = obj.modifiers.new("d", "DECIMATE")
        mod.ratio = min(1.0, target / max(len(me.polygons), 1))
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        v = np.zeros(len(me.vertices) * 3)
        me.vertices.foreach_get("co", v)
        t = np.zeros(len(me.polygons) * 3, dtype=np.int32)
        me.polygons.foreach_get("vertices", t)
        bpy.data.objects.remove(obj)
        bpy.data.meshes.remove(me)
        v, t = v.reshape(-1, 3), t.reshape(-1, 3)
        np.savez(cache, v=v, t=t)
        return v, t


class MeshShape(Shape):
    """The proxy primitives (for the rig and the paint), but the surface is the Meshy one (`model`)."""

    def __init__(self, prims, model):
        super().__init__(prims)
        self.model = model

    def mesh(self, tris):
        return self.model.decimated(tris)

    def eval(self, p):
        q = np.asarray(p, float)
        loc, nor, _ = self.model.nearest(q)
        d = q.reshape(-1, 3) - loc
        sign = np.where((d * nor).sum(1) < 0, -1.0, 1.0)
        return (np.linalg.norm(d, axis=1) * sign).reshape(q.shape[:-1])

    def project(self, p, offset=0.0, steps=6):
        q = np.asarray(p, float)
        loc, nor, _ = self.model.nearest(q)
        return (loc + nor * offset).reshape(q.shape)

    def grad(self, p, e=0.0012):
        q = np.asarray(p, float)
        _, nor, _ = self.model.nearest(q)
        return nor.reshape(q.shape)


def normal_texels(me, model, pos, tid, bary):
    """Tangent-space normals (0..1 RGB) of texels at game-axes `pos` on triangles `tid` of the unwrapped game mesh
    `me`: the Meshy model's normal there, in the frame the engine rebuilds from the exported tangents."""
    me.calc_tangents()
    count = len(me.loops)
    tan, nor, sign = np.zeros(count * 3), np.zeros(count * 3), np.zeros(count)
    me.loops.foreach_get("tangent", tan)
    me.loops.foreach_get("normal", nor)
    me.loops.foreach_get("bitangent_sign", sign)
    me.free_tangents()
    tan, nor = tan.reshape(-1, 3), nor.reshape(-1, 3)
    bit = np.cross(nor, tan) * sign[:, None]
    loops = tid[:, None] * 3 + np.arange(3)[None]
    basis = np.stack([(a[loops] * bary[..., None]).sum(1) for a in (tan, bit, nor)], -1)
    want = game_to_blender(model.normal(pos))
    ok = np.abs(np.linalg.det(basis)) > 1e-6
    out = np.tile(np.array([0.0, 0.0, 1.0]), (len(pos), 1))
    out[ok] = np.linalg.solve(basis[ok], want[ok][..., None])[..., 0]
    out[out[:, 2] < 0.05] = (0.0, 0.0, 1.0)      # the model's far side (a thin part): leave the game mesh's own
    out /= np.linalg.norm(out, axis=1, keepdims=True)
    return out * 0.5 + 0.5
