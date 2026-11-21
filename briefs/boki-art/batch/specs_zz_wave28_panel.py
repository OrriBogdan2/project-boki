# Round 28 (23:35 ET 11-08): full panel results for screen groups s1-s4 (160 jobs, 11 pass). Every non-pass is queued
# automatically from the panel's own fixes: 'edit' (avg >= 7.9) -> edit of the most-picked run; 'new' -> the original
# prompt again with the panel fixes appended as hard requirements. Source: panel_w28.json.
import json as _j, re as _r
_O='briefs/boki-art/batch/out/'
_JOBS={j['id']:j for j in _j.load(open(HERE/'jobs.json'))}
def _clean(f):
    f=_r.sub(r'^(EDIT|New prompt|Re-run the edit stronger|Relayout|Keep run \d+)[:;,]?\s*','',f or '',flags=_r.I)
    return _r.sub(r'^on run \d+,?\s*','',f,flags=_r.I).strip()
_W28=[]
for _d in _j.load(open(HERE/'panel_w28.json')):
    i=_d['id']; j=_JOBS.get(i)
    if not j: continue
    fx=[_clean(f) for f in _d['fixes'] if f and not _r.match(r'^(ship|keep run|none)',f.strip(),_r.I)]
    fx=list(dict.fromkeys([f for f in fx if len(f)>8]))
    if not fx: fx=['fix the problems: '+'; '.join(v for v in _d['veto'])] if _d['veto'] else ['make the face more characterful and keep everything clean']
    nid=i+'_w28'; asp=j.get('aspect','16:9')
    if _d['decision']=='edit' and _d['pick']:
        src=_O+i+'_'+str(_d['pick'])+'.jpg'
        if asp=='1:1':
            p=("Edit image 1: keep the same creature, design, colours and style, centred and filling about 85 percent of the square on a plain flat pale grey background, "
               "no effects, no shadows, no glow. Make all of these changes: "+" Also: ".join(fx))
        else:
            p=("Edit image 1: keep the same creature, design, colours and style, exactly four views (front, three-quarter, side, back) in ONE clean row on a plain flat pale grey "
               "background, no shadows, no ghost copies. Make all of these changes: "+" Also: ".join(fx))
        SPECS.append({'id':nid,'name':j['name'],'refs':[src],'runs':3,'aspect':asp,'prompt':p})
    else:
        SPECS.append({'id':nid,'name':j['name'],'refs':list(j['refs']),'runs':4,'aspect':asp,
          'prompt':j['prompt']+" The last attempt failed review. These panel fixes are hard requirements: "+" Also: ".join(fx)})
    _W28.append(nid)
TA('Scoopsy','briefs/boki-art/concepts/Scoopsy.jpg'); CQ('Sundormouse','briefs/boki-art/concepts/Scoopsy.jpg')
PRIORITY=PRIORITY+['ta_scoopsy','c_sundormouse']+_W28
