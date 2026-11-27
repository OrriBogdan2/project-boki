# corset34.py GLB RETEX_DIR|retone OUT.glb (RETEX_DIR = meshy retexture out: glb.glb + tex0_base_color.png;
#   retone = no Meshy: lift the corset's near-black texels to crimson, keeping each texel's shading and the silver filigree) [ylo=0.95 yhi=1.40 dil=4 gain=1.0 dbg=DIR] : Lace r34 corset re-tone.
# Meshy re-packs UVs and normalises the mesh even with --original-uv, so each corset texel goes texel -> 3D point (old UV tri)
# -> nearest Meshy face (centroid, after undoing the normalisation) -> barycentric -> Meshy UV -> colour. Only corset texels:
# body-retex faces whose 3 verts are dominated by Hips/Spine*, bind-pose y in [ylo,yhi], and whose old texel is not porcelain.
# Mesh bytes are untouched (part-lock): only the texD2 image changes.
import sys,io,numpy as np; sys.path.insert(0,'tools/art1/hem_r17'); sys.path.insert(0,'tools/anim')
from glbio import load,acc,replace_view,save; import geo_check as g
from PIL import Image,ImageDraw,ImageFilter; from scipy.spatial import cKDTree
a=dict(x.split('=') for x in sys.argv[4:]); ylo=float(a.get('ylo',.95)); yhi=float(a.get('yhi',1.40)); dil=int(a.get('dil',4)); gain=float(a.get('gain',1))
j,b=load(sys.argv[1]); rig=g.Rig(j,bytes(b)); N=np.array(rig.names)
p=[p for p in j['meshes'][1]['primitives'] if j['materials'][p['material']]['name']=='body-retex'][0]
P=acc(j,b,p['attributes']['POSITION']); UV=acc(j,b,p['attributes']['TEXCOORD_0']); F=acc(j,b,p['indices']).reshape(-1,3)
Jn=acc(j,b,p['attributes']['JOINTS_0']).astype(int); W=acc(j,b,p['attributes']['WEIGHTS_0']).astype(float)
dom=N[Jn[np.arange(len(Jn)),W.argmax(1)]]; tor=np.isin(dom,['Hips','Spine','Spine01','Spine02'])
fm=tor[F].all(1)&(P[F][:,:,1].mean(1)>ylo)&(P[F][:,:,1].mean(1)<yhi)
ii=j['textures'][j['materials'][p['material']]['pbrMetallicRoughness']['baseColorTexture']['index']]['source']; bvi=j['images'][ii]['bufferView']
bv=j['bufferViews'][bvi]; old=Image.open(io.BytesIO(bytes(b[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]))).convert('RGB'); S=old.size[0]
m=Image.new('L',old.size,0); d=ImageDraw.Draw(m)
for f in F[fm]: d.polygon([(UV[k,0]*S,UV[k,1]*S) for k in f],fill=255)
if dil: m=m.filter(ImageFilter.MaxFilter(2*dil+1))
M=np.asarray(m.filter(ImageFilter.GaussianBlur(1.5)),float)/255
# face id raster over the (dilated) mask area: every body face, so dilated texels still find their own triangle
fid=Image.new('I',old.size,0); d=ImageDraw.Draw(fid)
for k in np.argsort(~fm):                                   # corset faces drawn last (win overlaps)
    f=F[k]; d.polygon([(UV[q,0]*S,UV[q,1]*S) for q in f],fill=int(k)+1)
fid=np.asarray(fid).astype(np.int64)-1
if sys.argv[2]=='retone':
    O=np.asarray(old,float); L=O.mean(2); sat=O.max(2)-O.min(2)
    crim=np.array([float(x) for x in a.get('crim','150,30,52').split(',')]); dk=float(a.get('dark',75))
    w=np.clip((dk-L)/(dk*.5),0,1)*(O[...,0]<O[...,2]+40+0*sat)        # near-black texels (not already red/silver)
    shade=np.clip(.35+.65*L/dk,0,1.2)[...,None]; Nw=O*(1-w[...,None])+crim*shade*w[...,None]
    Nw=np.clip(Nw*np.where((O[...,0]>O[...,2]+25)[...,None],gain,1),0,255)
    print('retone dark texels in mask %.1f%%'%(100*((w>.5)&(M>.5)).sum()/max(1,(M>.5).sum())))
