# 10:47 ET 11-09 owner A/B review.
_O='briefs/boki-art/batch/out/'; _C='briefs/boki-art/cards/'
# 1-2: extra angles were not cute enough. (Promoted by hand to cards/<Name>_lying|_back.jpg, NOT over the main card.)
SPECS.append({'id':'xang_vespyx_lying2','name':'Vespyx (extra angle, lying)','refs':[_C+'Vespyx.jpg',SRA],'runs':4,'aspect':'1:1','size':'2K','prompt':CARD('Vespyx','baby','curled up asleep like a tiny kitten, extra round and chubby, eyes closed with a content little smile, its scorpion tail wrapped around the front of its body with the glowing green venom bead resting softly beside its cheek, very cute and cozy')})
SPECS.append({'id':'xang_mycroll_back2','name':'Mycroll (extra angle, on its back)','refs':[_C+'Mycroll.jpg',SRA],'runs':4,'aspect':'1:1','size':'2K','prompt':CARD('Mycroll','baby','lying flat on its back with its round belly up and all four paws in the air, mushroom caps squished against the ground, looking at the viewer upside-down with a happy giggling smile, very cute')})
# 6: Chandelapi -> B design (q2_2) with a better, regal pose.
_s=_O+'c_chandelapi_q2_2.jpg'
TA('Chandelapi',_s); SPECS[-1]['id']='ta_chandelapi_pb'
SPECS.append({'id':'chandelapi_cardb','name':'Chandelapi (hero card)','refs':[_s,SRA],'runs':4,'aspect':'1:1','size':'2K','prompt':CARD('Chandelapi','final','standing tall and regal on all four long legs, head raised proudly, candelabra antlers glowing, calm and majestic, three-quarter view')})
P('chandelapi_pb','Chandelapi',_s,'standing tall and regal on all four long legs, head raised proudly, candelabra antlers glowing')
# 13: Gongrowl: more aggressive action pose.
SPECS.append({'id':'gongrowl_cardb','name':'Gongrowl (hero card, action)','refs':[_C+'Gongrowl.jpg',SRA],'runs':4,'aspect':'1:1','size':'2K','prompt':CARD('Gongrowl','final','rearing up and slamming both fists into the bronze gong on its chest, roaring, shockwave ring around the gong, low heroic angle, very aggressive. Same design as image 1, only the pose changes')})
P('gongrowl_pb','Gongrowl',_C+'Gongrowl.jpg','rearing up and slamming both fists into the bronze gong on its chest, roaring')
# 22: Vespox: more on the shell; test with and without the extra shell eyes.
for _k,_b in enumerate([
 "Keep the creature exactly as image 1 but give the shell hood a row of hooked chitin spikes along its ridge like a crown, and NO extra eyes on the shell.",
 "Keep the creature exactly as image 1 but add glowing acid-green venom sacs set into the shell hood like jewels, and NO extra eyes on the shell.",
 "Keep the creature exactly as image 1 but the shell hood flares wider into a jagged frill with a scorpion-tail-like curl at the back, and NO extra eyes on the shell.",
 "Keep the creature exactly as image 1 including the eye markings on the shell, and add segmented armour plates trailing down its back from the hood."],4):
    VC(f'vespox_v{_k}','Vespox',_O+'c_vespox_v2_3.jpg','mid',_b+" One clear idea, few parts.",'half-hidden glowing eyes under the shell hood and a sly sneer','plum purple and lilac, with an acid-green venom accent','a different body, held objects, effects, text','venom','tough')
# 24: Reapant: between w4 (six-legged ant) and w2 (humanoid ninja): cooler, a bit more humanoid.
for _k,_b in enumerate([
 "A tall ninja ant standing semi-upright on its four back legs like a mantis, upper body raised and leaning forward, two long scythe-blade forearms held ready, a dark mask band across its eyes and a tattered ribbon-like neck membrane flowing like a scarf. Clearly an insect, but with a confident warrior stance.",
 "A sleek ninja ant rising up on its hind four legs into an upright fighting stance, narrow waist, broad armoured thorax like shoulders, scythe forearms crossed in front, a hood-shaped head crest and flowing membrane scarf. Insect body, humanoid posture.",
 "A tall, lean assassin ant mid-stride on four back legs with its torso upright, one scythe arm raised high and one low, a long tattered membrane scarf streaming behind, a mask-like head with glowing eyes."],5):
    SPECS.append({'id':f'c_reapant_w{_k}','name':'Reapant (concept)','refs':[_O+'c_reapant_w4_4.jpg',_O+'c_reapant_w2_2.jpg',SRA],'runs':4,'aspect':'1:1',
      'prompt':("Creature-collector monster concept art for a fantasy action game. Image 1 and image 2 are two versions of this creature: blend them, keeping image 1's insect body and colours and image 2's cooler, more upright ninja attitude. Image 3 is the style reference only. "
        "ONE creature only, full body, three-quarter view, centred with about 8 percent margin, plain flat pale grey background, no shadow, no text, no effects. "
        +CORE+LESSONS+desc(_b+" One clear idea, few parts.",'narrow, glowing eyes and a silent stare','deep plum and black, with a crimson accent','clothing, held weapons, green, leaves, a human face','swarm','majestic'))})
