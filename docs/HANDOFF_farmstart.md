# Handoff: branch `farmstart` (farm start, distinct islands, light survival, Boki stations)

Branch `farmstart` off main (sync48, 8244ec4). Not pushed, not merged.

## Done (commits)
- `e17613e` Farm start: a new save's island starts nearly empty; you place everything (layout `fs`, fixtures as
  build-mode items, lots appear only once marked out, Ransom/Challenge House arrive after the first expedition,
  first-day list starts with house + crop patch). Also fixes `HomeLayout.ensure` resetting every number in a
  loaded layout (JSON floats vs ints).
- `f248e54` Distinct islands (seeded outline + features, area normalized), light survival (`HomeGather`: axe and
  pickaxe, regrow), assigned Boki at stations (Seed Garden, Kiln added; offline catch-up), `--farm-start-check`,
  `--farm-demo`.
- `b321f4f` Polish: ghost tinted green/red itself, demo shots, visits never become fs islands, plots toast,
  validate ignores unplaced fixtures, Clear-the-wild leaves cliffs.
- This commit ("WIP: farmstart handoff"): only this file. Nothing was half-written.

All five requested steps are implemented. Nothing is in progress.

## Checks (run on b321f4f, all with a temp XDG_DATA_HOME through /home/claude/gq)
| check | result |
|---|---|
| `--check` | 0 failures |
| `--farm-start-check` | 0 failures (about 50 asserts, ~8 s) |
| `--home-build-check` | 0 failures |
| `--economy-check` | 0 failures |
| `--train-check` | 0 failures |
| `--simtest --seed=5` | extracted (hatch, 199 s sim), no errors |
No SCRIPT ERROR in any log.

Screenshots: /home/claude/shots/farmstart/ (island_seed7, island_seed222, placement_ghost,
placement_ghost_invalid, chopping, station_working, station_panel).
Re-take: `xvfb-run -a /home/claude/gq --rendering-driver opengl3 --audio-driver Dummy -- --farm-demo=<empty|ghost|ghostbad|chop|station|panel> --farm-seed=N --shot=out.png --frames=150`.

## Save-format changes (no Save.VERSION bump; all additive, old saves load unchanged)
- `layout.fs` (0/1), `layout.sk` (island size scale), `layout.regrow` {"x,z": {t, w}}: farm-start flag and chopped
  tiles waiting to grow back. Classic saves get `fs: 0` and keep their fixed farm.
- `Save.d.fs_grant` (the 200 starting gems were given), `Save.d.tools` (["axe", "pickaxe"]).
- `rec.work_at` (deco uid of the station a Boki is assigned to), `Save.d.work.seen` (last time the farm was seen,
  for offline output), station state `acc` (fractional offline progress).
- New catalog ids: house, crop_patch, cook_pot, market_stall, nesting_nook, boki_burrow, training_post, graveyard
  (cat "Buildings", only offered on fs islands), seed_garden, kiln (cat "Work", everyone).

## Left / not done
- Old (classic) saves have no wild land, so the axe and pickaxe have nothing to chop there. Options: an opt-in
  "start a new farm", or seeding a little wild on their unused meadow.
- `tools/loop_tour.gd` (demo QA, not in the required list) was not run; a brand-new player now gets an fs
  island with no plots until a crop patch is placed, so its farm steps may need updating.
- Cliffs are raised grassy ridges (World level 2, no props), not rocky faces; could use a rock-face look.
- Stream/pond water reuses layout water (blocky painted tiles), not the classic pond model.
- The homeplay branch (parkour + wardrobe) was looked at; nothing taken (unrelated).

## Gotchas
- New class `HomeGather` (scripts/home/home_gather.gd): a fresh worktree needs `gq --headless --import`
  (or a copied .godot) before it compiles.
- Unplaced fixtures sit at `home.FAR` (-400, 0, -400); anything that walks to or indexes a fixture spot must skip
  x < -100. `_house_door()` returns `HomeLayout.LANDING` when there's no house (the reach/flood anchor).
- `YARD_AT`, `NEST_AT`, `INCUB_AT`, `BURROW_AT`, `POND_EDGE` in home.gd are now vars (moved by `_sync_fixtures`).
- `home._ready` was split: the classic fixed farm is `_classic_layout`, the rest of setup is `_ready_rest`.
- `HomeLayout.ensure` now runs before `Econ.ensure` so a new fs save's first trough goes to storage.
- Fixing the JSON number reset means layout `seed`, `uid`, `grow` now survive reloads; players who already lost
  them keep what's in their file.
- Day-1 steps on fs islands give +5 gems each (house, patch), so gem asserts must allow for it.
- `open_up_fs` opens one gap per shut pocket per round (old `open_up` kept for non-fs islands); tiny pockets
  shut by non-wild blockers get a boulder.
