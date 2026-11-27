## Abyss fall, edge pop and their momentum vs the target feel (11-27, `--abyss-edge-check`)

Owner 11-27: the abyss fall, the bounce on the edge (not the climb) and the momentum out of it must be the
reference's; the reference is right on every number unless proven otherwise. Reference numbers come from the
private data (cm / 100 = m; horizontal speeds x `body_scale` 1.16, vertical ones unscaled, as for the jump).
"Before" = origin/main 68c8f5f0f8. Values now live in `content/rules/hunter_move.json` `edge_mantle`;
the law is `scripts/match/mantle_carry.gd` (MantleCarry), wired in `scripts/match/hunter.gd`.

| # | What | Reference | Before (origin/main) | After | Status |
|---|---|---|---|---|---|
| 37 | Abyss fall cap | 12 -> 10 m/s from 1 to 16.5 m under the lip, an ease-in curve (0.25 of the way: 0.063; half: 0.254; 0.75: 0.576) | the same ends, but linear (hunter_move.gd:251, hunter_move.json:13-16) | ease-in (u^2, within 0.013 of the curve's keys); lip to the point of no return 1.97 s (ref 1.97 s) | MATCH |
| 38 | Point of no return | 17.5 m under the ground level, gliding or not | 17.5 m, plus 1.5 m for a glider with heat (tuning.json:130, hunter.gd:1931) | 17.5 m for everyone | MATCH |
| 39 | Warning tint / sound | tint from 0.25 m down, full 3.5 m before the end; sound from 3 m | tint from 4 m, full at the kill depth; sound with the tint (abyss_danger.json:3, abyss_fx.gd:54) | tint from 0.25 m, full 3.5 m above the kill depth (14 m down); sound from 3 m (the owner's 11-17 ask was "graded + rising sound"; the 4 m was a worker's number) | MATCH (ends; the curve between is ours: its keys are not decoded) |
| 40 | Recovery | touching an island's side over the abyss while falling, gliding or dashing: one launch straight up at 9 + 16.5 x (lip height over the feet / 17.5) m/s (9-25.5), cooldown after; the glider's own floor pull under the lip: 10 -> 40 m/s^2 over 0-20 m deeper, cap 15.5 m/s, stops dead at its top | a continuous glider lift 22 + 7/m m/s^2, cap 18.2, brake + 4.5 m/s bounce (hunter.gd:824-832, tuning.json:117-125); an opening spring +6 m/s (glide_lift.gd:14); a side caught you only down to 4.5 m (tuning.json:128); a slow float up the face (lrise) | the one-shot launch at any depth over the abyss (MantleCarry.launch); glider lift on the reference law, letting go at the lip + 0.6 m; no spring | MATCH (lift: INFERRED, see unknowns) |
| 40b | Full mantle (lip >= 3 m above the feet) | held 0.1 s with no gravity, rising at 0.25 x your speed, all sideways speed gone; then the launch | (none) | the same (MantleCarry.step, hunter.gd vertical) | MATCH |
| 41 | Updraft | a glider in it: 10 m/s^2 up; once rising at 5 m/s or more it fades to 0 over 7.5 m above the floor target; cap 15.5 m/s; glide gravity 0.025 g | 9 m/s target at 45 m/s^2 (hunter.gd:1672) | the reference law (HunterMove.updraft_vy) | MATCH (the floor target over the abyss is INFERRED) |
| 42 | Dry-ground ledge climb | none (mantles only over the abyss) | our rise (lrise) | kept (terrace rule) | OFF (rule) |
| 43 | Edge pop (mini mantle, lip < 3 m) | speed zeroed, launch at once at the row-40 speed + 5 m/s; for 0.75 s a forward push toward max(0.6 x the speed you came in with, 3.5 x 1.16) easing to half, gained at 8 x the shortfall per s along a heading that turns from your entry to your keys; over the top while rising faster than 2 m/s, pulled down at 5 x the excess (x 1 - 0.35 by the end) | float up the face, then +2.6 m/s pop (tuning.json:148); a jump in the window: +0.9 m peak, 7.5 m/s (tuning.json:151-152, hunter.gd:2282) | over the abyss: the reference law exactly. Dry ground: a jump in the rise is the same launch (the forward goal capped at 1.2 x run, owner 11-11); the untimed top-out is ours | MATCH (abyss) / ours on dry ground |
| 44 | Mantle cooldown | 1.0 s from the launch (so 1.1 s from the touch on a full mantle); your own dash cuts it to 0.1 s | ledge_cd 0.45 (tuning.json:132), mantle_cd set but never read | 1.0 s from the launch gates abyss mantles; a dash cuts it to 0.1 s; dry-ground climbs keep ledge_cd 0.45 | MATCH (abyss) |
| 45 | Wall catch / suction | the capsule's hit on the side; suction: falling (not gliding) over the abyss with the cooldown idle, a head-on side (within 40 degrees) up to 2.5 m x (0.425 to 1 by speed 2-3.5 m/s) ahead pulls you in at 2.5-20 m/s^2 by a curve over 0.5-3 m (1/.75/.46/.25/.11/0); 0-1.5 m under its top, within 1.5 m and rising at 2.5 m/s or less, also up at 25-175 m/s^2 x a curve over 0.5-1.5 m (1/.99/.96/.77/.32/0); the near-kill fudge: within 3 m of the point of no return, a line 4 m one way | 0.75 m sideways reach (tuning.json:129), no pull | kept the reach; the fudge (3 m, 4 m, north only); the suction (MantleCarry.suction) on the reference law | MATCH (the lift's "under its top" uses the nearest lip; the fudge's world direction: see unknowns) |
| 46 | Float-up | none | `_grapple` (hunter.gd:2304), never armed (nothing sets `grap`) | deleted | MATCH (gone) |
| - | Glider after a mantle | shut for the mantle and 0.3 s after | could reopen at once | shut 0.7 s after the launch | MATCH |

### Momentum in and out

- **In:** every mantle zeroes your speed (the touch). A full mantle rises at 0.25 x your sideways speed for 0.1 s,
  then leaves with none: you steer onto the top. A mini mantle remembers your entry speed and direction (the
  decaying peak, `carry_v`) for its forward push.
- **Out:** the push runs 0.75 s or until you land; then the air rules (air steering is ours by owner ruling,
  row 16: ~4x the reference) and the usual landing (no speed lost on landing in either).
- **Landing on the lip:** both keep the sideways speed you land with.

### Measured (`--abyss-edge-check`, 60 Hz, keys into the island; ours vs the reference law simulated)

| Case | Launch up m/s ours / ref | Apex over the catch m | Land past the lip m | Air s | Before (main) |
|---|---|---|---|---|---|
| abyss 1.6 m | 15.52 / 15.52 | 3.90 / 3.90 | 4.73 / 4.24 | 1.17 / 1.15 | float up + pop 7.8 m/s, apex 0.4 m over the lip, 2.06 m in |
| abyss 8.2 m | 16.73 / 16.73 | 9.61 / 9.59 | 3.91 / 2.45 | 1.70 / 1.68 | lost to the abyss (side caught only to 4.5 m) |
| abyss 16.2 m | 24.26 / 24.26 | 20.11 / 20.09 | 6.90 / 5.53 | 2.50 / 2.48 | lost to the abyss |
| edge pop 2 / 5 / 9 m/s | 14.50 / 14.50 | 2.84 / 2.84 | 4.86-4.93 / 4.28-4.50 | 1.10 / 1.08 | pop 0.41 m over the lip, 2.4-2.5 m in, 0.73 s |
| fall, lip to no return | | | | 1.97 / 1.97 | 2.00 |
| glider lift from 3 / 8 / 14 m | | | | 0.67, 0.90, 1.17 / same | 0.63 from 3 m, then a 1.6 m bounce over the lip |

Launch speed, apex and air time are within 2% everywhere. Landing distance is ours 0.4-1.5 m longer in every
case (8-60%): the reference model here now has the island's side blocking you until your feet clear the lip, as
ours does (before 11-27 b it had no wall and read 6.15 / 10.37 m), so what is left is our air steering, ~4x the
reference's by owner ruling (row 16), steering you farther onto the top. Speed at landing is 5.28 m/s (run
speed) in both (kept on landing in both; the 16 m run then meets the test island's far edge, so its 0.25 s-later
speed is not a measurement).

Suction (`--abyss-edge-check`): pulled in at 18.15 / 7.93 / 4.99 m/s^2 from 0.75 / 1.75 / 2.4 m at 4.5 m/s (ref the
same to 0.01); 1 m under the top and 1 m out, up at 96.4 m/s^2 (ref 96.4); none at 55 degrees off, gliding or on
cooldown; a 1.5 m/s drift from 2.2 m out is caught after 1.20 s (main: 0.75 m reach only).

### Unknowns

- The height the reference's glider floor pull and the suction's lift aim at over abyss cells (its height map there is not
  decoded): ours uses the nearest lip (+ 0.6 m for the glider). If the reference's abyss cells sit deep, its glider would sink there instead.
- The tint/sound curve shapes between their ends (the curve assets' keys are not in the files).
- Which world way the near-kill fudge looks: the reference's name says south-side falls, its line goes +Y;
  ours looks north (screen up). INFERRED.
- The reference's floor offset is on the capsule centre (1.5 m); ours is the feet (0.6 m, from its 0.88 m half height).
