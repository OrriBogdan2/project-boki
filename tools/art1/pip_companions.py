"""Meeko's companions (tender, art pip): the little sun and the shy raincloud of briefs/art-refs/pip_v2/meeko_v2_companions_sheet.jpg,
modelled in place of the lantern. Edits art/wardens/pip/pip.glb: takes the lantern's faces out of the body mesh, adds the sun (on
pauldron.L) and the cloud (on pauldron.R) skinned rigidly at her shoulders, moves the lantern's FX points (weapon_muzzle,
anchor_hang_lantern, anchor_lantern_top) onto the sun, and paints the 8 expression faces as one atlas (the game swaps cells:
content/rules/warden_anim/pip.json "mood", scripts/heroes/warden_mood.gd). The rig, clips and every other anchor are kept.
  blender -b --factory-startup --python tools/art1/pip_companions.py -- art/wardens/pip/pip.glb out.glb art/wardens/pip/pip_faces.png
Space: Blender's, facing +Y, her right hand +X (the sun floats on her left, -X), up +Z, metres at the class-neutral size."""
import math
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

SUN_C = Vector((-0.40, 0.04, 1.10))
CLOUD_C = Vector((0.40, 0.04, 1.06))
SUN_R = 0.105           # m: the body's radius; the rays reach 0.64 of it again
SUN_DEPTH = 0.62        # the body's thickness, x its width (the sheet's side view)
CLOUD_W = 0.36          # m wide; its depth is 0.46 of that
SUN_CELL = 0.115        # m: half the span of the sun's face decal (atlas units are x this)
CLOUD_CELL = 0.155
DECAL_LIFT = 0.0035     # m the face sits off the skin
CELL_PX = 512
COLS, ROWS = 4, 2       # atlas: row 0 the sun (happy, laugh, grumpy, sleep), row 1 the cloud (shy, happy, sleep, cry)
TRIS = {"sun": 480, "cloud": 620}

PLUM = (0.40, 0.08, 0.38)
PINK = (0.98, 0.52, 0.62)
MOUTH = (0.86, 0.22, 0.36)
BROW_SUN = (0.72, 0.45, 0.16)
BROW_CLOUD = (0.42, 0.45, 0.62)
TEAR = (0.55, 0.78, 0.98)


# ---------------------------------------------------------------------------------------------------------- faces
class Cell:
    """One atlas cell: x, y in [-1, 1] (y up), layers composited in order with a 1.2 px soft edge."""

    def __init__(self):
        c = (np.arange(CELL_PX) + 0.5) / CELL_PX * 2 - 1
        self.x, self.y = np.meshgrid(c, c)
        self.px = 2.0 / CELL_PX * 1.2
        self.rgb = np.zeros((CELL_PX, CELL_PX, 3))
        self.a = np.zeros((CELL_PX, CELL_PX))

    def lay(self, d, col, alpha=1.0):
        m = np.clip(0.5 - d / self.px, 0, 1) * alpha
        out = m + self.a * (1 - m)
        k = np.where(out > 1e-6, m / np.maximum(out, 1e-6), 0)[..., None]
        self.rgb = np.array(col) * k + self.rgb * (1 - k)
        self.a = out

    def ellipse(self, cx, cy, rx, ry, col, alpha=1.0):
        self.lay(np.hypot((self.x - cx) / rx, (self.y - cy) / ry) * min(rx, ry) - min(rx, ry), col, alpha)

    def stroke(self, pts, w, col):
        d = np.full(self.x.shape, 9.0)
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            px, py = self.x - ax, self.y - ay
            bax, bay = bx - ax, by - ay
            t = np.clip((px * bax + py * bay) / (bax * bax + bay * bay), 0, 1)
            d = np.minimum(d, np.hypot(px - bax * t, py - bay * t))
        self.lay(d - w / 2, col)

    def arc(self, cx, cy, r, a0, a1, w, col, n=24):
        t = np.linspace(a0, a1, n)
        self.stroke(list(zip(cx + r * np.cos(t), cy + r * np.sin(t))), w, col)


