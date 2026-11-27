"""dec35.py IN.obj OUT.obj TRIS: Blender decimate (collapse, UVs kept) of the r35 hair piece; obj axes kept as written (glTF Y up)."""
import bpy, sys
a = sys.argv[sys.argv.index('--') + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=a[0], forward_axis='NEGATIVE_Z', up_axis='Y')
o = bpy.context.selected_objects[0]; bpy.context.view_layer.objects.active = o
n0 = len(o.data.polygons)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.remove_doubles(threshold=0.0005); bpy.ops.object.mode_set(mode='OBJECT')
m = o.modifiers.new('d', 'DECIMATE'); m.ratio = min(1.0, float(a[2]) / max(1, len(o.data.polygons)))
bpy.ops.object.modifier_apply(modifier='d')
bpy.ops.wm.obj_export(filepath=a[1], forward_axis='NEGATIVE_Z', up_axis='Y', export_materials=False, export_normals=False, export_selected_objects=True)
print('DEC', n0, '->', len(o.data.polygons))
