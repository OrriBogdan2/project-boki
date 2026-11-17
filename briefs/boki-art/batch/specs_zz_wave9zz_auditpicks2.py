# 06:55 ET 11-09: audit batch 2 picks (eye-checked vs live; all clear upgrades under owner rules) -> sheet + card + portrait (_pz).
_O='briefs/boki-art/batch/out/'
_P=[('Dragonkite','c_dragonkite_x1_3','final','planted and rearing, paper-sail wings spread'),
('Dreadnoyak','c_dreadnoyak_x3_2','final','planted like a mountain, icicle coat hanging to the ground'),
('Geodemole','c_geodemole_x1_2','final','planted mid-dig, crystal claws thrust forward'),
('Lanternmit','c_lanternmit_x1_3','final','standing tall on long legs, lantern body glowing'),
('Reapant','c_reapant_w4_4','final','poised on six legs with scythe forelegs raised'),
('Skateron','c_skateron_x1_3','mid','gliding fast in a low racing crouch, frost trail behind'),
('Sporcupine','c_sporcupine_x1_2','final','scurrying low with toadstool quills swaying'),
('Stormit','c_stormit_x1_4','final','scuttling sideways on tall legs, storm tower crackling'),
('Terrarimit','c_terrarimit_x1_3','final','planted with root legs, garden mound on its back'),
('Vaultara','c_vaultara_x3_1','final','planted heavy, vault-door back gleaming')]
for n,src,st,pose in _P:
    l=n.lower(); s=_O+src+'.jpg'
    TA(n,s); SPECS[-1]['id']=f'ta_{l}_pz'
    SPECS.append({'id':f'{l}_cardz','name':f'{n} (hero card)','refs':[s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(n,st,pose)})
    P(f'{l}_pz',n,s,pose)
TA('Voltalon',_O+'c_voltalon_x1_2.jpg'); SPECS[-1]['id']='ta_voltalon_rz'
