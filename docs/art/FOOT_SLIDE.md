# Foot slide across the whole locomotion blend

`--foot-slide-check` (tools/foot_slide_check.gd) poses each Hunter's real model through `WardenClips` at every speed
from 0 to its run speed (content/rules/hunter_move.json) in 0.5 m/s steps, plus the run speed itself, moving forward,
back, left and right, and measures planted-foot slip: the mean flat speed (m/s) of a foot against the ground while it
is in the lowest 30 % of its height range (the `--anim-audit` plant rule). Each speed is held 2.4 s to settle, then
sampled for 6 s. The sweep is deterministic: Sync only advances on the check's fixed 1/30 s steps. Neve (`rimewright`)
and Motley (`ostra`) skate and hover, so their legs don't step, and Gil has no clips yet; none of the three is swept.

`--anim-audit` reads only three forward speeds. The sweep shows that every Hunter slides most between the walk ring
(0.45 of `loco.run_speed`) and the run ring, at 2.5 to 4 m/s, in all four directions, where the earlier audit saw only
Albert.

## Why the mid-blend slides

The loco BlendSpace2D plays each walk and run loop as its own instance. They are keyed at different lengths (Albert's
walk 0.5 s, run 0.367 s; Tenzo's 0.967 s and 0.533 s), and a loop at zero weight stops, so where the two blend their
planted feet are at different points of the step and cancel. The blended foot then barely moves while the body does:
it slides about 75 % of the speed. Moving the blend thresholds does not help: a narrower window slides just as much
inside it (Albert with the walk ring at 0.6, 0.75 and 0.9 of the run ring: 3.1, 3.1 and 3.5 m/s). Neither does
putting the run loops at both rings, because the two instances still drift apart.

The fix is playback-rate scaling per loop. `loco.cycle_s` stretches every walk and run loop to one cycle length
(`AnimationNodeAnimation` custom timeline) and keeps the space advancing them all, so walk and run touch down
together. `foot_mps` is then measured at that cycle. Albert's cycle is his walk's own 0.5 s, so his walk plays as
keyed and his run cadence stays 3.5 steps/s. Tenzo's is 0.55 s.

Tenzo's strafe loops step only about 1.4 m/s sideways at rate 1, against a 4.65 m/s run. `loco.side_foot_mps`
[1.0, 2.0] lets the rate rise for a strafe (WardenGait mixes it in by how far the move points sideways), but the rate
caps at 1.4 (`WardenGait.RATE_MAX`), so the strafe run still slides 2.65 m/s. That needs strafe loops with a longer
side step (docs/DEBT.md).

Both fixes keep the game's run speeds. `loco.run_speed` (the run ring) moved onto them: Albert 4.8 to 4.85,
Tenzo 5.0 to 4.65.

## Worst slip per Hunter, and the gate

The gate is `--foot-slide-check`: FAIL when a Hunter's worst slip anywhere in the sweep passes its bar (`BAR`, this
table's after column rounded up to 0.05), or when a Hunter with stepping legs has no bar.

| Hunter | Worst before | Worst after | Bar |
|---|---|---|---|
| Tenzo (`dolm`) | 3.27 (left 4.65 m/s) | 2.65 (left 4.65 m/s) | 2.70 |
| Albert (`bulwark`) | 2.86 (right 3.50 m/s) | 1.27 (right 3.50 m/s) | 1.30 |
| Cinder (`ashwick`) | 2.40 (fwd 3.50 m/s) | 2.40 (fwd 3.50 m/s) | 2.40 |
| Sparkle (`mage`) | 2.08 (back 3.50 m/s) | 2.08 (back 3.50 m/s) | 2.10 |
| Kael (`juggernaut`) | 1.95 (back 3.00 m/s) | 1.95 (back 3.00 m/s) | 2.00 |
| Meeko (`tender`) | 1.88 (left 3.50 m/s) | 1.88 (left 3.50 m/s) | 1.90 |
| Sable (`thief`) | 1.85 (fwd 3.00 m/s) | 1.85 (fwd 3.00 m/s) | 1.85 |
| Lace (`archer`) | 1.73 (back 3.50 m/s) | 1.73 (back 3.50 m/s) | 1.75 |
| Grimble (`dredge`) | 1.72 (back 3.50 m/s) | 1.72 (back 3.50 m/s) | 1.75 |
| Vex (`gunslinger`) | 1.69 (back 3.00 m/s) | 1.69 (back 3.00 m/s) | 1.70 |

`cycle_s` would likely help the others too: Cinder at `cycle_s` 0.7 measured 2.40 to 1.16 m/s in one trial. This
branch doesn't change them.

## The sweep, m/s of planted-foot slip

Speed columns are m/s; "run" is the Hunter's game run speed. **before → after** marks a changed cell (Albert and Tenzo).
`--anim-audit` after the change: Albert forward run 0.51 to 0.94 m/s (11 to 20 %, under its 25 % gate; this sweep at
his run speed reads 0.85 to 0.90), jog at 3.4 m/s 2.71 to 0.43; Tenzo run 0.84 to 0.90 m/s (18 to 19 %), jog 2.14 to 0.65. Cadence at a run: Albert 3.5 steps/s (unchanged),
Tenzo 3.75 to 3.4.

| Hunter | dir | 0.0 | 0.5 | 1.0 | 1.5 | 2.0 | 2.5 | 3.0 | 3.5 | 4.0 | 4.5 | run |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Lace (`archer`, run 4.55) | fwd | 0.01 | 0.35 | 0.57 | 0.44 | 0.55 | 1.23 | 1.57 | 1.44 | 0.82 | 0.65 | 0.67 |
|  | back | 0.01 | 0.39 | 0.58 | 0.51 | 0.64 | 1.25 | 1.63 | 1.73 | 1.24 | 1.18 | 1.19 |
|  | left | 0.01 | 0.35 | 0.55 | 0.51 | 0.61 | 1.35 | 1.69 | 1.58 | 1.00 | 0.88 | 0.88 |
|  | right | 0.01 | 0.33 | 0.53 | 0.51 | 0.61 | 1.31 | 1.66 | 1.56 | 0.98 | 0.88 | 0.89 |
| Kael (`juggernaut`, run 4.55) | fwd | 0.00 | 0.29 | 0.58 | 0.42 | 0.50 | 0.90 | 1.10 | 0.85 | 0.72 | 0.60 | 0.60 |
|  | back | 0.00 | 0.48 | 0.62 | 0.45 | 0.76 | 1.30 | 1.95 | 1.85 | 1.36 | 0.93 | 0.92 |
|  | left | 0.00 | 0.30 | 0.58 | 0.56 | 0.59 | 1.17 | 1.34 | 1.14 | 1.03 | 0.92 | 0.88 |
|  | right | 0.00 | 0.31 | 0.56 | 0.56 | 0.58 | 1.13 | 1.12 | 1.04 | 1.05 | 0.87 | 0.86 |
| Vex (`gunslinger`, run 4.55) | fwd | 0.03 | 0.25 | 0.48 | 0.33 | 0.38 | 0.95 | 1.52 | 1.04 | 0.75 | 0.66 | 0.67 |
|  | back | 0.03 | 0.41 | 0.43 | 0.35 | 0.79 | 1.23 | 1.69 | 1.67 | 0.97 | 0.81 | 0.80 |
|  | left | 0.03 | 0.24 | 0.46 | 0.35 | 0.55 | 1.05 | 1.38 | 1.23 | 0.93 | 0.63 | 0.63 |
|  | right | 0.03 | 0.24 | 0.44 | 0.34 | 0.54 | 1.08 | 1.43 | 1.48 | 0.83 | 0.63 | 0.66 |
| Albert (`bulwark`, run 4.85) | fwd | 0.06 | 0.24 → **0.26** | 0.28 → **0.29** | 0.31 → **0.34** | 0.36 → **0.37** | 0.92 → **0.42** | 2.25 → **0.52** | 2.67 → **0.61** | 2.16 → **0.70** | 0.84 → **0.81** | 0.85 → **0.90** |
|  | back | 0.06 | 0.23 | 0.31 → **0.30** | 0.34 → **0.33** | 0.37 → **0.38** | 0.97 → **0.42** | 2.32 → **0.57** | 2.64 → **0.67** | 2.08 → **0.72** | 0.85 | 0.89 → **0.93** |
|  | left | 0.07 → **0.06** | 0.13 | 0.19 → **0.20** | 0.29 | 0.34 → **0.35** | 0.94 → **0.40** | 2.22 → **0.47** | 2.81 → **0.52** | 2.35 → **0.65** | 0.79 → **0.67** | 0.69 → **0.73** |
|  | right | 0.06 | 0.14 | 0.19 → **0.20** | 0.30 → **0.31** | 0.36 | 1.06 → **0.75** | 2.38 → **1.18** | 2.86 → **1.27** | 2.48 → **1.24** | 0.80 → **0.61** | 0.70 → **0.71** |
| Cinder (`ashwick`, run 4.65) | fwd | 0.00 | 0.31 | 0.35 | 0.28 | 0.25 | 0.43 | 1.87 | 2.40 | 0.50 | 0.56 | 0.58 |
|  | back | 0.01 | 0.18 | 0.26 | 0.28 | 0.29 | 1.13 | 0.70 | 1.97 | 1.17 | 0.56 | 0.57 |
|  | left | 0.00 | 0.34 | 0.52 | 0.61 | 0.25 | 1.31 | 1.93 | 0.73 | 2.13 | 1.10 | 1.12 |
|  | right | 0.01 | 0.35 | 0.57 | 0.54 | 0.25 | 1.36 | 1.71 | 0.78 | 2.16 | 1.12 | 1.19 |
| Meeko (`tender`, run 4.55) | fwd | 0.01 | 0.37 | 0.48 | 0.49 | 0.67 | 1.33 | 1.79 | 1.67 | 1.05 | 0.71 | 0.72 |
|  | back | 0.01 | 0.44 | 0.43 | 0.36 | 0.51 | 1.34 | 1.80 | 1.77 | 0.86 | 0.48 | 0.49 |
|  | left | 0.01 | 0.42 | 0.54 | 0.62 | 0.82 | 1.49 | 1.74 | 1.88 | 1.41 | 1.10 | 1.10 |
|  | right | 0.01 | 0.39 | 0.52 | 0.59 | 0.81 | 1.42 | 1.75 | 1.79 | 1.39 | 1.12 | 1.09 |
| Tenzo (`dolm`, run 4.65) | fwd | 0.01 | 0.39 → **0.27** | 0.67 → **0.40** | 0.49 → **0.40** | 0.49 → **0.51** | 0.92 → **0.45** | 2.30 → **0.50** | 2.34 → **0.70** | 1.96 → **0.85** | 1.02 → **0.89** | 1.00 → **0.89** |
|  | back | 0.00 | 0.32 → **0.19** | 0.59 → **0.33** | 0.50 → **0.44** | 0.53 → **0.54** | 0.98 → **0.84** | 2.38 → **0.95** | 2.79 → **0.99** | 2.66 → **1.04** | 1.26 → **1.12** | 1.04 → **1.12** |
|  | left | 0.00 | 0.42 → **0.35** | 0.79 → **0.50** | 0.97 → **0.63** | 1.01 → **0.76** | 1.50 → **0.75** | 2.28 → **0.73** | 2.57 → **0.76** | 2.90 → **0.87** | 3.14 → **2.43** | 3.27 → **2.65** |
|  | right | 0.00 | 0.42 → **0.34** | 0.78 → **0.51** | 0.99 → **0.69** | 1.02 → **0.78** | 1.51 → **0.75** | 2.25 → **0.74** | 2.64 → **0.73** | 2.89 → **0.89** | 3.12 → **2.43** | 3.18 → **2.61** |
| Grimble (`dredge`, run 4.65) | fwd | 0.01 | 0.29 | 0.51 | 0.30 | 0.42 | 0.87 | 1.22 | 0.99 | 0.58 | 0.57 | 0.55 |
|  | back | 0.01 | 0.45 | 0.57 | 0.44 | 0.69 | 1.14 | 1.63 | 1.72 | 1.08 | 0.84 | 0.87 |
|  | left | 0.01 | 0.24 | 0.44 | 0.33 | 0.57 | 1.04 | 1.36 | 1.32 | 0.86 | 0.69 | 0.70 |
|  | right | 0.01 | 0.25 | 0.43 | 0.34 | 0.56 | 1.06 | 1.26 | 1.14 | 0.89 | 0.73 | 0.74 |
| Sparkle (`mage`, run 4.65) | fwd | 0.01 | 0.33 | 0.59 | 0.52 | 0.55 | 0.96 | 1.61 | 1.71 | 0.93 | 0.65 | 0.61 |
|  | back | 0.01 | 0.37 | 0.57 | 0.48 | 0.67 | 1.12 | 2.07 | 2.08 | 1.42 | 1.32 | 1.43 |
|  | left | 0.01 | 0.30 | 0.57 | 0.50 | 0.58 | 1.12 | 1.92 | 1.87 | 1.20 | 0.92 | 0.98 |
|  | right | 0.01 | 0.31 | 0.55 | 0.50 | 0.59 | 1.15 | 1.96 | 1.92 | 1.22 | 0.94 | 0.99 |
| Sable (`thief`, run 4.65) | fwd | 0.01 | 0.40 | 0.58 | 0.45 | 0.59 | 1.47 | 1.85 | 1.81 | 1.09 | 0.94 | 0.93 |
|  | back | 0.01 | 0.52 | 0.84 | 0.71 | 0.89 | 1.55 | 1.82 | 1.75 | 1.54 | 1.35 | 1.39 |
|  | left | 0.01 | 0.48 | 0.67 | 0.71 | 0.92 | 1.49 | 1.83 | 1.79 | 1.58 | 1.44 | 1.48 |
|  | right | 0.01 | 0.42 | 0.63 | 0.68 | 0.92 | 1.55 | 1.71 | 1.76 | 1.59 | 1.48 | 1.50 |
