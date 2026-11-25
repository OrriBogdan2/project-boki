import bpy,sys
from mathutils import Vector
a=sys.argv[sys.argv.index('--')+1:]; glb,out,bone=a[0],a[1],a[2]; dist=float(a[3]); spec=a[4]
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=glb)
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='STUDIO'; sc.display.shading.color_type='TEXTURE'
sc.display.shading.show_backface_culling=True; sc.render.resolution_x=sc.render.resolution_y=300
arm=[o for o in sc.objects if o.type=='ARMATURE'][0]
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); sc.collection.objects.link(cam); sc.camera=cam; cam.data.lens=50
V={'front':Vector((0,-1,0.1)),'side':Vector((-1,0,0.1)),'back':Vector((0,1,0.1)),'q34':Vector((-0.7,-0.7,0.25))}
acts={x.name:x for x in bpy.data.actions}
for cf in spec.split(','):
    clip,fr=cf.split(':'); fr=int(fr)
    arm.animation_data.action=None if clip=='rest' else acts[[n for n in acts if n.startswith(clip)][0]]
    sc.frame_set(fr); sc.view_layers[0].update(); t=arm.matrix_world@arm.pose.bones[bone].head
    for v,d in V.items():
        cam.location=t+d.normalized()*dist; cam.rotation_euler=(t-cam.location).to_track_quat('-Z','Y').to_euler()
        sc.render.filepath=f'{out}_{clip}{fr}_{v}.png'; bpy.ops.render.render(write_still=True)
