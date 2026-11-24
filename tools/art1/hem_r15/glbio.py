import json, struct, numpy as np
CT={5120:np.int8,5121:np.uint8,5122:np.int16,5123:np.uint16,5125:np.uint32,5126:np.float32}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def load(p):
    b=open(p,'rb').read(); n=struct.unpack('<I',b[12:16])[0]
    j=json.loads(b[20:20+n]); o=20+n; m=struct.unpack('<I',b[o:o+4])[0]
    return j, bytearray(b[o+8:o+8+m])
def acc(j,bin_,i):
    a=j['accessors'][i]; bv=j['bufferViews'][a['bufferView']]
    dt=np.dtype(CT[a['componentType']]); nc=NC[a['type']]
    off=bv.get('byteOffset',0)+a.get('byteOffset',0); st=bv.get('byteStride',dt.itemsize*nc)
    if st==dt.itemsize*nc:
        return np.frombuffer(bin_,dt,a['count']*nc,off).reshape(a['count'],nc).copy()
    return np.array([np.frombuffer(bin_,dt,nc,off+k*st) for k in range(a['count'])])
def put(j,bin_,i,arr):
    a=j['accessors'][i]; bv=j['bufferViews'][a['bufferView']]
    dt=np.dtype(CT[a['componentType']]); nc=NC[a['type']]
    off=bv.get('byteOffset',0)+a.get('byteOffset',0); st=bv.get('byteStride',dt.itemsize*nc)
    assert st==dt.itemsize*nc
    raw=np.ascontiguousarray(arr.astype(dt)).tobytes(); bin_[off:off+len(raw)]=raw
    if 'min' in a and a['type']=='VEC3' and i is not None and dt==np.float32:
        a['min']=[float(x) for x in arr.min(0)]; a['max']=[float(x) for x in arr.max(0)]
def replace_view(j,bin_,vi,data):
    """replace bufferView vi bytes with data (any length); shifts later views. returns new bin"""
    bv=j['bufferViews'][vi]; o=bv.get('byteOffset',0); L=bv['byteLength']
    pad=(-len(data))%4; data=bytes(data)+b'\0'*pad
    oldpad=(-L)%4; delta=len(data)-(L+oldpad)
    nb=bin_[:o]+bytearray(data)+bin_[o+L+oldpad:]
    bv['byteLength']=len(data)-pad
    for k,v in enumerate(j['bufferViews']):
        if k!=vi and v.get('byteOffset',0)>o: v['byteOffset']=v.get('byteOffset',0)+delta
    j['buffers'][0]['byteLength']=len(nb); return nb
def save(p,j,bin_):
    js=json.dumps(j,separators=(',',':')).encode(); js+=b' '*((-len(js))%4)
    bin_=bytes(bin_)+b'\0'*((-len(bin_))%4); j['buffers'][0]['byteLength']=len(bin_)
    js=json.dumps(j,separators=(',',':')).encode(); js+=b' '*((-len(js))%4)
    out=b'glTF'+struct.pack('<II',2,12+8+len(js)+8+len(bin_))+struct.pack('<I',len(js))+b'JSON'+js+struct.pack('<I',len(bin_))+b'BIN\0'+bin_
    open(p,'wb').write(out)
