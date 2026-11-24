# Hunter fix suggestions (11-23)

One concrete fix per part for each of the 13 hunters, for the /admin Hunters panel.
Suggestions only: no glb was changed.

## How it was made

- Model: the live in-game glb of each hunter at origin/main 03bd4a9df58, picked by `content/rules/warden_native.json`
  (10 native `<art>_meshy.glb`, 3 contract `<art>.glb`: Albert, Grimble, Vex).
- Renders: real GPU (jobq workers rp1 and rp2g), 8 views (match camera, eye level front/back/side, low front, face,
  both hands) x 3 clips (idle, run, attack) x 3 frames, 512 px. 216 frames per hunter.
- Judge: one Fable subagent per hunter (claude-fable-5-2, effort high). It saw the frames, the turnaround and the glb
  facts (bones, materials, clips). It did not see the owner's per-hunter verdicts, so the comparison below is a real test.
- Scores are 0-10. `game` = match camera first, eye level second. `close` = close-ups. Ship bar 7.0, goal 9.0.
- Output per hunter in `/home/boki/gens/hunter-parts-1123/<key>/`: `fixes.json` (every part: game, close, clips_into,
  fix, cause, tool) and `fix_sheet.jpg` (game camera row + the evidence frame of the top 3 fixes).
  Full frames and judge sheets: `/home/boki/gens/hunter-fix-suggest-1123/<key>/`.

## Result in short

- Judge and owner agree on 8 of 13 outright and on the other 5 in part. No hunter is a flat disagreement.
- Two parts were re-scored after the owner check, because the judge under-called them: Meeko's sun (8.0 to 6.8)
  and Sable's face (7.3 to 6.5). The judge's own numbers stay in `fixes.json` as `judge_original`.
- Lowest in game: Grimble 5.0, Vex 6.0, Motley 6.8, Cinder 6.9. Highest: Sparkle 8.2.
- Tool split of the 39 top fixes: 16 texture repaint, 10 weights, 8 bone placement, 5 Meshy part edit. Clipping and stretching are almost all weights or bone placement
  (cheap, no Meshy). Face and hand shape problems need a Meshy part edit. Colour problems are texture repaints.

## Scores against the owner's eye (11-23)

| Hunter | Game | Close | Owner said | Judge agrees | Why |
|---|---|---|---|---|---|
| Vex | 6.0 | 5.0 | clipping issues | yes | Game 6.0. Left hand and belt coin chain stretch into 25 cm blades and streaks, right elbow fans into shards, coin sinks ~3 cm into the left leg. The judge names most of it stretching (weights), which reads as clipping in play. |
| Grimble | 5.0 | 5.0 | clipping issues | yes | Game 5.0, lowest of the 13. In the shot the gun passes ~15 cm through the hips; a black gap opens behind the left arm in run. |
| Lace | 7.0 | 5.6 | face + body/dress issues | yes | Close 5.6. Face close 5.5 (black wedge shards round the left eye and nose), corset close 5.5 (same shards), dress game 6.0 (skirt front splits in run, heel out the back). The match camera rows show none of it, so game is 7.0. |
| Meeko | 7.5 | 6.6 | sun + rain cloud need visible faces and a better look | partly | The judge caught the cloud (face is a black ragged blotch, close 5.5) but passed the sun at 8.0. I checked the frames: the sun's face is the same dark smudge, no eyes or mouth. Sun re-scored 6.8 / 5.5 and both moved to the top; the judge's own top fix was the cape. |
| Sable | 7.2 | 5.8 | face has weird angles | partly | The judge scored the face 7.3 / 6.0 as paint only (no smirk, stray ticks, cheek line) and put the bald lavender skull cap first. I checked the face frames: the face sits as a hard-edged plate on the cap, outlined in black from temple to jaw, with a crease across the cheeks and sharp brow ridges. That is shape, not paint. Face re-scored 6.5 / 5.5 and moved to the top as a Meshy head edit. |
| Neve | 7.6 | 6.7 | looks pretty good | yes | Game 7.6, close 6.7. Nothing clips in any frame. The old 2.0 was the previous model; see the Neve section. |
| Sparkle | 8.2 | 7.4 | good for the most part | yes | Game 8.2, best of the 13. No part under 7.0. Fixes are colour polish only. |
| Cinder | 6.9 | 6.4 | good for the most part | partly | Game 6.9. Nothing broken; the judge marks colour against the turnaround (red skin vs bronze-tan, stringy hair ends, boots without the lava lattice). The red may be the render's warm light: see the warm-cast caveat. |
| Kael | 7.4 | 6.8 | good for the most part | yes | Game 7.4. Body clean, no clipping. Only the sword is under 7.0 (swings ~90 degrees each run stride, flat slab). |
| Albert | 7.0 | 6.0 | good for the most part | partly | Game 7.0, on the bar. Helmet and torso 8.5+. Marked down for black shards on the right sail, the left fist through the shield (~8 cm) and thin crossed legs at eye level, which the match camera mostly hides. |
| Motley | 6.8 | 6.4 | good for the most part | partly | Game 6.8. Face 9.0, hat 8.8, ruff 8.6. Marked down for design fidelity: the void body is glossy black, not the turnaround's violet starfield, and the box swings up ~45 degrees in run. |
| Gil | 7.6 | 7.2 | good for the most part | yes | Game 7.6. No clipping. Fixes are texture: dots too small and dark, eyes orange not green. |
| Tenzo | 7.6 | 7.4 | good for the most part | yes | Game 7.6. No clipping. Skin reads orange and merges with the sash; may be the warm-cast caveat. |

