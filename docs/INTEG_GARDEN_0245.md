# Garden integration candidate for 0.24.5 (ext/integ-garden-0245)

One branch from origin/main d255acbee with every READY `ext/garden-*` line in briefs/EXT_TO_MAIN.md that still
applies, so the coordinator can take the Chao-style garden core (base_mode on) in one merge. Built 2026-11-11
by claude-job 20261111-062510-a1 on w2. Only `ext/garden-*` READY lines are in scope: sfx-garden-*, tut-garden-*,
anim-*, farm-* and ui-* branches that the full release line (ext/release-integ-0245) also took are not here.

## How the list was cut
96 READY lines name 80 garden branches. The last sha of each branch was kept (lantern-match, hub-theme,
hub-horizon, lean-foods, cinderstep-zone and journal had earlier lines). Every sha that is an ancestor of another
kept sha came in with it, which leaves 34 tips. The rest of this file says what happened to each tip.

## Order (GARDEN.md 10.7, then GARDEN_MODERN 6, then the later games)
1. `garden-zones-decision` c312e6c57 (10.7 step 1; fast-forward: it carries `garden-integrated` 58686d0b6, the
   base garden: base life, toys, nook, race, seek, volley, chores, mentor, journal, trust, soak and more).
2. `garden-hub-perf0` 926aa4377 (step 0, PERF_AUDIT only).
3. `garden-zone-budget` 410c9524e: the zone line (steps 2-6 and 7a/7b/9 through hub-zones, waystone, nav-sweep,
   carry, wayseed, hub-fixtures, zone-glasswater, cinderstep-zone, hub-horizon, snacks-all-types, items).
4. Steps 8, 10, 11 and the GARDEN_MODERN batch, in release-integ-0245's order so its resolutions replay:
   retire-isles, boki-wade, whistle, stat-budget, wishes-away, thrive, visitors, unlock-pace, hub-away,
   family-tree, balance-sim, glint-fishing (with mixing-bowl, prizes-cups), event-formats.
5. Games and later items: tumble, echo-steps, show-ring, relay-cup (with duo), path-meter, tag (with rivals and
   the games board), burrow-swap, voice-ambience, decor-tags, seasons, lantern-match, sleepovers.

## Left out (and why)
| branch | sha | why |
|---|---|---|
| garden-integrated-rebased | b1102554e | built for merge candidate mc-20261110-0630, it merges that whole candidate (non-garden work); 58686d0b6 is the right one on main |
| garden-nav-sweep-rebased | 13993323f | same: it merges integrated-rebased; nav-sweep d583ba443 is in |
| garden-voice-ambience-rebased | 405870580 | same, against mc-20261110-1030; ea25128ea merged instead |
| garden-race-main | 9ab5f8fa | duplicate Dash; garden-integrated keeps BaseRace |
| garden-trait-drift | 04173974a | superseded: garden-integrated carries BaseDrift and `--trait-drift-check` |
| garden-hub-move | 8fe040176 | superseded by garden-hub-zones (its READY line says so: a second zones/pad system) |
| garden-zone-cinderstep | d9b03de0d | superseded by garden-cinderstep-zone |
| garden-unlock | aa64a9c30 | step 6 again; garden-wayseed (in) supersedes it |
| garden-hub-theme | 7f1ba9db4 | second Glasswater build; zone-glasswater (in, ZoneLayout) is the one |
| garden-cinderstep | a2bb1bcb2 | second Cinderstep build; cinderstep-zone (in, ZoneLayout) is the one |
| garden-horizon | 02077956a | second step 9 (built on garden-unlock); hub-horizon (in) is the one |
| garden-lantern-zone-hub | 356960c0a | Hushwood keeps its own saved island (ZoneLook, `zones[id].layout`) beside ZoneLayout: two zone systems. Needs a port to a `build` entry in garden_zones.json |
| garden-ridge, kite-1, kite-2 | e769da604, 04fb6499f, df01d8830 | Kitewind and Kite Tow test and bench a re-themed farm (`--bench-theme`, a theme loop in the nav check) where the line uses real zones (`--bench-zone`, `--nav-zone`): 28-48 conflict blocks. Port the ridge to a `build` entry, then Kite Tow on top |

Alternative not taken: merging Hushwood and the ridge as they are and porting afterwards. Rejected because it
ships two zone systems (AGENTS 4).

## Conflicts and how they were resolved
- Replayed through rerere trained on ext/release-integ-0245's garden merges (29227543e..92df78ce4): boki-wade,
  whistle, wishes-away, thrive, visitors, unlock-pace, hub-away, family-tree (home.gd, base_life, garden_zones,
  hub_waystone, social, care, save, registry and checks). Generated docs/wiki and style_baseline: ours, then
  regenerated once at the end.
- glint-fishing: `GardenItems.preview` keeps the nest/down kinds and the mixing-bowl kinds; the down memory
  moved into the split `apply`.
- event-formats: Dash/Seek/Volley cards show the pin row and the prize rows; `pin()` returns early with no wall.
- tumble/echo-steps/show-ring/lantern-match/tag: one `games` list in home.gd (race, shove, seek, volley, tumble,
  echo, show, fishing, lantern, board); the Waystone find stays outside it.
