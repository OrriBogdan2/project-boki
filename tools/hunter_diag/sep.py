import numpy as np,json,sys
from analysis2 import prep
from collections import Counter
out={}
for h in sys.argv[1:]:
    g=prep(h); d=np.load(f'emax_{h}.npz'); em=d['emax']
    assert len(em)==len(g.E)
    bad=np.where(em>2)[0]
    A=g.acc[g.E[bad,0]];B=g.acc[g.E[bad,1]]
    D=A-B
    ka=D.argmax(1);kb=(-D).argmax(1)
    names=np.array(g.jn)
    import re
    from stretch import group
    ga=np.array([group(n) for n in names[ka]]);gb=np.array([group(n) for n in names[kb]])
    pair=np.where(ga<gb,np.char.add(np.char.add(ga,' vs '),gb),np.char.add(np.char.add(gb,' vs '),ga))
    # also contribution weighted by excess
    c=Counter(pair); tot=len(bad)
    out[h]={'n2':int(tot),'top':[(k,int(v)) for k,v in c.most_common(6)]}
    print(h,tot,[(k,v) for k,v in c.most_common(5)])
json.dump(out,open('sep.json','w'))
