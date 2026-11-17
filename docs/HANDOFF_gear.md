# Handoff: branch `ext/gear` (one signature weapon, rarity moves to gear, weapon upgrades)

Branch `ext/gear` off main sync58 (e5f25ec). Implements section 2 "Weapons and gear" of
`docs/HANDOFF_main_overflow.md` (branch `ext/main-overflow`).

## The model
- **One signature weapon per hero.** An archetype JSON names it with `"signature": "<weapon id>"`
  (`Arch.signature(id)`). An older file with a `weapons` list still loads: its first entry is the signature.
  No weapon pickups, no swapping, no weapon rarity, no weapon in the loadout or the armory, no weapon in a
  deathbox. `Arch.weapons(id)` still returns a one-element list so old callers keep working.
- **Rarity (Common..Legendary) lives on gear.** Five slots (`Gear.SLOTS`): active glove (Q), passive glove,
  armor, boots, utility kit. Rarity scales a piece's `stats` by `Gear.mult` (1, 1, 1.3, 1.6, 2). Pieces are
  `content/gear/*.json` (renamed from `content/gloves`; the 23 old actives and passives are unchanged, plus
  Quilted Coat, Gale Mantle, Bastion Plate (armor), Windstep/Quickstep/Skylark Boots, and Tinker Roll, Field
  Kit, Satchel, Spyglass, Magpie (kits); `vest` and `boots` became Brace Plate and Springheel Boots). New
  stats: `hp`, `reload`, `tonic`, `pack`, `dodge`, `gems`, `sight`.
- **In-run weapon upgrades** replace replacement weapons (`scripts/match/weapon_ups.gd`): Data.PERKS entries
  with a `"wup"` block (Hotload dmg, Deep Magazine, Quick Feed, Long Reach, five Brands that set the hit
  element). Sources: level-ups on even levels (offer only upgrades), chests and shrines, bosses, and
  "tuning" pickups on the ground that you take by walking over them. A weapon whose magazine is 3 or less
  (blades, bow) is never offered Deep Magazine (`WeaponUps.fits`).
- **Drops** are data (`content/rules/gear.json`, `scripts/match/gear_drops.gd`): tables ground, cache, crate,
  chest0-2, brute, sentinel, warden, glimmer, bl_skitter, bl_warden, boss. A roll is `gear` or `tune` with
  `chance`, `bonus` (rarity steps), `min_rar`, optional `slot`. **Bosses drop few, high-value items**: Epic+
  gear plus a Brand tuning, 30% for a Legendary; the Rare Egg stays its own drop. Biome JSONs carry
  `loot.slots` (a slot lean per region, e.g. frost leans armor).
- **Extract**: gear brought home goes to the armory as before and also breaks down into farm materials
  (`extract_mats` in gear.json, by rarity; `GearSave.extract_mats`). Armory tabs: Armor / Boots / Gloves /
  Kits / Treasure. Loadout keys are `gear0..gear4` (`Econ.LOADOUT_SLOTS`); the home expedition panel shows the
  signature weapon as a fixed tile; the try-on and Arena have no weapon picker.
- **Save v5** (`GearSave.migrate`, `Save._migrate_4_to_5`): stored weapons (armory and raid_out) become scrap
  (1/1/2/4/7 by rarity, +2 elemental, +5 named); gloves become `t:"gear"`; `glove0/glove1` loadout keys become
  `gear0/gear1`; the carried weapon becomes the archetype signature. Nothing else is touched.
- **Bots** start with gear by difficulty (`bot_start` in gear.json), walk over tunings, and pick up gear that
  beats what they wear (`GearDrops.bot_wants`). Their weapon is their archetype's signature.
- **Net**: `Net.VERSION` 0.10.0 -> 0.11.0. The `wdrop` event is now
  `["wdrop", id, "gear"|"tune", rar, x, y, z, gear_id_or_perk_id]`; `wtake` is `["wtake", id, nid]`. The
  "st"/"hit"/"ev" topics and Net function names are unchanged. The three checks that asserted `== "0.10.0"`
  now assert `>= "0.10.0"`.

## For the hero branches (`ext/heroes-*`)
Give your archetype JSON `"signature": "<weapon id>"` instead of a `weapons` list, and add the weapon in
`content/weapons/`. Drop the card's `weapons` block down to that one weapon (kit_card tags it "signature
weapon"). `Arch.weapon_ok(id, wid)` is `wid == signature(id)`. If your kit scales its own hits, multiply by
`h.wup_dmg` (see `juggernaut_kit.gd` `_wk()`), so Hotload and friends reach it.

## Merge notes (polish, ext/fixes)
- `origin/polish` adds `scripts/match/drop_family.gd` (`Match.earned_weapon_id` / `ground_weapon_id`). Resolve
  in favour of gear: delete DropFamily and its calls; ground spots, crates and chests already call
  `GearDrops.run_table` / `roll_gear`. Keep its other changes.
- `origin/ext/fixes` has the reload-on-swap rules (moot: nothing swaps) and the boss loot rework. Keep its
  shape (few, high-value drops; Rare Egg on its own spot with a beam) and make the drops the `boss` table in
  `lairs.gd` `_boss_dead` (`GearDrops.run_table(m, "boss", ...)`).

## Files
New: `scripts/match/weapon_ups.gd`, `gear_drops.gd`, `gear_models.gd`, `scripts/ui/gear_panel.gd`,
`scripts/core/gear_save.gd`, `content/rules/gear.json`, `content/gear/*` (11 new), `tools/gear_check.gd`.
Removed: `tools/pickup_check.gd` (replaced by `--gear-check`), `Match.spawn_weapon/found_weapon`,
`Loot.weapon`, `Data.roll_rarity`, `Models.weapon_drop`, the weapon pickers in Duel/Arena/training/home.
Big files got wiring lines only; `python3 tools/health.py --strict` passes.

## Checks
See the report. `--gear-check` covers: signature fixed per archetype (and for every hunter in the match), no
weapon pickups from any drop table, rarity rolls, gear effects (health, pack, boots), weapon upgrades and
Brands, level-up offers, boss/chest/Blight tables (bosses fewer and better), bots, and the v4 save migration.
Screenshots: `/home/claude/shots/gear/`.

## Open questions
- Value of the numbers in `gear.json` (drop rates, rarity weights, extract mats) is a first pass, untuned.
- Named/unique weapons and elemental weapon rolls are gone; Brands are the elemental path now. Say if you want
  named gear back as a separate unique tier.
