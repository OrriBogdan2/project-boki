"""Blender: collapse-decimate a rigged .glb's mesh to a triangle budget, keeping UV seams and the skin weights.

  blender -b --factory-startup -P decimate.py -- IN.glb OUT.glb TARGET_TRIS

The mesh is split by material first: the head and face materials keep HEAD_KEEP of their triangles (the face reads
at match zoom), the rest takes the budget's remainder. Only geometry and skin weights come out (the joints are
matched by name); graft.py puts them back into IN.glb, so the node tree, bones and clips stay Meshy's.
"""

import sys

import bpy

HEAD_KEEP = 0.35  # share of the head/face triangles kept
HEADS = ("head", "face_donor")  # material names that hold the head

src, dst, target = sys.argv[sys.argv.index("--") + 1 :][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)


def mat(o):
    return o.data.materials[0].name if o.data.materials else ""


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    if len(o.data.materials) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.separate(type="MATERIAL")
        bpy.ops.object.mode_set(mode="OBJECT")
parts = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.data.polygons]
total = sum(tris(o) for o in parts)
heads = [o for o in parts if mat(o) in HEADS]
keep = {o: HEAD_KEEP for o in heads}
rest = total - sum(tris(o) for o in heads)
body = (int(target) - HEAD_KEEP * (total - rest)) / rest if rest else 1.0
if not heads:
    body = int(target) / total
for o in parts:
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new("d", "DECIMATE")
    mod.ratio = min(1.0, keep.get(o, body))
    mod.use_collapse_triangulate = True
    mod.delimit = {"UV"}
    bpy.ops.object.modifier_apply(modifier=mod.name)
print("DECIMATE", src, total, "->", sum(tris(o) for o in parts), [(mat(o), tris(o)) for o in parts])
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=dst, export_format="GLB", export_animations=False, export_skins=True, export_image_format="NONE"
)
