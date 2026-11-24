# quick CPU views: blender -b -P qr.py -- GLB OUTPREFIX clip:frame [clip:frame...]   (front/side/back/34 of legs+skirt, z 0..1.3)
import bpy, sys, math
from mathutils import Vector
A=sys.argv[sys.argv.index('--')+1:]; G,OUT=A[:2]; JOBS=A[2:]
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=G)
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
for o in bpy.data.objects:
    if o.type=='MESH' and o.name in ('Icosphere',): o.hide_render=True
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=16; sc.cycles.device='CPU'; sc.render.resolution_x=420; sc.render.resolution_y=640
sc.render.film_transparent=False
w=bpy.data.worlds.new('w'); w.use_nodes=True; w.node_tree.nodes['Background'].inputs[0].default_value=(.8,.8,.82,1); w.node_tree.nodes['Background'].inputs[1].default_value=1.2; sc.world=w
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); sc.collection.objects.link(cam); cam.data.type='ORTHO'; cam.data.ortho_scale=1.45; sc.camera=cam
def look(az):
    r=3.0; cam.location=(-0.03+r*math.sin(az),-0.03-r*math.cos(az),0.62); d=Vector((-0.03,-0.03,0.62))-cam.location; cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
for jb in JOBS:
    clip,fr=jb.split(':'); arm.animation_data_create(); arm.animation_data.action=bpy.data.actions[clip]; sc.frame_set(int(fr)); bpy.context.view_layer.update()
    for nm,az in (('f',0),('s',math.pi/2),('b',math.pi),('q',math.pi/4)):
        look(az); sc.render.filepath='%s_%s_%s_%s.png'%(OUT,clip[:4],fr,nm); bpy.ops.render.render(write_still=True)
