# Cinder (ashwick): import note, v95 swap of Cinder appeal3, body b (2026-11-10)

`cinder.glb`: the owner's pick (11-10), Cinder v95 r2 appeal3 `cand_b.glb` (body variant b with the appeal3 face, one mesh), swapped
onto ashwick's own skeleton, clips and anchors by `tools/art1/v95_swap.py` (docs/art/wardens/V95_SWAP.md) with
`art/wardens/src/cinder_v95.json`. Raw files in ~/meshy/v95/Cinder/r2/appeal3 (never in git); the spec reads `cinder_v95_b_body.glb`,
which is `cand_b.glb` without its tail (unrigged in the master): the game's own tail stays.

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

Shots on the game rig (`--warden-shots`): docs/shots/cinder-appeal-b/ (front_34, turnaround_close, closeup_front, closeup,
poses_game, moves_close_1/2): no tearing at the mouth or elsewhere, no arm/chest clipping in idle, run or the moves.

Checks: `--cinder-art-check` 0 fails; `--warden-glb-check` all ashwick lines pass (13.7k tris); `--warden-model-check`
passes with ashwick's `height_3d` re-measured to 1.15 (the new horns stand lower than v2's). `--stretch-check` (new,
`tools/stretch_check.gd`, the same maths as `tools/art1/skin_relax.py`) still flags every ashwick clip past 1.3x, worst 6.8x
(idle 2.3x, run 4.0x); the old build was worse on every clip (worst 19.4x, idle 5.8x, run 11.9x), from the same rig's hips,
thighs, forearms and the kept jets.

Clips in 0.24.4: the swap ran on main's cinder.glb, before the docs/art/IDLE_AUDIT.md idle and stance and the
`x_breath` leaf (eeb4f3ae4, e557cd71e). The 0.24.4 merge copied the 41 clips of that glb (spring tracks included)
onto the swapped body by node name (same skeleton: no rest drift) and added `x_breath` with kael_retarget.py's
`add_breath` at her own spot (0.283 m over hips) and chest band (1.0-1.32 m up, |x| under 0.17 m): 3363 vertices.

**Anim slice3 (11-11), no change:** idle candidates retargeted from Meshy library actions 338, 335, 249 and 12 (Meshy API
on her pilot3 rig task, paid plan, commercial use under Meshy's terms), with the tail carried from the current idle. The
blind Fable 5.2 judge kept the current idle at 4.33; the candidates scored 3.17, 3.00, 2.83 and 2.00 (squats, kneels and
a taunt read timid, not menacing). walk/run were not retried: they lost in ext/anim-pilot-loops-cm and already plant at loco speed.
