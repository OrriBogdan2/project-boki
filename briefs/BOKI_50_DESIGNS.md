# Boki 50: designs, scores, upgrades and redesigns

Status: creature-design pass over ROSTER_50.md, 2026-11-07. Game data (`id`, size class, body type and rig, theme,
abilities, merge stub, rarity, biome, big-Boki role, mount numbers) is unchanged for every one of the 50. Only
names, mixes, looks and personalities change. Mounts stay at 6.

Owner's brief: "cool / interesting mixes of animals, objects, etc - be creative. Inspo from Pokemon, Digimon etc
is fine as long as it's not a rip."

## The judging rubric (1-5 each, total out of 30)

1. **Hook.** One line a 12-year-old would repeat to a friend.
2. **Surprising mix.** At least one non-animal ingredient (object, tool, food, instrument, machine, weather,
   mineral, plant) that changes the silhouette, not just the colour or texture.
3. **Silhouette.** Readable top-down at about 40 px: one big shape idea, distinct from all other 49.
4. **Personality + gameplay link.** The mix explains how it fights or helps.
5. **Buildability.** A single clean 3D model from a turnaround (Meshy): no thin floating parts, no
   particle-only bodies; limbs, wings and tail that the shared rig can drive.
6. **Originality.** Inspiration is fine, a rip is not. Not a rip = not the same animal + concept + silhouette +
   palette as an existing creature, and not its name. Where there is a clear inspiration it is named with the
   two things that make ours different.

Pass mark for a design that goes to art: **20/30**, with at least 4 on Hook, Mix, Silhouette, Personality and
Buildability. Every redesign below meets that; the kept originals meet the 20 total.

How scores are written: `H M S P B O = total` in rubric order.

## Summary

- **21 with 3D models.** Scored as they are. **8 kept** (cindle 21, pebbit 21, cairnback 25, glintmole 21,
  mossgrade 22, kestrike 20, thrumbird 22, selenfin 21). **13 get a v2 upgrade** (under 20): burrlet, puddlet,
  wisplet, zapple, hivara, zephyrak, kindlewren, rimeshrew, gloamshell, nettlynx, lodestick, marchleaf, glomwort.
  Each upgrade keeps the body type, size and rig and can be applied by editing the existing model (a new tail,
  crest, shell or back prop on the existing socket).
- **29 without models: all redesigned.** New mixes for all 29; 27 new display names (Murmurling and Umbrathere
  keep theirs because the new mix still fits the word). 29 of 29 carry an object, machine,
  food or instrument ingredient (the brief asked for at least a third). Weather, mineral and plant ingredients
  are kept where the theme needs them (storm clouds, ice, heather, moonflower).
- **Range:** cute (Soakybara, Lanterloris, Bubblisk, Snuffapi), weird (Zippelith, Pipewurm, Knotwyrm), majestic
  (Canvastross, Prowyak, Crofthorn, Spirevark), funny (Gongibbon, Mirrolin, Boltstrich, Barrelmander),
  creepy-cute (Effigeetle, Lockatara, Zippelith). Land 20, air 6, water-ish 3 of the 29.
- **Clashes removed while designing:** two copper weather-objects (Kestrike rod vs old Sentrikat vane), two
  mirror Boki (old Vanitail idea vs Mirrolin), three iron fire-boxes in ember (oven, stove, engine), two canopies
  (parasol vs umbrella), two sewing Boki (zipper vs needle), two lamps (lighthouse vs lantern), two candle Boki.
  Final set has none of these pairs.

## Shared image-prompt rules

Every prompt block below is self-contained, but these rules apply to all of them and the image session should
keep them in its system text:

- Output is a **concept sheet with a turnaround**: front, side, back and 3/4 views in a row, same scale, neutral
  standing (or hovering) pose, feet on one ground line, flat even light, plain pale grey background, whole body in
  frame with margin. Tail, ears, wings, back props must be fully visible in the side and back views.
- Style: **stylised hand-painted game art, chunky readable shapes, soft gradients, clean silhouette, no outlines
  heavier than the shapes, no text, no labels, no humans, no scenery, no weapons held in hands.**
- The model has no negative-prompt field, so the "no ..." clauses are part of the prompt text.
- Theme glow: a small amount of emissive colour only where the entry says; never a full-body glow.

---

# Part A: the 21 with 3D models

## Kept (8)

### Vespyx (`cindle`) KEPT 21/30
Fox + Scorpion. venom, small, quadruped QUAD, bruiser. Stinger Hook (E), Stinger Dash (auto).
Score: 3 2 4 4 5 3 = **21**. The curled stinger tail reads well and the hook ability is literal. The miss is the
lack of a non-animal ingredient; fire/venom foxes are a crowded field (Fennekin, Vulpix) but fox + scorpion is
not taken. Optional later twist (not required): the stinger barb as a brass fishing-hook.

### Gravadillo (`pebbit`) KEPT 21/30
Armadillo + Rhino beetle. gravity, large companion, QUAD-L, tank. Gravity Slam (E), Mass Guard (auto).
Score: 3 2 4 4 5 3 = **21**. Strong heavy silhouette, horn + plates say "tank" at a glance. Animal-only mix.
Optional later twist: the plates as a stack of weight-lifting plates with a bar through the horn.

### Cairnback (`cairnback`) KEPT 25/30
Tortoise + Ibex + rune-carved cairn. titan, large bulwark, QUAD-L, tank. Boulder Heave (E), Mass Guard (auto).
Score: 4 4 4 5 5 3 = **25**. Best of the live nine: it throws its own cairn stones and stands as cover.
Inspiration: Torterra (tree-tortoise). Different: ibex horns and a stacked stone cairn, no tree, grey + gold.

### Glintmole (`glintmole`) KEPT 21/30
Star-nosed mole + Quartz geode. stone, small, QUAD, controller. Puffcap Mines (E), Echolocate (auto).
Score: 3 3 3 4 5 3 = **21**. The cracked-open geode ridge is a real silhouette change and the star nose explains
Echolocate. Tweak for the texture pass only: make the star nose a tiny quartz cluster so the two ingredients meet.

### Mossgrade (`mossgrade`) KEPT 22/30
Tardigrade + Cushion moss. bloom, small, BLOB, support. Prism Wall (E), Refraction (auto).
Score: 4 3 3 3 5 4 = **22**. A water bear with a garden on its back is a hook on its own. Keep.

### Kestrike (`kestrike`) KEPT 20/30
Kestrel + Copper lightning rod. storm, small, WING, skirmisher. Echo Chain (E), Storm Arc (auto).
Score: 3 3 3 4 4 3 = **20**. Just passes. The copper rod is now the only copper weather-object in the 50 (the
old Sentrikat weathervane is gone). Texture pass: make the rod crest a stubby finial, not a needle.

### Thrumbird (`thrumbird`) KEPT 22/30
Hummingbird + Tuning fork. echo, small, WING, support. Prism Wall (E), Echolocate (auto).
Score: 4 4 3 4 3 4 = **22**. Keep. Buildability note for the next retopo: thicken the fork tines and the beak.

### Selenfin (`selenfin`) KEPT 21/30
Hatchetfish + Moonstone. lunar, small, FIN, support. Prism Wall (E), Refraction (auto).
Score: 3 3 4 3 4 4 = **21**. An upright floating hatchet-fish is the most distinct small silhouette we have. Keep.

## Upgrades (13): v2 twists for existing models

Each keeps id, size, body type and rig. "Edit" says which part of the existing model changes.

### Mycroll (`burrlet`) UPGRADE 19 -> 25
- **Was:** Hedgehog + Toadstool, glowing toadstool quills. Score 2 3 3 4 5 2 = 19 (mushroom-quill hedgehog is a
  stock fantasy design; Shroomish/Paras territory).
- **Mix v2:** Hedgehog + one big toadstool cap worn as a hinged lid.
- **Hook:** A hedgehog that pretends to be a mushroom: pull the lid down and it is just a toadstool in the grass.
- **Look:** Silhouette = a round hedgehog under one oversized red-brown toadstool cap that covers it like a
  helmet-lid, quills poking out under the rim. Key shapes: domed cap with cream spots, a ring of short quills under
  the rim, a small pointed snout and two black bead eyes peeking out. Palette: rust-red cap, cream spots and belly,
  umber quills, teal spore glow in the gills under the cap.
- **Fights / helps:** Puffcap Mines are tiny copies of its own cap it leaves in the grass; Spore Patch is the teal
  dust that sifts from its gills when it hunkers. Controller: it hides, then the mines pop.
- **Personality:** Curious and odd; thinks nobody can see it when the lid is down.
- **Inspiration:** Shroomish / Foongus (mushroom Pokemon). Different: it is a hedgehog with a working hinged cap
  (mammal face and legs visible), and the mushroom is a disguise, not its body.
- **Edit:** replace the quill-toadstool clusters with one cap mesh on the back socket; keep body and legs.
- **Score v2:** 4 4 4 5 5 3 = **25**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A small round hedgehog wearing one oversized toadstool cap on its back like a hinged helmet lid; the rust-red cap has cream spots and nearly covers the body, short umber quills poke out under the rim, a small pointed snout and two black bead eyes peek out from under the cap, four stubby legs, tiny tail visible in side and back views, faint teal glow in the gills under the cap edge. Palette: rust red, cream, umber, teal glow. Stylised hand-painted game art, chunky readable shapes, soft gradients. No multiple small mushrooms, no quills made of mushrooms, no fire, no text, no scenery, no humans.
```

### Prismander (`puddlet`) UPGRADE 19 -> 24
- **Was:** Axolotl + Crystal, crystal frills. Score 3 3 3 4 4 2 = 19 (cute pink axolotl is everywhere now).
- **Mix v2:** Axolotl + crystal chandelier for gills.
- **Hook:** An axolotl wearing a chandelier for gills; it chimes and throws rainbows when it is nervous.
- **Look:** Silhouette = a plump axolotl whose six gill-frills are tiered chandelier arms hung with cut-crystal
  drops, all one solid fan behind the head. Key shapes: the chandelier fan (three arms each side, drops as thick
  teardrop beads), a wide smiling axolotl head, a flat paddle tail. Palette: pale pink body, white-pink belly,
  clear crystal with cyan refraction, a little brass at the arm roots.
- **Fights / helps:** Prism Wall: it flares the chandelier fan and the drops lock into a glass pane. Refraction:
  rainbow sparks flick off the drops onto allies. Support.
- **Personality:** Gentle and a little formal; worries that its drops are not straight.
- **Inspiration:** Chandelure (chandelier Pokemon). Different: it is an amphibian body with the chandelier as
  gills, prism-crystal not ghost-fire, pink and cyan not black and purple.
- **Edit:** replace the frill meshes with chandelier arms, same sockets, drops as solid beads.
- **Score v2:** 4 4 4 4 4 4 = **24**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral hovering pose just above the ground line, flat even light, plain pale grey background, whole body in frame). A plump pale pink axolotl whose six external gills are the arms of a small crystal chandelier: three tiered brass arms each side of the head hung with thick clear teardrop crystal beads, forming one solid fan behind the head, a wide gentle smiling face, four short legs, a flat paddle tail clearly visible in side and back views, soft cyan refraction glints in the crystals. Palette: pale pink, white-pink belly, clear crystal with cyan, warm brass. Stylised hand-painted game art, chunky readable shapes. No candles, no flames, no thin wires, no dangling loose chains, no text, no scenery.
```

### Lunowl (`wisplet`) UPGRADE 17 -> 22
- **Was:** Owl + Luna moth. Score 3 2 3 3 4 2 = 17 (moth-owls are common; no object).
- **Mix v2:** Owl + luna moth + a crescent-moon face mask.
- **Hook:** An owl whose face is a crescent moon, and its wings have a second face, so you never know which way
  it is looking.
- **Look:** Silhouette = a small round owl with a facial disc shaped as a thick crescent (one side bright, one
  side dark) and two broad moth wings with big false-eye spots. Key shapes: crescent face, oval moth wings with
  eye spots, two feathered antenna tufts. Palette: lilac body, pale green wings, cream belly, moon-yellow glow on
  the bright side of the crescent.
