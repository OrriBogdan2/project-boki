# Hunters on Meshy's own skeleton (meshy_native)

A Hunter can be drawn on the skeleton Meshy's auto-rig made, playing Meshy's own clips, instead of the 14-bone
contract (RIG_CONTRACT.md). The game adapts to Meshy: its bones are never renamed, retargeted, merged or dropped.

## Switch
`content/rules/warden_native.json`, keyed by art name: `"meshy_native": true` and the file
`art/wardens/<art>/<art>_meshy.glb` present. Off (or no file): the contract model as before. On now: Sable (sable, the hybrid rig below) and the six hunters packed by `tools/meshy/native_hunters` (Sparkle ryzz, Tenzo tarek, Cinder cinder, Kael kael, Motley ostra, Meeko pip). Neve (claire, native Meshy r2) is on too. Gil is off: his only rigged file is a Tripo skeleton, not Meshy's. The contract `<art>.glb` stays beside it untouched.
`art/wardens/<art>/<art>_meshy.glb` present. Off (or no file): the contract model as before. On now: Sable (sable, the hybrid rig below) and the six hunters packed by `tools/meshy/native_hunters` (Sparkle ryzz, Tenzo tarek, Cinder cinder, Kael kael, Motley ostra, Meeko pip), and Gil (gil, r6: `gil_meshy.glb`, Meshy rig, 60k-tri body plus the 3k swordfish; the fish is the contract's `metal-swordfish` part carried on the right hand with data "scale" and "grip"). The contract `<art>.glb` stays beside it untouched.

## What changes on the native path (scripts/heroes/warden_native.gd)
- `WardenGlb.path/will_dress/dress` hand the Hunter to `WardenNative.dress`: no WardenSync. The contract layers that
  need only bones run on Meshy's bones through the one bone lookup `WardenSkeleton.find` (contract name -> Meshy bone,
  RIG_CONTRACT.md "Bone lookup"; data `bones` adds a Hunter's own): the hit flinch (WardenFlinch on `Spine02`), the
  wall kick's plant and push (WardenWall), the open channel's reach (WardenOpen.make_on) and the Heartspark carry
  (WardenCarry.hold_mote), the drop's ride and skydive poses (WardenDropPose, the contract numbers of
  content/rules/drop_poses.json) and the landing squash (WardenClips.lay_feel: HunterAnim's land_k by weight class,
  content/rules/land_feel.json, times WardenClips.LAND_SQUASH, on Meshy's `Hips` about the feet; the Hips scale goes
  back to rest each frame, as Meshy keys none). The clips advance by hand in `_process` (AnimationMixer manual mode),
  then the layers. The head's look-at (WardenLookAt, LOOK_AT.md) runs on `Head`, with `neck` and `Spine02` taking a
  share. Still off: springs, the run-start lean, blink, moods. `WardenGlb.layers(model)` is the layer node either way.
- Extract: the beat (`WardenClips.leave_t`, 0.7 s) plays Meshy's crouch for the dip, then its jump for the take-off.
- Anchors from the contract `.glb` (every `anchor_*` and `weapon_muzzle*` data `anchors` does not place) ride the Meshy
  bone `find` names for their contract bone at the same offset from its head; one on a bone with no stand-in (a tail
  spring) rides the nearest Meshy bone. The Gun's Muzzle sits on the copied `weapon_muzzle` each frame.
- HunterAnim still poses the hidden rig and hands over its state (`WardenClips.STATE`); the AnimationPlayer plays:
  idle `Idle`, walk `walk`, run `run`, air `Jump_Run`, any new swing/cast/kit move `Attack` (or its clip slot below), crouch
  `Crouch_Walk_with_Torch` (rate follows ground speed; standing still holds the crouch pose).
