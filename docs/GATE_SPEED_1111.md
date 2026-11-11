# Gate speed and flakes (2026-11-11)

The gate is `suite-fast.sh` (6 lanes) called by `merge-candidate.sh` (cron), with `w2-dispatch` for the
second box and the `godot` wrapper. Base: `origin/ext/release-integ-0245` at 92df78ce4. Game-repo
changes are on `ext/gate-speed-1111`. Tool changes are in `docs/GATE_SPEED_1111.patch` and are NOT
installed (section 5).

## 1. Where the gate's time goes

`~/suite-cache/durations.tsv`, 2026-11-07 to 11-11: 5193 check runs, 400.1 h of lane time.

| what | runs | hours | share |
|---|---|---|---|
| runs that hit the 1200 s timeout | 824 | 274.7 | 69% |
| all other runs | 4369 | 125.4 | 31% |

So the gate is slow because checks hang, not because checks are slow. Three causes:

1. **A script error kills the check's coroutine.** `quit()` is never reached and the engine idles until
   the timeout. 66 of the 77 timeouts with a saved log (86%) follow a `SCRIPT ERROR`. The extreme case
   was live at 07:17Z today: the cron candidate's merged tree had `Parse Error: Identifier "down_k" not
   declared` at `scripts/match/hunter_anim.gd:1051`, so every one of about 280 flags hung for 1200 s
   (about 15 h of lane time for one pass).
2. **Two-game net checks** (`--displace-net-check`, `--remote-anim-check`, `--online-displace-check`,
   `--revive-net-check`, `--remote-smooth-check`): 7 of the other 11 timeouts. The second game had a fixed
   600 s life, ports were fixed per check (two suites on one box collide), and a dead guest left the host
   waiting. Orphan servers, proxies and guests 14 to 46 h old were still running on the box.
3. **Box load.** During the measurement the box had load 57 to 77 on 16 cores and 3 to 11 GB of 61 GB
   free, no swap, `/tmp` on tmpfs holding 17 GB. The kernel OOM killer ended checks (exit code 137):
   `--capture-check`, `--blight-check`, `--boki-agency-check`, `--boki-follow-check` in my runs, and other
   sessions' jobq jobs. Checks with wall-clock budgets fail when the thread waits for a CPU (section 3).

Other findings:

- `w2-dispatch` turned every ssh failure (exit 255) into a fake timeout (124) at once: 254 bogus results
  per side against a dead host, each then retried on the server.
- The `godot` wrapper queue (`/tmp/godot-queue`) is held by runs that never end. Imports of other
  sessions were waiting 5 to 10 h for a slot at 08:30Z. The wrapper holds a slot with no upper time.
- `merge-candidate.sh` removes and re-creates both worktrees every run, so every run pays a cold import
  of the whole project twice. Warm import (fresh checkout plus another checkout's `.godot`): 102 s at
  load 77, 49 files re-imported.
- `scripts/match/match.gd:5231` (`_net_state`, `var e: Ent = ents_by_id.get(nid, null)`) raises
  "Trying to assign invalid previously freed instance" in the guest game of the net checks. That
  snapshot is dropped. The gate cannot see it (the guest's log is a separate file). Not fixed here
  (god file, game logic): owner of the net code.
- `--base-life-check` is red on 0.24.5 for a real reason: `rec["loose"]` is an int in `care.gd:138` and
  `garden_items.gd:333` (Unwind Tea) and a per-stat Dictionary in `stat_budget.gd:13-58`. Every toy
  finish raises `Nonexistent function 'get' in base 'int'` at `stat_budget.gd:41`. The count differs per
  run (46, 37), so the gate reports it as WORSE or FIXED at random. Needs a save-format decision.

## 2. Slow checks

Mean seconds per run from the gate's history (min to max, runs), loaded box, timeouts left out:

| flag | mean s | min to max | runs |
|---|---|---|---|
| --hunter-parity-check | 931 | 931 | 1 |
| --dash-streak-check | 868 | 607 to 1098 | 4 |
| --stretch-check | 850 | 491 to 1187 | 8 |
| --bot-sanity-check | 682 | 305 to 1097 | 31 |
| --cliff-mantle-check | 657 | 250 to 1167 | 24 |
| --revive-net-check | 579 | 260 to 1050 | 7 |
| --hitch-check | 559 | 0 to 1074 | 34 |
| --hold-pose-check | 501 | 276 to 689 | 8 |
| --perf-budget-check | 501 | 287 to 871 | 9 |
| --online-displace-check | 491 | 151 to 792 | 3 |
| --displace-net-check | 468 | 255 to 1168 | 24 |
| --practice-hero-check | 453 | 0 to 1072 | 19 |
| --teammate-check | 401 | 161 to 761 | 21 |
| --dash-flow-check | 400 | 176 to 1035 | 29 |

The spread per flag (3x to 5x) is box load, not the check. Sum of the means over 235 flags: 25352 s, so
one pass on 6 lanes is about 70 min of pure check time when nothing hangs. The suite ran the flags in
alphabetical order, so a long check that starts last sets the end of the pass. Splitting single checks
would not shorten a pass: the sum over 6 lanes is the bound, not the longest check.

Per-flag seconds of the measured passes: section 4.

## 3. Flaky checks and their roots

Measured: one full pass of the 281 flags on 0245 (`run1`), a second pass of the first 22 flags (`run6`),
one full pass on this branch (`after1`), single reruns, and the gate's own history (`durations.tsv`, saved
logs). The task asked for 5 full passes: one pass took 3.5 h on the box as it was today (load 57 to 108),
so 5 were not possible (section 8). `rc/count` below is exit code / lines with FAIL or SCRIPT ERROR.

Roots found and fixed on this branch:

| flag | how it flipped | root | fix |
|---|---|---|---|
| `--displace-net-check`, `--remote-anim-check`, `--remote-smooth-check`, `--revive-net-check`, `--online-displace-check` | displace-net: 34 of 58 gate runs hit the timeout. `run1`: 124 for four of them, remote-smooth 1/1 | (a) The relay runs inside the host game. The host builds its match in one blocking call, on a loaded box longer than ENet's 5 to 30 s without an answer, so the guest is dropped (`relay: ... left`) before the start message goes out. The guest then idles for 240 s and quits, the host waits 30 s per question for answers that never come (`own (inf, inf)`). (b) Reply caps counted wall time while the guest had no CPU. (c) Fixed ports and a fixed 600 s guest life | `CheckChild.hold` keeps the check's ENet links through a stall, replies and the wait for the guest's first state are timed on the guest's clock (`CheckClock.own_msec(pid)`), the host now asserts that the guest's state arrived and stops if not, free ports, guest tied to the host's life |
| `--revive-net-check` | `run1` 124/1, `after1` 1/6: "both games place the same beacons 6 here, -1 there", then no answer | not a flake. The check is stale: its guest sets and reports `rift_keys`, which d93439d72a removed from the game. The script errors are in the guest's log, which the gate never sees, so the host only sees silence | the guest carries a chest key, the same deathbox path (`BeltKeys`). Alone at load 56: 0/0, 22 ok, 980 s |
| `--remote-smooth-check` | 1/1 in both passes: "records to compare" | not a flake. The guest writes `drawn.json` under its own `user://`, the host reads its own. The `godot` wrapper gives every run a fresh data dir, so the host never found the file | the host passes its directory to the guest (`--rs-dir`). Alone at load 43 it compares 10681 frames for the first time, and 4 of its 5 assertions FAIL (32 snaps, 175 jerks, 7.06 m off the path, 395 ms behind): the gate will show 1 FAIL becoming 4 (below) |
| `--farm-tutorial-check` | `run1` 0/0, `after1` 1/6 ("feeding it through the home leans it" and 5 steps after it) | The check's Boki gets a random uid, `Care.ensure` seeds its likes from the uid, so about 1 run in 19 (19 foods) it hates the tutorial's food (emberberry) and refuses it | a fixed uid in the check. The game has the same hole for real players (section 8) |
| `--kin-indoors-check` | 0245 alone: 0/0, 0/0, 0/1, 0/1. `after1` 0/1 ("even with you away it is out within 45 s") | the check looked once, at second 45. The Boki comes out after 4 to 14 s and, with the home's unseeded dice, may walk back in before second 45 | the check stops at the moment it is out and fails if that takes more than 45 s. 5 runs: 0/0, out after 4.0 to 13.5 s |
| `--hob-check` | 1/3 and 0/1 | a wait capped in wall seconds for something that happens in game time (the home caps its frame step at 0.05 s, so slow frames used the cap up) | the wait counts the home's clock |
| `--depth-cue-check` | `run1` 1/1 ("3051 us" against its budget), `after1` 0/0 (575 us) | a per-call budget on the wall clock: one CPU wait inside the sample breaks it | `CheckClock` |
| `--base-demo-check` | 0/0 (`run1`), 1/1 (`run6`: "ready in 24.9 s (under 10)"), 1/1 (`after1`: 14.5 s on its own clock), 0/0 alone (7.6 s) | a 10 s budget for CPU-bound work on the wall clock | `CheckClock`: smaller, not gone (below) |
| `--hit-shape-check` | 1/1 both, "the run took 298.8 s (budget 60)" on 0245, 85.8 s here | the same | `CheckClock`: smaller, not gone |
| any check with a script error | 66 of 77 logged timeouts | the coroutine dies, `quit()` never runs | `CheckWatchdog` (`--exit-signal-check` 124 in 1200 s to rc 1 in 539 s, `--incubator-check` 124 to 1) |

