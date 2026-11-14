# Release 0.24.4 gate triage

The suite run (load ~35/16 cores) compared the old candidate ec3c9dafb with main d255acbee and flagged 8 NEW-RED and
20 WORSE checks (reports/suite-0244 on ext/suite-0244-reds). Rerun here on rpc1 (load 120-180 on 32 cores) on the newest
candidate, ext/release-integ-0244b e30b77695, and on origin/main d255acbee. Both trees were imported first (0 script
errors). Each check ran alone per tree under xvfb + `--rendering-driver opengl3` like the suite, with a 900 s timeout
(3x the suite's) and a clean XDG; reds were rerun, and also run `--headless` where the environment was in question.
Fixes are on ext/release-integ-0244c.

Two findings explain most of the list:
- **16 of the 20 WORSE checks don't exist on main.** Main ignores the unknown flag and sits on the title screen until the
  timeout, so main rc=124 means "no such check", not load. Those rows have no main baseline.
- **Fixed-frame waits race the ink fade.** `_fades_on()` is false under `--headless`, where most checks were written.
  Under xvfb the 0.3 s fade is on, and a farm opened while it still covers builds in slices (`home.building`). A check
  that waits a fixed number of frames then reads the old screen or a half-built farm.

Values are FAIL rows (rc=124 = timed out). c = candidate e30b77695, m = main d255acbee.

| check | main | candidate | class | cause | fix commit |
|---|---|---|---|---|---|
| move-feel | 0 | 4 | REAL | felt-dash rows new on the line (Hem, Sable air, Grimble air, Ryzz) ahead of the dash code | f46c137dd (merge ext/move-dash-gaps-0244 a25beb0e9): 0 |
| wallmove | 0 | 1 | REAL | Neve's tapped Rink Wall bounce sweep (same branch) | f46c137dd: 0 |
| raising | not on main | 7 (x2; 7 on ec3c9dafb too) | check race | `main._hb_home` returned 2 frames in, before the sliced farm spawned the Boki | aaec0c746: 0 |
| toy | not on main | 1, then hung (rc=124) | check race | same `_hb_home` race (no toys, HomeBuild camera nil) | aaec0c746: 0 |
| air-control | not on main | 2 | check race | farm half added home itself and set ppos/pvel before the sliced `_ready` reset them | 956afedbc: 0 |
| music-leave | 0 | 1 (x3) | check race | live `start_match` got the training match back (still current under the fade): d == m | febd3a648: 0 |
| sting | not on main | 2 | check race | `go("home")` 6 frames < fade + build, both home rows heard nothing | 5ae175779: 0 |
| warm-stamp | not on main | 1 (0 headless) | check env | `WarmStamp.trusted()` skips the pipeline age on opengl3 by design; the row assumed Vulkan | b45a52ce3: 0 |
| prematch | 0 (row not on main) | 1 (0 headless) | env, existed on the line already | at a real 1280x720 the Hunter grid runs 7 px past the safe margin; also red at ext/prematch-declutter-rebased 8f1ccd06a itself (12 Hunters), Gil adds a 4th row | not fixed: docs/DEBT.md (UI decision: 5 columns alone still overflows by 7 px) |
| feel-golden | not on main | 84 (84 headless, 84 on ec3c9dafb) | known red on the line | golden recorded at 4c76f338f, before the line's owner-directed feel changes | not fixed: re-recording with `--update` is a deliberate call, left to the owner | Resolved on ext/feel-golden-0244: 83 rows classified (owner-directed, sourced, 16 recorded shoves; no regression), golden re-recorded in a cleared space (docs/MOVEMENT_FEEL.md).
| ttk | not on main | 22 (22 headless) | known red on the line | the per-Hunter parity bar vs source footage (docs/TTK.md) | none (tracking bar) |
| stretch | not on main | 542 (542 headless) | known red on the line | rig bone stretch on every clip (known: "fails all clips") | none |
| online-displace | not on main | 2 (2 headless) | known red on the line | Meeko Hearth Call pull on the guest (0244b: 2 vs 3 on both trees) | none |
| displace-net | 2 | 3 (x3; 0 headless on both) | load/env | Warchain hook timing under xvfb; main red on the same rows | none |
| hatch | 0 | 3 (x3; 0 headless) | load | 3.4 s Relic drift vs a 10 s wall-clock wait; frame-capped delta under load (drift 90% done at 10 s) | none |
| remote-anim | not on main | 28, rc=124 | load | 0.3 s remote-pose lag bar with a headless guest at load ~180 | none |
| remote-smooth | not on main | 5 (0 headless) | load/env | snaps/jerks of the drawn remote body under load | none |
| revive-net | not on main | 3 (0 headless) | load/env | guest beacon/marker sync under load | none |
| perf-budget | not on main | 1 | load | frame ms worst 677 vs 50 at load ~180 | none |
| boss | 0 | 0 | load | suite-only red | none |
| bot-sanity | 0 | 0 | load | suite-only red | none |
| hob | 0 | 0 | load | suite-only red | none |
| swim | 0 | 0 | load | suite-only red (the home.gd:1298 nil player errors don't recur) | none |
| demo | not on main | 0 | load | suite timeout | none |
| hit-shape | not on main | 0 | load | suite red | none |
| new-player-flow | not on main | 0 | load | suite red | none |
| abyss | 0 | 0 | load | suite counted log noise (2436 vs 2730 matches, rc 0) | none |
| glider-heat | 0 | 0 | load | same as abyss | none |

On ext/release-integ-0244c (xvfb): move-feel 0, wallmove 0, raising 0, toy 0, air-control 0, music-leave 0, sting 0,
warm-stamp 0, swim 0, hob 0; warm-stamp also 0 headless; health --strict OK. Net.VERSION stays 0.24.4.
