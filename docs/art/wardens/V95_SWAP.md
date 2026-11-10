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
   whose old parts stay, with their old paint: Grimble's junk ball) and `move_bones` (such a bone's rest moved,
   its clips' translation keys corrected so they end where they did; or `{"to": master point, "chain": [bones]}`:
   the bone's head goes to that point and the chain moves with it, keys untouched: Albert's fish and its spring
   chain onto the mast it hangs from), `emit` (bake the master's emission map too: glTF emissive, which WardenGlb
   tints to the archetype's model_glow) and `screen` (`{"slot", "centre", "r"}`: that slot's triangles get a flat
   disc UV, u = 0.5 + dx/2r, v = 0.5 + dz/2r, for a shader face such as warden_mood's). The budget: `tris` + the kept parts +
   skin_relax's caps <= 15k (RIG_CONTRACT.md).
3. **Swap**: `blender -b --factory-startup --python tools/art1/v95_swap.py -- SPEC WORK OUT_GLB`. The first run
   bakes (bake_warden.py's low mesh, UVs and Cycles bake, ~10 min) into WORK/bake.blend and copies the game .glb
   to WORK/game.glb; later runs start from those, so a spec change re-fits in ~15 min. WORK/fit.blend is the
   model before skin_relax, for looking at the weights. It fits the low mesh
   onto the rig (grimble_source.py's segment method), weights it (bone heat on the body bones, on a rig copy whose
   hips bone reaches the neck), detaches and caps, slots it, moves the anchors, runs skin_relax (no edge past 1.3x
   in any clip) and exports with the clips. Copy OUT_GLB over `art/wardens/<id>/<id>.glb`,
   `godot --headless --path . --import`, then
   `--warden-glb-check`, `--warden-model-check`, `--stretch-check --wardens=<id>` and `--warden-shots
   --wardens=<id>` (before and after: `xvfb-run`, `LP_NUM_THREADS=2`).

## Albert (Mossy, the Breaker, bulwark): swapped 2026-11-10
`art/wardens/src/breaker_v95.json`: the appeal3 face master (body only) onto breaker.glb; k 1 (the rig is as wide as he
is, much shorter: the torso squashes ~0.76), masts and sails on `hips`, the fish and its spring chain moved to his
left mast (`move_bones` "to"/"chain"), the cracks from the emission map (`emit`), the porthole glass a flat disc for
warden_mood's face (`screen`). `relax` with no cuts: with cuts it took 5.4k of 13.8k triangles (the rigid-piece clips
swing the shoulders and hips hard); left without cuts the worst edge is 8.0x (shoulders, hips; 2.5k edges over 1.3).
`max_tris` 13000: the kept hammer and shield add ~1.8k, so the .glb stays under warden_glb_check's 15000 (14.7k).
`--stretch-check --wardens=bulwark` fails every clip (worst 9.45x, fuse; hips and right arm); the in-game shots of
fuse, x_wind and run_f show no tear at match size. He stands 2.47x a medium (the helmet and masts; was 1.9x).
Shots: docs/shots/albert-appeal/ (game/: in-engine, moods_sheet.png = calm, happy, angry, determined, sad, flare).

## Status (2026-11-10): Grimble NOT swapped yet
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
