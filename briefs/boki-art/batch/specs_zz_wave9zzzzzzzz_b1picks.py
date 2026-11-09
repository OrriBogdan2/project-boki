# 12:00 ET 11-09 OWNER REVIEW batch 1 picks (art review of c_<name>_b1-b3). Best concept -> sheet + card + portrait.
# The owner sees every direction on the A/B page and can swap ("use X for Y"); these go ahead meanwhile (rule: push the best pick).
# Coolatee  b2_3 (cream giggling seal pup, green eyes like Frigatee)        alts b2_4 (cooler lid + latch), b1_2
# Druzemole b3_4 (geode-shell dome mole titan, crystal crown, planted)      alts b2_3 (crystal-ridge maw), b2_4; b1 = Geodemole copy, b3_2 person-like
# Scythant  b1_2 (lean leaf ant mid-run, leaf sickles, plum legs)           alts b3_2 (leaf-hood ninja), b1_3; b2 ghost antennae, b1_4 off-model fox
# Jibbatross b1_1 (albatross gliding, jib sail grown from its back)         alts b2_2 (bigger head, open beak), b1_2; b3 rope harness reads strapped
_O='briefs/boki-art/batch/out/'
_P=[('Coolatee','coolatee','c_coolatee_b2_3','baby','sitting up mid-bounce on its tail flippers, belly round like a snowball, giggling with its mouth open'),
    ('Druzemole','druzemole','c_druzemole_b3_4','final','braced wide and planted on all four crystal-clawed feet, geode shell dome raised high behind it, glaring proudly'),
    ('Scythant','scythant','c_scythant_b1_2','mid','dashing forward low on its six legs, leaf-sickle forelegs swept back, leaf-scrap tail streaming behind'),
    ('Jibbatross','jibbatross','c_jibbatross_b1_1','mid','gliding low with its long wings spread wide, the jib sail on its back filled with wind, rope-feather tail streaming')]
for _n,_i,_c,_st,_pose in _P:
    _s=_O+_c+'.jpg'
    TA(_n,_s); SPECS[-1]['id']=f'ta_{_i}_pb'
    SPECS.append({'id':f'{_i}_cardb','name':f'{_n} (hero card)','refs':[_s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(_n,_st,_pose)})
    P(f'{_i}_pb',_n,_s,_pose)
