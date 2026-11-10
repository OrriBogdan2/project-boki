# Handoff: rolling 30-minute sessions (branch `rolling`)

Status: **ready to merge** (Agent C, Nov 1). Pushed to `origin/rolling`; merged with `origin/main` at sync56
(Net 0.8.0, Hollow Crown default map, health budgets). The feature stays behind the `rolling` option, off by
default. Net.VERSION is unchanged (0.8.0): rolling adds no sync, so the 0.8.3 slot is not used.

## After the sync58 merge (e5f25ec, Net 0.10.0)

- Merged `origin/main` with no conflicts, first sync58 (e5f25ec), then sync59 (fcc3745, mergeforms, Net 0.11.0). Net.VERSION stays 0.11.0 (rolling adds no sync; main's shape kept). No reserved file touched.
- Late joiners need nothing extra: `Rolling.populate_before` and the wave landings go through `Match.make_bot` / `make_hunter`, and `Kin` now starts `state = "active"`, `cmd = "follow"` for every owned Boki. New assertion in `--rolling-check` ("late joiners and the earlier arrivals start with their active Boki following, none on a shoulder", 35 Boki) pins it, so a regression to shoulder-start shows up here.
- Checks (all 0 failures, no SCRIPT ERROR): `--rolling-check` (62 assertions), `--check`, `--teammate-check`, `--boki-system-check`, `--bot-sanity-check`; `health.py --strict` OK; `gen_wiki.py --check` 15 unchanged.
- Re-run on the sync59 tree: rolling-check, check, teammate, boki-system, bot-sanity all 0 failures, no SCRIPT ERROR.
- `--simtest --seed=5`: "team wiped" (sim 157 s on sync59; 56 s on sync58). Plain sync58 gave the identical 56 s result, and "team wiped" is the known main result, so it is main, not rolling (rolling is off in the simtest).

## After the sync56 merge

- Merge conflicts were only in `main.gd` (the `--rolling-shot=` no-save list, and the `--demo-match` / `--match`
  branch order); both sides kept.
- **Map:** the default expedition map is now the Hollow Crown. The wide-map ring is written for Skyreach's island
  ids, so a rolling session builds **the wide Skyreach** (`WideLayout.pick`) unless `--map=` / `opts.map` names a map
  (then that map is used as it is, un-widened). `opts.narrow` gives plain Skyreach. Widening the Hollow Crown needs
  its own ring (a follow-up if the owner wants rolling on it).
- **Health budgets:** the merge pushed `match.gd` and `world.gd` over budget. The wide-map builder moved to
  `scripts/match/wide_layout.gd` (`class_name WideLayout`), `bot_time_left` / `bot_past` / `board()` moved into
  `rolling.gd`. Net effect against main: `match.gd` -20 lines, `world.gd` 0. `health.py --strict` is OK.
- **sync57 (e85193d, Net 0.9.0) merged too**, cleanly. Net.VERSION stays 0.9.0 (no sync change; the 0.9.3 slot is
  unused). `match.gd` is 6943 / 6950 lines.
- **Checks on the sync57 tree** (all 0 failures, no SCRIPT ERROR): rolling (61), check, mantle, drop, extract, boss,
  duel, revive, economy, home-build, arena, archetype, airheal, record, obstacle, bot-sanity, blight, raid, teammate,
  farm-start, abyss, kit-combo, life, title, boki-system; `gen_wiki.py --check` (15 unchanged); `health.py --strict` OK.
- **`--simtest --seed=5`:** now ends at 30 s, "team wiped". The old 205 s hatch-extract baseline no longer holds, but
  that is main, not rolling: pristine `origin/main` gives the identical result (30 s, team wiped; Hollow Crown default
  map and the Boki system changed the run). Rolling is off in the simtest, so the two match exactly.
- `rolling-check` fixes for the new world: the default-match assertion follows `World.layout_for_tier`; the bounty
  test clears the rival's cooldown (a bot fight before it can claim one off them); camp respawn counts >= 1; a
  player already finished off by the autopilot is the match result at 30:00.

## Branch history

- `7486d43`: branch point (`blight`, Net.VERSION 0.5.0).
- `d12b9e1`: `main` merged in (sync48+). It merged cleanly.
- WIP commit "WIP: rolling handoff": everything below. There are no earlier commits of this work.
- Agent C (Nov 1): merged `main` twice (farmstart + abysslift, then kits4 + Net 0.6.0), committed the
  `.gd.uid` files, ran the full suite and the 30-minute sim, tuned `XP_PER_MIN` and catch-up XP, made the
  population target switchable, fixed the screenshot modes and took the shots. Details below.

## What's built

The feature is behind the match option `rolling`. The default fixed-length match is unchanged, and the
`rolling` option is off unless something turns it on. To turn it on:

- the command-line args `--rolling`, `--join-wave=N` or `--join-at=SECONDS` (the last two also set
  `rolling`);
- the expedition panel's "Fixed match" / "Rolling session" tabs, stored in `Save.d["exp_rolling"]`,
  default off.

`--rolling-demo=wave|bounty|map` with `--rolling-shot=<png>` takes screenshots.

- **`scripts/match/rolling.gd`** (new, `class_name Rolling`) runs the session:
  - **Wave schedule:** a wave at 0:00, then one every 120-180 s. No wave starts after 22:00.
  - **Your join:** you get a random wave, unless `join_wave` or `join_at` picks one.
  - **Before you join:** a model simulates the earlier waves. Squads stay 8-16 min, and each
    squad has a 3%/min chance of being wiped.
  - **Earlier arrivals:** the squads still out there are spawned as bots already on the ground. Their
    level is the floor for when they landed plus `XP_PER_MIN` for each minute since. They carry
    gems. Hunters who died before you joined leave gem and weapon drops.
  - **Picked-over map:** some chests start open and some camps start cleared. Both scale with how
    late you join.
  - **Wave launches:** each wave gets its own skyship, flying a path over the less crowded side.
    Landing spots are the least crowded spawns near that path.
  - **Level floor:** applied on landing.
  - **Catch-up XP:** applied through `Hunter.gain_xp`.
  - **Bounties:**
    - posting, clearing and a cooldown;
    - payout on knock;
    - XP for knocking a hunter who is a higher level than you;
    - bots prefer bounty targets.
  - **Session events:**
    - Cleared camps come back after 240 s if nobody is near.
    - Meteor showers come every 6 session minutes.
  - **Per-squad stay:** bots leave based on their squad's planned stay (`Match.bot_time_left`,
    `Match.bot_past`).
