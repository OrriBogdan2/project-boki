# 0093: No ability starts while it is on cooldown

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** combat

## Problem
The owner could press RMB on cooldown and see the move start. `ArchKit.press_rmb` (and the archer and bulwark
overrides) set `rmb_down` with no charge check. The charge was only spent in each kit's `fire_rmb` on release.
In between, the hold ran: `rmb_hold_tick` started wind-ups and shields (the Heavy Shot's draw,
the Aegis, the Storm Rod's hold), and every pose that reads `rmb_down` played. The archer and bulwark kits
did not even show the deny. E, R, X, Shift and Q already checked their cooldown before anything happened.

## Options
1. Check the charge in every kit's `fire_rmb` and `rmb_hold_tick`. That is 13 kits with 13 ways to miss one.
2. Refuse the press itself: one gate at the top of the RMB press, reading the slot the way the bar shows it
   (`slot_info("sec").ready`: a charge, the kit's own lock-out, the Smash's air cooldown).

## Decision
Option 2. `ArchKit.rmb_open()` runs in every RMB press path: the base, the archer and bulwark kits, and the
juggernaut through `super`. The player, bots, DashFlow's held presses and a kit's own buffer all pass through it. The hold-to-aim preview
in `Match` is skipped for a cooling slot, so the press is refused at once. A refused press shakes and dims its
slot, with "On cooldown" over it while it is cooling (`PressDeny`, `HudSlot`, 0.75 s throttle per slot).

## Consequences
The Aegis can't go up while the RMB slot is cooling after a Shield Charge. The bar showed it as not ready
anyway. The juggernaut's bar shows the Meteor Drop's own rest while he is airborne, but a Smash charge still takes an air press (the ground Smash), so `JuggernautKit.rmb_open` lets it through. `--cd-gate-check` covers every hero and slot; `--cd-indicator-check` drives a real dash and RMB and compares the slots to the timers every step. hunter.gd +0 net, match.gd +5. No Net or save change:
remote players only ever see moves their owner's kit played.
