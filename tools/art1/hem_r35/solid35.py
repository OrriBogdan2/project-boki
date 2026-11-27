"""solid35.py RAW.obj TEX.jpg OUT.obj OUT_TEX.png TRIS VOXEL THICK: r35 hair as one solid lock.
RAW (Meshy hair cut, Meshy UVs + TEX) -> solidify THICK -> voxel remesh VOXEL -> smooth -> decimate to TRIS -> smart UV ->
Cycles CPU bake of RAW's colour (selected to active) into OUT_TEX (1024). Decimating the raw strands left black shards."""
import bpy, sys
a = sys.argv[sys.argv.index('--') + 1:]
raw, tex, out, outtex, tris, vox, thick = a[0], a[1], a[2], a[3], int(a[4]), float(a[5]), float(a[6])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=raw, forward_axis='NEGATIVE_Z', up_axis='Y'); src = bpy.context.selected_objects[0]
m = bpy.data.materials.new('src'); m.use_nodes = True; nt = m.node_tree; ti = nt.nodes.new('ShaderNodeTexImage'); ti.image = bpy.data.images.load(tex)
nt.links.new(ti.outputs[0], nt.nodes['Principled BSDF'].inputs['Base Color']); src.data.materials.append(m)
low = src.copy(); low.data = src.data.copy(); bpy.context.scene.collection.objects.link(low); low.data.materials.clear()
bpy.context.view_layer.objects.active = low
for o in bpy.context.selected_objects: o.select_set(False)
low.select_set(True)
md = low.modifiers.new('s', 'SOLIDIFY'); md.thickness = thick; md.offset = -1; bpy.ops.object.modifier_apply(modifier='s')
md = low.modifiers.new('r', 'REMESH'); md.mode = 'VOXEL'; md.voxel_size = vox; bpy.ops.object.modifier_apply(modifier='r')
md = low.modifiers.new('sm', 'SMOOTH'); md.iterations = 4; md.factor = 0.5; bpy.ops.object.modifier_apply(modifier='sm')
n1 = len(low.data.polygons); md = low.modifiers.new('d', 'DECIMATE'); md.ratio = min(1.0, tris / n1); bpy.ops.object.modifier_apply(modifier='d')
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004); bpy.ops.object.mode_set(mode='OBJECT')
img = bpy.data.images.new('bake', 1024, 1024); lm = bpy.data.materials.new('low'); lm.use_nodes = True; bt = lm.node_tree.nodes.new('ShaderNodeTexImage'); bt.image = img
lm.node_tree.nodes.active = bt; low.data.materials.append(lm)
sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 1
src.select_set(True); low.select_set(True); bpy.context.view_layer.objects.active = low
bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_selected_to_active=True, cage_extrusion=thick + 0.01, max_ray_distance=0.05, margin=8)
img.filepath_raw = outtex; img.file_format = 'PNG'; img.save()
for o in bpy.context.selected_objects: o.select_set(False)
low.select_set(True)
bpy.ops.wm.obj_export(filepath=out, forward_axis='NEGATIVE_Z', up_axis='Y', export_materials=False, export_normals=False, export_selected_objects=True)
print('SOLID raw %d -> remesh %d -> %d tris' % (len(src.data.polygons), n1, len(low.data.polygons)))
