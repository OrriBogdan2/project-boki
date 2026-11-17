# Movement-physics parity: SUPERVIVE vs Project Boki (owner item 150, step 1)

Read-only audit (physics lane, 2026-11-06), against origin/main 7907d9af plus ext/phys-185-boki-dash (no movement changes there).
SV data: `origin/ext/agent-briefs:briefs/supervive-data/supervive_physics.md`. Units: 100 uu = 1 m.

**Scale:** no horizontal scale factor found. docs/SUPERVIVE_FEEL.md and docs/MOVEMENT_FEEL.md convert uu to m at 1:1 and compare directly. Vertical scale is NOT 1:1 in practice: our terrace is `World.LEVEL = 0.8 m` (scripts/match/world.gd:7) and walk-up step is `World.STEP = 0.32 m` (world.gd:8), while SV's bot step height is 1.5 m (150 uu). The jump was cut to fit our 0.8 m terraces (hunter.gd:12-14). Everything below compares in metres, 1:1.

## Summary for the owner
- Gravity matches SV exactly (14.7 m/s^2, one gravity up and down).
- Run speed and acceleration match SV per hero (4.45 to 4.85 m/s, 47 to 54 m/s^2).
- The big miss is stopping. SV brakes at 22.2 m/s^2 and you slide about 0.4 to 0.5 m. Ours brakes at 110 m/s^2 and you slide about 0.1 m. That is the "hard stop".
- Air control is 20 times SV's. SV is 0.015 (almost no steering in a jump). Ours is 0.3.
- Jump is lower: 6.8 m/s gives 1.57 m and 0.46 s to apex. SV is 7.5 m/s, 1.91 m, 0.51 s. This is deliberate (our terraces are 0.8 m).
- Dash end: we keep only 15 percent of dash speed on the ground and 30 percent in the air. SV carries momentum with no hard stop.
- Glide is steered by instant-ish acceleration (26 m/s^2), not SV's force model (162,500 force). Top speed is ours (6.5 m/s); SV's glide speed is still unknown.
- Fall cap, abyss slow-fall band, glide height 8.5 m, swoop 2.5x over 1.5 s, mantle launch all match.
- Not modelled: bCanWalkOffLedges=false (deliberately off), glide dive -32.5 m/s, rail grinding, sync62 and dash-curve details.

## Where our values live
- `content/rules/hunter_move.json`: per-hero speed/accel, plus `physics` block (air, fall, glide, mantle).
- `scripts/match/hunter_move.gd`: `HunterMove` (loads that JSON; `air_steer` line 44, `fall_cap` line 59, `mantle_launch` line 68).
- `scripts/match/hunter.gd`: constants lines 7-76; ground/air/glide integration lines ~2163-2265; `accel2` line 851.
- `content/rules/dash_feel.json`: global dash multipliers (read by scripts/arch/arch_kit.gd:464-475).
- `content/classes/*.json`: no speed overrides found (grep "speed" returned nothing there); only `glide_cap` and `mass`. `content/archetypes/*.json`: per-kit dash numbers (not a movement-speed source). Run speed comes only from hunter_move.json.

## How velocity is integrated (hunter.gd ~2163-2265)
- Horizontal, grounded: `accel2(hv, mv*spd, ground_accel*grip, GROUND_DECEL*grip, GROUND_OVERSPEED*grip, dt)`. With keys and under speed: `move_toward(wish, accel*dt)`, linear (constant accel). With no keys: `move_toward(0, GROUND_DECEL*dt)`, constant decel, NO friction term. Over run speed: speed bleeds at GROUND_OVERSPEED (30) plus accel when steering against.
- Horizontal, airborne (normal jump): `HunterMove.air_steer`: `hv *= (1 - 0.375*dt)` (linear drag), then steer toward wish at `ground_accel * air_control`. Over run speed the keys turn momentum without topping it up.
- Ledge rise: `accel2` with AIR_ACCEL 40 / AIR_DECEL 9 / AIR_OVERSPEED 3 (hunter.gd:19-21).
- Vertical, falling: `vel.y = max(vel.y - 14.7*dt, -fall_cap)`. Gravity constant, no up/down asymmetry.
- Per-hero accel: `GROUND_ACCEL := 90` (hunter.gd:16) is shadowed; `HunterMove.apply` overwrites `ground_accel` with the JSON (47/50/54). Its comment "top speed in ~0.055 s" is stale; real is ~0.086 s.
- Knockback: while `knock_t` runs, hv decays 6 m/s^2 with 0.3 steer (hunter.gd:2186-2190); afterwards the normal over-speed rules apply.

