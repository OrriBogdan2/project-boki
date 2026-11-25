# blender -b -P underlay.py -- pack.glb out.glb voxel inset tris
import bpy, sys
a=sys.argv[sys.argv.index('--')+1:]
vox=float(a[2]); inset=float(a[3]); tris=int(a[4])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
ob=[o for o in bpy.data.objects if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in ob: o.select_set(True)
bpy.context.view_layer.objects.active=ob[0]
if len(ob)>1: bpy.ops.object.join()
o=bpy.context.view_layer.objects.active
o.data.materials.clear()
for m in list(o.modifiers): o.modifiers.remove(m)
r=o.modifiers.new('r','REMESH'); r.mode='VOXEL'; r.voxel_size=vox; r.adaptivity=0.0
bpy.ops.object.modifier_apply(modifier='r')
print("REMESH tris", sum(len(p.vertices)-2 for p in o.data.polygons))
# inset along normals
d=o.modifiers.new('d','DISPLACE'); d.strength=-inset; d.mid_level=0.0
bpy.ops.object.modifier_apply(modifier='d')
dm=o.modifiers.new('dm','DECIMATE'); dm.ratio=min(1.0,tris/max(1,sum(len(p.vertices)-2 for p in o.data.polygons)))
bpy.ops.object.modifier_apply(modifier='dm')
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.quads_convert_to_tris(); bpy.ops.object.mode_set(mode='OBJECT')
print("FINAL tris", len(o.data.polygons))
bpy.ops.export_scene.gltf(filepath=a[1], export_format='GLB', use_selection=True, export_apply=False)
