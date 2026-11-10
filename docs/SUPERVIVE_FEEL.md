# Supervive-style feel for Project Boki (phase 1: camera + movement)

Clean-room rebuild of the feel. Numbers now come first from the game data section below, then the wiki, guides and footage. The values come from the community wiki, published settings guides, frame-by-frame measurements of 60fps gameplay videos, or my estimates. Each one is tagged in `scripts/feel/feel_config.gd`: `[wiki]`, `[guide]`, `[footage]` or `[est]`.


## [game data] values read from the game files (Nov 2 2026): these win over every estimate below
The owner read these straight from the installed game (config files, curve tables and the hero movement component). Full tables: `ext/agent-briefs:briefs/supervive-data/supervive_physics.md` (kits: `supervive_kits.md`). 1 uu = 1 cm.

| Setting | Game value | In metres | Used here? |
|---|---|---|---|
| Gravity | -1470 uu/s² | -14.7 m/s² | **Yes**: `Hunter.H_GRAV`, one gravity up and down (match and home) |
| Jump velocity | 750 uu/s | 7.5 m/s (~1.9 m jump, apex ~0.51 s) | Partly: 6.8 m/s (1.5 m, 0.9 s in the air), so jump + mantle stays under our 4-terrace walls (the wall kick tops those) |
| Air control | 0.015 | almost no steering mid-jump | **No, owner ruling 11-08**: strong WASD air control (`Loco.air_step`, `content/rules/tuning.json` air), decision 0022 |
| Falling lateral friction | 0.375 | | **Yes**: `physics.air_friction`, a jump keeps its run-up |
| Run speed per hunter | 445-485 uu/s | 4.45-4.85 m/s | **Yes**: `content/rules/hunter_move.json` |
| Acceleration per hunter | 4700-5400 uu/s² | 47-54 m/s² | **Yes**: `HunterMove` (Oath, Kingpin 47; Tetra 50; others 54) |
| Braking (no input) | 2220 uu/s², GroundFriction 1.0 (x2 braking factor) | 22.2 m/s², 2/s | **Yes**: `physics.brake`, `physics.ground_friction`: a let-go from a run stops in ~0.17 s, ~0.3 m. Speed over a run (a kit step, a knock) sheds under the same brake, keys held or not, as UE does (`HunterMove.brake_rate`): a 10 m/s shove slides ~1.4 m (decision 0026) |
| Dash end | no hard stop (DashCurves not decoded; three heroes fitted from footage, below) | | **Yes**: a dash hands over at no more than run speed (`physics.dash_exit_run`), then the walk, brake or air carry; Ghost, Brall and Myth slow through their fitted curve first |
| Walkable floor | 50° | | n/a (heightmap) |
| Walk off ledges | off | you need a jump or dash to leave a platform | No, on purpose: the owner wants walking off ledges allowed everywhere |
| Mantle | pulls up ledges within 150 uu; Z speed cap 250 uu/s; mini-mantle launch 0.75 s at 0.6x forward speed, min 350 uu/s | 1.5 m, 2.5 m/s, min 3.5 m/s | **Yes**: reach 1.5 m; the rise is the suction (`HunterMove.rise_vy`: 175 m/s² while you rise slower than 2.5 m/s, so a jump's momentum carries you over); topping out sends you onto the ledge at max(0.6x run speed, 3.5 m/s) (`physics.mantle_launch_*`, decision 0026) |
| Turn rate | RotationRate yaw 1280°/s | | **Yes**: `physics.turn_rate`, a fixed rate to the cursor (a 180 in 0.14 s), match and farm (decision 0026) |
| Tall-ledge climb | Myth and Brall only | | **Yes**: Archer and Juggernaut (+0.9 m reach) |
| Abyss | death 1750 uu below; fall speed capped 1200 easing to 1000 uu/s between 100 and 1650 uu down; mantling out of the abyss allowed | 17.5 m; 12 to 10 m/s between 1 and 16.5 m | **Yes**: `Hunter.ABYSS_EXTRA` (17.5 m), `HunterMove.fall_cap` (12 m/s anywhere, easing to 10 in the abyss): ~1.9 s from the lip to the point of no return |
| Glide | height hold toward 850 uu; min Z -350 uu/s; start fall -85; swoop converts 2.5x falling speed to forward speed over 1.5 s | 8.5 m; -3.5 m/s | **Yes**: above 8.5 m the glider sinks at 3.5 m/s and the drop past its usual sink becomes speed (2.5x, fading over 1.5 s; `GlideLift.sink`) |
| Dive | Z target -3250 uu/s, ZForceMax 350,000 / Mass 100, XY force x0.25, cancel 350 uu up, 10 s timeout | -32.5 m/s at 35 m/s², steer 0.25, 3.5 m, 10 s | **Yes**: hold crouch under the glider (`GlideDive`, `HunterMove.dive_*`); the key is ours, the source names none |

Still unknown (encrypted C++ defaults): base glide speeds and gravity factor, glide braking, hoop boost, jump hold time, air-dash multipliers. Keep current tuning for those (TODO).

## Dash speed curves, fitted from footage (Nov 9 2026)
The game's DashCurves (e.g. `C_AssaultSlide_VelCurve`) sit in the encrypted code, so these come from the hero-ref sheets (`ext/agent-briefs:briefs/hero-ref/<hero>.md`, "Body, scale and movement feel" section 4). The sheets tracked the hunter's bar plus the camera pan at 30 fps and give the ground speed over each 1/15 s; the 5 fps frames alone (0.2 s) hold only 2-3 frames of a dash, too few for a shape, so the 1/15 s samples are the evidence here. 1 px (960 wide) = 0.0375 m. Model: speed rises in a straight line from a start speed to a peak, holds, then falls in a straight line to the end; least squares on the interval averages (each sample is the mean over its 1/15 s, not a point), knots on a 0.01 grid.

| Hero (ours) | Samples used (px/s per 1/15 s) | Window | Start / peak / end (m/s) | Ramp, plateau | Mean | RMS error | Kit curve (`content/rules/dash_feel.json`, u: k) | Hand-over |
|---|---|---|---|---|---|---|---|---|
| Ghost (gunslinger, Slipstep tap) | 332 454 377 287 213 144 86 (552.75-553.3 s, frames 0150-0152) | 0.47 s, 4.73 m | 0.1 / 18.4 / 1.4 | 0.04 s, 0.02 s | 10.2 m/s | 0.30 m/s (3%), max 0.47 | 0: 0.01, 0.09: 1.81, 0.13: 1.81, 1: 0.13 | last sample 0.78x run: the skid falls through run speed and the walk takes it |
| Brall (juggernaut, Rampage) | 143 365 423 336 266 190 112 (inside 434.40-435.35 s, frames 0372-0377) | 0.47 s, 4.59 m | 1.2 / 17.1 / 2.8 | 0.13 s, 0.01 s | 9.8 m/s | 0.11 m/s (1%), max 0.23 | 0: 0.12, 0.27: 1.73, 0.29: 1.73, 1: 0.28 | last sample 1.08x run |
| Myth (archer, Spirit Walk roll) | 147 346 447 258 125 (from 655.55 s, frames 0388-0389) | 0.33 s, 3.31 m | 1.7 / 18.4 / 1.2 | 0.15 s, none | 9.9 m/s | 0.45 m/s (4.5%), max 0.78 | 0: 0.17, 0.44: 1.86, 1: 0.12 | last sample 1.11x run, straight into the Spirit Walk |
| Felix (ashwick, Soot Ram) [?] | none per frame: "about 700 px/s (1080p) for the first 0.1 s, then 450-500, then it stops dead" (245.53-245.87 s, frames 0159-0160) | 0.33 s, 3.4 m | n/a | n/a | 10 m/s | n/a | none: the kit's own two-step (1.4x for the first 30%, then 0.85x, `RAM_FRONT*`) stays | `dash_exit_run` [?] (the sheet says a dead stop) |

How the game uses them: the curve is in the dash's own time (u = share of its duration) and speed against its mean (mean 1), so each kit keeps its distance and time; only the shape is the source's (`ArchKit.travel` with `"curved"`, `HunterMove.dash_k`). The dash then hands over through `HunterMove.dash_exit`: never above run speed, so a curve that ends under run speed (Ghost 0.48x, Myth 0.31x of ours) hands over that slower speed and the walk (47-54 m/s²) brings it back to run in ~0.05 s with keys held, as the footage's last samples dip and recover. Our Rampage is 0.20 s against Brall's 0.47 s (owner, item 113: "a quicker Rampage"), so the same shape peaks at ~34 m/s (1.73 x 19.5); the source peak is 17 m/s. Air dashes, Ghost's hold slide and every other hero keep a constant speed (no footage). `--move-feel-check` asserts each fitted hero's peak share, peak / mean, distance and hand-over (`dash_curve_*`).

## What's in it

| File | What it does |
|---|---|
| `scripts/feel/feel_config.gd` | Every tunable in one Resource. Save it as a `.tres` to give different weapons or kin their own feel. |
| `scripts/feel/hunter_controller.gd` | CharacterBody3D. Covers WASD, jump, hold-to-glide with heat, abyss lift, feathering, the glider balloon, spiking, dash/ex-dash (or tap/hold), deep mantling, jump pads, cursor aim and the aim laser. |
| `scripts/feel/top_down_camera.gd` | Fixed-angle camera with Supervive's 3 presets, zoom-out while gliding, and a purple screen tint that deepens the further you sink into the abyss. |
| `scripts/feel/jump_pad.gd` | Launch pad that keeps your momentum. |
| `scripts/feel/glide_zone.gd` | Wind rings (cool the glider + boost), jetstreams (no heat, faster), abyss storm clouds (more heat, slower). |
| `scripts/combat/class_profile.gd`, `weapon_profile.gd`, `data/` | Light/medium/heavy classes and 9 guns/swords as data files. See KINFALL_CLASSES.md. |
| `scripts/combat/weapon_user.gd`, `projectile.gd`, `training_dummy.gd` | Weapon firing (guns and swords), projectiles, and practice dummies. See WEAPON_FIRING_DATA.md. |
| `tests/weapons_sim.gd` | Headless weapon check: `godot --headless --path . -s tests/weapons_sim.gd` |
| `scripts/match/` + `data/rules/` | Downed (wisp), deathboxes, revives, revive beacons, team wipes, solo rules, kin hooks. See DEATH_AND_REVIVE.md. Test: `tests/life_sim.gd` |
| `scripts/feel/kinfall_input.gd` | Registers default binds at runtime (`kf_*` actions). |
| `scenes/feel_test.tscn` | Playground: islands over an abyss, a raised island to mantle onto, pillars, a jump pad and a debug HUD. |
| `tests/feel_sim.gd` | Headless check: `godot --headless --path . -s tests/feel_sim.gd` |

## Controls (Supervive defaults)
WASD move · Space jump (tap) / glide (hold in air) · Shift dash · Ctrl sneak · LMB/RMB attack (the hunter turns to face the cursor) · F1/F2/F3 switch camera preset, 1/2/3 switch class and 4/5/6 switch weapon in the test scene.

## What the footage showed

Videos studied: TheSixGame's full walkthrough (60fps), Ryan Lemur's Celeste guide and Legend solo queue game, Ryan Lemur's all-abilities video, Tom Kick's gliding guide, and Zik's abyss/spike guide.

**Camera**
- Pitch is ~65° (steep, close to top-down) with ~35° vertical FOV, sitting ~25m away. The screen shows ~28m of ground side to side.
- The hunter stays roughly centered and only shifts when the cursor pans the camera.
- The camera visibly zooms out while gliding.
- The screen goes purple as you sink below island level, and darker the deeper you go.

**Gliding**
- Glide speed is ~5 m/s, about the same as running.
- A glider over the abyss holds at island level rather than sinking. Two players in Tom Kick's guide glide level for ~14s before the heat ring by the nameplate turns hot.
- Lift is what eats heat. In Zik's drill, a player walks off an edge, free-falls ~1s (about 8m deep), opens the glider and is back at island level ~1s later. That one lift burns roughly a quarter to a third of the glider.
- Heat keeps climbing across repeated drop-and-lift (feathering) cycles. It only really cools on the ground.
- A balloon on a string appears about 0.25s after stepping off an edge. It stays at island level and glows purple while you glide, which is the cue that you can be spiked.

**Mantling**
- Falling players who touch an island wall spring back onto it, even from a full second deep. It takes ~0.8s.

**Dash**
- Some kits use tap Shift for a short dash and hold Shift for a longer dash on a longer cooldown. This is in as `dash_hold_for_ex`.
- Dash length is different for every hunter. Kinfall's dodge comes from the weapon, so the values here are only a baseline.

## Rules from the wiki
- Run speed is 465 units (4.65 m/s).
- Shiv's attack range is 850 units (8.5m), which is the aim laser length.
- Jin's dash cooldown is 7s and his ex-dash cooldown is 12.5s.
- Most hits on a glider deal double damage and knock them out of the air, with a stun on landing.
- Spiking an overheated or below-ground glider stuns them and sends them plummeting. Over ground the stun is 0.7s.

## Headless sim results (Godot 4.6.2)
| Check | Result | Footage / source |
|---|---|---|
| Run to 95% speed / stop | 0.07s / 0.07s | snappy MOBA feel |
| Glide over abyss until overheat | 14.1s | ~14s |
| Walk off edge, fall 1s | 9.2m deep, balloon at 0.13s | ~8m, ~0.25s |
| Open glider from there | back at island level in 1.25s, 30% heat | ~1s, ~25–35% |
| Deep mantle from 7m below | ✓ | ✓ |
| Hit while gliding | x2 damage, glider drops | wiki |
| Jump | 1.28m apex, 0.62s | [est] |
| Mini / ex dash | 3.9m / 6.7m | [est] |

## Combat hooks for Project Boki
`incoming_damage_multiplier()` · `notify_damaged()` (drops gliders) · `try_spike()` / `is_spikeable()` · `depth_below_ground()` · `launch(impulse)` · `main_ability_on_cooldown`. Signals: `dashed`, `glide_started`/`glide_ended`, `overheat_started`, `overheat_tick(damage)`, `mantled`, `spiked`, `fell_into_abyss`.

## Still estimates
- Jump height: I didn't find a clean plain jump in any of the videos.
- Dash distance per weapon.
- Glider damage while overheated, spike plummet speed, and the jump pad's launch strength.

Tune them in `feel_config.gd`, then rerun the sim.
