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
- `Save.VERSION` 12 to 13 (12 is Evo on the 0.24.4 line); the migration turns a saved `guild_id` into a member clan, everyone else gets `{}`.
- Net.VERSION: no. This is the page store, not the match relay.
- Closing is checked in the join button only (the store has no rules); a forged join can at worst put a name on
  a roll, never touch another save.
- `Social.store_stub` lets `--clan-check` run Social against an in-memory store.
- Debt (docs/DEBT.md): focus, officers, founder hand-off, kick, invite links, chat, the rest listed there.
- Slice 2 (the shared base): the ferry on the guild isle opens `ClanBase` (scripts/home/clan_base.gd), a visit to
  an island built from the members' published snapshots plus `clanbase/<gid>` (read only, cleaned by
  `Social.clean_clanbase`: one showcase Boki per current member, 12 at most). No new writes, no save change.
- Slice 3 (league and clan egg, `ClanLeague`, scripts/core/clan_league.gd): each member writes one score doc a
  season, `clanleague/<gid>_<season>_<me> = {guild, season, pts, day, day_pts}` (one writer per doc, as
  `contrib`). Seasons are Monday-to-Sunday UTC weeks (`w<n>`). An expedition you make it out of scores 10
  (`Game.apply_result` calls `ClanLeague.score`), at most 200 a day. The table and the clan egg read only
  current roster members' docs, points clamped to a season's most (1400). At 300 clan points each member
  can take one egg a season (a Rare Egg of a species picked from the clan and season) into their own
  Incubator; `Save.d["clan_egg"]` keeps the season taken, so leaving and joining another clan gives no
  second. Added to the same v12 -> v13 step (unreleased). The egg claim trusts the store's total: a forged
  doc can at worst give one egg a season early.
