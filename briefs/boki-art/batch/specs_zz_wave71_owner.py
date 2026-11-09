# Owner 03:37-03:39 ET 11-09 batch: Frigatee evolves into a massive seal (Glaciatee); Lunowl/Eclipsowl need new names and many
# variations; Gravadillo needs an evolution; Zippelith still has an extra tail; Anchorbill restore (wave70).
_P71=[]
# Zippelith: the back view shows two extra rounded lobes beside the body (reads as extra tails). One clean edit of the sheet.
SPECS.append({'id':'ta_zippelith_tailfix','name':'Zippelith (tail fix)','refs':['briefs/boki-art/turnarounds/Zippelith.jpg'],'runs':4,'aspect':'16:9','size':'2K',
 'prompt':("Edit image 1 and keep everything exactly the same (all four views, design, colours, zipper, pose, layout, background) except: Zippelith is"
  " ONE single tube-shaped body with exactly one head end and exactly one tail end that has the zipper pull. Remove any extra tail, extra lobe or"
  " extra rounded body part: in the back view on the right, delete the two rounded lumps sticking out on the left and right of the body so it is a"
  " single smooth tube seen from behind. Never add a second tail.")}); _P71.append('ta_zippelith_tailfix')
# Glaciatee: final of Coolatee > Frigatee > Glaciatee; owner: "a massive seal".
_FR='briefs/boki-art/turnarounds/Frigatee.jpg'
_AVG="the same body as image 1 made bigger, a ship, a rider, standing upright, held objects, a busy design"
for _k,_b in (
 ('s1',"A massive elephant-seal titan hauled up and planted on its huge fore-flippers, chest raised and head high, a great inflated trunk-like nose, a thick neck mane of frost, and a back crusted with a big glacier of jagged blue ice like an iceberg."),
 ('s2',"An enormous walrus-like frost seal braced wide and heavy, two long curved ice tusks, a thick white blubbery body with blue frost markings, an icebreaker ridge of ice plates down its back like a ship's prow, and big flat ice-rimmed flippers."),
 ('s3',"A gigantic ice-leviathan seal rearing tall on its tail with fore-flippers spread wide, a sleek powerful body, a crown of icicle spikes around its head and neck, and its whole back a frozen glacier shell with snow on top."),
 ('s4',"A huge, round, heavy harbour seal the size of a hill, calm and powerful, lying planted with its head raised, wearing a thick armour of fused pack-ice plates on its back and shoulders, frosty whiskers like icicles and broad ice-rimmed flippers."),
 ('s5',"A massive glacier seal lowered into a charge, broad flat head with a ram-like ice brow, thick frost-blue blubber with white ice streaks, tall jagged ice fins along its spine, and a heavy forked ice tail fluke.")):
    VC('glaciatee_'+_k,'Glaciatee',_FR,'final',_b+" A massive seal, much bigger than image 1. One clear idea, few parts.","calm, heavy-lidded ice-blue eyes and a gentle, mighty look","pearl white and pale blue, with an ice-cyan accent",_AVG,'frost','tough'); _P71.append('c_glaciatee_'+_k)
