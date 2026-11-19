# Cinder (ashwick): import note, v95 swap of Cinder appeal4, bust candidate 5 (2026-11-11)


## LIVE 11-19: skinning fix (job 20261119-024205-a3, ext/hunter-fix-cinder-1118): weights and contact cuts only
`cinder.glb` = the 11-18 board1117 A2 glb with the same positions, UVs, images, bones and 54 clips; only the skin weights
changed and 90 vertices were split. Why: the scan fused the forearms to the hips and ribs, and the re-derived heat weights
left forearm weight on hip skin and torso weight on forearm skin, so every clip dragged those triangles into spikes.
- Skin that lies on the forearm or lower upper arm (x outside 0.145 m, y below 1.12 m) is labelled arm, the rest by smoothed
  cluster weight (arm L/R, leg L/R, core). Arm vertices lose torso and leg weight, torso vertices lose forearm/hand weight.
- Fused arm/leg/torso contact triangles (120) are cut by splitting their vertices: same position, so the bind pose is
  identical, but the arm separates from the body when it moves.
- Arm and leg chains get a smooth blend along the limb (smoothstep, 14 cm at the elbow, 8 cm at the wrist, knee/ankle alike)
  instead of a one-vertex hinge; torso weight fades out 10 cm down the limb.
- Targeted weight smoothing (25 passes, alpha 0.6) on the vertices of edges that still stretch over 2.2x, never across the cuts
  and never from torso skin into forearms.
Numbers (edges stretched over 3x vs bind, Blender, idle / run_f / run_f / shot): 1.83 / 2.51 / 2.29 / 3.33 % -> 0.03 / 0.06 /
0.03 / 0.12 %, worst 205x -> 10x. hunter_mesh_check stretched tris in the worst clip 762 -> 96 (the jet flame cones, which grow
by design), collapsed 52 -> 0. Floating sheets: none found (floating_islands 0, no needle islands), so nothing was deleted.
Scripts: `/home/boki/gens/cinder-rigfix-1119/tool/` (fix.py, smooth.py, glbrw.py).

### Retry 11-19 (Fable review: new holes at the hips, scraps on the forearms), still weights plus added cap triangles only
No triangle of the scan is deleted or moved, and every original vertex keeps its bind position, so the rest pose looks like live.
- Two floating islands the cut left behind (20 + 24 triangles of hip skin from under the left forearm, they rode the forearm as
  red scraps) now take their hip twins' weights.
- The cut at the armpits (upper arm vs ribs, y above 0.98 m) is undone: the seam pairs take the mean of their two weight sets, so
  the armpit is one skinned surface again (raising an arm opened a hollow there).
- Every loop the cut opened at the hips and thighs is closed from its own side with a flat cap (fan or ear clipping, long thin
  triangles halved), weights of the loop's own vertices, UVs and colours of the nearest skin of the same side.
  Loops that were already open in the scan (front crotch, tail root) are left alone, as in live.
- Edges stretched over 3x vs bind (all 46 clips, every 0.1 s): median clip 3.44% -> 0.12%, worst clip 4.62% -> 0.29%.
Scripts: `/home/boki/cj/20261119-054029-a5/work/tool/` (isl.py, unify.py, cap13.py on top of fix.py output).

## LIVE 11-18: bust A (-20% chest volume, owner 11-18 ~00:20 EST "lets exchange it immediately")
`cinder.glb` = main's depth1117 A_s18 game glb with the chest of `~/meshy/v95/Cinder/bust1118/bust_m20.glb` (job
20261118-032222-a1; same topology as cand_A_s18, only chest vertices moved). No re-rig: the master's per-vertex chest
delta reaches each game vertex by UV barycentric lookup, through the local master->game Jacobian (affine fit over UV
neighbours, scale ~0.82), then an 8 mm spatial median across all body prims (metal and skin seams move together),
scaled so the volume change is the master's at game scale (-0.40 L). 5,574 vertices moved, max 19.6 mm; normals turned
with the mesh's own normal change. Weights, bones, clips, UVs, images byte-identical. Scripts:
`~/meshy/v95/Cinder/bust1118/game/` (transfer.py, clean.py, K=0.916). Stretch check: worst 7.60 lance_stoke, as main.

