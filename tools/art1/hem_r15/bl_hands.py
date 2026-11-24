import bpy,sys,math
from mathutils import Vector
a=sys.argv[sys.argv.index('--')+1:]; glb,out=a[0],a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='STUDIO'; sc.display.shading.color_type='TEXTURE'
sc.render.resolution_x=sc.render.resolution_y=400
arm=[o for o in sc.objects if o.type=='ARMATURE'][0]
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); sc.collection.objects.link(cam); sc.camera=cam; cam.data.lens=50
def shot(name,bone,view):
    sc.view_layers[0].update(); pb=arm.pose.bones[bone]; t=arm.matrix_world@pb.head
    d={'front':Vector((0,-0.45,0.05)),'side':Vector((0.45*(1 if 'Left' in bone else -1),0,0.05)),'back':Vector((0,0.45,0.05)),'down':Vector((0.1*(1 if 'Left' in bone else -1),-0.25,0.35))}[view]
    cam.location=t+d; cam.rotation_euler=(t-cam.location).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=out+'_'+name+'.png'; bpy.ops.render.render(write_still=True)
acts={x.name:x for x in bpy.data.actions}
for clip,fr in [('rest',0),('Idle',10),('Attack',14),('run',8)]:
    if clip=='rest': arm.animation_data.action=None
    else:
        k=[n for n in acts if n.startswith(clip)][0]; arm.animation_data.action=acts[k]
    sc.frame_set(fr)
    for side in 'Left','Right':
        for v in ('front','side'): shot(f'{clip}_{side}_{v}',side+'Hand',v)
