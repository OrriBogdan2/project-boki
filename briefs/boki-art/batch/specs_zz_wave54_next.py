# Tick 03:05 ET 11-09 (fast lane f10-f18 + panel w33c):
# 1) Glassolotl rock-candy upgrade: pick c_glassolotl_v3 run 3 (8.4, "same creature, much less plain") -> turnaround.
# 2) Stance images that reached 7.5+ -> turnaround in that stance (ta_<n>_stance), so each line gets distinct stances.
# 3) Fix round (_w33) for items under 7.5: Glaivyx stance image, Dobsabre concept, with the critics' fix notes.
import json as _j54
_W=_j54.load(open(HERE/'panel_w33.json')); _O='briefs/boki-art/batch/out/'; _P54=[]
_ids54={s['id'] for s in SPECS}
TA('Glassolotl',_O+'c_glassolotl_v3_3.jpg'); SPECS[-1]['id']='ta_glassolotl_v3'; _P54.append('ta_glassolotl_v3')
for _n,_k in _W['stance'].items():
    _i='ta_'+_n+'_stance'
    if _i in _ids54: _i+='3'
    TA(_n.capitalize(),_O+f'portrait_stance3_{_n}_{_k}.jpg'); SPECS[-1]['id']=_i; _P54.append(_i)
_by={s['id']:s for s in SPECS}
for _i,_fx in _W['fix'].items():
    if _i not in _by: continue
    _s=dict(_by[_i]); _s['id']=_i+'_w33'; _s['runs']=3
    _s['prompt']=_s['prompt']+' Reviewer notes from the last round, apply them: '+' '.join(f.replace('EDIT:','').strip() for f in _fx)
    SPECS.append(_s); _P54.append(_s['id'])
PRIORITY=_P54+PRIORITY
# 4) Glassolotl's live card and Dex portrait still show the old crystal design: redo both from the rock-candy v3 pick.
SPECS.append({'id':'glassolotl_card4','name':'Glassolotl (hero card)','refs':[_O+'c_glassolotl_v3_3.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':CARD('Glassolotl','mid','an in-motion pose, mid-stride with the striped rock-candy tail swinging, head turned toward the viewer')})
_P54.append('glassolotl_card4')
P('glassolotl_v3','Glassolotl',_O+'c_glassolotl_v3_3.jpg','a cheeky head-tilt toward the viewer with the crystal gills fanned'); _P54.append('portrait_glassolotl_v3')
PRIORITY=['glassolotl_card4','portrait_glassolotl_v3']+PRIORITY
