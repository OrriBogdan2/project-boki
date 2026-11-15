exec(open("/home/boki/cj/20261115-193602-a3/tree/ops_tmp_grimble/common.py").read())
import time
t0=time.time()
def T(s): print("T %.0f %s"%(time.time()-t0,s),flush=True)
out="out"; os.makedirs(out,exist_ok=True)
SRC="/home/boki/meshy/v95/Grimble/r5/cg3d1115/A.glb"
ob=load(SRC); m=ob.data
co,vi,uv,vuv,ev=arrays(m); nv=len(co); fv=vi.reshape(-1,3); fuv=uv.reshape(-1,3,2)
px0=imgarr('Image_0'); h0,w0=px0.shape[:2]
ix=np.clip((vuv[:,0]*w0).astype(int),0,w0-1); iy=np.clip((vuv[:,1]*h0).astype(int),0,h0-1)
rgb=px0[iy,ix,:3]
mx=rgb.max(1); mn=rgb.min(1); s=(mx-mn)/np.maximum(mx,1e-5); d=np.maximum(mx-mn,1e-5)
r,g,b=rgb[:,0],rgb[:,1],rgb[:,2]
hue=np.where(mx==r,((g-b)/d)%6,np.where(mx==g,(b-r)/d+2,(r-g)/d+4))*60
gold=(hue>22)&(hue<68)&(s>0.28)&(mx>0.4)
box=(co[:,0]>0.100)&(co[:,0]<0.136)&(co[:,2]>0.105)&(co[:,2]<0.345)&(co[:,1]<-0.30)
seed=gold&box
lab=components(seed,ev,nv)
ids,cnt=np.unique(lab[seed],return_counts=True)
big=ids[cnt>=30]
seed=seed&np.isin(lab,big)
def dilate(mask,k):
    mask=mask.copy()
    for _ in range(k):
        a=mask[ev[:,0]]; bb=mask[ev[:,1]]
        n=mask.copy(); n[ev[a,1]]=True; n[ev[bb,0]]=True; mask=n
    return mask
C=dilate(seed,int(os.environ.get("DIL","2")))
C&=(co[:,0]>0.095)&(co[:,0]<0.141)&(co[:,1]<-0.28)
T("seed %d C %d"%(seed.sum(),C.sum()))
print("C bbox",co[C].min(0),co[C].max(0))
# harmonic flatten
bnd=dilate(C,1)&~C
newco=co.copy()
e=ev[C[ev[:,0]]|C[ev[:,1]]]
deg=np.zeros(nv,np.float32); np.add.at(deg,e[:,0],1); np.add.at(deg,e[:,1],1)
# init: C verts from boundary mean
P=co.copy(); P[C]=co[bnd].mean(0)
for it in range(1500):
    acc=np.zeros((nv,3),np.float32)
    np.add.at(acc,e[:,0],P[e[:,1]]); np.add.at(acc,e[:,1],P[e[:,0]])
    P[C]=acc[C]/np.maximum(deg[C],1)[:,None]
newco=P
disp=np.linalg.norm(newco-co,axis=1)
print("max disp",disp.max(),"mean C",disp[C].mean())
m.vertices.foreach_set('co',newco.ravel()); m.update()
# normals: recompute smooth vertex normals for loops near C
near=dilate(C,3)
# face normals from new positions
v0,v1,v2=newco[fv[:,0]],newco[fv[:,1]],newco[fv[:,2]]
fn=np.cross(v1-v0,v2-v0)
vn=np.zeros((nv,3),np.float32)
for k in range(3): np.add.at(vn,fv[:,k],fn)
vn/=np.maximum(np.linalg.norm(vn,axis=1),1e-9)[:,None]
cn=np.zeros(len(m.loops)*3,np.float32); m.corner_normals.foreach_get('vector',cn); cn=cn.reshape(-1,3)
sel=near[vi]
cn[sel]=vn[vi[sel]]
m.normals_split_custom_set(cn.tolist())
T("geom done")
# texture mask
faces_in=C[fv].any(1)
def raster(tris,w,h):
    M=np.zeros((h,w),bool)
    for tri in tris:
        P=np.stack([tri[:,0]*w,(1-tri[:,1])*h],1)
        x0=int(max(np.floor(P[:,0].min()),0)); x1=int(min(np.ceil(P[:,0].max())+1,w)); y0=int(max(np.floor(P[:,1].min()),0)); y1=int(min(np.ceil(P[:,1].max())+1,h))
        if x1<=x0 or y1<=y0: continue
        X,Y=np.meshgrid(np.arange(x0,x1)+0.5,np.arange(y0,y1)+0.5)
        (ax,ay),(bx,by),(cx,cy)=P
        den=(by-cy)*(ax-cx)+(cx-bx)*(ay-cy)
        if abs(den)<1e-9:
            continue
        l1=((by-cy)*(X-cx)+(cx-bx)*(Y-cy))/den; l2=((cy-ay)*(X-cx)+(ax-cx)*(Y-cy))/den; l3=1-l1-l2
        e=-0.02
        M[y0:y1,x0:x1]|=(l1>=e)&(l2>=e)&(l3>=e)
    return M
