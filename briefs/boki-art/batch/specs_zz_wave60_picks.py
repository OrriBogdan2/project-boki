# 08:35Z: owner asked to stop waiting on him for redesigns. Best direction of each owner-requested redesign goes straight to a
# turnaround + hero card + Dex portrait (owner can still swap). Picks from fast lane f19/f20:
_O='briefs/boki-art/batch/out/'; _P60=[]
for _n,_src,_stg,_pose in (
 ('Chandelotl','c_chandelotl_d2_2','final','a commanding raised cobra pose with the sugar-glass hood fanned wide'),
 ('Barokat','c_barokat_b2_4','mid','an alert, chunky lookout pose with its head lifted and the rain cloud above it'),
 ('Nettlynx','c_nettlynx_la_1','baby','a round, bouncy kitten pose with the big nettle-leaf ears perked up'),
 ('Sporcupine','c_sporcupine_s1_1','mid','a puffed-up pose with its short mushroom quills raised along its back'),
 ('Teapotamus','c_teapotamus_t1_1','baby','a happy little bounce with a small puff of steam from its spout tail'),
 ('Umbrink','c_umbrink_u3_3','final','a sly planted pose looking back over its shoulder with the brush tail curled in an S')):
    _l=_n.lower()
    TA(_n,_O+_src+'.jpg'); SPECS[-1]['id']='ta_'+_l+'_pick'; _P60.append('ta_'+_l+'_pick')
    SPECS.append({'id':_l+'_card5','name':_n+' (hero card)','refs':[_O+_src+'.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(_n,_stg,_pose)}); _P60.append(_l+'_card5')
    P(_l+'_pick',_n,_O+_src+'.jpg',_pose); _P60.append('portrait_'+_l+'_pick')
PRIORITY=_P60+PRIORITY
# Thistlynx la kept a realistic narrow-eyed lynx face; retry with the round cartoon face of the new Nettlynx (image 1 = new baby).
VC('thistlynx_lc','Thistlynx',_O+'c_nettlynx_la_1.jpg','mid',
 "A lean, long-legged young lynx caught in a low prowl, its neck ringed with a spiky mane of round thistle-burr puffs, tall pointed nettle-leaf ears like image 1 but longer, and a long tail ending in a big spiky thistle-ball."+_FACE+" Keep the same round cartoon face, big eyes and fang as image 1, just a little older. One clear idea, few parts.",
 "big glossy green eyes like image 1, narrowed into a sly smirk","tawny brown and nettle green, with a toxic lime accent",_AVL,'venom','fast')
PRIORITY=['c_thistlynx_lc']+PRIORITY
