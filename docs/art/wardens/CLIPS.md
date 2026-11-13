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
- `hide_while_chain`: bones that shrink away while a kit sets the root meta `chain_out` (a runtime piece of the weapon).
- `loco`: idle, stance (after `stance_after` s still), walk and run by direction (f, b, l, r), speeds.
  Gait layer (WardenGait, docs/art/ANIM_QUALITY_AUDIT.md), after the tree has advanced: `stride` [walk, run] stretches the
  thighs about their running mean; `foot_mps` [walk, run] is the clips' foot speed at rate 1 (m/s, `--anim-audit` prints it),
  and move speed over it sets the clip rate (0.6 to 1.4); `arm_swing` {"L": gain, "R": gain} puts that arm on the opposite
  swing of its own side's leg. No key: the clip plays as keyed.
- `crouch` (item 143): idle, walk by direction, `in`, `out` (the 0.1 s dip and settle), `speed` (crouched walk, m/s). Under `air`; the game state's crouch says which way it is going. No key: the clips stand through a crouch. tools/art1/crouchkit.py shares the sneak and the dip; tools/art1/glb_add_clips.py puts the clips on a later build of the model with no Blender.
- `air`, `land`: rise, fall, glide; a landing clip after `min_fall` s airborne. Over the glide clip (and the dive, which
  plays it too) the whole body takes HunterAnim's air tilt (root meta `AIR_TILT`, WardenClips._air_tilt): the roll into
  a glider turn (25 deg at full steer) and the dive's nose-down pitch, about the rig's hips as the rig takes it, so the
  glider stays in the hands. A Boki riding on you sits on the torso you see (`WardenGlb.shown_torso`, the hips bone back
  through the retarget), not the hidden rig's. `--glide-bank-check` asserts it on every Hero; `--glide-shots` films it.
- `kmoves`: kit move id -> {clip, `hold_from` (a held move loops from there), `lead` (s of the clip skipped at the start, so its hit pose lands on the kit's hit), `upper` (torso only: the legs keep running), `heading` (the root turns to his velocity, so the lean follows where he goes)}.
  The clip is seeked to the kit's own `kmove_t`, so it can't drift from the hit. Clip length = the table's last key.
- `act` (DECISIONS 2026-11-09, the garden): home verb (HunterVerbs: `pat`, `feed`, `cheer`) -> clip (`pet` 1.3 s, `give` 1.0 s, `cheer` 0.8 s, as long as HunterVerbs.LENGTH). Seeked to the state's `act_t`; a verb with no entry stays on the procedural rig. Vex, Kael, Lace (hem), Cinder: tools/art1/gardenkit.py holds the shared timing, each hero's `*_clips.py` (Kael: `kael_garden.py`) the poses and attitude; `glb_add_clips.py` copies them onto the shipped glb.
  `moving` s (default `dur`) while he runs on, played at `rate` times its speed (default 1). `--clip-check` measures the
  plain jump through the clips (take-off, apex, dip, recovery: the JL rows); `--jump-land-shots` films it at the match camera.
  one-shot clip on one frame); a landing clip after `min_fall` s airborne. WardenAirTilt turns the whole .glb about the
  hips on top: `dive_tilt` (deg forward in a plunge, default 105: head-down), `glide_tilt` (deg forward under the
  glider, default 12: the legs trail), `glide_bank` (deg into a glider turn, default 28). A clip that already leans
  sets less (Tarek's and Breaker's dive 50, Hem's 35, Ostra's 12 on top of the rig's own tip). Strips: `--glide-shots`.
  The clip is seeked to the kit's own `kmove_t` (plus the lead), so it can't drift from the hit. Clip length = the table's last key.
  Firing on the run: a move the kit lets him run through (a shot, a throw, a slash, a cast he can walk in) is `upper`
  (`"moving"` when it also has a standing pose), or the legs freeze and the feet skid. `--fire-run-check` runs every
  Hunter at full stick, presses LMB, RMB and E, and gates the planted feet against his plain run (+25 % of the speed).
  `--clip-shots --run-fire=<kmove>` shoots it.
- `states`: downed, reviving, dead, stun, emote, hit {front, back, dur}.
- `emotes`: the clip each wheel emote (`Truce.EMOTES`) plays, {emote id: clip}, all eight, all different, each shorter than the 2.6 s bubble. A clip is one of the `.glb` or a gesture `g_<name>` keyed at load from `warden_anim/emote_gestures.json` (`WardenGestures`: degrees from the rig's rest, axes in that file's doc). Moving, it plays on the upper layer (the legs keep running); standing, a `.glb` clip owns the body and a gesture still only moves the upper body. An id off the wheel (the bots' replies) plays `states.emote`. Remote players get it from the existing `emo` event. `--clip-check` asserts the map; `--emote-shots` renders it.
- `procedural`: state keys that hand back to the rig (ledges, stomps...). A kit move with no clip does too.

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
