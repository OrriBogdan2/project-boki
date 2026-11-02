# 0006: Perks as orbs on the ground, and a fixed weapon path on level-ups

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
- **Level-ups.** Skill points and ability ranks are unchanged. On every even level a hero's signature weapon takes the next step of its path (`WeaponPath`, `content/rules/weapon_path.json`: five WeaponUps steps for each hero in `Arch.ORDER`). A step an orb already maxed becomes the next open plain upgrade. A banner (`LevelPop`) names the level and what improved. Brands and extra stacks are only in the orb pool.

## Consequences
- Removed: `offer_perks`, `choose_perk`, `perk_offer`, `perk_queue`, the 1-3 perk keys and the prompt cards. Keys 1, 2 and 3 are free for the utility belt.
- Public API for other parts: `PerkOrbs.drop(m, source, pos, n, h)`, `PerkOrbs.spawn(m, perk, pos, id, fan, send)`, `PerkOrbs.grant(h, perk_id)`, `PerkOrbs.list(m)`, `PerkOrbs.gem_mult(h)`; `WeaponPath.on_level(h, lvl)`.
- Checks: `--perkorb-check` (no prompt, drops, fan fade, sync, every hero's path, bots). `--perk-demo` now drops a fan and levels up for screenshots.
- Net.VERSION 0.15.2. No save change (perks are never saved).
- Left: chest and boss gear tables in `content/rules/gear.json` still also drop weapon tunings on the ground; the shop part decides whether to thin them.

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
