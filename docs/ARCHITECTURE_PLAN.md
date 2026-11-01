# Project Boki: server-authoritative architecture and licensing plan

Status: **proposal for owner review (Oct 31 2026). Nothing here is built yet.** Each phase ends with a
check-in before the next starts. Written after auditing main at c8abef9. Not legal advice: the
licensing parts need a lawyer's read before anything is published under new terms.

## 1. Audit: where things stand today

### Netcode
- `scripts/core/net.gd` (149 lines) is the only multiplayer code. It runs **only in the web build**,
  over the claude.ai artifact "room" or a BroadcastChannel between browser tabs. Desktop builds
  (the Windows/Mac exports you play) have **no online play at all**.
- Model: **peer-to-peer, owner-authoritative**. Each player's game simulates its own hunter and Boki
  and broadcasts snapshots; the "host" player's game simulates monsters, bots and loot; a player
  who hits something sends the hit to its owner, who applies it.
- So today **nothing is server-authoritative**. A modified client can set its own health, damage,
  position, cooldowns, catches and loot. There is no server, no validation, no prediction or lag
  compensation (a remote hunter is snapped/smoothed from 0.15 s snapshots).
- Match code reads the local save during a match (`Save.d` is used ~23 times in match.gd: loadout,
  roster, items) and writes results back to it on extraction.

### Ownership and persistence
- Everything a player owns (Boki roster, gems, items, buildings, IVs, provenance-to-be) lives in a
  **local JSON save** on the player's machine (`scripts/core/save.gd`). The client is the source of
  truth for ownership.
- Social features (guilds, market, island visits, gifts in `scripts/core/social.gd`) are backed by
  the web page's shared store, are web-only, and already treat reads as untrusted. Nothing
  server-side exists.

### Code shape
- The simulation and the presentation are interleaved: `match.gd` (5,990 lines), `hunter.gd`
  (2,804), `kin.gd` (992) and `bot.gd` (821) each mix game rules, rendering, audio and UI calls.
  The fixed step (`Match.DT`, `m.step`) is already separate from rendering, which helps.
- Randomness mixes a per-match RNG with Godot's global RNG (`randf`, `randi`), so the simulation is
  not reproducible across machines yet.