## LIVE v95 master in game (2026-11-12, ext/hunters-v95-ingame)
the facekeep body `~/meshy/v95/Cinder/r2/ingame1112/cinder_v95_facekeep_body.glb`: body6 cand_B's shape on the cut `cinder_v95_body6_body` (every vertex matched) with the cand_A face3 face image. Was appeal4 cand_5 below. 13.7k tris, 2048 atlas + 2048 emit, 44 clips (pet/give/cheer gain sampled channels, same timing).
Spec `art/wardens/src/cinder_v95.json`; proof sheet ~/meshy/v95/_closeups/ingame-1112/sheet.jpg.

`cinder.glb`: Cinder v95 r2 appeal4 `cand_5.glb` (one mesh), swapped
onto ashwick's own skeleton, clips and anchors by `tools/art1/v95_swap.py` (docs/art/wardens/V95_SWAP.md) with
`art/wardens/src/cinder_v95.json`. Raw files in ~/meshy/v95/Cinder/r2/appeal4 (never in git); the spec reads
`cinder_v95_bust5_body.glb`, which is `cand_5.glb` without its tail (unrigged in the master): the game's own tail stays.

`cand_5.glb` (11-11) redoes candidate 3's bust after the owner's note that it juts out like a cone in side view (and "all the girls a
bit curvier, tighter waist, not weird from the side"). Candidate 3 scaled the bust radially, so the apex moved most. Candidate 5
displaces each breast as a dome instead: zero slope where it meets the chest wall (no shelf), volume spread over the whole breast,
a fuller lower curve with a small drop, and the apex lower and softer (38.1 cm forward vs 38.8). Waist about 9% narrower at its
narrowest, hips +4.5%. Same vertices and UVs, so the shell and lava seams ride it (triangle area p95 1.51x). Candidate 3's
painted face is kept. Sheet: ~/art-review/cinder-bust-round-1111/cmp_bust_round.png; candidate 4 is the perkier alternative.

`cand_3.glb` (previous in-game, 47415fdfe) was the owner's earlier pick (appeal3 `cand_b.glb`, body variant b with the appeal3 face; in game at 51ec101a8) after the
owner's 11-10 evening note ("bust should be bigger", "both big and seductive"): a fuller rounded bust (apex 6.5 cm further forward,
10.4 cm past the underbust instead of 3.9), waist 1.5 cm narrower, hips 1.9 cm wider, and half-lidded eyes, smoky liner, one raised
brow and fuller lips painted into the appeal3 face. Same vertices and UVs as `cand_b.glb`. Numbers, the milder candidates 1 and 2
and the reasons: `pick.txt` and `cmp_bust.png` beside the raw files. This is the worker's pick, not yet the owner's.

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/cinder_v95.json WORK art/wardens/cinder/cinder.glb

Body: 13k triangles (head 2.6k), one 2048 atlas and the master's emission map baked beside it (`"emit": true`), both embedded
(Godot extracts them to `cinder_atlas.jpg` and `cinder_emit.jpg`). The lava seams are the emission map, as before;
`PipStars.pulse` still brightens it while she casts. Slots by colour and box (first match wins): metal (the horns, the dark shell
and the orange seams), hair, skin.
Weights: bone heat from the spec's joints; the head box rides `head` and the hips box `hips`. They meet at z 1.53 (the fit frame),
just under the neck joint and below her chin: a first cut at the lips' height (z 1.6) fitted and skinned her lower lip with
the torso and tore it into spikes.

