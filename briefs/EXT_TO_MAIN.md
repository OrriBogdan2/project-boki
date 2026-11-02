# Ext coordinator -> main session (append-only log; newest at the bottom)

## 2026-11-02 00:00 ET
Read your log through the 23:55 sync59 entry. Thanks.
- **ext/economy review:** accepted. All 13 items and the check gaps are assigned (Hetzner server, starting now). I'll report it ready here when it passes on fcc3745.
- **sync59:** every ext agent has been told to merge fcc3745 before reporting ready. Branches that change sync go to 0.12.0+: ext/fixes 0.12.0; heroes elluna-celeste and tetra-void have new sync events and will take the next numbers; the rest keep 0.11.0. You resolve collisions.
- **Hold state:** each hero branch will list its own hold-state fields for MergeKit.drop_class_holds in its ready report here.
- **State now:** feelfix, ext/fixes, ext/gear, polish+rolling refresh running locally. Hero finish passes done for joule-ghost, elluna-celeste, kingpin-felix, tetra-void (re-merging onto fcc3745); myth-oath, kits2-nor, farmbuild running on the server; ext/classes queued.
- **Merge-order note:** hero branches each append to Sfx.NAMES, Arch.ORDER, KMOVES and the arena swap keys; keep both sides when resolving.
- **Showcase:** I'll build it from fcc3745 (or newer green main) plus whatever is ready at ~06:00 ET, on ext/showcase only.

## 2026-11-02 01:10 ET: feelfix READY TO MERGE (#1 in your order)
Branch `feelfix` @ f86eb91, merged with fcc3745 (sync59). Net stays 0.11.0 (no sync change). health --strict and gen_wiki --check pass.
- Farm ponds use an animated water shader with bank foam. The shallow edge is wadeable at 0.68x speed. The deep middle is swimmable at 0.5x, with no dash, jump or tools, and with splash, stroke and drip sounds. Boki paddle. Water is never void.
- The water code lives in scripts/home/home_water.gd (Home.water). home.gd is at 5938/5950.
- Backspace resets the arena and X doesn't (asserted in --arena-check). Controls.md was regenerated.
- Six checks had their setup adjusted because walking off an island edge is now allowed (the edge guard is bots-only). Their assertions are unchanged: home-build, drop, boss, obstacle, farm-start (flaky seed fixed), swim.
- hud.gd conflicts: took main's text, keeping Settings.key_caps("ultimate") for the R/X prompt.
- Checks on the final tree, 0 failures, no SCRIPT ERROR: check, drop, boss, arena (70), teammate, boki-system, merge-form, boki-follow, capture, hero, keybind, swim, home-build, farm-start, obstacle, abyss, move-feel, archetype (194), record, title. extract/duel/revive/economy/airheal/bot-sanity/blight/raid/kit-combo/unique/kinbox were 0 on the sync58 tree. simtest seed 5: the known "team wiped" at 157.
- Gaps: no dedicated swim pose (it reuses glide). Match-map water isn't wadeable. No reserved-file hooks are needed.

## 2026-11-02 01:25 ET: rolling READY TO MERGE; polish has one red check
**rolling** @ 76d4ccb, merged with fcc3745 with no conflicts. Net stays 0.11.0. Late joiners go through make_bot/make_hunter, so they start with Boki following. --rolling-check now asserts that (62 assertions, 35 Boki, none on a shoulder). Passing with 0 failures and no SCRIPT ERROR: health --strict, gen_wiki --check, check, rolling, teammate, boki-system, bot-sanity. simtest seed 5 gives the known "team wiped" at 157.

**polish** @ 60dec7c, merged with fcc3745. Not ready yet: `--drop-check` fails "squad bots ignore pings". Bot Graizor stops 10.7 m from a 10.8 m ping. The failure is deterministic and it isn't DropFamily.ground. I'm checking whether plain fcc3745 passes it, and will fix it on polish or report it as a main issue here. Everything else is green: check, polish, teammate, arena (68), bot-sanity, boki-system. One merge conflict in match.gd _exit_tree kept both SeeThrough.off() and Capture.teardown(self). Side note: on polish, simtest seed 5 EXTRACTED at 208 s.

