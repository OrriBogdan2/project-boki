# Vex (gunslinger): import note

## LIVE v95 master in game (2026-11-12, ext/hunters-v95-ingame)
`~/meshy/v95/Vex/r2/prop1111/cand_A.glb` (CURRENT_OVERRIDES 11-12), the muzzles still on forearm.R (anchor_bones). Was appeal3 body b below. 13.1k tris, one 2048 atlas, 39 clips.
Spec `art/wardens/src/vex_v95.json`; proof sheet ~/meshy/v95/_closeups/ingame-1112/sheet.jpg.

Re-keying a clip without vex.blend (11-13, ext/anim-vex-rekeys): `blender -b --factory-startup --python tools/art1/vex_rig_only.py -- art/wardens/src/vex_rig.json rig.blend`, then
`blender -b --python tools/art1/vex_clips.py -- rig.blend new.glb rmb,dash,dash_ex`, then `python3 -I tools/art1/glb_add_clips.py vex.glb new.glb dash,rmb`
(the prefix `dash` also takes `dash_ex`, so bake both). Re-baking lmb and e this way matches the live GLB to 1e-6; the braid's constant tracks are not re-written.

## v95 swap, appeal3 body b (2026-11-10, ext/vex-appeal-b): the current vex.glb

The mesh is the v95 master in the owner's appeal3 look, body variant b (owner pick 11-10: fuller bust, waist 3% narrower,
the left jacket flap lying on the belly, a stray hair strand by her right eye tucked behind the skin) with the
owner-approved round-2 face: ~/meshy/v95/Vex/r2/appeal3/cand_b.glb (pick.txt beside it). It is put on this rig by
`tools/art1/v95_swap.py` with `art/wardens/src/vex_v95.json` (docs/art/wardens/V95_SWAP.md). The skeleton, the clips, the
anchors (moved through the fit) and the coin (`keep`) are unchanged; the minigun is rigid on forearm.R. 13.1k tris, one
embedded 2048 atlas (Godot's import extracts it to vex_atlas.jpg), no normal map. Shots: docs/shots/vex-appeal-b/.
Fix over round 2's spec: the gun hangs against her right thigh at rest, so the trouser's outer side, its cargo pocket and a
hip flap were weighted to forearm.R and lifted with the gun in the shoot clips as a dark panel. A `hips` region (the flap),
a `thigh.R` region (`in_segs` thigh.R 0.17: the trouser) and `detach` forearm.R from thigh.R/hips/shin.R keep them on the leg.
Limits: the barrels no longer spin (the gatling bone has no mesh), and the braid is rigid on the head.

## Previous build: v2 design (2026-11-06)

`vex.glb`: the owner's locked v2 redesign (briefs/art-refs/vex_v2/: index.md, master_sheet, turnaround), on the shared armature, under 15k
triangles (10.7k), six material slots, one 2048 atlas plus its normal map (build outputs; the v95 swap dropped vex_normal.jpg, and vex_atlas.jpg is now the new atlas), hand-keyed clips (docs/art/wardens/CLIPS.md, content/rules/warden_anim/vex.json).
Raw files in ~/meshy/vex_v2 (never in git); the Meshy tasks and credits are in docs/art/wardens/PIPELINE.md.

    python3 -I tools/meshy/meshy_task.py edit ...      # body views: bald, minigun and coin chain out; head views from a head sheet; prompts in ~/meshy/vex_v2/edit.sh
    python3 -I tools/meshy/meshy_task.py create ~/meshy/vex_v2/runA in/front.png in/left.png in/back.png --texture-refs in/*.png
    python3 -I tools/meshy/meshy_task.py create ~/meshy/vex_v2/hrunA hin/front.png hin/left.png hin/back.png hin/tq.png --pose ""
    godot --headless -- --warden-rig-json --warden=gunslinger     # after any body change
    ~/meshy/vex_v2/build.sh [source|shape]                         # tools/art1/vex_source, vex_headscan, vex_finish, vex_clips

Anatomy (owner): her right forearm IS the minigun from the elbow down, no hand. `upper_arm.R` is her own arm in the jacket sleeve; `forearm.R`
carries the whole gun rigid (hand.R follows it, unskinned), so aim = arm pose: the brass cuff over the elbow, the receiver with its side boss,
six barrels on `gatling` (spins), the ammo drum under the receiver, the ribbed belt loop over the top, the chain with the bullet charm. The left
forearm and hand are brass machine parts, rigid per bone, with the gold coin on `coin`. The stickers, the trousers' green splatter and tally marks,
the shoulder tattoos and freckles are texture. The gold coin hip chain is rigid on `hips`.

v2 has no launcher tube: the `launcher` bone stays for the clip set and carries no mesh; `launcher_muzzle` sits on its pivot (the swing leaves
it in place) at the drum's mouth, the same spot as `launcher_fire` on `forearm.R`. Nothing leaves from there now: the coin (RMB) and
the Palm Lance (E) leave her left palm (owner, 11-17 playtest).

Cast clips (11-17): `vex_cast_clips.glb` is a clips-only file (her rig's nodes and skin, no mesh, material or image) with `coin_flick`
(0.5 s: the left hand flicks the coin out, the gun arm down) and `palm_cast` (1.07 s: the left arm up, palm out, the gun arm down).
The game adds them to her library at load (warden_anim `clip_files`, `scripts/heroes/warden_clip_file.gd`), so `vex.glb` is never
re-exported for a clip. Built by `python3 -I tools/art1/glb_clips_only.py art/wardens/vex/vex.glb <source.glb> rmb=coin_flick,e=palm_cast
art/wardens/vex/vex_cast_clips.glb`, the source being the 11-13 coin build of her glb (commit 775e4a78e3b, clips `rmb` and `e`).

FX points (empties on bones): `gatling_muzzle` (= `weapon_muzzle`), `launcher_muzzle`, `launcher_fire`, `anchor_gatling_root`, `anchor_sleeve_mouth`
(the cuff's top), `anchor_grenade_drum`, `anchor_eye_glow` (= `anchor_lens`: her mechanical left eye; nothing glows there), `anchor_spine`,
`anchor_coin`, `anchor_left_hand`, `anchor_pack` (her left shoulder blade), `anchor_chest`, `anchor_head_top`.

Head: a separate Meshy scan of a v2 head sheet, placed on the body by its eye line and chin (H_EYE, H_CHIN in build.sh, read on the scan's
gridded front render); the scan's braid is cut and rebuilt on the spring chain. Gun length elbow to muzzle 0.55 m = 31% of her height
(the turnaround: about 30%).

walk and run b, l, r, fl, fr, bl, br (2026-11-11): `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- art/wardens/vex/vex.glb OUT.glb 2.1 4.55`,
then `python3 tools/art1/glb_add_clips.py art/wardens/vex/vex.glb OUT.glb walk_b,walk_l,walk_r,walk_fl,walk_fr,walk_bl,walk_br,run_b,run_l,run_r,run_fl,run_fr,run_bl,run_br`
(judge: docs/art/wardens/dirloops/JUDGE.md).

NOT APPLIED on main (11-16 merge): the diagonal and re-baked back/side loops (walk_/run_ fl fr bl br, b l r) described here were baked into the old model's glb with a walk_f/run_f of a different length than main's v95 clips, so main's glb and warden_anim json are kept. Re-bake: `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- SRC.glb OUT.glb WALK RUN` on main's glb, then `glb_add_clips.py`, then restore the json map from ext/anim-dirloops-lace-kael.

Face pass (2026-11-18, ext/faces-ship-1118, owner "upload all of these"): vex-face3d-r2 c_4 ("A") texture-only: `python3 -I tools/art1/face_swap.py art/wardens/vex/vex.glb /home/boki/meshy/vex-face3d-r2-1118/final/c_4.glb /home/boki/meshy/v95/Vex/face1117/alive1117/cand_A.glb OUT.glb` blends the changed face pixels into the embedded 4096 `v95` image (hair shade A and the rest stay as game; mesh, rig, clips, gatling untouched).

## Tearing fix 11-19 (ext/hunter-fix-vex-1118, retry 6): weights only, no split, no caps
Cause: the left forearm and hand only join the rest of the mesh at the elbow (a graph cut on the welded mesh finds one 50-edge
ring there), but live weights put 30-70 % hand/forearm weight on the left hip/thigh skin and 30-40 % hip/thigh weight on
the hand. So clips drag hip skin after the hand (black/orange curtains from hip to hand) and leave the hand on the hip.
Fix (scripts in /home/boki/gens/hunter-fix-vex-1118/retry6/tool/: `seg2.py c1.json` labels, `build_ns.py lab.npy out.glb n3.json`):
- In the box x -0.45..0.08, y 0.56..1.32 m only. Forearm/hand verts (graph-cut label): arm-chain bones only. Hip/thigh verts:
  their forearm/hand weight moves onto their own hips/thigh share (never onto the chest bone `head`). Stripping fades out over
  y 1.20..1.30 so the elbow and sleeve stay continuous. Every vertex outside the box keeps its live weights bit for bit.
- Same vertices, triangles, positions, normals, UVs, colours, texture, skeleton and clips as live (48236 verts, 60095 tris).
- Rest pose: Blender 4 sides x 4 zooms (full, eye, knee, hip): at most 1 px of 250k differs. (The live-audit bind shot only caught the boot logo.)
- Edges >= 8 mm over 3x: 1.005 % -> 0.134 %; worst 10.16 -> 5.22; edges growing > 10 cm 286 -> 60, > 20 cm 11 -> 0.
  Seam verts open > 10 cm 156 -> 156 (as live), open boundary edges 189 -> 189. tools/stretch_check.gd worst 10.16 -> 5.53,
  35 clips better, 0 worse. hunter_mesh_check stretched tris 524 -> 120, no new warning.
- Changes on purpose: in idle/stance the left hand now sits where hand.L puts it (on the hip, fingers visible) and the gold bead
  chain stays on the trousers (live dragged it with the hand); the black spike at the left hip from behind is gone.

## Tearing fix 11-20 (same branch, deep pass): gun-mount junk follows the gun
Right side: between the jacket cuff and the ammo belt the scan has blade-like leather/skin sheets (folded-back fins) and small
junk patches that were weighted to hips/thigh.R, so every clip that moves the gun arm left them hanging at the hip (the dark
needles above the gun in idle, the floating tan chunk at the hip in run/glide).
Fix (scripts in /home/boki/gens/hunter-fix-vex-1118/deep/tool/: `folds.py`, `blade.py 0.03`, `finsel.py`, `debris.py`,
`finsplit4.py ns3.glb fin_b.npy upper_arm.R,forearm.R,hand.R,gatling,launcher out.glb 8`):
- 629 fin/junk triangles (fold edges grown over big flat triangles, plus the patches that already broke off as islands).
- Where they touch the hip skin their 256 vertices are duplicated; every fin vertex not already on the arm takes the
  distance-blended weights of its 8 nearest sleeve/gun vertices (>= 95 % on the right arm chain). Nothing deleted: 60095 tris, positions, UVs, normals, colours,
  texture, skeleton and clips as before, so the bind pose is identical (48236 -> 48492 verts).
- The left-side retry 6 weights are kept as they were.
- Numbers (live -> this glb): edges >= 8 mm over 3x 1.005 % -> 0.134 %, worst 10.16 -> 5.22 (numpy, 41 glb clips x 24 samples);
  tools/stretch_check.gd worst 10.16 -> 5.53, mean clip worst 5.02 -> 3.85, 35 clips better, g_laugh 1.76 -> 2.00;
  posed loose islands (seams joined within 5 mm) 373 -> 159 tris; hunter_mesh_check stretched tris 524 -> 120 (WARN cleared),
  spike_edges 188 -> 188 (bind-pose scan slivers, untouched: no remodel).

## Left hand re-bind 11-23 (ext/vex-hands-1123, on top of #360): the hand hangs on its bones
Owner 11-23: "mostly issues with ... hands for Vex". Cause: v95_swap.py keeps everything past the wrist rigid in the master's
pose (`past_wrist`), and the master holds the left hand flat, pointing 62 deg out from the hip, while the rig's hand.L ->
fingers.L hang straight down. So the mesh fingers sat 15-25 cm from the bones and the coin (bound under them), bone heat gave
them to thigh.L (live: 61 % thigh, 22 forearm, 17 hand), #360 moved that to forearm/hand 56/44 (the wrist shears), and
fingers.L/thumb.L had no weight, so the clips' finger curl (14 deg grip, 48 coin flick, 57 fusion) never showed: a flat claw.
Fix: `python3 -I tools/art1/hand_rebind.py in.glb out.glb --turn 0.75 --no-thumb` (on #360's glb):
- the 1244 hand vertices (arm side of #360's cut, below the cuff) turn rigidly about the mesh wrist by 46 deg (0.75 of the
  turn onto the bone axis; the full turn puts the idle fingers into the hip), faded in over 2 cm at the cuff. Same shape, UVs, texture.
- weights: cuff band forearm.L -> hand.L over 3.5 cm, palm hand.L, past the knuckles (the fingers bone's depth, 8.2 cm)
  fingers.L blended over 4 cm. Thumb left on the hand (the thumb split is a heuristic; `--no-thumb` off weights it to thumb.L).
- Everything else is #360's glb bit for bit (right side fins, left hip weights); no other GLB touched; the gatling unchanged.
- hunter_mesh_check: stretched tris live 524 / #360 120 / this 124, union 647 / 180 / 185, collapsed 2 / 42 / 2.
- Sheets (Blender, game camera 28 deg lens at 27 m up / 17.5 m back, plus full, eye, knee and both hand close-ups;
  idle, run, shoot, coin flick (Vex has no reload clip), dash): /home/boki/gens/vex-hands-1123/final/.
Open: #360's fin split leaves a black jagged gap on the right hip in run/shoot close-ups (was tan blade fins); a pipeline hook
(v95_to_game running hand_rebind) needs a hand selection that does not depend on #360's graph cut.
