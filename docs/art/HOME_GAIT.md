# The Empty's gait: planted feet at home (Nov 11)

The player at home is the Empty: the Models.hunter rig that HunterAnim poses by hand (no clips), at the creator's
sex, height and build. Its walk, run, turn, stop and idle were audited against the Hunters' bar (foot slide, cadence
against speed, arm swing, stop settle) and the legs rebuilt as `EmptyGait` (scripts/match/empty_gait.gd, decision
0022): every foot is planted where it lands and the leg is solved onto that spot each frame.

## How it is measured

`godot --headless -- --home-gait-check [--json=file]` (tools/home_gait_check.gd, 100 s): seven bodies (male
short/slight, average, tall/sturdy; female short/slight, average, tall/average, tall/sturdy), the tool moving the model as the farm does.

- **slide**: every sole point (heel, mid, toe of each boot) on the floor (within 1.2 cm) for 3 frames or more is a
  contact; its slide is how far it moved from its second frame down to its last but one. The gate is the task's:
  3 cm a step, at the walk (2.2 m/s), the full stick (5 m/s) and a run bending round at 1.5 rad/s.
- **steps/s**: a foot coming down after 3 frames or more off the floor.
- **sink**: no sole point more than 3 cm under the floor (the boot has no ankle: the toe dips a little behind).
- **stop**: full stick then let go; every sole point under 2 cm/s within 0.8 s.
- **turn**: 6 rad/s on the spot, no sole point, hip or head jumps more than 8 cm a frame; **idle creep** under 2 cm.

## Before (origin/main sine gait) and after

| body | walk slide | run slide | turning run | steps/s walk / run | bob | stop | turn pop | idle creep |
|---|---|---|---|---|---|---|---|---|
| before, average | 39-54 cm | 65-82 cm | 64-87 cm | 2.5 / 3.8 | 1-3 cm | 0.6 s | 4 cm | 6 cm (free foot) |
| male short/slight | 0.3 cm | 0.7 cm | 0.7 cm | 3.3 / 4.6 | 5.0 cm | 0.33 s | 2.9 cm | 0.2 cm |
| male average | 0.4 cm | 0.8 cm | 0.8 cm | 2.9 / 4.2 | 5.6 cm | 0.40 s | 3.8 cm | 0.2 cm |
| male tall/sturdy | 0.5 cm | 0.8 cm | 0.7 cm | 2.9 / 3.8 | 6.1 cm | 0.38 s | 5.3 cm | 0.3 cm |
| female short/slight | 0.2 cm | 0.7 cm | 0.7 cm | 3.3 / 4.6 | 5.0 cm | 0.42 s | 3.4 cm | 0.4 cm |
| female average | 0.2 cm | 0.8 cm | 0.8 cm | 2.9 / 4.2 | 5.5 cm | 0.43 s | 4.5 cm | 0.4 cm |
| female tall/average | 0.3 cm | 0.9 cm | 0.9 cm | 2.5 / 3.8 | 6.1 cm | 0.45 s | 5.0 cm | 0.5 cm |
| female tall/sturdy | 0.3 cm | 0.8 cm | 0.7 cm | 2.9 / 3.8 | 6.1 cm | 0.45 s | 6.9 cm | 0.5 cm |

"Before" is the same tool on origin/main's legs (slide there is a contact that is really a skating foot). Strips: docs/art/home_gait/ (before, after; eight shots half a
second apart at 5 m/s past floor posts every half metre).

## What the gait does

- **Planted**: the heel's ground point is stored in world space when the foot lands; each frame the hip, knee and
  leg-out angles are solved (closed form: thigh and boot are one planar chain about the thigh's axis) so the sole
  point on the ground stays on it while the hips pass over. The boot rolls heel, mid, toe as the hips move on and
  the leg cannot reach with the earlier point.
- **Hips**: at the rig's size 0.43 m at the strike, 0.445 m flat-footed (by 30 % of the stance), 0.485 m from the
  push-off (70 %) on: the body rises onto the toe because there is no ankle, and comes down again in the air.
- **Swing**: the lowest sole point (the toe as it leaves, the heel as it lands) travels in the body's frame from
  where it left to where it lands, kicking up fast behind (so the leg can reach it as the body moves on), and brakes
  to a standstill against the ground over the last 0.03 s, overshooting the spot by half the body's travel in that
  time. The next foot comes down one step after the other, half-way between the cycle's own swing and that beat.
- **Cadence**: step length = hip height / 0.44 x (0.36 + 0.18 x speed) m, so a short body steps quicker.
- **Standing**: the same anchors; the hips sit at the flat-footed height, feet stay put as the body turns or shifts
  weight; a leg that cannot reach re-steps (0.25 s) to a spot under the hip. Stopping therefore settles in the time
  the swinging foot takes to land. WardenStance's idle leg offsets (free leg, spread) fade with the gait.
- **Data**: content/rules/warden_stance.json `empty_f` / `empty_m` gait keys `step`, `stance`, `strike`, `hip`,
  `swing` (metres at the rig's rest size; the body's scale is read from the legs' transform).

## Left open
- Crouch-walking adds HunterAnim's knee bend after the solve, so a crouched walk slides a little (DEBT).
- The toe dips up to 2 cm into the floor just after toe-off on the sturdy body (gated at 3 cm).
- Arm swing is HunterAnim's, following the gait's phase (left leg's cycle); not re-tuned here.

## Fishing (Glint Fishing)
The Empty fishes with a rod (`scripts/match/hunter_rod.gd`): HunterAnim's "act" slot plays `wait` (rod held out, a loop), `cast` (wind back, flick, 0.6 s), `bite` (the tip jerks, 0.4 s), `reel` (the rear hand cranks, a loop) and `land` (the lift on a catch, 0.9 s). `HomeVerbs.hold` keeps `wait`/`reel`, `play` lays the one-shots over it; `GlintFishing` calls them on its state changes and puts the rod away when the session ends. These poses skip HunterAnim's act-legs override, so the legs stay on EmptyGait's planted feet and only the lean moves. The line leaves the rod's `Tip` node. `--home-gait-check` runs the sequence on the seven bodies (feet creep, rod up and in the hands, hidden afterwards); `--glint-fishing-check --glint-fishing-shots=<dir>` is the GPU strip (docs/shots/glint-fishing-anim/).

## Feet on the floor, both frames

`--home-gait-check` also holds standing feet to HOVER_CM (1.5 cm) over the floor on all seven bodies. The female
legs used to be a leg node scaled 0.9 across and along; a pitched leg inside a scaled node shears, so the solved
sole hung 1.6-2.8 cm up (found by `--unmasked-check`). `Unmasked._slim_leg` narrows the meshes instead and leaves
the joints unscaled. The boot also keeps its facing from where it landed (`EmptyGait._heel_at`) while the body
turns on the move, which took the tall female's turning-run slide from 3.0 to 0.9 cm. The female stance's weight
shift (`tilt` 0.06, `hip` 0.05) now stays inside the legs' reach, so a short body no longer re-steps while idle.
