# 0022: The sky train's cars carry their speed off the deck (moving-platform parity)

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement

## Problem
Leaving a moving car kept you glued to it: anyone in the air within 1.2 s of standing on it was still
moved with the car (so a jump or a dash could be carried off the deck, then re-caught with the car's speed
added twice: a slingshot), and a glide landing on a car kept its world speed on top of the deck's (a lurch).
In the source, leaving a moving platform imparts its velocity, which then follows normal air control and drag.

## Options
1. Keep the air carry and patch the double hand-off.
2. A plain moving platform: only grounded riders are carried; the step you leave, the car's speed (horizontal,
   as the source: no platform Z) is added to your velocity; the step you land, it is taken off. A dash sets
   its own speed every step, so one that runs past the car's end is moved along with the car until it hands over.

## Decision
Option 2, all in `SkyTrain.tick` (the occupancy code); `hunter.gd` is untouched. The car's speed you leave with
stays apart from your own (`SkyTrain.off_car`) for `AIR_CARRY` (1.2 s, a jump's hang): you move with it on top of
your air motion, following the deck under you while you're over a car, so `Loco.air_step`'s overspeed drag and the
air steering work on your speed over the car alone and a jump comes down on it. Then (or on touching other ground,
or as a dash in the air ends: a dash ends in world terms) it joins your own speed once and the drag takes it from
there. Landing on a car takes its speed off yours. A rider who just left a car is no longer hit by a car's frame
(only the engine's front): a deck climbing out of a dip under a jumper scoops them up instead of killing them.
`--train-ride-check` logs a second of world velocity for a jump, a dash off the back, a walk off the side falling
and gliding, and a glide landing, and asserts no jolt, no dead stop and no slingshot.

Alternatives for the drag (main's `Loco.air_step` bleeds speed above the run cap, so a hand-over in `vel` drifted a
jump 5 m behind a 16 m/s car): exempt the carried speed inside `Loco`/`Hunter` (touches the frozen hunter.gd, and
every air mode: air, glide, feather), or accept the drift (breaks "a jump lands back on the car").

## Consequences
A jump on a moving car lands on it at any train speed; a long glide off the side bleeds the car's speed after 1.2 s.
`--train-check` asserts walking off the side (DECISIONS: never blocked) on the default map. `--train-ride-check`
runs on Skyreach (its clear-stretch search is tuned there; the 2x map is in docs/DEBT.md).
