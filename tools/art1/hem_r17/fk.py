import sys; sys.path.insert(0,'tools'); from glbio import *
from scipy.spatial.transform import Rotation as Rot, Slerp
def fk(path,clip,times,nodes):
    j,b=load(path); N=j['nodes']; par={c:i for i,n in enumerate(N) for c in n.get('children',[])}
    an=[a for a in j['animations'] if a['name']==clip][0]
    tr={}
    for c in an['channels']:
        s=an['samplers'][c['sampler']]; tr[(c['target']['node'],c['target']['path'])]=(acc(j,b,s['input'])[:,0],acc(j,b,s['output']).astype(float))
    idx={n.get('name'):i for i,n in enumerate(N) if 'mesh' not in n}
    def local(i,t):
        n=N[i]; T=np.array(n.get('translation',[0,0,0]),float); R=Rot.from_quat(n.get('rotation',[0,0,0,1]))
        if (i,'translation') in tr: ti,o=tr[(i,'translation')]; T=np.array([np.interp(t,ti,o[:,k]) for k in range(3)])
        if (i,'rotation') in tr:
            ti,o=tr[(i,'rotation')]; R=Slerp(ti,Rot.from_quat(o))(np.clip(t,ti[0],ti[-1])) if len(ti)>1 else Rot.from_quat(o[0])
        M=np.eye(4); M[:3,:3]=R.as_matrix(); M[:3,3]=T; return M
    out={}
    for t in times:
        for nm in nodes:
            i=idx[nm]; M=np.eye(4)
            while i is not None: M=local(i,t)@M; i=par.get(i)
            out[(t,nm)]=M
    return out
if __name__=='__main__':
    A,Bp,clip=sys.argv[1:4]; ts=np.arange(0,1.2,0.1)
    nodes=['Bow','StringMid','RightHand','LeftHand','Head']
    fa=fk(A,clip,ts,nodes); fb=fk(Bp,clip,ts,nodes)
    for t in ts:
        d=lambda f,x,y:np.linalg.norm(f[(t,x)][:3,3]-f[(t,y)][:3,3])*100
        print('t%.1f bow moved %.1f cm | string-RH live %.1f fix %.1f | bow-head live %.1f fix %.1f'%(t,np.linalg.norm(fa[(t,'Bow')][:3,3]-fb[(t,'Bow')][:3,3])*100,d(fa,'StringMid','RightHand'),d(fb,'StringMid','RightHand'),d(fa,'Bow','Head'),d(fb,'Bow','Head')))
