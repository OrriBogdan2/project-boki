"""Builds a rigged Boki: shapes to mesh, paint, face, rig, clips, .glb and .blend. docs/art/kin/RIGGED_BOKI.md.

  blender -b --factory-startup --python tools/boki/build_boki.py -- [--preview=<prefix>] [--no-export]
"""
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import boki_sdf
import face
import importlib

import boki_rig

REPO = os.path.dirname(os.path.dirname(HERE))
SPECIES = "cindle"
# id -> (shapes module, paint module, skeleton and clips module)
SPECS = {"cindle": ("vespyx", "vespyx_paint", "vespyx_anim"), "puddlet": ("prismander", "prismander", "prismander_anim"),
         "burrlet": ("mycroll", "mycroll", "mycroll_anim"),
         "glintmole": ("glintmole", "glintmole", "glintmole_anim"),
         "rimeshrew": ("rimeshrew", "rimeshrew", "rimeshrew_anim"),
         "zephyrak": ("zephyrak", "zephyrak", "zephyrak_anim"),
         "pebbit": ("gravadillo", "gravadillo", "gravadillo_anim"),
         "cairnback": ("cairnback", "cairnback", "cairnback_anim"),
         "wisplet": ("lunowl", "lunowl", "lunowl_anim"),
         "gloamshell": ("gloamshell", "gloamshell", "gloamshell_anim"),
         "selenfin": ("selenfin", "selenfin", "selenfin_anim"),
         "zapple": ("echolop", "echolop", "echolop_anim"),
         "hivara": ("hivara", "hivara", "hivara_anim"),
         "glomwort": ("glomwort", "glomwort", "glomwort_anim"),
         "kestrike": ("kestrike", "kestrike", "kestrike_anim"),
         "kindlewren": ("kindlewren", "kindlewren", "kindlewren_anim"),
         "lodestick": ("lodestick", "lodestick", "lodestick_anim")}
creature = paint = anim = None
ATLAS_PX = 2048
GROWN_K = 0.22         # most Boki show one or two grown parts; all of them hide in every tri count
SCALE = 0.95             # the whole Boki, so its body sits near the other species' 0.8 m frame


def use_species(species):
    global SPECIES, creature, paint, anim, SCALE
    SPECIES = species
    creature, paint, anim = [importlib.import_module(m) for m in SPECS[species]]
    SCALE = getattr(creature, "SCALE", SCALE)


def bl(p):
    """Game axes to Blender's (glTF export turns them back)."""
    return np.stack([p[..., 0], -p[..., 2], p[..., 1]], -1) * SCALE


def decimated(verts, quads, target):
    me = bpy.data.meshes.new("tmp")
    me.from_pydata(verts.tolist(), [], quads.tolist())
    obj = bpy.data.objects.new("tmp", me)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("d", "DECIMATE")
    mod.ratio = min(1.0, target / (len(quads) * 2.0))
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


def vertex_normals(v, t):
    fn = np.cross(v[t[:, 1]] - v[t[:, 0]], v[t[:, 2]] - v[t[:, 0]])
    n = np.zeros_like(v)
    for i in range(3):
        np.add.at(n, t[:, i], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)


class Piece:
    """One separately meshed part of the creature, in game axes."""

    def __init__(self, name, shape, v, t, slot, prop=False):
        self.name, self.shape, self.v, self.t, self.slot, self.prop = name, shape, v, t, slot, prop


def mesh_pieces():
    out = []
    for name, (shape, h, tris) in creature.parts().items():
        v, q = boki_sdf.mesh_shape(shape, h)
        v, t = decimated(v, q, tris)
        v = shape.project(v, steps=2)
        slot = 2 if name in getattr(creature, "LIT_PIECES", ()) else 1 if name in creature.GLOW_PIECES else 0
        out.append(Piece(name, shape, v, t, slot))
        print("piece", name, len(v), len(t))
    for name, (shape, h, tris) in creature.prop_parts().items():
        v, q = boki_sdf.mesh_shape(shape, h)
        v, t = decimated(v, q, tris)
        out.append(Piece(name, shape, v, t, 1 if name in creature.GLOW_PIECES else 0, prop=True))
    for pid, (_, _, look, tris, prims) in creature.grown_parts().items():
        shape = boki_sdf.Shape(prims)
        v, q = boki_sdf.mesh_shape(shape, 0.003)
        v, t = decimated(v, q, max(int(tris * GROWN_K), 12))
        pc = Piece("gp_" + pid, shape, v, t, 1 if look == "glow" else 0, prop=True)
        pc.look = look
        out.append(pc)
    return out


