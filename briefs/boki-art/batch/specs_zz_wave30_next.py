# Round 30 (00:20 ET 11-09): next steps for concepts that passed (Pavonazar) or went to owner review (owner: don't block on him).
# Turnaround from the chosen concept image + the next stage's concept with the chosen image as the parent. Owner can still reject.
_O='briefs/boki-art/batch/out/'
_NX=[('Pavonazar','briefs/boki-art/concepts/Pavonazar.jpg'),('Gilabacus',_O+'c_gilabacus_r_w28_1.jpg'),('Olmlet',_O+'c_olmlet_r_w28_1.jpg'),
     ('Pawnfry',_O+'c_pawnfry_e_w28_1.jpg'),('Pocketpus',_O+'c_pocketpus_e_w28_2.jpg'),('Polyshroom',_O+'c_polyshroom_e_w28_3.jpg'),
     ('Proofhop',_O+'c_proofhop_r_w28_1.jpg')]
_names=list(ROSTER200)
_P30=[]
for _n,_p in _NX:
    TA(_n,_p); _P30.append('ta_'+_n.lower())
    _k=_names.index(_n)
    if _k+1<len(_names) and ROSTER200[_names[_k+1]]['stage'].startswith('2 of'):
        CQ(_names[_k+1],_p); _P30.append('c_'+_names[_k+1].lower())
        if 'Spore' in _TYPES.get(_names[_k+1],''): SPECS[-1]['prompt']+=SPORE_NOTE
PRIORITY=PRIORITY+_P30
