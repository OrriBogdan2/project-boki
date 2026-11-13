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
- `crouch` (item 143): idle, walk by direction, `in`, `out` (the 0.1 s dip and settle), `speed` (the sneak clip's own ground speed, m/s: the clip runs at the game's crouch speed over it, up to `WardenClips.CROUCH_RATE_MAX`, so the planted foot stays put; `--crouch-check` measures it). Under `air`; the game state's crouch says which way it is going. No key: the clips stand through a crouch. tools/art1/crouchkit.py shares the sneak and the dip; tools/art1/glb_add_clips.py puts the clips on a later build of the model with no Blender.
- `air`, `land`: rise, fall, glide; a landing clip after `min_fall` s airborne. Over the glide clip (and the dive, which
  plays it too) the whole body takes HunterAnim's air tilt (root meta `AIR_TILT`, WardenClips._air_tilt): the roll into
  a glider turn (25 deg at full steer) and the dive's nose-down pitch, about the rig's hips as the rig takes it, so the
  glider stays in the hands. A Boki riding on you sits on the torso you see (`WardenGlb.shown_torso`, the hips bone back
  through the retarget), not the hidden rig's. `--glide-bank-check` asserts it on every Hero; `--glide-shots` films it.
- `kmoves`: kit move id -> {clip, `hold_from` (a held move loops from there), `lead` (s of the clip skipped at the start, so its hit pose lands on the kit's hit), `upper` (torso only: the legs keep running), `heading` (the root turns to his velocity, so the lean follows where he goes)}.
  The clip is seeked to the kit's own `kmove_t`, so it can't drift from the hit. Clip length = the table's last key.
- `states`: downed, reviving, dead, stun, emote, hit {front, back, dur}. The `hit` clip plays only on a stagger (`hit_k` at
  `Oomph.HEAVY_FLINCH`); any other hit is `WardenFlinch`: a torso spring (front, back, left, right from `hit_dir`) added after
  the clips, so it rides over a run or a cast without stopping it. `--flinch-layer-check` holds each Hero's LMB move and hits it.
- `act` (DECISIONS 2026-11-09, the garden): home verb (HunterVerbs: `pat`, `feed`, `cheer`) -> clip (`pet` 1.3 s, `give` 1.0 s, `cheer` 0.8 s, as long as HunterVerbs.LENGTH). Seeked to the state's `act_t`; a verb with no entry stays on the procedural rig. Vex, Kael, Lace (hem), Cinder: tools/art1/gardenkit.py holds the shared timing, each hero's `*_clips.py` (Kael: `kael_garden.py`) the poses and attitude; `glb_add_clips.py` copies them onto the shipped glb.
- `states`: downed, reviving, dead, stun, emote, hit {front, back, dur}.
- `emotes`: the clip each wheel emote (`Truce.EMOTES`) plays, {emote id: clip}, all eight, all different, each shorter than the 2.6 s bubble. A clip is one of the `.glb` or a gesture `g_<name>` keyed at load from `warden_anim/emote_gestures.json` (`WardenGestures`: degrees from the rig's rest, axes in that file's doc). Moving, it plays on the upper layer (the legs keep running); standing, a `.glb` clip owns the body and a gesture still only moves the upper body. An id off the wheel (the bots' replies) plays `states.emote`. Remote players get it from the existing `emo` event. `--clip-check` asserts the map; `--emote-shots` renders it.
- `lockin`: the pre-match lobby pose when you pick the Hunter ({clip, from (s, 0), dur (s, 1-1.5), rate, fade (s in,
  0.2), settle (s back to the idle, 0.35)}): a window of an existing clip at about its own speed, then the idle. Each
  Hunter's beat: Vex flips the coin and catches it, Kael hoists the sword onto his shoulder (his `stance`), Lace draws
  the string taut (`draw`), Motley slams his lid and bursts out bowing, Sable spins her pistols into a stage bow, Neve
  spins on the spot, Meeko grins at her lantern and hops, Sparkle cocks finger guns, Tenzo tosses and catches a pebble,
  Cinder cackles over a flame, Albert laughs and pats his hull, Grimble rears up at his monocle. The art lane owes real
  clips for the weakest: Kael's hoist (today a crossfade into `stance`), and Vex's coin and Tenzo's pebble, both too
  small to read at the lobby's stage size.
- `procedural`: state keys that hand back to the rig (ledges, stomps...). A kit move with no clip does too.
- `blink`: the lids' closed pose off their rest, `turn` {bone: axis x angle, rad} or `move` {bone: m}, in the bone's own frame. WardenBlink closes them over the clip every 2-6 s in close-ups only ([BLINK.md](BLINK.md)).
- No wall clip: a wall kick or bounce keeps the air's rise or fall, and `WardenWall` (`scripts/heroes/warden_wall.gd`) plants
  the nearer foot on the wall over it, for every Hero (docs/art/WALL_POSE_AUDIT.md).

## The tree
loco (BlendSpace2D) > stance > crouch > air > `upper` (filtered Blend2, one seek channel) > `full` (Blend2 onto two crossfaded seek
channels), built in code from the file. A node's output feeds one input only. `--clip-check` asserts budget, clips,
timings, weapon on the bone, FX on the blade and hand-overs. `--clip-shots` shoots them in the game's renderer.

## Parity strip: our move beside the footage (`--parity-strip`, tools/parity_strip.gd)
1. Get the footage folder: `git fetch origin ext/hero-ref-footage && git checkout origin/ext/hero-ref-footage -- footage/<folder>` (folders in its README; Vex is `venator_ghost`). Don't commit it.
2. Pick the frame range of the move in `briefs/hero-ref/<sheet>.md` (frame N = video second base + (N-1)/5, 5 fps). Start on the press.
3. Run: `jobq submit --needs gpu --tree <tree> --out shots -- --parity-strip --hero=gunslinger --slot=lmb --frames=7-18 --shots-dir=shots`.
4. `--hero` is our archetype id; `--slot` is lmb, rmb, e, x (ultimate) or dash; `--frames=a-b` sets the length (5 fps, so 12 frames = 2.4 s).
5. It plays the move in the Training Area (the Arena) with the dummy 6 m out, one frame per 0.2 s from the press.
6. `--hold=<s>` sets how long the key stays down (an LMB is held through the move; the rest are a tap). `--footage-dir=<dir>` is where `footage/` lives.
7. The sheet is `shots/<hero>_<slot>.jpg`: ours on the top row, footage frames a..b below, six per row, labelled `+seconds`.
8. Both are close crops on the hero: the footage's centre half, and ours a few metres round him toward the dummy.
9. Compare by eye: wind-up, contact frame, recovery. Note the frame where ours is early or late and fix the clip's key times.
10. Demos: `docs/art/parity_strip/` (`vex_lmb.jpg` frames 7-18 of venator_ghost, `kael_rmb.jpg` the RMB tap, frames 152-161). Owner notes in briefs/DECISIONS.md win over the footage.

## The rescue carry (WardenCarry)
While you carry your downed Boki (pose id `rs_carry`, KinDowned) the legs stay on the walk and run clips at the carry's 90% speed and `scripts/heroes/warden_carry.gd` lays one upper-body layer over them: two-bone IK brings both wrists in round a chest socket, the torso leans back a little, and the bones the Hero's data lists as `"carry_stow"` shrink away (Albert's weapon and shield, Hem's bow, Dredge's gun, Vex's gatling and launcher, Ostra's card fan). A weapon modelled straight into the hand mesh leaves the shown mesh instead: once a session per mesh, `WardenCarry.held` copies the body mesh without it, the carry shows that copy while it is in and the whole mesh again when it lets go. Kael's sword and Claire's spear ride `hand.R` rigidly as their own pieces (the hands listed as `"carry_drop"`: each piece that rides one of them alone and reaches more than 0.1 m from it goes). Sable's two flintlocks are fused into her v95 body by blended weights (mostly the forearms), so they go by surface (`"carry_drop_surfaces": ["metal-atlas"]`, her import note's pistol slot). `--clip-check` asserts per Hero, off the meshes and not the data, that while carrying no shown piece on a hand alone reaches more than 0.25 m from it (a hand, not a weapon), and that each listed surface is emptied. The Boki rides at the socket (`carry_socket` model meta, read by `KinDowned.scoop_pose`); a broad body sets its cradle further out (`"carry_fwd"`, arm lengths: Albert's barrel, Ostra's ruff), and `--clip-check` asserts the socket clears the body's front by 0.1 m. It runs on the contract bones, so no clip is authored. Cinder, Ryzz, Tarek and Pip hold no weapon (Tarek's fist shards keep orbiting). A scan of every .glb skin for pieces led by a hand or forearm (2026-11-11) finds no other weapon: Dredge's big left hand is his gauntlet (his IMPORT.md), Sable's two leather pieces under the hands are bone-heat blends (60% hand, 40% leg; her slot rule puts the pistols in metal), and Gil has no clips yet, so the carry layer does not run on him (his Swordfish rides hand.R as its own mesh). Strip: docs/art/anim_audit/carry_pose.jpg (Vex, Kael, Albert, Sable, Claire; the other seven are asserted by --clip-check, not yet shot).