`--displace-net-check` alone on this branch at load 60: the guest stays on the relay, 21 case steps ok, 0 FAIL,
then the 1200 s limit (the guest had a CPU for 336 s and waited 750 s for one). On 0245 and before
`CheckChild.hold`: every case FAIL from the first step. So it is no longer wrong under load, only slow.

`--remote-smooth-check`'s 4 FAIL were the host game's drawing, not the net code: with the host not drawing it is
green (section 9).

`CheckClock` takes out the time a thread waits for a CPU. It cannot take out that the work itself runs 2 to
4 times slower when 100 runnable threads share 16 cores (caches, memory bandwidth, hyperthreads). A CPU budget
is only deterministic on a box that is not overloaded: that is a scheduling decision for the owner (section 8).

Flaky, root known, not fixed here:

- `--base-life-check`: count 46, 37, 44 in three runs. A real bug (section 1), the count is how many toys
  finished in the run.
- Killed by the kernel for memory (rc 137), different flags each pass: `--capture-check`, `--demo-check`,
  `--gear-check`, `--heart-check`, `--kin-loss-check`, `--obstacle-check`, `--perkorb-check` (`run1`),
  `--boki-agency-check`, `--boki-system-check` (`after1`), `--blight-check`, `--boki-follow-check` (earlier
  partial runs). All green or the same count in the other pass. The tool patch waits for memory and retries 137.
