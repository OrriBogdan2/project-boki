"""Normalise a card's backdrop to the spec colour #E8E8EE without touching the creature (run from the repo root):
python3 briefs/boki-art/tools/flat_card.py Name ...      (or --all-off to do every live card whose backdrop is more than 10 levels off)
Uses the same soft cut-out as the dex hero (with the pale-fur fix), then lays the creature back on flat #E8E8EE. Prints the names it changed."""
import sys,os,json,numpy as np
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__))); sys.path.insert(0,os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','batch'))
from cutout_v2 import cutout
from PIL import Image
from scipy import ndimage
SPEC=np.array([232,232,238],np.float32)
def off(path):
    a=np.asarray(Image.open(path).convert('RGB')).astype(int)
    b=np.concatenate([a[:8].reshape(-1,3),a[-8:].reshape(-1,3),a[:,:8].reshape(-1,3),a[:,-8:].reshape(-1,3)]); return int(np.abs(np.median(b,0)-SPEC).max())
def flatten(path):
    im=Image.open(path).convert('RGB'); a=np.asarray(im).astype(np.float32); rgba=np.array(cutout(im)).astype(np.float32)
    border=np.concatenate([a[:4].reshape(-1,3),a[-4:].reshape(-1,3),a[:,:4].reshape(-1,3),a[:,-4:].reshape(-1,3)]); bg=np.median(border,0); diff=np.abs(a-bg).sum(2)
    al=rgba[...,3]/255.0; tr=al<0.5; lab,k=ndimage.label(tr); edge=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
    if k:
        means=ndimage.mean(diff,lab,range(1,k+1)); solid=[i+1 for i in range(k) if (i+1) not in edge and means[i]>=5.0]
        if solid:
            msk=ndimage.binary_dilation(np.isin(lab,solid),iterations=2); al[msk]=1.0; rgba[msk,:3]=a[msk]
    out=rgba[...,:3]*al[...,None]+SPEC*(1-al[...,None]); Image.fromarray(out.clip(0,255).astype('uint8')).save(path,quality=93)
if __name__=='__main__':
    m=json.load(open('briefs/boki-art/LIVE_MANIFEST.json'))
    names=[n for n in m if off(m[n]['card'])>10] if '--all-off' in sys.argv else [x for x in sys.argv[1:] if not x.startswith('--')]
    for n in names: flatten(m[n]['card'])
    print(' '.join(names))
