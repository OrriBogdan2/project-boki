# 0022: Rejoin a match in progress

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** networking / match flow

## Problem
A client crash or a connection blip loses that Hunter for the rest of an online match: the relay forgets the
connection, its peer id is gone, and a restarted game can only start a new match.

## Options
1. Host-side handover: the host adopts the dropped Hunter. The host doesn't simulate other players' Hunters
   today, so it needs a new ownership path. Large.
2. Relay keeps the slot: the relay already sees every Hunter's own `st` snapshot. It keeps the last one and the
   player's net id for 90 s and gives them back to a client that shows the right rejoin token. Small.

## Decision
Option 2. The relay gives each connection a net id of its own (no longer the ENet id, which gets reused), so a
rejoin can take the old id back and every other game keeps driving the same `P<id>` Hunter. On a drop the relay
sends the room one last still copy of the Hunter (zero velocity), so it stands where it was, or stays a Wisp if
it was downed. The client keeps `user://rejoin.json` (server, token, the match start, last seen); the title
offers "Rejoin match" while it is under 90 s old. The rejoined game builds the same match, skips the drop and
puts back its Hunter's place, health and Boki from the relay's copy; the host's snapshots fill in the world.

## Consequences
`Net` (scripts/core/net.gd), `RelayServer`, the new `NetRejoin` (scripts/match/net_rejoin.gd), one line each
in `match.gd` and `title.gd`. Net.VERSION 0.25.1 (the hello, join and welcome carry rejoin fields). Check:
`--rejoin-check`. Not covered: a host that drops (the world stops with it, as before), and world changes
other than the Hunter while the player was away beyond what the host's snapshots carry.
