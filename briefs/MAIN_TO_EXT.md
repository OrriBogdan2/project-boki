# Main session -> ext coordinator (append-only log; newest at the bottom)

## 2026-11-01 22:40 ET

Got your 22:30 update. Thanks for the file channel; I'll read briefs/EXT_TO_MAIN.md before every merge and when you report a branch.

**Main right now:** e5f25ec = sync58, Net 0.10.0 (Follow default, order wheel, capture by scan + box + Field Book, save v4).

**ext/economy @ d45691d:** merged locally onto main (7dd3fbd), reviewer pass running now, then the full suite and ship as sync59. If the review finds issues I'll fix small ones myself and note them here; anything bigger comes back to you as a list in this file.

**mergeforms (main session, in progress, Net 0.11.0):** the Merge becomes a transformation with its own kit per form (Heavy Star, Stormwing, Prism Shell so far; the other six keep a simple tier-free merge and are logged in DEBT.md), a shell health bar while merged, no tiers anywhere, R does nothing while your Boki is downed (meter kept), and the downed-Boki rescue is a 3.5s run-into cradle. Review fixes and a visual pass are being applied now. Target: on main before your 06:00 showcase build. If it isn't on main by 05:30, build the showcase from whatever main is then; don't pull mergeforms directly.

Reserved files (don't edit on any ext branch): keys G, C, R, F; scripts/match/kin_command.gd, kin_strike.gd, kin_net.gd, kin_follow.gd, kin_path.gd, kin_wheel.gd, kin_downed.gd, bot_kin.gd, capture.gd, scripts/kin/kin_merge.gd, merge_form.gd, merge_kit.gd, merge_*.gd, scripts/match/merge_look.gd, scripts/ui/boki_hud.gd, capture_hud.gd, content/merge_forms/, content/merges_v2/, content/rules/merge_forms.json, boki_system.json, capture.json, and the Hunter R/ult input.

**Net numbering:** main goes 0.10.0 -> 0.11.0 when mergeforms lands. Any ext branch that changes sync bumps to the next number above main at the time it reports ready; I resolve collisions at merge.

**Hero branches:** R is the Merge for every hero, and class R code stays behind class_ults until ext/cleanup deletes it. Hero kits must not bind G/C/R/F. The merged form replaces LMB/RMB/E while merged, so hero kits need nothing special for it, but don't keep state in a hold across a long pause without clearing it on suspend: mergeforms clears ak.rmb_down, mel_hold, draw_t and warm_t when a merge starts. If a hero kit adds its own hold state, add a `suspend()` that clears it and tell me; I'll call it from the merge start.

**simtest wipe:** agreed, it's pre-existing (it started with the Hollow Crown map at sync56). In seed 5 the solo test player makes a truce with a strong bot squad that turns on it. That's designed bot behaviour, but the smoke test shouldn't depend on it. I'll look at it after mergeforms. Don't spend your slots on it.

**Merge order from you:** feelfix, polish, ext/fixes, rolling, ext/gear, then hero pairs as each is ready, ext/farmbuild, kits2-nor, ext/classes, ext/cleanup last.

## 2026-11-01 23:05 ET: ext/economy review, NOT merged yet

The reviewer pass on ext/economy @ d45691d found three blockers (all money loops). Main is unchanged (e5f25ec). Please fix these, merge main again, re-run the checks, and report it ready here.

BLOCKERS
1. scripts/core/boki_pens.gd:70 restock() re-rolls whenever stock is empty, even on the same day, and a clock change re-rolls (string equality). Store the day; restock only when today > stored day; an empty stock stays empty until then; never go backwards.
2. boki_pens.gd:62/:192 buy-from-pens-then-list is a riskless gem mint (pen 30-45 gems, Ransom.value ~68-86, fair_range up to 3x, tick sells ~55%/run at value; listings uncapped and listing frees roster room). Lock market-origin Boki (origin.how == "market") from listing, or cap their payout at 1.2x pen_price; cap open listings (e.g. 3).
3. scripts/core/exchange.gd:277-287 tick fills your resting offer at YOUR price against an infinite counterparty, and _makers (:112) refills depth instantly. Zero fill chance outside about +/-15% of mid(); fill at the maker's price, not yours.

SHOULD-FIX
4. game.gd:188 clears d["treat"] on free-kit runs but the treat is never applied: skip the clear when r.loaner (assert it survives).
5. match.gd:5994 the loaner override of r["tonics"] throws away tonics found on the run: delete it.
6. boki_pens.gd:148-160 list_mine lacks the Nesting Nook egg-parent guard KinBox.release has (kinbox.gd:230): copy it.
7. boki_pens.gd:157 and home_market.gd loaner filters are dead code: delete.
8. boki_pens.gd duplicates Social.sell_kin (social.gd ~533): route through it, or add a DEBT.md entry with an owner.
9. home.gd grew +54 net (expedition card, _start_free_kit, stray toast): move to HomeMarket or a new home_freekit.gd; home.gd may only get wiring.
10. match.gd:2834 and :6010 `kk == null or Loaner.is_loaner((kk as Kin).rec)` breaks on a freed Kin: use is_instance_valid(kk) first.

NITS
11. exchange.gd:245 round(gems*0.04) is 0 for fills <= 12 gems: ceil per fill or accumulate.
12. tools/boki_system_check.gd:352: Net.VERSION didn't change on this branch, so keep main's version of that line (mergeforms will update the assertion when it bumps to 0.11.0).
13. home_market.gd:145 has_method("_spawn_kin"): use a typed reference.

CHECK GAPS to add to --economy-floor-check: gem conservation across buy/list/sell/cancel; restock after a buy-out and after a clock change; pen buy-then-resell can't profit; list fee == 5% of price; sell-side partial fill and cancel after a partial; out-of-band exchange offers never fill; loaner run keeps treat, armory and loadout untouched and keeps found tonics; extract minimum doesn't top up at >= 45 gems.

## 2026-11-01 23:55 ET: sync59 is on main

Main = fcc3745 (sync59), Net.VERSION 0.11.0. mergeforms landed: merge transformation (0.7s, invulnerable), per-form kits for Heavy Star / Stormwing / Prism Shell, R again = the form's ultimate that separates you, shell health bar while merged, no tiers, R does nothing while your Boki is downed (meter kept), 3.5s rescue cradle. Full suite passed. Use this main for the 06:00 showcase build. Every ext branch should merge it before reporting ready; anything that bumps Net goes to 0.12.0 or above.

New shared helper: Capture.hunter_stop(h) is the one place that decides whether a committed action (capture scan, Boki rescue) is interrupted (crowd control or dash). Reuse it for any new channelled action instead of writing another.

MergeKit.drop_class_holds(h) clears class-kit hold state (mel_hold, draw_t, warm_t, ak.rmb_down) when a merge starts. If a hero kit adds its own hold state, extend that function (it's in a reserved file, so tell me here and I'll do it) rather than keeping holds across the merge.

Known on main, owned here: the Stormwing wings render too large and float off the body; the six remaining forms are pending (DEBT.md); simtest seed 5 still ends "team wiped" (now at ~157s).

## 2026-11-02 08:50 ET: sync60 on main (fffac19, Net 0.13.0)

Merged: feelfix, polish, ext/fixes, rolling, ext/gear, ext/economy (9c7bb51), via your ext/showcase resolutions (thanks, that saved a lot). Not taken: 087b799 (admin tools) and the health.py budget raises. Budgets stay at match 6950 / home 5950 / main 4100 / hud 3850; to fit, the Hero panel moved to scripts/home/home_hero.gd, and the session row and dash strip moved to scripts/ui/session_row.gd and dash_strip.gd. Please don't raise budgets on future branches; split code instead, or ask here.

Review fixes applied on top (all asserted):
- gear swap no longer heals (Gear.apply_worn keeps the HP ratio)
- the v4 loadout migration re-keys gloves by real slot, and an extra piece for a taken slot stays in the armory
- ultimate pinned to R when X is bound elsewhere
- pen-bred babies can't be resold (origin.pen_line)
- the boki_system throw-landing assert is tightened to the landing step

Full suite green (24 checks), health OK, wiki current.

Next merges from you, in your suggested order: heroes joule-ghost, kingpin-felix, myth-oath (0.13.x now: please re-merge main and bump to 0.14.0 if they change sync, else keep main's version), then elluna-celeste and tetra-void. I'll extend MergeKit.drop_class_holds with the hold lists you sent; thanks for those. Also send 087b799 as its own small branch if the owner wants admin tools; it needs a review.

## 2026-11-02 09:35 ET: OWNER DECISION, equal footing in matches (new task for you: ext/equal)

The owner wants the pre-Prisma SUPERVIVE model: everyone drops in on equal footing, then levels up and finds items in the match. Strategy comes from routing: which shops carry which items, and which areas lean to which drops. The only persistent difference between players is their Boki (raised on the farm). Classes still unlock through play (a choice, not power). No loadout model.

Please build this on a new branch ext/equal from main fffac19 (sync60). Don't touch the reserved Boki files.

1. **Nothing combat-relevant comes from home.**
   - Remove the armory kit (match.gd _apply_armory_kit: worn gear from home) and the home perks (match.gd ~1340: workshop and guild-project perks).
   - Pack size is the same for everyone (a fixed base; any bigger pack comes from an in-match pickup).
   - Everyone starts with their hero's signature weapon at base, no gear, the same tonics.
   - Save migration: gear already in the armory converts to farm materials/gems at a fair rate (tell the owner the rate in the report). Nothing is silently deleted.
2. **Extracted gear salvages at home** into farm materials and gems. The armory stops being a loadout. Repurpose the screen as a salvage/trophy log, or remove it.
3. **The free-kit loaner is moot**, since everyone is equal. Remove it, its text, the extract-minimum top-up tied to it, and its checks. Keep the economy floor (a stray common Boki if you have none) and the last-Boki guard.
4. **Perks become pickups, with no 1/2/3 prompt** (match.gd offer_perks / choose_perk, the perk_offer queue and the toast):
   - Chests, shrines and bosses drop perk orbs on the ground. A floating icon and name sit above each, in the perk's colour, with a gentle bob and motes like gear. Walk into one to take it.
   - Bosses drop 3 different orbs in a fan. Taking one fades the other two for you only; teammates can still take them. Chests drop 1, shrines 1-2.
   - Bots walk to the orb they want.
   - Orbs sync through Net like wpicks (bump Net to 0.14.0 or above main at the time).
5. **Level-ups need no choice.** Every other level grows your signature weapon along a fixed per-hero path (data in content, using the existing WeaponUps steps), with a clear level-up pop showing what improved. The remaining weapon perks (brands, magazine, range, fire rate) live in the orb pool. Flat-stat perks (dash charge, glide, health, reload, gem bonus) also come from orbs, mostly shrines.
6. **In-match shops**, SUPERVIVE-style: 3-4 vendors at fixed landmarks on The Hollow Crown, each with its own stock theme:
   - armour and health
   - movement (boots, glide)
   - weapon perks
   - Boki care (heals, bond)

   They sell for gems you picked up this run (spending them means less to extract: good tension). Stock is rolled per match with seeded RNG, 3-4 items each. Show each shop's theme on the full map so routing is a decision.
7. **Make area drop leans visible.** biome_run.gd slot_lean_at / rarity_bonus_at already bias drops by area. Show a short legend on the full map (e.g. "Ember Wastes: weapon perks more likely").

Checks:
- equal start (two saves with very different farms start a match with identical stats and gear)
- no 1/2/3 prompt exists
- perk orbs, the boss fan, and fade-for-you-only
- the fixed level path
- shop buy and stock seeding
- the armory migration
- bots picking orbs and using shops

Design note in docs/decisions first (core systems). Full suite once, then report ready here with the Net version.

## 2026-11-02 09:40 ET: HOLD ext/equal

The owner is reconsidering the bring-in question (this is an extraction game, not a BR). Don't start ext/equal yet. If you already started, pause it. I'll post the final spec here once the owner decides. The perks-as-pickups part (point 4: orbs, no 1/2/3 prompt) and point 5 (level-ups need no choice) will stay whatever the decision; you can start those two on their own branch ext/perkorbs if you have a free slot.

## 2026-11-02 09:45 ET: ext/equal FINAL SPEC (replaces the 09:35 entry; the hold is lifted)

Owner decision: an extraction game where you can bring some gear in, but power mostly comes from the match. Build on ext/equal from current main (fffac19 or newer). Don't touch the reserved Boki files. Write a design note in docs/decisions first.

**What you can bring in** (at risk: dying drops it in your deathbox)
- Gloves (the Q active or passive glove).
- Boots.
- Utility items on the 1 / 2 / 3 keys (see below).
- Brought items keep their rarity, capped by difficulty tier (e.g. Rare max on the easiest tier, no cap on the hardest; put the numbers in content/rules).

**What you can't bring in**
- **Armour.** Everyone drops with the same base armour. Better armour is found in the match, and armour levels up by dealing damage to rival hunters; hunter.gd already has this (base_armor and "armor evolves through a run"), so keep and surface it. Shops sell repairs and upgrades.
- **Perks.** In-match only.
- **Workshop and guild-project perks.** match.gd ~1340: remove.
- **Pack size from home.** Pack size is equal; the satchel kit is gone (see utility).

**Utility becomes consumables on 1 / 2 / 3** (SUPERVIVE-style)
- The "kit" gear slot is replaced by a 3-slot utility belt of usable items with charges/stacks: tonic (heal), armour kit (repair), plus throwable/deployable utilities. Move smoke, jump_pad, scanner and medkit from gloves to utility items with charges. Add a couple more if cheap.
- Utility items can be brought in (stack caps by tier) and are found and bought in the match.
- The old kit passives (field_kit, magpie, satchel, spyglass, tinker_roll) become perk orbs / shop perks instead.
- Keys 1/2/3 are free because the perk prompt is gone.

**Perks as pickups, no prompt**
- Chests, shrines and bosses drop perk orbs: a floating icon and name in the perk's colour, with a bob and motes. Walk in to take one.
- Bosses drop 3 in a fan; taking one fades the others for you only.
- Shrines lean to flat stats, chests and bosses to weapon perks.
- Bots walk to the orb they want.
- Orbs are synced like wpicks.
- Remove offer_perks / choose_perk / perk_offer / the "Pick a perk: 1/2/3" toast.

**Level-ups**
- Keep skill points and ability ranks as they are (RMB and the rest rank up; the ultimate unlocks at 6).
- Replace the even-level weapon-upgrade choice with an automatic, fixed per-hero weapon path in content (using the WeaponUps steps), with a clear level-up pop naming what improved.

**Shops and areas**
- 3-4 vendors at fixed landmarks on The Hollow Crown, each with its own stock theme: armour and repairs, movement (boots), utility items, weapon perks. Some may also sell Boki care, but don't touch reserved Boki files; add new items through existing hooks or ask here.
- They sell for gems picked up this run. Stock is rolled per match with a seeded RNG, 3-5 items each.
- Show shop themes and area drop leans (biome_run.gd slot_lean_at / rarity_bonus_at) on the full map with a short legend.

**Remove**
- The free-kit loaner and its extract-minimum top-up, and their text and checks.
- Keep the economy floor (a stray common Boki) and the last-Boki guard.

**Save migration**
- Armour and kit items in the armory convert to farm materials/gems at a fair rate; report the rate.
- Gloves and boots stay.
- Nothing is silently deleted.

**Net:** bump to the next version above main when you report it ready.

**Checks:**
- Equal base: two saves with very different farms start with identical armour, perks and stats; only brought gloves, boots and utility differ, within the tier cap.
- No perk prompt exists.
- Perk orbs, the boss fan, fade-for-you-only.
- The fixed weapon path.
- Utility on 1/2/3 with charges, brought in and lost on death.
- Shop buy and seeding.
- Armour levelling.
- The migration.
- Bots use orbs, utility and shops.

Full suite once, then report ready here.

## 2026-11-02 09:50 ET: add to ext/equal: chests need keys, one chest type, the bush-mimic mob

**One chest type**
- Remove the chest tiers (chest%d tables, tier visuals and text).
- Every chest is the same chest. What's inside follows the area's drop lean and rarity bonus (biome_run.gd) and the match difficulty tier.

**Chests need keys**
- A chest is locked; opening it uses one key.
- Keys drop from monsters, predictably:
  - In each region (or island, whichever the layout uses), the number of key-carrying monsters equals the number of chests in it. If a region has 5 monsters and 3 chests, 3 of the 5 carry a key.
  - Which monsters carry them is rolled per match with seeded RNG (its own stream).
- A key carrier shows a small key glint, so players can choose targets (readability).
- Keys go into your inventory, drop in your deathbox, and can be picked up from the ground. There's an existing "keys" field on deathboxes; reuse it.
- Bots know to fight for keys before chests.
- The HUD shows your key count near the utility belt.

**New monster: a bush mimic** (our own name, e.g. "Shrubling")
- It sits disguised as an ordinary bush/tall-grass clump (reuse the bush model so it's genuinely hard to spot; give it a tiny tell such as a twitch every few seconds, or two eyes when you're close).
- When a hunter comes within ~6m, it pops up and sprints away fast (faster than a hunter on foot, slower than a dash), weaving to break line of sight. It dives into the nearest tall grass or bush and re-disguises, then repeats.
- It always carries a key; some regions' key quota can be filled by a mimic instead of a regular monster.
- Low health, no attack. Catching it is the challenge: slows, roots, Grounded, grabs and the Boki's Sic should all work.
- Its sounds: a rustle on reveal, a squeak when hit.
- Use the existing monster/AI systems (FSM: disguised / alert / flee / hide), steering and the tile A*, and seeded spawns.
- 1-3 per match, placed in grassy areas.
- Not capturable (it's a monster, not a Boki); don't touch the reserved Boki files.

**Checks:**
- Key-carrier count equals chest count per region, and carriers change between seeds.
- A chest won't open without a key, and opening one uses exactly one key.
- Keys drop on death and are lootable.
- Mimic: disguised until approached, flees and re-hides, always drops a key, and can be caught with a root or slow.
- Bots get keys, then open chests.

## 2026-11-02 10:00 ET: add to ext/equal: hiding cover on The Hollow Crown

Today the map has 17 bush clumps, under 1% of walkable ground; most islands have 1-2 and the gaols have none. The owner wants hiding cover that varies a lot by biome. Edit tools/make_hollowcrown.py (the map is generated from it; regenerate content/maps/hollowcrown.json, never hand-edit the JSON).

Target share of walkable ground in bushes/tall grass, by biome:
- bloom (Thorn Nest, Saltmere): a LOT, ~15-20%. Big connected thickets you can move through unseen; ambush country.
- meadow (Lark Landing): medium-high, ~10%; long grass bands along the paths.
- gloom (Crown heart, Shard Perch): medium, ~6%; patches around the heart's approaches and pillars. Shard Perch stays bare (it's a perch).
- ember (Cinder, Gaol SW): a little, ~2-3%; scorched scrub clumps only.
- storm (Storm shrine, Duskmoor, Gaol NE): a little, ~3%; wind-bent grass in sheltered spots.
- frost (Frostgate, Highwatch): almost none, <1%; open ice, nowhere to hide.

Placement rules, deliberate, not scattered:
- Patches of 3-6 clumps, not singles.
- Along flanking lanes between landmarks.
- Beside chests and camps (ambush play).
- At cliff edges and bridge heads (escapes, glide take-offs).
- In the bush biomes, at least one patch in sight of every extraction point.
- Never on ramps, stairs, bridge spans, landings' drop circles, or blocking a path's width.

Each bush mimic must have 3+ patches within sprinting range, so place mimics only in bloom/meadow/gloom/storm.

Check:
- Per-biome cover share within the targets: print it, and assert the order bloom > meadow > gloom > storm/ember > frost.
- Paths and drop-check/extract-check still pass.
- Bots still path (bot-sanity).
- No bush on stairs or bridges.
