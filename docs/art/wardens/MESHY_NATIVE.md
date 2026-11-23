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
  (WardenCarry.hold_mote). The clips advance by hand in `_process` (AnimationMixer manual mode), then the layers. Still
  off: springs, look-at, drop pose, squash, blink, moods. `WardenGlb.layers(model)` is the layer node either way.
- Extract: the beat (`WardenClips.leave_t`, 0.7 s) plays Meshy's crouch for the dip, then its jump for the take-off.
- Anchors from the contract `.glb` (every `anchor_*` and `weapon_muzzle*` data `anchors` does not place) ride the Meshy
  bone `find` names for their contract bone at the same offset from its head; one on a bone with no stand-in (a tail
  spring) rides the nearest Meshy bone. The Gun's Muzzle sits on the copied `weapon_muzzle` each frame.
- HunterAnim still poses the hidden rig and hands over its state (`WardenClips.STATE`); the AnimationPlayer plays:
  idle `Idle`, walk `walk`, run `run`, air `Jump_Run`, any new swing/cast/kit move `Attack` (or its clip slot below), crouch
  `Crouch_Walk_with_Torch` (rate follows ground speed; standing still holds the crouch pose).
- Crouch arms (`crouch_arms_from`): Meshy's only crouch holds a torch out in front, which read in game as Sable's
  pistol and Tenzo's stone arm floating off the body. The crouch plays a copy (`<clip>_arms`, added beside Meshy's
  clips at load) whose arm bones (every bone below Meshy's `LeftShoulder`/`RightShoulder`, data `arm_roots`) take
  the walk clip's keys, time-scaled to the crouch loop; hips, spine and legs keep Meshy's crouch.
- Size: Meshy's head bone is scaled onto the rig's head pivot (the contract model's head height). Hit ring and
  hitbox are the rig's, unchanged.
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
`--warden-glb-check` counts native Hunters apart. Renders: `--clip-shots --warden=<arch> --states [--match]`.

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
| `hit` | one-shot when a hit lands (state `hit_t` jumps back) and pushes the body against its facing (struck from the front) | the loop clip plays on |
| `hit_back` | the same, when the hit pushes the body the way it faces (struck from behind); a Hunter with one of the two plays it for both | `hit` |
| `land` | one-shot on a hard landing (`WardenClips.FEEL` landing >= `LAND_MIN`) | the loop clip |
| `dash` | while the state `rolling` (a dash or kit rush) lasts | the air or ground clip |
| `glide` | while `gliding` (loops) | `jump` |
| `downed` | while the knocked-down beat runs (`fall` >= 0; holds its last frame) | the loop clip |
| `stomp` | while the stomp cycle runs (`stomp` >= 0; loops) | the loop clip |
Swing, cast, `hit` and `land` are one-shots: they own the body for their length (a new one restarts a clip once 60% is
played) and play at `attack_rate`, `hit` and `land` at 1. A hit wins over a swing, a swing over a landing.
A clip may come from an animation-only file `art/wardens/<art>/<art>_clips.glb`, packed with `native_pack.py` onto the
same skeleton (Y-up Hips as in the main file). Clips the data names that Meshy's own file lacks are looked up there by
clip name, their tracks laid on this skeleton's bones by bone name (tracks of a bone it lacks are dropped), and added
once to the shared library (`WardenNative.borrow`). A slot whose clip is in neither file is dropped with a warning and
plays today's clip.
`--warden-native-check` rows (per Hunter, per slot): the slot empty plays today's clip; the slot filled plays its clip
with at least 10 bones off Meshy's T-pose on the switch frame and after the crossfade; a charged swing takes `lmb`
without `lmb_hold`; a synthetic clips file's clip lands on Meshy's bones and plays; every slot the data names has its clip.

## State clips (dash, glide, land, hit, hit_back, downed)
All ten native Hunters map these six slots to the clips of `art/wardens/<art>/<art>_clips.glb`, built by
`python3 tools/meshy/native_states.py OUT BASE_meshy.glb tools/meshy/native_states.json SRC_DIR <art>` (spec: Meshy
library action id, kept second range, game seconds, per weight class; sources are one `animate` download per action id
on one rig task, `/home/boki/meshy/anim-native-states-1123`). The clip file carries no mesh; translations scale by hips
height. Timing is the source's number, not the motion's own length: land = `land_feel.json` drop seconds (light 0.24,
medium 0.30, heavy 0.50), hit = the contract's stagger 0.42 s, downed = `HunterFall.STYLE` seconds (0.4/0.45/0.5, last
frame held), dash = the kit's own dash time (`dash_s` per Hunter: hem 0.27, ryzz 0.24, sable 0.48, claire 0.45, gil 0.55,
tarek 0.26, ostra 0.45, pip 0.23, kael 0.24, cinder 0.33; hold or teleport dashes play a 0.45 s burst, last frame held).
The glide is one 0.4 s arms-out cut played there and back (1.2/1.5/1.8 s a loop by class).

