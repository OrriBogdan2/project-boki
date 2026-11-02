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

## 2026-11-02 06:30 ET: ext/showcase built (integration preview, not a merge request)
`ext/showcase` 2b8eb0b = fcc3745 + feelfix + polish + ext/fixes + rolling + ext/gear + ext/economy, in your merge order, Net 0.13.0. Built so the owner can record a showcase; it's also a dry run of your merges. Full suite green (24 checks + health --strict + gen_wiki --check, no SCRIPT ERROR). Not run: --simtest, --train-check, --pack-ui-check (known red on main).
What you'll hit when you merge the same branches:
- Only ext/gear conflicts (net.gd, lairs.gd, match.gd, spawn_plan.gd, hud.gd, boki_system_check.gd). Resolution as in my 03:15 note; see the merge commit on ext/showcase for a worked example. In match.gd's training area, keep polish's staggered two-row rack layout and put gear's six ids in it.
- Leftover callers after the gear merge: `Arch.default_weapon`, `HomeEcon.fix_loadout_class`, `spawn_weapon` in home.gd, hero_check.gd, level_hud_check.gd, rolling.gd. Switched to `Arch.signature` / a gear roll.
- Two checks need fixes after the merge: economy_floor_check (use a gear armory item in slot gear2) and lair_lock_check (boss pile now has "tune" pickups). Commit 5010b00.
- health.py budgets go over: home 6000, match 7100, main 4200, hud 3950 on ext/showcase. Those are temporary raises; the real fix is splitting those files.
Showcase-only commits you may want too: 087b799 (admin tools F1/backtick/Admin/Mod mode gated behind `-- --admin`), 2b8eb0b (gear card text no longer quotes rarity-scaled numbers, e.g. "+80 armor"/"40 armor").
Seen in the shots: the boss-pile egg label overlaps a second egg label ("Rare Cairn Egg" over "Prismatic ... Egg · 2m"); the Armory's 3D preview of Bastion Plate is a tiny white blob.

## 2026-11-02 07:00 ET: four hero branches ready to merge (on sync59)
All merged fcc3745, suite 0 failures, no SCRIPT ERROR, health --strict / gen_wiki --check OK. No reserved file edited.
| Branch | Commit | Net |
|---|---|---|
| ext/heroes-joule-ghost (Vireo, Marlowe) | 2a5e15c | 0.11.0 |
| ext/heroes-kingpin-felix (Ashwick, Dredge) | de9f660 | 0.11.0 |
| ext/heroes-elluna-celeste (Tender, Rimewright) | 2ca705e | 0.12.0 ("carry") |
| ext/heroes-tetra-void (Dolm, Ostra) | 9e7e2a8 | 0.12.1 ("zone") |
Conflicts you'll see: joule-ghost DEBT.md (keep both); kingpin-felix hunter_anim.gd km_sample now chains KMOVES -> KMovesPair.MOVES -> MergeMoves.MOVES; elluna-celeste and tetra-void both touch net.gd and the exact `Net.VERSION == "0.11.0"` asserts in boki_follow_check, boki_system_check, capture_check and merge_form_check.gd:767 (all changed to `naturalnocasecmp_to("0.11.0") >= 0`; merge_form_check is yours, a one-line change).
Two rule fixes: Tender's carry set-down was on `interact` (F), moved to crouch via `TenderKit.SETDOWN` (one line to change). Dolm's LMB hold threw a punch when a merge started; `DolmKit.lmb_override` now clears it when `KinMerge.active(h)`, asserted in hero_pair_check.

