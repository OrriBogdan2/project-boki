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

## Judge framing gotcha (2026-11-13, ext/low4-hunters)
v95-promote's renderer (`_tools/r95_render.py`) turns the model about its glTF origin, not its bbox centre, and
the side frame is only ~0.62 m either side of the origin (Grimble's height, 1.9 m). A hunched pose that pushes the head
forward (Grimble hunch E: head at z 0.64) puts the face out of frame. The judge then reports "too upright, head tucked
in". Moving the whole mesh 10 cm back (-Z, `_low4-1112/tools/shift_z.py`) gave 85/80/84/83 vs the live 79/79 with the
same scorer. The face is unchanged, but the pose moves it, so promote such a pass with `--face`. The candidate and the
command are in `/home/boki/meshy/v95/_low4-1112/PROMOTE_GRIMBLE.txt`. The swap then needs the feet re-centred.

## Status (2026-11-12 evening, ext/hunters-best-1112): the 11-12 evening promotions
In game on top of the table below: Neve's chiffon skirt body under the live head (`claire_v95.json`, from
ext/neve-skirt-livehead). Not swapped yet, so the game keeps the table's model:
- Sparkle, the owner's chest fix (`Sparkle/r3/meshy1112/graft/m4c_livehead.glb`, live 19:59Z). The 160 MB master ran
  out of memory twice in the server bake. On a remote Blender worker (mac, `jobq submit --app blender`, a minimal tree:
  tools/, art/wardens/src, the master, WORK/game.glb = `95f0fef3e5^`'s ryzz.glb) it ran in 2 min, but the game showed
  her white-grey with black specks: the base colour did not bake there. Re-run on a worker whose bake keeps colour.
- Albert's i1 face pass (`Albert/r3/meshy1112/candidates/i1/glb.glb`, live 20:35Z): the same mac run (current
  breaker.glb as WORK/game.glb, `move_bones` dropped, since v95_swap.py now takes offsets and his spec has `to`/`chain`)
  rendered him solid cyan (the glow covered the whole body). His eyes-mood screen also needs re-placing on the porthole.
- Gil (v95a cand_B, live 20:03Z) has no swap spec yet: a first `gil_v95.json` (joints, tail, fin, rapier).

## Status (2026-11-12, ext/hunters-v95-ingame): every Hunter's LIVE v95 master is the game model
The masters are the ones `~/meshy/v95/CURRENT_OVERRIDES.txt` and `current.json` name on 11-12. Re-swapped here:
Cinder (the facekeep body: body6 cand_B's shape with the cand_A face3 image), Sable (prop1111 cand_B), Vex (prop1111
cand_A), Sparkle (prop1111 cand_A) and Lace (body6); Tarek's appeal3 cand_b and Grimble's appeal3 cand_b come in from
their branches. Albert, Kael, Motley, Neve and Meeko already were live (Neve and Motley with the 11-12 owner fixes).

| Hunter (id) | tris | textures | clips |
|---|---|---|---|
| Albert (breaker) | 14.8k | 3 x 2048 | 48 |
| Lace (hem) | 13.9k | 2 x 2048 | 51 |
| Kael (kael) | 13.9k | 2 x 2048 | 52 |
| Vex (vex) | 13.1k | 2048 | 39 |
| Motley (ostra) | 14.1k | 2 x 2048 + 512 | 45 |
| Sparkle (ryzz) | 13.2k | 4096 | 45 |
| Tarek (tarek) | 13.4k | 1024 + 2 x 2048 | 48 |
| Sable (sable) | 13.0k | 2048 | 47 |
| Neve (claire) | 13.4k | 2048 | 49 |
| Cinder (cinder) | 13.7k | 2 x 2048 | 44 |
| Meeko (pip) | 14.3k | 2 x 2048 | 45 |
| Grimble (dredge) | 14.9k | 2048 | 40 |

Re-swapping a model that is itself a swap: pre-place its current .glb as WORK/game.glb (no move_bones in the spec)
or the file from before the first swap (Sparkle: `95f0fef3e5^`, its move_bones are deltas). The old mesh drops whole
unless `keep` names bones. Proof: `tools/art1/ingame_face_sheet.py` (ffmpeg) from two `--warden-shots` runs, the
engine's own close-up and match cameras; the older facekeep sheets framed the glb in Blender with guessed fractions
of a bounding box, in rest pose, which is why their "game" column looked wrong.

Bake misses: a triangle the decimation folds under catches no ray, and its texels bake exactly black (Sparkle's
forehead, Cinder's arm in the first 11-12 swaps; a bigger cage or ray distance did not reach them). `fill_misses` in
v95_swap.py fills exact-black base-colour texels from their neighbours (max(32, tex/64) texels in), not the glow map.
Step 1 is skipped while WORK/bake.blend exists: delete it to re-bake.

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
