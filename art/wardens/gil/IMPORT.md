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

## Regen 11-20 r2 candidate A (DRAFT, owner visual check; ext/hunter-regen-gil-1120)
Body: a new Meshy multi-image-to-3d (meshy-7.1, A-pose) from the 11-19 turnaround views with the live open fish grin
(gens/hunter-regen-1120/gil/r2/gen/b5: grin front/3-4/side + arms-clear back), quad remesh 60k (119k tris), then

    python3 tools/art1/v95_to_game.py Gil --weights meshy --spec art/wardens/src/gil_regen1120/r2_b5.json --tris 96000
    blender -b --factory-startup --python tools/meshy/gil_parts.py -- --fish-only art/wardens/gil/gil.glb FISH.glb art/wardens/gil/gil.glb --len 1.2 --pitch 60

(`--tris 96000`: the head band keeps all its ~7k triangles and the body gets ~53k, 59.5k in all as live's 60k; the
default 60000 left 39.7k.) The spec's joints are measured off the mesh, the arm's own elbow and wrist included
(`v95_regen_spec.py --joints`). One connected body, no loose parts, 24 open edges.
Swordfish: a new Meshy fish from the live splash's swordfish (gens/.../r2/fish: splash crop -> image edits with the
long bill -> multi-image-to-3d s7 -> Meshy remesh to 4k triangles, texture rebaked by Meshy), 1.2 m (the splash: about
0.7 of his height; the old one was 0.74 m), held at the palm of the right hand on the palm's own bone, 60 degrees under
level at rest so the game's idle and thrusts carry it level and forward. Its texture is `gil_swordfish.jpg`;
`gil_Image_0.jpg` (the old fish's) is gone. The old fish rode a bone point under the hand (live skins the hand to
forearm.R), so it floated below the fist in every pose.
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

## Regen 11-20 r3 candidate A (DRAFT, owner visual check; ext/hunter-regen-gil-1120)
r2's A had a long flat tail and a spiky back fin (from the 11-19 turnaround; neither the splash nor LIVE has them).
r3: the four turnaround views edited with Meshy image-to-image (nano-banana-pro) to remove ONLY the tail and back fin
(gens/hunter-regen-1120/gil/r3/edit, 12 edits), 6 new Meshy multi-image-to-3d gens (r3/gen/c1-c6, all tail-free),
c3 picked (open grin), quad remesh 60k, then as r2:

    python3 tools/art1/v95_to_game.py Gil --weights meshy --spec art/wardens/src/gil_regen1120/r3_c3.json --tris 96000
    blender -b --factory-startup --python tools/meshy/gil_parts.py -- --fish-only art/wardens/gil/gil.glb FISH.glb art/wardens/gil/gil.glb --len 1.2 --pitch 60

Body 58,545 tris + swordfish 4,048 (r2's fish, 1.2 m). Open on main's Meeko-clip animation (PR #461): the Meshy-rig
sleeve stretches into a black bar in surfacing/thrust/E, and the fish's bill points down in idle (pitch 60 was tuned
for the old procedural poses).

## Regen 11-20 r3b candidate A2 (DRAFT, owner visual check; ext/hunter-regen-gil-1120)
Same Meshy body as r3 A (c3: no tail, no back fin, open grin) and the same 1.2 m swordfish; no new Meshy credits.
r3 A's black sleeve bar had two causes, both measured over the game's own frames (`clip_shots --proc --bone-dump`,
393 frames at 30 fps over all 14 moves; skinned offline as the game does):
- **Game code:** WardenSync wrote the clips' hand position onto the rig's Hand nodes and it rode into the next
  HunterAnim move: from the first kmove on, hand.R/hand.L sat 0.7 m off the forearm (GPU dump), so the swordfish
  floated (LIVE too) and the hand dragged the sleeve after it. Fixed in warden_sync.gd (hands go home each step): 0.00 m.
- **Fit:** this body's right arm is bent forward in a held pose (Meshy's auto-rig: the right wrist 0.3 m ahead of the
  mirrored left), but the spec mirrored the left arm's joints onto it. `r3_c3b.json`: arm joints from Meshy's auto-rig,
  `mirror_arm` "R" (the right arm swings down onto the rig like the left).

    W=gens/.../gil/r3/cand/workc_c3 (work_c3's meshy/ rig and spec with r3_c3b's joints + mirror_arm, game.glb = main's)
    blender -b --factory-startup --python tools/art1/v95_swap.py -- $W/spec.json $W $W/gil.glb
    blender -b --factory-startup --python tools/meshy/gil_parts.py -- --fish-only $W/gil.glb FISH.glb F.glb --len 1.2 --pitch 15 --yaw 30
    python3 tools/art1/glb_relax.py F.glb gil.glb --poses=DUMP.json --only=Body.002 --no-rip --rigid=hand.R:0.05

- Weights relaxed over the game frames (weights only, no ripped triangles; the right fist wholly on hand.R).
  Body edges past 3x over all moves: r3 A 4.16% (worst 30.6x) -> A2 0.35% (worst 7.3x); LIVE 0.44% (17.1x) with the fix.
- Swordfish 15 degrees under level, bill swung 30 degrees out at rest (was 60 under): under main's borrowed Meeko
  clips the old angle drove the bill 0.4-0.55 m into the floor in walk/run. Now its lowest point is at the soles in
  every move; bill forward share (median) idle 0.62, walk 0.32, run 0.71, thrust 0.41, lunge 0.55 (was 0.34/0.75/0.68/0.85/0.95).
- Body 58,541 tris + swordfish 4,048.

## Regen 11-20 r4 candidate A (DRAFT; ext/hunter-regen-gil-1120)
r3 failed the art-gate (stretched forearm, black sleeve bars, swordfish through the head). No new Meshy gen (balance 3 credits):
the body is r3b A2's (r3 c3 body, arm refit onto the rig, forearm/sleeve weights relaxed over the game's frames with the
WardenSync fix, so hand.R follows the forearm and main's hand-made forearm-led sleeve rule holds), plus two fixes:
- Fish re-seated in the fist: A2's fist centre (0.197, 0.407, -0.03), rigid on hand.R, turned (`tools/art1/gil_fish_rot.py`) to 60 degrees
  under level, 40 out, in rest space. Over the 393 game frames the bill points forward (median fwd share) idle 0.63, walk 0.49, run 0.55,
  thrust/lunge/potion 0.95, jump 0.23, hit 0.35; in front of the face in 2% of frames (was 33% at 70/20 on the forearm trial); one
  run frame within 5 cm of the coat (the swing), none at the head.
- Tail fin back: `gil_parts.py --tail-only` adds the live model's fish tail (tube + forked fin, bone `tail`, 112 tris); no dorsal blade.
- Stretch (14 moves x 393 frames, body mesh, fixed game code): LIVE worst 17.1x, mean of moves' worst 10.3x, edges over 3x 0.441%;
  r3 30.6x / 17.7x / 4.16%; r4 7.3x / 4.3x / 0.347%. All 14 moves are still over the game's 1.3x at the coat hem and thighs.
