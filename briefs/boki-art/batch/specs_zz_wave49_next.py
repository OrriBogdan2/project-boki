# Round 32 results (02:10 ET 11-09): turnarounds for concepts at pass/owner tier, sheets from the passing square stance images.
import json as _j49
_pk=_j49.load(open('/tmp/claude-0/-home-claude/8d7770c0-fbec-571e-85de-44fde799926f/scratchpad/r32_picks.json'))
_O='briefs/boki-art/batch/out/'
_P49=[]
TA('Pebblamb','briefs/boki-art/concepts/Pebblamb.jpg'); _P49.append('ta_pebblamb')
for _c,_n in [('c_chandelotl_a','Chandelotl'),('c_geodelotl_a','Geodelotl'),('c_blotlet','Blotlet'),('c_sloggoth','Sloggoth'),('c_arcestrel_v2','Arcestrel'),
              ('c_blossmink_v2','Blossmink'),('c_briarlynx_v2','Briarlynx'),('c_flarmink_v2','Flarmink'),('c_galleotter_v2','Galleotter')]:
    if _c in _pk: TA(_n,_O+f'{_c}_{_pk[_c]}.jpg'); SPECS[-1]['id']='ta_'+_c[2:]; _P49.append('ta_'+_c[2:])
for _n in ['bellowary','boltstrich','chandelapi','frigatee','latchling','lockatara','prowyak','puffamus','ringrove','snuffapi','soakybara','sporcupine']:
    _c='portrait_stance2_'+_n
    if _c in _pk: TA(_n.capitalize(),_O+f'{_c}_{_pk[_c]}.jpg'); SPECS[-1]['id']='ta_'+_n+'_stance'; _P49.append('ta_'+_n+'_stance')
PRIORITY=_P49+PRIORITY
