import numpy as np, json
from glbio import *
def qmat(q):
    x,y,z,w=q; 
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
def slerp(a,b,t):
    d=np.dot(a,b)
    if d<0: b=-b; d=-d
    if d>0.9995:
        r=a+t*(b-a); return r/np.linalg.norm(r)
    th=np.arccos(d); return (np.sin((1-t)*th)*a+np.sin(t*th)*b)/np.sin(th)
class Glb:
    def __init__(s,p):
        s.js,s.bin=load(p); js=s.js
        s.nodes=js['nodes']; n=len(s.nodes)
        s.parent=[-1]*n
        for i,nd in enumerate(s.nodes):
            for c in nd.get('children',[]): s.parent[c]=i
        s.name=[nd.get('name','') for nd in s.nodes]
        s.rest=[(np.array(nd.get('translation',[0,0,0]),float),np.array(nd.get('rotation',[0,0,0,1]),float),np.array(nd.get('scale',[1,1,1]),float)) for nd in s.nodes]
        sk=js['skins'][0]; s.joints=sk['joints']
        s.ibm=acc(js,s.bin,sk['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1).astype(float)  # col-major -> row
        s.order=[]; 
        def vis(i):
            s.order.append(i)
            for c in s.nodes[i].get('children',[]): vis(c)
        for i in range(n):
            if s.parent[i]<0: vis(i)
        # geometry
        P=[];J=[];W=[];T=[];prim=[]
        off=0
        for mi,m in enumerate(js['meshes']):
            for pr in m['primitives']:
                a=pr['attributes']
                if 'JOINTS_0' not in a: continue
                pos=acc(js,s.bin,a['POSITION']).astype(float)
                j=acc(js,s.bin,a['JOINTS_0']).astype(int); w=acc(js,s.bin,a['WEIGHTS_0']).astype(float)
                idx=acc(js,s.bin,pr['indices']).reshape(-1).astype(int)
                P.append(pos);J.append(j);W.append(w);T.append(idx.reshape(-1,3)+off)
                prim.append((mi,off,len(pos),pr.get('material')))
                off+=len(pos)
        s.P=np.concatenate(P);s.J=np.concatenate(J);s.W=np.concatenate(W);s.T=np.concatenate(T);s.prim=prim
        ws=s.W.sum(1,keepdims=True); s.W=s.W/np.maximum(ws,1e-9)
        s.anims={}
        for a in js.get('animations',[]):
            ch={}
            for c in a['channels']:
                smp=a['samplers'][c['sampler']]
                t=acc(js,s.bin,smp['input']).reshape(-1); v=acc(js,s.bin,smp['output'])
                ch[(c['target']['node'],c['target']['path'])]=(t.astype(float),v.astype(float),smp.get('interpolation','LINEAR'))
            s.anims[a['name']]=ch
    def pose_globals(s,trs):
        G=[None]*len(s.nodes)
        for i in s.order:
            t,q,sc=trs[i]
            M=np.eye(4); M[:3,:3]=qmat(q)*sc[None,:]; M[:3,3]=t
            G[i]=M if s.parent[i]<0 else G[s.parent[i]]@M
        return G
    def sample(s,name,tt):
        trs=list(s.rest); ch=s.anims[name]; trs=[list(x) for x in trs]
        for (nd,path),(t,v,interp) in ch.items():
            if tt<=t[0]: k=0;f=0
            elif tt>=t[-1]: k=len(t)-1;f=0
            else:
                k=np.searchsorted(t,tt,side='right')-1; f=(tt-t[k])/(t[k+1]-t[k]) if interp!='STEP' else 0
            k2=min(k+1,len(t)-1)
            if path=='rotation': val=slerp(v[k]/np.linalg.norm(v[k]),v[k2]/np.linalg.norm(v[k2]),f)
            else: val=v[k]*(1-f)+v[k2]*f
            trs[nd][{'translation':0,'rotation':1,'scale':2}[path]]=val
        return trs
    def skin(s,G,grow=False):
        # joint matrices relative to armature: joint global * ibm  (glTF ignores mesh node xf)
        JM=np.stack([G[j]@s.ibm[k] for k,j in enumerate(s.joints)])
        Ph=np.c_[s.P,np.ones(len(s.P))]
        out=np.zeros((len(s.P),3)); B=np.zeros((len(s.P),3,3))
        for c in range(4):
            M=JM[s.J[:,c]]  # n,4,4
            out+=s.W[:,c:c+1]*np.einsum('nij,nj->ni',M,Ph)[:,:3]
            if grow: B+=s.W[:,c,None,None]*M[:,:3,:3]
        if grow:
            cn=np.linalg.norm(B,axis=1)       # column lengths (n,3)
            return out,np.maximum(1.0,cn.min(1))
        return out
    def clip_len(s,name):
        return max(v[0][-1] for v in s.anims[name].values())
