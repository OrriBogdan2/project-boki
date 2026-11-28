# 0181: Knockback resist divides the push

- **Status:** accepted
- **Date:** 2026-11-28
- **Area:** combat

## Problem
The source (traversal-1126, physics-parity-1127 row 49) scales a knock as impulse x KnockbackCoefficient(instigator)
/ max(KnockbackResist(target), 0.5) / mass. Ours (`Hunter.impulse`) multiplied by (1 - knockback_resist): a 0.5 resist
halved the push where the source's divisor leaves two thirds, 25% less; a 0.75 merge resist left a quarter where the
source leaves 57%. Over the 15% line the parity row set.

## Options
1. Keep the subtract form and shrink the data's resist amounts: the data stops meaning what the kin cards say.
2. Divide by max(1 + resist, 0.5), the source's shape with our stat as the bonus over 1: the data stays, the text changes.

## Decision
Option 2. `Hunter.impulse` divides the push by max(1 + knockback_resist, 0.5) and by the class mass; the lift still
divides by mass only. `KinText.owner_stat` says "-33% knockback" for 0.5 (was "half knockback"), "-43%" for 0.75.

## Consequences
`scripts/match/hunter.gd` (one line), `scripts/kin/kin_text.gd`, the "a third less knockback" wording in KIN_GRAMMAR,
RIDING_SPEC and BOKI_AGENCY_AUDIT. No Net.VERSION bump: the resist is read on the body's own game. `--knock-chain-check`
asserts Albert, Kael and Meeko carrying a Goliathite (0.5) fly at push / 1.5 / mass. The class mass (0.85 / 1.0 / 1.35)
vs the source's fixed 100 stays as it is: docs/KNOCK_WALLS.md "Knock formula" lists the gap.
