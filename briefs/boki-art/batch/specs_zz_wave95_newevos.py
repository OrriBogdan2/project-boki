# 06:00 ET 11-09: picks for the new evolutions + Lodestick first art (eye-checked), -> sheet + card + portrait (_p95).
_O='briefs/boki-art/batch/out/'
_P=[('Lodestick','c_lodestick_e1_1','final','balancing on its twig legs with lodestone flakes orbiting'),
('Moatpole','c_moatpole_e2_2','baby','sitting round and squishy, looking up with big eyes'),
('Moundlet','c_moundlet_e1_4','baby','sitting with its little clay mound on its back, sniffing the air'),
('Murmuron','c_murmuron_e2_2','final','wings spread wide, a swirl of tiny birds forming its body'),
('Spanglin','c_spanglin_e1_2','baby','curled into a shiny disco ball, peeking out')]
for n,src,st,pose in _P:
    l=n.lower(); s=_O+src+'.jpg'
    TA(n,s); SPECS[-1]['id']=f'ta_{l}_p95'
    SPECS.append({'id':f'{l}_card95','name':f'{n} (hero card)','refs':[s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(n,st,pose)})
    P(f'{l}_p95',n,s,pose)
TA('Crofthollow',_O+'c_crofthollow_z1_1.jpg'); SPECS[-1]['id']='ta_crofthollow_r95'
