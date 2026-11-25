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
