"""Drops the accessors and buffer bytes nothing references (glb_add_clips leaves a replaced clip's old data behind), changing nothing else.
Run: python3 tools/art1/glb_compact.py in.glb out.glb"""
import sys,json,struct
b=open(sys.argv[1],'rb').read(); n=struct.unpack('<I',b[12:16])[0]; j=json.loads(b[20:20+n]); at=20+n; m=struct.unpack('<I',b[at:at+4])[0]; bn=b[at+8:at+8+m]
ref=set()
for me in j['meshes']:
    for p in me['primitives']:
        ref|=set(p['attributes'].values())
        if 'indices' in p: ref.add(p['indices'])
        for t in p.get('targets',[]): ref|=set(t.values())
for sk in j.get('skins',[]):
    if 'inverseBindMatrices' in sk: ref.add(sk['inverseBindMatrices'])
for an in j.get('animations',[]):
    for sm in an['samplers']: ref|={sm['input'],sm['output']}
am={}; na=[]
for i,a in enumerate(j['accessors']):
    if i in ref: am[i]=len(na); na.append(a)
for me in j['meshes']:
    for p in me['primitives']:
        p['attributes']={k:am[v] for k,v in p['attributes'].items()}
        if 'indices' in p: p['indices']=am[p['indices']]
        for t in p.get('targets',[]):
            for k in t: t[k]=am[t[k]]
for sk in j.get('skins',[]):
    if 'inverseBindMatrices' in sk: sk['inverseBindMatrices']=am[sk['inverseBindMatrices']]
for an in j.get('animations',[]):
    for sm in an['samplers']: sm['input']=am[sm['input']]; sm['output']=am[sm['output']]
j['accessors']=na
used=set()
for a in j['accessors']:
    if 'bufferView' in a: used.add(a['bufferView'])
    sp=a.get('sparse')
    if sp: used.add(sp['indices']['bufferView']); used.add(sp['values']['bufferView'])
for im in j.get('images',[]):
    if 'bufferView' in im: used.add(im['bufferView'])
new=bytearray(); remap={}; nbv=[]
for i,bv in enumerate(j['bufferViews']):
    if i not in used: continue
    while len(new)%4: new+=b'\0'
    d=bn[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]
    nb=dict(bv); nb['byteOffset']=len(new); new+=d; remap[i]=len(nbv); nbv.append(nb)
for a in j['accessors']:
    if 'bufferView' in a: a['bufferView']=remap[a['bufferView']]
    sp=a.get('sparse')
    if sp:
        for k in ('indices','values'): sp[k]['bufferView']=remap[sp[k]['bufferView']]
for im in j.get('images',[]):
    if 'bufferView' in im: im['bufferView']=remap[im['bufferView']]
j['bufferViews']=nbv; j['buffers'][0]['byteLength']=len(new)
while len(new)%4: new+=b'\0'
js=json.dumps(j,separators=(',',':')).encode(); js+=b' '*(-len(js)%4)
open(sys.argv[2],'wb').write(struct.pack('<4sII',b'glTF',2,12+8+len(js)+8+len(new))+struct.pack('<I4s',len(js),b'JSON')+js+struct.pack('<I4s',len(new),b'BIN\0')+new)
