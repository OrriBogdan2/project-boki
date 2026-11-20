# Tarek (dolm): 11-20 regen r2, candidate A (ext/hunter-regen-tarek-1120, draft until the owner's visual check)

`tarek.glb`: a new Meshy model from the CURRENT turnaround (`~/gens/v95-latest-ta-1119/tenzo.jpg`, 4 views + texture
refs): multi-image-to-3d meshy-7.1, A-pose, enhance off, PBR off (6 gens, A picked), quad remesh 60k, Meshy auto-rig
weights onto dolm's skeleton and clips; joints and head read off Meshy's rig (`meshy_joints.py`), the neck at z 1.58
(the head-box line, as before). 47.8k tris. `glb_prop_paint.py --meshes eye_stone,shard --drop shard --from
leather-body.001 --to leather-v95 --near 58,78,110`: the three round eye stones cobalt slate (a separate orbiting
prop), the off-hand shards out. One stone arm (his LEFT), a bare five-finger off hand, cream bandage + cobalt cuff on
the off forearm, cream ankle wraps (as the turnaround and live splash).

Slots (spec `art/wardens/src/tarek_v95.json`): teal runes -> `glow` (0.45), the stone arm and wrist cuff (blue hue) ->
`leather` (matte: gloss/sheen/fres 0, albedo x1.4, desat 0.4), cream wraps and bandages -> `cloth` (desat 0.4), so the
skin slot's tint no longer browns them; skin desat 0.6, albedo [0.86, 0.8, 0.78], sss 0. In-game (RTX 4090, eye level,
idle): stone H223 S0.51 V0.40 (splash rocks H224 S0.47 V0.43; live S0.22 grey), skin S0.54 (live 0.70, orange-red),
runes teal H170. The game's environment adds saturation x1.14; tune colours on the GPU queue, not on llvmpipe/OpenGL.

Checks: `--stretch-check --wardens=dolm` worst 15.06 -> 7.86, median 6.67 -> 4.91, clips over 3x 60 -> 50.
`--warden-model-check`: the 3D model stands 1.175x -> 1.153x a medium hunter (sheet 1.08x, still over the 4%); the
rig-only "stands 1.153x" line fails on main as well. Raw files, sheets and proof MP4s: ~/gens/hunter-regen-1120/tarek/r2.

# Tarek (dolm): import note, v95 swap of Tarek appeal3, candidate b (2026-11-11)

`tarek.glb`: Tarek's v95 r2 appeal3 `cand_b.glb` (a new warm-brown face with a gentle smile and a firmer jaw, plus a
waist taper, from `briefs/art-refs/tarek_v2/` only) swapped onto dolm's own skeleton, clips and anchors by
`tools/art1/v95_swap.py` (docs/art/wardens/V95_SWAP.md) with `art/wardens/src/tarek_v95.json`. Raw files in
~/meshy/v95/tarek/r2/appeal3 (never in git; `cmp.png` is the current-vs-cand_b sheet, `pick.txt` the pick and why); the
spec reads `tarek_v95_b_body.glb`, which is `cand_b.glb` without its three floating eye stones (the game's own
`stone_0-2` stay).

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/tarek_v95.json WORK art/wardens/tarek/tarek.glb

The appeal pass: the face is a texture-only edit (one Meshy edit of a flat head render, projected back onto the master's
head with the baked position and normal maps); the body moves positions and normals only (topology and UVs identical to
the v95 master), a V-taper at the waist (max move 2 cm). The v95 body already matched the turnaround within ~1 cm.

HY-Motion pilot 2 (NOT applied to the v95 glb): the branch baked `idle` and `walk_f` from HY-Motion-1.0-Lite clips into the old 13k-tri
tarek.glb. To redo it on the current glb: `python3 tools/art1/glb_swap.py G CLIPS.glb G hy_idle_s2:idle:loop` (see the script header).
Licence: tencent-hunyuan-community excludes the EU, UK and South Korea; legal signs off before these ship.

Body: 13k triangles (head 3.2k), one 2048 atlas embedded (Godot extracts it to `tarek_atlas.jpg`; the old
`tarek_tarek_atlas.jpg` and `tarek_tarek_emit.jpg` are gone). No emission map (`"emit"` off): the master has none.
Slots by colour, bone and box (first match wins): hair (the locs, box z >= 1.3, dark), cloth (dark trousers, the sash),
metal (the stone arm and gauntlet, grey), cloth (saturated orange sash; the cream blindfold and wrap), skin (the rest).
Weights: bone heat from the spec's joints, limbs on the rig's own segments (`spread: "rig"`); the head box takes the
head, the hips box the cloth and trousers, the pauldron box the stone shoulder. The spec's neck joint sits at z 1.58 (the
head box's line): at 1.5 the master's head took the rig's low neck at full body scale and stood 1.157x a medium hunter
against the sheet's 1.08x; now 1.106x (`--warden-model-check` allows 4%).

