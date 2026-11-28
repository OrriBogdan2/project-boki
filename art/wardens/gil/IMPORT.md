# Gil (the Novice Mage): import note, v1 (2026-11-10)

`gil.glb` is the owner's Gil turnaround (refs in ~/meshy/gill/refs: gill_turnaround, gill_portrait) through the
ART-1 pipeline (docs/art/wardens/PIPELINE.md steps 5-9). Raw files in ~/meshy/gill/ (never in git).

    B="~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python"
    $B tools/meshy/bake_warden.py -- art/wardens/src/gil_bake.json        # s_g2 scan -> 30k low + 4096 atlas
    godot --headless -- --warden-rig-json --warden=gil                    # -> art/wardens/src/gil_rig.json
    $B tools/meshy/fit_warden.py -- art/wardens/src/gil_fit.json          # -> ~/meshy/gill/fit/fit.glb
    $B tools/meshy/gil_parts.py -- ~/meshy/gill/fit/fit.glb ~/meshy/gill/m_sf/glb.glb ~/meshy/gill/parts.glb
    $B tools/blender/decimate_warden.py -- ~/meshy/gill/parts.glb --tris=14000 --out=art/wardens/gil/gil.glb

- **Scan:** Meshy s_g2 (hat, polka-dot coat, satchel, striped curl-toe boots, the fish face). No new Meshy credits.
- **Rig:** the body numbers in BODY.json (size 1.0, head 0.71, legs 1.03, torso 1.0, shoulder 1.14, arms 0.92,
  hit_r 0.38) put the rig's joints on the scan's; they belong in content/archetypes/gil.json `body` (kit's file).
- **Fit:** slots by region + colour (cloth coat and hat, skin face/hands/legs, leather satchel and boot soles),
  14k body triangles, fit weights, ink room in COLOR_0 alpha, atlas 2048.
- **Swordfish (skinned, its own mesh):** Meshy's m_sf swordfish cut to 1.6k triangles, texture 1024, 0.74 m bill to
  fork, held by the root of the tail in the RIGHT fist, bill forward and down (as Kael's sword); weighted 1.0 to
  hand.R, material `metal-swordfish`. `weapon_empty` hides the procedural weapon; FX empties weapon_muzzle (bill
  tip), anchor_blade_mid and anchor_blade_root sit on hand.R. The kit may want `skinned_weapon` in
  content/rules/warden_anim/gil.json, as Kael has.
- **Fish tail and dorsal fin (turnaround; scripted, gil_parts.py):** a tapered tube from under the coat's back hem,
  down and back to a forked caudal fin at boot height (`skin-tail` / `skin-fin`), and a ray fin on the upper back
  (`skin-fin`, blue root to orange edge); both rigid on hips. Simple stand-ins: no spring bones, flat from behind.
- **Import:** `meshes/generate_lods=false`, `force_disable_compression=true` in gil.glb.import.

## v95 swap (2026-11-13, ext/showcase-1113)
`gil.glb` is now his v95 master (`~/meshy/v95/Gil/r2/v95a/cand_B.glb`, current.json, the first v95 face; its own
swordfish rapier left out: `gil_v95_B_body.glb`) on this file's skeleton and anchors, by `tools/art1/v95_swap.py` with
`art/wardens/src/gil_v95.json` (the game .glb before the swap is origin/main's v1):

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/gil_v95.json WORK art/wardens/gil/gil.glb

The master's real fish tail (on the `tail` bone) and dorsal fin replace the scripted stand-ins (`drop_meshes`: Tail,
Dorsal; their textures gil_Image_0.png and gil_gil_fin.png went with them). The skinned Swordfish mesh stays, its
texture now `gil_Image_0.jpg`. The satchel rides the hips (bone heat had put it on the right hand). 12.5k body
triangles, 2048 atlas. gil.glb carries no clips (the game keys his moves), so skin_relax is skipped and
`--stretch-check --wardens=gil` reports "no clips", as on the base. warden_model_check's `height_3d` is 0.9 (the
v95 hat stands lower than the v1 floppy one).

## Skinning, grip and ink fix (2026-11-19, ext/hunter-fix-gil-1118)
Gil has no clips (the game poses his rig), so every number is measured by skinning offline over 900 frames of the
real game's bone matrices (all 21 moves: idle x3, walk, run, stop, jump, jump_up, glide, land, both dashes, fall,
LMB, RMB, E + recast, X + leap, hit, death).
- Weights: the right arm uses the left arm's clean weight field, mirrored; the hand is 50/50 forearm.R + hand.R.
  Then a stretch solve over the frames (hand locked, no root weight, no cross-side bones, every UV-seam copy
  the same). Edges past 3x: live 3.95% -> 0.068%; past 2x: 7.71% -> 0.86%; worst 30.2x -> 5.3x; seam cracks 0.
