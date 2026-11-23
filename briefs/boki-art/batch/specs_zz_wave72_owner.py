# Owner 03:39-03:40 ET 11-09:
#  "furnacowary and bellowary look exactly the same, that can be a 2 line and pick one as the 2nd" -> Bellowlet > Furnacowary;
#     Bellowary cut (art session pick: Furnacowary is the more developed design). No new art needed.
#  "gongibbon needs to be smaller/cuter and gongrowl needs to be bigger/scarier"
#  "glintmole is too generic"
#  "glomwort should evolve"
import os as _o72
def _s72(n): return next(f'briefs/boki-art/{d}/{n}.jpg' for d in ('turnarounds','evolutions','cards') if _o72.path.exists(HERE.parent/d/f'{n}.jpg'))
_P72=[]
_AVG2="standing upright like a person, held objects, a gong it holds, a busy design"
for _k,_b in (('c1',"A tiny, round baby gibbon with a huge head and huge eyes, very long dangly arms it can barely control, a small brass gong disc set into its round tummy, and a little mallet-tipped tail, hanging from its tail or tumbling playfully."),
              ('c2',"A chubby baby gibbon ball of fluffy dark fur, a big pale face ring, a tiny brass gong cheek-pouch disc on its chest, stubby legs and long arms wrapped around its own tail with a small mallet tip, sitting and bouncing."),
              ('c3',"A tiny round gibbon chick with oversized ears and a huge grin, a small shiny gong forehead crest, very long arms raised in excitement, and a curly tail tipped with a little wooden mallet."),
              ('c4',"A small, plush, round baby gibbon curled into a ball with only its big eyes, tiny gong-shaped belly and mallet tail tip peeking out, sleepy and cute.")):
    VC('gongibbon_'+_k,'Gongibbon',_s72('Gongibbon'),'redo_of',"Same species and idea as image 1 but much smaller, rounder and cuter, clearly a baby: "+_b+" One clear idea, few parts.","huge round amber eyes and a sweet, cheeky smile","charcoal grey and cream, with a brass accent",_AVG2,'echo','cute'); _P72.append('c_gongibbon_'+_k)
for _k,_b in (('s1',"A huge, hulking war ape far bigger than image 1, broad shoulders and massive long arms knuckle-planted wide, a great brass gong grown into its chest like a shield, a heavy brass gong-plate crest on its head, and a thick tail ending in a huge war-hammer mallet."),
              ('s2',"A towering roaring gong ape rearing up with arms spread wide, fanged mouth open in a howl, sound-wave grooves carved into the bronze gong plates on its shoulders and back, and a massive mallet tail raised to strike."),
              ('s3',"A massive scarred silverback-gibbon brute lowered into a charge, enormous arms, bronze gong armour plates on its forearms like gauntlets, a jagged bronze gong crown, glowing angry eyes, and a long heavy mallet tail."),
              ('s4',"A giant shadowy howler-gibbon looming over the viewer, very long powerful arms, a deep bronze gong set in its open chest vibrating, a spiky mane, and a thick tail ending in a spiked bronze mallet.")):
    VC('gongrowl_'+_k,'Gongrowl',_s72('Gongibbon'),'final',"Much bigger and scarier than image 1: "+_b+" One clear idea, few parts.","fierce, glowing amber eyes and a fanged roar","charcoal black and bronze, with a burnt-orange accent","a gong it holds, a person, standing upright like a human boxer, a busy design",'echo','tough'); _P72.append('c_gongrowl_'+_k)
for _k,_b in (('d1',"A chubby mole whose huge star nose is a blooming cluster of pink quartz crystals like a flower, its back a round geode shell split open with sparkling amethyst inside, giant shovel claws tipped in crystal, popping out of a little dirt mound."),
              ('d2',"A round mole wearing its home: its whole body is a dusty grey rock with a cracked-open crystal cave showing through, two huge crystal-tipped digging claws, and a sparkling crystal star nose, peeking with squinting eyes."),
              ('d3',"A tiny miner mole with a big crystal lantern-like star nose that glows softly pink, a back covered in a neat mosaic of polished gem facets like a disco ball, and stubby crystal claws."),
              ('d4',"A plump mole with a long sparkly crystal-spike mohawk running down its back like a geode ridge, a big pink quartz star nose, oversized spade claws, and a happy squint.")):
    VC('glintmole_'+_k,'Glintmole',_s72('Glintmole'),'redo_of',"Same species and idea as image 1 (crystal star-nosed mole) but far more distinctive and memorable: "+_b+" One clear idea, few parts.","tiny squinting eyes and a proud little smile","dusty brown and stone grey, with pink quartz and amethyst accents","a realistic mole, a gem on its head, standing upright, a busy design",'stone','cute'); _P72.append('c_glintmole_'+_k)
for _k,_b in (('f1',"A huge, wobbling slime-mold giant oozing forward, its back a whole forest of tall puffball and shelf mushrooms puffing spore clouds, a big gooey grinning face, and thick pseudopod arms."),
              ('f2',"A towering slime-mold mound shaped like a living hill, glowing toxic-green veins through its mustard body, a crown of giant puffballs, and dozens of small mushrooms sprouting along its drippy sides."),
              ('f3',"A massive slime-mold beast with a wide mouth and dopey eyes, its body split into lobes like a cauliflower of fungus, big puffball mushrooms bursting from its back, oozing on many stubby pseudopods."),
              ('f4',"An enormous gooey slime-mold ogre rearing up with two big drippy pseudopod arms, a forest canopy of puffball mushrooms on its head, spore puffs drifting, and toxic-green goo dripping from its grin.")):
    VC('glomwort_'+_k,'Glomworth',_s72('Glomwort'),'final',_b+" Clearly Glomwort's evolution, much bigger. One clear idea, few parts.","two dopey, droopy eyes and a huge, gooey grin","mustard yellow and pale cream, with a toxic green accent","a face on a mushroom, legs, a person, a busy design",'spore','creepy'); _P72.append('c_glomwort_'+_k)
PRIORITY=_P72+PRIORITY