def eyes_open(c, y=0.06, hi=True, size=1.0):
    for s in (-1, 1):
        c.ellipse(0.40 * s, y, 0.075 * size, 0.105 * size, PLUM)
        if hi:
            c.ellipse(0.40 * s + 0.022 * size, y + 0.04 * size, 0.026 * size, 0.032 * size, (1, 1, 1))
            c.ellipse(0.40 * s - 0.018 * size, y - 0.04 * size, 0.012 * size, 0.014 * size, (1, 1, 1), 0.8)


def eyes_arc(c, up, y=0.06):
    for s in (-1, 1):
        c.arc(0.40 * s, y - (0.04 if up else -0.04), 0.085, 0.25 if up else math.pi + 0.25, math.pi - 0.25 if up else 2 * math.pi - 0.25, 0.034, PLUM)


def blush(c, y=-0.12):
    for s in (-1, 1):
        c.ellipse(0.56 * s, y, 0.115, 0.07, PINK, 0.8)


def brows(c, col, worried=True, y=0.27):
    for s in (-1, 1):
        inner, outer = (0.30, 0.52) if worried else (0.30, 0.52)
        yi, yo = (y + 0.045, y - 0.025) if worried else (y - 0.05, y + 0.04)
        c.stroke([(inner * s, yi), (outer * s, yo)], 0.03, col)


def mouth_open(c, y=-0.2, w=0.2, depth=0.22):
    top = np.full(c.x.shape, 0.0)
    inside = (c.y < y) & (c.y > y - depth * np.clip(1 - (c.x / w) ** 2, 0, 1)) & (abs(c.x) < w)
    d = np.where(inside, -0.01, 0.05)
    c.lay(d, MOUTH)
    c.lay(np.where(inside & (c.y < y - depth * 0.45 * np.clip(1 - (c.x / w) ** 2, 0, 1)), -0.01, 0.05), (1.0, 0.55, 0.62), 0.9)
    c.stroke([(-w, y), (w, y)], 0.024, PLUM)
    c.arc(0, y, w, math.pi, 2 * math.pi, 0.0, PLUM, 2)
    t = np.linspace(0, math.pi, 24)
    c.stroke(list(zip(w * np.cos(t), y - depth * np.sin(t))), 0.026, PLUM)


def mouth_o(c, y=-0.2):
    c.ellipse(0, y, 0.035, 0.05, MOUTH)
    c.ellipse(0, y, 0.035, 0.05, PLUM, 0.0)


def mouth_frown(c, y=-0.24):
    c.arc(0, y - 0.07, 0.13, 0.45, math.pi - 0.45, 0.032, PLUM)


def mouth_wavy(c, y=-0.17):
    x = np.linspace(-0.13, 0.13, 20)
    c.stroke(list(zip(x, y + 0.025 * np.sin(x / 0.13 * 3 * math.pi))), 0.026, PLUM)


def mouth_sad(c, y=-0.18):
    inside = (c.y > y - 0.2) & (c.y < y - 0.2 + 0.22 * np.clip(1 - (c.x / 0.17) ** 2, 0, 1)) & (abs(c.x) < 0.17)
    c.lay(np.where(inside, -0.01, 0.05), MOUTH)
    t = np.linspace(0, math.pi, 24)
    c.stroke(list(zip(0.17 * np.cos(t), y - 0.2 + 0.22 * np.sin(t))), 0.028, PLUM)


def tears(c):
    for s in (-1, 1):
        c.stroke([(0.40 * s, 0.0), (0.46 * s, -0.5)], 0.075, TEAR)
        c.ellipse(0.46 * s, -0.5, 0.05, 0.05, TEAR)