- Grip: no finger bones, so the three right fingers are curled in the mesh (rest pose) round the swordfish's
  tail stalk; the thumb and the rest of the body are not moved. The swordfish (same 3000 triangles, same shape)
  is held at the tail, bill FORWARD as in the splash (fwd component 0.62 in idle, walk, run, glide, hit), set
  diagonally across the palm; rigid, weight 1.0 on hand.R (forearm.R and hand.R share one matrix in every game
  frame). Over the 1080-frame game dump it stays clear of head, hat and body everywhere except dash_ground
  272-288, where the dash pose itself puts this fist on the hat brim (open: a clip/HunterAnim matter).
- Cuffs (retry 5): the right forearm, cuff and hand (right-arm-dominant verts below y 0.66) follow forearm.R
  only, blending back to the solved weights by y 0.80. The inner cuff had 66% upper_arm.R and up to 49% torso,
  which smeared the cuff band when the arm was raised. Edges past 3x: 0.068% -> 0.05% (live 3.90%).
- Ink: COLOR_0 is now RGBA on the body and the swordfish. Alpha holds the ink room (`fit_warden.ink_room`, 0.02 m),
  as on the other v95 Hunters. Before this the outline shell grew full width everywhere and poked through
  thin and folded parts as black specks.
- Not changed: textures, materials, UVs, skeleton, bind matrices, every body vertex except the right fingers.
  The hat brim keeps the scan's notches.

## Native model r6 (gil_meshy.glb)
- Hat (brim and cone) texels recoloured from charcoal to dark navy, blue floor above the toon shader's dark_lift (0.07 linear; anything darker is lifted to neutral grey). Texture is now `gil_meshy_r6.jpg` (4096, q90, 4:2:0).
- Attack: LeftArm/LeftForeArm re-keyed again, closest left hand/forearm to head and hat 0.021 -> 0.098 m. Other clips, mesh, UVs, skin and ink room unchanged from r5.

## Native model r7 (gil_meshy.glb)
- Swordfish: `scale hand.R 1.3` (uniform), grip in the palm at the tail stalk, bill 2.5 deg off forward and 18.6 deg up in Idle; fish length/body ratio 0.998 -> 0.756 of the splash.
- Dorsal fin (`skin-fin-back`, hips, 1,100 tris, scale 0.75) and head crest (`skin-crest`, head, 900 tris) are Meshy create parts placed by `tools/art1/gil_fin_crest.py` (gil.glb), listed in `props`; ink room 0.02 m, magenta outline test clean on both.
- The 630-vertex strand island behind the nape (1,171 tris) is cut from `Body` (index data only; verts stay in the buffer).
- Rig: `Tail` bone under Hips (`glb_add_bone.py --from LeftUpLeg,RightUpLeg --behind -0.18`), swings 15 deg back in Idle/walk/Attack/Hit; the tail verts used to follow the thighs. Arms re-keyed off the thighs, torso and head in Idle/walk/run/Attack; new `Hit` clip and a slash `Attack` (`clips.hit`, `attack_rate` 2.0 unchanged).
- geo_check vs main: hand_R/thigh_R held 8.7 cm -> 0 in Idle/walk/run/Attack, forearm_L pairs 0. Unchanged from main: Jump_Run and Crouch arm/torso pairs, run shin_L>thigh_R 13.4 cm (Meshy). New: outfit:tail>foot/shin 3.3 cm in Jump_Run (the tail verts now stay with the hips).
- Not done: texture candidate (credits spent past the 250 cap on fin/crest); shoulder roll beyond the arm re-keys; the hand cannot close (no finger bones).

