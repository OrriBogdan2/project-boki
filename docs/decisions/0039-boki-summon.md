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
Damage never ends it; killing it turns it back into a wisp (rules changed by 0044: x1.25 cooldown only for a rival's kill). The window ends in a 0.35 s
shrink; Summon while out sends it back early (full cooldown). The wisp is dim with no sparkles while resting;
Damage never ends it; a knock-down turns it back into a wisp with x1.25 cooldown. The window ends in a 0.25 s
fold; Summon while out sends it back early (full cooldown). The wisp is dim with no sparkles while resting;
a ring and the seconds (or the Summon key) sit on the right-side Boki box (BokiHud.summon_ring).
The look both ways is BokiWispPop (ext/wisp-summon-pop): the wisp swells and the Boki grows out of it, squashes on
landing and opens its eyes last; the fold shuts the eyes, shrinks the Boki into the wisp and zips it to the
shoulder. Soft light only: the bloom's spark burst and ground ring and the knock-down's spark burst are gone
(DECISIONS: explosions only for things that truly explode).
Left out on purpose: guardian summon, stealing, the reveal on a killed summon, bots summoning, mounts.

## Consequences
- Net.VERSION 0.28.0: kin snapshot indices 25-27 = window, shrink, cooldown seconds (KinNet).
- kin.gd +6 lines (field, tick, knock-down hook), match.gd +5 (input wiring). `--wisp-check` covers it.
- Net.VERSION 0.28.1, all in `net.gd`: a Boki's k1/k2 cast goes out at once as `["kab", nid, ability, slot]` and plays on the
  other games as `CombatBus.ability_used` plus the floating name; my snapshot is sent at once when my Boki blooms, shrinks or
  falls back into its wisp (not on the next 0.1 s beat); a remote Boki's summon timer counts down between snapshots.
  `--summon-net-check` (two games over the relay): burst, both casts, the kill, the shrink and the timer read the same on
  the other game within 150 ms (seen 15-40 ms; before the fix: no casts, bursts up to 250 ms, timer 0.2 s stale).
- One summon lane (Q3): a Hunter has one summoned Boki out at a time, a stolen one included
  (`KinSummon.lane_busy`). Summon while another Boki is out, or while resting, is refused with the denied
  cue (warn sound, red shake); Summon while your own is out stays the early recall. The leash (Q7) is in the
  rules with its unit and reason; `--summon-leash-check` covers the lane and the leash through a chase past
  it, a dash, a glide and a knock. The ordered chase and guard keep today's longer leashes (the 20 m re-bloom
  still cuts them): "controlled exactly like the out Boki". Alternative: refuse the press while your own is out too.
