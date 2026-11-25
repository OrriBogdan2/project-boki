import sys,io,numpy as np
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
from PIL import Image
j,b=glbio.load(sys.argv[1])
def img(i):
    im=j['images'][i]; bv=j['bufferViews'][im['bufferView']]; o=bv.get('byteOffset',0)
    return np.asarray(Image.open(io.BytesIO(bytes(b[o:o+bv['byteLength']]))).convert('RGB'))
nodes=j['nodes']; skin=j['skins'][0]; jn=[nodes[k].get('name') for k in skin['joints']]
def samp(prim):
    mat=j['materials'][prim['material']]; t=mat['pbrMetallicRoughness']['baseColorTexture']['index']
    I=img(j['textures'][t]['source']); h,w,_=I.shape
    uv=glbio.acc(j,b,prim['attributes']['TEXCOORD_0']); J=glbio.acc(j,b,prim['attributes']['JOINTS_0']); W=glbio.acc(j,b,prim['attributes']['WEIGHTS_0'])
    top=J[np.arange(len(J)),W.argmax(1)]
    px=I[np.clip((uv[:,1]%1*h).astype(int),0,h-1),np.clip((uv[:,0]%1*w).astype(int),0,w-1)]
    return top,px,mat['name']
for mi,me in enumerate(j['meshes']):
    for pi,p in enumerate(me['primitives']):
        try: top,px,mn=samp(p)
        except Exception as e: continue
        groups={}
        for k in ['Arm','ForeArm','UpLeg','Leg','Hips','Spine','Hand']:
            sel=np.array([ (k in jn[t]) and not (k=='Arm' and 'Fore' in jn[t]) and not(k=='Leg' and 'Up' in jn[t]) for t in top])
            if sel.sum()>50:
                v=px[sel].astype(float); L=v.mean(1)
                groups[k]=(int(sel.sum()),np.median(v,0).astype(int).tolist(),int(np.percentile(L,25)),int(np.percentile(L,75)))
        print(me['name'],pi,mn,groups)
