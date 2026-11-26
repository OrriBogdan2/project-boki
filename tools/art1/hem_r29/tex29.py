# tex29.py IN.glb SKIRT_TEX OUT.glb [lin=0.70,0.60,0.80] : Lace r29 skirt texture = a Meshy retexture of the r21 skirt model A
# (same UV as the shipped skirt; r29/m/R*/tex_base_color.png), lining = that texture x a darker wine factor (hem_r23/lintex23 rule).
# gain=R,G,B: scale the texture so its median is that colour (r29: 113,9,30 = live skirt22; R6 at 74,12,29 rendered near-black).
# Images renamed skirt29 / skirt_lining29 so Godot extracts fresh hem_meshy_*.jpg files. Mesh, weights, clips untouched.
import sys,io,subprocess,os,numpy as np
from PIL import Image
sys.path.insert(0,'tools/art1/hem_r17'); import glbio
src,tex,out=sys.argv[1:4]; O=dict(a.split('=') for a in sys.argv[4:]); k=np.array([float(x) for x in O.get('lin','0.70,0.60,0.80').split(',')])
tmp=out+'.tmp'; os.makedirs(tmp,exist_ok=True)
im=Image.open(tex).convert('RGB')
if 'gain' in O:   # per-channel gain so the median = the live skirt red (a darker albedo renders near-black under the toon shader)
    a=np.asarray(im).astype(float); t=np.array([float(x) for x in O['gain'].split(',')]); med=np.median(a.reshape(-1,3),0)
    im=Image.fromarray(np.clip(a*t/np.maximum(med,1),0,255).astype(np.uint8)); print('gain',np.round(t/np.maximum(med,1),2))
im.save(tmp+'/s.jpg',quality=90)
Image.fromarray(np.clip(np.asarray(im).astype(float)*k,0,255).astype(np.uint8)).save(tmp+'/l.jpg',quality=90)
py=sys.executable
subprocess.run([py,'tools/art1/glb_image_swap.py',src,'skirt22',tmp+'/s.jpg',tmp+'/a.glb'],check=True,stdout=subprocess.DEVNULL)
subprocess.run([py,'tools/art1/glb_image_swap.py',tmp+'/a.glb','skirt_lining23',tmp+'/l.jpg',tmp+'/b.glb'],check=True,stdout=subprocess.DEVNULL)
j,b=glbio.load(tmp+'/b.glb')
for i in j['images']:
    i['name']={'skirt22':'skirt29','skirt_lining23':'skirt_lining29'}.get(i['name'],i['name'])
glbio.save(out,j,b); print('wrote',out,'lining median',np.median((np.asarray(im).astype(float)*k).reshape(-1,3),0).astype(int))
