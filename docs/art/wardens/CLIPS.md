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

## The tree
loco (BlendSpace2D) > stance > crouch > air > `upper` (filtered Blend2, one seek channel) > `full` (Blend2 onto two crossfaded seek
channels), built in code from the file. A node's output feeds one input only. `--clip-check` asserts budget, clips,
timings, weapon on the bone, FX on the blade and hand-overs. `--clip-shots` shoots them in the game's renderer.

## The rescue carry (WardenCarry)
While you carry your downed Boki (pose id `rs_carry`, KinDowned) the legs stay on the walk and run clips at the carry's 90% speed and `scripts/heroes/warden_carry.gd` lays one upper-body layer over them: two-bone IK brings both wrists in round a chest socket, the torso leans back a little, and the bones the Hero's data lists as `"carry_stow"` shrink away (Albert's weapon and shield, Hem's bow, Dredge's gun, Vex's gatling and launcher, Ostra's card fan). A weapon modelled straight into the hand mesh (Kael's sword, Claire's spear, Sable's two flintlocks: the hands listed as `"carry_drop"`) leaves the shown mesh instead: once a session per mesh, `WardenCarry.held` copies the body mesh without each piece that rides one of those hands alone and reaches more than 0.1 m from it, and the carry shows that copy while it is in. The Boki rides at the socket (`carry_socket` model meta, read by `KinDowned.scoop_pose`); a broad body sets its cradle further out (`"carry_fwd"`, arm lengths: Albert's barrel, Ostra's ruff), and `--clip-check` asserts the socket clears the body's front by 0.1 m. It runs on the contract bones, so no clip is authored. Cinder, Ryzz, Tarek and Pip hold no weapon (Tarek's fist shards keep orbiting). Strip: docs/art/anim_audit/carry_pose.jpg (Vex, Kael, Albert, Sable, Claire).

## The Heartspark carry (WardenCarry.hold_mote)
While you hold the Heartspark (`Heart.carrying`, state key `heart`) `WardenClips._heart` lays a second, lighter layer over the same contract bones: only the off arm (side `"heart_hand"`, default L; Lace's bow is in her left, so hers is R) lifts to the rescue carry's cradle height and holds the mote at the chest, and the Heart's spark rides that hand (`heart_mote` model meta, drawn at half size; a Hero without the layer keeps the spark floating over the head). The legs, torso and main arm stay on the clips, so the run plays and LMB fires and casts as usual; while a clip plays (a shot, a cast, a hit, Lace's draw) or the rescue carry owns both arms, the layer fades out and it eases back in on plain locomotion. It drops when the Heart is dropped, handed on, or the carrier is knocked, out or extracted. Everything is in arm lengths of the Hero's own skeleton (and the same `"carry_fwd"` for broad bodies), so one layer fits all 12 heights. `--carry-pose-check` asserts it per Hero in a real match; `--clip-shots --carry --heart` renders the strip.
