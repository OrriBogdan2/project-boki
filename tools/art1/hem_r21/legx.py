# legx.py IN.glb OUT.glb : export the leg-meshy prim (bind pose, own UV + texture) as a standalone glb for Meshy retexture upload
import sys,io,json,struct,numpy as np
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
j,b=glbio.load(sys.argv[1])
p=next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name']=='leg-meshy')
P=glbio.acc(j,b,p['attributes']['POSITION']).astype('<f4'); uv=glbio.acc(j,b,p['attributes']['TEXCOORD_0']).astype('<f4'); F=glbio.acc(j,b,p['indices']).astype('<u4').ravel()
t=j['materials'][p['material']]['pbrMetallicRoughness']['baseColorTexture']['index']; im=j['images'][j['textures'][t]['source']]
bv=j['bufferViews'][im['bufferView']]; o=bv.get('byteOffset',0); img=bytes(b[o:o+bv['byteLength']])
blobs=[P.tobytes(),uv.tobytes(),F.tobytes(),img]; bvs=[]; off=0; bin_=b''
for x in blobs:
    pad=(-len(bin_))%4; bin_+=b'\0'*pad; bvs.append({'buffer':0,'byteOffset':len(bin_),'byteLength':len(x)}); bin_+=x
bin_+=b'\0'*((-len(bin_))%4)
g={'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0,'name':'legs'}],
 'meshes':[{'primitives':[{'attributes':{'POSITION':0,'TEXCOORD_0':1},'indices':2,'material':0}]}],
 'materials':[{'name':'leg','pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':0.8}}],
 'textures':[{'source':0}],'images':[{'bufferView':3,'mimeType':im.get('mimeType','image/jpeg')}],'bufferViews':bvs,'buffers':[{'byteLength':len(bin_)}],
 'accessors':[{'bufferView':0,'componentType':5126,'count':len(P),'type':'VEC3','min':P.min(0).tolist(),'max':P.max(0).tolist()},
  {'bufferView':1,'componentType':5126,'count':len(uv),'type':'VEC2'},{'bufferView':2,'componentType':5125,'count':len(F),'type':'SCALAR'}]}
js=json.dumps(g).encode(); js+=b' '*((-len(js))%4)
out=struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(bin_))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(bin_),0x004E4942)+bin_
open(sys.argv[2],'wb').write(out); print('legs',len(P),'verts',len(F)//3,'tris ->',sys.argv[2])