## World
| SV value (name) | SV in uu | SV in m | Ours (file:line) | Verdict |
|---|---|---|---|---|
| Gravity (DefaultGravityZ) | -1470 /s^2 | -14.7 m/s^2 | `H_GRAV := 14.7` hunter.gd:7 (used 2264, 837, 1920, 2371, 2804) | match |
| Abyss death depth (AbyssHeight) | -1750 | 17.5 m | World.ABYSS_DEPTH 6.0 (world.gd:100) + Hunter.ABYSS_EXTRA 11.5 (hunter.gd:2453) = 17.5 below the island lip | match (reference is the lowest island lip within 9 tiles, not "ground level"; unverified vs SV) |
| Recall duration | 4 s | 4 s | not checked (not movement) | unverified |
| Revive HP per tick | 2 | n/a | not movement | not audited |
| Stomp/revive diminishing returns | 1/.75/.58/.47 | n/a | not movement (Life.R) | not audited |
| Death circle damage | 3/6/50/450 | n/a | not movement | not audited |
| ADS camera distance | 12700 | 127 m | not movement | not audited |
| Bot nav agent radius / height / step | 43 / 176 / 150 | 0.43 / 1.76 / 1.5 m | World.STEP 0.32 (walk-up), mantle reach 1.5 (MANTLE_REACH hunter.gd:46), LEVEL 0.8 | different (our walk-up step is 0.32 m, climb 1.5 m by mantle; no documented reason for 0.32; radius/height not checked) |

