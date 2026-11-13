# 0039: Boki summon out of the wisp

- **Status:** accepted (prototype, behind the boki_wisps setting); input amended 2026-11-11 (see below)
- **Date:** 2026-11-09
- **Area:** match flow, networking, input

## Problem
DECISIONS 2026-11-09 (Soul-linked Boki ride as wisps): a dedicated Summon button bursts the wisp into the full
Boki for a short window on a long cooldown, per species. briefs/boki-art/WISP_DESIGN_OPEN.md recommends the
numbers (Q1), one summon at a time (Q3), damage never ending it but death doing so (Q5) and a short leash (Q7).

## Options
1. Reuse the Boki key (tap = summon/recall, hold = wheel), the brief's pick. The owner asked for a dedicated button.
2. A new rebindable `summon` action (C; "details" has C at home only), state in a focused `KinSummon` on the Kin.

## Decision
Option 2. `content/rules/boki_summon.json` holds the role x size table (window, cooldown) and the uptime band;
every species takes its cell (no per-species override until one is needed). Summon: the kin bursts beside you
whole, on its normal AI and orders, leash 10 m (+-2 m by aggression), re-blooming beside you past 20 m.
Damage never ends it; a knock-down turns it back into a wisp with x1.25 cooldown. The window ends in a 0.35 s
shrink; Summon while out sends it back early (full cooldown). The wisp is dim with no sparkles while resting;
a ring and the seconds (or the Summon key) sit on the right-side Boki box (BokiHud.summon_ring).
Left out on purpose: guardian summon, stealing, the reveal on a killed summon, bots summoning, mounts.

## Consequences
- Net.VERSION 0.28.0: kin snapshot indices 25-27 = window, shrink, cooldown seconds (KinNet).
- kin.gd +6 lines (field, tick, knock-down hook), match.gd +5 (input wiring). `--wisp-check` covers it.
- Press timing: `--summon-press-check` (the burst on the press frame, offline and at 100 ms).

## Amendment 2026-11-11: the summon is on G
The 11-10 design review (fix 6) held DECISIONS Controls to its word: G is the single Boki button. Option 1 is in
after all, the `summon` action (C) is gone. `KinCommand.poll` returns "summon" the frame G is pressed on a wisp
(the burst still lands on tick 0, buffered through casts and dashes as before, since it is not the Hunter's body);
the release of that press is no tap. A tap while summoned sends it back (`KinCommand.tap` -> `KinSummon.press`);
a hold opens the order wheel as ever. `KeyMigrate` step 6 (keys6_v) drops a saved Summon bind, default or custom.
`--summon-press-check` G rows: tap, tap again, hold on the wisp, hold while out, cooldown; `--keybind-check`:
no summon action, old-settings migration.
