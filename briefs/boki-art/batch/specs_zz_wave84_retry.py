# 04:25 ET 11-09: families that stayed under 8.2 get one more round using the critics' "new prompt" notes (body-plan changes).
_P84=[]; _O='briefs/boki-art/batch/out/'
import os as _o84
def _s84(n): return next((f'briefs/boki-art/{d}/{n}.jpg' for d in ('turnarounds','evolutions','cards') if _o84.path.exists(HERE.parent/d/f'{n}.jpg')),None)
_R=[
 ('Anchorhorn','Anchorbill','tide','tough',"stern, sea-green eyes","dark iron grey and sea-black, with a rust and sea-green accent",[
   "A low, heavy, wide sea-hornbill sprawled on its belly like a beached turtle, its huge anchor beak dug into the ground, rusted chain links grown as a ridge down its spine (nothing around the neck or ankles), stubby wide legs.",
   "A squat, wide-legged diving seabird with a broad round body, its casque grown into a big rusted anchor fluke, a rudder-shaped tail, and barnacle-crusted wings folded tight, braced low."]),
 ('Bastionpet','Buckleron','stone','tough',"stubborn, grumpy little yellow eyes on stalks","iron grey and rust, with a brass accent",[
   "A wide, low crab with a flat shield-plate carapace spanning sideways, two huge plate claws braced forward, eye stalks peeking over the rim, no cone shell, scuttling sideways.",
   "A long, low caterpillar-like train of three domed shield shells crawling along, each segment with its own short spike and stubby legs, grumpy eye stalks peeking from the front shell."]),
 ('Cisternmander','Barrelmander','storm','tough',"small, calm yellow eyes and a wide, slow grin","wood brown and slate grey, with copper and an electric-yellow accent",[
   "A huge battery salamander reared up on a braced wide stance with its heavy head raised high, its barrel body grown into a big battery cell, copper running through it like veins (no bands), two copper horns grown from the skull with a single small arc between them.",
   "A massive battery salamander with a long, low segmented body of three distinct round battery cells like a caterpillar, each cell with its own short legs, copper terminal nubs on each, crawling in a new pose."]),
 ('Crofthollow','Crofthorn','bloom','tough',"calm, kind brown eyes under a shaggy fringe","russet brown and moss green, with stone grey and flower accents",[
   "A towering hill-beast braced wide whose whole body is the croft: dry-stone-wall shoulders, gnarled root-trunk legs, a thatched-roof mane, a tiny cottage chimney on its back, and long horns wrapped in climbing roses; a hill silhouette, not a cow.",
   "A low, wide mountain-ox whose back and flanks ARE terraced vegetable fields with little stone walls, legs like stone retaining walls, head lowered and horns swept forward, moss and flowers growing everywhere."]),
 ('Gongrowl','Gongibbon','echo','tough',"big readable fierce amber eyes and a fanged roar","charcoal black and bronze, with a burnt-orange accent",[
   "A huge stylised ape crouched on its knuckles, its chest and brow bone grown into its own bronze gong discs (nothing worn), a mane made of layered gong rims, long powerful arms and a mallet tail, simple bold shapes and big readable eyes.",
   "A towering gong ape rearing on its haunches with knuckles planted, bronze gong discs fused into its shoulders like plates, forearm callus shields shaped like small gongs, a huge mallet tail raised, stylised and scary."])]
for _new,_par,_el,_ar,_face,_cols,_dirs in _R:
    _ref=_s84(_par)
    if _new=='Cisternmander': _ref=_O+'c_barrelmander_gb_4.jpg'
    if _new=='Gongrowl': _ref=_O+'c_gongibbon_c4_3.jpg'
    for _k,_b in enumerate(_dirs,1):
        VC(_new.lower()+'_z'+str(_k),_new,_ref,'final',_b+" A new body plan and stance, clearly different from image 1. One clear idea, few parts.",_face,_cols,"the same body or stance as image 1, worn armour, helmets, collars, cuffs, standing upright like a person, a busy design",_el,_ar); _P84.append('c_'+_new.lower()+'_z'+str(_k))
PRIORITY=_P84+PRIORITY
