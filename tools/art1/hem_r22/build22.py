# build22.py SHIPPED.glb WEIGHTS_FROM.glb SKIRT_TEX.jpg OUT.glb : r22 = shipped r21e glb with (1) the skirt-meshy JOINTS/WEIGHTS 0+1
# taken from WEIGHTS_FROM (same skirt vertex order: legfollow21 on r21c) and (2) the skirt-meshy base colour image replaced.
# Every other byte (meshes, other prims, clips, other textures) stays as shipped.
import sys,numpy as np
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
base,wf,tex,out=sys.argv[1:5]
j,b=glbio.load(base); j2,b2=glbio.load(wf)
sk=lambda j: next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name']=='skirt-meshy')
p,p2=sk(j),sk(j2)
assert np.array_equal(glbio.acc(j,b,p['attributes']['POSITION']),glbio.acc(j2,b2,p2['attributes']['POSITION'])), 'skirt verts differ'
for k in ('JOINTS_0','JOINTS_1','WEIGHTS_0','WEIGHTS_1'): b=glbio.put(j,b,p['attributes'][k],glbio.acc(j2,b2,p2['attributes'][k])) or b
ti=j['materials'][p['material']]['pbrMetallicRoughness']['baseColorTexture']['index']; im=j['images'][j['textures'][ti]['source']]
users=[m['name'] for m in j['materials'] if m.get('pbrMetallicRoughness',{}).get('baseColorTexture',{}).get('index')==ti]
assert users==['skirt-meshy'], users
r=glbio.replace_view(j,b,im['bufferView'],open(tex,'rb').read()); b=r if r is not None else b
im['name']='skirt22'; im['mimeType']='image/jpeg'
glbio.save(out,j,b); print('built',out,'image',im['name'])
