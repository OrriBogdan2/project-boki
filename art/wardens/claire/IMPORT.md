# Claire (rimewright): import note, v95 swap of Claire appeal3, body a (2026-11-10)

## 2026-11-19: tearing fix (ext/hunter-fix-claire-1118), skin weights only
Under animation the v95 mesh tore (hand/forearm/shin weight on hip and thigh skin, 3-15x edge growth, black spikes). Only
JOINTS_0/WEIGHTS_0 of the body mesh changed; the spear mesh, skeleton, bone names, clips, UVs, indices and textures are
byte-identical, so the bind pose looks the same.
Method (first pass): tools/art1/skin_relax limbs_apart + relax on the glb's own clips, every edge measured as posed length /
(rest length + 1 cm) so short edges (under 8 mm, which glb_relax skips and where the elbow and hair spikes were) count.
Retry (Fable review: the first pass put black blobs on the thighs in idle): the legs/hands skin primitive (skin-v95b) was
re-weighted differently. It keeps the live thigh/shin/hips mix; only the arm bones (hand/forearm/upper_arm, 22% on the thigh
at worst) are removed from the thigh skin and the rest renormalised, and the 7 faces the first pass had made degenerate are
back (those holes were the black blobs). The top of the thigh (bind y 0.70-0.80 m, under the skirt hem) keeps the live
weights, blended in, so the thigh opening stays hidden. Skirt, sleeve, shoulder and hair weights are the first pass's.
Numbers (own numpy skinner, unique edges): share over 3x bind length at idle / run_f 0.25 / run_f 0.60 1.12 / 1.15 / 1.24 %
-> 0.18 / 0.16 / 0.14 %. (Corrected 11-19: the "triangles over 8x 245 -> 0" here was wrong; the Fable review's numpy
skinner, no minimum edge, 61 glb clips, counts 1379 -> 102 for that pass. With Godot's 8 mm minimum edge over all 1784
game-clip frames it is 8 -> 0.)
Close-camera renders (30 clips, 15 fps): idle leg black px per frame live 9.9, first pass 50.4, now 12.9 (no frame over 30 px);
frames with a 100+ px black blob over all clips live 88, first pass 84, now 74 (hip/thigh wedge gone in run, spear, stomp,
walk, mantle; crouch band 379 -> 211 px).
Not fixed (identical in live, not leg skin): the dark wrist cuff and glove, hand slivers, the dark patch by the shoulder in emote.
Retry 2 (11-19, Fable review: 21 thigh points still followed hand.R, upper right thigh fatter than live): no leg-skin
vertex keeps any arm weight now (89 -> 0). The stripped weight goes to hips at bind y >= 0.76 m (under the hem), blending to
thigh.L/R at <= 0.68 m. Giving it all to the thigh bone (first try) opened a bigger black wedge under the right hem. Upper right
thigh idle width 20.6 cm (live 23.3, bind 16.8). Godot --stretch-check worst 9.15 -> 5.73 (fusion), lower in all 69 clips. Known
residual: hit_f f1-f6 shows a black wedge under the right hem, larger than live's. In live, hand-weighted thigh points hid that
gap by accident. Weighting the thigh top to hips hides it but tears every crouch clip.
Retry 3 (11-19, Fable review: new black under the right/back hem in crouch_l, hit_f, idle, rime_crash, skate_stop, death,
crouch_b, walk/run): weights only again (only Body JOINTS_0/WEIGHTS_0 differ from live; positions, indices, UVs, spear,
skeleton and clips byte-identical, no triangle deleted or split). The hem black was the thigh skin creasing under the hem
(back faces show black), not a hole. Fix: the right thigh skin (0.45-0.91 m, leg-weighted, no arm weight) has smoothed
hips/thigh/shin weights; the boot-top and hem seam copies that the earlier passes had split (cloth/fur vs skin at one
position, different weights) carry one weight set again; 5 inner-thigh points move shin -> thigh. Above 1.0 m (sleeves,
waist, the arm cut) the weights are the previous pass's, and no vertex gains arm weight. Picked by a ray-cast black-face
check on the game's own poses for all 1784 frames, then confirmed in GPU renders (live audit harness).
Numbers vs live: Godot --stretch-check worst 9.15 -> 5.73 (fusion), lower in 68 of 69 clips (walk_fl 3.33 -> 3.94); share
of edges (>= 5 mm) over 3x, game poses: idle 0.82 -> 0.12 %, worst clip peak 1.38 -> 0.36 %, clips peaking over 0.5 %
62 -> 0 of 69. GPU close cam, 1784 frames: frames with a new 100+ px black blob vs live 2 (previous pass: 164 in the
review), frames where a live blob is gone 587; idle frames with a new 40+ px tooth 4 of 146 (previous pass 136).
Known residual: death f23-37 at the game camera (lying down) shows a black patch at the thigh top / left hem, larger than
live's; the left hem weights that close it open one in crouch_b instead. Proof: /home/boki/gens/claire-fix4-1119/.

