# V95 swap: a v95 master into a game Warden, on its own skeleton and clips

The v95 masters (`~/meshy/v95/<Name>/v95.glb` on hetzner: Meshy, ~1.5M triangles, 8k paint, no rig; the round's
compare sheet `cmp.png` and `score.json` beside it) replace a Warden's current mesh. The skeleton, the 40-odd clips
and the anchors stay exactly as they are in the Warden's current `.glb`: only the mesh, its weights and its atlas
change, so every kit move, clip and hitbox keeps working. Grimble (`dredge`) went first (2026-11-10); the other
v95 Hunters follow the same three steps. Blender runs on hetzner (`jobq submit --app blender` from a worker).

1. **Measure** (look): `blender -b --factory-startup --python tools/art1/v95_grid.py --
   ~/meshy/v95/<Name>/v95.glb OUT/v95` (and `-- art/wardens/<id>/<id>.glb OUT/old --rest` for the current
   model). Gridded flat front and side renders in the fit frame: his front +Y, his right +X, soles on z 0.
   Read the joints (pelvis, neck, crown,
   shoulders, elbows, wrists, hips, knees, ankles), the head's centre, the rigid parts' boxes and the anchors.
2. **Spec**: copy `art/wardens/src/grimble_v95.json` to `<name>_v95.json` and set `master`, `game`, `joints`,
   `head`, `spread` ("rig": the limbs sit on the bones; without it they keep the master's spread), `past_wrist`
   (the bone that takes each hand's weights: `hand.R`, or a fused weapon's bone), `regions` (boxes moved whole
   onto one bone, minus leg capsules (`except_segs`) and boxes, or only within capsules (`in_segs`); a later region wins), `detach` (bone pairs cut apart and capped:
   parts the scan fused that the clips swing apart), `slots` (toon slots by the paint's hue/sat/value, a bone or
   a box; first match wins), `room` (ink room per bone), `anchors` (moved through the same fit), `keep` (bones
   whose old parts stay, with their old paint: Grimble's junk ball) and `move_bones` (such a bone's rest moved,
   its clips' translation keys corrected so they end where they did). The budget: `tris` + the kept parts +
   skin_relax's caps <= 15k (RIG_CONTRACT.md).
3. **Swap**: `blender -b --factory-startup --python tools/art1/v95_swap.py -- SPEC WORK OUT_GLB`. The first run
   bakes (bake_warden.py's low mesh, UVs and Cycles bake, ~10 min) into WORK/bake.blend and copies the game .glb
   to WORK/game.glb; later runs start from those, so a spec change re-fits in ~15 min. WORK/fit.blend is the
   model before skin_relax, for looking at the weights. It fits the low mesh
   onto the rig (grimble_source.py's segment method), weights it (bone heat on the body bones, on a rig copy whose
   hips bone reaches the neck), detaches and caps, slots it, moves the anchors, runs skin_relax (`relax` in the spec overrides its
   settings: `{"CUTS": 0}` relaxes without cutting holes), collapses to `max_tris` if over, and exports with the clips. Copy OUT_GLB over `art/wardens/<id>/<id>.glb`,
   `godot --headless --path . --import`, then
   `--warden-glb-check`, `--warden-model-check`, `--stretch-check --wardens=<id>` and `--warden-shots
   --wardens=<id>` (before and after: `xvfb-run`, `LP_NUM_THREADS=2`).

## Status (2026-11-10): Grimble swapped (`art/wardens/src/grimble_v95.json`, round e7)
dredge.glb is the v95 master: 14.9k triangles, one 2048 atlas, the old skeleton, inverse binds, 40 clips and anchors.
No extra hand; the slime arm is on his right and the gauntlet on his left (docs/shots/grimble-v95/after_*.jpg against before_*.jpg).
What it took, for the next Hunter:
- **No cuts** (`"relax": {"CUTS": 0}`): skin_relax's cut-and-cap pass took ~3.3k triangles out of the v95 torso and
  shoulders and left it shredded (the junk ball showed through). Relax only: worst stretch 2.2x to 5.3x per clip
  (`--stretch-check` lists every clip; the other Hunters measure 6x to 118x, docs/DEBT.md).
- **max_tris** (default 15000): the detach caps push the bake over the budget; the swap collapses it back.
- **Fused parts by place**: the crescent curls in between his legs at rest and the bake fuses it to the right shin.
  The hook's lower box reaches x -0.12 (the crescent tip) minus thin leg capsules (thigh 0.1, shin 0.06 m) and the
  foot's box; `in_segs` regions then pin the shin capsule and the foot box whole on shin.R and foot.R, so heat
  doesn't leave them half on the hook. Check with a weights render in a clip, not only at rest (a colour test does
  not split the pale crescent from the skin).
- **Kept parts** (`move_bones`): the v95 hoard is shallower than v2's sack; the junk ball now rides at the hoard's
  back (+0.1 y, +0.26 z), where it shows a little, as on v1.
- warden_model_check's `height_3d` for dredge is 1.5 (the v95 hoard is lower than the v2 pile); warden_look loses
  the anchor_lamp_l halo (both lamp anchors sit on the one v95 lantern).

Left: the crescent tip and slime drips fused into the right foot ride the foot (dark shards at his right foot in
some clips, after_front_34.jpg); the lens gets 7 triangles of glow.

Known limits: hanging pieces in the master (lanterns, chains) are rigid on their region's bone (the old spring
chains stay in the rig, unweighted); the loincloth rides the legs and hips (no skirt colour mask yet).

## Motley (`ostra`, 2026-11-11): the appeal3 master, body b with the new face (`art/wardens/src/ostra_v95.json`)
New spec keys (v95_swap.py):
- `drop`: the game .glb's own meshes removed (Motley's old Face, Ruff, Brass, Lining and Wisp: the master has them
  in one piece); unlisted ones stay (his orbiting cards and fan, with their own textures).
- a region's `fade` [z0, z1]: the region's bone takes the weight in full at z0 and none at z1 (the spring and the void
  tail's root between x_box and the hips, so they stretch when he springs up).
- `move_bones` `turn`: the moved bone's rest also turns about z (degrees): the lid's hinge on the master's diagonal box edge.
- `normal`: true bakes the master's tangent-space normals (its normal map and the detail the decimation took) onto
  the atlas UVs as `<id>_normal.jpg` (WardenGlb's `use_nrm`; motley_live_check wants it). Delete WORK/bake.blend to add it.

What it took: the torso's fit capsule (0.30 m) swallows a thin hero's arms and hands (spiky fanned fingers, no
hand.R weights, the arms on the hips), and bone heat does not recover them; arm regions (`in_segs` round each
upper arm and forearm, a box past each wrist for the hand) put them back. A per-spec segment radius in the tool would
be the cleaner fix. warden_model_check's `height_3d` for ostra is 1.2 (the cap's points flop out to the sides).
Stretch: worst 4.1x to 5.5x per clip, Grimble's range (docs/DEBT.md), no tearing in the renders.
Left: the coat tails ride the hips (the old sway is gone); the void tail is painted cloth, not the void shader; the
wisp springs stay in the rig, unweighted.