- **Fights / helps:** Moon Swap: it trades places with its decoy, and the decoy is the wing-spot "face" so the
  enemy aims at the wrong one. Moonlift: a soft updraft off the wing beat. Trickster.
- **Personality:** Airy, teasing, dramatic; strikes a pose after every swap.
- **Inspiration:** Noctowl / Rowlet (owl Pokemon). Different: moth wings with false faces, a crescent-shaped
  face, lilac and green not brown.
- **Edit:** reshape the facial disc mesh to a crescent and repaint the wing texture with eye spots; no new parts.
- **Score v2:** 4 3 4 4 4 3 = **22**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral perched-standing pose, flat even light, plain pale grey background, whole body in frame). A small round lilac owl whose facial disc is shaped like a thick crescent moon, the right side bright moon-yellow and the left side dark shadow, two feathered antenna tufts, broad pale green luna-moth wings folded at the sides each with one large false eye spot, cream belly, short feathered tail visible in side and back views, small talons. Palette: lilac, pale green, cream, moon yellow. Stylised hand-painted game art, chunky readable shapes. No real moth body, no thin antennae, no second head, no scenery, no text.
```

### Echolop (`zapple`) UPGRADE 18 -> 26
- **Was:** Hare + Bat. Score 3 2 3 4 4 2 = 18 (bat-eared hare, no object).
- **Mix v2:** Hare + bat wings + brass gramophone horns for ears.
- **Hook:** A hare with gramophone horns for ears; it shouts into them and the sound comes back as lightning.
- **Look:** Silhouette = a long-legged hare with two flared brass horns rising where the ears are and small bat
  wings on the shoulders. Key shapes: two flared horn-bells, a lean hare body with big back feet, folded purple
  bat wings. Palette: dusk blue fur, pale blue belly, tarnished brass horns, cyan glow inside the horn bells.
- **Fights / helps:** Echo Chain: a shout out of the horns that jumps target to target. Echolocate: the horns are
  its sonar dishes. Skirmisher.
- **Personality:** Hyper, easily distracted, loves winning, loudest Boki on the island.
- **Inspiration:** Loudred / Exploud (speaker Pokemon). Different: a hare body with bat wings, brass horns as
  ears not speaker holes, blue and brass palette.
- **Edit:** swap the ear meshes for horn meshes on the ear sockets; wings and body stay.
- **Score v2:** 4 5 4 5 4 4 = **26**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A lean dusk-blue hare with long back legs and big feet whose two ears are tarnished brass gramophone horns, flared bells opening upward and slightly outward, small folded purple bat wings on the shoulders, pale blue belly, short tufted tail visible in side and back views, soft cyan glow inside the horn bells. Palette: dusk blue, pale blue, tarnished brass, cyan glow. Stylised hand-painted game art, chunky readable shapes. No fur ears, no record player body, no thin wires, no text, no scenery.
```

### Hivara (`hivara`) UPGRADE 19 -> 23
- **Was:** Honeybee + Praying mantis + wax crown + a halo of tiny bees. Score 3 3 3 4 3 3 = 19 (the floating bee
  halo is unbuildable; bee queen with crown is close to Vespiquen).
- **Mix v2:** Honeybee + mantis + a cloak of sleeping bees as wax armour.
- **Hook:** A mantis-bee queen whose armour is made of sleeping bees; when it fights, the armour wakes up and
  flies off.
- **Look:** Silhouette = an upright mantis body with folded raptorial blades and a broad back cloak of overlapping
  bee-shaped wax scales (solid), a small wax crown. Key shapes: the scale cloak (rounded shingles), folded blades,
  striped abdomen. Palette: gold, black stripes, pale wax yellow, amber glow at the crown.
- **Fights / helps:** Hive Swarm: scales peel off as the swarm (VFX spawns from the cloak). Spore Patch: pollen
  dust shaken off the cloak. Bruiser.
- **Personality:** Busy and bossy; counts its bees every night.
- **Inspiration:** Vespiquen (bee queen Pokemon). Different: mantis raptorial blades and posture, a bee-scale
  cloak instead of a hive skirt, no face on the abdomen.
- **Edit:** delete the floating bee halo; add a scale-cloak mesh over the thorax and wing cases.
- **Score v2:** 4 4 4 4 4 3 = **23**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose on six legs, flat even light, plain pale grey background, whole body in frame). A small gold and black mantis-bee queen: an upright mantis thorax with two folded raptorial blade forelegs, a striped bee abdomen, a small pale wax crown, and a broad cloak over the back made of overlapping rounded wax scales each shaped like a sleeping bee, all one solid layer, four walking legs, two short antennae, soft amber glow at the crown. Palette: gold, black, pale wax yellow, amber. Stylised hand-painted game art, chunky readable shapes. No flying bees around it, no separate floating parts, no skirt, no human face, no text, no scenery.
```

### Zephyrak (`zephyrak`) UPGRADE 18 -> 26
- **Was:** Moray eel + Swift, static wings. Score 3 2 3 4 4 2 = 18 (sky-serpent is the oldest trope in the book).
- **Mix v2:** Moray eel + fighting kite.
- **Hook:** A moray eel that is also a fighting kite: paper wings on bamboo spars and a tail of ribbon bows that
  crackles like a storm.
- **Look:** Silhouette = a long eel body with two taut diamond kite-wings framed by thick bamboo spars, and a
  ribbon-bow tail. Key shapes: diamond wings, bamboo spar cross, three fat ribbon bows down the tail. Palette:
  storm blue body, white kite paper with a red sun patch, bamboo tan, cyan static glow along the spars.
- **Fights / helps:** Gale Lance: it dives on the wind like a kite cutting a string. Storm Arc: static jumps from
  the spar tips. Skirmisher.
- **Personality:** Wild and quick; tugs on your sleeve like a kite on a string.
- **Inspiration:** Rayquaza / Stormcoil-type sky serpents. Different: paper kite wings on visible bamboo spars,
  ribbon-bow tail, small (shoulder-sized), white-red-blue palette.
- **Edit:** rebuild the wing meshes as kite panels on the existing wing sockets; add bow meshes to the last three
  spine bones.
- **Score v2:** 5 5 4 4 4 4 = **26**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral hovering S-curve pose above the ground line, flat even light, plain pale grey background, whole body in frame). A small storm-blue moray eel with a toothy grin and a long body, two taut diamond-shaped kite wings of white paper with a red circle patch stretched over thick tan bamboo spars, a cross spar visible behind each wing, the tail ending in three fat red ribbon bows spaced along it like a kite tail, faint cyan static along the spar tips. Palette: storm blue, white, red, bamboo tan, cyan. Stylised hand-painted game art, chunky readable shapes. No feathers, no string, no thin loose ribbon, no legs, no text, no scenery.
```

### Kindlewren (`kindlewren`) UPGRADE 17 -> 26
- **Was:** Wren + Ember coal (coal-tipped tail). Score 2 2 2 3 5 3 = 17 (a texture swap on a small brown bird).
- **Mix v2:** Wren + a lit match.
- **Hook:** A wren whose tail is a lit match; it strikes it on rocks and dives.
- **Look:** Silhouette = a round little wren with its tail cocked straight up as one fat matchstick with a burning
  red head. Key shapes: ball body, upright matchstick tail, stubby wings. Palette: warm brown, cream belly, pale
  matchwood, red match-head with orange flame glow.
- **Fights / helps:** Gale Lance: the strike-and-dive. Stinger Dash (Coal Dart later): a dash that leaves a burn.
  Skirmisher.
- **Personality:** Cheeky and impatient; always first in, sulks if it has to sit still.
- **Inspiration:** Charcadet (match-stick Pokemon), Fletchling. Different: a real bird body with the match as a
  single cocked tail, warm brown not armour-red.
- **Edit:** replace the tail fan with one matchstick mesh on the tail bone; recolour the tip.
- **Score v2:** 5 4 4 4 5 4 = **26**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A tiny round warm-brown wren with a cream belly and stubby wings whose tail is a single thick wooden matchstick cocked straight up, the match head red and lit with a small orange flame, the flame and stick fully visible in side and back views, thin dark legs with simple feet. Palette: warm brown, cream, pale matchwood, red, orange glow. Stylised hand-painted game art, chunky readable shapes. No feather tail, no smoke trail, no multiple matches, no text, no scenery.
```

### Rimeshrew (`rimeshrew`) UPGRADE 16 -> 24
- **Was:** Shrew + Hoarfrost (frost feathers). Score 2 2 2 2 5 3 = 16 (lowest of the 21; texture swap, and the
  swarm/storm abilities had no visual).
- **Mix v2:** Shrew + hoarfrost + pinecone.
- **Hook:** A shrew so frozen it looks like a pinecone, and it shakes off a snowstorm of ice needles.
- **Look:** Silhouette = a cone-shaped body of overlapping frosted scales (pinecone) with a long twitchy snout
  out the front and a thin tail out the back. Key shapes: pinecone body, long snout, tiny feet. Palette: frosted
  brown scales with white rime edges, pale blue-grey face, icy cyan glow between scales.
- **Fights / helps:** Hive Swarm: it shakes and a swarm of ice needles flies out of the cone. Storm Arc: the
  needles carry a static crack. Skirmisher.
- **Personality:** Frantic, hungry, fearless; squeaks at things thirty times its size.
- **Inspiration:** Pineco (pinecone Pokemon). Different: a mammal with a snout, legs and tail, the cone is its
  frozen fur not a bagworm case, frost palette.
- **Edit:** add a pinecone scale shell over the existing body mesh; keep head, legs, tail.
- **Score v2:** 4 4 4 3 5 4 = **24**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A tiny shrew whose body is shaped like a pinecone: overlapping frosted brown scales with white rime edges cover it from neck to rump, a long pale blue-grey twitchy snout and black bead eyes at the front, four tiny feet, a thin tail out the back visible in side and back views, faint icy cyan glow between the scales. Palette: frosted brown, white rime, pale blue-grey, cyan. Stylised hand-painted game art, chunky readable shapes. No feathers, no loose flying needles, no tree branch, no text, no scenery.
```

### Gloamshell (`gloamshell`) UPGRADE 18 -> 24
- **Was:** Garden snail + Smoked obsidian shell. Score 2 3 3 3 4 3 = 18 (a black snail).
- **Mix v2:** Garden snail + an ink bottle for a shell.
- **Hook:** A snail whose shell is a spilled ink bottle and whose slime is ink.
- **Look:** Silhouette = a squat snail body with a fat glass ink bottle (cork in) tipped on its back like a shell,
  dark ink pooling out of a crack. Key shapes: the squared bottle with a cork, the soft snail foot, two thick eye
  stalks. Palette: grey-violet body, black-violet ink, dark green bottle glass, cork tan, violet glow in the ink.
- **Fights / helps:** Puffcap Mines are ink blots that burst and blind. Spore Patch (Dusk Trail later): its ink
  trail slows and shows the footprints of anyone hiding. Controller.
- **Personality:** Slow, private, oddly smug; signs its name on things it passes.
- **Inspiration:** Inkay (squid), Magcargo (lava snail). Different: a land snail with a glass bottle shell, ink
  not lava or squid, green glass and violet.
