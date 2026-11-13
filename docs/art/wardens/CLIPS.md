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
  Gait layer (WardenGait, docs/art/ANIM_QUALITY_AUDIT.md), after the tree has advanced: `stride` [walk, run] stretches the
  thighs about their running mean; `foot_mps` [walk, run] is the clips' foot speed at rate 1 (m/s, `--anim-audit` prints it),
  and move speed over it sets the clip rate (0.6 to 1.4); `arm_swing` {"L": gain, "R": gain} puts that arm on the opposite
  swing of its own side's leg. No key: the clip plays as keyed.
- `loco`: idle, stance (after `stance_after` s still), walk and run by direction (f, b, l, r; fl, fr, bl, br where the Hero has them), speeds, `in_step` (the ring's loops share a length and a strike key: the blend keeps them in time); `cadence` (optional) plays the run clip that many times its planted-foot rate, blended in over the walk-to-run band (Kael 1.5, Tarek 0.85; Cinder's scurry is keyed in her clip instead).
- `hide_while_chain`: bones that shrink away while a kit sets the root meta `chain_out` (a runtime piece of the weapon).
- `crouch` (item 143): idle, walk by direction, `in`, `out` (the 0.1 s dip and settle), `speed` (crouched walk, m/s). Under `air`; the game state's crouch says which way it is going. No key: the clips stand through a crouch. tools/art1/crouchkit.py shares the sneak and the dip; tools/art1/glb_add_clips.py puts the clips on a later build of the model with no Blender.
- `air`, `land`: rise, fall, glide; a landing clip after `min_fall` s airborne. Over the glide clip (and the dive, which
  plays it too) the whole body takes HunterAnim's air tilt (root meta `AIR_TILT`, WardenClips._air_tilt): the roll into
  a glider turn (25 deg at full steer) and the dive's nose-down pitch, about the rig's hips as the rig takes it, so the
  glider stays in the hands. A Boki riding on you sits on the torso you see (`WardenGlb.shown_torso`, the hips bone back
  through the retarget), not the hidden rig's. `--glide-bank-check` asserts it on every Hero; `--glide-bank-shots` films it.
