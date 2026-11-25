# legtone.py IN.glb OUT.glb [texfile] : put a new leg-meshy base-colour image into the glb (mesh bytes untouched).
# No texfile: per-channel gain so the median leg texel under the leg verts matches the median forearm/hand porcelain texel.
import sys,io,json,struct,numpy as np
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
from PIL import Image
j,b=glbio.load(sys.argv[1])
def img(t):
    im=j['images'][j['textures'][t]['source']]; bv=j['bufferViews'][im['bufferView']]; o=bv.get('byteOffset',0)
    return np.asarray(Image.open(io.BytesIO(bytes(b[o:o+bv['byteLength']]))).convert('RGB')),j['textures'][t]['source']
jn=[j['nodes'][k]['name'] for k in j['skins'][0]['joints']]
def samp(p,names):
    I,_=img(j['materials'][p['material']]['pbrMetallicRoughness']['baseColorTexture']['index']); h,w,_=I.shape
    uv=glbio.acc(j,b,p['attributes']['TEXCOORD_0']); J=glbio.acc(j,b,p['attributes']['JOINTS_0']); W=glbio.acc(j,b,p['attributes']['WEIGHTS_0'])
    top=np.array([jn[t] for t in J[np.arange(len(J)),W.argmax(1)]]); sel=np.array([any(n in t for n in names) for t in top])
    return I[np.clip((uv[sel,1]%1*h).astype(int),0,h-1),np.clip((uv[sel,0]%1*w).astype(int),0,w-1)].astype(float)
prims={j['materials'][p['material']]['name']:p for me in j['meshes'] for p in me['primitives']}
arm=samp(prims['body-retex'],['ForeArm','Hand']); lp=prims['leg-meshy']; leg=samp(lp,['Leg'])
ta=np.median(arm,0); tl=np.median(leg,0); print('arm median',ta.astype(int),'leg median before',tl.astype(int))
li,src=img(lp['material'] and j['materials'][lp['material']]['pbrMetallicRoughness']['baseColorTexture']['index'])
if len(sys.argv)>3: new=np.asarray(Image.open(sys.argv[3]).convert('RGB').resize((li.shape[1],li.shape[0]),Image.LANCZOS))
else: new=np.clip(li.astype(float)*(ta/tl),0,255).astype(np.uint8)
bio=io.BytesIO(); Image.fromarray(new).save(bio,'JPEG',quality=92); data=bio.getvalue()
# append the image as a new bufferView at the end of the bin, repoint the image
o=len(b); b+=b'\0'*((-o)%4); o=len(b); b+=data; j['bufferViews'].append({'buffer':0,'byteOffset':o,'byteLength':len(data)})
j['images'][src]={'bufferView':len(j['bufferViews'])-1,'mimeType':'image/jpeg','name':j['images'][src].get('name','leg20')+'_r21'}
# drop the old image bufferView bytes? keep (tiny); compact afterwards with ../hem_r19/compact19.py if wanted
b+=b'\0'*((-len(b))%4); j['buffers'][0]['byteLength']=len(b)
js=json.dumps(j,separators=(',',':')).encode(); js+=b' '*((-len(js))%4)
open(sys.argv[2],'wb').write(struct.pack('<III',0x46546C67,2,28+len(js)+len(b))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(b),0x004E4942)+bytes(b))
j2,b2=glbio.load(sys.argv[2]); j,b=j2,b2; prims={j['materials'][p['material']]['name']:p for me in j['meshes'] for p in me['primitives']}
print('leg median after',np.median(samp(prims['leg-meshy'],['Leg']),0).astype(int))
