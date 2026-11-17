# Owner 03:30 ET 11-09: "yes lets cut the 2 forms from the starters". Each starter now has ONE final:
#   Vespyx > Vespox > Glaivyx   (Lashyx cut)      Mycroll > Sporcupine > Ringrove   (Amanitusk cut)
# Owner 03:31: Mycroll's final - "both could be better" -> all-new directions, name Ringrove kept as placeholder.
# The old finals were Vespox with longer claws (Glaivyx/Lashyx) or a different animal (Ringrove), so each final gets fresh
# directions that are a real transformation but clearly the same line; best one goes straight to sheet+card+portrait.
_P62=[]
# Owner 03:31: "glaivyx also becomes more dog like than fox" -> every direction must read clearly as a fox.
_FOX=" Clearly a FOX, never a dog or wolf: long narrow pointed muzzle, very big tall pointed ears, slender sly fox face, big bushy fox proportions."
_AVV="a dog or wolf look (broad muzzle, heavy jaw, floppy or small ears), the same fox body as image 1 with longer claws, standing upright, a person, held weapons, effects, a busy design"
for _k,_b in (
 ('g1',"An epic scorpion-fox beast braced wide and low on four armoured legs, its body now plated in glossy dark chitin over plum fur, two huge pincer forelimbs raised, and a towering segmented scorpion tail arched high with a big glowing venom bulb."),
 ('g2',"A huge, sleek scorpion-fox standing tall and planted, a thick fur mane of plum and lilac framing its face, chitin plates down its back, and three segmented stinger tails fanned behind it like a war crest, each tipped with a lime venom bead."),
 ('g3',"A massive armoured scorpion-fox crouched like a coiled spring, its whole back a smooth dark exoskeleton shell, long sickle claws on its front legs, and a heavy tail curling over its body ending in a big curved stinger dripping lime venom."),
 ('g4',"A regal six-legged scorpion-fox: a long fox head and big ears, a broad chitin-armoured body on six planted legs, two great pincers held forward, and a long segmented tail curling high with a glowing venom orb at the tip."),
 ('g5',"A towering fox-scorpion knight standing planted on four legs with its chest out, bold chitin armour plates over the shoulders and legs (grown, not worn), a long elegant plume-like fur tail wrapped in segmented chitin bands ending in a crescent stinger."),
 ('g6',"A huge plum-and-black scorpion-fox with a heavy crest of chitin horns sweeping back from its brow, broad clawed forelegs planted wide, and a long armoured tail curled into a big S over its back with twin venom bulbs."),
 ('g7',"An epic desert-shadow scorpion-fox: lean but huge, low and wide like a scorpion, a fox face with a dark mask, a long segmented tail held overhead, glossy pincer forelimbs, and lime venom glowing through the joints of its armour."),
 ('g8',"A giant fluffy-maned scorpion-fox looming over the viewer, its front half fluffy plum fur and its back half a glossy segmented scorpion body with eight short legs, and a massive curled stinger tail with a big lime venom drop."),
):
    VC('glaivyx_'+_k,'Glaivyx','briefs/boki-art/evolutions/Vespox.jpg','final',_b+_FOX+" One clear idea, few parts.","fierce, clever lime-green eyes and a fanged grin","plum purple and dark chitin, with a toxic lime accent",_AVV,'venom','tough'); _P62.append('c_glaivyx_'+_k)
_AVM="a boar, held objects, standing upright, tall thin mushroom stalks, a busy design, the same body as image 1"
for _k,_b in (
 ('r1',"A huge, ancient mossy fungus beast shaped like a giant round hedgehog-tortoise: a high domed back that is a living forest floor of short spiky mushroom quills and moss, a big round hedgehog face, and four thick stumpy legs planted wide."),
 ('r2',"An enormous rolling spore-hedgehog: a huge round body covered in thick short mushroom spines with glowing caps, a broad friendly face, short powerful legs, braced wide with its head lowered like a living hill."),
 ('r3',"A giant mushroom-grove hedgehog the size of a hill, its back a ring of big flat bracket-fungus shelves and spiky mushroom quills around a mossy dome, a wise old hedgehog face with a mossy beard, planted on thick legs."),
 ('r4',"A massive armoured spore-porcupine grown into a walking grove: long pointed mushroom quills fanning out in a huge crest, spotted caps glowing softly at the tips, a strong hedgehog face, standing tall on four thick legs."),
 ('r5',"A huge mossy hedgehog with a shell-like back of overlapping mushroom caps like roof tiles, short spiky spore quills between them, a big friendly hedgehog face, braced wide and planted, small mushrooms sprouting along its tail."),
 ('r6',"A giant spore-hedgehog guardian sitting back on its haunches like a great mossy boulder, its huge round back a dense crown of short glowing mushroom quills, stubby clawed paws planted in front, and a calm, wise face."),
):
    VC('ringrove_'+_k,'Ringrove','briefs/boki-art/batch/out/c_sporcupine_s1_1.jpg','final',_b+" Clearly the grown-up final of image 1's hedgehog/porcupine line. One clear idea, few parts.","calm, wise teal eyes and a gentle smile","earthy brown and moss green, with soft mint mushroom caps",_AVM,'spore','tough'); _P62.append('c_ringrove_'+_k)
# "it can be changed and worked off that one": two directions that start from the current Glaivyx and fix it into a clear fox final.
for _k,_b in (('g9',"Keep the current Glaivyx from image 1 (plum fur, chitin armour plates, sickle claws, raised scorpion tail with lime venom bulb) but make it unmistakably a fox and bigger: a long narrow pointed fox muzzle, huge tall fox ears, a slim sly fox face, a thick bushy fox ruff at the neck, and a big planted final stance with chest out."),
              ('g10',"Keep the current Glaivyx from image 1 but turn it into a grand fox final: fox head with a narrow muzzle and very tall ears with dark tips, a bushy fox tail that becomes a segmented chitin stinger tail near the tip, chitin plates on shoulders and forelegs, sickle claws, standing tall and planted.")):
    _gr=next(f'briefs/boki-art/{d}/Glaivyx.jpg' for d in ('cards','evolutions','turnarounds') if (HERE.parent/d/'Glaivyx.jpg').exists())
    VC('glaivyx_'+_k,'Glaivyx',_gr,'redo_of',_b+_FOX+" One clear idea, few parts.","fierce, clever lime-green eyes and a sly fanged grin","plum purple and dark chitin, with a toxic lime accent",_AVV,'venom','tough'); _P62.append('c_glaivyx_'+_k)
PRIORITY=_P62+PRIORITY
