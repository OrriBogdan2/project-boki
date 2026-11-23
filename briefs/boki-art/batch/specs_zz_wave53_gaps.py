# Tick 02:55 ET 11-09 (queue empty). Only intentional gap-fillers:
# 1) Gravigrub redesign (crescent-moon grub; 4 rounds failed on a held moon ball, so its line was blocked).
# 2) Hero cards for live sheets that never had a card job (Blossmink, Geodelotl, Lanternmit, Prismink, Vespox).
#    Amanitusk is skipped until its redesign passes.
_P53=[]
CQ('Gravigrub',None); SPECS[-1]['id']='c_gravigrub_n'; SPECS[-1]['runs']=4; _P53.append('c_gravigrub_n')
import os as _o53
for _n,_s in (('Blossmink','final'),('Geodelotl','mid'),('Lanternmit','baby'),('Prismink','mid'),('Vespox','final')):
    _d=next(d for d in ('evolutions','turnarounds') if _o53.path.exists(HERE.parent/d/f'{_n}.jpg'))
    _i=_n.lower()+'_card3'
    if _i in {s['id'] for s in SPECS}: continue
    SPECS.append({'id':_i,'name':_n+' (hero card)','refs':[f'briefs/boki-art/{_d}/{_n}.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K',
      'prompt':CARD(_n,_s,'a characterful grounded pose that is natural for this animal and different from its sheet pose, head turned toward the viewer')})
    _P53.append(_i)
PRIORITY=_P53+PRIORITY
