# A Hero's hand-keyed clips (ART-1)

A Hero with `content/rules/warden_anim/<art>.json` and animations in its .glb plays those clips instead of the retargeted
HunterAnim pose (`scripts/heroes/warden_clips.gd`). HunterAnim still runs: it is the source of truth for the state, and
every state the file does not list falls back to the rig with a short blend. The recipe and style notes for building a
Hero live in `tools/art1/` (Kael is the pilot).

## The file
- `skinned_weapon`: the weapon is skinned in the .glb (item 76b); the procedural pieces hide and the Gun node is only the
  invisible aim and FX reference. `blade` {`root`, `tip`, `bone`, `root_bone`} names the empties on it and the bones they ride (`root_bone`: the root's, when it isn't the tip's): Sync keeps the Gun and its
  Muzzle on them every frame, and writes the hands back on the rig, so kit FX leave the weapon you see.
- `bone_scale`: {bone: size}, a skinned weapon's size against its sheet (item 137; warden_look `weapon_scale` only reaches
  an unskinned `weapon` node). The bone and what it carries scale about its head, held over the clips. Vex: barrels 0.8,
  launcher 0.9, cannon 0.55 of her height as on the sheet.
- `extra_bones`: the Hero's variant bones (RIG_CONTRACT), bone -> parent. Data, not `WardenGlb.EXTRA`, so branches
  don't collide.
- `loco`: idle, stance (after `stance_after` s still), walk and run by direction (f, b, l, r), speeds.
- `crouch` (item 143): idle, walk by direction, `in`, `out` (the 0.1 s dip and settle), `speed` (crouched walk, m/s). Under `air`; the game state's crouch says which way it is going. No key: the clips stand through a crouch. tools/art1/crouchkit.py shares the sneak and the dip; tools/art1/glb_add_clips.py puts the clips on a later build of the model with no Blender.
- `air`, `land`: rise, fall, glide; a landing clip after `min_fall` s airborne.
- `kmoves`: kit move id -> {clip, `hold_from` (a held move loops from there), `upper` (torso only: the legs keep running), `heading` (the root turns to his velocity, so the lean follows where he goes)}.
  The clip is seeked to the kit's own `kmove_t`, so it can't drift from the hit. Clip length = the table's last key.
- `states`: downed, reviving, dead, stun, emote, hit {front, back, dur}.
- `procedural`: state keys that hand back to the rig (ledges, stomps...). A kit move with no clip does too.
- `open_knees` (0..1, default 0.5): the Hero's attitude in the open pose below: how much of the dip goes on the knees
  rather than the back.

## The tree
loco (BlendSpace2D) > stance > crouch > air > `upper` (filtered Blend2, one seek channel) > `full` (Blend2 onto two crossfaded seek
channels), built in code from the file. A node's output feeds one input only. `--clip-check` asserts budget, clips,
timings, weapon on the bone, FX on the blade and hand-overs. `--clip-shots` shoots them in the game's renderer.

## Opening a box
No clip: one shared layer on the contract bones (`scripts/heroes/warden_open.gd`, WardenOpen), laid over the clips by
Sync while the Hero holds a chest or a deathbox open (`Hunter.holding()` "chest" or "loot"; the player's open loot
window holds "loot"). The state's `act_at` is the lid's top (`WardenOpen.lid_near`, the nearest closed chest or full box).
It turns the root to the box, steps in (at most 0.45 m), sinks with the soles kept (leg IK), leans the hips and lays both
wrists on the lid (arm IK, elbows out), reaching in over 0.25 s, stirring a little while held, and going straight back
in 0.1 s when the hold ends. Step, drop and lean are searched once per reach against the Hero's own shoulders and arm
length, so a tall Hero folds deeper and every Hero's hands reach the same lid. A move, dash, cast, hit, stun or a jump
takes it off the frame it comes; a hold that goes on reaches in again. The channel's timing is the game's own
(ChestLoot `hold_s`, Life `loot_time`): the layer only shows it. `--loot-open-check` asserts all 12 Heroes.
