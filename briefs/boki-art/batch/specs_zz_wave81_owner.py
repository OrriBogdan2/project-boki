# Owner 04:00 ET 11-09 review of the picks page. Kept picks (going live): Bucketmander/Barrelmander battery, Terrasloth pangolin,
# Glaciatee, Lunowl, Thunderstrich, Mortarfly, Gravitank (g4 saved as reference), Barokat cloud halo (Meeko has the thundercloud),
# Glaivyx g8 and Ringrove r6 and Reapant n4 for now. Swaps and redos below; wave79 jobs for Eclipsowl, Lanceron, Pyrraven,
# Effigoon and Chandelapi are skipped at review (not promoted).
_O='briefs/boki-art/batch/out/'; _P81=[]
def _pick3(_n,_src,_stg,_pose,_tag):
    _l=_n.lower()
    TA(_n,_O+_src+'.jpg'); SPECS[-1]['id']='ta_'+_l+'_'+_tag; _P81.append('ta_'+_l+'_'+_tag)
    SPECS.append({'id':_l+'_card'+_tag,'name':_n+' (hero card)','refs':[_O+_src+'.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(_n,_stg,_pose)}); _P81.append(_l+'_card'+_tag)
    P(_l+'_'+_tag,_n,_O+_src+'.jpg',_pose); _P81.append('portrait_'+_l+'_'+_tag)
# Swaps the owner chose: Lanceron option 2 (ice heron-dragon), Pyrraven option 2 (horned vulture-raven).
_pick3('Lanceron','c_lanceron_k2_1','final','towering with frozen crystal wings spread wide','o81')
_pick3('Pyrraven','c_pyrraven_d3_1','final','hunched and looming with molten-cracked wings folded like a shroud','o81')
def _dirs(_n,_ref,_rel,_list,_face,_cols,_avoid,_el,_ar,_pre):
    for _k,_b in enumerate(_list,1):
        VC(_pre+str(_k),_n,_ref,_rel,_b+" One clear idea, few parts.",_face,_cols,_avoid,_el,_ar); _P81.append('c_'+_pre+str(_k))
# Glaivyx: "a little too scorpion; keep your pick but longer, with taller legs; or work off the OG Glaivyx".
_dirs('Glaivyx',_O+'c_glaivyx_g8_2.jpg','redo_of',[
 "Same creature as image 1 but a longer, leaner fox body on tall, slender legs, standing tall: much more fox than scorpion, fluffy plum fur and big ears, chitin only as plates on the shoulders and legs, one long segmented stinger tail arched high.",
 "Same creature as image 1 but long and elegant like a big fox on tall legs, mid-stride, bushy plum ruff, sleek chitin bracers on its forelegs, a long fox tail that turns into a segmented stinger near the tip with a lime venom bulb.",
 "A tall, long-legged plum fox (more fox than scorpion), long muzzle and huge ears, chitin plating along its spine like a ridge, slim sickle claws on its front paws, and a high-arched stinger tail."],
 "fierce, clever lime-green eyes and a sly fanged grin","plum purple and dark chitin, with a toxic lime accent","a scorpion body, eight legs, pincers, a dog or wolf look, standing upright, a busy design",'venom','tough','glaivyx_h')
_dirs('Glaivyx','briefs/boki-art/evolutions/Glaivyx.jpg' if (HERE.parent/'evolutions'/'Glaivyx.jpg').exists() else 'briefs/boki-art/cards/Glaivyx.jpg','redo_of',[
 "Keep the original Glaivyx from image 1 but make it longer and taller on long legs, a clear sly fox face with a narrow muzzle and very tall ears, bigger and grander, chitin plates and stinger tail kept."],
 "fierce, clever lime-green eyes and a sly fanged grin","plum purple and dark chitin, with a toxic lime accent","a dog or wolf look, standing upright, a busy design",'venom','tough','glaivyx_o')
# Ringrove: "love the back, his face is like an old bear" -> keep the mushroom-grove back, younger and more hedgehog face.
_dirs('Ringrove',_O+'c_ringrove_r6_4.jpg','redo_of',[
 "Same creature and mushroom-grove back as image 1 but a younger, livelier face: a clear hedgehog face with a pointed snout, bright eyes and a friendly grin, no old-bear look, sitting back strong.",
 "Same mossy mushroom back as image 1 on a big hedgehog with a bold, heroic face (pointed hedgehog snout, round ears, confident smile), braced wide on thick legs.",
 "Same idea as image 1 but the face is Mycroll's grown up: cream hedgehog face, big teal eyes, a small pointed nose, a cheeky smile, the huge glowing mushroom-quill back kept."],
 "bright teal eyes and a friendly, confident grin","earthy brown and moss green, with soft mint mushroom caps","an old bear face, a beard, wrinkles, standing upright, a busy design",'spore','tough','ringrove_y')
# Eclipsowl: "has to look like a more epic, dark version of the one before" (new Lunowl, image 1); a real final.
_dirs('Eclipsowl',_O+'c_lunowl_m2_1.jpg','final',[
 "The dark, epic final of image 1: the same moth-owl idea grown huge and sinister, deep violet-black plumage, four great tattered moth wings with eclipse-ring eye spots, long trailing tail streamers like night smoke, glowing gold eclipse eyes, looming with wings spread.",
 "A huge dark moth-owl, the night version of image 1: black-violet fur, a heavy mane, long luna tails turned into dark trailing ribbons edged in gold corona light, a crescent-horned brow, perched planted and imposing.",
 "A towering eclipse moth-owl: the same body plan as image 1 but much bigger and darker, wings like a total eclipse (black discs ringed with thin gold fire), feathered antennae swept back like horns, long dark tail streamers.",
 "An epic dark moth-owl spreading four enormous wings in a wide fan, each wing deep night-blue fading to black with a gold eclipse ring, a big fluffy dark ruff, antennae like a crown, glowing eyes, imposing and still."],
 "glowing gold eclipse-ring eyes and a cold, commanding stare","deep violet and night black, with gold corona accents","a pastel palette, the same size as image 1, standing upright like a person, a busy design",'lunar','majestic','eclipsowl_d')
# Reapant: "taller/cooler version of your pick, different colours/height".
_dirs('Reapant',_O+'c_reapant_n4_2.jpg','redo_of',[
 "Same ninja ant as image 1 but much taller and leaner on long legs, standing high in a ready stance, dark night-blue and charcoal armour with a crimson eye-mask marking and crimson blade edges.",
 "Same ninja ant idea as image 1, taller and cooler: long slim body raised high, blade forelegs crossed in front, a long dark leaf-frond scarf streaming behind, deep black-green with a bright jade mask band.",
 "A tall, sleek shadow ninja ant, long legs and a narrow waist, blade forelegs swept back, a split frond scarf, charcoal armour with violet accents and a glowing violet eye band."],
 "narrow, focused glowing eyes behind a mask band","night charcoal and deep blue, with a crimson accent","a mantis, a person, clothes, held weapons, a busy design",'swarm','fast','reapant_t')
# Effigoon: "meant to be no face while in a cocoon" -> faceless defensive cocoon, more mechanical than Effigeetle.
_dirs('Effigoon','briefs/boki-art/cards/Effigeetle.jpg','mid',[
 "A faceless, heavily armoured cocoon: a smooth marble pod sealed shut, wrapped in riveted brass bands, gears turning in a ring around its middle, the gold horn as a spire on top, hanging from a short brass hook. No face, no eyes, nothing alive showing.",
 "A faceless clockwork chrysalis vault: an upright marble egg with hinged brass armour plates closed like a safe, a small round brass porthole glowing amber from inside (no face), sitting heavy on three short brass feet, gold horn on top.",
 "A faceless siege cocoon: a thick marble shell banded in brass with rows of rivets and small defensive spikes, a turning brass gear crown, the gold horn folded down like a latch, sealed and silent."],
 "no face at all; a single soft amber glow showing through a seam","marble white and polished brass, with gold and amber accents","a face, eyes, a mouth, legs, a snake body, wheels, a tank, a busy design",'stone','tough','effigoon_f')
# Mortarfly: agreed, "can be a bit more epic".
_dirs('Mortarfly',_O+'c_mortarfly_a2_2.jpg','redo_of',[
 "Same artillery butterfly as image 1 but more epic: much bigger wings like ornate brass-and-marble battlements, more cannon tubes along the wing edges, wings raised high, planted wide on brass legs.",
 "Same design as image 1 but grand and imposing: four huge layered marble-and-brass wings fanned wide like a fortress, a heavy armoured thorax, the statue face calm under a gold horn crown."],
 "calm, serene carved statue face with glowing amber eyes","marble white and polished brass, with gold and amber accents","a person, held weapons, explosions, a busy design",'stone','majestic','mortarfly_x')
# Chandelapi: "is this the final form? the pick looks like a form 2" -> grander final, still simple and graceful.
_dirs('Chandelapi',_O+'c_chandelapi_m2_2.jpg','final',[
 "The grand final of image 1: a much bigger, taller, broad-chested okapi stag with a commanding presence, a wide crown of smooth candelabra antlers holding six tall violet-flame candles, a long flowing wax-drip mane, clean silhouette.",
 "A towering regal okapi elder, twice the size of image 1, long powerful legs, a heavy ruff of pale wax at the chest, great sweeping antlers ending in tall violet flames, head held high and calm.",
 "A majestic, ancient okapi spirit, large and stately, antlers like a cathedral candelabra with violet flames, melted wax robing its shoulders like a mantle, bold leg stripes, standing tall."],
 "gentle, wise violet eyes and a calm, regal look","dark chestnut brown and soft cream, with brass and violet-flame accents","gold filigree over the body, more than eight candles, spikes, a chandelier, a busy design",'ember','majestic','chandelapi_f')
PRIORITY=_P81+PRIORITY