- **`match.gd`:**
  - New: `rolling`, `sess_t0`, `ships`, `sess_time()`, `sess_len()`, `at_sess(k)`.
  - `make_bot()` is factored out of `_spawn_hunters`. The rng call order is the same.
  - New `board()`.
  - New: `ship_of(h)` and `ship_pos_of(s)`.
  - `plan_jump`, `ship_jump` and `_update_one_ship` now handle several ships.
  - Hooks call into Rolling from: plan in `_start`, the spawn, `_spawn_mobs` (`note_camp`),
    `after_setup`, `step` (`tick`/`demo`), `on_drop_landed`, `knock`, the meteor and event timing,
    `_check_last` and `_finish` (`r["rolling"]`).
  - `opts.sim_keep` stops the match from ending when the player is done.
- **Map:** `World.widen_layout()` builds the rolling-only map `skyreach_wide`:
  - Skyreach is shifted by 36 tiles, giving a 288-tile map (1.78x the area).
  - 8 calm outer islands are added (danger 0). Each has a bridge to its corner island and a wind
    road to its landing.
  - There are more cache and rare-Boki spawn points.
  - `opts.narrow` keeps the old map.
- **Session clock:** the match clock (`Match.time`) starts at 0 when your wave sets off.
  `sess_time() = sess_t0 + time`, and `length = 1800 - sess_t0`. As a result:
  - Exits open and close via `at_sess()`. In rolling, the docks close at 84, 89, 93 and 95% of the
    session.
  - Glimmer and Warden use `at_sess()`.
  - The Blight's map-wide strength uses `sess_time()`.
- **Soft landing:** `Bot.fresh` reads the per-hunter `landed_t` meta. `BlightDir.land_at` is per team,
  and the earlier squads get their real landing times.
- **HUD (`hud.gd`, `full_map.gd`):**
  - A session row under the clock: session clock, "JOINED mm:ss", next drop wave / "WAVE INCOMING ·
    N SQUADS" / "NO MORE DROPS", lobby median level, "BOUNTY ON YOU".
  - The other waves' skyships, in amber, on the minimap and the full map.
  - Bounty markers on nameplates, the minimap (with edge arrows) and the full map.
  - The loading screen's mode line.
- **`DropSquad`:** new `add_squad()`. Ship heading comes from `ship_of()`. Grounded squads are
  skipped at planning and depart.
- **`main.gd`:** the args above, plus `--rolling-check` and `--rolling-sim` (`tools/rolling_check.gd`,
  `tools/rolling_sim.gd`).

## Net / sync

- **No sync changes.** Net.VERSION is main's **0.6.0** (main took 0.6.0 for Blight + kits4 Hex; rolling
  adds nothing to the sync shape, so it keeps main's number).