- **Edit:** replace the spiral shell mesh with the bottle on the shell socket; thicken the eye stalks.
- **Score v2:** 4 4 4 4 4 4 = **24**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral resting pose, flat even light, plain pale grey background, whole body in frame). A squat grey-violet garden snail whose shell is a fat squared dark-green glass ink bottle with a tan cork, tipped on its back and cracked at one corner so a thick blob of black-violet ink pools over the shell edge, two thick eye stalks with round eyes, a soft foot with a short ink-dark slime trail under it, faint violet glow in the ink. Palette: grey-violet, black-violet, dark green glass, cork tan. Stylised hand-painted game art, chunky readable shapes. No spiral shell, no pen, no thin stalks, no text, no scenery.
```

### Nettlynx (`nettlynx`) UPGRADE 19 -> 26
- **Was:** Lynx kitten + Stinging nettle (leaf ear tufts). Score 2 3 3 3 5 3 = 19 (an olive-green cat is close to
  Sprigatito; nothing to grab onto).
- **Mix v2:** Lynx kitten + a ruff of nettle leaves + a burdock-burr tail.
- **Hook:** A lynx kitten in a nettle-leaf collar with a burr for a tail; it throws the burr and reels you in.
- **Look:** Silhouette = a stocky kitten with a wide jagged leaf ruff around the neck and a round spiky burr ball
  on a short tail. Key shapes: the ruff, the burr ball, big paws. Palette: ash-grey coat with dark spots, deep
  green nettle ruff, magenta-purple burr, lime glow on the nettle hairs.
- **Fights / helps:** Stinger Hook: the burr tail flicks out, hooks, pulls back. Stinger Dash: a pounce through
  its own nettle sting. Bruiser.
- **Personality:** Prickly and proud; affectionate on its own terms, bites first and purrs later.
- **Inspiration:** Sprigatito / Shinx (small cat Pokemon). Different: an ash-grey lynx with a plant ruff and a
  burr tail, no green body, no electricity.
- **Edit:** add the ruff mesh at the neck bone, swap the tail tip for a burr sphere, recolour the coat to ash.
- **Score v2:** 4 4 4 5 5 4 = **26**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A stocky ash-grey lynx kitten with dark spots, oversized paws and short ear tufts, wearing a wide ruff of jagged deep-green nettle leaves around its neck like a collar, its short tail ending in a round magenta-purple burdock burr ball covered in hooked spines, the burr clearly visible in side and back views, faint lime glow on the leaf edges. Palette: ash grey, deep green, magenta purple, lime. Stylised hand-painted game art, chunky readable shapes. No green fur, no long fluffy tail, no flowers, no text, no scenery.
```

### Lodestick (`lodestick`) UPGRADE 17 -> 25
- **Was:** Stick insect + Lodestone (iron filings). Score 3 3 2 3 2 4 = 17 (a thin line at 40 px; filings are
  particles).
- **Mix v2:** Stick insect + a horseshoe magnet + a compass needle head.
- **Hook:** A stick insect that is a horseshoe magnet with legs; its head is a compass needle and it always
  points at you.
- **Look:** Silhouette = a chunky U-shaped red-and-steel horseshoe magnet as the abdomen, a twig thorax, six
  thick knobbly twig legs, a flat lozenge compass-needle head. Key shapes: the U magnet, the needle head, knobby
  legs. Palette: red and steel-grey magnet, bark brown, violet glow at the magnet tips.
- **Fights / helps:** Moon Swap / Lodestar later: it pulls things to it. Moonlift: it repels itself upward off
  iron in the ground. Trickster.
- **Personality:** Still, patient, deadpan; plays dead when bored and sticks to your belt buckle.
- **Inspiration:** Magnemite (magnet Pokemon). Different: an insect with twig legs and a compass head, red U
  magnet as abdomen, no screws or eye-ball body.
- **Edit:** thicken all leg meshes to twig width; replace the abdomen with the U magnet; reshape the head.
- **Score v2:** 4 5 4 4 4 4 = **25**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose on six legs, flat even light, plain pale grey background, whole body in frame). A small stick insect whose abdomen is a chunky horseshoe magnet, red with steel-grey tips, pointing backward like a tail, a short bark-brown twig thorax, six thick knobbly twig legs, and a flat lozenge-shaped head like a compass needle, red on one end and white on the other, two short antennae, faint violet glow at the magnet tips. Palette: red, steel grey, bark brown, violet. Stylised hand-painted game art, chunky readable shapes. No thin legs, no loose iron filings, no screws, no text, no scenery.
```

### Marchleaf (`marchleaf`) UPGRADE 18 -> 24
- **Was:** Leafcutter ant + Leaf (sail) with three trailing ants. Score 3 3 3 3 3 3 = 18 (trailing ants are
  floating parts).
- **Mix v2:** Leafcutter ant + a leaf lashed to a twig pole as a regimental banner.
- **Hook:** A leafcutter ant marching under its own leaf flag.
- **Look:** Silhouette = a glossy ant with a twig flagpole held upright in its front legs and one big leaf tied
  to it as a banner, corners curling. Key shapes: the banner, the ant's three-part body, a knotted vine at the
  pole. Palette: red-brown ant, bright green leaf, twig tan, a lime glow at the leaf veins.
- **Fights / helps:** Hive Swarm: it raises the flag and the column comes. Spore Patch: leaf scraps it drops.
  Bruiser.
- **Personality:** Dutiful, stubborn, a born foreman; sulks when the plan changes.
- **Inspiration:** none direct. Durant (steel ant) is the nearest, which this is not.
- **Edit:** delete the trailing ants; replace the loose leaf with a leaf-on-pole mesh on the leaf socket.
- **Score v2:** 4 4 4 4 4 4 = **24**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A small glossy red-brown leafcutter ant with a round head, big mandibles, two bent antennae and six legs, holding a short tan twig flagpole upright in its two front legs, one large bright green leaf tied to the pole by a knotted vine so it hangs like a banner above its head, leaf and pole fully visible in side and back views, faint lime glow at the leaf veins. Palette: red-brown, bright green, twig tan, lime. Stylised hand-painted game art, chunky readable shapes. No other ants, no metal, no thin pole, no text, no scenery.
```

### Glomwort (`glomwort`) UPGRADE 17 -> 26
- **Was:** Slime mold + Puffball (yellow blob with three balls). Score 2 3 2 3 4 3 = 17 (a blob).
- **Mix v2:** Slime mold + a rusty garden watering can + puffballs.
- **Hook:** A yellow slime mold that lives in a rusty watering can; puffballs pop out of the spout.
- **Look:** Silhouette = a dented tin watering can tipped slightly, bright yellow slime oozing out of the top and
  through the spout rose, puffball mushrooms growing from the spout. Key shapes: the can body with handle, the
  long spout, the slime dome with two dot eyes. Palette: rust-orange tin, bright yellow slime with veining, cream
  puffballs, teal spore glow.
- **Fights / helps:** Puffcap Mines: puffballs it lobs from the spout. Spore Patch (Puffball Net later): spore
  dust it waters onto the ground, rooting whoever steps in. Controller.
- **Personality:** Curious about everything, remembers every path; slowly fills your pack.
- **Inspiration:** Polteageist (teapot Pokemon) is the obvious neighbour. Different: a living yellow slime mold
  in a garden watering can (not a ghost, not fine china), spore and plant theme, rust and yellow palette.
- **Edit:** add the can mesh around the blob core; puffball sockets move to the spout rose.
- **Score v2:** 5 5 4 4 4 4 = **26**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral resting pose, flat even light, plain pale grey background, whole body in frame). A dented rust-orange tin garden watering can with a top handle and a long spout, bright yellow slime mold oozing out of the open top in a soft dome with two black dot eyes and vein-like branching edges, more yellow slime dripping from the spout rose where three cream puffball mushrooms grow, faint teal spore glow, the spout clearly visible in side and back views. Palette: rust orange, bright yellow, cream, teal. Stylised hand-painted game art, chunky readable shapes. No teapot, no ghost face, no purple, no water, no text, no scenery.
```

---

# Part B: the 29 without models, redesigned

Each keeps `id`, size, body and rig, theme, abilities, merge stub, rarity, biome and big-Boki role. The "Was" line
is the old mix for reference.

## Small

### Bubblisk (`opalisk`) REDESIGNED 27/30
- **Was:** Basilisk lizard + Opal. **Fixed data:** prism, small, biped BIPED, trickster, Moon Swap (E) +
  Refraction (auto), merge Eclipse, uncommon, Greenreach.
- **Mix:** Basilisk lizard + soap bubble + opal.
- **Hook:** A lizard that blows a soap-bubble copy of itself and runs while you pop the bubble.
- **Look:** Silhouette = a slim upright running lizard with a tall head crest and a thick ring (a bubble wand) on
  the end of its tail; opal scales. Key shapes: the tail ring, the head crest fan, long back legs. Palette: milky
  opal white with pink and green flash, a soap-film rainbow sheen, brass tail ring.
- **Fights / helps:** Moon Swap: it blows a bubble through the tail ring that forms its double, then swaps
  places with it. Refraction: the soap film throws rainbow sparks. Trickster.
- **Personality:** A show-off that startles easily; runs first, poses later.
- **Inspiration:** none direct. Not a Lotad or Cradily.
- **Score:** 5 5 4 5 4 4 = **27**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose on two legs with a balancing tail, flat even light, plain pale grey background, whole body in frame). A slim small lizard standing upright on long back legs with small front arms, a tall rounded head crest fan, milky white opal scales with soft pink and green flashes, a long tail that ends in a thick brass ring like a bubble wand, the ring fully visible in side and back views, a faint rainbow soap-film sheen on the crest. Palette: opal white, pink, green, brass. Stylised hand-painted game art, chunky readable shapes. No floating bubbles, no mirror, no wings, no text, no scenery.
```

## Medium

### Anvilbrock (`kilnbadger`) REDESIGNED 28/30
- **Was:** Honey badger + Kiln brick. **Fixed data:** ember, medium, quadruped QUAD, tank, Gravity Slam (E) +
  Mass Guard (auto), merge Heavy Star, uncommon, Emberfall.
- **Mix:** Honey badger + blacksmith's anvil.
- **Hook:** A honey badger with a red-hot anvil for a back; it headbutts you and the anvil rings.
- **Look:** Silhouette = a low broad badger with an anvil fused to its back, horn end forward over the shoulders,
  heel end over the rump. Key shapes: the anvil (horn, face, heel), the badger's white crown stripe, short thick
  legs. Palette: black fur, white crown stripe, dark iron, orange heat glow in the anvil face.
- **Fights / helps:** Gravity Slam: it rears and drops the anvil. Mass Guard: nothing dents an anvil. Tank.
- **Personality:** Fearless and grumpy; picks fights it cannot win and wins them.
- **Inspiration:** none direct (the honey badger meme). Not a Steelix.
- **Score:** 5 5 4 5 5 4 = **28**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A low broad honey badger, black fur with a wide white stripe over the crown and back of the head, small ears, thick legs with big claws, a dark iron blacksmith's anvil fused onto its back with the pointed horn forward over the shoulders and the square heel over the rump, the anvil face glowing dull orange with heat, short tail visible in side and back views. Palette: black, white, dark iron, orange glow. Stylised hand-painted game art, chunky readable shapes. No hammer, no bricks, no flames, no text, no scenery.
```

### Skateron (`hoarheron`) REDESIGNED 25/30
- **Was:** Grey heron + Icicle. **Fixed data:** frost, medium, winged WING, controller, Gale Lance (E) + Spore
  Patch (auto), merge Stormwing, uncommon, Frostreach.
- **Mix:** Grey heron + ice skates + icicle.
- **Hook:** A heron on ice skates with an ice-pick beak; it glides in, stabs, glides out.
- **Look:** Silhouette = a tall thin heron with a long neck, both feet ending in thick skate blades, a long
  straight pale-blue ice beak, frost plumes swept back. Key shapes: the S-neck, the two skate blades, the folded
  wing wedge. Palette: slate grey, white chest, pale ice blue, a cold cyan glow at the blade edges.
- **Fights / helps:** Gale Lance (Ice Spear later): a gliding lunge that pierces. Spore Patch: ice chips scraped
  off by the skates that slow whoever crosses them. Controller.
- **Personality:** Patient, severe, says little; approves of you only when you stand still.
- **Inspiration:** none direct.
- **Score:** 5 4 4 4 4 4 = **25**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A tall slate-grey heron with a white chest and a long S-curved neck, a straight long dagger beak of pale blue ice, swept-back frost plumes on the head, folded wings forming a wedge, and both long legs ending in thick ice-skate blades with sturdy boot-like feet, blades touching the ground line, short tail visible in side and back views, cold cyan glow at the blade edges. Palette: slate grey, white, pale ice blue, cyan. Stylised hand-painted game art, chunky readable shapes. No one-leg pose, no thin blades, no fish, no text, no scenery.
```

