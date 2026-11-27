# bodyout34.py GLB OUT.glb : Lace r34. Write the body-retex primitive alone (bind pose, its UVs and texD2) as a plain static glb,
# the input of a Meshy retexture with --original-uv (the corset pass blends only corset texels back, corset34.py).
import sys,io,json,struct; sys.path.insert(0,'tools/art1/hem_r17'); from glbio import *
j,b=load(sys.argv[1])
p=[p for p in j['meshes'][1]['primitives'] if j['materials'][p['material']]['name']=='body-retex'][0]
P=acc(j,b,p['attributes']['POSITION']).astype(np.float32); UV=acc(j,b,p['attributes']['TEXCOORD_0']).astype(np.float32)
F=acc(j,b,p['indices']).reshape(-1).astype(np.uint32)
mat=j['materials'][p['material']]; im=j['images'][j['textures'][mat['pbrMetallicRoughness']['baseColorTexture']['index']]['source']]
bv=j['bufferViews'][im['bufferView']]; tex=bytes(b[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']])
used=np.unique(F); print('verts',len(P),'used',len(used),'tris',len(F)//3)
B=bytearray(); views=[]
def add(raw):
    B.extend(b'\0'*((-len(B))%4)); views.append({'buffer':0,'byteOffset':len(B),'byteLength':len(raw)}); B.extend(raw); return len(views)-1
vp=add(P.tobytes()); vu=add(UV.tobytes()); vi=add(F.tobytes()); vt=add(tex)
g={'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0,'name':'body'}],
 'meshes':[{'primitives':[{'attributes':{'POSITION':0,'TEXCOORD_0':1},'indices':2,'material':0}]}],
 'materials':[{'name':'body','pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':1},'doubleSided':True}],
 'textures':[{'source':0}],'images':[{'bufferView':vt,'mimeType':im.get('mimeType','image/jpeg')}],
 'accessors':[{'bufferView':vp,'componentType':5126,'count':len(P),'type':'VEC3','min':P.min(0).tolist(),'max':P.max(0).tolist()},
  {'bufferView':vu,'componentType':5126,'count':len(UV),'type':'VEC2'},{'bufferView':vi,'componentType':5125,'count':len(F),'type':'SCALAR'}],
 'bufferViews':views,'buffers':[{'byteLength':len(B)}]}
js=json.dumps(g).encode(); js+=b' '*((-len(js))%4); B.extend(b'\0'*((-len(B))%4))
open(sys.argv[2],'wb').write(struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(B))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(B),0x004E4942)+bytes(B))
