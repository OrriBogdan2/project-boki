# 0022: Vision model (who sees whom)

- **Status:** proposed
- **Date:** 2026-11-09
- **Area:** combat / match flow

## Problem
Lace's passive reveals injured foes "in the fog", so hiding must exist. The source publishes no vision radius,
occlusion, hit-reveal or minimap rules. We need one written rule that kits, bots and the HUD all follow.

## Options
1. Keep the current model (`Match.sees`: shared team cone, near circle, line of sight, grass hides, `reveal_t`). Zero cost; numbers are ours.
2. Rework to a source-style radius plus ADS cone. Needs numbers we do not have; touches match.gd (frozen) and the shader.
3. Keep it and add a small reveal-on-hit or off-screen sound cue (docs/specs/VISION.md options B and C).

## Decision
Proposed: option 1 now, option 3 only after a 30-Hunter profile. The rules in docs/specs/VISION.md section 2 become
the reference; any kit that reveals must write `reveal_t` and nothing else.

## Consequences
No code and no Net.VERSION bump. Debt: our range, cone and grass rules stay unverified against the source.
If option 3 is chosen, a new check is needed for the attacker reveal. Owner decides; renumber if 0022 is taken.

## Addendum 2026-11-12: the owner's wedge
The owner sent a reference with a wide lit wedge, so the numbers change, the model does not: the cone is 170 degrees
(`VIEW_COS` 0.6 -> 0.087), the always-lit circle 2.0 m (was 3.2; half for a crouched target, was 1.6), range stays 24 m
(the reference's circle measures about the same in the world). The shader draws the same wedge (`VIS_COS`,
`VIS_NEAR`, asserted by `--vision-check`), and a seen rival who is hiding (crouched, grass, smoke) shows no plate.
Bots use the same rule, so they also see wider. No Net or save change. Measurements: docs/specs/VISION_LOOK.md.
