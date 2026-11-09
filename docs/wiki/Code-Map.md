# Code map

Every folder under `scripts/`, with one line per file that matters. Most files open with a `##`
comment that says more. Line counts are rough sizes, to warn you before you open a big one.

## scripts/

| File | What it is |
|---|---|
| `main.gd` (4k lines) | The screen holder (`show_screen`), command-line flags, and most inline `--*-check` hooks |
| `shot.gd` | Screenshot tooling: lists controls that stick out of the window |

## scripts/core/ (autoloads and shared rules)

| File | What it is |
|---|---|
| `game.gd` | Global glue: input actions and default keys, screen switching, `start_match` |
| `data.gd` | Tuning not yet in JSON: weight classes, rarity, perks, bot difficulty, monsters, crops, tiers, home buildings |
| `save.gd` | The save (`Save.d`): gems, farm, the Boki roster with personalities and memories; migrations |
| `settings.gd` | Player settings (shared by every save), the rebindable action list, Demo options |
| `net.gd`, `net_enet.gd` | Online play: browser room or the desktop relay over ENet (see [Networking](Networking.md)) |
| `bridge.gd` | Web build only: talks to the page (Claude-written Boki lines, the room, shared storage) |
| `social.gd` | Shared things: island snapshots, gifts, guilds, the town market (web build) |
| `care.gd` | Raising: needs, likes, natures, trained stats, bond ranks, life stages, IVs, breeding |
| `evo.gd` | Evolution by affinity, forms every 4 levels, body parts |
| `unique.gd` | Inborn rolls that make each Boki itself (size, coat, eyes, voice...) |
| `mutations.gd`, `shiny.gd` | Rare mutations and shimmers: odds, inheritance, looks, perks |
| `kin_speak.gd` | How young Boki talk, from their name only up to full sentences |
| `kinbox.gd` | The farm cap and the Boki Burrow box |
| `incubator.gd` | Rare Egg cradles, warming, hatching |
| `work.gd` | Farm jobs: work knacks, priorities, stations, catch-up while away |
| `econ.gd` | Home side of loot and keeping: armory, feeders, starving, graves, the Soul Shrine |
| `loot.gd` | Carryable items: weapons with rarity and element, named weapons, valuables, Rare Eggs |
| `ransom.gd` | Lost Boki: the Ransom House, rival holders, prices and haggling |
| `progress.gd` | Lifetime stats, challenges and market unlocks |
| `gliders.gd` | Glider skins |
| `names.gd` | Name pools for Boki and bots |
| `sfx.gd`, `synth.gd` | Playing generated sounds; sounds made in code |
| `look.gd`, `assets.gd` | Shared outdoor look (sky, grade, haze); imported CC0 models |
| `record.gd`, `perf_log.gd` | Recording mode (F10); timing marks for heavy steps |

## scripts/match/ (an expedition)

| File | What it is |
|---|---|
| `match.gd` (6.8k lines) | One match: setup, the 60 Hz step, interaction, catching, chests, events, online sync, training and tutorial |
| `world.gd` | The island tile grid, authored layouts, ground queries, the abyss |
| `ent.gd` | Base for everything that moves and takes damage |
| `hunter.gd` (3.4k lines) | A player or bot: movement, glide, ledge rise, abyss lift, weapon, levels and ranks, armor |
| `hunter_anim.gd` | Procedural hunter animation and the kits' keyed moves |
| `warden_stance.gd` | Each Warden's signature stance and idle cycle (content/rules/warden_stance.json) as pose offsets on the rig |
| `bot.gd` | Bot hunters: fight, farm, loot, catch, revive, extract |
| `kin.gd` | A Boki in a match: shoulder, thrown, fighting, dazed, fused |
| `kin_companion.gd` | A Boki as a teammate: callouts, caring, keeping close |
| `kin_voice.gd` | What a Boki says in a match |
| `life.gd` | Down, death, deathboxes, revives and beacons |
| `exits.gd`, `exit_models.gd` | Skiff docks, rift hatches, uplink outposts and their props |
| `lairs.gd`, `boss.gd`, `boss_models.gd` | Boss lairs, their locks and seals; the three bosses |
| `blight.gd`, `blight_dir.gd`, `blight_models.gd` | The Blight and its director |
| `mob.gd`, `mob_models.gd` | Monsters |
| `spawn_plan.gd` | What's live on a fixed map each match |
| `drop_squad.gd` | Planning phase, the skyship, squad drop formation |
| `raid_look.gd` | Raid conditions: light, weather, sight |
| `truce.gd` | Emotes and truces |
| `pack.gd` | The backpack |
| `gear.gd` | Gloves (loaded from `content/gloves`) |
| `biome_run.gd` | Regional monsters and hazards on authored maps |
| `sky_train.gd` | The sky train |
| `arena.gd`, `duel.gd` | The Arena's practice tools; the duel room |
| `cam.gd` | The match camera |
| `fx.gd`, `juice.gd`, `abyss_fx.gd` | Pooled effects; hit feel; the abyss tint |
| `models.gd`, `kin_models.gd`, `hero_kit.gd`, `hero_gear.gd`, `hero_hair.gd`, `props_sculpt.gd`, `flora.gd` | Characters and props built in code |
| `terrain_mesh.gd`, `ruin_walls.gd`, `landmarks.gd`, `sky_deco.gd` | Drawing the world |
| `music_dir.gd` | The layered expedition score |
| `arena_demo.gd` | Screenshot tooling for the Arena |

