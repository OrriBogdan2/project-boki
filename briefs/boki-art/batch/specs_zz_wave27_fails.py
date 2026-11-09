# Round 27 (23:45 ET): screener zero-survivor jobs -> new prompts. Repeat offenders (armour, ghost rows, hat caps) get the
# concept-first route: one square concept image (judged on design), then a turnaround from it.
def VC(i,n,ref,rel,body,face,cols,avoid,el,arch):
    # single square concept for an existing-line evolution (concept-first); turnaround follows when it passes
    SPECS.append({'id':'c_'+i,'name':n+' (concept)','refs':[ref,SRA],'runs':4,'aspect':'1:1',
      'prompt':("Creature-collector monster concept art for a fantasy action game. "+REL[rel]+"Image 2 is the style reference only (soft hand-painted shading, clean thin dark outline, big glossy eyes); never copy its creatures. "
        "ONE creature only, full body, gentle three-quarter view with the head turned toward the viewer, centred with about 8 percent margin, plain flat pale grey background, no shadow, no text, no effects. "
        +CORE+LESSONS+desc(body,face,cols,avoid,el,arch))})
NO_ARMOUR=" Bare fur and skin on the head, neck, shoulders, arms and legs: no metal plates, pauldrons, gauntlets, cuffs, bands, straps, frames or harness anywhere."
VC('gongrowl','Gongrowl',T+'Gongibbon.jpg','final',
 "A huge, stylised knuckle-walking silverback ape with an oversized head and shaggy dark fur, whose spine rises into two horn-like bony ridges with one big round bronze gong disc grown between them as part of its back, and whose knuckles are bare bronze-coloured callused knobs."+NO_ARMOUR,
 "deep-set, fierce eyes and a booming roar","dark grey and bronze, with a gold accent","armour, a backpack frame, straps, held mallets, a lanky gibbon",'echo','tough')
VC('furnacowary','Furnacowary',T+'Bellowary.jpg','final',
 "A massive, low, forward-hunched forge bird with a deep barrel body whose ribs glow through its soot-black feathers like furnace grate bars, a short thick neck with a bony chimney crest grown from the skull, short thick scaly legs with big bronze-coloured spur claws, and spread ember-edged wings."+NO_ARMOUR,
 "fierce, glowing eyes and a scorching glare","soot black and bronze, with a molten-orange accent","a tall upright cassowary, a plate on its chest, metal on the legs",'ember','majestic')
VC('dreadnoyak','Dreadnoyak',T+'Prowyak.jpg','final',
 "A hulking glacier beast whose whole front half is a huge iceberg-shaped skull with a grown ice-keel jaw, a low wedge-shaped body sloping back from a raised ridge of jagged ice growing out of its shaggy frost-white coat, and short pillar-like legs; it reads as a living icebreaker, not a yak."+NO_ARMOUR,
 "small, glaring, unstoppable eyes and a deep, stubborn scowl","frost white and glacier blue, with a dark iron accent","riveted plates, armour, a helmet, a realistic yak",'frost','tough')
VC('kayak','Kayak',T+'Prowyak.jpg','baby',
 "A tiny, round, fluffy yak calf with a short, flat, wedge-shaped pale ice prow growing from the fur of its brow (not a horn), a faint keel ridge down its back, stubby legs, a puffy tail and frost crystals in its fluff.",
 "big, curious eyes and a determined little huff","frost white and pale grey, with an ice-blue accent","a horn, a helmet plate, other creatures",'frost','cute')
VC('sporcupine','Sporcupine',T+'Mycroll.jpg','mid',
 "A long, low porcupine with brown quilled flanks, a long snout and a bare furry head, whose BACK quills (from the shoulders to the rump only, never on the head) fuse into one low ridged mint-and-cream mushroom cap whose rim breaks into quill points, the back outline a low rounded hump.",
 "sleepy, stubborn eyes and a small grumpy pout","earthy brown and mint, with a pale cream cap accent","a cap or anything on its head, a hat, tall stalks, a turtle shell",'spore','tough')
VC('cisternmander','Cisternmander',T+'Barrelmander.jpg','final',
 "A huge, flat, crocodile-low salamander lying sprawled with a wide frog-like jaw, whose whole broad back is an open stone cistern basin full of dark storm water with tiny lightning flickering across it, rain dripping off its stave-ridged flanks, and a long paddle tail; no barrel shape at all.",
 "tiny eyes and a wide, slow, toothy grin","slate grey and wood brown, with an electric-yellow accent","a barrel body, hoops, the round body of image 1, standing upright",'storm','tough')
VC('forgebrock','Forgebrock',T+'Anvilbrock.jpg','final',
 "A huge, low honey badger whose massive forearms swell into iron hammer-head fists fused at the wrist, with NO anvil on its back: instead its back is cracked cooling-iron hide with glowing orange seams like a fresh forging, soot-tan belly fur and quench-steam rising from its shoulders."+NO_ARMOUR,
 "fierce, squinting orange eyes and a wide, toothy grin","charcoal black and soot tan, with a hot-iron orange accent","an anvil on its back, an apron, armour, held hammers, chimneys",'ember','tough')
RL('meeko','pip_FINAL_sheet.png',"A palm-size glass snow-globe-style sphere on a small round wooden base holding a tiny smiling sun and a little puffy raincloud dripping a few raindrops, the sun glowing warmly; warm yellow and soft grey-blue. Only the object: no figures, people, creatures, legs or scales.")
SPECS[-1]['id']='relic_meeko_r'
PRIORITY=PRIORITY+['c_gongrowl','c_furnacowary','c_dreadnoyak','c_kayak','c_sporcupine','c_cisternmander','c_forgebrock','relic_meeko_r']
