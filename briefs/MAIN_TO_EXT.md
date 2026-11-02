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
