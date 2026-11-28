#!/usr/bin/env python3
"""Cut a Meshy tube's ragged open end and close it with a flat cap, editing the .glb's buffers in place (no Blender).

Albert r44 (11-28): arm38_L/R, the upper-arm tubes, end at the elbow in a ragged fan of shard triangles with a partial
cap. With the elbow bent (idle) the end shows beside the forearm gauntlet and its inside draws as black ink wedges.
This drops every triangle past a plane across the tube, rings the new cut and closes it with a centre fan of new
vertices (the ring's skin and UVs, normal along the tube), so the cap shades like wood and the ink shell closes. The old
cap39_wood-arms38 piece (the same fan of shards) loses its mesh.

  python3 tools/art1/glb_cap_arm_ends.py IN.glb OUT.glb "NAME:cx;cy;cz:nx;ny;nz:s0" ...
  (glTF coords, y up: c a point on the axis near the end, n the axis pointing out of the end, s0 the cut in metres
  along n.) Albert: "arm38_L:0.646;0.754;0.045:0.719;-0.683;0.126:-0.03"
  "arm38_R:-0.647;0.731;0.037:-0.756;-0.65;0.085:-0.03"
numpy only; appends new buffer views, never touches the textures or the clips.
"""
import json
import struct
import sys
import collections
import numpy as np
def load(p):
    d=open(p,'rb').read()
    magic,ver,ln=struct.unpack('<III',d[:12]); assert magic==0x46546C67
    off=12; chunks=[]
    while off<len(d):
        cl,ct=struct.unpack('<II',d[off:off+8]); chunks.append([ct,d[off+8:off+8+cl]]); off+=8+cl
    j=json.loads(chunks[0][1]); return j,chunks
def save(p,j,chunks):
    jb=json.dumps(j,separators=(',',':')).encode()
    while len(jb)%4: jb+=b' '
    chunks[0][1]=jb
    body=b''.join(struct.pack('<II',len(c),ct)+c for ct,c in chunks)
    open(p,'wb').write(struct.pack('<III',0x46546C67,2,12+len(body))+body)
CT={5120:'b',5121:'B',5122:'h',5123:'H',5125:'I',5126:'f'}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def acc_view(j,chunks,i):
    a=j['accessors'][i]; bv=j['bufferViews'][a['bufferView']]
    dt=np.dtype('<'+CT[a['componentType']]); n=NC[a['type']]
    off=bv.get('byteOffset',0)+a.get('byteOffset',0)
    stride=bv.get('byteStride',0)
    buf=chunks[1][1]
    if stride and stride!=dt.itemsize*n:
        raise Exception('strided')
    arr=np.frombuffer(buf,dtype=dt,count=a['count']*n,offset=off).reshape(a['count'],n)
    return a,arr,off


src,dst=sys.argv[1],sys.argv[2]
spec=[a.split(':') for a in sys.argv[3:]]   # name:cx;cy;cz:nx;ny;nz:s0
j,ch=load(src); buf=bytearray(ch[1][1])
def app(arr,target):
    global buf
    while len(buf)%4: buf.append(0)
    off=len(buf); buf+=arr.tobytes()
    j['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':arr.nbytes,'target':target})
    return len(j['bufferViews'])-1
for nm,cs,ns,s0 in spec:
    c=np.array([float(x) for x in cs.split(';')]); m=np.array([float(x) for x in ns.split(';')]); m/=np.linalg.norm(m); s0=float(s0)
    node=[n for n in j['nodes'] if n.get('name')==nm][0]
    p=j['meshes'][node['mesh']]['primitives'][0]; at=p['attributes']
    A={k:acc_view(j,ch,v)[1] for k,v in at.items()}; P=A['POSITION']
    ia=j['accessors'][p['indices']]; _,I,_=acc_view(j,ch,p['indices']); tri=I.reshape(-1,3).astype(np.int64)
    s=(P-c)@m
    keep=tri[(s[tri].max(1)<=s0)]
    print(nm,'tris',len(tri),'kept',len(keep))
    key={}; pid=np.zeros(len(P),int)
    for i,q in enumerate(np.round(P,5)): pid[i]=key.setdefault(tuple(q),len(key))
    rep={}
    for i in range(len(P)): rep.setdefault(pid[i],i)
    E=collections.Counter(); D={}
    for a,b,cc in keep:
        for u,v in((a,b),(b,cc),(cc,a)):
            x,y=pid[u],pid[v]
            if x!=y: E[(min(x,y),max(x,y))]+=1
    ring=set()
    for (x,y),n in E.items():
        if n==1 and (s[rep[x]]>s0-0.04 and s[rep[y]]>s0-0.04): ring|={x,y}
    ring=sorted(ring); R=np.array([P[rep[v]] for v in ring]); cen=R.mean(0)
    u,sv,vt=np.linalg.svd(R-cen)
    ang=np.arctan2((R-cen)@vt[1],(R-cen)@vt[0]); order=np.argsort(ang); ring=[ring[i] for i in order]
    # winding: normal along +m
    Rr=np.array([P[rep[v]] for v in ring])
    nsum=sum(np.cross(Rr[i]-cen,Rr[(i+1)%len(Rr)]-cen) for i in range(len(Rr)))
    if nsum@m<0: ring=ring[::-1]
    n0=len(P); extra={k:[] for k in A}
    def newv(sp,pos=None):
        for k in A: extra[k].append(A[k][rep[sp]].copy())
        extra['NORMAL'][-1]=m.astype(np.float32)
        if pos is not None: extra['POSITION'][-1]=pos.astype(np.float32)
        return n0+len(extra['POSITION'])-1
    ctr=newv(ring[0],cen); rv=[newv(v) for v in ring]
    idx=[]
    for i in range(len(rv)): idx+=[ctr,rv[i],rv[(i+1)%len(rv)]]
    allI=np.concatenate([keep.reshape(-1),np.array(idx,dtype=np.int64)]).astype(np.uint32)
    for k,v in at.items():
        a=j['accessors'][v]; old=A[k]; new=np.concatenate([old,np.array(extra[k],dtype=old.dtype)])
        a['bufferView']=app(new,34962); a['byteOffset']=0; a['count']=len(new)
        if k=='POSITION': a['min']=new.min(0).tolist(); a['max']=new.max(0).tolist()
    ia['bufferView']=app(allI,34963); ia['byteOffset']=0; ia['componentType']=5125; ia['count']=len(allI)
    print(nm,'ring',len(ring),'planarity',round(float(np.abs((Rr-cen)@vt[2]).max()),3),'cap tris',len(idx)//3)
for n in j['nodes']:
    if n.get('name')=='cap39_wood-arms38': n.pop('mesh',None); n.pop('skin',None)
ch[1][1]=bytes(buf); j['buffers'][0]['byteLength']=len(buf); save(dst,j,ch)
