# 0022: Clans grow out of guilds

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** save / networking

## Problem
The owner wants clans so people can do what they like and still play together (docs/specs/CLANS.md). A guild
already has a shared isle, projects and a member list read from profiles, but no ranks and no record of who
belongs that the clan itself keeps. Slice 1 is only identity and the roster.

## Options
1. A new clan system beside guilds. Two registries for the same people.
2. Extend the guild: the clan id equals `guild_id`; a rank and a corner seed live in `Save.d["clan"]`; the store
   gets one new per-member doc.
3. Put the roster inside the `guilds/<id>` doc. One doc, many writers: members would overwrite each other.

## Decision
Option 2. `Save.d["clan"] = {id, role, corner_seed, joined}` (empty when in none). The store gets
`clanroster/<gid>_<me> = {guild, role, joined, corner_seed, last_seen}`, written by the member (on join and on
each `refresh_guild`, so members from before clans appear), deleted on leave. Reads go through
`Social.clean_roster`: other clans' rows, unknown ranks and repeats are dropped, "founder" is believed only for
the guild doc's founder, numbers are clamped, 24 rows at most. Ranks are `founder`, `officer`, `member`.
The guild doc gains `open` (default true); the founder can close the clan to newcomers. The clan never gates
content: leaving or never joining costs nothing. Size cap 24, as the spec's default.

## Consequences
- `Save.VERSION` 11 to 12; the migration turns a saved `guild_id` into a member clan, everyone else gets `{}`.
- Net.VERSION: no. This is the page store, not the match relay.
- Closing is checked in the join button only (the store has no rules); a forged join can at worst put a name on
  a roll, never touch another save.
- `Social.store_stub` lets `--clan-check` run Social against an in-memory store.
- Debt (docs/DEBT.md): focus, invite links, league, chat (officers, hand-off and removal: slice 3; base: slice 2).
- Slice 2 (the shared base): the ferry on the guild isle opens `ClanBase` (scripts/home/clan_base.gd), a visit to
  an island built from the members' published snapshots plus `clanbase/<gid>` (read only, cleaned by
  `Social.clean_clanbase`: one showcase Boki per current member, 12 at most). No new writes, no save change.
- Slice 3 (ranks): a rank is what the guild doc says (`Social.rank_of`): its `founder`, and a new `officers`
  list (cleaned by `clean_guild`); a member's own roster row no longer decides its rank, so a forged "officer"
  reads as member. Only the founder writes the guild doc (`_founder_edit`): make an officer or a member again,
  or hand the founder role to an officer (the founder field moves, the old founder joins `officers`). Removal
  writes no one else's doc: founder and officers list removed ids in their own `clanout/<gid>_<me>` =
  `{guild, ids}` (48 at most). `Social.removed_from` believes a removal only while its author outranks the
  member now, and skips an officer the founder removed; `clean_roster` drops the removed. The removed
  member's game sees it on its next `refresh_guild` and leaves (row deleted), and its Join refuses. A forged
  write can at worst put a name back on the roll. No save change (the rank was already in `Save.d["clan"]`),
  no Net change. Alternative not taken: a removal list in the guild doc (officers would share its writes).
