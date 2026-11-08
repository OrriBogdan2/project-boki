# Movement feel: targets, sources, measurements

The owner's note (Oct 31 2026): dropping, gliding and moving felt sloppy. SUPERVIVE is the bar: snappy and responsive, especially the glide, and Shift into a glide should give you more momentum.

Every target below is checked by `--move-feel-check` (`tools/move_feel_check.gd`). The check drives the real match step with scripted inputs. It counts fixed 60 Hz simulation steps, never wall-clock time, so a loaded machine can't skew it. It never touches the save.

```
XDG_DATA_HOME=<scratch> godot --headless --path . -- --move-feel-check
```

It prints one `MFEEL <key> = <value> target <op> <target> ok|FAIL (source)` line per measurement and ends with `MOVE FEEL CHECK DONE, failures: N`.

Source tags follow SUPERVIVE_FEEL.md / SUPERVIVE_DATA.md:

- `[wiki]` is supervive.wiki.gg.
- `[guide]` is a published guide (Deltia's Gaming gliding guide, ludo.guide).
- `[footage]` is a frame measurement from SUPERVIVE_FEEL.md.
- `[spec]` is docs/EXPEDITION_SPEC.md.
- `[est]` is our own estimate, tuned for feel and labelled as such.

Nothing here comes from SUPERVIVE's files.

## What the public sources say (and don't)

- **Glider momentum [wiki]:** "Gliding right after a lateral Impulse in the same direction keeps some momentum and increases glide speed." This works with dashes, relics, consumables and terrain. The wiki also says gliding "preserves momentum".
- **Air dashes [guide]:** mid-air dashes, jump pads and relics combine with gliding to go faster. Some hunters "dash mid-air before gliding for a fast speed gain".
- **Opening the glider [guide]:** you hold jump while already jumping or falling, and letting go closes it. No engage delay is published anywhere.
- **Abyss lift [wiki]:** a rapid upward impulse to ground level, then a rapid deceleration on arrival. Letting go before the top keeps the upward momentum.
- **Fall depth and glide speed [footage]** (SUPERVIVE_FEEL.md): 1s off an edge is ~8m deep. Glide speed is ~5 m/s, about run speed. The hunter stays roughly centred on screen.
- **Ledges [footage] and the owner's description:** in the air, touching the side of ground above you while moving into it floats you up. Falling players who touch an island wall spring back onto it, even from a full second deep, in about 0.8s. The owner adds that there's no climb animation: you gain upward momentum, you can fling yourself a little in any direction with WASD, and a well-timed input or jump gives a better fling. The game never takes control.
- **Feathering:** players tap the glider on and off. The owner points to a video about Nidhogg. The public wiki and guide pages we could read (supervive.wiki.gg Gliding, Abyss) don't describe it, so every feathering number here is [est]. [footage] says heat keeps climbing across repeated drop-and-lift cycles and only really cools on the ground.
- **Ground movement [spec]:** near-instant acceleration and deceleration (a 0.05–0.1s ramp). Camera follow smoothing is 0.08–0.15s.
- **Not published:**
  - Jump height or arc.
  - Glide turn rate.
  - Drop dive speed.
  - Whether jump height is variable. Nothing suggests SUPERVIVE has it, and holding jump is already the glide input, so **no variable jump height** was added.
  - Coyote time or buffer values. These use FeelConfig's 0.1s / 0.12s.

## Targets and results

"Before" is main as it was when this work started (e7c7086; for the abyss, framing and obstacle rows, main 3b800a0), measured with the same checks. "After" is branch `movefeel`.

| Key | Before | After | Target | Source |
|---|---|---|---|---|
| ground_input_frames | 1 | 1 | <= 1 step | press acts the same step |
| ground_t95 (to 95% run speed) | 0.083s | 0.067s | <= 0.07s | [spec] 0.05–0.1s |
| ground_stop_t | 0.067s | 0.167s | 0.12–0.25s | [game data] braking 22.2 m/s² + friction 2/s (SV ~0.18s) |
| ground_stop_dist | 0.10m | 0.31m | 0.2–0.5m | [game data] SV slides ~0.38–0.49m |
| ground_reverse_t (180 degrees) | 0.150s | 0.117s | <= 0.12s | [spec] crisp |
| ground_turn90_t | 0.100s | 0.083s | <= 0.09s | [spec] crisp |
| speed light / medium / heavy | 5.2 / 5.0 / 4.73 | same | class data | KINFALL_CLASSES |
| jump_input_frames | 1 | 1 | <= 1 | |
| jump_apex | 1.28m | 1.52m | 1.2–1.6m | [game data] 1.9m, held under 1.6 for the terrace grammar |
| jump_speed_vs_source (lift-off 6.8 m/s over 7.5) | n/a | 0.87 | 0.85–1.0 | [game data] JumpZVelocity 750 uu/s; the gap is the terrace call, plus one step of gravity |
| jump_airtime | 0.633s | 0.900s | 0.85–1.05s | [game data] 1.02s |
| air_carry_m (let go at take-off) | n/a | 3.4m | >= 3.0m | [game data] FallingLateralFriction 0.375 |
| air_reverse_dv (keys reversed for a whole jump) | n/a | 0.63 m/s | 0.5–1.1 m/s | [game data] AirControl 0.015 |
| dash_exit_run (speed as a dash ends / run speed) | 0.15x | 1.0x | 0.95–1.05x | [game data] no hard stop |
| dash_exit_slide_m (let go out of a dash) | ~0.02m | 0.33m | 0.2–0.5m | [game data] the walking stop |
| coyote_frames | 7 | 7 | >= 6 | FeelConfig 0.1s |
| jump_buffer_frames | 6 | 7 | >= 7 | FeelConfig 0.12s |
| freefall_1s_depth | 6.37m | 7.20m | 6.8–8m | [game data] 14.7 m/s² capped at 12 m/s ([footage] ~8m) |
| glide_open_press_frames (second press) | 1 | 1 | <= 1 | [guide] |
| glide_open_hold_s (Space held from the jump) | 0.150s | 0.117s | <= 0.12s | tap/hold split |
| glide_open_button_frames (glide button) | 6 | 1 | <= 1 | no tap ambiguity |
| glide_catch_t (terminal fall to sink rate) | 0.383s | 0.150s | <= 0.2s | opens "instantly" |
| glide_speed | 6.5 m/s | 5.0 m/s | 4.5–5.5 | [game data] MaxGlide 500 uu/s (item 163: ours was "too fast and controllable") |
| glide_sink | 2.2 m/s | 1.4 m/s | 1.2–1.6 | owner: "falls a bit faster"; [spec] 2–4 is an eyeball guess |
| glide_turn90_t | 0.200s | 0.383s | 0.3–0.6s | [game data] GlideTargetXYForce: a force, so turns have inertia (item 163) |
| glide_reverse_t | 0.417s | 0.600s | 0.45–0.8s | [game data] the same force brakes a reversal (item 163) |
| glide_brake_ratio (10 m/s, 0.4s against vs let go) | 0.60 | 0.00 | <= 0.8 | brake stays |
| reglide_frames / dashglide_reopen_frames | 1 / 1 | 1 / 1 | <= 1 | |
| dashglide_open_speed (glider opened out of an air dash) | 6.9 m/s | 13.8 m/s | >= 12 | [wiki] momentum + speed |
| dashglide_1s_speed | 5.7 m/s | 12.3 m/s | >= 10.5 | [wiki] preserved |
| dashglide_2s_speed | 5.0 m/s | 10.8 m/s | >= 9 | [wiki] preserved |
| feather_toggle_frames (let go, press again) | 1 | 1 | <= 1 | no toggle penalty |
| feather_m vs feather_hold_m (distance before overheating, over the abyss) | (no feathering) | 110.7m vs 90.1m | | |
| feather_gain | n/a | 1.23x | >= 1.15x | [est] skilled taps beat holding when heat is the limit |
| ledge_rise_t (1.6m wall, jump and push in: contact to over the top) | (scripted mantle) | 0.08s | <= 0.35s | [footage] ~0.8s from a full second deep |
| rim climb, 2.5m under a rim over the void (`--mantle-check`) | 0.40–0.58s (scripted) | 0.55–0.63s | < 1.4s | [footage] ~0.8s |
| ledge_rise_peak_m (no jump: height over the top) | n/a | 0.36m | >= 0.2m | [est] a small pop |
| fling from a 1.35m rise (`--mantle-check`, 6 walls): none / early jump / timed jump | n/a | +0.38m & 1.25m on / +0.24m & 1.31m / +0.94m & 2.22m | timed beats both | [est] |
| ledge_fling_timed_m (from a jump at a 1.6m wall) | n/a | 4.28m | >= 1.5m | [est] |
| ledge_fling_timed_up_m | n/a | 0.95m | >= 0.7m | [est] |
| ledge_fling_gain (timed vs no jump, distance) | n/a | 3.4x (1.8x from a 1.35m rise) | >= 1.5x | [est] rewarding |
| ledge_window_s | n/a | 0.117s (7 steps) | >= 0.08s | [est] readable |
| abyss_lift_t (4m deep to balloon line) | 1.05s | 0.82s | <= 1.0s | [footage] ~1s |
| abyss_kill_depth (point of no return under the lip) | 6.0m | 17.5m | 17–18m | [game data] AbyssHeight |
| abyss_recover_depth (deepest a terminal fall can still glide out) | ~6m | 18.5m | >= 15m | |
| abyss_fall_t / abyss_fall_vy_deep (step off the lip) | n/a | 1.93s / 10.0 m/s | >= 1.8s / 10–10.8 | [game data] AbyssFallSlow 12 to 10 m/s |
| abyss_bounce_m (lift from 6m deep, over the lip) | ~0.8m | 1.58m | >= 1.5m | owner: bouncy |
| glide_high_sink / glide_swoop_speed (gliding above 8.5m) | 1.4 / 6.5 m/s | 3.5 / 11.75 m/s | 3.3–3.6 / >= 10.5 | [game data] GlideDownwardForce, swoop 2.5x |
| dive_vy / dive_vy_t (hold Ctrl under the glider) | n/a | 32.5 m/s / 0.75s | 32–32.5 / 0.6–0.9s | [game data] GlideDiveZTargetSpeed -3250 uu/s, ZForceMax 350,000 / Mass 100 |
| dive_steer_ratio (the keys in the dive vs under the glider) | n/a | 0.25x | 0.2–0.3 | [game data] GlideDiveXYForceMultiplier |
| dive_cancel_h / dive_timeout_s | n/a | 3.27m / 9.98s | 2.9–3.5 / 9.9–10.1 | [game data] GlideDiveCancelDistance 350 uu, GlideDiveTimeout 10 s |
| dive_swoop_speed (let go of Ctrl high up) | n/a | 15.0 m/s | 12–15 | [game data] swoop 2.5x, capped at GLIDE_MAX |
| abyss_tint_lip / half / end (screen danger 0..1) | (old HUD rings only) | 0.00 / 0.67 / 0.99 | <= 0.02 / >= 0.6 / >= 0.95 | owner: "really dark/red when going low" |
| updraft_rise_t (to 8 m/s climb) | 0.333s | 0.233s | <= 0.3s | [est] powerful |
| drop_dive_vy_t (90% of dive fall) | 0.583s | 0.333s | <= 0.4s | [est] punchy |
| drop_dive_steer_t (90% of commanded) | 0.783s | 0.233s | <= 0.3s | [est] responsive |
| drop_deploy_frames | 1 | 1 | <= 1 | |
| drop_deploy_settle_t | 0.267s | 0.217s | <= 0.3s | [est] |
| drop_glide_steer_t | 0.583s | 0.217s | <= 0.3s | [est] |
| drop_land_dead_frames / land_dead_frames | 1 / 1 | 1 / 1 | <= 1 | no dead time |
| land_squash | 0.00 | 0.16 | >= 0.05 | landing reads |
| e2e_input_frames (key to sim, via Match._process) | 1 | 1 | <= 1 | |
| e2e_render_frames (key to model moving) | 2 | 1 | <= 1 | no interpolation lag |
| render_lag_m (model behind sim at a run) | 0.083m | 0.000m | <= 0.03m | |
| cam_lag_m (camera behind you at a run) | 0.65m | 0.29m | <= 0.40m | [footage] centred |
| cam_settle_t (after a stop) | 0.35s | 0.15s | <= 0.35s | |
| cam_glide_lead_m | -0.67m (trailing) | +0.92m | >= 0.4m | lead in glide |
| view_across_m (Supervive preset, 16:9) | 28.0m | 23.5m (movefeel 23.0m) | 22–25m | camcal: ~17 hunter silhouettes across, as in gameplay frames |
| hunter_screen_pct (medium hunter, feet to head) | 5.4% | ~7% (movefeel 7.6%) | 6.4–7.6% | camcal: its silhouette ~10.5% of the height, as in gameplay frames |
| hunter_feet_below_pct (feet below screen centre) | 0% | ~4% | 1.5–5% | camcal: the view aims at the body |

Other checks:

- `--wallhug-check` (tools/wallhug_check.gd): 40 grabbable rims are hugged from the abyss side. There are 2400 tries over heights from 0.8m above to 4m below the lip, keys 0/45/65 degrees off straight into the wall, gliding or not, and touching the wall or a step off it falling at full speed. A try counts as caught only when it ends standing on top.
  - Main caught 2141 of 2400 (89.2%).
  - Movefeel catches 1578 of 1600 (98.6%) with the keys pushing in (0/45 degrees), target 95%.
  - Steering mostly along the wall (65 degrees) it catches 691 of 800 (86.4%), target 70%. The ledge rise follows your keys, so sliding along a short rim can carry you off its end. Before the rise reworked the mantle, the scripted mantle caught all 2400.
- `--mantle-check` (tools/mantle_check.gd): checks the ledge rise, steering and the fling, plus that ledges you don't push into never grab you (see below).
- `--obstacle-check` (tools/obstacle_slide_check.gd, from branch `stuckfix`): walks round, away from and past every tree and rock cluster on the training map and an expedition island.
  - Main 3b800a0: a hunter hugging a 3-tile rock cluster on the expedition island is pinned on a corner for 823 steps (13.7s).
  - Movefeel (and `stuckfix`):
    - Expedition island: 31 of 31 laps clean, 853 of 853 walk-aways leave at once, 851 walk-pasts with 0.0000m pull.
    - Training map: all 20 clusters clean.

## What changed (all in clearly marked `(movefeel)` blocks)

- **Input to screen:** the local player is drawn at the present (`Hunter.render_pos`, `LOCAL_RENDER_LEAD`), extrapolated by the fraction of a step since the last one. Before, it was interpolated up to a step in the past, so a press showed a frame late and the camera trailed. Everyone else is still interpolated, and a teleport snaps.
- **Ground:** acceleration 70 → 90 m/s², deceleration 90 → 110 m/s².
- **Air:** steering 22/3 → 40/9 m/s², so letting go in a jump stops you. Speed above run speed (a dash, a pad, a knockback) still carries at 3 m/s².
- **Falls:** gravity x1.2 straight to a 10 m/s terminal speed, which matches the footage depth and tightens the jump arc. It replaces the slow 3.2/s ease to 9 m/s. The camera's soft vertical follow keeps falls from jolting the view.
- **Glider:**
  - Steering is `glide_steer()`:
    - 420°/s at cruise, in wider arcs above cruise (down to 45%).
    - 26 m/s² acceleration; over-speed bleeds at 1.5 m/s².
    - Steering more than 115° against your heading brakes at 36 m/s². Letting go drifts.
  - Cruise 5.0 → 6.5 m/s and sink 2.2 → 1.4 m/s. The owner found the glide "falls a bit faster and feels weaker than SUPERVIVE".
  - The canopy catches a fall at 60 m/s² (was 16).
  - Space opens the glider after 0.1s (a tap is a jump). The glide button (unbound by default; Mouse 5 is a dash key now) opens it at once (`inp.glide_btn`, local input only).
  - **Dive** (`GlideDive`, `HunterMove.dive_*`, all [game data]): hold crouch (Ctrl) under an open glider and the canopy folds into a plunge toward 32.5 m/s at 35 m/s², the keys steering at a quarter of their glide force. Let go, come within 3.5 m of the ground (or the island's lip over the abyss) or hold for 10 s and the glide catches you again; the drop you pull out of becomes speed, capped at the glide's 15 m/s max. The key is ours: the source names no dive input, and Space is the glider itself. The folded pose is local-only (the dive isn't in the net snapshot).
  - The abyss lift's brake zone rises at 3.5 m/s per metre left (was 2). Updrafts grab at 45 m/s² (was 30).
- **Heat** (owner, Nov 2: "lasts too long, not punishing enough"): a level glide overheats after 9s (was 14). Hits heat it 3x (was 2x). An overheated glider burns ~3.5% of max health a second in 20-damage ticks, flies at 0.5x speed and sinks at 5 m/s.
- **Feathering** [est] (tap the glider on and off instead of holding it). Constants: `FEATHER_*`, `lift_t`, `glide_off_t`.
  - Open and close are instant, with no penalty for rapid toggles. The glider reopens with 5% of its heat room left (was 15%).
  - While the glider is closed in the air its heat cools at 0.04 per second (was 0.06) (a full glider is 1.0). The ground still cools it fastest: [footage] "it only really cools on the ground".
  - For 0.6s after you let go you keep the glide's speed and steering.
  - The first 0.3s of an abyss lift (the "rapid upward impulse" [wiki]) heats at 0.4x a level glide (was 1x; lowered with the shorter glider so feathering still beats holding). Holding the lift past that costs the full 4x. So short lift taps that coast on the impulse are the skilled, efficient way across.
  - Unconfirmed: what SUPERVIVE's feathering exactly does. Public pages don't describe it. These numbers are ours, to be checked against the owner's Nidhogg reference video.
- **Dash into glide** (`glide_handoff(dir, speed)`, `_take_glide_handoff()`):
  - The Shift dash's end and a jump out of a dash register the burst. If the glider opens within 0.3s, heading within about 70° of the burst, it starts at 60% of the burst's speed (max 14 m/s). That speed bleeds off slowly.
  - The burst reads clearly: a loud whoosh, a burst of air, a dense streak trail with afterimages while you stay well above cruise, and a brief camera pull-back (`CamRig.pull_back`).
  - **Archetype dashes:** call `glide_handoff(dir, speed)` as the dash ends.
- **Ledge rise** (replaces the scripted mantle; `Hunter._ledge_rise`, `_ledge_fling`, `lfloat`). This follows the owner's description of SUPERVIVE.
  - When it starts: you're below a ledge in the air and your keys push into it (within about 60 degrees of straight in; over the abyss below a lip, about 78 degrees). You gain upward momentum and float up the face. No climb animation sets your position.
  - Steering: your keys steer the whole way (ordinary air steering). Nothing holds you to the face except the wall itself.
  - Letting go: moving 0.9m out from the face, a dash, a fresh glide press, a stun or a knock ends the rise.
  - Over the top with no jump: a small pop (3.2 m/s), carried toward your keys.
  - The fling window: the last 0.6m below the top (about 0.12s), shown with a click and a ring. A jump in it flings you to 0.9m over the top at 7.5 m/s toward your keys, with a whoosh. A jump earlier gives a weak fling (just over the top, at run speed).
  - Never grabs you: walking, jumping along a wall, glancing it, or standing next to it with no keys. Gliding past a lip doesn't grab you either unless you steer into it.
  - Home uses the same rise (`Home._ledge_float`).
  - A deliberate pull still lands you on top: `Hunter.launch_to` to higher ground (an archer's Grapple onto a ledge, a leap up a cliff) flies a sure arc.
- **Wall catch over the abyss:** below an island's lip, a wall 0.75m from your side catches you (elsewhere 0.4m), except near a sheer cliff. The abyss catch reach is 4.5m below the lip (was 3.5m). A sheer cliff right in front of you has nothing to hold, and its neighbours don't catch you through it.
- **Rocks, trees and walls are walls** (item 151): a jump into one never lifts you over it (the old rock hop did, and dropped you into one-tile holes inside rock clumps). The generator never leaves ground sealed in by blockers (BlockPrune.fill_pockets), so nothing can land you in a hole you can't walk out of. Terrain ledges are the ledge rise's.
- **Abyss:**
  - Hunters' point of no return is `World.ABYSS_DEPTH` + 7m: about 13m under the lip (was 6m). Monsters and the home keep the old depth.
  - As you sink, the local player's screen drains of colour, darkens, goes deep crimson and closes in with a vignette that beats with a heartbeat (`scripts/match/abyss_fx.gd`, a screen shader under the HUD). The HUD adds a heartbeat and a low rumble, and near the end a pulsing "HOLD GLIDE TO LIFT" / "CLIMB OUT".
- **Drop:**
  - Dive fall 11 → 13 m/s, reached in about 0.3s.
  - Steering 3/4 → 10/11 per second.
  - Deploying checks your fall to -1.6 m/s, then settles to 4.2 m/s in about 0.2s. It comes with the glider sound, a ring and a small camera punch.
- **Landing:** every landing faster than 4 m/s gets a brief squash, a puff and a soft thud, with no lockout. Jump buffering is time-based (0.12s from the ground at your fall speed).
- **Trees and rocks (`stuckfix`):**
  - Bodies collide with blocker tiles as true circles (`World.occupy`, `World.push_out_blocks`).
  - A move into a rock is pushed straight out and slides along it. Only the part of your speed going into it is dropped.
  - This ends the corner snag that held you until you dashed ("magnetizing").
- **Camera and scale:**
  - Follow across: 8 → 15 per second (about 0.07s).
  - Glide lead: 0.2s of glide velocity (max 1.8m).
  - The Supervive preset sits at 20.5m (was 25m): about 23m of ground across a 16:9 screen (was 28m).
  - Hunters are drawn 12% larger (`Hunter.VIS_SCALE`, visual only; hitboxes and rings unchanged).
  - Together these take the medium hunter from 5.4% to 7.6% of the screen's height.
- **Camera calibration (`camcal`):** the Supervive preset re-measured from 1080p gameplay frames (training-map footage, HUD visible; one zoomed-out transition frame left out).
  - Pitch 65.5° ±1.5 and vertical FOV ~32° (25–34°): a least-squares camera fit to a floor ring and the platform rim it sits in (ellipse extents), plus a matched pair of barrels at the top and bottom of the screen (lid widths 70 vs 87 px, sides 47 vs 25 px). A matched pair of posts gives the same answer (vertical sides 67 vs 45 px, about 34°).
  - The hunter's silhouette is ~10.5% of the screen's height (75–80 px of 742), centred across, with the feet ~3–4% below the centre. The ground across is ~17 silhouette heights. Crates read ~1.1 and walkways ~1.5 silhouette heights wide.
  - Ours measured the same way (the medium gunslinger, 1320x742): the movefeel framing already drew the silhouette at ~10.8% (80 px; the wide hat seen from above makes it read far bigger than the 7.6% feet-to-head figure), so the distance stays near it. A metre-based match (a 1.8 m hunter, ~12–16 m across) would have drawn our chunkier hunters ~1.5x the footage size.
  - The preset is now pitch 66° (was 65°), FOV 32° (was 35°), 23.0 m back (was 20.5 m; the narrower lens needs it to keep the same size), and it aims 1.0 m above the focus (`CamRig.rise`, new). That is ~23.5 m across. Wall-face foreshortening (cot pitch) is 0.445 vs the reference 0.456 (was 0.466). Ground scale at the screen's top edge vs its bottom edge is 0.774 vs the reference 0.769 (was 0.744).
  - The movefeel framing stays available as "Supervive (wider lens)" (`supervive_wide`). `--cam-style=<id>` picks a style for one tooling run.
- **Settings:**
  - "Expedition camera" is now "Camera".
  - The style and follow mode also apply at home (`CamRig.apply_settings`). The farm keeps its own wider framing (`Home._apply_cam_settings`).

## Move pass: wall moves, ledges that answer, a springier abyss (`--wallmove-check`)

- **Wall kick / wall dance** (`WallMoves`, every hunter; item 149, the SUPERVIVE wall dance): touching or facing a wall (your keys, else your aim), every jump press hops you off it: no limit, no cooldown, no glider, and a stone scuff with a varied pitch that everyone nearby hears (online too: the "fx" "whop" event). Keys into the wall or none add `KICK_RISE` 0.8m to the jump you are on; keys away push you off at 7.5 m/s. A hop only starts up to `HOP_CLIMB_CAP` 1.6m over your take-off ground, so you can dance at a wall indefinitely, jump + kick + mantle (1.5m) tops 4 terraces (3.2m, the Cinder Steps plateau), and 5 terraces (4.0m) stay sheer. Near a wall a capped press does nothing rather than open the glider (the glide button or a held glide still does). The glider stays shut until each hop's rise ends.
- **Wall bounce** (`WallMoves`): an airborne dash, glide or boosted jump that hits a wall more than 20 degrees off its normal and at least 4 m/s into it reflects about the normal, keeping 85% of the speed. Your keys steer the rebound for 0.25s at 25 m/s^2. Head-on it stops as before. Ground dashes, shoves and charges, walls low enough to mantle, knockbacks and slow jumps don't bounce. Dust, a spark and the landing thud mark it.
- **Ledges:** the rise no longer waits for the apex of a jump. Any airborne state (rising, falling, gliding, just after releasing the glider, after a dash) catches a ledge top within `MANTLE_REACH` above you when you press into it, or when glide momentum carries you into it. A ledge higher than where you last stood counts once you have been in the air 0.5s (`GlideLift.LEDGE_AIR_T`), are gliding, or let go of the glider within the last 0.6s (`FEATHER_KEEP`); before, launching from a higher place meant the ledge never caught you. Stunned or rooted players never grab a ledge. Only a tile sharing an edge with yours counts, so sliding along a wall never pulls you up it.
- **Abyss (SUPERVIVE-like float):**

| Constant | Before | After | Why |
|---|---|---|---|
| `GlideLift.OPEN_KICK` | none | 6 m/s, once per lift, 8% of the heat, capped at `ABYSS_LIFT_CAP` | spring when the glider opens more than 2.5m under the lip |
| `ABYSS_LIP_VY` | 1.5 m/s | 3.5 m/s | the lift reaches the lip still rising and floats over it |
| `GlideLift.HANG_GRAV` / `HANG_T` | 1.0 / none | 0.35 / 0.9s | lower gravity at the top of a lift: a soft hang |
| `GLIDE_DECEL` | 2.0 | 1.4 | less drag, a long coast |
| `GLIDE_OVERSPEED` | 1.5 | 1.1 | momentum carries longer |

  Measured opening 6m deep at -8 m/s: peak over the lip -0.39m before, +0.77m after; time near the top (above the lip, under 1 m/s vertical) 0.00s before, 0.38s after. Heat rules are unchanged.
- The `--mantle-check` steering-away window is 24 steps (was 12): a ledge now catches you earlier in the jump, so reversing out takes longer to show as distance.

## Physics pass: SUPERVIVE's game data (`physics76`)

Tunables are in `content/rules/hunter_move.json` (`physics`), read by `HunterMove`; values and sources are in SUPERVIVE_DATA.md.

- **Gravity** 30 (x1.2 falling) → 14.7 m/s², one gravity. **Jump** 9 → 6.8 m/s (the data's 7.5 would let jump + mantle top four terraces). **Wall kick** rise 0.9 → 0.8m, so jump + kick + mantle still tops 4 terraces and not 5.
- **Fall cap** 10 → 12 m/s, easing to 10 m/s from 1m to 16.5m under the lip. **Point of no return** 13 → 17.5m under the lip: about 1.9s of falling to save yourself (was ~1.4s).
- **Air control** (`HunterMove.air_steer`): keys steer at 0.3x your ground acceleration and carried speed bleeds at 0.375/s. The data's 0.015 felt like dropped input top-down. A ledge rise keeps the old crisp air steering.
- **Glide height hold** (`GlideLift.sink`): more than 8.5m over the ground (or the lip) the glider sinks at 3.5 m/s, and 2.5x the drop past its usual sink becomes glide speed, fading over 1.5s.
- **Mantle**: topping out sends you onto the ledge at max(0.6x run speed, 3.5 m/s). The no-jump pop is 2.6 m/s (was 3.2; lower gravity floated it twice as long).
- **Glider at any heat, softer deep lift** (owner item 63): the glide input opens the glider at every heat, overheated or not (no heat floor, no lockout after an overheated one closes); overheated it burns you and lifts at half strength. The deepest lift is 30% softer (climb cap 26 -> 18.2 m/s; speed per metre of depth 1.7 -> 1.1) at the same heat cost. Measured by `--glider-heat-check`.
- **Abyss bounce** [est]: the lift reaches the lip at 4.5 m/s (was 3.5), floating ~1.6m over it.
- **Feathering**: the glider no longer cools in the air, and a lift's first 0.3s heats like a level glide (was 0.4x). The slower gravity had made coasting between taps so cheap that feathering went 4.8x as far as holding; it is 2.0x now.

## Air limits: the drop and the glider during moves (`AirLimits`, `--air-limits-check`; items 162, 162b)
- **The opening drop is steering only:** heading and the dive. Shift, jump, LMB, RMB, E, R, gloves, belt items and the Boki throw do nothing until you land, and the HUD greys those slots. Space only deploys the canopy out of the dive. This replaces the old rule that an ability or heal pressed mid-drop broke out of it.
- **No glider during an ability or attack animation:** a hold (Kael's Lunge charge, Breaker's spin, Lisette's draw), a cast, a dash or a kit move still inside its keys keeps the glider shut. Glide held opens it the moment the move ends, with its speed. A move that travels ends with its travel, and a kit's Shift moves count as the dash, so Shift into a glide still opens the step the dash ends. Tarek's Quakefall runs to its landing (no glide-out mid-move), except over the abyss. An open glider is never folded by this rule.
- **Free fall:** a fall never gives more dashes than the ground does (the charges plus the long dash). Each hero's air dash itself is item 183's audit.

## Not touched

- Dash kits (the archetypes own them). Only the generic `glide_handoff()` hook was added, and `launch_to` was made sure for upward targets.
- The network protocol. Movement runs on the owning machine, and remote hunters still use `net_follow`.
- Landing performance (branch `landhitch`).
