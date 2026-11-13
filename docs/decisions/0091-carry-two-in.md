# 0091: Carry two Boki in (the lead and the second)

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** match flow, networking (save format unchanged)

## Problem
Owner order 11-11 (DECISIONS "carry 2 in, 1 extra out"), the "2 in" half: a match takes a lead Boki and a second one. The lead has the summon (G). Both carry passives apply, but the same passive counts once (the stronger one). A key swaps the lead on a short cooldown. Main had one Boki per run (`Match.TWO_KIN` off), with the old bench code still there.

## Options
1. A new two-slot system next to `Hunter.kin`. Cons: it duplicates the bench, swap and life/loss code that already handles `Hunter.kin2`.
2. Bring back main's own two-kin code (`Hunter.kin` / `kin2`, the `bench` state, `Hunter.swap_kin`), drop the flag, and fix what it lacked: passive stacking, a key, Net sync, downed rules.

## Decision
Option 2, from the carry-in half of the unmerged WIP `wip/cj-20261111-191659-a3` (its 0090 note). The carry-out slots and the 4-wisp cap stay out of this branch.
- **Passives:** `KinSlots.carry_stats` adds up each Boki's own carry passives. Between the two Boki, the stronger value of a shared stat counts. The lead's passives are on while it rides with you (`kin_carry_on`), the second's while it is in the satchel, healthy, with you standing.
- **Swap:** the new rebindable `swap_kin` action (default C, which is Details at home: `Settings.SHARED_OK`) swaps the two after `kin_ai.swap_cooldown` (3 s). There is no swap while you are downed, and only a Boki in the satchel can come out.
- **Downed:** a downed lead stays where it fell (decision 0001: it can still be scooped or stolen). The swap brings the second out, and the downed one comes back to the satchel when it comes round (`KinDowned.come_round`). If you go down while the lead is down, the second still comes out by itself.
- **Bots:** they always bring two, online too.
- **Net (0.24.6):** the snapshot carries both Boki, `KIN_STATES` gains `bench`, and the kin row gets a lead flag (`KinNet`). Other games follow which one leads.
- **Save:** `active2` is already saved and read with a default, so there is no format change and no migration.

## Consequences
The `TWO_KIN` gate leaves match.gd and home.gd. The new kin_slots.gd holds the passive rule. kin_net.gd gets the lead flag, and kin_downed.gd sends a second back to the satchel. Only the lead's on-shot riders and stat-point owner bonus apply. Check: `--carry-two-check`.
