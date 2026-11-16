# Party: friends queue into the same squad

Design only. Written 2026-11-10 against `scripts/core/net.gd` (Net.VERSION 0.24.3), `server/matchmaker/` (`mm/queue.py`, `mm/core.py`, `mm/api.py`, `mm/config.py`, `server/README.md`) and ADR 0019 (pre-match lobby). No game code changes here.

## Decisions this builds on
- Extraction is always trios, 10 teams (30 slots); humans seat first, bots fill the rest.
- "Play with friends" today is the relay lobby (`scripts/ui/lobby.gd`, `Net.set_presence` + `lobby_emit`): everyone with the game open, whoever presses Start hosts. It has no way to keep three friends in one squad on the matchmaker path.
- Clans are coming; their roster will want a one-tap invite into a party.

## What exists, what is missing
- `POST /queue` takes `"party": ["friend", ...]` = names. `assign_slots` groups tickets whose name sets are equal. Problems: names are typed by the client (collisions, spoofing), nothing makes the party enter the line together, and `TicketQueue.pick` cuts `line[:slots]`, so a party can straddle two matches (one member in each). An oversized party is split instead of refused.
- The game client has no matchmaker client at all yet (nothing in `scripts/` calls `/queue`).
- Net itself needs no new function or topic (see Net below).

## Player flow
1. Main menu: **Party** button next to Play. Disabled with "Finish the tutorial first" until the tutorial is done (see Tutorial).
2. **Make a party** shows a 5-character invite code (e.g. `K7QM2`) and a Copy button. **Join a party** takes a code. Later the clan roster gets an "Invite to party" row that hands the same code to the friend (the join call is identical; only the delivery differs).
3. Party card (up to 3): names, class, Ready tag, crown on the leader. The leader picks the mode from the modes that fit the party size (`team_size >= party size`: trio always; arena for 1-3; duel only alone). Default mode: trio. Changing mode or membership clears every Ready.
4. Everyone presses **Ready**. The leader's button then reads **Find match** (enabled when all others are ready; pressing it is the leader's ready). The party goes into the queue as one unit.
5. The queue screen is the same as the solo one (position, ETA, Cancel). When the server is ready every member gets host/port/token and connects (`Net.server_addr = host:port`, `Net.start()`, the existing native path).
6. After the match (or a cancel) the party is back on the card, not-ready, still together.

## Matchmaker changes (`server/matchmaker/`)
Parties live in matchmaker memory (like tickets). New module `mm/party.py` (~120 lines); `core.py`, `api.py`, `queue.py`, `config.py` gain a few calls.

### HTTP (all JSON; member secret in header `X-Boki-Member`, never in the URL, because `api.py` logs paths)
| Call | Body | Answer |
|---|---|---|
| `POST /party` | `{name, version}` | `{code, member}` (creator is leader) |
| `POST /party/<code>/join` | `{name, version}` | `{member}`; errors `not_found` 404, `full` 409, `busy` 409 (queued or playing), `version` 409, `rate_limited` 429 |
| `GET /party/<code>` | | `{state: forming\|queued\|playing, mode, members: [{name, ready, leader, you}], ticket?, eta_s?, position?}`; `403 not_member`, `404 gone`. This is also the heartbeat. `ticket` appears for the caller once queued; the client then polls `GET /queue/<ticket>` exactly as a solo player does |
| `POST /party/<code>/mode` | `{mode}` | leader only; mode must fit the party size |
| `POST /party/<code>/ready` | `{ready}` | any member; leader's `ready:true` with all others ready = queue |
| `DELETE /party/<code>/queue` | | leader: cancels every member ticket, back to `forming`, Ready cleared |
| `POST /party/<code>/leave` | | cancels that member's ticket too; leadership passes to the longest-standing member; empty party is deleted |

Codes: 5 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (no O/0/I/1/L), collision-checked, case-insensitive on entry. Wrong codes are rate limited: 10 per minute per client address (in-memory counter, reset by `tick`), so a code cannot be walked.

