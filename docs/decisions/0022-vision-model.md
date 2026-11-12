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