## Neve: why the tracker said 2.0, and the re-score

- The 2.0 is stale. It is `LIVE SCORE: 2.0/10` in `/home/boki/gens/hunter-fix-1118/reviews/claire.md`, scored on the
  old contract-rig `claire.glb`. The live model since PR #673 (merged 11-23 01:52 EST) is `claire_meshy.glb`
  (85,006 tris, 99 joints). The tracker kept showing the old number.
- The newer model then got 5.0 FAIL from the judge of that PR, for three blockers:
  1. Idle hip yaw: idle stands about 60 to 80 degrees off the run facing.
  2. Black patches under and behind the skirt. That review itself says they are 0 px at the match camera.
  3. Attack front-hem stretch (119 tris, up to 15 cm) near the right upper leg.
- Re-score on the live model with the game camera first: game 7.6, close 6.7. All 14 parts are at or above 6.8
  in game; nothing clips in any sampled frame. This agrees with the owner ("looks pretty good").
- Rules that over-penalised her: blockers 1 and 2. Both are real but neither shows in play: the idle facing is
  hidden because the game turns the model to its aim, and the under-skirt black has 0 px at the match camera.
  They belong in `close` as notes. Blocker 3 shows as a small dark fleck at eye level only.
- What is still worth fixing on her (all small): hair colour (6.8), the black skirt underside (7.0 / 5.5),
  the left ear lump on the cheek (close 6.5), the idle yaw (one root key).

Proposed ruling line for `boki-tools/hunter-regions.json` under `hunters.neve` (NOT installed; the panel job owns
that file):

```json
"ruling": "11-23 owner: Neve looks pretty good. Score the live claire_meshy.glb; the 2.0 was the old claire.glb and is void. Game score = match camera first, eye level second. Idle hip yaw against the run facing, and dark patches under the skirt or on the back hem that are 0 px at the match camera, are close notes worth at most -0.5 in game and are never blockers. Attack front-hem stretch counts in game only if it shows at the match camera or eye level."
```

## Top 3 fixes per hunter

Part scores are game / close. The tool is the smallest one that does the job. Every part (not only the top 3), with what is wrong and the full cause, is in the hunter's `fixes.json`.

### Vex (game 6.0, close 5.0)