- `kmoves`: kit move id -> {clip, `hold_from` (a held move loops from there), `lead` (s of the clip skipped at the start, so its hit pose lands on the kit's hit), `upper` (torso only: the legs keep running), `heading` (the root turns to his velocity, so the lean follows where he goes)}.
- `air`, `land`: rise, fall, glide; a landing clip after `min_fall` s airborne, owning the body for `dur` s standing and
  `moving` s (default `dur`) while he runs on, played at `rate` times its speed (default 1). `--clip-check` measures the
  plain jump through the clips (take-off, apex, dip, recovery: the JL rows); `--jump-land-shots` films it at the match camera.
- `air`, `land`: rise, fall, glide, dive (a plunge: the glider's Ctrl dive and the opening skydive; `dive_at` s holds a
  one-shot clip on one frame); a landing clip after `min_fall` s airborne. WardenAirTilt (on top of HunterAnim's AIR_TILT, which owns the bank and the dive's first DIVE_PITCH: the data adds the rest) turns the whole .glb about the
  hips on top: `dive_tilt` (deg forward in a plunge, default 105: head-down), `glide_tilt` (deg forward under the
  glider, default 12: the legs trail), `glide_bank` (deg into a glider turn, default 28). A clip that already leans
  sets less (Tarek's and Breaker's dive 50, Hem's 35, Ostra's 12 on top of the rig's own tip). Strips: `--glide-shots`.
- `air`, `land`: rise, fall, glide; one landing `clip` timed two ways by the fall speed (`HunterAnim.land_tier`: under
  4 m/s, a kerb, nothing plays; a plain jump's 6.8 m/s is the `hop`; 8.5 m/s up, a terrace drop, or any glide's end, is
  the `drop`). Each tier: `w`, how much of the land pose shows (the hop's small dip, default 1), `dur` s it owns the body
  standing, `moving` s while he runs on (default `dur`), `rate` times the clip's speed (default 1). The source is up and
  moving ~0.15 s after any touchdown, so `moving` stays near 0.1. `--clip-check` measures the jump, the drop, a glide's
  end and a kerb through the clips (take-off, apex, dip, legs back, recovery: the JL rows); `--jump-land-shots --way=`
  films them at the match camera (docs/art/anim_audit/LANDING_WEIGHT.md).
- `mantle` {`clip`, `rise`}: a ledge climb (Vex, Kael, Cinder, Meeko; tools/art1/mantlekit.py shares the poses, each Hero's clips file gives the personality). The first `rise` share of the clip is the climb and its time is how far up the face he is (the state's `mantle` 0..1, `hunter.gd _rise_k`), so the motion can't lag the body whatever the height; once over the lip the rest (the vault, the landing) plays in real time. A Hero without the key keeps `mantle` in `procedural` and the rig plays the reach and push. `ledge` (the grapple) stays procedural for everyone.
- `kmoves`: kit move id -> {clip, `hold_from` (a held move loops from there), `upper` (torso only: the legs keep running), `heading` (the root turns to his velocity, so the lean follows where he goes)}.
- `kmoves`: kit move id -> {clip, `hold_from` (a held move loops from there), `upper` (torso only: the legs keep running), `heading` (the root turns to his velocity, so the lean follows where he goes), `air_legs` (a play that has been in the air goes on the torso only: the fall legs under it, then the legs' own layer once he lands, to the move's end; audit and strips in [../air_cast/AIR_CAST_POSES.md](../air_cast/AIR_CAST_POSES.md))}.
- `kmoves`: kit move id -> {clip, `hold_from` (a held move loops from there), `upper` (torso only: the legs keep running), `heading` (the root turns to his velocity, so the lean follows where he goes), `ground_clip` / `air_clip` (the clip when the move starts on the ground / in the air: a dash looks different by where it was pressed; an air-started clip gives way to the glide or the landing)}.
  The clip is seeked to the kit's own `kmove_t`, so it can't drift from the hit. Clip length = the table's last key.
- `act` (DECISIONS 2026-11-09, the garden): home verb (HunterVerbs: `pat`, `feed`, `cheer`) -> clip (`pet` 1.3 s, `give` 1.0 s, `cheer` 0.8 s, as long as HunterVerbs.LENGTH). Seeked to the state's `act_t`; a verb with no entry stays on the procedural rig. Vex, Kael, Lace (hem), Cinder: tools/art1/gardenkit.py holds the shared timing, each hero's `*_clips.py` (Kael: `kael_garden.py`) the poses and attitude; `glb_add_clips.py` copies them onto the shipped glb.
- `kmoves`: kit move id -> {clip, `hold_from` (a held move loops from there), `upper` (torso only: the legs keep running; `"moving"`: only while he moves), `heading` (the root turns to his velocity, so the lean follows where he goes), `rate` (clip seconds per kit second, default 1: a dash clip keyed with a long recovery ends with the body's travel instead of riding the run; `--dash-frames-check`, docs/art/anim_audit/DASH_TRAVEL.md)}.
  The clip is seeked to the kit's own `kmove_t` (times `rate`), so it can't drift from the hit. Clip length = the table's last key.
- `recoil` {`deg`, `settle`}: every shot (the state's `fired` falling back to 0) kicks the arm bones and shoulder pieces up by `deg` degrees over whatever plays, settling in `settle` s (0.06-0.12); fast fire stacks to 1.5x. Only those bones move: the legs keep running, the shot's timing is the kit's. Vex 2 (the minigun, a shot every 0.12 s), Sable 3, Grimble 4. `--recoil-shots` films before/after strips.
- A kmove with `"upper": "moving"` (Vex's shots, Tarek's boulder, wind and punch, Grimble's shot and throw, Sparkle's casts) rides the torso and arms only while the Hero moves, so the legs keep the walk or run; without it the clip owns the legs and the feet stop mid-stride. `--layer-verify --wardens=gunslinger,dolm,dredge,mage` (`--shots-dir=<dir>` for the strips) measures every layer over walk and run in four directions.
- `loco`: idle, stance (after `stance_after` s still), walk and run by direction (f, b, l, r), speeds; `cadence` (optional) plays the run clip that many times its planted-foot rate, blended in over the walk-to-run band (Cinder's scurry 1.8, Kael's heavy run 1.5).
- `crouch` (item 143): idle, walk by direction, `in`, `out` (the 0.1 s dip and settle), `speed` (crouched walk, m/s). Under `air`; the game state's crouch says which way it is going. No key: the clips stand through a crouch. tools/art1/crouchkit.py shares the sneak and the dip; tools/art1/glb_add_clips.py puts the clips on a later build of the model with no Blender.
- `air`, `land`: rise, fall, glide; a landing clip after `min_fall` s airborne.
- `kmoves`: kit move id -> {clip, `hold_from` (a held move loops from there), `upper` (torso only: the legs keep running), `heading` (the root turns to his velocity, so the lean follows where he goes), `lead` (s: the clip starts that far in, so a late strike key lands on the kit's hit; under zero, its first frame is held that long)}.
  The clip is seeked to the kit's own `kmove_t` (plus the lead), so it can't drift from the hit. Clip length = the table's last key.
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
- `beats`: the result beats (`scripts/heroes/warden_beats.gd`), win / lose / board: `{clip}` (an existing clip: win is each Hunter's own emote, lose its downed clip) or `{pose: {bone: [pitch, yaw, roll]}}` degrees on hips, head and arms from the rig's rest (arm x- raises forward, right arm z+ and left arm z- go out; board is a pose in the Hunter's own manner). The state keys `beat` and `beat_t` play one: the results card (win/lose) and a skiff deck while boarding (`Exits.board_t`). `--clip-check` asserts all three are mapped. `--result-pose-shots` + `tools/result_pose_strip.py` shoot the strip of all twelve (docs/shots/result_poses.png).
  `stomp` (a downed foe, Life.R stomp_cycle 0.7 s, the slam at 0.7 of it = 0.49 s) and `drink` (Hunter.DRINK_TIME 1.1 s) are clips as long as the cycle / the drink, seeked by the game's phase; `drink` is upper-body only while he moves. `reviving` is a kneel loop. A Hunter with no such clip keeps the rig's own stomp, drink and kneel (leave them in `procedural`).
- `procedural`: state keys that hand back to the rig (ledges, stomps...). A kit move with no clip does too.
- `procedural`: state keys that hand back to the rig (ledges, stomps...). A kit move with no clip does too. Every Hero lists `wade` and `swim` (water, `HunterSwim`): no clip is keyed for them, so HunterAnim's wading high knees and
  swimming crawl (a flutter kick, a stroke in each hand the kit lets go of, the weapon held as on a run) play on the rig;
  `--clip-check` walks every Hero through a pond (`tools/pond_walk.gd`), `--pond-shots` films it.
- `states`: downed, reviving (a kneel loop), stomp, drink, dead, stun, emote, hit {front, back, dur}. `stomp` and `drink` are seeked by the state's 0..1 phase (a stomp clip is Life's `stomp_cycle`, 0.7 s, the heel down at 0.7 of it; a drink clip is `Hunter.DRINK_TIME`, 1.1 s, upper body only). tools/art1/actionkit.py shares the three actions; each Hero's clips file gives its ready pose, its free hand and the mouth. Kael v2 has no clips file of his own (his clips are the first Kael's, retargeted): tools/art1/kael_v2_clips.py keys his three on the v2 rig, his ready pose read off his v2 idle, and copies them onto kael.glb. `--clip-check` asserts the lengths.
- `procedural`: state keys that hand back to the rig (ledges, mantles, bases; stomp and drink for a Hero with no clip). A kit move with no clip does too.
- `states.stomp`, `states.drink` (shared actions, item: parity): the clip name; the clip is the game's phase 0..1 (Hunter state `stomp` = time in `Life.R.stomp_cycle`, `drink` = over `Hunter.DRINK_TIME`) laid over its length, so the stomp clip is 0.7 s with the slam at 0.49 s (the kit's hit at 0.7 of the cycle) and the drink clip is 1.1 s, an upper-body one (the legs keep walking). `states.reviving`'s clip is a loop. Motley, Albert, Sparkle and Sable have all three (`tools/art1/*_clips.py` `stomp`, `revive`, `drink`); a Hunter with no clip keeps the procedural pose.
- `procedural`: state keys that hand back to the rig (ledges, mantles; `stomp` and `drink` for a Hunter with no clip). A kit move with no clip does too. `--action-shots --warden=<id> --state=stomp|revive|drink --shots-dir=<dir>` renders the three (`--variant=proc` the rig's pose).
- No wall clip: a wall kick or bounce keeps the air's rise or fall, and `WardenWall` (`scripts/heroes/warden_wall.gd`) plants
  the nearer foot on the wall over it, for every Hero (docs/art/WALL_POSE_AUDIT.md).
- `cancels`: [from move, cut at s, to] rows, one per second press the hero's docs/heroes Cancels table lists (to: a move,
  `""` the legs, `stun`, `glide`). `--clip-check` hands each over as the game does and asserts no pop and a blend done
  within one footage frame (0.2 s); `--clip-shots --cancels` shoots the frames around each cut.

## The tree
loco (BlendSpace2D) > stance > crouch > air > `upper` (filtered Blend2) > `full` (Blend2), each of the last two onto two
crossfaded seek channels. A cancel hands over clean: a layer that starts from off snaps its crossfade onto the new clip
(no stale pose bleeds in), an upper move that cuts a full one starts at the full one's weight and a full one covers the
upper one until it owns the body (the run's arm swing never shows between them), and the glide pose holds under a move
cast from the glider. Built in code from the file. A node's output feeds one input only. `--clip-check` asserts budget, clips,
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
## The aim lead
`WardenAimLead` (scripts/heroes/warden_aim_lead.gd) runs in `WardenGlb.Sync` after the clips. The model already faces
the cursor, so the layer turns the parts back: the leg line (bone `root`) lags the cursor, the chest (`hips`) leads it
by up to 30 degrees and the head (`head`) by up to 60, each a damped follower (rates are consts in the file). It is
off under a full-body clip (`act_w`), a procedural pose (mantle, ledge: `proc_w`), dead and downed; a move keyed
`"upper"` (even standing: Vex's LMB) keeps it on. `--aim-lead-check` measures the splits and checks clamp, jitter at
30 fps and the off cases; `--shots-dir=<dir>` draws the sweep strips (GPU).
## The rescue carry (WardenCarry)
While you carry your downed Boki (pose id `rs_carry`, KinDowned) the legs stay on the walk and run clips at the carry's 90% speed and `scripts/heroes/warden_carry.gd` lays one upper-body layer over them: two-bone IK brings both wrists in round a chest socket, the torso leans back a little, and the bones the Hero's data lists as `"carry_stow"` shrink away (Albert's weapon and shield, Hem's bow, Dredge's gun, Vex's gatling and launcher, Ostra's card fan). A weapon modelled straight into the hand mesh (Kael's sword, Claire's spear, Sable's two flintlocks: the hands listed as `"carry_drop"`) leaves the shown mesh instead: once a session per mesh, `WardenCarry.held` copies the body mesh without each piece that rides one of those hands alone and reaches more than 0.1 m from it, and the carry shows that copy while it is in. The Boki rides at the socket (`carry_socket` model meta, read by `KinDowned.scoop_pose`); a broad body sets its cradle further out (`"carry_fwd"`, arm lengths: Albert's barrel, Ostra's ruff), and `--clip-check` asserts the socket clears the body's front by 0.1 m. It runs on the contract bones, so no clip is authored. Cinder, Ryzz, Tarek and Pip hold no weapon (Tarek's fist shards keep orbiting). Strip: docs/art/anim_audit/carry_pose.jpg (Vex, Kael, Albert, Sable, Claire).

## The Heartspark carry (WardenCarry.hold_mote)
While you hold the Heartspark (`Heart.carrying`, state key `heart`) `WardenClips._heart` lays a second, lighter layer over the same contract bones: only the off arm (side `"heart_hand"`, default L; Lace's bow is in her left, so hers is R) lifts to the rescue carry's cradle height and holds the mote at the chest, and the Heart's spark rides that hand (`heart_mote` model meta, drawn at half size; a Hero without the layer keeps the spark floating over the head). The legs, torso and main arm stay on the clips, so the run plays and LMB fires and casts as usual; while a clip plays (a shot, a cast, a hit, Lace's draw) or the rescue carry owns both arms, the layer fades out and it eases back in on plain locomotion. It drops when the Heart is dropped, handed on, or the carrier is knocked, out or extracted. Everything is in arm lengths of the Hero's own skeleton (and the same `"carry_fwd"` for broad bodies), so one layer fits all 12 heights. `--carry-pose-check` asserts it per Hero in a real match; `--clip-shots --warden=<id> --clips=idle --carry --heart` renders the strip; docs/art/anim_audit/heartspark_carry.jpg (Lace, Kael, Albert, Meeko; the blue ball is the held mote).
## Strike reach (`--strike-reach-check`, also run by `--clip-check`)
A keyed strike carries `"strike": [point, reach, rule]` on its `kmoves` entry: the point that lands (`tip` = the skinned
weapon's `weapon_muzzle`, a bone, `fist` = the lower hand, `front` = the body's leading point), the kit's reach as a path
into the archetype data (`lmb/reach`; `ram` = hit_r + the Soot Ram's touch) and the rule: `edge` (a cut, ring or strip: the
point's furthest reach lands within 15% of the area's edge), `ground` (a slam: where it lands lowest it is inside the area
ahead), `start` (a punch that starts a lane), `throw` (the hand leads at the release). The kits' reaches are the source's
in metres (PARITY FIRST); the fix for a short strike is the clip or the weapon, never the reach. Strikes known short at
the owner's heights sit in the check's `OPEN` table with the reason and a docs/DEBT.md line: Kael's cuts and cleave (his
arm folds and the sword is the splash's 0.61 of his height: straight out he reaches 2.6 m of the 3.1 m cut) and Albert's
whirl (3.2 m straight out, 3.5 m ring). Albert's smash was fixed in the clip with no Blender
(`tools/art1/glb_bone_turn.py`: a bone turned about a model-frame axis over a window of the clip): his arm pitched up 36
degrees at the impact, so the hammer head lands 2.45 m out on the ground instead of 1.7 m out and 0.6 m under it
(`--strike-reach-check --reach-trace` prints the head's path frame by frame; before/after strips still to render on a GPU).
