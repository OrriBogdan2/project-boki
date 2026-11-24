"""blender -b -P grid.py -- IN.glb OUT.png CLIP:F,CLIP:F,... [az=0,90,180] [cz=0.55 dist=2.6 res=256]: workbench textured grid, rows = frames, cols = azimuths (0 = front)."""
import bpy, sys, math
from mathutils import Vector
A = sys.argv[sys.argv.index('--') + 1:]; O = dict(a.split('=') for a in A[3:])
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=A[0])
for o in list(bpy.data.objects):
    if o.name.startswith('Icosphere'): bpy.data.objects.remove(o)
sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.color_type = 'TEXTURE'; sc.display.shading.light = 'STUDIO'
R = int(O.get('res', 256)); sc.render.resolution_x = sc.render.resolution_y = R; sc.render.film_transparent = False
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]; arm.animation_data_create()
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam; cam.data.lens = 50
AZ = [float(x) for x in O.get('az', '0,90,180').split(',')]; CZ = float(O.get('cz', .55)); D = float(O.get('dist', 2.6)); TZ = float(O.get('tz', .65))
import numpy as np; tiles = []
for cf in A[2].split(','):
    c, f = cf.split(':'); arm.animation_data.action = bpy.data.actions[c]; sc.frame_set(int(f))
    row = []
    for az in AZ:
        a = math.radians(az - 90); cam.location = Vector((-0.027 + D * math.cos(a), -0.042 + D * math.sin(a), CZ))
        cam.rotation_euler = (Vector((-0.027, -0.042, TZ)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = '/tmp/_g_%d.png' % __import__('os').getpid(); bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load('/tmp/_g_%d.png' % __import__('os').getpid()); px = np.array(im.pixels[:]).reshape(R, R, 4)[::-1, :, :3]; bpy.data.images.remove(im); row.append(px)
    tiles.append(np.concatenate(row, 1))
g = np.concatenate(tiles, 0); im = bpy.data.images.new('o', g.shape[1], g.shape[0]); im.pixels = np.concatenate([g[::-1], np.ones(g.shape[:2] + (1,))], 2).ravel(); im.filepath_raw = A[1]; im.file_format = 'PNG'; im.save()