1. **hand_l** (4.0 / 3.0, weights; cause: weights): Make the left hand rigid: palm verts 100% hand.L, finger verts 100% fingers.L, thumb verts 100% thumb.L, and remove every coin, forearm.L and hips weight from them, so the hand is a compact ~17 cm hand with no blades at idle f008 and lmb f001.
2. **coin** (4.5 / 3.5, weights; cause: weights): Remove all coin-bone weight from every vert except the loose disc itself and set the belt coin-chain verts to 100% hips (hanging end 100% thigh.L), so the chain stays seven round gold coins on the left hip in every clip and no streak or needle follows the disc.
3. **arm_r** (5.5 / 4.5, weights; cause: weights): Set the verts in the 10 cm band between the right sleeve hem and the gatling collar to 100% forearm.R (remove upper_arm.R, gatling and launcher weights) so the band stays a closed brass cuff with no shards at run_f f001 and lmb f001.

Also under 7.0 in game: arm_l 5.0.

Note: The solid-black left forearm may be flipped faces, not paint: check normals before repainting.

### Grimble (game 5.0, close 5.0)

1. **outfit** (4.5 / 5.0, bone placement; cause: placement): Re-parent joint 'ball' from root to 'hoard' keeping its rest offset (nested at the back of the pack, about 1.3 m up and 0.25 m behind the spine) and remove its own track from idle, run_f and shot, so the ball stays tucked in the pack in every clip.
2. **torso** (5.5 / 5.0, weights; cause: weights): Move the chest and back verts that lie inboard of the left shoulder joint (everything from 15 cm left of the spine to 16 cm right of it) from upper_arm.L to hips at 100%, leaving only the deltoid and arm on upper_arm.L, so nothing stretches and no black gap shows in run_f.
3. **gauntlet_arm** (5.5 / 5.5, bone placement; cause: animation): In the shot clip only, re-pose upper_arm.L and forearm.L so the fist is held about 30 cm in front of the chest with weapon_muzzle pointing along the character's forward; the barrel must stay clear of the torso from front, side and back.

Also under 7.0 in game: gauntlet_fist 5.5, crescent_hook 5.5.

Note: The top fix (ball hanging 20-90 cm off the pack) is on the `ball` bone, which is the dash junk-ball prop. The render does not run his kit, so check in a live match before moving it. The face and hand close-up cameras sit inside the pack on this model, so close scores here are weak.

### Lace (game 7.0, close 5.6)

1. **dress** (6.0 / 4.5, weights; cause: weights): Re-weight the skirt mesh (Mesh_0) front: waist-to-mid-thigh band 0.5 Hips / 0.5 LeftUpLeg or RightUpLeg by side with a 10 cm smooth blend across the centre line, lower half and hem 0.7 Hips / 0.3 UpLeg, no vertex 100% on one leg bone; result: in eye_front/run/2 the skirt front bulges smoothly over the rising knee with no hole, no split flap and no black inside showing.
2. **bow** (6.0 / 5.0, weights; cause: weights): On the Bow mesh weight the red grip and the inner 70% of both limbs 1.0 to the Bow bone, leave at most 0.25 StringMid on the outer limb tips and 1.0 StringMid only on the string's middle vertex; result: in hand_l/attack/1 the grip stays straight inside the left fist and only the string moves back.
3. **face** (7.2 / 5.5, Meshy part edit; cause: mesh): In Meshy re-sculpt only the face front (forehead to chin, ear to ear) as one smooth porcelain shell with no grooves around the left eye, nose bridge and under the lip, keeping the diagonal red stitch scar and hairline cracks in the texture only; result: no black wedges in face/run/1, only the thin red stitch line and lilac-grey eyes.

### Meeko (game 7.5, close 6.6)

