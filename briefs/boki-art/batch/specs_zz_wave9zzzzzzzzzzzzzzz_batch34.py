# 13:37 ET 11-09 OWNER REVIEW batch 3 (poses / cleanup) + batch 4 (new evolutions), coordinator 11:05 order.
# Cards only for now; sheets and portraits follow the owner's A/B pick (or the best run when he says "you decide").
_C='briefs/boki-art/cards/'
def _EDIT(i,n,instr,runs=3):
    SPECS.append({'id':i,'name':n+' (hero card edit)','refs':[_C+n+'.jpg'],'runs':runs,'aspect':'1:1','size':'2K',
      'prompt':"Edit image 1: keep everything exactly the same: the same creature, design, colours, pose, style and plain pale grey background. Only change this: "+instr+" Do not add anything else."})
def _POSE(i,n,stage,pose,runs=3):
    SPECS.append({'id':i,'name':n+' (hero card)','refs':[_C+n+'.jpg',SRA],'runs':runs,'aspect':'1:1','size':'2K','prompt':CARD(n,stage,pose)})
# ---- batch 3: poses and cleanup ----
# 3 Echolop: a more interesting pose.
_POSE('echolop_cardz','Echolop','baby','mid-hop with both big bat ears flared wide like satellite dishes catching a sound, one paw raised, head tilted, a curious open-mouthed look')
_POSE('echolop_cardw','Echolop','baby','sitting up on its haunches leaning forward, one ear cupped toward the viewer and the other folded down, listening hard with a mischievous grin')
# 7 Kayak: a cuter pose.
_POSE('kayak_card101','Kayak','baby','sitting back on its haunches like a puppy, head tilted, fluffy frost tail curled around its feet, a happy little smile')
_POSE('kayak_card102','Kayak','baby','bouncing mid-hop with all four stubby legs tucked under it, fluff puffed up, eyes squeezed happy')
# 8 Prowyak: faces the same way as Kayak. Turn it the other way and put it in motion (middle stage).
_POSE('prowyak_cardz','Prowyak','mid','charging forward low with its ice prow leading, head down, facing to the LEFT side of the image (the opposite way from Kayak), frost streaming off its coat')
_POSE('prowyak_cardw','Prowyak','mid','trotting toward the viewer, body turned to the LEFT side of the image, snorting a puff of frost, prow raised proudly')
# 9 Geodemole: polish and a better pose.
_POSE('geodemole_card101','Geodemole','mid','reared up on its back legs in a digging swipe, both huge crystal claws raised mid-scoop, crystal nose sniffing, a determined grin')
_POSE('geodemole_cardw','Geodemole','mid','prowling low and fast with its crystal claws reaching forward and its geode back arched, sniffing the air')
# 34 Foldbat: too shiny.
_EDIT('foldbat_cardz','Foldbat','tone the material down: soft, matte, velvety fur and leathery matte wings with no glossy plastic shine and no bright specular highlights on the body (keep the glossy eyes).')
# 22 Pangolith (Terrasloth): pull the camera back.
_EDIT('terrasloth_cardz','Terrasloth','pull the camera back so the whole creature is smaller in the frame, with about 15 percent empty margin on every side.')
# 23 Lunarca (Selenwhale): full body, nothing cut off anywhere.
_EDIT('selenwhale_cardz','Selenwhale','pull the camera back so the whole whale, from the tip of its nose to both tail flukes and every fin, sits inside the frame with about 12 percent empty margin on every side.')
# 25 Vatmander (Cisternmander): add a barrel reference to tie it to Bucketmander > Barrelmander.
_EDIT('cisternmander_cardz','Cisternmander',"its mossy stone pond back now has a big broken wooden barrel half sunk into it, a few split staves and one rusty iron hoop poking out of the moss, clearly the barrel of its earlier form Barrelmander grown into the pond.",runs=4)
# 13 Voltalon: remove the rocks.
_EDIT('voltalon_cardz','Voltalon','remove the rock under its feet completely; its feet rest on nothing, on the plain background.')
# ---- batch 4: new evolutions + Lurklet ----
_NG=" Full body, no crop, no ground, no rocks, no base under it. One clear idea, few parts."
# 38 Snapler is cut: the line is Lurklet (T1) > Maulangler (T2). Lurklet looks like Snapler, so redo it as Maulangler's baby.
for _k,(_b,_f) in enumerate([
 ("A tiny round anglerfish fry bobbing in the air, soft round body, a small glowing lure on a short stalk, little stubby fins, a closed smiling mouth with just two tiny teeth showing.","huge glossy violet eyes and a sweet smile"),
 ("A chubby angler tadpole with a big head and big eyes, its lure glowing softly like a nightlight, a little wiggly tail.","sleepy, glowing violet eyes and a shy grin"),
 ("A little angler pup crawling on two stubby fin-legs, its lure drooping sleepily over its face, round belly.","curious violet eyes and a tiny toothy smile")],1):
    VC(f'lurklet_n{_k}','Lurklet',_C+'Maulangler.jpg','baby',_b+_NG,_f,'deep purple-black, with a violet glow accent','a metal jaw, chains, rows of big teeth, a snarl','shadow','cute')
