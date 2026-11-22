# Round 37 (01:35 ET 11-09): round-30 results (s11-s14); items already sent to the owner are not re-fixed; stance redos always regenerate. Round 32 (00:55 ET 11-09): panel results for round-29 fixes (groups s8-s10). Same auto rules as round 29;
# automatically from the panel's own fixes: 'edit' (avg >= 7.9) -> edit of the most-picked run; 'new' -> the original
# prompt again with the panel fixes appended as hard requirements. Source: panel_w31.json.
import json as _j, re as _r
_O='briefs/boki-art/batch/out/'
_JOBS={j['id']:j for j in _j.load(open(HERE/'jobs.json'))}
def _clean(f):
    f=_r.sub(r'^(EDIT|New prompt|Re-run the edit stronger|Relayout|Keep run \d+)[:;,]?\s*','',f or '',flags=_r.I)
    return _r.sub(r'^on run \d+,?\s*','',f,flags=_r.I).strip()
_W31=[]
for _d in _j.load(open(HERE/'panel_w31.json')):
    i=_d['id']; j=_JOBS.get(i)
    base=_r.sub(r'_(w[23]\d|v)$','',i)
    if not j: continue
    fx=[_clean(f) for f in _d['fixes'] if f and not _r.match(r'^(ship|keep run|none)',f.strip(),_r.I)]
    fx=list(dict.fromkeys([f for f in fx if len(f)>8]))
    if not fx: fx=['fix the problems: '+'; '.join(v for v in _d['veto'])] if _d['veto'] else ['make the face more characterful and keep everything clean']
    nid=base+'_w31'; asp=j.get('aspect','16:9')
    if i.startswith('portrait_') and _d['decision']=='new':
        nm=_r.sub(r'^portrait_|_(pe|p2|p|r)$','',base).capitalize()
        sh=next((f'briefs/boki-art/{d}/{nm}.jpg' for d in ('evolutions','turnarounds') if (HERE.parent/d/f'{nm}.jpg').exists()),None)
        if sh:
            P(nid[len('portrait_'):],nm,sh,"its body turned about 30 degrees toward the viewer, head toward the viewer with both eyes visible, a characterful grounded pose. "+" Also: ".join(fx))
            SPECS[-1]['runs']=4; _W31.append(nid); continue
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
    _W31.append(nid)
PRIORITY=PRIORITY+_W31
PRIORITY=[x for x in _W31 if x.startswith('stance_')]+PRIORITY
