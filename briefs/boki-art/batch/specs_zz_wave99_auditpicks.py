# 06:40 ET 11-09: line-audit picks (eye-checked vs live; clear surprise-evolution upgrades) -> sheet + card + portrait (_p99).
_O='briefs/boki-art/batch/out/'
_P=[('Chuggamus','c_chuggamus_x1_4','final','planted on its piston wheels, steam blasting from its stack'),
('Furnacowary','c_furnacowary_x1_1','final','planted on anvil feet, furnace chest roaring'),
('Geysirbara','c_geysirbara_x1_2','final','resting heavy inside its volcanic mound, geyser erupting'),
('Seamwyrm','c_seamwyrm_x1_2','final','coiled and rearing, its zipper torn open down its body'),
('Voltalon','c_voltalon_x1_2','final','planted on a rock, crest crackling with lightning'),
('Lodestaff','c_lodestaff_e2_1','final','standing tall on its spindly legs, lodestone shards orbiting')]
for n,src,st,pose in _P:
    l=n.lower(); s=_O+src+'.jpg'
    TA(n,s); SPECS[-1]['id']=f'ta_{l}_p99'
    SPECS.append({'id':f'{l}_card99','name':f'{n} (hero card)','refs':[s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(n,st,pose)})
    P(f'{l}_p99',n,s,pose)