| Class | Dash | Glide | Land | Hit front | Hit back | Downed |
|---|---|---|---|---|---|---|
| light (hem, ryzz, sable, claire, gil) | Lean Forward Sprint | Jump with Arms and Legs Open | Jump with Arms Open (tail) | Face Punch Reaction | Hit in Back While Running | Shot and Fall Backward |
| medium (tarek, ostra, pip) | Standard Forward Charge | same, slower | Dive Down and Land (tail) | Hit Reaction 1 | same | Falling Down |
| heavy (kael, cinder) | Male Head-down Charge | same, slowest | Jump and Slam Back Down (tail) | Hit Reaction to Waist | same | Shot and Slow Fall Backward |

`--clip-shots --warden=<art> --states [--bare-slots]` shoots idle, walk, run, jump, attack, crouch, then dash, glide,
land, hit front, hit back and downed (`--bare-slots` drops the six slots: the before).

## Not on the native path (yet)
Death, stun, ledge, emote and clips for moves beyond the slots above (Meshy gave six); the contract's per-hunter extras (Tenzo's
ground rings, Sparkle's blink, Sable's braid springs); 300k-tri meshes vs the 80k contract budget.

## Sable: hybrid rig (Meshy rig, scripted weight fixes)
`art/wardens/sable/sable_meshy.glb`: 78,000 tris (master decimated BEFORE rigging, budget 80k), Meshy's 42 bones with
fingers, untouched names and tree, Meshy's six clips. Only the weights and the coat bones' rotation keys differ from
Meshy's files (`tools/meshy/sable_hybrid/README.md`: pistol/hand lock, coat/arm split, coat and armpit smoothing,
contact-band smoothing, coat chains hung by gravity with floor and thigh collision). Torn frames (glbstretch, 15 fps):
raw Meshy rig 100% Attack, 93% Jump, 100% Crouch, 89% run, 67% walk; this file 0% in all six clips.
Game states with no Meshy clip (fall, land, glide, climb, mantle, hit, emote, aim twist) play the nearest of the six.

## Native hunter pack (Sparkle, Tenzo, Cinder, Kael, Motley, Meeko)
Their rigged Meshy files carry 300k-tri meshes. `tools/meshy/native_hunters/pack.sh <art> <rigged.glb> <decimated.glb> [clip glbs]`
decimates the mesh in Blender (`decimate.py`: material by material, head and face kept at 35%, UV seams kept, 80k tris),
grafts it back into the rigged file by material name (`graft.py`: Meshy's node tree, skeleton, skin joints and clips stay
as Meshy made them; only the vertex data is replaced) and packs it with `native_pack.py` (2048 atlas, 1024 maps). The
Sable weight fixes are not applied to these. Tenzo rides `orbit_stones`, Motley `orbit_cards`, both on `Head`.
Every state plays one of the six clips (the same map as Sable's), so none can T-pose.
