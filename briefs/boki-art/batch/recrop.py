# Centre a portrait's creature and scale it to fill ~88% of the square (Pokedex-style framing).
import numpy as np, cv2, sys
from PIL import Image
def recrop(im, fill=0.88, out_size=2048):
    a=np.array(im.convert('RGB')); h,w=a.shape[:2]
    corners=np.concatenate([a[:20,:20].reshape(-1,3),a[:20,-20:].reshape(-1,3),a[-20:,:20].reshape(-1,3),a[-20:,-20:].reshape(-1,3)])
    bg=np.median(corners,0)
    diff=np.abs(a.astype(int)-bg).sum(2)
    m=(diff>40).astype(np.uint8); m=cv2.morphologyEx(m,cv2.MORPH_OPEN,np.ones((5,5),np.uint8))
    n,lab,st,_=cv2.connectedComponentsWithStats(m)
    big=[i for i in range(1,n) if st[i][4]>0.002*h*w]
    if not big: return im
    x0=min(st[i][0] for i in big); y0=min(st[i][1] for i in big)
    x1=max(st[i][0]+st[i][2] for i in big); y1=max(st[i][1]+st[i][3] for i in big)
    side=int(max(x1-x0,y1-y0)/fill); cx=(x0+x1)//2; cy=(y0+y1)//2
    # paste into a bg-coloured canvas so we can crop past the edges
    pad=side; c=np.zeros((h+2*pad,w+2*pad,3),np.uint8); c[:]=bg.astype(np.uint8); c[pad:pad+h,pad:pad+w]=a
    l=cx-side//2+pad; t=cy-side//2+pad
    crop=Image.fromarray(c[t:t+side,l:l+side])
    return crop.resize((out_size,out_size),Image.LANCZOS)
if __name__=='__main__':
    for f in sys.argv[1:]:
        recrop(Image.open(f)).save(f,quality=92)
