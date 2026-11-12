# Movement feel: targets, sources, measurements

The owner's note (Oct 31 2026): dropping, gliding and moving felt sloppy. SUPERVIVE is the bar: snappy and responsive, especially the glide, and Shift into a glide should give you more momentum.

Every target below is checked by `--move-feel-check` (`tools/move_feel_check.gd`). The check drives the real match step with scripted inputs. It counts fixed 60 Hz simulation steps, never wall-clock time, so a loaded machine can't skew it. It never touches the save. `--fps-feel-check` steps the same moves at 1/30, 1/60 and 1/144 s and holds jump apex, dash, glide sink and knock within 3% of each other (docs/decisions/0022).

```
XDG_DATA_HOME=<scratch> godot --headless --path . -- --move-feel-check
```

It prints one `MFEEL <key> = <value> target <op> <target> ok|FAIL (source)` line per measurement and ends with `MOVE FEEL CHECK DONE, failures: N`.

Frame rate must not change the feel: `--fps-parity-check` (`tools/fps_parity_check.gd`) plays one input script (dash, jump, glide 2 s, hold LMB 3 s, cast E) for Vex, Kael, Cinder and Sparkle through the real `Match._process` at 30, 60 and 144 fps and at 60 fps with 20 ms hitches, and asserts dash length, jump apex, glide reach, end position, swings/shots/flame ticks and the E cooldown end agree within 2% (and that sim time keeps pace with the frames drawn). The physics step is fixed at 60 Hz; only the camera and animation read the frame time.

Source tags follow SUPERVIVE_FEEL.md / SUPERVIVE_DATA.md:

