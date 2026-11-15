exec(open("/home/boki/cj/20261115-193602-a3/tree/ops_tmp_grimble/common.py").read())
import time
t0=time.time()
def T(s): print("T %.0f %s"%(time.time()-t0,s),flush=True)
out="out"; os.makedirs(out,exist_ok=True)
SRC="/home/boki/meshy/v95/Grimble/r5/cg3d1115/A.glb"
ob=load(SRC); m=ob.data; mat=m.materials[0]
co,vi,uv,vuv,ev=arrays(m); nv=len(co); nf=len(m.polygons); fv=vi.reshape(-1,3)
px=imgarr('Image_0'); h,w=px.shape[:2]
ix=np.clip((vuv[:,0]*w).astype(int),0,w-1); iy=np.clip((vuv[:,1]*h).astype(int),0,h-1)
rgb=px[iy,ix,:3]
mx=rgb.max(1); mn=rgb.min(1); s=(mx-mn)/np.maximum(mx,1e-5); d=np.maximum(mx-mn,1e-5)
r,g,b=rgb[:,0],rgb[:,1],rgb[:,2]
hue=np.where(mx==r,((g-b)/d)%6,np.where(mx==g,(b-r)/d+2,(r-g)/d+4))*60
strict=(hue>30)&(hue<62)&(s>0.4)&(mx>0.45)
perm=(hue>22)&(hue<68)&(s>0.2)&(mx>0.35)
box=(co[:,0]>0.104)&(co[:,0]<0.131)&(co[:,2]>0.09)&(co[:,2]<0.30)&(co[:,1]<-0.345)
Tm=perm&box
lab=components(Tm,ev,nv)
ids,cnt=np.unique(lab[Tm],return_counts=True)
keepids=[]
for i,c in zip(ids,cnt):
    sm=lab==i
    ns=(strict&sm).sum()
    print("COMP n",c,"strict",ns,"z[%.3f,%.3f] x[%.3f,%.3f]"%(co[sm,2].min(),co[sm,2].max(),co[sm,0].min(),co[sm,0].max()))
    if c>=15 and ns>=0.3*c and co[sm,0].min()>=0.107: keepids.append(i)
C=np.isin(lab,keepids)&Tm
def dilate(mask,k):
    mask=mask.copy()
    for _ in range(k):
        a=mask[ev[:,0]]; bb=mask[ev[:,1]]
        n=mask.copy(); n[ev[a,1]]=True; n[ev[bb,0]]=True; mask=n
    return mask
C=dilate(C,int(os.environ.get("DIL","1")))
C&=(co[:,0]>0.107)&(co[:,0]<0.135)&(co[:,1]<-0.34)
print("C verts",C.sum(),"bbox",co[C].min(0),co[C].max(0))
cn=np.zeros(len(m.loops)*3,np.float32); m.corner_normals.foreach_get('vector',cn); cn=cn.reshape(-1,3)
smooth=np.zeros(nf,bool); m.polygons.foreach_get('use_smooth',smooth)
print("smooth frac",smooth.mean())
keepf=~C[fv].any(1)
print("faces del",(~keepf).sum())
fvk=fv[keepf]; uvk=uv.reshape(-1,3,2)[keepf]; cnk=cn.reshape(-1,3,3)[keepf]
# boundary half-edges
he=np.concatenate([fvk[:,[0,1]],fvk[:,[1,2]],fvk[:,[2,0]]])
key=he[:,0].astype(np.int64)*nv+he[:,1]; rkey=he[:,1].astype(np.int64)*nv+he[:,0]
bmask=~np.isin(rkey,key)
Nn=dilate(C,1)&~C
bh=he[bmask&(Nn[he[:,0]]|Nn[he[:,1]])]
print("boundary half-edges",len(bh))
nxt={}
for a,bq in bh: nxt.setdefault(int(a),[]).append(int(bq))
seen=set(); loops=[]
for a0 in list(nxt):
    if a0 in seen: continue
    lp=[a0]; seen.add(a0); cur=a0
    while True:
        nl=[x for x in nxt.get(cur,[]) if x not in seen or x==a0]
        if not nl: break
        n1=nl[0]
        if n1==a0: break
        lp.append(n1); seen.add(n1); cur=n1
    loops.append(lp)
