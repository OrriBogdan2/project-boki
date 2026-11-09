# 12 stuck concepts redesigned in ROSTER_200_NEW.md (01:25 11-09). New concept runs (ids c_<name>_n); later stages use the
# parent's approved turnaround/concept as image 2 when one exists.
_RD=['Fawngus','Malletary','Morelkin','Nymphane','Reelacine','Sarcobra','Torpecone','Glaciammoth','Grammite','Hydrangor','Clinkpede','Tootle']
_nm38=list(ROSTER200); _P38=[]
for _n in _RD:
    if _n not in ROSTER200: continue
    _st=ROSTER200[_n]['stage']; _par=None
    if _st.startswith(('2 of','3 of')):
        _p=_nm38[_nm38.index(_n)-1]
        _par=next((f'briefs/boki-art/{d}/{_p}.jpg' for d in ('turnarounds','concepts') if (HERE.parent/d/f'{_p}.jpg').exists()),None)
    CQ(_n,_par); SPECS[-1]['id']='c_'+_n.lower()+'_n'
    if 'Spore' in _TYPES.get(_n,''): SPECS[-1]['prompt']+=SPORE_NOTE
    _P38.append('c_'+_n.lower()+'_n')
PRIORITY=_P38+PRIORITY
