import sys,json,re,numpy as np,time
from rig import *
from stretch import group,ROOT,MIN_EDGE
from scipy.stats import spearmanr
def prep(h):
    g=Glb(ROOT+f'{h}/{h}.glb')
    jn=[g.name[j] for j in g.joints]
    acc_=np.zeros((len(g.P),len(jn)))
    for c in range(4): np.add.at(acc_,(np.arange(len(g.P)),g.J[:,c]),g.W[:,c])
    dom=acc_.argmax(1); grp=np.array([group(jn[d]) for d in dom])
    E=np.unique(np.sort(np.concatenate([g.T[:,[0,1]],g.T[:,[1,2]],g.T[:,[2,0]]]),1),axis=0)
    L0=np.linalg.norm(g.P[E[:,0]]-g.P[E[:,1]],axis=1)
    cnt={}
    for p in g.prim: cnt[p[0]]=cnt.get(p[0],0)+p[2]
    bm=max(cnt,key=cnt.get); bodym=np.array([p[0]==bm for p in g.prim for _ in range(p[2])])
    keep=bodym[E[:,0]]&bodym[E[:,1]]&(L0>=MIN_EDGE)&~np.char.startswith(grp[E[:,0]],'spring')&~np.char.startswith(grp[E[:,1]],'spring')
    g.E=E[keep];g.L0=L0[keep];g.grp=grp;g.dom=dom;g.jn=jn;g.acc=acc_
    cnt={}
    for p in g.prim: cnt[p[0]]=cnt.get(p[0],0)+p[2]
    bm=max(cnt,key=cnt.get)
    g.body=np.array([p[0]==bm for p in g.prim for _ in range(p[2])])  # the biggest mesh = body
    g.bodyH=float(np.ptp(g.P[g.body,1]))
    g.bind=[np.linalg.inv(m) for m in g.ibm]           # bind joint world
    g.jorig={jn[k]:g.bind[k][:3,3] for k in range(len(jn))}
    g.jidx={n:k for k,n in enumerate(jn)}
    return g
def ratio(g,X,gr=None):
    r=np.linalg.norm(X[g.E[:,0]]-X[g.E[:,1]],axis=1)/g.L0
    return r if gr is None else r/(0.5*(gr[g.E[:,0]]+gr[g.E[:,1]]))
def region_masks(g):
    a,b=g.grp[g.E[:,0]],g.grp[g.E[:,1]]
    def has(*ks): return np.array([any(x.startswith(k) for k in ks) for x in a])|np.array([any(x.startswith(k) for k in ks) for x in b])
    return {'arm':has('upper_arm','forearm','hand','fingers','thumb','pauldron'),'leg':has('thigh','shin','foot'),
            'torso':np.array([ (x.split('.')[0] in('hips','root','skirt','head')) for x in a])&np.array([ (x.split('.')[0] in('hips','root','skirt','head')) for x in b])}
def ang(q1,q2):
    d=abs(np.dot(q1/np.linalg.norm(q1),q2/np.linalg.norm(q2))); return float(np.degrees(2*np.arccos(min(1,d))))
def rotmat(axis,deg):
    a=np.radians(deg);x,y,z=axis/np.linalg.norm(axis);c,s=np.cos(a),np.sin(a)
    return np.array([[c+x*x*(1-c),x*y*(1-c)-z*s,x*z*(1-c)+y*s],[y*x*(1-c)+z*s,c+y*y*(1-c),y*z*(1-c)-x*s],[z*x*(1-c)-y*s,z*y*(1-c)+x*s,c+z*z*(1-c)]])
def mat2q(M):
    from scipy.spatial.transform import Rotation as R
    return R.from_matrix(M).as_quat()
def qm(q): return qmat(q)
def synth(g,bone,axis,deg):
    """rest pose with `bone` turned about world `axis` by deg (at its own origin)"""
    ni=g.joints[g.jidx[bone]]; trs=[list(x) for x in g.rest]
    G=g.pose_globals(g.rest)
    P=g.parent[ni]; Pr=G[P][:3,:3] if P>=0 else np.eye(3)
    Pn=Pr/np.linalg.norm(Pr,axis=0)
    Rl=qmat(trs[ni][1]); Rw=rotmat(np.array(axis,float),deg)
    new=Pn.T@Rw@Pn@Rl
    trs[ni][1]=mat2q(new)
    return g.skin(g.pose_globals(trs),True)
