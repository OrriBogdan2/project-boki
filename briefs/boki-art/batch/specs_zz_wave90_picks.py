# 05:15 ET 11-09 tick (owner asleep; picks eye-checked against his notes). Top direction -> sheet + card + portrait (_p88).
_O='briefs/boki-art/batch/out/'
_P=[('Prismink','c_prismink_m3_3','final','prowling proudly with its crystal gem mane glittering'),
('Rimink','c_rimink_m3_1','final','stepping lightly on frozen tiptoes, poised and elegant'),
('Rippmink','c_rippmink_m2_1','final','swimming through the air in a looping S-curve'),
('Flarmink','c_flarmink_m2_4','final','planted firm with its huge bonfire tail blazing over its back'),
('Effigoon','c_effigoon_g2_4','mid','hanging still from its thick silk cable, sealed and faceless'),
('Glaivyx','c_glaivyx_h4_1','final','standing tall on long legs with its blade tail raised high'),
('Cisternmander','c_cisternmander_y2_1','final','sitting heavy and calm with water spilling from the pond on its back'),
('Vespox','c_vespox_v2_3','mid','prowling low under its shell hood with pincer claws raised')]
for n,src,st,pose in _P:
    l=n.lower(); s=_O+src+'.jpg'
    TA(n,s); SPECS[-1]['id']=f'ta_{l}_p88'
    SPECS.append({'id':f'{l}_card88','name':f'{n} (hero card)','refs':[s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(n,st,pose)})
    P(f'{l}_p88',n,s,pose)
# retries of failed wave86 outputs
TA('Ringrove',_O+'c_ringrove_y1_2.jpg'); SPECS[-1]['id']='ta_ringrove_r88'
SPECS.append({'id':'eclipsowl_card88','name':'Eclipsowl (hero card)','refs':[_O+'c_eclipsowl_d2_2.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD('Eclipsowl','final','perched on a rock with wings half spread, looming and dark')})
SPECS.append({'id':'pipeworth_card88','name':'Pipeworth (hero card)','refs':[_O+'c_pipeworth_e2_1.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD('Pipeworth','final','standing planted and proud, full body clearly visible')})
P('bastionpet_r88','Bastionpet',_O+'c_bastionpet_z1_2.jpg','planted firm with its armoured shell braced')
P('eclipsowl_r88','Eclipsowl',_O+'c_eclipsowl_d2_2.jpg','perched on a rock with wings half spread, looming and dark')