Kept from the old build: the three floating eye stones (`stone_0-2`, halos on `anchor_stones_0-2`), the fist shards
(`shard_0-4`) and the ground rings, as separate nodes, untouched, with their anchors and `far_hide` in warden_look.json.
`anchor_head_top` and `anchor_chest` move onto the new mesh (the spec's `anchors`).

**Stone arm:** the master carries it on his LEFT, as the v2 turnaround does. It sits in the `metal` slot (grey toon);
alternative not taken: the `leather` slot (emission 1.8, the old build's stone slot).

**Known gap:** the old build's jade glyphs glowed (an emission map keyed from the atlas, tinted by dolm.json
`model_glow`); the master's arm has no glyph paint to key, so the arm is plain grey stone and the glow now comes only
from the kit FX on the anchors. Follow-up: paint the glyphs on the master's atlas and set `"emit": true`.

Clips: the 48 clips of the v2 build, unchanged (the swap keeps the game rig).

`tarek.glb.import`: unchanged.

Shots on the game rig (`--warden-shots`): docs/shots/tarek-appeal/ (before_after.jpg first).

Checks (2026-11-11): `--warden-glb-check` 183/0 failed, `--warden-model-check` 157/0 failed. `--stretch-check
--wardens=dolm` still flags all 48 clips (worst 19.5x in fuse, run_f 10.0x, idle 5.0x, mostly the thighs and hips;
skin_relax's own worst edge 19.4x after 59 passes): not under 1.3x, as for Kael and Grimble. No tearing, arm or
chest clipping shows in the turnaround, idle, run or kit poses.

## Re-swap on the current rig (2026-11-11, patch 0.24.6)
The appeal3 swap above was made on a pre-IDLE_AUDIT tarek.glb, whose clips had no `x_breath` bone, so on current main
`--warden-glb-check` rejected it ("variant bone x_breath missing") and Tarek fell back to the procedural model. Re-swapped
with the same spec (`art/wardens/src/tarek_v95.json`) onto main's tarek.glb as the rig input (fresh WORK): same master,
12999 tris, 48 clips, `x_breath` kept.

## Stone arm A look (2026-11-13, job 20261113-153317-a4)
Owner-approved A look for the stone arm, shoulder plates and bracer: V1 blue slate with teal runes. The colour was graded from
Meshy retexture gen 1 (the only gen used) onto the original UVs. Lab LUT: L is quantile-matched and the median is recentred
on the A swatch [62,78,85]. Runes are masked out and keep their emission.
- The game glb splits the `metal-atlas` primitive in two. 141 tris keep `metal-atlas` (tarek_atlas.jpg, byte-identical).
  The 1359 arm tris move to the new material `metal-slate`, a copy of metal-atlas whose albedo is `tarek_slate.jpg`
  (the graded 2048 atlas). `warden_glb.gd` reads the slot as the slice before "-", so `metal-slate` is set up exactly
  like metal. A separate image is needed because a JPEG edit of the shared atlas spills chroma into the hair, skin and cloth islands.
- Proof: Blender Workbench flat-texture renders, old vs new, 4 views. 0-3 px changed outside the slate prim.
  Face, skin, sash, beads, hair and trousers are unchanged. On the site master, head_diff is [].
- Re-running `v95_swap` on this rig drops the split. The recolour scripts (grade.py, gamesplit.py, armprim.py) and their
  inputs are in /home/boki/meshy/tenzo-arm-3d-1113/ (NOTES.md, work/).

The strikes lmb_punch and lmb_throw are keyed at 60 fps (`bake(fps=60)`; tools/art1/fine_export.py exports them at that rate and splices
them in), so the .glb.import keeps `animation/fps=60`. Clips only, with no raw files: import the shipped .glb in Blender
(bone_heuristic BLENDER, actions dropped, the armature named `Armature`) as WORK, run the clip script on it, and splice
the changed clips into the shipped .glb with `python3 tools/art1/glb_add_clips.py <shipped> <new> <clip,...>` (the
other clips re-bake byte-equal that way).

NOT APPLIED on main (11-16 merge): the diagonal and re-baked back/side loops (walk_/run_ fl fr bl br, b l r) described here were baked into the old model's glb with a walk_f/run_f of a different length than main's v95 clips, so main's glb and warden_anim json are kept. Re-bake: `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- SRC.glb OUT.glb WALK RUN` on main's glb, then `glb_add_clips.py`, then restore the json map from ext/anim-dirloops-lace-kael.