else:
    ys,xs=np.nonzero((M>0)&(fid>=0)); fk=fid[ys,xs]; uv=np.c_[(xs+.5)/S,(ys+.5)/S]
    A,B,C=UV[F[fk,0]],UV[F[fk,1]],UV[F[fk,2]]; v0=B-A; v1=C-A; v2=uv-A
    den=v0[:,0]*v1[:,1]-v1[:,0]*v0[:,1]; den[np.abs(den)<1e-12]=1e-12
    w1=(v2[:,0]*v1[:,1]-v1[:,0]*v2[:,1])/den; w2=(v0[:,0]*v2[:,1]-v2[:,0]*v0[:,1])/den; w0=1-w1-w2
    X=w0[:,None]*P[F[fk,0]]+w1[:,None]*P[F[fk,1]]+w2[:,None]*P[F[fk,2]]
    rj,rb=load(sys.argv[2]+'/glb.glb'); rp=rj['meshes'][0]['primitives'][0]
    RP=acc(rj,rb,rp['attributes']['POSITION']).astype(float); RU=acc(rj,rb,rp['attributes']['TEXCOORD_0']).astype(float); RF=acc(rj,rb,rp['indices']).reshape(-1,3)
    c=(P.min(0)+P.max(0))/2; sc=(RP.max(0)-RP.min(0))[1]/(P.max(0)-P.min(0))[1]; Xn=(X-c)*sc
    _,nf=cKDTree(RP[RF].mean(1)).query(Xn)
    A,B,C=RP[RF[nf,0]],RP[RF[nf,1]],RP[RF[nf,2]]; e0=B-A; e1=C-A; e2=Xn-A
    d00=(e0*e0).sum(1); d01=(e0*e1).sum(1); d11=(e1*e1).sum(1); d20=(e2*e0).sum(1); d21=(e2*e1).sum(1); dn=d00*d11-d01*d01; dn[np.abs(dn)<1e-18]=1e-18
    b1=np.clip((d11*d20-d01*d21)/dn,0,1); b2=np.clip((d00*d21-d01*d20)/dn,0,1); s12=np.maximum(b1+b2,1); b1/=s12; b2/=s12; b0=1-b1-b2
    ru=b0[:,None]*RU[RF[nf,0]]+b1[:,None]*RU[RF[nf,1]]+b2[:,None]*RU[RF[nf,2]]
    T=np.asarray(Image.open(sys.argv[2]+'/tex0_base_color.png').convert('RGB')); TS=T.shape[0]
    O=np.asarray(old,float); Nw=O.copy()
    Nw[ys,xs]=np.clip(T[np.clip((ru[:,1]*TS).astype(int),0,TS-1),np.clip((ru[:,0]*TS).astype(int),0,TS-1)].astype(float)*gain,0,255)
    if a.get('match','1')=='1':                                # pull Meshy's orange-red onto the atlas's own crimson (red texels only)
        q=Nw[ys,xs]; Oq=O[M>.5]; ro=Oq[Oq[:,0]>Oq[:,2]+25].mean(0); rq=(q[:,0]>q[:,2]+25); rn=q[rq].mean(0); gn=ro/rn
        wr=np.clip((q[:,0]-q[:,2]-10)/30,0,1)[:,None]; Nw[ys,xs]=np.clip(q*(1-wr)+q*gn*wr,0,255); print('match gain',gn.round(2),'old crimson',ro.round())
    print('transfer texels',len(ys),'face dist p95 %.4f'%np.percentile(np.linalg.norm(RP[RF[nf]].mean(1)-Xn,axis=1),95))
L=O.mean(2); sat=O.max(2)-O.min(2); por=(L>150)&(sat<60)          # porcelain texel in the old atlas: keep it
por=np.asarray(Image.fromarray((por*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)),float)/255
M=M*(1-por); R=O*(1-M[...,None])+Nw*M[...,None]
print('faces',len(F),'corset faces',fm.sum(),'mask texels %.1f%%'%(100*(M>.5).mean()),'old mean',O[M>.5].mean(0).round(),'new mean',Nw[M>.5].mean(0).round())
out=Image.fromarray(R.round().astype(np.uint8)); buf=io.BytesIO(); out.save(buf,'JPEG',quality=92); b=replace_view(j,b,bvi,buf.getvalue())
if 'dbg' in a:
    old.save(a['dbg']+'/texD2_old.jpg',quality=85); out.save(a['dbg']+'/texD2_new.jpg',quality=85); Image.fromarray((M*255).astype(np.uint8)).save(a['dbg']+'/corset_mask.png')
save(sys.argv[3],j,b)
