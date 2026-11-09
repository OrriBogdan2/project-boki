# Networking

Code: `scripts/core/net.gd` (the `Net` autoload), `scripts/core/net_enet.gd` (desktop transport),
`scripts/server/relay.gd` (the relay server), the `# online` section of `scripts/match/match.gd`
(snapshots and events), and `scripts/ui/lobby.gd`.

## Model

The current model is **owner-authoritative per entity**, not server-authoritative:

- Each player's game owns its own hunter (`P<peer>`) and Boki (`P<peer>k`) and simulates them.
- The **host** (whoever pressed Start in the lobby) owns everything else: monsters, bots, loot,
  wild Boki, the Blight. `Net.owner_of(nid)` decides: ids starting with `P` belong to that peer,
  the rest to the host.
- Owners send **snapshots** of what they own. Anyone who hits something they don't own sends the hit to
  its owner, which applies it. One-off happenings (effects, catches, chests) go as events.

A move to a server-authoritative model (clients send inputs only) is planned in
`docs/ARCHITECTURE_PLAN.md` on the `design` branch. Nothing of it is built yet.

## Transports

| Where | Transport |
|---|---|
| Desktop | ENet to the relay server: channel 0 reliable (lobby, presence, hits, events), channel 1 unreliable-ordered (snapshots). One JSON object per packet. |
| Web build | The page's room capability via `Bridge`; locally, a BroadcastChannel between browser tabs. |

The launcher starts the game with `-- --server=host:port --token=<discord token>` (or set
`BOKI_SERVER`). Without a server address, desktop online play is off.

## Messages

**Lobby (relay `k` field):** `hello` (version, token, name) -> `welcome` or `deny` (with a reason);
`pres` (your presence), `peers` (who's online), `emit` / `msg` (lobby topics, e.g. `start` from the
lobby), `join` / `leave` (a match room), `memit` (a match message), `ping` / `pong`.

**Match topics:**

| Topic | Sent by | Content |
|---|---|---|
| `st` | Every owner, every 0.1 s; the host's world every 0.15 s | Snapshots of owned entities, with the match time as a header. Unreliable channel. |
| `hit` | Anyone who hits something they don't own | `[target nid, damage, knockback x, z, lift, crit, ...]`, applied by the owner |
| `ev` | Anyone | Events: `fx` (ring, bolt, cone), `kst` (kit status), `knock`, `out`, `catch` / `caught`, `chest`, and more |

Messages are chunked to stay under about 3.6 KB (`Net._chunks`).

## Net.VERSION

`const VERSION` in `scripts/core/net.gd` (now **0.7.0**). Online play only matches players on the same
version, and the relay refuses a `hello` with the wrong one.

- **Bump it** whenever you change anything on the wire: a new event kind or topic, a field added to,
  removed from or reordered in a snapshot or hit, a change in who owns what, or a lobby message change.
  (Example: the Mage's Hex added the `hex` event, 0.4.0 -> 0.5.0.)
- **No bump** for changes that reuse existing messages as they are (new kits that only send existing
  `fx` events, balance numbers, art).
- A release tag must equal `v<VERSION>` (`.github/workflows/release.yml` enforces it), so bump it
  before tagging a playtest build.

## The relay server

A headless copy of the game started with `-- --relay`. It keeps the lobby (who's online and their
presence), passes lobby messages to everyone and match messages to the others in the same match. The
match itself still runs on the host's PC.

Settings (environment, or `-- --relay --port=7777 --max=120`): `BOKI_PORT`, `BOKI_MAX_PLAYERS`,
`BOKI_VERSION` (the required game version; default this build's), and for access control
`BOKI_DISCORD_BOT_TOKEN`, `BOKI_GUILD_ID`, `BOKI_ALLOWED_ROLES`. With those set, every player logs in
with Discord (the launcher does it) and must hold an allowed role in the Project Boki server; without
them anyone on the right version can join (local testing). Deploy with `deploy/setup_server.sh`.

## Testing

`tests/net/net_probe.gd` and `tests/net/match_probe.gd` are probes for the relay and a match over it.
