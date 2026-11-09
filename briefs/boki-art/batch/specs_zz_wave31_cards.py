# Round 31 (00:15 ET 11-09): hero-card sample passed (Skidlet 8.5, Lunowl owner-review 8.37), so roll canon hero cards
# (STYLE_CANON, CARD()) out to every Boki with a current approved sheet. Input = its sheet; stage from lines/index.json.
import json as _j31, os as _o31
_idx=_j31.load(open(HERE.parent/'lines'/'index.json'))
_stage={}
for _first,_sts in _idx:
    for _k,_s in enumerate(_sts):
        for _n in _s.split(' / '): _stage[_n]=['baby','mid','final'][min(_k,2)] if len(_sts)>2 else (['baby','final'][min(_k,1)])
_OLD={'Amanitusk','Blossmink','Geodelotl','Lanceron','Lanternmit','Prismink','Seamwyrm','Stormit','Terrarimit','Vaultara','Vespox','Voltalon'}
_have={s['id'] for s in SPECS}
_P31=[]
for _d in ('evolutions','turnarounds'):
    for _f in sorted(_o31.listdir(HERE.parent/_d)):
        _n=_f[:-4]
        if not _f.endswith('.jpg') or '_' in _n or _n in _OLD: continue
        _i=_n.lower()
        if _i+'_card' in _have or _i+'_card' in _P31: continue
        SPECS.append({'id':_i+'_card','name':_n+' (hero card)','refs':['briefs/boki-art/'+_d+'/'+_f,SRA],'runs':2,'aspect':'1:1','size':'2K',
          'prompt':CARD(_n,_stage.get(_n,'mid'),'a characterful grounded pose that is natural for this animal, head turned toward the viewer')})
        _P31.append(_i+'_card')
PRIORITY=PRIORITY+_P31
