# Project Boki game servers (stage 1)

The service side of online play: a matchmaker that holds the queues and starts one headless game
server process per match. The game server itself is the "Linux Server" export of this repo
(`--server` mode, see `docs/decisions` and the contract in the S2 briefs). This folder is ignored by
Godot (`.gdignore`) and is not part of the game export.

```
server/
  matchmaker/           Python 3 stdlib only, no pip
    matchmaker.py       the service (also --selftest)
    fake_server.py      stand-in game server for tests
    mm/                 config, queue, launcher, core, picks, api, selftest, log
    tests/              python3 -m unittest
  deploy/
    install.sh          box setup, run as root on Ubuntu 24.04 (idempotent, --dry-run)
    push.sh             rsync + install + health from your machine
```

## Ports (same as the Hetzner firewall)

| Port | Protocol | What |
|---|---|---|
| 22 | TCP | SSH (deploys) |
| 8080 | TCP | matchmaker HTTP (plain HTTP in stage 1; TLS later behind a reverse proxy) |
| 7777-7799 | UDP | one match process per port, so at most 23 matches per box |

## The HTTP API

All bodies are JSON. The client's `Net.VERSION` must equal the version the matchmaker serves.

| Call | Body | Answer |
|---|---|---|
| `GET /health` | | `{"ok": true, "version": "<Net.VERSION served>", "region": "eu", "matches": n}`. Clients time it to pick the region. |
| `POST /queue` | `{"mode": "duel\|arena\|trio", "name": "...", "version": "<client Net.VERSION>"}` | `200 {"ticket": "<id>"}`; `409 {"error": "version", "server_version": "..."}`; `400 {"error": "mode"}` or `{"error": "bad_request"}` |
| `GET /queue/<ticket>` | | `{"state": "waiting", "position": n, "eta_s": n}` while queued or while the server boots; `{"state": "ready", "host": "<PUBLIC_HOST>", "port": N, "token": "<one-time>"}`; `{"state": "gone"}` |
| `DELETE /queue/<ticket>` | | `{"state": "gone"}` (leaves the queue; a ticket that already has a match leaves its slot to a bot) |
| `POST /queue/<ticket>/pick` | `{"hunter": "<Hunter id>"}` (`""` only reads) | `200 {"ok": true, "picks": {"phase": "loading\|picking\|done", "loaded": n, "of": N, "teams": [{"order", "picking", "left_s", "picks"}]}}`; `409 {"error": "loading\|turn\|taken"}`; `400 {"error": "unknown"}`; `404 {"error": "no_match"}`. Works after the token is spent: picking waits until every human slot joined (or 60 s), then each team picks in turn, 10 s each, one of each Hunter per team (mm/picks.py) |

Queues: duel is 1v1 (2 slots), arena 4v4 (8 slots), trio is extraction in teams of 3 (`TRIO_SLOTS`,
default 18: 6 teams). A match starts as soon as the line holds a full match of humans, or when the oldest
ticket has waited the fill timeout (20 s duel and trio, 30 s arena); bots fill the rest, at least one
human is in. The line is taken in whole units, oldest first: one solo ticket or a party's tickets
together. A unit that does not fit keeps its place for the next batch. Seats are handed out parties
first (largest first, each on an empty team, so a party never splits), then solos fill the fullest team
with room, so a duo gets a stranger as third before a new team opens.

### Parties

Friends queue as one unit. Parties live in memory (a restart ends them; clients see `404 gone`). The
member secret returned by create/join goes in the `X-Boki-Member` header of every later call, never in the
URL (the access log records paths). Codes are 5 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, case-insensitive.

