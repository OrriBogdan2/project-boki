# 14:16 ET 11-09 retries after reviewing the 13:52 runner batch.
# Echolop/Geodemole kept their old pose; Lunarca's edit stayed cropped at the bottom (the live card is cropped too);
# ta_jibbatross_pc came out as two rows of four. Plus follow-ups for promoted cards (Gongrowl, Vatmander, Voltalon female).
_C='briefs/boki-art/cards/'; _O='briefs/boki-art/batch/out/'
_NEW=" Most important: a completely different pose from image 1; do not reuse its pose, angle or silhouette."
SPECS.append({'id':'echolop_card103','name':'Echolop (hero card)','refs':[_C+'Echolop.jpg',SRA],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':CARD('Echolop','baby','leaping through the air mid-bounce, body stretched out, both huge bat-wing ears swept back by the jump, front paws reaching forward, mouth open in a happy squeak')+_NEW})
SPECS.append({'id':'geodemole_card103','name':'Geodemole (hero card)','refs':[_C+'Geodemole.jpg',SRA],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':CARD('Geodemole','mid','reared up tall on its hind legs, both huge crystal claws raised high over its head as if about to dig down hard, belly toward the viewer, a fierce grin')+_NEW})
SPECS.append({'id':'selenwhale_card101','name':'Lunarca / Selenwhale (hero card)','refs':[_C+'Selenwhale.jpg',SRA],'runs':4,'aspect':'1:1','size':'2K',
  'prompt':CARD('Selenwhale','final','the whole moon whale floating in a gentle S-curve, drawn small enough that its entire body fits inside the frame: the cratered head, belly, both flippers and both tail flukes are all fully visible with clear empty space between them and every edge of the image')+" Nothing may touch or be cut off at any edge of the image."})
TA('Jibbatross',_C+'Jibbatross.jpg'); SPECS[-1]['id']='ta_jibbatross_px'; SPECS[-1]['prompt']+=" Exactly ONE single row of four views side by side, never two rows, never a grid, never eight views."
P('gongrowl_py','Gongrowl',_O+'gongrowl_cardx_3.jpg','standing upright facing the viewer, roaring and pounding the bronze gong on its chest with both fists')
TA('Cisternmander',_C+'Cisternmander.jpg'); SPECS[-1]['id']='ta_cisternmander_px'
P('cisternmander_px','Cisternmander',_C+'Cisternmander.jpg','resting heavily with its mossy pond-and-broken-barrel back steaming, looking off to the side')
SPECS.append({'id':'c_voltalon_f_n2','name':'Voltalon (female form concept)','refs':[_C+'Voltalon.jpg',SRA],'runs':4,'aspect':'1:1',
  'prompt':("Creature-collector monster concept art for a fantasy action game. "+REL['female']+
    "Image 2 is the style reference only; never copy its creatures. ONE creature only, full body, the same gentle three-quarter view and the same pose as image 1, "
    "centred with about 8 percent margin, plain flat pale grey background, no rock, no ground, no shadow, no text, no effects. "+CORE+LESSONS+
    "Keep everything that defines Voltalon so it reads instantly as the same species; change only a few things the way real animals differ by sex: crest shape, tail plumage, the size of its lightning crest, and a teal-and-cream colour tint instead of rust.")})