## 2026-11-12 evening: the chiffon skirt body under the live head (ext/neve-skirt-livehead, spec claire_v95.json)
claire.glb is now the v95 swap of `claire/r3/meshy1112/redo_skirt/graft/u1rm_livehead.glb` (the live appeal3 face kept
byte-identical down to the fur collar, tools/meshy/head_graft.py). It replaces the arms fix below: that fix was made for the
11-10 body, and on the skirt body its sleeve and glove detection finds 43 and 60 arm vertices and no glove, so it is not
applied (the skirt swap's own spec puts the arms on the arm bones). Kept below as the 11-10 body's history.

## Owner fix 2026-11-12 (11-10 body, superseded): arms and hands (`tools/art1/warden_fix_1112.py claire`, on the 11-10 file)
The owner's Model Room note: "arm / hands are weird". Bone heat had put the sleeves mostly on `hips` and the gloves on
`forearm`, and the skirt, the sash and its bow on the forearms and hands, so a raised arm dragged a lump of skirt and the
bow up with it (the bulky "sleeve", the bow fused into the hand). The mesh's arms also hung 6-10 cm outside the arm bones.
The fix: the sleeve (fur by the arm's line) and the glove (its purple paint, or all-arm weights, and the claws) are the arm,
grown over the mesh; only they keep arm weights (upper_arm, then forearm over 3 cm round the elbow; the glove rides the
forearm, as the clips' wrist turns were keyed for the old fist round the spear); everything else loses its arm weights.
The 35 faces fusing the cuffs to the skirt and sash below the armpit are cut. Each arm is then turned onto its bones
(upper arm about the shoulder, forearm about the elbow) so it bends where the clips bend it; the bones stay on the rig
nodes (REST_TOL). Body proportions untouched. Stretch check: worst 5.41 (was 6.61); idle 0 stretched edges (was 93).

`claire.glb`: the owner's pick (11-10), Claire v95 r2 appeal3 `cand_a.glb` (the appeal3 face on body a, one mesh), swapped onto
Claire's own skeleton, 49 clips and anchors by `tools/art1/v95_swap.py` (docs/art/wardens/V95_SWAP.md) with
`art/wardens/src/claire_v95.json`. Raw files in ~/meshy/v95/claire/r2/appeal3 (never in git); the spec reads
`claire_v95_a_body.glb`, which is `cand_a.glb` without its spear node: the game's spear (its shaft and ice blade on `hand.R`,
`keep_slots` cloth and ice, so the old glove is left out) stays as it was, with its weights and the old atlas `claire_atlas.jpg`.

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/claire_v95.json WORK art/wardens/claire/claire.glb

Body: 13k triangles (head 2.6k) plus the spear, one 2048 atlas embedded. The master's sheer skirt is a flat colour with no
texture; tools/meshy/bake_warden.py now bakes such a material's base colour (opaque).
Slots by colour and box (first match wins): hair (white, head box), skin, fur (white trim), ice (cyan), cloth (the rest).
Slot fix: a face box comes first and is all skin. Without it the pale face triangles split between hair, skin and ice,
and the face shaded in facets.
Weights: bone heat from the spec's joints; the sheer back cape rides `hips` (legs excepted), the head box `head`.
Clip fix: the front braid hangs over her left chest; by heat it went to `forearm.L` and stretched from the chest to the hand
in idle. A `hips` box over the braid (the left arm and thigh capsules excepted) keeps it on the torso.

Lost from the scripted build (tools/art1/claire_source.py, claire_pieces.py, claire_finish.py, claire_paint.py: replaced, not merged):
the modelled lids (blinks no longer show; `lid`/`brow` bones move nothing); the ears, braid, bow, scarf and puff tail are the
master's, part of the body by bone heat (the ears on `head`), so the spring chains, `skirt` and `scarf` carry no weight; her hands
are the master's open gloves.

Rig unchanged: archetype body legs 2.04, torso 0.96, shoulder 0.84, neck -0.04, size 1.1.
Anchors moved through the fit: `anchor_head_top`, `anchor_chest`, `anchor_eye_l/r`, `anchor_clasp`, `anchor_tail_tip`.

Shots on the in-game rig (Godot, `--shots`): docs/shots/claire-appeal-a/ (front/3-quarter, back, side in the turnaround,
face close-ups, idle/run/attack/cast/ult at the match camera, run close). Checks: --warden-glb-check rimewright ok (the one
fail is tender's hit flash, the same on the base), --warden-model-check 157/157.
Stretch check: all 49 clips over 1.3 (worst 6.61 revive, idle 6.01, run_f 3.15), almost all
in `hips`; before the braid fix: worst 8.01, idle 6.35, run_f 5.72. The relax runs with CUTS 0 (no holes), as Lace, Sparkle and Meeko, so a stretched
edge stays rather than a hole; it is not reworked here.

Clip re-key (2026-11-11, docs/heroes/rimewright.md "Animation timing"): `dart_r`, `dart_l`, `dart_heavy`, `beam`, `wall`,
`freeze` and `clench` re-baked from `~/meshy/claire_v2/stage/c/claire.blend` (hetzner) by `tools/art1/claire_clips.py` with
those names as its third argument, then put into this file by `python3 tools/art1/glb_add_clips.py claire.glb claire_rk.glb
dart_r,dart_l,dart_heavy,beam,wall,freeze,clench` (no re-swap: same skeleton; a control clip, `shatter`, came out bit-equal).

walk and run, on foot (2026-11-11): the Meshy-rig retarget of ext/anim-pilot-albert-neve (`walk_f`, `run_f`, copied with `glb_add_clips.py` onto this v95 body, same rig) re-pinned with `tools/art1/hunter_dir_gait.py` (Blender 4.5, CPU): `-- SRC.glb F.glb 2.54 5.31 f 0.5625 0`, `glb_add_clips.py SRC F walk_f,run_f S1`, then `-- S1 D.glb 2.54 5.31 b,l,r,fl,fr,bl,br` and `glb_add_clips.py` again. The speeds are her 2.2 / 4.6 m/s over her in-game model scale 0.867 (the gait tool works in model metres; pinned at 2.2 / 4.6 the soles covered only 3.8 / 4.0 m/s of ground, which was the skate). Walk 0.5625 s (27 keys, duty 0.40), run 0.604 s (duty 0.18); every planted sole 100 % within 5 %, seams 0, diagonals in step; the swing meets the floor at 0.95 of the ground speed (`MEET`, was 0.6: the foot scuffed forward at the strike). Her skate stays `skate*`/`tm_skate`. claire.json `loco`: `stride` [1.0, 1.0] (no thigh stretch on a pinned clip), `foot_mps` [2.0, 4.4] (the game's blend reads it a touch slower than baked). `--anim-audit`: run slide 24 % at the ankle (gate 25 %), 21 % at the sole; walk 19 % at the sole.

**11-17 restore (job 20261117-172201-a1):** body re-ported from the current pick `~/meshy/v95/Neve/board1117/B/cand.glb` (its body
node only; `python3 tools/art1/v95_to_game.py claire --master <B body>`), then the owner's spear A (11-16: candy-cane shaft, faceted
ice-heart head) from the same master as a separate 4k-tri mesh `spear` rigid on hand.R (`tools/art1/v95_prop_swap.py`, material
`cloth-spear`, image `claire_v95p.jpg`); the old atlas spear faces are gone and weapon_muzzle / anchor_blade_root / anchor_blade_mid
sit on the new head. 59.9k tris, same rig and 61 clips.
