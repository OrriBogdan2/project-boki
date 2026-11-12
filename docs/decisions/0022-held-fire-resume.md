# 0022: Held fire resumes the frame a slot's lock ends

- **Status:** accepted (extends 0015)
- **Date:** 2026-11-10
- **Area:** combat / input

## Problem
PARITY FIRST (briefs/DECISIONS.md 2026-11-07): in the source LMB is a held input. Hold it through an E, RMB, a dash or the ult and fire resumes the frame that action's lock ends, with no re-press (the footage shows the rifle firing on through a slide, the hose back on the aim out of a bash, the bow drawn again without a click). Ours already reads the key every frame (`Hunter.trigger` and each kit's `lmb_override`), but two kits had re-press latches: Albert's Crushing Blow ignored a held button after another ability cut the hold (owner item 30's cancel rule, "the button must come up"), so a held LMB never came back after an RMB, E or glove; and nothing measured the rest.

## Options
1. A shared "resume" buffer in Hunter that re-presses LMB for the kit when a lock ends: a second input path beside the held key.
2. Keep the held key as the one path, delete the latches that contradict it, and add a check that measures every Hunter and slot so a new latch can't slip in.

## Decision
Option 2. `BulwarkKit.hold_blocked` is gone (a cut hold restarts the step he is free). `ArchKit.lmb_holding()` names a kit's hold state (a draw, a charge, a hose) so the check needs no per-kit tables. `--held-fire-resume-check` (tools/held_fire_resume_check.gd) runs, per Hunter and slot, a held run against two tapped runs: the tapped runs' first accepted tap is the lock's end as the kit defines it; the held run must fire (or hold) again within 1 frame of it, and a hold kit must not loose a stale release. A tap that cuts the action short (Sable's Kitefall comes down on a fresh press, by design: the source's way down is reactivating the ult, not LMB) makes it another action, so that row is judged against the held run's own action end. Measured: 12 Hunters x 5 slots, 0 failures, no gap over 0 frames.

## Consequences
- `content/dash_flow/<hero>.json` may carry `held_fire` rows (docs only) that `tools/gen_wiki.py` lists in docs/heroes/dash_interactions.md under "hold LMB through"; the rule itself is shared, not per row.
- Not covered: LMB held through a recast (an E pressed again while its first cast is up); the slot press in the check is a single press.
- No Net or save change.
