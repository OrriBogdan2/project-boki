# 0026: Supervive movement pass (turn rate, over-run brake, mantle suction, one dash shape)

## Problem
Owner 11-09: does the game FEEL like Supervive? Locomotion against the source data
(`ext/agent-briefs:briefs/supervive-data/supervive_physics.md`, `PHYSICS_PARITY.md`, `MANTLE_185b.md`),
measured with `--move-feel-check` and `--cliff-mantle-check` before and after:

| Area | Source | Ours before | Ours now |
|---|---|---|---|
| Turn to cursor | RotationRate yaw 1280°/s, fixed | exponential 20/s (farm 14/s): 20° flick 0.13 s, 180° ~0.22 s | fixed 1280°/s: 0.017 s, 0.150 s |
| Over-run speed on the ground (knock, kit step) | UE walking brake 2/s + 22.2 m/s², keys or not | 110 m/s² no keys, 30 with keys: a 10 m/s shove slides ~0.7 m | the source brake: 1.33 m (1.09 m to a run with keys) |
| Mantle rise | suction ≤ 175 m/s² while rising < 2.5 m/s, within 1.5 m | set to 4-14 m/s every step (a yank) | jump momentum + suction to 2.5 m/s; peak 14 -> 5.6 m/s |
| Dash shape (Myth) | footage curve (0025) | curve x cos ease stacked: 1.09x the distance | the curve x 0.7 speed (owner item 9): 1.0x |
| Ground accel / stop | 47-54 m/s²; brake 22.2 + 2/s | same (0020) | same |
| Gravity / fall cap | 14.7 m/s²; 12 -> 10 m/s abyss | same | same |
| Jump | 7.5 m/s | 6.8 m/s (terraces, 0020) | same |
| Air control | 0.015 | strong (owner 11-08, 0022) | same |
| Knockback vs mass | Mass 100 and Knockback 1.0 for all 12 | mass 1.0 for all (same ratio); 0.12-0.35 s of 6 m/s² no-control [?] | same, then the source brake |
| Walk while firing | not in the data [?]; Shiv footage 0.68-0.76x, unsettled | weapon fire_slow 0.5-1.0 (default 0.8) | same |
| Dash end lag | DashCurves not decoded | hand-over at run speed; 3 of 12 curves fitted | same |
| Input buffer through dashes | no data field; one 5 fps frame | DashFlow.BUFFER_S 0.15 s | same (0.2 s waits on ext/dash-buffer-window) |

## Choice
Fix the four rows that differ from the data: the turn rate (`hunter_move.json` turn_rate), the over-run brake
(`HunterMove.brake_rate`, `slide_speed`; GROUND_SHED and GROUND_OVERSPEED deleted), the mantle suction
(`HunterMove.rise_vy`, mantle_vy_cap, mantle_pull) and one dash shape (tuning.json dash_speed on the
dash_feel.json curve). The [?] rows keep our numbers until the data or footage settles them.

## Affects
Every hunter, the farm avatar (turn, brake, ledge float, dash). Mantles from a slow arrival are slower
(a glide into a 1.6 m face 0.23 -> 0.59 s); revert knob: mantle_vy_cap. Knocks slide ~20% further.
No Net or save change.
