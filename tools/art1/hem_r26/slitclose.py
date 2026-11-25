# slitclose.py IN IN_CLIPS OUT OUT_CLIPS [clo=Crouch:0.5,*:1.0 had=Attack:1,lace_:1 psi=16 smooth=0.03]
# Lace r26: the r25 slit (a 20-30 deg wedge, hem to y 0.60) faces the game camera in idle/attack, and that camera (66 deg down)
# sees the ground through it = the "trouser V". r25 closed it only in Attack/kit moves. This post-pass on the shipped r25 files
# adds a closing yaw to the SkirtSlitA/B keys in every clip (node local L' = L @ Hrest^-1 Yaw(sg*dclo*psi) Hrest, the same factor
# sway25 applied last), where dclo = target clo (first substring match in clo=, '*' = default) - clo already baked (had=).
# smooth=R (m): the slit-joint weights are averaged over all skirt verts within R in 3D (stacked panel islands then move as one),
# other weights rescaled to keep each vertex's sum 1. band1=DEG (r25: 30): rebuild the slit weights with sway25's formula
# (gap centre gapc -40, full within band0 12 deg, fade to 0 at band1, y fade sy0 0.86 -> sy1 0.60) so the closing shear spreads wider. Mesh, textures and all non-slit keys are untouched.
import sys,numpy as np
sys.path.insert(0,'tools/anim'); sys.path.insert(0,'tools/art1/hem_r17'); import geo_check as g, glbio
from scipy.spatial import cKDTree
from scipy.spatial.transform import Rotation as Rot
src,srcc,out,outc=sys.argv[1:5]; O=dict(a.split('=') for a in sys.argv[5:])
def kv(s): return [(x.split(':')[0],float(x.split(':')[1])) for x in s.split(',') if x]
CLO=kv(O.get('clo','Crouch:0.5,*:1.0')); HAD=kv(O.get('had','Attack:1,lace_:1')); psi=np.radians(float(O.get('psi',16)))
def append(jj,bb,arr,typ):                                   # same as sway25.append (float accessor at the end of the buffer)
    raw=np.ascontiguousarray(arr.astype(np.float32)).tobytes(); bb+=b'\0'*((-len(bb))%4); off=len(bb); bb+=raw
    jj['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':len(raw)})
    jj['accessors'].append({'bufferView':len(jj['bufferViews'])-1,'componentType':5126,'count':len(arr),'type':typ}); return len(jj['accessors'])-1
def look(L,name,dflt):
    for k,v in L:
        if k=='*' or k.lower() in name.lower(): return v
    return dflt
j,b=glbio.load(src); rig=g.Rig(j,b); jn=rig.names; ih=jn.index('Hips')
S0=rig.skin_mats(None,np.zeros(1))[0]; H=(S0@np.linalg.inv(rig.ibm))[ih]; hc=H[:3,3]
def Yaw(a):
    M=np.eye(4); M[:3,:3]=Rot.from_rotvec([0,a,0]).as_matrix(); M[:3,3]=hc-M[:3,:3]@hc; return M
def fix(jj,bb,tag):
    nn=jj['nodes']; idx={nd.get('name'):i for i,nd in enumerate(nn)}; sl={idx['SkirtSlitA']:1.0,idx['SkirtSlitB']:-1.0}
    for an in jj['animations']:
        d=look(CLO,an['name'],1.0)-look(HAD,an['name'],0.0)
        if abs(d)<1e-6: continue
        ch={(c['target']['node'],c['target']['path']):c for c in an['channels'] if c['target']['node'] in sl}
        for ni,sg in sl.items():
            cr,ct=ch[(ni,'rotation')],ch[(ni,'translation')]; sr,st=an['samplers'][cr['sampler']],an['samplers'][ct['sampler']]
            q=glbio.acc(jj,bb,sr['output']).astype(float); t=glbio.acc(jj,bb,st['output']).astype(float); assert len(q)==len(t)
            E=np.linalg.inv(H)@Yaw(sg*d*psi)@H; L=np.tile(np.eye(4),(len(q),1,1)); L[:,:3,:3]=Rot.from_quat(q).as_matrix(); L[:,:3,3]=t
            L2=L@E; q2=Rot.from_matrix(L2[:,:3,:3]).as_quat(); q2*=np.sign(q2[:,3:4]+1e-9)
            sr['output']=append(jj,bb,q2,'VEC4')
            st['output']=append(jj,bb,L2[:,:3,3],'VEC3')
        print(tag,an['name'],'dclo %+.2f'%d)
    jj['buffers'][0]['byteLength']=len(bb)
