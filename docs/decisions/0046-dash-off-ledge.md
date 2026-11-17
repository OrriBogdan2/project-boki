# 0046: A ground dash off a ledge falls as it goes

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement

## Problem
A ground dash that crossed a terrace edge held its height to the end ("an air dash holds your height"), so the
Hunter slid on in the ground-dash pose over empty air, then dropped. Several kits then put a ground ending on it in
the air: Grimble's barge planted him (3 m/s), Neve, Sparkle and Tenzo played their stop/landing/crash poses mid-air,
and the dashes' ground wind-downs kept the glider shut for up to 0.45 s.

## Options
1. End the dash at the lip and carry its speed as momentum: simple, but a burst dash carries its peak speed (Sparkle
   34.8 m/s, Kael 19.6 m/s) for the whole fall, 11-20 m out from a 3.2 m terrace.
2. Keep the dash's own course (distance, speed curve) and let gravity act from the lip; it ends in the air with the
   shared dash exit, then normal air control. Matches the source (a dash is how you leave a platform,
   bCanWalkOffLedges false; a falling body sheds only FallingLateralFriction) without stretching any dash.

## Decision
Option 2. `Hunter.roll_falls` is set the step a running Shift dash loses its ground and turns off the height hold;
`HunterMove.dash_off_ledge` clears it as the dash ends and, if that is in the air, calls
`ArchKit.on_dash_off_ledge` (cut the dash's own pose, drop the ground wind-down `glide_cd`).

## Consequences
hunter.gd +5 lines of wiring; hunter_move.gd, arch_kit.gd; kit fixes in dredge (plant only on the ground),
bulwark (spin wind-down only on the ground), mage (land pose only on the ground), rimewright (stop pose only on the
ground), breah_hop (the skid's next hop and crash wait for the ground). Net.VERSION: no (owner-side physics).
Check: `--move-feel-check` ledge_dash rows (tools/move_feel_ledge.gd), 15 runs over the 12 kits; origin/main fails
13 of them. Air dashes pressed in the air keep their height hold.