## Native model r8 (gil_meshy.glb)
- Tail: the 965 tail verts get main's JOINTS_0/WEIGHTS_0 back (Meshy thigh weights). r7's partial move to `Tail` tore the ring on every leg swing (run 110 spike edges, crouch 238). Now run 31 / walk 15 / crouch 111 (main 33 / 15 / 138). The `Tail` bone stays in the rig with zero weight; its keys move nothing.
- Swordfish: `scale hand.R` 1.3 -> 1.6 (fish length 0.756 -> ~0.93 of the splash ratio). Attack and Hit right-arm re-keyed (`r7/tools/rightfish.py`) so the bigger fish clears the head: Hit 0.003 -> 0.049 m off the head mesh, Attack sampled frames >= 0.043 m (one in-between pass to 0.008 m, no contact).
- Legs: run LeftUpLeg 3 deg / RightUpLeg 6 deg out (about the forward axis). geo_check vs main: run shin_L>thigh_R 13.4 cm -> 0, held worst 6.8 cm (run foot_R>thigh_R), nothing worse than main.
- Not changed: mesh, UVs, textures, fin/crest parts, other clips. Still open: fin recolour, closed grip, Jump_Run forearm>torso 8.8 cm, Crouch hand/forearm>thigh holds.

## Native model r9 (gil_meshy.glb)
- Back fin and coat: live's skin-v95 index list is back (the 1,171 triangles r7 cut were live's own dorsal fin; the cut left 95 open edges down the coat back). Open edges 95 -> 0; vertex data is byte-identical to main.
- The Meshy `skin-fin-back` / `skin-crest` props and `tools/art1/gil_fin_crest.py` are gone; gil.glb and its textures are main's again.
- Kept from r8: tail weights, Tail bone (zero weight), arm/leg re-keys, Hit clip, swordfish scale 1.6.
- Grip (r9b-d): `grip.hand.R` turned so the bill leads (hammer grip, tail stalk in the palm). Bill yaw off forward, median: Idle 79 -> 31 deg, walk 85 -> 28, run 114 -> 37, Jump_Run 112 -> 11, Crouch 86 -> 15. Bill-back frames: run 50% -> 17%, Jump_Run 60% -> 0%. Hit stays bill-back (94%, a recoil).
- Attack: RightArm/ForeArm/Hand re-keyed (`hunter-round-1124/gil/r9/tools/attacksweep.py`, `fadeback.py`): wind-up over the right shoulder at 0.30, bill sweeps past the front at 0.47, follow-through to his left at 0.58, eased back to the original keys over 0.80-0.95 (no pop into Idle).
- Right-arm clearance (`r7/tools/rightfish.py`, SIDE=Right) on run, Jump_Run, Hit and Idle. Closest fish-to-body min, before -> after: run -0.009 -> 0.007 m, Jump_Run -0.007 -> 0.021, Hit -0.010 -> 0.033, Idle 0.030 -> 0.040. Fish-to-head min: Attack 0.038, Hit 0.039.
- geo_check vs main: worst held 7.2 cm (Jump_Run forearm_L>torso; main 13.6). HAND L/R ok.

