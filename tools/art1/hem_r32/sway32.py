# sway32.py IN OUT [amp=Jump_Run:0.4,run:0.5,*:1 bones=SkirtSw slit=Jump_Run:1,*:1 cut=SkirtSw2:0.3] : Lace r32. The hem sway bones (SkirtSw0-7,
# children of Hips) swing the hem 0.25-0.32 m (p95, vs Hips-rigid) in Jump_Run/run, so at the game camera the skirt fans out
# like a cape and reads as 2-3 separate flaps (r30/r31 review). Per clip (first substring match, '*' = default) every key of
# those bones is scaled toward the BIND pose: local L = Lb @ D, D's rotation vector and translation x amp (Lb = bind local
# = inv(G_parent_bind) @ G_bind from the inverse bind matrices). slit= does the same for SkirtSlitA/B. New keys are appended
# as fresh accessors; mesh, weights, textures and all other channels untouched.
import sys,numpy as np
sys.path.insert(0,'tools/anim'); sys.path.insert(0,'tools/art1/hem_r17'); import geo_check as g, glbio
from scipy.spatial.transform import Rotation as Rot
src,out=sys.argv[1:3]; O=dict(a.split('=') for a in sys.argv[3:])
kv=lambda s:[(x.split(':')[0],float(x.split(':')[1])) for x in s.split(',') if x]
def look(L,name):
    for k,v in L:
        if k=='*' or k.lower() in name.lower(): return v
    return 1.0
AMP=kv(O.get('amp','Jump_Run:0.4,run:0.5,*:1')); SL=kv(O.get('slit','*:1')); CUT=dict(kv(O.get('cut','')))
# cut=BONE:c (default 1) scales the cut per bone: amp_bone = 1-(1-amp)*c, so c 0 keeps that bone's full sway.
j,b=glbio.load(src); rig=g.Rig(j,b); b=bytearray(bytes(b)); jn=rig.names; nn=j['nodes']
par={c:i for i,nd in enumerate(nn) for c in nd.get('children',[])}
skin=j['skins'][0]; jnode=skin['joints']; Gb={n:np.linalg.inv(rig.ibm[k]) for k,n in enumerate(jnode)}
def append(arr,typ):
    raw=np.ascontiguousarray(arr.astype(np.float32)).tobytes(); b.extend(b'\0'*((-len(b))%4)); off=len(b); b.extend(raw)
    j['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':len(raw)})
    j['accessors'].append({'bufferView':len(j['bufferViews'])-1,'componentType':5126,'count':len(arr),'type':typ}); return len(j['accessors'])-1
tgt={}
for ni in jnode:
    n=nn[ni].get('name','')
    if n.startswith(O.get('bones','SkirtSw')): tgt[ni]='sw'
    elif n in('SkirtSlitA','SkirtSlitB'): tgt[ni]='slit'
for an in j['animations']:
    for ni,kind in tgt.items():
        a=look(AMP if kind=='sw' else SL,an['name']); a=1-(1-a)*CUT.get(nn[ni]['name'],1.0)
        if abs(a-1)<1e-6: continue
        Lb=np.linalg.inv(Gb[par[ni]])@Gb[ni]; Rb=Rot.from_matrix(Lb[:3,:3]); chs={c['target']['path']:c for c in an['channels'] if c['target']['node']==ni}
        if 'rotation' not in chs: continue
        sr=an['samplers'][chs['rotation']['sampler']]; q=glbio.acc(j,b,sr['output']).astype(float)
        D=(Rb.inv()*Rot.from_quat(q)).as_rotvec()*a; q2=(Rb*Rot.from_rotvec(D)).as_quat(); q2*=np.sign(q2[:,3:4]+1e-9)
        sr['output']=append(q2,'VEC4')
        if 'translation' in chs:
            st=an['samplers'][chs['translation']['sampler']]; t=glbio.acc(j,b,st['output']).astype(float)
            st['output']=append(Lb[:3,3]+(t-Lb[:3,3])*a,'VEC3')
    print(an['name'],'sw amp %.2f slit amp %.2f'%(look(AMP,an['name']),look(SL,an['name'])))
j['buffers'][0]['byteLength']=len(b); glbio.save(out,j,b); print('wrote',out)
