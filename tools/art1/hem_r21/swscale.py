# swscale.py IN OUT k [clips=all] : SkirtSw* rotation keys slerped toward the bone's rest rotation by factor k (k=1 unchanged, 0 = rest).
# Written in place in the key accessors (mesh, skin and every other track byte-identical).
import sys,numpy as np
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
src,out,k=sys.argv[1],sys.argv[2],float(sys.argv[3]); only=sys.argv[4].split(',') if len(sys.argv)>4 else None
j,b=glbio.load(src); nodes=j['nodes']
def slerp(a,c,t):
    d=(a*c).sum(1,keepdims=True); c=np.where(d<0,-c,c); d=np.abs(d)
    th=np.arccos(np.clip(d,-1,1)); s=np.sin(th); w0=np.where(s>1e-6,np.sin((1-t)*th)/np.where(s>1e-6,s,1),1-t); w1=np.where(s>1e-6,np.sin(t*th)/np.where(s>1e-6,s,1),t)
    q=w0*a+w1*c; return q/np.linalg.norm(q,axis=1,keepdims=True)
done=set(); n=0
for an in j['animations']:
    if only and an['name'] not in only: continue
    for ch in an['channels']:
        nd=ch['target'].get('node'); 
        if nd is None or ch['target']['path']!='rotation' or not nodes[nd].get('name','').startswith('SkirtSw'): continue
        ai=an['samplers'][ch['sampler']]['output']
        if ai in done: continue
        done.add(ai); q=glbio.acc(j,b,ai).astype(float); r=np.array(nodes[nd].get('rotation',[0,0,0,1]),float)[None].repeat(len(q),0)
        glbio.put(j,b,ai,slerp(r,q,k).astype(np.float32)); n+=1
glbio.save(out,j,b); print('scaled',n,'SkirtSw rotation tracks by',k,'->',out)
