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
# Owner 03:30: Umbrink alt (u2) confirmed -> u3 pick jobs are skipped at review. Barokat: another character already has a rain
# cloud, so swap Barokat's little rain cloud for soft wispy cloud puffs swirling around his head like a fluffy halo.
SPECS.append({'id':'c_barokat_cloud','name':'Barokat (cloud halo edit)','refs':[_O+'c_barokat_b3_1.jpg'],'runs':4,'aspect':'1:1','size':'2K',
 'prompt':("Edit image 1 and keep everything about this creature exactly the same (face, body, colours, brass horn ears, barometer belly dial,"
  " lightning-rod tail, pose, style, background) except one change: remove the small grey rain cloud and raindrops above its head, and instead"
  " give it soft, wispy white cloud puffs that swirl loosely around its head and shoulders like a fluffy halo of cloud, drifting and curling,"
  " light and airy, partly see-through, with no rain. Keep the cloud close around the head, not a separate cloud floating above.")})
PRIORITY=['c_barokat_cloud']+PRIORITY
