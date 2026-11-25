import bpy,sys,math
from mathutils import Vector
a=sys.argv[sys.argv.index('--')+1:]; glb,out,spec=a[0],a[1],a[2]
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=glb)
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='STUDIO'; sc.display.shading.color_type='TEXTURE'
sc.display.shading.show_backface_culling=True; sc.render.resolution_x=sc.render.resolution_y=300
arm=[o for o in sc.objects if o.type=='ARMATURE'][0]
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); sc.collection.objects.link(cam); sc.camera=cam; cam.data.lens=50
acts={x.name:x for x in bpy.data.actions}
for cf in spec.split(','):
    clip,fr=cf.split(':'); fr=int(fr)
    arm.animation_data.action=None if clip=='rest' else acts[[n for n in acts if n.startswith(clip)][0]]
    sc.frame_set(fr); sc.view_layers[0].update(); hp=arm.matrix_world@arm.pose.bones['Hips'].head; t=Vector((hp.x,hp.y,hp.z-0.05))
    for deg in (0,60,120,180,240,300):
        r=math.radians(deg); d=Vector((math.sin(r),-math.cos(r),0.35))
        cam.location=t+d.normalized()*0.75; cam.rotation_euler=(t-cam.location).to_track_quat('-Z','Y').to_euler()
        sc.render.filepath=f'{out}_{clip}{fr}_{deg:03d}.png'; bpy.ops.render.render(write_still=True)
