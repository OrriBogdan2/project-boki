# Workbench texture views of a glb: blender -b -P bl_views.py -- GLB OUTPREFIX "clip:frame,..." target_y dist [matsolo]
import bpy,sys
from mathutils import Vector
a=sys.argv[sys.argv.index('--')+1:]; glb,out,spec=a[0],a[1],a[2]; ty=float(a[3]); dist=float(a[4]); solo=a[5] if len(a)>5 else ''
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
sc=bpy.context.scene; sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='FLAT'; sc.display.shading.color_type='TEXTURE'
import os
sc.display.shading.show_backface_culling=os.environ.get('CULL','1')=='1'
sc.display.shading.background_type='VIEWPORT'; sc.display.shading.background_color=(0.1,0.6,0.1)
sc.render.film_transparent=False
sc.render.resolution_x=sc.render.resolution_y=360
if solo:
    for m in bpy.data.materials:
        if m.name not in solo.split('+') and m.node_tree:
            # paint non-solo materials flat grey via viewport colour
            m.diffuse_color=(0.5,0.5,0.5,1)
arm=[o for o in sc.objects if o.type=='ARMATURE'][0]
cam=bpy.data.objects.new('c',bpy.data.cameras.new('c')); sc.collection.objects.link(cam); sc.camera=cam; cam.data.lens=50
V={'front':Vector((0,-1,0.05)),'q34':Vector((0.7,-0.7,0.1)),'side':Vector((1,0,0.05)),'sideR':Vector((-1,0,0.05)),'back':Vector((0,1,0.05)),'q34R':Vector((-0.7,-0.7,0.1))}
acts={x.name:x for x in bpy.data.actions}
for cf in spec.split(','):
    clip,fr=cf.split(':'); fr=int(fr)
    if clip=='rest': arm.animation_data.action=None
    else: arm.animation_data.action=acts[[n for n in acts if n.startswith(clip)][0]]
    sc.frame_set(fr); sc.view_layers[0].update()
    hp=arm.matrix_world@arm.pose.bones['Hips'].head
    t=Vector((hp.x,hp.y,ty))
    for v,d in V.items():
        cam.location=t+d.normalized()*dist; cam.rotation_euler=(t-cam.location).to_track_quat('-Z','Y').to_euler()
        sc.render.filepath=f'{out}_{clip}{fr}_{v}.png'; bpy.ops.render.render(write_still=True)
