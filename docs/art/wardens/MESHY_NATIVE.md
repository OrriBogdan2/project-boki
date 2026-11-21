# Hunters on Meshy's own skeleton (meshy_native)

A Hunter can be drawn on the skeleton Meshy's auto-rig made, playing Meshy's own clips, instead of the 14-bone
contract (RIG_CONTRACT.md). The game adapts to Meshy: its bones are never renamed, retargeted, merged or dropped.

## Switch
`content/rules/warden_native.json`, keyed by art name: `"meshy_native": true` and the file
`art/wardens/<art>/<art>_meshy.glb` present. Off (or no file): the contract model as before. On now: Sparkle (ryzz),
Sable (sable), Tenzo (tarek), Kael (kael: K1, cape cut to the waist) and Grimble (dredge: the G3 look,
no backpack, its drips and strands made one firm connected goo arm by a Meshy edit: kael-grimble-ingame-1121 r2_e1b_f2b). The contract `<art>.glb` stays beside it untouched.

## What changes on the native path (scripts/heroes/warden_native.gd)
- `WardenGlb.path/will_dress/dress` hand the Hunter to `WardenNative.dress`: no WardenSync, so the contract's
  procedural bone layers (springs, orbits, carry IK, look-at, drop pose, squash, flinch, wall, blink, moods) are off.
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
- Held weapon (data `weapon`, `scripts/heroes/warden_held.gd`): Kael's and Grimble's Meshy models were made with no
  weapon. The live weapon is cut out of the contract `<art>.glb` (its surfaces by material, all riding one contract
  hand bone: Kael's sword on `hand.R`, Grimble's blunderbuss in his iron fist on `hand.L`), unskinned and held rigidly
  in Meshy's `hand` bone: in Meshy's idle it sits as the contract model holds it at rest, then it follows the hand
  through every clip. It is placed when the skeleton takes its pose (`skeleton_updated`, a fixed socket: never a frame
  behind the clip). `"mirror": true` cuts it mirrored into the other hand (Kael: the contract holds the sword in the
  right hand, the splash in the dark-veined left one). `"tilt"` (state -> degrees about the grip, on the body's side
  axis, eased between states) keeps a long weapon off the floor in every clip: Kael idles with the splash's
  forward-down blade and raises it ahead of him for walk, run, jump, attack and crouch; the check pins a 2 cm gap.
  `"hold"` seats it by its own grip anchor in the palm (halfway from the hand bone to the `palm` bone), its
  grip-to-muzzle line on `aim` in the idle: Grimble's blunderbuss sits in his iron fist, barrel ahead (the contract's
  wrist pivot left it hanging behind the fist). It takes the toon pass with the contract look's slots (metal, glow, leather).
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

## Not on the native path (yet)
Death, stun, ledge, glide, emote and per-move clips (Meshy gave six); the contract's per-hunter extras (Tenzo's
ground rings, Sparkle's blink, Sable's braid springs); 300k-tri meshes vs the 80k contract budget.
