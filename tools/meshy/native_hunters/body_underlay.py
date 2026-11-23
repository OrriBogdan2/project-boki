# blender -b -P body_underlay.py -- in.obj out.obj voxel inset tris
# r14: a closed shell (e.g. dredge_r14.py --shell): voxel remesh, moved inward by inset (0: not), decimated to tris.
import bpy
import sys

a = sys.argv[sys.argv.index("--") + 1:]
vox, inset, tris = float(a[2]), float(a[3]), int(a[4])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=a[0])
o = [x for x in bpy.data.objects if x.type == "MESH"][0]
bpy.context.view_layer.objects.active = o
o.select_set(True)
r = o.modifiers.new("r", "REMESH")
r.mode, r.voxel_size, r.adaptivity = "VOXEL", vox, 0.0
bpy.ops.object.modifier_apply(modifier="r")
if inset:
    d = o.modifiers.new("d", "DISPLACE")
    d.strength, d.mid_level = -inset, 0.0
    bpy.ops.object.modifier_apply(modifier="d")
n = len(o.data.polygons)
dm = o.modifiers.new("dm", "DECIMATE")
dm.ratio = min(1.0, tris / max(1, 2 * n))
bpy.ops.object.modifier_apply(modifier="dm")
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.object.mode_set(mode="OBJECT")
print("UNDERLAY tris", len(o.data.polygons))
bpy.ops.wm.obj_export(filepath=a[1], export_selected_objects=True, export_materials=False, export_uv=False)
