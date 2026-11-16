# The head looks at the aim (WardenLookAt)

The source's Hunters turn the head toward the aim before the body has caught up; ours turned as a block. One layer
(`scripts/heroes/warden_look_at.gd`) lays a turn over the rig contract's `head` bone (its pivot is the neck, the
contract has no separate neck bone) after the clips or the rig posed it and before the braids swing off the head. It is
the same for every Hero: no per-hero script, no per-hero data, and the keyed poses stay underneath.

## How it runs
- `Hunter._anim_state` writes the anim state key `look` (`WardenLookAt.aim_of`): a Vector3, x and z the unit aim
  (`Hunter.aim_dir`), y its slope up from chest height; `Vector3.ZERO` for a remote Hunter (the aim is not on the
  wire) and through a knock.
- `WardenGlb.Sync._process` steps the layer each frame. The yaw it wants is what is left between the body's facing
  and the aim, clamped; the turn eases to it (`RATE`) and is capped at it, so as the body arrives (it turns at
  `HunterMove.turn_rate`, sourced 1280 degrees a second) the head gives the turn back and never looks past the aim.
- Off, eased out over `OFF_S` and back in over `ON_S`: a dash (`rolling`), a stun, an emote, a glide or dive, a
  ledge, a mantle, a stomp, the base channel, a revive, a locked facing (`statue`), a knock-out, and a kit move the
  procedural rig plays. A full-body clip (a cast, a flinch, a landing) owns the head as much as it owns the body
  (`WardenClips.act_w`); an upper-body clip leaves the head to the layer.

## The numbers
| const | value | from |
|---|---|---|
| `YAW_MAX` | 70 degrees | estimate: the source data (`briefs/supervive-data`) and `briefs/hero-ref` give no figure |
| `PITCH_MAX` | 25 degrees | estimate, as above |
| `RATE` | 40 1/s | estimate: about half the way to the aim each 60 Hz frame |
| `OFF_S` / `ON_S` | 0.06 s / 0.15 s | ours: off inside the first third of a dash (0.19 s) |

With the body at the sourced turn rate a 60 degree swing is over in three frames, so the head's lead is short (it peaks
near 19 degrees on the first frame); a 170 degree turn-around takes eight frames and the head is 65 degrees ahead by
the fourth.

## Proof
- `--look-at-check`: every Hunter of the roster (13), the head bone read before the layer and after the whole frame
  (its turn is measured on the skeleton, not taken from the layer): 60 and 170 degree swings, a held aim, the clamps,
  and every off state.
- `--look-at-shots --shots-dir=<dir>` (GPU): strips of four Hunters, before on top and after below.
