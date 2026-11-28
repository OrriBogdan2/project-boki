# Movement parity: every movement quantity against the source

One table per area: the source's value, ours, where each comes from, and a status. Mechanics and numbers only.

- **Status:** `match` (same number or within measuring error), `off` (differs; "ruling" = the owner chose it), `unknown` (the source value is not decoded or not documented, so ours is an estimate), `[?]` (the data does not settle what the row means, so nothing is built on it).
- **Source of truth tags:** `[D]` the source's game data (sv/briefs/physics.md, 100 uu = 1 m), `[W]` its wiki, `[F]` a footage frame count (docs/MOVEMENT_FEEL.md, docs/the reference_FEEL.md), `[est]` ours, tuned.
- **Ours** is a data row (file named) or a measurement by a check: `MFEEL` = `--move-feel-check`, `RATE` = `--move-rate-check` (both on the real step; 2026-11-10, branch ext/move-parity-1).
- The match steps at 60 Hz (`Match.DT`). Since decision 0048 the farm does too.

## Review on main, 2026-11-20 (all 13 Hunters)

Main 0b0b680df2 plus this branch's one fix, at 60 Hz. Per-Hunter rows come from `--move-feel-check`'s "hunter" lines (`tools/move_feel_hunters.gd`, each kit swapped in), `--move-rule-guard-check` and `--wallmove-check`. **Source** is the value that rules the row (owner > data > footage). Verdicts: `match`, `ruling` (the owner's number holds), `unknown` (the source has no number; ours unchanged), `changed` (moved since its closing commit by a later decision: needs an owner call), `REGRESSED -> fixed`, `red` (fails its check on main; not traced here).

| Row | Source | Main | Verdict |
|---|---|---|---|
| Run speed | data row 4.45–4.85 m/s x body_scale 1.16 (decision 0061) | 5.162–5.626 m/s, 13/13 on their row (±0.01) | match (the §1 "Ours" column predates 0061) |
| Acceleration | data row 47–54 m/s² x 1.16 | 95% of run in 0.083–0.100 s, 13/13 | match |
| Brake, keys let go | 22.2 m/s², friction 1 x 2, sub-steps ≤ 1/33 s, stop under 0.1 m/s | the same rows; `brake_vs_ue_err` 0.000 m/s | match |
| Let-go slide and stop | 0.28–0.39 m in ~0.17 s at the data's run speeds (b5e1af358e) | 0.412–0.481 m in 0.200 s, 13/13 inside the source's band for our faster run; `ground_stop_dist` 0.429 (target ≤ 0.40) and the 5 farm-stop rows of `--move-rate-check` red | changed (0061 scaled the run, not the brake): owner call |
| Facing turn | 1280°/s | 180° in 0.150 s; run flip within 1 step of the source's rule, 0.217 s | match |
| 90° turn of the velocity | none | 0.117 s | unknown |
| Sneak | 0.5 | 0.5 | match |
| First key acts | – | the same step | match |
| Gravity | 14.7 m/s² | 14.7 | match |
| Jump lift-off | owner 6.8 m/s (data 7.5) | 6.800 m/s, 13/13 | ruling |
| Jump apex / airtime | follow the lift-off | 1.517 m / 0.900 s (30/60/144 fps within 0.005 m) | ruling |
| Coyote / buffer | none | 0.117 / 0.133 s, match and farm | unknown |
| Fall cap / free fall 1 s | 12 m/s / 7.35 m | 12 / 7.20 m | match |
| Air control | owner 11-08: steer in the air | reverse 8.94 m/s in the check window; farm = match trace | ruling |
| Air drag, keys idle | 0.375 | 0.4 /s | match |
| Bleed over run in a glide | none (owner 11-08 model, 2.0 /s) | 12 m/s glide: 5.64 after 2 s (target ≤ 5.5), steering along 6.41 (≤ 6.0) | red (`--air-control-check` item 9) |
| Shift then glide, item 4 / chain, item 7 | owner 11-08 | Neve 10.50 -> 9.16 -> 8.84 m/s; worst one-step loss 84% (≤ 30%) | red (`--air-control-check`) |
| Dash exit | run speed, then the walking stop | 1.000x run; slide 0.429 m | match (slide as the let-go row) |
| Dash, default kit | kit rows | 4.852 m in 0.450 s, the same at 30/60/144 fps (§8's 4.11 m / 0.517 s predates later dash tuning) | match across rates |
| Jump out of a dash | none | 0.750 (Vex, Kael, Cinder), 0.752 (Lace) | unknown |
| Glide opening | a press in the air, held 0.4 s, 0.85 m/s down | opens after a 0.4 s hold of the second Space or the glide button (`glide_engage`); a tap never opens it; never from Space held since the jump (13/13) | match (11-27) |
| Glide top speed | 5.0 m/s | 5.000 m/s, 13/13 | match |
| Glide steer | footage (decision 0027) | 90° in 0.383 s, 13/13; reverse 0.600 s | unknown (footage-tuned, unchanged) |
| Glide catch / sink | none / owner over 2.2 | 0.183 s / 1.4 m/s | unknown |
| Glide heat | owner 11-02 | 9.017 s to overheat | ruling |
| Overheated glider lift | owner item 63: half strength | 0.52 of the full lift (8.7 of 16.7 m/s), at the lip in 1.55 s, 13/13 | ruling |
| Swoop | §5 says "never" (owner 11-08 item 8) | a level-out after a short dive is 2.46x for 1.5 s (`swoop_x`, 358153be8e, data-sourced in MOVEMENT_FEEL) | owner call (the two docs disagree) |
| Dive | 32.5 m/s, 35 m/s², steer 0.25, cancel 3.5 m, 10 s | peak 32.500 m/s 13/13; 90% in 0.750 s; steer 0.250; cancels 3.09 m up; 9.98 s | match |
| Walking off a ledge | owner: always allowed | walks and crouch-walks off a rim, 26/26 | ruling |
| Walk off, keys turned back into the face | wallmove-check 1b (dcceafd026): lands below | Lace's tall climb caught the ledge she left (1.17 m up) | REGRESSED -> fixed (cb30534328; lands 0.00 m, still climbs the wall from a jump) |
| Ground dash off a ledge (decision 0046) | the dash carries over the lip | Cinder ends at 0.367x run (≥ 0.75x), Albert held 14 steps | red (`ledge_dash`) |
| Mantle into a rim from an air dash | `--mantle-check` | Vex, Albert stall 2.1–2.2 s at a 1.5 m rim | red (`dash-rim`) |
| Ledge rise / fling | ours [est] | rise 0.350 s, timed fling 3.694 m, window 0.233 s (§7's 0.333 s / 3.24 m predate 0061) | unknown (targets pass) |
| Wall kick and bounce | ours, every Hunter | 13/13 kick and bounce from a run, a jump, a dash and after every ability, nothing blocked | ruling |
| Knock arc at 0.4 s | footage | Lace 4.242 m (4.03–4.23), Sparkle 2.879 m (2.62–2.82), 0.797 landed (≥ 0.85) | red (`knock_*`) |
| Haste + kin buff | data: bonuses add | 1.326x (1.49–1.51) | red (`haste_two_bonus_x`) |
| Sable's dash curve, Cartwheel exit | footage | peak at 0.10 of the dash (0.28–0.44), 1.547x (1.7–1.9), distance 0.429x; Cartwheel exit 1.18x run | red (`dash_curve_*`, `vault_exit_run`) |
| Air limits: a fall during a cast (items 162, 162b) | owner | Meeko's fire in a fall acts as on the ground (`--air-limits-check`) | red |
| Online feel (100 ms) | – | `--online-feel-check` 0 failures | match |

`--feel-golden-check` has 104 drifted samples on main (the golden predates later tuning); this branch leaves them unchanged. The `red` rows were red on main before this branch and are listed for follow-up; they are outside the rows this review fixes.

## 1. Ground

| Quantity | Source | Ours | Truth | Status |
|---|---|---|---|---|
| Run speed per class | MoveSpeed 445–485 uu/s | 4.45 (Neve's kit) to 4.85 (Oath's kit) m/s, a row per kit: 4.45 / 4.55 ×5 / 4.6 / 4.65 ×6 / 4.85 | [D]; `content/rules/hunter_move.json` | match |
| Run speed, measured | – | 4.550 m/s at 30, 60 and 144 fps (default kit) | RATE | match |
| Acceleration to run | MaxAcceleration 4700–5400 uu/s² | 47–54 m/s² per kit; 95% of run speed in 0.083 s | [D]; hunter_move.json; MFEEL `ground_t95` | match |
| Braking (keys let go) | BrakingDecelerationWalking 2220, GroundFriction 1 × BrakingFrictionFactor 2, sub-steps of ≤ 1/33 s, stop under 10 uu/s (UE's ApplyVelocityBraking) | brake 22.2 m/s², ground_friction 1.0, braking_friction_factor 2.0, braking_substep 1/33 s, brake_stop_speed 0.1 m/s; `HunterMove.brake` equals UE's loop to 1e-4 m/s at 1/144–0.2 s steps | [D]; hunter_move.json `physics`; MFEEL `brake_vs_ue_err` | match |
| Time and slide to a stop | ~0.17 s; per run speed 4.45 / 4.55 / 4.6 / 4.65 / 4.85 m/s: 0.275 / 0.286 / 0.292 / 0.302 / 0.329 m drawn at 30 fps, 0.336 / 0.350 / 0.357 / 0.364 / 0.393 m at 144 fps (UE's formula from the rows; UE moves at the braked speed, so its slide grows with the frame rate) | 0.167 s; 0.311 / 0.324 / 0.330 / 0.339 / 0.367 m at 30, 60 and 144 fps (our fixed 60 Hz step) | MFEEL `ground_stop_t/dist` and a stop per run speed, RATE `stop_<speed>` | match (inside the source's band for every Hunter) |
| Turn rate (facing) | RotationRate 1280°/s | turn_rate 1280°/s | [D]; hunter_move.json | match |
| Turn rate while casting: Kael (juggernaut) RMB charge hold | no cursor swing in the hold (juggernaut 0122-0126, 0143-0145: cursor on the dummy) (ext/hero-ref-footage, 5 fps) | turn_rate 1280°/s, the row's early `free` | [D] one RotationRate; [F] no evidence of a slower turn | match |
| Turn rate while casting: Sparkle (mage) RMB spear hold | no cursor swing in the hold (vireo 0043-0048, 0057-0062) (ext/hero-ref-footage, 5 fps) | 1280°/s, `free` | [D]; [F] no evidence | match |
| Turn rate while casting: Vex (gunslinger) LMB held fire | the shots follow a ~65° cursor swing inside one 0.2 s frame mid-hold (venator_ghost 0014→0015): ≥325°/s (ext/hero-ref-footage, 5 fps) | 1280°/s, `free` | [F] lower bound; [D] | match |
| Turn rate while casting: Cinder (ashwick) LMB held fire | the nozzle follows a ~45° swing (linwick 0014→0015) and a ~90° one (0017→0018) inside one frame: ≥450°/s; only the stream lags (ext/hero-ref-footage, 5 fps) | 1280°/s, `free` | [F] lower bound; [D] | match |
| Turn rate while casting: Tenzo (dolm) RMB charge hold | no cursor swing in the charge (breah 0253-0258, 0265-0268) (ext/hero-ref-footage, 5 fps) | 1280°/s, `free` | [D]; [F] no evidence | match |
| Turn rate while casting: Motley (ostra) ult wind-up | a tap; the cursor stays by the dummy through the 1 s telegraph (ostra 0436-0441) (ext/hero-ref-footage, 5 fps) | 1280°/s early, `locked` once it opens (its own row) | [D]; [F] no evidence | match |
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
| Jump out of a dash | AirDash multipliers not decoded; no dash-then-jump in the footage of Ghost (slides 0118-0121, 0135-0138, 0149-0151: all end on the ground), Brall (Quick Dash 0371-0420 on the ground; his only jumps, Air Slam 0252-0269, start from a stand), Myth (the 0051-0053 push is a hop during a camera zoom with no dash before it) or Felix (Bash 0134-0165 ends on the ground) | keeps 0.75 of the dash speed for every Hunter (`tuning.json` dash.jump_keep); MFEEL `dash_jump_keep` 0.750 for Vex, Kael and Cinder, 0.752 for Lace | [D] undecoded; [F] none (5 fps, footage/<hero>/frames on ext/hero-ref-footage) | unknown (ours [est]) |
| Dash on the farm | the hunter's own dash everywhere | the class dodge (3.53 m in 0.15 s), not the kit's dash, without `dash_feel` | RATE (farm) | off (follow-up 3) |

## 5. Glide

| Quantity | Source | Ours | Truth | Status |
|---|---|---|---|---|
| Opening | a press in the air held 0.4 s; opens once falling 0.85 m/s | the same; `glide_engage` 0.4, glide_start_vy 0.85; Space held since the jump never opens it (owner 11-08, kept); feathering = let go closes at once, another 0.4 s hold reopens | [D]; practice notes 11-26; tuning.json; `--glide-hold-check`, `--glider-parity-check` | match (11-27: the tap-opens rule is gone) |
| Top speed | MaxGlide 500 uu/s | 5.0 m/s | [D]; MFEEL `glide_speed` | match |
| Acceleration | 162,500 force on mass 100 | glide_accel 16.25 m/s² | [D]; hunter_move.json | match |
| Catch (fall to glide) | not documented | 0.183 s | MFEEL `glide_catch_t` | unknown |
| Steering | target speeds not decoded | turn 420°/s; 90° in 0.383 s, reverse in 0.600 s | [F] decision 0027; MFEEL | unknown (footage-tuned) |
| Sink | glide gravity factor not decoded; footage checked 11-11, none measurable: no long steady glide on disk (hetzner /home/boki/svvid abilities video 1174 s + its hero-ref frames, Tetra guide 300 s; refs/sv-mantle Joule 1v4 42 s, owner clip 34 s). The abyss-tinted seconds are a storm zone (Tetra 16, 122, 240-243 s) and a fight over the abyss with the camera swinging (owner clip 12-20 s); the one glide the hero-ref notes name (Elluna, 706.8 s) is a step off the practice range's edge | 1.4 m/s, hunter_move.json `glide_sink` | owner: 2.2 fell faster than the source; MFEEL `glide_sink`, `--glider-heat-check` | unknown |
| Height hold | 8.5 m over the ground, sinks 3.5 m/s above it | glide_height 8.5, glide_pull_vy 3.5 | [D]; hunter_move.json | match |
| Drop into speed (swoop) | height trades for speed | never | owner 11-08 item 8 | off (ruling) |
| Heat | coefficients not decoded; [F] a level glide ~14 s to the hot ring (Tom Kick's guide, docs/the reference_FEEL.md; not on disk to recount); the same footage check as Sink | 6.25 s from the open to overheat (500 fuel at 80 a second, 11-27), hunter_move.json `glide_heat_s` (x the archetype's glide_cap); a lift heats 4x as fast | owner 11-02 "lasts too long, not punishing enough" outranks the footage; MFEEL `glide_overheat_s`, `--glider-heat-check` | match (11-27: 6.25 s, the owner's "lasts too long" goes the same way) / unknown (coefficients) |
| Overheat | burns; the glider closes | opens at any heat, burns, flies at 0.7x speed, lifts as strongly as a cool one | [W]; owner item 63 | off (ruling) |
| Dive | −32.5 m/s, force 350,000, steer 0.25, cancel under 3.5 m, 10 s | dive_vy 32.5, dive_accel 35, dive_steer 0.25, dive_cancel_h 3.5, dive_timeout 10 | [D]; hunter_move.json | match |
| Spike (knocked out of a glide) | 0.18 s freeze, then set to 80 m/s straight down; stun 0.7 s on landing, then a 1.5 s heat regen stun; a slam burns the victim 0.5 x max heat plus the 1.5 s regen stun, the slammer pays nothing; only an emptied glider spikes | `glide_spike` air_stun 0.18, fall_vy 80, land_stun 0.7, regen_stun 1.5, slam_heat 0.5 | [W]; private notes glider-fuel / slam-spike-abyss 11-25, PRACTICE-UPDATE 11-26; hunter_move.json; `--glider-parity-check` | match (11-27); open: the practice update measured -4000 and one -8000 kick at 0.305 s |

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

1. **Stop slide**: the 0.38–0.49 m listed as the source's was not the engine's output but three guesses at its model for one run speed in continuous time (brake only 0.49, friction 1 0.43, friction 2 0.38; sv/briefs/PHYSICS_PARITY.md). UE's ApplyVelocityBraking is friction (GroundFriction × BrakingFrictionFactor) × speed plus BrakingDecelerationWalking, in sub-steps of at most BrakingSubStepTime, never reversing, stopping dead under BRAKE_TO_STOP_VELOCITY; the walk then moves at the braked speed, so the slide depends on the frame rate: 0.28–0.33 m at 30 fps, 0.34–0.39 m at 144. `HunterMove.brake` is now that loop exactly (sub-steps and the stop speed were missing; GroundFriction and the factor are separate rows). Before → after on our 60 Hz step, by run speed: 4.45 (Neve's kit) 0.311 → 0.311, 4.55 ×5 0.325 → 0.324, 4.6 (Gil) 0.332 → 0.330, 4.65 ×6 0.339 → 0.339, 4.85 (Oath's kit) 0.367 → 0.367 m. Matching the source's longer 144 fps slide would mean stepping faster, not a new formula.

## Follow-ups (off / unknown, in the order a player would feel them)

1. **Jump 6.8 vs 7.5 m/s** (owner call): the source's jump is 0.4 m higher and 0.12 s longer. Flipping it needs the terrace and mantle reach re-checked (jump + mantle would top four terraces).
2. **Farm dash** is the class dodge, not the kit's dash (3.5 m in 0.15 s against 4.1 m in 0.52 s for the same Hunter in a match).
3. **Dash curves** for 9 kits are not decoded: they run on the global ×0.85 / ×1.15 (KIT_PARITY gap 4; also gaps 9, 11, 13).
4. **Air control** (owner 11-08) and **no swoop** (owner 11-08) are rulings against the data; **walking off ledges** and **glider at any heat** too.
5. **Unknown in the source**: glide sink and steering speeds, heat coefficients, jump hold, air-dash multipliers, knockback steering values, landing recovery, hit-stop, coyote and buffer. Footage frame counts could settle the first three.
6. **Rail grinding** is not modelled. **Mini mantle** [?]: its 0.75 s post-launch hold is `MantleCarry`; a short mantle for low lips needs a height band the data does not have (MantleZDiffMax and the suction curves are named but not decoded), so none is modelled.
7. The farm avatar's facing turns per step (not blended between steps); the interior and town movers still step on frame time.
8. `--feel-golden-check` (done, ext/feel-golden-determinism): every script now runs in a cleared space (mobs, wild and own Boki freed and every other Hunter parked idle 80 m away before each step; seed 1109, the Hunter placed fresh), and the golden was re-recorded once. Three runs in a row: 117 traces, drift 0.000 m / 0.000 m/s each.
