# Archive of briefs/MAIN_TO_EXT.md, trimmed 2026-11-06 (finished, superseded history)

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

## 2026-11-03 09:00 ET: SYNC77 SHIPPED (4d39c623): physics pass
- **Physics pass on main** (content/rules/hunter_move.json "physics", from the game data): air control, fall caps, abyss slow, glide height and swoop, mantle launch. Walking off ledges stays allowed.
- **Check updates:** Dancer's cartwheel landing wait is now 2.0 s (jumps hang longer). Dredge's abyss reel gap is now 5 tiles (lower gravity). kin-regen moves the owner 15 m away.
- **Bug fix:** a bot looped in the air at prop-raised ledges. `_ledge_rise` now uses the higher ground.
- **For your kit checks:** any that pin jump or fall timing may need the same retune.

## 2026-11-03 17:20 UTC: SYNC78 INSTALLED on the owner's PC (main 31ef8481 = ext/demo-integ ba7e542 + the notice fix)
- The demo build is on his PC. All nine demo branches are now on main.
- Still open: --boss-check "bot opens Stormcrown Eyrie in 150s" (likely mapclean). S1, please look.
- Main's parked WIP: an overheated glider still lifts out of the abyss at half strength (owner request), on branch awaynote. It's unchecked, so it's not in sync78. Main will check it and land it next.

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

## sync90 SHIPPED (main c80f19c6) and installed on the owner's PC: ext/art-integ ed3cf00c (all 12 Hunters in 3D, match-zoom v2, Dredge at r3h). Suite green except the known farm-start-check meadow tint. The exe is now ~300 MB (15 parts). Later Hunter 3D updates (the accuracy pipeline, Dredge r3j) ship as follow-up syncs from new READY commits.

## 2026-11-05 03:21 UTC S5 SHIPPED ff92d1e2: ext/small-60-66-75 f44adba4, ext/warden-dredge-friend abf5f812 (Dredge r3m), ext/warden-3d-breaker db5d2f7b (Breaker s6), ext/warden-3d-sable 521ad28a (Sable s9), ext/warden-3d-ryzz dda04366 (Ryzz r9)
- main 4bac1edb -> ff92d1e2 (fast-forward of integ-s5b). All five merged with no conflicts.
- Integration commit:
  - regenerated docs/wiki/Rules.md (warden_look for Sable and Breaker)
  - wrapped one 150-char line in tools/ostra_orb_shots.gd (the style ratchet failed on it)
  - added its .uid
- No Net.VERSION change.
- Checks: --import, health --strict OK (no budget raised), gen_wiki --check clean. Full suite: 119 flags + --simtest --seed=5, fresh XDG_DATA_HOME, timeout 1200. Every check was 0 failures / PASS except the same reds as plain main:
  - abyss, obstacle, perch, grammar-runtime (5), merge-form, farm-start meadow
  - hitch and load (software renderer)
  - the known pack-ui, train and teammate
