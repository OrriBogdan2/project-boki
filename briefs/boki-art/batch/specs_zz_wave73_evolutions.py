# Owner 03:40-03:41 ET 11-09: "lanterloris needs an evolution that makes him tall and skinny"; "i generally dont like too many 1
# evolutions cuz theyre boring - they should be a minority (legendaries and a few specific bokis)"; "rimeshrew seems boring to me,
# needs a change and 2 evolutions (1 below 1 above)".
# Singles kept: Cairnback, Hivara, Zephyrak (rares), Barokat (just redesigned), Terrasloth (being re-animaled). Everyone else
# that was single gets an evolution (Effigeetle, Glomwort, Gravadillo in waves 68/71/72). Working names; owner confirms names.
import os as _o73
def _s73(n): return next((f'briefs/boki-art/{d}/{n}.jpg' for d in ('turnarounds','evolutions','cards','portraits/light','portraits') if _o73.path.exists(HERE.parent/d/f'{n}.jpg')),None)
_P73=[]
_AV73="the same body as image 1 made bigger, standing upright like a person, held objects, a busy design"
_EVO={
 'Lanterloris':('Lanternlong','echo','pretty',"warm amber eyes and a shy, gentle smile","cream and soft brown, with warm lantern-orange light",[
   "A tall, very skinny slow loris with long thin stilt-like limbs and a long neck, its slender body a tall paper lantern of stacked glowing segments with bamboo ribs, a long tassel tail, standing tall and swaying.",
   "A towering, lanky loris like a tall paper lantern pole, long thin arms reaching up, its narrow chest a glowing lantern column, tiny head with huge eyes at the top, and a long hanging tassel tail.",
   "A tall, thin festival-lantern loris balanced on long skinny legs, three small glowing paper lanterns strung down its long body like a lantern string, long spindly fingers, and big gentle eyes.",
   "A tall, elegant loris on long thin legs with an extra-long slender body that glows through paper-thin skin with bamboo ribs, a long curling tassel tail, and a small round head tilted curiously."]),
 'Crofthorn':('Crofthollow','bloom','tough',"calm, kind brown eyes under a shaggy fringe","russet brown and moss green, with stone grey and flower accents",[
   "A huge highland bull whose broad back carries a whole little farmstead hill: dry-stone walls, a tiny thatched cottage roof grown from its hide, an orchard tree, and long horns wrapped in climbing roses.",
   "A massive shaggy highland ox braced wide, its back a terraced hillside of stone-walled vegetable fields, a small waterfall running down its flank, and huge curving horns with ivy and flowers."]),
 'Lodestick':('Lodestaff','gravity','fast',"narrow, sharp silver eyes","dark iron grey and charcoal, with a red-and-blue magnet accent",[
   "A tall, long-limbed lodestone stick insect standing high on stilt legs, its body a long iron rod with red and blue magnetic poles at each end, swarms of iron filings standing up along it like bristling fur, metal shards orbiting it.",
   "A huge praying-stick insect of black lodestone with long spear-like forelegs, magnetic field-line grooves along its body, and a ring of floating iron shards held around it."]),
 'Pipewurm':('Pipeworth','venom','creepy',"sleepy, sly eyes and a satisfied smirk","dusky pink and plum, with a lime venom accent",[
   "A long, thick velvet worm with many stubby legs and three pastry piping nozzles on its head like a crown, piping looping lines of glowing venom icing in patterns, its body ringed with frosting-like ridges.",
   "A huge velvet-worm dragon with a broad head ending in a big fluted piping-bag nozzle, velvety plum body with sugar-pearl spots, dozens of stubby legs, and venom-icing frills along its back."]),
 'Gloamshell':('Gloamspire','shadow','majestic',"glowing violet eyes on long stalks","smoked obsidian black and dusky blue-grey, with a violet glow",[
   "A large snail whose shell has grown into a tall twisting obsidian-glass spire like a dark lighthouse tower, violet light glowing from slit windows inside, its soft body broad and dusky blue.",
   "A big shadow snail with a huge spiral obsidian shell cracked with glowing violet seams, long elegant eye stalks, and a smoky trail behind it, planted and looming."]),
 'Mossgrade':('Mossbastion','bloom','tough',"tiny sleepy eyes and a round tube mouth","moss green and earth brown, with tiny flower accents",[
   "A huge tardigrade like a walking mossy hill, eight thick stubby legs, a thick shaggy carpet of moss and ferns on its round body, small flowers and mushrooms growing in it, and a round tube mouth.",
   "A giant armoured tardigrade with plated segments covered in thick moss and lichen like a fortress wall, eight sturdy clawed legs planted wide, and small saplings growing from its back."]),
 'Selenfin':('Selenwhale','lunar','majestic',"calm, glowing moon-white eyes","moonstone silver and pale blue, with a soft lunar glow",[
   "A large floating moonstone hatchetfish grown into a sky-whale shape, its body glowing softly from inside, long crescent fins like wings, and a full-moon disc glowing on its side.",
   "A great floating moonstone fish with a broad round body like a full moon, delicate crescent fins and long trailing tail fins like moonlight streamers, hovering low and serene."]),
 'Anchorbill':('Anchorhorn','tide','tough',"stern, sea-green eyes","dark iron grey and sea-black, with a rust and sea-green accent",[
   "A huge hornbill whose giant beak is a massive iron ship's anchor, heavy chain links grown along its neck, barnacles on its dark feathers, wings like tattered sails, planted and looming.",
   "A massive anchor-beaked sea bird braced wide, its casque a heavy iron capstan crown, rusted chain feathers on its wings, and a tail like a ship's rudder."]),
}
for _n,(_new,_el,_ar,_face,_cols,_dirs) in _EVO.items():
    if not _s73(_n): print('no image for',_n); continue
    for _k,_b in enumerate(_dirs,1):
        VC(_new.lower()+'_e'+str(_k),_new,_s73(_n),'final',_b+" Clearly "+_n+"'s evolution, much bigger. One clear idea, few parts.",_face,_cols,_AV73,_el,_ar); _P73.append('c_'+_new.lower()+'_e'+str(_k))
