# 0022: The Empty's feet are planted

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** farm (the home player body's animation)

## Problem
The Empty (the player at home) has no clips: HunterAnim walks the Models.hunter rig by hand, swinging the hips
with a sine on a phase that advances with distance. At the farm's speeds (2.2 to 5 m/s on a 0.47 m leg) the
planted foot slid 20 to 76 % of the body speed and the swing foot skimmed the floor; tuning the sine (stride,
cadence, a third harmonic) got the slide down to about 20 %, never near the Hunters' bar.

## Options
1. Keep tuning the sine gait's data (stride, cadence, harmonics). Bounded at ~20 % slide: a pure swing cannot
   hold a foot still under a moving hip.
2. Author walk and run clips for the Empty. There is no body export for it (it is Models.hunter built at
   runtime, at three heights and builds), so clips would need re-timing per body and still slide at other speeds.
3. Plant the feet: keep each foot's ground point in world space and solve the leg (hip, knee, leg-out) every
   frame so the boot's lowest sole point stays on it, rolling heel to toe; swing the free foot to where the
   body will be when it lands; data for step length over speed and hip heights.

## Decision
Option 3, as `EmptyGait` (scripts/match/empty_gait.gd), wired into HunterAnim's legs for the `unmasked`
archetype only; the Hunters keep their clips. Closed-form solve for this rig (the knee bends about the thigh's
axis, so thigh and boot are one planar chain). Standing uses the same anchors, so idle feet never creep and a
turn on the spot re-steps when a leg cannot reach.

## Consequences
- New: scripts/match/empty_gait.gd, tools/home_gait_check.gd (`--home-gait-check`), gait keys in
  content/rules/warden_stance.json `empty_f` / `empty_m`; a few lines of wiring in hunter_anim.gd and
  warden_stance.gd (its idle leg offsets fade with the gait).
- No Net or save change: the Empty is local to the farm, nothing synced reads the leg angles.
- The boot has no ankle, so the body rises onto the toe to push off (hip 0.43 -> 0.485 m at the rig's
  size, a 5 to 6 cm bob); the hips come down again in the air. Crouch-walking still adds a knee bend after
  the solve, so a crouched walk slides a little (not gated).
