# Hero cards round 2 (01:35 ET 11-09): 18 of 80 passed (>= 8.3, main image). The rest regenerate fresh from the sheet with the
# strengthened CARD prompt (no shadow/glow, face first, signature parts kept) plus the critics' notes for that card.
import json as _j41, re as _r41
_byid={s['id']:s for s in SPECS}
_P41=[]
for _i,_fx in _j41.load(open(HERE/'cards_redo.json')).items():
    if _i not in _byid: continue
    _s=dict(_byid[_i]); _s['id']=_i+'2'; _s['runs']=2
    _notes=" Also: ".join(_r41.sub(r'^(EDIT|New prompt)[:]?\s*(on run \d+,?\s*)?','',f,flags=_r41.I) for f in _fx[:3])
    _s['prompt']=_s['prompt']+" Fix these notes from the last attempt: "+_notes
    SPECS.append(_s); _P41.append(_s['id'])
PRIORITY=PRIORITY+_P41
