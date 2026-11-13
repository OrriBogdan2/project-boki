# 0045: One wisp rule set in PvE and PvP

- **Status:** accepted (prototype, behind the boki_wisps setting)
- **Date:** 2026-11-10
- **Area:** match flow

## Problem
DECISIONS 2026-11-09 "Soul-linked Boki" and WISP_DESIGN_OPEN.md Q9: one rule set everywhere, with exactly two PvE
exceptions: (1) monsters and bosses never grab wisps (stealing is between Hunters only); (2) a summon killed by a
monster (no rival Hunter involved) goes home with the plain x1.0 cooldown and no reveal, whatever the owner's state.
(The Meadow tier keeps stealing on: that is the same rule, not an exception.)

## Audit (code read, then `--wisp-rules-check`)
| Place | Summon | Kill of a summon | Steal / loose | Same as PvP? |
|---|---|---|---|---|
| Lairs, bosses, monster camps | same `KinSummon` | a monster kill = exception 2 | no monster code path grabs; Hunters grab | yes |
| Meadow tier | same | same | stealing on (echo bonus is small) | yes |
| Training Area | same | same | same | yes |
| Expedition rivals / bots | same | rival kill: x1.25, reveal, ping, loose if owner down | same | (the baseline) |
| Tutorial | **off**: `KinWisp.mode` returns false | none | none | **no, kept** |

Only the tutorial differed. It stays walking-Boki only: its steps (`kin1`, orders, the Boki guide in
`KinCompanion`) teach a Boki with an AI, which a wisp does not have. Alternative if the owner wants wisps taught
there: add a wisp step to the tutorial and drop the guard in `KinWisp.mode`. Nothing else needed a fix.

## Decision
One code change: a kill counts as a monster's only when no rival Hunter hurt the summon in the last
`rival_window_s` (3 s, content/rules/boki_summon.json); KinSummon.note_hit remembers the rival, so a monster that
finishes a rival's work still costs x1.25 and reveals. `--summon-death-check` has the monster-kill and mixed-kill rows.
Besides that, no game-code change. `tools/wisp_rules_check.gd` (`--wisp-rules-check`) runs one summon, kill and steal script in an
expedition, the Meadow tier and the training area, once with a rival Hunter as killer and once with a monster, and
requires every recorded field to match except the exception-2 fields (cooldown multiplier, reveal, loose when the
owner is down).

## Consequences
A future PvE special case in the summon or steal code fails this check.
