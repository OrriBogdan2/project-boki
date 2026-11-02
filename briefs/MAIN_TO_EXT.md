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