## scripts/arch/ (class kits)

| File | What it is |
|---|---|
| `arch.gd` | Class data: lookups, weapon families, Boki infusion into sockets |
| `arch_kit.gd` | One hunter's kit at run time; base class for the six kits |
| `kits/*.gd` | `thief_kit`, `archer_kit`, `mage_kit`, `gunslinger_kit`, `juggernaut_kit`, `bulwark_kit` |
| `hex.gd`, `kit_status.gd` | The Mage's Hex; kit statuses sent over the network |
| `oomph.gd`, `feel.gd` | Combat weight; the global feel spec |
| `arch_demo.gd` | Screenshot tooling |

## scripts/combat/ (data-driven abilities)

| File | What it is |
|---|---|
| `content.gd` | Loads weapons, abilities, class dodges, rules and combos from `content/` |
| `ability_def.gd`, `ability_runner.gd`, `effects.gd` | An ability as data, its slots and cooldowns, and the effect building blocks |
| `verbs.gd`, `fields.gd` | Things abilities leave in the world; ground zones |
| `ability_fx.gd` | How abilities look and sound |
| `combos.gd`, `bond.gd` | Combos; the bond meter |
| `kin_tactics.gd` | How a Boki fights on its own |
| `combat_bus.gd`, `weapon_def.gd` | Signals between systems; a weapon definition |

## scripts/kin/ (the Boki grammar)

| File | What it is |
|---|---|
| `grammar.gd`, `grammar_report.gd` | Load and validate grammar files; collect errors |
| `parts.gd` | The vocabulary: deliveries, effects, modifiers, triggers, themes |
| `kin_spec.gd`, `ability_spec.gd`, `stage_spec.gd`, `part_spec.gd`, `merge_spec.gd`, `evolution_node.gd` | Parsed, checked specs for each file type |
| `kin_lib.gd` | The live library: species, effective abilities after evolution and ranks |
| `kin_exec.gd`, `kin_runner.gd` | Run any ability spec; charges and cooldowns |
| `kin_rules.gd`, `kin_merge.gd` | Core runtime rules; the merge (bond ultimate) |
| `kin_text.gd` | Readable lines generated from parts (tooltips) |

## scripts/home/ (the farm)

| File | What it is |
|---|---|
| `home.gd` (5.8k lines) | The farm screen: walking, crops, cooking, the market, caring for Boki, panels |
| `home_build.gd`, `home_layout.gd` | Build mode; the saved layout and the build catalog |
| `home_work.gd`, `work_models.gd` | Boki working stations; station models |
| `home_gather.gd` | Chopping and mining |
| `home_econ.gd`, `econ_models.gd` | Armory, feeders, graveyard, Soul Shrine |
| `home_incubator.gd`, `kin_burrow.gd` | The Incubator and the Burrow on the island |
| `interior.gd` | Inside buildings, decorating |
| `kin_brain.gd` | Chat intents for talking to a Boki |

## scripts/ui/

| File | What it is |
|---|---|
| `ui.gd` | The menu kit every screen builds from |
| `hud.gd` (3.7k lines) | The in-match HUD |
| `overlay.gd` | Esc menu, settings, save files, admin panel |
| `title.gd`, `prologue.gd`, `hatch.gd`, `wyrm.gd`, `scenery.gd` | Title, story, first egg |
| `kit_card.gd` | A class's whole kit on one page (K) |
| `full_map.gd`, `map_paint.gd` | The M map and its baked painting |
| `results.gd`, `loading.gd`, `lobby.gd`, `screen_fade.gd`, `hold_skip.gd` | Between screens |
| `dex_view.gd`, `about_view.gd`, `iv_view.gd`, `kinbox_view.gd`, `incubator_view.gd`, `work_view.gd` | Boki menus |
| `egg_hatch.gd`, `kin_reveal.gd`, `kin_portrait.gd`, `portraits.gd`, `icons.gd` | Hatching, portraits, icons |

## scripts/server/ and scripts/social/

| File | What it is |
|---|---|
| `server/relay.gd` | The relay server (`-- --relay`) |
| `social/town.gd` | The town and guild isles (web build) |

## tools/

| File | What it is |
|---|---|
| `*_check.gd`, `check.gd`, `mapcheck.gd`, `speaktest.gd` | Check scripts run by `main.gd` hooks ([Checks](Checks.md)) |
| `loop_tour.gd` | Plays the core loop end to end with a screenshot per step |
| `gen_wiki.py` | Generates this wiki's data pages |
| `gen_abilities_doc.py` | Generates `docs/ABILITIES.md` |
| `gen_sfx.py`, `sfx_combat.py`, `gen_train_sfx.py`, `gen_ambience.py`, `compose.py`, `gen_music.py`, `sfx_stats.py` | Sound and music generators |
| `make_skyreach.py` | Builds `content/maps/skyreach.json` |
| `gen_names.py`, `rebrand.py` | Name pools; the Kinfall to Project Boki text pass |
| `build_web.sh`, `mkshell.py`, `shell.html` | The web build wrapper |
| `vendor_assets.sh`, `vendor_gltf.py` | Bringing in CC0 models |
