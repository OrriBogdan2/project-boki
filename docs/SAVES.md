# Save compatibility: the golden files

Every file the game writes for the player has a golden copy in `tests/fixtures/saves/`, captured from a real build.
`--save-compat-check` (in the check registry, and in `tools/ship_check.sh`) loads each one and fails on a load error, a
save marked "from a newer game", a lost kin or field, or a key `Settings` no longer knows.

| golden | written by | what the check asserts |
|---|---|---|
| `save_v<N>_*.json` | `Save.save_game` (slots `kinfall_save*.json`, the profile is inside) | loads through `Save.load_from`, upgrades to `Save.VERSION`, writes no `.bak`, keeps every kin and every field. A golden at the current version must lose nothing (only `LOAD_REWRITES` fields may change); an older one keeps its names, counts and numbers (`MIGRATED_KEYS`) |
| `settings.cfg` | `Settings.save` (+ the last slot from `Save.use_slot`) | every key is in `Settings.DEFAULTS` or `REMOVED`; values, key bindings and the slot survive |
| `feedback.json` | `Feedback` | `Feedback._load` reads minutes, answered versions and the queue back |
| `warm_stamp.json` | `WarmStamp.save` (a cache; a stale one is ignored) | the file still has its fields |

`save_v1.json` is the oldest format (hand-made, v1); `save_v13_fresh.json` is a new save, `save_v13_farm.json` a
populated farm (kin, bonds, incubator egg, home layout).

## Changing a format on purpose
Per AGENTS.md section 4 an old save must still load, so a format change ships with a migration:
1. Bump `Save.VERSION` and add `_migrate_N_to_M` in `scripts/core/save.gd` (`MIGRATIONS`). Settings keep their own
   `keys_v` / `video_v` style counters; a removed settings key goes into `Settings.REMOVED`.
2. **Do not touch or delete the existing goldens.** They prove the old file still loads. If the check now reports a
   lost field on one of them, the migration is wrong (or the field is rewritten on purpose: add it to
   `LOAD_REWRITES` / `MIGRATED_KEYS` with the reason).
3. Add the new golden from the new build, with a temporary data dir (never the real save):
   `XDG_DATA_HOME=$(mktemp -d) godot --headless -- --save-golden-capture --out=/tmp/gold`, then copy the new
   `save_v<N>_fresh.json` and `save_v<N>_farm.json` into `tests/fixtures/saves/`. Keep the previous version's pair
   (rename nothing). Replace `settings.cfg`, `feedback.json` or `warm_stamp.json` only when that format changed.
4. If the capture needs the new fields populated, extend `_capture` in `tools/save_compat_check.gd` (a few lines).
5. Run `godot --headless -- --save-compat-check` and `--unique-check` (the v1 migration details).