def join(pieces):
    vs, ts, ids, off = [], [], [], 0
    for i, pc in enumerate(pieces):
        vs.append(pc.v)
        ts.append(pc.t + off)
        ids.append(np.full(len(pc.v), i))
        off += len(pc.v)
    return np.concatenate(vs), np.concatenate(ts), np.concatenate(ids)


def uv_unwrap(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(52), island_margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    n = len(obj.data.loops)
    uv = np.zeros(n * 2)
    obj.data.uv_layers.active.data.foreach_get("uv", uv)
    return uv.reshape(-1, 2)


def rasterize(uv, tri_uv_idx, px):
    """Texels of every triangle: (ix, iy, tri index, barycentrics)."""
    xs, ys, tid, bary = [], [], [], []
    for i, tri in enumerate(tri_uv_idx):
        a, b, c = uv[tri] * px - 0.5
        lo = np.floor(np.minimum(np.minimum(a, b), c)).astype(int) - 1
        hi = np.ceil(np.maximum(np.maximum(a, b), c)).astype(int) + 1
        gx, gy = np.meshgrid(np.arange(max(lo[0], 0), min(hi[0] + 1, px)), np.arange(max(lo[1], 0), min(hi[1] + 1, px)))
        px_, py_ = gx.ravel(), gy.ravel()
        v0, v1 = b - a, c - a
        d = v0[0] * v1[1] - v0[1] * v1[0]
        if abs(d) < 1e-9:
            continue
        w1 = ((px_ - a[0]) * v1[1] - (py_ - a[1]) * v1[0]) / d
        w2 = (v0[0] * (py_ - a[1]) - v0[1] * (px_ - a[0])) / d
        w0 = 1 - w1 - w2
        m = (w0 > -0.04) & (w1 > -0.04) & (w2 > -0.04)
        xs.append(px_[m])
        ys.append(py_[m])
        tid.append(np.full(m.sum(), i))
        bary.append(np.stack([w0[m], w1[m], w2[m]], -1))
    return np.concatenate(xs), np.concatenate(ys), np.concatenate(tid), np.concatenate(bary)


def dilate(img, mask, rounds=28):
    img, mask = img.copy(), mask.copy()
    for _ in range(rounds):
        got = np.zeros(img.shape)
        cnt = np.zeros(mask.shape)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            m = np.roll(np.roll(mask, dx, 0), dy, 1)
            got += np.roll(np.roll(img, dx, 0), dy, 1) * m[..., None]
            cnt += m
        fill = (~mask) & (cnt > 0)
        img[fill] = got[fill] / cnt[fill][..., None]
        mask = mask | fill
    img[~mask] = img[mask].mean(0)     # the deep mips of the far camera average into these gaps
    return img


def occlusion(pieces, p, n):
    """A soft crevice term from all the shapes: how far the surface can see along its normal."""
    def scene(q):
        d = None
        for pc in pieces:
            if pc.prop:
                continue
            e = pc.shape.eval(q)
            d = e if d is None else np.minimum(d, e)
        return d

    ao = np.zeros(len(p))
    total = 0.0
    for s, w in ((0.012, 1.0), (0.03, 0.8), (0.06, 0.6), (0.11, 0.4)):
        ao += w * np.clip(scene(p + n * s) / s, 0, 1)
        total += w
    return ao / total


def paint_texels(pieces, piece_id, p, n, vao):
    col = np.ones((len(p), 3)) * 0.5
    body = next(pc for pc in pieces if pc.name == "body")
    prim = {pr.name: pr for pr in body.shape.prims}
    for i, pc in enumerate(pieces):
        m = piece_id == i
        if m.any():
            col[m] = paint.paint_piece(pc, p[m], n[m], prim)
    shadow = np.clip(vao, 0, 1)[:, None] ** 1.4
    # pale pieces in deep crevices (and thin ones, which shade themselves) went violet
    pale = np.isin(piece_id, [i for i, pc in enumerate(pieces) if pc.name in getattr(creature, "PALE_PIECES", ())])
    shadow[pale] = np.maximum(shadow[pale], 0.75)
    tint = np.array([0.60, 0.50, 0.72])
    return col * (tint + (1 - tint) * shadow)


def bake_atlas(pieces, verts, tris, piece_of, uv, px):
    nrm = vertex_normals(verts, tris)
    ao = occlusion(pieces, verts, nrm)
    tri_uv = np.arange(len(tris) * 3).reshape(-1, 3)
    xs, ys, tid, bary = rasterize(uv, tri_uv, px)
    tv = tris[tid]
    pos = (verts[tv] * bary[..., None]).sum(1)
    nor = (nrm[tv] * bary[..., None]).sum(1)
    nor /= np.maximum(np.linalg.norm(nor, axis=1, keepdims=True), 1e-9)
    vao = (ao[tv] * bary).sum(1)
    col = paint_texels(pieces, piece_of[tv[:, 0]], pos, nor, vao)
    img = np.zeros((px, px, 3))
    mask = np.zeros((px, px), dtype=bool)
    img[ys, xs] = col
    mask[ys, xs] = True
    return dilate(img, mask)


def image_from(name, rgb, path=None):
    h, w = rgb.shape[:2]
    im = bpy.data.images.new(name, w, h, alpha=False)
    data = np.concatenate([rgb, np.ones((h, w, 1))], -1)
    im.pixels.foreach_set(data.ravel().astype(np.float32))
    if path:
        im.filepath_raw = path
        im.file_format = "PNG"
        im.save()
    im.pack()
    return im


def material(name, image=None, color=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.7
    if image:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = image
        m.node_tree.links.new(t.outputs[0], b.inputs[0])
    if color:
        b.inputs[0].default_value = color
    return m


def mesh_object(name, verts, tris, uvs=None, slots=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata(bl(verts).tolist(), [], tris.tolist())
    me.update()
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    if uvs is not None:
        lay = me.uv_layers.new(name="UV")
        lay.data.foreach_set("uv", uvs.ravel())
    if slots is not None:
        me.polygons.foreach_set("material_index", slots.tolist())
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def eye_tex(px=256):
    y, x = np.mgrid[0:px, 0:px]
    q = np.stack([(x + 0.5) / px * 2 - 1, (y + 0.5) / px * 2 - 1], -1)
    r = np.hypot(q[..., 0], q[..., 1] * 1.04)
    white = np.array([1.0, 1.0, 1.0])
    iris = paint.IRIS
    deep = getattr(paint, "IRIS_DEEP", paint.hexc("2f5a12"))
    t = np.clip((r - 0.2) / 0.62, 0, 1)[..., None]
    col = deep * (1 - t) + iris * t
    col = col * (r < 0.82)[..., None] + paint.INK * (r >= 0.82)[..., None]
    col = np.where((r < 0.9)[..., None], col, white)
    col = np.where((r < 0.42)[..., None], paint.hexc("102408"), col)
    hl = np.hypot(q[..., 0] + 0.3, q[..., 1] - 0.36) < 0.25
    h2 = np.hypot(q[..., 0] - 0.32, q[..., 1] + 0.3) < 0.1
    col[hl | h2] = white
    return col


def rest_colors(obj, verts, pieces, piece_of):
    """Vertex colour: the rest position (so coat marks stay on the fur however it moves), alpha 1 on fur only."""
    fur = np.array([pc.name == "body" for pc in pieces])[piece_of]
    p = (verts + np.array([0.6, 0.0, 0.7])) / np.array([1.2, 1.2, 1.4])
    rgba = np.concatenate([np.clip(p, 0, 1), fur[:, None].astype(float)], -1)
    attr = obj.data.color_attributes.new("rest", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", rgba.ravel())


def build_geometry():
    face.FACE.update(creature.FACE)
    pieces = mesh_pieces()
    verts, tris, piece_of = join(pieces)
    obj = mesh_object("Body", verts, tris)
    uv = uv_unwrap(obj)
    print("uv done", time.time())
    atlas = bake_atlas(pieces, verts, tris, piece_of, uv, ATLAS_PX)
    img = image_from(SPECIES + "_atlas", atlas)
    obj.data.materials.append(material("boki_coat", img))
    obj.data.materials.append(material("boki_glow", color=(0.45, 1.0, 0.1, 1.0)))
    obj.data.materials.append(material("boki_lit", img))
    rest_colors(obj, verts, pieces, piece_of)
    slots = np.array([pieces[piece_of[t[0]]].slot for t in tris])
    obj.data.polygons.foreach_set("material_index", slots.tolist())
    # the face
    body = next(pc for pc in pieces if pc.name == "body")
    fv, fuv, ft, keys = face.build_face(body.shape, creature.EYE_C, creature.EYE_R, creature.eye_frame)
    ev, euv, et = face.eye_dome(creature.EYE_C, creature.EYE_R, creature.eye_frame)
    n = len(fv)
    all_v = np.concatenate([fv, ev])
    all_uv = np.concatenate([fuv, euv])
    all_t = np.concatenate([ft, et + n])
    uv_flat = all_uv[all_t].reshape(-1, 2)
    fslots = np.concatenate([np.zeros(len(ft), dtype=int), np.ones(len(et), dtype=int)])
    fobj = mesh_object("Face", all_v, all_t, uv_flat, fslots)
    fimg = image_from(SPECIES + "_face", face.face_atlas(paint))
    eimg = image_from(SPECIES + "_eye", eye_tex())
    fobj.data.materials.append(material("boki_face", fimg))
    fobj.data.materials.append(material("boki_eye", eimg))
    fobj.shape_key_add(name="Basis", from_mix=False)
    for k, arr in keys.items():
        sk = fobj.shape_key_add(name=k, from_mix=False)
        co = np.concatenate([arr, ev])
        sk.data.foreach_set("co", bl(co).ravel())
    return pieces, obj, fobj, piece_of, keys, n


def preview(prefix):
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.samples = 16
    s.cycles.device = "CPU"
    s.render.threads = 6
    s.render.resolution_x = s.render.resolution_y = 620
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.82, 0.82, 1)
    s.world = w
    s.view_settings.view_transform = "Standard"
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
    s.collection.objects.link(cam)
    s.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.3
    tgt = bpy.data.objects.new("t", None)
    s.collection.objects.link(tgt)
    tgt.location = (0, 0, 0.42)
    con = cam.constraints.new("TRACK_TO")
    con.target = tgt
    con.track_axis = "TRACK_NEGATIVE_Z"
    con.up_axis = "UP_Y"
    for k, p in {"f": (0, 3, 0.5), "q": (1.6, 2.4, 0.8), "s": (3, 0, 0.45), "b": (-1.2, -2.7, 1.0)}.items():
        cam.location = p
        s.render.filepath = "%s_%s.png" % (prefix, k)
        bpy.ops.render.render(write_still=True)
    # a close look at the face with each expression
    cam.data.ortho_scale = 0.62
    tgt.location = (0, 0.1, 0.44)
    cam.location = (0.25, 3, 0.5)
    fobj = bpy.data.objects["Face"]
    for k in [b.name for b in fobj.data.shape_keys.key_blocks[1:]]:
        for b in fobj.data.shape_keys.key_blocks[1:]:
            b.value = 1.0 if b.name == k else 0.0
        s.render.resolution_x = s.render.resolution_y = 300
        s.render.filepath = "%s_x_%s.png" % (prefix, k)
        bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    t0 = time.time()
    species = next((a[10:] for a in argv if a.startswith("--species=")), "cindle")
    use_species(species)
    boki_rig.HIDE_AT.clear()
    boki_rig.HIDE_AT.update(anim.HIDE_AT)
    pieces, body_obj, face_obj, piece_of, _, face_n = build_geometry()
    print("geometry", time.time() - t0)
    arm = boki_rig.armature(anim.BONES, bl)
    boki_rig.skin(body_obj, face_obj, arm, pieces, piece_of, bl)
    boki_rig.make_clips(arm, anim.CLIPS)
    print("rig", time.time() - t0)
    for a in argv:
        if a.startswith("--blend="):
            bpy.ops.wm.save_as_mainfile(filepath=a[8:], compress=True)
    if "--no-export" not in argv:
        boki_rig.export(os.path.join(REPO, "art/kin", SPECIES, SPECIES + ".glb"))
    for a in argv:
        if a.startswith("--preview="):
            preview(a[10:])


if __name__ == "__main__":
    main()
