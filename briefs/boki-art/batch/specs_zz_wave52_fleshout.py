# Owner 02:40 ET 11-09: "by tomorrow the full Boki roster is fleshed out and perfect: portraits, stance redraws, etc." Big fill wave:
# 1) turnarounds for every new-species concept that reached pass/owner tier but has no sheet yet
# 2) next-stage concepts for new-species lines whose previous stage has a concept/sheet
# 3) Pokedex portraits for every Boki with a sheet but no portrait
# 4) square stance images for every remaining stance-audit stage (sheet follows when it passes)
import os as _o52, json as _j52, re as _r52
_B=HERE.parent
_sheets={x[:-4] for d in ('turnarounds','evolutions') for x in _o52.listdir(_B/d) if x.endswith('.jpg') and '_' not in x}
_ports={x[:-4] for x in _o52.listdir(_B/'portraits'/'light')}
_ids={s['id'] for s in SPECS}
_best={k:v for k,v in _j52.load(open(HERE/'best_concepts.json')).items() if not k.startswith('Seaglass')}
_P52=[]
for _n,(_p,_g) in _best.items():
    if _n in _sheets or ('ta_'+_n.lower()) in _ids or _n not in ROSTER200: continue
    TA(_n,_p); _P52.append('ta_'+_n.lower())
_nm=list(ROSTER200)
for _k,_n in enumerate(_nm):
    _st=ROSTER200[_n]['stage']
    if not _r52.match(r'[23] of',_st) or ('c_'+_n.lower()) in _ids or _n in _sheets: continue
    _prev=_nm[_k-1]
    _par=next((f'briefs/boki-art/{d}/{_prev}.jpg' for d in ('turnarounds','evolutions','concepts') if (_B/d/f'{_prev}.jpg').exists()),None) or (_best.get(_prev,[None])[0])
    if not _par: continue
    CQ(_n,_par)
    if 'Spore' in _TYPES.get(_n,''): SPECS[-1]['prompt']+=SPORE_NOTE
    _P52.append('c_'+_n.lower())
for _d in ('turnarounds','evolutions'):
    for _f in sorted(_o52.listdir(_B/_d)):
        _n=_f[:-4]
        if not _f.endswith('.jpg') or '_' in _n or _n in _ports: continue
        _i='portrait_'+_n.lower()+'_full'
        if _i in _ids: continue
        P(_n.lower()+'_full',_n,f'briefs/boki-art/{_d}/{_f}',"a characterful, natural pose that shows off its signature feature, body turned about 30 degrees toward the viewer, head toward the viewer")
        _P52.append(_i)
_aud=_j52.load(open(HERE/'stance_audit.json'))
_done={'Vespyx','Mycroll','Ermink','Teapotamus','Dribbara','Geysirbara','Kerchick','Oarlet','Tinbrock','Bubblisk','Nettlynx','Bellowary','Boltstrich','Chandelapi','Latchling','Lockatara','Prowyak','Puffamus','Ringrove','Snuffapi','Soakybara','Sporcupine'}
_lock=set(_j52.load(open(HERE/'owner_locked.json'))['sheet'])
for _a in _aud:
    _n=_a['stage']
    if not _a.get('redo') or _n in _done or _n in _lock or 'OLD DESIGN' in _a.get('current','').upper(): continue
    _src=next((f'briefs/boki-art/{d}/{_n}.jpg' for d in ('evolutions','turnarounds') if (_B/d/f'{_n}.jpg').exists()),None)
    _i='portrait_stance3_'+_n.lower()
    if not _src or _i in _ids: continue
    P('stance3_'+_n.lower(),_n,_src,_a['new_stance']+" This stance is the whole point of the image: clearly different from the pose in image 1.")
    SPECS[-1]['prompt']=SPECS[-1]['prompt'].replace("an interesting, characteristic pose full of personality and attitude","exactly this stance")
    _P52.append(_i)
PRIORITY=PRIORITY+_P52
