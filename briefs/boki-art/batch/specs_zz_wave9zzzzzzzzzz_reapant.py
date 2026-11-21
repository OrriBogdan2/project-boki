# 12:21 ET 11-09 owner (chat 12:13-12:14): the new compact Reapant "looks cool but feels like his t2"; give it a bit more green,
# and make a new, more grown-up / cooler t3. He also likes Scythant and is unsure which route (Scythant as t2, or this one).
# Both routes need a new t3, so: greener compact version (t2 candidate) + 3 t3 directions. Line: Marchleaf > (t2) > Reapant.
_O='briefs/boki-art/batch/out/'; _C='briefs/boki-art/cards/'
_w8=_O+'c_reapant_w8_1.jpg'
SPECS.append({'id':'c_reapant_t2g','name':'Reapant as t2 (concept)','refs':[_w8,_C+'Marchleaf.jpg',SRA],'runs':4,'aspect':'1:1',
  'prompt':("Creature-collector monster concept art for a fantasy action game. Image 1 is this creature: keep its compact body, big head, pose, mask band and scarf membrane exactly. "
    "Image 2 is its baby form: bring in more of the baby's leaf green so the family reads, leaf-green plates on its back, legs and scarf tips, with the plum and black kept on the mask and scythes. Image 3 is the style reference only. "
    "ONE creature only, full body, three-quarter view, centred with about 8 percent margin, plain flat pale grey background, no shadow, no text, no effects. "
    +CORE+LESSONS+desc("A compact ninja ant mid-stride, one scythe forearm raised, leaf-green and plum. One clear idea, few parts.",'big narrow glowing eyes and a determined stare','leaf green and deep plum, with a black accent','a human body, clothing, held weapons','swarm','fast'))})
for _k,(_b,_f) in enumerate([
 ("A towering reaper ant braced wide on four planted back legs, its front body raised high like a mantis (an insect posture, never a person), two huge curved scythe forelegs held out to the sides, a long tattered membrane cloak grown from its back, skull-like pale markings on its head.","cold, glowing eyes under a heavy brow"),
 ("A massive armoured war ant planted low and wide, four scythe forelegs crossed in front of its head like drawn blades, huge mandibles, glossy lacquered plum armour plates grown from its body, a torn leaf-green membrane trailing from its back.","fierce, narrow glowing eyes and open mandibles"),
 ("A huge reaper ant rearing on its back legs over the viewer like a looming insect, wings unfolded into ragged scythe-shaped blades, long scythe forelegs raised, a hooded head crest like a reaper's cowl grown from its carapace.","menacing glowing eyes in a shadowed face")],1):
    SPECS.append({'id':f'c_reapant_t3n{_k}','name':'Reapant t3 (concept)','refs':[_w8,_C+'Reapant.jpg',SRA],'runs':4,'aspect':'1:1',
      'prompt':("Creature-collector monster concept art for a fantasy action game. "+REL['final']+" Images 1 and 2 are the earlier forms of this family (compact plum ninja ant). Image 3 is the style reference only; never copy its creatures. "
        "ONE creature only, full body, three-quarter view, centred with about 8 percent margin, plain flat pale grey background, no shadow, no text, no effects. "
        +CORE+LESSONS+desc(_b+" Clearly bigger, more grown-up and cooler than images 1 and 2. One clear idea, few parts.",_f,'deep plum and black, with a leaf-green accent','a human body, standing like a person, clothing, held weapons','swarm','majestic'))})
