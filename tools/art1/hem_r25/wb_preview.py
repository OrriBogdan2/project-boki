# blender -b -P wb.py -- GLB OUTPREFIX CLIP FRAC[,FRAC] : workbench renders at the game camera (fov 8, (0,21,9.4)->(0,0.8,0)) and eye level front, model yawed YAW deg
import bpy,sys,math,mathutils
a=sys.argv[sys.argv.index('--')+1:]; glb,outp,clip,fr=a[0],a[1],a[2],[float(x) for x in a[3].split(',')]; yaw=float(a[4]) if len(a)>4 else 0
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=glb)
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE'); act=next(x for x in bpy.data.actions if clip.lower() in x.name.lower())
for o in bpy.data.objects:
    if o.parent is None: o.rotation_mode='XYZ'; o.rotation_euler[2]+=math.radians(yaw)
arm.animation_data_create(); arm.animation_data.action=act
for t in arm.animation_data.nla_tracks: t.mute=True
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='STUDIO'; sc.display.shading.color_type='TEXTURE'
sc.render.resolution_x=sc.render.resolution_y=420; sc.render.film_transparent=False; sc.world=bpy.data.worlds.new('w'); sc.world.color=(0.25,0.4,0.2)
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); sc.collection.objects.link(cam); sc.camera=cam
f0,f1=act.frame_range
for x in fr:
    sc.frame_set(int(round(f0+(f1-f0)*x)))
    for nm,eye,tgt,lens in (('game',(0,-9.4,21),(0,0,0.8),None),('eye',(0,-6,0.9),(0,0,0.75),None),('knee',(0,-6,0.45),(0,0,0.7),None)):
        cam.location=eye; d=mathutils.Vector(tgt)-mathutils.Vector(eye); cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
        cam.data.angle=math.radians(8 if nm=='game' else 22)
        pass
        sc.render.filepath='%s_%s_%.2f.png'%(outp,nm,x); bpy.ops.render.render(write_still=True)
