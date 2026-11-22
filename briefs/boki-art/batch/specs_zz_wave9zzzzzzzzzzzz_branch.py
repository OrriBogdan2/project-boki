# 12:33 ET 11-09 owner (chat 12:33): Marchleaf BRANCHES. Both t2s stay:
#   Marchleaf > Scythant (leaf-blade route) > new t3 (below)
#   Marchleaf > compact ninja ant (shadow route; from c_reapant_w8_1, greener c_reapant_t2g) > Reapant t3 (c_reapant_t3n1-3)
# "different t3s for both": this file is the Scythant route final. It must read clearly apart from the plum ninja-reaper finals.
_O='briefs/boki-art/batch/out/'; _C='briefs/boki-art/cards/'
for _k,(_b,_f) in enumerate([
 ("A colossal harvest mantis-ant planted wide on four legs, its armour grown from overlapping autumn leaves, two giant serrated leaf-scythe forelegs crossed in front of it, a tall crown of unfurled fern antennae, looming over the viewer.","calm, ancient amber eyes and a stern brow"),
 ("A huge rearing leaf war ant braced on its back legs like an insect (never a person), its abdomen grown into a wide fan of sharp leaf blades like a sickle wheel, rows of leaf blades along its legs, two long scythe forelegs raised.","fierce, glowing amber eyes and open mandibles"),
 ("A hulking field-guardian ant braced low and wide, its back overgrown into a living hedge of sharp blade-shaped leaves, enormous mandibles shaped like garden shears, thick bark-plated legs rooted firmly.","small, stubborn eyes and a heavy scowl")],1):
    SPECS.append({'id':f'c_scythant_t3n{_k}','name':'Scythant route t3 (concept)','refs':[_O+'c_scythant_b1_2.jpg',_C+'Marchleaf.jpg',SRA],'runs':4,'aspect':'1:1',
      'prompt':("Creature-collector monster concept art for a fantasy action game. "+REL['final']+" Images 1 and 2 are the earlier forms of this family (image 1 the leaf-blade middle form, image 2 the baby). Image 3 is the style reference only; never copy its creatures. "
        "ONE creature only, full body, three-quarter view, centred with about 8 percent margin, plain flat pale grey background, no shadow, no ground, no text, no effects. "
        +CORE+LESSONS+desc(_b+" Clearly bigger, more grown-up and more impressive than image 1, and nothing like a plum or black ninja. One clear idea, few parts.",_f,'leaf green and autumn gold, with a crimson accent','plum, black, a ninja mask or scarf, a human body, standing like a person, held weapons','swarm','majestic'))})
