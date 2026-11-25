import sys;sys.path.insert(0,__file__.rsplit('/',1)[0]);from glbio import *
j,b=load(sys.argv[1]);sk=j['skins'][0];N=j['nodes'];names=[N[k]['name'] for k in sk['joints']]
bd=j['meshes'][1]['primitives'][2];B=acc(j,b,bd['attributes']['POSITION']).astype(float)
BJ=acc(j,b,bd['attributes']['JOINTS_0']);BW=acc(j,b,bd['attributes']['WEIGHTS_0']);dom=np.array(names)[BJ[np.arange(len(BJ)),BW.argmax(1)]]
core=~np.array([('Arm' in d) or ('Hand' in d) or ('Shoulder' in d) for d in dom])
sp=j['meshes'][4]['primitives'][0];S=acc(j,b,sp['attributes']['POSITION']).astype(float)
c=np.median(B[core&(B[:,1]>0.98)&(B[:,1]<1.04)][:,[0,2]],0);NA=24
def prof(P,y0,y1,f):
    Q=P[(P[:,1]>=y0)&(P[:,1]<=y1)];a=np.arctan2(Q[:,2]-c[1],Q[:,0]-c[0]);r=np.hypot(Q[:,0]-c[0],Q[:,2]-c[1]);k=((a+np.pi)/(2*np.pi)*NA).astype(int)%NA
    return np.array([f(r[k==i]) if (k==i).any() else np.nan for i in range(NA)])
print('skirt top y',S[:,1].max().round(3))
for y0 in (0.96,0.98,1.0,1.02):
    rb=prof(B[core],y0,y0+0.02,np.max);rs=prof(S,y0,y0+0.02,np.min)
    print(y0,'gap cm per 15deg (skirt inner - body outer):',np.round((rs-rb)*100,1))
