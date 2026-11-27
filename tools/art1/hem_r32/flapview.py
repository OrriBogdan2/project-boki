# flapview.py GLB OUT.png clip:t[,clip:t...] : game-camera-direction orthographic dot plot of the posed outer skirt, coloured by
# each vert's dominant joint (R UpLeg red, L UpLeg blue, SlitA green, SlitB yellow, Hips white, sway bones greys). Debug view.
import sys,numpy as np
from PIL import Image,ImageDraw
sys.path.insert(0,'tools/anim'); sys.path.insert(0,'tools/art1/hem_r17'); import geo_check as g, glbio
src,out=sys.argv[1:3]; shots=[(s.split(':')[0],float(s.split(':')[1])) for s in sys.argv[3].split(',')]
j,b=glbio.load(src); rig=g.Rig(j,b); jn=rig.names
p=next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name'] in('cloth-skirtmeshy','skirt-meshy'))
A=lambda k: glbio.acc(j,b,p['attributes'][k]); P=A('POSITION').astype(float); Ph=np.c_[P,np.ones(len(P))]
J=np.c_[A('JOINTS_0'),A('JOINTS_1')].astype(int); W=np.c_[A('WEIGHTS_0'),A('WEIGHTS_1')].astype(float); dom=J[np.arange(len(J)),W.argmax(1)]
col={'RightUpLeg':(230,40,40),'LeftUpLeg':(60,90,240),'SkirtSlitA':(40,200,60),'SkirtSlitB':(240,220,40),'Hips':(255,255,255)}
C=np.array([col.get(jn[d],(70+20*int(jn[d][-1]) if jn[d].startswith('SkirtSw') else 128,)*3) for d in dom])
an={a['name']:a for a in j['animations']}; v=np.array([0,21,9.4.__float__()]); v/=np.linalg.norm(v)
xa=np.array([1.,0,0]); ya=np.cross(v,xa); S=320; im=Image.new('RGB',(S*len(shots),S),(40,70,40)); d=ImageDraw.Draw(im)
for k,(c,t) in enumerate(shots):
    M=rig.skin_mats(an[c],np.array([t]))[0]; X=np.einsum('vk,vkij,vj->vi',W,M[J],Ph)[:,:3]
    X-= (Ph@M[jn.index('Hips')].T)[:,:3].mean(0)*[1,0,1]
    depth=X@v; o=np.argsort(depth)  # far first
    u=X@xa; w=X@ya
    for i in o[::3]: d.point((k*S+S/2+u[i]*230,S/2-w[i]*230),fill=tuple(int(q) for q in C[i]))
    d.text((k*S+4,4),'%s %.2f'%(c,t),fill=(255,255,255))
im.save(out); print('wrote',out)