- Slow checks that cross 1200 s only under load (`run1`): `--bot-sanity-check`, `--cliff-mantle-check`,
  `--dash-streak-check`, `--hitch-check`, `--hold-pose-check`, `--perf-budget-check`, `--practice-hero-check`,
  `--stretch-check`, `--title-check`, `--wallhug-check`, `--work-check`. `--hold-pose-check` was 0/0 in 993 s
  in `after1`.

Flaky, root not found (rc the same, count differs between two passes of the same code or of code that does
not touch them): `--chore-check` 25/28, `--garden-nav-check` 61/66, `--garden-visitor-check` 16/13,
`--clip-check` 18/17, `--mask-moment-check` 11/5, `--music-leave-check` 3/1, `--perf-throttle-check` 5/1.
From the gate's history, timeouts in a large
share of runs: `--title-check` 18 of 41, `--air-control-check` 17 of 31, `--hero-check` 11 of 32. Red in
most gate runs with changing counts: `--farm-start-check`, `--incubator-check`, `--home-build-check`,
`--work-check`, `--toy-check`, `--aim-near-check`.

## 4. Suite minutes before and after

Measured, both on the box as it was (load 43 to 108 on 16 cores, other sessions running), 6 lanes, 1200 s
limit per flag, the tool patch NOT in (it is not installed). Per-flag exit code, FAIL count and seconds of
both passes: `docs/GATE_SPEED_1111_times.tsv`.

