"""A Hunter's held prop from its v95 master into the game .glb, as a separate mesh (weapons stay separate pieces).
v95_to_game.py ports the body and keeps the game's old prop (the faces riding `bone`); when the owner picked a new prop on
the master (Neve's spear A, 11-16: candy-cane shaft, faceted ice-heart head), this swaps it in after the port:
  - the master's prop object (`--prop`, a separate mesh in the master .glb) keeps its own mesh, UVs and paint, unreshaped;
  - it lies along the old prop's axis (rest pose), its head toward the old tip (`--tip` anchor), its grip (where the
    master's hand closes round it) on the old grip, scaled by body height (game / master) so it keeps the master's proportions;
  - it rides `bone` whole (weight 1), its material named `--mat` (the game's toon slot-tag), collapsed to `--prop-tris`;
  - the old prop's faces (`--old-mats`) go; the blade anchors (`--anchors`) move to the same share along the new head.
Blender only re-places and re-exports; no mesh is reshaped. Clips, rig and every other mesh are re-exported as imported.
Run: blender -b --factory-startup --python tools/art1/v95_prop_swap.py -- GAME.glb MASTER.glb OUT.glb
       --prop spear --bone hand.R --old-mats cloth-atlas,ice-atlas --tip weapon_muzzle
       --anchors anchor_blade_root,anchor_blade_mid --mat cloth-spear [--front -Y] [--out-dir +X]"""
import argparse
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

ap = argparse.ArgumentParser()
ap.add_argument("game")
ap.add_argument("master")
ap.add_argument("out")
ap.add_argument("--prop", required=True)
ap.add_argument("--bone", required=True)
ap.add_argument("--old-mats", required=True)
ap.add_argument("--tip", required=True)
ap.add_argument("--anchors", default="")
ap.add_argument("--mat", required=True)
ap.add_argument("--prop-tris", type=int, default=4000, help="the piece's triangle budget (collapse, UVs kept; body + prop under 80k)")
ap.add_argument("--front", default="-Y", help="the master's front (Meshy: -Y), laid on --out-dir in the game")
ap.add_argument("--out-dir", default="+X", help="game direction the prop's front faces (her right: +X)")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1 :])
AX = {"+X": (1, 0, 0), "-X": (-1, 0, 0), "+Y": (0, 1, 0), "-Y": (0, -1, 0), "+Z": (0, 0, 1), "-Z": (0, 0, -1)}


def world(ob, idx=None):
    mw = np.array(ob.matrix_world)
    co = np.array([v.co for v in ob.data.vertices]) if idx is None else np.array([ob.data.vertices[i].co for i in idx])
    return co @ mw[:3, :3].T + mw[:3, 3]


def axis(P):
    c = P.mean(0)
    d = np.linalg.svd(P - c)[2][0]
    t = (P - c) @ d
    return c, d, t.min(), t.max()


def grip_t(c, d, body_pts, r=0.04):
    """Where along the axis the hand closes round it: the median of the body points within r of the line."""
    rel = body_pts - c
    t = rel @ d
    near = np.linalg.norm(rel - np.outer(t, d), axis=1) < r
    return float(np.median(t[near])) if near.any() else None


def basis(d, f):
    f = f - d * (f @ d)
    f /= np.linalg.norm(f)
    return np.stack([d, f, np.cross(d, f)], 1)


bpy.ops.wm.read_factory_settings(use_empty=True)
# the master: its prop and its body
bpy.ops.import_scene.gltf(filepath=a.master)
m_objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
prop = next(o for o in m_objs if o.name.startswith(a.prop))
m_body = [o for o in m_objs if o is not prop]
for o in m_objs:
    o.name = "M_" + o.name
SP = world(prop)
MB = np.concatenate([world(o) for o in m_body])
mc, md, mt0, mt1 = axis(SP)
if md[2] < 0:       # (master prop stands upright: its head up)
    md = -md
    mt0, mt1 = -mt1, -mt0
m_grip = grip_t(mc, md, MB)
if m_grip is None:
    sys.exit("v95_prop_swap: no master hand near the prop")
m_h = MB[:, 2].max() - MB[:, 2].min()

# the game .glb (the port's output)
bpy.ops.import_scene.gltf(filepath=a.game)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
arm.data.pose_position = "REST"
bpy.context.view_layer.update()
body = next(o for o in bpy.context.scene.objects if o.type == "MESH" and not o.name.startswith("M_")
            and any(m and m.name.split(".")[0] in a.old_mats.split(",") for m in o.data.materials))
