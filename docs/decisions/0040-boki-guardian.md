# 0040: Guardian summon

- **Status:** accepted (prototype, behind the boki_wisps setting)
- **Date:** 2026-11-09
- **Area:** match flow, networking

## Problem
DECISIONS 2026-11-09 (owner leaning: guardian summon). A Hunter who goes down with the Boki's summon ready should
get the Boki bursting out to protect them. briefs/boki-art/WISP_DESIGN_OPEN.md Q4 recommends the numbers.

## Options
1. A manual Summon while downed. Rejected by Q4: a downed Hunter has no free input, and it adds a rule.
2. The knock itself starts the summon (`KinGuardian.on_down`, one call in `Match.knock`), with no key.
3. No guardian (wisps always scatter at once). The fallback if duo data says it is too strong.

## Decision
Option 2. Summon ready and not out: the Boki bursts beside the Hunter Wisp for its own window clamped to 8-15 s,
on its normal AI with a 6 m leash to the downed owner. It uses the summon (cooldown starts when the window
ends, as any summon), never touches the bond meter, and takes x1.25 damage. Beaten (KinSummon.knocked) it turns
back into a wisp with the x1.25 cooldown. Revived inside the window it finishes the window as a plain summon.
Readable: a white ground ring pulses round the Hunter Wisp and the Boki HUD ring turns white with GUARDIAN
(round = Hunter, critter = Boki). Numbers: `content/rules/boki_summon.json` "guardian".
Stealing is not built yet: `KinGuardian.protecting(h)` is the hook; a downed Hunter's wisps scatter only while
it is false (window ended, guardian beaten, or the Hunter is out).

## Consequences
- Net.VERSION 0.29.0: kin snapshot index 28 = the guardian flag (KinNet).
- kin.gd +2 lines (damage), match.gd +1. `--wisp-guardian-check` covers it.
- Not built: the Boki's own revive pull-up gating on a teammate standing on the Hunter (the existing 8 s Boki
  revive runs as it does for any downed owner), the `guard` bark, the +10 s squad cap.
