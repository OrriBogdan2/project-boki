# Movement tuning: our values and what each is for

The numbers Project Boki ships for camera, running, jumping, gliding, mantling and dashing. They are ours: the target is a
snappy, responsive top-down feel (owner note, Oct 31 2026: dropping, gliding and moving felt sloppy). Details and checks
are in [MOVEMENT_FEEL.md](MOVEMENT_FEEL.md) (`--move-feel-check`, `tools/move_feel_check.gd`). Where a value lives is in
the last column; retune there, not in code.

| Area | Our value | Intent | Lives in |
|---|---|---|---|
| Gravity | 14.7 m/s², one gravity up and down (match and farm) | one fall feel everywhere | `Hunter.H_GRAV` |
| Jump | 6.8 m/s (1.5 m, ~0.9 s in the air) | jump + mantle stays under the 4-terrace walls; the wall kick tops those | `Hunter.JUMP_V` |
| Air control | strong WASD steering mid-jump | owner ruling 11-08, decision 0022 | `content/rules/tuning.json` air, `Loco.air_step` |
| Falling lateral friction | 0.375 | a jump keeps its run-up | `physics.air_friction` |
| Run speed | 4.45-4.85 m/s per hunter | each hunter reads its own weight | `content/rules/hunter_move.json` |
| Ground acceleration | 47-54 m/s² per hunter | run speed in ~0.1 s | `HunterMove` |
| Braking | 22.2 m/s² + 2/s of speed | a let-go from a run stops in ~0.17 s, ~0.3 m | `physics.brake`, `physics.ground_friction` |
| Turn to cursor | fixed 1280°/s (180° in 0.15 s), match and farm | the aim never lags the mouse | `physics.turn_rate` |
| Mantle | reach 1.5 m; rise capped at 2.5 m/s of suction | ledges pull you up, never yank | `HunterMove.rise_vy`, `mantle_vy_cap`, `mantle_pull` |
| Tall ledges | Archer and Juggernaut reach +0.9 m | two heavy climbers | `hunter_move.json` climb_tall |
| Abyss | kill depth 17.5 m under the lip; fall capped 12 m/s easing to 10 m/s | a recoverable drop, a real danger | `Hunter.ABYSS_EXTRA`, `physics.fall_cap` |
| Glide | holds toward 8.5 m height; sinks at 3.5 m/s above it | glide level over a gap, never a free climb | `physics` glide_* |
| Dive | -32.5 m/s at 35 m/s², steer x0.25, 3.5 m cancel, 10 s timeout | hold crouch under the glider | `GlideDive` |
| Dash exit | hands over at no more than run speed | no dead stop; the walk, brake or air carry takes over | `physics.dash_exit_run`, `HunterMove.dash_exit` |
| Dash shape | per-kit speed curve over the dash's own time, mean 1 | each kit keeps its distance and time; only the shape differs | `content/rules/dash_feel.json`, `ArchKit.travel` |
| Input buffer through dashes | 0.15 s | a press during a dash still fires | `DashFlow.BUFFER_S` |

## Camera
- Pitch about 65° with a ~35° vertical lens, ~23 m back: the screen shows ~28 m of ground side to side.
- The hunter stays near the centre and the view leans toward the cursor (default follow preset).
- The view zooms out while gliding, and tints purple the deeper you sink under the island level.
- Presets: `content/rules/camera.json`.

## Gliding
- Glide speed ≈ run speed (about 5 m/s).
- A glider over the abyss holds near island level for ~14 s before it overheats; the lift after a drop burns a quarter to a third of the heat, and it only cools on the ground.
- A balloon appears ~0.25 s after stepping off an edge and glows while you can be spiked.
- A hit on a glider deals double damage and knocks it out of the air; spiking an overheated or sunk glider stuns it (0.7 s over ground).

## Still open
Jump height by weapon, dash distance per weapon, overheated-glider damage, spike fall speed and jump-pad strength are our own picks: tune in `content/rules`, then rerun `--move-feel-check`.
