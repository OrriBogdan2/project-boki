# 0040: A Boki's bite and cast wait for the release frame of their clip

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** combat (Boki), animation

## Problem
A Boki's skill and bite fired the instant it decided, while the rig played its 0.8 s attack or 1.1-1.7 s ability
from the start: the hit landed on the wind-up, and a burst out of the wisp showed a Boki casting from an idle pose.

## Options
1. Key new short clips per species in Blender (not on this box), and delay by a per-species number.
2. Fire at once and cut the clip to its release (no wind-up shown).
3. Retime each species' own keyed attack and ability at load into `lunge` (0.42 s) and `cast` (0.56 s) so the peak
   of the motion lands at a fixed time, and hold the bite or skill for that time.

## Decision
Option 3 (`BokiSwing`). `LUNGE_WIND` 0.12 s, `CAST_WIND` 0.2 s: `Kin._cast` pays the cooldown and bond cost at once,
plays the cast clip and releases the skill after the wind-up; the bite does the same for `lunge`. Only a rigged
species casting for itself waits (a Boki lending its skill to its hunter, or a primitive body, fires at once).
A Boki that cannot fight when the wind-up ends loses that swing. A Blender pass can key `lunge` and `cast` per
species later under the same names and times; the retime then stops applying.

## Consequences
- A summoned Boki's first hit and skill come 0.12-0.2 s after it decides. Wild Boki lunges are untouched.
- `--boki-rig-check` (clip length, release time) and `--boki-system-check` (held, then released) cover it.
