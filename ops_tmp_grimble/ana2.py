import sys; sys.path.insert(0,os.path.dirname(__file__)) if False else None
exec(open("/home/boki/cj/20261115-193602-a3/tree/ops_tmp_grimble/common.py").read())
out="out"; os.makedirs(out,exist_ok=True)
ob=load("/home/boki/meshy/v95/Grimble/r5/cg3d1115/A.glb"); m=ob.data
co,vi,uv,vuv,ev=arrays(m); nv=len(co)
px=imgarr('Image_0'); h,w=px.shape[:2]
ix=np.clip((vuv[:,0]*w).astype(int),0,w-1); iy=np.clip((vuv[:,1]*h).astype(int),0,h-1)
rgb=px[iy,ix,:3]; gold=hsv_gold(rgb)
# face-region only to limit
reg=(co[:,2]>0.05)&(co[:,2]<0.5)&(np.abs(co[:,0])<0.3)&(co[:,1]<0)
g=gold&reg
lab=components(g,ev,nv)
ids,cnt=np.unique(lab[g],return_counts=True)
order=np.argsort(-cnt)
cols=[(1,0,0),(0,1,0),(0,0.3,1),(1,0,1),(0,1,1),(1,0.5,0),(0.5,0,1),(1,1,1)]
cc=np.zeros((nv,4),np.float32); cc[:,:3]=rgb; cc[:,3]=1; cc[:,:3]*=0.6
for k,i in enumerate(order[:30]):
    s=lab==ids[i]
    print("COMP",k,"n",cnt[i],"x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f]"%(co[s,0].min(),co[s,0].max(),co[s,1].min(),co[s,1].max(),co[s,2].min(),co[s,2].max()))
    if k<8: cc[s,:3]=cols[k]
c=m.color_attributes.new("dbg",'FLOAT_COLOR','POINT'); c.data.foreach_set('color',cc.ravel()); m.color_attributes.active_color=c
sc,cam=setup_render(900); sc.display.shading.color_type='VERTEX'
for a in (-35,0,35): shot(sc,cam,f"{out}/comp_{a}.png",a,(0,0,0.28),0.6)
