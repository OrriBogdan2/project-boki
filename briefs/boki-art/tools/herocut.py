"""Dex hero cut-out with the 'pale fur goes see-through' bug fixed.
cutout_v2 treats any enclosed pale area (white chest fur, porcelain) as a background hole. Here an enclosed area only stays transparent
when its colour really is the background's (mean difference under 5); anything else is part of the creature and is made solid again.
Use: from herocut import hero; hero(card_path).save(out_png)"""
import sys,os,numpy as np
sys.path.insert(0,os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','batch'))
from cutout_v2 import cutout,frame
from PIL import Image
from scipy import ndimage
def hero(card_path,report=False):
    im=Image.open(card_path).convert('RGB'); rgba=np.array(cutout(im)); a=np.asarray(im).astype(np.float32)
    border=np.concatenate([a[:4].reshape(-1,3),a[-4:].reshape(-1,3),a[:,:4].reshape(-1,3),a[:,-4:].reshape(-1,3)]); bg=np.median(border,0)
    diff=np.abs(a-bg).sum(2); tr=rgba[...,3]<128; lab,k=ndimage.label(tr)
    edge=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}; fixed=0
    if k:
        means=ndimage.mean(diff,lab,range(1,k+1))
        solid=[i+1 for i in range(k) if (i+1) not in edge and means[i]>=5.0]
        if solid:
            msk=ndimage.binary_dilation(np.isin(lab,solid),iterations=2)&(rgba[...,3]<255)
            rgba[msk,:3]=a[msk].astype(np.uint8); rgba[msk,3]=255; fixed=int(msk.sum())
    out=frame(Image.fromarray(rgba,'RGBA'))
    return (out,fixed) if report else out
