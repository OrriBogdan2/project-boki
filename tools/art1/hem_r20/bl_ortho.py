# blender -b -P bl_ortho.py -- GLB OUT cz scale  (orthographic front/side, 1 px = scale/res m)
import bpy,sys,os
from mathutils import Vector
a=sys.argv[sys.argv.index('--')+1:]; glb,out=a[0],a[1]; cz=float(a[2]); S=float(a[3])
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=glb)
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='FLAT'; sc.display.shading.color_type='TEXTURE'
sc.display.shading.background_type='VIEWPORT'; sc.display.shading.background_color=(0.1,0.6,0.1)
sc.render.resolution_x=sc.render.resolution_y=int(os.environ.get('RES','800'))
for o in sc.objects:
    if o.type=='ARMATURE': o.data.pose_position='REST'
for o in sc.objects:
    if o.type=='MESH' and any(h and h in o.name for h in os.environ.get('HIDE','').split(',')): o.hide_render=True
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); sc.collection.objects.link(cam); sc.camera=cam; cam.data.type='ORTHO'; cam.data.ortho_scale=S
VV={'front':Vector((0,-1,0)),'side':Vector((1,0,0)),'back':Vector((0,1,0)),'sideR':Vector((-1,0,0))}
for v,d in [(k,VV[k]) for k in os.environ.get('VIEWS','front,side').split(',')]:
    t=Vector((0,0,cz)); cam.location=t+d*5; cam.rotation_euler=(t-cam.location).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f'{out}_{v}.png'; bpy.ops.render.render(write_still=True)
