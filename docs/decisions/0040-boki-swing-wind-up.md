# 0040: A Boki's cast waits for the release frame of its clip

- **Status:** accepted
- **Date:** 2026-11-17 (ported from the 11-09 branch; the bite half is main's `BokiRig.CONTACT`)
- **Area:** combat (Boki), animation

## Problem
A Boki's skill fired the instant it decided, while the rig played its 1.1-1.7 s ability from the start: the skill
landed on the wind-up, and a burst out of the wisp showed a Boki casting from an idle pose.

## Options
1. Key a short cast clip per species in Blender, and delay by a per-species number.
2. Fire at once and cut the clip to its release (no wind-up shown).
3. Retime each species' own keyed ability at load into `cast` (0.56 s) so the peak of the motion lands at a fixed
   time, and hold the skill for that time.

## Decision
Option 3 (`BokiSwing`). `CAST_WIND` 0.2 s: `Kin._cast` pays the cooldown and bond cost at once, plays the cast clip
and `_release` fires the skill after the wind-up. Only a rigged Boki casting for itself while out waits (a Boki
lending its skill to its hunter, or a primitive body, fires at once). A Boki that cannot fight when the wind-up ends
loses that cast. A Blender pass can key `cast` per species later under the same name and time.

## Consequences
- A summoned Boki's skill comes 0.2 s after it decides. Wild Boki attacks are untouched.
- `--boki-rig-check` (clip length, release time) and `--boki-system-check` (held, then released) cover it.
