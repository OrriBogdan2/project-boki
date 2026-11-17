# 12:05 ET 11-09 OWNER REVIEW batch 2: look-alike fixes (coordinator 11:05 order: #12 #15 #27 #37 #31 #11 #30 #39 #14).
# Concepts first (3 directions x 4 runs); the owner picks on the A/B page, then sheet + card + portrait.
_C='briefs/boki-art/cards/'
def _RD(i,n,refs,lead,body,face,cols,avoid,el,arch):
    # redo of an existing Boki from its own card: keep identity, change only what `lead` says
    SPECS.append({'id':'c_'+i,'name':n+' (concept)','refs':refs+[SRA],'runs':4,'aspect':'1:1',
      'prompt':("Creature-collector monster concept art for a fantasy action game. "+lead+" The last image is the style reference only (soft hand-painted shading, clean thin dark outline, big glossy eyes); never copy its creatures. "
        "ONE creature only, full body, gentle three-quarter view with the head turned toward the viewer, centred with about 8 percent margin, plain flat pale grey background, no shadow, no ground, no rocks, no text, no effects. "
        +CORE+LESSONS+desc(body+" One clear idea, few parts.",face,cols,avoid,el,arch))})
_NG=" Full body, no crop, no ground, no rocks, no base under it. One clear idea, few parts."
# #12 Kestrike vs Arcestrel too close: new middle form, in motion, clearly not a kestrel chick grown up.
for _k,(_b,_f) in enumerate([
 ("A lean storm swift in a steep power dive, wings folded back into a sharp lightning-bolt zigzag shape, a long forked copper-wire tail, a swept-back crest of copper filament feathers.","narrow, thrilled eyes"),
 ("A long-winged storm kite-hawk gliding, wings stretched flat into copper coil vanes with crackling gaps between the feathers, a long fan tail, slim body, hooked beak.","sharp, focused eyes and a confident smirk"),
 ("A ground-sprinting storm hawk like a roadrunner, long legs mid-stride, short wings swept back, a tall spiky copper crest and a long copper-coil tail sparking behind it.","wild, eager eyes and an open grinning beak")],1):
    VC(f'arcestrel_n{_k}','Arcestrel',_C+'Kestrike.jpg','mid',_b+_NG,_f,'rust orange and storm blue, with a copper accent','a perched pose, a round chick body, ground, rocks','storm','fast')
# #15 Soakybara + Geysirbara: too similar, plain, same pose. Redesign both; each stands differently.
for _k,(_b,_f) in enumerate([
 ("A long, low capybara paddling forward through the air as if swimming, its whole back sunk into a steaming hot-spring rock pool with lily pads, little steam curls rising, front paws mid-stroke.","sleepy, blissful half-closed eyes and a content smile"),
 ("A capybara mid-waddle with a stretched, otter-like body, a ring of smooth river stones grown along its spine holding warm water, a cattail tail and moss on its paws.","dozy, relaxed eyes and a little smile"),
 ("A round capybara sliding forward on its belly like a sled, its back a bubbling mud-and-hot-spring pool with pebble rims, steam trailing behind it.","happy squinting eyes and a wide grin")],1):
    VC(f'soakybara_n{_k}','Soakybara',_C+'Dribbara.jpg','mid',_b+_NG,_f,'warm brown and spring teal, with a moss green accent','standing still, a pond sitting on top like a bowl, ground','tide','cute')
for _k,(_b,_f) in enumerate([
 ("A colossal capybara braced wide on four pillar legs with its head low, its back a towering crust of orange and yellow mineral terraces like a hot-spring cliff, a geyser blasting from a vent on its brow like a whale's spout.","heavy-lidded, stubborn eyes and big tusks"),
 ("A huge capybara sitting back on its haunches like a sumo, chest out, its back and shoulders a steaming boulder of travertine with geyser chimneys, mineral crust flowing down its sides like a mane.","calm, unshakable eyes and a proud smirk"),
 ("A massive capybara half sunk in its own boiling spring basin that has grown around its body like a stone collar of terraces, rearing its head up with a geyser plume erupting behind its head.","fierce, steaming eyes and bared tusks")],1):
    VC(f'geysirbara_n{_k}','Geysirbara',_C+'Dribbara.jpg','final',_b+_NG,_f,'warm brown and mineral orange, with a spring teal accent','a volcano cone around it, a green mountain, standing in profile','tide','tough')
# #27 Latchling + Lockatara: too similar, same pose. New middle form in motion (Vaultara is already the vault golem).
for _k,(_b,_f) in enumerate([
 ("A long, low monitor lizard scuttling fast, its body segmented into overlapping iron chain-link scales, the padlock shackle grown into an arched frill behind its head, its tail ending in a long key-bit blade.","sly, narrow keyhole-shaped pupils and a toothy grin"),
 ("A lean lizard coiled mid-pounce, its back a row of tumbler-pin spikes like the inside of a lock, a round combination-dial plate grown into its shoulder, a key-bit tail lashing.","sharp, scheming eyes"),
 ("A sneaky chameleon-like lizard creeping forward on long legs, its curled tail shaped like a big ornate key, keyhole markings down its back and a hinged shackle-shaped crest on its head.","half-lidded, sneaky eyes and a smug smile")],1):
    VC(f'lockatara_n{_k}','Lockatara',_C+'Latchling.jpg','mid',_b+_NG,_f,'olive green and dark iron, with a brass accent','a squat toad body, a padlock hanging on its back, standing still','titan','sleek')
