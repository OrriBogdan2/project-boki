# Supervive-style feel for Project Boki (phase 1: camera + movement)

The lab this describes (`scripts/feel/`, `--feel-lab`, `tests/feel_sim.gd`) was deleted on 11-09 (briefs/STATE_MACHINES.md M1): the live movement is `Hunter` + `Loco` (docs/decisions/0022). The numbers and footage notes below are still the sources.

Clean-room rebuild of the feel. Numbers now come first from the game data section below, then the wiki, guides and footage. The values come from the community wiki, published settings guides, frame-by-frame measurements of 60fps gameplay videos, or my estimates. Each one is tagged in `scripts/feel/feel_config.gd`: `[wiki]`, `[guide]`, `[footage]` or `[est]`.


## [game data] values read from the game files (Nov 2 2026): these win over every estimate below
The owner read these straight from the installed game (config files, curve tables and the hero movement component). Full tables: `ext/agent-briefs:briefs/supervive-data/supervive_physics.md` (kits: `supervive_kits.md`). 1 uu = 1 cm.

| Setting | Game value | In metres | Used here? |
|---|---|---|---|
| Gravity | -1470 uu/s² | -14.7 m/s² | **Yes**: `Hunter.H_GRAV`, one gravity up and down (match and home) |
| Jump velocity | 750 uu/s | 7.5 m/s (~1.9 m jump, apex ~0.51 s) | Partly: 6.8 m/s (1.5 m, 0.9 s in the air), so jump + mantle stays under our 4-terrace walls (the wall kick tops those) |
| Air control | 0.015 | almost no steering mid-jump | **Yes**: keys steer at 0.015x ground accel (`physics.air_control`), a jump keeps its run-up; ledge rises still steer crisply |
| Falling lateral friction | 0.375 | | **Yes**: `physics.air_friction`, a jump keeps its run-up |
| Run speed per hunter | 445-485 uu/s | 4.45-4.85 m/s | **Yes**: `content/rules/hunter_move.json` |
| Acceleration per hunter | 4700-5400 uu/s² | 47-54 m/s² | **Yes**: `HunterMove` (Oath, Kingpin 47; Tetra 50; others 54) |
| Braking (no input) | 2220 uu/s², GroundFriction 1.0 (x2 braking factor) | 22.2 m/s², 2/s | **Yes**: `physics.brake`, `physics.ground_friction`: a let-go from a run stops in ~0.17 s, ~0.3 m. Speed over a run with no keys (a kit step, a knock) sheds at `Hunter.GROUND_SHED` first (kit distances) |
| Dash end | no hard stop (dash curves not decoded) | | **Yes**: a dash hands over at run speed (`physics.dash_exit_run`), then the walk, brake or air carry |
| Walkable floor | 50° | | n/a (heightmap) |
| Walk off ledges | off | you need a jump or dash to leave a platform | No, on purpose: the owner wants walking off ledges allowed everywhere |
| Mantle | pulls up ledges within 150 uu; Z speed cap 250 uu/s; mini-mantle launch 0.75 s at 0.6x forward speed, min 350 uu/s | 1.5 m, 2.5 m/s, min 3.5 m/s | Reach 1.5 m; topping out sends you onto the ledge at max(0.6x run speed, 3.5 m/s) (`physics.mantle_launch_*`) |
| Tall-ledge climb | Myth and Brall only | | **Yes**: Archer and Juggernaut (+0.9 m reach) |
| Abyss | death 1750 uu below; fall speed capped 1200 easing to 1000 uu/s between 100 and 1650 uu down; mantling out of the abyss allowed | 17.5 m; 12 to 10 m/s between 1 and 16.5 m | **Yes**: `Hunter.ABYSS_EXTRA` (17.5 m), `HunterMove.fall_cap` (12 m/s anywhere, easing to 10 in the abyss): ~1.9 s from the lip to the point of no return |
| Glide | height hold toward 850 uu; min Z -350 uu/s; start fall -85; swoop converts 2.5x falling speed to forward speed over 1.5 s | 8.5 m; -3.5 m/s | **Yes**: above 8.5 m the glider sinks at 3.5 m/s and the drop past its usual sink becomes speed (2.5x, fading over 1.5 s; `GlideLift.sink`) |
| Dive | Z target -3250 uu/s, ZForceMax 350,000 / Mass 100, XY force x0.25, cancel 350 uu up, 10 s timeout | -32.5 m/s at 35 m/s², steer 0.25, 3.5 m, 10 s | **Yes**: hold crouch under the glider (`GlideDive`, `HunterMove.dive_*`); the key is ours, the source names none |

Still unknown (encrypted C++ defaults): base glide speeds and gravity factor, glide braking, hoop boost, jump hold time, air-dash multipliers. Keep current tuning for those (TODO).

## What's in it

| File | What it does |
|---|---|
| `scripts/combat/class_profile.gd`, `weapon_profile.gd`, `data/` | Light/medium/heavy classes and 9 guns/swords as data files. See KINFALL_CLASSES.md. |
| `scripts/combat/weapon_user.gd`, `projectile.gd`, `training_dummy.gd` | Weapon firing (guns and swords), projectiles, and practice dummies. See WEAPON_FIRING_DATA.md. |
| `tests/weapons_sim.gd` | Headless weapon check: `godot --headless --path . -s tests/weapons_sim.gd` |
| `scripts/match/` + `data/rules/` | Downed (wisp), deathboxes, revives, revive beacons, team wipes, solo rules, kin hooks. See DEATH_AND_REVIVE.md. Test: `tests/life_sim.gd` |

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
