# Movement parity: every movement quantity against the source

One table per area: the source's value, ours, where each comes from, and a status. Mechanics and numbers only.

- **Status:** `match` (same number or within measuring error), `off` (differs; "ruling" = the owner chose it), `unknown` (the source value is not decoded or not documented, so ours is an estimate), `[?]` (the data does not settle what the row means, so nothing is built on it).
- **Source of truth tags:** `[D]` the source's game data (briefs/supervive-data/supervive_physics.md, 100 uu = 1 m), `[W]` its wiki, `[F]` a footage frame count (docs/MOVEMENT_FEEL.md, docs/SUPERVIVE_FEEL.md), `[est]` ours, tuned.
- **Ours** is a data row (file named) or a measurement by a check: `MFEEL` = `--move-feel-check`, `RATE` = `--move-rate-check` (both on the real step; 2026-11-10, branch ext/move-parity-1).
- The match steps at 60 Hz (`Match.DT`). Since decision 0048 the farm does too.

## 1. Ground

| Quantity | Source | Ours | Truth | Status |
|---|---|---|---|---|
| Run speed per class | MoveSpeed 445–485 uu/s | 4.45 (Neve's kit) to 4.85 (Oath's kit) m/s, a row per kit: 4.45 / 4.55 ×5 / 4.6 / 4.65 ×6 / 4.85 | [D]; `content/rules/hunter_move.json` | match |
| Run speed, measured | – | 4.550 m/s at 30, 60 and 144 fps (default kit) | RATE | match |
| Acceleration to run | MaxAcceleration 4700–5400 uu/s² | 47–54 m/s² per kit; 95% of run speed in 0.083 s | [D]; hunter_move.json; MFEEL `ground_t95` | match |
| Braking (keys let go) | BrakingDecelerationWalking 2220, GroundFriction 1 × BrakingFrictionFactor 2, sub-steps of ≤ 1/33 s, stop under 10 uu/s (UE's ApplyVelocityBraking) | brake 22.2 m/s², ground_friction 1.0, braking_friction_factor 2.0, braking_substep 1/33 s, brake_stop_speed 0.1 m/s; `HunterMove.brake` equals UE's loop to 1e-4 m/s at 1/144–0.2 s steps | [D]; hunter_move.json `physics`; MFEEL `brake_vs_ue_err` | match |
| Time and slide to a stop | ~0.17 s; per run speed 4.45 / 4.55 / 4.6 / 4.65 / 4.85 m/s: 0.275 / 0.286 / 0.292 / 0.302 / 0.329 m drawn at 30 fps, 0.336 / 0.350 / 0.357 / 0.364 / 0.393 m at 144 fps (UE's formula from the rows; UE moves at the braked speed, so its slide grows with the frame rate) | 0.167 s; 0.311 / 0.324 / 0.330 / 0.339 / 0.367 m at 30, 60 and 144 fps (our fixed 60 Hz step) | MFEEL `ground_stop_t/dist` and a stop per run speed, RATE `stop_<speed>` | match (inside the source's band for every Hunter) |
| Turn rate (facing) | RotationRate 1280°/s | turn_rate 1280°/s | [D]; hunter_move.json | match |
| 90° turn of the velocity | not documented | 0.117 s | MFEEL `ground_turn90_t` | unknown |
| Sneak (crouch) speed | SneakSpeedMultiplier 0.5 | sneak_speed 0.5 (was 0.55 in two constants) | [D]; hunter_move.json | match (fixed here) |
| Walk while attacking | per hunter: full speed on taps, a slowed walk in holds | per kit `fire_slow` / hold rows | [F]; MOVEMENT_FEEL.md "Walking while attacking" | match (2 kits kept slower, listed there) |
| First key press acts | – | the same step (1 frame) | MFEEL `ground_input_frames` | match |

## 2. Jump

| Quantity | Source | Ours | Truth | Status |
|---|---|---|---|---|
| Gravity, rising and falling | 14.7 m/s² (GravityScale 1.5), one value | 14.7 m/s² both ways (`Hunter.H_GRAV`) | [D] | match |
| Lift-off speed | JumpZVelocity 750 uu/s = 7.5 m/s | 6.8 m/s (`Hunter.JUMP_V`) | [D]; MFEEL `jump_speed_vs_source` 0.87 | off (ruling: 7.5 + mantle tops four terraces; KIT_PARITY item 20) |
| Apex height | 1.91 m | 1.517 m (1.516–1.517 at 30/60/144 fps) | MFEEL, RATE `jump_apex` | off (follows lift-off) |
| Time to apex | 0.51 s | 0.46 s | computed | off (follows lift-off) |
| Airtime on flat ground | 1.02 s | 0.900 s | MFEEL, RATE `jump_air` | off (follows lift-off) |
| Variable height (hold) | jump-hold rows not decoded | fixed height | [D] undecoded | unknown |
| Coyote time | not in the decoded data | coyote_s 0.12 s; measured 0.117 s (7 steps), match and farm | hunter_move.json; RATE `coyote` | unknown (ours [est]) |
| Jump buffer | not in the decoded data | jump_buffer_s 0.12 s; measured 0.133 s, match and farm | hunter_move.json; RATE `buffer` | unknown (ours [est]) |
| Fall speed cap | 12 m/s | fall_cap 12.0 | [D]; hunter_move.json | match |
| Free fall, 1 s | 7.35 m (½·14.7) | 7.20 m | MFEEL `freefall_1s_depth` | match |

## 3. Air control and drag

| Quantity | Source | Ours | Truth | Status |
|---|---|---|---|---|
| Air control | AirControl 0.015 (almost none: you keep your take-off velocity) | 32 m/s² along the keys, ×2.5 against the drift, ×0.3 sideways, capped at run speed | [D]; `content/rules/tuning.json` `air`; `--air-control-check` | off (ruling, owner 11-08: steer in the air) |
| Air drag, keys idle | FallingLateralFriction 0.375 | idle_drag 0.4 /s | [D]; tuning.json | match (within 7%; the mapping of the UE term is approximate) |
| Bleed of speed above run speed | not documented | drag 2.0 /s | tuning.json | unknown |
| Farm = match in the air | – | identical traces | `--air-control-check` | match |

## 4. Dash

Per-kit dashes are the kits' own (content/archetypes/*.json `dash`); the source's table is docs/DASHES_AND_ABILITY_FEEL.md §1 and the per-hero comparison is docs/KIT_PARITY.md. Shared rules:

| Quantity | Source | Ours | Truth | Status |
|---|---|---|---|---|
| Distance and duration | per hunter; DashCurves decoded for 3 | kit rows × `dash_feel.json` (default ×0.85 distance, ×1.15 time; 4 kits exempt); source speed curves on 3 kits (Vex, Kael, Hem) | [D]/[F]; KIT_PARITY gap 4 | off for the 9 kits on the global scale (their curves are not decoded) |
| Measured (default kit, tap, run held) | – | 4.11 m in 0.517 s, the same at 30/60/144 fps | RATE `dash`, `dash_time` | match across rates |
| Cooldown | light dashes 6.5–7 s; most 8–14 s; ex / air dash 12.5 s | kit `cd` 4.5–13 s; ex dash 12.5 s (`Hunter.EX_DASH_CD`) | [W]; archetypes, KIT_PARITY | match per kit (KIT_PARITY lists two: gaps 11, 13) |
| Charges | 1, or 2 with "a knock restores one" | per kit; knock refresh by decision 0022 | [W]; KIT_PARITY | match |
| I-frames | not listed, except one 0.1 s incorporeal dash | 0.08–0.12 s on four kits, none on the rest | [W]; archetypes `invuln` | unknown (three of ours have no source row) |
| Exit speed | no hard stop: you leave at run speed | dash_exit_run 1.0; slide 0.33 m if the keys are let go | [D]; MFEEL `dash_exit_run`, `dash_exit_slide_m` | match |
| Jump out of a dash | AirDash multipliers not decoded | keeps 0.75 of the dash speed (`tuning.json` dash.jump_keep) | [D] undecoded | unknown |
| Dash on the farm | the hunter's own dash everywhere | the class dodge (3.53 m in 0.15 s), not the kit's dash, without `dash_feel` | RATE (farm) | off (follow-up 3) |

## 5. Glide

| Quantity | Source | Ours | Truth | Status |
|---|---|---|---|---|
| Opening | a press in the air; opens once falling 0.85 m/s | the same; glide_start_vy 0.85; never from holding Space | [D]; hunter_move.json; `--glide-hold-check` | match (hold-to-open is ruled out, owner 11-08) |
| Top speed | MaxGlide 500 uu/s | 5.0 m/s | [D]; MFEEL `glide_speed` | match |
| Acceleration | 162,500 force on mass 100 | glide_accel 16.25 m/s² | [D]; hunter_move.json | match |
| Catch (fall to glide) | not documented | 0.183 s | MFEEL `glide_catch_t` | unknown |
| Steering | target speeds not decoded | turn 420°/s; 90° in 0.383 s, reverse in 0.600 s | [F] decision 0027; MFEEL | unknown (footage-tuned) |
| Sink | glide gravity factor not decoded | 1.4 m/s | MFEEL `glide_sink` | unknown |
| Height hold | 8.5 m over the ground, sinks 3.5 m/s above it | glide_height 8.5, glide_pull_vy 3.5 | [D]; hunter_move.json | match |
| Drop into speed (swoop) | height trades for speed | never | owner 11-08 item 8 | off (ruling) |
| Heat | coefficients not decoded | tuned; `--glider-heat-check` | [D] undecoded | unknown |
| Overheat | burns; the glider closes | opens at any heat, burns, lifts at half strength | [W]; owner item 63 | off (ruling) |
| Dive | −32.5 m/s, force 350,000, steer 0.25, cancel under 3.5 m, 10 s | dive_vy 32.5, dive_accel 35, dive_steer 0.25, dive_cancel_h 3.5, dive_timeout 10 | [D]; hunter_move.json | match |
| Spike (knocked out of a glide) | stun 0.7 s on landing; slam threshold not decoded | land stun 0.7 s; slam numbers [est] | [W]; hunter_move.json `glide_spike` | match / unknown (slam) |

## 6. Knockback, launches, landing

| Quantity | Source | Ours | Truth | Status |
|---|---|---|---|---|
| Knockback | steerable; no values | no steering for clamp(0.1 + speed·0.02, 0.12, 0.35) s, then air control | [W]; `Hunter.impulse` | unknown |
| Launch arcs | the same gravity | 14.7 m/s²; a straight lift caps at 9 m/s | [D] | match (gravity) / unknown (caps) |
| Landing recovery | not documented | 1 step before a key acts; the landing pose is 0.2 s (0.32 s hard) and does not lock the keys | MFEEL `land_dead_frames` | unknown |
| Hit-stop on movement | not documented | a time dip on a few impacts (`Match.freeze_frame`, 0.04–0.06 s); movement itself never pauses | [W] silent | unknown |

## 7. Slopes, ledges, walls, abyss

| Quantity | Source | Ours | Truth | Status |
|---|---|---|---|---|
| Walkable slope | WalkableFloorAngle 50° | terraces and stairs, no free slopes | [D]; map grammar | off (different terrain model) |
| Walking off a ledge | bCanWalkOffLedges false | allowed | [D] | off (ruling: our maps are terraces) |
| Mantle | reach 1.5 m, pull 1.75M on mass 100, rise cap 2.5 m/s, exit 0.6× run (min 3.5 m/s) | MANTLE_REACH 1.5, mantle_pull 175, mantle_vy_cap 2.5, mantle_launch_keep 0.6 / min 3.5 | [D]; hunter_move.json; `--mantle-check`, `--cliff-mantle-check` | match |
| Mini mantle | MiniMantlePostLaunchDuration 0.75 s, MiniMantleForwardForceSpeedDeltaMultiplier 8, XYSpeedTarget 0.6 / 350 uu/s; no height row (no mini-mantle height band in the data) | the exit speed held 0.75 s in the air after the lip (`MantleCarry.MINI_S`, held firm instead of the ×8 force); no separate low-lip mantle | [D]; `scripts/match/mantle_carry.gd`; `--cliff-mantle-check` | [?] (the 0.75 s is a post-launch window, not a mantle length; a low-lip band is not in the data) |
| Ledge rise and fling | not documented | rise 0.333 s; a timed jump flings 3.24 m; window 0.233 s | MFEEL `ledge_*` | unknown (ours [est]) |
| Wall kick, wall bounce | none found in the data | every kit has both | `--wallmove-check` | off (ours, kept) |
| Rail grinding | in the source | not modelled | [D] | off (missing) |
| Abyss fall | 12 m/s easing to 10 m/s between 1 and 16.5 m under the lip | fall_cap 12, abyss_fall_cap 10, abyss_slow_from 1, abyss_slow_to 16.5 | [D]; hunter_move.json; `--abyss-check` | match |

## 8. Frame-rate independence (`--move-rate-check`)

Real frame loops at 30, 60 and 144 fps, keys pressed for one drawn frame. Values are 30 / 60 / 144.

| Measure | Match | Farm | Status |
|---|---|---|---|
| Run speed (m/s) | 4.550 / 4.550 / 4.550 | 4.550 / 4.550 / 4.550 | match |
| Distance in the first second (m) | 4.396 ×3 | 4.429 ×3 | match |
| Slide after letting go (m) | 0.324 ×3 | 0.324 ×3 | match |
| Slide per Hunter's run speed (m) | 0.311 to 0.367 ×3, each inside the source's 30–144 fps band | the same | match |
| Jump apex (m) | 1.516 / 1.517 / 1.517 | 1.515 / 1.516 / 1.516 | match (the farm was ~1.46 / 1.52 / 1.55) |
| Jump airtime (s) | 0.900 / 0.900 / 0.903 | 0.900 / 0.900 / 0.903 | match |
| Dash length (m) | 4.110 ×3 | 3.526 ×3 | match across rates (two different dashes, §4) |
| Coyote window (s) | 0.100 / 0.117 / 0.118 | the same | match (the farm had none) |
| Jump buffer (s) | 0.133 / 0.133 / 0.132 | the same | match (the farm had none) |

The windows read one frame shorter at 30 fps only because a press can land on a frame boundary 33 ms apart; the simulated window is the same.

## Fixed on ext/move-parity-1

1. The farm's avatar moved on the frame time: jump height, stop slide and dash length changed with the display rate. It now steps like the match (`FarmStep`, decision 0048).
2. The farm had no coyote time and no jump buffer; it has the match's now, from the same two rows.
3. Sneak speed 0.55 → 0.5, one row (`sneak_speed`) for the match and the farm.
4. A kit swap in the middle of Hem's Spirit Walk left walls and ledges switched off for the next kit (the ledge rise and fling failed in `--move-feel-check`).

## Fixed on ext/feel-stop-slide

1. **Stop slide**: the 0.38–0.49 m listed as the source's was not the engine's output but three guesses at its model for one run speed in continuous time (brake only 0.49, friction 1 0.43, friction 2 0.38; briefs/supervive-data/PHYSICS_PARITY.md). UE's ApplyVelocityBraking is friction (GroundFriction × BrakingFrictionFactor) × speed plus BrakingDecelerationWalking, in sub-steps of at most BrakingSubStepTime, never reversing, stopping dead under BRAKE_TO_STOP_VELOCITY; the walk then moves at the braked speed, so the slide depends on the frame rate: 0.28–0.33 m at 30 fps, 0.34–0.39 m at 144. `HunterMove.brake` is now that loop exactly (sub-steps and the stop speed were missing; GroundFriction and the factor are separate rows). Before → after on our 60 Hz step, by run speed: 4.45 (Neve's kit) 0.311 → 0.311, 4.55 ×5 0.325 → 0.324, 4.6 (Gil) 0.332 → 0.330, 4.65 ×6 0.339 → 0.339, 4.85 (Oath's kit) 0.367 → 0.367 m. Matching the source's longer 144 fps slide would mean stepping faster, not a new formula.

## Follow-ups (off / unknown, in the order a player would feel them)

1. **Jump 6.8 vs 7.5 m/s** (owner call): the source's jump is 0.4 m higher and 0.12 s longer. Flipping it needs the terrace and mantle reach re-checked (jump + mantle would top four terraces).
2. **Stop slide** 0.31–0.33 m vs the source's computed 0.38–0.49 m: the same rows, a different friction formula. Small; needs the UE braking formula reproduced exactly.
3. **Farm dash** is the class dodge, not the kit's dash (3.5 m in 0.15 s against 4.1 m in 0.52 s for the same Hunter in a match).
4. **Dash curves** for 9 kits are not decoded: they run on the global ×0.85 / ×1.15 (KIT_PARITY gap 4; also gaps 9, 11, 13).
5. **Air control** (owner 11-08) and **no swoop** (owner 11-08) are rulings against the data; **walking off ledges** and **glider at any heat** too.
6. **Unknown in the source**: glide sink and steering speeds, heat coefficients, jump hold, air-dash multipliers, knockback steering values, landing recovery, hit-stop, coyote and buffer. Footage frame counts could settle the first three.
7. **Rail grinding** is not modelled. **Mini mantle** [?]: its 0.75 s post-launch hold is `MantleCarry`; a short mantle for low lips needs a height band the data does not have (MantleZDiffMax and the suction curves are named but not decoded), so none is modelled.
8. The farm avatar's facing turns per step (not blended between steps); the interior and town movers still step on frame time.
9. `--feel-golden-check` (done, ext/feel-golden-determinism): every script now runs in a cleared space (mobs, wild and own Boki freed and every other Hunter parked idle 80 m away before each step; seed 1109, the Hunter placed fresh), and the golden was re-recorded once. Three runs in a row: 117 traces, drift 0.000 m / 0.000 m/s each.
2. **Farm dash** is the class dodge, not the kit's dash (3.5 m in 0.15 s against 4.1 m in 0.52 s for the same Hunter in a match).
3. **Dash curves** for 9 kits are not decoded: they run on the global ×0.85 / ×1.15 (KIT_PARITY gap 4; also gaps 9, 11, 13).
4. **Air control** (owner 11-08) and **no swoop** (owner 11-08) are rulings against the data; **walking off ledges** and **glider at any heat** too.
5. **Unknown in the source**: glide sink and steering speeds, heat coefficients, jump hold, air-dash multipliers, knockback steering values, landing recovery, hit-stop, coyote and buffer. Footage frame counts could settle the first three.
6. **Rail grinding** and the **mini mantle** are not modelled.
7. The farm avatar's facing turns per step (not blended between steps); the interior and town movers still step on frame time.
8. `--feel-golden-check`: the traces carry shoves from mobs and wild Boki that walk into the Hunter (`Match._separate`), so `crouch_walk` does not replay identically run to run (3–5 of 13 differ in position, never in velocity), and clearing mobs before each script shifts 45 traces. It needs mobs and wild Boki cleared and one full re-record, together with the 72 drifts the RC already carries.
7. **Rail grinding** and the **mini mantle** are not modelled.
8. ~~The farm avatar's facing turns per step; the interior and town movers step on frame time.~~ Done (ext/feel-town-fixed-step, decision 0049): town and interior step on `FarmStep` with the match's rows, and the farm, town and interior blend the drawn facing between steps.
9. `--feel-golden-check`: the traces carry shoves from mobs and wild Boki that walk into the Hunter (`Match._separate`), so `crouch_walk` does not replay identically run to run (3–5 of 13 differ in position, never in velocity), and clearing mobs before each script shifts 45 traces. It needs mobs and wild Boki cleared and one full re-record, together with the 72 drifts the RC already carries.
