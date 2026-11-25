# blender -b -P bl_look.py -- GLB OUT target_z dist hide_obj_substr(,..) [clip:frame]
import bpy,sys,os
from mathutils import Vector
a=sys.argv[sys.argv.index('--')+1:]; glb,out=a[0],a[1]; tz=float(a[2]); dist=float(a[3]); hide=[h for h in a[4].split(',') if h]; cf=a[5] if len(a)>5 else 'rest:0'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light=os.environ.get('LIGHT','FLAT'); sc.display.shading.color_type='TEXTURE'
sc.display.shading.show_backface_culling=os.environ.get('CULL','1')=='1'
sc.display.shading.background_type='VIEWPORT'; sc.display.shading.background_color=(0.1,0.6,0.1)
sc.render.resolution_x=sc.render.resolution_y=int(os.environ.get('RES','400'))
for o in sc.objects:
    if o.type=='MESH' and any(h in o.name for h in hide): o.hide_render=True
    if o.type=='MESH': print('OBJ',o.name,len(o.data.polygons),[m.name for m in o.data.materials])
arms=[o for o in sc.objects if o.type=='ARMATURE']
clip,fr=cf.split(':')
if arms and clip!='rest':
    acts={x.name:x for x in bpy.data.actions}; arms[0].animation_data.action=acts[[n for n in acts if n.startswith(clip)][0]]
sc.frame_set(int(fr)); sc.view_layers[0].update()
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); sc.collection.objects.link(cam); sc.camera=cam; cam.data.lens=50
V={'front':Vector((0,-1,0.05)),'q34':Vector((0.7,-0.7,0.1)),'side':Vector((1,0,0.05)),'back':Vector((0,1,0.05))}
t=Vector((float(os.environ.get('TX','0')),0,tz))
for v,d in V.items():
    cam.location=t+d.normalized()*dist; cam.rotation_euler=(t-cam.location).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f'{out}_{v}.png'; bpy.ops.render.render(write_still=True)
