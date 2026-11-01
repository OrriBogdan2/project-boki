# Project Boki roadmap

Status: **plan**, nothing here is built yet. The owner approved building all of it ("everything but
controller support should be built"). This document plans seven workstreams and fits them, together
with the work already planned (kin grammar Phases 2-6, the archetype build, the 150-Boki roster
pipeline, boss lair exits, character art), into one order that can be scheduled.

1. [Real multiplayer](#1-real-multiplayer)
2. [Meta loop and economy](#2-meta-loop-and-economy)
3. [Maps](#3-maps)
4. [Onboarding: the first hour](#4-onboarding-the-first-hour)
5. [Audio](#5-audio)
6. [Telemetry and crash reports](#6-telemetry-and-crash-reports)
7. [Collectible Boki: editions, trading, crossover](#7-collectible-boki-editions-trading-crossover)
8. [The order](#8-the-order)
9. [Biggest risks](#9-biggest-risks)
10. [Decisions the owner needs to make](#10-decisions-the-owner-needs-to-make)

**Conventions.**

- **Boki** is the player-facing name for what the code and older docs call kin. Code identifiers
  (`Kin`, `content/kin_v2`, `KinSpec`, `Save.d["roster"]`) stay as they are until the grammar's
  format freeze (Phase 6, §8), so this plan doesn't add a rename to every other change.
- **Effort** is in rough dev-weeks: one focused developer, or the equivalent run of agent build
  sessions with an owner check-in after each milestone. Treat them as ±50%.
- **Ships on its own** means a milestone merges to `main`, passes the whole headless check suite,
  and leaves the game playable without the next milestone.
- **Tests** follow the existing pattern: `godot --headless --path . -- --<name>-check` prints
  `PASS`/`FAIL` lines and exits non-zero on failure (see `scripts/main.gd`, `tools/*_check.gd`).

---

## 0.5 Owner priority (Oct 31): a small closed playtest first

Owner: "the main thing is getting the game to work with a small amount of people - we don't need to build it
for thousands of people off the bat. I want to trial it with ex-SUPERVIVE players first."

This overrides the scale-first parts of the order below. The first online target is the **Playtest MVP**:
- **Size (owner update):** 20-40 real players per match (e.g. 10 squads of 3-4), bots only to fill gaps.
  Up to ~100 testers online at once, so 2-3 matches running at the same time. One map (Skyreach), one region.
- **Hosting:** dedicated headless Godot servers (same project) on one or two VMs, several match processes per
  VM; a tiny lobby/queue service that fills matches and hands out the server address; invite codes for
  the closed test. No regions, no global matchmaking, no autoscaling.
- **Server performance is now a real constraint:** 40 hunters + Boki + mobs + bosses at a fixed 30 Hz tick on
  one core per match. Needs: interest management (each client only receives what's near it / in its vision),
  delta-compressed snapshots, budgeted mob AI and shot processing (today's measured 4-5 ms mob AI and up to
  ~5 ms shots per step must hold at 40 players), and a load test with 40 simulated clients before the
  first session.
- **Authority:** server-authoritative simulation (so results are consistent), but light anti-cheat:
  testers are invited. Client prediction for your own movement and lag compensation for shots, because
  ex-SUPERVIVE players will feel input lag immediately.
- **Saves:** a separate "playtest profile" that the server hands out at start (fixed kits/Boki per tester or a
  quick draft), so nothing touches the future economy. No accounts or cloud saves yet: a tester name + code.
- **Feedback:** opt-in telemetry + crash reports from day one, an in-game "report" key that captures a clip
  of the last seconds and match state, and a short post-match survey. Discord for voice and community.
- **Distribution:** a private build (itch.io restricted page or Steam Playtest later), auto-update optional.
- **Deferred until after the playtest proves the fun:** accounts, cloud saves, matchmaking, multiple regions,
  marketplace/trading, editions, season track, anti-cheat hardening.
Order: in-flight branches -> archetypes (the combat identity testers will judge) -> Playtest MVP netcode ->
first closed playtest -> iterate on feedback -> then the rest of this roadmap.

## 0. Where the code is today

What this plan builds on. Paths are on `main` unless a branch is named.

| System | Code | State |
|---|---|---|
| Match simulation | `scripts/match/match.gd` (5.4k lines), `hunter.gd`, `kin.gd`, `mob.gd`, `boss.gd`, `ent.gd` | Custom tile-grid movement (no Godot physics), variable timestep in `_process` (`d = min(delta, 0.1)`), seeded `rng`. `--simtest` already runs a whole match headless on autopilot, which proves the sim can run without a screen |
| Input | `Match._gather_input()` writes `player.inp` (move, aim, aim_y, fire, glide, dash_hold, sec_hold, interact, ...) | Already a command dictionary: the natural client-to-server input packet |
| Networking | `scripts/core/net.gd`, `# online` section of `match.gd` (`net_snapshot`, `_ser`, `_net_apply`, `net_send_hit`, `_net_ev`), `scripts/ui/lobby.gd`, `tools/shell.html` | **Web only**, over the JS bridge (artifact room or BroadcastChannel). Each client owns its own hunter and Boki; the host owns mobs, bots, loot and wild Boki. JSON snapshots at 10 Hz (own) and ~6.7 Hz (host world) in 4 KB chunks. Hits on something you don't own are sent to its owner. Event types: knock, out, up, ext, xc (exits), emo, sping, lead, dsep, spill, fx. `drop_squad.gd`, `truce.gd`, `exits.gd` have `net_on` paths. Desktop builds have no networking at all. Nothing is validated: any client can claim any hit, extraction or pickup |
| Hit-pause | `Match.freeze_frame()`, `hitstop` | Global, **skipped when `net_on`**. `Ent.freeze_t` already exists as a per-entity visual hit-pause |
| Persistence | `scripts/core/save.gd` | Local JSON in `user://`, 6 slots, `VERSION := 1`. `load_game()` **ignores any file whose version isn't exactly 1**, so bumping the version today would silently wipe saves. Boki `uid` is `"k" + usec % 1e6 + randi % 1000` (not globally unique). Bred Boki store `parents` as **names** (`care.gd:344`) |
| Shared places | `scripts/core/social.gd`, `scripts/social/town.gd` | Web-only shared store: island visits, town market, guilds. Untrusted reads cleaned by `Social.clean_*` |
| Economy | `econ.gd`, `loot.gd`, `ransom.gd`, `progress.gd`, `data.gd` (`TIERS`, `BUILDINGS`, `ISLES`, prices), `home_econ.gd`, `--economy-check` | One currency (gems) plus scrap. Challenges 40-300 gems, buildings 40-220, isles 100-220, armory/pack upgrades 100-450 + scrap, Boki revive 60 + 10/level, outfits 25-80. Tier loot ×1 / ×1.75 / ×2.75. Death spills carried gems (the Vault keeps a third) |
| Home | `home.gd` (4.9k lines), `home_build.gd`, `home_work.gd` + `core/work.gd` (jobs), `care.gd`, `kinbox.gd` (Boki Burrow), `evo.gd`, `mutations.gd`, `shiny.gd` | Rich. **Branch `ivs`**: IVs (Health, Power, Speed, Work, Bond, 0-31), the Nesting Nook and the Incubator for Rare Eggs |
| Boki grammar | `scripts/kin/*`, `content/*_v2/`, `--grammar-check` | Phase 1 on `main`. **Branch `grammar2`**: Phase 2 runtime (`KinLib`, `KinExec`, `KinRules` with tier `LEVEL_CAP` 15/25/35%, `KinRunner`, `KinMerge`, `KinText`), `--grammar-runtime-check` |
| Archetypes | `docs/ARCHETYPES.md`, `docs/DASHES_AND_ABILITY_FEEL.md` (branch `design`) | Designed, not built. **Branch `chars2`**: six archetype silhouettes and the HeroKit sculpting kit |
| Maps | `tools/make_skyreach.py` → `content/maps/skyreach.json`; `World.load_layout`, `World.layout_for_tier()` (always `"skyreach"`), `spawn_plan.gd`, `biome_run.gd` + `content/biomes/*.json` (6 biomes), `landmarks.gd`, `lairs.gd`, `sky_train.gd`, `exits.gd`, `tutorial.json` | One authored map (216×216 tiles, 17 islands, 3 lairs, 4 docks, 3 outposts, 6 hatches, train). A procedural generator also exists (`--mapcheck` on 200 seeds). **Branch `lairexit`**: 90 s lair seal, post-kill lever, escape updraft, outside alerts, bot choices (`--boss-check`) |
| Onboarding | `ui/prologue.gd`, `ui/hatch.gd`, `tutorial.json` (`--tutorial`, `--tut-test`), `home_training.gd`, `Progress.DAY1`, `Match._tips()`, `Progress.SHOP_REQ`, `TIERS[i].unlock` | Gates are scattered across four places |
| Audio | `tools/gen_sfx.py`, `gen_train_sfx.py`, `core/synth.gd`, `core/sfx.gd` (distance muffle bus, compressor, reverb, limiter, MIN_GAP/STACK), `tools/compose.py` (GeneralUser GS), `tools/gen_music.py`, `tools/sfx_stats.py` | All synthesized or composed, nothing sourced. 11 music tracks, 3 ambience beds. Music switching lives in `home.gd` and `Sfx.music_lock` |
| Telemetry, crashes | — | None. `Progress` keeps lifetime stats on the save; branch `perf` has an on-screen perf probe |

Other in-flight branches not yet on `main`: `names2`, `perf`, `integ13`. Two older docs describe a
parallel prototype (`DEATH_AND_REVIVE.md` and `KINFALL_CLASSES.md` mention `data/*.tres`, `life.gd`
paths and `HunterController` under `scripts/feel/`); their rules match the live game but their file
references have drifted. Fix them during the Wave 0 merge.

---

## 1. Real multiplayer

### Goals

- 20-player PvPvE matches (solo, duo, trio) on **dedicated servers** for desktop (Windows, macOS).
- The server is the authority on everything that persists or decides a fight, because the client is
  open source and must be assumed hostile.
- Everything that exists today syncs: hunters, Boki (shoulder, perch, mount, thrown, merged, wild,
  dazed), bosses and lairs, drops and pickups, truces, hatches and rift keys, skiff docks and
  outposts, deathboxes and beacons, the sky train, events (meteors, Glimmerkin, Warden), fields,
  walls, traps and tethers, the skydrop, pings and emotes.
- Shooting feels local at 30-120 ms: your own movement is predicted, your hits are lag-compensated.
- Accounts and cloud saves, parties, matchmaking, private lobbies for Discord events.

### Design

**Authority model.**

| Thing | Authority | Client does |
|---|---|---|
| Your hunter's movement (walk, dash, jump, glide, mantle, wall kick) | server simulates from your inputs | predicts and reconciles |
| Ability casts, cooldowns, run level, skill points | server | plays the tell and sound at once (cosmetic), shows the result when confirmed |
| Damage, CC, knocks, deaths, revives | server | shows predicted hit markers only for its own shots; server confirms |
| Projectiles | server spawns at the shooter's fire time (rewound) | draws its own shot immediately (today's `"cos": true` cosmetic shots) |
| Boki (yours and wild), mobs, bosses, bots | server | interpolates ~100 ms behind |
| Loot, pickups, deathbox contents, backpack, catches | server, item ids minted by the server | sends "take item X" requests |
| Lair dial lock | server validates each press against the needle phase at the client's timestamp, with an RTT tolerance window (≤ 120 ms) | runs the dial locally for feel |
| Truces, exits, beacons, train clock, events | server | interpolates, plays effects |
| Results (XP, gems, Boki changes) | server posts them to the account service | displays |

**Server types.**

- **Dedicated servers** run every matchmade match and every match that can change persistent state.
  One headless Godot process per match (dedicated-server export, visuals stripped).
- **Listen servers** (host-and-play in one process) only for private lobbies with persistence off
  (practice, custom rules, community content testing). The same server code runs in-process, so
  this costs little.
- The web build and `core/net.gd` are retired after milestone N2 (the owner said the web version is
  only for prototyping). Shared places (`social.gd`) move to the account service in N4.

**Transport and protocol.**

- Godot's `ENetMultiplayerPeer` (UDP) with three channels: unreliable state, reliable-ordered
  events, reliable inputs-ack. Use raw packets (`SceneMultiplayer.send_bytes`), not
  `MultiplayerSynchronizer`: the match is built on `Ent` objects in a custom loop, not replicated
  scene nodes.
- Binary, quantized snapshots (`StreamPeerBuffer`): positions to 1 cm within the 216-tile map,
  angles to 1 byte, health to 0.1. **Delta-compressed** against the client's last acknowledged
  snapshot.
- Sim tick **30 Hz**, snapshots **20 Hz**, client input packets at 30 Hz carrying the last 3 inputs
  (loss cover).
- **Interest management**: each client only receives entities within its squad's shared sight plus
  a margin (World already computes sight cones, walls and grass). Hidden rivals aren't sent at all,
  which is also the main defence against wallhacks in an open-source client.
- Bandwidth estimate: ~60 visible entities × ~20 bytes × 20 Hz ≈ 24 KB/s down per client,
  ~0.5 MB/s out per 20-player server. Inputs ≈ 3 KB/s up.

**Latency handling.**

- **Prediction and reconciliation** for your hunter: inputs carry a sequence number; the server
  returns the last processed sequence with your authoritative state; the client rewinds and replays
  unacknowledged inputs. This needs movement to be a pure function of (state, input, dt, World), so
  N0 pulls it out of `hunter.gd` into a `HunterMove` step function.
- **Interpolation** for everyone else at 100 ms (two snapshots), extrapolation capped at 150 ms.
  `Ent.net_pos`/`net_vel` already exist.
- **Lag compensation**: the server keeps a 1 s ring buffer of every hunter's and Boki's hitbox
  position. Hitscan and melee are checked against positions rewound to the shooter's view time,
  capped at **200 ms** of rewind (past that, the shooter has to lead). Travelling shots (sniper at
  32 m/s, shotgun slugs) spawn server-side at the rewound fire position and then fly in real time, so
  they stay dodgeable. Dodges with invulnerable frames are checked on the target's own timeline
  (a perfect dodge on your screen counts), which is the usual favour-the-defender exception.
- **Hit-pause online** (DASHES §5.4): the server never pauses. Clients apply per-entity visual
  freezes (`Ent.freeze_t`) only to the attacker and target, only on those two players' clients (50%
  for the Boki owner), while hurtboxes keep updating. The global `freeze_frame` stays offline-only.

**Persistence.**

- Account service: **Nakama** (open source, Apache-2.0, Go + Postgres/CockroachDB) with the
  `nakama-godot` client (Apache-2.0). It gives accounts (email, device, Steam, Discord via custom
  auth), friends, parties, matchmaker, storage objects, leaderboards and server-side modules for
  authoritative logic. Apache-2.0 is GPL-3.0 compatible.
- **Two kinds of state.** Hard state (Boki identity and ownership, items, gems, account XP, Bokidex,
  season progress) lives only on the server and changes only through server modules or game-server
  results. Soft state (farm layout, decor, care needs, memories, chat with Boki) is cloud-saved but
  may be client-written, because it can't be traded or carried into PvP.
- **Economy ledger.** Every gem or item mint and burn is a ledger row with a source id
  (`extract`, `stall_sale`, `challenge:first_out`, `build:workshop`...). Home actions that mint gems
  (selling crops at the stall) become RPCs validated against server-known timestamps (planted at,
  watered at, 90 s per stage). The rules come from the same data (`Data`, `content/`) through an
  export tool, and a shared test-vector file keeps the Godot and server implementations from
  drifting (§2 E6).
- **Offline single player stays.** Local saves keep working exactly as today, as a separate realm.
  Nothing from an offline save becomes tradable online (see §7 for the one-time import).

**Matchmaking, parties, lobbies.**

- Parties (squads of 1-3) through Nakama parties; invite by friend list or code; party leader queues.
- Queue keys: mode (solo/duo/trio), tier, region, and **squad power bracket** (§7d). Hidden skill
  rating is used only to tune bot difficulty and to avoid pairing brand-new squads with veterans.
- Bots backfill empty seats after 60 s (bots exist and fight, loot, revive and extract), so a match
  always starts at 20 hunters even with a small population.
- Launch with **trios + duos** only and turn solos on when queues allow (DEATH_AND_REVIVE.md
  already recommends this).
- Private lobbies by code for Discord events, with persistence on (dedicated) or off (listen).
- Allocator: a small service that keeps warm server processes per region and hands one to the
  matchmaker. Start with two regions (NA-East, EU-West) on fixed VMs; move to a fleet manager
  (Agones, Edgegap or similar) only when concurrency needs it.

**Anti-cheat (what an open-source client allows).**

- Server simulation makes speed, teleport, cooldown, damage and infinite-glide hacks impossible.
- Interest management stops ESP for anything outside your squad's sight.
- Items have server ids and move only by server transactions, so duplication is a server bug, not a
  client exploit.
- Admin tools (F1, mod mode, `Game.god`) are ignored by servers and stripped from release builds.
- Content hash check: the server's content set must match the client's (community content only in
  private listen lobbies until accepted).
- Aimbots and triggerbots can't be prevented in an open client. Detect them statistically from
  server telemetry (§6 T3: hit rate by range, reaction time to reveal, flick distribution), plus
  reports and server-side replays. Bans are account-level.

### Technical plan

New folder `scripts/net/`:

| File | Job |
|---|---|
| `net_proto.gd` | message ids, binary encode/decode per entity kind (`h`, `k`, `m`, boss, pickup, field, wall, trap, tether, shot, deathbox, beacon, exit, lair, events), quantization, delta against a baseline |
| `net_link.gd` | the transport interface, with `EnetLink` and `LoopbackLink` (in-process, with configurable latency, jitter and loss for tests) |
| `net_server.gd` | accepts clients, owns the `Match` in server mode, reads input queues, runs the 30 Hz tick, builds per-client snapshots with interest culling, keeps the lag-comp history |
| `net_client.gd` | sends inputs, applies snapshots, runs prediction and reconciliation, interpolation buffers |
| `interest.gd` | per-squad visibility from World sight queries |
| `lagcomp.gd` | hitbox ring buffer and rewind queries |
| `account.gd` | Nakama session, cloud save sync, RPC wrappers (N4) |
| `matchmaker.gd` | parties, queue, ticket handling (N5) |

Changes to existing code:

- `match.gd`: a `mode` of `offline | server | client`. In client mode the sim doesn't run world
  logic, only prediction for the local hunter. The `# online` section is replaced by calls into
  `scripts/net/`. Every `if m.net_on and not m.is_host` in `exits.gd`, `truce.gd`, `drop_squad.gd`
  becomes "server decides, clients receive events".
- `Match._process` → fixed-step accumulator at 30 Hz with render interpolation (`Ent.prev` exists).
- `hunter.gd`: movement extracted into `HunterMove.step(state, inp, dt, world)`; abilities split
  into "request" (client) and "resolve" (server).
- `life.gd`, `pack.gd`, `exits.gd`, `lairs.gd`, `boss.gd`, `truce.gd`, `sky_train.gd` (already
  clock-driven: sync the clock only), `combat/fields.gd`, `combat/verbs.gd`, `kin/kin_exec.gd`
  (grammar2): every state change goes through a server-side function that also emits a reliable
  event for clients.
- `Ent.hurt()`: server-only in online modes; clients receive `hit` events for hit markers, numbers,
  sounds and `freeze_t`.
- `scripts/ui/lobby.gd` → party and queue screens (UI_DESIGN shell); results come from the server.
- Export preset "Linux Server" (dedicated server mode) in `export_presets.cfg`.

### Milestones

| # | Milestone | Ships as | Effort |
|---|---|---|---|
| N0 | **Net-readiness.** 30 Hz fixed tick, `HunterMove` step function, sim runs with no models (`--simtest --no-view`), one seeded RNG per match, input commands with sequence numbers | offline game unchanged, measurably same feel (`feel_sim` numbers) | 2-3 |
| N1 | **Protocol and loopback.** `net_proto`, `LoopbackLink`, a server and a client `Match` in one process | headless checks only | 2 |
| N2 | **Dedicated server MVP.** ENet, connect by IP, server runs bots and world, every listed system synced, no prediction yet (own hunter interpolated at low latency). Retire `core/net.gd` and the web lobby | Discord LAN/IP playtests | 5-6 |
| N3 | **Feel online.** Prediction and reconciliation, lag compensation, cosmetic cast tells, per-entity hit-pause, interpolation tuning | playable at 120 ms | 3-4 |
| N4 | **Accounts and cloud saves.** Nakama deploy, sign-in, soft-state cloud save, hard-state tables (Boki, items, gems, XP), server posts match results, ledger | online profile separate from offline saves | 3 |
| N5 | **Parties, matchmaking, lobbies.** Squads, queues per mode/tier/region/power bracket, bot backfill, private codes, allocator | public queues | 2-3 |
| N6 | **Persistent stakes online.** Boki-risk tiers (Dusk Isles, Hollow) on dedicated servers only, server-authoritative loot transfer, Ransom House and rival offers between real accounts, replay logs, reports and bans | full extraction loop online | 2-3 |
| N7 | **Scale and operations.** 20-client load test, server tick budget, second region, deploy scripts, monitoring, incident runbook | launch readiness | 2 |

Total: **21-26 dev-weeks**.

### Tests

- `--net-proto-check`: round-trip every entity kind and event; fuzz 10,000 malformed packets
  (truncated, wrong ids, huge counts) with no crash and no state change.
- `--net-loopback-check`: server + client in one process at 0 / 80 / 200 ms and 2% loss; a scripted
  route (walk, dash, jump, glide across a gap, mantle) ends within 5 cm of the server; no correction
  bigger than 0.3 m at 80 ms.
- `--net-sync-check`: scripted scenarios on loopback (boss fight with phases, lair dial and seal,
  deathbox revive and smart loot, truce accept, skiff boarding, train ride, Boki capture in the
  Hollow); a hash of every client-observable field matches the server at the end of each.
- `--lagcomp-check`: a target dodges 100 ms after the shot on the shooter's screen; at 150 ms the
  hit counts, at 250 ms it doesn't (past the cap).
- `--simtest --server --bot-clients=19`: headless server plus 19 headless bot clients for a full
  match; prints tick time p50/p99 and bytes per client per second. Budget: p99 tick under 20 ms on
  one core, under 40 KB/s per client.
- Soak: 100 back-to-back server matches without a leak (memory flat within 5%).

### Risks

- **Retrofit cost.** `match.gd` and `hunter.gd` mix simulation, presentation and input. N0 is the
  make-or-break refactor; if it slips, everything online slips. Keep every N0 step behind the
  existing offline checks.
- **Every new feature adds synced state.** From N1 on, each feature PR includes its net schema and a
  `--net-sync-check` scenario (a checklist in CONTRIBUTING.md).
- **Server cost** for a free, open-source game: 20-player servers at roughly one core per match.
  Measure in N2, then decide the subscription's timing (§10).
- **Small population** splits across modes, tiers, maps and regions. Bots and queue consolidation
  are the answer; don't open more queues than concurrency supports.
- **GPL and proprietary SDKs.** Steamworks (through GodotSteam) can't be linked into a GPL-only
  binary without a linking exception from every copyright holder. Add a GPL exception for platform
  SDKs to the license and a contributor agreement **before** outside contributions grow (Wave 0).

---

## 2. Meta loop and economy

### Goals

- **One ladder** a player can name: their **Hunter Rank** (account level). Everything else feeds it.
- Side tracks that each mean something: archetype mastery, Bokidex completion (~150 Boki at launch),
  a free seasonal track.
- Gems with clear sources and sinks, steady-state balanced, and a death-loss rule per tier that
  makes "what you risk vs what you bring home" legible.
- Home progression (incubator, jobs, buildings, breeding) tied into the ladder.
- Nothing sold for money gives power: the planned subscription is cosmetic and convenience-light
  (see §10), never Boki, gems, XP boosts or editions.

### Design

**The ladder.**

| Track | Range | Fed by | Rewards |
|---|---|---|---|
| **Hunter Rank** | 1-50, then prestige stars | all match XP + track milestones | unlocks (§4), home buildings and isles, incubator and nook slots, Boki Burrow pages, titles, secure-pouch upgrade |
| Archetype mastery | 1-10 per archetype (6) | match XP earned while playing that archetype | colourways, emotes, mastery badge on the nameplate, an alternate RMB *visual* at 10. Never stats |
| Bokidex | 150 species × 5 marks (seen, caught, raised, evolved, shimmer) | catching, hatching, raising | milestone rewards at 10/25/50/75/100/125/150 caught; regional dex per map |
| Season track | 60 tiers per 10-week season | match XP + 3 dailies + 5 weeklies | cosmetics, glider skins, decor, Boki outfits, a season edition marker (§7) |

**Match XP** (never lost: it's what you learned; gems and items are what you risk):

| Source | XP |
|---|---|
| Time alive | 1 per second (max 360) |
| Extracted | +150 |
| Monster defeated | +5 (cap 100 per match) |
| Hunter knocked | +25 |
| Boss killed (participation) | +200 |
| Boki caught and extracted | +50 |
| First extract of the day | +300 |

A typical Meadow match gives ~250 XP on death and ~450 on extract.

**Hunter Rank curve:** XP to next rank = 1,000 + 100 × (rank − 1). Total to 50 ≈ 166,600 XP ≈ 450
matches ≈ 75-90 hours including home time. Ranks 1-10 come fast (~6 hours) because that's where the
unlocks are.

**Archetype mastery curve:** 500 × level XP per level, 27,500 total ≈ 70 matches per archetype.

**Bokidex launch roster (150):**

| Rarity | Species | Where | Expected first catch |
|---|---|---|---|
| Common | 60 | every map, 2-3 biomes each | first 5 hours |
| Uncommon | 40 | 1-2 biomes, more in Dusk Isles | 5-20 hours |
| Rare | 26 | rare spawn points, mostly Dusk Isles and Hollow | 20-60 hours |
| Epic | 12 | Hollow, night events, map-exclusive | 60+ hours |
| Legendary | 12 | boss eggs (3 lairs × 4 maps) | per boss kill and extract |

About 25 species are map-exclusive so every map matters. Every species stays obtainable in an
uncapped form (§7b), so dex completion is never blocked by supply.

**Gem sources (faucets), steady state for a regular player (~10 h/week):**

| Source | Today | Proposed |
|---|---|---|
| Carried gems on extract | mobs 2-40, meteors, Glimmerkin, chests | Meadow median ~80, ×1.75 Dusk, ×2.75 Hollow (existing tier loot multipliers) |
| Selling crops at the stall | seed prices 8-60 | profit ~15-40 per crop cycle; server-validated (N4); daily soft cap 400 |
| Selling found weapons and gloves | `WEAPON_VALUE` 4-90, `GLOVE_VALUE` 3-70 | unchanged |
| Challenges | 40-300 once | plus dailies 3 × 40, weeklies 5 × 150 |
| First extract of the day | — | +50 |

Target income: ~550-650 gems per hour of mixed play.

**Gem sinks:**

| Sink | Today | Proposed |
|---|---|---|
| Buildings, isles | 40-220 | keep; add a tier-2 version of each (300-600) gated by rank 15-30 |
| Armory and backpack upgrades | 100-450 + scrap | keep |
| Soul Shrine revive | 60 + 10/level | keep |
| Ransom House buy-back | haggled | 40 + 15 × level + rarity bonus (common 0, rare 80, epic 200, legendary 400); haggle floor 70% |
| Outfits, decor | 25-80 | keep; add premium decor 150-500 (earned, not bought) |
| Breeding fee (new) | — | 50 × generation, +2 per IV point above 90 total |
| Incubator fuel (new) | — | 30 per Rare Egg to halve its hatch time (optional) |
| Loadout insurance (new) | — | 20% of the weapon's value to return it on death in Dusk Isles |
| Market fees (§7) | — | 5% listing + 5% sale tax: the main late-game sink |
| Guild projects | exist (Hall, Forge, Kin Shrine, Lighthouse) | keep as the community sink |

Target: sinks absorb 90-100% of faucets at rank 20+, measured by §6 dashboards and retuned each
season.

**Death-loss rules per tier (what you risk vs bring home):**

| | Meadow (T0) | Dusk Isles (T1) | Hollow (T2) |
|---|---|---|---|
| Loadout weapon from the armory | always comes home | lost unless insured | lost |
| Found weapons, gloves, valuables | lost to deathbox | lost to deathbox | lost to deathbox |
| Carried gems | lost (Vault keeps 1/3) | lost (Vault keeps 1/3) | lost (Vault keeps 1/4) |
| Boki on you | safe | in your deathbox, lootable | in your deathbox, lootable |
| Boki out of your hands | safe | escape home | capturable (hold F 3 s) |
| Secure pouch (new): 1 slot, 2 at rank 20 | kept | kept | kept |
| XP | kept | kept | kept |
| Loot multiplier | ×1 | ×1.75 | ×2.75 |
| Target extract rate | 55-65% | 40-50% | 30-40% |

Tuning rule: a Hollow run's expected value should be about 1.4× a Meadow run for a squad that
extracts at the target rate, and below 1× for one that doesn't.

**Home tie-ins.**

- **Incubator** (branch `ivs`): 1 slot at first Rare Egg, 2 at rank 12, 3 at Bokidex 75. A Rare Egg
  hatches after 3 expeditions or 30 real minutes.
- **Nesting Nook and breeding** (branch `ivs`): opens at rank 6. Each Boki can lay at most 5 eggs in
  its life with a 3-expedition cooldown between. Offspring IVs: each IV from a random parent, with a
  1-in-4 chance per IV of a fresh roll. Bred Boki are "line" edition (§7b).
- **Jobs** (`core/work.gd`): Boki work produces materials (lumber, sparks, scrap) that feed
  building tier-2 upgrades. Jobs never produce gems directly, so the farm can't become a gem
  faucet outside the stall's cap.
- **Buildings**: tier-2 buildings gated by rank (Workshop II at 15, Training Yard II at 20, Vault II
  at 30), so rank matters at home too.

### Technical plan

- New `scripts/core/meta.gd` (class `Meta`): account XP, rank, mastery, dex counters, season track.
  Reads `content/meta/ranks.json`, `mastery.json`, `dex_rewards.json`, `season_<n>.json`,
  `xp_rules.json`.
- `progress.gd`: challenges gain `daily` and `weekly` kinds with rotation by date.
- `match.gd` → `Match.finish()` computes XP from `xp_rules.json` into the result dict;
  `ui/results.gd` shows the rank bar, mastery bar and track progress (UI_DESIGN shell).
- `econ.gd`, `ransom.gd`, `data.gd`: new sinks and the death-loss table become data in
  `content/meta/economy.json` rather than constants.
- Kindex tab in `ui/overlay.gd` → Bokidex v2 with marks, regions and milestones.
- `tools/econ_sim.py`: Monte Carlo of three player profiles (casual 3 h/week, regular 10 h,
  grinder 30 h) through matches and home cycles, printing days to rank 10/30/50, gem balance over
  time and faucet/sink ratio. Reads the same JSON.
- N4 onward: the ledger and rules live in a Nakama server module; `tools/export_econ_vectors.gd`
  writes input/expected-output pairs from the Godot rules that the server's tests replay.

### Milestones

| # | Milestone | Effort |
|---|---|---|
| E0 | Economy sheet as data (`content/meta/*.json`) + `econ_sim.py` + this table reviewed by the owner | 1 |
| E1 | Hunter Rank and match XP, results screen, rank-gated unlock hooks (used by §4 O1) | 1.5 |
| E2 | Archetype mastery (after the archetype build) | 1 |
| E3 | Bokidex v2 (after roster R1) | 1.5 |
| E4 | Death-loss tuning: secure pouch, loadout insurance, Ransom price formula, tier warning screens | 1.5 |
| E5 | Dailies, weeklies and the season track (offline first) | 2 |
| E6 | Server ledger: rules exported to the account service, test vectors, offline vs online realms | 2-3 |

Total: **10.5-11.5 dev-weeks**.

### Tests

- `--meta-check`: XP from a scripted result matches `xp_rules.json`; rank-ups at the right totals;
  mastery only for the played archetype; dex marks set once.
- `--economy-check` (exists): extended with the death-loss table per tier, secure pouch, insurance
  and Ransom pricing.
- `econ_sim.py --assert`: regular profile reaches rank 10 in 1-2 weeks and rank 30 in 8-12 weeks;
  steady-state sink/faucet between 0.9 and 1.05.
- E6: `--econ-vectors` output equals the server module's results byte for byte.

### Risks

- Tuning against a tiny population: use bot simtests (`--simtest` with §6 T0 events) for first
  numbers, then real telemetry.
- Too many tracks feel like chores. Keep one ladder on screen; side tracks live on the Journey page.
- Gem inflation once trading opens (§7). The market tax is the main brake; watch the price index.

---

## 3. Maps

### Goals

- Three new maps beyond Skyreach, each with distinct biomes, three boss lairs, landmarks, an
  extraction layout that plays differently, and Boki spawn tables by region.
- Built with the same authored-map pipeline as Skyreach, generalized into a reusable tool.
- No new synced systems: new hazards are clock- or server-driven so networking (§1) covers them.

### Design

| | **Underbough** | **Saltglass Expanse** | **Riftfall** |
|---|---|---|---|
| Fantasy | giant canopy islands: trunks as pillars, under-branch walkways, glowing fungus below | bleached salt flats and crystal spires, heat shimmer, long sightlines | the shattered rim over the sleeping Wyrm (the prologue's lore), small islands, lots of abyss |
| Plays like | vertical, close-range, ambush-heavy; Thief, Juggernaut, Bulwark | open, ranged, rotation-heavy; Archer, Gunslinger, Mage | chaotic, high-stakes, short; everything |
| Tiers | all | all | Hollow and above only (endgame) |
| Size | 200×200 tiles | 240×240 | 180×180 |
| New biomes | `canopy` (green-gold light, leaf litter), `lumen` (dark underside, bioluminescent) | `salt` (white crust, crystal clusters), `glass` (mirrored dunes) | `rift` (void-cracked stone, floating debris), `ash` (grey, ember-free cinder plain) |
| Landmark | the Lantern Tree crown | the Shattered Lens, a giant prism | the Wyrm's Spine breaking through the clouds |
| Lairs and bosses | **Orchid Reaver** (mantis + orchid: camouflage, blade arcs, a pollen cloud that hides it); **Old Hollowhorn** (stag beetle + elk: charges that root you on a wall slam, root eruptions); **Lumen Matriarch** (moth: darkness phases that shrink everyone's sight radius, lights you fight over) | **Glassback** (pangolin + tortoise: a mirror shell that reflects shots from the front, a rolling charge); **Mirage Stalker** (caracal + chameleon: decoys on the minimap and in the world); **Saltwyrm** (eel: swims under the crust, surfaces on telegraphed lines) | **The Choir** (three owl-bat bodies with shared health; kill order changes the attack set); **Gravemaw** (mole-rat + anglerfish: a lure in the dark, burrow ambushes); **Wyrm Scion** (a young Wyrm: arena-wide gravity pulls and falling debris lines) |
| Exits | docks on 4 outer branch tips; 6 hatches in hollow trunks; 3 canopy lifts (outposts) | 3 docks far apart (loud is deadly in the open); 8 hatches; 2 salt lifts | 2 docks; 6 hatches; one mid-match **Rift Lift** event at 3:30 that the whole map fights over |
| Hazards | canopy shade (sight −20% under leaves), spore updrafts | glass storms: a drifting zone that doubles glider heat (like the abyss storm clouds, clock-driven) | islands start falling at 5:00 instead of 6:00; gravity vents (strong updrafts that also pull) |
| Train or signature mover | a canopy gondola loop (sky train code, new model) | none (open map) | none |

**Boki spawn tables by region.**

- Each biome JSON gains a `boki` table:
  `[{"sp": "vespyx", "w": 10, "tiers": [0, 1, 2], "rarity": "common", "time": "any"}]`.
- A map can override per region (`islands[i].boki`), for map-exclusive species.
- `SpawnPlan` already deals `rare_kin` candidate points; it draws species from the region's table,
  weighted by rarity × tier: Meadow 70/25/5/0/0 (common/uncommon/rare/epic/legendary), Dusk Isles
  50/32/15/3/0, Hollow 35/35/22/8/0. Legendary only from boss eggs.
- Roughly 14 biomes (6 today + 6 here + 2 later) × 10-14 species each, each species in 1-3 biomes.
- The Bokidex shows habitats once a species is seen.

### Technical plan

- **Map tool.** Split `tools/make_skyreach.py` into `tools/mapgen/` (`shapes.py`, `bridges.py`
  for the bridge-end solver, `validate.py`, `export.py`, `preview.py`) and one script per map
  (`tools/maps/skyreach.py`, `underbough.py`, `saltglass.py`, `riftfall.py`). `preview.py` renders a
  PNG of islands, bridges, exits, lairs and spawn candidates, so layouts can be iterated without
  Godot. `validate.py` checks reachability, bridge ends on solid ground, minimum distances between
  exits and between spawns, and that every lair gate faces walkable ground.
- **Game code.**
  - `World.layout_for_tier()` → map rotation from `content/maps/rotation.json` (mode and tier to a
    weighted map pool; Riftfall only at Hollow+).
  - `ui/full_map.gd`: map name from the layout instead of the `"skyreach"` special case.
  - `landmarks.gd`: landmark kind per region read from the map JSON (today the six kinds are
    picked in code).
  - `boss.gd`: each new boss is a subclass or an attack-set module (`scripts/match/bosses/`); boss
    attacks stay code (reviewed), but phases, health, enrage and egg species become data in
    `content/bosses/<id>.json`.
  - `sky_train.gd`: generalized to any clock-driven mover with a model hook (the gondola).
  - New biome JSONs in `content/biomes/`; props through `flora.gd` / `assets.gd` (CC0 kits per
    ASSET_CREDITS rules).
- **Networking.** Glass storms, gravity vents, the Rift Lift and the gondola are functions of the
  match clock and seed, so clients compute them; only state changes (Rift Lift captured) are events.

### Milestones

| # | Milestone | Effort |
|---|---|---|
| MT0 | `tools/mapgen/` refactor: `skyreach.json` regenerates **byte-identical**; `preview.py` | 1 |
| MT1 | Map rotation, generalized `--mapcheck=<id>`, data-driven landmarks and boss data, Boki spawn tables on Skyreach's 6 biomes | 1.5 |
| MA | Underbough: layout, 2 biomes, landmark, 3 bosses, gondola, spawn tables, perf pass | 6-7 |
| MB | Saltglass Expanse | 6 |
| MC | Riftfall (post-launch content drop) | 6-7 |

Total: **20.5-22.5 dev-weeks** (bosses are about half of each map).

### Tests

- `python3 tools/mapgen/validate.py <map>`: fails on unreachable islands, bad bridge ends, exits
  closer than 40 tiles, lairs without walkable gates.
- `--mapcheck=<id>` (generalize `run_authored`): 20 seeds per map; every island reachable, pads and
  updrafts clear, spawn candidates on solid ground.
- `--boss-check` (exists on `lairexit`): extended per new boss: phases at 66% and 33%, enrage, egg
  drop, every attack telegraphed above the DASHES §5.3 floors.
- `--biome-check` (exists): new biomes' mobs, hazards and Boki tables load and roll.
- `--simtest --map=<id>`: a full bot match per map prints extraction count per exit type, deaths
  per region and boss kills, to catch dead zones.
- Perf: the perf probe (branch `perf`) under the drop's wide view stays within the frame budget set
  in the `perf` work.

### Risks

- Bosses are the expensive part (about 1 week each with models and telegraphs). Reuse attack
  building blocks (`combat/verbs.gd`, `fields.gd`) and keep each boss to 4-5 attacks.
- Three new maps split a small population; rotate one map per queue at a time early on.
- Readability of new biomes from the top-down camera: test each palette against the effect-category
  colours (DASHES §5.1) so control violet and damage ember stay readable on salt white and lumen dark.

---

## 4. Onboarding: the first hour

### Goals

- A new player understands move, shoot, dash, glide, their Boki's ability and send/recall, and how
  to get out alive within 15 minutes.
- Every other system appears when it first matters, not before.
- One registry decides what's unlocked, so no panel shows a system the player hasn't met.

### Design

**The first hour, beat by beat.**

| Time | Where | Beat | Teaches |
|---|---|---|---|
| 0:00 | prologue | the seven-shot story (skippable) | the world, the Wyrm |
| 0:03 | hatch | pick one of three eggs, hatch, name your Boki | your partner |
| 0:05 | hatch | "How do you like to fight?" three answers → Thief (light), Gunslinger (medium) or Juggernaut (heavy) | your first archetype (the three most direct kits) |
| 0:06 | tutorial expedition (`tutorial.json`) | walk, aim, shoot a dummy; dash through a slow orb; jump and glide over a gap | movement and weapon |
| 0:09 | tutorial | your Boki's ability (C) on a dummy; send it out (G) and recall it | the two Boki keys |
| 0:11 | tutorial | Boki stuns, you shoot: COMBO | the combo loop |
| 0:12 | tutorial | break a crate, pick up a better weapon, see the backpack | loot |
| 0:13 | tutorial | a dazed wild Boki: hold F to catch | catching |
| 0:14 | tutorial | the outpost uplink: start it, hold the yard against a small wave, ride the lift | extraction (one exit type only) |
| 0:16 | results | XP bar, Hunter Rank 2, "your Boki trusts you more" | the ladder |
| 0:17 | home | DAY1 list: pet, feed, plant, water | care and farm |
| 0:22 | home | the caught Boki starts a job on its own; a prompt explains jobs | jobs |
| 0:24 | home | armory: pick your loadout | loadout |
| 0:26 | first Meadow expedition (easy bots, 6 squads) | tips on first sight: skiff dock, rift hatch, deathbox, revive beacon; first level-ups and skill points; R unlock at level 6 with the bonded R tip | the full match |
| 0:40 | results + home | second archetype of your weight class unlocked; Challenge House | variety |
| 0:45 | second Meadow expedition | first glove found: Q explained | gloves |
| 0:58 | home | "Next: the Dusk Isles after 2 extracts. Your Boki can be lost there." | what's coming |

**Unlock order (the registry).**

| Unlock | When | Hidden until then |
|---|---|---|
| Archetype 1 (choice of Thief, Gunslinger, Juggernaut) | hatch | other archetypes shown as silhouettes |
| Boki ability, send/recall, combos, catching, outpost exit | tutorial | — |
| Docks, hatches, deathbox, beacons, levels and R | first Meadow match, as tips on first sight | — |
| Archetype 2 (same weight class) | first extract | |
| Armory loadout, Challenge House, jobs | first extract | the job board |
| Gloves | first glove found | the Q slot shows empty |
| All six archetypes | Hunter Rank 5 (~3 hours) | — |
| Typing/infusion explained | when a second Boki can be equipped | the infusion table on the Boki card |
| Dusk Isles | 2 extracts + a one-time warning screen | tier card shows a lock |
| Ransom House | the first time a Boki is lost, or rank 8 | the building is boarded up |
| Nesting Nook (breeding) | rank 6 + two level-5 Boki with a Close bond | — |
| IVs | first hatch from the nook or the incubator | the Growth tab's IV cells |
| Incubator | first Rare Egg, or rank 8 | — |
| Evolution and mutations | first form at level 4 | — |
| Hollow | 5 extracts + rank 10 + warning screen | — |
| Season track | after the tutorial | — |
| Trading and market (§7) | rank 10 + 2FA | the market's Boki tab |
| Shimmer, rare mutations | found naturally | never announced in advance |

**Tips and the codex.** Tips stay context-triggered and shown once (today's `_tip`), moved to data
with a trigger, text with key placeholders, priority and a "done when" condition. A **Codex** page
(Esc menu) keeps a short entry for every system the player has met, with Phase 4's generated rules
text for abilities.

### Technical plan

- New `scripts/core/unlocks.gd` (class `Unlocks`), reading `content/meta/unlocks.json`. Replaces
  `Progress.SHOP_REQ`, `TIERS[i].unlock` and the hub's ad-hoc checks; `home.gd` `hub_items()`,
  `overlay.gd`, the expedition panel and `kinbox_view.gd` ask `Unlocks.has(id)`.
- `ui/hatch.gd`: the archetype question after naming.
- `content/maps/tutorial.json` + the tutorial beats in `match.gd` (`opts.tutorial`): rewritten for
  archetype kits and the two Boki keys (C ability, G send/recall).
- `content/meta/tips.json` + `Match._tips()` reading it; tips log `tip_shown` and `tip_acted`
  events (§6).
- `Progress.DAY1` → `content/meta/day1.json`.

### Milestones

| # | Milestone | Effort |
|---|---|---|
| O1 | Unlock registry and gating (no new content), warning screens for Boki-risk tiers | 1 |
| O2 | Tutorial expedition rework for archetypes and the Boki keys (after the archetype build) | 2 |
| O3 | First-hour home flow: DAY1 v2, guided first armory and job prompts, Ransom House reveal | 1.5 |
| O4 | Data-driven tips and the Codex, using Phase 4 rules text | 1 |
| O5 | Funnel telemetry + a watched session with 5 new Discord players, then a tuning pass | 1 |

Total: **6.5 dev-weeks**.

### Tests

- `--tut-test` (exists, drives the tutorial): one assertion per beat; finishes in under 10 minutes
  of game time.
- `--onboard-check`: a fresh save through scripted results (1, 2, 5 extracts; rank 5, 6, 10) asserts
  the unlock order and that no hub entry, panel or tip refers to a locked system.
- `--tips-check`: every tip's trigger fires in a scripted scenario and its placeholders resolve to
  the current binds.

### Risks

- The archetype build changes the kit the tutorial teaches: O2 waits for it.
- Too much hidden feels empty for veterans: an "I've played before" option at the archetype question
  skips the tutorial and unlocks archetypes 1-3 immediately.

---

## 5. Audio

### Goals

- **Calmer** overall, per the owner's earlier feedback: warm and acoustic in the world, short and dry
  in combat, nothing harsh.
- **Strong two-sided ability cues**: you always know what you did and what's coming at you, by sound
  alone.
- Music that follows the match (home, drop, explore, fight, boss, extraction) without abrupt cuts.
- A voice for every Boki, including community Boki, without recording 150 voices.
- Only original, procedural or properly licensed (CC0) audio.

### Design

**Direction: soft world, sharp signals.**

- World and music: warm folk and airy pads; acoustic plucks, woodwinds, light percussion; slow
  attacks; little energy above 6 kHz.
- Combat: short, dry transients; no long tails on repeated sounds.
- Signals (enemy CC tells, incoming projectile, low health, bonded R ready): distinct timbre
  families that cut through by pitch and rhythm, not loudness.
- No square waves or raw hiss (already the rule in `synth.gd` and `gen_sfx.py`).

**Two-sided cues.** Every ability event plays a different version depending on who hears it, using
DASHES §5.6's four layers (tell, body, impact, sweetener) and §5.1's category families:

| Listener | Tell | Impact | Level |
|---|---|---|---|
| caster | soft confirmation, centred | muted | 0 dB |
| ally | same sound, quieter | quieter | −4 dB |
| enemy in reach | brighter attack, spatialized, a rising pitch as a projectile nears | full; CC holds its tone for the CC's duration | +3 dB |
| enemy out of reach | normal | normal | 0 dB |

Category families: damage = crack + thump; control = hard hit then a held tone; sustain = rising
chime; utility = airy ping. The Boki's theme only picks the sweetener.

**Music by context.**

| Context | Music |
|---|---|
| Title, prologue | the main theme |
| Home | day, night, rain variants (exist), plus seasonal variants later |
| Town, guild isles | exist |
| Drop (skyship and glide) | a soaring cue that builds and resolves on landing |
| Explore | low-intensity stems per map |
| Fight | a percussion and bass stem fades in when you've dealt or taken damage in the last 6 s or a rival is within 15 m; fades out over 8 s |
| Boss | a per-boss motif: sting on lair open, loop during the fight, phase stingers at 66% and 33% |
| Extraction | a tension pulse while your skiff is called, your uplink charges or the islands start falling; a release stinger on boarding |
| Results | extract, death and win stingers |
| Hollow and Riftfall | darker arrangements of the same themes |

Godot 4.3+ has `AudioStreamInteractive` (transitions between clips) and
`AudioStreamSynchronized` (stems in sync): use them instead of hand-rolled crossfades.
`tools/compose.py` renders stems (equal length, same tempo) per track.

**Boki voices.** Synthesized at runtime from `voice.syllables` in each KinSpec plus body size
(pitch), role and personality (temper roughens, curiosity raises intonation): a short formant
"creature speech" made of chirps, trills, purrs and growls, seeded per species so every Vespyx
sounds like a Vespyx and each individual varies slightly. Emotions: happy, alert, unsure, hurt,
attack bark, name call (today's `kin_happy`, `kin_alert`, `kin_unsure` become synthesized per
species). Community Boki get voices for free. Words shown in text (the `kin_speak.gd` stages) are
accompanied by babble.

**Mix rules.**

- Buses: Master → Music; SFX → Signals, Combat, World (ambience, footsteps), UI, Voices. Signals is
  never ducked; Music ducks −4 dB for 0.3 s on bonded R or merge starts within 20 m (DASHES §5.6).
- Priority for voice stealing: enemy CC tells > incoming impacts on you > your impacts > ally casts
  > Boki voices > ambience. At most 4 voices per ability event; 32 voices total.
- Damage-over-time and zone ticks: first tick only.
- Loudness targets: combat mix around −16 LUFS short-term, true peak ≤ −1 dBTP; music alone ~6 dB
  under combat; UI ~−22 LUFS.
- Per-tier loudness budget: the ability's grammar tier caps its impact layer (DASHES §5.7).
- Settings: separate sliders (music, effects, voices, UI), **calm mode** (fewer combat stems,
  softer impacts), mono, and visual sound indicators as an accessibility option (direction arcs for
  unseen gunfire and footsteps, available to everyone so it isn't an advantage).

**Procedural vs sourced.**

| Keep procedural (original) | Source as CC0 |
|---|---|
| ability layers generated from parts (`gen_sfx.py` bank keyed by delivery × category × theme) | footsteps per surface (grass, stone, wood, salt crust, glass, canopy bark) |
| Boki voices (`synth.gd`) | cloth and gear foley, weapon mechanical clicks (reloads) |
| UI clicks, glider, whistle (exist) | ambience beds: wind, birds, insects, forest canopy, crystal hum |
| music composition (`compose.py`, `gen_music.py`) | — |

Candidate sources (check the license on **every file** before vendoring and record source, URL,
commit or file id and license in `docs/ASSET_CREDITS.md`, as the art packs already are):

| Source | License | Use |
|---|---|---|
| Kenney audio packs (kenney.nl: Impact Sounds, Interface Sounds, RPG Audio, and others) | CC0 | foley, impacts, UI |
| Freesound.org, filtered to "Creative Commons 0" only | CC0 per file | footsteps, ambience |
| OpenGameArt.org, filtered to CC0 | CC0 per file | ambience loops |
| VSCO 2 Community Edition (Versilian Studios) | CC0 | orchestral samples for `compose.py` |
| FluidR3_GM soundfont | MIT | an alternative GM bank for `compose.py` |
| GeneralUser GS (already used) | its own license allows rendering music with it; only rendered audio ships | keep |

Excluded: Sonniss GDC bundles (royalty-free but not CC0; redistributing raw files in a public repo
isn't covered), Pixabay audio (Pixabay Content License, not CC0), BBC Sound Effects (RemArc,
non-commercial). Community-made audio is accepted only under CC0 (or CC-BY with credit) with a
contributor statement.

### Technical plan

- `core/sfx.gd`: category buses, priority and voice stealing, and
  `Sfx.ability(layer, delivery, category, theme, pos, caster_team, listener_team, reach)` that picks
  the two-sided variant. Extends today's MIN_GAP/STACK.
- New `scripts/core/music.gd` (class `Music`): a music director state machine (context + intensity)
  driving `AudioStreamInteractive`; takes over track switching from `home.gd` and match code;
  `Sfx.music_lock` (the house's music list) keeps working.
- `tools/gen_sfx.py`: an ability bank generated per (delivery, category, theme) and per listener
  side; budgets per category.
- `tools/compose.py`: stems and boss motifs.
- `core/synth.gd`: `BokiVoice` (formant synthesis, cached per species and emotion).
- `tools/vendor_audio.sh` + `tools/vendor_audio.py`: like `vendor_assets.sh`, rebuilds
  `audio/vendor/` from pinned sources, normalizes loudness, converts to ogg, writes credits.

### Milestones

| # | Milestone | Effort |
|---|---|---|
| A1 | Calm pass and mix rework: buses, priorities, loudness budgets enforced by `sfx_stats.py` | 1 |
| A2 | Two-sided ability cues generated from parts (after grammar Phase 4) | 2 |
| A3 | Music director and stems: drop, explore, fight, boss, extraction, results | 2.5 |
| A4 | Boki voices (synthesized per species) | 1.5 |
| A5 | CC0 foley and ambience pass (surfaces, biome beds for new maps) | 1.5 |
| A6 | Accessibility: calm mode, mono, visual sound indicators | 1 |

Total: **9.5 dev-weeks**.

### Tests

- `python3 tools/sfx_stats.py --assert`: every file within its category's loudness, peak and
  spectral-centroid budget (calm rule); fails the build otherwise.
- `--audio-check` (headless, dummy audio driver): a scripted 20-hunter fight logs voices per frame;
  asserts the 32-voice cap, that enemy CC tells are never stolen, ducking timing, first-tick-only for
  DoTs, and the two-sided variant per listener.
- `--music-check`: drives the director through every context and asserts the clip and transition.
- `--voice-check`: every species in `content/kin_v2` gets a voice; same species same timbre, two
  individuals measurably different.

### Risks

- Synthesized impacts can sound cheap next to sourced foley. Blend: synthesized tells and signals
  (where clarity matters most), sourced foley where texture matters.
- Voice stealing bugs hide signals in a 20-player fight. The `--audio-check` scenario is the guard.

---

## 6. Telemetry and crash reports

### Goals

- Balance from data: deaths and causes, extraction rate by tier and map, archetype and Boki pick and
  extract rates (and archetype × Boki), economy flow.
- Crash reports that let us fix crashes we can't reproduce.
- Respect privacy: opt-in, anonymous, minimal, documented in the open repo.

### Design

**Principles.**

- **Opt-in** at first launch: two separate questions, "Share anonymous match stats" and "Send crash
  reports", both unchecked by default; changeable in Settings > Privacy.
- A random install id, not the account id, not a hardware id. No names, no chat, no free text, no
  IP addresses stored (the ingest drops them).
- Server-side match records (results, anti-cheat stats) are needed to run online play; they're
  disclosed in the privacy policy rather than opt-in analytics. Legal review decides the exact
  basis (§7f).
- Raw events kept 90 days, aggregates 13 months. Deletion on request via the account page.
- The event schema lives in the repo (`content/telemetry/schema.json`), so anyone can read exactly
  what's collected.
- No third-party ad or attribution SDKs, ever.

**Events (all with time, build, map, tier, mode).**

| Event | Fields |
|---|---|
| `match_start` | squad size, archetype, Boki species and level, loadout rarity, squad power bracket |
| `death` / `knock` | match time, cause (hunter, monster, boss, abyss), killer archetype, Boki and ability id, position bucketed to 8 m |
| `extract` | method (dock, hatch, uplink, Rift Lift), match time, carried value |
| `match_end` | extracted or not, XP, gems in and out, items in and out |
| `boss` | boss id, open method, kill or wipe, duration |
| `boki_catch` | species, rarity, tier, region |
| `ability_summary` | per ability id: casts, hits, damage share (sampled 20%) |
| `econ` | mint or burn, source or sink id, amount (home and match) |
| `unlock`, `tutorial_step`, `tip_shown`, `tip_acted` | ids |
| `perf` | fps p50 and p95, worst frame, GPU class, quality preset |
| `session` | length, screens visited (counts) |

**Pipeline.**

- Client: events go to `user://telemetry/queue.jsonl`, flushed every 60 s and at match end over
  HTTPS (`HTTPRequest`), dropped after 7 days unsent. Opted out = nothing written, nothing sent.
- Dedicated servers send their own match events directly (more trustworthy than clients).
- Backend, two options:
  - **PostHog** (a dedicated project, EU cloud region, person profiles off, anonymous ids): fastest
    to stand up, dashboards included.
  - **Self-hosted**: a small ingest endpoint (a Nakama RPC or a tiny Go service) → ClickHouse or
    Postgres → Metabase or Grafana.
  - Recommendation: PostHog first for speed, with a vendor-neutral schema and a thin client so the
    backend can move to self-hosted later without a client change.

**Crash reporting.**

- Godot desktop builds already write `user://logs/godot.log`. Minimal path (T1a): a
  `running.lock` written at start and removed on clean exit; on the next start, if the lock exists
  and crash reports are allowed, send the last log, build id, OS, GPU and the last 50 telemetry
  events. Godot 4.5+'s scriptable `Logger` (`OS.add_logger`) captures script errors and warnings
  as they happen.
- Fuller path (T1b): Sentry's official Godot SDK (`sentry-godot`, MIT, a GDExtension that works
  with the standard build) for native crash dumps and symbolicated stacks, reporting to Sentry or a
  self-hosted Sentry-compatible server (GlitchTip).
- Dedicated servers: process supervisor restarts the match server, ships the log and core dump to
  the same place, and marks the match void (no losses applied).

**Dashboards.**

| Dashboard | Shows |
|---|---|
| Balance | archetype pick and extract rates; archetype × Boki matrix with confidence intervals; ability damage share; TTK distributions |
| Match health | extract rate by tier and map; deaths by cause; abyss deaths share; boss kill rate and time; death heatmaps per map |
| Economy | faucets vs sinks per day per cohort; median balance; market price index (§7) |
| Onboarding | tutorial and first-hour funnel; tip acted-on rates; unlock timing |
| Tech | crash-free sessions; fps by GPU class; server tick p99; bandwidth per client |
| Community | DAU/WAU, D1/D7/D30 retention, queue times by mode |

### Technical plan

- New `scripts/core/telemetry.gd` (autoload `Telemetry`): consent, queue, flush, schema check in
  debug builds. Called from `match.gd` (start, knock, death, extract, end), `boss.gd`, `econ.gd`,
  `unlocks.gd`, `Match._tips()`, the perf probe.
- `--simtest` writes the same events to a local file, so **bot-versus-bot balance dashboards exist
  before any player data** (T0).
- `scripts/core/crash.gd` (lock file, log upload) or the Sentry GDExtension under `addons/`.
- Consent screen in the first-run flow (`ui/title.gd` or `ui/hatch.gd`) with the UI_DESIGN shell.

### Milestones

| # | Milestone | Effort |
|---|---|---|
| T0 | Local event log, schema, consent screen; `--simtest` emits events; a script turns them into balance tables | 1 |
| T1 | Crash reports (T1a lock file + log; T1b Sentry SDK if native crashes need it) | 1 |
| T2 | Ingest and dashboards | 1.5 |
| T3 | Server-side match telemetry from dedicated servers, anti-cheat statistics | 1 |
| T4 | Privacy page, deletion requests, retention jobs | 0.5 |

Total: **5 dev-weeks**.

### Tests

- `--telemetry-check`: every emitted event validates against the schema; no field outside the
  allowed list (no names, no free text); opted out → zero queue writes and zero requests (the
  `HTTPRequest` is mocked).
- `--crash-test` (debug builds only): forces a crash; the next start detects the lock and builds a
  report (sent to a mock).

### Risks

- Opt-in rates may be low; server-side telemetry (T3) covers balance for online matches anyway.
- A creature game attracts children. Without an age gate, assume some players are under 13: no
  profiling, no ads, minimal data (§7f).

---

## 7. Collectible Boki: editions, trading, crossover

The owner's vision: Boki that can cross over into other genres while staying the same Boki, and
limited editions so people trade to get them, with some super-rare limited releases: "the good part
of NFTs but not crypto related". No blockchain is involved: the server is the record.

### Goals

- Every Boki is a **unique instance** with a global id and a history, owned by an account, and
  never trusted from a client.
- Real scarcity where it's promised: numbered editions with published caps that are kept.
- Safe trading: player-to-player and a marketplace, with escrow, no dupes, and protection against
  bots, scalpers and account theft.
- Rarity brings a mix of value, designed **case by case**: collectible and identity value (edition,
  serial, provenance, looks), unique utility, and sometimes extra power. There's no blanket rule
  either way. The tier system makes the power cases fair.
- A versioned, genre-neutral Boki schema and API so other games can read the same Boki.

### (a) The Boki instance

Stored in the account service (Nakama module with Postgres tables, transactional), never written by
clients:

| Field | Meaning |
|---|---|
| `bid` | global id, server-minted (128-bit, time-ordered, e.g. ULID/UUIDv7) |
| `species`, `form` | species id and evolution path/form |
| `edition` | `{id, kind, serial, cap}`: kind is `wild`, `line`, `genesis`, `event`, `mythic`, `boss`, `heirloom`, `founder`; `serial` 12 and `cap` 500 read "#12 of 500" |
| `ivs`, `mutations`, `shimmer`, `traits` | genetics and personality as today |
| `level`, `xp`, `trust` | trust is per owner and partly resets on a change of owner (the owner's "a Boki that loved its old owner may be slow to bond") |
| `lineage` | `{parents: [bid, bid], gen}` |
| `provenance` | append-only events: `{t, event, by, where, match, price}` with event in caught, hatched, bred, traded, sold, looted, captured, ransomed, released |
| `owner`, `status` | account; `home`, `boxed`, `in_match`, `escrow`, `listed`, `lost` |
| `minted` | `{t, by: server or match id}` |
| soft state | name, memories, care needs, outfit: cloud-saved, client-written, not part of value |

Mint points: a wild catch mints at **extraction** (until then it's pending and follows the tier's
loss rules); a hatch mints with lineage; a boss egg mints a `boss` edition at hatch.

### (b) Supply

| Edition | Supply | How you get it |
|---|---|---|
| `wild` | uncapped | catching; every species has an uncapped way in, so the Bokidex is never blocked by supply |
| `line` | uncapped | breeding; offspring are always line edition |
| `genesis` | the first 1,000 of each species caught in the launch season, serials #1-1000 | catching at launch |
| `event` | capped (e.g. 500) and/or time-limited | catching during limited-time events in event regions; per-account limit 1-2 per edition |
| `mythic` | caps of 10-100 | hard in-game feats only: first clears of new bosses, season finales, community events. Never sold, never random-for-money |
| `boss` | uncapped | boss eggs (legendary species) |
| `founder` | one per pre-launch Discord playtester | minted server-side as a thank-you |
| `heirloom` | one-time | the offline-save import (g) |

Rules that close infinite-supply loopholes:

- Serials are assigned in one database transaction against the cap. A released (deleted) limited
  Boki is **burned**: its serial is retired and never reissued.
- Edition and serial are **not heritable**. Offspring of a limited Boki are line edition and carry
  an ancestry note in provenance ("descended from Genesis Lunowl #12"), flavour only.
- Evolution, mutation and shimmer never change edition.
- NPCs never create or absorb limited Boki: Old Pell holds a lost limited Boki until it's bought back
  or released; he never sells it on to an NPC rival (that path exists today after 6 expeditions).
- Event spawns roll edition at mint time on the server, with per-account caps, minimum account age
  and rank, so bot farms can't drain an event.

### (c) Trading

- **Direct trade**: both players online (town, home visit or a party), both lock their offer, a 5 s
  confirm, then the server swaps atomically through escrow (both sides move to escrow, then to the
  new owners in one transaction). The window shows edition, serial, IVs, mutations, provenance and a
  value warning when an offer is lopsided.
- **Marketplace**: listings priced in **gems only**. The Boki sits in escrow while listed; 5% listing
  fee + 5% sale tax (the main late-game gem sink, §2). Buy-now first; auctions later if needed.
- **Anti-dupe**: one database row per Boki with an owner and a version (optimistic locking); every
  transfer is a ledger entry; every RPC carries an idempotency key; the client never mints.
- **Anti-bot and anti-scalper**: rank 10 and 2FA to trade; anything you acquire by trade or market
  is trade-locked for 7 days; daily trade and listing limits; limited editions come from play, never
  first-come store drops (the pattern scalpers exploit).
- **Account security**: TOTP 2FA required for trading; device verification; a 3-day trade hold after
  a password or email change; self-service trade lock; session list and remote sign-out; account
  linking (Discord, Steam) through OAuth.
- **Fraud handling**: full trade logs; reversals only for proven account compromise; bans for scams
  and real-money trading; a report button on every trade and listing; admin tools as server RPCs.
- **Real money: recommendation is no.** Gems can't be bought and can't be cashed out; the
  subscription never grants gems, Boki or editions. The terms of service forbid selling Boki or
  accounts for money. Real-money trading invites scams, phishing, account theft, botting, and
  regulatory trouble (f). Steam's Community Market would attach wallet value to Boki, so don't use
  it at launch. Steam's rules ban blockchain and NFT games; this design uses neither, but keep the
  marketing free of NFT language.
- **PvP transfers**: losing a Boki in the Dusk Isles or Hollow can move it to a rival (that's the
  point of those tiers). It's logged like a trade. Repeated transfers between the same accounts are
  flagged as possible collusion to dodge trade locks.

### (d) Fairness: rarity, power and tiers

There's no blanket rule that rarity must or must not mean power. Each rare Boki is designed case by
case, with a mix of:

- **Collectible and identity value**: edition, serial plate, provenance, special looks (palette,
  aura, a unique idle or trail), a nameplate badge in matches.
- **Unique utility**: a companion trait common Boki don't have (riding, carry-flight, bounce pads,
  throwing the player), within the grammar's rules.
- **Sometimes extra power**: a bigger stat budget, better IV floors, an extra modifier.

The balancing tool for the power cases is the tier system:

1. **Boki Power Rating (BPR).** Computed by the grammar's Phase 3 budget: stat points and ability
   budget, plus rarity budget, plus IVs, plus level growth (`KinRules.LEVEL_GROWTH`) and evolution.
   One number per instance, shown on the Boki card.
2. **Tier caps.** Each expedition tier has a BPR cap. Grammar Phase 2 already caps level growth by
   tier (`KinRules.LEVEL_CAP` 15 / 25 / 35%); this generalizes it to total power.
3. **Risk pays for power.** Bringing a rare Boki into a Boki-risk tier risks losing it under the
   existing death rules (§2 table).
4. **Matchmaking by squad power** (§1 N5): squad power = effective BPR (after tier scaling) + a
   light hunter-skill term, bracketed within a tier, so new players aren't fed to maxed squads.

Two ways a tier can handle a Boki above its cap:

| Option | How | Pros | Cons |
|---|---|---|---|
| **Scale down** | numbers are normalized to the tier's cap, like level scaling: stats and ability numbers scale by cap / BPR, utility traits stay | you can bring the Boki you love anywhere; one queue | a scaled rare still feels a bit special (looks, utility), which is fine but must stay within the cap |
| **Disallow** | the Boki can't be equipped for that tier | simplest to read; no hidden math | locks players out of their favourite; splits squads ("your Boki is too strong for this queue") |

| Tier | Recommended |
|---|---|
| Meadow (T0, Boki never lost) | **scale down** to the T0 cap, so safety never comes with an advantage |
| Dusk Isles (T1) | **scale down** to the T1 cap |
| Hollow (T2) | full power, Boki capturable |
| Riftfall / top tier (T3, later) | full power, highest stakes |
| Any tier, specific outliers | **disallow** by a per-Boki, per-tier data flag, for a rare whose utility can't be scaled fairly (for example a carry-flight trait in T0) |

**UI.** A tier badge (T0-T3 pips) on every Boki card and in the loadout; a chip on the Boki's
portrait in the loadout and on the in-match Boki card: "Scaled to Tier 1 (−18%)"; a padlock and
"Not allowed in the Meadow" for disallowed cases; the queue screen shows your squad's power and
bracket; enemy nameplates show a power band, not the exact number.

### (e) Crossover: the Boki identity schema and API

- **Schema** `boki/1` (JSON Schema in the repo, `schema/boki-1.schema.json`), genre-neutral:
  - identity: `bid`, species, name, edition, serial, owner handle (if the owner allows it);
  - appearance: body plan (`look` part ids: body, ears, tail, feet, aura), colours, size, visible
    mutations, shimmer palette, plus a reference render (PNG) and a glTF model exported from the
    procedural builders (Godot's `GLTFDocument` can export at runtime);
  - abstract stats: power, guard, speed, focus and IVs normalized 0-1;
  - personality: bravery, loyalty, temper, curiosity;
  - abilities: the grammar parts re-expressed as category (damage, control, sustain, utility),
    shape (projectile, zone, dash...) and intensity 0-1, so a card game, a racer, a farming sim or
    a puzzle game can interpret them their own way;
  - lineage and a provenance summary.
  - Versioning: additive changes within `boki/1`; breaking changes make `boki/2`, served side by
    side for a deprecation period.
- **API**: read-only REST (`GET /species/{id}`, `GET /boki/{bid}` with public-safe fields) and OAuth
  ("Sign in with Boki") for a third party to read a player's collection with consent scopes. No
  third-party writes at first. Terms forbid gambling sites and trade bots.
- **License**: publish the schema and API docs under CC0 or MIT (separately from the GPL game code),
  so other games, including closed-source ones, can implement them.
- **First crossovers are ours**: a Discord bot that shows a player's Boki card in the community
  server (cheap, and the community already lives there), then a small companion app (view your
  collection, light care). Outside partners after that.

### (f) Legal and regulatory risks to flag for a lawyer

This is a list of questions for counsel, not legal advice.

- **Loot boxes and gambling.** Belgium and the Netherlands have treated paid random items,
  especially tradable ones, as gambling; Australia's classification rules (from 2024) give games
  with paid loot boxes a minimum M rating and simulated gambling R18+; South Korea requires
  probability disclosure (from 2024); China requires disclosure and limits. The design avoids paid
  randomness entirely: never sell a chance at a limited Boki, for money or through a paid tier. If
  any paid random item ever appears, disclose odds and check every market first.
- **Tradable items with real-world value.** Any official or tolerated cash-out route can bring
  gambling, money-transmission, KYC/AML and tax questions. Keep the economy closed.
- **Consumer protection for limited items.** "Only 500 ever" is a binding claim: minting more later
  risks deceptive-practice claims (US FTC Act §5, EU Unfair Commercial Practices Directive). Publish
  caps and keep them. Also decide and state what happens to digital items if servers shut down.
- **Investment framing.** Never market Boki as something that gains value.
- **Age ratings and children.** Trading, user interaction and in-game purchases affect ESRB, PEGI
  and IARC descriptors. Children's privacy law (US COPPA under 13, GDPR's child provisions, the UK
  Age Appropriate Design Code) and child safety argue for an age gate and no trading with strangers
  for younger accounts.
- **Platform policies.** Steam bans blockchain/NFT apps; Apple and Google require loot box odds
  disclosure and have in-app purchase rules for any mobile companion.
- **Third-party gambling around items.** Skin-gambling sites appear wherever items trade; terms and
  API terms must prohibit it, and the API must not make it easy.
- **Data protection.** Provenance shows other players' handles: give players a setting to appear as
  "a hunter".
- **Community-designed Boki.** If a crowdsourced design becomes a limited edition, the contributor
  agreement must cover rights and any credit or reward.

### (g) Groundwork to do now (cheap, Wave 0)

1. **Save migrations.** Replace the exact-version check in `Save.load_game()` with a migration chain
   (`MIGRATIONS[v] = func(d) -> d`), writing a `.bak-v<n>` copy before migrating. Today a version
   bump would wipe every save.
2. **Real unique ids.** New Boki get `bid` = 128 random bits from `Crypto.generate_random_bytes`
   plus a millisecond timestamp, base32. Existing `uid`s are kept as `legacy_uid` and every reference
   is rewritten (`active`, `active2`, `loadout`, Boki Burrow slots, `lost_kin`, Ransom offers,
   rivals). Loot items and eggs get the same.
3. **New fields with defaults** on every Boki record: `edition` `{id: "local", kind: "wild",
   serial: 0, cap: 0}`, `origin` `{how, t, where: {map, region, tier, match}}`, `lineage`
   `{parents: [bid, bid], gen}` (replacing name-only `parents`, keeping names for display),
   `provenance: []` (capped at 32 entries locally), `realm: "offline"`, `schema: 2`.
4. **Write provenance** at the existing points: catch (`match.gd` catches), hatch (`care.gd`),
   rival take and ransom (`ransom.gd`), revive at the Soul Shrine (`econ.gd`).
5. **`content_version`** on the save, and a rule that species ids are never reused.
6. **Instance schema** `schema/boki_instance.schema.json` and `--boki-schema-check` validating every
   roster entry in fixture saves.
7. **Import path to accounts** (written down now, built in N4): offline saves are editable, so
   nothing imported can be tradable. A one-time import brings up to 6 offline Boki online as
   `heirloom` edition: untradeable, species, name, look, personality and memories kept, IVs and
   mutations re-rolled by the server, shimmer not carried over (it would be forgeable).

### Technical plan

- Wave 0: `save.gd` migrations and ids; `care.gd`, `ransom.gd`, `econ.gd`, `kinbox.gd`, `match.gd`
  provenance writes; `schema/`; fixtures in `tests/save_fixtures/`.
- After N4: Nakama module `boki` (tables `boki`, `boki_events`, `editions`, `ledger`), RPCs for mint,
  transfer, escrow, list, buy, release; game servers mint through server-to-server calls.
- Client: Boki card shows edition, serial, provenance timeline, BPR and tier badge
  (`ui/kinbox_view.gd`, the Boki card in `home.gd`); trade window and market tab (UI_DESIGN shell).
- Public API: a small read-only service in front of the module; `tools/boki_export.gd` for renders
  and glTF.

### Milestones

| # | Milestone | Effort |
|---|---|---|
| S0 | Groundwork (g): migrations, ids, fields, provenance writes, schema check | 1 |
| S1 | Boki instances in the account service (with N4); heirloom import | 2-3 |
| S2 | Editions and minting: caps, serials, event windows, founder and genesis; BPR and tier scaling UI (needs grammar Phase 3) | 2 |
| S3 | Direct trading with escrow, 2FA, trade locks, logs | 3 |
| S4 | Marketplace (gems only), fees, limits, price index | 3 |
| S5 | Identity schema `boki/1`, read-only API, OAuth, Discord bot | 3 |

Total: **14-15 dev-weeks**, plus external legal review before S2 ships.

### Tests

- `--save-migrate-check`: fixture saves from v1 load, migrate, keep every Boki and reference, and
  write a backup; ids are unique across 1,000,000 generated.
- `--boki-schema-check`: every roster entry validates.
- Server module tests: concurrent trades of the same Boki (one succeeds, one fails cleanly); a
  replayed RPC with the same idempotency key does nothing; a cap of N mints exactly N under parallel
  load; released serials never reappear; a line egg never inherits edition.
- `--tier-scale-check`: a Boki above a tier's cap is scaled to exactly the cap in T0/T1, untouched
  in T2, refused where the disallow flag is set; the UI chip shows the right percentage.

### Risks

- **Trust is the product.** A single dupe or a broken cap destroys the collectible value; the
  server module needs the most careful review in the project.
- **Scarcity vs a small community**: with ~150 players at first, caps of 500 aren't scarce. Size
  caps to the population (start small: 50-200) and publish them per release.
- **Collusion transfers** through PvP loss; detection is statistical.
- **Legal exposure** (f) grows with trading volume; get the review done before S3.

---

## 8. The order

### What else is already planned

| Work | State | What's left |
|---|---|---|
| Grammar Phase 2 (runtime) | done on `grammar2` | review and merge |
| Grammar Phase 3 (budget validator) | not started | tier caps, part prices, socket pricing (ARCHETYPES §7), **Boki Power Rating** (§7d), per-kin × per-archetype result tables |
| Grammar Phase 4 (rules text, look, sound) | not started | generated rules text, icons, colour by category, telegraph floors, sound layers (DASHES §5) |
| Grammar Phase 5 (reviewed content) | per ARCHETYPES §7 | playtest the 6 × 6 archetype × Boki tables; retarget merge patches to `rmb`/`e`/`dash` sockets |
| Grammar Phase 6 | no written plan; defined here | **community pipeline**: grammar v2 format freeze (and the code rename to Boki, `content/boki/` with a loader alias), a GitHub Action running `--grammar-check` on pull requests, a web validator/preview, Discord voting, acceptance into rotation |
| Archetype build | designed (ARCHETYPES.md, DASHES_AND_ABILITY_FEEL.md) | `ArchetypeSpec`, input router (tap/hold/air/during-E/resource), six kits, passives and resources, dashes, bonded R, new weapons (longbow, spellstaff, shield and mace), HUD level cluster |
| 150-Boki roster pipeline | no doc | scaffold tool, generic body kit for `look`, turntable and portrait renders, Phase 3 check, spawn table and dex entry per Boki; batches of 10 per review. R1 = tools + 30, R2 = to 80, R3 = to 150 |
| Boss lair exits | done on `lairexit` | review and merge |
| Character art | first pass on `chars2` | merge, then a second pass: final archetype models, animation sets, weapon models for the new families |

### Dependencies

| Needs | Depends on |
|---|---|
| Archetype build | grammar Phase 2 (merged); Phase 3 for socket pricing (can start with placeholder prices) |
| Grammar Phase 4 | Phase 3 (budget tiers drive the feel budget) |
| Roster pipeline R1 | Phase 3 (budget), Phase 4 (auto tooltips and icons), the generic body kit |
| Bokidex v2 (E3), spawn tables at scale | roster R1 |
| Two-sided ability audio (A2) | Phase 4 |
| Tutorial rework (O2), mastery (E2) | archetype build |
| N1-N3 | N0; every system that exists at the time must be synced, so content added later carries its own net schema |
| Accounts (N4), server ledger (E6), Boki instances (S1) | N2 |
| Matchmaking (N5) | N4 |
| Boki-risk tiers online (N6) | N4, N5, E4 |
| Editions (S2) | S1, Phase 3 (BPR) |
| Trading (S3), market (S4) | S2, N6, 2FA, legal review |
| New maps | MT0-MT1; roster for spawn tables; boss framework (`lairexit` merged) |
| Telemetry dashboards from real players (T2) | consent (T0); online data (T3) needs N2 |
| Groundwork S0 | nothing: do first |

### Waves

Each wave lists parallel lanes. A wave ends when its milestones are merged and the check suite is
green; the owner checks in at the end of each.

**Wave 0: Consolidate (1-2 weeks)**

- Merge in-flight branches into `main`: `grammar2` (Phase 2), `ivs` (IVs, Nesting Nook, Incubator),
  `lairexit` (boss lair exits), `chars2` (character art pass 1), `names2`, `perf`. Run every
  `--*-check`.
- Player-facing rename: Kinfall → Project Boki, kin → Boki (strings, docs, README); code ids stay.
- §7 S0 groundwork: save migrations, unique ids, provenance fields.
- §6 T0: local event log, consent screen, `--simtest` events.
- License: GPL exception for platform SDKs and a contributor agreement.
- Fix doc drift in `DEATH_AND_REVIVE.md` and `KINFALL_CLASSES.md`.

**Wave 1: Foundations (about 4 weeks)**

| Lane | Work |
|---|---|
| Net | N0 net-readiness, then N1 protocol and loopback |
| Grammar | Phase 3 budget validator + BPR |
| Maps | MT0 mapgen refactor, MT1 rotation and spawn tables on Skyreach |
| Economy | E0 economy sheet and `econ_sim.py` |
| Audio | A1 calm pass and mix rework |
| Telemetry | T1 crash reports |

**Wave 2: Kits and servers (about 6 weeks)**

| Lane | Work |
|---|---|
| Archetypes | the archetype build (six kits, router, passives, dashes, bonded R, HUD) |
| Net | N2 dedicated server MVP; Discord IP playtests start |
| Grammar | Phase 4 rules text, look and sound generation |
| Onboarding | O1 unlock registry |
| Meta | E1 Hunter Rank and match XP |
| Art | character art pass 2 (archetype models, new weapon families) |

**Wave 3: Feel online, roster pipeline (about 6 weeks)**

| Lane | Work |
|---|---|
| Net | N3 prediction, lag compensation, online hit-pause |
| Grammar | Phase 5 reviewed content (6 × 6 playtests) |
| Roster | R1: pipeline tools + first 30 new Boki |
| Audio | A2 two-sided ability cues, A3 music director |
| Onboarding | O2 tutorial rework |
| Meta | E2 archetype mastery |

**Wave 4: Accounts and the second map (about 6 weeks)**

| Lane | Work |
|---|---|
| Net | N4 accounts and cloud saves |
| Collectibles | S1 Boki instances in the account service, heirloom import |
| Economy | E6 server ledger |
| Maps | MA Underbough |
| Roster | R2 to ~80 Boki; E3 Bokidex v2; A4 Boki voices |
| Telemetry | T2 dashboards, T4 privacy page |
| Onboarding | O3 first-hour home flow, O4 tips and Codex |

**Wave 5: The live loop (about 7 weeks)**

| Lane | Work |
|---|---|
| Net | N5 parties and matchmaking (squad power brackets), N6 Boki-risk tiers online + anti-cheat |
| Telemetry | T3 server-side telemetry |
| Economy | E4 death-loss tuning, E5 season track |
| Collectibles | S2 editions and tier scaling UI; S3 direct trading (after legal review) |
| Maps | MB Saltglass Expanse |
| Roster | R3 to 150 Boki |
| Grammar | Phase 6 community pipeline (format freeze, code rename, CI, voting) |
| Audio | A5 CC0 foley and ambience |

**Wave 6: Launch (about 5 weeks)**

| Lane | Work |
|---|---|
| Net | N7 load test, second region, operations |
| Collectibles | S4 marketplace |
| Onboarding | O5 funnel tuning with new players |
| Audio | A6 accessibility, final mix |
| All | bug bash, perf pass on minimum-spec hardware, launch season content |

**After launch**

- MC Riftfall (the Hollow-top tier, T3) as the first content drop.
- S5 identity schema, API and the Discord bot; then the companion app.
- Community Boki submissions entering rotation each season.

### Critical paths

1. **Online**: N0 → N1 → N2 → N3 → N4 → N5 → N6 → S2 → S3 → S4 → launch. About 30 weeks of the
   longest chain; this is the schedule's spine. Start N0 in Wave 1 and protect it.
2. **Content**: Phase 3 → Phase 4 → roster R1 → R2 → R3 → Bokidex and spawn tables on every map.
3. **Kit**: Phase 2 merge → archetype build → Phase 5 playtests → tutorial rework.

### Effort summary

| Workstream | Dev-weeks |
|---|---|
| 1 Multiplayer | 21-26 |
| 2 Meta and economy | 10.5-11.5 |
| 3 Maps (three maps + tools) | 20.5-22.5 |
| 4 Onboarding | 6.5 |
| 5 Audio | 9.5 |
| 6 Telemetry | 5 |
| 7 Collectibles | 14-15 |
| Grammar Phases 3-6 | ~10 (3 + 3 + 2 + 2-3) |
| Archetype build | 8-10 |
| Roster pipeline + 150 Boki | ~18 (3 tools + ~15 content at about half a day per Boki with review) |
| Character art pass 2 | 4-6 |
| Wave 0 merges and groundwork | 1.5-2 |
| **Total** | **~128-142** (Riftfall, ~6.5 of it, lands after launch) |

With four to five lanes running in parallel, that's roughly **35-40 calendar weeks** to launch
(Waves 0-6), with Riftfall and the crossover API after.

---

## 9. Biggest risks

1. **The netcode retrofit.** Moving a 5.4k-line, variable-timestep, client-owned match to a 30 Hz
   server-authoritative simulation touches nearly every system, and every feature built meanwhile
   adds more to sync. It's the longest chain in the schedule. Mitigation: N0 first, loopback tests
   from N1, a net checklist on every PR.
2. **150 Boki of content.** Each one needs a readable look from the top-down camera, a balanced kit,
   a voice, a habitat and a dex entry; the procedural model builders have to stretch to 150 distinct
   creatures. Mitigation: the generic body kit and scaffold tool in R1, Phase 3/4 automation,
   batches of 10 with owner review.
3. **An open-source client in a game with persistent, tradable value.** Every byte the client sends
   is suspect. Server authority over loot, Boki and gems is non-negotiable before Boki-risk tiers or
   trading go online; offline saves can never feed the online economy.
4. **Collectible trust and legal exposure.** One dupe or broken cap destroys edition value; trading
   with real-world value pulls in gambling and consumer-protection law. Mitigation: careful server
   module review, published caps, no paid randomness, no cash-out, legal review before trading.
5. **Population.** A ~150-person community spread over modes, tiers, maps and regions means empty
   queues. Mitigation: bots backfill every match, launch trios + duos only, one map per queue at a
   time, two regions.
6. **Server cost** for a free, GPL game with dedicated 20-player servers. Measure in N2 and decide the
   subscription's timing early.
7. **Licensing.** GPL plus proprietary platform SDKs needs an exception now; audio and art must stay
   CC0 or original; community designs need a contributor agreement.
8. **Owner bandwidth.** Six lanes produce more check-ins than one person can review. Keep milestones
   small and each wave's review list short.

---

## 10. Decisions the owner needs to make

| Decision | Recommendation |
|---|---|
| Hosting and backend | Nakama for accounts, parties and storage; dedicated Godot servers on fixed VMs in NA-East and EU-West |
| Steam | yes for distribution later, with the GPL exception in place first; no Steam Market |
| Subscription contents and timing | cosmetic lane on the season track, extra home decor and cloud island slots; never Boki, gems, XP boosts or editions; start once server costs are measured (after N2) |
| Solos at launch | no; trios + duos, solos when queues allow |
| Rarity and power | case by case; tier scaling in T0-T1, full power in T2+, disallow only flagged outliers (§7d) |
| First edition caps | small (50-200), sized to the community, published per release |
| Real-money trading | no; gems only, no purchase, no cash-out |
| Map order | Underbough, then Saltglass, then Riftfall after launch |
| Telemetry backend | PostHog (dedicated project, EU, anonymous) first, self-hosted later if needed |
| When to rename code ids to Boki | at the Phase 6 format freeze |
| Age gate | yes, with trading off for under-age accounts |
