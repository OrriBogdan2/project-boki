# 06:15 ET 11-09: round-2 picks after eye check vs live art. -> sheet + card + portrait (_p96).
_O='briefs/boki-art/batch/out/'
_P=[('Gongrowl','c_gongrowl_q2_2','final','planted on its knuckles, chest gong glowing, roaring'),
('Galleotter','c_galleotter_q1_4','final','rising out of the water, coiled galley body with sail raised'),
('Chandelapi','c_chandelapi_q1_1','final','standing tall and still, candle antlers glowing softly')]
for n,src,st,pose in _P:
    l=n.lower(); s=_O+src+'.jpg'
    TA(n,s); SPECS[-1]['id']=f'ta_{l}_p96'
    SPECS.append({'id':f'{l}_card96','name':f'{n} (hero card)','refs':[s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(n,st,pose)})
    P(f'{l}_p96',n,s,pose)
# Reapant: q1/q2 copied the old green leafy look. Fresh concepts with NO old-card reference.
for _k,(_b,_f,_c) in enumerate([
 ("A tall, slender ninja ant on four long thin legs, its front pair of arms ending in long curved scythe blades held crossed behind its back like sheathed swords, a narrow head with a dark mask-like band across the eyes, long swept-back antennae, a sleek glossy carapace.","narrow, glowing red eyes and a silent, focused stare","midnight indigo and charcoal black, with a crimson accent"),
 ("A tall, lean assassin ant in a low ready crouch, long scythe forearms, a flowing tattered membrane like a scarf trailing from its neck, a smooth armoured head shaped like a ninja hood.","cold, sharp violet eyes","deep plum and black, with a silver blade accent"),
 ("A tall, elegant ant warrior standing still and poised, slim waist, long legs, folded scythe arms, a crescent-shaped crest on its head, very clean silhouette.","calm, deadly white eyes","matte black and dark red, with a gold accent")],1):
    SPECS.append({'id':f'c_reapant_w{_k}','name':'Reapant (concept)','refs':[SRA],'runs':4,'aspect':'1:1',
      'prompt':("Creature-collector monster concept art for a fantasy action game. Image 1 is the style reference only (soft hand-painted shading, clean thin dark outline, big glossy eyes); never copy its creatures. "
        "ONE creature only, full body, gentle three-quarter view with the head turned toward the viewer, centred with about 8 percent margin, plain flat pale grey background, no shadow, no text, no effects. "
        +CORE+LESSONS+desc(_b+" NOT green, NOT leafy, NOT a mantis. One clear idea, few parts.",_f,_c,'leaves, green colours, held weapons, clothing, a person-like body','swarm','majestic'))})