- --market-check failed once and passed on rerun (known flake).
- Also green: --ostra-combo-check, --ashwick-combo-check, --keybind-check, --warden-model-check, --warden-glb-check, --rig-standard-check, --warden-stance-check, --dredge-combo-check, --weapon-clip-check.
- Skipped: ext/hem-reticle (superseded by S2's ext/kit-hem-55b).
- Next, being tested now: batch 3 = ext/s4-integ bfb12fa7 (S4 98, 99, 101, 105) + ext/clarity-96 f41a7157 (S3), with **Net.VERSION 0.21.0** (S4 0.20.0 "bcn" + S3's "sping" kind). Then batch 4 = S2 kits hem-55b, kael-57, sable-53-54 (dry-run merge is clean).
- **Not done by S5 (reserved files, needs main or owner OK):** boki-talk-105's wiring 1-4 (kin_voice.gd line/callout -> BokiChatter, kin.gd bark_cd, kin_speak.gd recall cleanup, BokiSpeech/BokiLines tie-in). Until then the match callouts play the old lines (S4's DEBT entry covers it).

## 2026-11-05 04:11 UTC S5 SHIPPED 8f7a33d2: ext/s4-integ bfb12fa7 (rank-ui-98 bd04d5d2, loot-full-99 127ecfc8, revive-101 d53c445b, boki-talk-105 364fde44), ext/clarity-96 f41a7157
- main ff92d1e2 -> 8f7a33d2 (fast-forward of integ-s5c). s4-integ merged clean. clarity-96 conflicted in 6 files, resolved keeping both:
  - **Net.VERSION -> 0.21.0** (0.20.0 = S4's beacons "bcn", 0.21.0 = S3's squad ping kind). Online servers and the launcher need this build.
  - match.gd smart loot and life.gd beacons: S4 moved them into LootFull and Beacons; clarity had only shortened those toasts, so S4's code stays. Clarity's other life.gd toast text is kept.
  - farm_guide.gd: clarity's _update_marker(dt) and bubbles-under-lane, plus tut-airdash's crop label and task hint.
  - check_registry.gd: both sides' entries. style_baseline.json: regenerated (style_lint --update after health passed).
- Fixes needed for the combination:
  - tools/box_revive_check.gd used the removed hud.toasts; it now reads hud.msgs (clear/texts).
  - --uipolish-check failed 2 rows on scripts/ui/loot_hold.gd: S4's loot row builder moved out of hud.gd and lost hud.gd's exemption. LootHold is now in the check's ALLOWED list with hud.gd (in-match HUD). S3/S4: if you'd rather it use UiFrame, that's a follow-up.
- Checks: --import, health --strict OK (no budget raised), gen_wiki --check clean. Full suite: 126 flags + --simtest --seed=5, fresh XDG_DATA_HOME, timeout 1200. All 0 failures / PASS, including:
  - --rank-ui-check, --loot-full-check, --box-revive-check, --boki-lines-check
  - --shield-check, --clarity-check, --reticle-check, --ping-check, --msg-queue-check, --hudref-check
  - --uipolish-check (after the fix)
  - --hero-combo-check, --archetype-check, --dash-flow-check, --ability-check
- Except the same reds as main: abyss, obstacle, perch, grammar-runtime, merge-form, farm-start meadow, mantle-look, hitch/load, pack-ui, train, teammate. The farm-tutorial river row flaked once and passed on rerun.
- **Still open, reserved files (main/owner OK needed): boki-talk-105 wiring 1-4.** Match callouts still play the old KinVoice lines.
- Next: batch 4 = S2 kits hem-55b 8b2c04f1, kael-57 249bc11b, sable-53-54 157cffe4, breaker-59 8840f3d6, pip-scale-108 525298b8 (merged clean; suite running). Then batch 5 = art2-kael 0fbc63e6 + rename-lisette 7341f61a (dry-run resolved). perf-94 waits on S1's rebase (EXT_TO_MAIN).

## 2026-11-05 05:30 UTC S5 SHIPPED c204a6d5: ext/kit-kael-57 249bc11b, ext/kit-sable-53-54 157cffe4, ext/kit-breaker-59 8840f3d6, ext/pip-scale-108 525298b8
- main 8f7a33d2 -> c204a6d5 (fast-forward of integ-s5d). All four merged with no conflicts. No Net.VERSION change. Wiki unchanged.
- **ext/kit-hem-55b held:** it adds 3 mid-play shader compiles during the drop (bisected; details and a suggested fix in EXT_TO_MAIN).
- Checks:
  - --import, health --strict OK, gen_wiki --check clean.
  - Full suite (126 flags + simtest) on the five-kit batch: every check was 0 failures / PASS apart from main's existing reds and two known flakes that passed on rerun (farm-start pickaxe, mantle-look). The checks included --hero-combo-check 287, --archer-combo-check 143, --dancer-combo-check 126, --bulwark-combo-check 144, --juggernaut-combo-check 164, --kit-combo-check, --warden-model-check, --warden-glb-check, --rig-standard-check, --aimkit-check, --class-unlock-check, --arena-check and --tutorial-hud-check.
  - Re-run on the shipped four-kit tree, all 0 failures: --check, --hero-combo-check 272, --archer-combo-check 128, --archetype-check 362, --dash-flow-check, --ability-check, --aimkit-check, --class-unlock-check 153, --tutorial-hud-check. --hitch-check is back to main's baseline (no drop compiles).
- Next, suite running: batch 5 = ext/art2-kael 0fbc63e6 (registry conflict, kept both) + ext/rename-lisette 7341f61a (clean on this tree).

## 2026-11-05 07:15 UTC S5 SHIPPED 25e8ea8d: ext/rename-lisette 7341f61a, ext/kit-vex-68-109 4e4ab9b5 (incl. item 109 b13b0bc5), ext/portraits-six af003746
- main c204a6d5 -> 25e8ea8d (fast-forward of integ-s5f). No conflicts; the regenerated wiki is committed (Vex's gunslinger.json). No Net.VERSION change.
- **ext/art2-kael held:** it adds 3 mid-play shader compiles (2 ride, 1 land), bisected; details in EXT_TO_MAIN. Same family as kit-hem-55b's drop compiles.
- Checks: --import, health --strict OK, gen_wiki --check clean. Full suite: 127 flags + simtest. Every check was 0 failures / PASS apart from main's existing reds, including --gunslinger-combo-check 95, --hero-combo-check 272, --portrait-check 107, --dash-aim-check, --class-unlock-check, --arena-check, --tutorial-hud-check and --archetype-check. --hitch-check matches main's compile list exactly.
- Waiting on others:
  - ext/perf-94 (+ perf-94b): S1 is rebasing it onto main.
  - ext/kit-hem-55b, ext/art2-kael: S2, the warm-up fix.
  - ext/friendly-bodies: the dolm leap row.
  - ext/boki-starter: wiring in reserved files.
  - boki-talk-105: the reserved-file wiring.

## 2026-11-05 10:22 UTC S5 SHIPPED 354be5b4 (pushed 07:45 UTC; this log was delayed by a session restart): ext/perf-94c 3338363c, ext/s7-empty-77-81 a4808f68, ext/s7-boki-82-92 aeac83fe
- main 25e8ea8d -> 354be5b4 (fast-forward of integ-s5g). Merge conflicts: only tools/check_registry.gd (kept both).
- s7-empty carries a save-format change, with its migration (Unmasked.clean). No Net change.
- Fixes needed for the combination (S1, S4, S7: FYI):
  - **perf-94c x rank-ui-98:** HudPanels redraws the slots at 20 Hz, but RankMarks.spot dropped a "+" one frame after it was drawn, so the click target blinked out between redraws (--rank-ui-check: 2 rows; real in game). A spot now goes stale only once a panel redraw was due (frames > MIN_FRAMES+1 and > 75 ms). --rank-ui-check and --hudref-check (its "X tile shows its cooldown" row) now wait for HudPanels' draw signal before reading drawn state.
  - **s7-boki-82-92:** scripts/ui/boki_moves.gd built a StyleBoxFlat (--uipolish-check). It now uses UI.frame (same fill, edge and padding). --boki-moves-check 0.
- Checks: --import, health --strict OK, gen_wiki --check clean. Full suite: 131 flags + simtest.
  - 0 failures / PASS everywhere apart from main's existing reds. That includes --match-audio-check, --perf-overlay-check, --perf-throttle-check, --unmasked-check, --hatch-check, --prologue-check, --boki-moves-check, --warden-glb-check, --warden-model-check, --rig-standard-check, --hero-combo-check and --gunslinger-combo-check.
  - After the fixes: --rank-ui-check, --hudref-check, --uipolish-check, --tutorial-hud-check and --level-hud-check are all 0.
  - --hitch-check improved: 2 compile frames vs 4 on main.
  - --teammate-check: 2, the known rows (one rerun printed a third, "the tutorial still finishes", which did not repeat).
- s7-boki-82-92's later tip c10dfaef only merges main in, so there's nothing more to take.
- Next: batch 7 = ext/sfx-cleanup c35d44e2 (the whole sound pass) + ext/rename-lisette 1228b324. Batch 8 = ext/s7-dash-outpost-84-86 f1eac1a2 + ext/s7-build-90-91 f08e6c04 + ext/kit-hem-55b (perf-94c is in now).

## 2026-11-05 11:17 UTC S5 SHIPPED a4b39fd7: ext/sfx-cleanup c35d44e2 (the whole S4 sound pass: sfx-base + 14 groups incl. Claire, UI, Boki + cleanup), ext/rename-lisette 1228b324
- main 354be5b4 -> a4b39fd7 (fast-forward of integ-s5h). sfx-cleanup merged clean. rename-lisette conflicted in docs/heroes/ostra.md: kept the sound pass's names, with "Motley" applied. No Net change.
- Follow-up fix for 354be5b4's rank "+" (S1/S4 FYI): the 75 ms staleness rule still flaked under load ("no points left: the + is gone"). Now exact: HudPanels counts its redraws (static var draws) and RankMarks keeps a spot only while the latest redraw marked it. --rank-ui-check and --hudref-check (its E cooldown row too) wait for the panels' draw signal before reading drawn state. **Anyone writing a check that reads HUD slot text, keys or spots: await hud.panels.draw first** (panels redraw at 20 Hz).
- Checks: --import, health --strict OK, gen_wiki --check clean. Full suite: 132 flags + simtest. 0 failures / PASS everywhere apart from main's existing reds, including:
  - --sfx-set-check 0
  - every combo check: rimewright, tender, ashwick, dredge, ostra, mage, gunslinger, dancer, juggernaut, bulwark, dolm, archer
  - --hero-combo-check, --boki-system-check
  - after the fixes: --rank-ui-check 0 and --hudref-check 0, each twice
- Still not done (reserved files): the sfx-boki wiring in merge_xform.gd and kin_downed.gd, as listed by S4.
- Next, suite running: batch 8 = ext/s7-dash-outpost-84-86 f1eac1a2, ext/s7-build-90-91 f08e6c04, ext/kit-hem-55b 8b2c04f1. Merge notes:
  - registry: stamina-bar-check dropped, sfx-set-check kept
  - DEBT.md: both entries kept
  - 55b vs the rename: Lisette names

## 2026-11-05 16:46 UTC S5 SHIPPED b23aab82: ext/art2-kael 37e5033e, ext/art2-lisette acc0dcfb (+ Net.VERSION 0.23.0; release v0.23.0 running)
- main 0237eb8d -> b23aab82 (fast-forward of integ-s5j). Conflict: tools/hero_vfx_reel.gd (took Lisette's reel functions after Kael's voice section).
- Checks: --import, health --strict OK, gen_wiki --check clean. Full suite: 136 flags + simtest. 0 failures / PASS everywhere apart from main's existing reds, including:
  - --hero-vfx-check OK
  - --juggernaut-combo-check 164
  - --archer-combo-check 143
  - --sfx-set-check 0
  - --match-audio-check 9/0
- --hitch-check (S2/S1 FYI): 4 compile frames vs main's 3, as S2 predicted. The extras are existing lazy kit FX (CareLook glow/disc, PinFx trail, Fx.beam), not HeroVfx. The worst frame was 0.77 of budget under 3-job load. Accepted; the lazy kit FX remain S1's next perf step.
- S3: art2-kael's HeroVfx is now main's shared copy. ext/vfx-core and the per-Hero branches should merge main and keep S2's prewarm/prewarm_end, which draws particles and trails.
- Next, suite running: batch 10:
  - ext/kit-vex-112 d3252225 (HIGH)
  - ext/kit-tarek-61-67 eb040e7d. **S4:** br_rumble and br_crumble came in as committed .wav files; the old gen_stone_sfx.py stays deleted. Please port their two generator functions into gen_sfx_tarek.py.
  - ext/kit-cinder-66 ea287770
  - ext/portraits-three 8edb4f23

## 2026-11-05 16:54 UTC S5 RELEASED v0.23.0 (main b23aab82)
- https://github.com/OrriBogdan2/project-boki/releases/tag/v0.23.0 published at 16:52 UTC, first try, all 5 assets. It is now releases/latest, so launchers update to it on their next start. It adds art2-kael + art2-lisette (Kael's and Lisette's ability VFX and sounds) over v0.22.0.

## 2026-11-05 17:26 UTC ext → S5: PRIORITY: finished branches the owner is still waiting on
The owner keeps re-reporting items whose fixes sit on unmerged branches. Merge these first in the next batch, then release:
- ext/claire-62-65 @ c4cf394a (Claire air skate, 64, 65)
- ext/kit-tarek-61-67 @ eb040e7d (Tarek Quakefall tap/short hold, rocks). The owner adds 61b: a locked forward slam, auto-fired at the cap (≤2 s), no movement during. Add it if 61 doesn't cover it.
- ext/kit-tarek-111 @ 4e25e66a (Rock Hop)
Then 129 (the Gravadillo rider) and the 119-133 feel items.

## 2026-11-05 17:44 UTC ext → S5: item 139 (Ryzz finger guns; coils not gun-like) goes to S2 art. If art1-ryzz is merged before S2's fix, take the follow-up later. Projectile spawn = the fingertip anchors, alternating.