def face_cell(who, name):
    c = Cell()
    brow = BROW_SUN if who == "sun" else BROW_CLOUD
    if name == "happy" and who == "sun":
        blush(c); brows(c, brow); eyes_open(c); mouth_open(c)
    elif name == "laugh":
        blush(c); eyes_arc(c, True); mouth_open(c, w=0.24, depth=0.3)
    elif name == "grumpy":
        blush(c, -0.14); brows(c, brow, False, 0.22); eyes_open(c, 0.04, True, 0.85); mouth_frown(c)
    elif name == "sleep":
        blush(c); eyes_arc(c, False); mouth_o(c)
    elif name == "shy":
        blush(c); brows(c, brow); eyes_open(c); mouth_wavy(c)
    elif name == "happy":
        blush(c); eyes_arc(c, True); mouth_open(c)
    elif name == "cry":
        tears(c); blush(c); brows(c, brow); eyes_arc(c, False, 0.02); mouth_sad(c)
    return c


def build_atlas():
    names = [("sun", n) for n in ("happy", "laugh", "grumpy", "sleep")] + [("cloud", n) for n in ("shy", "happy", "sleep", "cry")]
    w, h = COLS * CELL_PX, ROWS * CELL_PX
    img = np.zeros((h, w, 4), dtype=np.float32)
    for i, (who, n) in enumerate(names):
        c = face_cell(who, n)
        col, row = i % COLS, i // COLS
        r0 = (ROWS - 1 - row) * CELL_PX      # (Blender's image rows run bottom up; row 0 of the atlas is on top)
        img[r0:r0 + CELL_PX, col * CELL_PX:(col + 1) * CELL_PX, :3] = c.rgb
        img[r0:r0 + CELL_PX, col * CELL_PX:(col + 1) * CELL_PX, 3] = c.a
    im = bpy.data.images.new("mood_faces", w, h, alpha=True)
    im.pixels.foreach_set(img.ravel())
    im.pack()
    return im


# ------------------------------------------------------------------------------------------------------ geometry
def new_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def blob(name, bm, voxel, smooth_n, tris):
    """The overlapping pieces in bm fused into one soft body: voxel remesh, smoothed, decimated, smooth-shaded."""
    ob = new_obj(name, bm)
    bpy.context.view_layer.objects.active = ob
    for md, kw in (("REMESH", dict(mode="VOXEL", voxel_size=voxel, use_smooth_shade=True)),
                   ("SMOOTH", dict(factor=0.6, iterations=smooth_n))):
        m = ob.modifiers.new("m", md)
        for k, v in kw.items():
            setattr(m, k, v)
        bpy.ops.object.modifier_apply(modifier=m.name)
    d = ob.modifiers.new("d", "DECIMATE")
    d.ratio = min(1.0, tris / 2.0 / max(1, len(ob.data.polygons)))
    bpy.ops.object.modifier_apply(modifier=d.name)
    t = ob.modifiers.new("t", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=t.name)
    ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))
    return ob


def ellipsoid(bm, c, r):
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=14, radius=1.0, matrix=Matrix.Translation(c) @ Matrix.Diagonal((r[0], r[1], r[2], 1)))


def sun_body():
    bm = bmesh.new()
    ellipsoid(bm, (0, 0, 0), (SUN_R, SUN_R * SUN_DEPTH, SUN_R))
    n = 10
    for k in range(n):
        a = math.tau * (k + 0.5) / n
        out = Vector((math.sin(a), 0, math.cos(a)))
        base = SUN_R * 0.82
        length = SUN_R * 0.64 + (SUN_R * 0.18 if k % 2 == 0 else 0)      # alternate long and short, as drawn
        m = Matrix.Translation(out * base) @ Matrix.Rotation(a, 4, "Y") @ Matrix.Diagonal((1, 0.72, 1, 1))
        bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=SUN_R * 0.3, radius2=SUN_R * 0.055, depth=length + SUN_R * 0.18, matrix=m @ Matrix.Translation((0, 0, (length + SUN_R * 0.18) / 2 - SUN_R * 0.1)))
    return blob("sun", bm, 0.0045, 8, TRIS["sun"])


