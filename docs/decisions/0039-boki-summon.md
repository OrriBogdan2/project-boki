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
Damage never ends it; a kill turns it back into a wisp (the cooldown and what follows: decision 0044). The window ends in a 0.35 s
shrink; Summon while out sends it back early (full cooldown). The wisp is dim with no sparkles while resting;
a ring and the seconds (or the Summon key) sit on the right-side Boki box (BokiHud.summon_ring).
Carry passives: the wisp rides on the shoulder with the Return order, so its passives are on at 100 % whether
it is a wisp or out; stolen wisps add theirs at a share (decision 0041). Stealing (0041), the killed summon (0044)
and one rule set for PvE and PvP (0045) have their own notes.
Left out on purpose: guardian summon, kill credit (the kill-feed task), bots summoning, mounts.

## Consequences
- Net.VERSION 0.24.14: kin snapshot indices 25-27 = window, shrink, cooldown seconds (KinNet).
- kin.gd +6 lines (field, tick, knock-down hook), match.gd +5 (input wiring). `--summon-check` (alias `--summon-leash-check`) covers the key, the table, the kills, the snapshot round trip and the leash
  (chase, dash, glide, knock). The Summon prompts read `Settings.key_cap("summon")`.
- The Training Grounds' Boki island has a summon pad (`SummonStation`, content/rules/summon_station.json): stand on it for the
  round-vs-critter card and the live Summon key, interact for the next of three practice Bokis with different windows.
  `--summon-station-check` covers the card, each window and cooldown, and the early send-back.
- Cards: the Field Book species page shows `Summon N s / rest N s` from `KinSummon.times` (the same cell the summon
  reads) and a plain line picked by `card_lines` thresholds in boki_summon.json ("Short summon, strong" / "Long summon,
  steady") (DexView.summon_row; ported from ext/ui-summon-card 10b3b9152a; the garden card and loadout rows are left
  out because home.gd is frozen).