Kept from the old build (the swap's `keep`): the spined tail on its 9 spring bones, with its own slots and paint, so it is
darker and spikier than the master's own tail; and the heel jets on `jet.0`/`jet.1` (`flame-jet`, for Flue Flight).
Gone: the hair cards with ember ends and their sheet `cinder_cards.png` (the master's hair rides head and hips), the painted
eyes (the master's face is painted), the modelled scan shards.

Contract unchanged: the flame on the tail is not mesh (`smoke` and `bloom` on `anchor_tail_tip` in warden_look.json);
`weapon_muzzle` is her right palm, the dominant one (the kit's fire point); `weapon_muzzle_l` is her left palm;
`anchor_tank`, `anchor_vial_*` and `anchor_gun_mid` stay as contract names only. `anchor_head_top` and `anchor_chest` move onto
the new mesh (the spec's `anchors`). Her fire stream keeps the rules' NOZZLE.

`cinder.glb.import`: `generate_lods=false`, `force_disable_compression=true`, `remove_immutable_tracks=false`.

Shots on the game rig (`--warden-shots`): docs/shots/cinder-bust/ (front_34, turnaround_close, closeup_front, closeup,
poses_game, moves_close_1/2, back_34, turnaround_game): no tearing at the mouth or elsewhere, and no arm crossing the bigger bust in
idle, run or the moves (the chest rides `hips` rigidly, so it cannot tear).

Checks (11-11, candidate 5): `--cinder-art-check` 0 fails; `--warden-glb-check` PASS; `--warden-model-check` PASS;
`--stretch-check --wardens=ashwick` flags all 41 clips as before, worst 5.83x (lance_stoke; idle 2.17x), the same as candidate 3's.
Shots on the game rig: docs/shots/cinder-bust/ (re-rendered for candidate 5).
Earlier, candidate 3: `--cinder-art-check` 0 fails; `--warden-glb-check` 183 checks, 0 failed (13.7k tris); `--warden-model-check`
passes with ashwick's `height_3d` re-measured to 1.15 (the new horns stand lower than v2's). `--stretch-check` (new,
`tools/stretch_check.gd`, the same maths as `tools/art1/skin_relax.py`) still flags every ashwick clip past 1.3x, worst 5.9x
(lance_stoke; idle 2.2x; 6.8x and 2.3x with body b); the old build was worse on every clip (worst 19.4x, idle 5.8x, run 11.9x), from the same rig's hips,
thighs, forearms and the kept jets.

Clips in 0.24.4: the swap ran on main's cinder.glb, before the docs/art/IDLE_AUDIT.md idle and stance and the
`x_breath` leaf (eeb4f3ae4, e557cd71e). The 0.24.4 merge copied the 41 clips of that glb (spring tracks included)
onto the swapped body by node name (same skeleton: no rest drift) and added `x_breath` with kael_retarget.py's
`add_breath` at her own spot (0.283 m over hips) and chest band (1.0-1.32 m up, |x| under 0.17 m): 3363 vertices.

Appeal4 (cand_5, ext/cinder-bust 7efd99345) in 0.24.5: that branch swapped onto the appeal3 b glb from before the
line's IDLE_AUDIT clips, so the 0.24.5 merge copied the line glb's 41 clips (spring tracks included) onto the cand_5
body by node name (same skeleton, no rest drift) and added `x_breath` at the line's spot with the chest band
1.00-1.32 m up, |x| under 0.17 m (kael_retarget.add_breath): 3288 vertices.

Re-key (ext/anim-cinder-rekey, 11-12): `run_f/b/l/r` and `jet_land` rebaked with cinder_clips.py on
~/meshy/cinder_v2/stage_p2/cinder.blend (a control bake of `walk_f` matched this glb's to 4e-7) and copied on by
`python3 tools/art1/glb_add_clips.py art/wardens/cinder/cinder.glb <bake.glb> run_f,run_b,run_l,run_r,jet_land`.
On the 0.24.5 merge the five clips were copied again, from the re-key glb (6f4b8f0fe) onto main's cand_5 glb by the same
command (rest poses equal to 2e-6); every other clip, the garden set and `x_breath` are main's.

v95 swap 11-12 (ext/hunters-v95-ingame): re-baked with `fill_misses` (docs/art/wardens/V95_SWAP.md), which fills the
texels the bake missed (exact black where the decimation folded a triangle under) from their neighbours.

Cloak peak (ext/anim-cinder-cloak-peak, 11-13): `cloak` rebaked with cinder_clips.py (arms-wide peak 0.13 -> 0.03 s) and copied on by
`python3 tools/art1/glb_add_clips.py art/wardens/cinder/cinder.glb <bake.glb> cloak`. Bake source: the stage_p2 rig (a worker without
stage_p2/cinder.blend used a prior bake's `*_anim.blend` of it with every action removed; the unchanged cloak baked from it matched this
glb's to 1.5e-6, bone rests equal up to quaternion sign). All 43 other clips, nodes, meshes and images byte-equal.
**Anim slice3 (11-11), no change:** idle candidates retargeted from Meshy library actions 338, 335, 249 and 12 (Meshy API
on her pilot3 rig task, paid plan, commercial use under Meshy's terms), with the tail carried from the current idle. The
blind Fable 5.2 judge kept the current idle at 4.33; the candidates scored 3.17, 3.00, 2.83 and 2.00 (squats, kneels and
a taunt read timid, not menacing). walk/run were not retried: they lost in ext/anim-pilot-loops-cm and already plant at loco speed.
Re-key (ext/anim-dash-clips-cinder-lace, 11-12): `leap` (Soot Ram) re-keyed to the felt ram (3.4 m / 0.33 s, fastest at
the start): flat out by 0.12 s, the stop on RAM_IMPACT_KEY 0.36 as before. The source .blend was not on the art worker, so
the bake ran on this glb through `tools/art1/clip_blend.py ... palm=anchor_blade_root` (a control bake of `leap` and `hop`
matched this glb's exactly) and was copied on with `glb_add_clips.py ... leap`. `hop` (the air poof) already fits the felt
6.8 m / 0.28 s (the roll done at 0.25 s) and is unchanged.
On the v95 swap the `leap` re-key was copied again onto main's v95 glb with `glb_add_clips.py ... leap`.

**v95 master A (11-16, ext/cinder-3d-a-1116):** the owner accepted Cinder 3D option A (job 20261116-200037-a2, Meshy rebuild from the
owner-picked sheet: glowing amber eyes, clean lips, deeper bust). Master: `~/meshy/v95/Cinder/r8/pick1116/cands/A.glb` (live in
`CURRENT_OVERRIDES.txt` / `current.json`). A carries a fused tail, so the game swap uses a copy with it cut off
(`~/meshy/v95/Cinder/r8/pick1116/game/A_notail.glb`, made by `cut_tail_A.py`, an adaptation of `_body5_tools/cut_tail.py`: 115,030 of
682,993 vertices) and the game keeps its own spring tail (`keep`). Swap:
`python3 tools/art1/v95_to_game.py Cinder --master <A_notail.glb>` (new `--master` flag) with `art/wardens/src/cinder_v95.json`
(joints re-read from `v95_grid.py` renders of A). Result: 60,711 tris, same rig, clips, spring tail and jets. Judges disagree:
the promote judge scored A 53 vs A2 71, the source job's judge 83 vs 65; the owner picked A by eye.

**board1117 A2 colours (11-18, ext/hunter-picks-tcg-1117):** owner 11-17 "cinder your call" on the 3D board, coordinator call A
(board1117 g13: crown hair maroon, lower flame ramp on the hair, thin orange crack emission, skin graded toward the ref).
A2 is a texture-only grade of the depth1117 master (same mesh, UVs and images 1-3, 5-6), so it goes on top of the live
bust A chest without a re-port: master `~/meshy/v95/Cinder/board1117/A2_bust_m20.glb` = bust_m20's mesh + A2's three changed
images. In this glb only `v95`, `v95c` and `v95d` changed (`tools/art1/glb_image_swap.py`), each = game image + resize(A2) -
resize(bust_m20) at the game size (JPEG q92); mesh, rig, clips, tail and jets byte-equal.
