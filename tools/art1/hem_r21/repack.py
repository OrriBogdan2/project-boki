# repack.py IN OUT : rewrite the BIN chunk with only the bufferViews accessors/images still use (orphans from grafts dropped). Data bytes unchanged.
import sys,json,struct
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
j,b=glbio.load(sys.argv[1]); used=sorted({a['bufferView'] for a in j['accessors'] if 'bufferView' in a}|{i['bufferView'] for i in j['images'] if 'bufferView' in i})
mp={}; nb=bytearray(); nv=[]
for k in used:
    v=dict(j['bufferViews'][k]); o=v.get('byteOffset',0); nb+=b'\0'*((-len(nb))%8 if v.get('byteStride') else (-len(nb))%4)
    d=b[o:o+v['byteLength']]; v['byteOffset']=len(nb); nb+=d; mp[k]=len(nv); nv.append(v)
for a in j['accessors']:
    if 'bufferView' in a: a['bufferView']=mp[a['bufferView']]
for i in j['images']:
    if 'bufferView' in i: i['bufferView']=mp[i['bufferView']]
j['bufferViews']=nv; nb+=b'\0'*((-len(nb))%4); j['buffers'][0]['byteLength']=len(nb)
js=json.dumps(j,separators=(',',':')).encode(); js+=b' '*((-len(js))%4)
open(sys.argv[2],'wb').write(struct.pack('<III',0x46546C67,2,28+len(js)+len(nb))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(nb),0x004E4942)+bytes(nb))
print('bufferViews',len(used),'bin',len(b),'->',len(nb))