- Content and rules are already data: Boki definitions (content/kin/*.json), the ability grammar and
  validator (scripts/kin/*), mutations, rules JSON. These are naturally "shared".

### Licensing and contributors
- Whole repo is **GPL-3.0** (`LICENSE`), public at OrriBogdan2/project-boki.
- Git history shows **no outside contributors**: every commit is by you (Orri Bogdan / OrriBogdan2)
  or by Claude sessions you ran. You hold whatever rights exist in the code, so you can license
  future versions however you choose. Caveat for the lawyer: how copyright applies to AI-written
  code is unsettled; that mostly affects how strongly anyone (you included) can enforce the GPL or a
  stricter asset license on AI-generated parts.
- **Assets:**
  - Hunters, Boki, gear, bosses and most props are **procedural: built in GDScript code**
    (`models.gd`, `kin_models.gd`, `hero_gear.gd`, `boss_models.gd`...). Legally they're code, and
    they're already published under GPL.
  - Trees, rocks, ruins, chests, skeleton monsters: **CC0 KayKit packs** in `art/vendor/` (5.4 MB).
    CC0 can't be restricted; anyone can get the originals anyway.
  - Audio (130 files, 7.4 MB) and music are **synthesized by our own scripts** (`tools/gen_sfx.py`,
    `gen_music.py`, `compose.py`, `synth.gd`). The scripts are GPL; the generated files are ours.
  - Fonts (Lilita One, Rubik, Noto Symbols) are **SIL OFL** and must stay OFL.
  - `art/splash.png` (rebranded logo) is ours.

## 2. Principles (from the owner's brief)
1. Every client may be hacked. Clients send **inputs only**; the server decides every outcome.
2. Responsiveness through client-side prediction and lag compensation, always corrected by the server.
3. Ownership (accounts, Boki, inventory, trades, limited-edition supply) lives only in a server-side
   database we control. The client never stores anything that counts as ownership.
4. Every request is validated against the rules; impossible ones are rejected and logged.
5. Built for ~100 concurrent players first (2-3 rolling 30-minute sessions of 24-40), without blocking
   scale later.
6. Forks are welcome under the GPL, but no client (ours included) is trusted, and nothing from a fork
   reaches our accounts or economy.

## 3. What can and can't be private

| Part | Today | Proposal |
| --- | --- | --- |
| Client (rendering, UI, input, audio playback, prediction) | public GPL | stays public GPL |
| Shared simulation rules (movement, combat, abilities, Boki grammar, validator, content data) | public GPL | stays public GPL: the client needs the same rules to predict, and community Boki design depends on it |
| Authoritative match server (session runner, validation, bots, loot rolls) | public GPL (all sim code is) | **recommend public** (a thin headless entry over the shared sim). It's already almost entirely published, and keeping it public lets the community run LAN/community servers. Security comes from authority, not secrecy |
| New backend services: accounts, auth, inventory/ownership DB, trading, limited-edition supply, matchmaking/session allocation, telemetry pipeline, anti-cheat heuristics, admin tools | don't exist | **private repo you own** (e.g. `OrriBogdan2/project-boki-backend`). New code, written fresh, never published under GPL |
| Anything already published under GPL | public | stays GPL forever in those versions; you can still change the license of *new* versions you write |

Why the match server should probably stay public: hiding it gives little protection (the shared
rules it runs are public either way, and a hacked client can't do anything the server doesn't
accept), while keeping it public costs nothing and supports LAN/offline play. The secrets worth
keeping private are operational: credentials, the database, the economy and trading logic, cheat
detection thresholds. If you'd rather keep the match server private too, that's possible for new
code (GPL-3.0 only requires source when you distribute binaries, and you'd never distribute the
server), but the shared rules it imports stay public.

## 4. Proposed structure

```
project-boki/               (public, GPL-3.0 code)
  shared/                   rules both sides run; no rendering, no Save, no global RNG
    sim/                    match state, fixed-step tick, entities, movement, combat, abilities
    kin/                    Boki grammar, validator, KinExec rules (today scripts/kin)
    data/                   Data, content loaders, rules tables
    net/                    protocol: message schemas, input packets, snapshot encoding, versions
  client/                   everything a player's machine needs
    view/                   models, animation, fx, camera (today models.gd, *_models.gd, fx.gd...)
    ui/  home/  audio/  input/
    net/                    connection, prediction, reconciliation, interpolation
  server/                   headless dedicated server (public)
    main_server.gd          `--server` entry, no rendering, no audio
    session/                rolling 30-min sessions, drop waves, join-in-progress
    authority/              input validation, lag-compensated hit checks, server RNG
    backend_client/         talks to the private backend with server credentials
  content/                  Boki and rules data (public; community-editable)
  assets/                   art, audio, music, splash  -> under LICENSE-ASSETS (see §6)
  tools/  tests/  docs/
  LICENSE (GPL-3.0, code)   LICENSE-ASSETS   CONTRIBUTING.md   CLA.md   NOTICE

project-boki-backend/       (private, yours)
  services/ api: accounts, profiles, Boki ownership ledger, inventory, trades, editions/supply,
            sessions/matchmaking, telemetry intake
  db/       Postgres schema + migrations
  ops/      deployment for 1-2 VMs, server keys, dashboards
```

The Godot project keeps one `project.godot`; the server export uses a "dedicated server" export
preset that strips `client/` and `assets/`.

## 5. Phased plan (check-in after each)

**Phase 0: Decisions and licensing groundwork (no gameplay changes)**
- Confirm: public vs private match server (§3), backend language/hosting, asset license choice (§6).
- Add `LICENSE-ASSETS`, `NOTICE` (what is under which license, CC0/OFL exceptions), CLA + CONTRIBUTING
  update, move art/audio/music/splash into `assets/` with the license header.
- Lawyer review of LICENSE-ASSETS and the CLA before they apply to anything new.
- *You can test:* nothing in-game changes; you review the license files and the published notice.

**Phase 1: Folder split without behaviour change**
- Move files into `shared/`, `client/`, `server/` (mechanical moves + path updates); add the
  `--server` headless entry that runs a full bot-only session with no rendering.
- *You can test:* the game plays exactly as before; a headless server process runs a bot session and
  prints a summary. All existing checks pass.

**Phase 2: Pull the simulation away from presentation**
- Make `shared/sim` pure: match state + fixed tick with no Nodes for visuals, no `Save` reads (the
  loadout is passed in), one seeded RNG per match (no global RNG), events emitted for the view to
  draw (hits, deaths, sounds) instead of the sim calling fx/sfx directly.
- The offline game becomes "a local server + a client in one process", the same code path as online.
- Rolling-session model (ROADMAP §0.6) built here offline with bot waves.
- *You can test:* offline play identical (or better); a headless 30-minute session at 30 Hz on one
  core with a perf report; replays (same seed + inputs = same result).

**Phase 3: Dedicated server and input-only clients**
- ENet (UDP) server; clients send input packets only (move, aim, fire, ability, dash, jump/glide,
  interact, Boki send/recall/ability, pings) with sequence numbers.
- Server snapshots with delta compression and interest management (only what's near you or in your
  vision); client interpolation for everything you don't control; join-in-progress snapshot.
- *You can test:* run a server on your PC (or a VM) and join with two clients (PC + Mac); play a
  session together with bots; join mid-session.

**Phase 4: Feel: prediction, reconciliation, lag compensation**
- Client predicts its own movement, dashes, glides, jumps and its own cooldown UI; reconciles on
  server correction with smoothing.
- Server rewinds hitboxes to the shooter's view time (capped, e.g. 200 ms) for hitscan and projectile
  spawn; abilities predicted cosmetically, outcomes always from the server.
- Built-in latency/loss simulator for testing.
- *You can test:* side-by-side feel at 0/80/150 ms simulated latency vs offline; the SUPERVIVE-feel bar.

**Phase 5: Validation and cheat resistance**
- Server checks every input: rates, cooldowns, resources, movement speed/teleport, line of sight and
  range for hits and interactions, inventory contents, catch/loot/extract conditions; server-only
  RNG for loot, IVs, mutations, shinies.
- A "hacked client" test bot that sends impossible inputs (speed hacks, instant cooldowns, fake hits,
  looting through walls, extracting from afar) and a check that every one is rejected and logged.
- *You can test:* run the cheat bot against a server and read the rejection log; normal play unaffected.

**Phase 6: Backend and ownership (private repo)**
- Postgres + one small service: tester accounts (name + invite code first), profiles, Boki ownership
  ledger (unique ids, provenance, event log from Wave 0), inventory, match-result commits.
- Match servers authenticate with server keys; extraction results are committed transactionally by
  the server (the client never reports what it got). Online profile is server-side; the local save
  becomes a cache plus a separate offline profile that never imports into online.
- Trading and limited-edition supply as server transactions (later in this phase or after the first
  playtest).
- *You can test:* log in with an invite code, extract a Boki, quit, log in on the other machine and
  see it; try to edit the local save and see it change nothing online.

**Phase 7: Official launcher and distribution**
- Official signed builds (Windows/Mac) that point at our servers by default, with version/protocol
  checks and auto-update; a small launcher if needed (or Steam Playtest later).
- Fork policy enforced by design: servers never have a "trusted client" mode; protocol versioned; any
  client that speaks the protocol gets exactly the same (zero) trust; community servers (if allowed)
  get no credentials to the official backend, so nothing from them reaches official accounts.
- *You can test:* install the official build, join the playtest servers; a modified build connects
  but can't do anything the official one can't.

**Phase 8: Playtest hardening**
- 40-client load test, telemetry and crash reports, ops for 1-2 VMs, runbook.
- *You can test:* a dry-run playtest session with bots + friends before inviting ex-SUPERVIVE players.

## 6. Assets license proposal
- Code stays **GPL-3.0**. Art, audio, music, logo and splash move under **a separate assets license**
  that allows use with official/unmodified builds and community content made for the official game,
  but doesn't allow redistribution in forks or other projects (a custom "Project Boki Asset License",
  or CC BY-NC-ND 4.0 as a simpler stand-in). Forks then ship their own art.
- **Stays as it is no matter what:** CC0 KayKit models (anyone can use them; the originals are free),
  OFL fonts, and every asset already published in GPL versions of the repo (anyone can keep using
  those old versions under GPL).
- **Can't be covered by an asset license:** the procedural models (hunters, Boki, gear, bosses) are
  GDScript code already published as GPL. Future art you want protected needs to be authored as asset
  files (meshes, textures) rather than code.
- **CONTRIBUTING + CLA:** contributors agree code is GPL-3.0 and assets are under LICENSE-ASSETS, and
  grant you the right to relicense their contributions (so you can keep the split and change terms
  later). Without a CLA, outside code contributions stay GPL-only.

## 7. Conflicts with what's already built
1. **Local saves own everything.** Roster, gems, items, buildings and Boki ownership are client-side.
   Online play needs server-side profiles; offline progress can't carry into the online economy.
   Existing testers' saves would stay offline-only (or get a one-time, server-validated import for
   the closed playtest only).
2. **The current netcode is the opposite model** (P2P, owner-authoritative, web-only). It gets
   replaced, not extended.
3. **Simulation is mixed with visuals** in the four biggest files; Phase 1-2 are a large refactor that
   touches the same files the in-flight branches touch (archetypes, Boki uniqueness, parkour/wardrobe,
   landing perf, lair exits). Plan: land those branches first, then freeze features during Phases 1-2.
4. **Global RNG and seeded tests:** moving to one server RNG changes every seeded test's outcome once;
   the checks get re-baselined in Phase 2.
5. **Procedural art is code**, so it stays GPL (see §6).
6. **Web build features** (artifact room multiplayer, shared-store guilds/market, Claude-backed Boki
   chat) rely on the web page. Guilds/market/trading move to the backend; Boki chat stays a client
   feature (cosmetic, no ownership).
7. **ROADMAP §0.5/§1** already planned dedicated headless servers and a playtest MVP; this plan
   supersedes the netcode parts and adds the backend, licensing and launcher.
8. **Another session:** if the other instance is already building multiplayer (e.g. a `net` branch),
   we should pick one owner for Phases 1-5 so two sessions don't refactor the same files at once.
