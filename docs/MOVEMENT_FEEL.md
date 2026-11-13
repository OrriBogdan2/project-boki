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
  - Whether jump height is variable. Nothing suggests SUPERVIVE has it, and holding jump keeps the glider open, so **no variable jump height** was added.
  - Coyote time, jump buffer or a wall-kick press window. See "Jump grace" below.

## Jump grace

How early or late a jump press still counts. `[game data]` here is briefs/supervive-data/supervive_physics.md
(ext/agent-briefs); `[est]` is ours. No source number exists for any row, so none changed (rule: a row changes
only for a source value). `--move-feel-check` asserts the match rows (`coyote_jump_*`, `buffer_jump_*`).

| Window | Ours (match) | Ours (feel prototype) | Source | Evidence |
|---|---|---|---|---|
| Coyote: jump after running off a ledge | 0.12 s (`hunter.gd` walk-off sets `coyote`); +0.05 / +0.10 s jump, +0.15 s doesn't | 0.1 s (`FeelConfig.coyote_time`) | none: `bCanWalkOffLedges` false, so the source never walks off a ledge to need one (we allow it, owner ruling) | [est]; [game data] has no coyote field |
| Jump buffer: jump pressed before landing | 0.12 s (`Hunter.JUMP_BUFFER`); 0.05 / 0.10 s before landing jump on landing, 0.15 s doesn't | 0.12 s (`FeelConfig.jump_buffer`) | none: `JumpCooldown` and `AirJumpPressDuration` are named but sit in the encrypted code | [est]; [game data] names only |
| Wall kick, late press (after leaving the wall) | 0.2 s (`hunter.gd` `wall_touch_t`), or any time you face a wall within `WallMoves.FACE_REACH` 0.4 m | none (no wall kick) | none: `bCanWallJump` is the tall-ledge climb, not a press window | [est] |
| Wall kick, early press (before reaching the wall) | only the 0.4 m `FACE_REACH`: further out an air press opens the glider (or buffers a landing jump), never a kick on contact | none | none | [est] |