- relay-cup, path-meter: both lines kept; toy play uses the zone `train_gain` and counts `toy_use`.
- tag: `Fsm.on_exit` keeps one callback per state, so the branch's second NAP exit would have dropped the
  first: one NAP exit erases pile and spot and wakes the duo. Zone ask, then rival ask. Patch timer on RIPE_KEY.
- burrow-swap: the Burrow wake calls `add_kin(rec, 0, -1, door)` (new optional spot) instead of a second
  `_add_kin`; the full-farm line keeps the out-count with `farm_caps()`.
- voice-ambience: `HomeVoice.say` plus the welcome greet and `Care.care_day` petting; the sfx check keeps both
  garden parts.
- decor-tags + seasons: `SnackPatch.grow_secs` (Sunny patch) on RIPE_KEY; `SnackPatch.grown(d, now)` = the
  island's list plus the season snack, the rotating extra kept. The seasons check now reads RIPE_KEY and expects
  the extra (its old `e["t"]` key is gone since the RIPE_KEY fix).
- lantern-match: garden_prizes.json and garden_items.json merged by key (3-way JSON); 27 items, 7 prize games.
- sleepovers: Save.VERSION 15, sleepovers migrate 14 -> 15 after zones (13) and shaping items (14).
- Integ fixes: `BaseRace.ground` (made public) in the Dash sign; zones check calls `ZoneCards.open_lines`;
  long lines the merges added wrapped; style baseline locked.

- Found by the checks and fixed on this branch: StatBudget kept `rec.loose` as a per-stat dict while shaping
  items keep one int pool (GARDEN_MODERN 1: loose points go back into any stat), which crashed every toy play;
  ZoneDress hid bridge signs that retire-isles no longer builds; garden_away (away overflow) and the soak still
  used the patch's old `"t"` timer (a deco tier since garden-tag's RIPE_KEY fix); the lean-snacks, snack-patch,
  seasons, daily and zones checks were updated to RIPE_KEY and the season snack (assumption changed, not loosened).

## Checks (final commit, w2 headless, temp XDG_DATA_HOME)
- `--check` and the 54 garden checks the merged branches registered or touched (arrival, baby-parents, base-demo,
  base-life, board, boki-rig, burrow, carry-boki, chore, come-look, decor-tags, duo, echo-steps, evo-path,
  family-tree, farm-tutorial, garden-daily, -items, -nav, -prizes, -recipes, -rivals, -save, -tag, -trust,
  -unlock-pace, -visitor, -whistle, -zones, glint-fishing, home-verbs, journal, lantern, lean, lean-snacks,
  mentor, nest-items, race, raising, relay-cup, seasons, seek, sfx-set, shove, showcase, show-ring, sleepover,
  snack-patch, stat-budget, toy, trait-drift, tumble, volley, wade): 0 fail.
- `--garden-nav-check`: 0 stuck, 0 inside, 0 overlaps in 600 s; 6 Boki waded.
- `--garden-soak` (30 days): 0 failures.
- Flaky under load, green alone: `--carry-boki-check` (follow distance 3.1-3.5 m with 5-8 Godot runs at once),
  `--base-demo-check` (ready in 10.4 s vs 10).
- `python3 tools/health.py --strict` OK; `python3 tools/gen_wiki.py --check` OK.
- Not run as checks: `--garden-save-load` is garden-save-check's child process; *-shots/*-clip need jobq gpu.

## Perf (jobq gpu 20261111-070247-15781 on rp1-1, Medium, `--bench-zone=all`, commit c5d60e496)
| part | draws | objects | frame ms | base_life ms | budget line |
|---|---|---|---|---|---|
| farm (home) | 1001 | 1731 | 6.4 | - | - |
| hub | 491 | 695 | 4.9 | 0.00 | ok (over target 200/500, under held 720) |
| Bramblebank | 482 | 786 | 10.6 | 0.12 | FAIL: objects past held 770 |
| Glasswater | 398 | 423 | 8.9 | 0.37 | FAIL: draws past held 395, objects past held 420 |
| Cinderstep | 408 | 742 | 9.6 | 0.18 | FAIL: objects past held 550 (draws under held 540) |

Red: the zone ratchets in garden_zones.json were held from M5 numbers on the zone line alone; the merged games
(board, lantern ring, show ring, fishing rock, tumble, echo stones) add objects on top. Frame ms and base_life are
inside budget everywhere. Not loosened: a draw pass or a new hold is the owner's call.

## Follow-ups (not built here)
- origin/main moved during the build: d255acbee -> 88b06b9e7 (the 0.24.4 release, 894 commits). This candidate is
  on d255acbee. A trial merge of 88b06b9e7 conflicts in 30 files / 54 blocks (save.gd versions, base_race and
  race_check vs garden-race-main on main, fsm, care, evo, home.gd, kin_voice/kin_companion, sfx_set_check,
  check_registry, perf_bench, Hunter glbs). The resolutions in ext/garden-integrated-rebased b1102554e and
  ext/garden-voice-ambience-rebased 405870580 were made against that line and are the reference.
- Port Hushwood (lantern-zone-hub) and Kitewind (ridge) to `build` entries in garden_zones.json, then Kite Tow.
- The away overflow pays the start garden's four snacks even on a zone island (`GardenAway._patch_overflow`).
- Two decision notes share 0022 (garden-zones, sleepovers) as on their branches.
