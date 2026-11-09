# 14:45 ET 11-09 owner (chat 14:42): "geodemole and druzemole look too similar - might just be the pose - do a check on everything for those".
# Full line check (73 lines, picked designs in place of cards being replaced). Fix = new card poses on the stage ladder
# (baby sits/bounces, middle in motion, final planted/rearing/looming) plus a Druzemole redesign. Ids <n>_card105; sheets follow picks.
_C='briefs/boki-art/cards/'
_NEW=" Most important: a completely different pose and silhouette from image 1; do not reuse its pose, angle or stance."
def _RP(n,stage,pose,extra=''):
    SPECS.append({'id':f'{n.lower()}_card105','name':n+' (hero card, new pose)','refs':[_C+n+'.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(n,stage,pose)+_NEW+extra})
# severe
_RP('Glintmole','baby','sitting up round and chubby on its bottom like a plush toy, little crystal claws held up, head tilted, a sleepy happy smile')
_RP('Geodemole','mid','lunging forward mid-dig, body stretched long and low, crystal claws thrown forward, dirt-free plain background')
_RP('Druzemole','final','towering on its hind legs, looming over the viewer, its geode shell split open behind it like a glittering cave, both crystal claws spread wide, roaring')
_RP('Rattlebub','baby','bouncing upright on its coiled tail like a spring, rattle shaking, wide happy eyes')
_RP('Maracoil','final','reared high in a striking pose like a cobra, body coiled in a big planted base, both maraca rattles raised and shaking, fangs bared')
_RP('Gravadillo','baby','half rolled into a ball with only its face and front paws peeking out, small rocks floating around it')
_RP('Gravitank','final','braced wide and planted, head lowered for a charge, horn forward, its cratered shell raised high like a mountain')
_RP('Forgebrock','final','reared up on its hind legs like a bear, roaring, forge chest glowing',
    " Colours: warm copper-bronze fur, a soot-grey face mask and blue-white spark cracks instead of orange lava; metal parts dark iron.")
_RP('Embrook','mid','mid-leap with wings half spread and cinders trailing, neck stretched forward, scrappy and fast')
_RP('Frigatee','mid','sliding forward on its belly across the air like a seal on ice, flippers swept back, cooler-lid back steaming cold')
_RP('Scopeleon','mid','creeping forward along a branch-less pose mid-stride, telescope eye extended forward, tail curled tight')
_RP('Domeleon','final','reared up tall and planted, its telescope cannon aimed high at the sky, frill spread wide')
_RP('Zippelith','mid','slithering fast in a big S-curve, its zipper half open in a grin')
# milder
_RP('Skateron','mid','in a low racing crouch, neck stretched forward, wings swept back like a speed skater, one blade lifted')
_RP('Snuffapi','mid','prancing mid-trot with one foreleg high and its smoking antlers tossed back')
_RP('Briarlynx','final','rearing up on its hind legs, thorny paws raised, briar whip tail lashing, snarling')
_RP('Howlop','mid','lunging forward mid-howl, ears flared wide, sound rings bursting from its mouth')
_RP('Dreadnoyak','final','charging head-down toward the viewer, ice keel forward, frost hair streaming')
_RP('Morelossus','final','reared up on its hind legs trumpeting, front feet high, morel back towering')
_RP('Loafhopper','mid','mid-leap with its long legs stretched out behind it, crusty wings open')
_RP('Lodestaff','final','reared up tall like a praying mantis, lodestone forelegs raised and crossed, magnetic flakes orbiting')
_RP('Blastopuff','final','fully inflated to bursting, spikes out, fuse sparking, glaring')
# Druzemole: also a stronger redesign in case a pose isn't enough.
_NG=" Full body, no crop, no ground, no rocks, no base under it. One clear idea, few parts."
for _k,_b in enumerate([
 "A colossal crystal-cavern titan reared up on its hind legs, its whole back a huge open geode cave glittering with amethyst, tiny eyes, giant crystal digging claws, a body clearly NOT the low crouching mole of its earlier forms.",
 "A huge mole that has become a walking amethyst mountain: crystal spires rising from its shoulders like peaks, a broad flat head, planted wide on pillar legs, crystals glowing from cracks in its stone hide.",
 "A long, serpentine tunnelling beast with a mole's head and a segmented crystal-studded body coiled around itself, enormous crystal shovel claws raised, eyes hidden under a stone brow."],1):
    VC(f'druzemole_n{_k}','Druzemole',_C+'Geodemole.jpg','final',_b+_NG,'small, fierce glowing eyes','dark stone brown and deep amethyst, with a pink crystal glow','the low crouching mole-lizard of Glintmole and Geodemole, a turtle shell, a crown sitting on its head','stone','majestic')
# ---- 5 new legendaries (LEGENDARY_TIERS.md; owner OK 14:42 for Minor = Pavonazar/Ghoulamari/Glacione; Blight = new creatures) ----
_LEG={'minor':"A Minor legendary: normal Boki size, a rare world find, one standout feature that makes it feel special. ",
      'boss':"A Boss legendary: huge, armoured and planted, an arena-scale silhouette that reads instantly from a small banner icon. ",
      'ultra':"An Ultra legendary: colossal and awe-inspiring, with a presence around it, something players would see from far across the map. ",
      'blight':("A Blight legendary, the game's top-danger tier: bruised purple-black sludge, purple veins under its skin, bone spurs along the veins, white-hot cracks "
                "where it burns, a faint inner glow. Menacing and unforgettable, not gross or rotting, never green slime. ")}
_NEWLEG=[('leg_minor','minor',["A small tortoise whose shell is a brass compass rose with a glowing needle that always points to treasure, star-map markings on its skin.",
                                "A tiny pangolin-sized fennec fox whose huge ears are glowing sundials casting little shadow-hands, desert gold markings.",
                                "A little seahorse-dragon whose curled tail is a key and whose body is a music box with a tiny spinning dancer-fin crest."]),
         ('leg_boss','boss',["A colossal aurochs bull whose body is a ruined stone colosseum: arches for ribs, a cracked arena floor for a back, horns like broken pillars, planted for battle.",
                             "A giant armoured gorilla-crab whose shell is a castle keep with battlements and an iron portcullis mouth.",
                             "A huge war elephant whose skin is siege-tower timber and iron, a battering-ram trunk, ballista tusks grown from its jaw."]),
         ('leg_ultra','ultra',["A colossal sea turtle rising from the map carrying a sunken ruined city on its shell, waterfalls pouring off its sides, ancient calm eyes.",
                               "A vast aurora stag whose antlers are a glowing northern-lights tree spanning the sky, its body made of night sky and stars.",
                               "An immense sky manta whose wings are a slow-moving storm front, lightning in its gills, rain trailing from its wingtips."]),
         ('leg_blight1','blight',["A gaunt Blight hyena-wolf whose ribcage is an open furnace of white-hot cracks, a purple-black sludge mane, bone spurs down its spine, a grinning skull-like muzzle.",
                                  "A towering Blight moth whose tattered wings are purple-black membranes laced with white-hot veins, bone-spur antennae, a hollow glowing thorax.",
                                  "A serpentine Blight eel-dragon whose body leaks purple-black sludge from white-hot fissures, a crown of bone spurs, hungry glowing eyes."]),
         ('leg_blight2','blight',["A hulking Blight boar-beast whose tusks are curved bone spurs and whose back erupts in white-hot cracked plates leaking purple sludge.",
                                  "A Blight vulture-sphinx with a lion-like body, ragged purple-black wings, white-hot cracks across its chest and a bone-spur crown.",
                                  "A Blight scorpion-mantis with sludge-dripping scythe arms, a bone-spur tail, white-hot veins glowing through translucent purple plates."])]
for _slot,_tier,_dirs in _NEWLEG:
    for _k,_b in enumerate(_dirs,1):
        SPECS.append({'id':f'c_{_slot}_n{_k}','name':f'New {_tier} legendary (concept)','refs':[SRA],'runs':4,'aspect':'1:1',
          'prompt':("Creature-collector monster concept art for a fantasy action game. Image 1 is the style reference only (soft hand-painted shading, clean thin dark outline, big glossy eyes); never copy its creatures. "
            "ONE creature only, full body, gentle three-quarter view with the head turned toward the viewer, centred with about 8 percent margin, plain flat pale grey background, no shadow, no ground, no text, no effects. "
            +CORE+LESSONS+_LEG[_tier]+_b+" One clear idea, few parts. It must not look like any existing Boki.")})