- Own move clips (data `clip_files` + `kmoves`, 11-23, Kael first): a clips-only file beside the model
  (`art/wardens/<art>/<art>_clips.glb`, the rig's nodes with no mesh; WardenClipFile adds its clips to Meshy's library
  by bone name) holds clips keyed on Meshy's skeleton, and `kmoves` (WardenNativeMoves, see Kit-move clips) maps a kit move (`kmove`) to one: `clip`, `fade` (a clip with no
  `hold_from` stays on its last pose while the kit holds the move), and for the check `hit` (the kit's hit second) with
  `peak` (`speed`, `low`, `reach`: how the clip's hit pose is measured). The clip's clock is the kit's (`kmove_t`),
  so its hit pose lands on the kit's hit. A move with no entry still plays `Attack`. Kael's are made by
  `python3 -I tools/art1/kael_native_clips.py` (poses as body-frame numbers: hips, chest, feet, sword hand and blade
  direction, solved with two-bone IK by `tools/art1/meshy_rig.py`; the blade runs along the right hand bone). Timing and
  poses: docs/heroes/juggernaut.md "Native clips". `--warden-native-check` sweeps each clip and asserts the hit pose
  within one frame of the kit's hit; `--clip-shots --states` presses each mapped move.
- Crouch arms (`crouch_arms_from`): Meshy's only crouch holds a torch out in front, which read in game as Sable's
  pistol and Tenzo's stone arm floating off the body. The crouch plays a copy (`<clip>_arms`, added beside Meshy's
  clips at load) whose arm bones (every bone below Meshy's `LeftShoulder`/`RightShoulder`, data `arm_roots`) take
  the walk clip's keys, time-scaled to the crouch loop; hips, spine and legs keep Meshy's crouch.
- Size: Meshy's head bone is scaled onto the rig's head pivot (the contract model's head height). Hit ring and
  hitbox are the rig's, unchanged. Data `size` (as Dredge's 1.09) then scales a body whose visible height stood over
  10% off the owner's height chart (hit_h, plus the headwear the chart allows over the head; drawn as a match draws it, x1.12): Kael 1.2,
  Pip 0.79, Gil 0.69. The contract's parts, anchors and companions are placed as for the unfitted body and grow with
  it (`WardenNative._to_contract`). The hitbox never changes: its numbers are parity rows.
- Facing: Meshy faces +Z; the model is turned 180 deg to face -Z like every Hunter.
- Anchors (`anchors`): `anchor_head_top`, `anchor_chest`, `anchor_gun_R` are BoneAttachment3D nodes on Meshy bones,
  found by `WardenGlb.anchor`. The rig's Gun (aim and muzzle) rides Meshy's `RightHand` bone each frame.
- Materials: Meshy's textures through the game's hero-toon pass (`WardenGlb._toon`, the same call as the contract
  models: painted shading, ink shell, match-zoom read, the Hunter's `warden_look.json` "painted" keys) and into meta
  `mats`, so hit flashes and team looks reach them. Meshy's material names (`head`, `body`, `Material_0`) are no toon
  slot, so they shade as cloth; per-slot looks do not apply. `"toon": false` keeps Meshy's PBR.

## Building the .glb
`python3 tools/meshy/native_pack.py OUT BASE [CLIPS[=name] ...] --in-place=Crouch_Walk_with_Torch`: BASE is Meshy's
rig (or its weight-fixed hybrid); clips from the other Meshy files are matched by node name; Meshy's animate files
keep the armature Z up, so their Hips keys are carried into the rig's Y-up frame. Colour textures are capped at
2048 px, normal and metal/roughness maps at 1024 px.

## Checks
`--warden-native-check` (switch, bones, facing, height, each state's clip, weapon hidden, anchors, toon surfaces,
crouch arms, only Meshy's model draws (no rig mesh such as the Offhand), each data orbit rides its bone and turns);
`--warden-glb-check` counts native Hunters apart.
`--native-hitbox-check` measures each one's visible body (skinned vertices at idle, no weapon, orbits or companions)
against hit_h and the hit ring and fails past 10% on height; `--native-hitbox-shots` draws each inside its hurtbox.
Renders: `--clip-shots --warden=<arch> --states [--match]`.
crouch arms, only Meshy's model draws (no rig mesh such as the Offhand), each data orbit rides its bone and turns,
the drop poses hold --clip-check's bars); `--land-weight-check` measures every native Hunter's squash off the model
(head height against the same frames unsquashed: depth and seconds within 10% of the contract numbers, feet on the
ground); `--land-weight-shots [--before]` renders light, medium and heavy native Hunters landing (GPU);
`--warden-glb-check` counts native Hunters apart. Renders: `--clip-shots --warden=<arch> --states [--match]`.
Online: each `--remote-anim-1|2|3|rest-check` shard ends with a native row (Lace, Kael, Sable, Gil): through the
online-feel proxy at 100 ms each way, the other player's copy plays the same state and clip as the owner's (idle,
walk, run, air, attack, crouch, the extract beat) in order, at the same pace per state, with no stalled loop and no
one-frame snap of the hand. A freshly dressed model reads its first filled state as the baseline (no phantom attack
from old counters) and poses its idle at once (no rest T-pose frame).

## Footsteps
Steps sound on the plants of the Meshy feet you see, not on the hidden rig's stride (`HunterAnim` phase, which ran at
another cadence than Meshy's walk: ~1.0 vs ~1.5 steps/s at walk speed, up to ~20 frames off a visible plant).
`scripts/heroes/warden_native_steps.gd` (`WardenNativeSteps`) reads data `plants` {walk, run, crouch: {L, R: seconds
into Meshy's clip}} and bumps the model's `WardenSteps.STEPS` as the contract path's `WardenSteps` does; `HunterAnim`
hands it on as `stepped`. No `plants` entry (Motley hovers): the old stride. `--step-sync-check` has native rows per
Hunter: the plants read off Meshy's `LeftFoot`/`RightFoot` in each clip, the data within one frame of them, every step
heard at two walk, two run and a sneak speed within one frame after a plant of that foot, the feet alternating through
a walk-run ramp, no step standing. Swap a clip and the check names the new plants to paste into the data.

## Weapons and orbit props
Meshy's mesh carries the weapons (Sable's two pistols, Tenzo's one stone arm), so the rig's Gun and HunterAnim's
Offhand (the twin hold's left piece, the fist hold's second gauntlet) stay hidden: shown, they floated beside the body
in every frame. Props that orbit (data `orbits`: orbit node -> Meshy bone; Tenzo's three seeing-stones on `Head`) are
copied from the contract `<art>.glb` and turned by WardenOrbits as on the contract path. Their holder follows the
bone's place, not its turn, so the ring stays level when a clip bows the head.
Parts the contract model has and Meshy's mesh lacks (data `props`: contract bone -> material names; Kael's sword on
`hand.R`, Cinder's heel jets on `jet.0`/`jet.1`) are cut out of the contract `.glb` by material and hung rigidly on the
Meshy bone that plays that bone (WardenProps): limb onto limb, the contract's ahead onto Meshy's thumb or toes, then
bent by data `tilt` (Kael's blade lies along his arm: Meshy's clips do not bend the wrist as his contract idle does).
The contract's anchors on that bone ride the part (the blade tip on the blade). Data `stretch` {kmove, y, rest} keys
the parts' length as the contract clips key Cinder's jet bones (x0.06 at rest, x3 in Flue Flight). Floating companions
in Meshy's mesh (Meeko's sun and cloud, surfaces named as in `warden_anim/<art>.json` "companions") are cut out and
circle her as on the contract path, the data's skeleton space carried onto Meshy's.

## Clip slots (per-move and per-state clips)
Data `clips` may add any of these keys beside idle, walk, run, jump, attack and crouch. Each names a clip; a missing key
plays today's clip, so nothing changes until a Hunter's clips land (`WardenNative._one_shot` / `_held`).
| Key | Plays | Without it |
|---|---|---|
| `lmb` | a melee swing or a shot | `attack` |
| `lmb_hold` | a charged swing (state `combo` -1) | `lmb`, then `attack` |
| `rmb`, `e`, `r` | the kit move or cast of that slot (state `cast_slot` secondary, utility, ult; a kit move starting within `SLOT_CAST` of a cast takes its slot) | `attack` |
| `hit` | one-shot when a stagger lands (state `hit_t` jumps back with `hit_k` at Oomph.HEAVY_FLINCH; a chip hit only leans) | the loop clip plays on |
| `land` | one-shot on a hard landing (`WardenClips.FEEL` landing >= `LAND_MIN`) | the loop clip |
| `dash` | while the state `rolling` (a dash or kit rush) lasts (blends in over 0.25 s) | the air or ground clip |
| `glide` | while `gliding` (loops; opens at once, lets go over 0.2 s) | `jump` |
| `downed` | while the knocked-down beat runs (`fall` >= 0; holds its last frame) | the loop clip |
| `stomp` | while the stomp cycle runs (`stomp` >= 0; loops) | the loop clip |
Swing, cast, `hit` and `land` are one-shots: they own the body for their length (a new one restarts a clip once 60% is
played) and play at `attack_rate`, `hit` and `land` at 1.
A swing or cast while he moves on the ground, or is in the air, plays on the torso and arms only (`WardenNativeUpper`: Spine02
and every bone above it, eased in 0.1 s and out 0.16 s) over the running legs; standing on the ground it owns the body as
above, and `hit` and `land` always do. A hit wins over a swing, a swing over a landing.
A clip may come from an animation-only file `art/wardens/<art>/<art>_clips.glb`, packed with `native_pack.py` onto the
same skeleton (Y-up Hips as in the main file). Clips the data names that Meshy's own file lacks are looked up there by
clip name, their tracks laid on this skeleton's bones by bone name (tracks of a bone it lacks are dropped), and added
once to the shared library (`WardenNative.borrow`). A slot whose clip is in neither file is dropped with a warning and
plays today's clip.
`--warden-native-check` rows (per Hunter, per slot): the slot empty plays today's clip; the slot filled plays its clip
with at least 10 bones off Meshy's T-pose on the switch frame and after the crossfade; a charged swing takes `lmb`
without `lmb_hold`; a synthetic clips file's clip lands on Meshy's bones and plays; every slot the data names has its clip.

## Own clips for kit moves (Cinder)
A Hunter whose kit moves Meshy's one Attack does not fit gets its own clips on Meshy's skeleton: a clips-only `.glb`
(`art/wardens/<art>/<art>_clips.glb`, an animation file, never the model, read by clip name like the slots'), played by
data `kmoves` (kit move id -> {clip, then, hold, upper}; WardenNativeMoves, the same rows as the kit-move clips below). They run on the kit's own clock (state `kmove`,
`kmove_t`), so the pose lands on the frame the kit fires. An `upper` clip keys only torso, head and arms and lies over
the legs' clip (walk, run, idle, the air) at a weight that rises in 0.08 s and falls in 0.2 s; any other row is a
full-body clip on the main player. Data `own_casts` stops her casts and recoils playing Meshy's swing.
Cinder (hands, no weapon: DECISIONS 11-07), written by `tools/meshy/cinder_native_clips.py` (numpy FK and two-bone IK on
Meshy's node tree, no Blender): `as_lance` the pilot's 0.26 s spool then the 8 Hz-bucking hold from her right palm,
`as_lance_end` the let-go, `as_aim` the 0.4 s cast sighting along the arm (held), `as_shot` the push on the frame the bolt
spawns (the palm already at the eye, the push 0.07 s in), `as_cloak` a tuck then both arms flung wide by 0.04 s,
`lw_jet` the take-off crouch and spring (0.22 s, the kit's lift) then the leaning flight loop, `lw_land` the light landing.
The fire leaves from `weapon_muzzle` on her right hand (the palm), which rides the posed bone. Checks:
`--warden-native-check` (each row's clip, pose and hand-over), `--muzzle-check`; renders: `--clip-shots --warden=ashwick
--states [--match] [--no-moves]` (`move_<id>_<stand|run>/`).

## Own clips retargeted from the contract file (Sparkle first)
A Hunter whose hand-keyed contract clips (`art/wardens/<art>/<art>.glb`, RIG_CONTRACT.md) still fit her kit lays them on
Meshy's skeleton with `python3 -I tools/meshy/native_retarget.py <art> [--moves] <clip>[:full] ... [--shot]` (`--moves`: every kit move of `content/rules/warden_anim/<art>.json`, printing the data's `kmoves` rows; Sparkle: `ryzz --moves crouch_f:full`) (no Blender; the IK of
`tools/meshy/cinder_native_clips.py`). Each clip is sampled at 30 fps on the contract rig: the torso lean and head turn go to
Meshy's spine and neck, each wrist keeps its reach from its shoulder (scaled to Meshy's arm), elbow side, hand direction and
roll; a `:full` clip also takes the hips' height and the ankles' travel (scaled to Meshy's leg, so a crouch's planted feet stay
planted). Clips are named `<art>_<clip>` and written to `<art>_clips.glb`; the data's `kmoves` rows and `clips` slots name them
(a clip with no `:full` is an `upper` row). `--shot` prints each clip's worst wrist miss (Sparkle: under 2 cm). Sparkle (ryzz):
the 17 kit-move clips of her contract rows (`mage_lmb_*`, rmb, Skycall, Wirerun, Kitefall, fusion) and her own crouch walk
(`ryzz_crouch_f`, data `clips.crouch`, no torch and no `crouch_arms_from`), `own_casts` on: no kit move plays Meshy's Attack.
Meeko (pip, arch `tender`): the same with her 17 contract kit-move clips and `pip_crouch_f` (`own_casts` on; crouch_mps tuned to a +2.9 cm/step slide by `--foot-slide-check`).
Neve (claire, arch `rimewright`): her 20 contract kit-move clips and `claire_crouch_f` (+1.4 cm/step).
Sable (sable, arch `thief`): her 18 contract kit-move clips (`thf_*`) and `sable_crouch_f` (+0.4 cm/step); the pistols aim along the retargeted hands.
Tenzo (tarek, arch `dolm`): his 19 contract kit-move clips (`breah_*`) and `tarek_crouch_f` with `crouch_f:full:stride=1.16` (his Meshy legs are 0.69 of the contract's, so the strides run too short for the ground speed at the 1.8x rate cap; stride=K lengthens the fore and aft travel: +0.1 cm/step, was +8.3). `own_casts` stays off (his punches and throws are melee).

## Kit-move clips (data `kmoves`)
A kit move (state `kmove`, the move's id) may have a clip of its own: `"kmoves": {kmove: {"clip": name, "hold_from": s,
"rate": x, "fade": s}}` (`WardenNativeMoves`). While the move lasts the clip is laid at the move's clock (`kmove_t`), so a
release move, which the kit starts at the frame the arrow leaves, shows its release on its first frames. `hold_from` loops
the clip from there to its end for as long as the move lasts; the kit ends the draw move with the hold input, so the loop
never shows without it. A move with no clip, or whose clip no file has, keeps the slot clips above. The clips come from
`<art>_clips.glb` by name like the slots'. Lace's (`tools/meshy/lace_clips.py`, poses by limb direction on her skeleton,
no retarget; the string follows the drawing hand on `StringMid`): `lace_draw`, `lace_over`, `lace_tap`, `lace_loose`,
`lace_super`, `lace_heavy_wind`, `lace_heavy`, `lace_spirit`, `lace_ult`, `lace_ult_final`. The clips are the whole body
(the contract's upper-body layer is not on this path): the feet of the draw and Spirit Walk clips do not follow the ground.
`--warden-native-check` rows (per kit move): the clip is there, plays on the move and is no T-pose; a hold loop stays in
`[hold_from, end]` while the move lasts and is gone when it ends; a release has the string drawn on its first frame and
back on the bow a frame later.

## Look-at on Meshy's bones
`WardenLookAt.make(model, skel, true)`: the same layer, limits (70 deg yaw, 25 deg pitch) and smoothing as the contract path,
laid after the clip and the air tilt. The turn is shared down Meshy's chain so the head's total turn is the contract's
figure: the chest (`Spine02`, `WardenSkeleton.find "hips"`) takes 20% of the yaw, the neck (the head bone's parent) 30% of
yaw and pitch, the head the rest. It is off for the same states as the contract path, and under Meshy's Attack clip (which
plays for any swing, cast or kit move): the layer eases out as that clip takes the body (`owned`, over `FADE`) and back in
after it, so it does not fight a clip that already turns the head. `--look-at-check` runs it on every native Hunter.

## Not on the native path (yet)
Death, stun, ledge, emote and clips for moves beyond the slots above (Meshy gave six); the contract's per-hunter extras (Tenzo's
ground rings, Sparkle's blink, Sable's braid springs; loose parts only through data "springs" below); 300k-tri meshes vs the 80k contract budget.

## Sable: hybrid rig (Meshy rig, scripted weight fixes)
`art/wardens/sable/sable_meshy.glb`: 78,000 tris (master decimated BEFORE rigging, budget 80k), Meshy's 42 bones with
fingers, untouched names and tree, Meshy's six clips. Only the weights and the coat bones' rotation keys differ from
Meshy's files (`tools/meshy/sable_hybrid/README.md`: pistol/hand lock, coat/arm split, coat and armpit smoothing,
contact-band smoothing, coat chains hung by gravity with floor and thigh collision). Torn frames (glbstretch, 15 fps):
raw Meshy rig 100% Attack, 93% Jump, 100% Crouch, 89% run, 67% walk; this file 0% in all six clips.
Game states with no Meshy clip (fall, land, glide, climb, mantle, hit, emote, aim twist) play the nearest of the six.
Strafing and back-pedalling: Meshy has one forward run, so `WardenNativeTwist` turns the hips to the way he goes (the torso bone takes
the turn back in world space, through the bent spine between, so the body stays on the aim without tipping) up to `WardenClips.TWIST_MAX` (~96 deg). More than 120 deg off the aim (it reverses at 130
and goes forwards again inside 110: no flicker at the edge) the run clip plays in reverse instead, the rate keeping its stride matched to the
ground speed, and the legs turn only by what is left to dead behind the aim (none at 180 deg, from either side). The clip's direction
(`WardenNativeTwist.dir`) eases between +1 and -1, so the crossing is a blend. `--native-upper-shots --mode=back` prints STRIDE (the planted foot's
sweep against his travel, 1 = along it, -1 = backwards to it).

## Native hunter pack (Sparkle, Tenzo, Cinder, Kael, Motley, Meeko)
Their rigged Meshy files carry 300k-tri meshes. `tools/meshy/native_hunters/pack.sh <art> <rigged.glb> <decimated.glb> [clip glbs]`
decimates the mesh in Blender (`decimate.py`: material by material, head and face kept at 35%, UV seams kept, 80k tris),
grafts it back into the rigged file by material name (`graft.py`: Meshy's node tree, skeleton, skin joints and clips stay
as Meshy made them; only the vertex data is replaced) and packs it with `native_pack.py` (2048 atlas, 1024 maps). The
Sable weight fixes are not applied to these. Tenzo rides `orbit_stones`, Motley `orbit_cards`, both on `Head`.
Every state plays one of the six clips (the same map as Sable's), so none can T-pose.

## Grimble (dredge): goo arm, pack, coin cap (r7), tail chain and cleanup (r8), right leg and lean (r10)
`art/wardens/dredge/dredge_meshy.glb` (skin-native, skin-goo, hoard pack, coin cap) is the r5 body re-skinned by
`tools/meshy/dredge_reskin.py OUT R5 R3 [tail_arm]` (`--stretch FILE.glb` lists edges stretched >3x and over 6 cm).
- Goo: one mesh, no cuts (r6 cut it at 0.8 m, which left floating pieces). Own vertex copies, Meshy's weights without
  any leg bone, one weight per welded position (UV seams used to tear), a blend from the arm chain (above 0.9 m) to
  the hips (below 0.3 m; `tail_arm` is the share of arm motion its end keeps), so the tail stays near the floor.
- Skin: the shin Meshy fused the goo to carries no arm weight. The skin around its holes (they show black ink hull
  once the goo moves off them) gets an inside-out lining 4 mm behind it, on the same bones.
- Pack: rigid on the spine. Coin cap: texture hue-shifted orange to gold, 0.7x about the skull.
Longest goo edge over Idle/Attack/run/walk/jump: 0.16 m idle, 0.20 run, 0.26 Attack at 0.5 s (1366 edges >3x and over
6 cm there; r6 35 but cut in pieces); skin 0.22 m (as r6).
r8, `tools/meshy/dredge_post.py OUT IN` on the r7 body (IN = the r7 glb, never the file it wrote; `--islands FILE` counts):
- Islands: a body piece (skin, goo, leather pack) of under 1000 triangles that touches no other (1 mm) is deleted,
  so the loose pink chunk and the torn shards are gone (skin and goo are one island each; the brass fittings and the
  coin pile are many small pieces on purpose). The pale crescent Meshy fused to the right heel (skin triangles of
  the goo's pale texture in a box beside the shin, 1197 triangles) is deleted too.
- Tail chain: GooTail0..3 under `RightHand`, the goo below the hand weighted along them by height (it bends, never
  shears against the hips). Each clip gets baked rotation keys for them: the first follows the hand, the rest keep
  their rest direction (they hang) and take 60/50/50 % of the bone above's turn with a lag. Goo edges over 3x and
  6 cm: Attack 0.5 s 113 (r7 1366), run 16, idle 0.
- Attack: the head and upper-spine bend of Meshy's lunge is cut to 35 % (Spine02, Spine01, neck, Head keys).
r10 (same tool):
- Right leg: Meshy fused dark spiky shards into the right instep and layered torn flaps up the shin (the right leg
  had 4x the left's triangles at the knee). Below 0.62 m it is replaced by a mirror copy of the clean left leg
  (x flipped, Left* bones swapped for Right*, fitted to the thigh). Both legs are two shells 4 mm apart; each shell
  is welded to its own along a flat seam (rims onto the copy's cross-section, copy rim vertices onto the thigh's rim
  edges), relaxed, and the inner shell near the seam wears the outer's texture. Skin stays 1 island.
- Attack: the lean that the Hips still pitched in (Head over Spine02, 38 deg at the slam, idle 10) past 12 deg is
  cut by 60 % with a counter-turn of Spine02 about the side axis: peak 21 deg, legs keep their plant.
- Goo: the arm-to-tail blend runs from 1.35 m (was 1.15): Attack 0.5 s 33 long edges (r9 109), run 0 (16).
r11 (`dredge_post.py --r11 OUT IN_R10 PACK`, PACK = Meshy image-to-3D of the turnaround's hoard with the top chest open, decimated to
14k tris in Blender, export only): the goo's tail chain keeps the forearm's twist (swing-only bones met the forearm's twist in the
blend zone and the tube collapsed to a ribbon; flat clusters at Attack 0.5 s 31 -> 5, stretched edges 49 -> 0), head/spine weights on the
goo move to RightArm, the open shoulder socket gets a dome (it showed as a black patch once the arm swung), and the hoard pack
replaces the leather bedroll (rigid on the spine).

r12 (`--r12`): the tail chain re-baked so a swung tail gathers (GooTail0 scale, GooTail1..3 translation per clip).
r13/r13b (`--r13`): skin weights welded, the goo puddle trimmed, rim caps on the open goo/shoulder rims (simple cycles wound like
their rims), faces below 1.2 m wound to their normals, the pack retextured, leather straps added (no ink room).
r14 (`dredge_r14.py`): mesh rebuilt on the r13b glb (liner shell, 3-across strap rows); r16b `--ball` put the contract's junk ball
rigid on Spine02. r15 (`--r15`): the goo arm's swing calmed in run/walk/jump. r16 (`--r16`): Idle stands on the walk's neutral
frame, the jump/glide pose is held. r17 (`--r17`): the goo arm hangs at its bind abduction (+HANG_OUT), the chain follows less.
r18 (`--r18 OUT IN ARM`): the fat goo is replaced by a slim Meshy arm (image-to-3D of the turnaround crop, 24k tris).
r19 (`--r19`): socket dome UVs from the left shoulder, strap rows lifted off the skin, the liner cut under the dome.
r20 (`--r20`): the dome reshaped on the mirrored left torso with its own baked texture; the right strap mirrored from the left.
r21 (`--r21`, `--r21-graft OUT IN FIST ROD`, `--r21-keys`; build script in gens/hunter-round-1124/grimble/r21/build_r21.sh):
the second junk ball copy dropped; every primitive keeps only the vertices its triangles use (the pre-r18 goo's ~80k
orphan vertices were what geo_check measured as a 16 cm "tail" clip); strap UVs inside the stitch lines and weights on
Spine02/Spine01/shoulders only, strap ink on; dome colour matched to the body round it; skin S -0.10 V +0.07 and goo hue -5
(eye-level medians skin S 0.54 -> 0.40, goo H 322 -> ~296; turnaround 0.38 / 301). A Meshy gauntlet fist (image-to-3D of an
edit of the turnaround crops, 6k tris after Blender decimate) replaces the r20 fist, its cuff ring blended onto LeftForeArm
(geo_check hand_L sep 0.13 -> 0.23); a Meshy knobbed rod (1.5k tris) stands in the pack on his left, rigid on the pack's bone.
Keys: per-key clearance eases (gauntlet arm out up to 15 deg, run/walk knees toward rest, run arm swing toward rest, goo
chain out in the attack): geo_check held pairs over 1 cm 33 -> 0. `warden_native.json` size 1.025: the head joint within 3 % of the contract's (--warden-native-check; 1.09 gave body_h 2.42 but the head +9 %).

Grimble has no hit clip: a hit is the Hips flinch spring (WardenFlinch) over the playing clip.
The gun's hip is data (`holster.hip.pos`, x +0.17 = his left, where the gauntlet draws it).

## Loose parts: spring chains on Meshy's bones (data "springs", pilot: Sable's coat tails)
A hunter's loose parts (tails, coat tails, skirts, capes) used to ride the clip's keys. `WardenNative` now builds `WardenSprings`
chains on Meshy's own bones when the hunter's entry in `content/rules/warden_native.json` has `"springs": [{"bones": [root ..
tip], "hang": true, "floor": m}]` (no key = clip keys only, as before). The root's parent carries it; the tip bone rides its
parent; the others are a rope in world space (momentum, pull to the rest shape, link lengths kept: `WardenSprings.step`).
`hang` pulls toward straight down from the root, `floor` keeps the joints that many metres over the ground. The layer runs
after the clip and the other bone layers and before the props. ON for Sable only: her two chains Bone_009 .. 007 and
Bone_013 .. 011 (no Blender change: Meshy's rig already has them and the weights carry the coat tails and moth wings).
`--warden-native-check` asserts the chain count per hunter, the stream-back in a run and the link lengths;
`--native-springs-shots --warden=thief [--no-springs]` films run, turn, lunge and stop at the match camera and eye level.
Proof: `/home/boki/gens/native-springs-1126/` (sheets sable_coat_springs_*.jpg, MP4, raw frames).
Seen: in the deep lunge and the stop the tails hang down and stay inside the silhouette (the clip's baked keys fan them out
over the thighs); in a run they trail more; at the match camera (fov 8, 66 deg down) the change is too small to read.
Known gaps: no leg collision (a back leg can pass through a tail), both tails can drift to the same side in a turn.

### Plan: Cinder tail, Lace skirt, Kael cape (not built; glbs untouched)
1. Cinder tail: bones Bone_016 (child of Hips) -> Bone_006, 11 bones, already weighted; the tail lies out on the floor. A
   rest-shape chain (no `hang`), `floor` on. Needs one new thing in WardenSprings: push-out from the thigh and shin joints
   (data "avoid": [bone names], radius) so the tail stops passing through the legs; measure it with a check that samples every
   joint against the leg capsules in run, lunge and stop.
2. Lace skirt: `hem_meshy.glb` has eight single bones SkirtSw0..7 round the Hips, no chains. Either add a 2-bone hem
   chain under each in Blender (rig step, weights split by height; no visible change) and hang them with `floor` plus the
   same leg push-out, or add a one-bone "swing" mode (spring on the bone's rotation). Check first whether her lace_* clips key
   SkirtSw (a spring would fight keys); then lower the clip's weight on them.
3. Kael cape: `kael_meshy.glb` has no cape bones (the cape rides Spine and the shoulders). Add three chains of three bones
   under Spine02 in Blender (rig step), re-weight the cape's vertices down the chain, hang them with a back plane so they do
   not enter the body. Check that no job is rigging Kael's sword or clips (ext/anim-kael-native-clips).
Order: Cinder (no glb change), Lace, Kael. Each: flag in the data, the same shots tool, a check line per hunter.
