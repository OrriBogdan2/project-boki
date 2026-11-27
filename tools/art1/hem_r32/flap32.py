# flap32.py GLB [clips=Jump_Run,run,Idle] : Lace r32 "flap" measure. Per clip frame, outer-skirt verts posed with 8-influence
# skinning vs the same verts moved rigidly with Hips; horizontal deviation (m). Prints per clip the p95/max deviation of the
# upper skirt (rest y > 0.55) and of the hem, and the dominant joint of the worst-moving upper verts.
import sys,numpy as np
sys.path.insert(0,'tools/anim'); sys.path.insert(0,'tools/art1/hem_r17'); import geo_check as g, glbio
src=sys.argv[1]; O=dict(a.split('=') for a in sys.argv[2:]); clips=O.get('clips','Jump_Run,run,Idle,Attack').split(',')
j,b=glbio.load(src); rig=g.Rig(j,b); jn=rig.names; ih=jn.index('Hips')
p=next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name'] in('cloth-skirtmeshy','skirt-meshy'))
A=lambda k: glbio.acc(j,b,p['attributes'][k]); P=A('POSITION').astype(float)
J=np.c_[A('JOINTS_0'),A('JOINTS_1')].astype(int); W=np.c_[A('WEIGHTS_0'),A('WEIGHTS_1')].astype(float)
dom=J[np.arange(len(J)),W.argmax(1)]; up=P[:,1]>0.55; Ph=np.c_[P,np.ones(len(P))]
an={a['name']:a for a in j['animations']}
for c in clips:
    a=an[c]; T=max(glbio.acc(j,b,s['input']).max() for s in [a['samplers'][ch['sampler']] for ch in a['channels']])
    ts=np.linspace(0,T,24); S=rig.skin_mats(a,ts); r=[]
    for f in range(len(ts)):
        M=S[f]; X=np.einsum('vk,vkij,vj->vi',W,M[J],Ph)[:,:3]; H=(Ph@M[ih].T)[:,:3]; d=np.hypot(*(X-H)[:,[0,2]].T); r.append(d)
    r=np.array(r); mu=r[:,up].max(0); worst=np.argsort(-mu)[:200]
    jc=np.bincount(dom[up][worst],minlength=len(jn)); top=np.argsort(-jc)[:3]
    print('%-9s upper p95 %.3f max %.3f | hem p95 %.3f max %.3f | worst upper by %s'%(c,np.percentile(r[:,up],95),r[:,up].max(),
        np.percentile(r[:,~up],95),r[:,~up].max(),', '.join('%s %d'%(jn[t],jc[t]) for t in top)))
