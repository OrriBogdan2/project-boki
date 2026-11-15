import bpy, os, math, numpy as np, colorsys
from mathutils import Vector
out="out"; os.makedirs(out,exist_ok=True)
src="/home/boki/meshy/v95/Grimble/r5/cg3d1115/A.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ob=[o for o in bpy.data.objects if o.type=='MESH'][0]
m=ob.data
mat=m.materials[0]
for n in mat.node_tree.nodes: print("NODE",n.type,n.name,getattr(n,'image',None) and n.image.name)
for l in mat.node_tree.links: print("LINK",l.from_node.name,l.from_socket.name,'->',l.to_node.name,l.to_socket.name)
print("UV",[u.name for u in m.uv_layers],"ATTR",[(a.name,a.domain) for a in m.attributes], "loops",len(m.loops),"polys",len(m.polygons), "objxform", ob.matrix_world.to_euler(), ob.scale)
nv=len(m.vertices)
co=np.zeros(nv*3,np.float32); m.vertices.foreach_get('co',co); co=co.reshape(-1,3)
vi=np.zeros(len(m.loops),np.int32); m.loops.foreach_get('vertex_index',vi)
uvl=m.uv_layers.active.data; uv=np.zeros(len(m.loops)*2,np.float32); uvl.foreach_get('uv',uv); uv=uv.reshape(-1,2)
vuv=np.zeros((nv,2),np.float32); vuv[vi]=uv
img=bpy.data.images['Image_0']; w,h=img.size
px=np.array(img.pixels[:],dtype=np.float32).reshape(h,w,4)
ix=np.clip((vuv[:,0]*w).astype(int),0,w-1); iy=np.clip((vuv[:,1]*h).astype(int),0,h-1)
rgb=px[iy,ix,:3]
mx=rgb.max(1); mn=rgb.min(1); s=(mx-mn)/np.maximum(mx,1e-5)
r,g,b=rgb[:,0],rgb[:,1],rgb[:,2]
hue=np.where(mx==r,((g-b)/np.maximum(mx-mn,1e-5))%6,np.where(mx==g,(b-r)/np.maximum(mx-mn,1e-5)+2,(r-g)/np.maximum(mx-mn,1e-5)+4))*60
gold=(hue>30)&(hue<62)&(s>0.4)&(mx>0.45)
box=(co[:,0]>0.10)&(co[:,0]<0.155)&(co[:,2]>0.08)&(co[:,2]<0.40)
sel=box&gold
print("box verts",box.sum(),"gold in box",sel.sum())
c=m.color_attributes.new("dbg",'FLOAT_COLOR','POINT')
cc=np.full((nv,4),0.5,np.float32); cc[:,3]=1; cc[sel]=(1,0,0,1); cc[box&~gold]=(0,0,1,1)
c.data.foreach_set('color',cc.ravel())
m.color_attributes.active_color=c
np.save(out+"/co.npy",co[box]); 
# depth profile
for z0 in np.arange(0.10,0.40,0.03):
    zz=sel&(co[:,2]>=z0)&(co[:,2]<z0+0.03)
    nn=box&(~gold)&(co[:,2]>=z0)&(co[:,2]<z0+0.03)
    if zz.sum(): print("z%.2f gold n=%d x[%.3f,%.3f] y[%.3f,%.3f] | nongold y[%.3f,%.3f] n=%d"%(z0,zz.sum(),co[zz,0].min(),co[zz,0].max(),co[zz,1].min(),co[zz,1].max(),co[nn,1].min() if nn.sum() else 0,co[nn,1].max() if nn.sum() else 0,nn.sum()))
sc=bpy.context.scene
sc.render.engine='BLENDER_WORKBENCH'; sc.display.shading.light='FLAT'; sc.display.shading.color_type='VERTEX'
sc.render.resolution_x=800; sc.render.resolution_y=800
sc.world=bpy.data.worlds.new("w"); sc.world.color=(0.5,0.5,0.5)
cam=bpy.data.objects.new("cam",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam; cam.data.type='ORTHO'
fc=Vector((0.1,0,0.25))
for a in (-35,0,35):
    cam.data.ortho_scale=0.4
    az=math.radians(a); pos=Vector((fc.x+6*math.sin(az),-6*math.cos(az),fc.z)); cam.location=pos
    cam.rotation_euler=(fc-pos).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f"{out}/dbg_{a}.jpg"; bpy.ops.render.render(write_still=True)
