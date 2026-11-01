# Handoff: rolling 30-minute sessions (branch `rolling`)

Status: **work in progress**, committed as "WIP: rolling handoff". Not pushed, not merged.

## Branch history

- `7486d43`: branch point (`blight`, Net.VERSION 0.5.0).
- `d12b9e1`: `main` merged in (sync48+). It merged cleanly.
- WIP commit "WIP: rolling handoff": everything below. There are no earlier commits of this work.

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

- **No sync changes.** Net.VERSION stays 0.5.0.
- Rolling is forced off when `opts.net` exists (`Rolling.enabled`), so online play only gets the fixed
  match.
- Bounties and levels are computed locally.
- The roadmap's next step is late-join snapshots. Bump to 0.6.0 when rolling goes online.

## Numbers chosen (constants at the top of rolling.gd)

| What | Value |
|---|---|
| Session length | 1800 s |
| No new waves | last 480 s (after 22:00) |
| Wave gap | 120-180 s (9-10 waves a session) |
| Wave size | 6-12 hunters: 2-4 trios, 3-6 duos or 6-12 solos. The fuller the map, the smaller the wave (`POP.y - 4 - pop`, clamped) |
| Population target | 24-40 hunters on the map at once (the roadmap's "at any moment"; the brief said "24-40 over the session", so the owner should confirm). The model gives ~30 hunters out there at about 15:00 (17-36) |
| Level floor | min(5, 1 + floor(sess_t / 240)). The points are auto-spent in the archetype's order, for the player too |
| Catch-up XP | +0.5x per level under the median, capped at x2. The median is over hunters on the ground |
| Bounty | posted at ≥3 levels over the median and level ≥5; cleared once the hunter is less than 2 levels over the median; 45 s cooldown after a claim |
| Bounty payout | XP 80 + 40/level of the gap; 4 + 2×gap gems and a valuable |
| Gap-knock XP | 25 per level |
| Bot stay | 8-16 min. They leave past 30% of that if they have more than 40 gems |
| Earlier squads | wiped at 3%/min; each squadmate has an 18% chance of having died |
| `XP_PER_MIN` | 105. This is a guess; the sim is meant to measure it |
| Camps | come back after 240 s |
| Meteor showers | every 360 s |

## Checks right now

- `--check`: **0 failures** (it covers scripts/ only).
- `--rolling-check`: **59/59 ok, 0 failures, no SCRIPT ERROR** (log was /tmp/rc2.log). It covers:
  - the schedule over 40 seeds;
  - the cut-off;
  - a join at wave 4: the clock, the length, the wide map, the ring islands and links, 27 earlier
    arrivals at their floors, the picked-over map, the Blight's per-squad `land_at`;
  - landing at the floor with abilities spent, the soft landing (fresh grace, Blight 0.06 vs 0.55);
  - the next wave launching exactly on time over the quiet side and landing at its floor;
  - catch-up XP: x2, x1.5, x1;
  - the median;
  - a bounty posted, claimed, paid out (+430 XP, 12 gems + treasure) and on cooldown;
  - a camp coming back;
  - meteors;
  - no joins after the cut-off;
  - 30:00 ending everyone except the extracted;
  - the default match untouched.
- `--rolling-sim`: **not run yet.** Its first run died on a GDScript type-inference parse error
  (`floor()` → `floorf()`), which is now fixed. `--check-only -s` can't parse tools because autoloads
  (`Save`) aren't loaded there, so to check it, just run it. Expect ~1x real time or slower with
  40 hunters, so a full session is 30-60 min wall time. Run it in the background with
  `--rolling-sim --seed=5`. `--sim-minutes=N` stops early.
- **Not yet re-run after these changes:** `--blight-check`, `--raid-check`, `--archetype-check`,
  `--drop-check`, `--extract-check`, `--boss-check`, `--duel-check`, `--bot-sanity-check`,
  `--economy-check`, `--simtest --seed=5`.
  - The baseline `--simtest --seed=5` on the merged tree before any change extracted by hatch at 205 s:
    `SIMTEST done ... sim time 205, result { "extracted": true, "how": "hatch", "where": "Rift Hatch" }`
    (/home/claude/shots/rolling_base_simtest5.log). Compare against it. `make_bot` keeps the rng order,
    and the non-rolling paths are written to be identical (`at_sess(k) == k*length`,
    `bot_past == time > length*k`, ship `t0 = 0`). It still needs confirming.
  - Script `/home/claude/rolling_checks.sh <args...>` runs a list of checks with logs in /tmp/rl_logs.
- **Screenshots: not taken yet.** `/home/claude/rolling_shots.sh wave bounty map` writes to
  /home/claude/shots/rolling/. The `Rolling.demo()` modes were written but never run, so expect to
  debug them.

## What's left

1. Run `--rolling-sim` (full 30 min). Check the population band, waves on time, extracts and deaths,
   and the measured bot XP/min, then tune `XP_PER_MIN` to it. Check that the bot stay of 8-16 min
   gives reasonable extraction.
2. Run the whole required suite (list above) plus `--simtest --seed=5`, and compare with the baseline.
3. Take the screenshots (wave drop, HUD with the session clock, bounty marker, full map).
4. Generate the `.gd.uid` files for the 3 new scripts (`--headless --import` or the editor). The
   global class cache in my worktree's `.godot` was hand-edited to add `Rolling`. A fresh `.godot`
   copied from another worktree **won't know `class_name Rolling`** until it's re-imported, and
   then match.gd fails to compile.
5. Optional, not done:
   - "exits start closing" is only the dock-closing schedule;
   - the Walker isn't in the code;
   - the results screen doesn't show joined/left times yet (`r["rolling"]` is there).

## Gotchas

- **Checks run as RefCounted tool objects: don't `await` in them.** The RefCounted is freed at the
  first await and the coroutine silently dies, and the process then idles until the timeout. That's
  why main.gd holds the rolling check in a meta and the check has no awaits.
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
