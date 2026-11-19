# Merge-lane unstick: #106 and #122

## #106 ext/merge-lane-vfx3-1114-b
- Conflicts: none. origin/main e2bc08e889c merged cleanly.
- Failure: the REGATE NEW-RED was `--remote-smooth-check`. It is load-flaky. The PR failed 3 of 4 runs and main failed 2 of 3 on the same loaded box. The PR diff is audio/VFX/HUD only and touches no net or smoothing code, so no code fix was made.
- Pushed head: 36effc5f65ba644acd7947e24c949c65ab87050e

## #122 ext/merge-lane-misc2-1115-b
- Conflicts with main (clans slice 3 ranks/roles, Scrap King card, registry, aim_draw, gameplay_media):
  - Clans: main's ranks/roles kept; the PR's clan tag and last-deeds relabelled Slice 4 (decision 0022, DEBT).
  - Scrap King: main's short card kept, with the tight-pack shotgun line; wiki regenerated.
  - `aim_draw.gd`: duplicate `var k` removed.
  - `gameplay_media.gd`: walk clips are 14 = forest (main), 15 = Vex (PR).
  - `check_registry.gd`: main's file plus `--move-speed-check`.
- Real NEW-RED: `dredge_rmb_carry_check` "braced at a fifth of his walk" read 0.27-0.33.
  - Cause: the check's window started 0.05 s after the throw, while he was still braking from the faster body_scale run. The braced speed itself was exactly 0.2 of his run (1.08 of 5.39 m/s).
  - Fix: wait `BRACE_T` = 0.2 s for the brake, then measure over 0.1 s. Result: 0.23, PASS. `--dredge-combo-check`: 154 checks, 0 failures.
- Concurrent push: another worker pushed their own main merge (9f118b62a3b) while I worked. I merged it, took their resolution for the repeat conflicts, and kept only my check fix on top.
- Pushed head: 7c53fdabc07732243e5b673a3507cb6ae697e83e
- Not run: the full suite, and `--move-one-profile-check` (its log was empty). The regate-bot will re-gate both heads.
