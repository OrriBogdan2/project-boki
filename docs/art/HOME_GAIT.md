# The Empty's gait: planted feet at home (Nov 11)

The player at home is the Empty: the Models.hunter rig that HunterAnim poses by hand (no clips), at the creator's
sex, height and build. Its walk, run, turn, stop and idle were audited against the Hunters' bar (foot slide, cadence
against speed, arm swing, stop settle) and the legs rebuilt as `EmptyGait` (scripts/match/empty_gait.gd, decision
0022): every foot is planted where it lands and the leg is solved onto that spot each frame.

## How it is measured

`godot --headless -- --home-gait-check [--json=file]` (tools/home_gait_check.gd, 100 s): four bodies (male
short/slight, average, tall/sturdy; female average), the tool moving the model as the farm does.

- **slide**: every sole point (heel, mid, toe of each boot) on the floor (within 1.2 cm) for 3 frames or more is a
  contact; its slide is how far it moved from its second frame down to its last but one. The gate is the task's:
  3 cm a step, at the walk (2.2 m/s), the full stick (5 m/s), a run bending round at 1.5 rad/s and a crouched
  walk at the crouched full stick (2.75 m/s; the hips at least 3 cm lower than at the walk).
- **steps/s**: a foot coming down after 3 frames or more off the floor.
- **sink**: no sole point more than 3 cm under the floor (the boot has no ankle: the toe dips a little behind).
- **stop**: full stick then let go; every sole point under 2 cm/s within 0.8 s.
- **turn**: 6 rad/s on the spot, no sole point, hip or head jumps more than 8 cm a frame; **idle creep** under 2 cm.

## Before (origin/main sine gait) and after

| body | walk slide | run slide | turning run | steps/s walk / run | bob | stop | turn pop | idle creep |
|---|---|---|---|---|---|---|---|---|
| before, average | 39-54 cm | 65-82 cm | 64-87 cm | 2.5 / 3.8 | 1-3 cm | 0.6 s | 4 cm | 6 cm (free foot) |
| male short/slight | 0.3 cm | 0.7 cm | 1.1 cm | 3.3 / 4.6 | 5.0 cm | 0.33 s | 2.9 cm | 0.2 cm |
| male average | 0.4 cm | 0.8 cm | 1.8 cm | 2.9 / 4.2 | 5.5 cm | 0.42 s | 4.0 cm | 0.2 cm |
| male tall/sturdy | 0.5 cm | 0.8 cm | 2.5 cm | 2.9 / 3.8 | 6.1 cm | 0.38 s | 5.3 cm | 0.3 cm |
| female average | 0.1 cm | 0.0 cm | 0.0 cm | 5.8* / 4.2 | 5.5 cm | 0.47 s | 4.6 cm | 0.0 cm |
| female average, Nov 11 crouch fix | 0.2 cm | 0.7 cm | 1.5 cm | 2.9 / 4.2 | 5.3 cm | 0.63 s | 5.0 cm | 0.0 cm |

"Before" is the same tool on origin/main's legs (slide there is a contact that is really a skating foot). *The
female walk count is doubled by a toe brush at toe-off (the toe comes back under 1.2 cm one frame after lifting);
her real cadence is 2.9 steps/s like the male (her soles floated a little: fixed with the crouch, see Crouched
below). Strips: docs/art/home_gait/ (before, after; eight shots half a second apart at 5 m/s past floor posts every
half metre).

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
- **Crouched**: every hip height above comes down by `crouch` x the crouch (0.07 m at the rig's size, as deep as
  HunterAnim's old crouch bend took the hips), so the solve plants the feet with the bend in the legs; HunterAnim no
  longer bends the Empty's knees for the crouch after the solve. With no ankle the crouched boot is toe-down, so a
  crouched foot lands and stays on its toe.
- **Landing frame**: the frame a swing ends on runs past the swing's end; the landing spot moves back at the body's
  pace for that overshoot, so the foot is not carried a frame with the body as it comes down.
- **Data**: content/rules/warden_stance.json `empty_f` / `empty_m` gait keys `step`, `stance`, `strike`, `hip`,
  `swing`, `crouch` (metres at the rig's rest size; the body's scale is read from the legs' transform).

## Crouched (Nov 11, ext/anim-empty-crouch)

The same tool's crouch row (2.75 m/s, crouched). Before, the knee bend came after the solve; the female body's
crouched feet never touched the floor at all: Unmasked slimmed her legs by scaling the leg joints (0.9 across and
front to back), which shortened a bent leg's reach, so her planted toe floated 2-3 cm up. The slimming is now on
the leg's parts, not its joints (the same look standing); that also ends her doubled walk count (5.8 -> 2.9).

| body | crouch slide before | after | hips crouched / walk | steps/s crouched |
|---|---|---|---|---|
| male short/slight | 3.8 cm | 0.8 cm | 0.33 / 0.40 m | 3.8 |
| male average | 5.5 cm | 0.5 cm | 0.37 / 0.44 m | 3.8 |
| male tall/sturdy | 6.9 cm | 0.9 cm | 0.41 / 0.49 m | 2.9 |
| female average | no contact (feet 2-3 cm up) | 0.5 cm | 0.37 / 0.44 m | 3.8 |

The other rows hold (walk 0.2-0.3 cm, run 0.5-0.7 cm, turning run 0.8-2.8 cm; the tall body's turning run went
2.5 -> 2.8 cm with the landing-frame change, the short body's walk counts 3.8 steps/s from a toe brush). Strips:
docs/art/home_gait/crouch_before.jpg, crouch_after.jpg (`--empty-shots --only=gait --crouch`).

## Left open
- The toe dips up to 2 cm into the floor just after toe-off on the sturdy body (gated at 3 cm).
- Arm swing is HunterAnim's, following the gait's phase (left leg's cycle); not re-tuned here.
