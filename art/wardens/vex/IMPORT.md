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
it in place) at the drum's mouth, the same spot as `launcher_fire` on `forearm.R`. The Burr Charge leaves from there.

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

## Tearing fix 11-19 (ext/hunter-fix-vex-1118, retry 3): arm-to-body contact split, weights per side
Live (v95, 11-15) welds the left hand/forearm to the hip and thigh, and the arms to the torso sides, with shared vertices, so the
re-derived weights drag hip skin after the hand (black webs from hip to hand in drink, cheer, fusion, glide, x, emote...).
Fix (scripts: /home/boki/gens/hunter-fix-vex-1118/retry3/tool/, `fix2.py` then `prune.py`):
- Faces are split into arm side and body side by their own vertex weights (row level, so the gun sleeve's existing seam to the
  belly skin stays as live). Below y 1.33 m the vertices both sides share are duplicated (372 left, 40 right). No face is deleted,
  no vertex moves: positions, UVs, normals, colours, rig, clips and textures are as live.
- Arm-side copies keep only arm bones, body-side copies only body bones; weights that changed by >15 % are diffused over their
  own side (3857 verts). The coin keeps its live weights (it is a child of hand.L and every clip keys it).
- The openings get small fan caps (420 new triangles, flat colour of the nearest skin/cloth texel), centred inside the body
  (winding test) and pruned to those not seen at rest from 14 directions; rims are inset 1 mm so no welded edge has >2 faces.
- Rest pose renders: 0 px differ from live full body, 6-8 px of 480k at 2.2x zoom (Blender workbench, 4 sides).
- Edges >= 8 mm stretched over 3x 1.005 % -> 0.112 %; worst 10.16x -> 6.86x; edges growing over 10 cm 286 -> 37;
  hunter_mesh_check stretched_tris (worst clip) 524 -> 44.
- Left as live: the skin fan that sticks out 20 cm from the outer left thigh at rest (now rides on thigh.L instead of being
  torn between thigh and hand), and the gun sleeve's seam to the belly (sleeve rigid on forearm.R as live).
Earlier weights-only attempts (no split) did not beat live: hard split 119x edges, smoothing 2.18 % of edges over 3x. The
audit's "5.9 % of all edges" counts sub-8 mm edges too; those are not noise for the eye (a 5 mm edge growing to 20 cm is a
needle), so absolute growth (cm) is reported next to the >= 8 mm ratio.
