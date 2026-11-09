# 06:40 ET 11-09: line-audit picks (eye-checked vs live; clear surprise-evolution upgrades) -> sheet + card + portrait (_p99).
_O='briefs/boki-art/batch/out/'
_P=[('Chuggamus','c_chuggamus_x1_4','final','planted on its piston wheels, steam blasting from its stack'),
('Furnacowary','c_furnacowary_x1_1','final','planted on anvil feet, furnace chest roaring'),
('Geysirbara','c_geysirbara_x1_2','final','resting heavy inside its volcanic mound, geyser erupting'),
('Seamwyrm','c_seamwyrm_x1_2','final','coiled and rearing, its zipper torn open down its body'),
('Voltalon','c_voltalon_x1_2','final','planted on a rock, crest crackling with lightning'),
('Lodestaff','c_lodestaff_e2_1','final','standing tall on its spindly legs, lodestone shards orbiting')]
for n,src,st,pose in _P:
    l=n.lower(); s=_O+src+'.jpg'
    TA(n,s); SPECS[-1]['id']=f'ta_{l}_p99'
    SPECS.append({'id':f'{l}_card99','name':f'{n} (hero card)','refs':[s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(n,st,pose)})
    P(f'{l}_p99',n,s,pose)
# More tries for finals whose audit redos were not clearly better.
_C='briefs/boki-art/cards/'
VC('vaultara_x3','Vaultara',_C+'Lockatara.jpg','final',"A huge, low, heavy armoured lizard planted on four thick legs whose entire back is a single giant round bank-vault door with a big spoked handle wheel, the door slightly ajar showing a golden glow inside, key-shaped spikes along its tail. Fundamentally different from Lockatara. One clear idea, few parts.","stern, guarded eyes","gunmetal and brass, with a gold glow",'a padlock, a small lizard, held objects, text','titan','tough')
VC('dreadnoyak_x3','Dreadnoyak',_C+'Prowyak.jpg','final',"A colossal glacier beast planted like a mountain: a mammoth-sized yak whose shaggy coat has frozen into long hanging icicle dreadlocks reaching the ground, a massive ice-prow skull, two huge curved ice tusks. Fundamentally different from Prowyak. One clear idea, few parts.","small, glowing, relentless eyes","frost white and glacier blue, with a deep navy accent",'a helmet, armour, a ship, held objects, text','frost','tough')
VC('forgebrock_x3','Forgebrock',_C+'Anvilbrock.jpg','final',"A huge low honey-badger beast planted on all fours whose whole back has become a glowing coal forge with a stone chimney rising from its shoulders, molten cracks along its flanks, front claws like heavy black iron tongs. Fundamentally different from Anvilbrock. One clear idea, few parts.","fierce, ember-bright eyes and a snarl","charcoal and iron, with a molten orange accent",'an anvil on its back, armour plates, held tools, upright pose, text','ember','tough')
SPECS.append({'id':'c_reapant_w4','name':'Reapant (concept)','refs':[SRA],'runs':4,'aspect':'1:1',
  'prompt':("Creature-collector monster concept art for a fantasy action game. Image 1 is the style reference only; never copy its creatures. "
    "ONE creature only, full body, side three-quarter view, centred with about 8 percent margin, plain flat pale grey background, no shadow, no text, no effects. "
    +CORE+LESSONS+desc("A tall, sleek ANT, clearly an insect: horizontal three-part ant body on SIX long thin legs, NOT standing upright like a person. Its two front legs end in long curved scythe blades held raised. A dark mask-like band across its eyes and a long tattered ribbon-like membrane trailing from its neck give it a ninja feel. One clear idea, few parts.","narrow, glowing eyes and a silent stare","deep plum and black, with a crimson accent",'standing on two legs, a human body, clothing, green, leaves, held weapons','swarm','majestic'))})
