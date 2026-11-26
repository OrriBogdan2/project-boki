# curtain30.py IN OUT [ylo=0.30 yhi=0.88 dz=0.0 inset=0.006 cols=8] : Lace r30. Replaces the r28/r29 slit godet (a membrane
# skinned to the slit EDGES, 10-15 cm in front of the right thigh: the swinging thigh crossed it = white "shards" in the front slit)
# with a wine curtain BETWEEN the legs. Per height row: the right leg's inner-most point and the left leg's inner-most point (verts
# of any non-skirt prim dominated by Right*/Left* UpLeg/Leg), `inset` m into the gap; the row spans them at the legs' mid depth + dz.
# Edge verts copy the skin of their leg vertex, inner verts blend the two (top 4 renormalised), so each edge rides its own leg and
# the sheet stays between the legs: it fills the slit V seen from the game camera (ground otherwise shows) and can't pass in front
# of the thigh. Material skirt-godet30 = a copy of skirt-liner (solid wine texture), UV at the texture middle.
import sys,numpy as np
sys.path.insert(0,'tools/anim'); sys.path.insert(0,'tools/art1/hem_r17'); import geo_check as g, glbio
src,out=sys.argv[1:3]; O=dict(a.split('=') for a in sys.argv[3:]); f=lambda k,d: float(O.get(k,d))
ylo,yhi,dz,ins,nc=f('ylo',0.30),f('yhi',0.88),f('dz',0.0),f('inset',0.006),int(f('cols',8))
j,b=glbio.load(src); b=bytearray(bytes(b)); rig=g.Rig(j,b); jn=np.array(rig.names)
host=next(m for m in j['meshes'] if any(j['materials'][p['material']]['name']=='leg-meshy' for p in m['primitives'])); mats=j['materials']; mi=lambda nm: next(i for i,m in enumerate(mats) if m['name']==nm)
for m in j['meshes']:
    n0=len(m['primitives'])
    m['primitives']=[p for p in m['primitives'] if not ((mats[p['material']]['name'].startswith('skirt-lining') or mats[p['material']]['name'].startswith('skirt-godet')) and j['accessors'][p['attributes']['POSITION']]['count']<5000)]
    if n0!=len(m['primitives']): print('godet prims dropped:',n0-len(m['primitives'])); host=m
# leg points from every non-skirt prim
PS,JS,WS=[],[],[]
for m in j['meshes']:
    for p in m['primitives']:
        if mats[p['material']]['name'].startswith('skirt') or 'JOINTS_0' not in p['attributes']: continue
        A=lambda k: glbio.acc(j,b,p['attributes'][k])
        P=A('POSITION').astype(float); J=A('JOINTS_0').astype(int); W=A('WEIGHTS_0').astype(float)
        if 'JOINTS_1' in p['attributes']: J=np.hstack([J,A('JOINTS_1').astype(int)]); W=np.hstack([W,A('WEIGHTS_1').astype(float)])
        J=np.pad(J,((0,0),(0,8-J.shape[1]))); W=np.pad(W,((0,0),(0,8-W.shape[1]))); PS.append(P); JS.append(J); WS.append(W)
P=np.vstack(PS); J=np.vstack(JS); W=np.vstack(WS); dom=jn[J[np.arange(len(J)),W.argmax(1)]]
R=np.isin(dom,['RightUpLeg','RightLeg']); L=np.isin(dom,['LeftUpLeg','LeftLeg'])
def sk4(Jv,Wv):
    acc={}
    for jj,ww in zip(Jv,Wv):
        if ww>0: acc[jj]=acc.get(jj,0)+ww
    t=sorted(acc.items(),key=lambda x:-x[1])[:4]; t+= [(0,0.0)]*(4-len(t)); s=sum(w for _,w in t)
    return [x for x,_ in t],[w/s for _,w in t]
V,UJ,UW,rows=[],[],[],0
for y in np.arange(ylo,yhi+1e-6,0.02):
    s=np.abs(P[:,1]-y)<0.012; r=s&R; l=s&L
    if not r.any() or not l.any(): continue
    ir=np.where(r)[0][P[r,0].argmax()]; il=np.where(l)[0][P[l,0].argmin()]
    zr=np.median(P[r,2]); zl=np.median(P[l,2]); xr=P[ir,0]+ins; xl=P[il,0]-ins
    if xl-xr<0.01: continue
    for c in range(nc+1):
        t=c/nc; V.append([xr+(xl-xr)*t,y,(zr+(zl-zr)*t)+dz])
        jj,ww=sk4(np.r_[J[ir],J[il]],np.r_[W[ir]*(1-t),W[il]*t]); UJ.append(jj); UW.append(ww)
    rows+=1
V=np.array(V); UJ=np.array(UJ); UW=np.array(UW); F=[]
for r_ in range(rows-1):
    for c in range(nc):
        a=r_*(nc+1)+c; F+=[[a,a+1,a+nc+2],[a,a+nc+2,a+nc+1]]
F=np.array(F)
N=np.tile([0,0,1.0],(len(V),1)); UV=np.tile([0.5,0.5],(len(V),1))
if not any(m['name']=='skirt-godet30' for m in mats):
    nm=dict(mats[mi('skirt-liner')]); nm['name']='skirt-godet30'; nm['doubleSided']=True; mats.append(nm)
EXT=bytearray()
def add(arr,typ,ct=5126,target=None):
    dt={5126:np.float32,5123:np.uint16,5125:np.uint32}[ct]; raw=np.ascontiguousarray(arr.astype(dt)).tobytes()
    EXT.extend(b'\0'*((-(len(b)+len(EXT)))%4)); o=len(b)+len(EXT); EXT.extend(raw); bv={'buffer':0,'byteOffset':o,'byteLength':len(raw)}
    if target: bv['target']=target
    j['bufferViews'].append(bv); a={'bufferView':len(j['bufferViews'])-1,'componentType':ct,'count':len(arr),'type':typ}
    if typ=='VEC3' and target==34962: a['min']=[float(x) for x in arr.min(0)]; a['max']=[float(x) for x in arr.max(0)]
    j['accessors'].append(a); return len(j['accessors'])-1
at={'POSITION':add(V,'VEC3',target=34962),'NORMAL':add(N,'VEC3',target=34962),'TEXCOORD_0':add(UV,'VEC2',target=34962),
    'JOINTS_0':add(UJ,'VEC4',5123,34962),'WEIGHTS_0':add(UW,'VEC4',target=34962)}
host['primitives'].append({'attributes':at,'indices':add(F.ravel(),'SCALAR',5125,34963),'material':mi('skirt-godet30'),'mode':4})
b=b+EXT; j['buffers'][0]['byteLength']=len(b); glbio.save(out,j,b)
print('curtain30: rows %d verts %d tris %d  x %.3f..%.3f  y %.2f..%.2f  z %.3f..%.3f -> %s'%(rows,len(V),len(F),V[:,0].min(),V[:,0].max(),V[:,1].min(),V[:,1].max(),V[:,2].min(),V[:,2].max(),out))
