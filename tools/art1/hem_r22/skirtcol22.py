# skirtcol22.py TA2.jpg TA.jpg OUT.jpg [r g b] : skirt base colour from the two r21 Meshy retextures of the same UV (TA2 = matte wine
# 89,8,27 with fabric detail but 12.8% near-black texels and grey specks that drew the "black shredded hem"; TA = 185,8,36 flat
# red, no dark texels). TA2 detail where it is red and not dark, TA where TA2 is dark/grey; both per-channel gained to the live
# skirt median (114,9,31 by default) = tone match to the approved live red, no design change.
import sys,numpy as np
from PIL import Image
a=np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(float); t=np.asarray(Image.open(sys.argv[2]).convert('RGB')).astype(float)
tgt=np.array([float(x) for x in sys.argv[4:7]]) if len(sys.argv)>6 else np.array([114.,9.,31.])
ma=np.median(a.reshape(-1,3),0); mt=np.median(t.reshape(-1,3),0)
A=a*tgt/ma; T=t*tgt/mt
L=a.mean(2); sat=(a[...,0]-np.maximum(a[...,1],a[...,2]))/np.maximum(a[...,0],1)
s=lambda x: np.clip(x,0,1)**2*(3-2*np.clip(x,0,1))
w=s((L-22)/30)*s((sat-0.45)/0.25)
from scipy.ndimage import gaussian_filter
w=gaussian_filter(w,1.5)   # soft seams between the two sources
o=np.clip(w[...,None]*A+(1-w[...,None])*T,0,255)
Image.fromarray(o.astype(np.uint8)).save(sys.argv[3],quality=92)
Lo=o.mean(2); print('src TA2 med',ma.astype(int),'TA med',mt.astype(int),'-> out med',np.median(o.reshape(-1,3),0).astype(int),
  'dark<40 %.1f%% (TA2 %.1f%%), TA share %.1f%%'%(100*(Lo<40).mean(),100*(L<40).mean(),100*(1-w).mean()))
