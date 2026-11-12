# 0039: Boki summon out of the wisp

- **Status:** accepted (prototype, behind the boki_wisps setting)
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
- Net.VERSION 0.33.1 (0.28.2 before merge candidate 0630 took 0.33.0), all in `net.gd`: a Boki's k1/k2 cast goes out
  at once as `["kab", nid, ability, slot]` and plays on the
  other games as `CombatBus.ability_used` plus the floating name; my snapshot is sent at once when my Boki blooms, shrinks or
  falls back into its wisp (not on the next 0.1 s beat); a remote Boki's summon timer counts down between snapshots.
  `--summon-net-check` (two games over the relay): burst, both casts, the kill, the shrink and the timer read the same on
  the other game within 150 ms (seen 15-40 ms; before the fix: no casts, bursts up to 250 ms, timer 0.2 s stale).
