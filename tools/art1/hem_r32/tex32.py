# tex32.py IN OUT [flat=0.8 blur=20 k=0.8] : Lace r32 skirt texture pass (r31 art-gate: "red with dark blotches", "dark grey
# ragged piece behind the leg"). Outer skirt image (skirt29): the baked low-frequency shading patches (darker UV islands) are
# flattened toward the image median: out = img - flat*(blur(img) - median), blur = gaussian of radius blur px, so the
# fine weave/strand detail stays and the hue stays the same red. Lining (skirt_lining30) = new outer x k (r30 lin30 used 0.55,
# which reads grey-black behind the leg once the cloth slot removed the salmon). Images renamed skirt32/skirt_lining32 so Godot
# extracts fresh jpgs. Mesh, rig, clips, materials untouched.
import sys,io,os,subprocess,numpy as np
from PIL import Image,ImageFilter
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
src,out=sys.argv[1:3]; O=dict(a.split('=') for a in sys.argv[3:]); fl,bl,k=float(O.get('flat',0.8)),float(O.get('blur',20)),float(O.get('k',0.8))
j,b=glbio.load(src); im=next(i for i in j['images'] if i['name']=='skirt29'); bv=j['bufferViews'][im['bufferView']]
o=bv.get('byteOffset',0); I=Image.open(io.BytesIO(bytes(b[o:o+bv['byteLength']]))).convert('RGB'); a=np.asarray(I).astype(float)
med=np.median(a.reshape(-1,3),0); lo=np.asarray(I.filter(ImageFilter.GaussianBlur(bl))).astype(float)
N=np.clip(a-fl*(lo-med),0,255); L=np.clip(N*k,0,255)
tmp=out+'.tmp'; os.makedirs(tmp,exist_ok=True)
Image.fromarray(N.astype(np.uint8)).save(tmp+'/o.jpg',quality=92); Image.fromarray(L.astype(np.uint8)).save(tmp+'/l.jpg',quality=90)
sw=lambda s,name,img,d: subprocess.run([sys.executable,'tools/art1/glb_image_swap.py',s,name,img,d],check=True,stdout=subprocess.DEVNULL)
sw(src,'skirt29',tmp+'/o.jpg',tmp+'/a.glb'); sw(tmp+'/a.glb','skirt_lining30',tmp+'/l.jpg',tmp+'/b.glb')
j,b=glbio.load(tmp+'/b.glb')
for i in j['images']:
    i['name']={'skirt29':'skirt32','skirt_lining30':'skirt_lining32'}.get(i['name'],i['name'])
glbio.save(out,j,b)
lum=lambda x: x.mean(2)
print('tex32: outer lum p10/p90 %.0f/%.0f -> %.0f/%.0f, lo-freq std %.1f -> %.1f, lining median'%(np.percentile(lum(a),10),np.percentile(lum(a),90),
  np.percentile(lum(N),10),np.percentile(lum(N),90),lum(lo).std(),(lum(lo)*(1-fl)).std()),np.median(L.reshape(-1,3),0).astype(int),'->',out)
