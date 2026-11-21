# Round 33 (01:05 ET 11-09): next steps. Concepts passed (Narfoil) or in owner review (Bullpole, Foldbat, Glacione, Pinster,
# Rattlebub) -> turnaround + next-stage concept. New approved turnarounds -> Pokedex portrait (cards come from wave31's scan).
_O='briefs/boki-art/batch/out/'
_NX33=[('Narfoil','briefs/boki-art/concepts/Narfoil.jpg'),('Bullpole',_O+'c_bullpole_e_w29_2.jpg'),('Foldbat',_O+'c_foldbat_e_w29_2.jpg'),
       ('Glacione',_O+'c_glacione_r_w29_3.jpg'),('Pinster',_O+'c_pinster_e_w29_2.jpg'),('Rattlebub',_O+'c_rattlebub_e_w29_2.jpg')]
_names33=list(ROSTER200); _P33=[]
_ids33={s['id'] for s in SPECS}
for _n,_p in _NX33:
    if 'ta_'+_n.lower() not in _ids33: TA(_n,_p); _P33.append('ta_'+_n.lower())
    _k=_names33.index(_n)
    if _k+1<len(_names33) and ROSTER200[_names33[_k+1]]['stage'].startswith('2 of') and 'c_'+_names33[_k+1].lower() not in _ids33:
        CQ(_names33[_k+1],_p); _P33.append('c_'+_names33[_k+1].lower())
        if 'Spore' in _TYPES.get(_names33[_k+1],''): SPECS[-1]['prompt']+=SPORE_NOTE
for _n in ['Bathilus','Cubbat','Gilabacus','Olmlet','Pawnfry','Polyshroom','Proofhop']:
    if 'portrait_'+_n.lower() in _ids33: continue
    P(_n.lower(),_n,'briefs/boki-art/turnarounds/'+_n+'.jpg',"its body turned about 30 degrees toward the viewer, head toward the viewer with both eyes visible, a characterful grounded pose")
    SPECS[-1]['runs']=3; _P33.append('portrait_'+_n.lower())
PRIORITY=PRIORITY+_P33
