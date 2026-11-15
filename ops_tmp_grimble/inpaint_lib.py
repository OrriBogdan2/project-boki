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
def inpaint_img(name,tris,pd=5):
    im=bpy.data.images[name]; w,h=im.size
    arr=np.array(im.pixels[:],dtype=np.float32).reshape(h,w,4)
    M=raster(tris,w,h); M=dil2d(M,pd)
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