### Barokat (`sentrikat`) REDESIGNED 25/30
- **Was:** Meerkat + Copper weathervane. **Fixed data:** storm, medium, biped BIPED, support, Echo Chain (E) +
  Echolocate (auto), merge Resonance, common, Stormcrest.
- **Mix:** Meerkat + a brass barometer set in its chest + a storm cloud ruff.
- **Hook:** A meerkat with a barometer in its belly; when the needle spins, lightning is coming and so is the
  enemy.
- **Look:** Silhouette = an upright meerkat with a big round brass dial on its chest and a ragged grey cloud ruff
  around the shoulders, stiff tail as a tripod. Key shapes: the round dial, the cloud ruff, the tall thin stance.
  Palette: sandy fur, dark eye patches, brass dial with a white face, storm grey ruff, yellow glow on the needle.
- **Fights / helps:** Echolocate (Storm Warning later): the needle swings and reveals everything in range. Echo
  Chain: static from the ruff jumps between targets. Support.
- **Personality:** Alert and bossy; cannot relax unless it is the one keeping watch.
- **Inspiration:** Watchog (meerkat Pokemon). Different: a brass instrument in the chest and a cloud ruff,
  storm theme, sandy palette not brown-and-yellow stripes.
- **Score:** 4 4 4 4 5 4 = **25**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral upright standing pose on two legs with the stiff tail touching the ground as a third support, flat even light, plain pale grey background, whole body in frame). A sandy meerkat standing tall with dark eye patches and small ears, a large round brass barometer dial set into its chest with a white face and a single yellow-glowing needle, a ragged storm-grey cloud ruff around its shoulders like a collar, small hands at its sides, tail visible in side and back views. Palette: sandy tan, brass, white, storm grey, yellow. Stylised hand-painted game art, chunky readable shapes. No weathervane, no clock numbers, no lightning bolts, no text, no scenery.
```

### Rampartoad (`basaltoad`) REDESIGNED 28/30
- **Was:** Cane toad + Basalt columns. **Fixed data:** stone, medium, quadruped QUAD, tank, Boulder Heave (E) +
  Mass Guard (auto), merge Cairn Colossus, common, Greenreach.
- **Mix:** Cane toad + castle rampart.
- **Hook:** A toad with a castle wall on its back; sit behind it and nothing gets through, and it pulls stones
  out of itself to throw.
- **Look:** Silhouette = a wide squat toad whose back is a curved stone wall with crenellations (battlements)
  along the top. Key shapes: the crenellated wall, the wide flat toad head, fat legs. Palette: slate grey stone,
  pale mortar, moss green patches, amber eyes.
- **Fights / helps:** Boulder Heave: it pulls a block out of its wall and lobs it. Mass Guard (Column Rise
  later): it hunkers down and the wall takes the shots. Tank.
- **Personality:** Placid, heavy, a creature of habit; croaks once, deeply, when it disapproves.
- **Inspiration:** Seismitoad / Torterra (back-landscape). Different: built masonry with battlements, not rock
  or trees, grey and moss palette.
- **Score:** 5 5 4 5 5 4 = **28**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral squatting pose, flat even light, plain pale grey background, whole body in frame). A wide squat slate-grey toad with a broad flat head, big amber eyes and fat warty legs, whose back is a curved stone castle wall built of grey blocks with pale mortar lines and a row of square crenellations along the top ridge, small patches of moss green on the stones, a short toad rump visible in side and back views. Palette: slate grey, pale mortar, moss green, amber. Stylised hand-painted game art, chunky readable shapes. No towers, no flags, no blue skin, no text, no scenery.
```

### Terrasloth (`orchisloth`) REDESIGNED 25/30
- **Was:** Three-toed sloth + Orchid. **Fixed data:** bloom, medium, biped BIPED, support, Prism Wall (E) +
  Refraction (auto), merge Prism Shell, uncommon, Bloomwild.
- **Mix:** Three-toed sloth + a glass greenhouse on its back + orchids inside.
- **Hook:** A sloth carrying a little glass greenhouse on its back with orchids inside; it opens the glass as a
  wall and the mist heals you.
- **Look:** Silhouette = a shaggy hunched sloth with a small gabled glass-and-brass greenhouse strapped to its
  back, pink orchids visible through the panes. Key shapes: the gabled glass house, long hooked arms, round
  sleepy head. Palette: tan fur, brass frame, pale green glass, pink orchids.
- **Fights / helps:** Prism Wall: it swings a glass pane off the greenhouse into a shield. Refraction (Orchid
  Mist later): light through the panes and warm mist that heals. Support.
- **Personality:** Gentle and dreamy; waters its orchids mid-fight.
- **Inspiration:** Slakoth (sloth Pokemon). Different: a built greenhouse with brass and glass, bloom and prism
  theme, upright biped carrying posture.
- **Score:** 4 5 4 4 4 4 = **25**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral hunched standing pose on two legs with long arms hanging, flat even light, plain pale grey background, whole body in frame). A shaggy tan three-toed sloth with a round sleepy face, dark eye markings, long hooked arms, carrying a small gabled greenhouse on its back made of a brass frame and pale green glass panes with pink orchids and moss visible inside, the greenhouse fully visible in side and back views, short stub tail. Palette: tan, brass, pale green glass, pink. Stylised hand-painted game art, chunky readable shapes. No tree branch, no flowers growing from fur, no thin glass edges, no text, no scenery.
```

### Zippelith (`caecilith`) REDESIGNED 29/30
- **Was:** Caecilian + Obsidian. **Fixed data:** shadow, medium, serpent SERPENT, trickster, Moon Swap (E) +
  Echolocate (auto), merge Eclipse, uncommon, Gloomheart.
- **Mix:** Caecilian + a giant zipper + obsidian.
- **Hook:** A worm that unzips the ground: it dives into a seam, zips it shut behind it, and comes up somewhere
  else.
- **Look:** Silhouette = a thick ringed legless body with a row of chunky zipper teeth along the whole back and
  a big flat zipper-pull tag as the tail tip. Key shapes: the tooth ridge, the pull tag, the blunt rounded head.
  Palette: glossy black obsidian, gunmetal zipper teeth, violet glow in the seam between teeth.
- **Fights / helps:** Moon Swap (Underpass later): it unzips a seam, vanishes, swaps with its shadow. Echolocate:
  it feels footsteps through the ground. Trickster.
- **Personality:** Secretive and sly; loves surprises, appears where you least expect it, grinning.
- **Inspiration:** none direct; the "object creature" spirit of Cassette Beasts.
- **Score:** 5 5 4 5 5 5 = **29**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral low S-curve resting pose on the ground line, flat even light, plain pale grey background, whole body in frame). A thick glossy black legless worm with a blunt rounded head, tiny eyes and a wide faint grin, smooth ringed segments, a single row of chunky gunmetal zipper teeth running along its back from head to tail, the tail ending in a large flat zipper-pull tag, violet glow leaking from the seam between the teeth, whole body including the tag visible in side and back views. Palette: glossy black, gunmetal, violet. Stylised hand-painted game art, chunky readable shapes. No legs, no fabric, no second zipper, no text, no scenery.
```

### Pipewurm (`velvorm`) REDESIGNED 27/30
- **Was:** Velvet worm + Amethyst. **Fixed data:** venom, medium, serpent SERPENT (leg nubs procedural),
  controller, Hive Swarm (E) + Spore Patch (auto), merge Hive Crown, uncommon, Bloomwild.
- **Mix:** Velvet worm + piping bag and icing nozzles + crushed velvet.
- **Hook:** A velvet-cake worm with icing nozzles for a face; it pipes sticky poison icing that glues your feet
  down.
- **Look:** Silhouette = a long soft plush worm with many stubby leg nubs, a bulbous pleated piping-bag head
  with two star nozzles where the slime glands are. Key shapes: the pleated head bulb, two cone nozzles, the
  segmented soft body. Palette: deep violet velvet, pale lilac piped-icing ridges along the back, tin nozzles, a
  toxic green glow at the nozzle tips.
- **Fights / helps:** Hive Swarm (Thread Spray later): a spray of icing threads that root and poison. Spore
  Patch: sticky drips it leaves behind. Controller.
- **Personality:** Looks sweet, hunts like a cat; loves being stroked, hates being ignored.
- **Inspiration:** Alcremie / Slurpuff (cream Pokemon). Different: a worm body with nozzle face, poison theme
  and violet-green palette, no human-like face.
- **Score:** 4 5 4 5 4 5 = **27**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral low crawling pose on the ground line, flat even light, plain pale grey background, whole body in frame). A long soft deep-violet velvet worm on many short stubby leg nubs, a bulbous pleated head shaped like a cloth piping bag with two tin star-tip icing nozzles at the front like a double snout and two small eyes above them, pale lilac piped-icing ridges running in neat swirls along its back, a tapered tail visible in side and back views, faint toxic green glow at the nozzle tips. Palette: deep violet, pale lilac, tin grey, toxic green. Stylised hand-painted game art, chunky readable shapes. No cake slices, no cherries, no sprinkles floating, no legs longer than nubs, no text, no scenery.
```

### Gongibbon (`gibbelle`) REDESIGNED 28/30
- **Was:** Gibbon + Bellflower. **Fixed data:** echo, medium, biped BIPED, controller, Echo Chain (E) + Echolocate
  (auto), merge Resonance, uncommon, Greenreach.
- **Mix:** Gibbon + bronze temple bell.
- **Hook:** A gibbon whose belly is a temple bell; it swings by its arms and clangs itself to stun everyone.
- **Look:** Silhouette = very long arms over a bell-shaped bronze torso with the legs hanging out the bell mouth
  like a clapper, a small round grey-furred head on top. Key shapes: the bell torso, the two long arms, the small
  head. Palette: lilac-grey fur, aged bronze, dark green patina lines, a warm gold glow at the bell rim.
- **Fights / helps:** Echo Chain (Bell Peal later): it strikes its own chest and the ring jumps target to target,
  stunning. Echolocate: the hum tells it where everyone is. Controller.
- **Personality:** Loud, joyful, a show-off; sings when happy and louder when scared.
- **Inspiration:** Bronzong (bell Pokemon). Different: a living ape with fur, head, arms and legs; the bell is
  only the torso, no face on the bell.
- **Score:** 5 5 5 5 4 4 = **28**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral upright standing pose with very long arms reaching down to the ground, flat even light, plain pale grey background, whole body in frame). A gibbon with lilac-grey fur, a small round head with a pale face and big eyes, extremely long arms and hands, whose torso is a bronze temple bell with aged green patina lines and a thick rim, its short furry legs hanging out of the bell mouth, a small bell-rope tassel tail visible in side and back views, warm gold glow at the rim. Palette: lilac grey, aged bronze, patina green, gold. Stylised hand-painted game art, chunky readable shapes. No face on the bell, no separate hanging clapper, no flowers, no text, no scenery.
```

### Anchorbill (`casquebill`) REDESIGNED 27/30
- **Was:** Hornbill + Iron meteorite. **Fixed data:** gravity, medium, winged WING, controller, Gravity Slam (E) +
  Echolocate (auto), merge Heavy Star, rare, Gloomheart.
- **Mix:** Hornbill + ship's anchor + chain.
- **Hook:** A hornbill whose casque is a ship's anchor; it drops out of the sky like one and drags everything to
  it.
- **Look:** Silhouette = a heavy black-and-cream hornbill with a big curved bill and a rusted iron anchor as the
  casque on top, flukes pointing back over the head, a short chain tail. Key shapes: the anchor casque, the long
  bill, broad folded wings. Palette: black plumage, cream chest, rust iron, violet glow in the anchor ring.
- **Fights / helps:** Gravity Slam (Starfall later): it dives and lands anchor-first, pulling foes in and
  stunning. Echolocate: bill clacks. Controller.
