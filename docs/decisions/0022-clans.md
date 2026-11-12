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
- `Save.VERSION` 13 to 14; the migration turns a saved `guild_id` into a member clan, everyone else gets `{}`.
- Net.VERSION: no. This is the page store, not the match relay.
- Closing is checked in the join button only (the store has no rules); a forged join can at worst put a name on
  a roll, never touch another save.
- `Social.store_stub` lets `--clan-check` run Social against an in-memory store.
- Debt (docs/DEBT.md): focus, officers, founder hand-off, kick, invite links, base, league, chat.