- Rolling is forced off when `opts.net` exists (`Rolling.enabled`), so online play only gets the fixed
  match.
- Bounties and levels are computed locally.
- The roadmap's next step is late-join snapshots. Bump Net.VERSION past main's when rolling goes online
  (the coordinator reserved 0.6.7 for a rolling sync change).

## Numbers chosen (constants at the top of rolling.gd)

| What | Value |
|---|---|
| Session length | 1800 s |
| No new waves | last 480 s (after 22:00) |
| Wave gap | 120-180 s (9-10 waves a session) |
| Wave size | The fixed format (11-08): 10 trios per session in all, shared evenly over the waves (`Rolling.wave_share`, rounding up from the opening wave), about one squad a wave; a late wave with no share flies no ship |
| Level floor | min(5, 1 + floor(sess_t / 240)). The points are auto-spent in the archetype's order, for the player too |
| Catch-up XP | **+0.3x per level under the median, capped at x1.6** (was +0.5x, x2; tuned from the sim, see below). The median is over hunters on the ground |
| Bounty | posted at ≥3 levels over the median and level ≥5; cleared once the hunter is less than 2 levels over the median; 45 s cooldown after a claim |
| Bounty payout | XP 80 + 40/level of the gap; 4 + 2×gap gems and a valuable |
| Gap-knock XP | 25 per level |
| Bot stay | 8-16 min. They leave past 30% of that if they have more than 40 gems |
| Earlier squads | wiped at 3%/min; each squadmate has an 18% chance of having died |
| `XP_PER_MIN` | **200** (was a 105 guess). The sim measured a median 243 XP/min for bots on the map, 12.8% of it catch-up |
| Camps | come back after 240 s |
| Meteor showers | every 360 s |

## The 30-minute sim and the tuning

`--rolling-sim --seed=5` (trios, you on autopilot in wave 0), on the merged tree. Log:
`/home/claude/shots/C/rolling_sim_seed5_run1.log`. 0 failures; 1801 s of session took 4850 s of wall time
(0.37x real time on the shared 2-CPU box; each sim minute 1.6-3.9 min).

- **Waves:** 9 waves (0:00 to 19:56), every one launched on time (+0.00-0.02 s); none after 22:00; nobody
  left at 30:00. Each wave brought 4 trios (12 hunters), because the map never filled up.
- **Population:** 108 hunters over the session; **on the map at once 7-21, median 14** (target 24-40).
  Waves are sized to fill the map, but hunters go out fast: mean stay 1-4 minutes, 12 extracted, 96 out
  (51 finished off, 14 team wipes, 13 bled out, 9 executed, 9 abyss). The Blight knocked only 4; almost
  all of it is hunters fighting hunters. That's bot aggression on a crowded map, not the rolling logic,
  so I didn't change it here (see Open questions).
