import sys,json,numpy as np,io
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection
from matplotlib.colors import LinearSegmentedColormap
from PIL import Image,ImageDraw
from rig import Glb
ROOT='/home/boki/cj/20261119-145816-a5/tree/art/wardens/'
cm=LinearSegmentedColormap.from_list('h',[(0,'#8a8a8a'),(0.15,'#d8c85a'),(0.4,'#f08a1c'),(1,'#e01010')])
def render(g,X,vr,az,flip=False,size=(540,720)):
    a=np.radians(az); R=np.array([[np.cos(a),0,-np.sin(a)],[0,1,0],[np.sin(a),0,np.cos(a)]])
    Y=X@R.T   # rotate about y ; camera looks down -z? depth = z
    T=g.T; tri=Y[T]; depth=tri[:,:,2].mean(1)
    n=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]); n/=np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-12)
    shade=0.55+0.45*np.abs(n@np.array([0.3,0.5,0.8])/1.0)
    if vr is None: col=np.stack([shade*0.78]*3,1)
    else:
        h=np.clip((vr[T].mean(1)-1.0)/3.0,0,1); c=cm(h)[:,:3]; col=c*shade[:,None]
    o=np.argsort(depth)
    fig=plt.figure(figsize=(size[0]/100,size[1]/100),dpi=100); ax=fig.add_axes([0,0,1,1]); ax.set_facecolor('#20202c'); fig.patch.set_facecolor('#20202c')
    ax.add_collection(PolyCollection(tri[o][:,:,:2],facecolors=col[o],edgecolors='none',antialiaseds=False))
    ymin,ymax=g.P[:,1].min(),g.P[:,1].max(); hh=(ymax-ymin)*1.08; cx=0; 
    ax.set_xlim(cx-hh*size[0]/size[1]/2,cx+hh*size[0]/size[1]/2); ax.set_ylim(ymin-0.04*hh,ymin-0.04*hh+hh); ax.axis('off')
    buf=io.BytesIO(); fig.savefig(buf,format='png',dpi=100,facecolor=fig.get_facecolor()); plt.close(fig)
    return Image.open(io.BytesIO(buf.getvalue())).convert('RGB')
def run(h,az):
    g=Glb(ROOT+f'{h}/{h}.glb'); s=json.load(open(f'stretch_{h}.json'))
    cx=float(np.median(g.P[:,0]))
    g.P[:,0]-=0  # no-op
    Xb=g.skin(g.pose_globals(g.rest)); 
    # centre on body x/z
    ctr=np.array([np.median(Xb[:,0]),0,np.median(Xb[:,2])])
    gp=Xb-ctr
    pan=[]
    pb=render(g,gp,None,az)
    if s.get('noclips'):
        pw=Image.new('RGB',(540,720),(32,32,44)); ImageDraw.Draw(pw).text((20,350),'no clips in this glb (plays the retargeted rig)',fill=(200,200,200)); cap=f'{h}: no glb clips; heatmap n/a'
        pi=pw
    else:
        d=np.load(f'worst_{h}.npz'); X=d['X']-ctr; vr=d['vr']
        pi=render(g,X,None,az)    # the same worst frame, plain
        pw=render(g,X,vr,az)
        e=s['edge_max_pct']; cap=f"{h}  worst frame: {s['worst']['clip']} t={s['worst']['t']:.2f}s  max x{e['max']:.1f}  p95 x{e['p95']:.2f}  edges>2x {e['gt2']}"
    gi=Image.open(f'gpu/{h}/idle_3q.png').convert('RGB').resize((540,720)); gb=Image.open(f'gpu/{h}/bind_3q.png').convert('RGB').resize((540,720))
    W=Image.new('RGB',(540*4,720+60),(20,20,28)); 
    for i,im in enumerate((gb,gi,pi,pw)): W.paste(im,(i*540,60))
    d=ImageDraw.Draw(W)
    for i,t in enumerate(('bind pose (game, no clip)','idle (game)','worst-stretch frame (plain)','worst-stretch frame, heatmap: grey x1 -> red x4+')):
        d.text((i*540+10,38),t,fill=(230,230,230))
    d.text((10,10),cap,fill=(255,255,255))
    W.save(f'sheets/{h}.png'); return h
if __name__=='__main__':
    az=float(sys.argv[1]); 
    for h in sys.argv[2:]: print(run(h,az),flush=True)