| Call | Body | Answer |
|---|---|---|
| `POST /party` | `{"name", "version"}` | `{"code", "member"}`; the creator is the leader; `409 version` |
| `POST /party/<code>/join` | `{"name", "version"}` | `{"member"}`; `404 not_found`, `409 full`, `409 busy` (queued or playing), `409 version`, `429 rate_limited` |
| `GET /party/<code>` | | `{"state": "forming\|queued\|playing", "mode", "members": [{"name", "ready", "leader", "you"}], "ticket"?, "position"?, "eta_s"?}`; `403 not_member`, `404 gone`. This is the heartbeat: poll it every few seconds, also while queued. `ticket` appears once queued (poll `GET /queue/<ticket>` as a solo player does) |
| `POST /party/<code>/mode` | `{"mode"}` | leader only (`403 not_leader`); the mode's `team_size` must be at least the party size (`400 mode`); clears every Ready |
| `POST /party/<code>/ready` | `{"ready": bool}` | any member. The leader's `true` is Find match: with every other member ready it queues the party (`{"state": "queued"}`), else `409 not_ready`. `409 busy` unless forming |
| `DELETE /party/<code>/queue` | | leader: cancels every ticket, back to `forming`, Ready cleared; `409 busy` while playing |
| `POST /party/<code>/leave` | | cancels that member's ticket; leadership passes to the longest-standing member; an empty party is deleted |

State: `forming` -> (Find match) `queued` (one ticket per member, same queue time) -> `playing` (a server
holds the tickets) -> `forming` when the server exits. A member who leaves while queued gives their seat
to a stranger or bot; the party keeps its place. Members who do not poll for `PARTY_IDLE_S` are dropped
(not while `playing`; after a match the party has `PARTY_AFTER_MATCH_S` to come back). More than
`PARTY_BAD_CODES_PER_MIN` wrong codes or secrets from one address in a minute answer `429 rate_limited`.

The `ready` answer repeats on every poll for the same ticket until the token is spent or expires: the
game server reports `BOKI_SERVER joined slot=<i>` when the token is used, and the ticket answers `gone`
from then on. A token nobody uses expires 60 s after `ready` (`TOKEN_TTL_S`), and the ticket goes `gone`.

## What the matchmaker expects of the game server

It runs `SERVER_CMD --server --port <N> --mode duel|arena|trio --match-id <id> --tokens-file <path>`
with stdout piped, and:

- waits for `BOKI_SERVER ready port=<N>` on stdout (`READY_TIMEOUT_S`, default 30 s; a server that
  stays silent is killed and the tickets are re-queued, once);