- `[wiki]` is supervive.wiki.gg.
- `[guide]` is a published guide (Deltia's Gaming gliding guide, ludo.guide).
- `[footage]` is a frame measurement from SUPERVIVE_FEEL.md.
- `[spec]` is docs/EXPEDITION_SPEC.md.
- `[est]` is our own estimate, tuned for feel and labelled as such.
- `[game data]` is the decoded source data (briefs/supervive-data on ext/agent-briefs).
- `[unseen]` means the footage we have does not show it; nothing was changed on it.

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
  - Whether jump height is variable. Nothing suggests SUPERVIVE has it, and holding jump keeps the glider open, so **no variable jump height** was added.
  - Coyote time or buffer values. These use FeelConfig's 0.1s / 0.12s.
  - Whether jump height is variable. Nothing suggests SUPERVIVE has it, and holding jump is already the glide input, so **no variable jump height** was added.
  - Coyote time or buffer values. The game files name JumpCooldown and AirJumpPressDuration but their values are
    in the encrypted code, bCanWalkOffLedges is false there (no walk-off, so no coyote window to copy), and the
    reference footage is 5 fps (0.2 s a frame, coarser than either window). Ours stay: `Hunter.COYOTE` 0.12 s and
    `Hunter.JUMP_BUFFER` 0.12 s (7 steps each), checked by the four jump-forgiveness rows below.
  - Whether jump height is variable, and whether there is a re-jump delay. The game data names JumpMaxHoldTime, JumpCooldown, JumpApexTime and a JumpDecel spring, but their values are not decoded (supervive_physics.md), and the 5 fps footage shows no tap next to a held jump, no two jumps in a row and no jump just past a ledge (Nov 9 re-check of briefs/hero-ref). Holding jump is already the glide input, so ours keeps **a fixed jump height and no re-jump delay**.
  - Coyote time or buffer values. The source can't walk off an edge at all (bCanWalkOffLedges false), so it needs no coyote time; ours can (owner), so it uses FeelConfig's 0.12s for both (`coyote`, `jump_buffer` in content/rules/hunter_move.json).

## Targets and results

"Before" is main as it was when this work started (e7c7086; for the abyss, framing and obstacle rows, main 3b800a0), measured with the same checks. "After" is branch `movefeel`.

| Key | Before | After | Target | Source |
|---|---|---|---|---|
| ground_input_frames | 1 | 1 | <= 1 step | press acts the same step |
| ground_t95 (to 95% run speed) | 0.083s | 0.067s | <= 0.07s | [spec] 0.05–0.1s |
| ground_stop_t | 0.067s | 0.167s | 0.12–0.25s | [game data] braking 22.2 m/s² + friction 2/s (SV ~0.18s) |
| ground_stop_dist | 0.10m | 0.31m | 0.27–0.4m | [game data] UE's walking brake slides 0.28–0.39m drawn at 30–144 fps (MOVEMENT_PARITY.md §1) |
| ground_reverse_t (180 degrees) | 0.150s | 0.117s | <= 0.12s | [spec] crisp |
| ground_turn90_t | 0.100s | 0.083s | <= 0.09s | [spec] crisp |
| speed light / medium / heavy | 5.2 / 5.0 / 4.73 | same | class data | KINFALL_CLASSES |
| haste_two_bonus_x (haste 0.35 + kin buff 0.15, speed / plain run) | 1.55x (multiplied) | 1.50x | 1.49–1.51x | [game data] one MoveSpeed attribute: bonuses add (decision 0054) |
| haste_bonus_slow_x (haste 0.35 under a 40% slow) | 0.81x | 0.81x | 0.80–0.82x | the slow multiplies the hasted total |
| haste_cap_mps (+100% and haste) | 10.3 m/s | 7.0 m/s | 6.95–7.0 | [game data] MaxMoveSpeed 700 uu/s |
| haste_clip_rate (clip rate / (speed / clip speed), worst Warden, hasted and capped) | 0.94x (rate held at 1.5x) | 1.00x | 0.99–1.01x | no foot slide (WardenClips.loco_rate) |
| jump_input_frames | 1 | 1 | <= 1 | |
| jump_apex | 1.28m | 1.52m | 1.2–1.6m | [game data] 1.9m, held under 1.6 for the terrace grammar |
| jump_speed_vs_source (lift-off 6.8 m/s over 7.5) | n/a | 0.87 | 0.85–1.0 | [game data] JumpZVelocity 750 uu/s; the gap is the terrace call, plus one step of gravity |
| jump_airtime | 0.633s | 0.900s | 0.85–1.05s | [game data] 1.02s |
| air_carry_m (let go at take-off) | n/a | 3.4m | >= 3.0m | [game data] FallingLateralFriction 0.375 |
| air_reverse_dv (keys reversed for a whole jump) | n/a | 0.63 m/s | 0.5–1.1 m/s | [game data] AirControl 0.015 |
| dash_exit_run (speed as a dash ends / run speed) | 0.15x | 1.0x | 0.95–1.05x | [game data] no hard stop |
| dash_exit_slide_m (let go out of a dash) | ~0.02m | 0.33m | 0.2–0.5m | [game data] the walking stop |
| dash_curve_<hero>_peak_u / _peak_k (gunslinger, juggernaut, archer: where the speed peaks, peak / mean) | flat | 0.11 / 1.86, 0.29 / 1.74, 0.44 / 1.86 | the fit ± ~0.08 / ± ~0.1 | [footage] docs/SUPERVIVE_FEEL.md "Dash speed curves" |
| dash_curve_dist / dash_curve_exit_run (distance against the kit's, hand-over / run) | n/a | 1.00–1.01x / 0.31–1.0x | 0.95–1.05x / <= 1.05x | the curve's mean is 1; the skid falls through run speed |
| coyote_frames | 7 | 7 | >= 6 | FeelConfig 0.1s |
| jump_hold_dv (tap vs Space held, 0.1s in) | n/a | 0 m/s | <= 0.01 | JumpMaxHoldTime undecoded: fixed height |
| rejump_frames (press the step after landing) | n/a | 1 | <= 1 | JumpCooldown undecoded: no delay |
| coyote_frames | 7 | 7 | 6-8 | FeelConfig 0.12s; a later press doesn't jump |
| jump_buffer_frames | 6 | 7 | >= 7 | FeelConfig 0.12s |
| coyote_frames (latest press after walking off a rim) | 7 | 7 | >= 7 | `Hunter.COYOTE` 0.12s; source has no walk-off |
| jump_buffer_frames (earliest press before landing) | 6 | 7 | >= 7 | `Hunter.JUMP_BUFFER` 0.12s; source silent |
| jump_buffer_dash_frames (the press lands inside an air dash that ends 4 steps before the landing) | n/a | 7 | >= 7 | the same buffer, held across the dash end |
| dash_jump_eaten (ground-dash frames whose jump press does not jump) | n/a | 0 | <= 0 | a press on any frame jumps out of the dash |
| freefall_1s_depth | 6.37m | 7.20m | 6.8–8m | [game data] 14.7 m/s² capped at 12 m/s ([footage] ~8m) |
| glide_open_press_frames (second press) | 1 | 1 | <= 1 | [guide] |
| glide_open_hold_s (scripted input only: a player's Space held from the jump never opens it, glide_press_only) | 0.150s | 0.117s | <= 0.12s | tap/hold split |
| glide_press_held_s (jump, let go, press and hold) | 1.0s | 1.0s | >= 1.0s | owner 11-08: the double press |
| glide_hold_opens (Space held 2 s from the jump) | opened at 0.117s | never | never | owner 11-08: a hold never glides |
| albert_lmb_hold_glides (Albert, LMB and Space held) | opened | never | never | owner 11-08 |
| glide_open_button_frames (glide button) | 6 | 1 | <= 1 | no tap ambiguity |
| glide_catch_t (terminal fall to sink rate) | 0.383s | 0.183s | <= 0.2s | [guide] opens "instantly"; the catch rate is ours, the source's fastest-fall clamp at the open is locked |
| glide_start_vy (opened from a rising jump: the first glide step's fall) | rising on | 1.08 m/s | 0.85–1.4 | [game data] GlideStartFallSpeedMin -85 uu/s: the open cuts the rise, never adds speed |
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
| ledge_rise_t (1.6m wall, jump and push in: contact to over the top) | (scripted mantle) | 0.33s (0.15s before the 11-09 suction) | <= 0.45s | [game data] jump-paced; suction cap 2.5 m/s (decision 0026) |
| ledge_rise_vy_max (the fastest rise up that wall) | n/a | 5.6 m/s (14 before) | <= 7 m/s | [game data] the suction never outruns the jump |
| rim climb, 2.5m under a rim over the void (`--mantle-check`) | 0.40–0.58s (scripted) | 0.87–0.97s | < 1.4s | [footage] ~0.8s |
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
| glide_high_sink / glide_swoop_speed (gliding above 8.5m) | 1.4 / 6.5 m/s | 3.5 / <= cruise | 3.3–3.6 / <= 5.3 | [game data] GlideDownwardForce; the drop adds no speed (owner 11-08) |
| dive_vy / dive_vy_t (hold Ctrl under the glider) | n/a | 32.5 m/s / 0.75s | 32–32.5 / 0.6–0.9s | [game data] GlideDiveZTargetSpeed -3250 uu/s, ZForceMax 350,000 / Mass 100 |
| dive_steer_ratio (the keys in the dive vs under the glider) | n/a | 0.25x | 0.2–0.3 | [game data] GlideDiveXYForceMultiplier |
| dive_cancel_h / dive_timeout_s | n/a | 3.27m / 9.98s | 2.9–3.5 / 9.9–10.1 | [game data] GlideDiveCancelDistance 350 uu, GlideDiveTimeout 10 s |
| dive_swoop_speed (let go of Ctrl high up) | n/a | <= cruise | <= 6 | owner 11-08: pulling out of a dive adds no speed |
| dive_swoop_speed (let go of Ctrl high up) | n/a | 15.0 m/s | 12–15 | [game data] swoop 2.5x, capped at GLIDE_MAX |
| dive_land_vy (Ctrl held to the ground) | 26.5 m/s | 1.4 m/s | <= 4 | [game data] the glide catches at GlideDiveCancelDistance and holds you to the ground; no hard-land beat |
| dive_release_glide_t (let go high up, back under the glider) | n/a | 0.48s | 0.3–0.7 | [game data] the canopy's usual catch, no landing |
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
| cam_lag_m (camera behind you at a run) | 0.65m | 0.00m | <= 0.40m | [footage] centred: the follow is locked across |
| cam_settle_t (after a stop) | 0.35s | 0.15s | <= 0.35s | |
| cam_glide_lead_m | -0.67m (trailing) | +0.92m | >= 0.4m | lead in glide |
| cam_glide_zoom_05 (zoom 0.5 s after the glider opens / before) | 1.18x | 1.18x | 1.12–1.25x | [spec] +15..25% boom in the air |
| cam_dive_zoom_hold (lowest zoom in a plunge / zoom at its start) | 0.85x (closed in) | 1.00x | >= 0.98x | the view stays open so you see where you'll land |
| cam_dive_land_view (ground under a plunge, screens below centre) | 0.18 | 0.18 | <= 0.3 | |
| cam_land_step / cam_land_left_05 (zoom-out lost in landing's first step / left at +0.5 s) | 0.04 / 0.29 | 0.04 / 0.29 | <= 0.1 / <= 0.35 | eases back, no pop; no lens change or shake (asserted) |
| view_across_m (Supervive preset, 16:9) | 28.0m | 23.5m (movefeel 23.0m) | 22–25m | camcal: ~17 hunter silhouettes across, as in gameplay frames |
| hunter_screen_pct (medium hunter, feet to head) | 5.4% | ~7% (movefeel 7.6%) | 6.4–7.6% | camcal: its silhouette ~10.5% of the height, as in gameplay frames |
| hunter_feet_below_pct (feet below screen centre) | 0% | ~4% | 1.5–5% | camcal: the view aims at the body |

Other checks:

- `--wallhug-check` (tools/wallhug_check.gd): 40 grabbable rims are hugged from the abyss side. There are 2400 tries over heights from 0.8m above to 4m below the lip, keys 0/45/65 degrees off straight into the wall, gliding or not, and touching the wall or a step off it falling at full speed. A try counts as caught only when it ends standing on top.
  - Main caught 2141 of 2400 (89.2%).
  - Movefeel catches 1578 of 1600 (98.6%) with the keys pushing in (0/45 degrees), target 95%.
  - Steering mostly along the wall (65 degrees) it catches 691 of 800 (86.4%), target 70%. The ledge rise follows your keys, so sliding along a short rim can carry you off its end. Before the rise reworked the mantle, the scripted mantle caught all 2400.
- `--wall-slide-check` (tools/wall_slide_check.gd, decision 0022): Sable, Vex and Kael run at 15, 45 and 75 degrees into a straight Hollow Crown cliff, three prop corners (a rock, a built wall, a camp crate) and a placed Tenzo rock off the grid, and ground-dash into the cliff, 1 s each against the same run on open ground. Targets [source]: the speed along the wall never under 90% of the reference's, and never more than 2 still steps in a row. Main failed 11 of 54 (every Tenzo-rock run: stopped 44-51 steps at 45/75 degrees; Sable's 45/75-degree dashes at 88%); now 0 of 54. In the air a dash into a wall is the wall bounce's, not this check's.
- `--dash-wall-check` (tools/dash_wall_check.gd, decision 0047): all 12 Hunters ground-dash from touching a straight Hollow Crown cliff, a Tenzo rock, a full-width Neve wall and a prop face at 20, 45 and 80 degrees to it. Target [game data, Unreal's slide along a surface]: the distance along the wall is cos(angle) of the same dash's length on open ground (94%, 71%, 17%), within 10%. Before, cliff dashes at 80 degrees kept 16-19% (the corner slip pushed them on; Dredge failed at 19%). Now all 132 shared-dash tries pass; Tenzo's Rock Hop (12 tries) lands short of a wall by design and only must not end in it. In the air the wall bounce still applies.
- `--mantle-check` (tools/mantle_check.gd): checks the ledge rise, steering and the fling, plus that ledges you don't push into never grab you (see below).
- `--aim-latency-check` (tools/aim_latency_check.gd): a scripted mouse move, then the frames until the reticle and the aim point sit under the cursor, at 60 and 144 Hz, at 720p and at 4K with a UI scale (see "Aim: the raw cursor").
- `--obstacle-check` (tools/obstacle_slide_check.gd, from branch `stuckfix`): walks round, away from and past every tree and rock cluster on the training map and an expedition island.
  - Main 3b800a0: a hunter hugging a 3-tile rock cluster on the expedition island is pinned on a corner for 823 steps (13.7s).
  - Movefeel (and `stuckfix`):
    - Expedition island: 31 of 31 laps clean, 853 of 853 walk-aways leave at once, 851 walk-pasts with 0.0000m pull.
    - Training map: all 20 clusters clean.

## What changed (all in clearly marked `(movefeel)` blocks)

- **Input to screen:** the local player is drawn at the present (`Hunter.render_pos`, `LOCAL_RENDER_LEAD`), extrapolated by the fraction of a step since the last one. Before, it was interpolated up to a step in the past, so a press showed a frame late and the camera trailed. Everyone else is still interpolated, and a teleport snaps.
- **Camera before the cursor:** each frame moves the view first (`MatchCam.update`, following where the last frame drew you), then reads the cursor, then steps the sim. A shot fired while the view moves (a dash, a knock, the skyship) leaves on the reticle as drawn; with the old order it trailed by one camera step (0.35 m at 15 m in a 10 m knock). The cost is one more frame of follow lag, about 0.1 m at a run. `--dash-aim-check` (steady rows) holds it to 0.25 m at 15 m for Vex, Lace, Sparkle and Neve.
- **Ground:** acceleration 70 → 90 m/s², deceleration 90 → 110 m/s².
- **Air:** steering 22/3 → 40/9 m/s², so letting go in a jump stops you. Speed above run speed (a dash, a pad, a knockback) still carries at 3 m/s².
- **Falls:** gravity x1.2 straight to a 10 m/s terminal speed, which matches the footage depth and tightens the jump arc. It replaces the slow 3.2/s ease to 9 m/s. The camera's soft vertical follow keeps falls from jolting the view.
- **Glider:**
  - Steering is `Loco.glide_step()`:
    - 420°/s at cruise, in wider arcs above cruise (down to 45%).
    - 16.25 m/s² toward where you steer ([game data] GlideTargetXYForce 162,500 / Mass 100, `HunterMove.glide_accel`, decision 0027): a 90° turn ~0.38 s, a reversal ~0.6 s at cruise. Over-speed bleeds back (tuning.json glide.drag).
    - Steering more than 115° against your heading brakes at 36 m/s². Letting go drifts.
  - Cruise 5.0 → 6.5 m/s and sink 2.2 → 1.4 m/s. The owner found the glide "falls a bit faster and feels weaker than SUPERVIVE".
  - The glider opens falling at least 0.85 m/s ([game data] GlideStartFallSpeedMin, `Loco.glide_start`, match and farm): a rising jump is cut at the open, no float-up, and the jump pad's own 2 m/s cap went with it. The canopy then catches a fall at 60 m/s² (ours: the source's matching fastest-fall clamp is locked; [guide] it opens "instantly").
  - Space opens the glider after 0.1s (a tap is a jump). The glide button (Mouse 5) opens it at once (`inp.glide_btn`, local input only).
  - The canopy catches a fall at 60 m/s² (was 16).
  - Space opens the glider only on a second press in the air (`Hunter.jump`), and holding it keeps the glider open; holding Space from the jump, or while doing anything else (Albert's held swing), never glides (owner 11-08, decision 0058). The glide button (Mouse 5) opens it at once (`inp.glide_btn`, local input only). Bots and the tutorial drive press jump again to open it.
  - **Dive** (`GlideDive`, `HunterMove.dive_*`, all [game data]): hold crouch (Ctrl) under an open glider and the canopy folds into a plunge toward 32.5 m/s at 35 m/s², the keys steering at a quarter of their glide force. Let go, come within 3.5 m of the ground (or the island's lip over the abyss) or hold for 10 s and the glide catches you again; the drop you pull out of becomes speed, capped at the glide's 15 m/s max. The key is ours: the source names no dive input, and Space is the glider itself. The folded pose is local-only (the dive isn't in the net snapshot).
  - **Dive camera** (`CamRig.air_zoom`): the plunge holds the view at least as open as it was, where height alone would close it in as you drop (1.82 → 1.70 mid-plunge before). Landing eases back as from any glide (2.5/s; 1.65 → 1.18 at +0.5 s → 1.01 at +1.5 s). Strip: `--glide-cam-shots`.
  - **Dive** (`GlideDive`, `HunterMove.dive_*`, all [game data]): hold crouch (Ctrl) under an open glider and the canopy folds into a plunge toward 32.5 m/s at 35 m/s², the keys steering at a quarter of their glide force. Let go, come within 3.5 m of the ground (or the island's lip over the abyss) or hold for 10 s and the glide catches you again; the drop you pull out of becomes speed, capped at the glide's 15 m/s max. Held to the ground, the catch is sized to the cancel height (`GlideDive.catch_rate`), so you land at the glide's sink with no hard-land beat, as the source's glide holds you from the cancel distance; its own catch constant is in the encrypted code. The key is ours: the source names no dive input, and Space is the glider itself. The folded pose is local-only (the dive isn't in the net snapshot).
  - The abyss lift's brake zone rises at 3.5 m/s per metre left (was 2). Updrafts grab at 45 m/s² (was 30).
- **Heat** (owner, Nov 2: "lasts too long, not punishing enough"): a level glide overheats after 9s (was 14). Hits heat it 3x (was 2x). An overheated glider burns ~3.5% of max health a second in 20-damage ticks, flies at 0.5x speed and sinks at 5 m/s.
- **Feathering** [est] (tap the glider on and off instead of holding it). Constants: `FEATHER_*`, `lift_t`, `glide_off_t`.
  - Open and close are instant, with no penalty for rapid toggles. The glider reopens with 5% of its heat room left (was 15%).
  - While the glider is closed in the air its heat cools at 0.04 per second (was 0.06) (a full glider is 1.0). The ground still cools it fastest: [footage] "it only really cools on the ground".
  - For 0.6s after you let go you keep the glide's speed and steering.
  - The first 0.3s of an abyss lift (the "rapid upward impulse" [wiki]) heats at 0.4x a level glide (was 1x; lowered with the shorter glider so feathering still beats holding). Holding the lift past that costs the full 4x. So short lift taps that coast on the impulse are the skilled, efficient way across.
  - Unconfirmed: what SUPERVIVE's feathering exactly does. Public pages don't describe it. These numbers are ours, to be checked against the owner's Nidhogg reference video.
- **Jump out of a dash** (`Loco.dash_jump_keep`, tuning.json `dash.jump_keep`, 0.75): the dash ends and the jump carries 75% of its speed, the rest is air drag's; the farm does the same (it used to keep the whole dash, the match 55%: a one-step 45% stop). A Shift's speed is `Loco.dash_hv` in both places (the per-hunter ease too).
- **Dash into glide** (owner 11-08, `Hunter._dash_into_glide`, docs/decisions/0022): a fresh glide press (second Space, or the glide button) at any moment of an air Shift dash ends the dash that step and the glide carries the dash's velocity exactly. No handoff boost: the glide's drag (`Loco.glide_step`) bleeds it back toward cruise within ~1.5 s, faster above the hunter's `glide_carry` cap (content/rules/tuning.json). A kit's rush or special movement (`move_kind` other than "dash") is not cancelled; `--air-control-check` tries every Hunter's own air Shift and FLAGS the ones a press doesn't cancel (Motley's). A kit that ends its dash with a stop skips it when the glide took over (Vex's air slide). The boost trail and whoosh still play when the glide starts well above cruise.
- **Casting at the top of a jump:** per Hunter and slot (LMB, RMB, E, R) in docs/heroes/dash_interactions.md ("Cast at the top of a jump", rows in `content/dash_flow/<id>.json` `air_cast`, asserted by `--air-cast-check`). 35 of 48 go off in the air and keep the jump: air steering and the fall go on. Meeko's Burrseed waits for the landing; Tenzo's Stone Row and Motley's E and R are not cast in the air. The other 9 stop, hover, rise or slam as their row says. The source settles only a few: Kael's air slam onto the cursor disc, Sparkle's straight-up Kitefall, Neve's rooted Rimelock (horizontal), and Grimble's hand (owner 11-10). Those match; the rest are [?].
- **Space in a dash, Shift in a jump's rise, both on one step:** per Hunter in docs/heroes/dash_interactions.md ("Space and Shift together", rows in `content/dash_flow/<id>.json` `dash_jump`, asserted by `--dash-jump-check`). The source settles only Shift in the rise (Shiv, Elluna: the air dash goes at once, flat), which ours matches; the rest are [?].
- **Dash into glide** (`glide_handoff(dir, speed)`, `_take_glide_handoff()`):
  - The Shift dash's end and a jump out of a dash register the burst. If the glider opens within 0.3s, heading within about 70° of the burst, it starts at 60% of the burst's speed (max 14 m/s). That speed bleeds off slowly.
  - The burst reads clearly: a loud whoosh, a burst of air, a dense streak trail with afterimages while you stay well above cruise, and a brief camera pull-back (`CamRig.pull_back`).
  - **Archetype dashes:** call `glide_handoff(dir, speed)` as the dash ends.
- **Ledge rise** (replaces the scripted mantle; `Hunter._ledge_rise`, `_ledge_fling`, `lfloat`). This follows the owner's description of SUPERVIVE.
  - When it starts: you're below a ledge in the air and your keys push into it (within about 60 degrees of straight in; over the abyss below a lip, about 78 degrees). You gain upward momentum and float up the face. No climb animation sets your position.
  - Steering: your keys steer the whole way (ordinary air steering). Nothing holds you to the face except the wall itself.
  - Letting go: moving 0.9m out from the face, a dash, a fresh glide press, a stun or a knock ends the rise.
  - Over the top with no jump: a small pop (`LRISE_POP` 2.6 m/s), carried toward your keys.
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
  - Follow across: locked (was 8, then 15 per second). The view moves with you, so no dash, pull, swap or knockback leaves you off centre: `--camera-fast-check` logs your screen offset per frame through every hero's dash, the Wirerun (40 m/s), the Warchain self-pull, an Abyssal Hand reel, a 10 m knockback and the sky train pulling out, and fails over 8% of the screen's height or a 3% single-frame jump (before the lock: 8-15% on the fast dashes, 58% at the swap's teleport). Up and down still follows softly (3.5 per second). Recording mode keeps its own slower trail.
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
- **Camera framing vs the source (parity pass, 2026-11-09, now `--camera-frame-check`):** sources are the hero-ref sheets' 1080p measures [F] (no frames on the box that wrote this, so their numbers, not new pixels), camcal above [F] and the game data [D]. Numbers live in `content/rules/camera.json`.

  | Measure | Source | Ours before | Ours now |
  |---|---|---|---|
  | Pitch | 65.5° ±1.5 [F camcal]; Ghost's nuke disc 153x135 px (0.88) fits it a few degrees above the centre | 66° | 66° (inside) |
  | Horizon, roll | none on screen (the top edge looks ~50° down), never rolls [F] | same | same |
  | Vertical lens | ~32° (25–34) [F camcal] | 32° | 32° (inside) |
  | Ground across 16:9 | ~37 m: Void's 3.5 m Black Hole [D] reads ~2 bh (90 px) and run pans of 205–250 px/s at the data's 4.4–4.8 m/s [D] both give ~51 px/m | 23.5 m | 23.5 m (narrower) |
  | Hunter height on screen | mediums 90–100 px of 1080 (8.3–9.3%), Oath 107 px, Elluna 67 px [F] | 3.8–11.1% by Hunter (gunslinger 6.0, bulwark 11.1, tender 3.8), median ~1.3x smaller than the source's | same |
  | Feet below the centre | ~3–4% [F camcal] | 3.0% on level ground | 3.5% (`rise` 1.0 -> 1.2 m) |
  | Cursor lean, how far | not measurable in the sheets: the view sits still through 1–2 bh moves and pans with the aim (venator) | 42% past 1.4 m, cap 7.5 m; at sneak zoom a full lean up-screen put you at the bottom edge | none: measured from the clips, "Camera lead" below (ext/feel-camera-lead) |
  | Cursor lean, how fast | not measurable [F]; a blink dash takes ~0.5 s to catch up (dredge) | eased 6/s; follow 15/s | unchanged |
  | Glide / drop zoom | only ability zoom-outs (Vireo's R, Oath's ult) [F]; data names an abyss zoom, no value [D] | glide 1.25x, drop 1.05–1.7x, sneak 1.45x | unchanged |
  | `CameraDistance` 5500 uu [D] | 55 m, meaning unproven (the ADS row is a fog-of-war radius); as an arm length it would need a ~21° lens, against the footage's ~32° | not used | not used |

  - Not matched: the distance. The source shows ~1.6x more ground across and draws its Hunters ~1.3x bigger: its Hunters are about twice the size of the world ours are, which no camera can match. 36 m back would show the source's ground but shrink tender to ~2.5% of the screen (the owner wants silhouettes that read at gameplay zoom); 18 m would match the Hunters' size on half the source's view. 23 m sits between the two, so it stays. Matching both means drawing Hunters larger (`Hunter.VIS_SCALE`), a model call for the owner (docs/DEBT.md).
  - GPU pair (`--cam-framing-shots`, since replaced by `--camera-frame-shots`, 1280x720): before job 20261109-101651-10739 (origin/main), after 20261109-101658-27648, `out/framing_*.png`. The default view moves 4 px (feet 381 -> 385). Sneaking with the cursor on the top edge, the lean stops at 7.8 m instead of 8.1 m, so you sit 55 px above the bottom edge instead of 45.
- **Camera frame per aspect (2026-11-11, `--camera-frame-check`):** what the Supervive style shows of level ground around your feet, on each screen shape. Sources: the 16:9 source column is the framing table above solved for the ground (pitch 65.5°, lens 32°, ~37 m across at your feet, so ~36 m from the camera, feet 3-5% below the centre [F]); the source's other aspects are inferred [E]: its footage is all 16:9, its engine keeps the horizontal lens by default, and players reported no ultrawide view (a Steam thread, 2024-10), so every screen shows the 16:9 width. The numbers are in `content/rules/camera.json` (`styles`, `frame_aspect`, the `source` bands).

  | Measure | Source 16:9 | Ours before 16:9 / 21:9 / 4:3 | Ours after 16:9 / 21:9 / 4:3 | Source 21:9 / 4:3 [E] |
  |---|---|---|---|---|
  | Camera height above your feet | ~33 m | 22.2 m (all) | 22.2 m (all) | ~33 m |
  | Pitch | 65.5° ±1.5 | 66° | 66° | 65.5° |
  | Vertical lens | ~32° | 32° / 32° / 32° | 32° / 24.6° / 41.8° | 24.6° / 41.8° |
  | Ground ahead (to the top edge) | ~14.2 m | 9.3 / 9.3 / 9.3 m | 9.3 / 7.0 / 12.8 m | ~10.7 / ~19.6 m |
  | Ground behind (to the bottom edge) | ~9.3 m | 6.2 / 6.2 / 6.2 m | 6.2 / 4.8 / 8.2 m | ~7.1 / ~12.2 m |
  | Ground to each side, at your feet | ~18.5 m | 12.3 / 16.1 / 9.2 m | 12.3 / 12.3 / 12.3 m | ~18.5 / ~18.5 m |
  | Ahead per behind | 1.46-1.62 | 1.49 | 1.49 | same |
  | Side per ahead | 1.25-1.35 | 1.32 | 1.32 | — |

  - Fixed: the screen's shape. Godot keeps the vertical lens, so a 21:9 screen showed 31% more ground to each side than 16:9 and a 4:3 one 25% less. `CamRig.frame_fov` now sets the lens each frame so every screen shows the 16:9 frame's width (`frame_aspect` 1.7778; the style's `fov` is the lens on that screen, kept as `CamRig.lens`): 21:9 sees less ahead and behind, 4:3 more. Windowed and full screen differ only by shape: a 1280x720 window, 1920x1080 and 3840x2160 frame the same metres, and a maximised window under a title bar (1920x1017) is a slightly wider shape (8.7 m ahead). Only the shape counts: `frame_fov` reads the view's width over its height.
  - The shape matches the source (ahead per behind, side per ahead inside its bands); the scale does not: ours shows 0.66x the source's metres every way, the distance left open in the table above (docs/DEBT.md, an owner call on Hunter size). Kept as it was: the cursor lean (none, below), the glide camera, the cast view (its room follows the live lens).
  - `--camera-frame-check` asserts it on ten views (16:9 at 1280x720, 1920x1080, 3840x2160 and 1920x1017; 16:10; 21:9 at 2560x1080, 3440x1440, 1680x720; 4:3 at 1600x1200, 1024x768): the 16:9 side metres within 0.5% everywhere, less ahead on wider shapes and more on narrower ones, the same shape framing the same metres at any size, your feet and head inside the screen; and the 16:9 pitch, lens, feet and ground shape inside the source's bands. `--move-feel-check`'s framing rows now read shares of a 16:9 screen's height (the headless view is square, so its lens is wider).
  - GPU pair (`--camera-frame-shots`, one 720 px-tall window per shape; `--frame-before` keeps the lens at every shape, the rule before this change): before jobq 20261111-053358-15138 (rp1-0), after 20261111-053415-04484 (pc-MRROBOTO, gl_compatibility, so the light differs), `out/frame_16x9|21x9|4x3.png`. The 4:3 window came out 1240x930 (the window's minimum width), still 4:3.
  - Not taken: black bars at 21:9 (the 16:9 picture, with as much ahead as 16:9). Fairer to ultrawide players, but nothing shows the source draws them, and it needs a letterbox under the HUD.
- **Camera lead (measured, Nov 2026):** the Supervive follow used to lean toward the cursor (42% of its distance from you after a
  1.4 m deadzone, capped at 7.5 m). Nobody had checked that against the source, so it was measured from the reference clips in
  `/home/boki/refs/supervive-mantle/` (hetzner): the cursor ring and the player's own health bar were tracked per frame, and the
  ground's shift between frames read by phase correlation of the HUD-free centre of the picture.
  - `sv_every_ability.mp4` (training ground, 1080p60): a cursor flick with the hunter standing moves the view by nothing. At
    252.27 s (frame 15136) the cursor jumps 116 px of 480 (a quarter of the screen) and the ground shifts under 1 px over the next
    4 s; at 293.53 s a 108 px flick gives 5 px; the flicks at 218.2, 220.3, 221.8, 247.6, 248.4, 249.1, 284.0, 285.2, 288.4 and
    301.0 s all give 0-2 px. The hunter sits a fixed ~5% of the height below the centre whatever the cursor does.
  - `sv_joule_1v4.mp4` (a fight, 1080p60): over the 1173 frames where both the bar and the cursor read, the hunter's screen offset
    against the cursor's has a slope of -0.03 px/px (r = -0.1): no lean. From 2.0 to 4.25 s the cursor flips between (-240, +50)
    and (+296, -130) px of 960x540 while the hunter stays at (-100 +-10, -30).
  - `owner_mantle_clip.mp4` (a streamer's clip, webcam overlays): too noisy to read (weak slopes of -0.1 and -0.24), not used.
  - So **the view stays on the hunter wherever the cursor is**: the Supervive row of `content/rules/camera.json` "follow" has a 0 m pan and there is no ease to time.
    The lean survives as the Standard and Fully dynamic follow presets, which model the source's own camera options (deadzone,
    maxzone, pan distance, quadratic easing; a Supervive guide recommends 0.5 / 0.8 / 100% on Fully dynamic).
  - Dashes: the view trails and eases, never cuts. In the 1v4 clip at 4.37-4.80 s the hunter crosses 105 px (11% of the width)
    while the ground moves at most 8.5 px per frame; the dredge sheet (frames 0187-0188, 493.2-493.8 s) saw ~0.5 s to catch up
    on a blink dash. Ours trails a dash by ~0.55 m and is back to the running lag 0.5 s in (`--cam-lead-check`); a slower,
    dash-only catch-up like the source's 0.4-0.5 s is not built (the tight 15/s follow is what keeps `cam_lag_m` under 0.4 m).
  - Knocks and glides: no clean sample in these clips. With no cursor lean there is nothing to hold or recentre.
  - `--cam-lead-check` asserts it in an expedition and in the Training Grounds: the lean with the cursor at the screen's edge is
    under 0.35 m (the footage's noise floor, 1.5% of the view), the view drifts under 5 cm in the second after a flick, and a dash
    moves it under 0.5 m in any frame, trails, and is back within 0.5 s. `--cam-lead-shots` holds the cursor at the right edge for
    a review frame (GPU).
- **Settings:**
  - "Expedition camera" is now "Camera".
  - The style and follow mode also apply at home (`CamRig.apply_settings`). The farm keeps its own wider framing (`Home._apply_cam_settings`).

## Move pass: wall moves, ledges that answer, a springier abyss (`--wallmove-check`)

- **Wall kick / wall dance** (`WallMoves`, every hunter; item 149, the SUPERVIVE wall dance): touching or facing a wall (your keys, else your aim), every jump press hops you off it: no limit, no cooldown, no glider, and a stone scuff with a varied pitch that everyone nearby hears (online too: the "fx" "whop" event). Keys into the wall or none add `KICK_RISE` 0.8m to the jump you are on; keys away push you off at 7.5 m/s. A hop only starts up to `HOP_CLIMB_CAP` 1.6m over your take-off ground, so you can dance at a wall indefinitely, jump + kick + mantle (1.5m) tops 4 terraces (3.2m, the Cinder Steps plateau), and 5 terraces (4.0m) stay sheer. Near a wall a capped press does nothing rather than open the glider (the glide button or a held glide still does). The glider stays shut until each hop's rise ends.
- **Wall bounce** (`WallMoves`): an airborne dash or boosted jump that hits a wall more than 20 degrees off its normal and at least 4 m/s into it reflects about the normal, keeping 85% of the speed. Your keys steer the rebound for 0.25s at 25 m/s^2. Head-on it stops as before. Ground dashes, shoves and charges, walls low enough to mantle, knockbacks and slow jumps don't bounce. Dust, a spark and the landing thud mark it.
- **Glider on a wall** (`WallMoves.stopped`, decision 0023): a glider never bounces or stops dead on a cliff face, a ruin wall or a Tenzo rock. [game data] SUPERVIVE glides on UE's CharacterMovementComponent, whose wall hit slides: the part of the speed into the wall is dropped, the part along it kept, and the canopy stays open; the glide force then holds the slide at cruise x sin(angle off the normal) while your keys push into it (0, 30, 60 degrees in `--move-feel-check`, rows `glide_wall_*`). [?] No glide-wall row in the physics dump and no footage of one.
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

## Wall kick and wall bounce for every Hunter (`--wallmove-check`, `tools/wallmove_hunters_check.gd`)

DECISIONS 11-07 "Movement and combat feel": wall kick and wall bounce for everyone, every interaction chainable. The check puts each of the 12 Hunters in the Training Area's strip beside a 16 m wall and tries both moves: from a run, from a jump, out of the ground dash, out of the air dash, and in the air 0.05 / 0.2 / 0.45 / 0.8 s after LMB, RMB, E, X and Shift (each tapped and held; the held RMB sets `sec_hold`). A case counts only when the body is still at the wall (or reached it at 4 m/s into it); a kit move that took it off the wall, down to the ground or head-on into it is "n/a", not a block.

| Move | Result for all 12 Hunters |
|---|---|
| Kick from a run, a jump, the ground dash, the air dash | works |
| Kick after LMB, RMB, E, X, Shift (tap and hold), 0.05-0.8 s | works; no ability keeps the jump from the wall (`do_jump` only refuses stun, a grapple, Grounded, `cast_locked` and a ledge rise, and no kit holds those at the wall) |
| Bounce after the same buttons | works wherever the hit is angled and at 4 m/s |
| Bounce out of the ground dash | **was blocked for Kael** (fixed, below); the rest bounce |

**Fixed:** Kael's dash is a shove (`dash.shove`) and `Hunter.shove` stays set after the dash ends, so a jump out of it never bounced (`WallMoves.hit` refused while `shove` was non-empty). The refusal now applies only while the dash runs (`roll_t > 0`), which is what it was for: a ram doesn't rebound off the wall it hits. `--wallmove-check` fails on the old line (juggernaut, bounce:dash).

**Commits (the kit owns the body, so no kick or bounce; sources):**
- Motley's Lantern Trade (Shift): while the lantern flies (1.8 s) he hovers in place and a jump press does nothing: "owner dash note (Nov 2)", `docs/heroes/ostra.md`. Not a wall problem, so no change.
- The probe's n/a cases (not blocks): Tenzo's RMB in the air is a slam that lands him; Kael's RMB (lunge, meteor) and E (Warchain) and Dredge's and Vex's E move the body off the wall or down. The move is the point of the button, so nothing was changed for them.

**Open (not fixed, no source or owner line decides it):** Claire's rink skate (E held, X): the skate steers her at the wall head-on (hit within 16 degrees of the normal), so an angled bounce never shows. In `COMMITS` of the check until someone decides the skate should rebound. The case would need her skate heading to come from the keys, not the aim.

**Suggestion (not built, parity):** a run is 4.4-4.9 m/s, so a plain run-and-jump bounces only when it meets the wall between 20 and about 26-35 degrees off the normal (`BOUNCE_MIN_INTO` 4 m/s and `BOUNCE_HEAD_ON_DEG` 20 are our estimates, no source number). Tenzo's and Claire's runs didn't bounce at 25 degrees (they are slowest in the air). If the source bounces off a walking jump, drop `BOUNCE_MIN_INTO` to about 3 m/s.

## Physics pass: SUPERVIVE's game data (`physics76`)

Tunables are in `content/rules/hunter_move.json` (`physics`), read by `HunterMove`; values and sources are in SUPERVIVE_DATA.md.

- **Gravity** 30 (x1.2 falling) → 14.7 m/s², one gravity. **Jump** 9 → 6.8 m/s (the data's 7.5 would let jump + mantle top four terraces). **Wall kick** rise 0.9 → 0.8m, so jump + kick + mantle still tops 4 terraces and not 5.
- **Fall cap** 10 → 12 m/s, easing to 10 m/s from 1m to 16.5m under the lip. **Point of no return** 13 → 17.5m under the lip: about 1.9s of falling to save yourself (was ~1.4s).
- **Air control** (`Loco.air_step`, owner 11-08: the data's low AirControl is overruled): WASD adds 32 m/s^2 onto what you carry, 2.5x that against your drift (a 5 m/s backward drift turns forward in ~0.07 s), never past your run speed along the keys; speed above it (dash, knock) bleeds at 2/s. The farm uses the same step. Numbers in content/rules/tuning.json `air`.
- **Glide height hold** (`GlideLift.sink`): more than 8.5m over the ground (or the lip) the glider sinks at 3.5 m/s. The drop never becomes speed (owner 11-08 item 8).
- **Mantle**: topping out sends you onto the ledge at max(0.6x run speed, 3.5 m/s). The no-jump pop is 2.6 m/s (was 3.2; lower gravity floated it twice as long).
- **Holding Space never opens the glider** (owner 11-08, said twice). With a player's keys (`inp.glide_press_only`, set in `Match`) the glider opens only from a fresh press in the air: a second Space press (`Hunter.do_jump`) or the glide button's press, or a pad/updraft auto-glide. Opening the glider uses the press up (owner 11-09): once it folds (a heal, a dash, a knock, a kit's wind-down) it stays shut while Space is still held, until a new press. A press while a move or cast keeps the glider shut (`_glide_armed`) opens it as the move ends, if still held; letting go or landing clears it. Space held from the jump, or while LMB/RMB/abilities are held (Kael's RMB, Lace's and Albert's LMB; Albert's perfect launch no longer opens it by itself off a drop), never opens it. Every Hunter's air Shift takes a press during or after it, except Sparkle's wire (her keys do nothing while it holds). Scripted input (bots, checks, demos) keeps the old hold-to-open (`GLIDE_ENGAGE`). Home islands follow the same rule. Measured by `--glide-hold-check`. The earlier tap/hold split only added the second-press route next to the hold route and then shortened the hold wait (0.15 -> 0.1 s), so it never went away.
- **Air control** (`HunterMove.air_steer`): keys steer at 0.3x your ground acceleration and carried speed bleeds at 0.375/s. The data's 0.015 felt like dropped input top-down. A ledge rise keeps the old crisp air steering.
- **Glide height hold** (`GlideLift.sink`): more than 8.5m over the ground (or the lip) the glider sinks at 3.5 m/s, and 2.5x the drop past its usual sink becomes glide speed, fading over 1.5s.
- **Mantle**: over the lip you keep max(0.6x the speed you came in with, 3.5 m/s), held 0.75 s in the air (`MantleCarry`, item 185b; `physics.mantle_launch_*`). The no-jump pop is 2.6 m/s (was 3.2; lower gravity floated it twice as long). Timing and reach per ledge height: "Ledge mantle timing" below.
- **Glider at any heat, softer deep lift** (owner item 63): the glide input opens the glider at every heat, overheated or not (no heat floor, no lockout after an overheated one closes); overheated it burns you and lifts at half strength. The deepest lift is 30% softer (climb cap 26 -> 18.2 m/s; speed per metre of depth 1.7 -> 1.1) at the same heat cost. Measured by `--glider-heat-check`.
- **Heat on the canopy** (`GliderHeat`): the glider cloth warms toward ember with heat, an overheated glider trails a thin smoke, and one burning over the abyss at half strength flickers, so teammates and enemies read a gliding Hunter's heat from the world. Two toon-shader parameters (`canopy_heat`, `canopy_burn`) on the canopy's own material: no extra draw calls, no burst on open or close. The heat (4 bits, 15 = overheated) and the burn state ride the hunter flags (bits 19-23); no Net shape change. Measured by `--glider-canopy-check`; shots by `--glider-canopy-shots`.
- **Abyss bounce** [est]: the lift reaches the lip at 4.5 m/s (was 3.5), floating ~1.6m over it.
- **Step height** (`physics.step_height`, `World.STEP`): 0.32 → 0.45 m, the tallest lip a hunter on the ground walks straight over [game data: MaxStepHeight is not overridden, so Unreal's 45 uu default stands]. The walk-over is now eased like the terrace step (`step_vis`, with the render lead held off the rise) instead of snapping the model; stairs, whose ground rises smoothly, are left alone. `--step-up-check` (`tools/step_up_check.gd`) runs Sable, Vex and Albert at lips of 0.10 to 0.60 m and at a terrace, head-on and at 45 degrees: every lip is walked over, and no frame moves the body or the camera more than half the lip.
- **Feathering**: the glider no longer cools in the air, and a lift's first 0.3s heats like a level glide (was 0.4x). The slower gravity had made coasting between taps so cheap that feathering went 4.8x as far as holding; it is 2.0x now.

## Hits on the glider (`--glide-hit-check`, decision 0055; PARITY FIRST)

Asked: what happens to a Hunter under the glider who is shot, knocked, stunned or pulled, and when they can open it again. Evidence read: `docs/SUPERVIVE_DATA.md` sections 4 (crowd control) and 5 (glider rules at 1.0), the 1.0 rules in `docs/KINFALL_CLASSES.md`, the wiki notes in `docs/SUPERVIVE_FEEL.md`, `supervive_physics.md` (only the names `GliderHeatInboundDamageCoefficient` and `GliderFullHeatInboundDamageCoefficient`, no values), sync64 in `docs/ROADMAP.md`, and the hero-ref footage sheets. None of the footage shows a glider being hit, so the rows below come from the data.

| Case | Source | Glider | Reopen | Ours (measured) |
|---|---|---|---|---|
| Shot, heat left | 1.0: a hit doesn't knock you out of the air, you take normal damage, it heats the glider (sync64: 3x) | stays open, extra heat | never shut | a 10 shot: 0.261 heat (`Hunter.GLIDER_HIT_HEAT`), 10 damage, still open 0.5 s later; heat then builds 2x for 1 s (`hit_heat_t`, [est]) |
| Shot that fills the heat, or any shot on an overheated glider | 1.0: "damage that pushes heat to 100%: instant spike"; a spike is stun + plummet, 0.7 s stun over ground [wiki] | shut, plummets with the body | not in the air: on landing, after the 0.7 s stun (`glide_cd` 2.5 s [est] still runs into the next jump) | shut, -6 m/s, lands stunned 0.70 s |
| A monster's shot | 1.0: "Monsters can't spike" | stays open, extra heat | never shut | heat stops at 2% |
| Knocked (a shove, no stun) | 1.0: damage doesn't knock you out of the air; Knockback: "you can steer it" (you keep control) | stays open, shoved with the body | never shut | **changed:** a shove over 4 m/s used to fold it for 0.4 s. A 12 m/s knock now keeps it open and carries it 5.3 m in 0.5 s; WASD bends it as on foot (`knock_steer`); only the knock's damage heats it |
| Stunned | Stun: "no movement, no air control, no abilities" | shut at once, falls with the body | a fresh press, the step the stun ends | shut, -4.6 m/s after 0.2 s, opens on the first press after |
| Pulled by Grimble's arm | the target is stunned for the whole pull | shut (the stun row) | after the reel and its stun | as the stun row |
| Pulled or pushed by any other move (Cinder's cloak, Neve's carry, Ostra's draw, Mossy's push, Sparkle's slide) | not in the data or the footage | open stays open unless the move stuns | | not changed, not asserted |

Kept: holding Space never opens the glider (DECISIONS 11-08; every reopen above is a fresh press), and an overheated glider still lifts out of the abyss at half strength (`--abyss-check`, `--glider-heat-check`). A glider that is still shut waits out a hard knock (0.4 s, [est]) before it opens. Still open for the owner: the older wiki note "most hits on a glider deal double damage" (ours keeps 1.0's normal damage), and "spiking a below-ground glider" (a hit on the balloon under the lip, at any heat; ours spikes only when the heat runs out).
## Ledge mantle timing (`--move-feel-check` ledge rows)

Settled against the source, PARITY FIRST (briefs/DECISIONS.md 2026-11-07): briefs/supervive-data/MANTLE_185b.md, supervive_physics.md and the owner's clips. [?] marks what neither the data nor the footage settles; nothing there is guessed.

| Question | Source | Ours | Status |
|---|---|---|---|
| How long a climb takes | [footage] owner_mantle_clip 18.3 to 18.5 s (dash in from the abyss) and sv_joule_1v4 9.20 to 9.27 s (glide onto a low rim): rim to standing in ~0.1 to 0.2 s, no pause, no pose. [game data] MantleSuctionUpwardsForceZSpeedCap 2.5 m/s caps the suction's lift, not the pull-up: MantleZImpulseMin/Max and MantleLaunchDelay are C++ defaults the data doesn't store, so the rise per metre is [?] | the rise runs at up to `LRISE_SPEED` 14 m/s and never under 4 m/s (hunter.gd); catch to top is 0.13 s (1.6 m) and 0.18 s (2.4 m) from a running jump, 0.10 s from a glide at every height | matches the footage; the per-height curve is [?] in the data |
| Highest rise from a walk | [game data] stores no MaxStepHeight for the hero (a C++ default) [?]; the 1.5 m bot nav step is the pathing agent, not the walk; bCanWalkOffLedges false only says you don't stroll off. No walk-up in the footage | one terrace (0.8 m) is a ramp (LAYOUT_RULES); 1.6 m and up never climb from a walk (`Hunter._try_ledge_grab`: walking into a wall doesn't climb it, jump and you mantle at the top) | source [?]; ours kept |
| Highest rise from a jump | [game data] JumpZVelocity 7.5 m/s (apex 1.91 m) plus MantleSuctionUpwardsForceHeightMax 1.5 m: about 3.4 m | `JUMP_V` 6.8 (apex ~1.5 m) plus `MANTLE_REACH` 1.5: 1.6 and 2.4 m top, 3.2 m (four terraces, the wall tier) never; `--cliff-mantle-check` asserts the four-terrace miss | deliberately lower (the jump decision in the Physics pass; LAYOUT_RULES' wall tier) |
| Highest rise from a glide | [game data] the same 1.5 m below the top from any glide height (the 8.5 m hold): faces to ~10 m | any airborne state catches a top within `MANTLE_REACH` 1.5 m; 3.2 m tops from a glide | match |
| Speed you leave with | [game data] max(0.6x the approach, 3.5 m/s) (MiniMantleXYSpeedTargetCoefficient / Min), held 0.75 s (MiniMantlePostLaunchDuration); how firmly it's held (MiniMantleForwardForceSpeedDeltaMultiplier 8) is a force we don't model [?] | `MantleCarry.exit`: the same floor (`physics.mantle_launch_keep` 0.6, `mantle_launch_min` 3.5), held firm 0.75 s, never above the approach speed or run speed (that cap is ours [?]) | match |
| Walking off ledges | bCanWalkOffLedges false | always allowed | owner rule, kept |
| Ledges answer at once | [footage] no pause at the face | the catch is the first step you push into the face within reach | kept |

Three ledge heights x walk / jump / glide, keys into the face (`_ledge_matrix`; one terrace is left out because it's walked up):

| Ledge | Walk | Running jump | Glide in at 5 m/s |
|---|---|---|---|
| 1.6 m (two terraces) | never climbs | tops; catch to top 0.133 s; in 4.42, over the lip 4.55 m/s | tops; 0.100 s; in 5.00, over the lip 4.60 m/s |
| 2.4 m (three) | never climbs | tops; 0.183 s; in 4.40, over the lip 4.51 m/s | tops; 0.100 s; in 5.00, over the lip 4.60 m/s |
| 3.2 m (four, the wall tier) | never climbs | never (by design) | tops; 0.100 s; in 5.00, over the lip 4.60 m/s |

Asserted: each cell tops or not as above; a caught ledge's catch-to-top <= 0.35 s ([footage] ~0.2 s rim to top); over the lip >= max(0.6x in, 3.5 m/s) ([game data]). Rows this pass fixed, each with its source: `hunter_move.json` now says mantle_launch_keep is a share of the approach speed, not the run speed (MANTLE_185b: "the approach speed was thrown away"); `MantleCarry` lost its own copy of that 0.6; this doc's no-jump pop read 3.2 m/s where `LRISE_POP` is 2.6; the Physics pass line and docs/SUPERVIVE_FEEL.md's Mantle row said the launch was 0.6x run speed.
## Slow and haste ramp (`--move-feel-check` slow_* / haste_* rows; docs/decisions/0022)

The source has no ramp time: a Slow or a speed boost moves the speed cap at once, and the body follows it under the ordinary movement, down at the walking brake (BrakingDecelerationWalking 22.2 m/s² plus GroundFriction 1 × 2 per second of speed) and up at MaxAcceleration (47-54 m/s²). A 30% Slow on a run settles in about 0.05 s either way. Ours: every Slow (`slow_t`/`slow_k`, from kits, hazards, Boki and merges) and every haste (`haste_t`, the kits' `pace()`, a `move_speed` buff) multiplies into the one cap in `Hunter._physics`, and the ground step follows it with `ground_accel` up and `HunterMove.cap_brake` down. The check runs one kit per weight class (thief, gunslinger, juggernaut) and the haste on the medium kit.

| Key | Measured | Target | Source |
|---|---|---|---|
| slow_land_0p1s / 0p3s (speed over the run before it) | 0.70 / 0.70 | 0.69–0.71 | [game data] the brake: ~0.05 s |
| slow_end_0p1s / 0p3s | 1.00 / 1.00 | 0.99–1.01 | [game data] MaxAcceleration: ~0.03 s |
| haste_land_0p1s (over the hasted run) | 1.00 | 0.99–1.01 | [game data] as a Slow ends |
| haste_end_0p1s (over the plain run) | 1.00 | 0.99–1.01 | [game data] as a Slow lands |
## Jump pads and updrafts (`PadFlight`, `--pad-check`; decision 0024)
- **A pad is a throw, not a rail:** 17 m/s up [est] under the source's 14.7 m/s² (apex 9.8 m at 1.16 s), aimed
  so the arc alone would come down on the pad's landing and clearing a higher landing's lip by 2 m. The keys
  barely steer the rise (`air_control` 0.015, the data's value). Map pads and the pocket Spring pad share it.
- **The glider opens by itself at the apex** (DECISIONS: the exception to "a held Space never opens the glider"),
  keeps the launch's speed and steers as any glide. A hands-off glide (or a bot) is carried onto the landing and
  folded over it, as a lair's escape updraft does; a fresh glide press makes it your own glide.
- **Updrafts open the glider too:** falling into rising air with the glider shut opens it and holds the climb at
  `updraft_vy` 9 m/s [est] (GlideUpdraftMinZVel: the data names it among the locked defaults, not its value).
- Sources: no pad numbers in the data; the one footage pad take (Ghost's ult clip, f103) shows no arc. All [est].

## Knocked in the air (`--glide-hit-check` rows "ACHECK row ..."; PARITY FIRST)

Asked: what a knock or a stun does to a Hunter who is gliding, in an air dash or falling, for Lace, Kael, Vex and Albert. Source: `supervive_physics.md` has only Knockback/KnockbackResist 1.0 for every hunter and Mass 100 (no knock distances, no glider-hit values: the glide and heat constructor defaults are encrypted); the hero-ref frames show no hit on a glider; `docs/SUPERVIVE_DATA.md` sections 4-5: a hit doesn't knock you out of the air, a knockback pushes you and you can steer it, a stun is "no movement, no air control, no abilities". Dash protection stays short (0.14 s i-frames, `docs/DASHES_AND_ABILITY_FEEL.md`).

Hits (from the content): light = Kael LMB, kb 2.6; heavy = Kael RMB Smash push 6, or Albert's full Crushing Blow, kb 13 and a 0.4 s stun; stun = 0.5 s, no push. Knock speed is kb / mass (Lace 0.85, Vex 1.0, Kael and Albert 1.35). Each cell: how far the hit carried the Hunter, measured as the x gap to the same run with no hit at the end of a 1.3 s run, and when a press opened the glider after the hit ("-" means it never shut). Hit 0.05 s in; in an air dash, on the first step its i-frames are over. Measured 2026-11-12, 60 Hz.

| State | Hit | Glider | Lace | Kael | Vex | Albert |
|---|---|---|---|---|---|---|
| Gliding | light | stays open | 1.81 m, - | 1.30 m, - | 1.24 m, - | 1.30 m, - |
| Gliding | heavy (Kael RMB) | stays open (main folded it 0.43 s, decision 0055) | 6.80 m, - | 3.38 m, - | 5.17 m, - | 3.38 m, - |
| Gliding | heavy (Crushing Blow) | shut by its stun | 12.74 m, 0.43 s | 8.32 m, 0.43 s | 10.99 m, 0.43 s | 8.36 m, 0.43 s |
| Gliding | stun | shut | 0 m, 0.53 s | 0 m, 0.53 s | 0 m, 0.53 s | 0 m, 0.53 s |
| Air dash | light | (shut) | 2.35 m, 0.20 s | 0 m, 0.03 s | 1.97 m, 0.20 s | 0 m, 0.03 s |
| Air dash | heavy (Kael RMB) | (shut) | 5.05 m, 0.43 s | 3.44 m, 0.57 s | 2.19 m, 0.43 s | 3.09 m, 0.43 s |
| Air dash | heavy (Crushing Blow) | (shut) | 11.10 m, 0.43 s | 8.15 m, 0.57 s | 4.57 m, 0.43 s | 7.22 m, 0.43 s |
| Air dash | stun | (shut) | 0 m, 0.53 s | 0 m, 0.57 s | 0 m, 0.53 s | 0 m, 0.53 s |
| Falling | light | (shut) | 1.84 m, 0.20 s | 1.33 m, 0.03 s | 1.27 m, 0.20 s | 1.33 m, 0.03 s |
| Falling | heavy (Kael RMB) | (shut) | 6.06 m, 0.43 s | 3.42 m, 0.43 s | 5.10 m, 0.43 s | 3.42 m, 0.43 s |
| Falling | heavy (Crushing Blow) | (shut) | 12.74 m, 0.43 s | 8.32 m, 0.43 s | 10.99 m, 0.43 s | 8.36 m, 0.43 s |
| Falling | stun | (shut) | 0 m, 0.53 s | 0 m, 0.53 s | 0 m, 0.53 s | 0 m, 0.53 s |

- **Fixed (air dash):** on main a knock or a stun that landed after the i-frames did nothing to an air dash: the dash kept driving (Vex 14 m/s, Albert 20 m/s straight on), the push was 0 m and was gone when the dash ended, and a stunned Hunter dashed on. Now a knock (one of 2.5 m/s or more, the one that sets `knock_t`) or a stun ends an air Shift dash that step, as a glide press does (`HunterMove.cut_air_dash`): the push comes in at its full speed and keeps the dash's leftover momentum (why Vex's sideways carry is shorter), a stun stops the drive and the momentum coasts under air drag. A hit inside the i-frames still misses. Kael's air Rampage spends its first 0.07 s in a wind-up, so his row is a hit in the wind-up: a knock or a stun cancels the Rampage.
- **Fixed (gliding, decision 0055, stacked):** a knock carries an open glider instead of folding it for 0.4 s.
- **Matches, not changed:** a stun shuts the glider and a fresh press opens it the step the stun ends (0.5 s stun: 0.53 s with the press). A shut glider waits out a shove over 4 m/s for 0.4 s ([est], kept: `--abyss-check` asserts it at the rim). A lighter knock (Lace and Vex, 2.6-3.1 m/s) keeps it shut for its 0.16-0.2 s slide. A nudge under 2.5 m/s (Kael and Albert, LMB) is not a knock: it neither ends a dash nor holds the glider.
- **Not changed:** Kael's 0.57 s reopen after an air Rampage is AirLimits (the glider stays shut while his kit move runs, items 162). Ground dashes and kit rushes (move kind "rush") still ride through a knock: not asked here, not measured. An overheated glider still lifts you out of the abyss at half strength (`--glider-heat-check`).

## Air limits: the drop and the glider during moves (`AirLimits`, `--air-limits-check`; items 162, 162b)
- **The opening drop is steering only:** heading and the dive. Shift, jump, LMB, RMB, E, R, gloves, belt items and the Boki throw do nothing until you land, and the HUD greys those slots. Space only deploys the canopy out of the dive. This replaces the old rule that an ability or heal pressed mid-drop broke out of it.
- **No glider during an ability or attack animation:** a hold (Kael's Lunge charge, Breaker's spin, Lisette's draw), a cast, a dash or a kit move still inside its keys keeps the glider shut. Glide held opens it the moment the move ends, with its speed. A move that travels ends with its travel, and a kit's Shift moves count as the dash, so Shift into a glide still opens the step the dash ends. Tarek's Quakefall runs to its landing (no glide-out mid-move), except over the abyss. An open glider is never folded by this rule.
- **A press with the glider open (the source decides, owner rule):** Tarek's RMB slam and every other cast the source allows go through; a cast that needs ground (Tarek's Rockwave) is refused, as in the source. The jump rows never hold a press for a glide, and a zone cast (Void's Anomaly and Singularity) measures its ground from the terrain under a glider. LMB stays refused while gliding ([?] in the source). One row per hero and slot in docs/heroes/dash_interactions.md, "From the glider" (`glide` rows, `--glide-cast-check`).
- **Free fall:** a fall never gives more dashes than the ground does (the charges plus the long dash). Each hero's air dash itself is item 183's audit.

## Dashing off a ledge (`HunterMove.dash_off_ledge`, decision 0046)
Walking off a ledge is always allowed (DECISIONS), and so is dashing off one. A ground dash that crosses an edge keeps
its own course (distance and speed curve) but falls as it goes: the height hold is only for dashes pressed in the air.
It ends in the air with the shared dash exit, the kit's ground pose for it stops there, and the glider and the air
dash are free at once (a kit's own gap between dashes still applies: Grimble's barges go a beat apart).
`--move-feel-check` dashes every kit off a 3.2 m terrace (tools/move_feel_ledge.gd; Vex held, Grimble's three barges and
Tenzo's Rock Hop chain too): held height at most 1 step, the exit at least 0.75x run speed (or the end of the dash's
own fitted curve if lower: Vex, Kael and Lace bleed off through run speed, decision 0025), glider within 2 steps,
no ground pose after the end, an air dash on the next press, and no Rock Hop crash in the air. Motley's Trade (a lob,
no travel of his own) must set him down below the edge.

## Walking while attacking (fire-move parity, 2026-11-09)
Share of the plain run while LMB is held, during each charge or hold, and just after release. Measured in the
real match step: ground walk speed on a flat strip, 60 Hz, steady part only. Sources: `[data]` = the tooltips in
briefs/supervive-data/supervive_kits.md (none of them gives a self-slow number); `[F]` = briefs/hero-ref/<file>.md
footage; `[wiki]` as above. Rule (briefs/DECISIONS.md 2026-11-07, parity first): a row changes only when the
source contradicts it and no owner note covers it. Data keys: the weapon's `fire_slow`/`draw_slow`
(content/weapons/, `Hunter._fire_slow`, non-melee default 0.8), and the kit's `move_k()`.

| Hunter (source) | LMB held | Charge / hold | Just after release | Source says | Verdict |
|---|---|---|---|---|---|
| Lace (Myth) | draw 0.70 (`draw_slow`); 0.85 after a perfect | Heavy Shot hold 0.38 (`pin.hold_move`) | full once the arrow leaves | [F] pin.md: walks slowly while drawing; [wiki] perfect shots ease the self-slow | kept |
| Cinder (Felix) | full | Cinder Shot aim: full | 0.60 for 0.35 s after the hose (`after_t`) | [F] linwick.md gap 12: no slow seen while firing; [wiki] 0.35 s slow after release | kept (matches) |
| Albert (Oath) | tap: full; whirl 0.55 | Brightshield 0.60 on the ground (`shield.slow`) | release: the swing's own launch | [F] bjorn.md: stands in the holds seen, can't tell if forced | kept: owner #59 (walks at the hold speed) |
| Tenzo (Tetra) | punch hold 0.85 (`fire_slow`) | Quakefall 0.55 (`slam.walk_k`) | release: the punch / slam travel | [F] breah.md: walks while the fist recovers; jump while charging leaps | kept (silent on the hold walk) |
| Grimble (Kingpin) | 0.80 (default) | hook out 0.15-0.25; Broadside 0.3 / 0.2 | full between shots | [F] dredge.md: walks between shots, no number | kept; Broadside: owner item 36 |
| Vex (Ghost) | full (`fire_slow` 1.0) | Longneedle: planted (`self_slow` 1.0) | full | [F] venator.md: no fire slow; stands still through the cast | kept (matches) |
| **Kael (Brall)** | tap: full; Searing Wave charge 0.55 | **Lunge charge 0.80 (was full)**; Finishing Slam wind-up 0.60 | the Lunge fling | [F] juggernaut.md: 85-95 px/s during the Heavy Attack hold against 113-124 on plain runs (0.69-0.84) | **changed**: `rmb.lunge.walk_k` 0.8; asserted in `--juggernaut-combo-check` |
| Sparkle (Joule) | 0.90 (`fire_slow`) | Storm Rod hold: full on main | full | [F] vireo.md: stood still in every shot; whether she can move while holding is an open question | kept (ext/sparkle-dash-feel adds 0.82 on its own) |
| Motley (Void) | 0.90 (`fire_slow`) | Snap wind-up 0.75 (`cast_slow`); Trade drift 0.3 | full after the 0.15 s recovery | [patch] Snap slows Void while casting (25% less) | kept |
| Neve (Celeste) | full (kit-fired darts; the weapon's `fire_slow` 0.9 never applies) | Ice Spear aim: full | full | [F] rimewright.md: throws while walking or skating | kept (matches) |
| Meeko (Elluna) | full (`fire_slow` 1.0) | Burrseed wind-up 0.5 (`wind_move`) | 0.5 until the seed leaves | [F] mooshmoosh.md: keeps walking while firing | kept |
| Sable (Shiv) | 0.90 (`fire_slow`) | none | full | [F] dancer.md: 77-86 px/s while firing against 113 (0.68-0.76), "not confirmed" | kept (unconfirmed; see below) |

Open, not built (suggestions): Sable may slow more while firing (0.7-0.75 if a straight-run clip confirms it);
Neve's dead `fire_slow` 0.9 on hoar_fan could go; Kael's Searing Wave charge (0.55) and Tenzo's punch hold have no
source number either way.

## Dash streak: the same ribbon on every dash (`DashStreak`, `--dash-streak-check`; owner bug 181)

With no ring, disc or burst on a dash (DECISIONS), some dashes read as a blink. Every Hunter's dash (ground, air, chained) now lays one pooled, flat ribbon in their ability colour from the body anchor (0.9 m up) along the path. It is 0.6 m wide, starts at 0.8 opacity and fades out in 0.2 s, so rivals read the line at match zoom. It sits under a kit's own dash look (Kael's Blazing Spirit, Grimble's junk roll, the flame, ink and blink trails) instead of replacing it: the source shows streaks and ribbons on top of the body look (Brall's flame streaks, the Combat Slide's ribbon trails). `--dash-streak-check` asserts it for all 12 Hunters; `--dash-streak-shots` renders the strips.

## Dash direction with no keys (`--move-feel-check` "standing dash" rows)
The shared rule (`ArchKit.dash_dir`, `Hunter.dash_with`): the move keys held on the press tick, else the cursor (`aim_dir`; the body's facing only if the cursor sits on the hunter). Keys released a tick before Shift count as no keys. Mid-turn the dash takes the keys held on that tick. The "Dash toward the cursor" setting always uses the cursor. Moving = WASD is DECISIONS ("Dashes follow WASD by default"). Sources: briefs/hero-ref/<hero>.md, briefs/supervive-data/supervive_kits.md. [?] = the footage doesn't show it.

| Hunter (source) | Source dash aim | Standing: ours / source | Moving: ours | Just released: ours / source |
|---|---|---|---|---|
| Bjorn (Oath) | aim (bjorn.md:25) | cursor / cursor | WASD (Shield Charge: cursor) | cursor / [?] |
| Breah (Tetra) | cursor (breah.md:156) | cursor / cursor | cursor (the hop aims) | cursor / cursor |
| Dancer (Shiv) | "looks like" movement (dancer.md:116) | cursor / [?] | WASD | cursor / [?] |
| Dredge (Kingpin) | cursor (dredge.md:103) | cursor / cursor | WASD (clamped after the Anchor) | cursor / [?] |
| Juggernaut (Brall) | facing/aim (juggernaut.md:20) | cursor / cursor | WASD (after a Slam: cursor) | cursor / [?] |
| Linwick (Felix) | cursor (linwick.md:75) | cursor / cursor | WASD | cursor / [?] |
| Moosh Moosh (Elluna) | movement (mooshmoosh.md:85) | cursor / [?] | WASD | cursor / [?] |
| Ostra (Void) | lands at the cursor (ostra.md:18) | cursor / cursor | cursor | cursor / cursor |
| Pin (Myth) | movement (pin.md:22) vs cursor (supervive_kits.md:78, tested) | cursor / cursor | WASD [?] | cursor / [?] |
| Tamsin (Celeste) | movement (tamsin.md:70) | cursor / [?] | WASD | cursor / [?] |
| Venator (Ghost) | movement, "slide forward" (venator.md:89) | cursor / [?] | WASD | cursor / [?] |
| Vireo (Joule) | cursor (vireo.md:28) | cursor / cursor | cursor | cursor / cursor |

No row contradicts a source, so no code changed. The [?] rows keep the shared rule until footage shows a standing dash or a dash pressed right after letting go of the keys.
## Aiming across terraces (`Match._mouse_aim`, `AimMode.ray_ground`, `--aimkit-check`)
The source (top-down shooter, supervive_kits/physics [D]): shots travel at the shooter's height; ground casts snap to the surface under the cursor. Ours: with a foe under the cursor (52 px, within 3 tiers) the aim is that foe and shots climb or dip to its height (`aim_y`, at most `AIM_DY_MAX` 2.6 m, passing their own cliff); otherwise the aim is the ground under the cursor. Terraces are 0.8 m (one tier), the muzzle 0.95 m, the camera pitch 66 deg (1 m of height moves the cursor's ground 0.45 m). Before = the old cut at chest height nudged twice by the ground there; measured by the `tier_up` / `tier_down` shots of `--aimkit-check --shots-dir` on the tier-0 map, the rest computed.

| Case | Skillshot (before -> now) | Ground cast (before -> now) |
|---|---|---|
| Same tier, open ground | flat, at your height (= source) | landed 0.42 m short of the cursor's ground (toward the camera) -> at it |
| Foe one tier up on a ledge, cursor on them | climbs to them over their cliff and hits (ours, not the source's flat shot; kept) | at their feet on the ledge (= source) |
| Foe one tier down, cursor on them | dips to them and hits (kept) | at their feet below (= source) |
| No foe, cursor just past a lip | `aim_y` of the wrong tier past a lip facing the camera (0.00 instead of 0.80; one tier still clears the muzzle, two would fly into the face) -> the tier under the cursor | behind the lip you stand on: on the upper tier 0.80 m short (wrong tier) -> on the lower tier at the cursor (0.01 m) |
| Cliff 4+ tiers away (past the old 3-tier cut) | flat into the cliff face (= source; `AIM_DY_MAX` keeps it) | cut at your chest: ~1.0 m past the cursor -> at the cursor |

Fixed (worst case: a cast on the wrong tier): with no foe under the cursor the aim is the first ground the cursor's ray meets, `AimMode.ray_ground`, the walk Vireo's ult landing already did (moved there, so both share it). A ray striking a cliff face takes that cliff's top at its lip; ground hidden behind a lip is never picked; over the abyss the aim stays on your own height. Asserts: the 8 `tier:` checks in `--aimkit-check`.
## Aim: the raw cursor (`--aim-latency-check`)

The owner's note (Nov 10 2026): aim must feel crisp. The in-match cursor sits exactly where the OS mouse is, with no smoothing, acceleration or a frame of lag added by us. This is the audit of the path from the mouse event to the aim point, and what `--aim-latency-check` holds.

**The path, event to aim point.** The OS event lands in Godot's `Input`, which accumulates motion (`Input.use_accumulated_input`, left at its default) and flushes it once at the start of the frame: the position every reader sees that frame is the latest one, with nothing averaged. `Match._process` then moves the view (`MatchCam.update`), reads the cursor (`_gather_input` → `_mouse_aim`, which casts `CamRig.mouse_on_plane` straight through `get_viewport().get_mouse_position()`), steps the sim and draws. The HUD's crosshair (`Reticle.draw`) and the AimKit cursor states (`AimReticle`) draw at that same mouse position the same frame. Nothing on this path interpolates, eases, accelerates or dead-zones the cursor: the only lerps near it are the camera's own lean and follow, which move the world under a raw cursor, not the cursor. The one snap in `_mouse_aim` (a foe within 52 px lends its height) changes the plane the ray is cut at, never where the cursor sits.

**What was adding a frame.** Before this pass the cursor was read before the view moved, so while the view leans after the cursor (every big mouse move, dash and knock) the aim point was one frame old in camera terms: on the move's frame it sat 13.6 px off the cursor at 60 Hz and 5.9 px at 144 Hz. The camera-first order from `ext/feel-aim-steady` (merged here, see "Camera before the cursor" above) removes it: 0.0 px on every case. No other smoothing was found, so nothing else was removed; the reticle art is unchanged.

**Measured** (`AIMLAG` lines; "frames" is rendered frames after the event's own, so 0 is the same frame; allowed is one physics tick, 1 frame at 60 Hz and 2 at 144 Hz):

| Case | Reticle under cursor | Aim under cursor (view still) | Aim stale while the view leans | Before this pass |
|---|---|---|---|---|
| 60 Hz, 720p | 0 | 0 | 0 | 1 frame stale (13.6 px) |
| 144 Hz, 720p | 0 | 0 | 0 | 1 frame stale (5.8 px) |
| 60 Hz, 4K, UI scale 1.5 (canvas 1137.8x640 at 3.375) | 0 | 0 | 0 | 1 frame stale (13.9 px) |
| 144 Hz, 4K, UI scale 1.5 | 0 | 0 | 0 | 1 frame stale (6.0 px) |

The check drives `Match._process` one call per frame at the case's rate (not wall-clock), pushes the move through `Input` and flushes it as the engine would, and measures the aim point against the cursor's own projection through the camera as drawn that frame. The 4K cases set the window and the user's UI scale, so the content scale (`Settings._apply_ui_scale`) is on the path: the mouse position and the camera's ray share the scaled canvas, and the aim lands under the cursor at the same 0 frames.

**Not ours, and not changed.**
- The OS cursor is hidden in a match (`MOUSE_MODE_HIDDEN`) and the reticle is drawn in the frame, so it appears one presentation after a hardware cursor would. That is the engine's frame, not smoothing; a hardware cursor could not carry the bloom, charge, ammo and kit arcs, so the drawn one stays.
- Vsync is on by default (`display/window/vsync/vsync_mode=1`, Settings > Video), which adds up to one display refresh of presentation latency on every platform, and the frame rate limit is off (`max_fps` 0). Both are the player's call in Settings and were left alone.
- The display's own queue and compositor sit outside what a headless check can see.
## Frame-rate parity: the farm steps like the match (`FarmStep`, `--move-rate-check`; decision 0048)

The full table of every movement quantity against the source is [MOVEMENT_PARITY.md](MOVEMENT_PARITY.md). This pass fixed what it found off in the first ten seconds of play:

- **The farm moved on the frame time.** A match steps 60 times a second; the farm's avatar stepped once per drawn frame, so its jump peaked at about 1.46 m at 30 fps and 1.55 m at 144 (1.52 m in a match). `FarmStep` (`scripts/home/farm_step.gd`) now runs the farm's step in `Match.DT` steps, latches a key press for exactly one step, shows the body between its last two steps and plays the pose once a frame.
- **Coyote time and the jump buffer on the farm.** The farm had neither. Both timers live on `FarmStep` and read the match's rows (`coyote_s` 0.12, `jump_buffer_s` 0.12 in `content/rules/hunter_move.json`); the match and the farm share `HunterMove.near_landing`.
- **Sneak speed** is one row (`sneak_speed` 0.5, the source's multiplier). It was 0.55, a constant in `hunter.gd` and another in `home.gd`.

`--move-rate-check` (`tools/move_rate_check.gd`) runs real frame loops at 30, 60 and 144 fps, in a match and on the farm, and fails if run speed, the first second's distance, the stop slide, the jump's apex and airtime, the dash, the coyote window or the jump buffer differ from the 60 fps value by more than a step's worth. It prints one `MRATE` line per measure and ends with `MOVE RATE CHECK DONE, failures: N`.
## Launch arcs: Spring pad and updrafts (`--launch-arc-check`)
Parity pass (DECISIONS 2026-11-07). Sources: supervive_physics.md, SOURCE_UTILITIES.md (wiki Jump_Pad, Deployable_Fan, Gliding), briefs/hero-ref (no pad or updraft use on camera: bjorn, dredge, linwick, ostra, tamsin and venator all list it as missing). The source gives no launch speed or apex, so those rows stay ours and are marked [?]. Pad = the belt's Spring pad (`content/utility/jump_pad.json`, `UtilityUse.pad_launch`); updraft = the map's rising-air columns (`World.updrafts`).

| | Source | Ours (measured) | Tag |
|---|---|---|---|
| Pad launch speed | not published or decoded | 17 m/s up (`UtilityUse.PAD_VY`) | [?] |
| Pad apex | not published | 9.7 m at 1.15 s, back to pad height after ~2.3 s | [?] (gravity [game data] 14.7) |
| Pad sideways speed | launches whatever walks onto it | what you brought, at least 6 m/s (`PAD_MIN_HV`; toward your aim if you stood still) | [?] floor |
| Dash into the pad | keeps the forward momentum, plus a small boost | **was: the dash held you level and ran over the pad, no launch.** Now the pad ends the dash and keeps its speed (10.5 of 10.7 m/s), 1.6x the walk-on's travel | [wiki] fixed; boost size [?], not added |
| WASD in the arc | AirControl 0.015, FallingLateralFriction 0.375 | the one model, `HunterMove.air_steer`: keys reversed the whole arc take 2.3 m/s off, sideways keys drift 1.3 m; a walk-on carries 9.5 m | [game data] match |
| Glider after a pad | you open it to slow the fall, as after any launch (wiki Gliding) | stays shut; a second press opens it the same frame | [wiki] match (DECISIONS allows a pad auto-glide; the source has none, so none) |
| Updraft lift | updrafts act on gliders (GlideUpdraftMinZVel exists, value not decoded) | gliders only: 8 m/s climb in 0.18 s, 9 m/s, thrown 2.8 m past the column's top; a fall with no glider gets no lift | [?] speed, match on gliders-only |
| Updraft heat | currents stop glider heat (wiki wind tunnels) | 0 heat in the column; gliding across keeps 5 m/s | [wiki] match |
| Glider in an updraft | not published | never opens on its own (DECISIONS allows an updraft auto-glide; the lair escape updraft uses it) | [?] |

Not changed, needs the source: the dash boost size, pad arm delay / lifetime / stack (SOURCE_UTILITIES proposes 2 s, 30 s or 10 s after first use, stack 2), and the map's own island pads (`World.pads`), which fly a scripted arc to a set landing with no steering and have no source counterpart.
## LMB: mash vs hold (`--lmb-spam-check`)
The source: mashing the mouse never beats holding. The weapon's cadence caps both, and a charge weapon restarts or ignores an early tap. Measured headless in the training strip, 3 s per run against an idle dummy pinned 3 m off (damage counted through `CombatBus.hit_landed`, plus 1 s after the key comes up). **held** is the key down the whole 3 s. **best** is the best play of the weapon as meant: the hold, hold-and-release cycles (0.7/1.0/1.3 s), or 50 ms taps in a steady 0.2-0.6 s rhythm (for a weapon whose tap is its own move). **clicks** are 20 Hz clicks (1 or 2 frames down out of 3, the worse of the two). The check fails when clicks beat best by more than one shot (the most damage landed in one frame), or when a draw weapon looses anything to the clicks. Hits / damage (2026-11-10):

| Hunter | held | best (how) | clicks | one shot | |
|---|---|---|---|---|---|
| Vex | 23 / 86 | 23 / 86 held | 20 / 76 | 6 | ok |
| Kael | 1 / 20 | 9 / 115 taps every 0.2 s | 10 / 128 | 13 | ok: the clicks are the slash series at its 0.34 s cadence |
| Cinder | 27 / 376 | 27 / 376 held | 0 / 0 | 29 | ok: the flame needs its warm-up |
| Meeko | 8 / 82 | 8 / 82 held | 8 / 82 | 12 | ok |
| Tenzo | 1 / 24 | 3 / 49 cycle 1.0 s | 5 / 45 | 24 | ok: boulders at their 0.6 s cadence |
| Lace | 1 / 30 | 2 / 90 cycle 1.3 s | **0 / 0** (was 6 / 90) | 60 | fixed |
| Grimble | 22 / 59 | 22 / 59 held | 22 / 59 | 11 | ok |
| Neve | 19 / 212 | 19 / 212 held | 16 / 120 | 60 | ok: a release restarts the dart rhythm before its heavies |
| Sparkle | 5 / 60 | 5 / 60 held | 5 / 60 | 12 | ok |
| Albert | 1 / 66 | 3 / 141 cycle 1.0 s | 10 / 120 | 59 | ok: throw and recall at their cadence |
| Sable | 7 / 118 | 8 / 140 cycle 0.7 s | 8 / 140 | 22 | ok: a click is kept one bolt interval, never more |
| Motley | 5 / 48 | 5 / 49 taps every 0.3 s | 5 / 48 | 12 | ok |

- **Fixed, Lace's draw (the shared bow path, `Hunter._loose`):** a release inside the weapon's `draw_min` (longbow 0.08 s) looses nothing and the next press draws afresh. 20 Hz clicks used to loose a 15-damage tap arrow on every 0.5 s cooldown (6 arrows, 90, as much as the best hold). A deliberate tap (0.1 s or more) still looses the 15 tap shot.
- In no other kit do the clicks get past the weapon's cadence: no clicks run beat the best play by more than one shot, so the shared press path (hunter.gd's `trigger`, DashFlow) needed no change.
- Kael's 3 s hold is one Searing Wave (20). His clicks are the slash series, a separate move (source: press = series, hold = blast), at the same cadence as deliberate taps. How the series' damage compares with the wave's is a numbers question, not an input one.
## Press to picture: key to first visible frame (`--press-latency-check`)

How many frames pass between a key going down and the first frame its result is on screen, for every hero's LMB, RMB, E, R (the Merge), dash and jump, at 60 and 144 Hz. Budget: 2 frames at 60 Hz, and the same 33 ms at 144 Hz (4 frames); the check fails above it.

```
XDG_DATA_HOME=<scratch> godot --headless --path . -- --press-latency-check            # all twelve
XDG_DATA_HOME=<scratch> godot --headless --path . -- --press-latency-check=thief,ostra
```

**How it measures.** `tools/press_latency_check.gd` drives `Match._process` one call per engine frame at the case's refresh rate, so the whole real path is on the clock: the Input flush, `_gather_input`, the 60 Hz fixed steps under the accumulator, the interpolated render. It presses through the real Input actions (`fire`, `secondary`, `signature`, `ultimate`, `dash`, `jump`) with a 33 ms tap, and stamps two frames: `sim`, the first frame the simulation acted (a shot, a charge spent, a cast, a dash or jump under way, a draw or wind-up started), and `vis`, the first frame something is on screen (a shot or node spawned, the hunter's rendered position moving, the cast or kit-move pose, a swing, the bow draw, the muzzle flash). Frame 0 is the frame of the press. At 144 Hz every press is tried at the three phases of the 60 Hz tick and the latest kept. Between cases the hunter waits until it is at rest; a case where it is not is void and fails, so a long move leaking into the next press can never pass as "fast".

**The path, and where a frame could hide.** A press lands in `_gather_input`, which runs at the top of the same `_process`, before the steps. `Input.is_action_just_pressed` goes into `pending_input`, which the next `step` turns into the hunter's `inp` flags; `inp["fire"]` is read as a level, so a held button fires on the first step that sees it. Nothing on the ability path is deferred to a later frame: no `call_deferred`, no `await`, no Timer; the kits' wind-ups (`Match.later`, the R fuse, a dash "windup") run on match time inside `step`, and their first visible sign (the pose, the telegraph) is on the press frame. The render reads the state the steps just produced in the same `_process` (`LOCAL_RENDER_LEAD`: the local hunter is drawn at `pos + step * alpha`, never a tick behind), and shot nodes are placed the frame they spawn. The one hop is the fixed step itself: at 144 Hz a press can wait up to two frames (14 ms) for the accumulator to reach the next 60 Hz tick; at 60 Hz every frame runs a step.

**Result: nothing over budget, nothing to fix.** Every hero's six keys show their result on the press frame at 60 Hz (0 frames), and within 2 frames at 144 Hz, with three readings at 3 (Tenzo's RMB and E, Meeko's RMB: the cast or kit-move pose eases in from zero over its first 60 Hz tick, so the pose is read one tick after the sim accepted). Before and after are the same table, since no game code changed for latency; the table below is the trace. Measured headless on rpc1 and on a real GPU (Forward+, RTX 4090, through jobq): the same frames.

Causes traced and cleared, with where each would have cost a frame:

| Suspect | Found | Frames |
|---|---|---|
| Input polled late in the frame | `_gather_input` runs first in `Match._process`, before the steps; the step in the same call acts on it | 0 |
| `pending_input` to `inp` handoff | just-pressed flags go into `pending_input`, the next `step` moves them into the hunter's `inp`; at 60 Hz that step is in the same frame | 0 (60 Hz), the tick hop at 144 Hz |
| A deferred call, `await`, Timer | none on the key paths (`scripts/arch`, `hunter.gd`, `match.gd`); the one `call_deferred` in combat is `HunterFeats._watch_knock`, bookkeeping after a knock | 0 |
| A wait on an animation event | none: casts stamp `cast_at`, the pose follows the sim state in the same render | 0 |
| Wind-ups (`Match.later`, the R fuse, a dash `windup`) | run on match time inside `step`; the pose or telegraph shows on the press frame, the effect lands when the data says | 0 to first sign |
| The physics tick hop | the 60 Hz accumulator: at 144 Hz a press waits 0 to 2 frames for the next tick (14 ms at most) | 0 to 2 (144 Hz) |
| Render a tick behind the sim | `LOCAL_RENDER_LEAD`: the local hunter is drawn at `pos + step * alpha`, shot nodes are placed the frame they spawn | 0 |
| Release-shaped keys | an RMB with a hold variant (Kael 0.3 s, Cinder 0.15, Tenzo 0.2, Lace 0.15, Neve 0.2, Motley 1.0, Mossy 0.1) and a charged sword (Tenzo's fists) fire on the release by design; the result is on the release frame | 0 from the release |

**Per hero** (frames from the event to the sim acting / to the first thing on screen; "first sign" is press to the first visible sign for the release-shaped keys; via names what showed first):

| Hero | Key | 60 Hz sim/vis | first sign | 144 Hz sim/vis | first sign | via |
|---|---|---|---|---|---|---|
| Vex (gunslinger) | LMB | 0/0 |  | 2/2 |  | shot / shot |
| Vex (gunslinger) | RMB | 0/0 |  | 2/2 |  | kit move / kit move |
| Vex (gunslinger) | E | 0/0 |  | 2/2 |  | kit move / kit move |
| Vex (gunslinger) | R | 0/0 |  | 2/2 |  | merge / merge |
| Vex (gunslinger) | dash | 0/0 |  | 2/2 |  | move / move |
| Vex (gunslinger) | jump | 0/0 |  | 2/2 |  | move / move |
| Kael (juggernaut) | LMB | 0/0 |  | 2/2 |  | shot / shot |
| Kael (juggernaut) | RMB | 0/0 | 0 | 0/0 | 2 | cast pose / cast pose |
| Kael (juggernaut) | E | 0/0 |  | 2/2 |  | kit move / kit move |
| Kael (juggernaut) | R | 0/0 |  | 2/2 |  | merge / merge |
| Kael (juggernaut) | dash | 0/0 |  | 2/2 |  | move / move |
| Kael (juggernaut) | jump | 0/0 |  | 2/2 |  | move / move |
| Cinder (ashwick) | LMB | 0/0 |  | 2/2 |  | shot / shot |
| Cinder (ashwick) | RMB | 0/0 | 0 | 0/0 | 2 | cast pose / cast pose |
| Cinder (ashwick) | E | 0/0 |  | 2/2 |  | kit move / kit move |
| Cinder (ashwick) | R | 0/0 |  | 2/2 |  | merge / merge |
| Cinder (ashwick) | dash | 0/0 |  | 2/2 |  | move / move |
| Cinder (ashwick) | jump | 0/0 |  | 2/2 |  | move / move |
| Meeko (tender) | LMB | 0/0 |  | 2/2 |  | shot / shot |
| Meeko (tender) | RMB | 0/0 |  | 1/3 |  | kit move / kit move |
| Meeko (tender) | E | 0/0 |  | 2/2 |  | kit move / kit move |
| Meeko (tender) | R | 0/0 |  | 2/2 |  | merge / merge |
| Meeko (tender) | dash | 0/0 |  | 2/2 |  | move / move |
| Meeko (tender) | jump | 0/0 |  | 2/2 |  | move / move |
| Tenzo (dolm) | LMB | 0/0 | 2 | 2/2 | 7 | shot / shot |
| Tenzo (dolm) | RMB | 0/0 | 2 | 0/3 | 8 | kit move / cast pose |
| Tenzo (dolm) | E | 0/0 |  | 1/3 |  | kit move / cast pose |
| Tenzo (dolm) | R | 0/0 |  | 2/2 |  | merge / merge |
| Tenzo (dolm) | dash | 0/0 |  | 2/2 |  | move / move |
| Tenzo (dolm) | jump | 0/0 |  | 1/1 |  | move / move |
| Lace (archer) | LMB | 0/0 |  | 2/2 |  | shot / shot |
| Lace (archer) | RMB | 0/0 | 0 | 0/0 | 2 | cast pose / cast pose |
| Lace (archer) | E | 0/0 |  | 2/2 |  | kit move / kit move |
| Lace (archer) | R | 0/0 |  | 2/2 |  | merge / merge |
| Lace (archer) | dash | 0/0 |  | 2/2 |  | move / move |
| Lace (archer) | jump | 0/0 |  | 2/2 |  | move / move |
| Grimble (dredge) | LMB | 0/0 |  | 2/2 |  | shot / shot |
| Grimble (dredge) | RMB | 0/0 |  | 2/2 |  | kit move / kit move |
| Grimble (dredge) | E | 0/0 |  | 2/2 |  | kit move / kit move |
| Grimble (dredge) | R | 0/0 |  | 2/2 |  | merge / merge |
| Grimble (dredge) | dash | 0/0 |  | 2/2 |  | move / move |
| Grimble (dredge) | jump | 0/0 |  | 2/2 |  | move / move |
| Neve (rimewright) | LMB | 0/0 |  | 2/2 |  | shot / shot |
| Neve (rimewright) | RMB | 0/0 | 0 | 0/0 | 2 | cast pose / cast pose |
| Neve (rimewright) | E | 0/0 |  | 2/2 |  | kit move / kit move |
| Neve (rimewright) | R | 0/0 |  | 2/2 |  | merge / merge |
| Neve (rimewright) | dash | 0/0 |  | 2/2 |  | move / move |
| Neve (rimewright) | jump | 0/0 |  | 2/2 |  | move / move |
| Motley (mage) | LMB | 0/0 |  | 2/2 |  | shot / shot |
| Motley (mage) | RMB | 0/0 | 0 | 0/0 | 2 | cast pose / cast pose |
| Motley (mage) | E | 0/0 |  | 2/2 |  | kit move / kit move |
| Motley (mage) | R | 0/0 |  | 2/2 |  | merge / merge |
| Motley (mage) | dash | 0/0 |  | 2/2 |  | move / move |
| Motley (mage) | jump | 0/0 |  | 2/2 |  | move / move |
| Mossy (bulwark) | LMB | 0/0 |  | 2/2 |  | shot / shot |
| Mossy (bulwark) | RMB | 0/0 | 0 | 0/0 | 2 | cast pose / cast pose |
| Mossy (bulwark) | E | 0/0 |  | 2/2 |  | kit move / kit move |
| Mossy (bulwark) | R | 0/0 |  | 2/2 |  | merge / merge |
| Mossy (bulwark) | dash | 0/0 |  | 2/2 |  | move / move |
| Mossy (bulwark) | jump | 0/0 |  | 2/2 |  | move / move |
| Sparkle (thief) | LMB | 0/0 |  | 2/2 |  | shot / shot |
| Sparkle (thief) | RMB | 0/0 |  | 2/2 |  | kit move / kit move |
| Sparkle (thief) | E | 0/0 |  | 2/2 |  | kit move / kit move |
| Sparkle (thief) | R | 0/0 |  | 2/2 |  | merge / merge |
| Sparkle (thief) | dash | 0/0 |  | 2/2 |  | move / move |
| Sparkle (thief) | jump | 0/0 |  | 2/2 |  | move / move |
| Sable (ostra) | LMB | 0/0 |  | 2/2 |  | shot / shot |
| Sable (ostra) | RMB | 0/0 |  | 2/2 |  | kit move / kit move |
| Sable (ostra) | E | 0/0 |  | 2/2 |  | kit move / kit move |
| Sable (ostra) | R | 0/0 |  | 2/2 |  | merge / merge |
| Sable (ostra) | dash | 0/0 |  | 2/2 |  | kit move / kit move |
| Sable (ostra) | jump | 0/0 |  | 2/2 |  | move / move |

**Worth a look (not built, PARITY FIRST):** Tenzo's LMB and RMB are the only keys that show nothing on the press frame: both wait for the release (first sign 2 frames at 60 Hz, 7 to 8 at 144: the 33 ms tap plus the tick hop), where every other hold-variant RMB plants its cast pose on the press. If the source shows a wind-up on the press for his fists or his RMB hold, that pose is the fix; if not, this is parity.

Found by the check and fixed on the side: `VVFx.echo` (Vex's dash after-image) read mesh instances the model had since freed (a muzzle flash, an old weapon) and spammed "previously freed instance" errors on every echo frame; the pair is now skipped and its ghost hidden.

- **Town and interior on `FarmStep`, facing blended** (decision 0049). Both walked on the frame time with their own constants (town speed 5.0, jump 8.5 at gravity 26; room speed 4.2, an exponential ease). They now step in `Match.DT` steps with the hero's row (`speed`, `accel`, the walking brake, `turn_rate`) and the town jumps with `Hunter.JUMP_V` and `H_GRAV`, coyote time and the buffer included. The farm, town and room draw their facing between the last two steps' facings. `--move-rate-check` gained town and room rows (run, stop, jump, graces) and a facing assert: through a reversal at 144 fps no frame turns the drawn facing by more than `turn_rate` allows in that frame.
## 8 directions: W up the screen, no diagonal bonus (`tools/move_feel_dirs.gd`)

The keys become a world direction in one place for the match (`Match._gather_input`) and one for the
garden (`Home._move_player`), the same way: `Vector2(get_axis(left, right), get_axis(up, down))`,
normalised only when longer than 1 (so a stick's partial push keeps its length, and a key diagonal is
exactly 1), then rotated by the camera's yaw, which only the skyship ride and the drop turn (the match
camera and the garden camera sit at yaw 0, looking north). There is no deadzone on keys. World north
(-z) is straight up the screen because `CamRig` places the camera on +z at its pitch; no roll, no twist.
The glide steers toward `move x glide speed`, the class dash takes `move.normalized()` (`ArchKit.dash_dir`),
so every consumer of the keys sees the same unit vector.

Measured on the match camera (style supervive, pitch 66, cursor pan off so the hunter is on the screen's
centre line), medium class, through the real keyboard path (`Match._process`), 2026-11-11, origin/main
d255acbee. Nothing needed fixing: there was no skew and no speed bonus before this pass; the rows pin it.

| Key | Screen heading (deg, 0 = right, 90 = up) | Ideal (the projected world line) | World off (deg) | Ground speed (m/s) | Glide speed (m/s) | Dash speed (m/s) |
|---|---|---|---|---|---|---|
| W | 90.0 | 90.0 | 0.00 | 4.550 | 5.000 | 23.000 |
| S | -90.0 | -90.0 | 0.00 | 4.550 | 5.000 | 23.000 |
| A | 180.0 | 180.0 | 0.00 | 4.550 | 5.000 | 23.000 |
| D | 0.0 | 0.0 | 0.00 | 4.550 | 5.000 | 23.000 |
| W+D | 42.5 | 42.5 | 0.00 | 4.550 | 5.000 | 23.000 |
| W+A | 137.5 | 137.5 | 0.00 | 4.550 | 5.000 | 23.000 |
| S+D | -42.5 | -42.5 | 0.00 | 4.550 | 5.000 | 23.000 |
| S+A | -137.5 | -137.5 | 0.00 | 4.550 | 5.000 | 23.000 |

A diagonal reads 42.5 degrees on screen, not 45, because the pitched camera foreshortens the up-down
axis (atan(sin 66) = 42.4; the glide at 25 m reads 42.2 for the same reason). The source's angled camera
does the same: a 45-degree world diagonal is a flatter diagonal on screen. The check rows (`--move-feel-check`):

| Key | Target | Source |
|---|---|---|
| dir_ground / dir_glide _screen_err_deg | <= 1 deg, worst of 8 | [footage] W runs straight up the screen |
| dir_ground / dir_glide / dir_dash _world_err_deg | <= 1 deg, worst of 8 | keys -> world: no skew from the yaw or the axes |
| dir_ground / dir_glide / dir_dash _speed_spread | <= 1% (fastest vs slowest) | [game data] normalised input, a diagonal is no faster |

The dash row fires the press as one sim step: while the check drives frames by hand inside one engine
frame, a key's "just pressed" never clears, so a real Shift would stay pressed into every later run and
dash before the keys are read (toward the cursor). The garden has no separate row: it is the same
expression and the same camera class at yaw 0.
## Water: shallow edges and deep ponds (parity table, Nov 11)

Only the farm's ponds are water you move through (`scripts/home/home_water.gd`; the edge ring of a pond is shallow, the middle deep). Match maps have no wadeable water: their pools and falls are set dressing and a hunter runs over them at land values. Source side: the game-data dump (`briefs/supervive-data/supervive_physics.md`) overrides no swim or water setting in the movement component (no swim speed, no water speed multiplier, no water physics volume), the kit data and the hero footage notes (`briefs/hero-ref`) never mention crossing water, and no public page we could read gives a water rule. Nothing settles any cell on the source side, so every one is [?] and ours stand. No `hunter_move.json` const and no `--move-feel-check` row was added: the check only takes rows the source settles.

Ours below are the farm's constants (run `SPEED` 5.0 m/s, `JUMP_V` 6.8 m/s, `H_GRAV` 14.7 m/s²; jump height = v²/2g). `--swim-check` reads the speeds through a window that spans the shoreline, so it prints 3.5 wading and 3.3 swimming; the steady values are the products in the table.

| Move | Source, shallow | Source, deep | Ours, shallow (wade) | Ours, deep (swim) |
|---|---|---|---|---|
| Run speed | [?] | [?] | 0.68x walk (`WADE_SPEED`): 3.4 m/s | 0.5x walk (`SWIM_SPEED`): 2.5 m/s |
| Dash length | [?] | [?] | land length (the dash ignores water) | no dash |
| Jump height | [?] | [?] | land height, 1.57 m | kick up at 0.85x lift (`BREACH_V`): 5.78 m/s, 1.14 m |
| Glide take-off | [?] | [?] | as on land: a second Space in the air, or hold 0.1 s (`GLIDE_ENGAGE`) | as on land once the kick has you airborne; from the lower apex |

What to do when the source gets a value: put it in `hunter_move.json` as a named const, read it from `HomeWater`, and add a `--move-feel-check` row for it.
## Input latency: press to first motion or shot (`--input-latency-check`)
Source feel is instant: the first frame of motion, or the shot, follows the press. `tools/input_latency_check.gd` presses LMB, RMB, E, dash and jump for every Hunter through the real input path (Input actions, `Match._process`: gather, pending input, the step, the render). It holds each press for 6 ticks (a quick 0.1 s tap) and records the first tick on which the Hunter's velocity, its animation state (what `HunterAnim` is told: the kit move, the cast, the shot, the swing, the dodge, leaving the ground) or a projectile of theirs changes. Tick 0 is the step run in the frame of the press. Target: tick 0 or 1, unless a sourced wind-up applies (the check's `WINDUP` table cites it).

| Hunter | LMB | RMB | E | Dash | Jump |
|---|---|---|---|---|---|
| Vex | 0 anim, shot | 0 anim | 0 anim | 0 vel, anim | 0 vel, anim |
| Kael | 0 anim | 6 anim (release) | 0 anim, shot | 0 anim | 0 vel, anim |
| Cinder | 0 anim | 1 anim | 0 anim | 0 vel, anim | 0 vel, anim |
| Meeko | 0 anim, shot | 0 anim | 0 anim | 0 vel, anim | 0 vel, anim |
| Tenzo | 0 anim | 6 anim (release) | 0 anim | 0 anim | 0 vel, anim |
| Lace | 0 anim | 0 anim (was none) | 0 anim, shot | 0 vel, anim | 0 vel, anim |
| Grimble | 0 vel, anim, shot | 0 anim, shot | 0 anim | 0 vel, anim | 0 vel, anim |
| Neve | 0 anim, shot | 1 anim | 0 anim | 0 vel, anim | 0 vel, anim |
| Motley | 0 anim, shot | 1 anim | 0 anim | 0 anim | 0 vel, anim |
| Mossy | 0 anim | 0 anim (was none) | 0 anim | 0 vel, anim | 0 vel, anim |
| Sparkle | 0 anim, shot | 0 anim | 0 anim | 0 vel, anim | 0 vel, anim |
| Sable | 0 anim, shot | 0 anim | 0 anim | 0 anim | 0 vel, anim |

No double buffering: a press is gathered, queued and applied in the same frame's step, and the local Hunter is drawn at the present. What was later, and what changed:
- **Lace RMB (Heavy Shot): an animation gate.** The draw pose waited for the 0.15 s tap guard, so a tap showed nothing and a hold showed nothing for 9 ticks. The draw clip now starts on the press. It already ran on the hold's clock, so the full-draw key still lands at full charge. A tap still looses nothing and costs nothing, and its release puts the bow down.
- **Mossy RMB (Aegis): an animation gate.** The guard pose waited for the aegis, 0.1 s into the hold. The arm now comes up on the press. The aegis still rises 0.1 s in (source: 0.2 s, docs/heroes/bulwark.md), and a tap lowers the arm again.
- **A cleared kit move froze its pose.** When a kit cleared its move (a cancelled draw, the lowered aegis), `Hunter.anim_s` kept the old move with its clock stopped, so the body held that frame. The move now ends.
- **Kael and Tenzo RMB: tap/hold splits, kept.** The press can't show which one it is until the release (the tap) or the hold threshold, so both act on the tap's release (tick 6 here, tick 0 from the release). Tenzo's is owner item 61 ("a tap shows nothing, it lands on the release"). Alternative not built: start Kael's Finishing Slam wind-up on the press, which would bring its strike up to 0.3 s earlier (a balance change).
- **Cinder, Neve and Motley RMB: tick 1** (within target). The aim pose starts on the kit's first hold tick, which runs the step after the press.
## Brake under a cast: let go and cast RMB the same frame (`--move-feel-check` `brake_cast` rows)

The source brakes a let-go the same whatever the walk's cap is: UE's CalcVelocity applies the walking brake (22.2 m/s² plus friction 2/s) whenever the keys are off, and a cast's move scale only caps the walk while keys are held. Ours passed the cast-scaled walk cap to `HunterMove.brake` as the run speed, so a wind-up slow (Meeko's Burrseed x0.5, Motley's Shard Snap x0.75) turned an ordinary run into "over-run" and shed it at `Hunter.GROUND_SHED` 110 m/s² first: a short, dead stop under those two casts. Now only speed over the Hunter's own run (base speed with gear) counts as over-run, so a slow, a crouch or a cast's wind-up brakes like the plain stop too. Kit rows are untouched (the walk caps still apply while you hold a key). No kit's RMB cast lock zeroes the speed; Motley's well lock and Neve's Rimelock (X, the statue slides on its ice on purpose, item 65) only block other keys.

Run at full speed on flat ground, keys off and RMB pressed the same frame (a tap on hold kits goes on the release, one frame later), 60 fps:

| Hunter | Plain stop | Cast stop before | Cast stop after | Gap after |
|---|---|---|---|---|
| Meeko (tender) | 0.325 m / 0.183 s | 0.166 m / 0.133 s | 0.325 m / 0.183 s | 0.000 m |
| Motley (ostra) | 0.339 m / 0.183 s | 0.253 m / 0.150 s | 0.339 m / 0.183 s | 0.000 m |
| gunslinger, juggernaut, archer | 0.325 m / 0.183 s | 0.325 m / 0.183 s | 0.325 m / 0.183 s | 0.000 m |
| ashwick, dolm, dredge, mage, thief | 0.339 m / 0.183 s | 0.339 m / 0.183 s | 0.339 m / 0.183 s | 0.000 m |
| rimewright | 0.311 m / 0.167 s | 0.311 m / 0.167 s | 0.311 m / 0.167 s | 0.000 m |
| bulwark | 0.367 m / 0.183 s | 0.367 m / 0.183 s | 0.367 m / 0.183 s | 0.000 m |

`brake_cast_gap_m` (the widest gap over the 12) must stay <= 0.05 m; each Hunter has its own ok line. Dredge's Abyssal Hand on the ground is a CastHold hover that steers like the ground (decision 0020), so it is compared too. The "before" column for the ten unchanged Hunters is the same run with the old brake.
## Dashing off a ledge (`HunterMove.dash_off_ledge`, decision 0046)
Walking off a ledge is always allowed (DECISIONS), and so is dashing off one. A ground dash that crosses an edge keeps
its own course (distance and speed curve) but falls as it goes: the height hold is only for dashes pressed in the air.
It ends in the air with the shared dash exit, the kit's ground pose for it stops there, and the glider and the air
dash are free at once (a kit's own gap between dashes still applies: Grimble's barges go a beat apart).
`--move-feel-check` dashes every kit off a 3.2 m terrace (tools/move_feel_ledge.gd; Vex held, Grimble's three barges and
Tenzo's Rock Hop chain too): held height at most 1 step, the exit at least 0.75x run speed, glider within 2 steps,
no ground pose after the end, an air dash on the next press, and no Rock Hop crash in the air. Motley's Trade (a lob,
no travel of his own) must set him down below the edge.
## Dashes on slopes, steps and crests (`--dash-slope-check`, 2026-11-10)
[game data] A ground dash is walking movement: it keeps to the floor on walkable slopes (WalkableFloorAngle 50 deg; the floor-find reaches MaxStepHeight 45 uu down) and keeps its distance. It leaves the ground only off a ledge. Our terrain has no smooth slopes, only stair tiles (one 0.8 m tier per metre) and flat tiles, so the ramps are stair runs: "15 deg" is stair, flat, flat (14.9 deg mean) and "30 deg" is three stairs then a flat (31.0 deg mean). The step is one tier up. The crest is a flat top running into the 31 deg ramp going down. Every Hunter gets one Shift tap while holding the way it goes, on the Hollow Crown and the Training Area (both maps gave identical numbers). Distance is horizontal, from the press to the first step back on the ground at run speed. Pop is the most height over the ground under the body's footprint. Air is time off the ground in 2.5 s.

What was wrong: once grounded, any drop over 0.05 m under you in one step made you airborne, and an air dash holds its height, so every dash flew off a crest. Uphill, the body's radius saw the stair ahead as a wall. The terrace step-up only ran with movement keys held, and only at walking speed. The lift onto the stair's lip then went airborne, and the ledge rise floated you up the ramp for about 1.3 s.

Fix: `HunterMove.follows_floor` (shared by walking and every dash) keeps a grounded body on the floor when the ground under it drops less than `floor_snap` (0.45 m), or less than a 50 deg slope falls over the distance moved that step. The cap is under a whole tier, so a terrace edge stays a ledge. The model eases down by `step_vis`. The terrace step-up also runs during a dash, at the dash's own speed. Tarek's Rock Hop down a slope used to land back on the rock it sprang from. Its flight now lengthens so the arc clears that rock's end by 0.2 m (`BreahHop._flight_to`), and it still lands on the aimed spot.

Each cell is distance vs flat, pop m, air s: main d255acbee / this branch.

| Hunter | flat m | ramp 15 | ramp 30 | step | crest |
|---|---|---|---|---|---|
| gunslinger | 3.79 | +29% 0.42 1.40 / +0% 0 0 | +188% 0.42 1.35 / +0% 0 0 | -2% 0 0.05 / +0% 0 0.03 | +81% 2.03 1.45 / +0% 0 0 |
| juggernaut | 3.66 | +35% 0.42 1.90 / +0% 0 0 | +51% 0.31 2.17 / +0% 0 0 | -7% 0.80 0.03 / +0% 0 0.02 | +74% 1.73 1.23 / +0% 0 0 |
| ashwick | 3.42 | +44% 0.38 1.12 / +0% 0 0 | +243% 0.38 1.28 / +0% 0 0 | -5% 0.80 0.05 / +0% 0 0.03 | +77% 1.59 1.47 / +0% 0 0 |
| tender | 3.64 | -6% 0.18 0.30 / +0% 0 0 | -7% 0.42 1.32 / +0% 0 0 | -6% 0.80 0.03 / +0% 0 0.03 | +74% 1.79 1.23 / +0% 0 0 |
| dolm (hop) | 2.55 | -2% 1.54 1.13 / -2% 1.54 0.47 | +126% 0.66 1.93 / +0% 0.66 0.28 | -2% 1.16 0.57 / -2% 1.16 0.57 | -71% 0.81 1.53 / -1% 0.71 0.52 |
| archer | 2.96 | +56% 0.41 1.75 / +0% 0 0 | +87% 0.26 1.85 / +0% 0 0 | -3% 0 0.03 / +0% 0 0.03 | +90% 1.27 1.42 / +0% 0 0 |
| dredge | 2.79 | +71% 0.42 1.77 / +0% 0 0 | +111% 0.38 1.98 / +0% 0 0 | -6% 0 0.03 / +0% 0 0.03 | +55% 0.80 1.52 / +0% 0 0 |
| rimewright | 1.79 | +199% 0.42 1.23 / +0% 0 0 | +184% 0.31 1.78 / +0% 0 0 | -5% 0.80 0.05 / +0% 0 0.03 | +114% 0.23 1.55 / +0% 0 0 |
| mage | 7.61 | -84% 0 0 / -1% 0 0 | -84% 0 0 / -1% 0 0 | -91% 0 0 / +0% 0 0.02 | +42% 4.09 0.97 / +0% 0 0 |
| bulwark | 2.86 | +68% 0.41 1.80 / +0% 0 0 | +87% 0.35 1.82 / +0% 0 0 | -6% 0 0.03 / +0% 0 0.02 | +88% 1.10 1.38 / +0% 0 0 |
| thief | 4.37 | -52% 0.43 1.10 / +0% 0 0 | -52% 0.48 2.00 / +0% 0 0 | -3% 0.80 0.03 / +0% 0 0.03 | +77% 2.31 1.33 / +0% 0 0 |
| ostra (trade) | 13.18 | -2% 0 0.37 / -1% 0 0 | +0% 0 0.37 / -2% 0 0 | -2% 0 0.30 / -3% 0.80 0.33 | -6% 0.79 1.00 / -3% 0.13 0.18 |

How to read the before numbers: a distance far over flat means the dash took off and flew on. The step's 0.03 s of air after the fix is the lip lift before your centre is over the upper tier, the same as walking. The pass bar is distance within 10% of flat, and pop and air no more than flat plus 0.15 m and 0.1 s. A hop to higher ground may peak higher by that rise. Rock Hop down a slope may stay up as long as the extra drop takes to fall. Sable's Lantern Trade hovers him in place and then swaps him to the lantern, so it is not a ground dash and only its distance is held. Controls still pass: a dash and a walk off a one-tier ledge leave the ground (0.70 s and 0.33 s of air, the same as main), and a walk still goes up the step.

## A dash into a rim (`--mantle-check` section 7, `MantleCarry.dash_rise`)

Nobody had measured what a dash does when it meets a rim. Each starter presses Shift straight at a rim with the keys held
into it, from the ground and from the air (hanging with the lip that far above the feet). Lace's rows are her travel dash,
the flick: with charges her Shift is the Spirit Walk, which climbs faces by design. The terrain grid builds ground rims in
whole 0.8 m terraces, so a ground row builds the terrace nearest its height. Columns: what happened, press to over the
top, time lost against the same press with no rim, time stood still at the face, speed leaving the face.

**Source.** `supervive_physics.md`: the suction pulls you up at most 1.5 m (MantleSuctionUpwardsForceHeightMax; Lace
and Kael climb taller, bCanWallJump) and the mini-mantle sets your speed over the lip to 0.6x what you came in with,
held 0.75 s. Footage (MANTLE_185b.md, owner_mantle_clip 17.9-18.6 s): a dash at a rim is on top ~0.2 s later, still at
dash-trail speed, no stop. No hero-ref brief has dash-into-ledge frames.

**Before** (origin/main 53e2fe7f3), an air dash did catch the ledge, but the grab threw away the dash and the rise
started from a standstill at the suction's 2.5 m/s cap: 0.37-0.60 s to the top, up to 0.20 s stood dead at the face.
**Now** the dash hands over: what is left of it is still dropped (the mini-mantle sets the speed from the lip, 0.6x the
dash, unchanged), but its speed, capped at the 14 m/s fastest rise, takes you up the face. Ground dashes are unchanged:
a single terrace steps you up mid-dash, a higher face needs a jump (the walking rule). Alternative not taken: keep the
rest of the dash and resume it on top (more than the source's 0.6x would come over).

| Hunter | from | rim (m) | before | after |
|---|---|---|---|---|
| Lace | air | 0.6 | mantle, top 0.37s, lost 0.23s, stall 0.02s, off 10.5 m/s | mantle, top 0.20s, lost 0.08s, stall 0.00s, off 10.5 m/s |
| Lace | air | 1.0 | mantle, top 0.53s, lost 0.40s, stall 0.17s, off 10.5 m/s | mantle, top 0.22s, lost 0.10s, stall 0.00s, off 10.5 m/s |
| Lace | air | 1.5 | mantle, top 0.42s, lost 0.30s, stall 0.08s, off 10.5 m/s | mantle, top 0.25s, lost 0.12s, stall 0.02s, off 10.5 m/s |
| Lace | air | 2.0 | mantle, top 0.48s, lost 0.37s, stall 0.15s, off 10.5 m/s | mantle, top 0.30s, lost 0.17s, stall 0.03s, off 10.5 m/s |
| Kael | air | 0.6 | mantle, top 0.45s, lost 0.28s, stall 0.02s, off 16.3 m/s | mantle, top 0.25s, lost 0.08s, stall 0.00s, off 16.3 m/s |
| Kael | air | 1.0 | mantle, top 0.60s, lost 0.43s, stall 0.10s, off 16.3 m/s | mantle, top 0.27s, lost 0.10s, stall 0.00s, off 16.3 m/s |
| Kael | air | 1.5 | mantle, top 0.48s, lost 0.32s, stall 0.03s, off 16.3 m/s | mantle, top 0.30s, lost 0.13s, stall 0.02s, off 16.3 m/s |
| Kael | air | 2.0 | mantle, top 0.55s, lost 0.38s, stall 0.08s, off 16.3 m/s | mantle, top 0.35s, lost 0.18s, stall 0.02s, off 16.3 m/s |
| Vex | air | 0.6 | mantle, top 0.42s, lost 0.27s, stall 0.03s, off 8.5 m/s | mantle, top 0.25s, lost 0.08s, stall 0.00s, off 8.5 m/s |
| Vex | air | 1.0 | mantle, top 0.57s, lost 0.40s, stall 0.20s, off 8.5 m/s | mantle, top 0.27s, lost 0.10s, stall 0.00s, off 8.5 m/s |
| Vex | air | 1.5 | mantle, top 0.47s, lost 0.32s, stall 0.12s, off 8.5 m/s | mantle, top 0.28s, lost 0.13s, stall 0.02s, off 8.5 m/s |
| Vex | air | 2.0 | stop (beyond reach), never tops | stop (beyond reach), never tops |
| Albert | air | 0.6 | mantle, top 0.37s, lost 0.25s, stall 0.02s, off 12.3 m/s | mantle, top 0.20s, lost 0.08s, stall 0.00s, off 12.3 m/s |
| Albert | air | 1.0 | mantle, top 0.53s, lost 0.42s, stall 0.17s, off 12.3 m/s | mantle, top 0.22s, lost 0.10s, stall 0.00s, off 12.3 m/s |
| Albert | air | 1.5 | mantle, top 0.43s, lost 0.32s, stall 0.08s, off 12.3 m/s | mantle, top 0.25s, lost 0.13s, stall 0.02s, off 12.3 m/s |
| Albert | air | 2.0 | stop (beyond reach), never tops | stop (beyond reach), never tops |
| Lace | ground | 0.6 (0.8 built) | same | step, top 0.13s, lost 0.00s, stall 0.00s, off 17.5 m/s |
| Lace | ground | 1.0 (0.8 built) | same | step, top 0.13s, lost 0.00s, stall 0.00s, off 17.5 m/s |
| Lace | ground | 1.5 (1.6 built) | same | stop at the face, never tops (stall 2.22s) |
| Lace | ground | 2.0 (2.4 built) | same | stop at the face, never tops (stall 2.22s) |
| Kael | ground | 0.6 (0.8 built) | same | step, top 0.18s, lost 0.02s, stall 0.00s, off 23.3 m/s |
| Kael | ground | 1.0 (0.8 built) | same | step, top 0.18s, lost 0.02s, stall 0.00s, off 23.3 m/s |
| Kael | ground | 1.5 (1.6 built) | same | slide at the face, never tops (stall 2.25s) |
| Kael | ground | 2.0 (2.4 built) | same | slide at the face, never tops (stall 2.25s) |
| Vex | ground | 0.6 (0.8 built) | same | step, top 0.15s, lost 0.02s, stall 0.00s, off 15.5 m/s |
| Vex | ground | 1.0 (0.8 built) | same | step, top 0.15s, lost 0.00s, stall 0.00s, off 15.5 m/s |
| Vex | ground | 1.5 (1.6 built) | same | slide at the face, never tops (stall 2.10s) |
| Vex | ground | 2.0 (2.4 built) | same | slide at the face, never tops (stall 2.10s) |
| Albert | ground | 0.6 (0.8 built) | same | step, top 0.13s, lost 0.02s, stall 0.00s, off 20.5 m/s |
| Albert | ground | 1.0 (0.8 built) | same | step, top 0.12s, lost 0.00s, stall 0.00s, off 20.5 m/s |
| Albert | ground | 1.5 (1.6 built) | same | stop at the face, never tops (stall 2.30s) |
| Albert | ground | 2.0 (2.4 built) | same | stop at the face, never tops (stall 2.30s) |

The check asserts: a rim in reach is topped with at most 0.1 s stood at the face; a rim beyond reach never is.

## Not touched

- Dash kits (the archetypes own them). Only the generic `glide_handoff()` hook was added, and `launch_to` was made sure for upward targets.
- The network protocol. Movement runs on the owning machine, and remote hunters still use `net_follow`.
- Landing performance (branch `landhitch`).

## The owner's movement rules, every Hunter (`--move-rule-guard-check`)
`tools/move_rule_guard_check.gd` drives each of the 13 Hunters with a player's keys through the rules in briefs/DECISIONS.md that kept regressing, one `RULE ok|FAIL <hunter> | <DECISIONS line> | <measured>` row each: walking (and crouched) off a rim falls; Space held from the jump never glides, a second press does; opening the glider (from a jump, a fall, at rest) adds no horizontal speed and no lift; a fresh Space press 0.03 s and 0.15 s into an air Shift has the glider open within 2 steps, and the glide after it never jumps more than 2 m/s in a step; an overheated glider climbs back to the lip from 12 m at 0.4-0.62 of the full lift; no fall (free, glided, a dive, a landing) leaves horizontal speed, and a glide steers the same opened at rest or falling 14 m/s; WASD in the air beats the old farm's exp 6/s, turns a 5 m/s backward drift within 0.2 s and keeps a sideways speed; the farm avatar as each Hunter gives the Training Area's air and glide-open trace. Reds at 0.24.6 (docs/DEBT.md): Cinder's poof, Tenzo's Rock Hop, Sparkle's wire.

## Golden traces: nothing changes how a Hunter moves by accident

`--feel-golden-check` (`tools/feel_golden_check.gd`) catches silent feel changes from any branch. Each of the 12 Hunters plays nine fixed input scripts on the real match step at 60 Hz, on a flat square with a 5-terrace wall to the east: run, stop, jump, dash tap, dash hold, wall kick, double-press glide, dive, crouch walk. Each script is 2.5 s. Position (relative to the start) and velocity are sampled every 0.1 s and stored in `content/rules/feel_golden.json`. The check replays the scripts and fails if any sample is more than 0.05 m or 0.1 m/s off. It is deterministic (fixed steps, fixed seed) and never touches the save.

```
XDG_DATA_HOME=<scratch> godot --headless --path . -- --feel-golden-check            # verify
XDG_DATA_HOME=<scratch> godot --headless --path . -- --feel-golden-check --update   # rewrite the golden
```

When it fails: if the change was not meant to alter movement, fix the change. If the feel change is intended (a tuning pass, a new kit move), run with `--update` and commit the new `feel_golden.json` in the same commit, with the reason in the commit message ("feel golden: dash 10% shorter for Cinder, owner 11-09"). Update the targets above too if a measured row moved. A golden diff with no reason in the message is a review reject.
## The knock moment (`--knock-moment-check`; `KnockMoment`, scripts/match/knock_moment.gd)

The instant a Hunter is knocked (`Match.knock`), measured for all 12 Hunters holding LMB, RMB and Shift, with every key tapped again right after. One line per row: the source, ours, and what changed.

| Row | Source | Ours (now) | Changed |
|---|---|---|---|
| Held LMB (fire, bow draw, sword charge) | [footage] the victim shows the knock star and is a Wisp two frames later (5 fps), no shot of theirs follows; a knocked body has no attacks | `can_fire()` is false from the knock step; the draw, a buffered swing tap, the sniper wind-up and a sword charge are dropped on that step, nothing fires in the 0.5 s after | the bow draw and the buffered swing tap were cleared on the next tick, now on the knock step |
| Held RMB (a charge or aimed hold) | [game data] a knock cancels a held channel outright ("canceled if ... stunned, knocked"); it never completes | the hold is dropped on the knock step, no cast, the HUD's hold ring shuts | **fixed**: the kit's tick released the hold on the knock, which cast it (5 of the 7 Hunters with a hold open at the knock cast from the Wisp) |
| Buffered presses (a Shift or jump waiting for a move to end, presses parked during a dash) | [game data] nothing pressed before the knock goes off after it (the channel rule, above) | `dash_buf`, `jump_buf` and the dash-flow parking lot are cleared on the knock step | **fixed**: a press parked during a dash replayed 0.15 s after the knock (a deny buzz the player never asked for) |
| Dash in flight | [game data] the knocked body moves under its own rule from the knock (a knocked movement multiplier, 0.45 on rails); [est] so the dash ends where the knock lands it | `roll_t` ends on the knock step; a dash's carried speed is cut (the hit's own knockback still carries); the Wisp slides 0.05 m after (target under 0.5 m) | **fixed**: the dash carried the Wisp 2.3-4.4 m past the knock |
| Glide | [game data] knocked movement is its own rule | the glider folds on the knock step (`can` needs not downed); unchanged | no |
| Camera | [unseen] every clip we have is the attacker's view (constant zoom, no desaturation on their side; the red tint after Kael's execute is his Empowered); the victim's own view is not in the footage | 0.3 s at 0.55x time, a red flash, audio ducked, no zoom, no desaturation [est] | no (not measured) |
| Wisp control | [game data] the knocked body keeps moving under its multiplier from the knock; [footage] the victim is a Wisp within 0.2-0.4 s | the keys move the Wisp on step 1 after the knock (0.4x speed); the pop-in starts on the knock step and is done at 0.28 s | no |

Still different, noted for a later pass: a **stun** also releases a held RMB into its cast (`ArchKit.tick`), where the source cancels it ("canceled if stunned"); kit flights (`fly_t`) are the kits' own and were not audited here.