# #37 Kintsuwyrm line doesn't read as related: Glazolm bridges Olmlet (white porcelain, blush) and Kintsuwyrm (white + crimson, heavy gold).
for _k,(_b,_f) in enumerate([
 ("A sleek porcelain salamander slithering forward, longer than a baby and not yet a dragon, its glossy white porcelain hide crackled and mended with gold seams, crimson glaze spreading from its tail tip up its back, scalloped porcelain gill frills and two small horn buds.","serene, milky eyes and a calm smile"),
 ("A long porcelain newt swimming through the air in an S-curve, white glaze with a few broken shards rejoined by thick gold seams, a crimson glaze stripe along its spine, frilly porcelain-petal gills.","gentle, dreamy eyes"),
 ("A porcelain salamander mid-stride on short legs, its body lengthening toward a serpent, white glaze with crimson patches and gold kintsugi cracks, a small ridge of porcelain shards starting along its spine, gill frills like glazed petals.","calm, closed-eye smile")],1):
    VC(f'glazolm_n{_k}','Glazolm',_C+'Olmlet.jpg','mid',_b+_NG,_f,'porcelain white and crimson, with a gold seam accent','green or celadon colour, long raised legs, wings, pottery shapes','wyrm','pretty')
# #31 Slog still reads as a mink: tar-slug middle form between Blotlet (blob) and Sloggoth (many-eyed sludge brute).
for _k,(_b,_f) in enumerate([
 ("A fat tar slug oozing forward, glossy purple-black body with no fur, three wobbly eye-stalks, a dripping mantle ridge and a trail of ink drops behind it.","big glossy violet eyes on stalks and a toothy little grin"),
 ("A leech-like tar blob humping along like an inchworm, its body pinched in the middle, glossy purple-black, two extra small eyes opening on its back.","mischievous violet eyes and a wide grin"),
 ("A tar tadpole-slug dragging itself forward on two stubby blob arms, a long drippy tail, glossy purple-black skin with faint violet veins.","goofy violet eyes and a gap-toothed smile")],1):
    VC(f'slog_n{_k}','Slog',_C+'Blotlet.jpg','mid',_b+_NG,_f,'glossy purple-black, with a violet accent','fur, a mammal face, ears, a mink or weasel body, green slime','shadow','creepy')
# #11 Crofthorn: weapon on its back (or similar) so it stands apart from the capybara line.
for _k,_b in enumerate([
 "Keep this highland calf exactly, but its garden wall back now carries a big rusty plough blade grown out of the stones like a curved back fin.",
 "Keep this highland calf exactly, but three iron pitchfork tines grow out of the stone wall on its back like spines.",
 "Keep this highland calf exactly, but its garden wall back now carries a long curved stone-and-iron scythe blade grown along its spine like a crest."],1):
    _RD(f'crofthorn_n{_k}','Crofthorn',[_C+'Crofthorn.jpg'],"Image 1 is this creature: keep its body, face, colours and pose; change only its back.",_b,'big green eyes and a stubborn little huff','ginger brown and stone grey, with a rusty iron accent','held tools, straps, a pond, a garden pot','wild','tough')
# #30 Anchorhorn clashes with Anchorbill: change the thing on its face; names proposed in CHANNEL per direction.
for _k,_b in enumerate([
 "Keep this creature exactly, but replace the anchor on its face with a single long barbed harpoon tusk growing from its upper jaw like a narwhal's, no anchor anywhere.",
 "Keep this creature exactly, but its face becomes a bronze-coloured ship's ram prow grown from its snout, a battering beak, no anchor anywhere.",
 "Keep this creature exactly, but replace the anchor on its face with two hooked grapnel tusks curving out of its jaw, no anchor anywhere."],1):
    _RD(f'anchorhorn_n{_k}','Anchorhorn',[_C+'Anchorhorn.jpg'],"Image 1 is this creature: keep its body, flippers, colours, rust and chain; change only its face.",_b,'fierce green eyes','deep teal and rust, with an iron accent','an anchor, a held weapon, a helmet','tide','tough')
# #39 Spanglin looks like the earlier green design (Pangolith, also curled into a ball): never curled, own pose.
for _k,(_b,_f) in enumerate([
 ("A pink pangolin pup mid-hop, uncurled, a stripe of small mirror-tile scales down its back only, its tail tip a little glittering disco ball, rainbow glints.","sparkly, excited eyes and an open smile"),
 ("A chubby pink pangolin pup sitting splay-legged on its bottom, belly out, mirror-sequin scales fanned up around its cheeks and shoulders, a short disco-ball tail tip.","shy, glittering eyes and a tiny grin"),
 ("A pink pangolin pup lying on its belly with its tail curled up over its back, the tail ending in a mirror ball, a few mirror tiles on its head like a tiny crown.","sleepy, sparkly eyes and a happy smile")],1):
    VC(f'spanglin_n{_k}','Spanglin',_C+'Mirrolin.jpg','baby',_b+_NG,_f,'soft pink and mirror silver, with a rainbow glint accent','curled into a ball, green, moss, flowers, glass terrarium plates','prism','cute')
# #14 Tinbrock line vs Kindlewren line look alike (both charcoal with lava cracks). Probe on the baby: two new palettes, same design.
for _k,_p in enumerate(["pewter and tin silver fur with brass rivet freckles and a white-blue forge glow instead of lava cracks",
                        "warm copper-bronze fur with a soot-grey face mask and blue-white spark cracks instead of orange lava"],1):
    _RD(f'tinbrock_n{_k}','Tinbrock',[_C+'Tinbrock.jpg'],"Image 1 is this creature: keep its body, face, pose and design exactly; change only its colours.",
        "A chubby little badger cub sitting up, recoloured: "+_p+".",'big round eyes and a curious look','tin silver and brass, with a white-blue accent','black fur, orange lava cracks, flames','titan','cute')
