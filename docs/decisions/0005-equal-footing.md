# 0005: Equal footing in matches (ext/equal)

- **Status:** accepted
- **Date:** 2026-11-02
- **Area:** match flow / save / combat / farm / UI

## Problem
Power in a match came from home: worn armour, a bigger pack, workshop and guild-project perks, a
loaner kit. A player with a rich farm started stronger than a new one. The owner wants an extraction
game where you can bring a little in, but power mostly comes from the match: everyone drops with the
same body, then finds, buys and earns the rest. The only lasting edge is your Boki.

## Options
1. Pure equal start (bring nothing, like a battle royale). Simple and fair, but there is no reason to
   keep gear on the farm and no extraction fantasy.
2. Bring everything, balance with tiers. Keeps the farm loop, but the power gap stays.
3. Bring a small, capped, at-risk set (gloves, boots, utility) and nothing else. Keeps a reason to
   farm, bounded by difficulty tier, and dying costs it.

## Decision
Option 3.

**Brought in (at risk: it drops in your deathbox):**
- gloves (Q active, passive) and boots, with their rarity capped by difficulty tier;
- utility items on the belt (below), with stack caps by tier.

The caps are data in `content/rules/equal.json`: rarity cap [Rare, Epic, Legendary] for The Meadow,
Dusk Isles and The Hollow, and a stack-size cap per item per tier in `content/utility/*.json`.

**Not brought in:** armour (everyone starts on the same base armour; better plates are found, and
armour levels up by damaging rival hunters, `Hunter.armor_gain`, now shown on the HUD), perks (in the
match only), the workshop and guild-project perks, and a bigger pack (pack size is one number for all).
The Boki you raise is the one persistent difference.

**The utility belt (replaces the "kit" gear slot):** three slots on keys 1, 2 and 3. A slot holds one
item with charges. Items: tonic (heal), armour kit (repair), and smoke, jump pad, scanner and mending
kit (moved from gloves), plus a swift draught and a shield cell. Everyone is issued two tonics and two
armour kits; more can be brought (from the farm stash, capped by tier), found and bought. The whole
belt is lost on death (it goes into the deathbox). Public API: `UtilityBelt.grant(h, id, n)`,
`count`, `take`, `use`, `belt_of`. The old kit passives (field_kit, magpie, satchel, spyglass,
tinker_roll) leave gear and come back as perk orbs (ext/perkorbs).

**Removed:** the free-kit loaner run, its extract-minimum top-up, text and checks (everyone is on
equal footing, so there is nothing to lend). The economy floor (a stray common Boki when you have none)
and the last-Boki guard stay.

**Save migration (v5 to v6):** armour and kit pieces in the armory convert to farm materials and gems
(full item value in gems plus the extraction materials for its rarity). The four glove-turned-utility
pieces (smoke, jump pad, scanner, mending) become utility charges in the stash. Bought backpack levels
are refunded. Gloves and boots stay. A one-time notice lists everything that converted.

## The split of ext/equal
Three parallel branches, merged into ext/equal afterwards, then a shop/legend pass.
- **ext/equal-loadout (this note):** bring-in rules, no armour from home, armour-level HUD, the
  utility belt and its API, loaner removal, save migration.
- **ext/perkorbs:** perks as orbs from chests, shrines and bosses (no 1/2/3 prompt), the boss fan,
  bot orb pickup, orb sync, the old kit passives as perks, the fixed per-hero weapon path
  (note 0006).
- **ext/keys-cover:** one chest type, keys and key carriers, the bush mimic, hiding cover on The
  Hollow Crown (note 0007).
- **Later:** in-match shops (they sell armour and repairs, boots, utility via `UtilityBelt.grant`,
  weapon perks) and the full-map legend for shop themes and area leans.

Where parts meet: this branch owns utility definitions and the belt API; perkorbs owns the perk pool
and frees keys 1/2/3 by deleting the perk prompt; keys-cover owns keys and chests.

## Consequences
- Save version 5 to 6 (`EqualMigrate`). No Net sync change in this part (the belt is local state, like
  tonics were), so no Net.VERSION bump.
- New: `UtilityBelt`, `UtilityUse`, `Equal` (bring-in rules), `BeltHud`, `ArmorHud`, `HomeBelt`,
  `EqualMigrate`, `content/utility/`, `content/rules/equal.json`, `--equal-check`,
  `--equal-migrate-check`.
- Removed: `Loaner`, `HomeFreeKit`, the "kit" gear slot and its five pieces, four utility gloves'
  gear files, `Econ` pack upgrades, workshop/forge/lighthouse match perks.
- Settings: the heal and armour-kit actions become `util1`, `util2`, `util3` (keys 1, 2, 3); old
  custom bindings for the two move across.
- Debt: the armory is now gloves, boots and utility only; a salvage/trophy log is not built.
