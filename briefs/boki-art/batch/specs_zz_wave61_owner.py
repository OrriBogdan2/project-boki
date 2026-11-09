# Owner 03:28 ET 11-09: "barokat alt is def better" -> Barokat b3 (round egg-shaped sitter) replaces the b2 pick.
# "i love chandelotl 1, run it" -> candy cobra confirmed (wave60). Umbrink: owner torn between u3 (indigo, ivory face/paws) and
# u2 (ivory ermine with indigo ink wash); both get a sheet so he can compare them side by side; u2 is the art session's pick.
_O='briefs/boki-art/batch/out/'; _P61=[]
for _n,_id,_src,_stg,_pose in (('Barokat','b3','c_barokat_b3_1','mid','a round, content lookout pose sitting up with the rain cloud above it'),
                               ('Umbrink','u2','c_umbrink_u2_4','final','a proud planted pose with its ink-wash brush tail swept around its feet')):
    _l=_n.lower()
    TA(_n,_O+_src+'.jpg'); SPECS[-1]['id']='ta_'+_l+'_'+_id; _P61.append('ta_'+_l+'_'+_id)
    SPECS.append({'id':_l+'_card6','name':_n+' (hero card)','refs':[_O+_src+'.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(_n,_stg,_pose)}); _P61.append(_l+'_card6')
    P(_l+'_'+_id,_n,_O+_src+'.jpg',_pose); _P61.append('portrait_'+_l+'_'+_id)
# (b2 pick jobs already ran; they are skipped at review instead of promoted)
PRIORITY=_P61+PRIORITY
