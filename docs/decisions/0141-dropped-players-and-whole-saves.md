# 0061: Dropped players are out; a save is never cut in half

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** networking, save format

## Problem
1. A remote Hunter is a proxy that only its own game can hurt. When that player drops off the relay (or never reached it after the lobby), nothing on the other 29 games ever moves it: it stands frozen and unkillable, its squad counts as alive (`_check_last` never fires), and a Heartspark it carried is gone for everyone.
2. `Save.save_game` wrote over the save in place. A game that dies mid-write leaves half a JSON file; `load_from` then starts a fresh save and the next autosave writes over what was left.

## Options
1. Leave: a timeout on snapshots (no `st` for N seconds). Cons: a long hitch or a loading guest would be thrown out; a second rule beside the lobby's.
2. Leave: the relay's peer list, as `Prematch._gone` already does: a roster peer missing from `Net.peers` while we are online is gone. No new topic, no `Net.VERSION` bump.
3. Saves: write `<file>.tmp`, keep the old file as `<file>.prev`, rename the new one in; load the newest copy that parses.

## Choice
2 and 3. `NetLeave` (scripts/match/net_leave.gd) marks the proxy out and gone, its Boki dead, posts "left the match", and runs the squad and last-team checks; the host's Heart then drops the Heartspark where they stood. Nothing runs while our own line is down. The save file format is unchanged (no migration); deleting a slot removes all three copies.

## Affects
Online matches (every game, host and guests), Save load, save and delete. Checks: `--net-leave-check`, `--save-safe-check`. Not covered: the host leaving (monsters and bots freeze; needs host migration, docs/BUGHUNT_1111.md).
