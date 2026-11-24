"""graft.py LIVE.glb DONOR.glb OUT.glb : r10. Base = live (owner-merged #766 face/hair/pins/body + its body anims); replace
its Skirt with the donor's long narrow-slit Meshy skirt (r8b H2 + r9 flare) incl. weights, and take the donor's SkirtSw*
bone rests + SkirtSw* keys (built for that long skirt). Rig/export only, no sculpt."""
import bpy, sys
A = sys.argv[sys.argv.index('--') + 1:]; LIVE, DON, OUT = A[:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=DON)
don = {o.name: o for o in bpy.data.objects}; dact = {a.name: a for a in bpy.data.actions}
darm = [o for o in don.values() if o.type == 'ARMATURE'][0]
bpy.ops.import_scene.gltf(filepath=LIVE)
new = [o for o in bpy.data.objects if o.name not in don]; lact = [a for a in bpy.data.actions if a.name not in dact]
larm = [o for o in new if o.type == 'ARMATURE'][0]
SW = [b.name for b in darm.data.bones if b.name.startswith('SkirtSw')]
for o in new:
    if o.type == 'MESH' and not o.name.startswith('Skirt'):
        n = sum(1 for g in o.vertex_groups if g.name in SW); print('SWGROUPS', o.name, n)
# skirt bone rests from the donor
bpy.context.view_layer.objects.active = larm; bpy.ops.object.mode_set(mode='EDIT')
dm = larm.matrix_world.inverted() @ darm.matrix_world
for n in SW:
    e = larm.data.edit_bones[n]; db = darm.data.bones[n]
    e.head = dm @ db.head_local; e.tail = dm @ db.tail_local
    e.align_roll((dm.to_3x3() @ db.matrix_local.to_3x3().col[2]))
bpy.ops.object.mode_set(mode='OBJECT')
# skirt bone keys from the donor
for la in lact:
    base = la.name.rsplit('.', 1)[0] if la.name not in dact else la.name
    da = dact.get(base)
    if not da: print('NOACT', la.name); continue
    for fc in [f for f in la.fcurves if any('"%s"' % n in f.data_path for n in SW)]: la.fcurves.remove(fc)
    k = 0
    for fc in da.fcurves:
        if any('"%s"' % n in fc.data_path for n in SW):
            nf = la.fcurves.new(fc.data_path, index=fc.array_index, action_group=fc.group.name if fc.group else '')
            nf.keyframe_points.add(len(fc.keyframe_points))
            for a, b in zip(fc.keyframe_points, nf.keyframe_points):
                b.co = a.co; b.interpolation = a.interpolation; b.handle_left = a.handle_left; b.handle_right = a.handle_right
            k += 1
    print('ACT', la.name, '<-', da.name, k, 'curves')
sk = don['Skirt']; mw = sk.matrix_world.copy()
bpy.data.objects.remove([o for o in new if o.type == 'MESH' and o.name.startswith('Skirt')][0], do_unlink=True)
sk.parent = larm; sk.matrix_world = mw
for m in sk.modifiers:
    if m.type == 'ARMATURE': m.object = larm
for o in list(don.values()):
    if o is not sk: bpy.data.objects.remove(o, do_unlink=True)
for a in dact.values(): bpy.data.actions.remove(a)
for o in bpy.data.objects:
    if o.name.endswith('.001'): o.name = o.name[:-4]
for a in bpy.data.actions:
    if a.name.endswith('.001'): a.name = a.name[:-4]
if larm.data.name.endswith('.001'): larm.data.name = larm.data.name[:-4]
for o in bpy.data.objects: print('OBJ', o.name, o.type, o.parent.name if o.parent else '-')
print('ACTS', [a.name for a in bpy.data.actions])
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animations=True, export_skins=True, export_apply=False)
