"""Breaker revamp (owner 11-09): swap the shipped model's scan hull for a denser retopo, keep everything else byte-for-byte.
main's scripts no longer rebuild the shipped breaker.glb (hunter-revamp-af found a hull collar), so this opens the shipped build's own
breaker_anims.blend (rig, clips, scripted helmet/masts/fish/shield/hammer), drops the faces on `leather-scan-hot`, joins the new
scan_low.npz from breaker_scan.py in their place (same material, same bones, vertex normals as custom normals like breaker_art1.py),
points the material at the new baked maps and exports with breaker_anims.py's settings.
  blender -b OLD_WORK/breaker_anims.blend --python tools/art1/breaker_revamp.py -- OLD_WORK NEW_WORK OUT.glb
OLD_WORK: the shipped build dir (its scan_low.npz is the fit check, its breaker.glb names the clips); NEW_WORK: breaker_scan.py's output for the new retopo."""
import json
import os
import struct
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import breaker_paint as P  # noqa: E402
import imgio  # noqa: E402

OLD, NEW, OUT = sys.argv[sys.argv.index("--") + 1:][:3]
MAT = "leather-scan-hot"
for im in bpy.data.images:            # the blend is saved into NEW: keep the shipped atlas reachable
    im.filepath = bpy.path.abspath(im.filepath)
body = bpy.data.objects["breaker"]
me = body.data
mi = [m.name for m in me.materials].index(MAT)

# the shipped hull must be exactly the old retopo, so the new one lands where it did
co = np.empty(len(me.vertices) * 3, np.float32)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
fm = np.empty(len(me.polygons), np.int32)
me.polygons.foreach_get("material_index", fm)
hull_v = sorted({v for p in me.polygons if p.material_index == mi for v in p.vertices})
old = np.load(os.path.join(OLD, "scan_low.npz"))
assert int((fm == mi).sum()) == len(old["tri"]), (int((fm == mi).sum()), len(old["tri"]))      # (a few loose verts never reach the glb)
ov = old["v"][np.unique(old["tri"])]
d = np.abs(co[hull_v].min(0) - ov.min(0)).max() + np.abs(co[hull_v].max(0) - ov.max(0)).max()
assert d < 1e-3, d
print("old hull", len(hull_v), "verts", int((fm == mi).sum()), "tris, bbox match", d)

# drop it
bpy.context.view_layer.objects.active = body
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT")
body.active_material_index = mi
bpy.ops.object.material_slot_select()
bpy.ops.mesh.delete(type="VERT")
bpy.ops.object.mode_set(mode="OBJECT")
print("kept", len(me.vertices), "verts", len(me.polygons), "tris")

# the new hull, built as breaker_art1.py builds `scanbody`
scn = np.load(os.path.join(NEW, "scan_low.npz"))
nm = bpy.data.meshes.new("scanbody")
nm.from_pydata(scn["v"].tolist(), [], scn["tri"].tolist())
nm.update()
nm.uv_layers.new(name="UVMap").data.foreach_set("uv", scn["uv"].ravel())
so = bpy.data.objects.new("scanbody", nm)
bpy.context.scene.collection.objects.link(so)
for i, b in enumerate(scn["bones"]):
    g = so.vertex_groups.new(name=str(b))
    w = scn["w"][:, i]
    for vi in np.nonzero(w > 0)[0]:
        g.add([int(vi)], float(w[vi]), "REPLACE")
nm.materials.append(bpy.data.materials[MAT])
for pl in nm.polygons:
    pl.use_smooth = True
sn = np.empty(len(nm.vertices) * 3, np.float32)
nm.vertices.foreach_get("normal", sn)
sn = sn.reshape(-1, 3)
nm.normals_split_custom_set_from_vertices((sn / np.maximum(np.linalg.norm(sn, axis=1, keepdims=True), 1e-6)).tolist())
missing = {str(b) for b in scn["bones"]} - {g.name for g in body.vertex_groups}
assert not missing, missing

bpy.ops.object.select_all(action="DESELECT")
so.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
print("body", len(me.vertices), "verts", len(me.polygons), "tris")

# the new maps (albedo keyed as breaker_art1.py keys it)
sa = imgio.load(os.path.join(NEW, "scan_albedo.png"))
key = os.path.join(NEW, "scan_albedo_key.png")
imgio.save(P.key_scan(sa.reshape(-1, 3)).reshape(sa.shape), key)
for img, path in (("scan_albedo_key.png", key), ("scan_normal.png", os.path.join(NEW, "scan_normal.png"))):
    bpy.data.images[img].filepath = path
    bpy.data.images[img].reload()

hm = bpy.data.objects["hammer"].data
print("tris", len(me.polygons) + len(hm.polygons), "body", len(me.polygons), "hammer", len(hm.polygons))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(NEW, "breaker_anims.blend"), relative_remap=False)

# export exactly as breaker_anims.py does: the blend is saved before its NLA tracks, so lay one per clip of the shipped glb
glb = open(os.path.join(OLD, "breaker.glb"), "rb").read()
clips = [a["name"] for a in json.loads(glb[20:20 + struct.unpack("<I", glb[12:16])[0]])["animations"]]
arm = bpy.data.objects["Armature"]
ad = arm.animation_data
for name in clips:
    act = bpy.data.actions[name]
    ad.action = act
    if len(act.slots) and ad.action_slot is None:
        ad.action_slot = act.slots[0]
    tr = ad.nla_tracks.new()
    tr.name = name
    tr.strips.new(name, 0, act)
    ad.action = None
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=False, export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_skins=True, export_yup=True, export_materials="EXPORT",
                          export_image_format="JPEG", export_jpeg_quality=93, export_extras=False, export_force_sampling=True,
                          export_frame_step=1, export_optimize_animation_size=False, export_def_bones=False,
                          export_vertex_color="MATERIAL")
print("exported", os.path.getsize(OUT))
