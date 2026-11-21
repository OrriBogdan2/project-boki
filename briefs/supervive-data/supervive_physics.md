# SUPERVIVE physics pulled from the game files (Nov 2 2026)

Source: the live install (steamapps\common\SUPERVIVE), read directly: config .ini files from pakchunk0 (legacy pak, Oodle) and curve tables from the IoStore containers (UE5, unencrypted, unversioned properties). Units are Unreal units: 1 uu = 1 cm.

## Confirmed values

### World
| Setting | Value | Notes |
|---|---|---|
| Gravity (DefaultGravityZ, DefaultEngine.ini) | -1470 uu/s² (-14.7 m/s²) | 1.5x Unreal's default -980. Why jumps feel snappy and falls quick |
| Abyss death depth (AbyssHeight, CT_LokiGameplaySystemsAttributes) | -1750 uu (17.5 m below ground level) | Below this you die |
| Recall duration | 4s | |
| Revive HP per tick | 2 | |
| Stomp/revive diminishing returns (by count 1..4) | 1.0 / 0.75 / 0.58 / 0.47 | Same curve for allies reviving and enemies stomping |
| Death circle damage (by stage 0,1,2,10) | 3 / 6 / 50 / 450 | |
| ADS camera distance | 12700 uu | Fog-of-war radius x1.25, 30° cone |
| Bot nav agent (hero) | radius 43, height 176, step height 150 uu | Step 150 ≈ the single-high climb height |

### Per-hunter movement attributes (CT_LokiCharacterAttributes)
Shared by all 12: MaxMoveSpeed 700, GroundFriction 1.0, BrakingDecelerationWalking 2220, AirControlMultiplier 1.0, MaxGlide 500, SneakSpeedMultiplier 0.5, Mass 100, Knockback/KnockbackResist 1.0, CameraDistance 5500.

| Hunter | Internal name | MoveSpeed (uu/s) | MaxAcceleration | Max stamina | Stamina regen | Base HP | HP/level |
|---|---|---|---|---|---|---|---|
| Oath | ShieldBot | 485 | 4700 | 500 | 40 | 1475 | 88.5 |
| Kingpin | Butcher (probable) | 465 | 4700 | 120 | 10 | 1445 | 86.7 |
| Shiv | Stalker | 465 | 5400 | 2000 | 0 | 1290 | 77.4 |
| Joule | Storm | 465 | 5400 | 1250 | 0 | 1290 | 77.4 |
| Tetra | EarthTank | 465 | 5000 | 120 | 10 | 1290 | 77.4 |
| Void | Void | 465 | 5400 | 270 | 20 | 1150 | 66.0 |
| Felix | FireFox | 465 | 5400 | 200 | 20 | 1290 | 77.4 |
| Brall | Ronin | 455 | 5400 | 300 | 10 | 1290 | 77.4 |
| Myth | Huntress | 455 | 5400 | 150 | 10 | 1100 | 66.0 |
| Elluna | Seraph | 455 | 5400 | 150 | 10 | 1290 | 77.4 |
| Ghost | Rho | 455 | 5400 | 120 | 0 | 1225 | 73.5 |
| Celeste | Freeze | 445 | 5400 | 120 | 10 | 1290 | 77.4 |

"Stamina" in this table is likely the hero's resource bar (a few heroes use it as their custom meter), not a universal sprint stat.

### Base hero movement component (BP_LokiHeroCharacter → CharMoveComp)
Decoded by rebuilding the class layouts from the exe's reflection data. Only values the blueprint overrides are stored; everything else is a C++ default (see below).

