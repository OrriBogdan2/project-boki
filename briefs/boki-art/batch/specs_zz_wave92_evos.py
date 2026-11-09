# 05:20 ET 11-09 overnight: owner rule "1-stage Boki should be a minority (legendaries and a few specific ones)".
# Kept singles: Cairnback, Hivara, Zephyrak, Barokat, Terrasloth. Remaining singles get an evolution (surprise rule:
# cute baby -> grubbier/gnarlier later stage). 3 directions each; best goes to sheet+card+portrait.
_C='briefs/boki-art/cards/'
_E=[('moatpole','Moatpole','Rampartoad','baby','stone',[
 ("A tiny round tadpole-toadlet with a stubby tail and a little crenellated stone turret-bump on its head like a toy castle tower, sitting in a puddle.","big, sleepy, happy eyes and a wide froggy smile","mossy green and sandstone, with a cream belly"),
 ("A chubby baby toad with a pebble-wall pattern on its back like a tiny garden wall and a single small flag-shaped fin on its tail.","round, curious eyes and a tiny croak","sandstone and pond green"),
 ("A squishy toadlet curled up inside a cracked stone half-shell like a broken pot, peeking out.","shy, big eyes and a small pout","grey stone and lime green, with a pink cheek accent")]),
('moundlet','Moundlet','Spirevark','baby','swarm',[
 ("A tiny round aardvark pup with oversized ears and a long soft snout, a small clay termite mound growing on its back like a little backpack-hill, with a few cute termites peeking out.","sleepy, content eyes and a sniffly snout","clay orange and dusty pink, with a sand accent"),
 ("A fuzzy baby aardvark curled up asleep on top of a small clay mound, its tail wrapped around it.","closed, peaceful eyes and a tiny smile","terracotta and cream"),
 ("A clumsy aardvark pup with huge ears flopping, digging with its nose, clay dust on its face.","excited, bright eyes and a happy snort","dusty pink and ochre")]),
('murmuron','Murmuron','Murmurling','final','echo',[
 ("A large, majestic starling-like bird whose spread wings are made of rows of long organ pipes instead of flight feathers, iridescent speckled plumage, a crest of small reed pipes.","proud, piercing eyes and an open singing beak","iridescent black-green and brass, with white star speckles"),
 ("A big, ragged storm-starling whose body seems made of a swirling flock of tiny dark birds holding its shape, with a brass pan-pipe collar grown into its chest.","glowing, intense eyes and a sharp beak","glossy black and purple sheen, with a brass accent"),
 ("A tall, gnarly heron-sized starling with a long neck, its tail fanned like a giant pan-pipe, feathers scruffy and spiked.","fierce, beady eyes and a shrieking call","speckled iridescent green and black, with gold flecks")]),
('spanglin','Spanglin','Mirrolin','baby','prism',[
 ("A tiny round pangolin baby curled into a ball of small mirror-tile scales like a little disco ball, its face and paws peeking out.","sparkly, delighted eyes and a little grin","silver and pastel rainbow glints, with a pink belly"),
 ("A small pangolin pup with soft rounded mirror-tile scales, standing on its back legs and wobbling, light dots dancing around it.","big, shiny eyes and an excited open smile","silver and lilac, with rainbow reflections"),
 ("A sleepy pangolin baby with only a few shiny mirror tiles on its back like new teeth, the rest soft pink skin.","drowsy, sweet eyes and a yawn","soft pink and silver")])]
for _i,_n,_ref,_rel,_el,_dirs in _E:
    for _k,(_b,_f,_c) in enumerate(_dirs,1):
        VC(f'{_i}_e{_k}',_n,_C+_ref+'.jpg',_rel,_b+" One clear idea, few parts.",_f,_c,'held objects, effects, text, other creatures, copying the reference pose',_el,'cute' if _rel=='baby' else 'majestic')
