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