1. **rain_cloud** (7.2 / 5.5, texture repaint; cause: UV): Repaint/remap the eyes-mood_cloud face area so it shows one small sad face (two eyes and a mouth, at most 30% of the cloud's front width, centred) with the rest of the cloud front plain lavender-white.
2. **sun** (6.8 / 5.5, texture repaint; cause: UV): Re-lay the eyes-mood_sun face UVs to cover exactly one atlas cell (the cells are set in content/rules/warden_anim/pip.json mood.faces.sun) and redraw the sun cells as two big dark eyes and a smile filling about 60% of the disc; then check in a live match that the face shows and blinks.
3. **cape** (6.8 / 5.8, weights; cause: weights): Reweight the cape: neck ring, brooch, front panel and back 100% Spine02; only the two shoulder flaps blend smoothly to 0.5 LeftArm / 0.5 RightArm over about 4 cm, with zero weight on ForeArm and Hand bones; result is a cape that keeps its scalloped outline in attack with no red tears and the brooch centred.

Note: Both faces are drawn by the mood atlas (materials eyes-mood_sun, eyes-mood_cloud, image `faces`, cells in content/rules/warden_anim/pip.json). The likely cause is the face UVs on the native glb not matching one atlas cell, so fix UV/atlas first; no Meshy work needed for the faces. At the match camera each companion is about 35 px wide, so only a bold face (two big eyes and a mouth filling most of the front) will read in play.

### Sable (game 7.2, close 5.8)

1. **face** (6.5 / 5.5, Meshy part edit; cause: mesh): In Meshy regenerate the head only as one smooth shell: no step between face and skull, no crease across the cheeks, softer brow and chin, hairline blended into silver-white hair (pairs with the hair fix); repaint the mouth as the lopsided smirk afterwards.
2. **hair** (6.3 / 5.5, texture repaint; cause: texture): On the head material base-colour texture recolour the hair cap, from the hairline behind the antennae back to the nape and above the ears, to the braid's pale silver-white and paint swept-back strand lines, so cap and braid read as one hairstyle and the skin/hair boundary is the hairline.
3. **hand_r** (6.5 / 4.3, Meshy part edit; cause: mesh): Regenerate the right hand plus pistol grip in Meshy from the turnaround crop as a closed fist: four fingers curled around the grip, thumb wrapped over the far side, index at the trigger, dark fingerless glove on the back of the hand with lavender fingertips.

Also under 7.0 in game: hand_l 6.5.

### Neve (game 7.6, close 6.7)

1. **hair** (6.8 / 6.0, texture repaint; cause: texture): Repaint the hair area of the head texture: bring the periwinkle zones up to the turnaround's pale lilac-white (about 35% lighter and half the saturation) and blend the jagged white/purple borders at the crown and temples into a soft gradient, so the head reads white-lilac from the match camera.
2. **outfit** (7.0 / 5.5, texture repaint; cause: texture): Repaint the skirt underside and inner tier faces in the body texture from black to the pale lilac-blue tulle colour of the outer skirt, so no black shows from behind or below.
3. **face** (7.8 / 6.5, Meshy part edit; cause: mesh): Re-sculpt the left side of the head in Meshy from the turnaround face crop so the left ear sits at eye height and is tucked under the side hair lock (only the tip showing), removing the outlined lump on the cheek; result is a clean cheek contour on both sides.

### Sparkle (game 8.2, close 7.4)

1. **accessories** (7.6 / 7.5, texture repaint; cause: texture): Texture repaint on the body texture: shift every copper part (backpack shell, the three rods, the coil springs and the arm and forearm coils) from red-orange to copper brown (hue toward orange-brown, about 30 percent less saturation and 15 percent darker) so they separate from the skin as in the turnaround back view.
2. **leg_r** (7.8 / 6.8, texture repaint; cause: texture): Texture repaint on the right leg: clone clean fishnet-over-skin from the outer thigh over the dark blotches on the knee and front of the shin (two patches, each about 5 cm) and over the pale inner-thigh and knee-top area so the fishnet is even from garter strap to boot.
3. **face** (8.0 / 6.8, texture repaint; cause: texture): Texture repaint on the face_donor/head textures: paint the pink lightning bolt (about 3 cm tall) under the left eye as in the turnaround front view, and paint skin tone over the blue/pink smear on the temple and cheek in front of the left ear so the hairline ends cleanly at the hair mesh.

### Cinder (game 6.9, close 6.4)

1. **torso** (6.5 / 6.5, texture repaint; cause: texture): Repaint the body base colour on all skin areas (torso, upper arms, thighs, neck, face, tail): shift the red to the turnaround's bronze-tan (roughly hue 8 to 20 degrees, saturation down by a third, slightly lighter) and keep the scale lines, so the orange cracks stand out against it; also check the emit map lights only the cracks.
2. **hair** (6.3 / 5.5, Meshy part edit; cause: mesh): Meshy part edit on the hair from the ears down: regenerate it from the turnaround back/side crop as 5-7 thick closed wavy locks reaching the waist, dark at the top fading to flame orange only in the last third, with no loose single strands.
3. **lava_cracks** (6.5 / 6.0, texture repaint; cause: texture): Repaint the boot colour and emit maps with the turnaround's crossing diamond lattice (about 5-6 diamonds from boot top to ankle, lines about 1 cm wide, bright orange-yellow with a brighter dot at each crossing) on both boots, and add the same glowing lines down the sternum, belly and hips.

Also under 7.0 in game: dress 6.5.

### Kael (game 7.4, close 6.8)

1. **sword** (6.0 / 5.5, bone placement; cause: animation): In the run clip hold the right arm chain (RightShoulder, RightArm, RightForeArm, RightHand) at the single pose of run frame f005 (blade low beside the right hip, tip trailing back and down) with only a few degrees of bob, so the blade direction changes by under 20 degrees per stride and never rises above the waist.
2. **hand_r** (7.0 / 5.8, bone placement; cause: animation): Key a closed fist on the right finger bones for the whole Idle and run clips (RightHandIndex/Middle/Ring/Pinky 1-3 curled about 70 degrees each, RightHandThumb1-3 about 40 degrees across the fingers) and curl the stray digit the same way in Attack, so the fingers wrap the grip in all three clips.
3. **face** (7.8 / 6.5, texture repaint; cause: texture): Repaint only the two eye areas of the face texture: clean white sclera, pale grey iris with a dark pupil and one sharp dark upper-lid line per eye, same size both sides, as in the turnaround front view; leave brows, scar and mask untouched.

### Albert (game 7.0, close 6.0)

1. **mast_flags** (6.3 / 5.0, weights; cause: weights): Set every vert of the right mast, yard and sail to 100% hips (same as the pole base), removing all pauldron.R, upper_arm.R and head influence, so the sail stays rigid and the black spikes disappear in lmb_launch and run_f.
2. **shield** (6.5 / 6.5, bone placement; cause: placement): Move the shield prop about 10 cm outward from hand.L along x_shield (away from the knuckles, keep anchor_shield_face on the board) so the whole fist sits behind the board in run_f and lmb_launch.
3. **anglerfish_lamp** (6.3 / 6.8, bone placement; cause: placement): Move the root of spring_hangfish_0 from the left yard tip to anchor_chest, about 20 cm to the character's right of the compass and 5 cm proud of the barrel, with the chain shortened to about 15 cm so the fish hangs beside the compass as in the turnaround front view.

Also under 7.0 in game: hand_l 6.8, leg_l 6.3, leg_r 6.3, outfit 6.5.

Note: The face close-up camera sits inside the helmet on this model, so the face close score is weak.

### Motley (game 6.8, close 6.4)

1. **void_body** (5.5 / 5.0, texture repaint; cause: texture): Texture repaint: on the base colour texture, repaint the whole area below the coat hem from black to a saturated violet starfield (deep violet about #2a0a5a to bright violet about #6a2fd0 swirl streaks with white star specks, as in the turnaround) and paint out the pale lilac patch, so it reads purple, not black, at the match camera.
2. **jack_box** (6.3 / 7.0, weights; cause: weights): Weights: bind every box and lid vert rigidly (1.0) to Hips and remove all LeftUpLeg/LeftLeg/LeftFoot/LeftToeBase and Right leg-chain influence from them, so the box stays upright directly under the body in run and Attack.
3. **coat** (6.4 / 6.0, weights; cause: weights): Weights: move the back coat panel verts (hem and tail roots behind the hips) off LeftUpLeg/RightUpLeg and LeftLeg/RightLeg onto Hips at about 0.8 with 0.2 Spine02, so the panel hangs down with the hips in Attack instead of sticking out.

Also under 7.0 in game: void_tail 5.5.

### Gil (game 7.6, close 7.2)

1. **outfit** (7.2 / 7.0, texture repaint; cause: texture): Repaint the cloth texture (coat and hat): dark plum base instead of charcoal, dots about 1.6x their current diameter in the turnaround's bright cornflower blue, so the dots are visible on the hat and shoulders from the match camera.
2. **swordfish** (7.4 / 7.0, bone placement; cause: placement): In warden_native.json (gil) change tilt.hand.R from -45 by about 30 degrees in the direction that lifts the bill, so in Idle the fish points about 30 degrees above level with the bill at chest-to-head height; re-check Attack 2/3 that the bill stays above the ground.
3. **face** (7.6 / 7.2, texture repaint; cause: texture): Repaint both eyeballs on the skin texture: off-white sclera, a green iris ring about 60% of the eye diameter around the black pupil, keep the white highlight; result is two big round green eyes readable at eye level.

### Tenzo (game 7.6, close 7.4)

1. **torso** (6.8 / 7.2, texture repaint; cause: texture): Repaint all bare-skin areas of the albedo (torso, face, bare arm, feet) from saturated orange to the turnaround tan-brown: cut saturation by about 35% and drop value about 10%, leaving the sash orange untouched so skin and sash separate at match view.
2. **outfit** (7.2 / 7.0, texture repaint; cause: texture): Repaint the pants area of the albedo to the turnaround's plum-maroon (raise value about 25-30% and add purple-red hue) and keep it matte, so the folds show and the pants separate from the dark hair at match view.
3. **eye_rocks** (7.8 / 7.0, bone placement; cause: placement): In the orbit_stones prop (orbit on Head) yaw each rock so its teal eye always points radially outward from the head and tilt it about 30 degrees up, so the glow shows from both the match camera and eye level.

## Caveats (read before acting on a fix)

- Warm cast. Four judges independently reported skin or metal reading too red or orange against the turnaround
  (Cinder, Tenzo, Sparkle, Albert), and each said it could be the light. The inspect stage has a sunset sky.
  Before any colour repaint from this list, compare one frame in a real match. If the cast is the stage light,
  Cinder and Tenzo each gain about half a point and their top fix drops out.
- Kit props. The inspect render does not run hunter kits. Grimble's `ball` bone is his dash junk ball, and
  Sparkle's gun is not attached, so those reads need a live match.
- Camera framing. On the three big contract hunters the face and hand close-up cameras sit inside the helmet or
  pack, and eye-level views crop the head. Their `close` scores are weaker evidence than the native ones.
- Three frames per clip. A pass-through between sampled frames can be missed (for example Neve's staff swing).
- Weights fixes name bones inferred from motion and the bone list, not read from the weight data. Check the
  weights in the file before editing.
- Brief against turnaround. Several part briefs in `hunter-regions.json` do not match the turnaround (Neve "bare"
  right hand and two bows, Tenzo "teal eye glow" under a blindfold, Lace "bow" as a hair bow, Gil and Kael weapon
  hand). The judges followed the turnaround. The briefs should be corrected.

## Lessons

- A stale score outlives the model it was given to: key every score to the glb blob, and drop it when the blob changes.
- A judge that only sees turnaround colour marks a warm stage light as a texture fault: render the judge stage in match light.
- A judge passes small companions ("reads as a sun") unless told what they must show: write the must-show in the part brief.