CLOUD_LOBES = [(-0.03, 0.14, 0.28), (-0.30, -0.02, 0.20), (0.27, 0.0, 0.24), (-0.17, -0.18, 0.19), (0.05, -0.2, 0.2), (0.22, -0.17, 0.18),
               (-0.40, -0.1, 0.12)]
CLOUD_NUBS = [(-0.25, -0.30, 0.085), (0.19, -0.30, 0.085)]


def cloud_body():
    bm = bmesh.new()
    for x, z, r in CLOUD_LOBES:
        ellipsoid(bm, (x * CLOUD_W, 0, z * CLOUD_W), (r * CLOUD_W, r * CLOUD_W * 0.78, r * CLOUD_W))
    for x, z, r in CLOUD_NUBS:
        ellipsoid(bm, (x * CLOUD_W, CLOUD_W * 0.07, z * CLOUD_W), (r * CLOUD_W, r * CLOUD_W * 0.9, r * CLOUD_W * 1.05))
    return blob("cloud", bm, 0.0055, 6, TRIS["cloud"])


def drops():
    bm = bmesh.new()
    for x, z, r in ((-0.22, -0.52, 0.05), (0.02, -0.58, 0.062)):
        r *= CLOUD_W
        sub = bmesh.new()
        bmesh.ops.create_uvsphere(sub, u_segments=8, v_segments=5, radius=1.0)
        for v in sub.verts:
            if v.co.z > 0:
                k = 1 - 0.78 * v.co.z
                v.co.x *= k
                v.co.y *= k
                v.co.z *= 1.9
            v.co *= r
            v.co += Vector((x * CLOUD_W, CLOUD_W * 0.04, z * CLOUD_W))
        me = bpy.data.meshes.new("t")
        sub.to_mesh(me)
        sub.free()
        bm.from_mesh(me)
    ob = new_obj("drops", bm)
    ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))
    return ob


def face_patch(name, body, cell_half, centre):
    """A grid of quads on the body's front (rays cast from the front), lifted off the skin, UV 0..1 over the cell."""
    n = 6
    bvh = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    grid = {}
    for j in range(n + 1):
        for i in range(n + 1):
            x, z = centre.x + (i / n * 2 - 1) * cell_half, centre.z + (j / n * 2 - 1) * cell_half
            hit, nrm, _, _ = bvh.ray_cast(Vector((x, 1.0, z)), Vector((0, -1, 0)))
            if hit is not None:
                grid[i, j] = bm.verts.new(hit + nrm * DECAL_LIFT)
    for j in range(n):
        for i in range(n):
            ring = ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j))      # (clockwise from the front, +Y: x runs left on screen)
            q = [grid.get(k) for k in ring]
            if None in q:
                continue
            f = bm.faces.new(q)
            for lp, (a, b) in zip(f.loops, ring):
                lp[uv].uv = (1 - a / n, b / n)
    ob = new_obj(name, bm)
    ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))
    return ob


# ------------------------------------------------------------------------------------------------------- materials
def flat_mat(name, rgb, rough=0.35):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    return m


def face_mat(name, img):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.surface_render_method = "BLENDED"
    nt = m.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    b = nt.nodes["Principled BSDF"]
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], b.inputs["Alpha"])
    return m


# ------------------------------------------------------------------------------------------------------------ main
def drop_lantern(pip):
    """The lantern's faces (weighted to the hang chain) out of the body mesh; returns the triangles left."""
    me = pip.data
    grp = {g.index for g in pip.vertex_groups if g.name.startswith("spring_hanglantern")}
    lw = np.zeros(len(me.vertices))
    for v in me.vertices:
        lw[v.index] = sum(g.weight for g in v.groups if g.group in grp)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    gone = [f for f in bm.faces if np.mean([lw[v.index] for v in f.verts]) > 0.5]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    print("LANTERN faces removed", len(gone))


