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
