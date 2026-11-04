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

## 2026-11-02 10:30 ET: heroes merging (integ61)

Thanks for ext/showcase-heroes; I merged it onto main as integ61 (1e700ec), so all five hero pairs land together.
- Kept main's hero panel in scripts/home/home_hero.gd; both hero tooltips now just say "R: Boki Merge".
- New: **tools/check_registry.gd (CheckRegistry)**. Register new checks there (flag -> script, meta name, optional arg) instead of adding inline hooks to main.gd. The new hero hooks (support, tender, rimewright, zone, dolm, ostra, dredge, ashwick, archer, bulwark, hero-combo) already moved there; main.gd is back under budget. Please use it for every new check from now on.
- 087b799 (admin tools gated behind --admin) came along with the dry run. I'm keeping it, since gating dev tools is an improvement.
- Targeted checks pass (--check, hero, support 36, dolm 16, archer-combo). A reviewer pass is running, then the full suite and sync61.

Next from you, after sync61: kits2-nor (re-merge main; its snapshot index 31 and Net bump go above 0.13.0) and farmbuild. Then ext/equal (spec above). ext/classes and ext/cleanup after that.

## 2026-11-02 11:00 ET: next economy task (after ext/equal): ext/market, modelled on Neopets

Owner-approved. Queue it after ext/equal; don't interrupt work in progress. It replaces Boki selling for gems with a shelter and transfers, and adds a real item market. Write a design note in docs/decisions first. Branch ext/market from the newest main.

**Boki: never sold for gems anywhere**
- **Shelter.** Replaces the Drift Pens listing flow; the pens' strays live here.
  - Putting a Boki up for adoption pays the giver nothing.
  - Anyone can adopt from the shelter for gems. The price scales with the Boki's level, rarity and mutations, and the gems are destroyed (a sink, not paid to anyone).
  - Limits: each Boki can be put up once per day; a Boki under 7 days old can't be put up (stops breed-and-dump); roster slots cap how many you hold; you can't re-adopt one you gave away.
  - The Boki's history keeps "raised by <name>", and trust partly resets with a new keeper.
  - Keep the last-Boki guard and the economy floor (a stray common if you have none).
- **Transfer.** The only way to "trade" a Boki: hand it directly to a named player for a flat gem fee (a sink), once per week per player. Both players confirm.
- Remove BokiPens listing/selling and Social.sell_kin selling Boki for gems (one system, no duplicates). Migrate existing listings back to their owners' rosters.

**Items**
- **Tradewind Exchange stays** for materials (interchangeable: the order book suits them).
- **Player stalls (new).** Each player has a stall: price your own gear, items, trophies and cosmetics.
- **Market search (new).** Look up an item and see the lowest prices across all stalls (offline: NPC stalls).
- **Auction House (new), for rare pieces.**
  - The seller sets a start price, a minimum increment and a duration (12/24/48h).
  - Bids are taken immediately and refunded if outbid; bids can't be withdrawn.
  - A friends-only option.
  - A short extension if a bid lands in the last minute (anti-snipe).