def dil2d(M,k):
    for _ in range(k):
        N=M.copy(); N[1:]|=M[:-1]; N[:-1]|=M[1:]; M=N
        N=M.copy(); N[:,1:]|=M[:,:-1]; N[:,:-1]|=M[:,1:]; M=N
    return M
def box1(a,ax,r):
    c=np.cumsum(np.pad(a,[(r+1,r) if i==ax else (0,0) for i in range(a.ndim)],mode='edge'),axis=ax)
    n=a.shape[ax]
    sl=lambda lo,hi:tuple(slice(lo,hi) if i==ax else slice(None) for i in range(a.ndim))
    return (c[sl(2*r+1,2*r+1+n)]-c[sl(0,n)])/(2*r+1)
def blur(a,r,it=3):
    for _ in range(it): a=box1(box1(a,0,r),1,r)
    return a
def inpaint_img(name,pd=5):
    im=bpy.data.images[name]; w,h=im.size
    arr=np.array(im.pixels[:],dtype=np.float32).reshape(h,w,4)
    M=raster(fuv[faces_in],w,h); M=dil2d(M,pd)
    ys,xs=np.where(M)
    print(name,"mask px",M.sum(),"bbox",xs.min(),xs.max(),ys.min(),ys.max())
    pad=64
    y0,y1=max(ys.min()-pad,0),min(ys.max()+pad,h); x0,x1=max(xs.min()-pad,0),min(xs.max()+pad,w)
    sub=arr[y0:y1,x0:x1,:3].copy(); sm=M[y0:y1,x0:x1]
    known=(~sm).astype(np.float32)
    levels=[(sub*known[...,None],known)]
    while min(levels[-1][1].shape)>2:
        a,wt=levels[-1]
        H2,W2=a.shape[0]//2*2,a.shape[1]//2*2
        a2=a[:H2,:W2].reshape(H2//2,2,W2//2,2,3).sum((1,3)); w2=wt[:H2,:W2].reshape(H2//2,2,W2//2,2).sum((1,3))
        levels.append((a2,w2))
    fill=None
    for a,wt in reversed(levels):
        col=a/np.maximum(wt,1e-6)[...,None]
        if fill is not None:
            up=np.repeat(np.repeat(fill,2,0),2,1)
            pu=np.zeros(a.shape,np.float32); hh=min(up.shape[0],a.shape[0]); ww=min(up.shape[1],a.shape[1])
            pu[:hh,:ww]=up[:hh,:ww]; 
            if hh<a.shape[0]: pu[hh:]=pu[hh-1:hh]
            if ww<a.shape[1]: pu[:,ww:]=pu[:,ww-1:ww]
            col=np.where((wt>0)[...,None],col,pu)
        fill=col
    fill=blur(fill,3)
    res=np.where(sm[...,None],fill,sub)
    arr[y0:y1,x0:x1,:3]=res
    im.pixels.foreach_set(arr.ravel()); im.update()
for n in ('Image_0','Image_1','Image_2'): inpaint_img(n); T(n)
# normal map: leave inpainted
# render before/after check
sc,cam=setup_render(900); sc.display.shading.color_type='TEXTURE'
for a in (-30,0,30,60): shot(sc,cam,f"{out}/zA2_{a}.png",a,(0.115,-0.38,0.22),0.24)
T("rendered")
bpy.ops.export_scene.gltf(filepath=out+"/A2.glb",export_format='GLB',export_image_format='AUTO',export_apply=False)
T("exported")
print("SIZE",os.path.getsize(out+"/A2.glb"))
