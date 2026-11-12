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
- `Save.VERSION` 13 to 14 (renumbered when merged after Evo took 12 and the garden zones took 13); the migration turns a saved `guild_id` into a member clan, everyone else gets `{}`.
- Net.VERSION: no. This is the page store, not the match relay.
- Closing is checked in the join button only (the store has no rules); a forged join can at worst put a name on
  a roll, never touch another save.
- `Social.store_stub` lets `--clan-check` run Social against an in-memory store.
- Debt (docs/DEBT.md): focus, officers, founder hand-off, kick, invite links, base, league, chat.
- Slice 2 (the shared base): the ferry on the guild isle opens `ClanBase` (scripts/home/clan_base.gd), a visit to
  an island built from the members' published snapshots plus `clanbase/<gid>` (read only, cleaned by
  `Social.clean_clanbase`: one showcase Boki per current member, 12 at most). No new writes, no save change.
- Slice 3 (tag and member roll, `ClanInfo` in scripts/social/clan_info.gd): the guild doc gains `tag` (2-4
  letters A-Z, blocked list in content/rules/clan_tag.json; a clan without one shows its name's initials).
  `Save.d["clan"]["tag"]` is refreshed from the guild doc on every guild refresh (no migration: a missing key
  reads as no tag). The profile snapshot carries `tag` and `last` (the newest extraction, raise or breed in the
  event log, which now logs "extracted" and marks a hatched egg of two parents `bred`). The tag rides the lobby
  presence and roster to in-match nameplates (an optional key: an older peer just shows no tag, so Net.VERSION
  is left to the batch bump) and the island-visit top bar; the member roll shows each member's last deed.
