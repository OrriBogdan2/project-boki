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

`--remote-smooth-check` never measured anything on the gate, so nobody knows its numbers on a free box. Its
record is stamped with wall time on both games, so on a box at load 43 the 4 FAIL can be the load, the game,
or both. A second run (through `jobq`, which ran it on this same box) gave 25 snaps and 191 jerks but the same
7.06 m and 395 ms, so those two do not look like load. It needs one run on a free box before anyone reads
them as a net regression. I kept the fix: a check
that fails for "no record" hides the same numbers.

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

## 7. For the owner (I did not touch other sessions' processes)

- Orphans holding wrapper slots and RAM: online-displace servers and `udp_delay.py` proxies, displace-net
  guests 14 to 17 h old, a `--clip-check` 46 h old, 14 `godot-bin` older than 10 h (about 7 GB).
- `/tmp` is tmpfs: 17 GB of the 61 GB RAM (`/tmp/claude-1000` 7.4 GB, `/tmp/briefs-a4` 1.8 GB).
- My own runs used `GODOT_SLOTS=64` because the wrapper queue was jammed.

## 8. Left

- **5 passes on 0245 were not run.** One full pass took 210 min on the box today, so the flake list comes
  from 1 full pass per tree, a 22-flag second pass, single reruns and the gate's history. With the tool
  patch in and the box free, `SUITE_COVERED=0 suite-fast.sh` 5 times gives the full list.
- **The tool patch is not installed** and no real cron run, worker lane or `qjob` lane was run with it.
  `qjob` still turns a failed submit into a result.
- **CPU budgets on a loaded box**: `--hit-shape-check` (60 s) and `--base-demo-check` (10 s) still fail at
  load 100. Either the gate runs with fewer lanes than cores are free, or budget checks move to `jobq`.
  Owner decision. Not done: raising the budgets (that would weaken them).
- **Wall-clock waits not converted** (same pattern as `--hob-check`, not seen failing in my passes):
  `hatch_check`, `tutorial_idle_check`, `snack_patch_check`, `feed_check` and `farm_tutorial_check` line 618
  (60 s home waits), `mask_moment_check`, `hitch_check`, `title_check`, `remote_anim_check` (`LAG_TOL`),
  `remote_smooth_check` (20 s dump wait). `--prologue-check` still times out in `_play` under load.
  `--remote-anim-check` fails on its `LAG_TOL` (0.3 s of wall time between the two games): 6 FAIL on 0245,
  8 here, both at the 1200 s limit.
- **Game bugs the checks point at, not fixed here** (game rules or god files): a new player's first Boki
  hates emberberry in about 1 save of 19, and then the farm tutorial's feed step refuses its own food
  (`Care.ensure` likes, `farm_tutorial.json` `start_food`); `match.gd:5231` freed instance in the guest;
  the `loose` int against Dictionary in `--base-life-check`; `hob_check.gd:181` script error on 0245;
  `tools/exit_signal_shots.gd:90` still sets `rift_keys` and calls `_open_hatch` (both gone).
- **Roots not found**: the count flips listed at the end of section 3.
- **Not done**: a parse bisect per branch in `merge-candidate.sh` (which branch broke the merged tree),
  shards for the slowest checks (no gain while the sum over the lanes is the bound).
- Scratch left in place for whoever continues: `/tmp/gs1111` (logs of all passes, `ana.py`) and the trees
  under `/home/boki/cj/20261111-074008-a5/tmp/`. A checkout needs `godot --headless --import` once before
  checks see the new classes (`CheckClock`, `CheckChild`).