## Native model r10 (gil_meshy.glb)
- Back fin colour: live's fin texels kept. A Meshy retexture of the fin island (8 variants, `r10/fin/`) rendered hot pink at game view (art-gate fin 3.5 vs live 5.5, GAME 5.3 vs live 5.6), so the atlas is the r9/live one again (r10b). Next try must match the turnaround's orange membrane + blue rays under game light before shipping.
- Attack re-keyed on hand position (`hunter-round-1124/gil/r10/tools/handkey.py`, hips-local targets): wind-up hand at the right shoulder (y 0.41, 0.10-0.30 s), strike forward-down (0.40-0.55 s), follow-through to his left by 0.60 s, eased back to the original keys over 0.86-1.0 of the clip. Fish >= 0.03 m off head/hat, left arm and body in every frame (r9 had one -0.03 m frame).
- run: bill kept forward (tip z 0.68-1.29) and the tip under the brim (tip y <= 0.71 hips-local, was up to 1.23 vertical across the face); hand path unchanged (within 3 cm).
- Hit: the fish drops low by the right hip, bill forward-down (hand y 0.55 -> 0.15), not lifted overhead; forearm/hand >= 1.5 cm off the thigh/torso.
- Idle/walk: LeftArm in (hand x 0.44 -> 0.38 Idle, 0.41 -> 0.34 walk).
- geo_check vs main: held worst 6.8 cm (main 13.4), clipped frames 61 (main 159, r9 59). Attack clip pairs drop (upper_arm_R>thigh_R 4.8 cm gone); Hit has none.

## Native model r11 (gil_meshy.glb), 2026-11-25
- Hit clip slot dropped from `content/rules/warden_native.json` (the re-keyed Hit locked the body 1.63 s); the WardenFlinch layer plays, as on live.
- Left arm: r10's LeftArm/ForeArm/Hand keys slerped back toward live (`hunter-round-1124/gil/r11/tools/blendtrack.py`): Idle 35% of r10 (max off live 23 deg, r10 64), walk/run 55% (29/19 deg). Full live keys bring back held forearm_L>torso 8.2 cm in Idle.
- Attack re-keyed again (`r11/tools/handkey.py`): wind-up hand y 0.40 -> 0.35, bill ends forward (hips-local x 0.00-0.07 at 0.57-0.63 s, was +0.6 to his left), arm turn max 176 -> 40 deg.
- Fin: 12 Meshy edits + 40 retextures of the fin island (`r11/fin/gen_log.tsv`), auto hue gate (coral 0-40 deg >= 25%, pink 290-355 < 5%, blue rays >= 10%): 0 pass (coral comes only with 11-24% pink). Live's fin texels kept. Meshy balance 1946 -> 1244 (account-wide).
- geo_check vs main: held worst 6.8 cm (main 13.4), clipped frames 110 (main 159, r10b 61), held frames 76 (main 97).

## Native model r12 (gil_meshy.glb), 2026-11-25
- Fin colour: r11's Meshy edit v270_p2, fin texels only (`hunter-round-1124/gil/r12/fin/atlas_e2.png`): mean RGB 139/151/178 -> 136/99/112, coral webs and blue ribs. Hue gate: coral .48, blue .38, pink .067 (limit .05, missed).
- Fin weights: per-height coat weights under the fin root instead of a Head blend (`r12/finskin2.py`), so the fin moves with the coat. Shear mean .085 -> .039, max .314 -> .085. Root gap p95 max .032 -> .034 (about the same).
- Hat brim: numpy mesh repair, not Meshy (`r12/build.py`): rim pulled round, normals smoothed. Rim deficit max 2.32 -> 0.88 cm.
- Nothing else changed: face, hands and swordfish vertices, UVs and weights equal r11.
- geo_check same as r11: held worst 6.8 cm, 110 clipped frames, 76 held.
- art-gate GAME: 7.1 vs live 6.3 (3 sheets, context text described the fixes) and 6.0 vs live 5.7 (4 sheets, neutral text). 7.0 bar not confirmed.
- Open: dark pocket at the fin base in head-turn frames, fin edge-on from behind, near-black robe, small brim ticks.

