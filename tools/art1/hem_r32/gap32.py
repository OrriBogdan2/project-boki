# gap32.py GLB [clips=...] : Lace r32 slit/flap gap. Outer skirt posed (8 influences), relative to Hips (yaw removed via Hips
# matrix inverse), per height band of the REST pose: the largest empty angular sector (deg) around the hip axis. Rest pose row
# first, then per clip the max over 24 frames. A slit "open to the hip" = a wide gap in the top bands.
import sys,numpy as np
sys.path.insert(0,'tools/anim'); sys.path.insert(0,'tools/art1/hem_r17'); import geo_check as g, glbio
src=sys.argv[1]; O=dict(a.split('=') for a in sys.argv[2:]); clips=O.get('clips','Jump_Run,run,Idle,Attack,walk,Crouch_Walk_with_Torch').split(',')
j,b=glbio.load(src); rig=g.Rig(j,b); jn=rig.names; ih=jn.index('Hips')
p=next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name'] in('cloth-skirtmeshy','skirt-meshy'))
A=lambda k: glbio.acc(j,b,p['attributes'][k]); P=A('POSITION').astype(float); Ph=np.c_[P,np.ones(len(P))]
J=np.c_[A('JOINTS_0'),A('JOINTS_1')].astype(int); W=np.c_[A('WEIGHTS_0'),A('WEIGHTS_1')].astype(float)
bands=[(0.85,0.98),(0.75,0.85),(0.65,0.75),(0.55,0.65),(0.45,0.55)]
G=rig.skin_mats(None,np.zeros(1))[0]@np.linalg.inv(rig.ibm); hc=G[ih][:3,3]
def gaps(X):
    out=[]
    for lo,hi in bands:
        m=(P[:,1]>=lo)&(P[:,1]<hi); a=np.sort(np.degrees(np.arctan2(X[m,0]-hc[0],X[m,2]-hc[2])))
        d=np.diff(np.r_[a,a[0]+360]); k=d.argmax(); out.append((d[k],(a[k]+d[k]/2+180)%360-180))
    return out
print('bands (rest y):',' '.join('%.2f-%.2f'%bd for bd in bands))
print('%-22s'%'rest',' '.join('%5.1f@%4.0f'%x for x in gaps(P)))
an={a['name']:a for a in j['animations']}
for c in clips:
    a=an[c]; T=max(glbio.acc(j,b,a['samplers'][ch['sampler']]['input']).max() for ch in a['channels'])
    ts=np.linspace(0,T,24); S=rig.skin_mats(a,ts); worst=None
    for f in range(len(ts)):
        M=S[f]; X=np.einsum('vk,vkij,vj->vi',W,M[J],Ph)[:,:3]
        Hi=M[ih]@G[ih]; X=(np.c_[X,np.ones(len(X))]@np.linalg.inv(Hi).T)[:,:3]; X=(np.c_[X,np.ones(len(X))]@G[ih].T)[:,:3]
        gg=gaps(X); worst=gg if worst is None else [max(u,v) for u,v in zip(worst,gg)]
    print('%-22s'%c,' '.join('%5.1f@%4.0f'%x for x in worst))