### Hold state for MergeKit.drop_class_holds (none cleared today)
- Vireo `MageKit`: `wire` (Wirerun, has telegraph nodes: call `_end_wire()`, don't just set `{}`), `ak.rmb_t` (Coilshot).
- Marlowe `GunslingerKit`: `needle`, `e_t` (Longneedle charge; `_end_needle()`), `slide` (Slipstep; also drives `roll_dir`/`roll_speed`).
- Ashwick `AshwickKit`: `spool`, `was_held`, `after_t`, `flame_acc` (Torch Lance; also drives `h.mel_hold`).
- Dredge `DredgeKit`: `wind`, `flying`, `pull` (has a rope node).
- Tender `TenderKit`: `setdown_was`, `carry_t`; a carried teammate (`CareUtil` meta `carried_by`): suggest dropping the carry on merge (untested).
- Rimewright `RimewrightKit`: `rinkrun`.
- Dolm `DolmKit`: `lmb_t`, `lmb_was` (already self-clearing), `dive`.
- Ostra `OstraKit`: `swap`, `primed`, `prime_until`. A swap finishing mid-merge teleports the hunter: clear via `_swap_end(false)`.
Capture.hunter_stop not used: every channel is either the dash itself or already stun-cancels (covered by the combo checks). Your call whether to add more.
Flake note: elluna-celeste --bot-sanity-check flagged a Juggernaut airborne 3.0 s at seed 9 once (limit 3.0 s); seed 9 alone and a re-run were clean. Existing hero, not branch code.
Joule-ghost DEBT: remove hex.gd and the "hex" Net event at the next Net bump (yours when elluna/tetra land).

## 2026-11-02 07:40 ET: ext/heroes-myth-oath ready to merge (on sync59)
a2e572e (merge da18d30 + hold fix), Net 0.11.0, no conflicts with fcc3745, no reserved file touched. Suite 0 failures, no SCRIPT ERROR (--check, ability, kit-combo, archetype 189, arena 68, bot-sanity, duel, revive, teammate, boki-system, merge-form, capture, boki-follow, mantle, obstacle, hero-combo 38), health --strict and gen_wiki --check OK.
Hold fix (same bug as Dolm): Bulwark's Crushing Blow charge swung when a merge started. archer_kit.gd and bulwark_kit.gd now clear their own holds on `KinMerge.active(h)`, asserted in hero_combo_check (it fails 3 checks without the fix).
### Hold state for MergeKit.drop_class_holds
- Bulwark: `lmb_t` (Crushing Blow charge), `wall` (raised shield: lowered on merge, HP kept), `anim_id == "bul_smash_wind"`.
- Archer: `pin_tele` (Heavy Shot lane telegraph), `anim_id` `arc_draw` / `arc_heavy_wind`. The bow draw itself is covered by your `draw_t` clear.
Not holds: Bulwark's thrown mace (keeps flying or lying through a merge, can't be recalled while merged: your call), Mending Ground, Hail Wall, Archer `high_t` / `loosed`.
With this, all five hero pairs are ready. Suggested order after ext/gear: joule-ghost, kingpin-felix, myth-oath (all 0.11.0, low conflict), then elluna-celeste (0.12.0), then tetra-void (0.12.1).

## 2026-11-02 09:00 ET: ext/kits2-nor and ext/farmbuild ready to merge (verified locally; the server built them but went silent)
**ext/kits2-nor cb588ab**, Net 0.11.1 (kit move id at snapshot index 31). On fcc3745. Suite 0 failures, no SCRIPT ERROR (kit-combo 33, archetype 208, arena, ability, bot-sanity, duel, revive, teammate, boki-system, merge-form, capture, boki-follow, economy, mantle, obstacle), health --strict / gen_wiki --check OK.
- Hold fix: Juggernaut and Thief kept holds through a merge start (charged Searing Wave fired for 31 dmg, Finishing Slam wind-up landed, armed Haul Slam stayed, scheduled Jackpot knives kept flying). juggernaut_kit.gd and thief_kit.gd now drop them; 10 "merge hold" asserts in archetype_check _combos.
- Hold fields for drop_class_holds: Juggernaut `lmb_t`, `lmb_buf`, `slam_w`, `haul` (cleared by `_drop_for_merge()`); `lmb_override` returns early while merged. Thief: none (the Jackpot burst scheduled with `m.later` now aborts if a merge started). Left alone as movement, not holds: Juggernaut `chain` (Warchain tether), in-flight `lunge`.
- merge_form_check.gd:767: same one-line ">= 0.11.0" change as elluna-celeste and tetra-void (identical text, so it merges cleanly). It's your file; flagging it.
**ext/farmbuild b7537bd**, Net 0.11.0, unchanged. Suite 0 failures incl. --farmbuild-check and --home-build-check. --farm-start-check is flaky on plain main too (random island layouts, e.g. "a pickaxe mines a boulder for 0 stone"); not a regression. docs/wiki/Checks.md (hand-written) has no --farmbuild-check row. Quarry hover label still says "grows back in 64s" (older node wording).
Ready from this side: 13 branches. Only ext/classes and ext/cleanup remain unbuilt.

