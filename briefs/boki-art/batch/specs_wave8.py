# Round 8 (Vertex, 21:10 ET 11-08): rerolls for the first Vertex grades, portraits + 4K for new passes.
NOCOPY=" Not the same pose, proportions or silhouette as image 1."
V('geodemole_r','Geodemole',T+'Glintmole.jpg','mid',
 "A bigger, heavier mole, twice the size and twice the length of image 1, low on all four legs in every view with its body long and horizontal and its head held low, whose whole back is one big cracked-open geode dome glittering with pink and violet crystals inside, with crystal-tipped digging claws on its broad front paws and a star nose of small quartz points."+DIFF+NOCOPY+ALL4,
 "squinting, determined eyes and a proud grin","dusty brown and stone grey, with a pink-violet crystal accent",
 "standing on two legs, standing upright, a round body like image 1, a gem on its head",'stone','tough')
V('druzemole_r','Druzemole',T+'Glintmole.jpg','final',
 "A huge, low, wide mole as big as a boulder, three times the size of image 1, on all four legs in every view with its head lowered and its long heavy body horizontal, whose whole back is an open amethyst cavern bristling with tall violet crystal spires running down its spine, huge pickaxe-like crystal claws on its massive front paws, and a radiant crystal star nose."+DIFF+NOCOPY+ALL4,
 "tiny, fierce eyes and a wide, toothy grin","stone grey and amethyst violet, with a pink glow accent",
 "standing on two legs, standing upright, a cave on its back, looking like image 1",'stone','tough')
V('embrook_r','Embrook',T+'Kindlewren.jpg','mid',
 "A stylised young rook twice the size of image 1, with an oversized head and a hooked coal-black beak with a tiny row of sharp teeth, whose back is a smouldering bed of glowing coals grown into its body through cracked charcoal feathers, wing tips that end in cinder-edged blade feathers, and a long tail tipped with flickering flame.",
 "sharp, glowing orange eyes and a cocky, cawing grin","charcoal black and ember orange, with a yellow accent",
 "a realistic crow, a phoenix, a held coal",'ember','fast')
V('pyrraven_r','Pyrraven',T+'Kindlewren.jpg','final',
 "A huge, stylised raven three times the size of image 1, compact and powerful with an oversized head, a heavy beak with a burning coal tip, wings that end in long grown charcoal blades glowing at their edges, a crest of flickering flame and a tail of burning ember feathers. Exactly four views.",
 "fierce, smug, blazing eyes and a commanding sneer","charcoal black and ember orange, with a white-hot accent",
 "a realistic raven, a phoenix, fire everywhere, smoke",'ember','majestic')
V('mothlet_r2','Mothlet',T+'Lunowl.jpg','baby',
 "A tiny, perfectly round fluff ball of lavender owlet down, a quarter of the size of image 1, with no visible legs, two little stub wing nubs, two tiny fuzzy antenna sprouts and huge eyes, and no long wing tails."+DIFF+NOCOPY,
 "huge, sleepy, sparkling eyes and a tiny happy beak","lavender and cream, with a pale moon-gold accent",
 "the long moth wings of image 1, ear tufts, looking like image 1",'lunar','cute')
V('oarter_r2','Oarter',E+'Oarlet.jpg','mid',
 "A long, thin river otter twice the length of image 1, stretched out low in a swimming lunge on all fours in every view, lean and weasel-like, with a tail that is a long honey-wood oar blade as long as its body, a row of short wooden oar-spines down its back, and webbed paws with hooked claws."+DIFF+NOCOPY+ALL4,
 "bright, cheeky eyes and a sly, toothy grin","river brown and honey wood, with a sea-blue accent",
 "chubby, sitting, looking like image 1",'tide','fast')
for _i,_n,_r,_pose in [('ribbonwyrm','Ribbonwyrm',E,'winding through the air with its kite wings spread and its bow tail trailing'),
                        ('ringrove','Ringrove',T,'lumbering forward and swinging its spear quills out wide, spores drifting off its mushroom ring')]:
    P(_i,_n,_r+_n+'.jpg',_pose)
U('ribbonwyrm','Ribbonwyrm',E+'Ribbonwyrm.jpg')
U('ringrove','Ringrove',T+'Ringrove.jpg')
for _x in SPECS:
    if _x['id'].startswith('portrait_'): _x['aspect']='1:1'
