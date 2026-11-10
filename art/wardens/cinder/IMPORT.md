# Cinder (ashwick): import note, v95 swap of Cinder appeal4, bust candidate 3 (2026-11-10)

`cinder.glb`: Cinder v95 r2 appeal4 `cand_3.glb` (one mesh), swapped
onto ashwick's own skeleton, clips and anchors by `tools/art1/v95_swap.py` (docs/art/wardens/V95_SWAP.md) with
`art/wardens/src/cinder_v95.json`. Raw files in ~/meshy/v95/Cinder/r2/appeal4 (never in git); the spec reads
`cinder_v95_bust3_body.glb`, which is `cand_3.glb` without its tail (unrigged in the master): the game's own tail stays.

`cand_3.glb` is the owner's earlier pick (appeal3 `cand_b.glb`, body variant b with the appeal3 face; in game at 51ec101a8) after the
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

Checks: `--cinder-art-check` 0 fails; `--warden-glb-check` 183 checks, 0 failed (13.7k tris); `--warden-model-check`
passes with ashwick's `height_3d` re-measured to 1.15 (the new horns stand lower than v2's). `--stretch-check` (new,
`tools/stretch_check.gd`, the same maths as `tools/art1/skin_relax.py`) still flags every ashwick clip past 1.3x, worst 5.9x
(lance_stoke; idle 2.2x; 6.8x and 2.3x with body b); the old build was worse on every clip (worst 19.4x, idle 5.8x, run 11.9x), from the same rig's hips,
thighs, forearms and the kept jets.
