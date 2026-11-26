# dark30.py IN OUT [k=0.7] : Lace r30 outer skirt (image skirt29) x a UNIFORM k toward the turnaround's deep wine (ref median
# 77,28,40; skirt29 median 114,9,30). At the game camera the key light lifts the brighter wine to salmon-pink (art-gate GAME DEFECT).
# Renamed skirt30 so Godot extracts a fresh jpg.
import sys,io,os,subprocess,numpy as np
from PIL import Image
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
src,out=sys.argv[1:3]; k=float(dict(a.split('=') for a in sys.argv[3:]).get('k',0.7))
j,b=glbio.load(src); im=next(i for i in j['images'] if i['name']=='skirt29'); bv=j['bufferViews'][im['bufferView']]
o=bv.get('byteOffset',0); a=np.asarray(Image.open(io.BytesIO(bytes(b[o:o+bv['byteLength']]))).convert('RGB')).astype(float)
tmp=out+'.tmp'; os.makedirs(tmp,exist_ok=True); D=np.clip(a*k,0,255).astype(np.uint8); Image.fromarray(D).save(tmp+'/s.jpg',quality=90)
subprocess.run([sys.executable,'tools/art1/glb_image_swap.py',src,'skirt29',tmp+'/s.jpg',tmp+'/b.glb'],check=True,stdout=subprocess.DEVNULL)
j,b=glbio.load(tmp+'/b.glb')
for i in j['images']:
    if i['name']=='skirt29': i['name']='skirt30'
glbio.save(out,j,b)
print('dark30: outer median',np.median(a.reshape(-1,3),0).astype(int),'->',np.median(D.reshape(-1,3),0).astype(int),'->',out)
