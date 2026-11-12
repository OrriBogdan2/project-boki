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
   onto one bone, minus leg capsules and boxes; a later region wins), `detach` (bone pairs cut apart and capped:
   parts the scan fused that the clips swing apart), `slots` (toon slots by the paint's hue/sat/value, a bone or
   a box; first match wins), `room` (ink room per bone), `anchors` (moved through the same fit), `keep` (bones
   whose old parts stay, with their old paint: Grimble's junk ball), `keep_mats` (old faces kept by material: Kael's
   skinned sword), `anchor_bones` (`{anchor: bone}` puts a moved anchor on another bone: Kael's arm blooms onto the
   master's cursed left arm) and `move_bones` (such a bone's rest moved,
   its clips' translation keys corrected so they end where they did). The budget: `tris` + the kept parts +
   skin_relax's caps <= 15k (RIG_CONTRACT.md).
   Face detail: `tex` (atlas size, 2048 default; 4096 for a close-up Warden), `head_uv` (the head islands' scale
   against the body's: the face island is about 250 px of a 2048 atlas at 2.0, about 850 px of a 4096 one at 4.0)
   and `cage`/`ray` (the bake's cage and ray distance in metres, 0.008/0.03 default; 0.02/0.06 closes the bake
   misses, black blobs, on a head that is far from the low mesh). Sparkle uses 4096, 4.0, 0.02, 0.06.
3. **Swap**: `blender -b --factory-startup --python tools/art1/v95_swap.py -- SPEC WORK OUT_GLB`. The first run
   bakes (bake_warden.py's low mesh, UVs and Cycles bake, ~10 min) into WORK/bake.blend and copies the game .glb
   to WORK/game.glb (the game .glb must be the one from BEFORE any swap: a swapped one has its move_bones and
   anchors applied twice, e.g. the gum bubble ends up on the nose); later runs start from those, so a spec change re-fits in ~15 min. WORK/fit.blend is the
   model before skin_relax, for looking at the weights. It fits the low mesh
   onto the rig (grimble_source.py's segment method), weights it (bone heat on the body bones, on a rig copy whose
   hips bone reaches the neck), detaches and caps, slots it, moves the anchors, runs skin_relax (no edge past 1.3x
   in any clip) and exports with the clips. Copy OUT_GLB over `art/wardens/<id>/<id>.glb`,
   `godot --headless --path . --import`, then
   `--warden-glb-check`, `--warden-model-check`, `--stretch-check --wardens=<id>` and `--warden-shots
   --wardens=<id>` (before and after: `xvfb-run`, `LP_NUM_THREADS=2`).

## Status (2026-11-10): Ryzz and Vex swapped (ext/sparkle-underbust2, specs ryzz_v95.json, vex_v95.json); Grimble NOT swapped yet
The tools run end to end on Grimble (`art/wardens/src/grimble_v95.json`, 8 rounds; renders in docs/shots/grimble-v95/):
the master has no extra hand and its slime arm and gauntlet are right (master_v95_grid_front.jpg), the skeleton,
inverse binds and all 40 clips round-trip unchanged, but the result is not shippable (attempt8_*.jpg), so
dredge.glb stays the 11-08 model. Left to do, in order:
1. The right leg: the hook's boxes take most of the right thigh (attempt8_rest_weights.jpg). Separate the slime arm
   from the leg by its paint (saturated purple against grey-mauve skin): a colour test in `regions`.
2. skin_relax still cuts ~3.2k of 15.6k triangles (Grimble v2: 2.4k), mostly in the shoulder, neck and torso
   blends in run_f, reel, throw and glide (worst stretch before the relax 5.7x after `smooth` 12, from 107x with
   capsule weights). Measure the joints more closely (shoulders, neck) or fit the clips to the new shoulders.
3. The junk ball (`move_bones`) shows through the chest where cuts open it: move it further back or keep it
   scaled to 0 at rest.
4. Slots: the lens gets 7 triangles of glow; check the slot map; the old left-lantern halo (anchor_lamp_l now
   sits on the one lantern) comes out of warden_look.json with the swap.

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
