import sys,json,re,numpy as np,time
from rig import *
ROOT='/home/boki/cj/20261119-145816-a5/tree/art/wardens/'
NF=10; MIN_EDGE=0.008
def group(b):
    side=''
    m=re.search(r'\.([LR])$',b)
    if m: side='.'+m.group(1); b=b[:-2]
    if b.startswith('spring_'): return 'spring:'+b
    for k in ('upper_arm','forearm','hand','fingers','thumb','thigh','shin','foot','pauldron','head','lid','brow','mouth'):
        if b.startswith(k): return k+side
    return b+side
def run(h):
    g=Glb(ROOT+f'{h}/{h}.glb')
    jn=[g.name[j] for j in g.joints]
    # dominant bone per vertex (sum weights per joint index)
    dom=np.zeros(len(g.P),int); 
    acc_=np.zeros((len(g.P),len(jn)))
    for c in range(4): np.add.at(acc_,(np.arange(len(g.P)),g.J[:,c]),g.W[:,c])
    dom=acc_.argmax(1)
    grp=np.array([group(jn[d]) for d in dom])
    E=np.concatenate([g.T[:,[0,1]],g.T[:,[1,2]],g.T[:,[2,0]]]); E=np.sort(E,1); E=np.unique(E,axis=0)
    L0=np.linalg.norm(g.P[E[:,0]]-g.P[E[:,1]],axis=1)
    cnt={}
    for p in g.prim: cnt[p[0]]=cnt.get(p[0],0)+p[2]
    bm=max(cnt,key=cnt.get); body=np.array([p[0]==bm for p in g.prim for _ in range(p[2])])
    keep=body[E[:,0]]&body[E[:,1]]&(L0>=MIN_EDGE)&~np.char.startswith(grp[E[:,0]],'spring')&~np.char.startswith(grp[E[:,1]],'spring')
    E=E[keep];L0=L0[keep]
    g1=grp[E[:,0]];g2=grp[E[:,1]]
    lab=np.where(g1==g2,g1,np.where(g1<g2,np.char.add(np.char.add(g1,'|'),g2),np.char.add(np.char.add(g2,'|'),g1)))
    # which verts have any hand weight
    height=float(g.P[:,1].max()-g.P[:,1].min())
    res={'h':h,'verts':len(g.P),'tris':len(g.T),'edges':len(E),'height':height,'clips':{}}
    emax=np.zeros(len(E)); eclip=np.zeros(len(E),int); clipnames=sorted(g.anims)
    best=None
    if not g.anims:
        json.dump({'h':h,'noclips':True,'tris':len(g.T),'joints':jn},open(f'stretch_{h}.json','w')); return h
    pervclip={}
    for ci,cn in enumerate(clipnames):
        T=g.clip_len(cn); 
        cm=np.zeros(len(E))
        for k in range(NF):
            tt=T*k/(NF-1)
            X,gr=g.skin(g.pose_globals(g.sample(cn,tt)),True)
            L=np.linalg.norm(X[E[:,0]]-X[E[:,1]],axis=1); r=L/L0/(0.5*(gr[E[:,0]]+gr[E[:,1]]))
            cm=np.maximum(cm,r)
            score=((r>2)&(L>0.03)).sum()
            if best is None or score>best[0]: best=(score,cn,tt,X.copy(),r.copy())
        pervclip[cn]=cm
        upd=cm>emax; emax[upd]=cm[upd]; eclip[upd]=ci
    res['edge_max_pct']={'p50':float(np.percentile(emax,50)),'p95':float(np.percentile(emax,95)),'p99':float(np.percentile(emax,99)),'max':float(emax.max()),
        'gt1.3':int((emax>1.3).sum()),'gt2':int((emax>2).sum()),'gt4':int((emax>4).sum())}
    # clip table
    ct={}
    for cn,cm in pervclip.items(): ct[cn]={'max':float(cm.max()),'p99':float(np.percentile(cm,99)),'n2':int((cm>2).sum())}
    res['clips']=ct
    # regions
    reg={}
    for l in np.unique(lab):
        m=lab==l
        if m.sum()<30: continue
        v=emax[m]; ci=np.bincount(eclip[m][v>1.3],minlength=len(clipnames)) if (v>1.3).any() else np.zeros(len(clipnames),int)
        top=[ (clipnames[i],int(ci[i])) for i in np.argsort(-ci)[:3] if ci[i]>0]
        reg[str(l)]={'n':int(m.sum()),'max':float(v.max()),'p95':float(np.percentile(v,95)),'n2':int((v>2).sum()),'frac2':float((v>2).mean()),'clips':top}
    res['regions']=reg
    # prop-free: verts with hand weight
    hw=np.zeros(len(g.P))
    for c in range(4):
        hw+=g.W[:,c]*np.array([g.name[g.joints[j]].startswith(('hand','fingers','thumb')) for j in g.J[:,c]])
    res['hand_dom_verts']={'L':int(np.sum([ (grp[i].endswith('.L') and grp[i].split('.')[0] in ('hand','fingers','thumb')) for i in range(len(grp))])),
                           'R':int(np.sum([ (grp[i].endswith('.R') and grp[i].split('.')[0] in ('hand','fingers','thumb')) for i in range(len(grp))]))}
    res['worst']={'clip':best[1],'t':float(best[2]),'score':int(best[0])}
    # per-vertex ratio at worst frame
    vr=np.ones(len(g.P)); r=best[4]
    np.maximum.at(vr,E[:,0],r); np.maximum.at(vr,E[:,1],r)
    np.savez_compressed(f'worst_{h}.npz',X=best[3],vr=vr,E=E)
    np.savez_compressed(f'emax_{h}.npz',E=E,emax=emax,lab=lab)
    json.dump(res,open(f'stretch_{h}.json','w'),indent=1)
    return h
if __name__=='__main__':
    t=time.time()
    for h in sys.argv[1:]: print(run(h),time.time()-t,flush=True)
