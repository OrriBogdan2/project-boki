"""pokeview.py GLB OUT ACTION FRAME : flat colours (body green, skirt red, rest grey), front/side/back/3-4 of the legs."""
import bpy, sys, math
A = sys.argv[sys.argv.index('--') + 1:]; G, OUT, ACT, FR = A[0], A[1], A[2], int(A[3])
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=G)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
arm.animation_data_create(); arm.animation_data.action = bpy.data.actions[ACT]; bpy.context.scene.frame_set(FR)
for o in bpy.data.objects:
    if o.type == 'MESH':
        o.color = (0.1, 0.9, 0.1, 1) if o.name == 'head_graft' else (0.8, 0.05, 0.05, 1) if o.name == 'Skirt' else (0.5, 0.5, 0.5, 1)
        if o.name in ('Icosphere', 'Bow'): o.hide_render = True
sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.color_type = 'OBJECT'
sc.display.shading.show_backface_culling = True
sc.render.resolution_x = 320; sc.render.resolution_y = 420
cam = bpy.data.objects.new('c', bpy.data.cameras.new('c')); sc.collection.objects.link(cam); sc.camera = cam; cam.data.type = 'ORTHO'; cam.data.ortho_scale = 1.1
for i, az in enumerate((0, 45, 90, 180, 270)):
    a = math.radians(az); cam.location = (3 * math.sin(a), -3 * math.cos(a), 0.62); cam.rotation_euler = (math.radians(90), 0, a)
    sc.render.filepath = f'{OUT}_{i}.png'; bpy.ops.render.render(write_still=True)
