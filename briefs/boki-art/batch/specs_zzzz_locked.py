# Owner review 01:39 ET 11-09: owner-approved art is final. Drop pending fix/redesign/stance jobs for approved sheets and pending
# portrait jobs for approved portraits (cards are still made). build_jobs.py removes DROP ids from the queue if not started.
import json as _jl, re as _rl
_L=_jl.load(open(HERE/'owner_locked.json'))
_ls=[n.split('_')[0].lower() for n in _L['sheet']]; _lp=[n.lower() for n in _L['portrait']]
DROP=set()
for _s in SPECS:
    _i=_s['id']
    if _rl.search(r'_card\d*$',_i) or _i.startswith('ta_'): continue
    _m=_rl.match(r'^(?:c_|stance2?_|portrait_stance2_)?([a-z]+)',_i.replace('portrait_stance2_','stance2_'))
    _b=_m.group(1) if _m else ''
    if _i.startswith('portrait_'):
        _pb=_rl.match(r'^portrait_(?:stance2_)?([a-z]+)',_i).group(1)
        if _pb in _lp and 'stance2' not in _i: DROP.add(_i)
        if 'stance2' in _i and _pb in _ls: DROP.add(_i)
        continue
    if _b in _ls: DROP.add(_i)
# Intentionality audit 02:50 ET 11-09: these sheets were just redesigned/replaced (their stance-audit text describes the old
# design), Chandelotl waits on the Glassolotl variant pick, lodestick_r2 is an old-wave leftover.
DROP|={'portrait_stance3_'+n for n in ('arcestrel','briarlynx','galleotter','flarmink','chandelotl','glassolotl','prismander','zippelith')}
DROP|={'portrait_chandelotl_full','lodestick_r2'}
# 03:06 ET: new-species sheets get one card job (<n>_card) from the roster wave; skip the duplicate _card3 from wave50.
DROP|={n+'_card3' for n in 'bladypus bullsfrog clinkpede fawngus glaciammoth glazolm grainspin grammite hydrangor lensling loafhopper lurklet malletary maracoil morelkin nymphane puffuse reelacine sarcobra starcap sundormouse tootle torpecone'.split()}
# 03:20 ET: owner cut Puffamus (Teapotamus > Chuggamus). No more Puffamus jobs.
DROP|={s['id'] for s in SPECS if 'puffamus' in s['id']}
# 08:22Z: un-locking Reapant/Thistlynx/Thunderstrich for redesign re-admitted their old stance jobs; those designs are being replaced.
DROP|={p+n for n in ('thunderstrich','reapant','thistlynx') for p in ('stance_','portrait_stance3_','portrait_stance2_')}
# 03:32 ET: owner cut the starters' branch finals: Lashyx and Amanitusk removed. Old Glaivyx/Ringrove fix jobs replaced by wave62.
DROP|={s['id'] for s in SPECS if any(k in s['id'] for k in ('lashyx','amanitusk'))}
DROP|={s['id'] for s in SPECS if any(k in s['id'] for k in ('glaivyx','ringrove')) and not s['id'].startswith(('c_glaivyx_g','c_ringrove_r','c_glaivyx_h','c_glaivyx_o','c_ringrove_y')) and not s['id'].endswith(('_p79','_card9','_p86','_card86','_r86','_p88','_card88','_r88','_gap','_p93','_card93','_r93'))}
# 04:22 ET: Boki whose design came from an owner-reviewed pick already get their own card/portrait/sheet from the pick waves;
# don't let the generic roster waves add duplicate cards or old-audit stance jobs for them.
_PICKED={'glaciatee','bucketmander','barrelmander','gravitank','mortarfly','orbitle','glaivyx','ringrove','terrasloth','lunowl','thunderstrich','reapant','barokat','chandelotl','lanceron','pyrraven','eclipsowl','effigoon','chandelapi','canvastross','glintmole','gloamspire','glomworth','gongibbon','knotling','lanternlong','lyrewing','mossbastion','parasolth','pipeworth','ribbonwyrm','rimekit','rimeshrew','rimefang','selenwhale','tidalisk','umbrathere','nettlynx','sporcupine','teapotamus','umbrink','vespox','anchorbill','zippelith','glassolotl','prismander','anchorhorn','bastionpet','briarlynx','cisternmander','crofthollow','thistlynx'}
DROP|={s['id'] for s in SPECS if (s['id'] in {n+'_card' for n in _PICKED}|{n+'_card3' for n in _PICKED}) or any(s['id'] in (p+n,) for n in _PICKED for p in ('stance_','portrait_stance3_','portrait_stance2_'))}
