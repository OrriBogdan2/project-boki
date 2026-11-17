# 04:44 ET 11-09 owner (going to sleep, act on principles): minks Lunink, Voltmink, Umbrink, Blossmink are good;
# Rimink, Rippmink, Prismink, Flarmink need more differentiation -> 3 new body-plan directions each (shared Ermink ink-brush tail tie).
# Also redos for picks pulled on eye check (Effigoon faceless, Cisternmander no lightning, Glaivyx long legs less scorpion).
_C='briefs/boki-art/cards/'; _O='briefs/boki-art/batch/out/'
_TIE=" Family tie to its baby Ermink (an ivory ermine with an ink-brush tail): keep the ink-brush tail tip, but the body shape, posture and silhouette must be clearly its own and unlike any other mink form. One clear idea, few parts."
_M=[('flarmink','Flarmink','ember',[
 ("A long, low, sinuous stoat whose fur darkens to cracked cooling-lava plates toward the rump, with a flared ember ruff around the neck like a lion's collar.","fierce, confident eyes and a sly grin","charcoal black and ember orange, with a molten-yellow accent"),
 ("A compact, puffed-up stoat with a huge bonfire tail curled up over its back like a squirrel, its body ash-grey and soot-smudged.","bright, cheeky eyes and a mischievous smirk","ash grey and flame orange, with a cream belly"),
 ("A lean, long-legged hunting stoat with tall matchstick-tipped ears that glow at the tips and a slim tail whose ink-brush tip paints a ribbon of flame.","sharp, focused eyes and a determined look","cream and scarlet, with a black ink accent")]),
('rippmink','Rippmink','tide',[
 ("A sleek otter-shaped sea stoat with webbed paws, a smooth wave-shaped fin crest running down its back, and a tail that curls into a breaking wave.","calm, playful eyes and an easy smile","deep teal and seafoam, with a white belly"),
 ("A long serpentine eel-like mink with four small flipper paws, a ribbon-fin tail and a glossy wet coat, swimming pose.","gentle, curious eyes and a tiny smile","ocean blue and pale aqua, with a pearl accent"),
 ("A round, floaty stoat with a fluffy rain-cloud coat that drips droplets and a tail ending in a big ink-blue water-drop brush.","sleepy, content eyes and a soft smile","slate blue and cloud white, with an ink-blue accent")]),
('rimink','Rimink','frost',[
 ("A shaggy, heavy-coated snow weasel with a thick frosted ruff, a long icicle-fringed tail and big snowshoe paws, low and sturdy like a wolverine.","stern, steady eyes and a frosty huff","snow white and glacier blue, with a slate accent"),
 ("A round, fluffy arctic stoat curled like a snowball, with snowflake-crystal ears and a frost-crusted tail wrapped around itself.","big, sparkly eyes and a shy smile","pure white and pale ice blue, with a silver accent"),
 ("A tall, elegant, long-legged stoat that walks on frozen tiptoes, with a mane of ice shards along the spine and a tail that freezes into a calligraphy icicle.","cool, aloof eyes and a poised look","ice blue and white, with a deep navy ink accent")]),
('prismink','Prismink','prism',[
 ("A stoat whose body is partly translucent faceted crystal like cut glass, catching rainbow light inside, with a crystal-shard tail.","bright, wondering eyes and a delighted smile","clear crystal and white, with soft rainbow glints"),
 ("A sleek stoat with a tall crystal prism sail fin along its back that splits light into a rainbow, its fur pearly white.","proud, dazzling eyes and a confident smile","pearl white and lilac, with rainbow refractions"),
 ("A fluffy stoat with a big gem-studded mane of coloured crystal points around its head and neck, like a crystal lion cub.","playful, gleaming eyes and a toothy grin","white and amethyst, with gem-coloured accents")])]
for _l,_n,_el,_dirs in _M:
    for _k,(_b,_f,_c) in enumerate(_dirs,1):
        VC(f'{_l}_m{_k}',_n,_C+_n+'.jpg','final',_b+_TIE,_f,_c,'other mink shapes, the old design, held objects, effects, text',_el,'majestic')
VC('effigoon_g1','Effigoon',_O+'c_effigoon_f1_1.jpg','mid',
 "A thick, completely FACELESS armoured cocoon: a smooth riveted pupa casing with no eyes, no mouth and no face of any kind, half-mechanical with brass seams and small vents, resting upright on a short stubby base. It reads as a defensive living capsule.",
 "no face at all (sealed, featureless front)","ivory and brass, with a dark iron accent","any face, eyes, mouth, a lion, legs, a snake",'titan','tough')
VC('effigoon_g2','Effigoon',_O+'c_effigoon_f1_1.jpg','mid',
 "A FACELESS segmented mechanical chrysalis hanging from a thick silk-and-cable stalk, its shell made of overlapping armour plates like a closed bud, a faint glow seeping from the seams; no face, no eyes, no mouth.",
 "no face at all (sealed shell)","bone white and bronze, with a warm amber glow","any face, eyes, mouth, limbs, an animal",'titan','tough')
VC('cisternmander_y1','Cisternmander',_C+'Barrelmander.jpg','final',
 "A huge, heavy salamander whose whole back is a grown stone cistern brimming with water, a waterfall spout pouring from a spout-shaped crest on its head, thick pillar legs and a broad paddle tail. No lightning, no clouds, no electricity.",
 "calm, heavy-lidded eyes and a broad grin","mossy stone grey and water blue, with a brass accent","lightning, storm clouds, sparks, a barrel, held objects",'tide','tough')
VC('cisternmander_y2','Cisternmander',_C+'Barrelmander.jpg','final',
 "A massive salamander with a moss-covered water-tower body, lily pads and reeds growing from the pooled water on its back, droplets running down its flanks, a wide frog-like mouth and a thick tail. No lightning, no clouds, no electricity.",
 "sleepy, wise eyes and a contented smile","mossy green and stone grey, with a pond-blue accent","lightning, storm clouds, sparks, a barrel, held objects",'tide','tough')
VC('glaivyx_h4','Glaivyx',_O+'c_glaivyx_g8_2.jpg','final',
 "A tall, lean, long-legged fox with very long slender legs and a long body, standing high like a maned wolf, with a single elegant curved blade-like tail held high (a fox tail ending in a sleek glaive edge, not a segmented scorpion tail).",
 "sharp, clever eyes and a sly fox grin","plum purple and lilac, with an acid-green accent","a scorpion tail, segmented tail, stingers, short legs, a dog",'venom','majestic')
VC('glaivyx_h5','Glaivyx',_O+'c_glaivyx_g8_2.jpg','final',
 "An elegant, long-legged fox with a long neck and long body, tall slender legs, big fox ears, and a long plume tail whose tip hardens into a curved venom-green crescent blade; it reads as fox first, weapon second.",
 "cunning, narrow eyes and a confident smirk","plum and cream, with an acid-green accent","a scorpion, segmented tail, crab legs, short legs, a dog",'venom','majestic')
