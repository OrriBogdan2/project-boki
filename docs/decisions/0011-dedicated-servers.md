# 0011: Dedicated match servers (stage 1)

**Problem.** Online play ran on whoever pressed Start: that player's game was the host (monsters,
bots, loot) and everyone else went through the relay. The owner wants matchmade play on our own
authoritative servers in two regions (DECISIONS "Hosting and distribution").

**Options.** (a) Rewrite Net as a server-authoritative protocol. (b) Keep the host-authoritative
Net and make the host a headless process with no local player. (c) A third-party service (Nakama).

**Choice: (b).** `--server` (scripts/core/dedicated_server.gd) runs the existing relay with the
matchmaker's token table and joins it over loopback as the host, so the match code, the bots and
every sync message stay exactly as they are. The only new handshake rules live in the relay:
version, one-time token, seat count, each refused with a code the client keys its message on.
The matchmaker (server/matchmaker, Python) spawns one such process per match and hands clients
host, port and token; OnlineSession on the client does the queue and the join, the online screen
shows it. A match ends when one team is left (or the islands fall); the server calls it, sends
"end" and exits 0.

**Affects.** scripts/server/relay.gd (tokens, reason codes, signals), scripts/core/net.gd
(connect_to/leave, deny codes), match.gd (net_over/net_lost), the "Linux Server" export preset,
content/rules/servers.json, Settings "region". The host is not in the roster, so `Match.player`
is null on the server: anything that assumes a local player must guard on it. Players who drop
mid-match are eliminated by the server. Net.VERSION: the sync shape is unchanged; the handshake
grew fields old builds ignore (a bump is main's call).
