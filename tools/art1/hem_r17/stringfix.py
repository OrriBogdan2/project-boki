"""stringfix.py FIX LIVE OUT: Attack StringMid translation keys solved so the drawn string apex = live's (blend by draw amount)."""
import sys; sys.path.insert(0,'tools'); from glbio import *; from fk import fk
FIX,LIVE,OUT=sys.argv[1:4]
j,b=load(FIX); N=j['nodes']; nSM=[i for i,n in enumerate(N) if n.get('name')=='StringMid'][0]
an=[a for a in j['animations'] if a['name']=='Attack'][0]
c=[c for c in an['channels'] if c['target']['node']==nSM and c['target']['path']=='translation'][0]
s=an['samplers'][c['sampler']]; t=acc(j,b,s['input'])[:,0]; o=acc(j,b,s['output']).astype(float)
rest=np.array(N[nSM]['translation']); dr=np.linalg.norm(o-rest,axis=1); w=np.clip(dr/max(dr.max(),1e-6)*1.5,0,1)
fl=fk(LIVE,'Attack',t,['StringMid']); ff=fk(FIX,'Attack',t,['Bow'])
no=o.copy()
for k,tt in enumerate(t):
    pl=fl[(tt,'StringMid')][:3,3]; Mb=ff[(tt,'Bow')]; loc=(np.linalg.inv(Mb)@np.r_[pl,1])[:3]
    no[k]=o[k]*(1-w[k])+loc*w[k]
raw=np.ascontiguousarray(no.astype(np.float32)).tobytes(); off=len(b); b=b+bytearray(raw)
j['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':len(raw)})
j['accessors'].append({'bufferView':len(j['bufferViews'])-1,'componentType':5126,'count':len(no),'type':'VEC3'})
an['samplers'].append({'input':s['input'],'output':len(j['accessors'])-1,'interpolation':s.get('interpolation','LINEAR')}); c['sampler']=len(an['samplers'])-1
save(OUT,j,b); print('string keys',len(t),'max draw w',w.max().round(2))
