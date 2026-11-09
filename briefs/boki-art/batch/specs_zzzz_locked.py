# Owner review 01:39 ET 11-09: owner-approved art is final. Drop pending fix/redesign/stance jobs for approved sheets and pending
# portrait jobs for approved portraits (cards are still made). build_jobs.py removes DROP ids from the queue if not started.
import json as _jl, re as _rl
_L=_jl.load(open(HERE/'owner_locked.json'))
_ls=[n.split('_')[0].lower() for n in _L['sheet']]; _lp=[n.lower() for n in _L['portrait']]
DROP=set()
for _s in SPECS:
    _i=_s['id']
    if _i.endswith(('_card','_card2','_card3')) or _i.startswith('ta_'): continue
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
