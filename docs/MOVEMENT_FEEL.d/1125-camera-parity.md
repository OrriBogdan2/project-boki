## Camera parity with the target feel's data (11-25, `--cam-zoom-check`, `--cam-framing-check`)

Owner 11-25: match physics, momentum, movement, camera. Numbers come from the private data (cm / 100 = m); ours are in
`content/rules/camera.json`. The farm camera, the fall / skydive camera and the footage-fitted follow trail are untouched.

| Item | Target data | Before | After |
|---|---|---|---|
| Default follow | cursor pan: deadzone 0.1, maxzone 0.9, quadratic, 100%, 5.5 m sideways, 7.25 m up, 7.75 m down, critical spring (power 5: k 766.7, omega 27.7) | `centred` (no pan) | `pan` (default; once-only migration moves a saved `centred` to it; Centred / Locked stay in Settings); the lean is held to the screen's room and the HUD groups as before |
| Pan hysteresis band 0.225 / 0.325 | in the data | - | not used: no stated meaning |
| Lens | 59 deg horizontal = 35.3 deg vertical at 16:9 | 32 deg vertical (footage band 25-34) | kept (the farm shares the default style); the coverage is matched through the wheel's range |
| Ground across, widest / closest | 34.2 m (30.2 m arm) / 22.9 m (20.2 m arm) | 37.5 m / 12.9 m | 34.2 m / 22.9 m |
| Wheel | 4 notches of 2.5 m | 10 notches of 0.1 (0.55..1.6) | 4 notches of 0.1206 (0.9748..1.4572); the farm keeps 0.55..1.6 |
| Ctrl look | none in the data | 2.24x (51.5 m back) | 2.24x (kept: `match.ctrl` 1.5372 x the new max) |
| Glide zoom | +5.81 m of arm (+19%) | x1.25 in code | +6.45 m (5.81 x 1.1098), `zoom.match.glide_m` |
| Abyss zoom | +0.5..+15 m of arm over 3.5..10 m deep | none | +0.56..+16.65 m, none under 3.5 m (`zoom.match.abyss`) |
| Arm spring | critically damped, omega 10 | exponential, 2.5 /s (95% in 1.2 s) | critical spring, omega 10 (95% in 0.47 s), match only |
| Follow lag | location lag speed 18, max lag 2.5 m | rate 15, catch decel 28, max gap 3.5 m (footage) | unchanged, see below |
| Shakes | light attack 0.1 s, jump pad 0.3 s, heavy ult 0.4 s, FOV pop | owner rule: no shake from your own actions; hits on you 0.15 s positional | unchanged, see below |

- **1 m of the data's arm = 1.1098 m of ours.** Our lens is 32 deg vertical (1.0196 m of ground per metre back at 16:9),
  the data's 59 deg horizontal gives 1.1315 m per metre of arm, so a 30.2 m arm and our 33.5 m back (1.4572 x 23 m) show the
  same 34.2 m of ground. The `source` band `across_m` is now 34..39 (the data's 34.2 joins the footage's 35-39).
- **Follow lag, simulated** (a 6 m/s run for 1.5 s then a stop; a 4.6 m dash in 0.12 s): ours trails 0.62 m at a run,
  stops in 0.18 s, peaks 3.4 m behind a dash and is back within 0.1 m after 0.42 s; a pure lag of speed 18 capped at 2.5 m
  trails 0.32 m, stops in 0.10 s, peaks 1.8 m and settles in 0.16 s. Ours is the footage's fit (decision 0050: a dash pan
  peaks ~700 px/s and stops ~0.5 s, which the data's lag would not reproduce), so it stays; a lag of 18 would be the
  next try if the owner reads ours as floaty.
- **Shakes:** the data's rotational shakes (pitch 0.28-0.6 deg at 8-34 Hz) belong to the shooter's own attacks, jump pads
  and ults; ours is a positional jitter only for big things that happen TO you (owner rule, `shake.json`), so only the
  heavy-ult row matches an event, and it differs in kind and length (0.4 s vs the door's 0.15 s). No data change.
- Not touched: the `p.y < 0` rule that the view sinks with you below the lip (the abyss zoom adds to it).
