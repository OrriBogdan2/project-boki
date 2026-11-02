# 0007: One locked chest, keys carried by monsters, the Shrubling, and hiding cover

- **Status:** accepted (owner design of Nov 2 2026, the 09:50 and 10:00 ET entries of ext/equal; part C of the ext/equal split)
- **Date:** 2026-11-02
- **Area:** match flow / loot / AI / map / networking

## Problem
Chests came in three tiers, so where you opened one decided what you got, and any hunter could open any chest for free: nothing sent a squad out to fight for loot. Tall grass was nearly absent (17 clumps, under 1% of the ground), so there was little to hide in or ambush from, and the map had one cover density everywhere.

## Options
1. Keep the tiers and add keys per tier: rejected, it doubles the tables and keeps the map reading as "go to the rich chest".
2. Keys as a shop item or a fixed pickup per region: rejected, a key you can buy or walk to is not worth fighting over.
3. One chest type, locked. Each open costs one key. Keys are carried by monsters, so you fight for a key before a chest (decided).

## Decision
- **One chest.** The chest tiers (`chest0/1/2`, tier colours, tier text) are gone: one model, one table (`content/rules/gear.json` "chest"). What is inside follows the area (`BiomeRun` rarity bonus and slot lean) and the match difficulty tier. `ChestLoot.perk_hook` is the one call site for perk orbs (part B).
- **Keys.** Opening a chest takes one key and a one-second hold (`KeyChest`). Per region the number of key carriers equals the number of chests there (`KeyRun.assign_carriers`), rolled on a seeded stream of its own, so the same match seed gives the same carriers and no other roll moves. A region with too few monsters (a quiet landing) is carried for by its nearest neighbours, so there is always one key per chest in the world. A carrier wears a spinning key glint. A key is an item (`chest_keys`): it sits in the inventory, goes into the deathbox, and lies on the ground to be picked up. It is separate from the Rift Keys that open rift hatches. The HUD shows the count on the weapon card, right under the belt (`KeyCounter`). Bots go for a key first (`BotKeys`).
- **Shrubling** (`Shrubling`, a `Mob`). A bush mimic that looks like the map's own tall grass. Disguised with a faint rustle; reveals inside 6 m (or when hit), flees faster than a hunter walks and slower than a dash, weaving to break line of sight, dives into the nearest cover patch and hides again. Always carries a key and counts toward its region's quota. Low health, no attack. Slows, roots, Grounded and grabs work on it. Not capturable. 1 to 3 per match, only in bloom, meadow, gloom and storm, only where three or more cover patches lie within sprint range. It uses the ordinary mob systems: `KinPath` for the paths, seeded spawn spots, `Mob.hurt` and `on_mob_dead`.
- **Cover.** `tools/make_hollowcrown.py` now computes the tall grass (`place_cover`), a fixed seed, so the JSON is reproducible. Targets are shares of walkable ground per biome (`content/rules/keys.json` "cover"): bloom 15 to 20%, meadow about 10%, gloom about 6% (Shard Perch bare), storm about 3%, ember 2 to 3%, frost under 1%. Cover is a patch of 3 to 6 overlapping clumps, planted beside chests and camps, along the flanks of the lanes between landmarks, at cliff edges and bridge heads, around the Crown's pillars, and always in sight of every exit in the bush biomes. Never on stairs or ramps, bridges, landing drop circles, lair floors, or across a lane (each lane keeps a clear corridor). Rendering is the existing batched tall-grass path (`World._chunked`, one MultiMesh per chunk).
- **Net:** the carrier flag and the Shrubling state ride the mob snapshot (two more numbers), the chest event carries no tier; `Net.VERSION` 0.14.0 to 0.15.3 (the number assigned to part C; the main session reconciles).

## Consequences
- New: `key_run.gd`, `key_carry.gd`, `key_chest.gd`, `key_glint.gd`, `key_models.gd`, `chest_loot.gd`, `shrubling.gd`, `shrubling_model.gd`, `bot_keys.gd`, `ui/key_counter.gd`, `content/rules/keys.json`, four sounds (`tools/gen_key_sfx.py`), `tools/keys_check.gd` (`--keys-check`), `tools/cover_check.gd` (`--cover-check`). Both are in `CheckRegistry`.
- Changed: chest code in `models.gd`, `props_sculpt.gd`, `match.gd`, `world.gd`, `spawn_plan.gd`, `rolling.gd`, `polish_tools.gd`, `life.gd` and `pack.gd` (the box field), the `gear.json` table, `bot.gd`, `hud.gd` (one call), `sfx.gd`, `net.gd` (version).
- Removed: chest tiers everywhere. Sky-train crates stay free to open, so the train puzzle does not need a key. The tutorial chest is free.
- Debt: none added to the big files beyond wiring; `match.gd` stays under its budget. Open owner questions are listed in the part C report.
