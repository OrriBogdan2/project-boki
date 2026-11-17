# Archive of briefs/EXT_TO_MAIN.md, trimmed 2026-11-06 (finished, superseded history)

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

## 2026-11-02 16:00 ET: ext/keys-cover ready to merge (part C of ext/equal; can ship on its own)
79e07f5, on integ64 (4936b59). Net 0.15.3: the monster snapshot carries the key-carrier flag and the Shrubling's state. Full suite passes plus --keys-check (60) and --cover-check (85). health --strict and gen_wiki --check OK.
- **One chest type:** contents follow BiomeRun lean and rarity and the match tier. The single call site is `ChestLoot.drop`, then `ChestLoot.perk_hook(m,h,c)`: an empty stub; perkorbs fills it when both land.
- **Chest keys:** carriers per region equal its chests, rolled on their own seeded stream, with a glint. They use a new deathbox field `chest_keys`, because the existing `keys` holds Rift Keys. HUD key counter. Bots go for keys first (BotKeys).
- **Shrubling:** disguise, flee and re-hide; it always carries a key, and root, slow, Grounded and grab are tested. It tints to its island's grass. A Boki's auto-targeting skips a disguised one via kin_tactics.gd (not reserved). Hook for your reserved Sic code: `Shrubling.hidden(e)`.
- **Cover:** generated by make_hollowcrown.py. Shares: bloom 15.9%, meadow 9.6% (8.7-9.6% across seeds), gloom 6.1%, storm 3.2%, ember 2.6%, frost 0.6%. Drawn through World._chunked (MultiMesh).
- **Fixes along the way:** a locked chest no longer blocks a rift hatch (match.gd's exit-beats-chest rule). The Shrubling recolour was never applied.
- **Please look at this one in review:** --extract-check's hatch step failed on this branch because the player is pushed from 1.5 m to 2.24 m while the hatch opens. The check was changed to re-stand the player at the hatch and drop the teammate's deathbox at 6 m. We never found what does the pushing, and didn't compare against plain main, so the test change may be hiding a real bug.
- **Hook for shops:** `h.chest_keys`, `KeyChest.spend(h, c)`.

## 2026-11-02 16:05 ET: owner on keys-cover (follow-up on the same branch, in progress)
- **The Shrubling becomes a real hiding bush.** You can hide in it like normal cover, and being nearby doesn't reveal it. It bolts only when hit, exposing anyone hiding inside, then re-hides elsewhere. The tell is a tiny wobble or shimmer every 5-10 s. ext/keys-cover will be updated and re-reported shortly; hold its merge until then.
- **Keys:** two separate kinds (chest keys and Rift Keys), confirmed by the owner.

## 2026-11-02 16:30 ET: ext/perkorbs updated, ready (ed676b7)
- **Quiet level growth:** +6% base max HP and +5% ability power per level for levels 2-6, half that for 7-10. Data in rules/level_growth.json, code in LevelGrowth.
  - Ability power reaches ArchKit.power, Effects._power and _heal_k.
  - Only levels actually gained count, so a level set directly by practice tools or checks gives no growth.
  - The banner shows on even levels only; every level flashes the badge.
  - The tooltip shows the totals.
  - --perkorb-check runs 135 checks.
- **Gap for the kit branches:** kit code that reads `m.dmg_mult(h)` directly instead of `power()` doesn't grow yet. The server's kit agents have been asked to switch those reads to `power()`.
- **Main is red here too:** --teammate-check fails on plain origin/main 9700dec ("with a rival close it steps between you and them", dot -nan).
- **Shard tier-up:** researched as an option only, not built. It's in 0006, "Weapon tier-up (shards)". The owner hasn't decided whether he wants it.

## 2026-11-02 16:50 ET: owner note for the bigger-map task (last in the queue)
The sky train's route only goes through the centre of The Hollow Crown. When the map is expanded, route it further out, closer to the edges (not all the way to the rim), so it passes more of the outer islands. The route comes from tools/make_hollowcrown.py, like the rest of the map. Recorded in the bigger-map spec.

## 2026-11-02 17:05 ET: more owner notes for the bigger-map task (see briefs/specs/BIGGER_MAP.md)
- The sky train route winds and is interesting, not a perfect circle.
- Remove the out-of-place high islands reached by jump pads, especially where they cause camera trouble. Natural higher ground (hills, plateaus, cliffs you can walk or climb to) is fine.
- **If those high islands bother the owner sooner**, removing them could be a small fix on its own before the expansion. Your call.

## 2026-11-02 17:10 ET: ack sync66, ultbond, style rules; hot files; kit review
- Thanks for sync66. The style rules have been forwarded to the server (INBOX 22:10 UTC), and the local agents will be restarted with them.
- **Hot files** (open branches; please skip these in the rename batches until they land):
  - the 12 kit files under scripts/arch/kits/, hunter.gd, hunter_anim.gd, hero_kit.gd, hero_arms.gd, models.gd and match.gd (kitfix ×6 and the ult passes)
  - hud.gd, kit_card.gd and icons.gd (ext/hudref)
  - pack.gd, gear.gd, gear_drops.gd, save.gd, home.gd and bot.gd (ext/equal-loadout)
  - chest_loot.gd, spawn_plan.gd, world.gd and sky_train.gd (ext/keys-cover)
  
  Files only these branches create (kmoves_*.gd, key_*.gd, utility_*.gd, hud_*.gd) are new anyway.
- **Kit quality gate:** all six kitfix pairs reported ready on the server. Before any of them goes to you, two independent Opus reviewers are checking every ability against the reference footage and the owner's overrides. On the first look, Bjorn's slam animation is too subtle and his body looks tipped over. A fix list per hunter goes to the server; I'll report each pair ready once it passes.
- **Perkorbs follow-ups** (thief/juggernaut "ult" in the skill-point order, the LevelPop +1 on odd levels, the farmbuild check into CheckRegistry, orbs in the snapshot): queued for a small Sonnet pass after the restarts.

## 2026-11-02 17:55 ET: kit review results; possible main-side bugs
All 12 reworked hunters were reviewed independently against the footage and the owner's overrides. Every one has the mechanics and the overrides essentially right, but the visuals don't read at gameplay zoom yet.
- **Verdicts:** REWORK, visuals only, for Bjorn, Moosh Moosh and Tamsin. PASS WITH FIXES for the other nine.
- The fix lists are in ext/agent-briefs:briefs/kit-review/ and went to the server as a polish pass per pair (Opus).
- **No kitfix branch is ready for you until it passes.** I'll report each pair as it clears.

The reviewers saw these on main too; please check them:
1. In the "before" shots (main), the HUD caption prints twice in the arena or practice view.
2. Status-word toasts overprint each other (STUNNED and GROUNDED read as "GROUNNED"), and a slow shows as "DIZZY" on a swap target.
3. During an air dash near a dummy, the camera ends up inside a pink sphere, possibly the dummy's or a shield's mesh.

## 2026-11-02 18:40 ET: change: ext/uipolish takes the dash_hold removal
The owner also asked for a settings audit and a UI art upgrade ("the 'Boki can use your E ability' option is outdated; UI and settings need work and an art upgrade, along with all boxes"). It's started as **ext/uipolish** (Opus).

Scope:
- An audit of every setting: keep, remove or rename, with a migration that drops removed keys from saved settings.
- Removes `dash_hold`, so please skip my 18:35 request.
- Removes the outdated Boki E option.
- One theme/style system for menus, dialogs, tooltips, cards, panels and controls, shared with ext/hudref's hud_style.gd.

It touches settings.gd, overlay.gd and the ui/ panels (not hud.gd beyond wiring). If a Boki setting lives in a reserved file, it'll be written up for you.

## 2026-11-02 19:55 ET: ext/uipolish ready to merge (c7caef0, on latest main)
- **Settings audit:** see docs/SETTINGS_AUDIT.md.
  - **Removed:** `dash_hold` (the read in match.gd and the long-dash stretch in hunter.gd are gone), `kin_auto` ("Boki also use your E": E is the hunter's and the Boki casts on C; G after your C-into-G merge), and `hud_opacity` (unused). Old settings files drop them on start.
  - **Regrouped tabs:** Gameplay, Controls (with a "How keys behave" group), Camera (new), Audio, Video, Accessibility, Demo. Plain-words hints on rows.
- **Theme:**
  - `UiFrame` and `UiTheme`, one layered box style for every menu box. Hover and press never resize anything.
  - `UI.install()` merges the theme into the default theme; the per-screen `theme = UI.theme()` is deleted in 14 files.
  - `UI.toast` replaces three copies.
  - ui.gd is down ~200 lines.
  - hud.gd's StyleBoxFlats are left for ext/hudref; kin_reveal.gd (reserved) is untouched.
- **Checks:** --uipolish-check (26), --check, level-hud, keybind, hero, gear, economy, polish and bot-sanity pass, and health --strict passes (ratchet improved, nothing raised). +1309/−736 across 39 files.
- **Your follow-up (reserved):** kin_tactics.gd ~line 106 still reads `Settings.get_v("kin_auto")`. It returns null, which equals the old default, so behaviour is unchanged. Please change it to `if slot == "k1" and k.owner_h.is_local(): continue`, and tidy the mentions in the comment at ~89 and in docs/KIN_GRAMMAR.md (~248, 289).
- **Seen on main, before and after:** `--armory-test` logs SCRIPT ERRORs in home.gd `_close_panel` (the hook opens the armory before the home UI exists).

## 2026-11-02 19:40 ET: ext/hudref final 1b729dbb (supersedes the hash in my 19:20 entry)
- Merged sync70. Net 0.17.1: the run level rides at the end of the hunter snapshot, after the kit-move fields. 13 checks pass, health --strict and the style ratchet pass. +1206/−356 across 22 files; hud.gd −377/+19.
- **Plate height per hunter:** `HudPlate.plate_offset(h)` reads `plate_offset` from the archetype JSON (default 2.35).
- **HudStyle API**, for Boki ownership colours and your slots: the colour roles SELF, ALLY, FOE, plus `role_col(viewer, h)`, `slot_frame`, `strip`, `box`, `key_pill`, `GOLD`, `SLOT_RAD`. Details are in docs/HUD.md on the branch.
- **Requests for boki_hud.gd (reserved):**
  1. `form_overhead` draws the merged shell bar on top of the plate name. Move it up about 14 px: shell bar 32–26 px above the anchor, timer 38, label 42.
  2. Slot overlays at lines 172, 191, 195 and 198 use radii 8 and 12; use `HudStyle.SLOT_RAD` or `HudStyle.slot_frame(..., "off")`.
  3. Replace the gold literals with `HudStyle.GOLD`.
  4. `shell_bar` and the chip tags can use `HudStyle.strip` and `HudStyle.box` with `KEY_BG`.
- **Fixes the two main bugs your reviewers saw:** overprinted status words (one CC word now replaces the name, with icon tiles) and the doubled caption in practice. Please confirm the caption once it's merged.

## 2026-11-02 20:00 ET: ext/keys-cover ready to merge (be46e223; supersedes 79e07f5, drop the hold)
On integ72 (36d2c5c0). Net 0.17.3.

**Shrubling:**
- It's a real hiding bush: its tile counts as cover through World.live_bush and in_bush, and you can walk into it.
- No proximity reveal; any hit, root, slow, stun, shove or grab wakes it.
- A hider inside is exposed for 1.2 s, on the owning peer, so this also works on clients.
- Tell: a seeded wobble and shimmer every 5–10 s.

**Bonus chest keys:**
- New file rules/chest_keys.json, on the keys' own stream.
- Odds: boss 40%, elite 25%, monster 3%, pot 2%, barrel 2% (new breakable), crate 4%, sky-train crate 4%.
- Measured surplus over chests: **+22.4%** across 6 seeds (+20.4% to +24.5%).
- --keys-check asserts the 20–30% band and that no chest key appears in any other content table, so none in shops.

**Keys toward the belt (your 17:55 entry):**
- The standalone counter key_counter.gd is deleted; a pickup shows a toast.
- Adapter for the belt: `KeyChest.count(h, kind)`, `KeyChest.take(h, kind, n)`, `KeyChest.cap()`.
- Chest keys cap at 3 and are never auto-discarded: they stay on the ground with a glint, the deathbox keeps the overflow, and bots skip keys when full.
- The Rift Key cap of 1 is left to ext/equal-loadout's belt.

**Perk orbs:** `ChestLoot.perk_hook` now calls `PerkOrbs.drop` (host only).

**Two checks updated for locked chests:**
- perkorb-check gives the hunter a key first.
- lair-lock-check accepts the "ckey" drop.

**Checks:**
- keys-check 83 and cover-check 85 pass, as does perkorb-check 135.
- drop, extract, bot-sanity, lair-lock, level-hud, teammate, boss and hero pass after sync70.
- The rest pass on sync66.
- health --strict and the ratchet are OK.

**Size:** +3847/−463 across 73 files. New files: key_bonus.gd and rules/chest_keys.json.

## 2026-11-02 20:15 ET: ext/perkfollow ready to merge (b73d60eb, on 36d2c5c0, Net 0.18.0)
Your four perkorbs follow-ups from 16:15 ET:
1. Removed "ult" from the thief and juggernaut skill-point order, and dropped the dead `x != "ult"` filter in Hunter._bot_spend.
2. Odd levels now toast "LEVEL n · +1 skill point"; even levels keep the banner.
3. The farmbuild check moved into CheckRegistry. Registry flags now also match `--flag=value`, so `--farmbuild-shots=<dir>` still works.
4. **Late joiners get the live orbs.** There's no join snapshot in the code, so when Net.peers grows, the host re-sends every live orb as `odrop` (receivers skip ids they already have). This avoids resurrecting an orb a client just took. A fan the joiner missed starts fresh for them.

Checks: perkorb 139, farmbuild (through the registry), --check, archetype 192, level-hud, arena 86 and bot-sanity all pass. health --strict and gen_wiki pass. +67/−16 across 12 files, with no new files.

## 2026-11-02 21:30 ET: kit review round 2. No kitfix pair is ready yet (close)
The round-2 reviews of 8 polished hunters are in briefs/kit-review/round2/.
- Pin, Bjorn, Vireo, Linwick and Moosh Moosh pass.
- Venator, Dredge and Tamsin need a small fix each: an opaque slide after-image, ult slugs that can't be seen, and an over-leaning skate pose with a white spear.
- Every branch has some hard-coded key text ("Merge on R", "X"), which is being moved to `Settings.key_cap`.

Fix passes are queued on the server. **pin-bjorn should be ready first; it only needs the one text line.** I'll report each pair as it clears.

Notes for merging:
- The branches each merge cleanly onto main alone but conflict with each other (docs/wiki/Classes.md, shared match/UI scripts), so the order matters. Suggested order: pin-bjorn, linwick-dredge, moosh-tamsin, vireo-venator, then dancer-juggernaut and breah-ostra.
- Three different per-hunter plate-height hooks are being unified onto `HudPlate.plate_offset(h)`.
- Main's arena.gd still shows "X reset", but reset is Backspace.

## 2026-11-02 23:00 ET: FIRST HERO PAIR READY: ext/kitfix-dancer-juggernaut (dcad1777)
Dancer (thief) and Zedran (juggernaut) both **PASS** round-2 review (briefs/kit-review/round2/REVIEW2_dancer.md and REVIEW2_zedran.md).
- **Dancer:** ranged alternating-hand bolts that land at the cursor; bolas with a gold whirl and a lane that grounds the first foe and stuns two; Encore on X; matching size, lean and Cartwheel.
- **Zedran:** a striped chain; a red Searing Wave crescent; an RMB hold with crouch and a lane that turns red then magenta with a full flash, which can be held mid-jump and flings him 4.5–7.5 m; Gilded Riposte on X.
- **Merge notes:**
  - It's 17 commits behind main but merges into it cleanly.
  - `scripts/arch/hero_ult.gd` is byte-identical to linwick-dredge's copy.
  - It conflicts with the other pairs in docs/wiki and in a few shared files: arch.gd, arena_demo.gd, fx.gd, hero_kit.gd, hunter_anim.gd, arch_kit.gd, models.gd and the checks.
  - Its plate hook is `Arch.plate_y`; please converge it on `HudPlate.plate_offset(h)` when hudref lands.
- **Minor nits, to follow later and not blocking:**
  - TANGLED overprints other status words.
  - The bolt and its fizzle are small at game zoom.
  - The blink ghosts are discs.
  - The Encore fill, the slash crescent and the full-lunge flash lean white.
- **Yours, on main:**
  - The "BOND +N%" toast (kin_bond.gd:54) lands on the damage numbers.
  - arena.gd:387 still says "X · RESET".
  - The X ult tile was missing from the ability row in some shots; please check it with the HUD.
  - "Press E again" text across all archetypes: use key_cap too, if you want it consistent.

Since you're short on usage, it might be worth batching this pair with pin-bjorn, which should be ready shortly.

## 2026-11-02 23:15 ET: SECOND HERO PAIR READY: ext/kitfix-pin-bjorn (57507d44)
Pin (archer) and Bjorn (bulwark) passed round 2. The only blocker was hard-coded key text, which is now fixed (no "Merge on R/T/X" anywhere; it uses key_cap). The branch is merged with main b28c593.
- **Pin:** a feathered draw readout that behaves like the source in our own look, a gold flash on a perfect release, cursor-placed shots, Spirit Walk on Shift, and Starpiercer on X (3 piercing beams).
- **Bjorn:** the hammer spins visibly while held, then slams with forward momentum and a flaming crescent. He has a gold shield slab with his sigil, a planted hammer standing upright under a beacon, and Faultline on X.

With dancer-juggernaut (dcad1777), that's **two pairs ready. Please merge them together.**

Next up: vireo-venator, linwick-dredge and moosh-tamsin. The server says their round-2 fixes are done; I'm checking them visually now, about 30–60 minutes. breah-ostra is in its round-2 review.

## 2026-11-03 01:00 ET: ext/breakables ready to merge (61f8772b, on main 6def68a9, Net unchanged)
Owner request: breakables break in one hit, and it's clear when you hit one; explosive barrels too.
- **No HP pools on breakables:** every damage type goes through `Breakables.hit/smash` (scripts/match/breakables.gd). Boki and ability shots can now break things.
- **"barrel" is plain wood; a new "keg" is the explosive one.** In rules/breakables.json, a keg has radius 2.6, damage 22, a 0.45 s fuse with a hiss, ring and swell, and a 0.22 s chain fuse. Bots steer away from lit kegs. On the map, 4 of the 7 authored barrels are now kegs, via make_hollowcrown.py and a regenerated JSON (exactly 4 swapped lines).
- **Pooled effects (break_fx.gd):** debris by material, a flash, the radius ring, a glow, scorch marks. There are 4 new sounds of our own (tools/gen_break_sfx.py).
- **Checks:** --breakables-check (44), keys, cover, check, drop, bot-sanity and boss pass; health --strict is OK. +803/−116 across 31 files.
- **Fixed on main's side as part of this:** tools/uipolish_check.gd had a long_line regression on main (0→1) that failed `health --strict`. It's wrapped here; please keep the fix.

## 2026-11-03 08:00 UTC: READY from S1: ext/airdash-glide 411a591 and ext/mapclean 2082d0d (both on main 801bfbf)
- **airdash-glide:** kit dashes that end in the air hand their speed to the glide like the class dash (hunter.gd _hand_off_ended_dash; GLIDE_HANDOFF_KEEP 0.75, GLIDE_HANDOFF_MIN 3.0). New --airdash-glide-check (all 12 hunters). Full suite 0 failures + --move-feel-check.
- **mapclean (owner item 2):** no isolated 1-2 tile walls. New --wall-size-check (N=3) over training, arena, duel room, tutorial, Hollow Crown x2 seeds; generated maps pruned via new block_prune.gd + 1 line in world.gd; arena pillars -> 2x2; Hollow Crown via the generator (not hand-edited). Note: boki_system_check's landing-test skitter moved 1.3 -> 1.6 m (details in S1 STATUS).
- Merge caution (from the orchestrator check): take ext/kitdata-vireo-venator at 3c1c79a and kitdata-pin-bjorn at 93e9640, NOT their tips: S1 is adding owner-review work there, which will be reported separately.

## 2026-11-03 07:55 UTC: from S1 (server coordinator). READY to merge
- **ext/airdash-glide @ 411a5918:** READY. Kit air dashes hand their speed to the glide, the same as the class dash, through shared code in hunter.gd. Adds the new --airdash-glide-check for all 12 hunters. The full suite, --move-feel-check and --wallmove-check all pass with 0 failures.
- **ext/mapclean @ 2082d0d8:** READY (OWNER_REVIEW #2). Adds the new --wall-size-check (no wall piece under 3 tiles). Generated maps are pruned by block_prune.gd plus one line in world.gd. The arena pillars become 2x2 blocks. Hollow Crown changes go through its generator. One fixture move in boki_system_check. The full suite plus drop, extract and cover checks pass with 0 failures.
- **ext/kitdata-vireo-venator @ ab5fd36d:** READY AT THE TIP. It supersedes 3c1c79a: kit data plus OWNER_REVIEW #1, #4, #9 and #9b, and the Vireo/Venator rows of #32 and #35, all landed whole. It adds a shared content/rules/dash_interactions.json and DashRules. The full suite passes with 0 failures.
- **ext/kitdata-pin-bjorn:** merge @ 93e9640 (kit data) only. The tip is in progress: Pin #5 and #6 plus the Pin rows of #32 and #35, and Bjorn #10, #29 and #30, all owned by S1. A new READY line will follow.
- **Ready, unchanged:** kitdata-linwick-dredge 90c7138, kitdata-moosh-tamsin c6932ae (it adds an optional colour field on the zone "bridge" event without a Net bump; please decide) and kitdata-breah-ostra d0d045e.

## 2026-11-03 08:05 UTC: from S1. ext/kitdata-pin-bjorn READY at the tip
- **ext/kitdata-pin-bjorn @ 7dede8e9: READY AT THE TIP.** This supersedes 93e9640.
  - Contents: the kit data pass, OWNER_REVIEW Pin #5 and #6, Bjorn #10, #29 and #30, and the Pin and Bjorn rows of #32 and #35. Every item landed whole.
  - Checks: the full suite has 0 failures (hero combo 217, archer 119, bulwark 98), and health and gen_wiki are clean.
  - Pin: shots fire only on release, the draw is smooth and the readout sits on the aim line. The Heavy Shot is 3.5x size with a trail, a burst, a kick and a stake.
  - Bjorn: his autos are faster, the aegis pushes, the wall is bigger, and the Faultline now crosses drops. A held LMB ends on mantle, glide, dash, stun and other abilities.
- **Merge note on #32.** The two S1 branches each added a dash-interaction table. ext/kitdata-vireo-venator has content/rules/dash_interactions.json with DashRules; ext/kitdata-pin-bjorn has content/dash_interactions/<id>.json with dash_flow.gd. Both hook Hunter.trigger. Please converge on one when you merge the second branch. I suggest DashRules, with the archer and bulwark rows moved into it. S2's #32 rows should use the same table.

## 2026-11-03 09:35 UTC: from S1. ext/kitdata-vireo-venator READY at the new tip
- **ext/kitdata-vireo-venator @ 67454b5f: READY AT THE TIP.** It supersedes ab5fd36.
  - Built on S2's ext/dash-flow-base 4edc562 plus main integ77.
  - S1's DashRules is gone, and the Vireo/Venator dash rows live in DashFlow.
  - The dash rings stay stripped (S2's dash_with change).
  - Owner items #1, #4, #9 and #9b are included.
- **Checks:** the full suite has 0 failures, with one exception. `--dash-flow-check` fails "bulwark air dash -> lmb, pressed early: lost", and plain dash-flow-base fails the same way. That's S2's to fix in the Bulwark mace's lmb_override path.
- **Merge order:** take dash-flow-base first, then this branch.

## 2026-11-03 16:00 UTC: DEMO MERGE, UPDATED: everything is already re-merged on your main 4d39c623 (physics76) and trial-integrated GREEN
- S2 merged 4d39c623 into every demo branch, fixed the physics76 fallout (Breah's hop retuned for the new gravity), and trial-merged ALL of them together in plan order: every check 0 failures (details: origin/ext/server-status2:STATUS.md "FOR MAIN").
- S2 is now pushing that trial integration as ONE branch, `ext/demo-integ` (main 4d39c623 + dash-flow-base aa37aaf + review-breah-ostra e20c738 + review-linwick-moosh e718d87 + review-dancer 7ae07b9 + review-bjorn c31d4db + prologue-polish a1eecbe + airdash-glide 411a591 + kitdata-vireo-venator 67454b5, + mapclean if clean), with a full suite. **Fastest path: merge ext/demo-integ as soon as it's posted**, then ship the build to the owner's PC. If you'd rather merge branch by branch, use the commits above in that order; the only conflicts are docs/heroes/dash_interactions.md (regenerate with gen_wiki) and one check_registry line (keep both).
- Owner records tonight; he needs the build by ~22:00 UTC at the latest.

## 2026-11-03 16:35 UTC: thanks for taking ext/demo-integ. Two known regressions from mapclean, fix coming
- ext/demo-integ (now in main 31ef8481) includes ext/mapclean, which makes `--base-check` (balloon never arrives) and `--boss-check` (bot reaching Stormcrown Eyrie) fail 3/3; both pass on ext/demo-integ-core (70df4da, everything except mapclean). S1 is fixing it as `ext/mapclean-fix` from 31ef8481, due ~19:30 UTC.
- If it isn't in by your build time and you see either problem in play, revert just the mapclean merge (caf5deb's changes) for the owner's demo build.
- Please post in MAIN_TO_EXT when the owner's PC has the new build.

## 2026-11-03 17:21 UTC (S1): ext/mapclean-fix READY at c36f6ea (fixes --base-check and --boss-check on main 31ef8481)
- It's based on main 31ef8481 and merges cleanly. Two lines in two files:
  1. scripts/match/bot.gd: a bot following a glide route now gives up only when it's 4.0 m under the landing, not 1.2 m. Dipping under the far lip is normal on a climbing gap, and the glider's lift carries it up. At 1.2 m, bots bailed mid-glide and never crossed climbing gaps. That's a real bot bug: in --boss-check the dial bot roamed to island 5 and looped there.
  2. scripts/main.gd _base_check: the mate is set to idle during the 3 s recall. The check measured the landing against a mate that wandered off (2.53 m vs the 2.5 m bar). The bar is unchanged.
- The pruning was not the cause: boss-check fails with block_prune disabled too. Mapclean only shifted bot paths enough to expose these two. block_prune is untouched, and the no-tiny-walls rule holds.
- Checks:
  - --base-check and --boss-check pass 3/3 (agent) plus 1/1 (coordinator rerun).
  - wall-size, drop, extract, cover, balloon, check, arena, bot-sanity, boki-system, move-feel and simtest --seed=5 have 0 failures.
  - obstacle-check has 1 failure, the known one that also fails on main.
  - health OK, wiki unchanged.
- No need to revert mapclean. Merge this instead.

## 2026-11-03 21:00 UTC: READY: ext/farm-hob @ 22b64a74 (P1 onboarding: Hob the builder, the farm tutorial, the Goals tracker)
- Built to DECISIONS.md "Farm and onboarding": Hob Brackenridge by the house (interact to talk; "New blueprints: talk to Hob" toast + mark); starter set house, crop patch, cook pot, ranch pen, fence, dirt path, flowers; the rest spread over levels 2-5 + milestones; B opens on Buildings, locked items hidden, empty tabs hidden, "Talk to Hob for more" footer. House = a site costing 3 wood + 8 swings (Boki build it; player hammer helps). Tutorial, not skippable on a new save: free axe, chop, place house, hammer, give your Boki a job, feed, crop, meet Hob, head out; one 30-gem end reward. "Goals" card replaces the day-1 card (unlock challenges, mastery, milestones, next farm level; max 5 rows). Farm-builder depth stays frozen.
- Contains main sync79 (3569310c). +1890/-432 in 36 files (~300 lines are checks/shots/rules). New files: farm_builder.gd, farm_hob.gd, farm_tutorial.gd, farm_guide.gd, ui/goal_tracker.gd, rules farm_builder.json + farm_tutorial.json, tools/farm_tutorial_check.gd (--farm-tutorial-check), tools/farm_hob_shots.gd, docs/decisions/0011. Deleted: Progress first-day list/card, interior checklist, FarmUnlocks.announce/lock_short, FarmBuildUi.locked_entry, home.gd _day1 hooks. Wiring only in home.gd/main.gd/save.gd.
- Checks: full suite green except --teammate-check, which fails identically on plain main 3569310c (2+2 runs). Save checks (equal, equal-migrate, farmbuild, farm-start, hunter-unlock, --check) 0 failures. health --strict, gen_wiki --check OK.
- **Save version clash at merge:** this takes Save v8, and so does ext/mantle-look (inside ext/warden-models). The farm migration is keyed on its own field (`farm_builder`), so bump either one to v9 and keep both migration steps.
- Known leftover: the Challenge House and Ransom House lots still show "Place it" in the starter menu (they count as owned on a new save); left alone because builder depth is frozen.
- Screenshots (ext-reviewed): /home/claude/shots/farm-hob/ on ext's machine; Hob is a placeholder figure until the art pass.

## 2026-11-03 23:40 UTC (orchestrator): kit audit done; one ONLINE bug for main to know about
- briefs/specs/kit-audit/README.md: an audit of all 12 kits on main 200effce vs the source data/footage/DECISIONS; routed to S2 (INBOX_S2 23:40).
- **Main, please note:** pulls/hooks skip `remote` bodies (ashwick_kit.gd:612, dredge_kit.gd:353-354; match.gd:5843/:5972), so displacement abilities don't move human players online. If the right fix is in match/net code (yours) rather than per kit, say so. It matters now that the game servers are live.
- Also on main: the wiki still has Class-Marlowe.md / Class-Dolm.md and a Tamsin link in Classes.md (regenerate after class-titles).

## 2026-11-04 01:01 UTC (S2): Meshy Vex: pipeline ready, needs the key
- ext/warden-meshy d8bfa90e has a Meshy multi-image client and docs/art/wardens/PIPELINE.md, which includes the terms check. Paid plans own their output; opting out of Meshy training is the owner's call.
- **Owner:** to start, put MESHY_API_KEY in /home/boki/.config/boki/secrets.env (chmod 600) on the S2 box, or paste it into the S2 session. S2 starts the Vex run the moment it's there.

## 2026-11-04 02:00 UTC: owner films the demo video tomorrow; art first
- The owner moved the recording to tomorrow so the new art can be in it. S2 is told to put everything on the Meshy Wardens, then the Boki, landing Wardens as they pass. Please merge passing Wardens in batches through the day and keep tonight's installed build as the fallback for the video.

## 2026-11-04 04:04 UTC (S2): READY ext/kits-integ 5e551f8c (main 03:15 ask)
- **Base:** origin/main 91a6bd05. git merge-tree says it merges cleanly with main c00feadf.
- **Merges** (one --no-ff each): no-shake, online-displace, audit-zed-dredge-cinder, audit-pin-vireo-tarek, audit-bjorn, audit-ostra-claire-moosh, vex-ammo (which includes audit-sable-vex).
- **Fix commit:** weapon_path.json listed Deep Magazine for heroes with no ammo; they now get Hot Load. Without it, perkorb fails 5.
- **Resolutions:**
  - Every audit and parity change is kept, and moves of other bodies go through Displace.
  - Main's newer self-shakes are removed: DropFeel landing, the thief reset and the archer full draw. No add_trauma, cam.punch or Feel.shake calls remain outside the reserved files.
  - StaminaBar.long_cd carries the long-dash change from the deleted dash_strip.
  - The wiki keeps Class-Icy-Dancer and is regenerated.
  - No style baseline or health budget raised.
- **Checks:**
  - All 12 combo checks 0, hero-combo 263/0, archetype 339/0, dash-flow 0, displace-net 34/0, shake 0, perkorb 134/0, aimkit, gear, keys, uipolish, support, zone, arena: all 0.
  - S2 re-ran shake, displace-net, perkorb, gunslinger, rimewright and hero-combo, plus health --strict: all OK.
- **Full suite:**
  - Only known reds.
  - Pre-existing on main c00feadf: drop-feel (a SCRIPT ERROR, `_tut_drive` missing in drop_check.gd) and teammate 1.
  - The portrait "new names" assert is fixed on ext/rename-burple.
- **Main still has to do:**
  - The Net.VERSION bump: new ["disp"] events, ["zone","tp"] removed, and a 14th field on hit messages.
  - The reserved-file one-liners: the displace list in DEBT.md, plus the no-shake ones (merge_kit 159/161, merge_xform 42/44/79/177, kin_exec 424, kin_strike 20).
  - The R key (step 5).
  - docs/wiki/Classes.md line 7 still says "Tamsin".
- **Supersedes** merging the seven branches separately.

## 2026-11-04 04:10 UTC: READY: ext/farm-hob @ 8e82638f (round 2: all of your 00:25 and 00:45 owner items), replaces the 22b64a74 report
- Contains main sync83 ca4305c1. Diff vs main: 41 files, +2387/-351 (rounds 1+2).
- Round 2: the Challenge House is no longer granted (home.gd auto-grant removed). Hob draws it after the first expedition (`first_run` milestone); it's a Buildings lot at 6 wood + 4 stone. Existing saves keep theirs; the Black Market is untouched. Crops by water: new FarmWater means a patch within 2 tiles of any water waters its own plots (tooltip, prompt, panel say so; the farmhand skips them); the build preview shows "Near water: waters itself" in green. River brush (Paths tab, 2 gems a tile, counts as water). Tutorial now has 12 steps in Hob's voice: + mine a rock (free pickaxe), buy a seed (Seeds tab; gems topped up to one seed), sell a crop (Sell tab; where gems come from). The crop step points at water; the house first, the rest in any order; the hint wraps at ~600 px clear of Goals.
- **Save:** VERSION 10 per your numbering. 8->9 is an empty placeholder for mantle-look; 9->10 is FarmBuilder.migrate, keyed on its own `farm_builder` field. market_check loosened from == 8 to >= 8.
- Checks: --farm-tutorial-check (extended), farmbuild, farm-start, equal, equal-migrate, hunter-unlock, --check, market: 0 failures. Full suite: all pass except --teammate-check. health --strict, gen_wiki --check OK.
- **--teammate-check is red ON MAIN too (ca4305c1):** "rival behind you" and "leads you to the chest and the outpost" fail in 5/5 main runs; "a hint in its own voice for each step" in 4/5 (it needs 6 tut_* hints and gets 5 or 6 depending on whether tut_goexit is spoken before the sim ends: nondeterministic, tools/teammate_check.gd:380). Ext proved the farm branch can't reach it (no scripts/match diff; teammate_check never builds a Home). Worth a fix on your side.
- Screenshots (ext reviewed): /home/claude/shots/farm-hob2/ on ext's machine (Challenge House in the menu, near-water preview, river channel, market and sell steps).
- Next from ext: the build/decorate UI revamp (your 00:35 entry), starting now on ext/build-ui from this branch.

## 2026-11-04 04:33 UTC (S2): READY ext/rename-ryzz 14242204 (Vireo -> Ryzz; also contains rename-burple)
- **Base:** ext/rename-burple 6d9fd821 with origin/main merged in. Merge this one branch to get both renames. It merges cleanly with main.
- **Changes:** the display name (mage.json base_name "Ryzz"), kit and rules text, docs, the wiki (filenames kept) and comments; the portrait-check new-names assert now includes Ryzz. The id `mage` is unchanged.
- **Checks (S2 re-ran):** hero-title 0, portrait 107/0, mage-combo 92/0, archetype 307/0, health --strict OK, style OK.
- **Left as is:** docs/decisions/0010 still names Vireo (a historic record). portrait_art.gd keeps the art names "vireo"/"moosh" until round-2 ryzz_*/burple_* art files exist.

## 2026-11-04 06:03 UTC (S2): READY ext/rename-breaker 038a76b3: now also Burple -> Pip (owner 06:50)
- **What changed:** tender's display name is now Pip. "Burple" joins "Moosh Moosh" in --hero-title-check's old names. Docs, the wiki, comments and check labels are swept. The id `tender` is unchanged.
- **One branch for all renames:** this branch now carries Pip, Ryzz and Breaker. Merge only it; it supersedes ext/rename-burple and ext/rename-ryzz.
- **Checks (S2):** hero-title 0, portrait 107/0, tender-combo 72/0, support 140/0, health --strict OK, style OK.

## 2026-11-04 07:46 UTC (S2): READY ext/arena-sign 245f904c (from main)
- The arena's start sign said "X · RESET". It now says "BACKSPACE · RESET": reset is Backspace, and X is Fuse. The change is one line in arena.gd.
- arena-check 86/0, health OK, style OK.

## 2026-11-04 07:59 UTC (S2): READY ext/rename-breaker 93b2ab27, which now also renames Pin -> Hem (owner 08:45)
- **Hem:** archer's display name is now Hem. "Pin" was already in --hero-title-check's old names. Kit text, docs, the wiki and comments are swept; "pin" as a verb (pin a Boki, pin a note, wall pin) is untouched. The id `archer` is unchanged.
- **One merge for every rename:** this branch now carries Pip, Ryzz, Breaker and Hem.
- **Checks (S2):** hero-title 0, portrait 107/0, archer-combo 126/0, archetype 307/0, class-unlock 149/0, hero 0, health OK, style OK.

## 2026-11-04 08:43 UTC (S2): ext/rename-breaker 07ef436b now also has the new titles
- Hem: Dark Archer -> **Red Stitch**. Dredge: Broken Abomination -> **Brass Abomination**. Tarek: Rock Elementalist -> **Cliff Runner**.
- The wiki pages are renamed to match (Class-Red-Stitch.md and the others), and gen_wiki reports no changes.
- **Checks (S2):** hero-title 0, portrait 107/0, archetype 307/0, class-unlock 149/0, hero 0, dredge-combo 86/0, dolm-combo 130/0, archer-combo 126/0, health OK, style OK.
- One merge still gets every rename and title: Pip, Ryzz, Breaker, Hem and the three titles.

## 2026-11-04 09:19 UTC (S2): READY ext/rename-breaker 72b79ec0: now also Zedran -> Kael and 4 titles (09:30)
- **Kael:** juggernaut's display name is now Kael. "Zedran" was already in the old names.
- **Titles:** Kael "The Unbroken", Claire "Frost Siren", Pip "Little Lantern", Ryzz "Storm Chaser". The wiki pages are renamed to match.
- **"The" fix:** the label code now drops a leading "The", so it reads "Orri the Unbroken", never "Orri the The Unbroken". hero-title-check asserts this.
- **Checks (S2):** hero-title 0, portrait 107/0, archetype 307/0, class-unlock 149/0, hero 0, juggernaut-combo 135/0, title 0, health OK, style OK.
- **One merge** gets every rename and title: Pip, Ryzz, Breaker, Hem, Kael, plus the 7 titles.

## 2026-11-04 13:12 UTC (S2): Dredge READY updated to ext/warden-dredge-friend 86ca5691 (r3e)
- **Score:** about 81% at close-up and about 74% at match zoom.
- **Changes:** tar runs that follow the hull down and drip off it; a raised back hatch and a stand-off pipe; 8 wider lens cracks; warm highlights on the brass.
- **Checks:** all pass.
- **Shots:** in warden-3d/dredge/r3e_*.
- **Next:** credit-free work has hit diminishing returns. The next real gain is a Meshy hull, once the S2 permission is allowed.

## 2026-11-04 13:52 UTC (S2): Ryzz READY updated to ext/warden-3d-ryzz 40c9a5a1 (round 5)
- **Score:** about 83% close-up, about 68% at match zoom. All checks pass.
- **ORCH's 13:10 list is done:**
  - the pink glow only on the scar, charm and keyhole piping (the magenta smears are gone);
  - two-tier pigtails ending in thick S-curl zigzag ends;
  - the relic seated in the V on her back, with copper rods;
  - a gum bubble;
  - the keyhole piping on its edge;
  - charcoal-plum leather with copper zips and pink trim;
  - the shared match-zoom fix with an electric-blue rim.
- **Shots:** warden-3d/ryzz/s5_*.

## 2026-11-04 13:56 UTC (S2): Dredge READY updated to ext/warden-dredge-friend 8e776599 (r3f)
- **Score:** about 85% close-up, about 76% at match zoom. All checks pass.
- **ORCH's r3d list is done:** the spider glyph is gone (a lens dome over a red recess, with hairline cracks); a riveted brass porthole rim plus the small grilled port; tarnished brass with rust streaks; a thinner crimson ooze; the helm lifted so the eye faces the camera; and match zoom ported with a brass rim and glowing tears.
- **Shots:** warden-3d/dredge/r3f_*.

## 2026-11-04 13:59 UTC (S2): READY (for the art integ) ext/warden-3d-sable 76cc4af8: Sable 3D, round 5
- **Score (RECIPE_95 rubric):** about 86% at close-up and about 68% at match zoom. That's under 95%, but clearly better than the procedural model, so it ships per 13:15 and keeps improving.
- **What changed (ORCH's 13:10 list):**
  - one silver-white braid over the right shoulder;
  - the collar is grey-lilac, and its back is now purple;
  - the crossbows are 1.4x, with wooden grips and violet glowing tips;
  - a pendant halo;
  - an upright wide stance;
  - pearly wings hanging to mid-calf;
  - the recipe merged (look fix and match-zoom fix), with a violet rim.
- **Checks:** all pass. dancer-combo 92/0.
- **Shots:** warden-3d/sable/s5_*.
- **Still differs:**
  - a cheek and jaw smear at 3/4;
  - at match zoom she still speckles, and the bolt tips and pendant barely show.

## 2026-11-04 13:59 UTC (S2): READY (for the art integ) ext/warden-3d-hem c403a328: Hem 3D, round 4
- **Score (rubric):** about 83% at close-up and about 74% at match zoom. Ships per 13:15, and keeps improving.
- **What's in it:**
  - a true black recurve with a bright glowing red string and a spool, angled at her left side;
  - dark iron quiver needles with red threads;
  - the art's red coat, lengthened to mid-calf;
  - a smooth porcelain mask with stitches and a gold rim;
  - rebuilt thimble claws;
  - a red match-zoom rim;
  - RECIPE_95 merged.
- **Checks:** all pass (archer-combo 119/0). The width lower bound in warden-model is lowered to 0.5, because her art is slim.
- **Shots:** warden-3d/hem/s4_*.
- **Still differs:**
  - the bow is thin at match zoom;
  - small red smears on the mask at 3/4;
  - sleeve blotches;
  - the coat hem isn't flared.

## 2026-11-04 14:00 UTC (S2): READY (for the art integ) ext/warden-vex-r3b 8be127d9: Vex 3D r3d, the golden recipe
- **Score (rubric):** about 88% at close-up and about 88% at match zoom.
- **ORCH 12:55 items, all done:**
  - warm skin;
  - the cannon in gunmetal grey with brass bands;
  - the darks lifted;
  - the backpack painted from the art, with 4 thick ribbed hoses to the gun;
  - jade hair.
- **r3d face pass:** a 15-landmark warp from the face sheet, no jaw seam, a bladed-iris lens with a match-zoom halo, and the straps cleaned.
- **Checks (agent-run):** warden-glb 20/20, warden-model 34/34, mantle-look, move-feel, gunslinger-combo 67/67, weapon-clip, warden-stance, health and style all pass.
- **Branch:** this is also the base of every Hunter branch: RECIPE_95, the shared look fix 16c18b4f and the match-zoom fix f4b59cb3.
- **Shots:** warden-3d/vex/r3d_*.
- **Still differs:** the eye plate is round, not angular; the hoses are smaller than the art's loops; the trousers and boots are darker; a few chest smudges.

## 2026-11-04 14:02 UTC (S2): READY (for the art integ) ext/warden-3d-tarek f6d74ffd: Tarek 3D, round 6
- **Score (rubric):** about 79% close-up, about 67% at match zoom. Ships per 13:15 and keeps improving.
- **What's in it:**
  - warm deep-brown matte skin (the albedo now composes with the player's skin pick);
  - a slate vest;
  - brighter bracer cracks;
  - seeing-stones orbiting closer, with bigger glowing irises;
  - amber beads in the locs;
  - rock shards orbiting his raised right fist;
  - a slimmer upper body;
  - an amber rim;
  - RECIPE_95 merged.
- **Checks:** all pass (dolm-combo 118/0).
- **Shots:** warden-3d/tarek/s6_*.
- **Still differs:** his fists are closed and fused into the scan; fixing that needs the Meshy run, which the S2 session permission check refused. The gauntlets aren't rebuilt.

## 2026-11-04 14:14 UTC (S2): Ryzz READY updated to ext/warden-3d-ryzz c3b43742 (round 6)
- **Score:** about 84% close-up, about 70% at match zoom. All checks pass.
- **Changes:**
  - match zoom lifted;
  - a smaller gum bubble with no ink outline;
  - the corset glow kept to the piping only;
  - darker fishnets.
- **Shots:** warden-3d/ryzz/s6_*.

## 2026-11-04 14:44 UTC (S2): Hem READY updated to ext/warden-3d-hem 45d859ae (round 5)
- **Score (scored the way ORCH does):** about 85% close-up, about 68% at match zoom. All checks pass.
- **Covers ORCH 14:10:**
  - the face painted with an 18-landmark warp;
  - a deep crimson coat over black, with a split back tail;
  - silver needles with drooping red thread;
  - shears and a lapel needle;
  - a thicker bow with a 12 mm glowing string;
  - less highlight noise at match zoom.
- **Shots:** warden-3d/hem/s5_*.

## 2026-11-04 14:48 UTC (S2): Dredge READY updated to ext/warden-dredge-friend b9daa472 (r3g)
- **Score:** about 82% close-up, about 62% at match zoom. All checks pass.
- **ORCH r3f review covered:**
  - tarnished bronze with rivet rows;
  - a smaller glassy cracked eye;
  - helm drips;
  - a smoother hull;
  - an upright stance with the hull on top;
  - a brass grille.
- **New:** `--arena-demo=pose_clear`, which hides the arena sign and moves the hero off the spawn fern for clean review frames.
- **Shots:** warden-3d/dredge/r3g_*.

## 2026-11-04 14:49 UTC (S2): Sable READY updated to ext/warden-3d-sable 4d1f9221 (round 6)
- **Score:** about 87% close-up, about 64% at match zoom. All checks pass.
- **ORCH 14:10 items covered:**
  - face via an 18-landmark warp;
  - hand crossbows with glowing violet bolts;
  - a blooming pendant gem;
  - wide moth wings;
  - lilac-grey shadows and collar;
  - the laced back.
- **Shots:** warden-3d/sable/s6_*.

## 2026-11-04 14:52 UTC (S2): Tarek READY updated to ext/warden-3d-tarek d74e304e (round 7)
- **Score:** about 80% close-up, about 64% at match zoom. All checks pass.
- **What changed:**
  - scripted elbow-to-knuckle stone gauntlets with a glowing core;
  - the stones orbit above and beside his head, clear of the face, with amber halos;
  - a slate vest;
  - normal legs and a wider stance.
- **Shots:** warden-3d/tarek/s7_*.
- **Still blocked:** open hands and longer locs need the Meshy run, which is waiting on permission in the S2 session.

## 2026-11-04 14:55 UTC (S2): READY (for the art integ) ext/warden-3d-breaker 7e5f1bc1: Breaker 3D, round 3
- **Score (rubric):** about 81% close-up, about 69% at match zoom. Ships per 13:15 and keeps improving.
- **What it has:**
  - a new Meshy body from breaker_front: bare blue belly with frost cracks and barnacles, rope sash, ragged skirt, bare feet, beard braids with rings, kelp, teddy and compass;
  - the hammer haft back over his RIGHT shoulder;
  - the sheet shield in relief at his LEFT hip;
  - 1.5x scale with the hitbox unchanged;
  - RECIPE_95 plus both shared fixes, and an ice-blue rim.
- **Checks:** all pass (bulwark-combo 102/0).
- **Shots:** warden-3d/breaker/s3_*.
- **Still differs:**
  - the beard reads as one red mass, not three braids;
  - the skin is grey at distance;
  - ragged edges on the skirt and mantle.

## 2026-11-04 15:02 UTC (S2): Ryzz READY updated to ext/warden-3d-ryzz ea64914a (round 7)
- **Score:** about 85% close-up, about 72% at match zoom. All checks pass.
- **ORCH 14:10 covered:**
  - gum at the lip corner;
  - pigtails mid-blue at distance;
  - rounder curls;
  - pink-peach skin;
  - plum-grey jacket;
  - muted copper rods;
  - striped hazard sleeves as geometry;
  - 1.04x scale (the sheet height in warden-model-check moved from 1.0 to 1.04, hit radius unchanged).
- **Shots:** warden-3d/ryzz/s7_*, including s7_match_clean_vs_art.

## 2026-11-04 15:02 UTC (S2): Vex READY updated to ext/warden-vex-r3b 047f8724 (r3e)
- **Score:** about 79% close-up, about 78% at match zoom (was 82/68 by ORCH on r3d).
- **What changed:**
  - She reads black and green at match zoom, using a new shared-shader uniform light_neutral_warm (default 0).
  - Aged bronze.
  - The lens is drawn from the face sheet.
  - Solid jade braids with copper ties.
  - Gunmetal barrels.
  - Hose loops.
  - Clean match frames via the new --demo-at and --no-tips.
- **Checks:** all 9 pass.
- **Shots:** warden-3d/vex/r3e_*.
- **Still to do:** the gorget, the ammo-belt cartridges, the crop-top trim smears, the lens cone.

## 2026-11-04 15:03 UTC (S2): READY (for the art integ) ext/warden-3d-ostra-b 814601b2: Ostra 3D, b9
- **Score (rubric):** about 84% close-up, about 80% at match zoom.
- **What changed:**
  - a black-core vortex orb with violet spiral arms;
  - long claws;
  - mask glow kept inside the porcelain;
  - jagged halo cracks;
  - black and violet coat panels;
  - the arm-to-coat sheet cut away;
  - an S-curling wisp;
  - a violet rim;
  - the primed tell is a small violet mark, no longer a blue disc.
- **Checks:** all pass (ostra-combo 128/0).
- **Shots:** warden-3d/ostra/b9_*.

## 2026-11-04 15:18 UTC (S2): READY (for the art integ) ext/warden-3d-claire-b cdf23bfa: Claire 3D, b2
- **Score (rubric):** about 76% close-up, about 60% at match zoom. Ships per 13:15 and keeps improving.
- **What changed:**
  - skates with ice blades on the ground (the ankle was fixed);
  - scripted ram-curl horns going back and down;
  - the face touched up (softer blush, bigger glowing eyes);
  - wider wings, both visible from the front;
  - a spade S-tail;
  - a crystal spear;
  - the left hand raised;
  - geometry pigtails with ice ties;
  - light_neutral_warm on the ice.
- **Checks:** all pass (rimewright-combo 68/0, feet-forward assert).
- **Shots:** warden-3d/claire/b2_*.

## 2026-11-04 15:22 UTC (S2): Ryzz READY updated to ext/warden-3d-ryzz 6ee886f7 (round 8)
- **Score:** about 86% close-up, about 72% at match zoom. All checks pass.
- **What changed:** a flat pink corset with piping only, airier pigtails, plum leather, light_neutral_warm, and a clean match frame.
- **Shots:** warden-3d/ryzz/s8_*.

## 2026-11-04 15:24 UTC (S2): READY (for the art integ) ext/warden-3d-cinder d6cae305: Cinder 3D, b3
- **Score (rubric):** about 76% close-up, about 62% at match zoom. Ships per 13:15 and keeps improving.
- **What changed:**
  - a Meshy body from the r3 art: short, round, feminine face with amber slit eyes and the toothy grin painted from the head sheet;
  - a fin-crest with an orange edge;
  - brass goggles;
  - the flamethrower lance with a glowing chamber, held in her LEFT hand at idle via a new free_r carry key (the rig fires two-handed);
  - a copper hose;
  - a spring tail;
  - glowing vials.
- **Checks:** all pass (ashwick-combo 86/0).
- **Credits:** 250.
- **Shots:** warden-3d/cinder/b3_*.
- **Still differs:**
  - the crest is hidden from the front;
  - she reads dark at match zoom;
  - the tail isn't looped.

## 2026-11-04 15:35 UTC (S2): READY (for the art integ) ext/warden-3d-kael 4b128481: Kael 3D, b9
- **Score (rubric):** about 74% close-up, about 71% at match zoom. Ships per 13:15 and keeps improving.
- **What changed:**
  - dark mauve-brown skin with light_neutral_warm;
  - a silver-white Meshy mane kept off the face;
  - a broken iron blade with chain rows and a white-hot core, trimmed;
  - a gold shard collar on the scarf;
  - the sword point-down;
  - a gold rim;
  - white-hot model_glow.
- **Checks:** all pass (juggernaut-combo 135/0).
- **Shots:** warden-3d/kael/b9_*.
- **Still differs:**
  - the mane is stringy;
  - the arm cracks are blotchy at the shoulder;
  - the scan's shoulders are oversized.

## 2026-11-04 15:36 UTC (S2): Dredge READY updated to ext/warden-dredge-friend 05596f3f (r3h)
- **Score:** about 83% close-up, about 57% at match zoom. All checks pass.
- **What changed:** no white spec, smoother lames, a cracked hot-core eye, tarnished bronze with seams, and rivet rows.
- **Shots:** warden-3d/dredge/r3h_*.

## 2026-11-04 15:39 UTC (S2): Hem READY updated to ext/warden-3d-hem d77613ca (round 6)
- **Score:** about 86% close-up, about 66% at match zoom. All checks pass.
- **What changed:**
  - the stray foot block is gone, and the boots are proper;
  - one straight coat tail;
  - drooping red threads;
  - a clean mask;
  - steel thimbles;
  - tape wraps;
  - a black bow with string halos;
  - halos now built after the weapon is seated.
- **Shots:** warden-3d/hem/s6_*.

## 2026-11-04 15:43 UTC (S2): Tarek READY updated to ext/warden-3d-tarek 303282c5 (round 9)
- **Score:** about 84% close-up, about 62% at match zoom. All checks pass.
- **What changed:**
  - warm mid-brown skin, using a new default-off per-slot `desat` uniform;
  - chunkier gauntlet plates;
  - deeper stones;
  - bigger amber halos;
  - a clean match frame.
- **Shots:** warden-3d/tarek/s9_*.

## 2026-11-04 15:57 UTC (S2): Ostra READY updated to ext/warden-3d-ostra-b 1a2381a9 (b10)
- **Score:** about 86% close-up and about 84% at match zoom (agent self-score on the x4 crop; ORCH's b9 read was stricter). All checks pass.
- **ORCH b9 items covered:**
  - the ruff reads grey under light_neutral_warm, with a violet aura and rim;
  - the halo is violet, larger than the head and centred;
  - glowing mask marks: tear, crack and eye pinpoints;
  - the cut spike is gone (arm_reach binarize);
  - a forward lean;
  - an S-curve smoky wisp;
  - cards kept clear of the cap;
  - longer claws.
- **Shots:** warden-3d/ostra/b10_*.

## 2026-11-04 16:06 UTC (S2): Tarek READY updated to ext/warden-3d-tarek 983adc10 (round 10)
- **Score:** about 85% close-up, about 62% at match zoom. All checks pass.
- **What changed:** the gauntlet glow is orange, not yellow; a narrower stance; the sheet height in warden-model-check is now 1.19x.
- **Shots:** warden-3d/tarek/s10_*.

## 2026-11-04 16:11 UTC (S2): Sable READY updated to ext/warden-3d-sable 5d6c8122 (round 7)
- **Score:** about 88% close-up, about 68% at match zoom. All checks pass.
- **What changed:**
  - crossbows angled down by the thighs, with violet bolt glow;
  - ink opt-out tags;
  - the braid down the back with silver rings;
  - a grey-lilac collar;
  - the cream cast removed.
- **Shots:** warden-3d/sable/s7_*.

## 2026-11-04 16:24 UTC (S2): READY (for the art integ) ext/warden-3d-pip-b b1a770fa: Pip 3D, b7. That makes ALL 12 READY
- **Score (rubric):** about 89% close-up, about 86% at match zoom.
- **What she has:**
  - rose fur with a cream belly;
  - a 26-flower ring on the goggle strap;
  - chubbier limbs and a bigger head;
  - a geometry cape;
  - an amber lantern in her left paw with a warm halo and a local light;
  - wider glowing wings;
  - her own ink settings (no black specks).
- **Checks:** all pass (tender-combo 72/0). No credits.
- **Shots:** warden-3d/pip/b7_*.
- **All 12 Hunters now have a READY commit.** ext/art-integ (S2 agent, on main) is merging them plus the match-zoom fix; it posts READY when its full suite is done.

## 2026-11-04 16:34 UTC (S2): Tarek READY updated to ext/warden-3d-tarek 85d6039d (round 11)
- **Score:** about 86% close-up, about 62% at match zoom (before the shared match-zoom fix). All checks pass.
- **ORCH 16:10:** chunky rock-slab gauntlets with thin orange cracks; the geode openings and amber eyes are now visible on the stones.
- **Shots:** warden-3d/tarek/s11_*.

## 2026-11-04 16:36 UTC (S2): READY updates: Breaker 1f050418 (s4, ~85/80), Vex f02bb08e (r3f, ~82/85)
- **Breaker:**
  - three frozen beard braids as geometry;
  - no beard on the neck;
  - blue skin at distance;
  - the shield at his left hip;
  - a clean frame.
- **Vex:**
  - the lens on a smooth dome;
  - bronze cartridges;
  - a bronze slot that reads at distance;
  - solid braids;
  - toxic-green hair at match zoom;
  - the gun-side jacket black.
- **Shared match-zoom fix:** both branches carry v1 (f0ad9f60). They switch to v2 (ext/warden-matchzoom-v2 161708cc) next round. **Main:** the art integ uses v2.

## 2026-11-04 16:50 UTC (S2): Pip READY updated to ext/warden-3d-pip-b 8b79969d (b10)
- **Score:** about 90% close-up, about 89% at match zoom. All checks pass.
- **What changed:**
  - the cape sits outside her back;
  - 34 flowers;
  - match-zoom v2.
- **Shots:** warden-3d/pip/b10_*.
- **Also:** match-zoom v2 gained **8af89a9e**, a null-safe ink_mask fix. Pick it after 161708cc.

## 2026-11-04 16:59 UTC (S2): Cinder READY updated to ext/warden-3d-cinder d522f924 (b4)
- **Score:** about 80% close-up, about 68% at match zoom (b3 was 76/62). All checks pass. Match-zoom v2 is included.
- **ORCH 16:10 covered:**
  - a geometry fin-crest with a glowing edge, running down the dorsal and onto the tail fin;
  - a brass-and-glass lance chamber with a flame core and a looped copper hose;
  - bigger glowing vials;
  - the cracked goggle lens;
  - a wider grin;
  - a looped tail.
- **Shots:** warden-3d/cinder/b4_*.

## 2026-11-04 17:10 UTC: READY: ext/build-ui-polish @ f6828086 (small: fixes the build UI overlap)
- Removes the button strip above the catalog (it duplicated the cursor card and drew under it). The cursor card is now the one place for action keys; it and the piece menu flip near screen edges and never overlap the catalog bar, the top HUD band or the Goals card (new clamp case in --build-ui-check). "Hold Shift to place more" moves to the bar's hint line; Move/Store becomes one "Store" toggle left of Undo/Done (search box 130 -> 72 px). Same in house decorate mode.
- 8 files, +142/-86, no new files. Based on main d365cea8 (merges clean onto newer main expected; build UI files only). --build-ui-check, --farmbuild, --farm-tutorial-check, --home-build-check exit 0; health --strict OK; gen_wiki --check OK (also regenerates the stale docs/wiki/Rules.md line that made gen_wiki --check red on plain main).
- Shots (ext reviewed): /home/claude/shots/build-ui-polish/ on ext's machine, incl. edge cases.

## 2026-11-04 17:04 UTC (S2): Dredge READY updated to ext/warden-dredge-friend 4f60ba6f (r3i + match-zoom v2 port)
- **Score:** about 83% close-up, about 62% at match zoom. All checks pass.
- **What changed:** a small orb in a wide brass ring, the shards gone, shoulder ball joints, the horn seated, and match-zoom v2 ported.
- **Shots:** warden-3d/dredge/r3i_*.

## 2026-11-04 17:15 UTC (ORCH): [MAIN] hold Dredge r3i
- ORCH review: Dredge r3i (READY update 17:04) lost his arms and legs (they render invisible). Ship ext/art-integ with Dredge at r3h (ext/warden-dredge-friend 05596f3f), not r3i, unless S2 posts a fix first.

## 2026-11-04 17:07 UTC (S2): Tarek READY updated to ext/warden-3d-tarek 940b8aee (round 12, match-zoom v2)
- **Score:** about 86% close-up, about 70% at match zoom (was 62).
- **Checks:** all pass.
- **Shots:** warden-3d/tarek/s12_*.

## 2026-11-04 17:08 UTC (S2): Ostra READY updated to ext/warden-3d-ostra-b bc16c044 (b11, match-zoom v2)
- **Score (native size):** about 85% close-up, about 55% at match zoom. The earlier 80+ match scores were read off x4 crops.
- **What changed:**
  - a bigger 4-arm vortex orb visible from every side;
  - violet cards with glow halos;
  - a single cracked crescent halo;
  - brighter mask marks;
  - an S-hook wisp;
  - "Orb" added to FLOATING in warden-model-check.
- **Shots:** warden-3d/ostra/b11_*.

## 2026-11-04 17:11 UTC (S2): Dredge r3i regression: integ holds r3h; Breaker READY -> 558612f3
- **Dredge:** r3i (4f60ba6f) lost his limbs (ORCH 17:15). ext/art-integ keeps Dredge at **r3h 05596f3f** until a fixed r3j is posted. His agent is on it.
- **Breaker s5 (558612f3):** about 86% close-up, about 82% at match zoom. Kelp and icicles added as geometry, the compass visible, a lighter shield, match-zoom v2. All checks pass.

## 2026-11-04 S2: Dredge limb loss, cause found (r3h is affected too)
- The cause is decimation, not match-zoom v2. When the new hull went in, the friend's body was decimated to the leftover budget: 3,650 tris in r3h, 2,900 in r3i. That collapsed the limb rods, the claw fingers, the rope and the hook inside the .glb itself (confirmed by a Blender render with no game shaders). Evidence: warden-3d/dredge/r3j_dredge_cause.png (pushed with the r3j shots).
- r3h (05596f3f) is missing most of the rods too. The integ keeps it only as a placeholder.
- The r3j fix decimates each part on its own: the rods, claw, rope and hook keep 0.32, the boots 0.12 and the winch 0.25. Leftover shards are dropped. It also covers the ORCH 17:10 items: smaller shoulder pods, warm gold brass with a bright gold far rim, and a smaller, darker tar pool. The checks are running; READY follows when they pass.

## READY rigfix 0fe7a84e (RIGFIX, 2026-11-04)
Branch origin/rigfix (on integ91). Contact sheets (before left, after right; match zoom on top, close below; tiles: idle, walk, run, hit, dash and kit moves): briefs/rigfix/<hunter>_before_after.jpg.
- Rig standard locked: docs/RIG_STANDARD.md; new `--rig-standard-check` (all 12: armature, attachments, rest pose, weapon seated and in the hand in every state); `--rig-shots` makes the sheets.
- Fixes: weapon now follows the hand when the arm can't reach the grip (Kael's slam/lunge/dash, Vex's flip dash: up to 0.55 m off before); Breaker's hammer scale 0.75 (was oversized); Hem's bow seated (new warden_look `weapon_offset`); `--warden-model-check` heights updated to Kael 1.06 / Ostra 0.9; `--hero-combo-check` Hem Heavy Shot rows follow the red x6 arrow with the core hidden.
- NOT fixed: Tarek's leg/trouser deformation in deep crouches (leap, slam) needs a skin-weight rebuild through the Meshy/Blender fit pipeline, which I did not run; the sole-on-ground audit was visual only (no reliable numeric measure for skinned meshes).
- Checks: --import, --check, --warden-model-check, --warden-glb-check, --hero-combo-check, --hitbox-size-check, --warden-stance-check, --rig-standard-check, health --strict, gen_wiki --check all pass.

## 2026-11-05 (S4): trial merge of all four: `ext/s4-integ` @ 244b216d (main fe51b43b + 98 + 99 + 101 + 105)
- Real conflicts were only tools/style_baseline.json (101, 105; regenerated with style_lint --update after the merge) and docs/DEBT.md (105; both entries kept). hud.gd / match.gd merged cleanly (my earlier "expect a conflict" note was wrong).
- On the combined tree, all 0 failures: --check, --rank-ui-check, --loot-full-check, --box-revive-check, --boki-lines-check (26), --revive-check PASS, --backpack-check; health --strict OK; gen_wiki --check unchanged. 62 files +4513/-382.
- Main can fast-forward its integration from this branch, then do 105's reserved-file wiring. Not run here: the full suite.

## 2026-11-05 (S4): hash update (only the shots tools' missing .uid files added)
- `ext/rank-ui-98` @ bd04d5d2 (was d66e1383), `ext/loot-full-99` @ 127ecfc8 (was f484773e), `ext/s4-integ` @ bfb12fa7 (was 244b216d). No code changes.

## 2026-11-05 05:22 UTC (S5): ext/kit-hem-55b 8b2c04f1 held: new mid-play shader compiles in --hitch-check (S2, please fix)
- --hitch-check is red on main in this headless/xvfb box, but its compile list is stable: 4 "compiled N shader variant(s) during ride" lines and none during drop. With 55b merged on main 8f7a33d2 there are 3 more: "compiled 1 shader variant(s) during drop" at t=15.67, 15.77 and 15.82, 650-1100 ms each. They reproduce solo.
- Bisected: main + each of the five S2 kits alone. Only kit-hem-55b adds them; kael-57, sable-53-54, breaker-59 and pip-scale-108 add none.
- Likely cause: pin_draw.gd's new always-on rest line (AimKit.line "draw_rest", plus "draw_fill" and the "draw_mark" circle) is created lazily the first time a Lisette aims after landing, so its material variant isn't among Match.warm_up's stand-ins. Suggested fix: have warm_up draw the AimKit line and circle variants once (or create the rest line at spawn, hidden), then re-post READY with a --hitch-check showing no drop compiles.
- The rest of 55b was green in the batch: --hero-combo-check 287, --archer-combo-check 143, --aimkit-check, --archetype-check, --warden-*. Note: ext/rename-lisette ships before it, so 55b will conflict in docs/AIMKIT.md and tools/pin_bjorn_shots.gd. Keep 55b's text with "Lisette" (S5 resolved it that way once already).

## 2026-11-05 (S2): READY (HIGH) item 109: commit b13b0bc5 on ext/kit-vex-68-109, can ship alone. Merge the commit, not the tip. Targeted checks pass; full suite pending. Details in STATUS.md.

## 2026-11-05 06:30 UTC (S5): ext/art2-kael 0fbc63e6 held: 3 new mid-play shader compiles in --hitch-check (S2, please fix)
- On main c204a6d5, --hitch-check (solo, xvfb software GL) lists 5 shader variants over 4 frames in the ride and none in the land. main + art2-kael alone lists 7 over 5 ride frames, plus "compiled 1 shader variant(s) during land" at t=24.17. That is 3 new mid-play compiles, and it reproduces solo. main + rename-lisette alone matches main.
- Likely cause: hero_vfx.gd's new shader materials (flame arc, burning ground, trails, GPU motes) are made on first use, so Match.warm_up never draws them. Please add them to the warm-up stand-ins (or build them at spawn, hidden), and re-post READY with a --hitch-check whose compile list matches main's.
- Otherwise green in S5's batch run: --hero-vfx-check OK, --juggernaut-combo-check 164/0, full suite with only main's reds. Merge note: tools/check_registry.gd conflicts with --ostra-orb-shots (keep both).
- Same request as kit-hem-55b's (05:22 entry). The same check catches both.

## 2026-11-05 (S4): READY `ext/sfx-ui` @ 50f3c45f (sound pass: UI) — after ext/sfx-base
- vs ext/sfx-base: 87 files changed, 1006 insertions(+), 11 deletions(-) (mostly .wav/.import). tools/gen_sfx_ui.py, content/sfx/ui.json (15 sounds, cat ui, -22 dB RMS).
- Palette: one soft marimba/kalimba pluck family in C-major pentatonic with a small room, low-passed.
- Replaced under the same names: click, hover, pickup (4 takes each), unlock, level_up, ping (3 takes). New: ui_confirm, ui_back, ui_deny, ui_tab, ui_open, ui_close, ui_toast, ui_charge.
- **Kept the old `warn`** (S4 review): it is a combat danger cue (Grimble's blast, Breaker's ult, the R tell, Fusion timeout), not UI; UI denials use ui_deny instead. Note `ping` is also the squad ping and some ability cues: it is now the softer UI ping.
- Wiring (non-reserved files): ui.gd button() picks ui_confirm (primary), ui_tab (tabs), ui_back (Back/Close/Cancel/✕/"Leave it (Esc)"), else click; msg_lane.gd push() plays ui_toast on a new line (**S3's file: one line, possible merge conflict with clarity work**); full_map.gd, overlay.gd (pause menu), home_build.gd, decorate.gd: ui_open/ui_close; hud.gd: loot/pack open ui_open instead of whoosh (string swaps); kinbox_view, decorate (blocked), home_trade, home_black_market (failed buy): ui_deny; hold_unlock.gd: ui_charge. `charge` kept (Fusion uses it).
- Checks: --sfx-set-check 0 (re-run after the warn fix), --check 0, health --strict OK. Sheet: briefs/shots/s4/sfx/ui_sheet.png (made before two renames: `charge` there ships as ui_charge, and its `warn` row is not shipped).

## 2026-11-05 (S4): READY `ext/sfx-boki` @ cb04f986 (sound pass: Boki) — after ext/sfx-base
- vs ext/sfx-base: 117 files changed, 1451 insertions(+) (mostly .wav/.import). tools/gen_sfx_boki.py, content/sfx/boki.json (22 sounds, cat boki, -19 dB RMS). Code: 1 line in home_work.gd.
- Voices: a bright chirp over a soft wordless vowel through scaled-up formants (small, cute); species variety from the existing Unique.voice pitch plus takes.
- Replaced under existing names: kin_happy, kin_unsure, kin_alert, kinhit (4 takes), recall, throw, skill (3), catch, bond, and the element moves k_venom (bubbling gloop + spit), k_spore (puffs + sparkle), k_gravity (reverse suck + soft thud), k_prism (glassy chime fan), k_lunar (moonlit wind + pale bell), k_echo (a ping bouncing away), 4 takes each. Note: `skill` also plays on item use and `throw` on utility throws (both neutral enough; flag if they read too "Boki").
- New: boki_downed, boki_revive, boki_eat, boki_sleep, boki_work (played when a Boki finishes a farm task, home_work.gd:705), boki_fuse, boki_unfuse.
- **Wiring main must do (reserved files):**
  - scripts/match/merge_xform.gd:25 and :168: add `m.sfx("boki_fuse", h.pos, SOUND_RANGE_DB - 4.0)` (`at` at :168) next to the existing `charge` line.
  - merge_xform.gd:85: `m.sfx("recall", h.pos, -2.0, 1.3)` -> `m.sfx("boki_unfuse", h.pos, -2.0)`.
  - scripts/match/kin_downed.gd:167: "kin_unsure" -> "boki_downed"; :256 add `k.m.sfx("boki_revive", k.pos, -4.0)` next to revive_done.
  - boki_eat / boki_sleep have no call site yet (e.g. `Sfx.play("boki_sleep", pos, -10.0)` when a sleeper settles in kin_burrow.gd).
- Checks: --sfx-set-check 0, --check 0, --boki-system-check 0, health --strict OK. Sheets: briefs/shots/s4/sfx/boki_sheet.png, boki_sheet2.png.

## 2026-11-05 (S4): sound base updated: `ext/sfx-base` @ af51093c (was d3d6a77a; merge this one first)
- Feel.dash_sound skips its shared dash layers (dash+reload, portal, throw+whoosh, ...) for a Hunter that has its own `<arch>_dash`, so the new dashes aren't muddied. --sfx-set-check also reads a set's "kit_files" (helper kit scripts). docs/wiki/Rules.md regenerated. Every Hunter branch below has this base merged in.
- Checks: --sfx-set-check 0, --gunslinger-combo-check 82/0, health OK, gen_wiki --check unchanged.

## 2026-11-05 (S4): READY sound pass, 6 Hunters (each after ext/sfx-base; no two branches share a changed file, any order)
All synthesised (tools/gen_sfx_<hero>.py on sfx_lib, own seed), every take at its category loudness, wav + .import committed, no CC0 samples, no reserved files, no wiring for main. Each set: content/sfx/<arch>.json (sounds, signature, kit_files, replaces). Sheets (waveform + spectrogram + levels): briefs/shots/s4/sfx/<hero>_*.jpg ("old" sheets show the replaced sounds).

### `ext/sfx-vex` @ 96e557ca (gunslinger): 77 files changed, 1131 insertions(+), 1 deletion(-)
- Palette: rotary cannon on her shoulder, brass, servos, ember rounds; voice low, clipped woman with a faint servo under down/death.
- Fire vn_rifle (3 takes); RMB vn_cock / vn_throw / vn_blast (3); E vn_ion_charge / vn_ion_fire; X vn_nuke_fire / _fall / _boom / _burn; passive vn_stim; dash gunslinger_dash + vn_slide; steps on 4 surfaces (boots + bandolier); hurt (3) / down / death.
- **Signatures:** gunslinger_spinup (when a string starts after 0.5 s idle, new const SPIN_REST), gunslinger_grenade_thunk (the Burr Charge sticking; replaces vn_stick).
- Replaces 12 vn_* files. Unused now: vn_stick (cleanup).
- Checks: --sfx-set-check 0, --gunslinger-combo-check 82/0, --check 0, health OK.

### `ext/sfx-ryzz` @ 81be1f78 (mage): 85 files changed, 1234 insertions(+)
- Palette: dry, jittery hot-pink lightning, copper, thunder; voice bright, brash young woman.
- Fire vv_bolt (3); Wirerun vv_surge_charge / vv_surge_go + mage_dash; RMB vv_rod_summon / _full / _throw + new impact mage_rod_hit; E vv_sky_place / _count / _strike (2); X vv_ult_rise / vv_ult_hum / vv_ult_slam; passive vv_static_full, vv_orb; steps (light boots, bangles, static tick); hurt (3) / down / death.
- **Signatures:** mage_zap (3, every Static stack below the 4th, pitch climbs with the stack), mage_bubble_pop (snapping out of a Wirerun).
- Replaces 14 vv_* files. Checks: --sfx-set-check 0, --mage-combo-check 112/0, --check 0, health OK.

### `ext/sfx-lisette` @ e39574d5 (archer): 99 files changed, 1369 insertions(+), 1 deletion(-)
- Palette: plucked red thread (Karplus-Strong), steel needles, shears, the spool's ratchet, cloth; voice cool, breathy woman.
- Fire pin_loose (3) / pin_loose_super / pin_heavy; draw pin_draw / pin_heavy_draw; stages pin_stage / pin_super / pin_overdraw / pin_perfect (shears snip); hits pin_super_hit (2) / pin_heavy_hit (3); E pin_hail / pin_rain / pin_patter (3); Spirit Walk pin_spirit / _end; ult pin_ult_cast / _nock / _beam / _final; archer_dash; steps (soft, cloak brush); hurt (3) / down / death.
- **Signature:** archer_thread_twang (3) is now the longbow's shot sound (content/weapons/longbow.json "throw" -> archer_thread_twang), every loose. Anyone using a longbow hears it too.
- Replaces all 20 pin_* files. Checks: --sfx-set-check 0, --archer-combo-check 128/0, --check 0, --hero-combo-check 272/0, health OK.

### `ext/sfx-sable` @ 906e4b18 (thief): 91 files changed, 1272 insertions(+), 5 deletions(-)
- Fire dj_bolt (3) is now a flintlock crack (flint snap, pan puff, report, smoke) over her spinning bolts; dj_fizzle.
- **Signatures:** thief_flintlock_crack (the empowered double shot; replaces dj_bolt_emp), thief_cock (hammer cocked as the empowered bolt forms; replaces the shared click).
- RMB dj_bola_whirl / _throw / _wrap + thief_bola_stun (replaces ab_stun); E dj_knife_throw, thief_knife_stick (replaces ab_plant), dj_blink; ult dj_encore / dj_encore_whirr / dj_blade (3) / dj_encore_hit (3); knock heal dj_heal; thief_dash (her kit's own dash, replaces dj_cartwheel); steps (light leather + silver jingle); hurt (3) / down / death (pistols clatter).
- Replaces 12 dj_* files. Unused now: dj_bolt_emp, dj_cartwheel. Checks: --sfx-set-check 0, --dancer-combo-check 126/0, --check 0, health OK.

### `ext/sfx-kael` @ acbe23f0 (juggernaut): 99 files changed, 1332 insertions(+), 12 deletions(-)
- Fire jug_slash (3), heavy cut + low whoosh.
- **Signatures:** juggernaut_blade_hiss (2; white-hot hiss and crackle, no fire; now the greatsword's sound in greatsword.json, was the shared cleave), juggernaut_chain_rattle (2; Warchain throw, chain-lunge, haul arrival and landing). Also juggernaut_enrage (replaces knock + charge on Enrage), juggernaut_chain_bite (hook biting; replaces ab_tether), juggernaut_heal (replaces dj_heal for him).
- RMB jug_wave / jug_charge / jug_slam_wind / jug_full / jug_slam_hit / jug_lunge_hit / jug_drop / jug_meteor; E jug_chain / jug_taut / jug_reel; ult jug_guard / jug_ting (2) / jug_riposte; juggernaut_dash; steps (heavy boots + shackle chain); hurt / down / death (low, rasp; chain and sword fall).
- Replaces 15 jug_* files. Unused now: jug_dash. Checks: --sfx-set-check 0, --juggernaut-combo-check 164/0, --check 0, health OK.

### `ext/sfx-tarek` @ 4872c687 (dolm): 98 files changed, 1305 insertions(+), 1 deletion(-)
- Fire br_throw (3) / br_boulder_hit (3) / br_wind / br_punch (2).
- **Signature:** dolm_rock_crunch (2), played in launch() as each rock tears out of the ground (new line).
- Rocks br_launch / br_burst; Tremor Sense br_sense; leap and slam br_rise / br_leap / br_slam / br_shove / br_roll; E br_crack / br_raise; ult br_spine; dolm_dash (his air dash, replaces br_shove there); steps (sure-footed, grit); hurt / down / death (his stones drop).
- Replaces 15 br_* files. Checks: --sfx-set-check 0, --dolm-combo-check 139/0, --check 0, --hero-combo-check 272/0, health OK.
- Note: Sable/Kael/Tarek's --check and combo checks ran before the base merge; --sfx-set-check reran after it.

Still to come: Cinder, Grimble, Pip, Breaker, Motley, Claire, then ext/sfx-cleanup.

## 2026-11-05 (S4): READY sound pass, 5 more Hunters (after ext/sfx-base af51093c; all 13 sound branches so far merge together with no conflicts, any order)
Same rules as the first six: synthesised (tools/gen_sfx_<hero>.py), category loudness, wav + .import, no CC0, no reserved files, no wiring for main. Sheets: briefs/shots/s4/sfx/<hero>_*.jpg.

### `ext/sfx-cinder` @ 48ea9a42 (ashwick): 94 files changed, 1243 insertions(+), 28 deletions(-)
- Fire lw_roar (3, layered flame roar; still overlapping one-shots every 0.4 s, see "loops" below), lw_pilot (igniter tick + gas + catch); RMB lw_bolt / lw_bolt_hit; burns as_ignite / lw_blaze; Shift lw_bash / lw_bash_hit / lw_hop; E lw_shield + new ashwick_cloak_hit (first foe hit); X lw_jet / lw_jet_land / lw_trail (3); ashwick_dash (3); steps (light patter, pack clinks); hurt (3) / down (groan then a breathless laugh) / death (the tank vents).
- **Signatures:** flame roar = lw_roar; ashwick_tank_hiss (3) when the lance is let go.
- Also deletes scripts/arch/kits/ld_sfx.gd (LDSfx loaded one file per name, hiding takes; Sfx's lazy load covers it) and its 2 calls: the same commit on Cinder and Grimble, so they merge cleanly.
- Replaces 13 lw_*/as_* files. Checks: --sfx-set-check 0, --ashwick-combo-check 97/0, --check 0, health OK.

### `ext/sfx-grimble` @ 74b46846 (dredge): 103 files changed, 1392 insertions(+), 34 deletions(-)
- Fire dr_shot (3, junk blunderbuss + scrap rattle); RMB dr_throw / dr_grab / dr_reel; E dr_anchor_wind / dr_anchor / air smash dr_dive / dr_quake; Shift dr_barge / dr_hop; X dr_blast_charge / dr_blast; dredge_dash (3); steps (skittery claw clicks, hoard jangle); hurt (3) / down (coins spill) / death (the hoard crashes), wheezy and creaturely.
- **Signatures:** dredge_coin_jingle (each Salvage stack and the HAULED payoff; replaces pay_salvage), dredge_junk_clatter (every barge), dredge_pickup (coins pour in + wheezy chuckle when he picks up loot: 2 lines in scripts/match/pack.gd now use HeroSfx.of(h, "pickup", "pickup"); others keep the shared pickup; docs/AUDIO.md gets the "pickup" kind).
- Replaces 12 dr_* files. Checks: --sfx-set-check 0, --dredge-combo-check 93/0, --check 0, --hero-combo-check 272/0, --backpack-check 0, health OK.

### `ext/sfx-pip` @ 9b6f72e1 (tender): 94 files changed, 1271 insertions(+), 1 deletion(-)
- Light, warm, cute, never fiery (air, glass, brass, warm chords, sparkle under ~7 kHz). Fire tend_ember (3) / tend_ember_emp; tend_kindled; RMB tend_seed_aim / tend_seed / tend_stick / tend_root; E tend_hearth / tend_toss / tend_land / tend_flare; Shift/Carrier tend_hop / tend_pickup; X tend_call (soft wordless choir + lantern) / tend_call_hum (3) / tend_arrive; tender_dash (3); steps (light pads, lantern handle tick); hurt (3, a small "eep") / down / death (the star dims).
- **Signatures:** tender_lantern_chime (3) on the Hearthlight cast; tender_cheer when Hearth Call mends someone.
- Replaces 16 tend_* files. Checks: --sfx-set-check 0, --tender-combo-check 82/0, --check 0, health OK.

### `ext/sfx-breaker` @ e13745ea (bulwark): 103 files changed, 1466 insertions(+), 2 deletions(-)
- Palette: wet old timber, barnacled iron, a ship's bell, sea swell and bubbles, 1.5x size (low bodies, sub under heavy hits); voice deep, warm male with a drowned gurgle; death ends with the hull sinking and a distant bell.
- Fire bjorn_throw (3); LMB bjorn_recall / _catch / _plant / _spin (3) / _glint (ship's-bell ding) / _slam (3); RMB bjorn_shield_up / _block (3) / _break / _bash; Shift new bulwark_charge (replaces the shared shield) + bjorn_whirl; E bjorn_purify / _purify_burst; R bjorn_ult_wind / _slam / _rumble / _crackle; bulwark_dash; steps (heavy sea boot, iron band, shells).
- **Signatures:** bulwark_hammer_clang (3) when the thrown hammer hits a foe; bulwark_hull_creak as the prow shield comes up.
- Replaces 18 bjorn_* files. Checks: --sfx-set-check 0, --bulwark-combo-check 144/0, --check 0, health OK.

### `ext/sfx-motley` @ 260c17a1 (ostra): 78 files changed, 1170 insertions(+), 1 deletion(-)
- Palette: a worn music box (steel tines, an original tune), a coiled spring, cap bells on the swap, dark Void swells; voice hollow, behind the mask, with a giggle; death = a music box winding down. He floats: steps are hover pulses with a faint surface layer.
- Fire os_orb (3) / os_orb_hot (3); os_prime; RMB os_snap_wind (crank ratchet) / os_snap / os_snap_hit; Shift os_swap_lob (slide whistle) / os_swap (bells); E os_seed / os_pop; os_empower; R os_well / os_well_hum; ostra_dash.
- **Signatures:** ostra_music_box (~3 s original tune when Brimseed is nearly ripe; replaces os_full), ostra_spring_boing (with os_pop).
- Replaces 13 os_* files. Checks: --sfx-set-check 0, --ostra-combo-check 137/0, --check 0, health OK.

Still to come: Claire (agent running), then ext/sfx-cleanup (old generator functions, unused files: vn_stick, dj_bolt_emp, dj_cartwheel, jug_dash, os_full, pay_salvage, dr_haul?, tend_relay?; sfx_lib fixes reported by the agents: voice() tail release, chime() soft attack, shared helpers).

## 2026-11-05 (S4): READY `ext/sfx-claire` @ d7862dd8 (rimewright): 119 files changed, 1707 insertions(+), 5 deletions(-)
- Palette: clear ice (glassy crystal partials under 7.5 kHz), the falling chirp of cracking ice, a steel blade on ice, frosty air; voice airy and siren-like, slightly doubled; death = a siren wail with a faint low demonic growl under it, then an ice crack and wind (the sweet-face, demonic-body seductress).
- Fire rime_shard (3, the dart; the weapon's sound) / rime_beam (3, skating beam) + new rimewright_dart_hit (3, every dart/beam hit); RMB rime_spear_aim / rime_lance / rime_zone (3) / rime_burst; Shatter rime_splinter (3); E rime_wall_tell / rime_wall / rime_freeze; Rimelock rime_lock (a breathy hum inside the shell) / rime_creak (3) / rime_crash / rime_crack; steps (light heel + blade tick); hurt (3) / down / death.
- Dash: her skate IS her dash (on_dash handles it), so HeroSfx's dash never fires for her; _begin_skate plays rimewright_dash (was rime_run), rime_stop regenerated. (S4 checked the other kits: they dash through travel() -> dash_with(), so their <arch>_dash plays; Motley's Shift is his Trade with its own sounds, ostra_dash covers the other dashes that move him.)
- **Signatures:** rimewright_skate_scrape (3, each skate stride), rimewright_chime (3, when the 8-dart shell closes, on the spear's crystal at landing, and when the wall freezes).
- Replaces 15 rime_* files. Checks: --sfx-set-check 0, --rimewright-combo-check 78/0, --check 0, health OK, gen_wiki unchanged. Sheets: briefs/shots/s4/sfx/claire_*.jpg.

## 2026-11-05 08:10 UTC (S7): UPDATE ext/s7-boki-82-92 is now c10dfaef (origin/main 25e8ea8d merged in)
- check_registry conflict with --dash-aim-check: kept both entries. Re-run after the merge: --boki-moves-check 0 failures, health --strict OK, gen_wiki --check 34 unchanged.
- ext/s7-empty-77-81 a4808f68 still merges clean onto 25e8ea8d.
- ext/s7-dash-outpost-84-86 is held. On this box --simtest --seed=5 ends "team wiped" at sim 46 s on the branch; plain 25e8ea8d extracts at sim 236 s. Its agent is bisecting now.

## 2026-11-05 (S2 to S5): ext/boki-starter is now 3420bc02 (5k pass), ready to wire. Three pieces, exact lines in STATUS.md. Don't take 27fab2ad.

## 2026-11-05 (S2 to S5): ext/art2-kael cf1e6343 re-posted READY with one difference from your bar
- HeroVfx.prewarm() fixes all HeroVfx mid-play compiles; merges origin/main 354be5b4. --hitch-check vs clean main, solo xvfb, cold cache: ride main 3 compiles over 2 frames, branch 4 over 2; drop 0/0; land 0/0. Every mid-play compile on both is dj_fx (existing DJFx lazy shaders), none is HeroVfx. **The list doesn't match main exactly: one extra dj_fx variant, cause not proven.** Your call: merge, or hold for a DJFx warm-up.
- ext/art2-lisette 9193bc48: fix in, --hitch-check still rerunning. Hold until it reports.

## 2026-11-05 (S2 to S5): correction: ext/art2-kael cf1e6343 now conflicts with origin/main a4b39fd7. Its agent is merging main; wait for the new commit.
## 2026-11-05 (S2 to S5): ext/art2-kael 37e5033e READY (replaces cf1e6343); merges clean into a4b39fd7
- Contains main; no audio differs from main (main's sound pass wins). hero-vfx OK, juggernaut-combo 164/0, hero-combo 272/0, sfx-set 0, match-audio 0, health --strict OK. --hitch-check: main 3 ride compiles over 2 frames, branch 4 over 2; drop and land 0. All mid-play compiles traced on 354be5b4 are DJFx, none HeroVfx; one extra dj_fx variant, cause not proven. Your call whether that blocks.
- ext/art2-lisette df95ffe5: details to follow when its report lands; merge after Kael.

## 2026-11-05 (S2 to S5): bot-sanity is NOT an ART-1 regression
- Two reps each, seeds 3/5/9: main 0, art1-motley 0, art1-kael 0. art1-cinder bb7acfb3 flags 1 on seed 3 (Daemek, roam facing flips), but main + art1-cinder merged is 0 on all three seeds. It's seed drift exposing a latent bot roam jitter, not the clip code. The check is deterministic; a fresh worktree needs --import first or it gives a false all-zero pass.

## 2026-11-05 (S4): READY `ext/sfx-base-2` @ 015d545f (base for the owner's sound playtest orders; from origin/main 0237eb8d, +96/-20, 6 files)
- `tools/sfx_lib.py` `save_loop(name, x, cat)`: a seamless loop (tail cross-faded into the head, no fades), for held sounds played with Sfx.loop_start (minigun spin, charge hums). Until now every file got a 30 ms end fade, so loops dipped each cycle (why Cinder's roar and Pip's hum are overlapping one-shots).
- `scripts/core/sfx.gd`: reads `"reach"` (metres) from every content/sfx/<group>.json at start (`Sfx.sound_reach`) and uses it in play() and loop_start(): a heavy sound carries past the 22 m hear_range; past 9 m it still plays through the muffled SFXFar bus, so the low end is what carries ("hear Vex coming"). Each branch edits only its own set file.
- `content/rules/sfx_levels.json`: new categories heavy_fire (-15.5 dB RMS) and heavy_impact (-14.5) for the damage carries.
- `--sfx-set-check`: reach entries name the set's sounds and stay within 22-80 m; every sound under `"loops"` repeats seamlessly; heavy_fire counts as weapon fire. Verified with a throwaway set: a save_loop file passes, a one-shot listed as a loop and a 200 m reach both fail.
- docs/AUDIO.md (loops, reach, the two categories), docs/wiki/Rules.md regenerated.
- Checks: --sfx-set-check 0 (14 sets), --check 0, health --strict OK, gen_wiki --check unchanged. Merges cleanly onto main (built on it). No reserved files, no Net or save change.

## 2026-11-05 (S2 to S5): READY ext/art1-sable 78e69563 (no Kael art; replaces 8ffd3352)
- Agent ~85-87%. Nine targeted checks 0 FAIL lines on the tip, health --strict. Full suite last ran before the fine-detail round and the Kael split; please count it in your batch. Weapon display name is now Arc Shots; ids unchanged. Shared change: wing-chain stiffening in Springs.step (only on the `wg` flare). --clip-live-check skips while Kael has no clips.

## 2026-11-05 (S2 to S5): READY without Kael art: ext/art1-pip 1ed53fd7, ext/art1-vex 79dd1a4d
- Pip contains kit-pip-118; Vex contains kit-vex-112 and the 68/109 work. Main merged in; Kael's art, data, warden-model row restored to main; --clip-live-check skips while Kael has no clips. warden-model, warden-glb, juggernaut-combo, hero-combo, clip, rig-standard, warden-stance, Hero checks 0 FAIL lines; health --strict. No full suite since the split: your batch covers it.

## 2026-11-05 17:45 UTC (S2 to S5): READY: ext/kit-cinder-ult-e 311e5149 (Flue Flight: only E works)
- On top of ext/kit-cinder-66 ea287770 (your batch 10) and main b23aab82; merge-tree clean. Wiring: one empty ArchKit.gate_inputs() and one line in Hunter.
- Blocked: LMB, RMB, Shift, gloves, gear, util slots, Boki C, skill, throw. Kept: E, X (lands early), jump, steering, weapon swap, interact. Owner calls with alternatives are in STATUS.
- ashwick-combo 117/0, kit-combo 39/0, hero-combo 287/0, archetype 362/0, health and style strict OK. Not run in-game or over the network.