# 16 Buckleron: next stage (toad family; Bastionpet the crab exists but does not read as related, see CHANNEL).
for _k,(_b,_f) in enumerate([
 ("A bigger armoured toad prowling low, its buckler shell grown into a heavy round tower-shield carapace over its whole back like a turtle, a single spike boss in the centre, bolt-studded rim, thick warty legs mid-stride.","stern, narrow eyes and a grumpy frown"),
 ("A toad tucked into its round shield shell and rolling forward like a wheel, only its face and front feet showing, shield rim studded with bolts.","determined squinting eyes"),
 ("A lean shield-backed toad mid-leap, its back plate grown into a tall kite-shield shape with a ridge spike, long powerful back legs stretched out.","fierce, confident eyes")],1):
    VC(f'buckleron_ev{_k}','Buckleron next stage',_C+'Buckleron.jpg','mid',_b+_NG,_f,'mossy green and dark iron, with a rust accent','a helmet or hat, held shields, straps, a crab body','titan','tough')
# 24 Barokat: add an evolution (final).
for _k,(_b,_f) in enumerate([
 ("A tall sentinel meerkat beast standing up on its hind legs the way meerkats do, its belly dial grown into a big brass barometer face, storm clouds rolling around its shoulders like a mane, a weathervane tail.","wise, watchful eyes and a knowing smirk"),
 ("A hulking storm badger-meerkat braced on all fours, a domed brass weather-glass grown into its back with a tiny storm inside, a lightning-rod tail, a cloud mane.","fierce, stormy eyes"),
 ("A long lean mongoose stalking low, a barometer dial set into its chest, a thundercloud trailing from its tail tip, wind-swept fur.","sharp, alert eyes")],1):
    VC(f'barokat_ev{_k}','Barokat evolution',_C+'Barokat.jpg','final',_b+_NG,_f,'sandy tan and brass, with a storm-grey accent','held instruments, a clock face, straps','tempest','majestic')
# 32 Bullsfrog: T3 (T1 Bullpole is queued in the gaps file).
for _k,(_b,_f) in enumerate([
 ("A huge squat archery-target toad braced wide, its back one big round bullseye of concentric red and green rings, a crest of arrow fletching grown on its head, a long whip tongue.","confident, narrowed eyes and a wide smirk"),
 ("A rearing horned bullfrog with its throat sac inflated into a red and green target, dart-tipped spines on its fingers, planted on thick back legs.","fierce, bulging eyes"),
 ("A heavy spiked frog with rows of fletched quills down its back like darts stuck in a target, bullseye rings on its flanks, braced low.","grumpy, steady eyes")],1):
    VC(f'bullsfrog_t3n{_k}','Bullsfrog final',_C+'Bullsfrog.jpg','final',_b+_NG,_f,'bright red and leaf green, with a black accent','held arrows, a bow, straps','venom','tough')
# 22 Pangolith (Terrasloth): add a T2.
for _k,(_b,_f) in enumerate([
 ("A huge pangolin planted wide whose scales have grown into overlapping glass greenhouse panes with a living garden inside, ferns and flowers pressing against the glass, a domed conservatory roof on its back.","calm, gentle green eyes"),
 ("A tall pangolin rearing up on its hind legs and tail the way pangolins do, its scale armour a terraced glass garden with a small tree on top.","proud, serene eyes"),
 ("A long-bodied armoured garden beast half curled around itself like a walled garden, mossy glass plates and a little blossoming tree growing from its back.","sleepy, kind eyes")],1):
    VC(f'terrasloth_t2n{_k}','Pangolith final',_C+'Terrasloth.jpg','final',_b+_NG,_f,'sage green and glass white, with a pink blossom accent','mirror tiles, disco ball, curled into a ball like the baby','bloom','majestic')
