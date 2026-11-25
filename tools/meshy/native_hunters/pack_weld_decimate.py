# blender -b -P packdec.py -- in.glb out.glb tris : weld seams first, then collapse-decimate (UVs ride the loops)
import bpy, sys

a = sys.argv[sys.argv.index("--") + 1 :]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
ob = [o for o in bpy.data.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in ob:
    o.select_set(True)
bpy.context.view_layer.objects.active = ob[0]
if len(ob) > 1:
    bpy.ops.object.join()
o = bpy.context.view_layer.objects.active
print("IN tris", sum(len(p.vertices) - 2 for p in o.data.polygons), "verts", len(o.data.vertices))
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0008)
bpy.ops.mesh.delete_loose(use_verts=True, use_edges=True, use_faces=False)
bpy.ops.object.mode_set(mode="OBJECT")
print("WELDED verts", len(o.data.vertices))
tris = int(a[2])
n = sum(len(p.vertices) - 2 for p in o.data.polygons)
d = o.modifiers.new("d", "DECIMATE")
d.decimate_type = "COLLAPSE"
d.ratio = tris / n
d.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier="d")
print("OUT tris", len(o.data.polygons))
bpy.ops.export_scene.gltf(
    filepath=a[1], export_format="GLB", use_selection=True, export_apply=False, export_image_format="JPEG"
)