## Per-hunter movement attributes (CT_LokiCharacterAttributes, content/rules/hunter_move.json)
| SV value | SV uu | SV m | Ours | Verdict |
|---|---|---|---|---|
| MaxMoveSpeed (shared 700) | 700 | 7.0 m/s | no 7.0 cap anywhere; per-hero MoveSpeed (below) is the run speed | not modelled (the 700 is the cap above per-hero MoveSpeed; the per-hero value is what drives the runtime, doc'd as 445-485) |
| GroundFriction | 1.0 | 1.0 /s | none; no-input ground stop is constant decel only (hunter.gd:854-856) | not modelled (see stop distance below) |
| BrakingDecelerationWalking | 2220 | 22.2 m/s^2 | `GROUND_DECEL := 110.0` hunter.gd:17 (x grip) | wrong, 5x too strong. docs/SUPERVIVE_FEEL.md says "Braking: Not yet" |
| AirControlMultiplier | 1.0 | 1.0 | `physics.air_control` 0.3 (hunter_move.json:7) | different on purpose: json doc says 0.015 "read as lost input" at our top-down scale |
| MaxGlide | 500 | 5.0 m/s | `GLIDE_SPEED := 6.5` (hunter.gd:63; comment: owner wanted stronger than footage 5 to 5.5) | deliberately different (hunter.gd:63 comment). Unverified that MaxGlide is a speed |
| SneakSpeedMultiplier | 0.5 | 0.5 | crouch x0.55 (hunter.gd:2163) | near match (0.55 vs 0.5); also +slow aim/spot rules, not SV data |
| Mass | 100 | 100 | `mass()` returns cdat "mass" default 1.0 (hunter.gd:457, 761-768); knockback divides by mass | different units; knockback scaling not audited |
| Knockback / KnockbackResist | 1.0 / 1.0 | | owner_stat("knockback_resist") hunter.gd:764 | unverified |
| CameraDistance | 5500 | 55 m | not movement (23 m back camera rig, MOVEMENT_FEEL.md:182) | n/a |

Per-hunter MoveSpeed / MaxAcceleration (json value = SV/100):
| Hunter (ours id) | SV speed / accel | Ours | Verdict |
|---|---|---|---|
| Oath (bulwark) | 485 / 4700 | 4.85 / 47 | match |
| Kingpin (dredge) | 465 / 4700 | 4.65 / 47 | match |
| Shiv (thief) | 465 / 5400 | 4.65 / 54 | match |
| Joule (mage) | 465 / 5400 | 4.65 / 54 | match |
| Tetra (dolm) | 465 / 5000 | 4.65 / 50 | match |
| Void (ostra) | 465 / 5400 | 4.65 / 54 | match |
| Felix (ashwick) | 465 / 5400 | 4.65 / 54 | match |
| Brall (juggernaut) | 455 / 5400 | 4.55 / 54 | match |
| Myth (archer) | 455 / 5400 | 4.55 / 54 | match |
| Elluna (tender) | 455 / 5400 | 4.55 / 54 | match |
| Ghost (gunslinger) | 455 / 5400 | 4.55 / 54 | match |
| Celeste (rimewright) | 445 / 5400 | 4.45 / 54 | match |
| (default row, not in SV) | n/a | 4.55 / 54 | n/a |

Stamina / HP columns: not movement, not audited. Note: movement speed is multiplied at runtime by haste, slows, reload (x0.88), firing, drinking (x0.45), crouch (x0.55), gear and mounts (hunter.gd:2163); SV has comparable modifiers but they are not in the data.

## Base movement component (engine part)
| SV value | SV uu | SV m | Ours | Verdict |
|---|---|---|---|---|
| JumpZVelocity | 750 | 7.5 m/s | `JUMP_V := 6.8` hunter.gd:14 | deliberately different (hunter.gd:12-13: so jump + mantle tops out under four 0.8 m terraces; docs/MOVEMENT_FEEL.md:210) |
| AirControl | 0.015 | 0.015 | `air_control` 0.3 | deliberately different (hunter_move.json doc), 20x SV |
| FallingLateralFriction | 0.375 | 0.375 /s | `air_friction` 0.375, linear `hv*(1-0.375 dt)` (hunter_move.gd:48) | match (UE applies it as braking friction; model is equivalent for a first-order drag, unverified for the constant-decel part) |
| MaxAcceleration (base 50000, attribute drives runtime) | 50000 | 500 m/s^2 | per-hero 47 to 54 from the attribute table; GROUND_ACCEL 90 shadowed | match (the attribute is what drives runtime) |
| MaxWalkSpeed (180 base, overridden by MoveSpeed) | 180 | 1.8 | per-hero speed | match (override) |
| WalkableFloorAngle | 50 deg | | heightmap terraces, no slope angle | n/a |
| RotationRate (yaw) | 1280 deg/s | | `face = lerp_angle(face, want, min(1, dt*20))` hunter.gd:2091 (exponential; ~63 percent of the turn in 0.05 s) | different model; unverified equivalence |
| bCanWalkOffLedges | false | | walking off edges allowed (hunter.gd:~2268 comment; docs/SUPERVIVE_FEEL.md "No, on purpose") | deliberately different (owner wants it) |
| MaxSimulationTimeStep / Iterations | 0.2 / 1 | | fixed per-frame/tick step | not modelled |

## Mantle
| SV value | SV uu | SV m | Ours | Verdict |
|---|---|---|---|---|
| bAllowsMantlingFromAbyss | true | | yes: MANTLE_REACH_ABYSS 4.5 (hunter.gd:48), WALL_CATCH_REACH 0.75 | match |
| MantleSuctionUpwardsForceHeightMax | 150 | 1.5 m | `MANTLE_REACH := 1.5` hunter.gd:46 | match |
| MantleSuctionUpwardsForceMin / Max | 250k / 1.75M | | no force model; mantle is a scripted ease up the face (`_mantle_point` hunter.gd:2129, LRISE_SPEED 14, hunter.gd:2719) | not modelled (kinematic) |
| ...DistanceMin / Max | 50 / 150 | 0.5 / 1.5 m | LEDGE_REACH 2.8 (hunter.gd:55), MANTLE_REACH 1.5 | not modelled |
| ...ZSpeedCap | 250 | 2.5 m/s | mantle rise is 14 m/s (LRISE_SPEED, [footage] "deep mantle in 0.8 s") | different: ours is far faster up the face; docs/SUPERVIVE_FEEL.md claims a 2.5 m/s cap but only reach is implemented. Might be intended for abyss recovery |
| MiniMantlePostLaunchDuration | 0.75 s | | not found | not modelled |
| MiniMantleXYSpeedTargetCoefficient / Min | 0.6 / 350 | 0.6 / 3.5 m/s | `mantle_launch_keep` 0.6, `mantle_launch_min` 3.5 (json; hunter_move.gd:68; used hunter.gd:2758) | match |
| MiniMantleForwardForceSpeedDeltaMultiplier | 8 | | not found | not modelled |
| Mantle curves | | | n/a | unresolved in SV data |
| bCanWallJump (tall-ledge): Myth, Brall | | | `climb_tall` on archer, juggernaut (+0.9 m, TALL_CLIMB_EXTRA hunter.gd:47) | match |

## Glide
| SV value | SV uu | SV m | Ours | Verdict |
|---|---|---|---|---|
| GlideTargetXYForce | 162,500 | force; ~16.25 m/s^2 if /Mass 100 (unverified) | `GLIDE_ACCEL := 26.0` m/s^2 constant accel toward wish (hunter.gd:22, 879/890) | different model: instant-ish constant accel (0.25 s to cruise), not a force toward a target. Ours is ~1.6x snappier if SV divides by mass |
| GlideDownwardForceHeightTarget | 850 | 8.5 m | `glide_height` 8.5 (json) | match |
| GlideDownwardForceMinZVelocity | -350 | -3.5 m/s | `glide_pull_vy` 3.5 (json; glide_lift.gd:41) | match |
| GlideDownwardForceExitZVelocity | -40 | -0.4 m/s | not found | not modelled |
| ...SwoopSpeedTransferRatio | 2.5 | 2.5 | `swoop_ratio` 2.5 (glide_lift.gd:37) | match |
| ...SwoopSpeedFadeTime | 1.5 s | 1.5 s | `swoop_fade` 1.5 (glide_lift.gd:38-39) | match |
| GlideStartFallSpeedMin | -85 | -0.85 m/s | GLIDE_CATCH 60 m/s^2 brakes a fall to sink in ~0.13 s (hunter.gd:11); sink GLIDE_SINK 1.4 (hunter.gd:845) | different: SV start threshold unclear; we always catch quickly. Unverified meaning |
| Glide dive ZTargetSpeed | -3250 | -32.5 m/s | `DIVE_FALL := 13.0` [est] (hunter.gd:70) | different/estimate: ours is 40 percent of SV. docs: "Dive: Not yet" |
| ...ZForceMax | 350,000 | | `DIVE_VY_RATE 7` m/s^2 (hunter.gd:73) | not modelled (rate-limited, not force) |
| ...XYForceMultiplier | 0.25 | | `DIVE_SPEED 14` flat steer | not modelled |
| ...DistanceMin / Max / Cancel / Timeout | 100 / 6000 / 350 / 10 s | 1 / 60 / 3.5 m / 10 s | DEPLOY_H 8.0 (hunter.gd:77) opens glider | not modelled |
| Unknowns (glide gravity factor, target XY speeds, braking, boost) | locked | | GLIDE_GRAV 14, GLIDE_SPEED 6.5, GLIDE_MAX 15, GLIDE_BRAKE 36, drag 1.6, boost cap 14 | unverified: [est] values, kept |
| Rail grinding (1000/1250/600, knocked x0.45) | | | no grind code in hunter.gd (rail hits only in boss/exits/fx) | not modelled |

## Abyss fall
| SV value | SV uu | SV m | Ours | Verdict |
|---|---|---|---|---|
| AbyssFallSlowDistMin / Max | 100 / 1650 | 1.0 / 16.5 m | `abyss_slow_from` 1.0, `abyss_slow_to` 16.5 | match |
| AbyssFallSlowSpeedLimitMin / Max | 1200 / 1000 | 12 / 10 m/s | `fall_cap` 12.0, `abyss_fall_cap` 10.0 (hunter_move.gd:59-66, hunter.gd:2264) | match in the abyss. NOTE: ours also caps ordinary falls at 12 m/s (docs "12 anywhere"); SV's cap outside the abyss is unknown (UE default terminal 40 m/s) |
| AbyssHeight | -1750 | -17.5 m | see World | match |

## Per-hunter overrides
SV: only bCanWallJump (Myth, Brall) and the attribute table differ. Ours: `climb_tall` on archer and juggernaut; the same speed/accel table. Also ours has per-kit dash and glide_cap (content/classes `glide_cap`) that SV does not list. Match.

## Derived numbers
Jump (v0, g):
| | SV | Ours |
|---|---|---|
| v0 | 7.5 m/s | 6.8 m/s |
| g | 14.7 | 14.7 |
| time to apex v0/g | 0.510 s | 0.463 s |
| apex height v0^2/2g | 1.913 m | 1.573 m |
| total air time (flat) | 1.02 s | 0.925 s |
Docs (MOVEMENT_FEEL.md:54) measure 1.52 m with a tap jump. Holding jump opens the glider (lighter gravity), so held jumps float higher. A wall kick adds 0.8 to 0.9 m (MOVEMENT_FEEL.md:190).

Stop distance from run speed, no input (4.65 m/s as a mid hero):
- Ours: constant decel 110 m/s^2 (hunter.gd:17, accel2 is `move_toward`, no friction): 4.65^2 / 220 = 0.098 m in 0.042 s. For 4.85: 0.107 m.
- SV, constant braking only (2220 uu/s^2): 4.65^2 / 44.4 = 0.487 m in 0.209 s. For 4.85: 0.53 m.
- SV with ground friction 1.0 added (UE: dv/dt = -k*v - D; with k = 1, D = 22.2): 0.43 m in 0.19 s. If UE's BrakingFrictionFactor (default 2) applies, k = 2: 0.38 m in 0.175 s. So SV stops in about 0.38 to 0.49 m, ours in 0.10 m: 4 to 5x shorter. (Friction model unverified; UE source not available here.)
- Accel to speed: SV and ours 54 m/s^2 → 0.086 s. Same.

Air steer: SV effective air accel ~ 0.015 x 54 = 0.8 m/s^2 (UE air-control formula unverified); ours 0.3 x 54 = 16.2 m/s^2, a full reverse from 4.65 takes 0.57 s vs several seconds in SV (i.e. effectively never).

Glide: ours is velocity-based. Top speed GLIDE_SPEED 6.5 m/s (x gear), accel 26 m/s^2 toward wish (0.25 s), let-go decel 1.4 m/s^2 (long coast), overspeed bleed 1.1, brake 36 when steering >115 deg against heading, turn 420 deg/s. Glide over-speed is kept (dash handoff 75 percent, cap 14; hunter.gd:948-951). SV: force-based (TargetXYForce 162,500 pulls toward the target speed), target speeds locked. Parity cannot be judged beyond the approach model.

Momentum from dashes: dash ends keep 15 percent (ground) or 30 percent (air) of dash speed (DASH_CARRY_*, hunter.gd:52-53, applied 2178), then GROUND_OVERSPEED 30 m/s^2 / AIR_OVERSPEED 3 bleeds the excess. Jumping out of a dash keeps 55 percent (DASH_JUMP_CARRY hunter.gd:1112). Dash base: 19 m/s x 0.19 s = 3.6 m (hunter.gd:56-57), multiplied by dash_feel.json (default dist 0.85, time 1.15, i.e. speed x0.74; mage dist 1.0 time 1.15; thief 1.0/1.0).

Sync62 slowdown (git): a196808ca (2026-11-02) "Slower, shorter dashes for everyone" introduced dash_feel.json (x0.85 distance, x1.15 time); daf5d87d2 (2026-11-02) cut base speed (light 5.0, medium 4.8, heavy 4.55; later superseded by the game-data 4.45-4.85 table) and base dash 23 m/s x 0.15 s → 19 x 0.19 s; 4c6e7c58c is "Post-sync62 dash speeds". SV dash curves (C_AssaultSlide_VelCurve etc.) are not decoded, so dash parity is unverifiable. Base run speed now matches SV data; dashes carry the remaining slowdown.

## Top suspects (ranked by feel impact) and proposed new values
1. Braking deceleration too strong (the stop feels dead). `Hunter.GROUND_DECEL` hunter.gd:17: 110 → 22.2 (SV 2220 uu/s^2). Optionally add a friction term (k = 1 to 2 /s) in `accel2`'s no-keys branch (hunter.gd:854-856) for the exponential tail. Also revisit `GROUND_OVERSPEED` 30 (hunter.gd:18) so landing/dash speed bleeds like braking, not a hard stop. Note ice `grip` multiplies it.
2. Dash and knock momentum killed at the end. `DASH_CARRY_GROUND` 0.15 and `DASH_CARRY_AIR` 0.3 (hunter.gd:52-53): propose keeping speed at least to run speed and letting braking (22.2) do the stop, e.g. GROUND 0.5 / AIR 0.8 as a first try; SV dash curves unknown so exact value unverified. Also the `knock_t` decay 6.0 (hunter.gd:2187).
3. Air control 20x SV. `physics.air_control` in content/rules/hunter_move.json: 0.3 → 0.015 for parity; 0.05 to 0.1 as a compromise (the file's doc says 0.015 felt like lost input at our scale, so this is an owner choice).
4. Jump too low and short. `Hunter.JUMP_V` hunter.gd:14: 6.8 → 7.5 (apex 1.91 m, 0.51 s). Cost: tops out above four 0.8 m terraces with a mantle, so also drop `WallMoves.KICK_RISE` (docs: 0.9 → 0.8 earlier; scripts/match/wall_moves.gd) or raise `World.LEVEL`. The vertical scale (0.8 m terrace vs SV 1.5 m step) is the root issue.
5. Walk-up step. `World.STEP` world.gd:8: 0.32 vs SV bot step 1.5 (climb via mantle). Low priority; only if terraces are re-scaled.
6. Glide approach is velocity-accel, not a force-to-target. `Hunter.GLIDE_ACCEL` hunter.gd:22: 26 → ~16 (if SV force/mass: 162500/100 uu/s^2) to soften the snap; real parity needs the locked glide speed defaults. Unverified.
7. Fall cap applied to normal falls (12 m/s everywhere). `physics.fall_cap` in hunter_move.json: SV's cap outside the abyss is unknown; keep 12 unless a longer drop feels wrong.
8. Dive speed. `Hunter.DIVE_FALL` hunter.gd:70: 13 → up to 32.5 if parity wanted (SV -3250 uu/s); drop-pod feel, [est] value. Low priority for walking physics.

Rows I could not verify: recall/revive/death-circle values (not movement), yaw rate equivalence, UE friction/braking formulas, MaxGlide meaning, mantle suction force model, rail grinding (not found in code).

## Step 2 and step 3 (physics lane, 2026-11-06)
- Step 2 (footage timing): the reference footage is 5 fps (0.2 s a frame). SV's stop takes ~0.18 s and a dash's decel less, so the frames can't resolve them; jump airtime is ~5 frames +-1. The game data above is the reference instead.
- Step 3, changed (ext/phys-150-parity 4071fe66):
  - Walking stop: braking 110 -> 22.2 m/s^2 plus friction 2 /s (GroundFriction 1.0 x UE's braking factor 2). A let-go now stops in ~0.17 s / ~0.3 m from a run (SV ~0.18 s / ~0.38 m); it was 0.05 s / 0.08 m.
  - Speed over a run (a dash, a kit step, a knock) still sheds at 110 m/s^2 with no keys, so every kit-tuned distance holds (Breaker's step, Tarek's punch, Storm Rod knocks).
- Step 3, changed with item 163 (ext/phys-163-drop): glide cruise 6.5 -> 5.0 m/s (MaxGlide 500) and the glide steers as a force (16.25 m/s^2 = GlideTargetXYForce 162,500 / UE's 100 kg): a 90-degree turn ~0.38 s, a reversal ~0.6 s.
- Kept, with the reason:
  - Dash carry 0.15 / 0.3: SV's dash curves aren't decoded, and 0.5 / 0.6 pushed Breaker's step past item 30's 2 m.
  - Air control 0.3 and jump 6.8 m/s: deliberate (owner feel items), unchanged.
  - Base glide sink 1.4 m/s below 8.5 m: it is what the glider-heat limit is tuned on (owner: "lasts too long"); above 8.5 m it is SV's 3.5.
