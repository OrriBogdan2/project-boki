# blender -b -P bl_game.py -- GLB OUT clip:frame:yawdeg ... : workbench quick views at the game match camera (fov 8, cam (0,21,9.4) -> (0,0.8,0) Godot)
import bpy,sys,math
from mathutils import Vector
a=sys.argv[sys.argv.index('--')+1:]; glb,out=a[0],a[1]
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=glb)
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='STUDIO'; sc.display.shading.color_type='TEXTURE'
sc.display.shading.background_type='VIEWPORT'; sc.display.shading.background_color=(0.33,0.5,0.22); sc.render.resolution_x=sc.render.resolution_y=300
arm=[o for o in sc.objects if o.type=='ARMATURE'][0]; root=arm
while root.parent: root=root.parent
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); sc.collection.objects.link(cam); sc.camera=cam
cam.data.angle=math.radians(8*300/768*2.0); cam.location=Vector((0,-9.4,21)); t=Vector((0,0,0.8)); cam.rotation_euler=(t-cam.location).to_track_quat('-Z','Y').to_euler()
for spec in a[2:]:
    c,f,y=spec.split(':'); act=bpy.data.actions.get(c) or [x for x in bpy.data.actions if x.name.startswith(c)][0]
    arm.animation_data.action=act; sc.frame_set(int(f)); root.rotation_mode='XYZ'; root.rotation_euler[2]=math.radians(float(y))
    sc.render.filepath=f'{out}_{c[:5]}_{f}_{y}.png'; bpy.ops.render.render(write_still=True)