print("loops",len(loops),sorted(len(l) for l in loops)[-10:])
# vertex normal average
vnrm=np.zeros((nv,3),np.float32); np.add.at(vnrm,fvk.reshape(-1),cnk.reshape(-1,3))
vnrm/=np.maximum(np.linalg.norm(vnrm,axis=1),1e-9)[:,None]
newco=[];newf=[];newuv=[];newcn=[]
base=nv
for lp in loops:
    n=len(lp)
    if n<3 or n>400: print("skip loop",n); continue
    cidx=base+len(newco); c3=co[lp].mean(0); newco.append(c3)
    cu=vuv[lp].mean(0); cnn=vnrm[lp].mean(0); cnn/=max(np.linalg.norm(cnn),1e-9)
    for k in range(n):
        a=lp[k]; bq=lp[(k+1)%n]
        newf.append((bq,a,cidx)); newuv.append((vuv[bq],vuv[a],cu)); newcn.append((vnrm[bq],vnrm[a],cnn))
if newf:
    allco=np.concatenate([co,np.array(newco,np.float32)]); 
    F=np.concatenate([fvk,np.array(newf,np.int32)]); UV=np.concatenate([uvk,np.array(newuv,np.float32)]); CN=np.concatenate([cnk,np.array(newcn,np.float32)])
    SM=np.concatenate([smooth[keepf],np.ones(len(newf),bool)])
else:
    allco=co; F=fvk; UV=uvk; CN=cnk; SM=smooth[keepf]
# compact verts
used=np.unique(F); remap=np.full(len(allco),-1,np.int32); remap[used]=np.arange(len(used))
nm=bpy.data.meshes.new("Mesh_0")
nm.vertices.add(len(used)); nm.vertices.foreach_set('co',allco[used].ravel())
nf2=len(F); nm.loops.add(nf2*3); nm.polygons.add(nf2)
nm.loops.foreach_set('vertex_index',remap[F].ravel())
nm.polygons.foreach_set('loop_start',np.arange(nf2,dtype=np.int32)*3); nm.polygons.foreach_set('loop_total',np.full(nf2,3,np.int32))
nm.polygons.foreach_set('use_smooth',SM)
nm.update(calc_edges=True)
u=nm.uv_layers.new(name="UVMap"); u.data.foreach_set('uv',UV.reshape(-1,2).ravel())
nm.materials.append(mat)
nm.normals_split_custom_set(CN.reshape(-1,3).tolist())
ob.data=nm
T("mesh rebuilt faces %d"%nf2)

if os.environ.get("DBG")=="1":
    reg=(co[:,0]>0.09)&(co[:,0]<0.14)&(co[:,2]>0.09)&(co[:,2]<0.32)&(co[:,1]<-0.30)&~C
    R=strict&reg
    l2=components(R,ev,nv); i2,c2=np.unique(l2[R],return_counts=True)
    for i,c in sorted(zip(i2,c2),key=lambda t:-t[1])[:25]:
        sm=l2==i; print("RES n",c,"x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f]"%(co[sm,0].min(),co[sm,0].max(),co[sm,1].min(),co[sm,1].max(),co[sm,2].min(),co[sm,2].max()))
    cc=np.ones((nv,4),np.float32); cc[:,:3]=rgb*0.7; cc[R]=(1,0,0,1)
    cat=m.color_attributes if False else None
    ccn=cc[used]
    ca=nm.color_attributes.new("dbg",'FLOAT_COLOR','POINT'); ca.data.foreach_set('color',ccn.ravel()); nm.color_attributes.active_color=ca
    sc,cam=setup_render(900); sc.display.shading.color_type='VERTEX'
    for a_ in (0,30,60): shot(sc,cam,f"{out}/dbg_{a_}.png",a_,(0.115,-0.38,0.22),0.24)
    raise SystemExit
sc,cam=setup_render(900); sc.display.shading.color_type='TEXTURE'
for a in (-30,0,30,60): shot(sc,cam,f"{out}/zdel_{a}.png",a,(0.115,-0.38,0.22),0.24)
for a in (-30,0,30): shot(sc,cam,f"{out}/ztop_{a}.png",a,(0.11,-0.38,0.29),0.12)
T("rendered")
if os.environ.get("EXPORT","1")=="1":
    bpy.ops.export_scene.gltf(filepath=out+"/A2.glb",export_format='GLB',export_image_format='AUTO')
    T("exported"); print("SIZE",os.path.getsize(out+"/A2.glb"))