Footage can't settle these: a video shows the jump, not the frame the button went down. UE CharacterMovement
defaults aren't cited, since the data names no field for these windows.

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
| aim_side / aim_back / aim_back_fire speed_k (run with the keys across or away from the aim, over toward it) | 1.0 | 1.0 | 0.99–1.01 | [game data] no backpedal or strafe slow: one MoveSpeed per hunter, no directional row in the movement data (the only forward/back split decoded is rail grinding, 1300/1050); hero-ref footage has no clean walk-away run to frame (see ext/feel-backpedal-speed) |
| aim_back_3m_frames (frames to cover 3 m away from the aim, minus toward it) | 0 | 0 | <= 0 | [game data] same; 42 frames both ways at 4.55 m/s |
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
| felt dash gunslinger hold (Vex's Slipstep held from the press to its end; the tap row stays 4.8 m / 0.45 s) | 9.66 m / 0.725s | 7.14 m / 0.725s | 7 m ± 5% / 0.73 ± 0.035s | [footage] the longest of Ghost's three slides is ~1.6x the fitted tap; the source gives no hold length (docs/heroes/gunslinger.md) |
| flue_lift_hold_s / flue_hover_m (Cinder's Flue Flight: the hang at the ember ring, the height by its end) | 0s / 0.45m | 0.167s / 0.45m | 0.13–0.2s / 0.4–0.5m | [footage] Felix hangs 0.13–0.2s at the ring (15 fps, casts 1–2), flies low |
| flue_turn_deg_s (the flight's heading, cursor swung a right angle) | 120 deg/s | 90 deg/s | 85–95 deg/s | [footage] Felix's jetpack peaks at ~85–100 deg/s (cast 2's end; cast 1 holds 52–67) |
| coyote_frames | 7 | 7 | >= 6 | FeelConfig 0.1s |
| jump_buffer_frames | 6 | 7 | >= 7 | FeelConfig 0.12s |
| freefall_1s_depth | 6.37m | 7.20m | 6.8–8m | [game data] 14.7 m/s² capped at 12 m/s ([footage] ~8m) |
| glide_open_press_frames (second press) | 1 | 1 | <= 1 | [guide] |
| glide_open_hold_s (scripted input only: a player's Space held from the jump never opens it, glide_press_only) | 0.150s | 0.117s | <= 0.12s | tap/hold split |
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
| land_carry_hop_held / drop4_held (1 m hop, 4-terrace drop, keys held: touchdown / run speed) | | 1.00x / 1.00x | 0.98–1.02 | [game data] landing keeps what you carried |
| land_carry_glide_held (glider let go 2 m up, keys held) | 1.14x | 1.05x | 0.98–1.07 | the glide's extra bleeds at air.drag 2/s (decision 0052) |
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
- `--mantle-fling-check` (tools/mantle_fling_check.gd, owner bug 11-11): running jumps, ground and air dashes, glides and fast launches (6-19 m/s, also with a jump in the fling window) into a long ledge one and two terraces high, 0 to 80 degrees off the face. Over the lip you leave at most `MantleCarry.exit_cap` (1.2x run speed, ~5.5 m/s; a fling at most `Hunter.FLING_SPEED`), the rise carries you at most 2.5 m along the face (speed over the cap bleeds at `MantleCarry.RISE_BLEED`), and the wall never pushes you.
  - Before (main 88b06b9): a 19 m/s launch glancing in at 65 degrees kept its speed along the face, slid 4.3 m up the rise and left the top at 13.9 m/s, flying 8.3 m; a fling in the window kept it too (14.2 m/s). 103 of 187 tops over the cap, 19 rises over 2.5 m.
  - After: fastest exit 5.5 m/s (a fling 7.4), longest slide 2.4 m, longest flight 4.6 m (a fling), 181 tops.
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
  - Steering is `Loco.glide_step()`:
    - 420°/s at cruise, in wider arcs above cruise (down to 45%).
    - 16.25 m/s² toward where you steer ([game data] GlideTargetXYForce 162,500 / Mass 100, `HunterMove.glide_accel`, decision 0027): a 90° turn ~0.38 s, a reversal ~0.6 s at cruise. Over-speed bleeds back (tuning.json glide.drag).
    - Steering more than 115° against your heading brakes at 36 m/s². Letting go drifts.
  - Cruise 5.0 → 6.5 m/s and sink 2.2 → 1.4 m/s. The owner found the glide "falls a bit faster and feels weaker than SUPERVIVE".
  - The glider opens falling at least 0.85 m/s ([game data] GlideStartFallSpeedMin, `Loco.glide_start`, match and farm): a rising jump is cut at the open, no float-up, and the jump pad's own 2 m/s cap went with it. The canopy then catches a fall at 60 m/s² (ours: the source's matching fastest-fall clamp is locked; [guide] it opens "instantly").
  - Space opens the glider after 0.1s (a tap is a jump). The glide button (Mouse 5) opens it at once (`inp.glide_btn`, local input only).
  - **Dive** (`GlideDive`, `HunterMove.dive_*`, all [game data]): hold crouch (Ctrl) under an open glider and the canopy folds into a plunge toward 32.5 m/s at 35 m/s², the keys steering at a quarter of their glide force. Let go, come within 3.5 m of the ground (or the island's lip over the abyss) or hold for 10 s and the glide catches you again; the drop you pull out of becomes speed, capped at the glide's 15 m/s max. The key is ours: the source names no dive input, and Space is the glider itself. The folded pose is local-only (the dive isn't in the net snapshot).
  - The abyss lift's brake zone rises at 3.5 m/s per metre left (was 2). Updrafts grab at 45 m/s² (was 30).
- **Heat** (owner, Nov 2: "lasts too long, not punishing enough"): a level glide overheats after 9s (was 14). Hits heat it 3x (was 2x). An overheated glider burns ~3.5% of max health a second in 20-damage ticks, flies at 0.5x speed and sinks at 5 m/s.
- **Feathering** [est] (tap the glider on and off instead of holding it). Constants: `FEATHER_*`, `lift_t`, `glide_off_t`.
  - Open and close are instant, with no penalty for rapid toggles. The glider reopens with 5% of its heat room left (was 15%).
  - While the glider is closed in the air its heat cools at 0.04 per second (was 0.06) (a full glider is 1.0). The ground still cools it fastest: [footage] "it only really cools on the ground".
  - Letting go falls like any jump (`Loco.air_step`, decision 0052): the glide's extra over run speed bleeds at the air drag, so a let-go 2 m up lands at 1.05x run with the keys held (was 1.14x: for 0.6s the glide's speed and steering were kept).
  - The first 0.3s of an abyss lift (the "rapid upward impulse" [wiki]) heats at 0.4x a level glide (was 1x; lowered with the shorter glider so feathering still beats holding). Holding the lift past that costs the full 4x. So short lift taps that coast on the impulse are the skilled, efficient way across.
  - Unconfirmed: what SUPERVIVE's feathering exactly does. Public pages don't describe it. These numbers are ours, to be checked against the owner's Nidhogg reference video.
- **Jump out of a dash** (`Loco.dash_jump_keep`, tuning.json `dash.jump_keep`, 0.75): the dash ends and the jump carries 75% of its speed, the rest is air drag's; the farm does the same (it used to keep the whole dash, the match 55%: a one-step 45% stop). A Shift's speed is `Loco.dash_hv` in both places (the per-hunter ease too).
- **Dash into glide** (owner 11-08, `Hunter._dash_into_glide`, docs/decisions/0022): a fresh glide press (second Space, or the glide button) at any moment of an air Shift dash ends the dash that step and the glide carries the dash's velocity exactly. No handoff boost: the glide's drag (`Loco.glide_step`) bleeds it back toward cruise within ~1.5 s, faster above the hunter's `glide_carry` cap (content/rules/tuning.json). A kit's rush or special movement (`move_kind` other than "dash") is not cancelled; `--air-control-check` tries every Hunter's own air Shift and FLAGS the ones a press doesn't cancel (Motley's). A kit that ends its dash with a stop skips it when the glide took over (Vex's air slide). The boost trail and whoosh still play when the glide starts well above cruise.
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
- **Camera framing vs the source (parity pass, 2026-11-09, `--cam-framing-check`):** sources are the hero-ref sheets' 1080p measures [F] (no frames on the box that wrote this, so their numbers, not new pixels), camcal above [F] and the game data [D]. Numbers live in `content/rules/camera.json`.

  | Measure | Source | Ours before | Ours now |
  |---|---|---|---|
  | Pitch | 65.5° ±1.5 [F camcal]; Ghost's nuke disc 153x135 px (0.88) fits it a few degrees above the centre | 66° | 66° (inside) |
  | Horizon, roll | none on screen (the top edge looks ~50° down), never rolls [F] | same | same |
  | Vertical lens | ~32° (25–34) [F camcal] | 32° | 32° (inside) |
  | Ground across 16:9 | ~37 m: Void's 3.5 m Black Hole [D] reads ~2 bh (90 px) and run pans of 205–250 px/s at the data's 4.4–4.8 m/s [D] both give ~51 px/m | 23.5 m | 23.5 m (narrower) |
  | Hunter height on screen | mediums 90–100 px of 1080 (8.3–9.3%), Oath 107 px, Elluna 67 px [F] | 3.8–11.1% by Hunter (gunslinger 6.0, bulwark 11.1, tender 3.8), median ~1.3x smaller than the source's | same |
  | Feet below the centre | ~3–4% [F camcal] | 3.0% on level ground | 3.5% (`rise` 1.0 -> 1.2 m) |
  | Cursor lean, how far | not measurable in the sheets: the view sits still through 1–2 bh moves and pans with the aim (venator) | 42% past 1.4 m, cap 7.5 m; at sneak zoom a full lean up-screen put you at the bottom edge | same share and cap, also held to the screen's room (perspective-correct), you stay >= 1.5 m inside |
  | Cursor lean, how fast | not measurable [F]; a blink dash takes ~0.5 s to catch up (dredge) | eased 6/s; follow 15/s | unchanged |
  | Glide / drop zoom | only ability zoom-outs (Vireo's R, Oath's ult) [F]; data names an abyss zoom, no value [D]; abyss zoom not determinable (below) | glide 1.25x, drop 1.05–1.7x, sneak 1.45x | unchanged |
  | `CameraDistance` 5500 uu [D] | 55 m, meaning unproven (the ADS row is a fog-of-war radius); as an arm length it would need a ~21° lens, against the footage's ~32° | not used | not used |

  - Not matched: the distance. The source shows ~1.6x more ground across and draws its Hunters ~1.3x bigger: its Hunters are about twice the size of the world ours are, which no camera can match. 36 m back would show the source's ground but shrink tender to ~2.5% of the screen (the owner wants silhouettes that read at gameplay zoom); 18 m would match the Hunters' size on half the source's view. 23 m sits between the two, so it stays. Matching both means drawing Hunters larger (`Hunter.VIS_SCALE`), a model call for the owner (docs/DEBT.md).
  - Abyss zoom: **not determinable** (2026-11-12). The data names a camera zoom for the abyss next to the slow fall, with no value [D]. No reference frame shows the player's own Hunter below an island's lip: the cliff demo cuts to the Hunter standing on the pillar while the target falls, and the walkway demo stays at lip height [F]. So there is no distance or rate to measure, and `CamRig` gets no abyss state. Below the lip the view still sinks with you at the same size (`CamRig.follow`, `p.y < 0`), with the glide's 1.25x when the glider is open. To settle it, use a clip of the player stepping off a lip and falling for 2 s or more before a glide or a mantle brings them back.
  - GPU pair (`--cam-framing-shots`, 1280x720): before job 20261109-101651-10739 (origin/main), after 20261109-101658-27648, `out/framing_*.png`. The default view moves 4 px (feet 381 -> 385). Sneaking with the cursor on the top edge, the lean stops at 7.8 m instead of 8.1 m, so you sit 55 px above the bottom edge instead of 45.
- **Settings:**
  - "Expedition camera" is now "Camera".
  - The style and follow mode also apply at home (`CamRig.apply_settings`). The farm keeps its own wider framing (`Home._apply_cam_settings`).
- **Garden: framing you and a Boki (`HomeKinFrame`, `scripts/home/kin_frame.gd`, `--cam-framing-check`):** the farm camera sits at its wide framing, so petting, feeding, a ball toss or a Boki's card used to play out small in the middle of the farm.
  - Pet, feed or toss a ball to a Boki, or open its card, and over 0.3 s the view eases 30% nearer (`CamRig.dist_mul`) and onto the middle of you both, with the cursor lean off.
  - It eases back over 0.3 s when you move 2.5 m from where you started, when the Boki is more than 7 m per unit of zoom from you (8.4 m at the arrival zoom 1.2), or, opened by its card, when the card closes.
  - The garden's wheel zoom (0.55-1.6) is unchanged and stacks with it; a match never ticks the frame.
  - The check asserts the ease timing, both of you on screen at the wheel's closest, arrival and widest zooms (169/368/411 px from the nearest edge at full reach), and each way it lets go.

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

**Not a skate (fixed in the check):** the old open row, "Claire's rink skate (E held, X) meets the wall head-on (within 16 degrees of the normal)", was the check's own ice. In those cases no skate runs (`rinkrun` empty); she hit a 45-degree face 0.7-1.8 m short of the wall: her Rink Wall, cast toward the wall by the held E case (only the tapped E was aimed back) and left standing 6 s into the cases after it, met within 15 degrees of its face. The check now aims the held E back too (`CAST_BACK`) and clears placed walls between cases (`m.verbs.clear()` in `_fresh`); `COMMITS` is empty and all her cases bounce. Source for her real skate at a wall: none. `briefs/hero-ref/tamsin.md` (Shift window f169-f296; key frames 0195, 0241, 0243) and `briefs/supervive-data` show no skate meeting a wall. The one skate line, "Follows the movement input; the cursor is elsewhere" (f193-f199), is already ours: `_tick_rinkrun` steers toward the move keys. So nothing in the skate changed.

**Walking jump into a wall (`walkjump@` rows, footage pass 11-11).** The question: does the source bounce a plain jump off the walk, so `BOUNCE_MIN_INTO` (4 m/s) and `BOUNCE_HEAD_ON_DEG` (20) should come down? Frames read on `ext/hero-ref-footage` (1 bh = 1.8 m), 5 fps unless noted:
- Shiv `dancer` 0124-0135 (the jump at 303.8 s) and Brall `juggernaut` 0249-0268 (jumps and the Air Slam at 410-412.85 s): practice range, every jump starts and lands in the open, clear of the pillars and ledges. No wall contact.
- Tetra `breah` 0869-0917 ("Wall Stacking", 4 fps, real terrain): rock walls raised against a cliff; nobody jumps into a wall.
- Celeste `tamsin` 0489-0576 (match footage): fights among cliffs and structures; at 5 fps a jump is 2-3 frames and no plain jump is seen meeting a wall.
- Tetra `breah` 0391 (Rockwave card): "Allies can hop over friendly Tetra walls by jumping against them". The one source line on jumping against a wall is a hop over it, not a rebound.

So the footage shows no wall bounce from a walking or running jump, and no frame gives an into-speed or angle to set either constant from. Both stay as they are (estimates). `--wallmove-check` now walks Tenzo (slow kit) and Vex (fast kit) at the wall from a standstill, jumps, and holds the keys; a row fails if the bounce disagrees with `BOUNCE_MIN_INTO`:

| Row | Walk speed at the jump | Into the wall | Result |
|---|---|---|---|
| Tenzo walkjump@25 | 4.65 m/s | 4.21 m/s | bounces |
| Tenzo walkjump@35 | 4.65 m/s | 3.81 m/s | stops |
| Vex walkjump@25 | 4.55 m/s | 4.12 m/s | bounces |
| Vex walkjump@35 | 4.55 m/s | 3.73 m/s | stops |

A walking jump bounces between 20 and about 30 degrees off the normal (where `cos` x 4.55-4.65 m/s drops under 4). Tenzo walks a little faster than Vex at the wall (4.65 vs 4.55 m/s), so the slow/fast split doesn't show on a walking jump. **Suggestion (not built, parity):** with no source clip either way, the 3 m/s guess would make every walking jump up to about 50 degrees off the normal ricochet. Settle it with a clip of a hunter jumping at a wall at walking speed.

## Physics pass: SUPERVIVE's game data (`physics76`)

Tunables are in `content/rules/hunter_move.json` (`physics`), read by `HunterMove`; values and sources are in SUPERVIVE_DATA.md.

- **Gravity** 30 (x1.2 falling) → 14.7 m/s², one gravity. **Jump** 9 → 6.8 m/s (the data's 7.5 would let jump + mantle top four terraces). **Wall kick** rise 0.9 → 0.8m, so jump + kick + mantle still tops 4 terraces and not 5.
- **Fall cap** 10 → 12 m/s, easing to 10 m/s from 1m to 16.5m under the lip. **Point of no return** 13 → 17.5m under the lip: about 1.9s of falling to save yourself (was ~1.4s).
- **Air control** (`Loco.air_step`, owner 11-08: the data's low AirControl is overruled): WASD adds 32 m/s^2 onto what you carry, 2.5x that against your drift (a 5 m/s backward drift turns forward in ~0.07 s), never past your run speed along the keys; speed above it (dash, knock) bleeds at 2/s. The farm uses the same step. Numbers in content/rules/tuning.json `air`.
- **Glide height hold** (`GlideLift.sink`): more than 8.5m over the ground (or the lip) the glider sinks at 3.5 m/s. The drop never becomes speed (owner 11-08 item 8).
- **Mantle**: topping out sends you onto the ledge at max(0.6x run speed, 3.5 m/s). The no-jump pop is 2.6 m/s (was 3.2; lower gravity floated it twice as long).
- **Holding Space never opens the glider** (owner 11-08, said twice). With a player's keys (`inp.glide_press_only`, set in `Match`) the glider opens only from a fresh press in the air: a second Space press (`Hunter.do_jump`) or the glide button's press, or a pad/updraft auto-glide. Opening the glider uses the press up (owner 11-09): once it folds (a heal, a dash, a knock, a kit's wind-down) it stays shut while Space is still held, until a new press. A press while a move or cast keeps the glider shut (`_glide_armed`) opens it as the move ends, if still held; letting go or landing clears it. Space held from the jump, or while LMB/RMB/abilities are held (Kael's RMB, Lace's and Albert's LMB; Albert's perfect launch no longer opens it by itself off a drop), never opens it. Every Hunter's air Shift takes a press during or after it, except Sparkle's wire (her keys do nothing while it holds). Scripted input (bots, checks, demos) keeps the old hold-to-open (`GLIDE_ENGAGE`). Home islands follow the same rule. Measured by `--glide-hold-check`. The earlier tap/hold split only added the second-press route next to the hold route and then shortened the hold wait (0.15 -> 0.1 s), so it never went away.
- **Glider at any heat, softer deep lift** (owner item 63): the glide input opens the glider at every heat, overheated or not (no heat floor, no lockout after an overheated one closes); overheated it burns you and lifts at half strength. The deepest lift is 30% softer (climb cap 26 -> 18.2 m/s; speed per metre of depth 1.7 -> 1.1) at the same heat cost. Measured by `--glider-heat-check`.
- **Heat on the canopy** (`GliderHeat`): the glider cloth warms toward ember with heat, an overheated glider trails a thin smoke, and one burning over the abyss at half strength flickers, so teammates and enemies read a gliding Hunter's heat from the world. Two toon-shader parameters (`canopy_heat`, `canopy_burn`) on the canopy's own material: no extra draw calls, no burst on open or close. The heat (4 bits, 15 = overheated) and the burn state ride the hunter flags (bits 19-23); no Net shape change. Measured by `--glider-canopy-check`; shots by `--glider-canopy-shots`.
- **Abyss bounce** [est]: the lift reaches the lip at 4.5 m/s (was 3.5), floating ~1.6m over it.
- **Feathering**: the glider no longer cools in the air, and a lift's first 0.3s heats like a level glide (was 0.4x). The slower gravity had made coasting between taps so cheap that feathering went 4.8x as far as holding; it is 2.0x now.

## Slow and haste ramp (`--move-feel-check` slow_* / haste_* rows; docs/decisions/0022)

The source has no ramp time: a Slow or a speed boost moves the speed cap at once, and the body follows it under the ordinary movement, down at the walking brake (BrakingDecelerationWalking 22.2 m/s² plus GroundFriction 1 × 2 per second of speed) and up at MaxAcceleration (47-54 m/s²). A 30% Slow on a run settles in about 0.05 s either way. Ours: every Slow (`slow_t`/`slow_k`, from kits, hazards, Boki and merges) and every haste (`haste_t`, the kits' `pace()`, a `move_speed` buff) multiplies into the one cap in `Hunter._physics`, and the ground step follows it with `ground_accel` up and `HunterMove.brake_rate` down (decision 0020). The check runs one kit per weight class (thief, gunslinger, juggernaut) and the haste on the medium kit.

| Key | Measured | Target | Source |
|---|---|---|---|
| slow_land_0p1s / 0p3s (speed over the run before it) | 0.70 / 0.70 | 0.69–0.71 | [game data] the brake: ~0.05 s |
| slow_end_0p1s / 0p3s | 1.00 / 1.00 | 0.99–1.01 | [game data] MaxAcceleration: ~0.03 s |
| haste_land_0p1s (over the hasted run) | 1.00 | 0.99–1.01 | [game data] as a Slow ends |
| haste_end_0p1s (over the plain run) | 1.00 | 0.99–1.01 | [game data] as a Slow lands |

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
- **Free fall:** a fall never gives more dashes than the ground does (the charges plus the long dash). Each hero's air dash itself is item 183's audit.

## Air velocity: kit casts add to it, never overwrite it (DECISIONS 11-08; the eight kits outside the slice)

Rule (briefs/DECISIONS.md 2026-11-08): in the air WASD accelerates toward the keys, counter-steers hard and drag
bleeds speed above the cap (`Loco.air_step`); nothing overwrites the air velocity. A kit move may still own it when
it is a sourced displacement (a dash, skate, Rock Hop, barge, lob, knock or pull, cited to its KIT_PARITY row);
anything else adds to what you carry through `HunterMove.push` (the path `Hunter.impulse` and `BokiHit.knock` use).
Every horizontal `vel` write in Bjorn, Claire, Tarek, Grimble, Ryzz, Pip, Sable and Ostra's kits and helpers
(Vex, Zedran, Hem and Cinder are the slice pass's table). Shift moves that run on `roll_dir`/`roll_speed` are
dashes and not listed per site.

| Hunter | Site | What it writes (in the air) | Class | KIT_PARITY row / change |
|---|---|---|---|---|
| Bjorn | `BulwarkKit._spin_hit` | `+=` the 360 Smash's slide, grounded only | not airborne | Dash (Spin Dash) |
| Claire | `RimewrightKit._rinkrun_end` | skate ends in the air: keeps the skate's own speed (the ground branch brakes ×0.3) | skate, keep | Dash (hold, release stops) |
| Claire | `RimewrightKit._rime_hold_body` | the Rimelock statue: rooted, zero after its slide | sourced root, keep | R (body as ice) |
| Tarek | `DolmKit._punch` | air punch: was the aim × max(step, speed), wiping a sideways drift | **overwrite, fixed**: `HunterMove.push` along the aim | LMB (hold punch) |
| Tarek | `BreahSlam._tick_hop` | the slam's hop into the circle: its arc plus keys × `nudge` 1.3 m/s | sourced hop, keep | RMB (hold slam, centre stun) |
| Tarek | `BreahSlam.fire` | slam out of a glide: glider folds, speed ×0.25, plunge | sourced, keep | RMB (glide slam) |
| Tarek | `BreahSlam.arc` | the leap and the hop's jump arc | sourced leap, keep | RMB (jump to leap) |
| Tarek | `BreahHop._touchdown` | zero before the skid on the new rock, grounded | Rock Hop, not airborne | Dash (Rock Hop) |
| Grimble | `DredgeKit._hop` | the Anchor wind-up hop, skipped in the air | not airborne | E |
| Grimble | `DredgeKit._start_dive` / `_tick_dive` | air smash: straight down onto its ring (a pounce in it carries) | sourced plunge, keep | E (slam, dunk) |
| Grimble | `DredgeKit._tick_stop` | barge end: speed limited to 3 m/s, direction kept | barge, keep | Dash (barge) |
| Ryzz | `MageKit._exit_run` | Wirerun end: `HunterMove.dash_exit` hand-over at run speed | dash, keep | Dash (lane at 40 m/s) |
| Ryzz | `MageUlt._hold_air` / `_fall_tick` / `_strike` / `drop` | the ult's hover, fall and crash place her; zero speed | sourced, keep | R (launch, recast, crash) |
| Pip | `TenderKit.drop_all` / `_call_home`, `CareUtil` carry | the carried or pulled body is placed, zero speed | pull / carry, keep | R (revive and pull), Passive (carry) |
| Sable | `ThiefKit._blink` | the dagger blink: teleport to the ground spot, zero speed | sourced, keep | E (dagger, forced return) |
| Ostra | `OstraKit._arrive` | the Trade lob's landing writes only `vel.y` | none horizontal | Dash (lob, swap) |

`--dolm-combo-check` asserts it after the fixed cast: an air punch east keeps a 3 m/s drift south and steps her
east, and holding the keys against the drift turns it within 0.25 s.

## Edge knocks against the source (`--abyss-check` section 8; PARITY FIRST, decisions 2026-11-07)

Asked: what the source does when a Hunter is knocked off an island. Evidence read: `supervive_physics.md` (Abyss rows), `supervive_kits.md`, the wiki notes in `docs/SUPERVIVE_FEEL.md`, the hero-ref sheets (Kael, Grimble, Breah, Motley). **The source data answers almost none of it.** The footage sheets show only that an Air Slam or a dunk over the abyss ends in a KNOCK callout (juggernaut.md 0291-0292, breah.md 0989). So most rows below are [est] ours, kept as they are and measured; only the last fix changes behaviour.

| Question | Source | Ours (measured) | Verdict |
|---|---|---|---|
| Glider open at once off a knock, mid-knock or after? At what heat? | Nothing published (`bAllowsMantlingFromAbyss` true; hits on a glider drain heat, wiki). | A shove over 4 m/s shuts the glider for 0.4 s (`kb_t`); the longest knock is 0.35 s, so a held glide opens 0.42 s in, after the knock. A shove of 2.5 to 4 m/s opens it mid-knock (0.12 s). Heat never gates it: an overheated glider opens the same. | [est] kept; asserted for hard knocks at 0% and 100% heat. |
| Overheated glider out of the abyss | Owner decision: lifts at half strength while it burns. | Peak lift 6.1 vs 11.5 m/s from 7 m, 8.7 vs 16.7 from 12 m (0.53x, 0.52x); back at the lip in 1.2 to 1.6 s. | Matches; now asserted (it had no check). |
| Ledge grab or mantle while knocked | `bAllowsMantlingFromAbyss` true; no knock rule. | A knocked Hunter catches a rim from below; only a launch over 8 m/s within 0.3 s of the knock waits, and a stun, root or a fresh knock ends a rise. | [est] kept (section 2). |
| Kill credit after a knock-off | Not published. | The last attacker keeps the abyss kill for 4.0 s after a hard knock (`Match.on_fell`, `kb_t`), then the fall is nobody's. | [est] kept. Gap, not changed: Grimble's reel, Motley's Trade and a soft shove (under 4 m/s) never start the 4 s, so a fall after them credits nobody. Fixing it needs the tow and the swap to carry the caster over Net (`Net.VERSION`). |
| Walking or being shoved off | Source `bCanWalkOffLedges` false; owner: always allowed. | A person is never blocked. **Fixed:** a bot's edge guard held a bot at the rim after a 2.5 to 5.8 m/s shove, so the knock-off failed on bots only. The guard now ignores a knock (`knock_t`) and 0.6 s after a hard one. | Asserted: 4.5 m/s at the rim carries player and bot over. |
| Grimble's arm | Pierces terrain, pulls the first target, which is STUNNED all the pull; Grimble is GROUNDED. | Stun kept on the foe through the reel (so no glider), dragged over rocks and cliffs, the abyss takes it. Hover over the abyss while the arm flies is an owner ask (items 31, 75). | Matches. |
| Kael's chain | Attaches to a foe or wall; recast pulls him about 5 bh in 0.4 s. | A dash toward the anchor: it ends over the abyss like any dash and the glider and lift take over. | Matches. |
| Motley's Trade | Swaps a foe and Motley. | Owner override: hover-swap over the abyss. Foes land at Motley's spot, so a swap from over the abyss drops them. | Matches. |

Open for the owner, not built: a hit on a balloon (a glider under the lip) spikes it in the wiki notes, ours spikes only when the heat runs out (`Hunter.hurt`); and the 4 s credit window above.
## Air velocity in the slice kits (DECISIONS 2026-11-08, `--*-combo-check` "air steer")
SUPERVIVE's air control is the one model in a match: the keys add acceleration onto what you carry (`Loco.air_step`), counter-steer is strong, speed over the run cap bleeds under air drag, and nothing overwrites air velocity. Every place in the four slice Wardens' kits (scripts/arch/kits: gunslinger, juggernaut, archer = pin_*, ashwick) that writes a Hunter's horizontal velocity, classified. A **displacement** is a move that owns the velocity while it runs (a dash or pull in `roll_t`, a knock, a hold), so writing its start, exit or contact replaces only its own speed, never the keys': kept, with its KIT_PARITY row. An **overwrite** wipes air speed no source asks for: fixed.

| Site | Write | Kind | Row (docs/KIT_PARITY.md) / fix |
|---|---|---|---|
| `gunslinger_kit._slide_end` | air slide ends: speed x0.25 | displacement exit (her own dash's speed; the keys steer next step) | Vex Dash: air tap at 2/3 of the hold (patch notes, gunslinger.md "Small mechanics") |
| `gunslinger_kit._fire_needle` | `h.impulse(-aim * 6)` | recoil, already the shared impulse | Vex E: recoil 6 |
| `juggernaut_chain._hold_taut` | removes the outward part at the chain's length | leash constraint (subtracts, keeps the rest) | Kael E: tether 24 m |
| `juggernaut_chain._arrive` | pull's speed x carry | Warchain pull exit | Kael E: impulse 22 m/s, sling |
| `juggernaut_chain._jump_out` | pull's speed x jump_carry | Warchain pull exit into a jump | Kael E: sling, steer |
| `juggernaut_chain._stop("stopped")` | zeroed horizontal speed | **overwrite in the air** (a snap, stun, root or knock mid-pull left him hanging at 0 m/s, the knock wiped) | **fixed**: zeroed on the ground only; in the air the pull's speed carries under air drag (`--juggernaut-combo-check` "stopped mid-air", 17.6 m/s, was 0) |
| `juggernaut_kit._tick_lunge` | zero on the foe | contact stop | Kael RMB: Lunge (context) |
| `juggernaut_drop` start, hang, dive, impact | zero, held, then plunged | Meteor Drop owns the body | Kael Air RMB: cursor disc |
| `pin_ult._loose` | `vel -= aim * 2.5` | recoil, additive | Hem R: 3 empowered shots |
| `pin_spirit.end` | zero after the snap back | teleport to the walk's entry | Hem Dash: Phase Walk |
| `ashwick_kit._keep_poof` | poof speed x air_keep | air dash exit | Cinder Dash: air poof 6.8 m/.28 s |
| `ashwick_kit._bash_impact` | bounce back off the foe | recoil, contact stop | Cinder Dash: stops on first foe |
| `ashwick_jet._leap` | flight speed x `Loco.dash_jump_keep` | flight exit into a jump | Cinder R: fly forward |
| `ashwick_jet._land` | speed x0.3 | grounded (not air) | Cinder R |

The other kept writes stay in the kit rather than moving to `Hunter.impulse`: that path is built for hits (fortify blocks it, knockback resist scales it, and above 2.5 m/s it starts a knock that swaps the keys for knock steering), and each of these writes replaces only the move's own speed. Each kit's combo check casts one of its air moves 40 m up and asserts the keys win 3 m/s across the heading within 0.3 s after it (`ArchetypeCheck.air_steers`): Vex air slide and Longneedle, Kael snapped pull, Hem air roll, Cinder air poof.

## Walking while attacking (fire-move parity, 2026-11-09)
Share of the plain run while LMB is held, during each charge or hold, and just after release. Measured in the
real match step: ground walk speed on a flat strip, 60 Hz, steady part only. Sources: `[data]` = the tooltips in
briefs/supervive-data/supervive_kits.md (none of them gives a self-slow number); `[F]` = briefs/hero-ref/<file>.md
footage; `[wiki]` as above; `[?]` = the source can't settle it, so ours stays. Rule (briefs/DECISIONS.md 2026-11-07, parity first): a row changes only when the
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
| Sparkle (Joule) | 0.90 (`fire_slow`) | Storm Rod hold: full **[?]** | full | [F] vireo.md (5 fps): all 3 holds (0043-0048, 0057-0062, 0078-0083) are planted with no move input or camera pan; the only runs (0154-0160, 0270-0274) have no cast; no other Joule clip in the notes or supervive-data shows a hold, so walk-or-root can't be told | kept: full until a clip of a hold with movement input; ext/sparkle-dash-feel's 0.82 has no source either |
| Motley (Void) | 0.90 (`fire_slow`) | Snap wind-up 0.75 (`cast_slow`); Trade drift 0.3 | full after the 0.15 s recovery | [patch] Snap slows Void while casting (25% less) | kept |
| Neve (Celeste) | full (kit-fired darts; the weapon's `fire_slow` 0.9 never applies) | Ice Spear aim: full | full | [F] rimewright.md: throws while walking or skating | kept (matches) |
| Meeko (Elluna) | full (`fire_slow` 1.0) | Burrseed wind-up 0.5 (`wind_move`) | 0.5 until the seed leaves | [F] mooshmoosh.md: keeps walking while firing | kept |
| Sable (Shiv) | 0.90 (`fire_slow`) | none | full | [F] dancer.md: 77-86 px/s while firing against 113 (0.68-0.76), "not confirmed" | kept (unconfirmed; see below) |

Open, not built (suggestions): Sable may slow more while firing (0.7-0.75 if a straight-run clip confirms it);
Neve's dead `fire_slow` 0.9 on hoar_fan could go; Kael's Searing Wave charge (0.55) and Tenzo's punch hold have no
source number either way. Sparkle's Storm Rod hold [?] needs a clip of her holding the Rod while a move key is held.

## Dash streak: the same ribbon on every dash (`DashStreak`, `--dash-streak-check`; owner bug 181)

With no ring, disc or burst on a dash (DECISIONS), some dashes read as a blink. Every Hunter's dash (ground, air, chained) now lays one pooled, flat ribbon in their ability colour from the body anchor (0.9 m up) along the path. It is 0.6 m wide, starts at 0.8 opacity and fades out in 0.2 s, so rivals read the line at match zoom. It sits under a kit's own dash look (Kael's Blazing Spirit, Grimble's junk roll, the flame, ink and blink trails) instead of replacing it: the source shows streaks and ribbons on top of the body look (Brall's flame streaks, the Combat Slide's ribbon trails). `--dash-streak-check` asserts it for all 12 Hunters; `--dash-streak-shots` renders the strips.

## Glider trail: a side-coloured line behind every open glider (`GlideTrail`, `--glide-trail-check`)

In a 30-Hunter match, squads gliding in from the sky were hard to pick out at range. Every open glider now draws one thin ribbon (0.3 m at the glider, narrowing to nothing) at canopy height, in the Hunter's team colour lightened a quarter toward white: the colour of their glider stripe and ground ring, so allies and each rival squad read apart. A point fades out in 1.2 s, so the line is about one glide-second long and is gone soon after the glider folds. No burst when it opens or closes (DECISIONS). It is one pooled `ImmediateMesh` per glider (one unshaded draw, turned to the camera), the same on every preset, and sits under a skin's own cosmetic trail (`Gliders.trail`). The trail is taken when a glider opens and goes back to the pool once its tail has faded. `--glide-trail-check` asserts both, and the colour. `--glide-trail-shots` renders two squads from 40 m and 80 m, with and without the trails.
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

## Golden traces: nothing changes how a Hunter moves by accident

`--feel-golden-check` (`tools/feel_golden_check.gd`) catches silent feel changes from any branch. Each of the 12 Hunters plays nine fixed input scripts on the real match step at 60 Hz, on a flat square with a 5-terrace wall to the east: run, stop, jump, dash tap, dash hold, wall kick, double-press glide, dive, crouch walk. Each script is 2.5 s. Position (relative to the start) and velocity are sampled every 0.1 s and stored in `content/rules/feel_golden.json`. The check replays the scripts and fails if any sample is more than 0.05 m or 0.1 m/s off. It is deterministic (fixed steps, fixed seed) and never touches the save.

```
XDG_DATA_HOME=<scratch> godot --headless --path . -- --feel-golden-check            # verify
XDG_DATA_HOME=<scratch> godot --headless --path . -- --feel-golden-check --update   # rewrite the golden
```

When it fails: if the change was not meant to alter movement, fix the change. If the feel change is intended (a tuning pass, a new kit move), run with `--update` and commit the new `feel_golden.json` in the same commit, with the reason in the commit message ("feel golden: dash 10% shorter for Cinder, owner 11-09"). Update the targets above too if a measured row moved. A golden diff with no reason in the message is a review reject.

### Golden re-record for 0.24.4/0.24.5: every drifted row classified (ext/feel-golden-0244)

The golden recorded at 4c76f338f failed 83 rows on main 88b06b9e7 (GATE_TRIAGE_0244 counted 84 with the older tool;
the shove noise made the count vary). Every row was traced to the commit that moved it before the golden was
re-recorded. Nothing was found to be a regression, so no code or data changed and no tolerance moved.

How: the check now runs every script in a cleared space (no mobs, no Boki, the other Hunters parked; the tool half
of ext/feel-golden-determinism 9841c4f97). The same cleared tool recorded a clean baseline at 4c76f338f itself
(repeatable, 0 failures). The 4c76f338f golden then still failed 16 rows against that baseline. Those were shoves
from a mob or bot that the old golden had recorded: the velocity matches and the position stalls (class A). Then I
walked the 318 first-parent commits from d255acbee to 6421b711d (main's tree), recording traces at each commit. A
binary search found each commit after which some row first differs from the last recording, and repeated the
search from there. It found 10 change points. Inside the movement-unify and supervive-movement merges, the change
was pinned to single commits.

| Commit | What moved | Class | Source |
|---|---|---|---|
| 4143374c6 (void-jester-dash) | Motley's Trade drift slow 0.30 -> 0.35 | O | OWNER_REVIEW_1103 item 135 ("slowed too much during it"); owner 11-08 in the commit; KIT_PARITY Ostra Dash row |
| 3fbe25fae (movement-unify) | strong air control (a jump keeps run speed), the glider adds no speed (dive cruise 11.2 -> 5 m/s), an air dash keeps its speed, wall kick | O | briefs/DECISIONS.md 2026-11-08 "Movement: air control as SUPERVIVE ...; glide start adds no speed" and "real matches HAVE air control"; decision 0022 |
| d2adc51b8 (dash-curve-fit) | fitted dash curves for gunslinger, juggernaut, archer | S | decision 0025 (hero-ref footage at 1/15 s); KIT_PARITY "Felt dash per kit" |
| 6503f4fa8 (supervive-movement) | archer: one dash shape, the source curve x 0.7 speed | S+O | decision 0026 "Dash shape (Myth)" row; KIT_PARITY felt-dash Hem row "speed x0.7 (owner item 9)" |
| 5a2831b2b (supervive-movement) | over-run speed sheds under the source walking brake | S | decision 0026 "Over-run speed" row; KIT_PARITY gap 2 |
| a0259d1c3 (supervive-movement) | ledge rise: the source mantle suction (2.5 m/s) instead of a 14 m/s yank | S | decision 0026 "Mantle rise" row |
| b512c864c (glide-steer-parity) | the glider opens at a fall of at least 0.85 m/s and cuts a rising jump (GlideStartFallSpeedMin) | S+O | decision 0027; DECISIONS 11-08 "glide start adds no speed" |
| bdb7703bd (glide-fixes) | Sable's Cartwheel is the same in the air; out of charges, the class long dash | S | OWNER_REVIEW_1103 item 183; KIT_PARITY felt-dash Sable row |
| 754d177a0 (sparkle-dash) | Sparkle's Wirerun lane a quarter shorter, run-speed exit in the air | O | OWNER_REVIEW_1103 item 70 (lane length); owner playtest 11-10 in the commit; KIT_PARITY Ryzz (`mage`) Dash row |
| 0f6711d51 (motley-tune) | Motley's Trade drift slow halved (speed 35% -> 67.5%) | O | OWNER_REVIEW_1103 item 135; owner playtest 11-10 in the commit |
| 8280a6965 (feel-dash-scale-source) | the x.85/x1.15 felt-dash layer only on kits with no source dash | S | KIT_PARITY gap 4, "Felt dash per kit" |
| dde1bb0e2 (move-dash-gaps-0244) | a dash's last step runs its remainder before the hand-over | S | decision 0053; KIT_PARITY felt-dash rows |
| shove | the old golden recorded a mob or bot shove (velocity equal, position stalls) | A | re-record of 4c76f338f in the cleared space |

Class: O owner-directed, S sourced parity fix, A recording artefact, R regression (none).

One trace looks odd but is not a bug. After b512c864c, `glide_double` lands and then bounces: Space is
still held, so the Hunter jumps again and the glider reopens about 0.1 s later. This happens because the golden
check drives scripted input, which opens the glider on a hold by design (`hold_opens` in `Hunter`). Players get
`glide_press_only`, and there "Space held from the jump never glides" (DECISIONS 11-08) holds; `--glide-hold-check`
asserts it.

Every failing row, with the drift `--feel-golden-check` printed on main before the re-record and the commits that moved it, oldest first:

| Script | Hunter | Drift m, m/s | Moved by (in order) | Class |
|---|---|---|---|---|
| stop | ashwick | 0.112, 0.000 | shove | A |
| jump | archer | 0.344, 0.643 | 3fbe25fae | O |
| jump | ashwick | 0.533, 0.670 | shove, 3fbe25fae | A O |
| jump | bulwark | 0.428, 0.799 | 3fbe25fae | O |
| jump | dolm | 0.381, 0.713 | 3fbe25fae | O |
| jump | dredge | 0.398, 0.745 | 3fbe25fae | O |
| jump | gunslinger | 0.344, 0.643 | 3fbe25fae | O |
| jump | juggernaut | 0.344, 0.643 | 3fbe25fae | O |
| jump | mage | 0.358, 0.670 | 3fbe25fae | O |
| jump | ostra | 0.358, 0.670 | 3fbe25fae | O |
| jump | rimewright | 0.329, 0.616 | 3fbe25fae | O |
| jump | tender | 0.344, 0.643 | 3fbe25fae | O |
| jump | thief | 0.358, 0.670 | 3fbe25fae | O |
| dash_tap | archer | 0.647, 7.521 | shove, 3fbe25fae, d2adc51b8, 6503f4fa8, 8280a6965 | A O S S+O |
| dash_tap | ashwick | 7.329, 9.558 | shove, dde1bb0e2 | A S |
| dash_tap | bulwark | 1.082, 5.348 | shove, 5a2831b2b, 8280a6965, dde1bb0e2 | A S |
| dash_tap | dolm | 0.721, 0.253 | shove, 3fbe25fae | A O |
| dash_tap | dredge | 0.601, 0.000 | shove | A |
| dash_tap | gunslinger | 1.503, 6.690 | shove, d2adc51b8, 8280a6965 | A S |
| dash_tap | juggernaut | 0.668, 13.948 | shove, d2adc51b8 | A S |
| dash_tap | mage | 0.473, 0.000 | shove, 754d177a0, dde1bb0e2 | A O S |
| dash_tap | ostra | 2.896, 1.744 | 4143374c6, 0f6711d51 | O |
| dash_tap | rimewright | 0.625, 0.000 | shove | A |
| dash_tap | tender | 0.502, 0.159 | shove, 8280a6965 | A S |
| dash_tap | thief | 0.520, 0.000 | shove | A |
| dash_hold | archer | 2.445, 20.263 | shove, 3fbe25fae, d2adc51b8, 6503f4fa8, 8280a6965 | A O S S+O |
| dash_hold | ashwick | 5.772, 17.024 | shove, dde1bb0e2 | A S |
| dash_hold | bulwark | 4.909, 5.348 | shove, 8280a6965, dde1bb0e2 | A S |
| dash_hold | dolm | 0.047, 0.344 | 3fbe25fae, 5a2831b2b | O S |
| dash_hold | dredge | 3.159, 0.000 | shove | A |
| dash_hold | gunslinger | 4.393, 18.450 | shove, d2adc51b8, 8280a6965 | A S |
| dash_hold | juggernaut | 3.620, 13.948 | shove, d2adc51b8 | A S |
| dash_hold | mage | 1.852, 22.236 | shove, 754d177a0, dde1bb0e2 | A O S |
| dash_hold | ostra | 3.297, 1.744 | shove, 4143374c6, 0f6711d51 | A O |
| dash_hold | rimewright | 2.791, 0.000 | shove | A |
| dash_hold | tender | 3.677, 0.159 | shove, 8280a6965 | A S |
| dash_hold | thief | 10.906, 25.462 | shove, 5a2831b2b, bdb7703bd | A S |
| wall_kick | archer | 0.783, 6.106 | 3fbe25fae, a0259d1c3, b512c864c | O S S+O |
| wall_kick | ashwick | 0.117, 0.442 | 3fbe25fae | O |
| wall_kick | bulwark | 0.122, 1.830 | 3fbe25fae | O |
| wall_kick | dolm | 0.139, 0.452 | 3fbe25fae | O |
| wall_kick | dredge | 0.143, 1.300 | 3fbe25fae | O |
| wall_kick | gunslinger | 0.125, 0.448 | 3fbe25fae | O |
| wall_kick | juggernaut | 0.783, 6.106 | 3fbe25fae, a0259d1c3, b512c864c | O S S+O |
| wall_kick | mage | 0.117, 0.442 | 3fbe25fae | O |
| wall_kick | ostra | 0.117, 0.442 | 3fbe25fae | O |
| wall_kick | rimewright | 0.108, 0.387 | 3fbe25fae | O |
| wall_kick | tender | 0.125, 0.448 | 3fbe25fae | O |
| wall_kick | thief | 0.117, 0.442 | 3fbe25fae | O |
| glide_double | archer | 4.744, 10.290 | 3fbe25fae, b512c864c | O S+O |
| glide_double | ashwick | 4.728, 10.290 | 3fbe25fae, b512c864c | O S+O |
| glide_double | bulwark | 3.965, 10.290 | shove, 3fbe25fae, b512c864c | A O S+O |
| glide_double | dolm | 4.727, 10.290 | 3fbe25fae, b512c864c | O S+O |
| glide_double | dredge | 4.765, 10.290 | shove, 3fbe25fae, b512c864c | A O S+O |
| glide_double | gunslinger | 3.759, 10.290 | shove, 3fbe25fae, b512c864c | A O S+O |
| glide_double | juggernaut | 4.057, 10.290 | shove, 3fbe25fae, b512c864c | A O S+O |
| glide_double | mage | 4.728, 10.290 | 3fbe25fae, b512c864c | O S+O |
| glide_double | ostra | 4.728, 10.290 | 3fbe25fae, b512c864c | O S+O |
| glide_double | rimewright | 4.758, 10.290 | 3fbe25fae, b512c864c | O S+O |
| glide_double | tender | 4.744, 10.290 | 3fbe25fae, b512c864c | O S+O |
| glide_double | thief | 4.728, 10.290 | 3fbe25fae, b512c864c | O S+O |
| dive | archer | 13.576, 6.208 | 3fbe25fae | O |
| dive | ashwick | 13.576, 6.208 | 3fbe25fae | O |
| dive | bulwark | 13.576, 6.208 | 3fbe25fae | O |
| dive | dolm | 13.576, 6.208 | 3fbe25fae | O |
| dive | dredge | 13.576, 6.208 | 3fbe25fae | O |
| dive | gunslinger | 13.576, 6.208 | 3fbe25fae | O |
| dive | juggernaut | 13.576, 6.208 | 3fbe25fae | O |
| dive | mage | 13.576, 6.208 | 3fbe25fae | O |
| dive | ostra | 13.576, 6.208 | 3fbe25fae | O |
| dive | rimewright | 13.576, 6.208 | 3fbe25fae | O |
| dive | tender | 13.576, 6.208 | 3fbe25fae | O |
| dive | thief | 13.576, 6.208 | 3fbe25fae | O |
| crouch_walk | archer | 3.123, 0.000 | shove | A |
| crouch_walk | ashwick | 1.400, 0.000 | shove | A |
| crouch_walk | bulwark | 3.148, 0.000 | shove | A |
| crouch_walk | dolm | 1.489, 0.000 | shove | A |
| crouch_walk | dredge | 3.132, 0.000 | shove | A |
| crouch_walk | gunslinger | 3.809, 0.000 | shove | A |
| crouch_walk | juggernaut | 2.894, 0.000 | shove | A |
| crouch_walk | ostra | 3.017, 0.000 | shove | A |
| crouch_walk | tender | 1.089, 0.000 | shove | A |
| crouch_walk | thief | 2.964, 0.000 | shove | A |