# Rimeshrew: redesign + a baby below + a final above (3-stage: [baby] > Rimeshrew > [final]).
_RS=_s73('Rimeshrew')
for _k,_b in (('r1',"A quick frost shrew with a big fluffy ruff of frost-tipped fur like a snowball collar, a long twitchy nose ending in an icicle, ice-crystal whiskers, and a long tail tipped with a snowflake, mid-scurry."),
              ('r2',"A frost shrew wearing a shell of clear ice like an igloo grown onto its back, tiny icicle claws, a frost-white face mask and a pink twitchy nose, dashing low."),
              ('r3',"A tiny ice-skater shrew sliding on its belly over its own frost trail, frost spikes bristling down its back like a hedgehog of ice, big ears rimmed in frost, and a long icicle-tipped tail.")):
    VC('rimeshrew_'+_k,'Rimeshrew',_RS,'redo_of',"Same frost shrew idea as image 1 but much more distinctive and fun: "+_b+" One clear idea, few parts.","bright, darting ice-blue eyes and a cheeky grin","snow white and pale blue, with an ice-cyan accent","a realistic shrew, standing upright, held objects, a busy design",'frost','fast'); _P73.append('c_rimeshrew_'+_k)
for _k,_b in (('b1',"A tiny round snowball shrew baby, almost a perfect fluffy white sphere with a pink nose and two tiny paws, a few frost crystals on its fur."),
              ('b2',"A newborn frost shrew curled in a little ice-crystal nest shell, huge eyes, tiny twitchy nose with a dewdrop of ice, stubby legs.")):
    VC('rimekit_'+_k,'Rimekit',_RS,'baby',_b+" One clear idea, few parts.","huge sparkly ice-blue eyes","snow white and pale blue, with a pink nose","a realistic shrew, held objects",'frost','cute'); _P73.append('c_rimekit_'+_k)
for _k,_b in (('f1',"A large, powerful frost shrew-beast, long and low, with a thick armour of jagged ice plates along its back like a glacier ridge, huge icicle claws, a long ice-spike nose like a lance, and a frost-mist mane."),
              ('f2',"A big blizzard shrew with a huge mane of whirling frost fur, long legs built for speed, crystal ice horns along its nose, and a long tail ending in a cluster of ice spikes, planted and snarling.")):
    VC('rimefang_'+_k,'Rimefang',_RS,'final',_b+" One clear idea, few parts.","fierce ice-blue eyes and a fanged snarl","snow white and glacier blue, with an ice-cyan accent","a realistic shrew, standing upright, a wolf, a busy design",'frost','tough'); _P73.append('c_rimefang_'+_k)
# Owner 03:43: "knotwyrm i would suggest a cute pre-evolution" -> baby below Knotwyrm instead of a final above.
for _k,_b in (('k1',"A tiny, round baby worm made of soft fluffy yarn-like rope tied into one single loose bow knot, a little mushroom sprout on its head, stubby frayed-fibre tufts, sitting in a curl."),
              ('k2',"A small chubby rope-worm baby coiled into a simple round knot like a cinnamon bun, big sleepy eyes on its knotted end, a tiny mushroom cap on top, soft frayed fuzz."),
              ('k3',"A tiny wiggly rope-noodle baby with a single cute overhand knot in the middle of its body, a big head with huge eyes, two little button mushrooms on its back, bouncing.")):
    VC('knotling_'+_k,'Knotling',_s73('Knotwyrm'),'baby',_b+" One clear idea, few parts.","big, sleepy, sweet eyes and a tiny smile","hemp tan and soft cream, with moss-green and mushroom-cap accents","a person, held objects, a busy design",'spore','cute'); _P73.append('c_knotling_'+_k)
PRIORITY=_P73+PRIORITY