**Engine movement (UCharacterMovementComponent)**
| Setting | Value | Notes |
|---|---|---|
| JumpZVelocity | 750 uu/s | With gravity -1470: apex ~0.51s, height ~1.91 m |
| AirControl | 0.015 | Very low: almost no steering mid-jump (per-hero AirControlMultiplier is 1.0) |
| FallingLateralFriction | 0.375 | Horizontal speed bleeds off while falling |
| MaxAcceleration | 50000 | Base value; the attribute table (4700-5400) drives it at runtime |
| MaxWalkSpeed | 180 | Overridden at runtime by the MoveSpeed attribute (445-485) |
| WalkableFloorAngle | 50° | |
| RotationRate (yaw) | 1280 °/s | |
| bCanWalkOffLedges | false | You don't stroll off edges by accident; leaving a platform takes a jump or dash |
| MaxSimulationTimeStep / Iterations | 0.2 / 1 | |

**Mantle**
| Setting | Value |
|---|---|
| bAllowsMantlingFromAbyss | true (you can mantle back up out of the abyss) |
| MantleSuctionUpwardsForceHeightMax | 150 uu (1.5 m) |
| MantleSuctionUpwardsForceMin / Max | 250,000 / 1,750,000 |
| MantleSuctionUpwardsForceDistanceMin / Max | 50 / 150 uu |
| MantleSuctionUpwardsForceZSpeedCap | 250 uu/s |
| MiniMantlePostLaunchDuration | 0.75s |
| MiniMantleXYSpeedTargetCoefficient / Min | 0.6 / 350 uu/s |
| MiniMantleForwardForceSpeedDeltaMultiplier | 8 |
| Curves: MantleSuctionForceCurve, MantleSuctionUpwardsForceDistanceCurve | separate curve assets (not resolved yet) |
| bCanWallJump (tall-ledge climb) | ON for Myth AND Brall; off for the other 10 |

**Glide**
| Setting | Value | Notes |
|---|---|---|
| GlideTargetXYForce | 162,500 | Horizontal force pulling you to target glide speed |
| GlideDownwardForceHeightTarget | 850 uu (8.5 m) | Height the downward correction pulls you toward |
| GlideDownwardForceMinZVelocity | -350 uu/s | (shaped by a curve) |
| GlideDownwardForceExitZVelocity | -40 uu/s | |
| GlideDownwardForceSwoopSpeedTransferRatio | 2.5 | Falling speed converted into forward speed on a swoop: the feathering payoff |
| GlideDownwardForceSwoopSpeedFadeTime | 1.5s | How long the swoop bonus lasts |
| GlideStartFallSpeedMin | -85 uu/s | |
| Glide dive: ZTargetSpeed / ZForceMax / XYForceMultiplier | -3250 uu/s / 350,000 / 0.25 | Diving straight down (drop pods / aimed dive) |
| Glide dive: DistanceMin / Max / CancelDistance / Timeout | 100 / 6000 / 350 uu / 10s | |

**Abyss fall**
| Setting | Value | Notes |
|---|---|---|
| AbyssFallSlowDistMin / Max | 100 / 1650 uu | Below the rim, your fall is speed-limited between these depths |
| AbyssFallSlowSpeedLimitMin / Max | 1200 / 1000 uu/s | Max fall speed eases from 12 to 10 m/s as you sink, giving time to recover |
| AbyssHeight (death) | -1750 uu | So the slow-fall band ends 1 m above the kill depth |

**Rail grinding (exists in the movement code)**: idle 1000, charging 1250 (forward 1300, back 1050), accel 600 (+500 for the first 0.75s), knocked multiplier 0.45, start-while-gliding range 350.

### Per-hunter overrides (BP_HERO_* CharMoveComp)
Almost nothing is tuned per hero in the movement component: all 12 share the base values above. The only real differences are bCanWallJump (Myth, Brall) and the attribute table (move speed, acceleration, HP).

## Still locked: C++ defaults
The game's code section is encrypted on disk (anti-tamper wrapper, entropy 8.0), so constructor defaults can't be read statically. That covers every movement setting the blueprint doesn't override, e.g. GlideGravityFactor, CustomGlideZSpeed, the glide target/initial XY speeds, GlideUpward* forces, glide braking, glide boost (hoops), jump hold time, air dash multipliers. Getting them needs the game running once with UE4SS (or a memory dump of the default objects).

