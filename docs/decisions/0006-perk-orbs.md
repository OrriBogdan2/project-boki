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
- **Net.** `odrop` (id, perk, fan, x, y, z) when orbs spawn and `otake` (id, taker) when one is taken; the other game spawns or removes it and records the fan. Two games taking the same orb in the same instant both get it (same as ground pickups). Net 0.13.0 to 0.14.1.
- **Bots** walk to the orb they want most within 16 m (`PerkOrbs.bot_goal`, goal kind "orb", before chests), never take two from one fan, and skip perks they have maxed.
- **Level-ups.** Skill points and ability ranks are unchanged. On every even level a hero's signature weapon takes the next step of its path (`WeaponPath`, `content/rules/weapon_path.json`: five WeaponUps steps for each hero in `Arch.ORDER`). A step an orb already maxed becomes the next open plain upgrade. A banner (`LevelPop`) names the level and what improved. Brands and extra stacks are only in the orb pool.

## Consequences
- Removed: `offer_perks`, `choose_perk`, `perk_offer`, `perk_queue`, the 1-3 perk keys and the prompt cards. Keys 1, 2 and 3 are free for the utility belt.
- Public API for other parts: `PerkOrbs.drop(m, source, pos, n, h)`, `PerkOrbs.spawn(m, perk, pos, id, fan, send)`, `PerkOrbs.grant(h, perk_id)`, `PerkOrbs.list(m)`, `PerkOrbs.gem_mult(h)`; `WeaponPath.on_level(h, lvl)`.
- Checks: `--perkorb-check` (no prompt, drops, fan fade, sync, every hero's path, bots). `--perk-demo` now drops a fan and levels up for screenshots.
- Net.VERSION 0.14.1. No save change (perks are never saved).
- Left: chest and boss gear tables in `content/rules/gear.json` still also drop weapon tunings on the ground; the shop part decides whether to thin them.