def move_anchor(arm, name, pos, bone):
    ob = bpy.data.objects[name]
    ob.parent_bone = bone
    ob.parent_type = "BONE"
    ob.matrix_parent_inverse = Matrix.Identity(4)
    bpy.context.view_layer.update()
    ob.matrix_world = Matrix.Translation(pos)


def main():
    src, dst, faces_png = sys.argv[sys.argv.index("--") + 1:][:3]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30      # (the clips are keyed at 30: import and export at the scene rate, or every clip loses frames)
    bpy.ops.import_scene.gltf(filepath=src)
    for act in bpy.data.actions:      # (the importer's range stops a key short: each clip keeps its last key)
        ks = [kp.co.x for fc in act.fcurves for kp in fc.keyframe_points]
        act.use_frame_range, act.frame_start, act.frame_end = True, round(min(ks)), round(max(ks))
    arm = bpy.data.objects["Armature"]
    pip = bpy.data.objects["Pip"]
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    n_old = len(pip.data.vertices)
    drop_lantern(pip)
    n_old = len(pip.data.vertices)
    img = build_atlas()
    img.filepath_raw, img.file_format = faces_png, "PNG"
    img.save()
    mats = {"sun": flat_mat("cloth-sun", (1.0, 0.70, 0.14)), "cloud": flat_mat("skin-cloud", (0.93, 0.93, 1.0), 0.5),
            "drop": flat_mat("ice-drop", (0.60, 0.78, 0.98), 0.15),
            "fsun": face_mat("eyes-mood_sun", img), "fcloud": face_mat("eyes-mood_cloud", img)}
    sun, cloud, dr = sun_body(), cloud_body(), drops()
    parts = []
    for ob, mk, bone, c in ((sun, "sun", "pauldron.L", SUN_C), (cloud, "cloud", "pauldron.R", CLOUD_C), (dr, "drop", "pauldron.R", CLOUD_C)):
        ob.data.materials.append(mats[mk])
        ob.data.transform(Matrix.Translation(c))
        parts.append((ob, bone))
    bpy.context.view_layer.update()
    for name, body, cell, c, mk in (("face_sun", sun, SUN_CELL, SUN_C, "fsun"), ("face_cloud", cloud, CLOUD_CELL, CLOUD_C, "fcloud")):
        f = face_patch(name, body, cell, c)
        f.data.materials.append(mats[mk])
        parts.append((f, "pauldron.L" if body is sun else "pauldron.R"))
    tris = 0
    for ob, bone in parts:
        g = ob.vertex_groups.new(name=bone)
        g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
        tris += sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print("COMPANION tris", tris)
    bpy.ops.object.select_all(action="DESELECT")
    for ob, _ in parts:
        ob.select_set(True)
    pip.select_set(True)
    bpy.context.view_layer.objects.active = pip
    bpy.ops.object.join()
    ca = pip.data.color_attributes[0]
    for lp in pip.data.loops:
        if lp.vertex_index >= n_old:
            ca.data[lp.index].color = (1, 1, 1, 1)
    # the lantern's FX points ride the sun now
    move_anchor(arm, "anchor_lantern_top", SUN_C + Vector((0, 0, SUN_R * 1.5)), "pauldron.L")
    move_anchor(arm, "anchor_hang_lantern", SUN_C, "pauldron.L")
    move_anchor(arm, "weapon_muzzle", SUN_C + Vector((0, 0, -SUN_R * 0.3)), "pauldron.L")
    arm.data.pose_position = "POSE"
    me = pip.data
    print("TRIS", sum(len(p.vertices) - 2 for p in me.polygons))
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type in ("ARMATURE", "MESH", "EMPTY"):
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                              export_image_format="AUTO", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                              export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False)
    print("exported", dst)


main()
