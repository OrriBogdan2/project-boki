exec(open("/home/boki/cj/20261115-193602-a3/tree/ops_tmp_grimble/common.py").read())
ob=load("/home/boki/meshy/v95/Grimble/r5/cg3d1115/A.glb"); m=ob.data
co,vi,uv,vuv,ev=arrays(m); nv=len(co)
px=imgarr('Image_0'); h,w=px.shape[:2]
ix=np.clip((vuv[:,0]*w).astype(int),0,w-1); iy=np.clip((vuv[:,1]*h).astype(int),0,h-1)
rgb=px[iy,ix,:3]; gold=hsv_gold(rgb)
for zc in (0.13,0.17,0.22,0.26,0.30,0.33):
    sl=(np.abs(co[:,2]-zc)<0.0012)&(co[:,0]>0.085)&(co[:,0]<0.15)&(co[:,1]<-0.25)
    print("Z",zc,"n",sl.sum())
    for x0 in np.arange(0.085,0.15,0.005):
        s=sl&(co[:,0]>=x0)&(co[:,0]<x0+0.005)
        if not s.any(): continue
        ys=np.sort(co[s,1]); 
        # clusters
        cl=[];st=ys[0];pv=ys[0]
        for y in ys[1:]:
            if y-pv>0.003: cl.append((st,pv)); st=y
            pv=y
        cl.append((st,pv))
        print("  x%.3f"%x0,"gold%d/%d"%(gold[s].sum(),s.sum())," ".join("[%.3f..%.3f]"%c for c in cl))