b=bytearray(bytes(b)); fix(j,b,'main')
R=float(O.get('smooth',0)); BAND=float(O.get('band1',0))
if R>0 or BAND>0:
    sk=next(p for me in j['meshes'] for p in me['primitives'] if j['materials'][p['material']]['name']=='skirt-meshy')
    A=lambda k: glbio.acc(j,b,sk['attributes'][k]); P=A('POSITION').astype(float)
    Jx=np.c_[A('JOINTS_0'),A('JOINTS_1')].astype(int); Wx=np.c_[A('WEIGHTS_0'),A('WEIGHTS_1')].astype(float)
    n=len(P); D=np.zeros((n,len(jn))); np.add.at(D,(np.repeat(np.arange(n),8),Jx.ravel()),Wx.ravel())
    s=[jn.index('SkirtSlitA'),jn.index('SkirtSlitB')]; ws=D[:,s].copy()
    if BAND>0:
        va=np.arctan2(P[:,0]-hc[0],P[:,2]-hc[2]); da=np.degrees((va-np.radians(float(O.get('gapc',-40)))+np.pi)%(2*np.pi)-np.pi)
        b0=float(O.get('band0',12)); wb=np.clip((BAND-np.abs(da))/(BAND-b0),0,1); wb=wb*wb*(3-2*wb)
        y0,y1=float(O.get('sy0',0.86)),float(O.get('sy1',0.60)); ty=np.clip((y0-P[:,1])/(y0-y1),0,1); w=wb*ty*ty*(3-2*ty)
        ws2=np.zeros_like(ws); ws2[da<0,0]=w[da<0]; ws2[da>=0,1]=w[da>=0]
        old=(np.abs(da)<=30)&(ws.sum(1)>0); print('band check: r25 formula at band1 30 would match? mean |w-old| on old band %.3f'%np.abs(np.where(np.abs(da)<=12,1,0)[old]*(w[old]-ws[old].sum(1))).mean())
    else:
        nb=cKDTree(P).query_ball_point(P,R); ws2=np.array([ws[x].mean(0) for x in nb])
    rest=D.sum(1)-ws.sum(1); scale=np.where(rest>1e-6,(1-ws2.sum(1))/np.maximum(rest,1e-6),0)
    D*=scale[:,None]; D[:,s]=ws2; D/=D.sum(1,keepdims=True)
    o=np.argsort(-D,1)[:,:8]; w=np.take_along_axis(D,o,1); w/=w.sum(1,keepdims=True)
    print('smooth R %.3f band1 %.0f: slit weight change max %.2f, verts changed %d'%(R,BAND,np.abs(ws2-ws).max(),(np.abs(ws2-ws).sum(1)>0.01).sum()))
    for k,arr in (('JOINTS_0',o[:,:4]),('JOINTS_1',o[:,4:]),('WEIGHTS_0',w[:,:4]),('WEIGHTS_1',w[:,4:])):
        a=j['accessors'][sk['attributes'][k]]; dt={5121:np.uint8,5123:np.uint16,5126:np.float32}[a['componentType']]; glbio.put(j,b,sk['attributes'][k],arr.astype(dt))
glbio.save(out,j,b); print('wrote',out)
jc,bc=glbio.load(srcc); bc=bytearray(bytes(bc)); fix(jc,bc,'clips'); glbio.save(outc,jc,bc); print('wrote',outc)