| pass | flags | wall min | sum of flag s | timeouts (124) | killed for memory (137) | red |
|---|---|---|---|---|---|---|
| before: 0245 at 92df78ce4 (`run1`) | 281 | 210.6 | 71192 | 18 | 7 | 84 |
| after: this branch at 738f23951d (`after1`) | 282 | 204.2 | 70336 | 9 | 3 | 79 |

Read it with care: the 6 minutes are noise. The two passes ran under different load from other sessions, and
on this box the load sets the time (the same check took 24 s in one pass and 79 s in the other). What the repo
changes did measurably: half the timeouts (21600 s to 10800 s of lane time), and 10 flags red before are green
(`--wallhug-check`, `--practice-hero-check`, `--hold-pose-check`, `--depth-cue-check`, `--tutorial-hud-check`,
`--tutorial-fight-check`, and four that were killed for memory in `run1`). Green in `run1`, red in `after1`
(5): `--boki-agency-check` and `--boki-system-check` (killed for memory, 137), `--base-demo-check` (CPU budget
under load, also red on 0245 in `run6`), `--farm-tutorial-check` (the uid seed, fixed after the pass, 0/0
alone), `--kin-indoors-check` (red in 2 of 4 runs on 0245 alone, fixed after the pass, 5 of 5 green). None of them
runs code this branch changed.

The base branch moved to 2723685892 during the work and is merged in. On the merged tree: `--check`,
`--hob-check` (1/3 on the old base), `--farm-tutorial-check`, `--kin-indoors-check`, `--watchdog-check` all 0/0.
No full pass was run on the merged tree.

After the pass, alone on the same box: `--revive-net-check` 124/1 to 0/0 in 980 s, `--displace-net-check`
124/2 to 124/0 (no FAIL, not finished in 1200 s), `--farm-tutorial-check` 0/0 in 246 s, `--remote-smooth-check`
1/1 in 588 s to 1/4 in 352 s (it compares now, section 3).

Not measured, worked out from the numbers above (the tool patch needs the owner to install it):

- **Hang guard, `CheckWatchdog`, preflight**: 69% of the gate's lane time since 11-07 was timeouts and 86% of
  the logged ones follow a script error. Those end after about 1 to 3 minutes instead of 20: roughly half of
  all lane time. A merged tree with a parse error costs one run instead of about 15 h of lane time.
- **Covered flags**: 4 flags less, 1679 s of lane time in `run1` (1239 s in `after1`), about 4 min of a pass.
- **Longest-first order**: 210.8 to 197.8 min on `run1`'s own durations (a simulation of 6 lanes), 200.4 to
  195.4 on `after1`'s.
- **Import cache**: a warm import took 102 s at load 77 (49 files). The cron run does two cold ones each time.
- **A free box**: the sum of the mean durations from the gate's history is 25352 s, about 70 min on 6 lanes.
  The 200 min above are the box being 4 to 6 times over its cores, which no change to the checks takes out.

## 5. The tool patch (`docs/GATE_SPEED_1111.patch`, not installed)

Made against `/home/boki/coord/boki-tools/{suite-fast.sh,merge-candidate.sh,w2-dispatch}` and
`/usr/local/bin/godot` as of 2026-11-11 07:45Z. Apply in a scratch copy: `patch -p1 < GATE_SPEED_1111.patch`
with the four files in the current directory, then install each where it lives. It applies clean to
today's files and all four pass `bash -n`.

