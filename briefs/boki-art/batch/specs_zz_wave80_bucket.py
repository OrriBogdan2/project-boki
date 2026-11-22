# 03:55 ET 11-09: Bucketmander line gimmick = B (battery), art session pick (owner asked for my picks; he can swap).
# Bucketmander gb run 1 and Barrelmander gb run 4 go to sheet+card+portrait; Cisternmander's battery direction scored lowest of
# the three (7.6, coil tower read as stuck on), so it gets a fresh battery round built from the picked Barrelmander.
_O='briefs/boki-art/batch/out/'; _P80=[]
for _n,_src,_stg,_pose in (('Bucketmander','c_bucketmander_gb_1','baby','sitting round and happy with a tiny spark between its terminals'),
                           ('Barrelmander','c_barrelmander_gb_4','mid','plodding forward with an arc crackling between its copper terminals')):
    _l=_n.lower()
    TA(_n,_O+_src+'.jpg'); SPECS[-1]['id']='ta_'+_l+'_bat'; _P80.append('ta_'+_l+'_bat')
    SPECS.append({'id':_l+'_card10','name':_n+' (hero card)','refs':[_O+_src+'.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(_n,_stg,_pose)}); _P80.append(_l+'_card10')
    P(_l+'_bat',_n,_O+_src+'.jpg',_pose); _P80.append('portrait_'+_l+'_bat')
_AVB2="a cloud, rain, lightning bolts in the air, a separate machine on its back, a building, a ladder, standing upright, a busy design"
for _k,_b in (('b1',"A giant salamander whose whole body has grown into a huge wooden battery cell bound with thick copper wire bands, two big copper terminal horns on its head with a steady arc between them, a heavy head and broad flat tail, planted wide."),
              ('b2',"A massive battery salamander with a long, broad body made of three connected wooden cells like a row of batteries, copper bus-bar plates joining them along its back, glowing yellow charge lines in the seams, thick planted legs."),
              ('b3',"A towering storage-tank salamander braced wide, its barrel body grown into a big round copper-banded battery drum, glass charge windows on its sides glowing yellow, and its tail ending in a copper plug tip.")):
    VC('cisternmander_'+_k,'Cisternmander',_O+'c_barrelmander_gb_4.jpg','final',_b+" Clearly the final of image 1's battery line. One clear idea, few parts.","small, calm yellow eyes and a wide, slow grin","wood brown and slate grey, with copper and an electric-yellow accent",_AVB2,'storm','tough'); _P80.append('c_cisternmander_'+_k)
PRIORITY=_P80+PRIORITY
