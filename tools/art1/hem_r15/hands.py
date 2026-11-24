import sys,numpy as np; sys.path.insert(0,'tools'); from glbio import *
j,b=load(sys.argv[1]); sk=j['skins'][0]; names=[j['nodes'][n]['name'] for n in sk['joints']]
print(len(names),[n for n in names if 'and' in n or 'ing' in n or 'humb' in n or 'ndex' in n or 'ist' in n][:60])
for mi,m in enumerate(j['meshes']):
  for pi,p in enumerate(m['primitives']):
    J=acc(j,b,p['attributes']['JOINTS_0']);W=acc(j,b,p['attributes']['WEIGHTS_0']).astype(float)
    dom=J[np.arange(len(J)),W.argmax(1)]
    for side in 'LeftHand','RightHand':
      ids=[i for i,n in enumerate(names) if side in n]
      c=np.isin(dom,ids).sum()
      if c: print(m['name'],pi,side,c,{names[i]:int((dom==i).sum()) for i in ids if (dom==i).sum()})
