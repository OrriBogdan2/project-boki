# count open boundary loops (holes) of a glb primitive: loops by edge count + vertical extent
import sys,numpy as np
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
from collections import defaultdict
j,b=glbio.load(sys.argv[1]); mi=int(sys.argv[2]); pi=int(sys.argv[3])
p=j['meshes'][mi]['primitives'][pi]; P=glbio.acc(j,b,p['attributes']['POSITION']); F=glbio.acc(j,b,p['indices']).reshape(-1,3)
# weld by position
key=np.round(P/1e-4).astype(np.int64); _,inv=np.unique(key,axis=0,return_inverse=True); inv=inv.ravel(); F=inv[F]; 
Pw=np.zeros((inv.max()+1,3)); Pw[inv]=P
E=np.sort(np.concatenate([F[:,[0,1]],F[:,[1,2]],F[:,[2,0]]]),1); u,c=np.unique(E,axis=0,return_counts=True); bd=u[c==1]
adj=defaultdict(list)
for a,bb in bd: adj[a].append(bb); adj[bb].append(a)
seen=set(); loops=[]
for v in adj:
    if v in seen: continue
    st=[v]; comp=[]
    while st:
        x=st.pop()
        if x in seen: continue
        seen.add(x); comp.append(x); st+=adj[x]
    loops.append(comp)
up=1 if len(sys.argv)<5 else int(sys.argv[4])
L=[(len(c),float(np.ptp(Pw[c][:,up])),float(np.ptp(Pw[c][:,0]))) for c in loops]; L.sort(reverse=True)
print('tris',len(F),'boundary edges',len(bd),'loops',len(L))
print('biggest',[tuple(round(x,3) for x in l) for l in L[:6]])
small=[l for l in L if l[0]<200]; print('small loops (<200 edges):',len(small),' 8-200 edges:',sum(1 for l in small if l[0]>=8))