## Native model r13 (gil_meshy.glb), 2026-11-25
- Swordfish: RightArm/ForeArm/Hand re-keyed in Idle, walk, run, Jump_Run, Attack (`hunter-round-1124/gil/r13/tools/rekey.py`). Fish-to-head min, r12 -> r13: Idle .067 -> .142 m, walk .189 -> .336, run .129 -> .148, Jump_Run .05 -> .152, Attack .038 -> .149. Max face coverage 19/3/14/57/27% -> 0/0/0/4/1%.
- Robe and hat: Meshy retexture texels (30 candidates, `r13/tex/gen_log.tsv`) on the robe/hat islands; plum with bright blue dots. Face and fin texels are r12's. Atlas JPEG quality 90.
- Toon slots: robe/hat triangles that sat in the leather/skin prims moved to cloth (`r13/tools/rig13.py`: 469 + 481), 59 skin -> leather. Prims 22216 / 8733 / 29051 tris, 60,000 total. Removes the pale shards on the coat.
- Back fin weights (`r13/tools/finharm.py`): harmonic blend from the coat weights at the root (screen .02, spread 3 cm). Replaces r12's rigid per-height weights, which opened a dark pocket at the root. Fin-zone tris stretched >3x, linear 0-5 cm blend -> this: Idle 22.5 -> 6, walk 1.3 -> .7, run 11 -> 4, Attack 60 -> 28.5.
- geo_check same as r12: worst 7.2 cm, 110 frames, held 76, held worst 6.8 (main 13.6 / 159 / 97 / 13.4); hands ok. glbstretch spike frames: Attack 2/22, Idle 0/60, walk 2/15 (as r12); Jump_Run and Crouch equal main or 1 frame under.
- art-gate neutral, 5 match sheets: GAME 6.6 vs live 4.9, FAIL (7.0 bar).
- Open: the coat and fin crumple in the back-view attack wind-up (0.0-0.3 s). Damping spine/shoulder/neck/leg keys does not help (`r13/tools/atkdamp.py`: folds 2209 -> 2095 at best); it needs new coat weights around the shoulders. Also pale grey coat patches, dark satchel, teal face.

## Native model r16 (gil_meshy.glb), 2026-11-26
- Coat normals only: r14/r15 bent the cloth normals up (coat Ny mean +0.32..+0.39 vs geometric ~0; live ~0). In crouch the forward-tilted skirt then faced the key/top light and read silver (review T1). Below the waist the stored normals go back to the welded geometric normals, full at y<0.75 m, fading out by 0.90 m (`hunter-round-1124/gil/r16/tools/nflat.py`). Skirt Ny mean +0.32 -> -0.02.
- The chest/shoulders keep the up-bend: flattening them too (N2) let the shader's fresnel grey the upper back at the match camera (art-gate 6.4).
- Nothing else changed: positions, UVs, weights, atlas (r15 jpg, byte-identical) and animations equal r15. geo_check / stretch unchanged.
- Dark Meshy re-textures from the 11-19 turnaround (8 gens, `r16/tex/gen_log.tsv`) rendered flat grey under hero_toon (low-saturation near-black) or lost the dots/trim; none used.
- art-gate neutral, 3-row sheets (new|r15|live), 5 match sheets: GAME 6.8, r15 6.7, live 4.6. 7.0 bar not met.
- Open: face and fish mouth hidden under the brim at the match camera (5.5), grey fresnel patch on the back-left coat at top-down, flat charcoal brim.

