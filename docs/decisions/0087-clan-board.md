# 0087: One weekly clan goal on the showcase wall

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** networking (page store) / farm

## Problem
Clans are meant to let people do what they like and still play together (owner priorities 2026-11-09);
DECISIONS 11-09: some members extract, some raise. Nothing yet adds what each member does into one shared thing.

## Options
1. One goal doc per clan that every member adds to. Many writers on one doc: members overwrite each other.
2. Each member writes only their own row, `clanboard/<gid>_<me>`; the board is the sum, read like the roster.
3. A clan league or chat. Out of scope (owner: no chat, no league).

## Decision
Option 2. Points come from `content/rules/clan_board.json`: a garden cup won (on this base: the Dash won by the
Boki you backed; real cups can call the same `ClanBoard.add("cup")`), a Boki raised to a final form by levels,
and an extraction finished. A row is `{guild, week, cup, final, extract, paid, updated}`; the week is the
device clock's unix week. Read through `ClanBoard.clean_rows`: other clans' and other weeks' rows, non-members
and repeats are dropped, counts are clamped to each kind's weekly cap, points are worked out locally (a stored
score is never believed). The goal grows with the clan (`goal_per_member`, at least `goal_min`). The wall
shows the bar and the top three; every member's share is in the board read. At the goal, each member's own
client pays them `reward_gems` once a week when they open the clan base (it writes `paid` first).

## Consequences
- New `scripts/social/clan_board.gd`; hooks: `Game.apply_result` (extract), `Game._evolve` (final),
  `BaseRace.settle` (cup), `ClanBase` (read, pay, draw), `Social.leave_guild` deletes the row.
- No save field (counts live in the store row), so no migration; Net.VERSION: no (page store only).
- Events while offline or outside a clan don't count. A client can forge its own row, but only up to the caps.
- `--clan-check` gets board rows.
