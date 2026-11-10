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
Option 2, all in `SkyTrain.tick` (the occupancy code); `hunter.gd` is untouched. A rider who just left a car is
no longer hit by a car's frame (only the engine's front): a deck climbing out of a dip under a jumper scoops
them up instead of killing them. `--train-ride-check` logs a second of world velocity for a jump, a dash off
the back, a walk off the side falling and gliding, and a glide landing, and asserts no jolt, no dead stop and
no slingshot. The route's bridge dips and the loop's curve mean a long hang drifts off a car: that is the map, not the carry.

## Consequences
Jumping on a moving car drifts you back by the air drag (about 1 m per 10 m/s). A dash ends in world terms once
you are off the deck. `--train-check` now asserts walking off the side (DECISIONS: never blocked) and loads Skyreach.
