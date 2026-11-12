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
  3 cm a step, at the walk (2.2 m/s), the full stick (5 m/s) and a run bending round at 1.5 rad/s.
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

"Before" is the same tool on origin/main's legs (slide there is a contact that is really a skating foot). *The
female walk count is doubled by a toe brush at toe-off (the toe comes back under 1.2 cm one frame after lifting);
her real cadence is 2.9 steps/s like the male. Strips: docs/art/home_gait/ (before, after; eight shots half a
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

## Garden moves on planted feet (ext/anim-empty-garden)
The Empty pats, feeds and cheers with its feet where they stand (HunterVerbs, `scripts/match/hunter_verbs.gd`):
- **Squat**: each move asks for a hip depth (`HunterVerbs.squat`), handed to EmptyGait as `squat`, which lowers the
  standing hip height the planted legs are solved for; the body sinks over its feet and rises again, no slide. The
  deepest is 0.17 m at the rig's size: deeper, the folded leg cannot keep a splayed foot under it (the solve's
  leg-out angle runs out), so a Boki lower than that gets more lean instead (`LEAN_OVER`).
- **Reach**: petting and feeding pass the Boki node to `HomeVerbs.play`; its mesh bounds give the hand's spot
  (`HunterVerbs.aim`): the top of its head on the near side, or its mouth (45 % up its front). The squat is what
  takes the hand down to it from the shoulder (70 % of the arm's reach first); a head above reach is patted on the
  front. The Boki comes up to arm's length first (`HomeVerbs.hold_spot`: its near side 0.3 m off).
- **Timing** (lengths kept with the Hunters' pet/give/cheer clips): pat 1.3 s: the hand lifts, arcs over and lands
  (overshoot and settle), two strokes with a press and a give in the knees, lifts off, the body rises a beat later;
  the free hand braces over the knee. Feed 1.0 s: a small rise, hands gather the snack at the belly, go out past
  the mouth and settle, one nudge in, open and come back. Cheer 0.8 s: a dip to load with the arms swung back,
  sprung up past straight, two alternating pumps with a give in the knees, down.
- **Pick-up** (ext/anim-empty-care): holding interact on a Boki (`HomeCarry.press_hold`) plays `lift`, 0.8 s on the
  match pickup's beat (hands down by 0.28 s, up by 0.55, settled by 0.8). The Boki comes to your hands; both hands
  close on its flanks (`HunterVerbs.aim`: 40 % up it, each hand 0.13 m to a side, on the round of its body) with the
  squat and a fold over it, hold a beat, then it rides them up (`HunterVerbs.lifted`) and the lift ends on the carry
  hold. A Boki for the back is then swung over the shoulder (0.25 s). You stand still for the lift. HunterAnim eases
  one hold into the next over 0.2 s (`SWAP_S`), so lift to carry or pack has no pop.
- **Check**: `--home-verbs-check` plays pat and feed at a 0.5 m and a 1.25 m Boki stand-in: the hand on its surface
  (worst 6.9 cm), hips 13 cm lower feeding the small one, the pat hand 50 cm higher on the big one, sole points on
  the floor slide 0.07 cm (cheer too). The lift at both: each hand 1.9 cm from its grip, 0.9-1.3 cm off the Boki,
  feet 0.13 cm; the pick-up path keeps the Boki on the ground until the grip and hands over to the carry hold.
  `--clip-check` repeats the reach (shared `reach()`): the Empty's hand within 0.15 m of its target at the peak of
  pet, feed and lift, small and big. The strip: `--home-verbs-check --home-verbs-shots=<dir>` (glomwort, zapple;
  columns pat, feed, lift, cheer, toss), shot from the Boki's side (camera yaw -90°) so the fold over it faces the
  camera, not the cloak's back or Hob. [`home_gait/verbs_sw.jpg`](home_gait/verbs_sw.jpg) is the software-GL take
  (llvmpipe under Xvfb; the GPU take is jobq 20261112-011142-01599, queued behind the GPU backlog).

## Left open
- Crouch-walking adds HunterAnim's knee bend after the solve, so a crouched walk slides a little (DEBT).
- The toe dips up to 2 cm into the floor just after toe-off on the sturdy body (gated at 3 cm).
- Arm swing is HunterAnim's, following the gait's phase (left leg's cycle); not re-tuned here.

## Fishing (Glint Fishing)
The Empty fishes with a rod (`scripts/match/hunter_rod.gd`): HunterAnim's "act" slot plays `wait` (rod held out, a loop), `cast` (wind back, flick, 0.6 s), `bite` (the tip jerks, 0.4 s), `reel` (the rear hand cranks, a loop) and `land` (the lift on a catch, 0.9 s). `HomeVerbs.hold` keeps `wait`/`reel`, `play` lays the one-shots over it; `GlintFishing` calls them on its state changes and puts the rod away when the session ends. These poses skip HunterAnim's act-legs override, so the legs stay on EmptyGait's planted feet and only the lean moves. The line leaves the rod's `Tip` node. `--home-gait-check` runs the sequence on the four bodies (feet creep, rod up and in the hands, hidden afterwards); `--glint-fishing-check --glint-fishing-shots=<dir>` is the GPU strip (docs/shots/glint-fishing-anim/).