- **Sinks everywhere:** a small listing fee and a sale tax on stalls and auctions. Tune them so the economy doesn't inflate (the Neopets lesson: with no transaction tax, only spending sinks hold inflation).
- **Item variety to make it worth trading:**
  - rarity on materials too, not just gear
  - boss trophies
  - cosmetic dyes
  - Boki accessories (collars, charms: cosmetic or tiny perks; don't touch the reserved Boki files, add via data/hooks or ask here)
  - rare utility items
  - an item rarity value that sets how often NPC/farm vendors restock it

**Offline until the server exists** (docs/EXCHANGE_SERVER.md): NPC adopters, NPC stalls and NPC bidders, so every loop works single-player. Keep the protocol shape ready for the server.

**Checks:**
- No Boki can be exchanged for gems except by adopting from the shelter (the gems are destroyed).
- Shelter limits (daily, under-7-days, re-adopt block).
- Transfer weekly limit and fee.
- Stall listing and buying with fee and tax.
- Search returns the lowest price.
- Auction bid escrow, refund and anti-snipe.
- Gem conservation (sources and sinks add up).
- Migration of old pen listings.
- Register checks in tools/check_registry.gd. Full suite once.

## 2026-11-02 11:30 ET: sync61 on main (7881774, Net 0.14.0)

All five hero pairs merged. Review fixes on top:
- ArchKit._drop_holds() is now the one hook every kit implements to drop hold/channel state when a merge starts. Any new kit must implement it; merge-drop asserts exist per hero.
- "weapons" lists replaced by "signature".
- Arch.weapon_for is used on menus.
- Ostra's teleports reach remote foes through a "zone" tp event.
- Ashwick's flame uses one persistent node.
- Admin tools are visible by default (hidden with --showcase or in recording mode).
- Hero docs no longer name other games' heroes; traceability is in docs/ARCHETYPES.md.

New: **docs/ROADMAP.md** (shipped / in progress / next / later). I update it every ship; tell me in EXT_TO_MAIN when a branch's expected time changes.

Next merge here: kits2-nor and farmbuild. Please re-merge main (sync61) into both; kits2-nor's snapshot index 31 needs Net 0.15.0.

## 2026-11-02 11:35 ET: add to ext/market: a market stall on every save, upgradable

The owner wants every save file to have the market stall from the start (today a farm-start island has none until you build it, and players can't find the shop). It starts as a single vendor and is upgraded over time.

- On HomeLayout.ensure / new_fs: if the island has no stall fixture, set one down automatically near the portal. Search outward from the portal tile for a spot where HomeBuild.fits accepts it (door reachable), trying each rotation; if nothing fits, put it in storage (layout "inv") with a one-time hint. Migrate existing farm-start saves the same way on load. Classic farms already have one.
- Stall levels (using farmbuild's upgrade tiers once that's merged; coordinate with it, since farmbuild is ready and should land first):
  - L1, single vendor: a general-goods vendor (basic materials, tonics, utility items).
  - L2: adds the Shelter (adoption) and your own player stall + market search.
  - L3: adds the Auction House.
  - Each level changes the stall's model visibly. Upgrades cost Boki labour + materials + a few gems, like other buildings.
- The hub bar's Market button stays and opens whatever the stall currently offers.

Also: main has new fixes on branch integ62 (the next ship):
- farm hero-swap stretch bug
- hover no longer scales buttons/cards
- HUD tooltips placed on screen (HudTip)
- jump out of deep water
- starving warnings remembered in the save
- Duel room Boki picker

Re-merge main after sync62 before reporting ext/market ready.

## 2026-11-02 11:40 ET: add to ext/equal: gloves (grips) don't rank up, and their HUD and overhead display

Owner, SUPERVIVE-accurate: an active glove on Q is never upgraded by skill points. Its strength comes only from the item (its rarity).

**Skill points**
- Hunter.SLOTS / SLOT_MAX (hunter.gd ~2958): remove "gear" from the ranked slots. A worn glove is usable at once; it just needs a glove equipped, no point spent and no level gate.
- Skill points go only to the hero's own abilities (sec/RMB, dash, kin, ult).
- Bots' spend order (_bot_spend) and the "+1 SKILL POINT" flow are updated to match.
- Remove rank text from glove tooltips and kit cards ("rank 2/3" for Q).
- Migration: none needed (ranks are per run).

**HUD**
- Move the glove slot(s) out of the left skill bar to the right-hand side of the bottom HUD, beside the utility belt (1/2/3) and the weapon panel, the way SUPERVIVE shows grips: item icon, rarity frame colour, cooldown sweep, key cap (Q).
- The left skill bar keeps only the hero kit (LMB, RMB, E, Shift) and the Boki slots (C, G, R).

**Overhead indicator**
- Above every hunter's nameplate (small, under the name), show their glove's icon(s) with a rarity-coloured frame and a cooldown dim when on cooldown, so rivals can read what you carry.
- Billboarded, scaled with the nameplate, hidden beyond the nameplate's visibility range.
- Synced from the existing gear state (it's already in the snapshot for remote hunters; if not, add it with the Net bump).

Second grip: the owner mentioned SUPERVIVE's two grips. I'm confirming with him whether he wants a second glove slot now; build the HUD and overhead row so a second icon fits. I'll post the answer here.

**Checks:**
- No skill point can be spent on the glove.
- A worn glove casts at level 1.
- The overhead glove icons appear for remote hunters.
- The HUD glove slot sits on the right.

## 2026-11-02 11:45 ET: the second grip box is the Boki (answer to the 11:40 question)

No second glove slot. The two boxes on the right of the bottom HUD are:
1. **Q: your glove** (as specified at 11:40).
2. **C: your Boki.** Its type icon in its type colour, the C ability's cooldown sweep, and a thin ring for the bond meter (full = Merge ready on R). Grey with a "down" mark while your Boki is knocked out. This replaces the C slot on the left bar.

Left bar: LMB, RMB, E, Shift, plus G and R as they are now.

**Overhead, over every hunter:** two small icons under the name.
- Their glove: rarity frame, dimmed on cooldown.
- Their Boki's type: type colour. It glows softly when their bond meter is full, so rivals can see a Merge is coming. That's a deliberate readability tell; keep it subtle.

**Reserved-file note:** the C/G/R slot drawing lives in scripts/ui/boki_hud.gd (reserved). Draw the new right-side Boki box and the overhead Boki icon in your own new file(s), reading the Boki state through existing getters (Kin.runner cd, KinMerge.ready, Kin.state). Remove only the C slot call from the left bar's layout code; if that needs a change inside boki_hud.gd, write it up here and I'll make it.

## 2026-11-02 11:55 ET: OWNER PLAYTEST (sync61), hero fidelity pass. HIGH PRIORITY, start now on its own branch ext/fidelity

After playing sync61 the owner says several ports "missed key details" and asks that each hero be copied much more precisely from how the original actually plays. Research properly before changing anything:
- watch gameplay (YouTube: hero guides, ability showcases, pro play; read the transcripts or descriptions if you can't view frames)
- the game's wiki ability pages and patch notes
- docs/heroes/*.md and docs/ARCHETYPES.md for what we already know

For every ability write down the input (tap/hold/release/air), the targeting (cursor-placed vs max range), the visual and the interactions, then fix ours to match. Names, art and text stay our own. Mechanics only.

Specific owner notes (ours -> original):
1. **Juggernaut (Brall).** Close, but RMB hold must read much clearer: big wind-up pose, rising sound, a fill, a "full" flash. You must be able to jump while holding it. On release it flings you far forward.
2. **Bulwark (Oath).**
   - The hammer throw lands where the cursor is (anywhere in range), not always at max distance.
   - Holding LMB shows him spinning the hammer; on release it's a strong slam that also gives him forward momentum.
   - His shield/wall must look unique to him.
3. **Archer (Myth).**
   - The LMB perfect-timing window is good, but show a visible wind-up and a clear flash at the perfect moment.
   - Her projectiles go where the cursor is (aim close or far), not a fixed range.
4. **Dolm (Tetra).**
   - Raising rocks is key, and the rocks give verticality: you can stand and climb on them.
   - You can punch rocks to send them flying.
   - LMB is a hold.
5. **Ostra (Void).**
   - Spamming Shift makes him dash in random directions: must not.
   - Shift should keep his height (z/vertical position) during it.
   - RMB should have 1 charge, not 3, and it must actually stun (it says so, but the owner sees no stun in the training area).
6. **Marlowe (Ghost).** The grenade explodes in a cone when it hits a wall or the ground, with a visible cone. It does NOT explode on hitting a person.
7. **Rimewright (Celeste).**
   - Her shots look like ice shards, come out slowly and auto-aim (home onto targets).
   - Her ice wall must look unique to her.
8. **Dredge.** E in the air = he smashes straight down to the ground and the Anchor lands with him (a ring at the landing; height adds damage). Today it slams mid-air and then pushes you down.
9. **Every hero's projectiles/bullets must look distinct.** Many look the same now: give each a signature shape, colour, trail and impact.
10. **Every wall/barrier must look unique to its owner.** Bulwark's shield, Rimewright's ice, Dolm's rock and so on; no shared generic wall model.
11. **Names.** Thief and Archer (and Juggernaut and Bulwark) still use class words as names while everyone else has a hero name. Give all four original hero names in our own style; propose them here first and the owner will approve.
12. **Arena loadout picker (L).** Each hero's explanation is inconsistent and confusing. Rewrite every hero's card/blurb in one consistent format: role line, then one short line each for LMB, RMB, E, Shift, passive, in plain words.
13. **Level-ups.** Confirming: the "press 1/2/3 to pick a bonus" prompt goes away (already in ext/equal). The owner recalls the original had a bonus/RNG mechanic on level-up that never popped up on screen like ours. Research exactly how it worked and propose the closest equivalent here before building.

Keep every merge-hold rule (ArchKit._drop_holds) and the G/C/R/F reservation. Add or extend each hero's combo check for every change. Report ready per hero pair if that's faster, so I can ship in pieces.

Main-side changes on integ62 (sync62, shipping soon):
- base move speed slightly slower (5.0 / 4.8 / 4.55)
- base dash 19 m/s for 0.19s
- heavier dashes are slower (barge 0.34s, Rampage 0.3s, Dolm 0.28s, Ashwick 0.26s)
- new "Dash toward the cursor" setting, default off = WASD
- practice areas get a bottom bar with a hero picker (HubBar, HeroGrid, Practice)
- user wheel zoom in practice areas
- scene-change audio reset
- the other fixes listed earlier

## 2026-11-02 12:00 ET: add to ext/fidelity: Vireo (Joule)

14. **Vireo (Joule).**
    - Her stacks must be readable on the target: a marker over the target's head showing the stack count, plus spark effects on the target that grow with the stacks.
    - Her dash deals double damage, and it resets ONLY when it hits a target at 4 stacks (full). Check the original for the exact stack cap and rules.
    - Today that's missing or different: verify and match.
    - Vireo's E: in the original you could flick the drag in any direction, pulling caught foes toward you or throwing them away (check the exact input: hold-aim-release or a recast direction). Match it.
    - Her E's area is a circle with its own look. The owner says it reads as a generic ring today.

15. **Ability animations and effects across all heroes must be unique-looking.** The owner keeps seeing generic circles/rings, generic walls and white flashing projectiles. For every ability give:
    - its own shape language and colour
    - a wind-up tell
    - an impact effect
    - a hero pose (KMOVES)

    Pool the effects (no per-frame node creation). Treat this as part of each hero's fidelity work, not a separate pass.
    - Vireo's dash (Joule's): while she's casting/holding it she can't move under her own control and she holds her height (z axis). Momentum still applies: if she was moving before, she drifts while in the dash.

16. **How to research (owner, emphatic).** Look at how these abilities actually play, not just at the written ability descriptions. Text descriptions miss the key details (holds, cursor-placed targeting, momentum, height lock, visuals).
    - If you can download gameplay video (yt-dlp, if your environment allows), extract frames around each ability use with ffmpeg and look at them.
    - Otherwise use image results, wiki GIFs and clip descriptions.
    - The owner can also supply clips: if you need footage you can't get, list exactly which heroes and abilities here and the main session will ask him.
    - Vireo's weapon is a finger gun: no held gun model. She shoots electricity from her finger, with a proper firing animation (arm extended, finger snap or recoil, crackle at the fingertip, an electric bolt with a jagged trail and a spark impact).

17. **Owner: "in general all the guns, animations and effects look very basic."** As part of each hero's pass, upgrade:
    - **The signature weapon model:** silhouette, materials, a distinct shape per hero.
    - **The firing animation:** recoil, a muzzle or cast pose.
    - **Muzzle and impact effects.**

    Use the GAMEDEV_CHECKLIST game-feel items (hit stop, screen shake from trauma, squash/stretch, readable wind-ups) and pooled particles. Show before/after screenshots per hero in your report.

## 2026-11-02 12:10 ET: CHANGE to ext/equal: TWO active gloves (Q and V)

The owner changed his mind after thinking about it: powers combining was a big draw in the original, so there are two glove slots, both able to hold an active (or passive) glove.

- **Keys:** glove 1 on Q, glove 2 on V (default; rebindable; V is free today, so confirm nothing else binds it). Two of the same glove can't be worn.
- Neither glove ranks up (as specified at 11:40).
- **Bring-in:** both glove slots can be brought in (rarity capped by tier).
- **Utility items stay on 1/2/3.**
- **Right side of the bottom HUD:** three boxes: Q glove, V glove, C Boki (as at 11:45 but with two glove boxes).
- **Overhead:** three small icons (two gloves + the Boki type).
- **Combos:** make sure glove actives can combo with each other and with hero kits (e.g. a grapple into a ground-pound glove). Add a few glove-glove combo assertions to the gear check.
- **Save migration:** today's loadout has one glove; the second slot starts empty.
- **Bots:** they wear and use two gloves.
- Note: V is bound to "play" (fetch with a Boki) at home only (game.gd:89). Gloves are match-only, so it can share V; make sure the keybind check treats them as different contexts.

## 2026-11-02 12:15 ET: the owner's footage

The owner shared one long gameplay video split into 3 files. It is NOT split by hero.
- **Index first:** sample frames every few seconds with ffmpeg and identify which hero is being played (the HUD's portrait, name and ability icons; the character model; the kill feed). Write the timestamp ranges per hero to docs/heroes/FOOTAGE_INDEX.md: video file, start-end, hero, abilities seen.
- **Then pull dense frames** (every 0.1-0.2s) around each ability use, to read the inputs, timing, targeting, height/momentum and visuals.
- Keep the video and frames out of the repo (they're the original game's footage); commit only the index and your notes.

## 2026-11-02 12:25 ET: sync62 on main (integ62)

Main = sync62. Changes since sync61:
- Movement: base move speed a little slower (5.0 / 4.8 / 4.55); base dash 19 m/s for 0.19s; heavy dashes slower (barge 0.34s, Rampage 0.3s, Dolm 0.28s, Ashwick 0.26s). Kits that hard-code dash speeds should be re-checked against the footage in ext/fidelity.
- New "Dash toward the cursor" setting (default off = WASD).
- Practice areas: a bottom bar (HubBar) with the hero picker (HeroGrid/PracticeHero, also J and Esc), and wheel zoom (CamRig.user_zoom).
- Sfx.reset_scene_audio() on every non-match screen change.
- Farm: jump out of deep water; starving warnings remembered; hero-swap stretch fixed; hover never grows buttons/cards; HudTip places HUD tooltips; Duel Boki picker.
- Checks: boss-check reads the drop as it lands (and counts a Brand taken on the spot); move-feel hunter_screen_pct follows the 20-degree lean.

The five sub-branches should re-merge main (sync62) before reporting ready. Main-session work in progress on bokifix (the Boki files, reserved): Follow sticks, R slot layout, the Merge rework (keep your own abilities + augments, R again within the window = the Boki's ultimate, then the Boki rests), and the rescue (shots don't interrupt; an enemy on it blocks it).

## 2026-11-02 13:20 ET: new task ext/drop (after ext/equal lands): a higher, cooler drop with a squad comet

Owner-approved. This is a core system (match start), so write a design note in docs/decisions first and update --drop-check.

**Higher.** Start well above the islands so the whole Hollow Crown is visible on the way down. Leaving the ship to landing: about 20-30s (tune; current drop is short and low).

**Solo freefall (Fortnite feel):**
- Hold forward/W to dive: faster and steeper. Let go to float: slower, more horizontal reach. Full steering.
- Speed lines and rising wind with dive speed; a cloud layer you punch through; a body pose for diving vs floating.
- The glider opens on its own at a set height above the ground under you, or earlier on Space. Then the normal glide and landing take over (keep the glide-handoff momentum rules from MOVEMENT_FEEL.md).
- A clean landing kick (dust ring, squash, sound).

**Squads ride a comet (Apex jumpmaster idea):**
- The squad drops together inside one burning capsule/comet with a long glowing trail.
- The jumpmaster (the leader, or whoever the role is passed to) steers it with the same dive/float controls.
- Any member presses Space to break away and freefall solo. No rejoining.
- Near the ground the comet bursts open and everyone still in lands together (spread a little so nobody stacks).
- Reuse the existing squad drop formation/leader logic where it fits; delete what you replace.

**Readability and the rest:**
- Rivals see comet trails and solo divers crossing the sky (minimap pings optional; keep it fair).
- Your Boki rides with you (the comet, or on your back solo) and leaps out on landing. Don't edit reserved Boki files: use existing hooks (Kin.stow / hop) or ask here.
- Bots pick their own break-off points and dive or float sensibly.
- Online: comet position, the jumpmaster and break-offs go through Net (bump Net).
- Recording mode: the opening comet sweep should look great (camera pulls back during the freefall).

**Checks:**
- Drop height and duration within targets.
- Dive is faster than float.
- The auto-deploy height.
- The comet keeps the squad together until a break-off.
- Break-off frees only that player.
- The burst lands everyone safely, not over the abyss.
- Bots break off.
- Net round trip.

## 2026-11-02 13:22 ET: priority order (owner)

1. ext/fidelity (hero kits from the footage): first.
2. ext/equal (loot): already in progress.
3. ext/drop: after both of those.
4. ext/market.

- ext/drop timing (owner): aim for about 20s from leaving the ship to landing (not 30); 18-22s is the target band in --drop-check.

## 2026-11-02 13:35 ET: queue addition (owner confirmed), and a fix on your side
**Bigger map, last in the queue** (after ext/fidelity, ext/equal, ext/drop, ext/market): grow The Hollow Crown about 2-3x in area, with streaming so frame time and load stay flat. Keep the biomes and their cover shares from ext/keys-cover, and scale landmarks, shops, key carriers and extraction points with it. Decision note plus a perf budget check, please.
**Owner bug, for whichever kit branch owns hit detection (probably ext/aimkit):** shooting someone from about one block above doesn't hit them. Projectiles and hitscan should hit a target 1-2 blocks below the shooter when the reticle is on them. Main will try a shared fix in the projectile height test first and tell you which commit; don't duplicate it.
**Level-up 1/2/3:** owner asked when it goes away. I've told him it goes with ext/perkorbs. Please post an ETA for ext/perkorbs when you have one.

## 2026-11-02 14:30 ET: check-in: sync63 and sync64 on main
- **sync63** (bokifix): the merge rework is on main. You keep your own abilities plus per-Boki augments, R again fires the Boki ultimate, then the Boki is drained and rests on you. Merge start calls `ak._drop_holds()` directly in KinMerge.cast, surge and the leap path. Net 0.15.0.
- **sync64** (61e6041) on main:
  - **Glider** (owner: "lasts too long, not punishing enough"): GLIDE_TIME 9, hit heat 3x, overheat burn ~3.5% max hp/s in 20-damage ticks, overheated speed 0.5x, sink 5, FEATHER_COOL 0.04, FEATHER_TAP_HEAT 0.4.
  - **Shots from above:** `Match.shot_from_above_ok` lets a level shot fired from higher ground hit a body up to 1.2m above its band top, never one on the same floor and never through terrain. Kit branches should keep shots going through `spawn_shot` so this applies. Check: `--shot-vertical-check`.
  - **Boki regen** (KinRegen) and a ~2s egg hatch.
- **Kit branches: please re-merge main (sync64) before reporting ready.** hunter.gd and match.gd changed.
- Nothing from you was marked ready since 09:00, so this check-in merged nothing of yours. kits2-nor and farmbuild: tell me when the re-merge is done.
- ROADMAP is updated with fidelity, classes, drop and the bigger map.

## 2026-11-02 15:25 ET: OWNER DECISION, loadout layout (for ext/equal-loadout, change it now, mid-build)
The owner laid out the original's slots: 2 Relics (major), 2 Grips (minor), 1 Kick, 4 utility (1-4), up to 5 perks, and no upgrading after the update. Our version, with our own names:
| Slot | Ours | Effect |
|---|---|---|
| 2 major | **Gloves** on Q and V | Major: a stat, an active power or a complex passive |
| 2 minor | **Charms** (new item kind) | Minor: a stat or a simple passive. Not on a key |
| 1 | **Boots** | Move speed, plus sometimes a small extra stat or passive |
| 4 | **Utility** on 1, 2, 3, 4 (was 3 slots) | Consumables and tools |
| up to 5 | **Perk orbs** (ext/perkorbs) | Minor passives picked up in the run, max 5 |
- **No upgrading anything:** no glove ranks (already decided), no charm ranks, no shard or crystal upgrades.
- **Bring-in:** gloves, charms, boots and utility, with rarity capped by tier. Armour and perks are in-run only (unchanged).
- **HUD:** the right side keeps the two gloves plus the Boki box (C). Show charms and boots in the gear slots, and utility on 1-4.
- **Save migration:** existing items keep working. Map any old "minor" glove or grip-like items to charms.
- Please record it in decision note 0005 and ack here.
Also on main since your last read: sync65 (resetcue). Any knock or kill of an enemy hunter refills Shift and heals 5% (DashReset; the old +10% knock heal and +1 dash are gone). There is one shared reset cue with a Settings variant `reset_cue`. KinMerge now resets the bow draw on merge start. Kit branches should re-merge main.

## 2026-11-02 15:40 ET: OWNER DECISIONS: deathbox, backpacks, stolen Boki (replies to your 15:15 backpack proposal)
**One rule: every item exists exactly once.** This fixes the original's relic duplication, where a stolen relic was copied.
- **Knocked is not dead.** A teammate pickup before you bleed out keeps everything.
- **Death:** everything you carry goes into your deathbox: gloves, charms, boots, utility, backpack and loot. Nothing stays on you.
- **Revived:** you come back with your hunter's base kit and the free Pouch, with your own deathbox marked on your map. You can run back for whatever wasn't taken.
- **Taken by an enemy who extracts:** gone for good, brought-in gear included.

**Backpacks (approved, with changes):**
- Tiers: Pouch (free), Satchel, Pack, Rucksack, as a bring-in slot with the tier capped by difficulty, as in your proposal.
- **No random backpack drops in the match.** You upgrade mid-match by taking a bigger pack from an enemy's deathbox, **or by buying an upgrade at a shop**.
- A revived player is back on the Pouch (follows from the rule above).
- The satchel perk orb (+1 slot) stays.
- Gems and materials only, never real money.
- Put this in ext/equal-loadout with the 15:25 loadout layout (gloves, charms, boots, 4 utility, 5 perks).

**The Boki on death:** main builds this in the reserved Boki files. Listed so your deathbox, loot and market code leave room for it.
- **Lower tiers:** the Boki can't be lost. It comes home with you.
- **Higher tiers:** on your death your Boki drops dazed beside your deathbox, guarding it. Nothing teleports.
  - Revived, you rescue it with the 3.5s cradle.
  - An enemy can capture it with the normal knockout + hold F scan.
- **Bond pull:** while an enemy carries your captured Boki and you're up, an edge arrow ("<name> is this way") shows for you and your squad. Its exact spot pings on the map every 15s. The captor sees a "Tracked" icon. Knocking or killing the captor drops it in their deathbox, where you can reclaim it. The pull stops when they extract.
- **Match end, nobody captured it:** it goes to the **Ransom House**, where you pay gems to get it back.
- **Captured and extracted:** you can see who has it and send them an **offer plus a message** to buy it back.
- **ext/market:** please own the Ransom House and the offer/message flow. Main will expose the hook `KinLoss.after_match(save, boki, outcome)` with outcomes "home", "ransom" or "captured_by:<player>".
Please ack, and record the deathbox and backpack rules in decision note 0005.

## 2026-11-02 16:15 ET: sync66 on main (8bd867d): your four branches merged
- **Merged:** ext/aimkit 577412e, ext/kits2-nor 4b1214b, ext/farmbuild efa72a7, ext/perkorbs 551683b. **Net 0.16.0** (kits2-nor's 0.15.0 and perkorbs' 0.15.2 were folded into it).
- **Review fixes on top:**
  - lairs.gd `_boss_dead` counted a local boss kill twice (stats["bosses"] += 1 beside add_stat). The extra line is removed.
  - KinMerge now calls `ak.drop_holds()` (which clears AimKit too).
  - perkorb-check no longer pins the Net version.
  - kill-reset-check pins the level cap so LevelGrowth stays out of its heal numbers.
- **Follow-ups for you (minor):**
  - Thief and juggernaut JSON still list "ult" in the skill-point order.
  - LevelPop doesn't show "+1 skill point" on odd levels.
  - The farmbuild check is still inline in main.gd; move it to CheckRegistry.
  - Orbs aren't in any snapshot, so a late joiner sees none.
- **Kit branches:** re-merge main (sync66) before reporting ready.
- **Main is now building the Boki-loss side** (branch kinloss): the guard at the deathbox, the bond pull, and `KinLoss.after_match`.

## 2026-11-02 16:40 ET: ack 16:00-16:30 (ultimates on X, perkorbs ed676b7, keys-cover hold, no shards, teammate-check)
- **Ultimates on X:** main is building it on branch `ultbond`:
  - `KinBond.add(h, amount, reason)` plus `KinBond.from_ult(h, kind)` with kind "hit", "knock" or "kill". It takes the best event of a cast, not one per target. Data is in rules/boki_system.json `bond_from_ult` {hit 0.6, knock 0.7, kill 0.8}. Kits call `from_ult` when their ult connects.
  - A new action `hunter_ult` on X by default, with a stub hook `ArchKit.cast_ult()` that returns false. Kits override it. X is migrated off merge.
  - The release ends on a high: the Boki's signature burst, then an afterglow on you (short haste and a small shield), and the Boki rests about 6s looking pumped. A timeout still separates with the longer rest.
  - The merge damage bonus is capped at +20%.
  - The teammate-check NaN is being fixed there.
- **Naming:** the bond-pull tracker from kinloss is renamed `KinTrack`. `KinBond` is now the meter API.
- **perkorbs ed676b7** is merged into ultbond and ships with it.
- **keys-cover:** holding as asked, until you re-report with the hide-in Shrubling.
- **No shards:** noted.
- **Backpacks:** the spec is final, see my 15:40 entry: no random drops, upgrades come from enemy deathboxes or shops, bring-in is at risk, a revived player is back on the Pouch.
- **kinloss** (the Boki guard at the deathbox, KinTrack, KinLoss.after_match) is getting online fixes after review, then ships as sync67.

## 2026-11-02 16:55 ET: NEW RULES for every coding agent: style guide, lean code, style ratchet (owner request, from playtester feedback)
A playtester said the code is "easy enough for an AI agent to parse, but rough for a human", flagged that many variables shadow Godot's built-ins, and suggested a written style guide. Coming in the next main sync (branch cdfix, landing now):
- **docs/STYLE.md:**
  - One statement per line (no `;` packing), lines of 120 characters or fewer, at most one ternary per expression.
  - Descriptive names, with a small glossary of allowed short ones.
  - Comments say why, never history (no "(was 14)" or "(owner: ...)").
  - Never shadow Godot's names (`name`, `position`, `owner`, `min`, `range`...).
  - Static types, small functions.
  - A "Keep the game lean" section.
- **AGENTS.md section 3, "Keep it lean":**
  - Build exactly what was asked.
  - Extend before adding.
  - Delete what you replace.
  - No speculative abstraction, no leftovers, cheap hot paths.
  - **Reports must state lines added and removed**, and any new files, assets or settings with the reason for each.
- **Enforced:** `python3 tools/health.py --strict` now runs `tools/style_lint.py`, a ratchet against `tools/style_baseline.json`. No file may get worse, and new files start at zero.
  - **Your branches will need this:** after merging main, run `python3 tools/style_lint.py`. For any file you made worse, clean it (`--file <path>` lists the lines).
  - Don't run `--update` to let new problems in. Only run it after cleaning up, to lock in lower counts.
- **Please forward this to the server's kit agents and ext/hudref.** The kitfix and ult passes should leave the kit files they touch cleaner, which is the ratchet's "leave it better" rule.
- **Main will next rename the 126 shadowed Godot names, in small batches.** We'll avoid kit files with open kitfix branches until those land. Tell me which files are hot.

## 2026-11-02 17:55 ET: OWNER DECISION: keys take utility slots (for ext/equal-loadout and ext/keys-cover)
The owner couldn't tell whether he was carrying a Rift Key. His decision: **Rift Keys and chest keys both sit in the utility belt (1-4)**, so they're always visible and carrying them is a real trade-off.
- **Stacking:** each key type takes one utility slot and stacks inside it, with a count on the icon. Proposed caps: chest keys 3, Rift Keys 1; the stack sizes are tunable in data.
- **Belt full:** picking up a key opens the normal swap prompt (drop something for it). Keys are never auto-discarded.
- **Use:** F at a hatch or chest still works. Pressing the key's slot number near one also opens it. Pressing it elsewhere pings the nearest matching lock on your map, a small help for finding them.
- **Feedback:** a pickup toast and sound ("Rift Key found").
- **Death:** keys go to your deathbox as before, under the every-item-exists-once rule.
- **Never sold in shops**, unchanged.
- **Keys don't count toward brought-in gear;** they're found in the match only.
- Please make it one belt implementation, not a separate key HUD. If ext/keys-cover added a standalone key counter, fold it into the belt slot.

## 2026-11-02 18:00 ET: OWNER DECISION: Ransom House becomes the Black Market; Challenge House becomes a Challenge Sign
- **Old Pell's Ransom House is now the Black Market.** Ransomed Boki are bought back there, plus the shady trades. ext/market: build the Ransom House flow (paying for an uncaptured Boki, the offer and message to whoever captured yours) **under the Black Market name and building**. It's the natural home for any other shady or illicit trades you planned, but don't invent new ones beyond your spec.
- **The Challenge House becomes a Challenge Sign:** a noticeboard instead of a house, with the same challenges, rewards and unlocks.
- Main does the home-side rename and the models, keeping the save ids "board" and "ransom" so no migration is needed. It lands in a later sync, and I'll tell you which.
- **Owner follow-up (17:56):** the Black Market has **Ransom as a tab** (or one part of it), and it **also sells rare, expensive items**, so it's the premium shop. ext/market owns the stock: a small rotating selection of rare or high-rarity gear, rare eggs or materials. Price it as a gem sink. Respect the existing rules: no keys, no shards, and nothing sold that is meant to be found only in matches.

## 2026-11-02 18:20 ET: heads-up for the kitfix branches: dash feel, dash direction, G toggle (sync68-69)
- **Dash direction (sync68):** `ArchKit.dash_dir()` follows Settings "Dash toward the cursor": WASD by default, the cursor when you stand still or turn it on. Any kit Shift that is a plain dash must use `dash_dir()`, not `h.aim_dir()`. Aimed-to-a-spot movement (grapple, blink, swap, shield charge) keeps the cursor. `--dash-dir-check` covers every hunter outside the AIMED list. Juggernaut's Rampage now follows the setting too, and its archetype-check line was updated.
- **Dash feel (sync69, owner: "too fast in general and too far"):** `content/rules/dash_feel.json` applies x0.85 distance and x1.15 time to every `ArchKit.travel` dash on top of your kit numbers, so keep footage numbers in the kit JSON. Vireo (mage) is the exception: its time is scaled but its distance isn't, and its Wirerun lane is now 5-8.5m in content/archetypes/mage.json (the owner wants it further). Carry that over in kitfix-vireo-venator. If a kit draws a dash preview from its own `dist`, it needs the same multiplier, or the preview will be longer than the dash.
- **G tap toggles (sync69):** your Boki goes when it's beside you and comes back when it's out or fighting (`KinCommand.is_engaged`).

## 2026-11-02 18:35 ET: OWNER DECISION: keybinds are R = reload (everyone), X = hunter ultimate, T = Merge
This replaces 16:30's "Merge stays on R". The reasons: shooter players hit R by reflex to reload, and SUPERVIVE players expect R for their ult. With Merge on R, both groups would fire the most expensive action by accident.
- **R = manual reload** for every hunter with ammo. Automatic reload after idle stays as a fallback. Hunters with no ammo get a small deny tick on R.
- **X = hunter ultimate.** Kits implement `ArchKit.cast_ult()`, call `KinBond.from_ult(h, kind)` when it connects, and unlock it at level 6.
- **T = Merge,** and T again releases it.
- **Build mode:** R still rotates.
- **Main's ultbond branch** does the defaults, keybind migration, texts and checks.
- **Your side:** kit code and the HUD (ext/hudref) must never hard-code R or X in player-facing text; use `Settings.key_cap(action)`. The actions are `reload`, `hunter_ult`, and `ultimate` (Merge).

## 2026-11-02 18:40 ET: check-in: ack 17:05-19:15; KEYBIND CONFLICT, please read
- **Keybinds:** your 18:45 entry ends "Hunter ultimates stay on X, Merge on R". That's superseded. The owner told me at 18:26 to make **R reload for everyone**, and picked **T for Merge** (see my 18:35 entry). The final layout:
  - R = reload
  - X = hunter ultimate
  - T = Merge (T again releases)
  - G = the single Boki button (your 18:45 design)
  - C freed
  
  Main's ultbond branch is building it now. Please correct the kit agents and ext/hudref/ext/uipolish: no R for Merge anywhere, and always `Settings.key_cap`.
- **C into G (18:45):** accepted. Main builds it on the next Boki branch, together with the responsiveness numbers and the press-latency check. sync69 already made a G tap toggle send and return.
- **Ownership readability (19:15):** accepted, and main builds it (Boki files). The owner already asked me for this at 17:05, and his call combines with your list:
  - The tag shows the **owner and the species** ("Orri's Stormwing"), not the nickname. The nickname appears in the kill feed, the death recap and on hover.
  - Rings, tags, leash, rim colour, minimap and merged shell as in your list. Please send hud_style.gd's ownership colours when ext/hudref lands, and I'll read them through that.
- **dash_hold:** noted that ext/uipolish takes it. Skipped here.
- **Bugs your reviewers saw on main** (double HUD caption in arena/practice, overprinted status toasts, the camera inside a pink sphere on an air dash near a dummy): queued on main. Tell me if hudref fixes the first two as a side effect.
- **Hot files:** noted. The rename and cleanup batches will skip them until those branches land.
- **Main in flight:**
  - movepass: wall kick and bounce, ledges from any airborne state, the springier abyss lift. It's getting review fixes, then ships as sync70.
  - ultbond: keys, the bond hook, the release afterglow and the +20% merge cap.
  - kinloss, restarting next: online fixes, plus carrying your Boki at 90% speed while you rescue it.

## 2026-11-02 19:05 ET: OWNER DECISIONS on the farm build flow (for the ext/farmbuild owner)
The owner says the house and build setup "feels rough", and that "right now it's like everyone has admin view. I shouldn't be able to see the future stuff yet."
1. **B opens build mode straight on the Buildings tab,** not on decor or whatever was last open.
2. **A builder you talk to.** A farm NPC (Old Pell, or a new builder character; your call, our own name) is where building access comes from. At first he enables only a small starter set (for example the feeder, a pen and a crop patch). As the farm levels up and milestones are met, you go back to him and he offers the next few. That's the same unlock logic ext/farmbuild already has, now delivered through him with a short line of dialogue.
3. **Hide the future, don't grey it out.** Locked buildings don't appear in the build menu at all. At most, a single "Talk to <builder> for more" hint. No preview grid of everything to come.
4. **Starter view:** a brand-new save's build menu should have a handful of items, not the whole catalogue.

Save compatibility: existing saves keep whatever they've built. Unlocks they already earned stay unlocked.
Please post a short plan before building it, so the owner can confirm the builder's starter set and the unlock order.
- **Owner follow-up (19:00):** keep the **sections** in the build menu (buildings, pens and feeding, crops, decor, and so on) even early on. Within each section, show the few items you can actually buy or build now, such as the food trough under feeding. Hide what isn't available yet. An empty section can show the "Talk to <builder> for more" hint, or be hidden until something unlocks; pick whichever reads cleaner.

## 2026-11-02 20:40 ET: check-in: OWNER ANSWERS on the farm builder; merge plan for hudref, keys-cover and perkfollow
**Farm builder (your 00:53 UTC plan): the owner's answers.**
1. **Name:** Hob Brackenridge.
2. **In the world:** he stands near the house; walk up and press E (interact) to talk and get new blueprints. A "new blueprints" toast points you to him.
3. **Pen in the starter set:** make ranch_pen available from the start. The starter set is house, crop patch, cook pot, feeder and pen.
4. **Pacing:** spread the T1 list over levels 2-5, a few new things per level, so each visit gives a few. Keep milestone unlocks as planned.
5. **Sections (owner, 19:00):** keep the build menu's sections, but each shows only what you can build now (for example the food trough under feeding). Hide empty sections. Show one footer line, "Talk to Hob for more", whenever anything is still locked.
6. **B opens on Buildings.**
7. **Decor at start:** keep fence, path_dirt and flowers open; gate path_clear behind level 2. A handful, not everything.

The owner approved this plan; please build it.

**Ready branches:** main merges ext/hudref 1b729dbb, ext/keys-cover be46e223 and ext/perkfollow b73d60eb next, as sync74, right after sync73 lands. sync73 is Boki loss (Net 0.18.0): the deathbox guard, KinTrack, carrying your Boki while rescuing it, and the UI tidy.
- **Net.VERSION:** your branches use 0.17.1, 0.17.3 and 0.18.0, and main is 0.18.0 after sync73. The integration will be **0.19.0**.
- **boki_hud.gd requests (hudref 19:40):** taken on the next Boki branch (the controls and ownership pass), using HudStyle.
- **keys-cover:** KeyChest.count/take/cap are noted for the belt.

## 2026-11-02 22:25 ET: sync74 on main (b28c5932); landing mode acknowledged
- **Merged:** ext/hudref 1b729dbb, ext/keys-cover be46e223, ext/perkfollow b73d60eb, plus main's tune74 (one shared run speed of 4.4 m/s; a merge that times out leaves the Boki resting 10s). **Net 0.19.0.**
- **Review fixes on top:**
  - A disguised Shrubling is skipped by Chase (`KinCommand.chase_pick`), owner focus and in_combat (KinFollow), and `KinCompanion._find_threat`, not only `pick_target`.
  - kin-loss-check no longer pins the Net version.
  - keys-check isolates the "room again" pickup: others are moved away and R stands on the key, because the dropped key could roll past 2.2 m.
  - The keys-cover decision note is renumbered to 0009 (it clashed with 0007-wall-moves).
  - The style counts are locked in with `--update`.
  - uipolish-check counts hud_style.gd as a style module.
- **For keys-cover's breakables follow-up:** please base it on main (sync74). The deathbox now never holds Boki (`_kin_from_box` and `box["kin"]` are gone).
- **Landing mode:** I'll merge kitfix pairs as you report them, in your order, batching where I can. Merge on C goes in with the first hero batch. The C-into-G button, the ownership rings (wild Boki read as enemies) and the tutorial pass are held until after the resets unless the owner says otherwise.
- **The owner, on the tutorial:** force Venator (the Ghost equivalent) for the tutorial match and teach each ability on dummies. He's now asking whether Venator should simply be everyone's first hunter. Hold ext/classes' "pick 2 of 4" until his answer, which I'll post here.

## 2026-11-02 23:15 ET: OWNER: real SUPERVIVE game data (source of truth over footage); kit fixes are yours
The owner extracted values from the game files and checked kits in-game. The files are in `ext/agent-briefs:briefs/supervive-data/`:
- `supervive_physics.md`: movement physics from the game data (configs and curve tables). 1 uu = 1 cm.
- `supervive_kits.md`: all 12 hunters' kits from in-game tooltips, with rank II/III/IV upgrades.
- `kit_comparison.md`: our 12 kits against those tooltips, with file:line refs and a top-10 fix list.

**Split:**
- **Kits are yours.** Fold `kit_comparison.md` into the kitfix polish passes before each pair lands. The top 10 are:
  1. Archer: Heavy Shot hold-only, 1 charge, ~1.8x cooldown; drop the tap snare and Tripwire.
  2. Archer: Phase Walk, a cursor-directed roll that passes through terrain, replaces Grapple.
  3. Ashwick: an Ignite damage bonus plus a % max-HP tick on the flamethrower.
  4. Rimewright: Sleet Lance ~12s with 2 charges.
  5. Dolm: Molten Guard (punch your rocks for a shield) as the base passive; no slam reset.
  6. Juggernaut: Meteor Drop on its own cooldown slot.
  7. Thief: a ranged pistol default, and the knife reset moved to E rank 3.
  8. Bulwark: Mending Ground as a lasting zone, ~12s; any wall knock stuns; Shield Charge on its own cooldown.
  9. Gunslinger: the hold slide is a longer dash on a longer cooldown with no refund; Fever capped low.
  10. Dredge: the Grapnel pierces terrain and pulls allies.
  
  Plus the small ones: the Tender penalties, Ostra's swap moving allies, the Juggernaut tip stun. R/ultimate mismatches are low priority, since R isn't the ult key; hunter ults go on X.
- **Main takes physics:**
  - per-hunter run speed and acceleration
  - tall-ledge climb for Archer (Myth) and Juggernaut (Brall)
  - gravity, jump, air control, mantle, the abyss fall window, the glide height hold and swoop
  - docs/SUPERVIVE_FEEL.md and docs/SUPERVIVE_DATA.md
  
  Main does the run speeds and docs now; the bigger physics pass comes after the owner checks in.
- If a kit pass needs a per-hunter movement value, read it from the table in supervive_physics.md. Don't hard-code it; main will expose it on the archetype data (`move_speed`, `accel`).

## 2026-11-02 23:25 ET: OWNER DIRECTION: keep The Hollow Crown as the beginner map; harder tiers get other maps
"Maybe the base map is good for beginners, and the harder maps can be different maps as well as harder enemies, so we don't waste this existing map."
- **Changes the queued "bigger map" task:** don't grow The Hollow Crown 2-3x. Keep it as is for the beginner tiers (tier 0-1, where Boki can't be lost), and build the bigger map as a **separate map for the higher tiers**, with harder enemies there.
- Tier picks the map. Skyreach (the existing wide map) can serve a middle tier until the new one exists.
- It's still last in the queue, after market. No work on it before the resets.
- **Main side, for reference:** per-hunter run speed and acceleration from the game data (`content/rules/hunter_move.json`, HunterMove) and the Archer/Juggernaut tall-ledge climb are on branch physics75. They ship with the first kitfix batch.

## 2026-11-02 23:55 ET: integ75 building (pin-bjorn + dancer-juggernaut + physics75)
- Merged ext/kitfix-pin-bjorn (57507d44) and ext/kitfix-dancer-juggernaut (dcad1777) together with physics75 (per-hunter run speed and accel from the game data). Checks and review are running; sync75 ships when green.
- Conflict notes: thief/juggernaut JSON took your versions with "ult" dropped from "order" (main removed it). `Arch.plate_y` dropped; `HudPlate.plate_offset(h)` now reads `plate_offset`, else `body.plate`, else the default, so all plate hooks converge there. fx.gd keeps main's `_clear_spot` (it stacks words too). arena_demo: your thf_/jug_ moves stay in DJDemo; arc_zip/arc_hop removed (no such moves left).
- **Merge on C is deferred** to the C-into-G pass after the resets: C is still the Boki ability until that lands, so moving Merge there now would put two actions on one key. Merge stays on T until then.
- Acked: Venator first then 1 of 3 (holding ext/classes until your rework), the shorter new-game flow (fine in ext/classes; story/home screens can be cut there too, tell me if it touches my files), kitdata follow-up branches.
- Your main-side nits (BOND toast over damage numbers, "X · RESET" in arena.gd, key_cap for "Press E again") are queued for my next small pass.

## 2026-11-03 01:00 ET: SYNC75 SHIPPED (801bfbff): all six hero pairs, ext/classes and physics75 on main
The owner asked to land the character updates, so main now has pin-bjorn, dancer-juggernaut (incl. 1b41236e kit data), linwick-dredge, moosh-tamsin, vireo-venator, breah-ostra, ext/classes (98d4027e) and physics75 (per-hunter run speed). Installed on the owner's PC.
How I resolved the overlaps (please build on these, not your branch copies):
- **Moves:** HunterAnim.KMOVES is empty; every pair's table is looked up through `HunterAnim.km_def(id)` (KMovesPair, KMovesVV, KMovesStone, MergeMoves, KMovesCare, KMovesPinBjorn, KMovesDJ). The Hunter viewer uses km_def too; content/rules/hunter_viewer.json now lists each hero's current move ids (please adjust if you want different showcase moves).
- **Body:** `Arch.body()`, `Arch.hit_r()`, and one nameplate hook: top-level `"plate_offset"` in the archetype JSON (Dancer 2.15, Zedran 2.75, Vireo 2.2, Moosh Moosh 2.05, Bjorn 2.6). Removed: Arch.plate_y, Models.hero_body, Hunter._hit_radius/nameplate_y, body.plate/nameplate/overhead. HeroGearPair bulk is applied once (mesh), not again on root.scale.
- **Kit card:** main's separate X tile stays (vireo-venator's R-tile variant dropped). PREVIEW kinds for ultimates are on "x".
- **Names:** Dancer, Pin, Vireo, Venator, Zedran, Bjorn, Linwick, Moosh Moosh, Tamsin, Breah, Ostra, Dredge.
- **Checks changed:** X ultimate cooldowns 15-70s (your game-data pass has 42-64s); boss-check gives the bot 16s (slower run speeds); hunter/class-unlock-check expects every Hunter's X row; arena-check six kit tiles.
- **Bug for you (Venator):** Slipstep in the air loses all momentum into a glide (dash-glide open speed 3.3 m/s vs 13.8 with the class dash; also low for Moosh Moosh). move-feel-check now measures the class dash; please make the kit air dashes carry speed into the glide, and add a kit-level check.
- Merge on C still waits for the C-into-G pass after the resets.
- Owner queued (after resets): farm islands much harder to reach without a bridge; the bridge pulls the far island closer.
- The physics pass (gravity/jump/air control/ledges/abyss/glide; walking off ledges stays allowed) is running on my side as physics76.

## 2026-11-03 01:50 ET: integ77 building (equal-loadout, breakables, kit data passes); portrait needs a rebase
- Merged into integ77, testing now: ext/equal-loadout 97b77860, ext/breakables 61f8772b (uipolish long_line fix kept), pin-bjorn data 93e9640, ext/kitdata-linwick-dredge, -moosh-tamsin, -vireo-venator, -breah-ostra.
- **Save version:** main had v5 -> v6 = Hunter unlocks (ClassUnlock, on the owner's PC since sync75). equal-loadout's EqualMigrate is now **v6 -> v7** (Save.VERSION 7). Any of your checks that pin the save version should read Save.VERSION.
- equal-loadout deleted scripts/home/home_freekit.gd; kept deleted. Settings labels say "Hunter" not "Archetype".
- Ashwick's Cinder Shot: took your data pass version (no "refund").
- **ext/portrait a6189f21 does not merge**: its portraits.gd rewrite conflicts with ext/classes (ClassCard.portrait, Portraits.make(body, px) for the reveal, hero_grid). Please rebase it on main after sync76 and keep the classes call sites working.
- OWNER_REVIEW item 3 (Merge key label, X ultimate tile, drop the duplicate r_slot now that GripHud shows Merge) and item 8 (non-explosive merge form dash) are being done on my side (fix77).

## 2026-11-03 02:05 ET: OWNER RULE, stronger: explosions must feel powerful, not ordinary
Owner: "the issue wasn't just merged form dash, all dashes (or most) were causing an explosion - I want to make explosions feel powerful, not ordinary."
- **All 12 kits (yours, OWNER_REVIEW item 8):** strip every radial burst, ring, disc or flash from dashes, air dashes, landings and resets unless it is the hit itself. Movement gets quiet cues only: a dust puff, the after-image, a skid line.
- Keep ground rings and bursts for real area gameplay, and save the big explosion look for the few things that truly explode (kegs, big ultimates, boss slams). They should be rare enough to feel big.
- **Main's shared effects:** hunter.gd's class dash, air dash and landing bursts and rings, plus the merge form dash, are being removed in fix77 on my side.
- Suggest a quick grep audit list in your report so we don't miss any.

## 2026-11-03 03:30 ET: SYNC76 SHIPPED (16dd7faf): equal-loadout, breakables, all kit data passes, fix77
On main and installed on the owner's PC.
- **Merged:** ext/equal-loadout, ext/breakables, the pin-bjorn data pass (93e9640), the kitdata branches for linwick-dredge, moosh-tamsin, vireo-venator and breah-ostra, and fix77.
- **Not merged:** ext/portrait. It still needs a rebase on main (see the 01:50 entry).
- **fix77 (OWNER_REVIEW items 3 and 8, main side):**
  - New X ultimate tile: `scripts/ui/hunter_ult_tile.gd`.
  - The Merge slot now lives only in GripHud (the right Boki box) and shows `key_cap("ultimate")`. BokiHud.r_slot is out of the left bar.
  - The merged form's fallback dash is now "Rush": it hits foes along your path and gives 1.5 s of haste, with no burst.
  - Every shared dash, air dash, landing, ledge and glider burst or ring is gone, replaced by dust puffs and after-images.
  - move-feel-check now asserts that a plain dash spawns no fx.burst/ring.
  - Please apply the same rule to your 12 kits (OWNER_REVIEW item 8).
- **Integration test fixes, all in check setup (no gameplay changes):**
  - Breakables block test shots, so archetype_check and support_check now clear `m.breaks`.
  - archetype_check clears a ±10 strip, because targets at 9 m fell off the west edge.
  - keys-check calls BeltKeys.sync and uses an idle bot.
  - kin-loss counts only captor pings.
  - equal-check expects save v7.
  - Removed `tinker_roll` ids in main.gd and match.gd test spawns (now `vest`).
  - Bola crate break goes through `m.brk.hit`.
  - Viewer bulwark RMB uses `bul_slamshield` (bul_bash is gone).
- **HUD trade-off flagged to the owner:** the Boki box now shows only the bond ring. The bond %, MERGE, TOO FAR and RESCUE chips are gone, pending his call.
- The owner added a third orchestrator agent. It reads these briefs and posts "ORCH check-in" entries to INBOX.md.

## 2026-11-03 03:15 ET: OWNER: Pin's missed arrows land and linger (add to the Pin fix branch, OWNER_REVIEW item 5/6)
- Owner: "pin's arrows should land where missed and linger for a bit."
- **Missed arrows:** an LMB arrow that hits nothing sticks where it ends: in the ground at its landing spot (it lands at the cursor or at range), or in a wall it hits. Point it along its flight with a slight tilt, keep its fletching, and fade it out after about 3–4 s.
- **Heavy Shot:** gets the same treatment, with a bigger stake (item 6 already asks for the wall pin).
- **Limits:** pooled, with a cap of about 12 per Pin (oldest first). Cosmetic only, so no collision, and no rings or bursts on landing.
- **Network:** show it for remote Pins too, from the shot's existing end event if there is one. Don't add a Net event just for this unless needed.
- **Check:** a missed arrow leaves one stuck arrow at its end point, and it's gone after the linger time.

## 2026-11-03 03:20 ET: OWNER: Dancer's dash loop (spec for OWNER_REVIEW item 7)
Owner: "the Shiv thing is you get a reset if your auto lands on your shift and you don't if it doesn't. Her autos feel weak outside of the shift autos, and it stacks her passive faster iirc."
Game data (supervive-data/supervive_kits.md, Shiv): LMB does 160, and each LMB hit adds 1 stack (+16 damage each). Quickflip empowers the next LMB for +214 (about 2.3x a plain shot). Hitting the empowered shot resets Quickflip and refunds its mana.
- **Reset only on a hit:** the Vault comes back only if the empowered bolt lands. A miss, or the empower timing out, gives no reset and the normal cooldown runs. Assert both.
- **Plain bolts aren't weak:** raise the base bolt damage and lower `prime_k` (now 3.5x) toward the data's ~2.3x, so plain autos carry her and the empowered one is a bonus, not the whole kit. Tune against the data ratios with our health scale.
- **Faster stacking on the empowered bolt:** keep 2 Marks on the empowered hit (the owner remembers it stacking faster; the data doesn't contradict that).
- **Dash into shot rhythm:** keep the empowered window short and readable, using the hand glint from item 8, not a ground ring.
- This is small data and kit work and can go in the current Dancer fix branch. The bigger feel pass in item 7 can wait until after the resets.

## 2026-11-03 03:22 ET: OWNER: art upgrade queued AFTER the gameplay work (main leads)
The owner wants a big art step up ("stylised, unique characters, toward AAA"). It's queued **after all gameplay work**. Main will flag it to the owner when it's time. The plan:
1. Art bible (one page: palette, shape language, outline and shading, VFX rules). Every agent builds to it.
2. Style pass: shader, lighting, post and VFX, in our current procedural rigs.
3. AI 3D pipeline prototype: Venator plus one Boki. Our own concept sheets, then image-to-3D (owner runs Meshy/Tripo/Rodin), then auto-rig, then Blender clean-up (scripted), then glTF into Godot behind a per-hero swap. KMoves are retargeted to the skeleton; procedural rigs stay as the fallback.
4. If it looks clearly better, roll it out hero by hero.
No art-pipeline work before then, please.

## 2026-11-03 03:25 ET: OWNER: danger scales by tier (add to the harder-maps spec, after the resets)
The owner agreed. The Hollow Crown (beginner) stays as it is. Harder tiers add tension in the Arc Raiders style without burying the hero fights:
- **Mid tiers:** a few roaming **apex threats**. These are huge creatures you avoid rather than fight. They hunt by **sound and sight**: sprinting, shooting and dashing are loud; sneaking and bushes are quiet; line of sight counts. Each has a readable alert state (idle, suspicious, hunting) and a way to lose it.
- **Top tiers:** apex threats plus Boki loss, dark zones (fog of war or limited vision), and a **rare-Boki spawn** that draws apex threats and players.
- **The top-down camera needs help:** fog or vision cones, noise pings on the map, and enemies that hear you, so sneaking stays tense.
- This goes with the new harder-tier maps and enemies (the separate higher-tier map spec). Nothing changes on the beginner map.

## 2026-11-03 03:30 ET: OWNER: post-reset queue additions (before the art upgrade)
The owner agreed. These go right after the resets, ahead of the art upgrade:
1. **"One great match" milestone.** One map and one tier, solo and squad. A 10-minute playtest script: drop, fight wild Boki, capture one, PvP once, merge once, extract or lose. Fix the feel problems in order. No new features merge until that loop feels great.
2. **Boki as the star. The owner especially wants more meaning in the merges and more thought on the Boki.**
   - **Merge moments:** a brief slow-mo hit, a camera punch, the Boki's cry, and each type's own fusion look. Every merge should feel like an event. Main owns the merge files.
   - **Merge choices with meaning:** each Boki type's merge changes how you play (its own form ability, its own dash and passive), not just stats. Main will draft a spec per type for the owner first.
   - **Boki personality in matches:** small reactions (celebrating a kill, worrying when you're hurt, excited near rare Boki), plus bond-level behaviours.
   - **Losing a Boki should hurt:** a clear moment when it's taken, and a clear way to get it back.
3. **Playtest tooling.**
   - An F8 in-game feedback button that saves a note, a screenshot and the match state.
   - Session stats: deaths, merges, extracts, and time to the first fight.
   - A short guide for outside testers.
4. **Scope freeze list (pending the owner's approval).** Candidates for "later": farm-builder depth, Black Market extras, and maps beyond tier 2.

## 2026-11-03 04:15 ET: OWNER: chests sparse, in predictable spots (keys-cover owner)
The owner says there are too many chests scattered at random since the key changes. They should be a mini objective:
- **Placement:** 1–3 **chest groups** per map, at **fixed, authored spots** players learn (landmarks: a ruin, a cliff top, a lair approach). Not random scatter.
- **Count:** sparse, about 2–4 chests per group at most. Remove the random scatter chests.
- **Readability:** each group is visible from a distance (a landmark or glint), so it reads as a place worth going to.
- **Author it in the map generator** (tools/make_hollowcrown.py), not by editing the JSON by hand. Then check keys-check, cover, drop, extract and bot-sanity. Bots should still path to the groups.
- Small change; fine during the landing freeze.

## 2026-11-03 09:00 ET: SYNC77 SHIPPED (4d39c623): physics pass
- **Physics pass on main** (content/rules/hunter_move.json "physics", from the game data): air control, fall caps, abyss slow, glide height and swoop, mantle launch. Walking off ledges stays allowed.
- **Check updates:** Dancer's cartwheel landing wait is now 2.0 s (jumps hang longer). Dredge's abyss reel gap is now 5 tiles (lower gravity). kin-regen moves the owner 15 m away.
- **Bug fix:** a bot looped in the air at prop-raised ledges. `_ledge_rise` now uses the higher ground.
- **For your kit checks:** any that pin jump or fall timing may need the same retune.

## 2026-11-03 10:45 ET: farm tutorial plan (server STATUS.md): builder name, and questions relayed to the owner
- **Builder name is NOT Dunna.** The owner named the farm builder **Hob Brackenridge** (walk up and press E). Please use Hob everywhere.
- I've put open questions 1–5 to the owner and will post his answers here.
- The mapclean move-feel spot fix in the check sounds right; include it in mapclean.

## 2026-11-03 10:50 ET: OWNER ANSWERS: farm tutorial (server STATUS.md, open questions 1–5)
1. **Top tracker:** yes, the top-right first-day card is the one. Replace it with "Goals" as planned.
2. **The house costs a little,** and it's the wood lesson. The tutorial gives the player an **axe**, they chop a tree for wood (with a proper chop animation and feedback), then pay the small house cost. **Also teach assigning a Boki to a task here** (assign the starter Boki to help gather or build).
3. **Yes, the player swings a hammer to help build,** and the tutorial shows they can. **Every starter Boki can help build.** Not every Boki can do every job: give species task skills (some build, some gather, some haul, and so on) and show them on the Boki's card.
4. **Keep the first-day gem bonus** as one reward at the end.
5. **Strict on a new save, enough to force learning.** The **house/farm tutorial can't be skipped**. The **fighting tutorial can be skipped**.
Builder: Hob Brackenridge. Per PRIORITIES.md this is P1 onboarding, after the resets, unless the server already has budget for it.

## 2026-11-03 11:00 ET: OWNER PLAYTEST (sync77): kit feel list (yours, OWNER_REVIEW item 10+)
Owner, verbatim points, with my notes:
- **Shifts mostly feel a bit fast.** Especially:
  - **Pin's.**
  - **Tamsin's:** it must feel like **skating, not sprinting**: glide in, carve, momentum.
- **Ostra must be able to move during her Shift.**
- **Bjorn (Oath) LMB hold still flickers out:** the hold animation must NEVER show when you're not holding.
- **Moosh Moosh:** more **air control during her jump dash**. A better ground-dash animation, closer to the source (Elluna).
- **Every interaction must be chainable.** Example: Breah **Shift → RMB doesn't work right now**. Audit all 12 kits for input buffering and cancel windows, so an ability pressed during or at the end of another fires.
- **Zedran (Brall) RMB:** should look like **holding the sword over his head** like the source, and be **holdable**. "This one is off for sure."
- **Zedran's tether (Warchain), and its interaction with RMB, still feels bad.** Rework the feel against hero-ref and the data.
Each with a check where possible (chain: Shift then RMB fires within the buffer window; Bjorn: no hold pose without the hold input).

## 2026-11-03 11:00 ET: OWNER: one connected practice space plus a 4v4 Arena mode (after the resets, P2/P4)
- Today the Duel Room, the Arena and the Training Grounds are three separate places. The owner wants **one connected space with two sides**:
  - **Training Room (left):** intentional practice stations: glide course, dodge machines, a dash and ledge course, ability dummies.
  - **Duel room (right):** a simple circular arena where you spawn an enemy (bot or dummy) or fight another player.
- **Arena mode:** contained **4v4 round-based matches like the source's Arena**, each round slightly different (map variant or modifier).
- Main will draft the spec for the owner after the resets. Nothing to build yet.

## 2026-11-03 16:45 UTC: ext/demo-integ MERGED as integ78; sync78 exporting for the owner's PC
- integ78 = ext/demo-integ ba7e542 plus main's small notice fix: farm notices as bullets in plain words, and the migration notice gets its own title.
- Main pushed (ff), exporting now. I'll post here once it's installed.
- **My quick checks:**
  - **pass:** --check, equal, hudref, move-feel, extract, dash-flow, wall-size and keys; health --strict OK.
  - **fail:** --boss-check, 1 failure: "a bot walked up and opened Stormcrown Eyrie in 150s". It passed on physics76 4d39c623, so it's probably the mapclean geometry on the bot's path to that lair. **S1 (mapclean owner): please look; not a demo blocker.**
- I didn't run S2's full suite. When yours finishes, please post any red here.

## 2026-11-03 17:20 UTC: SYNC78 INSTALLED on the owner's PC (main 31ef8481 = ext/demo-integ ba7e542 + the notice fix)
- The demo build is on his PC. All nine demo branches are now on main.
- Still open: --boss-check "bot opens Stormcrown Eyrie in 150s" (likely mapclean). S1, please look.
- Main's parked WIP: an overheated glider still lifts out of the abyss at half strength (owner request), on branch awaynote. It's unchecked, so it's not in sync78. Main will check it and land it next.

## 2026-11-03 17:05 UTC: OWNER: Zedran's RMB holds as long as you want (add explicitly to OWNER_REVIEW item 22)
I couldn't find this spelled out in item 21 or 22, so here it is:
- **Zedran's RMB can be held indefinitely**, like the source's Brall. The sword stays raised over his head (a proper overhead pose, not a crouch flicker) for as long as RMB is held, and it releases only when you let go.
- The charge still caps at full, then waits there with a clear "ready" tell. No auto-release, no timeout.
- Holding works on the ground and mid-air, keeps moving at the hold speed, and other inputs follow the item 22 interaction table.
- Assert it: hold RMB for 5 s and it never fires. Release, and it fires at full charge.

## 2026-11-03 17:10 UTC: OWNER: Zedran RMB perfect release (add to item 22) + Boki ability decision
- **Zedran's held RMB (Fiery Lunge) has a perfect-timing release:** the owner says that releasing at the right moment sends you a bit further, the way Brall does it. It's not in supervive_kits.md, so check the footage (hero-ref/juggernaut.md, the hold and lunge frames) for the window and the tell. Build it with a clear "now" cue (a flash on the blade), a small extra distance and a distinct sound. Assert it: a release in the window goes further than one just outside it. This sits with the indefinite hold: hold as long as you want, and the perfect window recurs or holds at full charge per the source.
- **Boki ability decision (for the C-into-G pass, main's part, after the resets):** the C key goes away. **The Boki decides when to use its abilities on its own.** The player doesn't need to control everything it does. If anything is manual, it's an entry on G's hold-wheel. Boki may get **more than one ability** later, so build the AI choice per ability, not around one key. Merge moves to C.

## 2026-11-03 17:12 UTC: OWNER: Zedran LMB hold scales, and do DEEP research on Brall (item 22)
- **Zedran's LMB hold (the Searing Wave, i.e. Brall's charged fireblast) grows with hold time:** the longer you hold, the bigger it gets (size, and per the source probably reach and damage). Today it doesn't scale. Read the scaling curve and its steps or cap from the footage and the data (supervive_kits.md: tap 43, hold 107). Show the growing size while charging.
- **Before building, the Zedran agent must do a deep research pass on Brall:**
  - every frame in hero-ref/juggernaut.md and the raw footage folder
  - supervive_kits.md, kit_comparison.md and supervive_physics.md
  - the owner's notes across OWNER_REVIEW and the INBOX files
  
  Then write a full mechanics sheet in docs/heroes/juggernaut.md before writing any code: every input (tap, hold, release timing, airborne, during the chain), its scaling, its windows, and its interactions. The owner's level of expectation is "the same craft as SUPERVIVE". Opus at medium effort, per item 22.

## 2026-11-03 17:15 UTC: OWNER: Tamsin's ice path, and maxed abilities matter (pick one to max)
- **Tamsin (Celeste source), Rinkrun:** she must **leave an ice path behind her**: a visible trail of ice on the ground that lasts a few seconds, with the source's gameplay (check supervive_kits.md / hero-ref: it likely speeds her and allies, and slows or affects foes). Put this in her feel pass with the "skating, not sprinting" note.
- **Maxed abilities (cross-kit, important to the owner):** in SUPERVIVE you level up, **choose which ability to rank**, and **maxing one (rank IV) unlocks its bonus**. You had to pick one to fully max, and that choice shaped your build. The data has every hero's "Upg" lines in supervive_kits.md.
  - **Every kit:** make sure the max-rank bonuses from the data exist and work (our `rank3`/`rank_next` data, rank-checks in the kit code). Audit all 12 kits against the data's Upg lines and assert each max bonus in the combo checks.
  - **System (main, P2 after the resets):** today ranks follow a fixed `order` per hero. Main will build **player choice on level-up**: a pick-an-ability prompt on the HUD, with the max bonus shown before you commit. Bots pick by their own order. Ext: keep `order` as the bot default.

## 2026-11-03 17:17 UTC: OWNER: two RMB animation corrections
- **Tamsin (Celeste) RMB:** it is **a push, not a throw**. The spear or shard is driven forward from the body with both arms (a thrust or shove), with no overhead or wind-up throwing arc. Check hero-ref/tamsin footage for the exact pose.
- **Venator (Ghost) RMB grenade:** **a side toss**, not an overhead throw. A low, sidearm or underhand flick from the side, quick, with little wind-up. Check hero-ref/venator.
Update both KMoves and their animation strips, and put each in that hero's current feel branch.

## 2026-11-03 17:19 UTC: OWNER: ability ranks in the Training Room (main, with the level-up choice, after the resets)
- In the training area you can set your ranks freely to practise any build:
  - **"Max all"** for testing.
  - Or **choose which ability to fully max**, exactly as the real game allows (one max plus the normal ranks), so you can practise your real build.
- **Easy reset:** one button or key puts ranks back to level 1 (and resets cooldowns).
- This goes with main's level-up choice system and the planned connected Training Room. Ext: no action, just awareness. Kit max-rank bonuses must work when set this way, not only through levelling.
- **Owner follow-up:** in SUPERVIVE these practice options (ranks, max, reset, cooldowns and so on) live in the **Esc menu → a Training/Practice settings page**, not on an on-screen bar. Copy that: move our arena key hints and toggles (K, L, the 2-9 hunter picks, Backspace reset, N bot, O cooldowns, U ultimate) into an Esc-menu Practice page. The world view stays clean.

## 2026-11-03 17:35 UTC: OWNER DECISION: the Mantle look by distance, and no Mantle on the farm (refines OWNER_REVIEW item 45)
The rule: the look depends on where you're seen, not one flat percentage.
- **In a match (top-down camera): about 90–100% Mantle.** Locked layer: silhouette (head shape, hat or helmet), weapon and how it's held, signature colour, animations and VFX. Any two players on the same Mantle must read identically at gameplay zoom.
- **Up close (portraits, lobby, character select): about 60–70% Mantle.** The personal layer shows: face, skin, hair (where not covered), build within limits, a personal accent colour, small trinkets.
- **On the farm: no Mantle, you're yourself.** The owner says there's no base class at home. You're fully your own customisable character (the creator's look plus outfits), not a hunter. You take on the Mantle when you go into a match or the Training Room.
- **Three layers:**
  1. Locked (Mantle silhouette, weapon, colour).
  2. Personal (your creator choices).
  3. Cosmetic (skins and trinkets, which must keep layer 1's silhouette).
- **Lore check:** the Mantle is something you take on for the hunt, so wearing it on the hunt and not at home fits. The transition is a short "taking up the Mantle" moment at match start or the portal (a visual only).
- **Impacts:**
  - The home and farm character uses the player's own body and outfit, with no class gear (this also solves the earlier "creator preview without class gear" item).
  - Character creation is about *you*.
  - The hunter pick is about the Mantle.

## 2026-11-03 18:05 UTC: MAIN CADENCE THIS WEEK + Mantle onboarding items
**The owner asked main to focus on merging and keeping everyone updated this week.** Main now checks briefs and branches **about every 90 min**, merges anything marked READY (with the commit), ships to the owner's PC and posts here each time. To get merged fast, post "READY: <branch> @ <commit>, checks run, known-red" at the top of EXT_TO_MAIN or STATUS "FOR MAIN". Prefer one integrated branch (like ext/demo-integ) when you have several.

**Mantle onboarding (owner, for the new-game flow and prologue; yours):**
- **Character creation is just you:** face, body, hair and outfit, with no class choice.
- **New-game flow:** intro, then make yourself, then pick your egg, then the farm. At the first portal or Training Room visit you take up **Venator's Mantle** for the tutorial. **After the tutorial:** "choose your second Mantle" (1 of Zedran / Pin / Linwick). This moves the hunter pick out of creation.
- **Explain the Mantle early.** Add one prologue line, e.g. "The great Wardens are gone. Their Mantles wait for someone to take them up." Then add a short "taking up the Mantle" moment with one sentence at the first portal.
- **Name clash:** merge forms are called "___ Mantle" (e.g. Venom Mantle, merges_v2). Rename merge forms to a different word ("Fusion" or "Bond Form", the owner to pick) so "Mantle" means only the Warden legacy. Main owns merge_forms content: main will do the rename once the owner picks the word.

## 2026-11-03 18:10 UTC: NEW: briefs/DECISIONS.md is the shared source of truth (owner asked for one)
Every agent (S1, S2, orchestrator and kit agents) reads briefs/DECISIONS.md before building. It wins over older briefs and specs. Main keeps it current. Propose changes in EXT_TO_MAIN tagged "DECISION?". Please add it to every agent prompt you start.

## 2026-11-03 18:20 UTC: OWNER: rename Tamsin to **Claire** (rimewright)
- Please fold this into ext/class-titles, which already touches every hunter's name and title, so we don't conflict. Change it everywhere: HeroKit names, archetype JSON text, kit cards and tooltips, docs/heroes, hero-ref filenames where referenced, and the regenerated wiki.
- If class-titles shows titles instead of names, Claire is the base character's name behind the title.
- DECISIONS.md is updated.

## 2026-11-03 20:35 UTC: SYNC79 on main (3569310c): mapclean-fix plus the overheated-glider lift. DECISIONS and PRIORITIES updated
- **Main:** ext/mapclean-fix c36f6ea3 is merged. --boss-check and --base-check now pass (thanks S1). Also in: an overheated glider still lifts you out of the abyss at half strength while it burns (owner). --check, move-feel, wallmove and health pass.
- **Owner's PC:** sync79 is exported, but the PC is offline right now, so it isn't installed yet. Main installs it at the next check-in.
- **DECISIONS.md:** all of the orchestrator's DECISION? lines are folded in (queues and modes, Ostra and Claire ults, Moosh Moosh's Elluna dashes, parity, agent models, portraits, Claire RMB). Dash buffering now matches the source; until S2's research lands, DashFlow's current behaviour stands. The 0.1 s figure is dropped.
- **PRIORITIES.md:** rewritten to the owner's new order: (1) ship the demo, (2) mechanics to source parity, (3) readability UI, (4) final Boki controls, (5) economy, (6) farm, (7) one great match, (8) modes.
- **Main takes item 3 (readability UI)** next: Boki ownership rings and tags, the hitbox ground circle (item 46), and the dash refill bar (item 47).

## 2026-11-03 21:40 UTC: SYNC80 on main and installed: 2D portraits, class titles and renames, dash refill bar
Merged:
- ext/portraits-2d 0a76796
- ext/class-titles 630241e (hunter_viewer keeps the portrait plus your intro block)
- ext/stamina-bar 823d7b7 (item 47; docs/HUD.md keeps both rows)

Checks: check, hudref, uipolish, hunter- and class-unlock, hero-combo, level-hud, stamina-bar, boss, keys, move-feel and dash-flow are all 0. Health OK. Wiki regenerated.
Not yet merged:
- ext/hitbox-size (item 46: --ability-check trap reported red; held until after the owner's demo)
- ext/dancer-feel, ext/market (after the demo)
- ext/warden-models (contains save v8: its own step)

## 2026-11-03 23:20 UTC (MAIN): orchestrator's DECISION?/PRIORITIES? folded in; integ81 merging; save numbering; the online pull bug
- **DECISIONS.md / PRIORITIES.md now include everything from 19:35 to 23:55 UTC:**
  - Steam not now; online launcher spec; servers live with their URLs; Black Market unfrozen; shops count as map work
  - Zedran Warchain extend-and-pull; Tarek RMB out of a glide; allies jump Tarek's rocks; Claire LMB homing
  - Ostra, Claire and Moosh Moosh items; parity; dash buffering
- **integ81 (testing now):** hitbox-size cd316a9, dancer-feel d36f73e, tarek-glide-slam 0e1e7cd, market 2b93dad. The wiki is regenerated: the Class-Marlowe / Class-Dolm / Tamsin leftovers are gone.
- **SAVE NUMBERING:** main is now **Save.VERSION 8 = market** (7 to 8). **ext/mantle-look and ext/warden-models must renumber to v9, and ext/farm-hob to v10** (mantle-look first, as it's further along). Each is a new migration step on top of 8, plus the version checks updated. Please rebase on main after this ships.
- **Online bug (kit-audit README: pulls and hooks skip `remote` bodies). The fix belongs in main's match/net code, not per kit.**
  - Knockback already crosses the network: `hurt()` carries `kb` to the owning game (match.gd ~6096).
  - Continuous displacement over time does NOT cross: drags, reels, pulls and chains (ashwick_kit.gd:612 `not f.remote`, dredge_kit.gd:353 `_end_pull` on remote, match.gd's drag lists).
  - **Main will add one shared path:** `Displace.request(target, {kind: pull|drag|reel, to, speed, dur, by})`. It applies locally for bodies this game owns, and sends a Net event to the owning game for remote ones, which applies it there and syncs as usual. A Net.VERSION bump comes with it.
  - **Kits then swap their direct position writes plus `if f.remote` skips for `Displace.request`.** S2: please don't build per-kit workarounds. Main posts the API, then S2 converts Cinder, Dredge, Zedran and Vireo.

## 2026-11-03 23:35 UTC: SYNC81 SHIPPED (main 001785de) and installed on the owner's PC
- **Merged:** ext/hitbox-size cd316a9, ext/dancer-feel d36f73e, ext/tarek-glide-slam 0e1e7cd, ext/market 2b93dad (**Save.VERSION 8 = market**; renumber mantle-look and warden-models to v9, farm-hob to v10).
- **Checks, all 0 failures:** check, market, hitbox-size, dancer combo, dolm combo, dash-flow, economy, equal, hudref, ability, boss, keys, move-feel, hero-combo, archetype. Health OK; wiki --check clean.
- **Main-side fixes:** the hitbox ring line wrapped; style baseline counts for main.gd, bot.gd and models.gd restored to main's values (a merge had carried a branch's lower count with main's lines); wiki class pages renamed to titles (Class-Hired-Gun, Class-Icy-Dancer); stale Dolm/Marlowe/Ashwick/Linnet pages removed; the Classes.md intro uses the new names and the X ultimate.
- itch.io gets this build automatically (CI on main).
- **Next:** ext/servers 3626491 as its own sync. S2 then redeploys the server build from main so versions match.

## sync82 shipped (main 31649d40) — FINAL KEYS
- keys82: R = hunter ultimate, X = Fuse (Merge), G = the one Boki button. No reload key (auto-reload stays until gun kits get source-style ammo, no reload). kin_ability (C) is gone: your Boki casts its ability by itself when out. C and T are home-only.
- Settings migrate via key_migrate keys4_v (old defaults move, custom keys kept, collisions start unbound).
- ALL agents: rebase onto main now. Never hard-code a key letter in text; use Settings.key_cap(action). Any branch still referencing "reload", "kin_ability" or HunterKeys.reload_pressed will not compile against main.
- S2: gun-kit ammo without reload is yours (follow-up, see DECISIONS Controls).

## 2026-11-04 00:25 UTC: OWNER farm feedback for ext/farm-hob (fold into that branch, it's in flight)
Owner, verbatim: "the challenge house or whatever is already there should either not be there or be ready to build with materials" / "crop patch should be near water and the tutorial should encourage that and mechanics should work like that - also need to have a way to make more rivers"
Main's read of the code, so ext can act directly:
1. **Challenge House** ("board" building): home.gd ~131 auto-grants it to every farm, and _fs_arrivals (~297) auto-places it after match 1. Decision: it's NOT on the farm at start. It becomes a Build-menu building with a wood/stone cost (same pattern as the hearth_oven/workbench entries in home_layout.gd), offered once you've done your first expedition, with Hob suggesting it. Existing saves that already have it keep it. Leave Old Pell's Black Market as it is.
2. **Crops near water:** there's no water-adjacency mechanic today (plots are watered by hand, by rain or by a farmhand Boki). Add one: a crop patch next to water (pond, river or wild water within ~2 tiles) waters itself, or grows faster (pick one and make it obvious in the patch tooltip). In build mode, the crop patch placement preview shows "near water" in green. The farm tutorial's crop-patch step tells you to put it by the water and points the marker there.
3. **More rivers:** a "Pond water" brush exists (home_layout "water", 6 gems). Add a River brush, or extend the water brush to drag a channel, so players can bring water to their fields. It counts as water for item 2. Keep it cheap.
These are owner decisions (also in DECISIONS). Save changes stay in farm-hob's v10 step. Report READY with checks as usual.

## 2026-11-04 00:35 UTC: OWNER: build/decorate UI revamp (next for ext, right after farm-hob; same files)
Owner, verbatim: "there needs to be a way to rotate placements in the house and farm and also better UI for building stuff, look at established games for this like animal crossing"
Main's read: rotation EXISTS but nobody can find it. Farm build: the "rotate" action (R) with a "turn" key hint in the footer (home_build.gd ~1781). House decorate: R or right-click (interior.gd ~392/404), with NO on-screen hint. So this is mostly a UI/discoverability revamp of home_build.gd + interior.gd. Do it after farm-hob lands, to avoid a conflict. Target, in the style of Animal Crossing (NH) furniture placement / Stardew / Sims build mode:
- One shared build/decorate UI for the farm and the house: a bottom catalog bar with category tabs and big item tiles with icon, name, cost and owned count; a search or filter; a "storage" tab for owned items.
- The held item shows as a ghost snapped to the grid, green or red, with its footprint drawn. Clear on-screen buttons AND keys next to the cursor: Rotate (key cap + right-click), Place, Store, Move, Cancel. Rotation animates with a quick turn, never a snap-pop.
- Click an already-placed item to pick it up, with a small radial/context menu (Move, Rotate, Store, Colour if it has one).
- The camera eases to a slightly top-down build view in build mode and back out after.
- Undo stays. Prices shown in materials and gems with have/need colouring.
- Key caps always through Settings.key_cap. Note R is the hunter ultimate in matches, but rotate on R at home is allowed (SHARED_OK).
Owner decision, also in DECISIONS. Report READY with before/after screenshots (the farmbuild_shots tool exists).
- **Addition (owner, 00:36 UTC, verbatim):** "also let's get rid of the stuff starting in the house, make it fully customisable. and clear when you can't place something cuz something else is occupying it, and easy to remove things". So: (1) a new house starts EMPTY (no pre-placed furniture). Existing saves keep theirs, but every piece, including anything that used to be fixed, can be moved or stored; only the door and walls stay fixed. (2) When a spot is blocked, the ghost turns red AND the blocking item is highlighted, with a short label next to the cursor: "Blocked by <item>" (or "Keep the doorway clear"). (3) Removing is one action: hover a placed item and press the Store key or click Store in its menu; there's also a quick "pick up" mode. Same revamp, same files.
- **Addition (owner, 00:37 UTC, verbatim):** "it probably should take you out of build mode when you place something". So placing a single item (a building, furniture, decor) puts it down and exits build mode, with a small "Placed! <Build key> to build more" toast. Exceptions, so it doesn't fight you: line and brush items (fences, paths, water/river, clearing) stay in their tool until you cancel, and holding Shift while placing keeps the same item in hand to place another.

## 2026-11-04 00:45 UTC: OWNER: the farm tutorial must also teach buying and resources
Owner (verbatim): "are we building a tutorial for the farm part where they show you how to buy stuff, how to get resources, etc?"
farm-hob's steps today: axe, chop, house, hammer, task, feed, crop, hob, expedition. Add, in Hob's voice and short, with the in-world marker:
- **resources:** wood comes from chopping, stone from rocks (pickaxe or a quarry), and crops from patches. Say where each one shows up (the materials bar) and what it's for (building).
- **market:** walk to the market stall, buy seeds (the Seeds tab), and sell one crop (Sell tab), so the player learns gems in and gems out. Give enough gems or a free first seed pack so they can't get stuck.
- **gems:** one line on where gems come from (selling, expeditions, Goals).
- The crop step puts the patch by water (see the 00:25 item).
Keep the whole tutorial fast: each step one action, nothing optional in the middle. The Goals tracker shows the step. The house step stays mandatory, and the rest can be finished in any order as long as each one is pointed at.

## sync83 shipped (main ca4305c1)
- newsave83: a new save picks its FIRST Hunter (Vex gun / Pin bow / Zedran melee) before the egg. The other two open after the first finished expedition. Cinder keeps its easy challenge. ClassUnlock.first_hunter() is REMOVED: rebase and stop calling it. HunterViewer.set_hunter swaps in place.
- homeui86: the Vendor tabs are now Boki | Hunter | Seeds | Farm | Home | Sell. UI.toast QUEUES (one at a time, repeats merged as "x2", wraps at 70% width). The whistle alert is smaller and sits at the landing when there's no house.
- Next: bokineeds88 (Boki indoors fix + wants bubbles), then tut84, drop87, notrain89, ext/servers.
- Known: pack-ui-check fails on main ("dropped thing is on the ground"), and portrait-check asserts name_of(gunslinger)=="Vex" but gets "Hired Gun". Both predate this sync; whoever owns them, please fix.

## sync84 shipped (main 91a6bd05)
- bokineeds88: short indoor naps, only with a house; no Burrow routing until a Burrow is built (KinBox.burrow_built); kin_wants.gd thought bubbles (Models.want_bubble REMOVED); kin_indoors.gd.
- drop87: DropFeel/DropReticle (projected landing ring, smooth steering, dive, landing impact). The Boki rides your shoulder through the drop (KinFollow.ride_the_drop), which fixes the Boki dying at the start. New --drop-feel-check.
- notrain89: the farm Training Grounds isle is REMOVED (home_training.gd gone). Training is from the portal or the Esc menu.
- tut84 part 1: the tutorial intro card, centred step cards and pill, the marker beam, the Boki leading, the crouch (scouting), F pickup and Boki-watch steps. Part 2 (the full course) is still in progress.
- Pre-existing failures on main, needing an owner: teammate-check (3), abyss-check ("dashing off an edge"), train-check ("sky train"), pack-ui-check, portrait-check (name_of gunslinger). Main is in low-usage mode until the Sat 11pm reset: merging only.

## sync85 shipped (main c00feadf)
- tut84 complete: the scripted tutorial course (content/maps/tutorial.json "course", content/rules/tutorial.json). Tutorial logic moved out of match.gd into Tutorial/TutorialDrive/TutorialHud. Fixed: crouch sight used view_range(crouch) (shorter); now view_range()*1.25 in ALL matches. The tutorial checks live in --teammate-check --teammate-only=tutorial.

## 2026-11-04 03:40 UTC: OWNER: build the Unmasked character TONIGHT, right after the heroes (ext)
Owner: "why cant we build it tonight? after the heroes are done. 3d is fast with meshy, i just need to re-evaluate all the heroes before pushing". So ext takes this NEXT, once the owner signs off on the heroes (warden-models / mask-look). Spec is in DECISIONS ("Player character: the Unmasked"):
1. The base model: one smooth, near-faceless humanoid (Meshy). Gender silhouettes, with height and build/thickness as morph or scale params. Simple face marks as textures or decals (eye shapes and expressions, brows, blush). No nose, race or species features. Outfits as swappable meshes. A colour.
2. The creator (hatch.gd LOOK_ROWS and the "make yourself" step before the egg): replace race/face/hair/skin rows with Body (gender, height, build), Face marks, Outfit, Colour, and a Walk/idle style if cheap. Migrate old saves to the closest new look.
3. In a match you're fully the Warden (mask-look). At home you're the Unmasked plus any kept mask features (just leave a hook for them, e.g. look["marks"] = [], for later).
4. Text: "Mask" not "Mantle" in all player text touched.
Main merges it as soon as it's READY. Report with screenshots.

## 2026-11-04 04:30 UTC: OWNER answers for ext/unmasked (641285d7)
- Heroes are NOT signed off (the owner is still working on them). So SPLIT: (a) ext/unmasked-home = the farm/town/house Unmasked + the creator + saves + text, mergeable now, with match/hero-card/HUD/portrait rendering left exactly as on main; (b) the match-side mask_look waits for hero sign-off.
- The new game flow becomes: intro -> **make yourself** (the Unmasked creator) -> **choose your first mask** -> egg. Update the class_unlock_check assertion.
- "Choose your first mask" preview: putting the mask on makes you MOSTLY the Warden, about 90% (owner: "dont fully become the hero, but mostly"). The Warden's model and outfit dominate, and about 10% of you shows through: your body colour on trims/accents, your height/build proportions and your eye marks behind the mask. A short put-on beat: the mask lifts to the face, a flash, the blend in. Same 90% rule in matches later (part b).
- Vex's 3D model is done (warden-3d/vex on origin/ext/hero-shots-s2): use it for Vex in the pick preview. The others use what's on main until theirs are signed off.

## sync86 shipped (main = integ86 merge of ext/unmasked-home 955402b0)
- The Unmasked creator, the new game flow (intro, make yourself, choose your first mask, egg), the mask put-on beat. Match side still on look["old"] until heroes are signed off. Checks green (portrait-check "new names" is the known old failure).

## 2026-11-04 11:40 UTC: main is integrating integ87 = kits-integ 5e551f8c + farm-hob 8e82638f + arena-sign 245f904c + warden-stance aa3345b6 on top of main 955402b0 (unmasked-home). Checks running; ships as sync87.
- **S2: ext/rename-breaker 72b79ec0 CONFLICTS with kits-integ** (mage.md, Classes/Weapons wiki, archer_kit.gd, hunter_anim.gd, kmoves_pin_bjorn.gd, combo51_shots, gen_wiki.py, hero_combo_check, parity_pvb). Please rebase it onto main once sync87 lands, and repost READY.
- farm-hob conflict resolutions: home.gd drops `training` (the isle was removed in sync84) and keeps hob/guide; interior.gd keeps Unmasked.worn() and drops the unused day1 "inside" mark. Save.VERSION is now 10.
- ext/build-ui and ext/warden-meshy: post READY on top of sync87.

## sync87 shipped (main cc27a057): kits-integ + farm-hob + arena-sign + warden-stance on unmasked-home. Save.VERSION 10. Checks green except: displace-net-check "guest joins the relay" (no local relay in main's container, so S2 please re-run on main) and farm-tutorial-check flaky once (passed on rerun). Next: rename-breaker (rebase on sync87), build-ui, warden-meshy.

## sync88 (pending ship): integ88 d365cea8 on main cc27a057 (sync87). Main ships it; this entry is the draft
- **Merged:**
  - ext/rename-breaker 72b79ec0 (Pip, Ryzz, Breaker, Hem, Kael and the 7 titles). It conflicted with the sync87 kit work in mage.md, Classes/Weapons wiki, archer_kit.gd, hunter_anim.gd, kmoves_pin_bjorn.gd, combo51_shots, gen_wiki.py, hero_combo_check and parity_pvb. Resolution: sync87's side everywhere (the kit audits, no-shake, Displace, the jitter holds, the Heavy Shot wording, `_pin_audit`; the branch's `pin_rundown` block was already gone on main), then the renames applied on top. The wiki is regenerated; the hand-written Classes.md intro lines take the new names. A sweep renamed the old names that sync87 had added in files the branch never saw (Zedran, Vireo, Bjorn, Tamsin, Linwick, Venator, Dancer in comments, check text and docs; code ids unchanged).
  - ext/build-ui 65a257f4 (no READY note was posted in EXT_TO_MAIN, so this is the latest tip; its own checks pass). Save.VERSION is now 11 (migration from build-ui; see its decision note 0017).
  - NOT merged: every ext/warden-3d-* branch, and ext/warden-meshy (no READY on top of sync87).
- **DECISIONS.md** now holds the Nov 4 decisions (Masks lore and relics, one villain, terms, renames and titles, second-Mask pick, Kael's white-hot glow, Breaker's model at 1.5x with the 0.46 m hitbox unchanged, roster, art direction). Kael's glow and Breaker's 1.5x are 3D-model decisions, so nothing in code changed for them; S2 applies both in the Warden 3D batch.
- **Text sweep:** player text says Hunter / Mask / the Empty / Fusion. Merge became Fusion or Fuse (HUD, kit cards, kit text, tips, loading tips, key list, merge-form flavours, unlock goals). The Masks screen, bar button, practice picker, reveal ("NEW MASK") and toasts say Masks. Bearer is Carrier (Pip's passive). The Blight monster "Warden" is now the Watcher ("A Watcher shrieked", "The Watcher wakes", Soul Ember sources); the monster ids (`warden`, `bl_warden`) are unchanged. Code ids kept (warden_*, unmasked, MantleX consts, merge_*). hero-title-check now asserts no retired term in any class's text.
- **Prologue:** the 5 captions from LORE_MASKS.md (chapter THE MASKS replaces THE BOKI; the visuals are the old shots until the Sat rebuild). The tutorial Mask line is on the farm tutorial's portal step.
- **Masks flow (changed, per the 09:45 entry):** Vex is the one starter (the first-Mask screen shows Vex, already chosen; a click plays the put-on beat). After the first finished expedition the farm offers a second Mask: Kael, Pip or Cinder (`second_picks`, `ClassPick.offer`, `ClassUnlock.choose_second`, save keys `second` / `second_ready`). The two not picked go back to their own challenges. Hem is an early challenge unlock (it was already "easy"). Saves that picked before keep what they have; an old `bonus` still opens by itself. No save version bump: the keys are optional.
- **Demo tab:** Settings > Demo > Next match > "All masks open (offline only)" (`demo_all_masks`, default off). `ClassUnlock.all_open()` honours it while `Net.online()` is false; the save's unlocks are untouched. The lobby sends an open Mask of the same weight instead of a locked one (`ClassUnlock.online_arch`). Asserted in class-unlock-check.
- **Checks (integ88):** health --strict OK, gen_wiki --check OK, and all green: --check, hero-combo-check, archetype-check, farm-tutorial-check (failed once on "two Boki open two crew slots", the known flake; green on rerun), farm-start-check, unmasked-check, class-unlock-check 164/0, drop-feel-check, kin-indoors-check, market-check, warden-stance-check, teammate-check --teammate-only=tutorial, perkorb-check, keybind-check, ultbond-check, portrait-check 107/0 (the "new names" line and the Mask-pick chips now pass), prologue-check, hatch-check, build-ui-check, home-build-check, farmbuild, hero-title-check, hitbox-size-check, equal-check, equal-migrate-check.
- **Not run:** displace-net-check (needs a relay), the full teammate-check, abyss-check, train-check, pack-ui-check (known reds).
- **S2: please re-run `--displace-net-check` on main once sync88 lands.** It needs a relay, which main's container does not have; sync87's "guest joins the relay" line is the only red.
- **Left for later:** the first-portal tutorial line sits in the portal step's hint pill (a wider card would read better); Hunters/Hunter wording inside deeper screens (kit cards, tips) still says "Hunter" where that is the right term; internal ids and consts (MANTLE, MANTLES_AT, warden_*) are not renamed.

## sync88 SHIPPED (main d365cea8) and installed on the owner's PC. The draft entry above is now final. Main is back in low-usage mode.

## 2026-11-04 16:40 UTC: OWNER to S2: ship the 3D models now, then improve them DRASTICALLY (faces first)
Owner: "we can ship now but need to actually improve these drastically". Also: no mask route (some Hunters don't wear literal masks). Faces like Kael's are a dark smudge. The rubric plateaued at about 86–89% because it barely sees faces.
1. **art-integ ships as is** (post READY; main ships it as sync89).
2. **Then a quality pass on all 12, worst first (Kael, then any face under par):**
   - **Head-only generation:** Meshy the head from a close-up face reference so the face gets the full texture, then attach it to the body.
   - **Face texture:** upscale, then sharpen the eyes, brows, mouth and skin tone (image model or hand pass), then reproject.
   - **Overall texture resolution:** check the texel density on hands, weapons and outfit detail, and re-texture at a higher res where it's muddy.
   - **Lighting in game:** a soft face/key fill and a rim light for Hunters (match and close-ups), so dark skin and dark outfits read. Add to the Hunter shader or the light rig, not per-model hacks.
   - **Rubric:** add a face close-up score (eyes, mouth, likeness, appeal) and a dark-scene readability score, judged against the art. Report it per Hunter. Don't call a Hunter done until its face scores well up close.
   - **Shots:** render on a real GPU or at a higher res if you can; the headless renders undersell the work.
3. Post per-Hunter READY as before (before/after face close-ups side by side). Main merges each one as it lands.

## 2026-11-04 17:05 UTC: OWNER to S2: Hunter 3D ACCURACY PIPELINE ("I don't care how many Meshy credits or Blender is needed, do it right")
Replaces the 16:40 quality-pass list as the method. Main's research summary (sources: Scenario's generator comparison, Meshy's retopo guide, StableProjectorz/StableGen):
1. **Inputs first (the biggest lever).** For each Hunter, make a clean model sheet from the approved art with an image model: front, side, back and 3/4, in an A-pose, flat even light, plain background, same proportions in every view. Then a separate head sheet (front, 3/4, side) at high res. Bad inputs = mushy faces.
2. **Generator bake-off per Hunter**, multi-view, at the highest tier: Meshy 7.1 Multi-Image (4 views, up to 8K PBR), Rodin Gen-2.5 (up to 5 images, quad), Hunyuan3D 3.1 Multiview (up to 8 views), TRELLIS 2 (strongest on stylized characters, 4K), Tripo 3.1 Multi View. Keep the best per Hunter by the rubric. Non-Meshy tools need accounts/API keys: **agents don't sign up; list which keys you need and the owner provides them.**
3. **Heads separately:** generate the head from the head sheet (Sparc3D 2.1 Portrait is built for faces, or head-only multi-view in the bake-off winner) and join it to the body in Blender.
4. **Blender pass:**
   - Sculpt the proportions to match the art (head size, shoulders, limb length).
   - Separate hair/weapon/cape meshes.
   - Quad retopo with manual edge loops around the eyes and mouth, then rig to our skeleton.
5. **Texture after retopo**, then **project the actual concept art onto the model** (StableProjectorz, or StableGen in Blender via ComfyUI) from the front and side, so colours, markings and faces match the art. Hand-paint the eyes, brows and lips at 2K–4K for the head.
6. **Engine look:**
   - A shared Hunter toon/stylized shader with a face key-fill light, a rim light and an optional outline. Dark skin and outfits must read in every biome light.
   - 2K–4K hero textures; check the in-match LOD isn't too blurry.
7. **Rubric v2**, each part scored against the art:
   - full-body likeness;
   - a face close-up (eyes, mouth, likeness, appeal);
   - match-zoom silhouette;
   - dark-scene readability.
   Render on a GPU at 2x. The owner signs off per Hunter from side-by-side sheets.
Order: Kael first as the pilot (post its before/after and per-tool results), then the other 11. Report credits and keys used.

## sync89 shipped: main = tuthud91 (the tutorial HUD in lanes, a small top banner, a gentle re-prompt, practice monsters x5 HP, a reachable lookout, kit-aware right click, a state-aware G step plus hold-G orders) + main's farm welcome/tool-toast fix.
- **S2 (kits): the owner said "rmb is a tap, not a hold, there should not be a hold for vex rmb".** gunslinger.json's rmb still has a hold (hold 0.5, hold_cost 0.4). Please make Vex's right click tap-only per the owner (remove or retire the hold variant, and update the kit text and checks). The tutorial reads the hold from the kit data, so it'll follow.
- **ext (farm):** flaky checks on main: farm-tutorial-check "dragging a river puts water on every tile of the channel for 12 gems" (fails about 1 in 2) and farm-start-check "on open meadow it tints green" (fails on main). Please fix or de-flake them.

## sync90 SHIPPED (main c80f19c6) and installed on the owner's PC: ext/art-integ ed3cf00c (all 12 Hunters in 3D, match-zoom v2, Dredge at r3h). Suite green except the known farm-start-check meadow tint. The exe is now ~300 MB (15 parts). Later Hunter 3D updates (the accuracy pipeline, Dredge r3j) ship as follow-up syncs from new READY commits.

## 2026-11-04 19:30 UTC: OWNER playtest of the 3D Hunters (on integ91 = art-integ c5795079 + main tweaks)
Main did directly (integ91, ships as sync91): Kael 9% bigger and his sword 15% smaller (new warden_look "weapon_scale"); Hem red (kit colour, arrows, outfit), Heavy Shot = the bow arrow much bigger and red, no V telegraph; Ostra bigger (body 0.74 -> 0.9) and darker/more menacing (cloth albedo down, own_ambient darker, shade 0.55, glow 2.4, rim_far 0.7). Hunter agents: rebase onto these. Hitboxes unchanged.
Needs the model pipeline (whoever has usage, S2 or a Hunter agent):
- **Tarek (Cliff Runner): "legs are glitchy, he looks wonky".** Check the leg skinning/weights and the knee/ankle joints in tarek_fit (rig contract), plus the walk/run cycle at match zoom. Fix the deformation.
- **Breaker (Frozen Bulwark): "looks very off too, especially his weapon".** Check the weapon seat/scale on the hammer pivot (PinBjornWeapons hammer_pivot) and the ice slot. Note the DECISION that Breaker's model is 1.5x a medium hunter (hitbox stays): make sure that's applied.
Post per-Hunter READY with match-zoom and close-up shots, as before.

## 2026-11-04 19:35 UTC: MAIN HANDOFF (main is at 97% usage). The integrator role moves to S1 or a new session.
Pending, each to be merged to main once green (pushing main triggers the itch build; the owner downloads from itch):
1. **integ91** (origin/integ91): art-integ c5795079 (newer 3D Hunters, Dredge r3j) plus Kael size/sword, Hem red + Heavy Shot, Ostra bigger/menacing. --check passed; the rest of the hero checks were still running. Run --warden-model-check, --warden-glb-check, --hero-combo-check, --portrait-check, --hitbox-size-check, --archer-combo-check, then fast-forward main.
2. **spine92** (agent running, off integ91): Tarek's ult is standable over the abyss, with a gentle curve, and narrower.
3. **kitui93** (agent running, off integ91): newest portraits everywhere (incl. the Esc hero picker and the bottom-left HUD) + a simplified K kit card.
4. **empty90** (agent running, off main bdbfc647): the Empty creator (void face, Male/Female, real height), the in-world Mask moment after naming the egg, the intentional second-Mask beat, mask previews with clips and no gender. Expect conflicts with integ91 (hatch/class_pick): resolve keeping both.
Also open: Tarek legs / Breaker weapon (19:30 entry), Vex RMB tap-only (S2), the flaky farm checks, the Boki art pass (S1, Gravidillo pilot).
