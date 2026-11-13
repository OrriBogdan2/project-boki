# 0006: Perks as orbs on the ground (the level-up weapon path was retired)

- **Status:** accepted (owner design, 09:45 ET "ext/equal FINAL SPEC", part B of the split described in 0005)
- **Date:** 2026-11-02
- **Area:** match flow / networking / UI

## Problem
Perks were chosen from a "Pick a perk: 1/2/3" prompt after a chest, shrine, boss or even level. The prompt stops the action, takes keys 1, 2 and 3 (which the utility belt needs now), and a bot just took the first perk. The even-level weapon upgrade was also a choice.

## Options
1. Keep the prompt and move it to other keys: rejected, it is still a menu in the middle of a fight.
2. Perks as ground pickups that reuse the weapon-pickup list (`wpicks`): rejected, the 12 places that read `wpicks` all assume gear, tunings or treasure.
3. Perks as their own orbs with their own list, synced the same way as `wpicks` (decided).

## Decision
- **Orbs** (`PerkOrbs`, `scripts/match/perk_orbs.gd`; numbers and the pool in `content/rules/perk_orbs.json`). A floating core with the perk's icon and name in its colour, a bob and motes. Walk into one to take it: no prompt. Chests drop 1, shrines 1 or 2, bosses (the Warden, lair bosses) a fan of 3 different perks. A brute's 50% perk is one orb.
- **Leans.** Each perk is in a kind (flat stats, weapon, old kit passives); each source weights the kinds. Shrines lean to flat stats (dash charge, glide, health, reload, gem bonus). Chests and bosses lean to weapon perks (brands, magazine, range, fire rate). Rolls use the match's seed through their own stream, so orbs never shift other loot.
- **The fan.** Taking one orb removes it for everyone and records the taker on the fan; the other orbs fade on the taker's screen and cannot be taken by the taker, but anyone else can still take them (each of them one).
- **Old kit passives** field_kit, magpie, satchel, spyglass and tinker_roll are perks now with the same numbers (the kit gear files stay until agent A removes them from gear). Magpie's gem bonus used to be a stat nothing read; `PerkOrbs.gem_mult` makes it work, with Scavenger.
- **Net.** `odrop` (id, perk, fan, x, y, z) when orbs spawn and `otake` (id, taker) when one is taken; the other game spawns or removes it and records the fan. Two games taking the same orb in the same instant both get it (same as ground pickups). Net 0.14.0 to 0.15.2 (the split gives A 0.15.1, B 0.15.2, C 0.15.3; the main session reconciles).
- **Bots** walk to the orb they want most within 16 m (`PerkOrbs.bot_goal`, goal kind "orb", before chests), never take two from one fan, and skip perks they have maxed.
- **Level-ups.** Skill points and ability ranks are unchanged. *(Retired 2026-11-09, ext/level-growth-parity: the even-level weapon path (`WeaponPath`, `weapon_path.json`) is gone, per the 2026-11-05 decision "no random weapon stat bonuses on level-up". A level now gives one skill point, a gold wash, the badge pop and the quiet `LevelGrowth` health and ability power the source also gives; weapon upgrades come only from orbs and tunings.)* The lane line (`Hud.level_up`, `MsgLane`) names the level and the skill point.