- **Bot XP:** median **243 XP/min** on the map (n=37), 12.8% of all XP from catch-up. `XP_PER_MIN`
  (the earlier arrivals' head start) was a 105 guess; it's now **200** (243 less the catch-up share,
  a little lower for a picked-over map).
- **Bounties:** 54 posted, 19 claimed; level-gap knock XP 2025 in all; 86 camp respawns; 4 meteor showers.

**Catch-up XP for late joiners** (`--join-wave=5`, joins at 11:56, `--sim-minutes=24`). The sim prints
"level minus lobby median" per wave at 0/2/4/6 minutes after landing.

| | before (x1.5/level, cap x2) | after (x1.3/level, cap x1.6) |
|---|---|---|
| Earlier arrivals at your join | 31, levels 4-10 | 31, levels 4-10 (same plan) |
| Your wave (11:56), gap at 0/2/4 min | -3.5 / +0.0 / +2.0 | -1.3 / +3.0 / - |
| Wave 6 (14:40), gap at 0/2/4/6 min | -4.5 / -0.8 / +1.3 / +3.0 | -1.8 / +0.2 / +3.0 / - |
| Waves from 10:00, gap 6 min after landing | +1.75 | n/a (no squad lasted 6 min) |
| Catch-up share of all XP | 21.8% | **11.9%** |
| Bot XP/min on the map (median) | 287 | 283 |

Before, catch-up was a fifth of all XP and a squad 3-4 levels under the lobby was level with it after 2
minutes. After, catch-up is half as big (11.9% of XP). Late squads still pass the median within 2-4
minutes, but that now comes from base XP (bots make ~280 XP/min, about a level a minute at levels 4-7),
not from catch-up. The bots are not deterministic between runs (landing gaps differ: -3.5 vs -1.3 for the
same wave), so read these as rough. If late joiners still level too fast in playtests, the next lever is
monster XP, not catch-up. Logs:
`/home/claude/shots/C/rolling_sim_seed5_join5_before.log`, `..._after.log`.

Fixed along the way:
- The sim ran out of memory (5 GB, OOM-killed at 16:00): it stepped the match with no frames in between,
  so nothing `queue_free`d was ever freed. It now yields a frame every 120 steps (main.gd holds it in a
  meta, like the check). RSS now stays at 0.9-1.6 GB over the 30 minutes.
- The level floor only applied through `Match.on_drop_landed`. A drop ended early (an ability mid-air, a
  dip below the islands) skipped it, so one hunter in a wave landed at level 1. `Rolling.tick` now applies
  the floor to anyone down on the ground who hasn't had it. (Earlier arrivals are marked as done.)
- A wave counted as "incoming" only until its ship had passed; it now stays incoming until its squads are
  down, so the HUD's WAVE INCOMING lasts the whole drop.

## Checks (merged tree)

| Check | Failures | Notes |
|---|---|---|
| `--check` | 0 | |
| `--rolling-check` | 0 | 61 checks (2 new: the POP_MODE reading, and the "total" mode's 24-40 over a session: 27-39 over 20 seeds) |
| `--simtest --seed=5` | n/a | old tree: hatch at 205 s. After sync56/57: team wiped at 30 s, identical to pristine main |
| `--rolling-sim --seed=5` | 0 | full 30 minutes, see above |
| mantle, drop, extract, boss, duel, revive, economy, home-build, arena, archetype, airheal, record, obstacle, bot-sanity, blight, raid, farm-start, abyss | 0 each | no SCRIPT ERROR |

Run on the tree after the first main merge; after the second (kits4) merge `--rolling-check` was re-run.

## Screenshots

`--join-wave=4 --squad=3 --seed=5 --rolling-demo=<mode> --rolling-shot=<png>` (needs xvfb):

- `rolling_wave.png`: a drop wave coming in; the session row shows SESSION / JOINED / WAVE INCOMING.
- `rolling_bounty.png`: a rival with a bounty a few metres away (nameplate marker), "Bounty on ..." in the
  feed, the session row with NEXT DROP WAVE and LOBBY LV.
- `rolling_map.png`: the full map with a DROP WAVE ship and its route, and two bounty markers (LV 8, LV 9); the eight calm ring islands (Ashen Terrace, Rimefold, Brightwater Shoal,
  Saltwind Shelf, Driftmoor, Kestrel Rise, Hollowmere, Cinderfall Ledge) frame the wide map.

Demo fixes: `--rolling-shot` now counts as a screenshot run (no save writes, no fades), the demo forces a
clear sky, and the wave shot waits until the squad is mid-descent and stands under it. The HUD's LOBBY LV
gives way when the wave line needs the room (it overlapped WAVE INCOMING).

## Open questions for the owner

1. *(Settled 11-08: 10 trios in total over the session; `POP`, `POP_MODE` and `--rolling-pop` are gone.)* **"24-40 hunters": on the map at once, or in total over the session?** The code reads it as at once
   (the roadmap's wording). One constant switches it: `Rolling.POP_MODE = "total"` (or
   `--rolling-pop=total` per match).
2. With bots, the map holds 7-21 hunters at once, not 24-40, because they knock each other out in 1-4
   minutes. Bigger waves or calmer bots would raise it; that's a bot-behaviour call, left as is.

## What's left

1. Late-join snapshots in the netcode (rolling is offline-only until then).
2. Optional, not done:
   - "exits start closing" is only the dock-closing schedule;
   - the Walker isn't in the code;
   - the results screen doesn't show joined/left times yet (`r["rolling"]` is there).

## Gotchas

- **Checks run as RefCounted tool objects.** A RefCounted is freed at its first await unless something
  holds it, and the coroutine silently dies (the process then idles until the timeout). main.gd holds the
  rolling check and the rolling sim in metas; the sim awaits frames, the check doesn't.
- A long headless sim needs frames: `queue_free` only frees between frames.
- The `godot` queue wrapper's slots aren't FIFO and `timeout` counts the wait, so use long timeouts.
- The match clock starts at your join, so anything from before you joined is negative
  (`landed_t`, `land_at`, `cleared_at`).
- The check skips the clock ahead with `m.time = ...`. When that passes several planned waves, they
  all launch at once (that's the intended catch-up).
- The bot names list is shared via `Match._bot_names` / `Rolling._names`.
- Team ids:
  - your wave is 0..n-1;
  - earlier arrivals and later waves count up from n;
  - `Data.TEAM_COLORS` is indexed `% size`.
- The machine is heavily shared. Under load the wide map plus ~40 hunters runs at about 1x real time
  or slower.