`suite-fast.sh`
- **Hang guard** (`HANG_SECS`, default 120, 0 = off): a run whose log holds a `SCRIPT ERROR` and then
  stays silent for HANG_SECS is ended (TERM to `timeout`, which leads the process group, so Xvfb and
  godot go too). It was red before and stays red; the FAIL count is unchanged. Covers trees without
  `CheckWatchdog` (main until this branch merges).
- **Preflight**: `--check` runs first on the merge tree. A `Parse Error` there that main does not have
  stops the pass: `NEW-RED --check`, every other flag `notrun (preflight stop)`, a `PREFLIGHT:` line in
  the summary and the report. A broken merged tree costs one run, not 280 timeouts.
  `SUITE_PREFLIGHT=0` turns it off.
- **Order**: the merge side runs longest-first by the last server duration in `durations.tsv` (unknown
  flags first). `flags.txt` keeps its order for the workers.
- **Memory**: a run waits (up to 10 min) while `MemAvailable` is under `MEM_MIN_MB` (3000). Exit 137
  (OOM kill) is retried once like 124.
- **Covered flags**: a flag in `CheckRegistry.COVERED` is not run, its covering flags are (section 6).
  `SUITE_COVERED=0` runs all.

`merge-candidate.sh`
- **Import cache**: the candidate's and main's `.godot` move to `~/mc-import-cache` before the worktree
  is removed and come back after it is re-created. Godot re-imports only changed files. A cold rebuild
  every 7 days; `MC_IMPORT_CACHE=0` forces cold every run.
- The report carries the `PREFLIGHT` line.

`w2-dispatch`
- ssh exit 255 is not a result: no rc file is written and the lane ends, so the flag stays open for the
  server. `qjob` (the jobq lane) is left as it was: not tested here.

`godot` wrapper
- The slot is held only while Godot lives, a nested `godot` call in a slot does not take a second one,
  `GODOT_MAX_S` (default 21600, 0 = none) ends a run that never finishes, TERM and INT reach the child.