def analyse(h):
    t0=time.time(); g=prep(h); out={'h':h,'H':g.bodyH}
    reg=region_masks(g)
    names=g.jn
    # ---- B: spine bones
    out['spine_like_bones']=[n for n in names if re.search(r'spine|chest|neck|torso|waist|back',n,re.I)]
    # torso transition span hips->head
    hips=g.jorig.get('hips'); head=g.jorig.get('head')
    hy,hdy=hips[1],head[1]
    # head group weight & hips group weight per vertex
    def descend(root):
        ni=g.joints[g.jidx[root]]; s=set([ni]);st=[ni]
        while st:
            x=st.pop()
            for c in g.nodes[x].get('children',[]):
                if c not in s: s.add(c);st.append(c)
        return s
    hs=descend('head'); hset=[k for k,j in enumerate(g.joints) if j in hs]
    wh=g.acc[:,hset].sum(1)
    hipsw=g.acc[:,[g.jidx[n] for n in ('hips',) ]].sum(1)
    sel=g.body&(g.P[:,1]>hy)&(g.P[:,1]<hdy)&(wh+hipsw>0.7)   # torso verts between the two joints, mostly hips/head-bound
    y=g.P[sel,1]; r=wh[sel]/(wh[sel]+hipsw[sel])
    if sel.sum()>50:
        bins=np.linspace(hy,hdy,21); mid=[];val=[]
        for i in range(20):
            m=(y>=bins[i])&(y<bins[i+1])
            if m.sum()>5: mid.append((bins[i]+bins[i+1])/2); val.append(r[m].mean())
        mid=np.array(mid);val=np.array(val)
        def cross(th):
            i=np.where(val>=th)[0]; return float(mid[i[0]]) if len(i) else np.nan
        out['torso']={'hips_y':float(hy),'head_y':float(hdy),'n':int(sel.sum()),'y10':cross(0.1),'y90':cross(0.9),
           'span_over_joint_gap':float((cross(0.9)-cross(0.1))/(hdy-hy)), 'gap_pct_H':float((hdy-hy)/g.bodyH*100)}
    # ---- C: centring: bone origin vs dominant verts centroid (and axis)
    cen={}
    for n in names:
        if n.startswith(('spring','anchor','x_','orbit')) : continue
        k=g.jidx[n]; m=(g.dom==k)&g.body
        if m.sum()<30: cen[n]={'verts':int(m.sum())}; continue
        o=g.bind[k][:3,3]; c=g.P[m].mean(0)
        kids=[g.jidx[g.name[cn]] for cn in g.nodes[g.joints[k]].get('children',[]) if g.name[cn] in g.jidx and not g.name[cn].startswith(('spring','anchor'))]
        tail=np.mean([g.bind[q][:3,3] for q in kids],0) if kids else None
        d={'verts':int(m.sum()),'cen_off_pct':float(np.linalg.norm(c-o)/g.bodyH*100)}
        if tail is not None:
            seg=tail-o;L=np.linalg.norm(seg)
            if L>1e-3:
                t=np.clip(np.dot(c-o,seg)/L**2,0,1); d['cen_to_axis_pct']=float(np.linalg.norm(c-(o+t*seg))/g.bodyH*100); d['bone_len_pct']=float(L/g.bodyH*100)
        cen[n]=d
    out['centre']=cen
    # ---- D: hand weights
    hd={}
    for side in 'LR':
        k=[g.jidx[n] for n in names if n.startswith(('hand.'+side,'fingers.'+side,'thumb.'+side))]
        dv=int(np.isin(g.dom,k).sum()); wsum=float(g.acc[:,k].sum())
        o=g.jorig.get('hand.'+side)
        near=g.body&(np.linalg.norm(g.P-o,axis=1)<0.06*g.bodyH)
        hd[side]={'dom_verts':dv,'weight_sum':wsum,'verts_within6pct':int(near.sum()),
                  'hand_w_in_6pct':float(g.acc[near][:,k].sum(1).mean()) if near.sum() else 0.0,'bind_x':float(o[0])}
    out['hand']=hd
    # ---- synthetic joint sweeps
    sweeps={}
    tests=[]
    for s in 'LR':
        sg=1 if g.jorig['hand.'+s][0]>0 else -1
        for a in (45,70,90,120,150,180):
            tests.append((f'upper_arm.{s}','side',a,'upper_arm.'+s,(0,0,1),sg*a))
            tests.append((f'upper_arm.{s}','fwd',a,'upper_arm.'+s,(1,0,0),-a))
        tests.append((f'forearm.{s}','elbow',90,'forearm.'+s,(1,0,0),-90))
        tests.append((f'thigh.{s}','fwd',45,'thigh.'+s,(1,0,0),-45)); tests.append((f'thigh.{s}','fwd',90,'thigh.'+s,(1,0,0),-90))
        tests.append((f'shin.{s}','knee',90,'shin.'+s,(1,0,0),90))
    for (jb,kind,a,bone,axis,deg) in tests:
        X,gr=synth(g,bone,axis,deg); r=ratio(g,X,gr)
        sweeps[f'{jb}|{kind}|{a}']={'max':float(r.max()),'p99':float(np.percentile(r,99.9)),'n1.3':int((r>1.3).sum()),'n2':int((r>2).sum()),'n4':int((r>4).sum())}
    for kind,axis,deg in (('yaw45',(0,1,0),45),('pitch30',(1,0,0),30),('yaw80',(0,1,0),80)):
        X,gr=synth(g,'head',axis,deg); r=ratio(g,X,gr); sweeps[f'head|{kind}']={'max':float(r.max()),'p99':float(np.percentile(r,99.9)),'n1.3':int((r>1.3).sum()),'n2':int((r>2).sum()),'n4':int((r>4).sum())}
        X,gr=synth(g,'hips',axis,deg); r=ratio(g,X,gr); sweeps[f'hips|{kind}']={'max':float(r.max()),'p99':float(np.percentile(r,99.9)),'n1.3':int((r>1.3).sum()),'n2':int((r>2).sum()),'n4':int((r>4).sum())}
    out['synth']=sweeps
    # ---- clips: arm swing vs arm stretch; torso; bone length change (E); clip identity
    per=[]; 
    arms=[('upper_arm.L'),('upper_arm.R')]
    for cn in sorted(g.anims):
        T=g.clip_len(cn); sw=0;th=0;hp=0;hd_=0; sa=[];sl=[];st=[]; blmax=0
        for k in range(10):
            tt=T*k/9; trs=g.sample(cn,tt); G=g.pose_globals(trs); X,gr=g.skin(G,True); r=ratio(g,X,gr)
            sa.append(float(r[reg['arm']].max()) if reg['arm'].any() else 1); sl.append(float(r[reg['leg']].max()) if reg['leg'].any() else 1); st.append(float(r[reg['torso']].max()) if reg['torso'].any() else 1)
            for n in arms: 
                ni=g.joints[g.jidx[n]]; sw=max(sw,ang(trs[ni][1],g.rest[ni][1]))
            for n in ('thigh.L','thigh.R'):
                ni=g.joints[g.jidx[n]]; th=max(th,ang(trs[ni][1],g.rest[ni][1]))
            # head relative to hips, world
            Gh=G[g.joints[g.jidx['head']]][:3,:3]; Gp=G[g.joints[g.jidx['hips']]][:3,:3]
            R0=g.bind[g.jidx['head']][:3,:3].T@g.bind[g.jidx['hips']][:3,:3]
            Rel=(Gh.T@Gp); 
            hd_=max(hd_,float(np.degrees(np.arccos(np.clip((np.trace(Rel@R0.T)-1)/2,-1,1)))) if True else 0)
            # bone length change: parent-child joint distance vs bind (non-spring)
            for n in names:
                pn=g.parent[g.joints[g.jidx[n]]]
                if pn<0 or g.name[pn] not in g.jidx or n.startswith(('spring','anchor','x_','orbit')): continue
                d1=np.linalg.norm(G[g.joints[g.jidx[n]]][:3,3]-G[pn][:3,3]); d0=np.linalg.norm(g.bind[g.jidx[n]][:3,3]-g.bind[g.jidx[g.name[pn]]][:3,3])
                if d0>0.03*g.bodyH: blmax=max(blmax,abs(d1/d0-1))
        per.append({'clip':cn,'arm_swing':sw,'thigh_swing':th,'head_vs_hips':hd_,'arm_stretch':max(sa),'leg_stretch':max(sl),'torso_stretch':max(st),'bone_len_dev':blmax})
    out['clipstats']=per
    A=np.array([p['arm_swing'] for p in per]);S=np.array([p['arm_stretch'] for p in per])
    out['arm_corr']=float(spearmanr(A,S)[0]); 
    bins={}
    for lo,hi in ((0,30),(30,70),(70,120),(120,181)):
        m=(A>=lo)&(A<hi); bins[f'{lo}-{hi}']={'clips':int(m.sum()),'median_arm_stretch':float(np.median(S[m])) if m.any() else None}
    out['arm_bins']=bins
    out['leg_corr']=float(spearmanr([p['thigh_swing'] for p in per],[p['leg_stretch'] for p in per])[0])
    out['torso_corr']=float(spearmanr([p['head_vs_hips'] for p in per],[p['torso_stretch'] for p in per])[0])
    out['rest_arm_down']={'L':None}
    json.dump(out,open(f'a2_{h}.json','w'),indent=1)
    return h,time.time()-t0
if __name__=='__main__':
    for h in sys.argv[1:]: print(analyse(h),flush=True)
