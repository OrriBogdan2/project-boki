# Inbox for the image-gen agent (IMG)
<!-- briefs-trim pointer -->
> Trimmed 2026-11-06 by briefs-trim: 7 finished/superseded entries moved to briefs/archive/INBOX_IMG-2026-11-06.md. Kept here: owner rules and decisions, open owner questions, unmerged READY branches, open assignments and review items, the latest SHIPPED/RELEASED, holds still in force, and the last 12 h. Older archives: briefs/archive/INBOX_IMG-*.md
## 2026-11-04 01:35 UTC (orchestrator): OWNER: Boki art next; it feeds the 3D pipeline
- The Wardens are now built in 3D with Meshy image-to-3D from your turnarounds, so the quality of your sheets sets the quality of the models. The owner wants the **Boki** to look better next, through the same pipeline.
- Do now (main's 20:30 item 1): the **starter and common Boki species first**, to STYLE.md. For each one:
  - a clean **turnaround**: front / side / back / 3/4, neutral pose, flat light, plain background, the whole body in frame, no overlap between views (this is what Meshy reads best);
  - a splash and a portrait.
- Creature specifics: make the tail, ears, wings or fins readable in the side and back views, and show the feet and stance clearly (for the quadruped rig).
- Push to ext/imagegen as each species is done, and note it in IMG_STATUS.md so S2 can start modelling.

## 2026-11-04 01:50 UTC (orchestrator): after the Boki sheets, the character creator concepts
- The owner wants the character creator done to the same quality in Meshy. After the Boki turnarounds, make creator concept sheets to STYLE.md:
  - 3-4 base body types (turnaround, neutral A-pose, simple underclothes);
  - 6-8 head/face variants (front + side);
  - 8-10 hair styles (front/side/back);
  - 6-8 farm outfits (turnaround on the base body).

  Same clean-view rules as the Boki. Push to ext/imagegen and note it in IMG_STATUS.md.

## 2026-11-04 02:10 UTC (orchestrator): 50 original Boki are coming
- S2 is designing a roster of 50 Boki (docs/boki/ROSTER_50.md, owner review first). Once approved, make a clean turnaround per species, in batches of ~10, in the same style as the starters. They're fusions of real animals, plants and elements; never franchise creatures (no Pokémon/Digimon-like designs or prompts naming them). Reject any output that resembles an existing franchise creature.

## 2026-11-04 02:30 UTC (orchestrator): OWNER REVIEW of the Warden art: REGENERATE before any 3D
The owner wants these redone and approved before we commit to 3D models. Common thread: **too "AI"/generic, especially faces**. Push for distinctive faces with personality, and specific, characterful costumes (not stock fantasy), to STYLE.md. Each Warden: a new splash + portrait + turnaround (clean views for Meshy). Do them in this order:
1. **Vex:** now a **cyborg**. A cyborg arm holds the gun, maybe even fused/connected to it (big change OK). Keep her general look, a bit **younger**.
2. **Zedran:** the splash looks AI. Make the chain weapon much cooler, and the costume more unique (spartan arena king per DECISIONS).
3. **Pin:** she's hard to see in the image (it was reviewed on mobile). Make her fill the frame, readable at small sizes; a stronger costume (assassin archer, cloak with some red).
4. **Cinder:** looks generic. **No eyes on the goggles.** The reviewer read Cinder as a man: Cinder is a woman (DECISIONS: salamander-folk woman), so make that read clearly.
5. **Sable:** the face is a bit too big; a cooler, more interesting top/outfit.
6. **Vireo:** a very AI, generic face. Give her **cool, electrified hair** (not just very long), and more energy and personality.
7. **Bjorn:** too generic. Make him **obviously undead, rotting in places**, with more detail on his vest; bigger and more intimidating. **He's the biggest character.**
8. **Dredge:** keep the broken-robot concept, but a more interesting shape, **thinner through the middle**.
9. **Moosh Moosh is renamed "Burple"**: too AI/generic; redo.
10. **Claire:** far too AI/generic, nothing interesting about her; mostly the face (same as Vireo).
11. **Tarek:** add **jewellery in his hair**.
12. **Ostra:** fine; give it more oomph if you can.
- Post each redo to ext/imagegen with a before/after side-by-side for the owner (he reviews on mobile: big, readable images), and note it in IMG_STATUS.md. The video is tomorrow: Vex, Zedran, Pin and Cinder first.

## 2026-11-04 02:30 UTC (orchestrator): the Boki roster as PICTURES, not text
- Owner: "push them first, reading won't help me understand it." For the 50-Boki roster (ext/boki-roster50, docs/boki/ROSTER_50.md), make a **quick concept thumbnail per species** (one image each, or contact sheets of ~10 per image) so the owner can approve visually. Label each with its name and size class.
- Large Boki aren't all mounts: **some walk beside you, some are mounts, some fly**, and other ideas are welcome. Show the size and role in the thumbnail label.

## 2026-11-04 02:40 UTC (orchestrator): use anthum.ai in Chrome for the redo
- The owner confirms you can use anthum.ai in Chrome on his PC again for the regenerations (commercial-licence models only, as in your start brief). When a redo is ready, post it for the owner's approval. 3D only starts after he explicitly approves each one.

## 2026-11-04 03:40 UTC (orchestrator): Vex round 2 approved and pushed; a pure side view needed
- Your round-2 bundle is now on origin/ext/imagegen @ a9fd3b92 (pushed by the orchestrator at the owner's request). The owner approves Vex for 3D.
- For every turnaround from now on: include a **true side profile** (front / side / back, plus 3/4 optional), because Meshy reads clean orthographic views best. If you can, add a pure side view of Vex too.
- If you can't push from your machine, bundles work: the owner hands them over.

## 2026-11-04 04:35 UTC (orchestrator): received and committed
- Ryzz round 2 (turnaround, side, portrait, splash, before/after) is committed to ext/imagegen from the owner's uploads. Next redos still wanted: Sable, Bjorn, Dredge, Burple, Claire, Tarek, Ostra (each with a true side view).

## 2026-11-04 06:25 UTC (orchestrator): Bjorn is renamed "Breaker"
- Name his files breaker_* from now on. His round-2 look (towering undead sailor, red braids, ice-anchor hammer, prow shield) is the one the owner sent at 06:20.

## 2026-11-04 07:20 UTC (orchestrator): art direction from the owner
- Sex appeal is wanted (adult characters, stylised, not explicit). Several crop tops are fine; if you vary an outfit, keep the appeal. Ignore the "no crop top / no bare midriff" lines in the orchestrator's Ryzz/Vex/Sable/Claire prompts.

## 2026-11-04 07:10 UTC (orchestrator): Ryzz gets a lightning scar
- Owner idea: her closed right eye is a scar, not a wink. In any Ryzz redo, paint a branching lightning-shaped scar through the right brow and cheek (faint blue glow), the eye closed or half-lidded. Cinder: draw her spear in her RIGHT hand from now on.

## 2026-11-05 (S2): OWNER_REVIEW item 108: redo Vex's splash art
- Owner: a better Vex splash, our own design, with a stronger composition and pose. Keep her current design (green hair and braid, eye plate, rotary cannon in gunmetal + brass, gear backpack and hoses; see wardens_r3 VEX_KIT.md). Save as vex_splash* on ext/imagegen and post the commit in briefs/EXT_TO_MAIN.md. Approval gate as for ART-1: owner approves before it replaces the current one.

## 2026-11-05 (S2): Vex splash request updated
- The 00:52 request's design note is out of date: use briefs/art-refs/vex_FINAL_sheet.png (the street racer version, one hybrid arm-cannon) for any Vex splash. Skip it if the owner already made one.

## 2026-11-07 03:55 UTC (coordinator): OWNER ORDER: Boki 50, 2D designs for every species
The owner wants 50 Boki ASAP, each with a 2D design and a 3D model (DECISIONS 2026-11-07 "Boki 50"). The 3D side runs on the server as soon as a sheet lands. Your part, per species, in docs/art/gen/STYLE.md style (same quality as Pebbit and Glintmole):
1. a concept sheet `briefs/art-refs/boki/<id>_concept.png` (front, side, back, an expression row);
2. a clean turnaround `briefs/art-refs/boki/<id>_turnaround.png` (front / side / back / 3/4, neutral stance, flat light, plain background, whole body in frame, no overlapping views; tails, ears, wings, fins readable in side and back; feet and stance clear).
Design source: each species' entry in docs/boki/ROSTER_50.md on ext/boki-roster50 (name, look, colours, the "not like" line). Push each species as it's done and add a line to IMG_STATUS.md. Do 10 at a time, in this order:
- Batch 1 (no 3D yet, small/medium first): kilnbadger, moonloris, murmurling, nacrolin, sentrikat, lilybara, limpetor, gibbelle, duskapi, caecilith
- Batch 2 (no 3D yet): casquebill, cindowary, floenatee, heatherhorn, hoarheron, opalisk, orchisloth, scaldamus, spatewader, velvorm
- Batch 3 (no 3D yet, incl. the big ones): basaltoad, glaciyak, goliathite, moundvark, nimbostrich, squalltross, threadwyrm, tuatrune, umbrathere
- Batch 4 (3D exists, 2D design missing; match the existing model): burrlet (Mycroll), cindle (Vespyx), puddlet (Prismander), wisplet (Lunowl), zapple (Echolop), hivara, zephyrak, cairnback, kindlewren, mossgrade, kestrike, lodestick, marchleaf, nettlynx, thrumbird
Already done: pebbit, glintmole, gloamshell, glomwort, rimeshrew, selenfin.

## 2026-11-07 04:10 UTC (coordinator): Boki 50 UPDATE: wait for the new designs
- The owner raised the bar: every Boki must be a cool, creative mix (DECISIONS "Boki design bar"). A redesign pass is rewriting the bland roster entries now. It lands as briefs/BOKI_50_DESIGNS.md with an image prompt per species and a top-10 for batch 1.
- Use BOKI_50_DESIGNS.md (not ROSTER_50.md) for every species it covers, and its top 10 as batch 1. If it isn't there yet, start with the species marked "kept" in it, or wait; don't make sheets from the old roster text.

## 2026-11-07 04:35 UTC (coordinator): Boki 50 designs are IN: start batch 1
- Source: briefs/BOKI_50_DESIGNS.md. Each species has an IMAGE PROMPT block; follow "Shared image-prompt rules" in it. It replaces the batch lists above.
- Batch 1 (its top 10), file names by id: caecilith (Zippelith), gibbelle (Gongibbon), nacrolin (Mirrolin), squalltross (Canvastross), goliathite (Effigeetle), tuatrune (Lockatara), cindowary (Bellowary), umbrathere (Umbrathere), scaldamus (Chuggamus), lilybara (Soakybara).
- Per species: `briefs/art-refs/boki/<id>_concept.png` (concept sheet) and `briefs/art-refs/boki/<id>_turnaround.png` (clean turnaround for 3D). Push each as done, one line in IMG_STATUS.md.
- Batch 2: the remaining 19 redesigns in the doc's order. Batch 3: the 13 upgrades (edit the existing look; starters burrlet/puddlet first). The 8 "kept" need only a clean concept sheet matching their model.

## 2026-11-09 coordinator -> art batch (Vertex runner): 3 owner redos, priority over new species
Owner ratings are below the 8.5 bar; redo each with the same rules and grading, owner note first. Post ART lines as usual (main imports them into the Bokidex automatically every 5 min).
- **Sporcupine** (owner 7.9): the mushrooms are too tall and odd. Make them short, spiky, quill-like caps that sit close to the body and follow the porcupine silhouette.
- **Voltmink** (owner 7.0): should look calm and cool, in a relaxed pose (not tense or aggressive).
- **Teapotamus** (owner 7.1): no note. Push appeal and silhouette up to 8.5 (idea fused through the body, readable face).
Current renders: projectboki Bokidex / site assets/img/boki2d/<name>-1200.webp.

## 2026-11-09 coordinator -> art: THE BLIGHT (context for every Spore Boki, Blight art and future corrupted forms)
Read this before any Spore-type Boki, any Blight enemy, map-edge or corrupted-variant art. Background, not a new batch.
- **What it is:** the Blight is the Wyrm's blood. Malgrave and the Wyrm are the same villain. When Sable the thief touched
  the Wyrmheart in Malgrave's vault, the Wyrm woke and the Hollowing began; its blood seeps out of the vault and across the
  sky islands as the Blight. In every match the Blight closes in toward the Heart's site (the battle-royale ring), and it
  grows stronger at the outer edge of the map and at night.
- **Its look (already canon on Grimble and Kael; match it):** bruised purple and purple-black. Sludge that drips and pools,
  purple veins spreading under skin, bone spurs growing along the vein paths, swollen purple gums. Where it burns, it
  leaves white-hot cracks (Kael's arm). Not green slime, not generic zombie rot: it is dragon blood, rich and dangerous,
  with a faint inner glow.
- **What it does to living things:** it hollows them out. The Empty are people the Wyrm emptied. Blight creatures (Hollow
  Fliers, armored Husks that break cover, the Walker) are shells driven by it. Keep the early game weak-looking; the scary
  ones come later.
- **Spore type = the Blight's type (owner idea 11-09, design pass pending):** Spore Boki are the ones the Blight touches,
  fungal, more toxic, "corrupted" (a bit like shadow or corrupted forms in other creature games). For Spore species now:
  keep them appealing and on the 8.5 bar first, then use the Blight palette as an accent, e.g. purple-black gills, veined
  caps, a faint glow in the spores, small bone-spur quills. Don't make them gross or sad; they should look like they
  could thrive in it. Later there may be "Blighted" variants of other Boki (same species, corrupted look) and a combined
  corruption + Auburn pass (art-refs/REMINDERS.md, Nov 29). Don't start those yet.
- **Tone:** dark fantasy edge on a bright, toylike world. The Blight is the one truly menacing color in the game. Use it
  sparingly so it reads instantly.
- **Type names changed (owner final, 11-08 22:29 ET):** Spore stays Spore. Old names in older briefs map to the
  new ones: Ember=Fire, Tide=Water, Bloom=Grass, Storm=Electric, Frost=Ice, Stone=Rock, Gravity=Psychic,
  Tempest=Flying, Wyrm=Dragon, Shadow=Dark, Venom=Poison, Swarm=Bug, Titan=Steel, Wild=Normal, Lunar=Fairy, Prism=Crystal,
  Echo=Sound. Table: boki-art/GAME_RULES_NOV8.md.

## 2026-11-09 coordinator -> art: HERO CARDS for the Bokidex (owner priority)
Owner: "a lot of the hero images are bad cutouts still, make sure the art agent is on it." He is also making dark, light and
transparent versions of every hero card; match that set.
- Interim fix done by coordinator: heroes are now auto-cut from the turnaround sheets (3/4 view, backdrop removed). They are a
  stopgap; a proper hero is a single clean 3/4 pose, not a sheet crop.
- Deliver per species: <id>_hero_transparent.png (true alpha, no halo, 2048 px square, centered, ~8% margin),
  <id>_hero_dark.png (on deep navy #0b1220 glow), <id>_hero_light.png (on warm off-white #f6f3ee glow). Same pose in all three.
  Put them in boki-art/heroes/. The dex picks them up automatically (hero / heroDark / heroLight).
- Order: first the species with NO hero at all (41): Mothlet, Howlop, Bellowlet, Furnacowary, Wickapi, Coolatee, Glaciatee, Kayak, Dreadnoyak, Geodemole, Druzemole, Embrook, Pyrraven, Scythant, Reapant, Thistlynx, Briarlynx, Fizzlet, Thunderstrich, Terrasloth, Bucketmander, Cisternmander, Jibbatross, Lyrewing, Oarter, ???, ???, ???, ???, ???, ???, ???, ???, ???, ???, ???, ???, ???, ???, ???, ???.
  Then redo the rest, starting with any whose current cutout has holes or halos (crystal/glass species: Glassolotl, Prismander,
  Prismink, Geodelotl, Mirrolin are most at risk).
- Report each batch in EXT_TO_MAIN.md as "HEROES batch N: ids".

## 2026-11-09 05:35 UTC coordinator -> art batch: 18 owner orders (priority over new species)
Owner rated these below the 8.5 bar or asked for 2D of a 3D design. Same rules and grading as the originals, owner note first. Post ART lines as usual (imported into the Bokidex automatically).
- **Redo Amanitusk attempt 2 (owner 8.0)**: owner note first: good, i can see it being a little much, maybe the mushrooms are closer to him and wider and less of them, just because they make him so tall. Previous attempt: /home/boki/gens/amanitusk-1-art.
- **Redo Barokat attempt 3 (owner 8.3)**: owner note first: all close, 2 is prob the best but i dont love any - 1 could also be good but looks bad in this instance. i liek the stripes though.. Previous attempt: /home/boki/gens/barokat-1109045518.
- **Redo Bellowlet attempt 2 (owner 8.0)**: owner note first: the bottom part and top part feel disconnected. Previous attempt: /home/boki/gens/bellowlet-3-art.
- **Redo Briarlynx attempt 2 (owner 8.4)**: owner note first: very close to being there - the fae is a bit generic and the spikes are gneric / too many of them, but veyr col and keep a similar direction. Previous attempt: /home/boki/gens/briarlynx-2-art.
- **Redo Bucketmander attempt 2 (owner 8.1)**: owner note first: think i saw a better versi jonof this, but if this is the earlier verison, then it needs to have a slightly different thundercloud on it - its close though. Previous attempt: /home/boki/gens/bucketmander-2-art.
- **Redo Canvastross attempt 2 (owner 7.5)**: owner note first: a little generic like this. Previous attempt: /home/boki/gens/canvastross-1-art.
- **Redo Druzemole attempt 2 (owner 8.3)**: owner note first: dont like his nose, but close. Previous attempt: /home/boki/gens/druzemole-3-art.
- **Redo Druzemole attempt 2 (owner 6.9)**: owner note first: worse than the other option. Previous attempt: /home/boki/gens/druzemole-r-2-art.
- **Redo Echolop attempt 2 (owner 8.3)**: owner note first: cool but the circle around him is kind of weird (i like it but maybe mor sound wave than pure circle). Previous attempt: /home/boki/gens/echolop-1-art.
- **Redo Effigeetle attempt 2 (owner 8.4)**: owner note first: looks a bit low poly but is good!. Previous attempt: /home/boki/gens/effigeetle-1-art.
- **Redo Embrook attempt 2 (owner 8.1)**: owner note first: could be good but saw something similar, ill do redo cuz im not sure. Previous attempt: /home/boki/gens/embrook-r-3-art.
- **Redo Ermink attempt 2 (owner 8.1)**: owner note first: think he can be done better than this ,i dont like his hair on top. Previous attempt: /home/boki/gens/ermink-1-art.
- **Redo Frigatee attempt 2 (owner 7.3)**: owner note first: too generic. Previous attempt: /home/boki/gens/frigatee-1-art.
- **Redo Glaciatee attempt 2 (owner 7.8)**: owner note first: good but generic, if you're doing an ice seal it needs to have something more to it.. Previous attempt: /home/boki/gens/glaciatee-1-art.
- **Redo Glintmole attempt 2 (owner 8.4)**: owner note first: good based deisgn but could use a few more looks / designs - might be good enough. Previous attempt: /home/boki/gens/glintmole-1-art.
- **Redo Voltmink attempt 2 (owner 7.7)**: owner note first: a little too calm, i emant more cool than calm when i gave rthat advice - like epic cool thunder boki that is not over the top. Previous attempt: /home/boki/gens/voltmink-r-3-art.
- **Redo Wickapi attempt 2 (owner 7.8)**: owner note first: looks too realin the face, doesnt fit the game design. Previous attempt: /home/boki/gens/wickapi-r-2-art.
- **Redo Zipling attempt 2 (owner 8.0)**: owner note first: cool idea but i htink the one they used is better, so ill say redo cuz im ot sure. Previous attempt: /home/boki/gens/zipling-1-art.

## 2026-11-09 05:57 UTC coordinator -> art batch: 28 owner orders (priority over new species)
Owner rated these below the 8.5 bar or asked for 2D of a 3D design. Same rules and grading as the originals, owner note first. Post ART lines as usual (imported into the Bokidex automatically).
- **Barokat redo: distinct body shape**: owner note first: owner likes his design, but he is shaped like Ermink. Give him a clearly different body shape and silhouette; keep the design language. Renders: /home/boki/gens/barokat-1109045518. Previous attempt: /home/boki/gens/barokat-1109045518
- **Mink line: push Flarmink/Rippmink/Blossmink/Prismink apart**: owner note first: too many minks share the same posture and body shape. Push each evolution further: different pose, body build and silhouette for Flarmink, Rippmink, Blossmink and Prismink (all currently the same pose and body). One sheet each. Renders: /home/boki/gens/flarmink-2d. Previous attempt: /home/boki/gens/flarmink-2d
- **Ribbonwyrm line: fix stage read (Ribbonwyrm vs Dragonkite)**: owner note first: Ribbonwyrm and Dragonkite both read as tier 2/3, so the evolution feels weird. Make Ribbonwyrm clearly a mid stage (smaller, simpler, younger) and Dragonkite the clear final. Renders: /home/boki/gens/ribbonwyrm-1-art. Previous attempt: /home/boki/gens/ribbonwyrm-1-art
- **Galleotter redo: face + dex pose**: owner note first: looks cool but the face looks AI. Redesign the face (stylized, our game look) and give him a new dex pose. Renders: /home/boki/gens/galleotter-2-art. Previous attempt: /home/boki/gens/galleotter-2-art
- **Parasolth smaller/cuter, Umbrathere cooler/scarier**: owner note first: Parasolth should be smaller and cuter. Umbrathere (its evolution) should be cooler and scarier. Both sheets. Renders: /home/boki/gens/parasolth-1-art. Previous attempt: /home/boki/gens/parasolth-1-art
- **Latchling line: more change between stages**: owner note first: the whole line (Latchling, Lockatara, Vaultara) looks the same. Bigger design changes per stage and different poses. Renders: /home/boki/gens/latchling-r-1-art. Previous attempt: /home/boki/gens/latchling-r-1-art
- **Knotwyrm: add contrast**: owner note first: owner says he is awesome, but he blends into himself. Keep the design and add value/colour contrast so the knots and body read clearly. Renders: /home/boki/gens/knotwyrm-1-art. Previous attempt: /home/boki/gens/knotwyrm-1-art
- **Canvastross: cooler third-evo pose**: owner note first: should be cooler, with a better, more powerful pose that reads as a third evolution. Renders: /home/boki/gens/canvastross-1-art. Previous attempt: /home/boki/gens/canvastross-1-art
- **Barrelmander line: stop 'just wider'**: owner note first: the evos are too close; he just gets wider. Change the shape, features and pose per stage (Bucketmander, Barrelmander, Cisternmander). Renders: /home/boki/gens/barrelmander-1-art. Previous attempt: /home/boki/gens/barrelmander-1-art
- **Puffamus/Chuggamus: stop 'just wider'**: owner note first: same issue as Barrelmander: the evos just get wider. Make Puffamus and Chuggamus clearly different designs and poses from each other and from Teapotamus. Renders: /home/boki/gens/puffamus-1-art. Previous attempt: /home/boki/gens/puffamus-1-art
- **Rimeshrew: more distinct**: owner note first: should look more distinct, maybe wilder or cooler. Renders: /home/boki/gens/rimeshrew-2-art. Previous attempt: /home/boki/gens/rimeshrew-2-art
- **Tidalisk: new body type**: owner note first: break the obvious 2 to 3 pattern: give the final a new kind of body type, not a bigger version of stage 2. Renders: /home/boki/gens/tidalisk-1-art. Previous attempt: /home/boki/gens/tidalisk-1-art
- **Dribbara line: different poses**: owner note first: line is cool but all three (Dribbara, Soakybara, Geysirbara) need different poses. Renders: /home/boki/gens/dribbara-r-1-art. Previous attempt: /home/boki/gens/dribbara-r-1-art
- **Arcestrel vs Voltalon: separate them**: owner note first: Arcestrel and Voltalon look too similar. Make Voltalon a clearly bigger, different final (shape, pose), keep the line's identity. Renders: /home/boki/gens/arcestrel-r-2-art. Previous attempt: /home/boki/gens/arcestrel-r-2-art
- **Crofthorn: better back load**: owner note first: a camel with stuff on its back is too close to the capybara with stuff. Put something more interesting and unique on its back. Renders: /home/boki/gens/crofthorn-1-art. Previous attempt: /home/boki/gens/crofthorn-1-art
- **Geodemole: unbroken alternate form**: owner note first: owner wants to see the NOT-broken version as his alternate form. Make that sheet (same creature, intact). Renders: /home/boki/gens/geodemole-3-art. Previous attempt: /home/boki/gens/geodemole-3-art
- **Prowyak: give him a pose**: owner note first: he just stares at the camera. Give him a real action/character pose. Renders: /home/boki/gens/prowyak-1-art. Previous attempt: /home/boki/gens/prowyak-1-art
- **Glintmole: richer starter**: owner note first: cool starter but a bit basic and low-poly looking. Raise detail and quality, keep the concept. Renders: /home/boki/gens/glintmole-3-art. Previous attempt: /home/boki/gens/glintmole-3-art
- **Gongibbon/Gongrowl: Gongrowl bigger ape**: owner note first: Gongrowl needs to be bigger and stronger, like an ape. Gongibbon a bit more distinctive. Both sheets. Renders: /home/boki/gens/gongibbon-1-art. Previous attempt: /home/boki/gens/gongibbon-1-art
- **Snuffapi line: poses + tone down Chandelapi**: owner note first: line too samey on pose; vary poses (Wickapi, Snuffapi, Chandelapi). Chandelapi is too dripped out: fewer chandeliers and candles. Renders: /home/boki/gens/snuffapi-1-art. Previous attempt: /home/boki/gens/snuffapi-1-art
- **Bellowary: totally new tier 2**: owner note first: Bellowary and Furnacowary are basically the same. Change tier 2 (Bellowary) to a totally different design; keep Furnacowary (tier 3) as is. Renders: /home/boki/gens/bellowary-1109045508. Previous attempt: /home/boki/gens/bellowary-1109045508
- **Zippelith: remove extra tail**: owner note first: has an extra tail on his right; remove it (one tail only). Renders: /home/boki/gens/zippelith-1-art. Previous attempt: /home/boki/gens/zippelith-1-art
- **Seamwyrm: show the tail**: owner note first: show its tail somewhere in the pose. Renders: /home/boki/gens/seamwyrm-1-art. Previous attempt: /home/boki/gens/seamwyrm-1-art
- **Lunowl: more voidy to match Eclipsowl**: owner note first: Eclipsowl is very voidy/epic next to Lunowl. Keep Eclipsowl; make Lunowl a bit more voidy so the line matches. Renders: /home/boki/gens/lunowl-3-art. Previous attempt: /home/boki/gens/lunowl-3-art
- **Amanitusk line: wider + new pose**: owner note first: whole line (Mycroll, Sporcupine, Amanitusk) is the same pose. Keep Mycroll as is; Amanitusk wider and in a different pose; Sporcupine a different pose too. Renders: /home/boki/gens/amanitusk-1-art. Previous attempt: /home/boki/gens/amanitusk-1-art
- **Starters: pose regens**: owner note first: all starters need regens for position/pose: Vespyx/Cindle line, Prismander/Puddlet line, Mycroll/Burrlet line, Ermink. Keep designs, new varied poses per stage. Renders: -. Previous attempt: 
- **Lodestick: 2D sheet (still a 3D render)**: owner note first: Lodestick still shows a 3D render in the Bokidex. Make its 2D turnaround sheet. Renders: -. Previous attempt: 
- **Gloamshell: new portrait framing**: owner note first: art ran into its #number badge (fixed by resizing in the dex); a sheet with a lower, more compact pose would sit better. Renders: /home/boki/gens/gloamshell-1-art. Previous attempt: /home/boki/gens/gloamshell-1-art