- **Personality:** Dignified and slow to trust; clacks its bill when it disagrees.
- **Inspiration:** Dhelmise (anchor Pokemon), Toucannon. Different: a living bird body, the anchor is a crest
  not the body, no seaweed, black-cream-rust palette.
- **Score:** 5 5 4 5 4 4 = **27**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A heavy black hornbill with a cream chest and a large curved pale bill, on top of the bill and head a rusted iron ship's anchor fused as a casque, its two flukes curving back over the head and its ring at the front, broad folded black wings, thick legs, a short tail of a few fat iron chain links visible in side and back views, faint violet glow in the anchor ring. Palette: black, cream, rust iron, violet. Stylised hand-painted game art, chunky readable shapes. No rope, no long dangling chain, no toucan colours, no text, no scenery.
```

### Mirrolin (`nacrolin`) REDESIGNED 28/30
- **Was:** Pangolin + Mother-of-pearl. **Fixed data:** prism, medium, quadruped QUAD, tank, Prism Wall (E) +
  Refraction (auto), merge Prism Shell, rare, Greenreach.
- **Mix:** Pangolin + mirror-mosaic ball (a disco ball).
- **Hook:** A pangolin covered in mirror tiles; curl it up and it is a disco ball that bounces every shot back.
- **Look:** Silhouette = a pangolin with a small pointed head and long tail, every scale a square mirror tile, so
  curled it is a sphere. Key shapes: the tiled dome back, the long tiled tail, tiny head. Palette: silver mirror
  tiles with soft rainbow reflections, dusty pink skin on face and belly, cyan sheen.
- **Fights / helps:** Prism Wall: it curls into the ball in front of you. Refraction (Pearl Curl later): shots
  bounce off the tiles. Tank.
- **Personality:** Timid but stubborn; curls up when spoken to sharply, unrolls for snacks.
- **Inspiration:** Sandslash (curling pangolin-type). Different: square mirror tiles not spikes, prism and
  reflect gameplay, silver and pink.
- **Score:** 5 5 4 5 5 4 = **28**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A pangolin with a small pointed head, dusty pink skin on the face, belly and legs, whose overlapping scales are all square silver mirror tiles reflecting soft rainbow glints like a disco ball, covering its back, head crown and long thick tail, the tail fully visible in side and back views, short strong legs with claws. Palette: silver mirror, dusty pink, soft rainbow, cyan sheen. Stylised hand-painted game art, chunky readable shapes. No spikes, no pearl rounded scales, no lights beaming out, no text, no scenery.
```

### Lanterloris (`moonloris`) REDESIGNED 27/30
- **Was:** Slow loris + Moonflower. **Fixed data:** lunar, medium, biped BIPED, support, Moon Swap (E) + Moonlift
  (auto), merge Eclipse, uncommon, Gloomheart.
- **Mix:** Slow loris + a round paper lantern belly + moonflowers.
- **Hook:** A slow loris that is a paper lantern: its belly glows, and when it is scared it floats up like a
  balloon.
- **Look:** Silhouette = a round-bellied loris whose torso is a ribbed paper lantern, big ringed eyes, little
  arms and legs, white moonflowers on the head. Key shapes: the ribbed lantern sphere, enormous eyes, flower cap.
  Palette: cream fur, warm pale yellow lantern paper, dark amber eye rings, white flowers, moon-yellow glow.
- **Fights / helps:** Moonlift: its lantern body lifts allies with a warm updraft. Moon Swap (Moonbloom later):
  the lantern flares and reveals, then it floats to its decoy's spot. Support.
- **Personality:** Soft-spoken, sleepy by day, wide awake at night; clings to you when frightened.
- **Inspiration:** Lampent / Chinchou (lamp Pokemon). Different: a furry mammal with a paper lantern torso not a
  metal lamp or fish, lunar flowers, cream and yellow.
- **Score:** 5 5 4 5 5 3 = **27**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose on two short legs, flat even light, plain pale grey background, whole body in frame). A small slow loris with cream fur, a round face with enormous amber eyes in dark rings, whose whole torso is a round ribbed paper lantern in warm pale yellow glowing softly from inside, short furry arms and legs sticking out of the lantern, a cap of white moonflowers on its head, a tiny stub tail visible in side and back views. Palette: cream, pale yellow, dark amber, white, moon-yellow glow. Stylised hand-painted game art, chunky readable shapes. No candle visible, no hanging string, no fire, no text, no scenery.
```

### Murmurling (`murmurling`) REDESIGNED 24/30
- **Was:** Starling + Flock (a ring of floating birds). **Fixed data:** swarm, medium, winged WING, skirmisher,
  Hive Swarm (E) + Echolocate (auto), merge Hive Crown, common, Greenreach.
- **Mix:** Starling + pan-pipes for tail feathers.
- **Hook:** A starling with pan-pipes for a tail; every note it plays flies off as another tiny bird.
- **Look:** Silhouette = a glossy starling whose tail is a fan of six hollow reed pipes of different lengths,
  bound with a leather strap. Key shapes: the pipe fan tail, a speckled round body, a sharp yellow beak. Palette:
  glossy black with green-purple sheen, white speckles, reed tan, a green glow at the pipe mouths.
- **Fights / helps:** Hive Swarm (Murmuration later): it plays, and the notes become a flock that chases. Echolocate:
  it copies every sound it hears. Skirmisher.
- **Personality:** Sociable, noisy, lonely in a second; mimics your footsteps.
- **Inspiration:** none direct (Chatot is a music parrot; this is a starling with an instrument tail).
- **Score:** 4 4 4 4 4 4 = **24**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A glossy black starling with a green and purple sheen and small white speckles, a sharp yellow beak, folded wings, whose tail is a fan of six hollow tan reed pipes of stepped lengths bound together with a dark leather strap like pan-pipes, the pipe tail fully visible in side and back views, faint green glow at the pipe openings. Palette: glossy black, green-purple sheen, reed tan, yellow. Stylised hand-painted game art, chunky readable shapes. No other birds, no flock, no thin pipes, no text, no scenery.
```

### Knotwyrm (`threadwyrm`) REDESIGNED 26/30
- **Was:** Slow worm + Mycelium threads. **Fixed data:** spore, medium, serpent SERPENT, controller, Puffcap Mines
  (E) + Spore Patch (auto), merge Sporewake, uncommon, Bloomwild.
- **Mix:** Slow worm + knotted hemp rope + mushroom knots.
- **Hook:** A rope snake with mushroom caps growing from its knots; lay it across a path and whoever steps over it
  gets rooted.
- **Look:** Silhouette = a long legless lizard whose body is twisted rope strands, tied in three fat overhand knots
  along its length, a brown mushroom cap sprouting from each knot, a smooth lizard head. Key shapes: the knots,
  the caps, the frayed-tassel tail. Palette: hemp tan, bronze head scales, brown mushroom caps, white-teal glow in
  the rope twists.
- **Fights / helps:** Spore Patch (Root Line later): it lies across the ground as a tripwire line. Puffcap Mines:
  the knot mushrooms pop. Controller.
- **Personality:** Quiet, thoughtful, an old soul; likes damp shade and long naps.
- **Inspiration:** none direct.
- **Score:** 4 4 4 5 5 4 = **26**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral gentle wave pose on the ground line, flat even light, plain pale grey background, whole body in frame). A long legless lizard with a smooth bronze-scaled head and small eyes whose body is made of twisted hemp rope strands, tied in three fat overhand knots spaced along its length, a round brown mushroom cap growing out of the top of each knot, the tail ending in a frayed rope tassel visible in side and back views, faint white-teal glow in the rope twists. Palette: hemp tan, bronze, brown, white-teal. Stylised hand-painted game art, chunky readable shapes. No legs, no loose threads floating, no needle, no text, no scenery.
```

### Lockatara (`tuatrune`) REDESIGNED 28/30
- **Was:** Tuatara + Rune-cut bronze. **Fixed data:** titan, medium, quadruped QUAD, tank, Boulder Heave (E) +
  Mass Guard (auto), merge Cairn Colossus, rare, Greenreach.
- **Mix:** Tuatara + iron padlock + key.
- **Hook:** A lizard with a padlock shackle for a crest and a keyhole for a third eye; its tail is the key.
- **Look:** Silhouette = a stocky spiny lizard with a big U-shaped iron shackle arching over its back from
  shoulders to hips, a keyhole-shaped third eye on the forehead, and a tail that ends in a flat key bit. Key
  shapes: the shackle arch, the key tail, the heavy head. Palette: olive scales, dark iron, old gold runes along
  the shackle, gold glow in the keyhole.
- **Fights / helps:** Mass Guard (Rune Ward later): it locks a shield onto you with a click. Boulder Heave: it
  throws stone like a lock bolt. Tank.
- **Personality:** Ancient, calm, faintly amused; watches you through the keyhole when you are not looking.
- **Inspiration:** Klefki (key-ring Pokemon). Different: a living lizard body with scales and legs, one padlock
  shackle as a crest, olive and iron palette.
- **Score:** 5 5 4 5 5 4 = **28**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A stocky olive-green spiny lizard with a heavy head, a thick dark-iron padlock shackle arching over its back like a crest from shoulders to hips, a keyhole-shaped third eye glowing gold in the centre of its forehead, two normal eyes, old gold rune marks along the shackle, four sturdy legs, a tail ending in a flat iron key bit fully visible in side and back views. Palette: olive, dark iron, old gold, gold glow. Stylised hand-painted game art, chunky readable shapes. No loose keys, no chain, no wings, no text, no scenery.
```

## Large (companion, flyer, bulwark, packbeast, watchtower)

### Canvastross (`squalltross`) REDESIGNED 28/30
- **Was:** Albatross + Squall cloud. **Fixed data:** tempest, large flyer, winged WING-L (carry socket under the
  feet), skirmisher, Gale Lance (E) + Moonlift (auto), merge Stormwing, uncommon, Stormcrest.
- **Mix:** Albatross + patched ship sails and yardarms + storm.
- **Hook:** An albatross with patched ship sails for wings; grab the rigging under it and it carries you across
  the gap.
- **Look:** Silhouette = a huge long-winged seabird whose wings are canvas sails stretched on wooden yardarm
  spars, patched and stitched, with a short rope ladder and harness hanging under the belly. Key shapes: the two
  long sail wings with visible spars, the hooked pale beak, the hanging harness. Palette: white and weathered
  canvas, dark tar-brown spars, charcoal wing tips, pale gold beak, cyan storm glow on the spar ends.
- **Fights / helps:** Flyer: you hang from the harness for a carried glide or a hop over an abyss. Gale Lance:
  a wing-beat gust. Moonlift: the sails catch an updraft. Skirmisher.
- **Personality:** Easygoing, fearless, a wanderer; restless when it has not seen the sea.
- **Inspiration:** Ghibli flying machines (Laputa, Porco Rosso) and Skarmory. Different: a living bird with
  feathers on body and tail, the sails are its wings, canvas not steel.
