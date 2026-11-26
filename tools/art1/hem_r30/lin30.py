# lin30.py IN OUT [k=0.55] : Lace r30 lining = the glb's own outer skirt image (skirt29) x a UNIFORM factor k (no hue shift; r29's
# 0.85,0.70,0.90 read as a pale-pink flap). Swapped into skirt_lining29 and renamed skirt_lining30 so Godot extracts a fresh jpg.
import sys,io,os,subprocess,numpy as np
from PIL import Image
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
src,out=sys.argv[1:3]; k=float(dict(a.split('=') for a in sys.argv[3:]).get('k',0.55))
j,b=glbio.load(src); im=next(i for i in j['images'] if i['name']=='skirt29'); bv=j['bufferViews'][im['bufferView']]
o=bv.get('byteOffset',0); a=np.asarray(Image.open(io.BytesIO(bytes(b[o:o+bv['byteLength']]))).convert('RGB')).astype(float)
tmp=out+'.tmp'; os.makedirs(tmp,exist_ok=True); L=np.clip(a*k,0,255).astype(np.uint8); Image.fromarray(L).save(tmp+'/l.jpg',quality=90)
subprocess.run([sys.executable,'tools/art1/glb_image_swap.py',src,'skirt_lining29',tmp+'/l.jpg',tmp+'/b.glb'],check=True,stdout=subprocess.DEVNULL)
j,b=glbio.load(tmp+'/b.glb')
for i in j['images']:
    if i['name']=='skirt_lining29': i['name']='skirt_lining30'
glbio.save(out,j,b)
print('lin30: outer median',np.median(a.reshape(-1,3),0).astype(int),'lining median',np.median(L.reshape(-1,3),0).astype(int),'->',out)
