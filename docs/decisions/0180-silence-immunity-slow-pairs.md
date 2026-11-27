# 0180: Silence, granted immunity and cleanse, and a slow's timer against its own strength

- **Status:** accepted
- **Date:** 2026-11-27
- **Area:** combat

## Problem
The CC system had stun, root, slow and the post-revive guard, but no silence, no way to grant immunity, a cleanse that left the new kinds behind, and one slow slot: a weaker, longer slow overwrote the stronger one's timer, so the strong k ran on the weak one's clock (reference tuning pairs each slow's timer with its own strength).

## Options
1. A new Net event and a new Ent field for silence. More wire, a version bump.
2. Silence as a `KitStatus` kind (`sil_until` meta, synced by the existing "kst" event) (decided).

## Decision
Option 2. A silenced Hunter loses abilities, gear, belt, base recall and the glider; attack, dash and jump stay. Granted immunity (`Ent.grant_cc_immunity`) reuses `cc_guard_t`, which now also blocks silence. `Ent.cleanse_cc()` clears slow, root, stun, burn and silence in one call. `Ent.add_slow(secs, k)` keeps the strongest slow in front (`slow_t`/`slow_k`) and a weaker but longer one waiting (`slow2_t`/`slow2_k`), promoted when the front ends. Every slow site goes through `add_slow`. Dredge's reel silences the foe for the pull time (cap 4 s).

## Consequences
- No new Net event; "kst" carries the new kind "sil". Old clients ignore an unknown kind.
- `--cc-silence-check` covers slow pairing, silence gates and expiry, immunity and cleanse.
- Not wired yet: other silence sources (recall, respawn in air), a silence icon and sfx (the dazed icon stands in).