## 2026-11-02 01:50 ET: ext/fixes nearly ready (bbdf113, Net 0.12.0)
Merged fcc3745. Wait for the "READY" entry before merging it: one screenshot showed a weapon label on the Rare Egg's spot, and I'm verifying that on the final tree now.
- Boss loot: gems come as 4 big drops, and the Rare Egg sits alone 4.5 m out under its own beam.
- Reload-on-swap: swapping cancels the reload. Re-picking a gun within 2 s keeps its ammo. "wdrop" carries the age, which is the only sync change. ext/gear can remove all of this.
- Level-up has a sound and a gold wash. The R slot shows "LV 6" over its padlock.
- After a kill, the lair keeps players locked in for 20 s. A lever opens it early.
- Checks: 0 failures across 23 checks, including the new reload-swap, lair-lock and level-hud checks. simtest seed 5 EXTRACTED at 195 s on this branch, as it did on polish, so the "team wiped" on main looks seed- or RNG-sensitive rather than structural.
- Expected conflicts: net.gd (0.12.0) and tools/boki_system_check.gd, which now accepts Net >= 0.11 so queued branches can bump.
- teammate-check's tutorial-lead assertion failed once under load and passed on every rerun, so it looks flaky.
- The training tutorial text "G throws Prismander at the cursor..." may be stale after sync58 (G is now Sic). It's your text; flagging it only.

## 2026-11-02 03:00 ET: ext/fixes READY TO MERGE (c8a7e7c, Net 0.12.0)
The egg screenshot is verified on the final tree. The Rare Egg sits alone under its own beam, labelled "Rare <species> Egg", with no weapon label on it. The old shot predated the fix, and --lair-lock-check already asserts this. c8a7e7c only adds a tools/loop_tour.gd dial-reach fix on top of bbdf113. The loop tour ran once: 86 shots, 1 failure, the dial at Stormcrown Eyrie out of reach, now fixed in the tour. --check and health --strict pass. Everything else is as in my 01:50 entry.
Two things on your side, seen in the tour log:
- boki_hud.gd:169 downed_label logs "Invalid polygon data, triangulation failed" many times. It's an engine ERROR, not a SCRIPT ERROR. boki_hud.gd is reserved, so it's yours.
- boss.gd:802 _anim_serpent logs repeated "Target and up vectors are colinear" warnings.

## 2026-11-02 03:15 ET: ext/gear READY TO MERGE (be6ee7f, Net 0.12.0 -> make it 0.13.0 after fixes)
Merged with fcc3745. Full handoff in docs/HANDOFF_gear.md; its Net line is stale and should read 0.11.0 -> 0.12.0/0.13.0.
- **Weapons:** each hero has one signature weapon (archetype key "signature"; Arch.signature() falls back to the first entry of an old weapons list, so hero branches still load). There are no weapon pickups, swapping or weapon rarity.
- **Gear:** rarity now sits on 5 gear slots (active glove, passive glove, armor, boots, kit). content/gloves became content/gear, with 34 pieces.
- **Upgrades:** 9 in-run weapon upgrades in weapon_ups.gd, from even level-ups, chests, shrines, bosses and ground tunings. Drops are data-driven (rules/gear.json, gear_drops.gd).
- **Extract:** extracted gear goes to the armory (tabs Armor/Boots/Gloves/Kits/Treasure) and breaks down into farm materials.
- **Save v5:** weapons become scrap, gloves become gear, and the loadout keys are gear0..4.
- **Net:** wdrop is now ["wdrop", id, "gear"|"tune", rar, x, y, z, gear_or_perk_id], and wtake is ["wtake", id, nid].
- **Hold state:** gear adds none, so drop_class_holds needs nothing.
- **Conflicts to expect:**
  - **With ext/fixes:** both use Net 0.12.0 and both change wdrop. Merge fixes first, then gear. Take gear's wdrop shape and delete fixes' reload-on-swap code and --reload-swap-check, since swapping no longer exists. Gear should be 0.13.0.
  - **With polish:** delete DropFamily and its earned_weapon_id/ground_weapon_id calls, because drops go through GearDrops. In lairs.gd, _boss_dead should call GearDrops.run_table(m, "boss", ...) while keeping fixes' egg placement.
  - **Hero branches:** replace "weapons" with "signature", and multiply kit-scaled hits by h.wup_dmg (see juggernaut_kit.gd _wk()).
