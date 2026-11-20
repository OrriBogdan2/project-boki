# Vex (gunslinger): import note

## DRAFT candidate on ext/hunter-regen-vex-1120: regen r3b (2026-11-20, awaiting the owner's visual check)
Meshy multi-image meshy-7.1 `--pose t-pose` from briefs/art-refs/vex_v2/vex_v2_turnaround.jpg (front, 3/4, back; 30 gens in
two rounds, 1 kept, C2: the gatling is her right forearm with no hand inside it, a brass mechanical left hand, no dangling
bullet charm; the other 29 put the gun at the hip, doubled it, dropped it or hung the charm), quad remesh (46.2k tris in
game), blue irises on the amber-iris texels only, then `tools/art1/v95_swap.py` with `weights` "meshy" (r3b: Meshy's
auto-rig weights; r3's bone heat on joints measured from the T-pose mesh pinched the waist into a thin neck and tore the
belt in every clip), the whole gun past the right elbow on forearm.R, `spread_legs` "master" (the rig's thigh heads sit
0.123 m out, hers 0.086 m), the brass left forearm and hand in the metal slot by bone, and no kept coin (the old atlas coin
read as a dark blob in her palm). Spec and every step: ~/gens/hunter-regen-1120/vex/r3/ (work/C2/swap4/spec.json, scripts/,
raw/gen_log.tsv). Stretch-check (51 clips): worst 8.61 (dash_ex, hips), median 4.96 (r3 bone heat 6.69 / 4.64, live
10.16 / 4.46). After swapping the glb, delete vex_v95.jpg AND its .import (keep the old uid line), or Godot keeps the old
texture or none (r3b changed only the weights: the texture is byte-identical).

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

Regen r2 candidate A (2026-11-20, ext/hunter-regen-vex-1120, DRAFT until the owner's visual check): a new body, not a
patch of the 11-10 scan. r1's A-pose body had a bulge on the right hip where the gatling rested, so r2 asks Meshy for a
T-pose (`meshy_task.py create ... --pose t-pose`, meshy-7.1, the 4 views of the 11-19 turnaround `v95-latest-ta-1119/vex.png`):
nothing touches the hip. 11 gens: 2 kept the gatling fused to the prosthetic forearm (A, B on the sheet), 9 dropped,
doubled, holstered or floated it (one came back A-pose). B's gatling points across the forearm, not along it (fires sideways).
-> `remesh --topology quad --polycount 60000` -> irises tinted to the turnaround blue (irises only) -> Meshy auto-rig
weights (`v95_swap.py` `weights: "meshy"`; the fit puts the T-pose arms onto our rig's arms) -> 40.8k triangles, 4096 texture.
Hair already measured darker than the jacket (L 0.45 vs 0.52, hue 95), so it was left as Meshy painted it.
Stretch (51 clips, limit 1.3): worst live 10.16 -> 8.61, median 4.46 -> 5.32, clips over 3x 46 -> 45.
Files, sheet, MP4 and numbers: ~/gens/hunter-regen-1120/vex/r2/ (summary.txt).
