## Movement parity pass 2 against the reference's decoded client numbers (2026-11-25)

Reference uu = cm (divide by 100 for m). "Ours" is `content/rules/hunter_move.json` (and `tuning.json`) on main before this change.
Changed rows are retagged [game data]; `--move-feel-check` 0 failures, `--move-rate-check` red only on the 5 farm-stop rows that were red on main.

| Param | Reference (m) | Ours before | Tag | Verdict |
|---|---|---|---|---|
| MoveSpeed 430-490 | 4.30-4.90 (455/465 most) | 4.45-4.85 per kit | [game data] | same |
| MaxMoveSpeed | 7.0 | speed_cap 7.0 | [game data] | same |
| MaxAcceleration 4700-5400 | 47-54 | 47-54 per kit | [game data] | same |
| Braking walking / ground friction | 22.2 / 1 | 22.2 / 1 | [game data] | same |
| Backpedal coefficient 1.0 | no slow | no slow | [game data] | same |
| Yaw | instant snap (inferred) | turn_rate 1280 deg/s (180 deg in 0.15 s) | [game data] RotationRate | held: the earlier decoded RotationRate is a read, the snap is inferred |
| Jump velocity | 7.5 | 6.8 | owner ruling (KIT_PARITY item 20: 7.5 + mantle tops four terraces) | held-owner |
| Gravity | 14.7 | 14.7 | [game data] | same |
| Apex / ground-to-ground | 1.91 m / 1.02 s | 1.52 m / 0.90 s (follows the jump velocity) | ruling | held-owner |
| Air control 0.015 x 50000 | 7.5 m/s^2 per full input | 32 m/s^2 (tuning.json air) | [owner 11-08] | held-owner |
| Air friction | 0.375 | idle_drag 0.4 | tuning.json | same (7%) |
| Coyote time | 0.25 s | 0.12 s [est] | now [game data] | **change** 0.12 -> 0.25 |
| Sneak multiplier | 0.4 | 0.5 | now [game data] | **change** 0.5 -> 0.4 |
| Abyss fall cap | 12 -> 10 over 1.0-16.5 m | the same | [game data] | same |
| Terminal velocity | unresolved | fall_cap 12 | - | unused |
| Glide settled speed | target 8.0, settles ~7.0 (measured ~7.2) | glide_cruise 5.0 (a MaxGlide 500 read) | now [game data] | **change** 5.0 -> 7.0 (x body_scale 1.16 = 8.12 m/s) |
| Glide thrust 162500 / mass 100 | 16.25 m/s^2 | glide_accel 16.25 | [game data] | same |
| Glide sink cap (min Z velocity -125) | 1.25 m/s | glide_sink 1.4 [est] | now [game data] | **change** 1.4 -> 1.25 |
| Glide gravity factor 0.025 | 0.37 m/s^2 | glide_grav (owner row) | - | same in effect: the sink cap rules |
| Ceiling pushdown | 8.5 m above terrain | glide_height 8.5 | [game data] | same |
| Floor push-up 1.5 m above terrain | - | none (the glider lands) | - | design-different, not built |
| Glide entry speed 4-9.5 held 0.45 s, decays 0.55 s | ~1 s to settle | tuning.json glide.drag / carry_drag: dash-glide 12.8 m/s at 1 s, near cruise at 3-4 s | [owner 11-13 playtest] | held-owner |
| Lateral friction 0.6, braking factor 2.0 | - | glide turn / brake rows | [owner 11-13] | held-owner |
| Repeat-glide leniency 0.4 s, ability hold 0.4 s | - | dash_glide grace 0.15 s, Space hold 0.1 s | [owner 11-13] | held-owner |
| Glide-start ground distance 1.5 / 0.5 m | - | opens anywhere | - | design-different |
| Glide camera zoom 1.25x | 1.25x | 1.25x (CamRig) | docs | same (the 1 s delay lives on ext/cam-parity-1125) |
| Fuel: drain 80/500 per s | full tank 6.13 s | glide_heat_s 9.0 | [owner Nov 2] | held-owner: unchanged |
| Fuel regen 0.5 x max per s | 2.0 s empty to full | 1.2 s on the ground, a magic number | [est] | **change** 1.2 -> 2.0 (`glide_regen_s`) |
| Damage-to-fuel 1.4 x damage | - | hit_heat 3.0 [est] | [est] | held: the unit differs (our share of heat), not mapped |
| Spike crash velocity | -80 m/s after a 0.18 s freeze + 0.125 s gap | fall_vy 6 m/s | [?] | design-different: needs the freeze/gap sequence, not a number |
| Landing stun | 0.7 s | land_stun 0.7 | [wiki] | same |
| Slam stun / force / heat, kill-credit window, collision damage | see brief | not modelled as such | - | design-different |