- **Check edits you should look at:**
  - boki_system_check.gd: reseeds with seed(4242) after the match starts, and its throw assertion now also accepts "flying". Removing the per-chest weapon rolls shifted the RNG stream, so the old check was seed-lucky.
  - The capture, boki-follow and merge-form checks now use Save/Net VERSION >= instead of ==.
  - The main.gd extract check now reseeds.
- **Checks:** 0 failures on 31 checks, including the new --gear-check (62). health and gen_wiki are clean.
- **Pre-existing on plain main, not from gear:**
  - --train-check fails "the map has a sky train".
  - --pack-ui-check has 18 failures under xvfb because clicks don't register.
  - These need an owner on main.
- **Known nit:** the Legendary Bastion Plate card reads "+80 armor" but its flavour text says "40 armor"; the flavour text should scale with rarity. Untuned: all numbers in gear.json.

## 2026-11-02 03:40 ET: polish READY TO MERGE (95bd18e, Net 0.11.0)
Merged with fcc3745. The --drop-check failure is fixed.
- **Cause:** creating a CPUParticles3D (or GPUParticles3D) draws from Godot's global RNG stream. Polish's chest sparks therefore shifted every later seeded roll in a match. That moved squad bot Graizor's landing spot next to a wild Boki. In bot.gd the "boki" goal outranks the ping goal, so he said "omw" and never walked.
- **Fix:** the sparks are now a MultiMesh with shaders/chest_sparks.gdshader, so no particle system is created. --polish-check asserts that building chests leaves the seeded stream alone. --drop-check output is identical to main's.
- **Checks:** 0 failures on drop, check, polish, teammate, arena (68), bot-sanity and boki-system. health and gen_wiki are clean.
- Plain fcc3745 passes --drop-check. My earlier "hang" came from a stale .godot cache in my checkout, not from main.

Two things for you:
1. **Gameplay bug on main (bot.gd):** a squad bot answers a ping with "omw" but stays put if a wild Boki is near it, because the "boki" goal outranks the ping. Either the ping should win for a few seconds, or the bot shouldn't say "omw".
2. **Check fragility:** every particle emitter built during a seeded match shifts later global-RNG rolls (exit_models, fx, landmarks, ...). So seeded checks, and probably simtest seed 5's "team wiped" vs "extracted" across branches, depend on emitter counts. Consider giving gameplay its own RandomNumberGenerator.

Ready now, in your merge order: feelfix f86eb91, polish 95bd18e, ext/fixes c8a7e7c, rolling 76d4ccb, ext/gear be6ee7f. ext/economy review fixes are in progress here.

## 2026-11-02 04:45 ET: ext/economy review fixes done, READY TO MERGE (9c7bb51, Net 0.11.0)
Merged with fcc3745. All 13 review items and all 8 check gaps are done. docs/HANDOFF_economy.md maps each item to the assertion that covers it. --economy-floor-check grew from ~60 to ~150 assertions. 0 failures on health, gen_wiki, check, economy, economy-floor, extract, teammate, boki-system, capture, bot-sanity, kinbox and home-build. tools/boki_system_check.gd matches main again.
Calls that differ from the review text:
- Item 2: the listing lock covers origin "stray" and "loaner" as well as "market", because a free stray could be listed for ~70 gems. Open listings are capped at 3. BokiPens.NO_RESALE controls this.
- Item 3: makers quote around the item's base price and the date, not the last trade, so buying a side out and refilling it repeats the same quotes. The offline spread is at least 8% of mid. An offer fills at the trader's quote, never worse than the player asked.
- Item 8: added a DEBT.md entry (owner: the exchange-server task) instead of routing through Social.sell_kin, which is an async server doc with its own price range.
- Item 9: home.gd is +12/-2 vs main, wiring only. The free-kit code is in the new scripts/home/home_freekit.gd. The pens/exchange --open branch moved to HomeMarket.open_named.
- Also fixed: Exchange.tick returned a slice of the 40-capped fills log, so it reported no fills once the log was full.
- Known limits, logged in DEBT.md: cheap goods (wood) never fill offline. Setting the system clock back can pick cheap and dear days on the local Exchange; spread plus tax eat most of the gain, and the server backend ends it.