## Dorsal fan prop r19 (gil.glb + warden_native.json), 2026-11-26
- Why: since r9 dropped r7's Meshy fin/crest props, rounds r10-r18 only re-textured or re-weighted live's thin strip fin; fin/fin_head stayed 6.2-6.5.
- gil.glb = r7's (blob 0ecf9d95b2: Meshy create parts `skin-fin-back` + `skin-crest` on main's contract body), with the fin texture (image 2 only) recoloured from red-orange to the turnaround's pale peach membrane and light-blue rays (`hunter-round-1124/gil/r19/tools/fintex.py`). The import extracts the three embedded textures as gil_Image_0*.jpg.
- warden_native.json: `skin-fin-back` hangs on hips -> Spine02, nothing cut from gil_meshy.glb (no open edges; live's strip stays inside the fan). Grip pins the fan root (part [-0.001, 0.412, 0.337]) onto the coat back at nape-to-mid-back height (bone [0.001, 0.221, -0.161]); scale [1, 1, 0.7] flattens its depth about the root. r7's own seat floated the fan 0.13 m off the coat and up to the brim. The crest is not hung (it floated behind the head and is not in the turnaround).
- gil_meshy.glb unchanged from r18, so geo_check = r18: worst 12.0 cm, held worst 5.6 (live 13.6 / 13.4); hands ok.
- art-gate (3-row match sheets, new | r18 | live): GAME 7.8, r18 7.5, live 5.2, PASS. Vs r18's own art-gate (GAME 7.8): fin 7.0 -> 7.4, fin_head 7.0 -> 6.8 (run noise ~0.4); vs the Fable review of r18: fin 6.5, fin_head 6.2.

## Dorsal fan reseat r20 (warden_native.json only), 2026-11-27
- Why: the Fable review of r19 found the fan's front spike rising up through the hat brim in crouch walk and at the jump apex. r19 seated the fan root at the nape, right under the brim.
- Fix: hips grip bone y 0.221 -> 0.021 (the fan sits ~22 cm lower on Spine02, at shoulder-blade height like the turnaround). Same size, scale and tilt. No glb changed.
- Tried: dy -0.08/-0.12/-0.15, with tilts -0.25/+0.2 rad. Only -0.20 cleared the brim in back-view eye renders of every clip (5 yaws x 8 clips x 3 frames).
- art-gate (3-row match sheets, r20 | r19 | live, all re-rendered with the same moving-crouch audit): GAME 7.2, r19 6.5, live 5.0, PASS. Fin 6.0 -> 6.5, fin_head 6.5 -> 7.0 in the paired runs. An earlier run with stale r19/live rows gave 7.0 / 6.5 / 5.0.

## Crouch carry r21 (gil_meshy.glb anim + warden_native.json), 2026-11-27
- Why: the Fable review of r20 found the swordfish hanging bill-down in the crouch walk. A live probe gave the crouch bill 17-35 deg below level, tip at shin height. Every other clip is level (y -0.05..+0.3). Cause: `crouch_arms_from: walk` lays walk's arm keys over the crouch's forward-bent spine.
- Fix (rig only, no mesh/UV/texture change): Crouch_Walk_with_Torch now carries walk's 24 arm tracks, baked as WardenNative._arms_swapped does (times x 1.031). RightForeArm is re-pitched per key so the bill sits 6 deg above level, heading kept (tool: gens/hunter-round-1124/gil/r21/tools/crouchfix.py). `crouch_arms_from` dropped for gil only.
- Probe after: crouch bill y +0.10 at every sample, tip above the hips. geo_check: worst 12.0 cm, held worst 5.6, hands ok (same as r20). Crouch hand_L>thigh_L 5.4 cm is walk's left arm on the crouch, as the runtime mix already played.
- art-gate (3-row match sheets, r21 | r20 | live): GAME 7.3, r20 7.0, live 5.0, PASS.

## Left-hand clear r22 (gil_meshy.glb anim only), 2026-11-27
- Why: the art-gate caution on r21: geo_check hand_L>thigh_L 5.4 cm and forearm_L>thigh_L 4.1 cm in the crouch walk (live 0.0 / 2.6), because walk's left arm now rides the crouch's forward-bent hip.
- Fix: Crouch_Walk_with_Torch LeftArm rotated 10 deg about world z per key (tool: gens/hunter-round-1124/gil/r22/tools/leftfix.py). No mesh/UV/texture change.
- geo_check after: no hand/forearm pair worse than live; worst 12.0 cm, held worst 5.6 (shin_R>thigh_L, same as r19-r21, live 13.4). Hands ok.