## Consequences
- Removed: `offer_perks`, `choose_perk`, `perk_offer`, `perk_queue`, the 1-3 perk keys and the prompt cards. Keys 1, 2 and 3 are free for the utility belt.
- Public API for other parts: `PerkOrbs.drop(m, source, pos, n, h)`, `PerkOrbs.spawn(m, perk, pos, id, fan, send)`, `PerkOrbs.grant(h, perk_id)`, `PerkOrbs.list(m)`, `PerkOrbs.gem_mult(h)`; `WeaponPath.on_level(h, lvl)`.
- Checks: `--perkorb-check` (no prompt, drops, fan fade, sync, every hero's path, bots). `--perk-demo` now drops a fan and levels up for screenshots.
- Net.VERSION 0.15.2. No save change (perks are never saved).
- Left: chest and boss gear tables in `content/rules/gear.json` still also drop weapon tunings on the ground; the shop part decides whether to thin them.

## Level-up growth (built, owner-approved)
The owner approved parts 1 and 2 of the proposal below and turned down part 3.
- **Quiet growth** (`LevelGrowth`, `scripts/match/level_growth.gd`; numbers in `content/rules/level_growth.json`). Every level adds 6% of the class's base max health and 5% ability power for levels 2-6, and half that for levels 7-10 (a total of +42% health and +35% ability power at level 10).
  - Ability power multiplies ability damage (`ArchKit.power`, `Effects._power`) and ability heals and shields (`Effects._heal_k`). It does not touch the weapon, whose growth is the weapon path.
  - A Boki's own heals don't grow with its hunter's level.
  - Kit code that reads `m.dmg_mult(h)` directly instead of `power()` doesn't grow yet. The hero-kit owners can switch it over.
  - The new health is added to the bar. A class change in practice keeps it (`LevelGrowth.reset`).
  - Only levels actually gained grow you. A level set straight on a hunter (practice tools, checks) grows nothing, so fixtures that jump to level 6 keep their numbers.
- **No banner on odd levels.** Every level flashes the level badge and plays the chime. Only even levels, where the weapon takes its path step, name the step and get the gold wash.
- The vitals tooltip on the portrait and level badge gives the totals: "Level N · From levels: +X% max health, +Y% ability power".
- Max health was never synced and still isn't (the same as gear health and Tough Skin), so Net is unchanged.

## Proposal: level-up bonus
Research only, nothing built. The owner asked (11:55 ET, item 13) about a bonus or random roll on level-up that the original game had and that never showed up on screen the way ours does.

**What the original did.** Its level-ups had no random roll. Each level did two quiet things:
- **Base stats went up on their own.** Health, mana and ability power rose every level, more steeply up to level 7 and more slowly after that. After the leveling rework it was about +10 ability power and about 6% more base health per level. Ability power scales most ability damage, healing and shields. There was no banner: the level shows as a small number with a bar in the bottom-left corner.
- **One ability point per level** (levels 1 to 13), spent by ranking an ability up. The ultimate unlocks at 7. Rank 4 adds a special upgrade.

The random part the owner remembers is most likely its powers, which are a separate system. Powers come in rarities from vaults, area bosses and shops, and some areas favour some powers. Our perk orbs, with their per-source leans, already cover that. No source describes a random level-up roll.

**Closest equivalent for us (proposed):**
1. **A quiet stat growth on every level** (`content/rules/level_growth.json`, applied in `Hunter.gain_xp`): +6% max health and +5% ability power (a multiplier on ability damage, healing and shields) for levels 2-6, then half that for levels 7-10. That gives about +40% health and +32% ability power at level 10. Nothing pops up for it. The level badge's tooltip and the stats panel show the totals, and the level number flashes briefly.
2. **Make our banner quieter to match.** Show the `LevelPop` banner only on even levels, where the weapon path takes a step. On odd levels just flash the badge and play the chime.
3. **Optional, our own idea, not from the original:** a seeded "lucky level". On a level-up there's about a 15% chance (its own RNG stream) that a perk orb with the shrine lean pops at your feet. It gives a small surprise without a menu. Leave it out if the owner wants to stay close to the original.

Questions for the owner: build 1 and 2? Is 3 wanted? Should bots get the same growth? (Yes, if it's fair.)

**Sources:**
- Level page, SUPERVIVE Wiki: https://supervive.wiki.gg/wiki/Level
- Leveling Rework + Big Balance Patch: https://supervive.wiki.gg/wiki/Leveling_Rework_%2B_Big_Balance_Patch
- List of Hunter Base Stats: https://supervive.wiki.gg/wiki/List_of_Hunter_Base_Stats
- Glossary (Powers, Relic Shops): https://supervive.wiki.gg/wiki/Glossary
- Players on per-level gains ("~6% base hp increase and +10 ability power per level"): https://steamcommunity.com/app/1283700/discussions/0/603021563739010834/
- Steam announcements (rank-4 upgrades, level 15 caps): https://steamcommunity.com/app/1283700/announcements/
- Powers by rarity, area-specific: https://dignitas.gg/articles/how-to-thrive-in-supervive-a-general-introduction

## Weapon tier-up (shards)
Research only, nothing built. The owner corrected the memory above: the random choice was on weapon tier-ups, not level-ups.

**What the original did:**
- **Name.** The random fourth option is a **Warped evolution** ("Warped equipment"). It arrived in the Season Zero update ("Beebo's Warped Tour").
- **Currency.** Equipment, including the weapon slot, is upgraded with gold or with shards ("Power Shards" or "Upgrade Shards"; the wiki uses both names for one page).
  - Shards are loot from hunter deaths. One guide also says they come from killing creeps.
  - The wiki says a shard can "fully upgrade a piece of Equipment without having to visit a shop and spend gold".
  - Duplicates of an item you pick up also upgrade it.
- **Where and when.** At first, upgrades were bought with gold at any shop or basecamp. From Season Zero you can upgrade anywhere, any time, with ALT + 1-4 (one key per equipment slot), and normal shops stopped selling equipment.
- **Tiers.** Items climb the rarity tiers (white, green, blue, purple, legendary). The starter weapon (a Blade or a Helmet) evolves at Common into a choice of evolved items. At Blue (Rare) you get the big evolution choice, and that is where the item gains its passive (the guide calls Blue "a crucial breakpoint in power").
  - **Not found:** the shard or gold cost per tier. No wiki page, guide or patch note I could reach gives the numbers.
- **The three fixed options.** These are per item, not per hero and not random: each item has its own three evolutions. Players "often choose the same evolves, over and over", which is why Warped was added.
- **The fourth, rolled option (Warped).** It keeps the item's base stats and rolls one random passive:
  - 75%: a passive from any other blue item.
  - 20%: that passive plus extra stats from the evolution it came from. This is the owner's "+HP and +damage together".
  - 5%: one of three unique "legendary" passives.
  - Its rarity shows as stars on the item icon's corner.
  - No source mentions a reroll.
- **On screen.** An evolution picker shows the options as item cards side by side, with the Warped card starred. It only opens when you upgrade, not on a level-up.

**How the original did it, in short:**
- The upgrade is per item. Each equipment item (weapon, glove, boots and so on) has its own level-up button: an upgrade arrow on the item's slot, or ALT + its slot number. It costs gold or a shard.
- It doesn't use skill points and isn't tied to the hunter's level.
- At the big tier (Blue), the item offers its own 3 fixed evolutions plus 1 rolled Warped option.

**Does it fit us?** Partly. Our power in a match already grows on three tracks:
- perk orbs (random, found)
- quiet level growth (the even-level weapon path was retired)

Gloves are deliberately flat: the owner asked that they never rank up with skill points (11:40 ET). A shard tier-up would be a fourth track, and on gloves it would change that rule. It wouldn't use skill points, but gloves would grow in the match.

Pros:
- It gives a reason to fight for shards, and a downed rival drops theirs.
- It's a real choice, and the rolled fourth card keeps builds from repeating.
- It fits the "power comes from the match" decision. Gloves brought in at a capped rarity could climb during the run.
- The button on the item is easy to read: you see what you're upgrading.

Cons:
- It adds another currency and another UI next to gems, keys and orbs.
- It overlaps with perk orbs, which are already random power, and with in-match shops.
- It loosens the "gloves don't rank up" rule and the equal-footing tier caps. A glove can pass the cap in the match.
- It's one more thing for bots to learn, and it needs sync.

**One lightweight version, if wanted (not recommended over what we have, just an option):**
- Shards are a match-only currency (from rivals, bosses and brutes; lost in your deathbox).
- Hovering a glove box (Q or V) shows a small upgrade arrow when you have enough shards (2 / 4 / 6 per rarity step). Click it to tier the glove up one rarity.
- The step to Rare and up shows 4 small cards without pausing:
  - 3 fixed options from that glove's own content list (stronger, faster cooldown, a side effect)
  - 1 rolled "Wild" card: a mixed pair such as +health and +damage, or a passive from another glove. It's rolled once, with no reroll.
- The signature weapon keeps its fixed path; this only touches gloves.

Not built. The owner and the main session decide.

**Sources (tier-up):**
- Weapons, SUPERVIVE Wiki (Common and Rare evolutions, the Warped fourth option and its odds): https://supervive.wiki.gg/wiki/Weapons and https://supervive.wiki.gg/wiki/Weapon
- Season Zero Arc 1 "Beebo's Warped Tour" patch (Warped as the 4th Blue choice, ALT + 1-4 upgrades anywhere): https://supervive.wiki.gg/wiki/Season_Zero_Arc_1_Beebos_Warped_Tour
- PCGamesN on the Season Zero update (why Warped exists, the odds): https://www.pcgamesn.com/supervive/season-zero-launch
- Power Shard, SUPERVIVE Wiki (loot from player deaths, upgrade without a shop): https://supervive.wiki.gg/wiki/Power_Shard
- Items, SUPERVIVE Wiki (duplicates and power shards upgrade equipment): https://supervive.wiki.gg/wiki/Items
- Equipment, SUPERVIVE Wiki (gold prices by rarity): https://supervive.wiki.gg/wiki/Equipment
- GameLeap equipment list (Upgrade Shards from creeps and hunters, three evolutions per weapon): https://www.gameleap.com/articles/all-supervive-equipment-in-the-open-beta
- Dignitas intro (a Blue-tier evolution gives a passive of your choosing; shards from killed players): https://dignitas.gg/articles/how-to-thrive-in-supervive-a-general-introduction
