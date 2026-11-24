import json,struct,io
def load(p):
    b=open(p,'rb').read()
    jl,_=struct.unpack_from('<II',b,12); j=json.loads(b[20:20+jl]); off=20+jl
    bl=struct.unpack_from('<I',b,off)[0]; bin_=b[off+8:off+8+bl]
    return j,bin_
def img(j,bin_,i):
    bv=j['bufferViews'][j['images'][i]['bufferView']]
    return bin_[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]
import numpy as np
CT={5126:'f4',5123:'u2',5125:'u4',5121:'u1',5120:'i1',5122:'i2'}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def acc(j,b,i):
    a=j['accessors'][i]; bv=j['bufferViews'][a['bufferView']]
    n=NC[a['type']]; dt=np.dtype(CT[a['componentType']])
    st=bv.get('byteStride',n*dt.itemsize)
    o=bv.get('byteOffset',0)+a.get('byteOffset',0)
    arr=np.ndarray((a['count'],n),dt,b,o,(st,dt.itemsize)) if st!=n*dt.itemsize else np.frombuffer(b,dt,a['count']*n,o).reshape(-1,n)
    return arr.copy()
def prims(j,b,mesh=0):
    out=[]
    for p in j['meshes'][mesh]['primitives']:
        pos=acc(j,b,p['attributes']['POSITION']); idx=acc(j,b,p['indices'])[:,0].reshape(-1,3)
        out.append((pos,idx,p.get('material'),p))
    return out