# Lunowl / Eclipsowl: new designs (names to follow); Mothlet > [moth-owl mid] > [eclipse owl final]. Many variations.
_MO=next(f'briefs/boki-art/{d}/Mothlet.jpg' for d in ('turnarounds','evolutions') if (HERE.parent/d/'Mothlet.jpg').exists())
_AVO="a plain owl with moth wings stuck on, standing upright stiffly, a person, held objects, effects, a busy design"
for _k,_b in (
 ('m1',"A round fluffy moth-owl gliding low, its body a puffed owl with a big fuzzy moth collar, four broad soft moth wings with crescent-moon eye spots, feathery moth antennae as ear tufts."),
 ('m2',"A sleek night moth-owl caught mid-swoop, long pale-green luna-moth tail streamers trailing from its hind wings, a heart-shaped owl face, fluffy antennae tufts, wings marked with moon phases."),
 ('m3',"A plump moth-owl perched and hopping, a dense fuzzy mane of moth fur around its round face, small owl wings plus a pair of large pastel moth wings folded like a cloak, big feathered antennae."),
 ('m4',"A graceful moon moth-owl in a low dash across the ground, slim body, broad translucent moth wings held up and back, a single glowing crescent mark on its chest, long curved feathery antennae."),
 ('m5',"A sleepy-eyed velvet moth-owl fluttering, an extra-fluffy round body, four overlapping velvet wings in lilac and moon-green with soft eye-spot circles, comb-like antennae curling over its head.")):
    VC('lunowl_'+_k,'Lunowl',_MO,'mid',_b+" One clear idea, few parts.","big round glowing moon-gold eyes and a soft, curious look","pale moon green and lilac, with a soft gold accent",_AVO,'lunar','pretty'); _P71.append('c_lunowl_'+_k)
for _k,_b in (
 ('e1',"A huge eclipse great-horned owl planted on a perch-like stance with wings spread wide like a night sky, a dark disc of eclipse feathers behind its head ringed with a thin gold corona, and long moth-feather horns."),
 ('e2',"A towering shadow moth-owl with four great wings in deep violet that fade to black at the tips, each marked with a crescent-to-full moon phase spot, a regal crowned head of feathered antennae, standing tall and still."),
 ('e3',"A massive armoured night owl with a broad chest of layered dark feathers, a half-dark half-gold mask face like a solar eclipse, and big folded moth wings like a cloak trailing to the ground."),
 ('e4',"An eclipse sentinel owl rearing with wings raised overhead, a body of dusky purple feathers sprinkled with star specks, a glowing ring halo-corona behind it, and two long feathery antennae swept back like horns."),
 ('e5',"A great dusk moth-owl looming over the viewer, wide wings with huge eye-spot moons, a thick ruff of dark velvet fur, curling ram-like feathery antennae, and talons gripping the ground in a planted stance.")):
    VC('eclipsowl_'+_k,'Eclipsowl',_MO,'final',_b+" One clear idea, few parts.","glowing gold eclipse-ring eyes and a wise, commanding stare","deep violet and night blue, with gold corona accents",_AVO,'lunar','majestic'); _P71.append('c_eclipsowl_'+_k)
# Gravadillo: needs an evolution. Final form of a new 2-stage line (working name Gravitank).
_GR='briefs/boki-art/turnarounds/Gravadillo.jpg'
_AVR="the same body as image 1 made bigger, a vehicle, a rider, standing upright, a busy design"
for _k,_b in (
 ('g1',"A massive gravity armadillo titan braced wide on thick legs, its armoured shell bands now huge dark stone plates, a giant forward horn, and a slow ring of orbiting boulders circling its body like a planet's ring."),
 ('g2',"A huge armadillo that has become a living planetoid: curled half-round into a great ball-like shell with craters and orbiting moonlets, its head and big horn pushing out the front, short powerful legs planted."),
 ('g3',"An enormous rhino-armadillo with a crown of three heavy horns, layered gravity-stone shell plates floating slightly apart from its body as if weightless, and a dark violet gravity ring around its shoulders."),
 ('g4',"A colossal armadillo juggernaut lowered to charge, tall jagged stone plates along its back, a battering-ram horn, and the ground cracking and lifting in small floating chunks around its feet."),
 ('g5',"A towering armadillo golem standing tall on its back legs like a rearing bear, huge banded stone shell, long curved horn, small boulders orbiting its head in a halo.")):
    VC('gravitank_'+_k,'Gravitank',_GR,'final',_b+" Clearly Gravadillo's evolution, much bigger and more powerful. One clear idea, few parts.","small, stubborn violet eyes and a determined glare","dark slate and charcoal, with a violet gravity accent",_AVR,'gravity','tough'); _P71.append('c_gravitank_'+_k)
PRIORITY=_P71+PRIORITY
