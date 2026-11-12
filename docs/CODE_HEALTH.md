# Code health log

Each cleanup pass appends a section: what was removed or merged, and the evidence.

## GDScript and scenes (branch ext/health-gd-1112, 2026-11-12)

Method. The skip list holds every path changed by an `origin/ext/*` branch with a commit in the last 3 days (2201
branches). 916 of the 1038 tracked `.gd`/`.tscn` files are on it and were only read. Of the 122 left, 94 are named in
`/home/boki/coord-refs/ext-refs.txt`, so none of those files was deleted (only unused symbols inside them were removed).
- **Files.** A reference graph covered every tracked `.gd`/`.tscn`. A file counts as used when another file names its
  path, file name, uid (`.uid` file or scene header) or `class_name`. The search covered `.gd .tscn .tres .gdshader
  .cfg .json .py .sh .yml .txt`, `project.godot`, `export_presets.cfg` and `.github/`. Paths built from strings were
  added by hand (`hero_vfx_reel.gd` loads `tools/vfx_reel/<hero>.gd`). Reachability started from `project.godot`,
  export presets, content JSON, tool scripts and coord refs, and was run a second time with GDScript comments
  stripped. Every one of the 20 unreachable files is an entry point run by hand: F6 galleries, `godot -s` tools, a
  `--script` tool. **No file is provably dead, so none was deleted.**
- **Symbols.** Every top-level `func`, `signal`, `@export var`, `var` and `const` in the 122 free files was counted
  across all text. A name with no use outside its definition was then searched with `git grep` on all 2201 active
  branch tips.
- **Commented-out code.** None in the free files. Repo-wide, the only hit, `tools/boki_follow_check.gd:273`
  (`# return`), labels the next step and is not dead code.

### Removed

| Path | What it was | Evidence |
|---|---|---|
| `scripts/core/mutations.gd` `inherit_odds()` | getter for the parent-inherit odds | no caller on main or in any active branch tip; `_inherit` is still read by the roll |
| `scripts/core/mutations.gd` `SHIMMER_WILD`, `SHIMMER_EGG` | aliases of Shiny's odds "kept for older callers" | no caller on main or in any active branch tip; the odds live in `Shiny` |
| `scripts/match/gloves.gd` `wear_pair()` | puts two gloves on at once | no caller on main or in any active branch tip; bots use `Gloves.bot_fill` |

Kept: `KinRules.DEFAULT_SLOW` is unused on main, but `scripts/match/ent.gd` reads it on 6 active branches.

### Merged

| Path | Was | Now |
|---|---|---|
| `scripts/match/key_bonus.gd` `rules()` | its own JSON read and cache of `content/rules/chest_keys.json` (`RULES_PATH`, `_rules`) | `Content.rules("chest_keys")`, the shared cached loader; same dict, same `{}` on a missing file; `KeyBonus.rules()` callers unchanged |

### Guard: `--unref-check`

`tools/unref_check.gd` fails on any `.gd`/`.tscn` that no other file names by path, file name, uid or `class_name`.
Comments count as names; `.md` docs don't. It takes about 1.7 s headless. Intentional entry points go in
`tools/unref_allow.txt` with a reason, and a listed file that is gone also fails. The check is not transitive: a file
named only by another dead file still passes. It is registered with one line in `tools/check_registry.gd`, placed
where a trial `git merge-tree` against all 1078 active branches that change that file showed 0 new conflicts.

### Found, not changed

- **`--unstable-mix-check` is orphaned and red.** `tools/unstable_mix_check.gd` had an inline hook in `main.gd`
  (4e7fd6a893), and a later merge dropped it. `docs/wiki/Checks.md` still lists the check. Run on main, it fails:
  "20 of 20 clashing pairs get the Nook line and the card tag (0)". Registering it here would add a red, so it is
  allowlisted instead. Fix (Nook lane): repair `UnstableMix` tagging, then register the flag and drop the allowlist line.
- **Entry points nobody names** (allowlisted): `tests/feel_sim.gd`, `tests/glider_gallery.tscn`,
  `tests/portrait_gallery.tscn`, `tests/net/match_probe.gd`, `tests/net/net_probe.gd`, `tools/vfx_reel/*.gd` (4).

### Duplicate systems to merge later

All of these touch skip-list files (and most are in coord refs), so none was merged in this pass.
1. **Movement and camera prototype vs the game's.** `scripts/feel/` holds its own controller and camera:
   `HunterController` (560 lines), `TopDownCameraRig`, `FeelConfig`, `JumpPad`, `KinfallInput`, `feel_test_world`.
   It is reached by `--feel-lab` (`tests/feel_test.tscn`) and `tests/feel_sim.gd`. The game uses `Hunter` +
   `HunterMove` + `CamRig`; `hunter.gd` and `move_feel_check.gd` only name `FeelConfig` in comments and labels.
   Plan: once `move_feel_check`'s targets are in `content/rules`, delete `scripts/feel/`, `tests/feel_test.tscn`,
   `tests/feel_sim.gd` and the `--feel-lab` hook.
2. **Ruin walls twice.** `scripts/match/ruin_walls_v1.gd` (226 lines) is kept for the `--art1` before/after view
   next to `ruin_walls.gd`, and `_init` and `_exposed` are identical in both. Plan: drop the `Flora.v2()` false
   branch in `world.gd`, then delete v1. Both files are in coord refs, so the coordinator decides.
3. **Rules loaders.** 19 files read their own `content/rules/*.json` with a private cache instead of
   `Content.rules(id)`: `arch_kit`, `boki_lines`, `class_unlock`, `garden_xp`, `box_revive`, `breakables`, `cam`,
   `equal`, `gear_drops`, `heart`, `hunter_move`, `key_run`, `level_growth`, `mantle_look`, `perk_orbs`,
   `weapon_path`, `wisp_look`, `hunter_viewer`, `portraits`. Plan: the same swap as `KeyBonus` for each file as it
   comes off the skip list. Check that none of them writes into its cached dict (Content shares one).
4. **Kit FX mesh helpers.** `dj_fx.gd`, `ld_fx.gd` and `vv_fx.gd` each copy `_mi()`. `dj_fx` and `ld_fx` also copy
   `_quad_mesh()`, `_ribbon_mesh()` (20 identical lines) and `unplace()`. `KitMeshes.inst()` and `KitMeshes.quad()`
   already do this job. Plan: callers use `KitMeshes`, and `_ribbon_mesh` moves into `KitMeshes`.
5. **Model finishing.** `MobModels._finish` and `PropSculpt._finish` are identical (merge statics, bake part y).
   Plan: one `Models.finish(root)`.