### Queue (`mm/queue.py`)
- `Ticket.party` becomes the party code string (`""` for solo); `new_ticket(..., party)` takes that string. The names list is removed from `POST /queue`/`enqueue`; solo `POST /queue` stays. Not a Net contract (HTTP only, and nothing in the tree calls it yet), so no shim.
- A party queues atomically: one ticket per member, same `created_at` (the party's queue time), so `eta_s` and the fill timeout work unchanged.
- `TicketQueue.pick` takes whole units, oldest first: a unit is a party's tickets in the line, or one solo ticket. It adds units while they fit `slots` and skips one that does not (it keeps its place for the next batch). The start rule (full line of humans, or oldest waited `fill_timeout`) is unchanged.
- `assign_slots`: party units first, largest first, each onto an empty team (a party never splits; `len(party) <= team_size` is enforced at `/party/<code>/mode` and `/ready`). Solos then fill the **fullest** team that has room, so a duo gets a stranger as third before a fresh team is opened, and fewer seats are bots. Delete `_party_groups` name grouping and `test_oversized_party_is_split_not_dropped`.
- Config: `TRIO_SLOTS` default 12 becomes 30 (10 teams). Update `config.py`, `server/README.md` and `tests/test_queue.py` (it reads `cfg.trio_slots`). `Data.MATCH_PLAYERS` (20) is the offline count and is untouched. The game server reads `slots`/`team_size` from the token file; confirm it handles 30 (that reader is not in this tree; checked in job 2).
- New config: `PARTY_MAX=3`, `PARTY_IDLE_S=20` (no poll = member dropped), `PARTY_AFTER_MATCH_S=120` (grace to come back after a match), `PARTY_BAD_CODES_PER_MIN=10`.

### State machine
`forming` -> (leader Find match, all ready) -> `queued` -> (tickets spawned, `Match` holds the party code) -> `playing` -> (`_exited`) -> `forming`. `queued` also returns to `forming` when every ticket is gone before a join (cancel, expiry). `playing` pauses the idle timer (members are in the match, not polling); at match end all `last_seen` are reset to now and the 120 s grace applies.

## Disconnect rules (defaults)
| Case | Result |
|---|---|
| Member closes the app or stops polling (20 s) while `forming` | Dropped; Ready of the rest cleared; leader passes if it was them; an empty party is deleted |
| Leader leaves while `forming` | Longest-standing member becomes leader, mode kept |
| Member leaves while `queued` | Their ticket is cancelled; the party keeps its place and queue time; their seat is a stranger or bot. Nobody is bounced back |
| Whole party leaves while `queued` | Party deleted, all tickets cancelled |
| Token handed out, member never connects (60 s `TOKEN_TTL_S`) | Their ticket expires and a bot takes the seat; the others play (existing `core.py` behaviour) |
| Member drops inside the match | The game's own disconnect rule applies; the party is not involved. No rejoin (the token is spent) |
| Matchmaker restarts | Parties are lost like tickets; a client's `404 gone` shows "Your party ended" and returns to solo |
| Member on another version | `409 version` at join/create, shown as "Update the game to play with this party" |

## Tutorial (default)
Mid-tutorial players cannot be in a party: the Party button is disabled until `Save.d["tutorial"]["home"]` is true (the flag the farm tutorial and `--skip-tutorial` set). Starting the tutorial match while in a party shows a confirm ("Leave your party to do the tutorial?") and leaves it. The alternative (a `busy` member state the leader waits on) is rejected: it lets one slow friend stall two others.

## Pre-match lobby (ADR 0019)
- Party members get tokens in one tick and land on one team, so the lobby's squad ("your roster team") is the party plus any stranger solo; chat and picks already filter to teammates. No roster or topic change: the client marks party members by matching names against its last `GET /party` answer (a crown and a "Party" tag in `PrematchView`), so strangers show without one.
- The 90 s lobby holds each member's seat; a member not connected at lock becomes a bot (existing). The lobby does not wait for the party.
- If `Settings.lobby_enabled` is off, party members just load straight in.

## Net (`scripts/core/net.gd`)
- No renamed or removed function, no new topic, `"st"/"hit"/"ev"` untouched, `--relay`/`--server=`/`--token=` untouched.
- Additions: one child node `NetMatchmaker` (`scripts/core/net_mm.gd`, an `HTTPRequest` wrapper beside `net_enet.gd`) held as `Net.mm`, plus the optional arg `--matchmaker=host:port`; when absent the host of `--server=` with port 8080. That is the only edit to `net.gd` (a var and three wiring lines). Party traffic goes over HTTP, not the relay: the relay does not know the matchmaker's queues, and presence would give no atomic queue. Considered and rejected: party state in relay presence.
- Clan invite later: it should ride the clan system's own channel; if it needs a `lobby_emit` topic (e.g. `pinv`) that is a new topic and a `Net.VERSION` bump in that job, not here.

## Net.VERSION
Nothing synced in a match changes (squad = team as before), so this spec requires **no bump by itself**. `/party` also checks `version`, so mismatched clients fail early. It ships in the next release batch; the pre-match lobby already earmarked 0.25.0 (the `VERSION` comment lists it; the constant still reads 0.24.3), so the release that carries both is 0.25.0. If job 3 chooses to add a `party` field to the roster, bump to 0.26.0 and extend the comment.

## Open questions and the defaults taken
| Question | Default |
|---|---|
| Code length and charset | 5 chars, no look-alikes |
| Duo party with a stranger third | Yes, packed; a party never splits |
| Party of 3 into `arena` (teams of 4) | Allowed, a stranger/bot takes the 4th |
| Duel for a party | Not offered (only alone) |
| Ready with a leader | Leader's Find match is their ready |
| Who may change mode | Leader only |
| Kick button | None; a member leaves themselves (adds a stall risk only for the 20 s idle timer) |
| Discord identity on parties | Not required in v1: the matchmaker has no Discord check yet. Name is display-only; the member secret is the identity |
| Party survives a match | Yes, 120 s grace then idle rules |
| Pre-tutorial friends | Blocked (above) |

## Checks
- `python3 -m unittest discover -s server/matchmaker/tests` plus `python3 server/matchmaker/matchmaker.py --selftest`. New `tests/test_party.py`: create/join/full/busy/version, code rate limit, leader pass, ready reset on change, atomic queue, a party never straddles two batches (pick), duo packs a solo, trio party = one team, leave while queued keeps place, expiry leaves a bot, play->forming on `_exited`, idle drop and the after-match grace, and `test_api` for the routes and the header (no secret in the logged path).
- `tools/party_client_check.gd` (registered in `tools/check_registry.gd`, run with `godot`): a fake HTTP layer drives `NetMatchmaker`: create, join, ready, queue, ticket poll, leave, 404 gone; and the tutorial gate (`Party.can_join()` false until `tutorial.home`).
- `python3 tools/health.py --strict` and `python3 tools/gen_wiki.py --check`. GPU shots (party card, queue) via `jobq submit --needs gpu` in job 3 only.

## Build jobs (each under 2 hours)
1. **Matchmaker party core** (server only). Files: `server/matchmaker/mm/party.py` (new), `mm/core.py` (calls, `Match` carries the party code), `mm/queue.py` (party-aware `pick`, `assign_slots`, ticket field), `mm/api.py` (routes, header, rate limit), `mm/config.py` (`TRIO_SLOTS=30`, party settings), `tests/test_party.py` (new), `tests/test_queue.py`, `tests/test_api.py`, `server/README.md`. Also confirm the game server's token reader takes `slots=30`.
2. **Client party service** (no UI). Files: `scripts/core/net_mm.gd` (new), `scripts/core/party.gd` (new, state + `can_join()`), a few wiring lines in `scripts/core/net.gd`, `tools/party_client_check.gd` (new) + `tools/check_registry.gd`. Also the queue/ticket poll (`/queue`), which no client code has yet; ready -> `Net.server_addr` + `Net.start()`.
3. **Party UI**. Files: `scripts/ui/party_view.gd` (new: card, code, copy, join box, mode picker, Ready/Find match), `scripts/ui/title.gd` (one menu row beside "Play with friends"; god-file rule: wiring only), `scripts/ui/prematch_view.gd` (crown/Party tag), the tutorial-start confirm (one call from `main.gd` wiring, a line or two), `docs/wiki` if data changed. Add a screenshot via `jobq`.

Order: 1, then 2, then 3. Clan "Invite to party" is a later job on the clan roster.
