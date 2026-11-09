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
  Gait layer (WardenGait, docs/art/ANIM_QUALITY_AUDIT.md), after the tree has advanced: `stride` [walk, run] stretches the
  thighs about their running mean; `foot_mps` [walk, run] is the clips' foot speed at rate 1 (m/s, `--anim-audit` prints it),
  and move speed over it sets the clip rate (0.6 to 1.4); `arm_swing` {"L": gain, "R": gain} puts that arm on the opposite
  swing of its own side's leg. No key: the clip plays as keyed.
- `crouch` (item 143): idle, walk by direction, `in`, `out` (the 0.1 s dip and settle), `speed` (crouched walk, m/s). Under `air`; the game state's crouch says which way it is going. No key: the clips stand through a crouch. tools/art1/crouchkit.py shares the sneak and the dip; tools/art1/glb_add_clips.py puts the clips on a later build of the model with no Blender.
- `air`, `land`: rise, fall, glide; a landing clip after `min_fall` s airborne.
- `kmoves`: kit move id -> {clip, `hold_from` (a held move loops from there), `upper` (torso only: the legs keep running), `heading` (the root turns to his velocity, so the lean follows where he goes), `lead` (s: the clip starts that far in, so a late strike key lands on the kit's hit; under zero, its first frame is held that long)}.
  The clip is seeked to the kit's own `kmove_t` (plus the lead), so it can't drift from the hit. Clip length = the table's last key.
- `states`: downed, reviving, dead, stun, emote, hit {front, back, dur}.
- `procedural`: state keys that hand back to the rig (ledges, stomps...). A kit move with no clip does too.

## The tree
loco (BlendSpace2D) > stance > crouch > air > `upper` (filtered Blend2, one seek channel) > `full` (Blend2 onto two crossfaded seek
channels), built in code from the file. A node's output feeds one input only. `--clip-check` asserts budget, clips,
timings, weapon on the bone, FX on the blade and hand-overs. `--clip-shots` shoots them in the game's renderer.
