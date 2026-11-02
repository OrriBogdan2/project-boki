# 0005: Equal footing in matches (ext/equal)

- **Status:** accepted
- **Date:** 2026-11-02
- **Area:** match flow / save / combat / net / farm / UI

## Problem
Power in a match came from home: worn armour, a bigger pack, workshop and guild-project perks, a
loaner kit. A player with a rich farm started stronger than a new one. The owner wants an extraction
game where you can bring a little in, but power mostly comes from the match: everyone drops with the
same body, then finds, buys and earns the rest. Your Boki is the one lasting difference.

## Options
1. Pure equal start (bring nothing). Fair, but nothing to keep on the farm and no extraction stakes.
2. Bring everything and balance with tiers. Keeps the farm loop, keeps the power gap.
3. Bring a small, capped, at-risk set (two gloves, boots, utility) and nothing else.

## Decision
Option 3. The whole ext/equal design, by part:

**Bring-in (ext/equal-loadout).** From home: the two gloves, boots and up to three utility items.
Everything brought is at risk (it drops in your deathbox). Rarity is capped by difficulty tier
(`content/rules/equal.json` `rarity_cap_by_tier`: Rare, Epic, Legendary for The Meadow, Dusk Isles,
The Hollow); utility stacks are capped per item per tier (`content/utility/*.json` `bring`). Not
brought: armour (everyone has the same base armour; better armour is found, and armour levels up by
damaging rival hunters, `Hunter.armor_gain`, shown by `ArmorHud`), perks, the workshop and guild
project perks, and pack size (one `Equal.BASE_PACK` for all).

**Two gloves, no ranks.** Glove 1 on Q, glove 2 on V. Either slot holds an active or a passive glove,
never two of the same (`Gloves.slot_for`). Gloves never rank: "gear" is gone from `Hunter.SLOTS` and
`SLOT_MAX`; skill points go to the hero's own abilities only (bots too). A glove's strength is its
rarity. Gloves chain with each other and with hero kits (a hook into a fissure). V also plays fetch
at home; the two never apply in the same place (`Settings.SHARED_OK`).

**HUD and overhead.** The right of the bottom HUD has three boxes: Q glove, V glove, C Boki (type
badge, C cooldown, a bond ring, a down mark) in `GripHud`. Over every other hunter's nameplate, three
small icons: two gloves (rarity frame, dim on cooldown) and the Boki type (soft glow on a full bond),
in `GripOverhead`; remote hunters' gloves, cooldowns and bond ride in the snapshot (`GripNet`).

**Utility belt on 1/2/3.** Replaces the "kit" gear slot and the heal / armour-kit keys. Each slot
holds one item with charges: tonic, armour kit, and smoke, jump pad, scanner and medkit (moved from
gloves), plus a swift draught and a shield cell. Everyone is issued two tonics and two armour kits;
more are brought (capped), found and bought. The whole belt goes in the deathbox. API:
`UtilityBelt.grant(h, id, n)` (returns how many fit), `count`, `take`, `has_room`, `use_id`.

**Removed.** The free-kit loaner, its extract-minimum top-up, text and checks. The economy floor (a
stray common Boki) and the last-Boki guard stay.

**Save v5 to v6** (`EqualMigrate`). Armour and kit pieces become gems (full item value: 3, 8, 18,
36, 70 by rarity) plus the extraction materials for their rarity; the four gloves that became
utility items become stash charges (1, 2, 2, 3, 4 by rarity); bought backpack levels are refunded.
Gloves and boots stay; the V glove slot starts empty. A one-time farm notice lists every conversion.

**Perk orbs (ext/perkorbs, note 0006).** Chests, shrines and bosses drop perk orbs you walk into (no
1/2/3 prompt); bosses drop a fan of three that fades for you only; bots walk to orbs; orbs sync like
wpicks; the old kit passives (field_kit, magpie, satchel, spyglass, tinker_roll) become perks; a
fixed per-hero weapon path on even levels.

**Keys and cover (ext/keys-cover, note 0007).** One chest type opened by keys; key carriers per region
with a seeded stream; the bush mimic; hiding cover on The Hollow Crown by biome.

**Later (one pass after the parts).** In-match shops at fixed landmarks (armour and repairs, boots,
utility via `UtilityBelt.grant` and `UtilityBelt.price_of`, weapon perks) and the full-map legend.

## The split and where parts meet
- loadout owns utility definitions (`content/utility/`, `UtilityBelt`, `UtilityUse`), bring-in
  (`Equal`), gloves (`Gloves`, `GripHud`, `GripOverhead`, `GripNet`) and the migration.
- perkorbs owns the perk pool; it frees keys 1/2/3 by deleting the perk prompt (until then the belt
  keys yield to an open prompt, `Match._gather_input`).
- keys-cover owns keys, chests and cover; its key count sits beside the belt on the HUD.
- the shop pass calls `UtilityBelt.grant` / `price_of` and reads `Equal.rules()`.

## Consequences
- Save version 6. Net.VERSION 0.15.1 (the hunter snapshot gains GripNet's five fields).
- New: `Equal`, `UtilityBelt`, `UtilityUse`, `UtilityDrops`, `BotBelt`, `Gloves`, `GripHud`,
  `GripOverhead`, `GripNet`, `BeltHud`, `ArmorHud`, `HomeBelt`, `HomeNotices`, `EqualMigrate`,
  `--equal-check`, `--equal-migrate-check`.
- Removed: `Loaner`, `HomeFreeKit`, the "kit" gear slot and its five pieces, the four utility gloves'
  gear files, `Econ` pack upgrades, the workshop/forge/lighthouse match perks, glove ranks.
- Reserved-file hook for the main session: the left bar still draws C through
  `BokiHud.cg_slots` (C and G together); split it so the left bar draws G only.
