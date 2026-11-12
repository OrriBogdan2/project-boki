# 0026: Movement pass (turn rate, over-run brake, mantle suction, one dash shape)

## Problem
Owner 11-09: does locomotion feel as snappy as the target? Four values were off, measured with `--move-feel-check` and
`--cliff-mantle-check` before and after:

| Area | Ours before | Ours now |
|---|---|---|
| Turn to cursor | exponential 20/s (farm 14/s): 20° flick 0.13 s, 180° ~0.22 s | fixed 1280°/s: 0.017 s, 0.150 s |
| Over-run speed on the ground (knock, kit step) | 110 m/s² no keys, 30 with keys: a 10 m/s shove slides ~0.7 m | brake 22.2 m/s² + 2/s: 1.33 m (1.09 m to a run with keys) |
| Mantle rise | set to 4-14 m/s every step (a yank) | jump momentum + suction to 2.5 m/s within 1.5 m; peak 14 -> 5.6 m/s |
| Dash shape (Myth) | curve x cos ease stacked: 1.09x the distance | the curve x 0.7 speed (owner item 9): 1.0x |

Unchanged: ground accel 47-54 m/s² and brake (0020), gravity 14.7 m/s² and the abyss fall cap, jump 6.8 m/s
(terraces, 0020), strong air control (owner 11-08, 0022), mass 1.0 for all hunters, walk-while-firing from the weapon
`fire_slow` (0.5-1.0, default 0.8), dash hand-over at run speed (0025), input buffer through dashes `DashFlow.BUFFER_S` 0.15 s.

## Choice
Fix the four rows above: the turn rate (`hunter_move.json` turn_rate), the over-run brake (`HunterMove.brake_rate`,
`slide_speed`; GROUND_SHED and GROUND_OVERSPEED deleted), the mantle suction (`HunterMove.rise_vy`, mantle_vy_cap,
mantle_pull) and one dash shape (tuning.json dash_speed on the dash_feel.json curve).

## Affects
Every hunter, the farm avatar (turn, brake, ledge float, dash). Mantles from a slow arrival are slower
(a glide into a 1.6 m face 0.23 -> 0.59 s); revert knob: mantle_vy_cap. Knocks slide ~20% further.
No Net or save change.
