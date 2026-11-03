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
3. Bring a small, capped, at-risk set (two gloves, boots, utility, a backpack) and nothing else.

## Decision
Option 3. The whole ext/equal design, by part:

**Bring-in (ext/equal-loadout).** From home: the two gloves, boots, up to four utility items and a backpack.
Everything brought is at risk (it drops in your deathbox). Rarity is capped by difficulty tier
(`content/rules/equal.json` `rarity_cap_by_tier`: Rare, Epic, Legendary for The Meadow, Dusk Isles,
The Hollow); utility stacks are capped per item per tier (`content/utility/*.json` `bring`). Not
brought: armour (everyone has the same base armour; better armour is found, and armour levels up by
damaging rival hunters, `Hunter.armor_gain`, shown by `ArmorHud`), perks, the workshop and guild
project perks. The base pack is the same for all (`base_pack`, the free Pouch).

**Every item exists once.** Knocked is not dead: a teammate's pickup keeps everything. On death
everything you carry goes in your deathbox (gloves, boots, utility, backpack, loot); revived, you
have your hunter's base kit and the Pouch, and can run back for what is left. An enemy who takes it
and extracts keeps it; a brought item is gone for good then.

**Backpacks** (`Backpacks`, `HomeBackpacks`). Tiers Pouch (free, +0), Satchel (+2), Pack (+4),
Rucksack (+6), in `content/rules/equal.json` `backpacks`. Bought at the armory for gems and scrap
(never real money), one picked for the expedition, capped by difficulty (`backpack_cap_by_tier`:
Satchel, Pack, Rucksack). In a match there are no random backpack drops: you take a bigger one from
an enemy's deathbox (yours stays in its place) or buy the next tier at a shop (`backpack_shop`, run
gems). The satchel perk orb (+1 slot) stays. The size has one source: `Equal.pack_slots(h)` = base +
the worn backpack + gear and perk "pack" stats. Some bots set out with a bigger one (`bot_backpack`).

**Two gloves, no ranks.** Glove 1 on Q, glove 2 on V. Either slot holds an active or a passive glove,
never two of the same (`Gloves.slot_for`). Gloves never rank: "gear" is gone from `Hunter.SLOTS` and
`SLOT_MAX`; skill points go to the hero's own abilities only (bots too). A glove's strength is its
rarity. Gloves chain with each other and with hero kits (a hook into a fissure). V also plays fetch
at home; the two never apply in the same place (`Settings.SHARED_OK`).

**HUD and overhead.** The right of the bottom HUD has three boxes: glove 1, glove 2 and the Boki
on the Merge key (type badge, a bond ring that pulses when the Merge is ready, a down mark) in
`GripHud`. Every key shown comes from `Settings.key_cap` (gloves "gear1"/"gear2", Merge "ultimate"),
so the owner's later move of Merge to C needs no change here. Over every other hunter's nameplate, three
small icons: two gloves (rarity frame, dim on cooldown) and the Boki type (soft glow on a full bond),
in `GripOverhead`; remote hunters' gloves, cooldowns and bond ride in the snapshot (`GripNet`).
The overhead row sits under each plate in the row `HudStyle.PLATE_ICON_ROW` leaves free. Every
loadout widget draws with ext/hudref's `HudStyle` (slot frames, key pills, count badges, colour
roles), merged in here because hudref isn't on main yet; the armory's backpack tiers use
ext/uipolish's `UI.card` (UiFrame). No second palette: backpacks are `UI.ACCENT_HI`.

**Utility belt on 1-4.** Replaces the "kit" gear slot and the heal / armour-kit keys. Each slot
holds one item with charges: tonic, armour kit, and smoke, jump pad, scanner and medkit (moved from
gloves), plus a swift draught and a shield cell. Everyone is issued two tonics and two armour kits;
more are brought (capped), found and bought. The whole belt goes in the deathbox. API:
`UtilityBelt.grant(h, id, n)` (returns how many fit), `count`, `take`, `has_room`, `use_id`.