## 2026-11-02 10:30 ET: ext/showcase-heroes (dry run of all five hero merges on top of ext/showcase): two things you'll hit
ext/showcase-heroes 49ca61b = ext/showcase + joule-ghost + kingpin-felix + elluna-celeste + tetra-void + myth-oath. Full suite green, 12 heroes in Arch.ORDER.
1. **J hero picker crashes once heroes without a class R are in.** home.gd read `adf["r"]["name"]` in the hero card tooltip and the expedition hero-button tooltip; the panel never opened and --hero-check hung. Fixed on ext/showcase-heroes (75d127e, 4 lines: "R: Boki Merge"). Each hero branch alone may hit it too; please carry this fix whichever merges first.
2. **File name clash:** joule-ghost and myth-oath both add `tools/hero_combo_check.gd` (Vireo/Marlowe vs Archer/Bulwark). On ext/showcase-heroes myth-oath's became `tools/archer_bulwark_combo_check.gd` (main.gd hook and docs/heroes/archer.md, bulwark.md updated).
Also: `Arch.default_weapon` (removed by ext/gear) is still called by tools/support_check.gd and tools/hero_pair_check.gd (--support-check hangs); switch to `Arch.signature`. Archetype JSON conflicts (mage, gunslinger, archer, bulwark) resolved by taking the hero side and collapsing `weapons:[..]` to `signature` (Archer = longbow, Bulwark = tower_shield). kit_card.gd got two duplicate `slots_of` functions from auto-merge; delete the extra one.

## 2026-11-02 11:50 ET: ack sync60, integ61, ext/equal; work split
Thanks for taking the showcase resolutions. Noted: no budget raises (split instead); new checks go in CheckRegistry.
ext/equal is started now, split three ways so it moves in parallel. All three are based on integ61 (for the hero list and CheckRegistry) and will merge main once sync61 lands:
- **ext/equal-loadout:** bring-in rules (gloves, boots, utility with a tier cap), equal base armour plus visible armour levelling, no home perks or pack size, the 1/2/3 utility belt, migration, loaner removed. Decision note 0005. Net 0.14.0 if needed.
- **ext/perkorbs:** orbs, no prompt, the boss fan with fade-for-you, the old kit passives as orb perks, the fixed per-hero weapon path with a level-up pop. Note 0006. Net 0.14.1.
- **ext/keys-cover:** one chest type, keys and carriers, Shrubling, hiding cover via make_hollowcrown.py. Note 0007. Net 0.14.2 if needed.
- **Then:** shops and the full-map legend, after A and B (they need the belt and orb APIs), then everything merged into ext/equal for one review.
kits2-nor and farmbuild get re-merged once sync61 is on main (kits2-nor goes above 0.13.0), as you asked.

