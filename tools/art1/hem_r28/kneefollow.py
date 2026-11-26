# kneefollow.py IN OUT [s=0.5 rx=0.10 ry=0.12 legs=L,R] : Lace r28, local add-on to the skirt weights (written in place on the
# shared skirt-meshy/lining23 accessors; mesh, textures, clips untouched). The knee ball pokes through the skirt panel at the jump
# apex / dash / run (poke22: run 2.5 cm, Jump_Run 1.3 cm, rest y 0.49-0.61). Skirt verts in front of each knee
# (rest; z > knee z, elliptic window rx (x) by ry (y) around the knee) get an extra share w = s*smoothstep(1-d), d = window radius, of that leg's UpLeg (others scaled by 1-w), so the cloth
# over the knee moves with the thigh. Run BEFORE gusset.py so the under-panel inherits the weights.
import sys,numpy as np
sys.path.insert(0,'tools/anim'); sys.path.insert(0,'tools/art1/hem_r17'); import geo_check as g, glbio
src,out=sys.argv[1:3]; O=dict(a.split('=') for a in sys.argv[3:]); f=lambda k,d: float(O.get(k,d))
s,rx,ry=f('s',0.5),f('rx',0.10),f('ry',0.12); legs=O.get('legs','L,R').split(',')
j,b=glbio.load(src); b=bytearray(bytes(b)); rig=g.Rig(j,b); jn=rig.names
p=next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name']=='skirt-meshy')
A=lambda k: glbio.acc(j,b,p['attributes'][k]); P=A('POSITION').astype(float)
J=np.c_[A('JOINTS_0'),A('JOINTS_1')].astype(int); W=np.c_[A('WEIGHTS_0'),A('WEIGHTS_1')].astype(float)
G=rig.skin_mats(None,np.zeros(1))[0]@np.linalg.inv(rig.ibm)            # rest global joint matrices
n=len(P); D=np.zeros((n,len(jn))); np.add.at(D,(np.repeat(np.arange(n),8),J.ravel()),W.ravel())
for L in legs:
    side={'L':'Left','R':'Right'}[L]; ik,iu=jn.index(side+'Leg'),jn.index(side+'UpLeg'); k=G[ik][:3,3].copy()
    d=np.hypot((P[:,0]-k[0])/rx,(P[:,1]-k[1])/ry); t=np.clip(1-d,0,1)*(P[:,2]>k[2]); w=s*t*t*(3-2*t)
    print('%s knee at %s: verts w>0.05 %d, mean old UpLeg share there %.2f'%(side,np.round(k,3),(w>0.05).sum(),D[w>0.05,iu].mean() if (w>0.05).any() else 0))
    D*=(1-w)[:,None]; D[:,iu]+=w
o=np.argsort(-D,1)[:,:8]; ww=np.take_along_axis(D,o,1); ww/=ww.sum(1,keepdims=True)
for k_,arr in (('JOINTS_0',o[:,:4]),('JOINTS_1',o[:,4:]),('WEIGHTS_0',ww[:,:4]),('WEIGHTS_1',ww[:,4:])):
    a=j['accessors'][p['attributes'][k_]]; dt={5121:np.uint8,5123:np.uint16,5126:np.float32}[a['componentType']]; glbio.put(j,b,p['attributes'][k_],arr.astype(dt))
glbio.save(out,j,b); print('wrote',out)
