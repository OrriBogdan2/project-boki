# 05:50 ET 11-09 overnight: second round for families still below the bar or that the owner said were "not there yet".
_C='briefs/boki-art/cards/'
_R=[('gongrowl','Gongrowl','Gongibbon','final','echo','tough',[
 ("A towering, hulking silverback ape twice the size of its baby, knuckle-walking, with a huge cracked bronze gong grown into its broad chest like a breastplate of bone, scarred shaggy fur, massive forearms.","furious, deep-set glowing eyes and a roaring open mouth","charcoal black and dark bronze, with a molten gold accent"),
 ("A gnarly, hunched gorilla-beast with bronze cymbal-like plates grown out of its shoulders and spine, long arms, cracked knuckles, a wild mane.","menacing, glaring eyes and bared fangs","dark grey and tarnished bronze, with a red accent")]),
('reapant','Reapant','Reapant','final','swarm','majestic',[
 ("A tall, slender, upright-standing ninja ant (still an insect, on four thin legs, front pair as long scythe blades), with a dark wrapped-cloth-like carapace pattern across its face like a mask, long antennae swept back.","narrow, glowing red eyes and a silent stare","midnight indigo and charcoal, with a crimson accent"),
 ("A tall, lean mantis-ant hybrid in a low ninja crouch, scythe forearms folded behind it like sheathed blades, a sleek glossy carapace with a scarf-like flowing membrane at the neck.","cold, sharp eyes","deep teal-black and steel grey, with a jade accent")]),
('galleotter','Galleotter','Galleotter','final','tide','majestic',[
 ("A large, proud sea otter whose back is a grown wooden galley ship hull with a single furled sail rising from its spine and oar-like webbed fins along its sides, floating on its back.","confident, salty eyes and a captain's grin","weathered wood brown and sea teal, with a brass accent"),
 ("A big, burly otter standing on its hind legs on the water, a sail-fin grown from its back, rows of oar-shaped quills along its tail, a barnacle-crusted chest.","bold, cheerful eyes and a big toothy grin","chestnut brown and canvas white, with a navy accent")]),
('chandelapi','Chandelapi','Snuffapi','final','shadow','majestic',[
 ("A tall, regal okapi stag with long elegant legs and a calm, noble stance, a SIMPLE crown of three tall dark antler-candles with soft violet flames, striped legs, a long flowing tail. Majestic and uncluttered, few parts.","serene, wise glowing eyes","deep chocolate and cream stripes, with a violet flame accent"),
 ("A graceful okapi standing tall, its antlers forming a single elegant arch like a candelabra with small flames at the tips, a smoky mane flowing down its neck. Clean and majestic, not busy.","calm, half-lidded noble eyes","dark brown and ivory, with a warm amber flame accent")])]
for _i,_n,_ref,_rel,_el,_ar,_dirs in _R:
    for _k,(_b,_f,_c) in enumerate(_dirs,1):
        VC(f'{_i}_q{_k}',_n,_C+_ref+'.jpg',_rel,_b+" One clear idea, few parts.",_f,_c,'held objects, worn clothing, effects, text, other creatures, a person-like upright pose',_el,_ar)
P('tinbrock_gap','Tinbrock',_C+'Tinbrock.jpg','in the same pose and look as its hero card')