## Tunables that exist but aren't decoded yet
These are defined in the game code and set on the hero character/movement blueprint. Their values are stored without field names, so reading them needs the class layout (a .usmap mapping file or reconstructing it from the exe).

- Glide: GlideGravityFactor, CustomGlideZSpeed, GlideMinZVelocity, GlideStartVelZ, GlideStartFallSpeedMin/Max, GlideInitialMin/MaxXYSpeed(+Bonus), GlideInitialSpeedDuration/DecayDuration, GlideTargetXYMin/MaxSpeed(+Bonus), GlideTargetXYForce, GlideMin/MaxForceSpeedDelta, GlideFullInputInfluence, GlideMinInputInfluence, GlidePreserveSpeedSteeringAngle, GliderPreserveSpeedSteeringRate, GlideRepeatLeniencyDuration, GlideStartGroundDistance, GlideMaxFeetDistanceFromGround, CombatMaxGlideHeight, GlideCombatRange
- Glide braking: GlideBrakingForceMin/Max, GlideBrakingForceDelay, GlideBrakingRampDuration, GlideBrakingMin/MaxSpeedDelta
- Height hold / lift (feathering): GlideUpwardForceHeightTarget, GlideUpwardMin/MaxForce, GlideUpwardMaxZVel, GlideUpwardForceDistanceCheck, GlideUpdraftMinZVel, GlideDownwardForceHeightTarget, GlideDownwardMin/MaxForce, GlideDownwardForceRampUpTime, GlideDownwardForceSwoopSpeedTransferRatio, GlideDownwardForceLastSwoopSpeedBonus, GlideDownwardForceSwoopSpeedFadeTime, GlideDownwardForceExitZVelocity
- Glide boost (hoops/jetstreams): GlideBoostBonusSpeed, GlideBoostDuration, GlideBoostDecayDuration, GlideBoostForceMul
- Dive: GlideDiveZTargetSpeed, GlideDiveZForceMin/Max, GlideDiveXYForceMultiplier, GlideDiveDistanceMin/Max, GlideDiveCancelDistance
- Heat: GliderHeatInboundDamageCoefficient, GliderFullHeatInboundDamageCoefficient, overheat penalty effects
- Abyss: AbyssThreshold, AbyssFallSlowDistMin/Max, AbyssFallSlowSpeedLimitMin/Max, AbyssFallSlowCurve, camera abyss zoom
- Mantle: MantleZDiffMax, MantleZImpulseMin/Max, MantleLaunchDelay, MantleEndDelay, MantleSuctionForceMin/Max, MantleSuctionForceDistanceMin/Max, MantleSuctionTraceDistanceMin/Max (+speed scaling, angle from north), MantleSuctionUpwardsForceMin/Max, MantleSuctionUpwardsForceHeightMax, MantleSuctionUpwardsForceZSpeedCap
- Jump: JumpZVelocity, JumpApexTime, JumpMaxHoldTime, JumpCooldown, AirJumpPressDuration, AirJumpZThreshold, JumpOffJumpZFactor, JumpDecelSpringConstant/DampingRatio/SpeedLimit, JumpEntry/TargetMin/MaxXY
- Air/dash: AirControlBoostMultiplier, AirControlBoostVelocityThreshold, AirDashSpeedMultiplier, AirDashSpeedClamp, FallingLateralFriction, DashCurves (per-ability velocity curves like C_AssaultSlide_VelCurve), DashClamp
- Spike: SpikeSlamForceZ, SpikeSlamForceStrengthThreshold, SpikeSlamForceAbsoluteThreshold

The names alone confirm how SUPERVIVE glides: it's a force-based height-hold system (an upward force pulls you toward a target height, a downward force pulls you down toward it, and "swoop" speed transfers from dropping into horizontal speed). That is the mechanic behind feathering. Mantling uses a "suction" force that pulls you toward a detected ledge, then a Z impulse.
