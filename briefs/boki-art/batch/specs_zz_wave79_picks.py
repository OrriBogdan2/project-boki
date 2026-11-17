# 09:00Z tick: top direction of each owner-requested redesign/evolution goes straight to turnaround + hero card + Dex portrait
# (owner can still swap; alternates shown in chat). Picks from fast lane f28-f34.
_O='briefs/boki-art/batch/out/'; _P79=[]
for _n,_src,_stg,_pose in (
 ('Glaivyx','c_glaivyx_g8_2','final','looming forward with its stinger tail curled high'),
 ('Ringrove','c_ringrove_r6_4','final','sitting back like a great mossy boulder with its mushroom quills glowing'),
 ('Terrasloth','c_terrasloth_t4_2','mid','curling its tail around itself with its little greenhouse panes catching the light'),
 ('Glaciatee','c_glaciatee_s3_4','final','rearing tall with fore-flippers spread wide'),
 ('Lunowl','c_lunowl_m2_1','mid','mid-swoop with its long moth-tail streamers trailing'),
 ('Eclipsowl','c_eclipsowl_e5_4','final','looming with its great eye-spot wings spread'),
 ('Lanceron','c_lanceron_k4_4','final','lowered into a charge with its ice-lance beak forward'),
 ('Pyrraven','c_pyrraven_d5_4','final','braced low and wide, about to lunge'),
 ('Thunderstrich','c_thunderstrich_la_4','final','braced wide with its thundercloud body crackling'),
 ('Mortarfly','c_mortarfly_a2_2','final','planted with its artillery wings raised like shields'),
 ('Effigoon','c_effigoon_c1_3','mid','hanging heavy and armoured from its brass hook tail'),
 ('Gravitank','c_gravitank_g2_1','final','half-curled into its planetoid shell with moonlets orbiting'),
 ('Reapant','c_reapant_n4_2','final','balanced in a wide low ninja ready stance with blade forelegs out'),
 ('Chandelapi','c_chandelapi_m2_2','final','stepping forward lightly with its head turned toward the viewer'),
 ('Barokat','c_barokat_cloud_1','mid','sitting up as a round lookout with wispy clouds swirling around its head'),
 ('Orbitle','c_orbeetle_1','mid','walking head-first with its ringed planet abdomen raised')):
    _l=_n.lower()
    TA(_n,_O+_src+'.jpg'); SPECS[-1]['id']='ta_'+_l+'_p79'; _P79.append('ta_'+_l+'_p79')
    SPECS.append({'id':_l+'_card9','name':_n+' (hero card)','refs':[_O+_src+'.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(_n,_stg,_pose)}); _P79.append(_l+'_card9')
    P(_l+'_p79',_n,_O+_src+'.jpg',_pose); _P79.append('portrait_'+_l+'_p79')
PRIORITY=_P79+PRIORITY
