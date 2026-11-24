import sys,numpy as np; sys.path.insert(0,'tools'); from glbio import *
j,b=load(sys.argv[1]); N=j['nodes']
def qang(q0,q):
    d=np.abs((q*q0).sum(1)).clip(0,1); return np.degrees(2*np.arccos(d))
for a in j['animations']:
  out={}
  for c in a['channels']:
    n=N[c['target']['node']].get('name','')
    if 'Hand' in n and c['target']['path']=='rotation':
      q=acc(j,b,a['samplers'][c['sampler']]['output']).astype(float)
      r=np.array(N[c['target']['node']].get('rotation',[0,0,0,1]))
      out[n]=round(float(qang(r,q).max()),1)
  L={k:v for k,v in out.items() if 'Left' in k}; R={k:v for k,v in out.items() if 'Right' in k}
  print(a['name'],'L',L); print('   R',R)
