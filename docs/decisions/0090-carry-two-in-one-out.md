# 0090: Carry 2 Boki in, 1 extra out

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** match flow

## Problem
Owner order 11-11 (DECISIONS "carry 2 in, 1 extra out"): bring a lead and a second Boki, swap them, and ride one claimed Boki home, with stealing capped. Main had one Boki per run (`Match.TWO_KIN` off) and a 3-capsule capture box.

## Options
1. Build on the unmerged soul-link wisp line (ext/soul-link-integ): matches the wisp wording, but that line is 300+ commits behind main and held.
2. Revive main's own two-kin code (Hunter.kin / kin2, bench, swap_kin) and turn the capture box into the slots.

## Decision
Option 2. The lead (Hunter.kin) is the Boki you send out (the summon key on main); the second (kin2) waits in the satchel with its carry passive on. KinSlots.carry_stats sums each Boki's own passives and takes the stronger value of a shared stat. The swap key (C, swap_kin) trades them on kin_ai.swap_cooldown (3 s). Hunter.caught becomes 1 carry-out slot (claims: no passive, no summon, home on extract) + 1 stolen slot (another hunter's own Boki), 4 Boki in all (content/rules/capture.json). A full slot points the toast and a ping to the nearest teammate with room. Bots always bring two. Stealing stays main's: the slots spill into the deathbox.

## Consequences
match.gd/home.gd lose the TWO_KIN gate; capture.gd owns the slots; new kin_slots.gd; HUD: the right-side Boki box (GripHud) shows the lead with its summon ring and the second as a badge (passive icon, swap key cap, cooldown ring), the carry-out slot is a badge in boki_hud.gd; swap_kin bound to C (shares with home Details). No Net change (kin2 is a normal kin entity; the swap runs on the owner's game). No save change (active2 already saved). Check: --carry-two-check. When the soul-link wisps land, lead/second/carry-out map onto them as-is.
