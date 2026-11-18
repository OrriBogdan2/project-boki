"""blender -b --factory-startup -P close.py -- OUTDIR HUNTER RES SAMPLES TAG=GLB ... : lit face close-ups front + 3/4 (35 deg), GPU if present.
Relative paths resolve against this script's folder (GPU workers start elsewhere)."""
import sys,os,math,bpy
from mathutils import Vector
a=sys.argv[sys.argv.index('--')+1:]; B=os.path.dirname(os.path.abspath(__file__))
rp=lambda p: p if os.path.isabs(p) else os.path.join(B,p)
out,h,RES,S=rp(a[0]),a[1],int(a[2]),int(a[3]); os.makedirs(out,exist_ok=True)
F={'Gil':(0.05,0.45,0.50),'Lace':(-0.015,0.75,0.24),'Sable':(0.005,0.60,0.28),'Albert':(0.004,0.255,0.32)}[h]
def setup():
    sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.samples=S; sc.cycles.use_denoising=True
    try:
        pr=bpy.context.preferences.addons['cycles'].preferences
        for t in ('OPTIX','CUDA','METAL','HIP'):
            try:
                pr.compute_device_type=t; pr.get_devices(); devs=[d for d in pr.devices if d.type==t]
                if devs:
                    for d in devs: d.use=True
                    sc.cycles.device='GPU'; print('DEVICE',t,[d.name for d in devs]); break
            except Exception: pass
    except Exception as e: print('gpu?',e)
    sc.render.resolution_x=sc.render.resolution_y=RES; sc.view_settings.view_transform='Standard'
    sc.world=bpy.data.worlds.new('w'); sc.world.use_nodes=True; bg=sc.world.node_tree.nodes['Background']; bg.inputs[0].default_value=(0.5,0.5,0.53,1); bg.inputs[1].default_value=0.8
    return sc
for tg in a[4:]:
    tag,glb=tg.split('=',1); bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=rp(glb)); sc=setup()
    for o in sc.objects:
        if o.type=='ARMATURE': o.data.pose_position='REST'
    cam=bpy.data.objects.new('cam',bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera=cam
    cam.data.type='ORTHO'; cam.data.ortho_scale=F[2]; cam.data.clip_end=100
    key=bpy.data.objects.new('k',bpy.data.lights.new('k','SUN')); key.data.energy=3.0; sc.collection.objects.link(key)
    fill=bpy.data.objects.new('f',bpy.data.lights.new('f','SUN')); fill.data.energy=0.8; sc.collection.objects.link(fill)
    C=Vector((F[0],0,F[1]))
    for name,ang in (('front',0),('tq',35)):
        r=math.radians(ang); d=Vector((math.sin(r),-math.cos(r),0)); cam.location=C+d*5; cam.rotation_euler=(math.pi/2,0,r)
        key.rotation_euler=(math.radians(50),0,r+math.radians(-30)); fill.rotation_euler=(math.radians(70),0,r+math.radians(40))
        sc.render.filepath=f'{out}/{tag}_{name}.png'; bpy.ops.render.render(write_still=True)
    print('DONE',tag,flush=True)
