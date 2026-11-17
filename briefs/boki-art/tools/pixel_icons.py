"""Pixel icons for every Boki, regenerated from the dex hero cut-out (run from the repo root):
python3 briefs/boki-art/tools/pixel_icons.py [Name ...]     (no names = all)
Writes briefs/boki-art/pixel/<size>/<Name>.png (idle frame 1) and <Name>_b.png (idle frame 2, a one-pixel squash) for sizes 32 and 48,
each with a hard alpha edge, a 16-colour palette of its own and a one-pixel dark outline. Re-run after any card change."""
import sys,os,json,numpy as np
from PIL import Image
from scipy import ndimage
A='briefs/boki-art/'; SIZES=(32,48); COLS=16
def icon(hero,size):
    im=Image.open(hero).convert('RGBA'); bb=im.getchannel('A').point(lambda v:255 if v>40 else 0).getbbox(); im=im.crop(bb)
    inner=size-2; s=inner/max(im.size); w,h=max(1,round(im.width*s)),max(1,round(im.height*s))
    # premultiply so transparent pixels do not bleed colour, shrink with a box filter (clean pixel look)
    a=np.asarray(im).astype(np.float32); pm=a.copy(); pm[...,:3]*=a[...,3:]/255.0
    sm=np.asarray(Image.fromarray(pm.astype('uint8'),'RGBA').resize((w,h),Image.BOX)).astype(np.float32)
    al=sm[...,3]; rgb=np.where(al[...,None]>0,sm[...,:3]*255.0/np.maximum(al[...,None],1),0).clip(0,255)
    solid=al>=110
    # a little more contrast and saturation so small shapes read
    g=rgb.mean(2,keepdims=True); rgb=((rgb-g)*1.18+g); rgb=((rgb-128)*1.08+128).clip(0,255)
    q=Image.fromarray(rgb.astype('uint8'),'RGB').quantize(COLS,method=Image.MEDIANCUT,dither=Image.NONE).convert('RGB'); rgb=np.asarray(q).astype(np.uint8)
    out=np.zeros((size,size,4),np.uint8); oy=size-1-h; ox=(size-w)//2   # stand on the bottom edge
    out[oy:oy+h,ox:ox+w,:3]=rgb; out[oy:oy+h,ox:ox+w,3]=solid*255
    m=out[...,3]>0; ring=ndimage.binary_dilation(m)&~m
    dark=(rgb[solid].mean(0)*0.28).astype(np.uint8) if solid.any() else np.array([30,30,40],np.uint8)
    out[ring,:3]=dark; out[ring,3]=255
    return Image.fromarray(out,'RGBA')
def bob(ic):
    a=np.asarray(ic); h=a.shape[0]; ys=np.where(a[...,3].any(1))[0]
    if len(ys)<6: return ic
    t=ys.min(); cut=t+(ys.max()-t)//2; b=np.zeros_like(a); b[cut:]=a[cut:]; b[t+1:cut]=a[t:cut-1]   # top half drops one pixel
    return Image.fromarray(b,'RGBA')
if __name__=='__main__':
    m=json.load(open(A+'LIVE_MANIFEST.json')); names=[x for x in sys.argv[1:]] or list(m)
    for s in SIZES: os.makedirs(A+f'pixel/{s}',exist_ok=True)
    for n in names:
        for s in SIZES:
            ic=icon(m[n]['hero'],s); ic.save(A+f'pixel/{s}/{n}.png'); bob(ic).save(A+f'pixel/{s}/{n}_b.png')
    print(len(names),'Boki, sizes',SIZES)
