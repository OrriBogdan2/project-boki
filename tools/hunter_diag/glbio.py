import json,struct,numpy as np
CT={5120:np.int8,5121:np.uint8,5122:np.int16,5123:np.uint16,5125:np.uint32,5126:np.float32}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16,'MAT3':9,'MAT2':4}
def load(p):
    b=open(p,'rb').read()
    _,_,_=struct.unpack('<III',b[:12]); o=12; js=None; bin_=None
    while o<len(b):
        l,t=struct.unpack('<II',b[o:o+8]); d=b[o+8:o+8+l]; o+=8+l
        if t==0x4E4F534A: js=json.loads(d)
        elif t==0x004E4942: bin_=d
    return js,bin_
def acc(js,bin_,i):
    a=js['accessors'][i]; bv=js['bufferViews'][a['bufferView']]
    dt=np.dtype(CT[a['componentType']]); n=NC[a['type']]; cnt=a['count']
    off=bv.get('byteOffset',0)+a.get('byteOffset',0); st=bv.get('byteStride',0)
    if st and st!=dt.itemsize*n:
        arr=np.ndarray((cnt,),dtype=np.dtype([('v',dt,(n,))]),buffer=bin_,offset=off,strides=(st,))['v'].copy()
    else:
        arr=np.frombuffer(bin_,dtype=dt,count=cnt*n,offset=off).reshape(cnt,n).copy()
    if a.get('normalized'):
        arr=arr.astype(np.float32)/np.iinfo(dt).max
    return arr
