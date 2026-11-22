# 11:25 ET 11-09 coordinator/owner review, BATCH 1: designs we don't have yet. Rules: full body, no crops, no ground or rocks, centred.
_C='briefs/boki-art/cards/'
_NOGROUND=" Full body, no crop, no ground, no rocks, no base under it. One clear idea, few parts."
_B=[('coolatee','Coolatee','Frigatee','baby','frost','cute',[
 ("A tiny, round, fluffy white harp-seal pup sitting up, chubby as a dumpling, with a little frost-crystal tuft on its head and pale ice-blue flipper tips.","huge glossy dark eyes and a sleepy happy smile","snow white and pale ice blue, with a soft pink nose"),
 ("A round baby manatee-seal mid-bounce, belly like a snowball, stubby flippers like mittens, a few tiny ice flakes stuck to its whiskers.","big sparkly eyes and an open giggling mouth","cream white and frost blue, with a silver accent"),
 ("A chubby seal pup curled into a ball like a snowball, peeking out with one flipper waving, a little icicle drip on its nose.","shy round eyes and a tiny grin","white and pale blue, with a mint accent")]),
('druzemole','Druzemole','Geodemole','final','stone','tough',[
 ("A massive, hulking mole titan planted on all fours, its whole back split open into a huge glittering amethyst druze cavity like a cracked geode, huge crystal digging claws, a crystal star-shaped nose.","small, fierce glowing eyes and a snarl","dark stone brown and deep amethyst purple, with a pink crystal glow"),
 ("A colossal blind mole beast whose spine and shoulders erupt with long jagged crystal druze spikes like a mountain ridge, thick armoured stone hide, oversized shovel claws planted.","no visible eyes under its brow, a gaping crystal-toothed mouth","granite grey and violet, with glowing magenta crystal cores"),
 ("A heavy armoured mole emperor planted firm, a crown of clustered druze crystals on its head and a geode-shell cape over its back, crystal-lined claws.","proud, glowing violet eyes","dusk brown and amethyst, with a gold accent")]),
('scythant','Scythant','Marchleaf','mid','swarm','tough',[
 ("A lean young ant mid-run, halfway between a leafy bug and a ninja: green leaf-plate armour fading to dark plum on its legs, its two front legs grown into small curved leaf-shaped sickle blades, fern antennae, a torn leaf scrap trailing like a scarf.","sharp, eager eyes","leaf green fading to plum, with a crimson accent"),
 ("An agile ant leaping forward, slimmer than a beetle, leaf-blade forearms swept back, a leaf-shaped head crest, darker plum at the joints.","focused, narrow eyes","olive green and plum, with a dark brown accent"),
 ("A scrappy ant warrior scuttling fast on six legs, its front legs ending in sickle blades made of folded leaves, a leafy hood on its head.","fierce, determined eyes and a small grin","green and dark plum, with a red accent")]),
('jibbatross','Jibbatross','Kerchick','mid','tempest','tough',[
 ("A lanky juvenile albatross in mid-flight, long gangly wings with a single triangular jib sail of canvas grown from its back, rope-like tail streamers, scruffy half-grown feathers.","confident, half-lidded eyes and a cocky beak grin","white and sail cream, with navy blue swirl markings"),
 ("A teenage albatross gliding low over the water, a canvas jib sail stretched between its wing and its body, a small wooden mast-like crest on its head, scruffy down still on its chest.","bright, eager eyes","white and canvas beige, with a blue swirl accent"),
 ("A scrappy young albatross mid-takeoff, wings flared, a patched canvas sail-cape tied by grown rope-like feathers, a little bowsprit-shaped beak.","determined squinting eyes","off-white and sand, with navy accents")])]
for _i,_n,_ref,_rel,_el,_ar,_dirs in _B:
    for _k,(_b,_f,_c) in enumerate(_dirs,1):
        VC(f'{_i}_b{_k}',_n,_C+_ref+'.jpg',_rel,_b+_NOGROUND,_f,_c,'ground, rocks, a base, cropped parts, held objects, effects, text',_el,_ar)