old_mats = {i for i, m in enumerate(body.data.materials) if m and m.name.split(".")[0] in a.old_mats.split(",")}
old_v = sorted({v for p in body.data.polygons if p.material_index in old_mats for v in p.vertices})
rest_v = sorted(set(range(len(body.data.vertices))) - set(old_v))
OP = world(body, old_v)
GB = world(body, rest_v)
oc, od, ot0, ot1 = axis(OP)
tip = bpy.data.objects[a.tip]
tip_w = np.array(tip.matrix_world.translation)
if (tip_w - oc) @ od < 0:
    od = -od
    ot0, ot1 = -ot1, -ot0
o_grip = grip_t(oc, od, GB)
if o_grip is None:
    hb = arm.data.bones[a.bone]
    o_grip = float((np.array(arm.matrix_world @ ((hb.head_local + hb.tail_local) / 2)) - oc) @ od)
g_h = GB[:, 2].max() - GB[:, 2].min()
s = g_h / m_h
R = basis(od, np.array(AX[a.out_dir], float)) @ basis(md, np.array(AX[a.front], float)).T
m_g = mc + md * m_grip
o_g = oc + od * o_grip
print("PROPSWAP master len %.3f grip %.2f | old len %.3f grip %.2f | body h master %.3f game %.3f s %.3f -> new len %.3f" % (
    mt1 - mt0, (m_grip - mt0) / (mt1 - mt0), ot1 - ot0, (o_grip - ot0) / (ot1 - ot0), m_h, g_h, s, s * (mt1 - mt0)), flush=True)

# the new piece: the master's mesh, re-placed (rigid: rotation, uniform scale, move)
new = prop.copy()
new.data = prop.data.copy()
bpy.context.scene.collection.objects.link(new)
P = (SP - m_g) @ R.T * s + o_g
new.matrix_world = Matrix.Identity(4)
inv = np.array(arm.matrix_world.inverted())
new.data.vertices.foreach_set("co", (P @ inv[:3, :3].T + inv[:3, 3]).ravel())
new.parent = arm
new.matrix_parent_inverse = Matrix.Identity(4)
new.matrix_world = arm.matrix_world.copy()
new.name = new.data.name = a.prop
new.modifiers.clear()
ntri = sum(len(p.vertices) - 2 for p in new.data.polygons)
if ntri > a.prop_tris:
    d = new.modifiers.new("Decimate", "DECIMATE")
    d.ratio = a.prop_tris / ntri
    d.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = new
    bpy.ops.object.modifier_apply(modifier=d.name)
g = new.vertex_groups.new(name=a.bone)
g.add(range(len(new.data.vertices)), 1.0, "REPLACE")
new.modifiers.new("Armature", "ARMATURE").object = arm
for i, m in enumerate(new.data.materials):
    if m:
        m.name = a.mat if i == 0 else "%s%d" % (a.mat, i)
        for n in (m.node_tree.nodes if m.use_nodes else []):     # (Godot extracts it as <art>_v95p*.jpg: a 2048 second image)
            if n.type == "TEX_IMAGE" and n.image and not n.image.name.startswith("v95p"):
                n.image.name = "v95p" if "v95p" not in bpy.data.images else "v95p%d" % len(bpy.data.images)
for p in new.data.polygons:
    p.use_smooth = True
new_tip = o_g + od * (s * (mt1 - m_grip))
new_len = s * (mt1 - mt0)

# anchors: the tip on the new head's end, the others at the same distance share back from it
old_len = ot1 - ot0
for name in [a.tip] + [n for n in a.anchors.split(",") if n]:
    e = bpy.data.objects[name]
    back = (tip_w - np.array(e.matrix_world.translation)) @ od / old_len
    mw = e.matrix_world.copy()
    mw.translation = Vector(new_tip - od * back * new_len)
    e.matrix_world = mw
    print("PROPSWAP anchor", name, [round(x, 3) for x in mw.translation], flush=True)

# the old prop's faces go
import bmesh
bm = bmesh.new()
bm.from_mesh(body.data)
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in old_mats], context="FACES_ONLY")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(body.data)
bm.free()
for i in sorted(old_mats, reverse=True):
    if not any(p.material_index == i for p in body.data.polygons):
        body.data.materials.pop(index=i)
for o in list(bpy.data.objects):
    if o.name.startswith("M_"):
        bpy.data.objects.remove(o)
arm.data.pose_position = "POSE"
for act in bpy.data.actions:
    act.use_frame_range = True
    act.frame_start, act.frame_end = round(act.frame_range[0]), round(act.frame_range[1])
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    if o.type in ("ARMATURE", "MESH", "EMPTY"):
        o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.context.scene.render.fps = 30
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                          export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_materials="EXPORT",
                          export_image_format="JPEG", export_jpeg_quality=92, export_extras=False, export_vertex_color="ACTIVE",
                          export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False,
                          export_def_bones=False)
tris = sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == "MESH" for p in o.data.polygons)
print("PROPSWAP exported", a.out, "tris", tris, "prop tris", sum(len(p.vertices) - 2 for p in new.data.polygons), flush=True)