- **Score:** 5 5 5 5 4 4 = **28**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose with wings half spread, flat even light, plain pale grey background, whole body in frame). A huge white albatross with a pale gold hooked beak and dark eye markings whose very long wings are patched off-white canvas sails stretched over dark tar-brown wooden yardarm spars, stitched patches and a few rope lashings, charcoal wing tips, a short thick rope harness with two wooden grab bars hanging under the belly between the big webbed feet, a wedge tail of white feathers visible in side and back views, faint cyan glow at the spar ends. Palette: white, weathered canvas, tar brown, charcoal, pale gold. Stylised hand-painted game art, chunky readable shapes. No ship hull, no mast, no thin loose ropes, no rider, no text, no scenery.
```

### Chuggamus (`scaldamus`) REDESIGNED 28/30
- **Was:** Hippopotamus + Volcanic mud. **Fixed data:** ember, large companion, quadruped QUAD-L, tank, Gravity
  Slam (E) + Mass Guard (auto), merge Heavy Star, rare, Emberfall.
- **Mix:** Hippopotamus + steam locomotive + volcanic mud.
- **Hook:** A hippo that is half steam engine: smokestack ears, a boiler belly, a cowcatcher jaw, and it charges
  like a runaway train.
- **Look:** Silhouette = a barrel hippo with a riveted iron boiler for a back and flanks, two short smokestacks
  where the ears are, a wedge cowcatcher grille on the lower jaw, a firebox door glowing on the chest. Key shapes:
  the boiler barrel, the twin stacks, the wedge jaw. Palette: black iron, plum-grey hide, brass rivets and bands,
  orange firebox glow and lava cracks.
- **Fights / helps:** Companion: walks beside you, body-blocks a chase like a train on a crossing. Gravity Slam:
  a stamping charge. Mass Guard (Mud Geyser later): steam and mud vent when hit. Tank.
- **Personality:** Lazy until crossed, then unstoppable; yawns steam at you to say it likes you.
- **Inspiration:** Hippowdon (sand hippo). Different: a built machine body with stacks and firebox, no sand, no
  gaping-mouth idle pose, black-iron and brass.
- **Score:** 5 5 5 5 4 4 = **28**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A huge barrel-bodied hippopotamus with plum-grey hide whose back and flanks are a riveted black iron steam boiler with brass bands, two short black smokestacks standing where its ears are, a wedge-shaped iron cowcatcher grille along its lower jaw, a small round firebox door glowing orange on its chest, thick stumpy legs, a short tail visible in side and back views, a few orange lava cracks on the hide. Palette: black iron, plum grey, brass, orange glow. Stylised hand-painted game art, chunky readable shapes. No wheels, no rails, no smoke clouds, no open mouth, no text, no scenery.
```

### Frigatee (`floenatee`) REDESIGNED 27/30
- **Was:** Manatee + Pack ice. **Fixed data:** frost, large packbeast, aquatic FIN-L (flippers, cargo bone),
  support, Prism Wall (E) + Refraction (auto), merge Prism Shell, rare, Frostreach.
- **Mix:** Manatee + an antique wooden icebox with brass drawers + pack ice.
- **Hook:** A manatee carrying an old icebox on its back; your loot stays cold in its drawers until someone
  kicks them open.
- **Look:** Silhouette = a rotund grey-blue sea cow hovering low with a boxy oak icebox strapped to its back,
  four brass-handled drawers facing the sides, frost rime on the box edges. Key shapes: the box, the round body,
  the wide tail paddle. Palette: grey-blue hide, pale oak, brass handles, white frost, cyan glow in the drawer
  gaps.
- **Fights / helps:** Packbeast: extra pack slots live in the drawers; a hard hit spills a drawer for rivals.
  Prism Wall (Ice Floe later): it slides an ice slab out of the box as a wall. Refraction: frost glints. Support.
- **Personality:** Kind and slow, everyone's friend; hums low songs you feel through your boots.
- **Inspiration:** Cetitan (walking whale). Different: a manatee with flippers lying low (no legs), a built
  wooden icebox on its back, grey-blue and oak.
- **Score:** 4 5 4 5 5 4 = **27**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral hovering pose just above the ground line, flat even light, plain pale grey background, whole body in frame). A rotund grey-blue manatee with a whiskered snout, small eyes, two paddle flippers and a wide round tail paddle visible in side and back views, carrying on its back a boxy pale oak antique icebox strapped on with two leather belts, four brass-handled drawers facing outward on the sides, white frost rime along the box edges and top, faint cyan glow in the drawer gaps. Palette: grey-blue, pale oak, brass, white frost, cyan. Stylised hand-painted game art, chunky readable shapes. No legs, no water, no open drawers, no crates, no text, no scenery.
```

### Buckleron (`limpetor`) REDESIGNED 27/30
- **Was:** Limpet + Granite tor. **Fixed data:** stone, large bulwark, blob BLOB-L, tank, Boulder Heave (E) +
  Mass Guard (auto), merge Cairn Colossus, rare, Greenreach.
- **Mix:** Giant limpet + a riveted iron round shield + lichen stone.
- **Hook:** A giant limpet whose shell is a riveted iron shield; it clamps to the ground and the whole squad
  shoots from behind it.
- **Look:** Silhouette = a wide low dome shell with a central boss and a ring of big rivets, lichen and stone
  crust on top, a thick muscular foot and two eye stalks under the rim. Key shapes: the domed shield with boss,
  the rivet ring, the stalks. Palette: dark iron, rust, grey-green lichen, amber glow at the boss.
- **Fights / helps:** Bulwark: plants itself as cover and soaks shots until it cracks. Mass Guard (Clamp Down
  later): clamps, cannot be moved, slows foes around it. Boulder Heave: it flicks a stone off its crust. Tank.
- **Personality:** Stubborn as rock and proud of it; grudgingly fond of whoever hides behind it.
- **Inspiration:** Shieldon / Bastiodon (shield dinos). Different: a mollusc with a foot and eye stalks, a single
  round domed shield, no legs or face plate.
- **Score:** 4 5 4 5 5 4 = **27**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral resting pose on the ground line, flat even light, plain pale grey background, whole body in frame). A giant limpet whose cone-shaped shell is a wide low domed dark-iron round shield with a raised central boss and a ring of large rivets near the rim, patches of grey-green lichen and rough stone crust on the iron, under the rim a thick dark muscular foot and two short stout eye stalks with round eyes at the front, faint amber glow at the boss. Palette: dark iron, rust, grey-green lichen, amber. Stylised hand-painted game art, chunky readable shapes. No arms, no legs, no straps, no granite spire, no text, no scenery.
```

### Umbrathere (`umbrathere`) REDESIGNED 28/30
- **Was:** Giant ground sloth + Night smoke. **Fixed data:** shadow, large companion, biped BIPED-L, tank,
  Gravity Slam (E) + Mass Guard (auto), merge Heavy Star, rare, Gloomheart.
- **Mix:** Giant ground sloth + a huge ragged black umbrella + night smoke.
- **Hook:** A giant ground sloth with a ragged umbrella for a back; it opens it and your whole squad disappears
  underneath.
- **Look:** Silhouette = a hunched massive biped on thick legs and tail with a big domed umbrella canopy growing
  from its spine, torn at the edges, ribs showing, hooked claws hanging. Key shapes: the canopy dome, the hooked
  arms, the heavy tail. Palette: charcoal fur, black canopy, grey wisps, violet glow at the canopy tips.
- **Fights / helps:** Companion: walks beside you, draws fire, body-blocks. Mass Guard (Smoke Shroud later): the
  canopy opens and allies under it are hidden. Gravity Slam: a two-armed claw slam. Tank.
- **Personality:** Brooding and protective; shelters smaller Boki under its arms when it rains.
- **Inspiration:** Totoro at the bus stop (Ghibli). Different: a hulking sloth with claws and a tail, the
  umbrella is part of its body, a shadow creature not a forest spirit.
- **Score:** 5 5 5 5 4 4 = **28**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral hunched standing pose on two thick legs and a heavy tail, flat even light, plain pale grey background, whole body in frame). A massive shaggy charcoal giant ground sloth standing hunched on its hind legs with long arms and big hooked claws hanging down, a large domed black umbrella canopy growing from its spine and covering its back and shoulders like a shell, ragged torn edges and visible rib lines on the canopy, a thick heavy tail visible in side and back views, small eyes, faint violet glow at the canopy rib tips. Palette: charcoal, black, grey, violet. Stylised hand-painted game art, chunky readable shapes. No umbrella handle, no held umbrella, no rain, no smoke clouds, no text, no scenery.
```

### Spirevark (`moundvark`) REDESIGNED 26/30
- **Was:** Aardvark + Termite mound. **Fixed data:** swarm, large watchtower, quadruped QUAD-L (lookout bone),
  tank, Hive Swarm (E) + Mass Guard (auto), merge Hive Crown, rare, Bloomwild.
- **Mix:** Aardvark + a termite-built clay cathedral spire with a belfry gallery.
- **Hook:** An aardvark with a termite cathedral on its back; climb the spire and shoot from the belfry.
- **Look:** Silhouette = a big pink-tan aardvark with long ears and snout, a tall ochre clay spire rising from
  its back with buttresses, a little arched belfry gallery near the top where a hunter stands, and glowing vents.
  Key shapes: the tall spire, the belfry opening, the long snout. Palette: pink-tan hide, ochre clay, dark vent
  holes, amber glow in the vents.
- **Fights / helps:** Watchtower: stands still and lets you climb to the belfry for height and sight. Hive Swarm
  (Mound Swarm later): termites pour from the vents. Mass Guard: the spire is thick clay. Tank.
- **Personality:** Easy-going and nosy; talks to its termites more than to you.
- **Inspiration:** Heatmor (anteater Pokemon). Different: aardvark ears and snout, a built clay spire on the
  back, swarm theme not fire.
- **Score:** 4 4 5 5 4 4 = **26**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A big pink-tan aardvark with long rabbit-like ears, a long tubular snout, a thick tapering tail visible in side and back views and strong digging legs, a tall ochre clay termite spire rising from the middle of its back shaped like a cathedral tower with rough buttresses, an arched open belfry gallery near the top with a flat standing ledge, small dark vent holes glowing amber. Palette: pink-tan, ochre, dark brown, amber. Stylised hand-painted game art, chunky readable shapes. No termites visible, no bell, no flag, no person, no text, no scenery.
```

### Effigeetle (`goliathite`) REDESIGNED 28/30
- **Was:** Goliath beetle + Marble. **Fixed data:** stone, large flyer, insect HEXA-L (harness bone), tank,
  Boulder Heave (E) + Mass Guard (auto), merge Cairn Colossus, uncommon, Greenreach.
- **Mix:** Goliath beetle + a marble statue's face as wing cases.
- **Hook:** A beetle the size of a cart whose shell is a marble statue's face; it splits open down the nose when
  it flies you across the gap.
- **Look:** Silhouette = a huge six-legged beetle whose two wing cases together form a serene carved marble face
  looking upward, the seam running down the nose; a stubby Y horn on the real head at the front, two hooked
  forelegs. Key shapes: the oval face shell, the Y horn, thick legs. Palette: white marble veined grey, black and
  white striped thorax, old gold on the horn, amber glow in the statue's closed eyes.
- **Fights / helps:** Flyer: the cases split and the amber wings carry you on the harness. Mass Guard: marble.
  Boulder Heave (Shell Ram later): a ramming dive. Tank.
- **Personality:** Earnest and hard-working, a gentle giant; polishes its face when it is proud of you.
- **Inspiration:** Heracross / Monster Hunter Seltas (big beetles). Different: statue-face wing cases, white
  marble, carry-flyer role; not blue, no single big horn.
