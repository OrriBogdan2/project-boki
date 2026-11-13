# Bug hunt 2026-11-11: networking, combat state, saves (30-hunter expeditions)

Base: ext/release-integ-0245 (92df78ce4). Branch: ext/bughunt-net-1111. Ranked by player impact.
Method: reading `Net`, `Match` net receive/apply/events, the relay, `Save`, the Heart and pickups, then a
single-process online match fed the relay's peer list by hand (`--net-leave-check`), a save torture test
(`--save-safe-check`), and the two-process `--revive-net-check`. No 30-process soak was run (usage).

## Fixed (failing check first, then the fix; docs/decisions/0061)
1. **A player who drops off the relay, or never reached it, stays forever as a frozen, unkillable body.**
   Only the owner's game can hurt a proxy (hits go to `Net.owner_of`), and nothing on the other games
   ever ended it. Its squad counted as alive (`_check_last` never fired, so no last-squad Heart seat), and
   a Heartspark it carried was gone for the whole lobby. Roster players are spawned before anyone loads,
   so a player who crashed in loading stood at spawn the whole match.
   Evidence: `--net-leave-check` 4 FAIL before (out=false, Heartspark still carried), 9/9 after.
   Fix: `NetLeave` (scripts/match/net_leave.gd) uses the lobby's rule (`Prematch._gone`).
2. **A save cut off mid-write wipes the player's save.** `save_game` wrote over the file in place; half a
   JSON file loaded as a fresh save, and the next autosave wrote over the rest.
   Evidence: `--save-safe-check` 2 FAIL before (loaded "Hunter", the fresh default), 3/3 after.
   Fix: write `.tmp`, keep `.prev`, rename in; load the newest copy that parses; delete removes all three.

## Open (not fixed here, each needs a design call)
3. **The host leaving freezes the match for everyone.** Every non-`P` id (monsters, bots, loot, the Heart)
   belongs to `Net.host`; there is no host migration. With 30 hunters on player-hosted games this is the
   biggest remaining risk. Fix: the Stage 1 authoritative headless server (DECISIONS), not host migration.
4. **Loot can be duplicated.** `_take_gear`/`_take_tune` (match.gd ~1242) apply the pickup on the taker's
   own game first; a `wtake` from another game only removes the copy. Two players on one item within one
   round trip both get it. Fix: the host grants pickups (a claim and a grant event, `Net.VERSION` bump);
   costs one round trip of pickup delay, so it needs a feel check.
5. **Losing your own connection mid-match is silent.** `Net._on_enet_closed` calls `m.net_lost()` behind
   `has_method`, and `Match` has no `net_lost`: the other hunters freeze where they were and nothing says why.
   Also an AGENTS.md section 4 breach (dynamic call). Needs the owner's call on what a cut-off run keeps.
6. **A late snapshot can bring back a caught or dead Boki as a ghost.** Snapshots ride the unreliable
   channel, events the reliable one, so they can arrive out of order; `_net_apply` sets `k.dead = false`
   for any `k` snapshot. A wild Boki caught on the host can reappear frozen and unscannable on a guest.
   Rare (needs reordering across channels). Fix: keep the event's kill unless the snapshot's header time
   is newer than it.
7. **Dead monsters are never freed until the match ends.** `mobs` keeps every dead Mob node (lair adds,
   exit guards); every `for mb in mobs` walks them. Bounded per match; unbounded in a long Training
   Grounds session (dummies respawn forever, match.gd ~4545). Fix: free dead mobs after their death fx.
8. **Remote shot copies carry a freed owner.** The `s` event builds a throwaway `Ent`, `spawn_shot`
   stores it as the shot's `by`, then it is freed. Every current reader is guarded (`cos`,
   `is_instance_valid`), but the next one that isn't will crash. Fix: pass `null`-safe team data instead.
9. **An unknown Boki species in a snapshot crashes the receiver** (`_net_make` indexes `Data.KIN`
   without `has`). The version gate covers normal play.

## Checks
- `--revive-net-check` fails 2 of 7 on the 0245 base with and without this branch (same lines): the
  check reads deathboxes as objects (`b.out`, `b.pos`) but they are dictionaries now (tools/
  revive_net_check.gd:97, 123, 145). The check is stale, not the game; it needs its own fix pass.
- `Net.seen` is set and cleared but never read (dead).
