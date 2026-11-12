# Cinder (ashwick): import note, v95 swap of Cinder appeal4, bust candidate 5 (2026-11-11)

## Women body pass 11-11 (ext/women-body-1111): the current cinder.glb

Owner 11-10: Cinder bust bigger. The body5 swap (`~/meshy/v95/Cinder/r2/body5/cand_2.glb`, a 2.6 cm dome over cand_5) came out of the swap's fit no bigger than cand_5 in game, so the build keeps 0.24.5's cand_5 glb (clips, x_breath, paint) and pushes the dome into its bind mesh instead: `python3 tools/art1/cinder_bust_dome.py IN.glb OUT.glb` (2.8 cm forward at the apex, zero slope at the chest wall, a little sag and spread; positions and normals only, 631 vertices). Run it again after any re-swap; the spec still reads cand_5. Shots: docs/shots/women-body-1111/ (sheet_<name>.jpg is 0.24.5 against this build, front and side, rest pose).

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