- **Score:** 5 5 5 4 4 5 = **28**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose on six legs, flat even light, plain pale grey background, whole body in frame). A huge goliath beetle whose two closed wing cases together form a serene carved white marble face with closed eyes looking upward, the seam between the cases running straight down the nose and lips, grey marble veining, a black and white striped thorax, a stubby old-gold Y-shaped horn on the small real head at the front, six thick legs with two hooked forelegs, a short leather harness strap with a grab bar under the thorax, faint amber glow in the statue's eyelids. Palette: white marble, grey veining, black, old gold, amber. Stylised hand-painted game art, chunky readable shapes. No open wings, no human body, no second face on the head, no rider, no text, no scenery.
```

### Barrelmander (`spatewader`) REDESIGNED 27/30
- **Was:** Giant salamander + Flash flood. **Fixed data:** storm, large packbeast, aquatic FIN-L (limbs on,
  cargo bone), tank, Echo Chain (E) + Storm Arc (auto), merge Resonance, rare, Stormcrest.
- **Mix:** Giant salamander + a wooden rain barrel with a brass tap + storm cloud.
- **Hook:** A giant salamander with a rain barrel strapped on its back; your loot goes in the barrel, and a hard
  hit bursts it in a flash flood.
- **Look:** Silhouette = a long flat wrinkled salamander lying low on four stubby legs, a fat oak barrel lashed
  upright on its back with iron hoops and a brass tap, a small copper lightning rod on the lid. Key shapes: the
  barrel, the wide grinning flat head, the broad tail. Palette: brown-black skin with storm-blue spots, oak,
  black iron hoops, yellow static glow at the rod and tap.
- **Fights / helps:** Packbeast: loot slots in the barrel; hit hard enough and the barrel spills. Echo Chain:
  lightning hits the rod and chains off the brass. Storm Arc (Flash Flood later): the barrel bursts in a wave that
  pushes and slows. Tank.
- **Personality:** Lazy and good-natured, dozes in puddles; comes alive in a storm.
- **Inspiration:** Quagsire (grinning salamander). Different: a flat wrinkled giant salamander with frilled
  flanks, a built barrel and tap on its back, brown-black and oak.
- **Score:** 4 5 4 5 5 4 = **27**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral low standing pose on four stubby legs, flat even light, plain pale grey background, whole body in frame). A long flat wrinkled brown-black giant salamander with tiny bead eyes, a wide frog-like grin, frilly skin folds along the flanks, storm-blue spots and a broad flat tail visible in side and back views, a fat oak rain barrel with black iron hoops lashed upright on its back by two ropes, a brass tap low on the barrel's side and a short copper lightning rod on the lid, faint yellow static glow at the rod tip and tap. Palette: brown-black, storm blue, oak, black iron, brass. Stylised hand-painted game art, chunky readable shapes. No water pouring, no crates, no rain, no bathtub, no text, no scenery.
```

## Rideable (the 6 mounts; numbers unchanged)

### Bellowary (`cindowary`) REDESIGNED 28/30
- **Was:** Cassowary + Charcoal. **Fixed data:** ember, rideable mount (speed x1.25, jump x1.1, turn x0.75),
  biped BIPED-L (saddle bone behind the neck), bruiser, Gale Lance (E) + Stinger Dash (auto), merge Stormwing,
  rare, Emberfall.
- **Mix:** Cassowary + forge bellows for a casque + charcoal plumage.
- **Hook:** A cassowary whose head crest is a leather bellows; every stride pumps it and it blasts a gust of
  embers.
- **Look:** Silhouette = a tall flightless runner bird with a big wedge-shaped accordion bellows rising from its
  head, shaggy black plumage, thick clawed legs, a saddle behind the neck. Key shapes: the bellows wedge, the long
  neck, the heavy legs. Palette: ash-black feathers, brown leather bellows with brass nozzle, red and blue wattles
  kept as glossy enamel, orange ember glow at the nozzle.
- **Fights / helps:** Mount: fast travel, one rider. Gale Lance: the bellows fires a gust. Stinger Dash (Ash Kick
  later): a sprint and kick that scatters embers. Bruiser.
- **Personality:** Proud and territorial, loyal to its rider; wheezes the bellows as a warning before it charges.
- **Inspiration:** Blaziken (fighting bird). Different: a horizontal real cassowary body, bellows crest, no
  humanoid stance or fists.
- **Score:** 5 5 4 5 5 4 = **28**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose on two thick legs, flat even light, plain pale grey background, whole body in frame). A tall flightless cassowary-like bird with shaggy ash-black plumage, a long bare neck with glossy red and blue wattles, a large wedge-shaped brown leather forge bellows with brass corners and a brass nozzle rising from the top of its head in place of a casque, thick scaly legs with big claws, small folded wing stubs, a simple leather saddle sitting just behind the neck, a short tail tuft visible in side and back views, faint orange ember glow at the nozzle. Palette: ash black, brown leather, brass, red, blue, orange glow. Stylised hand-painted game art, chunky readable shapes. No rider, no fire blast, no bony casque, no text, no scenery.
```

### Prowyak (`glaciyak`) REDESIGNED 28/30
- **Was:** Yak + Glacier ice. **Fixed data:** frost, rideable mount (speed x1.1, jump x0.9, turn x0.65),
  quadruped QUAD-L (saddle bone), tank, Gravity Slam (E) + Mass Guard (auto), merge Heavy Star, uncommon,
  Frostreach.
- **Mix:** Yak + an icebreaker ship's riveted iron prow for horns + glacier ice coat.
- **Hook:** A yak with an icebreaker's iron prow for horns; it ploughs through the snow and anything standing in
  it.
- **Look:** Silhouette = a bulky yak with a long coat frozen into ice sheets, its two horns joined at the front
  into one riveted iron wedge like a ship's bow. Key shapes: the wedge prow, the heavy shaggy body, the broad
  saddle back. Palette: dark brown coat, white-blue ice sheeting, black riveted iron, cyan glow at the ice edge.
- **Fights / helps:** Mount: a slow, steady ride that pushes through snow. Gravity Slam (Glacier Charge later):
  a prow-first charge that shoves. Mass Guard: nothing dents the bow. Tank.
- **Personality:** Steady and warm-hearted; snorts frost when it laughs.
- **Inspiration:** Bouffalant / Mamoswine (big shaggy mounts). Different: an iron ship prow for horns and ice
  sheets in the coat, frost not normal/ground.
- **Score:** 4 5 5 5 5 4 = **28**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A bulky long-haired yak with a dark brown coat hanging to the ground, the lower coat frozen into white-blue ice sheets with icicle tips, its two horns sweeping forward and joining into one riveted black iron wedge like a ship's bow in front of the forehead, a heavy fringe over the eyes, a broad flat back with a simple leather saddle, a tufted tail visible in side and back views, faint cyan glow along the ice edges. Palette: dark brown, white-blue ice, black iron, cyan. Stylised hand-painted game art, chunky readable shapes. No rider, no ship hull, no snow, no curved separate horns, no text, no scenery.
```

### Boltstrich (`nimbostrich`) REDESIGNED 26/30
- **Was:** Ostrich + Thunderhead. **Fixed data:** storm, rideable mount (speed x1.3, jump x1.0, turn x0.7), biped
  BIPED-L (saddle bone), skirmisher, Echo Chain (E) + Storm Arc (auto), merge Resonance, rare, Stormcrest.
- **Mix:** Ostrich + thunderhead plumage + copper coil neck + rubber wellington boots.
- **Hook:** A thundercloud ostrich in rubber boots; ride it and your hair stands up.
- **Look:** Silhouette = a long-legged ostrich with a dark cumulus body, a long neck wound in copper wire like a
  coil, and big chunky rubber boots on its feet. Key shapes: the cloud body, the coil neck, the boots. Palette:
  storm grey plumage with yellow lightning flickers, copper neck, pale pink head, yellow rubber boots.
- **Fights / helps:** Mount: the fastest ride. Echo Chain: the coil discharges and jumps between targets. Storm
  Arc (Static Sprint later): a sprint that stuns whatever it passes; the boots insulate the rider. Skirmisher.
- **Personality:** Skittish and fast, afraid of nothing but boredom; races anything that moves.
- **Inspiration:** Dodrio (running bird). Different: one head, a cloud body with copper coil neck and boots,
  storm theme.
- **Score:** 5 4 4 4 5 4 = **26**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose on two long legs, flat even light, plain pale grey background, whole body in frame). A long-necked long-legged ostrich whose body plumage is a dark storm-grey cumulus cloud shape with small yellow lightning flickers in the feathers, a long pale pink neck wound in bright copper wire like a coil from shoulders to chin, a small pink head with big eyes, long bare pink legs ending in big chunky yellow rubber wellington boots, a simple leather saddle on the back, a fluffy grey tail visible in side and back views. Palette: storm grey, yellow, copper, pale pink. Stylised hand-painted game art, chunky readable shapes. No rider, no lightning bolts in the air, no rain, no second head, no text, no scenery.
```

### Soakybara (`lilybara`) REDESIGNED 27/30
- **Was:** Capybara + Water lily. **Fixed data:** bloom, rideable mount (speed x1.15, jump x0.9, turn x0.7),
  quadruped QUAD-L (saddle bone), support, Prism Wall (E) + Refraction (auto), merge Prism Shell, uncommon,
  Bloomwild.
- **Mix:** Capybara + a stone hot-spring pool on its back + floating flowers.
- **Hook:** A capybara with a hot spring on its back; you ride sitting in the bath, and the steam heals the squad.
- **Look:** Silhouette = a barrel-bodied capybara with a raised stone-rimmed pool set into its back, water inside
  with pink lily flowers and a little steam, a square blunt snout. Key shapes: the stone rim oval, the round body,
  the blunt head. Palette: warm brown fur, grey river stones, pale turquoise water, pink flowers, soft white steam
  glow.
- **Fights / helps:** Mount: you sit in the pool (the saddle bone is the pool floor). Prism Wall: a steam wall.
  Refraction (Lily Ring later): warm mist heals and cleanses allies around it. Support.
- **Personality:** Calm and sociable, the friend of everything; nothing ruffles it.
- **Inspiration:** the capybara-in-a-hot-spring photo meme; Temtem's Capyre. Different: a stone pool built into
  the back as a saddle, bloom healer not fire, brown and turquoise.
- **Score:** 5 5 4 5 5 3 = **27**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A big barrel-bodied warm-brown capybara with a square blunt snout, small ears and calm half-closed eyes, a shallow oval hot-spring pool built into its wide flat back with a rim of rounded grey river stones, pale turquoise water inside with three floating pink water-lily flowers and a little soft steam, short legs, a tiny stub tail visible in side and back views. Palette: warm brown, grey stone, pale turquoise, pink, white steam. Stylised hand-painted game art, chunky readable shapes. No rider, no bathtub, no fruit, no splashing water, no text, no scenery.
```

### Snuffapi (`duskapi`) REDESIGNED 27/30
- **Was:** Okapi + Dusk smoke. **Fixed data:** shadow, rideable mount (speed x1.25, jump x1.1, turn x0.85),
  quadruped QUAD-L (saddle bone), trickster, Moon Swap (E) + Echolocate (auto), merge Eclipse, rare, Gloomheart.
- **Mix:** Okapi + a brass candelabra for horns + dusk smoke.
- **Hook:** An okapi with a candelabra for horns; snuff the candles and it is gone, leaving a smoke copy behind.
- **Look:** Silhouette = a graceful okapi with a five-branched brass candelabra rising between its ears, stubby
  black candles with violet flames, white leg stripes fading into smoke. Key shapes: the candelabra crown, the
  long neck and ears, the striped legs. Palette: deep plum-brown body, white stripes, brass, violet flames.
- **Fights / helps:** Mount: nimble, hard to see. Moon Swap (Fade later): the flames snuff, it blinks and leaves
  a smoke decoy. Echolocate: big ears. Trickster.
- **Personality:** Shy and graceful, vanishes when strangers come; trusts one rider and only one.
- **Inspiration:** Litwick / Chandelure (candle Pokemon). Different: a living okapi with stripes and a saddle,
  the candelabra is a crest, violet flames on a plum animal.
