# 11:14 ET 11-09 owner round-2 picks.
_O='briefs/boki-art/batch/out/'; _C='briefs/boki-art/cards/'
# 1: Vespyx lying = option 2 design, but add its head tuft from the main card and a SHARP tail tip with the venom orb (no pincer).
SPECS.append({'id':'xang_vespyx_lying3','name':'Vespyx (extra angle, lying)','refs':[_O+'xang_vespyx_lying2_2.jpg',_C+'Vespyx.jpg',SRA],'runs':4,'aspect':'1:1','size':'2K','prompt':CARD('Vespyx','baby','exactly the cute curled-up lying pose and design of image 1, but restore the little tuft of hair on top of its head from image 2, and make the tail end in a single sharp stinger point with the glowing green venom orb at the tip (no pincer, no claw). Keep it very cute')})
# 2: Mycroll = fallen over onto its side (NOT upside down), same camera angle as its main card, a little panicked.
SPECS.append({'id':'xang_mycroll_fallen','name':'Mycroll (extra angle, fallen over)','refs':[_C+'Mycroll.jpg',SRA],'runs':4,'aspect':'1:1','size':'2K','prompt':CARD('Mycroll','baby','fallen over onto its side (not upside down), seen from the same camera angle as image 1, legs flailing a little, mushroom caps tilted, wide panicked eyes and a small worried open mouth, cute and funny')})
# 4: Gongrowl = card 1 action, but facing the camera more and more upright.
SPECS.append({'id':'gongrowl_cardc','name':'Gongrowl (hero card, action)','refs':[_O+'gongrowl_cardb_1.jpg',SRA],'runs':4,'aspect':'1:1','size':'2K','prompt':CARD('Gongrowl','final','the same chest-pounding action and design as image 1, but turned to face the camera more directly and standing more upright and tall, fists slamming the bronze chest gong, roaring at the viewer')})
P('gongrowl_pc','Gongrowl',_O+'gongrowl_cardb_1.jpg','standing upright facing the viewer, fists slamming the bronze chest gong, roaring')
# 6: Vespox = jagged frill (v6_1) -> sheet + card + portrait.
_s=_O+'c_vespox_v6_1.jpg'
TA('Vespox',_s); SPECS[-1]['id']='ta_vespox_pc'
SPECS.append({'id':'vespox_cardc','name':'Vespox (hero card)','refs':[_s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD('Vespox','mid','prowling low in motion under its jagged frilled shell hood, pincer claws raised')})
P('vespox_pc','Vespox',_s,'prowling low under its jagged frilled shell hood, pincer claws raised')
# 7: Reapant = mid-stride (w7_2) but less tall, closer to camera, more Boki-like (chunkier, bigger head, cuter proportions).
for _k in (8,9,10):
    SPECS.append({'id':f'c_reapant_w{_k}','name':'Reapant (concept)','refs':[_O+'c_reapant_w7_2.jpg',SRA],'runs':4,'aspect':'1:1',
      'prompt':("Creature-collector monster concept art for a fantasy action game. Image 1 is this creature: keep its plum and black colours, mid-stride ninja pose with one scythe raised, and tattered scarf membrane. Image 2 is the style reference only. "
        "Make it LESS tall and LESS human: shorter, chunkier insect body with a bigger head and bigger eyes, Boki-like creature proportions, framed closer to the camera so it fills the frame. "
        "ONE creature only, full body, three-quarter view, centred with about 8 percent margin, plain flat pale grey background, no shadow, no text, no effects. "
        +CORE+LESSONS+desc("A compact ninja ant mid-stride, one scythe forearm raised, scarf membrane flowing, mask band across its eyes. One clear idea, few parts.",'big narrow glowing eyes and a determined stare','deep plum and black, with a crimson accent','a human body, long human legs, clothing, held weapons, green','swarm','tough'))})