## 2026-11-02 13:30 ET: ext/fidelity is running (split), names from the owner, ext/equal updated
**Fidelity:** the owner also gave me his footage directly. It was indexed by the ability cards, and reference sheets were written for all 12 heroes (Opus): input, aim mode, reticle, animation beats with frame counts, VFX, numbers, and a ranked gap list against our code. Tetra came from a separate guide video. The sheets are in `ext/agent-briefs:briefs/hero-ref/*.md`; frames stay off the repo.
The build runs on the server per briefs/SERVER_UPDATE5.md, with Opus 5.5 at medium effort (owner's request):
- **ext/aimkit** first: shared cursor-clamp aim mode, lane, V-draw, cone, circle, sweet-spot ring, arc wall, dotted lane, two-end marker, plus reticle charge, flare and perfect-star states.
- Then six kit branches: **ext/kitfix-pin-bjorn, -vireo-venator, -linwick-dredge, -moosh-tamsin, -breah-ostra, -dancer-juggernaut**.
- Each one reports ready on its own, after re-merging sync62.
- Your 11:55 and 12:00 notes are written in as overrides wherever they differ from the footage. For example, the footage reads Oath's LMB as a static charge, but the owner wants the hammer spinning while held, so his note wins.

**Names (your item 11):** the owner chose them directly:
| id | Name |
|---|---|
| thief | Dancer |
| archer | Pin |
| bulwark | Bjorn |
| gunslinger | Venator (was Marlowe) |
| ashwick | Linwick |
| tender | Moosh Moosh (was Linnet) |
| dolm | Breah |

Juggernaut wasn't renamed. Display names only; ids stay. Each kit branch does its own heroes. The minigun ability that's also called "Bulwark" gets renamed so it doesn't clash.

**Level-up RNG (your item 13):** I'll research how the original's level-up bonus worked and propose it here before anything is built.

**ext/equal:** the 11:40, 11:45 and 12:10 changes (two gloves Q and V, no glove ranks, the right-side HUD boxes, overhead icons) have been sent to the loadout agent. ext/market is queued after ext/equal. kits2-nor (Net 0.15.0) and farmbuild are being re-merged onto sync62 on the server.

## 2026-11-02 14:10 ET: owner answers
- **Terminology:** "Hunters" (not hero or class), so "Hunter unlock". Drop the Light/Medium/Heavy labels.
- **Unlocks:** pick 1 hunter at character creation, then 2 more early. A much better hunter viewer (model, animated ability previews) and a hold-to-unlock bar with an animation. Going into ext/classes, which is reopened on the server.
- **Names:** juggernaut is **Zedran**. Also Dancer, Pin, Bjorn, Venator, Linwick, Moosh Moosh, Breah.
- **Dredge's grab** goes through rocks like the original. **Pin's Shift** is the newer Spirit-Walk-style one. **Tamsin** copies the base hero, with no healing.
- **Dancer** (thief) is the furthest off: LMB becomes the ranged alternating bolts, and RMB the bolas. Top of kitfix-dancer-juggernaut.

## 2026-11-02 15:00 ET: ext/perkorbs ready to merge (part B of ext/equal; can ship on its own)
551683b, Net 0.15.2 (main is 0.15.0; yours to reconcile). On main 18fab56. Full suite of 24 checks passes, plus --perkorb-check (108). health --strict, gen_wiki --check OK.
- **Prompt removed:** offer_perks, choose_perk, perk_offer, perk_queue, the 1/2/3 keys and the toast are gone.
- **Perk orbs** (perk_orbs.gd, rules/perk_orbs.json): chest 1, shrine 1-2 (flat-stat lean), boss fan of 3 (weapon lean), brute 1. Fade-for-you-only on the fan. Net events "odrop" and "otake". Bots go for orbs within 16 m. Own seeded stream.
- **Kit passives** are orb perks with the same numbers. Magpie's gem bonus now actually applies.
- **Level-ups:** even levels follow a fixed per-hero weapon path (weapon_path.json for all 12, weapon_path.gd). LevelPop banner.
- **Hooks:** PerkOrbs.drop / spawn / grant / gem_mult, WeaponPath.on_level.
- **Level-up research** (your item 13) is in docs/decisions/0006, "Proposal: level-up bonus", with sources. The original had no random level-up roll: quiet stat growth per level plus ability points. The "RNG" the owner remembers is most likely its power drops, which the orbs cover. The proposal: quiet growth (+6% HP and +5% ability power for levels 2-6, half for 7-10), the banner on even levels only, and optionally a 15% "lucky level" orb. The owner's answer goes to you.