- **Score:** 5 5 4 5 4 4 = **27**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A graceful okapi with a deep plum-brown body, a long neck, large rounded ears, white stripes on its upper legs that fade into soft dark smoke at the hooves, a five-branched brass candelabra rising from between its ears with five short thick black candles each lit with a small violet flame, a simple leather saddle on the back, a short tufted tail visible in side and back views. Palette: plum brown, white, brass, violet. Stylised hand-painted game art, chunky readable shapes. No rider, no melting wax drips, no thin candelabra arms, no antlers, no text, no scenery.
```

### Crofthorn (`heatherhorn`) REDESIGNED 28/30
- **Was:** Highland cow + Heather. **Fixed data:** bloom, rideable mount (speed x1.15, jump x0.95, turn x0.7),
  quadruped QUAD-L (saddle bone), tank, Boulder Heave (E) + Spore Patch (auto), merge Cairn Colossus, uncommon,
  Greenreach.
- **Mix:** Highland cow + a dry-stone walled cottage garden on its back + heather and bramble.
- **Hook:** A highland cow with a walled garden on its back; you ride sitting on the garden wall.
- **Look:** Silhouette = a huge shaggy ginger cow with wide horns and a fringe over its eyes, a low oval
  dry-stone wall ringing its back with purple heather and a bramble hedge inside. Key shapes: the horns, the
  stone-wall oval, the shaggy coat. Palette: ginger coat, grey stone, heather purple, bramble green.
- **Fights / helps:** Mount: the first mount most players meet. Boulder Heave: it shakes a wall stone loose and
  heaves it. Spore Patch (Heather Bed later): bramble roots whoever steps near, heather heals allies. Tank.
- **Personality:** Gentle and stubborn, grazes mid-fight; bellows proudly when you climb on.
- **Inspiration:** Torterra (garden on back), Miltank. Different: a shaggy cow with a built wall and a mount
  saddle, heather and bramble, ginger not green.
- **Score:** 4 5 5 5 5 4 = **28**.
- **Image prompt:**
```
Concept sheet with turnaround (front, side, back, 3/4 views in a row, same scale, neutral standing pose, flat even light, plain pale grey background, whole body in frame). A huge long-haired ginger highland cow with a shaggy fringe over its eyes, wide curved pale horns and a broad back, a low oval dry-stone wall of grey stones ringing its back like a raised garden bed, filled with purple heather and a low dark-green bramble hedge, a gap in the wall at the shoulders where a rider sits, a tufted tail visible in side and back views. Palette: ginger, grey stone, heather purple, bramble green. Stylised hand-painted game art, chunky readable shapes. No rider, no trees, no fence, no flowers taller than the wall, no text, no scenery.
```

---

# Part D: top 10, scoreboard, clashes, decisions

## Top 10 for the image session's batch 1

Chosen for excitement and for range (sizes, biomes, body types), not strictly by score.

| # | Name (`id`) | Size / role | Hook |
|---|---|---|---|
| 1 | Zippelith (`caecilith`) | medium serpent | A worm that unzips the ground and zips it shut behind it. |
| 2 | Gongibbon (`gibbelle`) | medium biped | A gibbon whose belly is a temple bell; it clangs itself to stun everyone. |
| 3 | Mirrolin (`nacrolin`) | medium quadruped | A pangolin in mirror tiles; curled up it is a disco ball that bounces shots. |
| 4 | Canvastross (`squalltross`) | large flyer | An albatross with patched ship sails for wings; hang from the rigging to cross the gap. |
| 5 | Effigeetle (`goliathite`) | large flyer | A cart-sized beetle whose shell is a marble statue's face that splits down the nose. |
| 6 | Lockatara (`tuatrune`) | medium quadruped | A lizard with a padlock shackle crest, a keyhole third eye and a key for a tail. |
| 7 | Bellowary (`cindowary`) | mount | A cassowary with a forge bellows for a crest; every stride blasts embers. |
| 8 | Umbrathere (`umbrathere`) | large companion | A giant ground sloth with a ragged umbrella back; the squad vanishes under it. |
| 9 | Chuggamus (`scaldamus`) | large companion | A hippo that is half steam engine and charges like a runaway train. |
| 10 | Soakybara (`lilybara`) | mount | A capybara with a hot spring on its back; you ride sitting in the bath. |

If batch 1 must be starters-first (the roster's old batch plan), ride the two starter upgrades along with these:
Mycroll's mushroom-lid (`burrlet`) and Prismander's chandelier gills (`puddlet`).

Next in line (batch 2 candidates): Anvilbrock, Rampartoad, Prowyak, Crofthorn, Anchorbill, Pipewurm,
Lanterloris, Bubblisk, Frigatee, Buckleron.

## Scoreboard: all 50

Status: kept = model exists, no change; upgrade = model exists, v2 twist (old -> new score); redesigned = no model,
new design. Totals are out of 30.

| # | id | Name (v2 name if changed) | Total /30 | Status |
|---|---|---|---|---|
| 1 | `burrlet` | Mycroll | 19 -> 25 | upgrade (toadstool lid) |
| 2 | `cindle` | Vespyx | 21 | kept |
| 3 | `puddlet` | Prismander | 19 -> 24 | upgrade (chandelier gills) |
| 4 | `wisplet` | Lunowl | 17 -> 22 | upgrade (crescent face, wing-spot faces) |
| 5 | `zapple` | Echolop | 18 -> 26 | upgrade (gramophone-horn ears) |
| 6 | `pebbit` | Gravadillo | 21 | kept |
| 7 | `cairnback` | Cairnback | 25 | kept |
| 8 | `hivara` | Hivara | 19 -> 23 | upgrade (bee-scale cloak, no bee halo) |
| 9 | `zephyrak` | Zephyrak | 18 -> 26 | upgrade (fighting-kite wings) |
| 10 | `kindlewren` | Kindlewren | 17 -> 26 | upgrade (lit-match tail) |
| 11 | `glintmole` | Glintmole | 21 | kept |
| 12 | `rimeshrew` | Rimeshrew | 16 -> 24 | upgrade (hoarfrost pinecone body) |
| 13 | `mossgrade` | Mossgrade | 22 | kept |
| 14 | `kestrike` | Kestrike | 20 | kept |
| 15 | `gloamshell` | Gloamshell | 18 -> 24 | upgrade (ink-bottle shell) |
| 16 | `nettlynx` | Nettlynx | 19 -> 26 | upgrade (nettle ruff, burr tail, ash coat) |
| 17 | `thrumbird` | Thrumbird | 22 | kept |
| 18 | `lodestick` | Lodestick | 17 -> 25 | upgrade (horseshoe magnet, compass head) |
| 19 | `selenfin` | Selenfin | 21 | kept |
| 20 | `marchleaf` | Marchleaf | 18 -> 24 | upgrade (leaf banner on a pole) |
| 21 | `opalisk` | Opalisk -> **Bubblisk** | 27 | redesigned |
| 22 | `glomwort` | Glomwort | 17 -> 26 | upgrade (watering-can home) |
| 23 | `kilnbadger` | Kilnbadger -> **Anvilbrock** | 28 | redesigned |
| 24 | `hoarheron` | Hoarheron -> **Skateron** | 25 | redesigned |
| 25 | `sentrikat` | Sentrikat -> **Barokat** | 25 | redesigned |
| 26 | `basaltoad` | Basaltoad -> **Rampartoad** | 28 | redesigned |
| 27 | `orchisloth` | Orchisloth -> **Terrasloth** | 25 | redesigned |
| 28 | `caecilith` | Caecilith -> **Zippelith** | 29 | redesigned |
| 29 | `velvorm` | Velvorm -> **Pipewurm** | 27 | redesigned |
| 30 | `gibbelle` | Gibbelle -> **Gongibbon** | 28 | redesigned |
| 31 | `casquebill` | Casquebill -> **Anchorbill** | 27 | redesigned |
| 32 | `nacrolin` | Nacrolin -> **Mirrolin** | 28 | redesigned |
| 33 | `moonloris` | Moonloris -> **Lanterloris** | 27 | redesigned |
| 34 | `murmurling` | Murmurling | 24 | redesigned (name kept) |
| 35 | `threadwyrm` | Threadwyrm -> **Knotwyrm** | 26 | redesigned |
| 36 | `squalltross` | Squalltross -> **Canvastross** | 28 | redesigned |
| 37 | `tuatrune` | Tuatrune -> **Lockatara** | 28 | redesigned |
| 38 | `scaldamus` | Scaldamus -> **Chuggamus** | 28 | redesigned |
| 39 | `floenatee` | Floenatee -> **Frigatee** | 27 | redesigned |
| 40 | `limpetor` | Limpetor -> **Buckleron** | 27 | redesigned |
| 41 | `umbrathere` | Umbrathere | 28 | redesigned (name kept) |
| 42 | `moundvark` | Moundvark -> **Spirevark** | 26 | redesigned |
| 43 | `cindowary` | Cindowary -> **Bellowary** | 28 | redesigned |
| 44 | `glaciyak` | Glaciyak -> **Prowyak** | 28 | redesigned |
| 45 | `nimbostrich` | Nimbostrich -> **Boltstrich** | 26 | redesigned |
| 46 | `goliathite` | Goliathite -> **Effigeetle** | 28 | redesigned |
| 47 | `lilybara` | Lilybara -> **Soakybara** | 27 | redesigned |
| 48 | `duskapi` | Duskapi -> **Snuffapi** | 27 | redesigned |
| 49 | `spatewader` | Spatewader -> **Barrelmander** | 27 | redesigned |
| 50 | `heatherhorn` | Heatherhorn -> **Crofthorn** | 28 | redesigned |

Averages: kept 8 at 21.6; upgrades 13 from 17.8 to 24.7; redesigns 29 at 27.1. Whole roster after this pass: 25.3.

## Name clashes and watch-outs

Within the 50: no two display names or ids are the same. Near-sounds to be aware of in UI lists:
- Three "Gl-" commons: Glintmole, Gloamshell, Glomwort. All kept names; fine in a sorted list, but a rename of
  Glomwort to **Canwort** is available if the owner wants them apart.
- Bubblisk / Buckleron and Barokat / Barrelmander / Bellowary / Boltstrich share first letters only.
- Ids that look like names and no longer match the display name (`pebbit` = Gravadillo, `puddlet` = Prismander,
  `zapple` = Echolop, `wisplet` = Lunowl, `burrlet` = Mycroll, `cindle` = Vespyx) are old and already live. The
  image session should always be given `id` + display name together so nobody draws a "pebbit".
- Old names that stay in the game data as ids but are no longer display names: opalisk, kilnbadger, hoarheron,
  sentrikat, basaltoad, orchisloth, caecilith, velvorm, gibbelle, casquebill, nacrolin, moonloris, threadwyrm,
  squalltross, tuatrune, scaldamus, floenatee, limpetor, moundvark, cindowary, glaciyak, nimbostrich, lilybara,
  duskapi, spatewader, heatherhorn. The roster JSON `name` field for these 26 needs updating when approved.

Against franchises (memory check; the roster's own rule of one web search per name before any public text still
applies, 27 new names + 13 upgrades):
- No new name matches a Pokemon, Digimon, Palworld, Temtem or Monster Hunter creature that I know of.
  "Anvilbrock": Brock is a Pokemon character (human), not a creature; "brock" is the old English word for badger.
  "Barrelmander" shares the generic "-mander" ending with Charmander; the creature is a brown giant salamander
  with a barrel, so no concept overlap.
- Closest concept neighbours are named inside each entry with the two differences. The ones worth a second look
  by the owner: Lanterloris (lamp Pokemon exist, but none are mammals), Glomwort's watering can (Polteageist is a
  teapot ghost; ours is a yellow slime mold in a garden can), Prismander's chandelier (Chandelure), Snuffapi's
  candelabra (Litwick line). All four pass the "same animal + concept + silhouette + palette" test because the
  animal is different and the object is a crest or home, not the body.

## Decisions for the owner (defaults in bold)

1. **Approve the 27 renames** (table above). Default: **yes**, apply to the roster JSON `name` fields; ids stay.
2. **Tone ceiling.** Three designs lean hardest into whimsy: Pipewurm (velvet-cake worm with icing nozzles),
   Boltstrich (rubber boots), Chuggamus (steam-engine hippo). Default: **keep all three**; the brief asked for
   objects, food and machines. Alternatives if he wants it more grounded: Pipewurm back to an amethyst velvet
   worm with slime nozzles, Boltstrich without the boots (keep coil neck), Chuggamus as a cauldron-backed hippo.
3. **Apply the 13 upgrades to existing models now, or after batch 1?** Default: **after batch 1** of the 29 new
   ones, except the two starters (Mycroll lid, Prismander chandelier) which players see first.
4. **Soakybara's saddle is the pool.** The riding spec's saddle bone becomes the pool floor and the rider sits in
   water. Default: **accept** (pure cosmetics, same bone).
5. **Lodestick's gravity theme uses Moon Swap and Moonlift** (lunar-flavoured abilities). The redesign explains
   them as magnetic pull and repulsion; no data change needed. Flagged only so nobody "fixes" it.
