## Traversal parity with the target feel's data (11-25 / 11-26, `--traversal-parity-check`)

Owner 11-26: fluidity, physics and the rules around jumps and gliding on par with the target feel. Numbers come from
the private data (cm / 100 = m; speeds x `body_scale` 1.16); ours are rows in `content/rules/hunter_move.json`
`physics` and `content/rules/tuning.json` `air`. The full gap table (theirs, ours, felt effect) is in the private
reports. The jump pad, a glide after an attack and the glide animation are other branches' and untouched here.

| Rule | Before | After |
|---|---|---|
| Coyote window | 0.12 s [est] | 0.25 s (`coyote_s`) |
| Crouch walk | 0.5 of run | 0.4 (`sneak_speed`) |
| Glide cruise | 5.0 m/s (5.8 at body scale) | 7.0 m/s (8.12): the data's settled glide speed |
| Glide sink | 1.4 m/s [est] | 1.25 m/s (`glide_sink`) |
| Glider refill on the ground | 1.2 s, in code | 2.0 s (`glide_regen_s`) |
| Glider open, falling | the fall kept, eased at 60 m/s^2 | caught at once at 0.85 m/s down (`Loco.glide_start`); the abyss pull still reads the fall you came in with |
| Glider open, rising | cut to a 0.85 m/s fall | the rise kept up to 2.5 m/s near the ground, none from 5 m up (`glide_rise_vy`, `glide_rise_h`) |
| Jump press falling near the ground | glider refused under ~0.9-1.7 m; the press kept 0.12 s | under 1.5 m (`land_buffer_h`) the press is kept until the landing and jumps there (`HunterMove.jump_hold`): never lost |
| Air, no keys | 0.4 of the speed lost a second | 0.75 (`air.idle_drag`) |
| Dash-jump | 0.75 of the dash, then air drag (a 19 m/s dash-jump hops ~8.7 m) | a jump faster than 9.3 m/s sheds the extra over ~0.3 s to 5.8-8.1 m/s (`jump_trim_*`, `JumpTrim`): ~6.7 m |

Kept on purpose (owner calls, the reference's number is noted in the private table): air control strength (owner
11-08), glide heat 9 s (owner 11-02), the dash-glide carry (owner playtest 11-13), turn rate 1280 deg/s, jump
speed (its own branch), ledge climbing anywhere (the reference mantles only at the abyss edge).