How it was tested: a fake engine and three fake trees (`/tmp/gs1111/tp/st`): a hanging check is ended
after HANG_SECS with rc 143 and the same count on both sides (`same`), a slow silent check without an
error is not touched, a parse error on the merge tree only gives `NEW-RED --check` plus 5 `notrun` in
16 s, a covered flag is left out and named in the summary. Import-cache helpers on a scratch repo
(round 2 got round 1's `.godot` back). Wrapper with a fake binary (nested call, cap, TERM). Not tested:
a real cron run, the worker lanes, `qjob`.

Not done on purpose: per-flag adaptive timeouts (in `suite-fast.sh.next`). On a loaded box they turn
slow passes into reds, which is the opposite of deterministic.

## 6. What changed in the game repo

- `tools/check_watchdog.gd` (autoload `CheckWatchdog`, first in the list): on a check run it taps the
  engine log. After a script error followed by 60 s and 600 frames without a line it prints
  `WATCHDOG quit` and exits with code 1. A check's second game (`--check-child`) is not watched.
  Limit: a check with an old script error and a live phase that prints nothing for 60 s and 600 frames
  is cut there. It was red already; only its FAIL count can differ.
- `tools/check_child.gd` (`CheckChild`): the second game, server or proxy of a check. A free port by
  bind probe, its own data dir, and a shell watcher that ends the child when the host is gone. The four
  net check scripts use it (65 lines out, 24 in); the fixed 600 s guest life is gone and the host stops
  waiting when the guest is dead. `CheckChild.hold` keeps a check's ENet links open while one of its games
  is blocked building a match.
- `tools/check_clock.gd` (`CheckClock`): a stopwatch that leaves out the time the main thread waited for
  a CPU (`/proc/self/schedstat`, or `/proc/<pid>/schedstat` for a check's second game). Same as the wall
  clock on a free box. Used by the budgets and wait caps of `--base-demo-check`, `--depth-cue-check`,
  `--hit-shape-check`, `--prologue-check`, `--hunter-unlock-check` and by the guest reply caps of the
  displace and revive net checks (section 3).
- `tools/hob_check.gd`: its waits count the home's own clock (frame step capped at 0.05 s), not wall time.
- `tools/farm_tutorial_check.gd`: its Boki have fixed uids, so their likes are the same every run.
- `tools/kin_indoors_check.gd`: the "out within 45 s" step stops when the Boki is out.
- `tools/revive_net_check.gd`: the guest carries a chest key (rift keys are gone from the game).
- `tools/remote_smooth_check.gd`: the guest writes its record into the host's directory.
- `CheckRegistry.COVERED`: four flags whose whole run is part of other flags' runs.
  `--class-unlock-check` is the old name of `--hunter-unlock-check`. `--hero-combo-check` is
  `--archer-combo-check` plus `--bulwark-combo-check`. `--support-check` is `--tender-combo-check` plus
  `--rimewright-combo-check`. `--equal-migrate-check` is the last step of `--equal-check`. The flags
  still work by hand. The gate skips them once the tool patch is in.
- `tools/watchdog_check.gd` (`--watchdog-check`): a child run that dies on a script error is ended with
  code 1, which flags count as a check run, the covered list names flags of one script, the check clock
  stays behind the wall clock.

- Second round (rpc3, section 9): `displace_net_check`, `remote_smooth_check`, `revive_net_check` turn the
  host's drawing off (`displace_net_check.run` also serves remote-anim and online-displace);
  `perf_throttle_check` shuts its far bot's glider; `snack_patch_check`, `feed_check`, `tutorial_idle_check`,
  `farm_tutorial_check` wait for the home's UI on `CheckClock`.

## 7. For the owner (I did not touch other sessions' processes)

- Orphans holding wrapper slots and RAM: online-displace servers and `udp_delay.py` proxies, displace-net
  guests 14 to 17 h old, a `--clip-check` 46 h old, 14 `godot-bin` older than 10 h (about 7 GB).
- `/tmp` is tmpfs: 17 GB of the 61 GB RAM (`/tmp/claude-1000` 7.4 GB, `/tmp/briefs-a4` 1.8 GB).
- My own runs used `GODOT_SLOTS=64` because the wrapper queue was jammed.

## 8. Left

- **5 full passes on 0245 were not run.** The flake list comes from 2 full passes per tree (hetzner `run1`/
  `after1`, rpc3 section 9), 3 reruns of the flip list and 2 of every count change on rpc3, and the gate's
  history. A full A/B pass takes 54 min on rpc3 at 10 lanes, so 5 more are about 4.5 h of that box.
- **The tool patch is not installed** and no real cron run, worker lane or `qjob` lane was run with it
  (rpc3 has no `boki-tools`, so it was not tried against the real files either). `qjob` still turns a
  failed submit into a result.
- **CPU budgets on a loaded box**: `--hit-shape-check` (60 s) and `--base-demo-check` (10 s) are green at
  load 17 to 25 on 32 cores (30 s, 6 s) and fail at load 100. Owner decision: fewer lanes than free cores,
  or budget checks on `jobq`. Not done: raising the budgets (that would weaken them).
- **Wall-clock waits not converted** (not seen failing): `hatch_check`, `mask_moment_check`, `hitch_check`,
  `title_check`, `remote_smooth_check` (20 s dump wait).
- **Checks that draw for nothing**: every check runs under xvfb + llvmpipe, and a check that steps the
  match one frame at a time pays for a software-drawn frame each step. The net checks no longer draw
  (section 9: remote-anim 1200 s to 272 s). The other non-visual checks would gain the same, but each needs
  a look at whether it reads anything drawn (shots, `--perf-*`, `--hitch-check` do). Not done here.
- **Game bugs the checks point at, not fixed here** (game rules or god files): a new player's first Boki
  hates emberberry in about 1 save of 19, and then the farm tutorial's feed step refuses its own food
  (`Care.ensure` likes, `farm_tutorial.json` `start_food`); `match.gd:5231` freed instance in the guest;
  the `loose` int against Dictionary in `--base-life-check`; `hob_check.gd:181` script error on 0245;
  `tools/exit_signal_shots.gd:90` still sets
  `rift_keys` and calls `_open_hatch` (hatches are gone since 2f37df6df, the tool needs its hatch part cut);
  `--online-displace-check` "Meeko Hearth Call pull, guest: the ends agree (37.14 offline, 0.00 other)" in
  every run on 0245 and here.
- **Roots not found**: section 9's flake list.
- **Not done**: a parse bisect per branch in `merge-candidate.sh` (which branch broke the merged tree),
  shards for the slowest checks (no gain while the sum over the lanes is the bound).
- Scratch: `/tmp/gs1111` on hetzner (first attempt), `/tmp/gs-a1` on rpc3 (logs, `results.tsv`,
  `bin/run1.sh`, `bin/ana.py`, the base worktree). A checkout needs `godot --headless --import` once
  before checks see the new classes (`CheckClock`, `CheckChild`).

## 9. Second pass on rpc3 (2026-11-11, 13:30 to 15:10Z)

rpc3: 32 cores, 503 GB, load 17 before my runs, 48 to 60 during the full pass (mostly mine). Each check
alone, xvfb + opengl3, `LP_NUM_THREADS=2`, a fresh `XDG_DATA_HOME`, 1200 s limit. Base: a worktree of
`origin/ext/release-integ-0245` 2723685892 with the branch's `.godot` copied in and re-imported (both trees
share one import, see `--clip-check` below).

**Full pass, both trees interleaved flag by flag, longest first, 10 lanes** (per-flag numbers: the `rpc3_*`
columns of `GATE_SPEED_1111_times.tsv`): 54 min wall for the two trees together.

| tree | flags | sum of flag s | timeouts (124) | red |
|---|---|---|---|---|
| 0245 2723685892 | 281 | 16078 | 4 (+ `--watchdog-check`, a flag 0245 does not have: an unknown flag hangs 1200 s) | 52 |
| this branch | 281 | 11193 | 1 (`--remote-anim-check`, started before the draw fix) | 47 |

NEW-RED against 0245: none. Two one-off reds in the pass, both green in 4 of 4 reruns on each tree:
`--market-check` ("a lot nobody bid on comes back") and `--tutorial-clean-check` ("the course runs to the
exit (600s)"). Count changes in the pass that flip on 0245 too (2 reruns per tree): `--hatch-check` 7/8,
`--new-player-flow-check` 2/3, `--tutorial-fight-check` 0/1/4 (bot-driven course; which abilities the
archer uses differs). `--incubator-check`, `--title-check`, `--work-check`: 1200 s timeout on 0245, red in
82 to 127 s here with the same count (`CheckWatchdog`). Red on 0245 only in the pass: `--hitch-check`,
`--lair-lock-check`, `--results-ways-check` (one-pass flips, code this branch does not touch), `--hob-check`
(fixed here, section 3).

**What the free box showed (single runs, then fixed):**

| flag | before | root | fix | after |
|---|---|---|---|---|
| `--remote-anim-check` | 124, 42 FAIL, 1200 s | the host game draws every step with llvmpipe at well under 60 fps, so 0.1 s of game time takes 0.3 to 0.5 s of wall time while the lag between the games is measured on the wall clock. Headless: 0/0, 96 casts, 270 s | the net checks' host does not draw (`RenderingServer.render_loop_enabled = false`, as `prologue_check` already does) | 0/0, 272 s |
| `--remote-smooth-check` | 1/5, 85 s (395 ms behind, 39 snaps) | the same | the same | 0/0, 32 s (1 snap, 8 jerks, 0.16 m, 200 ms) |
| `--displace-net-check` | 1/1, 240 to 267 s ("a 4 s burn" arrives as 2.8 s) | the same | the same | 0/0, 62 s |
| `--revive-net-check` | 0/0, 176 s | the same (slow only) | the same | 0/0, 46 to 63 s |
| `--online-displace-check` | 1/2 to 1/3, 403 to 438 s | the dedicated server and proxy do not draw; the reds are the game (Meeko, every run) and Kael's Warchain (some runs) | none | 1/4, 570 s |
| `--perf-throttle-check` | 1/5 here (7 of 7 runs), 1/1 on 0245 | its far bot is pinned (teleport, grounded, roam) but its glider was left as the monster phase's steps had it; in some runs the bot opened it, a glider is never calm, 4 cases FAIL together | the setup shuts the glider | 1/1 (the shadow case, red on 0245 too) |
| `--hit-shape-check`, `--base-demo-check` | 0/0, 30 s and 6 s | CPU budgets: fine on a free box | none | |
| `--snack-patch`, `--feed`, `--tutorial-idle`, `--farm-tutorial` | not seen failing | 60 s wall waits for the home's UI, built in frame slices (CPU) | `CheckClock` | |

Count flips from section 3 rerun 3 times on this branch: `--chore-check`, `--garden-nav-check`,
`--garden-visitor-check`, `--mask-moment-check` 0/0 in all (green since the 0.24.5 integration fixes,
which the first attempt's `run1` tree did not have); `--music-leave-check` 0/2 in all (two script errors,
0245 too); `--perf-throttle-check` 1/5 in all (above); `--clip-check` 1/1 in all and on 0245: "ostra: a hit
mid-run leaves the legs on the run (foot slide off by 0.41 m)", the non-deterministic `ostra.glb` import
already in `docs/DEBT.md`. So that flip follows the import: the gate's cold import per run (section 5)
draws a new copy each time, and an import cache keeps whichever copy it has. `--prologue-check` 1/2 on both
trees: a skip takes 2.4 to 2.8 s (budget 400 ms, `CheckClock`) on a free box, so it is not load.

## 10. Seeds (rpc1, job 20261111-135014-a1)

rpc1: 32 cores, load 20 to 27 from other sessions. Each check alone, the gate's engine arguments, 900 s limit.

- **`CheckRegistry.run` seeds the global stream from the flag** (`seed(hash(flag))`) before the check starts.
  Game code that rolls on it (`BaseLife`, AI, loot) rolls the same on every run of a check. A serial pass of the
  gate's 278 flags on the seeded tree took 10650 s of check time (177.5 min one at a time). The 13 flags that
  were red, or redder than the earlier passes, ran again on the same tree without the seed: the same rc and
  FAIL count for 12 of them.
- **`--new-player-flow-check`**: without the seed, it failed a different step each run ("there is a skiff
  to take", "seven knocks hatch it", "'Head out together' opens the tutorial match"). With its seed it fails
  the skiff every run (3 of 3): that expedition has no dock. That is a real game question (the first
  expedition can roll without a dock) and is left for the match owner. The check used to crash on `docks[0]`
  and wait for the watchdog. It now returns after the FAIL, so the count is 1 (the same as 0245).
- **`--chore-check` root**: with the global seed alone it was red in 1 of 7 runs. In that run Mole's fetch
  chores gave up (5 of 6 ended, 0 journal lines). `HomeLayout.ensure` rolls a new farm-start island every run
  (`new_fs`, its own `randomize()`), so the toy and the ball sometimes land where Mole cannot reach. The check
  now pins the island, the uids (likes) and the rolls after the home's real build frames: 6 of 6 green, and
  green on the rebased tree. Fetch counts still differ (59 to 74) because of wall-clock stamps and per-object
  RNGs, so the home is not fully repeatable.
- **Not done**: putting the game's own `randomize()` RNGs (20 sites) on the global stream would make the home
  repeatable in checks. It is not safe as it stands: `match.gd:280` and `main.gd:2175` seed the global stream in
  play, so island seeds drawn from it after a match would repeat. It needs a check-only seed hook. Owner decision.
- **Still flaky here**: `--remote-smooth-check` was 1 FAIL in 5 of 5 runs on rpc1, a different assertion each
  run (backsteps, snaps, jerks, 0.34 m off the path), with or without the seed. On rpc3 it was 0/0 in one run.
  Its two games are timed against each other on the wall clock.

