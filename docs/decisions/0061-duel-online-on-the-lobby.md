# 0061: The duel ring's online 1v1 runs on the Play online lobby

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** networking, match flow

## Problem
DECISIONS (owner, Nov 7): Duel keeps an online queue, reached only from the Training Grounds duel ring (search online, fight a bot, or fight a friend). ext/duel-ring-online queued through a matchmaker and dedicated servers that main does not have, and its ring was built on the old Arena / Training Area. The pad on main only opened the bot duel room.

## Options
1. Port the matchmaker, OnlineSession and the dedicated server. Cons: a second lobby and a server line main has not taken; well over the task.
2. A duel line on the existing lobby (scripts/ui/lobby.gd): the ring opens it with opts "duel"; your presence carries "duel" instead of "lobby"; the line pairs off two by two in id order and the first of each pair hosts, sending the lobby's usual "start" with a two-team roster.

## Choice
Option 2. The match is the duel room (Match.duel_opts) with the "net" roster; Duel takes the other player's hunter as its rival in place of the bot. Each game owns its own hunter, so each puts only its own back on its mark: a knock is read from the snapshot's downed flag (counted once, on the way down), a fall is turned into a knock (Match.knock sends the existing "knock" event). No new topic or event; Net.VERSION is unchanged (an older game never announces "duel", so it is never paired).

## Affects
scripts/ui/lobby.gd, scripts/match/duel.gd, scripts/match/duel_ring.gd (the pad's panel), match.gd wiring (-5 lines). Checked by --duel-online-check (two games over the relay) and --duel-ring-hint-check.
