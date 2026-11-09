"""A Boki body from a Meshy model of the owner's sheet instead of primitives (docs/art/kin/RIGGED_BOKI.md).

The raw model (glb.glb, tex0_base_color.png) stays in ~/meshy/<dir>, never in git. It is turned into game axes
(facing -Z, feet on the ground, `height` tall), decimated to the budget for the game mesh, and kept whole for the
surface questions (the face, the occlusion) and for the paint, which samples Meshy's own texture. The species'
primitives stay a proxy: the skin weights read them."""
import os

import numpy as np

from boki_sdf import Shape

TEX_PX = 4096          # Meshy's texture is read at this size for the paint


class Meshy:
    """The Meshy model in game axes: the full surface (a BVH), its texture, and a decimated copy for the game."""
    _loaded = {}

    @classmethod
    def get(cls, folder, height):
        key = (folder, height)
        if key not in cls._loaded:
            cls._loaded[key] = cls(os.path.expanduser(folder), height)
        return cls._loaded[key]

    def __init__(self, folder, height):
        import bpy
        from mathutils.bvhtree import BVHTree
        glb = os.path.join(folder, "glb.glb")
        if not os.path.exists(glb):
            raise SystemExit("meshy_body: the raw Meshy model is not at %s (see docs/art/kin/RIGGED_BOKI.md)" % glb)
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
        nt = len(me.loop_triangles)
        tv = np.zeros(nt * 3, dtype=np.int32)
        me.loop_triangles.foreach_get("vertices", tv)
        tl = np.zeros(nt * 3, dtype=np.int32)
        me.loop_triangles.foreach_get("loops", tl)
        uv = np.zeros(len(me.loops) * 2)
        me.uv_layers.active.data.foreach_get("uv", uv)
        self.v, self.t = g, tv.reshape(-1, 3)
        self.tuv = uv.reshape(-1, 2)[tl.reshape(-1, 3)]
        self.bvh = BVHTree.FromPolygons(g.tolist(), self.t.tolist(), all_triangles=True)
        img = bpy.data.images.load(os.path.join(folder, "tex0_base_color.png"))
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

    def colour(self, p):
        """Meshy's texture at the surface point nearest each of p."""
        loc, _, idx = self.nearest(p)
        a, b, c = (self.v[self.t[idx, k]] for k in range(3))
        v0, v1, v2 = b - a, c - a, loc - a
        d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
        d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
        den = np.maximum(d00 * d11 - d01 * d01, 1e-18)
        bv = (d11 * d20 - d01 * d21) / den
        bw = (d00 * d21 - d01 * d20) / den
        uv = (self.tuv[idx] * np.stack([1 - bv - bw, bv, bw], -1)[..., None]).sum(1)
        x = np.clip((uv[:, 0] % 1.0) * (TEX_PX - 1), 0, TEX_PX - 1).astype(int)
        y = np.clip((uv[:, 1] % 1.0) * (TEX_PX - 1), 0, TEX_PX - 1).astype(int)
        return self.tex[y, x]

    def decimated(self, target):
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
        return v.reshape(-1, 3), t.reshape(-1, 3)


class MeshShape(Shape):
    """The proxy primitives (for the rig and the paint), but the surface is the Meshy one."""

    def __init__(self, prims, folder, height):
        super().__init__(prims)
        self.folder, self.height = folder, height

    def model(self):
        return Meshy.get(self.folder, self.height)

    def mesh(self, tris):
        return self.model().decimated(tris)

    def eval(self, p):
        q = np.asarray(p, float)
        loc, nor, _ = self.model().nearest(q)
        d = q.reshape(-1, 3) - loc
        sign = np.where((d * nor).sum(1) < 0, -1.0, 1.0)
        return (np.linalg.norm(d, axis=1) * sign).reshape(q.shape[:-1])

    def project(self, p, offset=0.0, steps=6):
        q = np.asarray(p, float)
        loc, nor, _ = self.model().nearest(q)
        return (loc + nor * offset).reshape(q.shape)

    def grad(self, p, e=0.0012):
        q = np.asarray(p, float)
        _, nor, _ = self.model().nearest(q)
        return nor.reshape(q.shape)