**Keys on the belt (owner, 17:55).** A Rift Key and a chest key each take one belt slot while you
carry any, with the count on the icon, so you always see whether you carry one and carrying one costs
a slot. The counts stay the truth (`h.rift_keys`; `h.chest_keys` through `KeyChest`); `BeltKeys.sync`
shows them on the belt and spends through `KeyChest.take`. Caps: Rift Keys 1 (`content/utility/rift_key.json`),
chest keys `KeyChest.cap()` (3). A key that doesn't fit stays on the ground and a prompt offers a swap:
pressing a slot's key drops that slot's items and takes the key (bots drop their cheapest stack);
nothing is thrown away. F at a hatch or chest still opens it; the key's slot opens the lock beside
you, or elsewhere pings the nearest one on your map. Keys go in the deathbox, and are never brought
in, sold or taken home, so the market's Rift Key is gone (stash keys in an old save are refunded at
its price, 140 gems).

**Removed.** The free-kit loaner, its extract-minimum top-up, text and checks. The economy floor (a
stray common Boki) and the last-Boki guard stay.

**Save v5 to v6** (`EqualMigrate`). Armour and kit pieces become gems (full item value: 3, 8, 18,
36, 70 by rarity) plus the extraction materials for their rarity; the four gloves that became
utility items become stash charges (1, 2, 2, 3, 4 by rarity); a bought backpack level L becomes one tier-L backpack (picked), and the levels below it are refunded
at what they cost (120 gems 4 scrap, 260 gems 10 scrap), so nothing paid is lost.
Gloves and boots stay; the V glove slot starts empty. A one-time farm notice lists every conversion.

**Perk orbs (ext/perkorbs, note 0006).** Chests, shrines and bosses drop perk orbs you walk into (no
1/2/3 prompt); bosses drop a fan of three that fades for you only; bots walk to orbs; orbs sync like
wpicks; the old kit passives (field_kit, magpie, satchel, spyglass, tinker_roll) become perks; a
fixed per-hero weapon path on even levels.

**Keys and cover (ext/keys-cover, note 0007).** One chest type opened by keys; key carriers per region
with a seeded stream; the bush mimic; hiding cover on The Hollow Crown by biome.

**Later (one pass after the parts).** In-match shops at fixed landmarks (armour and repairs, boots,
utility via `UtilityBelt.grant` and `UtilityBelt.price_of`, weapon perks) and the full-map legend.

**Loadout layout (owner, 15:25).** The full layout is: 2 gloves (Q, V), 2 charms (a new minor item
kind, not on a key), boots, 4 utility slots (1-4), up to 5 perk orbs, and no upgrading of anything.
Built so far: gloves, boots, the belt on 1-4, backpacks, no ranks. Not built yet: charms (a follow-up;
old minor glove-like items map to charms then).

## The split and where parts meet
- loadout owns utility definitions (`content/utility/`, `UtilityBelt`, `UtilityUse`), bring-in
  (`Equal`), gloves (`Gloves`, `GripHud`, `GripOverhead`, `GripNet`) and the migration.
- perkorbs owns the perk pool; it frees keys 1/2/3 by deleting the perk prompt (until then the belt
  keys yield to an open prompt, `Match._gather_input`).
- keys-cover owns chests, key carriers and cover, and `KeyChest.count / take / give / cap`, which the
  belt reads and spends through; its own key counter is gone (merged in here at be46e223).
- the shop pass calls `UtilityBelt.grant` / `price_of`, `Backpacks.shop_price(h)` / `shop_upgrade(h)`,
  and reads `Equal.rules()`.

## Consequences
- Save version 6. Net.VERSION 0.17.5 (the hunter snapshot gains GripNet's five fields after ArchKit's
  move id, then hudref's run level). Deathboxes are local, so backpacks need no sync.
- New: `Equal`, `UtilityBelt`, `UtilityUse`, `UtilityDrops`, `BotBelt`, `Gloves`, `GripHud`,
  `GripOverhead`, `GripNet`, `BeltHud`, `ArmorHud`, `HomeBelt`, `HomeNotices`, `EqualMigrate`,
  `Backpacks`, `HomeBackpacks`, `--equal-check`, `--equal-migrate-check`, `--backpack-check`.
- Removed: `Loaner`, `HomeFreeKit`, the "kit" gear slot and its five pieces, the four utility gloves'
  gear files, the permanent `Econ` pack levels (now backpacks), the workshop/forge/lighthouse match perks, glove ranks.
- Reserved-file hook for the main session: the left bar still draws the Boki ability and orders
  through `BokiHud.cg_slots`, and the Merge through `BokiHud.r_slot`; once the Boki ability joins G
  and Merge moves to C, the left bar can drop its Merge slot (the right side's Boki box shows it).
