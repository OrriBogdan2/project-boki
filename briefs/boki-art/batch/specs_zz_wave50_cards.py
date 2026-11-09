# Owner 02:20 ET 11-09: "a lot of the boki in the dex need better portraits". Every Boki with an approved sheet but no main card
# gets a canon hero card now (fresh from its current sheet, strengthened card prompt, 3 runs), ahead of fix rounds.
import os as _o50, json as _j50
_idx=_j50.load(open(HERE.parent/'lines'/'index.json'))
_st={}
for _f,_s in _idx:
    for _k,_x in enumerate(_s):
        for _n in _x.split(' / '): _st[_n]=['baby','mid','final'][min(_k,2)] if len(_s)>2 else ['baby','final'][min(_k,1)]
_have={x[:-4] for x in _o50.listdir(HERE.parent/'cards')}
_SKIP={'Amanitusk','Umbrink','Blossmink','Flarmink','Galleotter','Arcestrel','Briarlynx','Chandelotl','Geodelotl'}
_P50=[]
for _d in ('evolutions','turnarounds'):
    for _f in sorted(_o50.listdir(HERE.parent/_d)):
        _n=_f[:-4]
        if not _f.endswith('.jpg') or '_' in _n or _n in _have or _n in _SKIP: continue
        _i=_n.lower()+'_card3'
        if _i in _P50: continue
        SPECS.append({'id':_i,'name':_n+' (hero card)','refs':[f'briefs/boki-art/{_d}/{_f}',SRA],'runs':3,'aspect':'1:1','size':'2K',
          'prompt':CARD(_n,_st.get(_n,'mid'),'a characterful grounded pose that is natural for this animal and different from its sheet pose, head turned toward the viewer')})
        _P50.append(_i)
PRIORITY=_P50+PRIORITY
