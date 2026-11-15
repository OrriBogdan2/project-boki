import bpy, os, math, numpy as np
from mathutils import Vector
def load(src):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    ob=[o for o in bpy.data.objects if o.type=='MESH'][0]
    return ob
def arrays(m):
    nv=len(m.vertices)
    co=np.zeros(nv*3,np.float32); m.vertices.foreach_get('co',co); co=co.reshape(-1,3)
    vi=np.zeros(len(m.loops),np.int32); m.loops.foreach_get('vertex_index',vi)
    uv=np.zeros(len(m.loops)*2,np.float32); m.uv_layers.active.data.foreach_get('uv',uv); uv=uv.reshape(-1,2)
    vuv=np.zeros((nv,2),np.float32); vuv[vi]=uv
    ev=np.zeros(len(m.edges)*2,np.int32); m.edges.foreach_get('vertices',ev); ev=ev.reshape(-1,2)
    return co,vi,uv,vuv,ev
def imgarr(name):
    im=bpy.data.images[name]; w,h=im.size
    return np.array(im.pixels[:],dtype=np.float32).reshape(h,w,4)
def hsv_gold(rgb):
    mx=rgb.max(1); mn=rgb.min(1); s=(mx-mn)/np.maximum(mx,1e-5); d=np.maximum(mx-mn,1e-5)
    r,g,b=rgb[:,0],rgb[:,1],rgb[:,2]
    hue=np.where(mx==r,((g-b)/d)%6,np.where(mx==g,(b-r)/d+2,(r-g)/d+4))*60
    return (hue>30)&(hue<62)&(s>0.4)&(mx>0.45)
def components(mask,ev,nv):
    lab=np.arange(nv); keep=mask[ev[:,0]]&mask[ev[:,1]]; e=ev[keep]
    while True:
        a=lab[e[:,0]]; b=lab[e[:,1]]; mn=np.minimum(a,b)
        new=lab.copy(); np.minimum.at(new,e[:,0],mn); np.minimum.at(new,e[:,1],mn)
        # pointer jump
        new=new[new]
        if (new==lab).all(): break
        lab=new
    return lab
def setup_render(res=800):
    sc=bpy.context.scene
    sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='FLAT'
    sc.render.resolution_x=res; sc.render.resolution_y=res
    sc.world=bpy.data.worlds.new("w"); sc.world.color=(0.5,0.5,0.5)
    cam=bpy.data.objects.new("cam",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam; cam.data.type='ORTHO'
    return sc,cam
def shot(sc,cam,path,az_deg,center,scale):
    cam.data.ortho_scale=scale; az=math.radians(az_deg)
    pos=Vector((center[0]+6*math.sin(az),center[1]-6*math.cos(az),center[2])); cam.location=pos
    cam.rotation_euler=(Vector(center)-pos).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=path; bpy.ops.render.render(write_still=True)
