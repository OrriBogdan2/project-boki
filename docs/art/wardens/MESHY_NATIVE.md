# Hunters on Meshy's own skeleton (meshy_native)

A Hunter can be drawn on the skeleton Meshy's auto-rig made, playing Meshy's own clips, instead of the 14-bone
contract (RIG_CONTRACT.md). The game adapts to Meshy: its bones are never renamed, retargeted, merged or dropped.

## Switch
`content/rules/warden_native.json`, keyed by art name: `"meshy_native": true` and the file
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
  idle `Idle`, walk `walk`, run `run`, air `Jump_Run`, any new swing/cast/kit move `Attack`, crouch
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

## Not on the native path (yet)
Death, stun, ledge, glide, emote and per-move clips (Meshy gave six); the contract's per-hunter extras (Tenzo's
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
Grimble has no hit clip: a hit is the Hips flinch spring (WardenFlinch) over the playing clip.
The gun's hip is data (`holster.hip.pos`, x +0.17 = his left, where the gauntlet draws it).