- reads `BOKI_SERVER joined slot=<i>` (marks that ticket's token spent) and `BOKI_SERVER end result=...`
  (logged); every other stdout line is logged as `server_out`;
- on exit, frees the port and deletes the tokens file. Exit before `ready` counts as a crash: the
  tickets go back to the front of the line and get a second server; a second crash drops them (`gone`).
- The tokens file is `{"tokens": {"<token>": {"name": "...", "slot": 0, "team": 0}}, "match_id": "...",
  "mode": "...", "slots": 8, "team_size": 4, "expires": <unix time>}`. The server needs only `tokens`;
  `slot` is team-major (slots 0..team_size-1 are team 0). The extra keys are informational.
- **Version:** at startup the matchmaker runs `SERVER_CMD --version` and takes the first stdout line
  matching `version=<v>` (the expected form is `BOKI_SERVER version=<Net.VERSION>`) or a bare `x.y.z`.
  If the build doesn't answer that, set `SERVER_VERSION` in the env file instead; with neither, the
  service refuses to start. Clients whose `version` differs are refused with `409 {"error": "version"}`.
- Only `ready`, `joined` and `end` status lines are parsed; `--seed` is never passed.

## Settings (`/etc/boki/matchmaker.env`, overridden by the environment)

| Key | Default | Meaning |
|---|---|---|
| `REGION` | `dev` | reported by `/health` |
| `PUBLIC_HOST` | `127.0.0.1` | the address handed to clients |
| `HTTP_HOST`, `HTTP_PORT` | `0.0.0.0`, `8080` | where the API listens |
| `SERVER_CMD` | (required) | the game server command prefix, e.g. `/opt/boki/server/ProjectBoki.x86_64 --headless --` |
| `SERVER_VERSION` | probe | the build's Net.VERSION when `--version` isn't supported |
| `PORT_MIN`, `PORT_MAX` | `7777`, `7799` | UDP match ports |
| `FILL_TIMEOUT_DUEL`, `_ARENA`, `_TRIO` | `20`, `30`, `20` | seconds before bots fill a match |
| `TRIO_SLOTS` | `18` | players per extraction match (6 trios: the 2x Hollow Crown, capped at 30 hunters) |
| `PARTY_MAX`, `PARTY_IDLE_S` | `3`, `20` | members in a party; seconds without a poll before a member is dropped |
| `PARTY_AFTER_MATCH_S`, `PARTY_BAD_CODES_PER_MIN` | `120`, `10` | grace to return after a match; wrong codes per minute per address |
| `TOKEN_TTL_S` | `60` | an unused token's lifetime |
| `READY_TIMEOUT_S` | `30` | how long a server may take to print `ready` |
| `TOKENS_DIR` | `/run/boki` | where tokens files are written (0600) |

## Run it locally

With a Godot checkout (needs the "Linux Server" preset's `--server` mode on this branch, from
`ext/servers`):

```sh
SERVER_CMD="godot --headless --path $PWD --" PUBLIC_HOST=127.0.0.1 TOKENS_DIR=/tmp/boki-tokens \
  python3 server/matchmaker/matchmaker.py --env-file /dev/null
curl -s localhost:8080/health
```

If the build has no `--version` yet, add `SERVER_VERSION=$(grep -oP 'const VERSION := "\K[^"]+' scripts/core/net.gd)`.

Without Godot:

```sh
python3 server/matchmaker/matchmaker.py --selftest       # the real service against fake_server.py, ~10 s
python3 -m unittest discover -s server/matchmaker/tests   # queue rules, core, launcher, API, deploy scripts, ~2 s
```

Both are stdlib only and are the check for this folder (there is no Godot-side check for the matchmaker;
the end-to-end `--server-e2e-check` on ext/servers drives the real server through it).

## Deploy

One box per region (owner-created in the Hetzner console: Ubuntu 24.04, firewall TCP 22, TCP 8080,
UDP 7777-7799, S2's deploy key). From your machine, with `~/.ssh/boki_s2_deploy`:

```sh
# 1. export the server build outside the repo (or download the release workflow's
#    "ProjectBoki-linux-server-<tag>" artifact: its build/ folder is this, next to a copy of server/)
godot --headless --path . --export-release "Linux Server" ../build/server/ProjectBoki.x86_64
# 2. push: rsync matchmaker + build + install.sh, run install.sh on the box, curl /health
server/deploy/push.sh <host> eu ../build/server
```

`install.sh` is idempotent: it creates the `boki` user, `/opt/boki/{server,matchmaker}`, writes
`/etc/boki/matchmaker.env` once (then only updates REGION, PUBLIC_HOST and SERVER_CMD from what it finds),
installs `boki-matchmaker.service` (Restart=always, runs as `boki`, journald, `/run/boki` for tokens),
sets the ufw rules and restarts the service. Run `install.sh --dry-run` anywhere to see what it would do.

**Update:** run the same `push.sh` again (with or without a build dir). Matches in progress die with
the restart (stage 1: deploy when the queues are empty). Edit `/etc/boki/matchmaker.env` by hand for other
settings, then `systemctl restart boki-matchmaker`.

**Logs:** `journalctl -u boki-matchmaker -f`. One line per event, `key=value`: `queue_join`, `match_start`
(humans/bots), `match_ready`, `player_joined`, `ticket_gone why=joined|expired|cancelled|crashed|match_over`,
`server_exit code=`, `ports_exhausted`, `server_ready_timeout`, `http` (every request), and `server_out`
for the game server's own stdout.

**Secrets:** none in the repo. The env file lives only on the box; the deploy key only on S2's machine.
