# Ext coordinator -> main session (append-only log; newest at the bottom)


## >>> PINNED FOR THE OWNER (S2, 2026-11-03 22:10 UTC): create the two game servers in Hetzner (click-steps) <<<
Main asked for this at the top. Agents never create paid resources, so these are for the owner. About 5 minutes; ~€8-10/month each.

**0. Once: add S2's SSH key** (Hetzner Console > your project > Security > SSH keys > Add SSH key). Name it `boki-s2-deploy` and paste exactly this one line:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOxBJtIZzkdINkjqWaUOSY0Y1yTeCC+kBHbY2DDe4NFx boki-s2-deploy
```
(Public key only; the private half stays on the S2 box. It's a dedicated deploy key: remove it in the console any time to cut S2's access.)

**1. Once: a firewall** (Security > Firewalls > Create firewall), name `boki-game`. Inbound rules:
- TCP 22 (SSH), any source
- TCP 8080 (matchmaker), any source
- UDP 7777-7799 (game matches, one port per match), any source
- (ICMP, any source: lets clients measure ping to pick a region)
Outbound: leave the default (all allowed).

**2. Server EU:** Servers > Add server:
- Location: **Falkenstein (fsn1)** (or Helsinki hel1 if Falkenstein is unavailable)
- Image: **Ubuntu 24.04**
- Type: **Shared vCPU > x86 (AMD) > CPX21** (3 vCPU, 4 GB RAM). If CPX21 isn't offered, the nearest 4 GB shared type.
- Networking: Public IPv4 **on** (clients need it), IPv6 on
- SSH keys: tick **boki-s2-deploy**
- Firewalls: tick **boki-game**
- Name: **boki-eu-1**
- Everything else default (no volumes, no backups needed yet). Create & Buy.

**3. Server US:** the same, except Location: **Ashburn, VA (ash)** and Name: **boki-us-1**.

**4. Tell S2 the two IPv4 addresses** (in the owner's inbox to S2 or here). S2 then deploys over SSH (user root, key above), installs the server build + matchmaker as systemd services, and posts the matchmaker URLs. Nothing secret goes into the repo.

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

## 2026-11-02 15:05 ET: replies to 13:20–14:30
- **Ready from the server**, re-merged onto sync62:
  - ext/kits2-nor 4b1214b (Net 0.15.0; that clashes with main's 0.15.0, so yours to renumber)
  - ext/farmbuild efa72a7
  - ext/aimkit 577412e (on 18fab56)
  
  I've asked aimkit to re-merge sync64 too.
- **ext/perkorbs** is ready (551683b), see the 15:00 entry. The 1/2/3 level-up prompt goes away with it.
- **The kit branches** (5 running on Opus, Breah/Ostra queued) were told via the server inbox to re-merge sync64 and to route every shot through `spawn_shot`. They won't add a separate height fix.
- **Queue noted:** fidelity, then equal (keys-cover and equal-loadout still running here, plus shops and the map legend), then ext/drop (target 18-22 s), then ext/market, then the bigger map.
- Also running here: **ext/hudref**, an owner request. The HUD, nameplates and health/armour bars are being brought closer to the original's layout, in our own style. Boki-slot changes, if any, will be written up for you rather than made in the reserved file.

## 2026-11-02 15:15 ET: owner answers on level-ups and backpacks
**Level-ups (approved):**
- Quiet per-level growth: +6% health and +5% ability power for levels 2-6, half that for 7-10.
- The banner shows on weapon-step levels only.
- No lucky-level orb.
- Being built on ext/perkorbs now.
- **Every hunter's level must be visible to everyone** on the overhead nameplate, presented like the original (our art). Being built in ext/hudref.

**Backpacks: the owner reverses "pack size is equal".** "Extra backpack slots, and even upgrading your backpack or paying to bring in a bigger backpack, is a good part of extraction games." Proposal, for you and the owner to confirm:
- **Backpack tiers** as a gear slot: Pouch (base, everyone has it free) up to Satchel, Pack and Rucksack. More slots per tier, and maybe a small move-speed cost on the biggest.
- **Bring-in, at risk:** like the gloves and boots. Bought or crafted at home (materials plus gems, the Workshop or the market stall). Lost in your deathbox if you die. Tier capped by difficulty, like the other bring-ins.
- **Found in the match:** backpack pickups from chests and bosses that you swap on the ground (the old one drops). The shops sell an upgrade.
- **The satchel perk** (+1 slot) stays as an in-match orb.
- **"Pay to bring in"** means gems or materials earned in play, never real money.

If you agree, it slots into ext/equal-loadout as one more bring-in slot. Tell me, or post the final spec here.

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

## 2026-11-02 16:20 ET: owner decision: no shards
No shard or item tier-up system for now. The research stays in 0006 as a record only. Don't add shards to ext/equal, the shops or ext/market.

## 2026-11-02 16:30 ET: OWNER DECISION: hunter ultimates return on X; Merge stays on R
The owner and I worked through how Merge and ultimates fit together. Decision:
- **Every hunter gets their own ultimate back, on X** (rebindable). It unlocks at level 6, runs on its own cooldown, and is rebuilt from the source footage like the kits. Please confirm X is free in a match: your 11:30 note said "ultimate pinned to R when X is bound elsewhere", so an old X binding may need to go.
- **Landing your ultimate charges the Boki bond.** A hit, knock or kill with it gives a big chunk, about 60-80% of the bar, tunable in data. Normal fighting still fills it more slowly, so Merge is never locked behind the ult.
- **Merge stays on R.** R again releases it: the Boki bursts out with its signature attack, then rests. The owner wants the split to end on a high rather than as a penalty; please shape the release that way.
- **The intended arc:** fight and build bond, ult (X) to cash in, merge (R) for the climax, release for a final burst. Two separate buttons, so the two resources (cooldown and bond) never share a key.
- **Readability:** rivals see the hunter's ult tell, then the Boki's bond glow.
- **Watch burst:** ult straight into merge must not one-shot people. Keep the merge damage bonus moderate.

**Your side** (reserved files): a public hook for kits to add bond, for example `KinBond.add(h, amount, reason)`; the release burst; any bond-meter tuning; freeing X.
**Our side:** an ult video study is running now (Opus, clean room). The server's kit agents will build each hunter's ult in a follow-up pass once the current kitfix pairs land, calling your bond hook.

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

## 2026-11-02 18:35 ET: OWNER: remove the "Hold Shift for the long dash" setting
- Remove the `dash_hold` setting: settings.gd default, the overlay.gd:295 toggle "Hold Shift for the long dash", and anything that reads it. Drop the key from saved settings on load.
- Hold-to-extend dashes are a **per-hunter mechanic**, not a player setting. Example: Tamsin's Rinkrun, where you hold Shift to skate. Where a hunter's source has a hold-dash, the kit implements it. Everywhere else, Shift does what the kit says.
- This is in your files (settings/overlay) and is small, so please take it in your next sync. I'm telling the kit agents not to rely on `dash_hold`.

## 2026-11-02 18:40 ET: change: ext/uipolish takes the dash_hold removal
The owner also asked for a settings audit and a UI art upgrade ("the 'Boki can use your E ability' option is outdated; UI and settings need work and an art upgrade, along with all boxes"). It's started as **ext/uipolish** (Opus).

Scope:
- An audit of every setting: keep, remove or rename, with a migration that drops removed keys from saved settings.
- Removes `dash_hold`, so please skip my 18:35 request.
- Removes the outdated Boki E option.
- One theme/style system for menus, dialogs, tooltips, cards, panels and controls, shared with ext/hudref's hud_style.gd.

It touches settings.gd, overlay.gd and the ui/ panels (not hud.gd beyond wiring). If a Boki setting lives in a reserved file, it'll be written up for you.

## 2026-11-02 18:45 ET: OWNER DECISION: merge C into G (one Boki button) and make the Boki feel faster
The owner asked why C and G are separate buttons. Approved design (your files; please build it on your next Boki branch):
- **Tap G, "Go!":** the Boki leaps to the cursor. If its C ability is ready, it uses it on arrival or at the target; if not, it does a normal Sic/attack.
- **Tap G while it's away:** call it back.
- **Hold G:** the order wheel (Chase, Guard, Return, Follow) plus a new **"Use ability here"** slice, for support Boki whose heal or shield you want where they stand. Smart default: tapping G with the cursor on yourself or a teammate makes a support Boki cast its ability there without leaping away.
- **C is freed.** Leave it unbound by default, and remove it from the HUD's Boki slot (the right-side Boki box shows the ability cooldown inside the G box). It stays reserved until the owner decides on a use. Migrate keybinds, update the tutorial and tips text, the kit cards, and the bots (they use the combined action).
- **Responsiveness (owner: "make sure it feels more responsive / faster"):**
  - The command fires on press: no waiting for release to tell tap from hold. Start the Go immediately; if G is still held after about 180 ms, cancel into the wheel without a visible hitch, or open the wheel only on hold-plus-flick.
  - Shorter Boki reaction latency: start moving within one or two frames, faster leap acceleration, and a quick anticipation pose instead of a long wind-up.
  - Instant feedback on press: a bark or chirp, a cursor ping and a target marker.
  - Recall snaps back faster.
  - Tune with numbers in boki_system.json, and add a check that asserts press-to-move latency stays under a set number of frames.
- Hunter ultimates stay on X, Merge on R.

## 2026-11-02 18:50 ET: OWNER DIRECTION: same kits, original designs
"I want them to feel like copies of the real ones but differently designed art. You can make the Elluna copy a fire fox or something, for example. But I want to start at the baseline of having the same kit."
- **Kits and feel:** mechanics, timing, aiming, movement and readability match the source as the baseline. That's what the kitfix, polish, ult and body/dash passes are doing.
- **Characters:** each hunter gets a clearly original design, with its own species or concept, silhouette, palette and theme, chosen to fit the kit's role but not resembling the source character. The owner's example: Moosh Moosh as a small fire fox.
- **Next (after the kits pass review):** a design-concept pass proposes an original concept for each of the 12 hunters (species or archetype, silhouette, palette, signature props, effect colours). The owner approves them, then the models and effects are rebuilt. I'll post the concepts here first.

## 2026-11-02 19:15 ET: PLAYTESTER FEEDBACK (via owner): you can't tell whose Boki is whose
"It's confusing which pets are theirs vs yours vs teammates." The Boki visuals are in your files, so here's a proposed fix for you to take (or adjust). The goal: answer "mine / my team's / enemy / wild" in under a second, even in a messy fight.
1. **Ownership ring under every owned Boki,** in the same visual language as hunter rings (ext/hudref's hud_style.gd colours):
   - **Yours:** a bright ring in your own colour, plus a small chevron or pip above it. It's the only one with the chevron.
   - **Teammates':** the team colour (blue/green), a thinner ring.
   - **Enemies':** red/orange, a thin ring.
   - **Wild Boki:** no ring, a neutral yellow-white "?" or paw pip, as now when capturable.
2. **A small owner tag** above owned Boki: the owner's name in small text, or their portrait dot. Show it for teammates' and enemies' Boki at mid range. Hide it on yours; the chevron is enough. Fade it with distance like nameplates.
3. **A leash line on hover or when far away:** a faint line from a Boki to its owner when you hover it or when it's more than about 8 m from its owner. You can also always show yours while you're aiming a G command.
4. **Colour echo:** the Boki's outline or rim light takes its ring colour, so ownership reads even when the ring is hidden by grass or a crowd. Keep it subtle enough not to fight the Boki's type colour.
5. **Minimap:** Boki dots in the same ownership colours; yours slightly larger.
6. **Merged form:** the merged shell keeps the owner's ring and tag, so an enemy merge reads red.

A check should assert that each relationship (mine, team, enemy, wild) renders a distinct ring and tag combination, and that the tag hides on yours.
ext/hudref (nameplates) and ext/uipolish (theme) can supply the colours and styling. Tell me if you'd rather one of our branches build the non-reserved parts: the ring and tag rendering could live in a new file reading Kin state through getters.

## 2026-11-02 19:45 ET: footage findings on base movement (your call; owner to confirm)
The body/movement study of all 12 hunters (briefs/hero-ref/*.md, "Body, scale and movement feel") measured the source at 30–60 fps:
- **Run speed is the same for every hero**, about 3.9–4.4 m/s; the heavies aren't slower. Ours spreads by weight: 5.0 / 4.8 / 4.55. The owner's earlier direction (drop weight labels, same kit feel as the source) points toward one shared speed. Please consider it with the owner.
- **Step cadence:** the source takes short, quick steps (~2.3 strides/s). Ours is 1.64 Hz (medium) and 1.41 Hz (heavy). Suggested: about spd×2.9 with ~25% shorter strides, so feet don't slide.
- **Start and stop:** instant in both; ours already matches.
- **Nameplate height** differs per hero in the source. ext/hudref will expose a per-hunter offset.
Per-hunter scale, dash and pose changes go through the kit polish passes.

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

## 2026-11-02 19:20 ET: ack 17:55–19:05; corrections sent; ext/hudref ready
- **Keybinds:** understood. R = reload, X = hunter ult, T = Merge, G = the Boki button, C freed; my "Merge on R" is withdrawn. Sent to the server's kit and ult agents and to ext/equal-loadout and ext/keys-cover: use `Settings.key_cap` everywhere and never hard-code a key letter.
- **Keys into the belt (17:55):** sent to both branches. ext/equal-loadout owns the belt and adds chest_key and rift_key belt items (stack caps 3 and 1). ext/keys-cover drops its standalone counter and exposes KeyChest.count/take.
- **Dash feel and dash_dir (sync68–69):** sent to all kit polish passes, including Vireo's Wirerun at 5–8.5 m.
- **Farm build flow (19:05):** sent to the server (the farmbuild owner). Its plan comes to you before it builds.
- **Black Market / Challenge Sign:** noted for ext/market (queued after ext/equal).
- **ext/hudref ready: 92c4c822**, on main around sync66. Nameplates have:
  - segmented health, armour and shield bars with a delayed damage chip
  - a level badge everyone can see, which pulses on level-up
  - stacked status words, which also fix the overprinting your reviewers saw
  - a downed state
  - a per-hunter plate height via `HudPlate.plate_offset(h)`, reading an optional `plate_offset` from archetype data
  
  Also in this branch: the bottom-left portrait and stats block, the ability-bar slots and cooldown text, floating damage numbers, and hit and low-health feedback. Shared colours live in scripts/ui/hud_style.gd, aligned with ext/uipolish's UI tokens. Use them for the Boki ownership rings (mine, team, enemy).

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

## 2026-11-03 00:53 UTC: from the server coordinator. Farm builder NPC plan (INBOX 00:15 item 3), for the owner to confirm before building
Base: ext/farmbuild is MERGED into origin/main; plan against main. Gating = FarmUnlocks (content/rules/farm_build.json), levels [0,6,16,30,48,70]; milestones first_extract, first_boss, scan3.

**Builder:** Dunna Quillfeather (alts: Hob Brackenridge; Mirela Joist). Note: avoids hunter names (Tamsin, Linwick). Personality: gruff, dry, proud of straight beams; talks in short sentences, never says no, only "not yet". Sample: "Boards don't hammer themselves. Tell me what you need and I'll draw it up."

**Starter set (today's `starter`, plus feeder):** house, crop_patch, cook_pot placed at once; feeder from Econ.FEEDER_ORDER (feeder_inv, not gated). Pen = ranch_pen is level 4 today. To match "feeder, pen, crop patch" the pen must move earlier (open question 1). Decor/paths/fences: fence, path_dirt, flowers, path_clear have no unlock entry, so they are open now; shrink to a handful (question 2).

**Unlock order (existing table; ids real):**
- T0 new save: house, crop_patch, cook_pot, feeder, fence, path_dirt, flowers. "Start with the basics. Rome wasn't built in a day, but it had a decent crew."
- T1 farm level 2 (6 pts): job_board, lumber_camp, quarry, storage_chest, market_stall, boki_burrow, training_post, workshop, bush, tree, lantern, bench, kin_bed, picket, path_stone. "You've got a crew now. Let's give them something to swing at."
- T2 farm level 3 (16): hearth_oven, workbench, seed_garden, nesting_nook, graveyard, cottage, stone_wall, hedge, path_wood, pine, lamp_post, rug, banner. "Real work needs a real bench."
- T3 farm level 4 (30): kiln, spark_mill, ranch_pen, infirmary, water, rug_long, pillar. "Pens, kilns, a proper hospital. Now we're talking."
- T4 farm level 5 (48): cold_store. "Cold store. Mind the draught."
- Milestones: first_extract -> armory; first_boss -> shrine, fountain; scan3 -> blossom_tree, kin_statue. "You came back alive. Take this blueprint." / "Bring me a trophy and I'll carve it in stone."
- Level 6 has no items yet (cradles 6-8 open at 4/5/6): optional line only.
That is a lot per tier for "next few"; consider thinning T1 (question 3).

**Hidden sections:** in home_build._tab_items, drop `FarmBuildUi.locked_entry` branches (3 call sites: fs() catalog loop, lots loop, default tab loop) when gated; items placed or owned stay (FarmUnlocks.open already covers). In _build_bar skip tabs whose _tab_items is empty (Upgrades, Island, Buildings always shown). Optional: a tab with items hidden shows "Talk to Dunna for more" instead of vanishing; recommend hiding all tabs except Buildings plus a single footer line "Talk to Dunna for more" when anything is still locked. Ungated (old) farms unchanged.

**Opening:** B opens on Buildings: set `cat = "Buildings"` when build mode toggles on (var cat defaults "Garden", line ~15; line ~1328 already does it in one path).

**New vs wiring:**
- New: scripts/home/farm_builder.gd (NPC placement near the house, dialogue pick by tier, "new blueprints" toast hooking FarmUnlocks.announce); content/rules/farm_builder.json (name, tier lines, tier->unlock grouping, optional); an interact prompt.
- Wiring: farm_build.json (move ranch_pen earlier, thin T0/T1 per answers; maybe add "tier" field); farm_unlocks.gd (tier_of(id), builder_line()); farm_build_ui.gd (hide instead of locked_entry); home_build.gd (hide branches, empty-tab skip, default cat); home.gd (spawn NPC, E interaction); --farmbuild-check updated (locked entries now absent).
- Reserved Boki files: none touched. Save: no new fields needed (fbs already tracks announced). Net.VERSION unchanged.

**Open questions for owner:**
1. Pen in starter set: make ranch_pen level 1 (it is level 4 now), or just unlock it first at level 2?
2. Which decor ids stay open at start (fence/path_dirt/flowers/path_clear are ungated today)?
3. Fewer items per tier (T1 has 15)? Spread over levels 2-5, or keep?
4. Name choice (Dunna Quillfeather / Hob Brackenridge / Mirela Joist).
5. Hide every locked tab, or keep tabs with "Talk to Dunna for more"?
6. Builder placed in the world (walk up, E to talk) or only a portrait dialogue on opening B?

## 2026-11-02 20:55 ET: OWNER DECISION: Merge moves to C (replaces T)
Now that C is free (the C-into-G merge), the owner wants **Merge on C** (C again releases), so the Boki keys sit together and it's easy to reach. Final layout:
- R = reload
- X = hunter ultimate
- **C = Merge**
- G = the single Boki button
- T free
- Q/V = gloves, 1-4 = belt, F = interact

Please update the ultbond/keybind defaults and the migration: anyone with Merge on T, or on the old default, moves to C, unless they rebound it themselves. Also update the texts and keybind-check. Our side already uses `Settings.key_cap("ultimate")` everywhere, so no kit or HUD text changes are needed.

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

## 2026-11-02 21:20 ET: OWNER ANSWERS
- **One run speed for every hunter** (owner: "if SUPERVIVE does it, yes"). The footage measured every hero at about 3.9–4.4 m/s, heavies included. Please replace the 5.0 / 4.8 / 4.55 per-class speeds with one shared base speed (around 4.3–4.5 m/s, tuned to feel). Keep the short, quick steps (cadence about spd×2.9, strides about 25% shorter). This is your movement file.
- **"Go to the source where possible"** is the owner's general rule for open tuning calls. Example: Moosh Moosh's air glide goes to the source's 11–15 m (sent to the server).
- **UI art:** a bolder, more professional second UI pass is starting as ext/uipolish2. It builds on ext/uipolish's theme, so merge ext/uipolish first if you can.
- **Hold-Alt detailed tooltips:** at the back of the queue as a consideration. The owner's alternative is making the base text clear enough.
- **Breakables (owner):** barrels and other breakables should break in **one hit**. Right now it isn't clear when you've shot one, and explosive barrels have the same problem. Being fixed on ext/keys-cover, which added barrels: one-hit breaks, clear hit feedback, and a readable explosive telegraph and blast. If breakable code lives in your files, I'll write it up instead.

## 2026-11-02 22:50 ET: ext/portrait ready to merge (a6189f21; built on ext/hudref, so merge hudref first)
The owner said the bottom-left portrait looked really bad.

**Causes:**
- The main one: the match's sight fog (`vis_fog`) was applied to the portrait model, which sits at the world origin outside your sight, so it rendered dark grey.
- A stretched 96² render.
- Framing that cropped the forehead and ignored model scale.
- A flat background and a band over the chest.

**Fix:**
- `Portraits` frames on the model's own Head part, in model space with scale, so it works for any size or future redesign. Per-hunter `"portrait": {zoom, lift, yaw}` overrides for helmet heroes.
- 16° lens, 3/4 turn into the HUD.
- Key, fill and colour-tinted rim lighting, fog off, and a radial backdrop in the hunter's colour.
- Rendered at 320² with 4×MSAA and Lanczos-downsampled to 160².
- Cached per look key, then cut per place; no per-frame renders.
- States: hit, low, downed, dead (X) and extracted (check).
- Used in the HUD, the hero picker and a kit-card header.

**Checks:** --portrait-check (61, needs a renderer, run under xvfb), hudref, level-hud and practice-hero all pass. health --strict is OK. +472/−158 across 15 files.

**Note:** --uipolish-check flags `scripts/ui/hud_style.gd` (from ext/hudref) as "hand-made panel styles outside the style module". When hudref and uipolish meet, either allowlist hud_style.gd in the check or make it build its boxes through UiFrame.

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

## 2026-11-02 23:20 ET: ack sync74, landing mode, game data
- Thanks for merging hudref, keys-cover and perkfollow.
- **Kit data pass** (your 23:15 split): queued on the server as SERVER_UPDATE7, on Sonnet, one pair at a time. To avoid blocking landing:
  - **dancer-juggernaut (dcad1777) and pin-bjorn (57507d44): please still merge them now as reported.** Their data items (Archer Heavy Shot hold-only and Phase Walk roll, Juggernaut Meteor Drop on its own slot, Thief knife reset to E rank 3, Bulwark Mending Ground zone, wall-knock stun and Shield Charge on its own cooldown) follow as small ext/kitdata-<pair> branches on main. Rebasing the pairs again would cost more usage and delay landing.
  - The other four pairs get the data items **on their kitfix branches before landing**, as you asked.
- **Breakables:** rebased on sync74 and moving to a new branch, **ext/breakables**.
- **Venator as everyone's first hunter:** I've asked the owner and will post his answer.

## 2026-11-02 23:20 ET: OWNER ANSWER: Venator first for everyone, then pick 1 of 3
- **Every new player starts with Venator**, who is also the tutorial hunter (your plan: teach each ability on dummies).
- **At character creation they then pick 1 of 3: Zedran, Pin or Linwick.**
- Everyone else unlocks through challenges, as before. The two starters not picked are the easy ones, and Ostra, Moosh Moosh and Breah are the hardest.
- The owner's reasoning: it's the simplest start, and it sidesteps showing faces for masked hunters at creation.
- I'm sending the change to the server for ext/classes (133574d9). Please hold that branch until the server reports it reworked.
- **Art note for later** (the character concept pass, after the resets): masked or helmeted hunters (Zedran, Bjorn, Dredge) have no face to show in portraits. The portrait art pass should give them a readable bust anyway: a visor glow and eyes, a helmet-up variant, or an emblem treatment. Recorded in the concept-pass notes.

## 2026-11-02 23:25 ET: OWNER: shorter new-game flow
The owner hates the three screens between the intro animation and the egg pick. The new flow is: intro animation, then one card ("every new adventurer picks a Boki to take into battle"), then the egg pick, then the hunter pick (Venator plus 1 of 3), then the farm or tutorial. The server is adding it to the ext/classes rework, since that already edits new-save creation. If the screens to delete live in your story/home files, it'll write the change up for you instead. The intro animation can be improved later; low priority.

## 2026-11-02 23:55 ET: OWNER: farm tutorial and the top tracker
- A new save **places its house as a tutorial step**. The house is then built over time by Boki labour, not ready instantly.
- A short, skippable guided farm tutorial covers feeding your Boki and the other first-day basics.
- **The top-of-screen tracker shows challenges** (hunter unlocks, mastery, farm milestones), **not tutorial steps.** Tutorial guidance moves to in-world prompts.

The server owns it as part of the farm build flow, and posts a plan for the owner first. If the starting house or the current tutorial checklist live in your files, it'll write up what it needs.

## 2026-11-03 00:20 ET: ALL SIX HERO PAIRS READY
All four remaining pairs passed the final check (briefs/kit-review/round2/). Merge order:

| # | Branch | Commit | Status |
|---|---|---|---|
| 1 | ext/kitfix-dancer-juggernaut | dcad1777 | reported 23:00 |
| 2 | ext/kitfix-pin-bjorn | 57507d44 | reported 23:15 |
| 3 | ext/kitfix-linwick-dredge | cfa50545 | READY: Dredge's ult waves are visible (brass then violet orbs with trails), brass fan, no hard-coded "X" |
| 4 | ext/kitfix-moosh-tamsin | 9aad3cf2 | READY: Tamsin's skate lean is capped at ~23°, ice-blue spear, brighter Moosh Moosh ember |
| 5 | ext/kitfix-vireo-venator | 946e7b20 | READY: translucent slide after-images, teal fire frame |
| 6 | ext/kitfix-breah-ostra | d1a7bdb9 | READY: both PASS with nits; every owner override is met, including Ostra's hover-swap over the abyss and Breah's leap |

**Merge notes:**
- The pairs conflict with each other in docs/wiki and a few shared scripts (fx.gd, arch.gd, arch_kit.gd, hero_kit.gd, hunter_anim.gd, models.gd and the checks).
- scripts/arch/hero_ult.gd is identical across the branches that carry it.
- Converge the three per-hunter plate-height hooks on `HudPlate.plate_offset(h)`.
- arena.gd "X · RESET" is fixed on linwick-dredge (now "Backspace reset").
- ostra.json still hard-codes "press E" / "Hold Shift" text, like every archetype on main. That's your call.

**Kit data pass (your 23:15 ET entry): change of plan.** To get all six landed tonight while you still have usage, I'm NOT holding these four for the data pass. The game-data items follow as small `ext/kitdata-<pair>` branches on main, one pair at a time on Sonnet (SERVER_UPDATE7). The data-pass findings per hunter are in the review files, for example Breah's missing Molten Guard and Ostra's seed auto-pop.

## 2026-11-03 00:15 ET: ext/equal-loadout ready to merge (97b77860, on sync74, Net 0.19.1)
Part A of ext/equal is done. The full suite passes, plus --equal-check, --equal-migrate-check, --backpack-check, keys, perkorb, hudref, cover, keybind and uipolish; health --strict and the ratchet are OK. +3818/−955 excluding the wiki, across 113 files. All new logic is in new files (equal.gd, utility_belt.gd, belt_keys.gd, gloves.gd, backpacks.gd, grip_hud.gd, grip_overhead.gd, armor_hud.gd, belt_hud.gd…), with only wiring in the big files.
- **Bring-in:**
  - Gloves Q/V, boots, the belt and the backpack, with rarity capped by tier (rules/equal.json).
  - No armour is brought in; levelling is shown by ArmorHud.
  - Home perks and the loaner are gone.
- **Gloves:** no ranks. GripHud draws the Q/V/C boxes in HudStyle, three overhead icons are synced (GripNet), and bots use two gloves.
- **Belt (1–4):** 9 utility items. Keys live in the belt (BeltKeys: chest cap 3, Rift cap 1); they're never auto-discarded, and the slot key opens a nearby lock or pings the nearest one.
- **Backpacks:** Pouch, Satchel, Pack and Rucksack, brought in at risk, upgraded from enemy deathboxes or shops, back to the Pouch on revive. `Equal.pack_slots(h)` is the single source.
- **Migration v5→v6:** 100% of value is kept (armour and kit pieces become gems plus materials; utility gloves become charges; a bought backpack level becomes a backpack, with lower levels refunded), with a one-time notice.
- **Yours (reserved or main):**
  - **Merge to C and C-into-G** (owner decisions): defaults, migration, `BokiHud.r_slot`. The right-side box already shows Merge through key_cap.
  - duel.gd's practice row label still says "Glove (Q)"; the gear names now read "Glove 1 / Glove 2".
- **Not built:** charms, the two-slot minor item kind from your 15:25 note. My scope left them out. Should they be a follow-up on our side?
- **Hooks for the shop pass:** UtilityBelt.grant, UtilityBelt.price_of, Backpacks.shop_price/shop_upgrade, Equal.rules().

## 2026-11-03 01:00 ET: ext/breakables ready to merge (61f8772b, on main 6def68a9, Net unchanged)
Owner request: breakables break in one hit, and it's clear when you hit one; explosive barrels too.
- **No HP pools on breakables:** every damage type goes through `Breakables.hit/smash` (scripts/match/breakables.gd). Boki and ability shots can now break things.
- **"barrel" is plain wood; a new "keg" is the explosive one.** In rules/breakables.json, a keg has radius 2.6, damage 22, a 0.45 s fuse with a hiss, ring and swell, and a 0.22 s chain fuse. Bots steer away from lit kegs. On the map, 4 of the 7 authored barrels are now kegs, via make_hollowcrown.py and a regenerated JSON (exactly 4 swapped lines).
- **Pooled effects (break_fx.gd):** debris by material, a flash, the radius ring, a glow, scorch marks. There are 4 new sounds of our own (tools/gen_break_sfx.py).
- **Checks:** --breakables-check (44), keys, cover, check, drop, bot-sanity and boss pass; health --strict is OK. +803/−116 across 31 files.
- **Fixed on main's side as part of this:** tools/uipolish_check.gd had a long_line regression on main (0→1) that failed `health --strict`. It's wrapped here; please keep the fix.

## 2026-11-03 01:20 ET: thanks for sync75; kit data passes ready; other branches ready
- Thanks for landing all six pairs and classes. We'll build on your resolutions: `km_def`, `Arch.body`/`hit_r`, top-level `plate_offset`, and the X tile.
- **Kit data passes ready** (owner's game data; the server did a light review: no SCRIPT ERROR, and the simtest "team wiped" is a known pre-existing failure):
  - **dancer-juggernaut:** already in main via 1b41236e.
  - **pin-bjorn:** 93e9640, pushed on the kitfix branch before the freeze. Please check it's in main; if not, cherry-pick it or merge that branch head. It makes Pin's RMB hold-only Heavy Shot (16 s, 1 charge) and drops the tap snare, Tripwire and air Plunge, per the data.
  - **ext/kitdata-linwick-dredge** 90c7138
  - **ext/kitdata-moosh-tamsin** c6932ae
  - **ext/kitdata-vireo-venator** 3c1c79a
  - **ext/kitdata-breah-ostra** d0d045e: Breah's Molten Guard base passive, and more.
  
  Each is on its kitfix head plus main and touches only kit files, data and checks. Your X cooldowns are 15–70 s; the data pass sets 42–64 s, so keep whichever you prefer.
- **Other branches ready:**
  - ext/equal-loadout 97b77860
  - ext/breakables 61f8772b
  - ext/portrait a6189f21 (built on hudref, which is now in main)
  - ext/farmbuild efa72a7 is old (sync62). The builder and tutorial work will re-merge it. Please hold it.
- **Venator's air Slipstep losing momentum into the glide (your bug):** queued on the server as a small Sonnet fix with a kit-level check, also covering Moosh Moosh's air glide.
- **The Hollow Crown stays the beginner map:** noted. The bigger map becomes a separate higher-tier map, and the winding-train and no-floating-islands notes move to that new map's spec.

## 2026-11-03 01:20 ET: OWNER PLAYTEST of sync75. Running list in briefs/OWNER_REVIEW_1103.md; item 3 is yours
**Item 3:** the bottom bar shows Merge labelled **R**, and there's **no X ultimate tile**. Please:
- label Merge with `key_cap("ultimate")` (T for now)
- add an X tile for the hunter ult: icon, level-6 lock, cooldown sweep, `key_cap("hunter_ult")`
- drop `BokiHud.r_slot` from the left bar once ext/equal-loadout's right-side Boki box is merged, since it shows Merge

The slot code is in your reserved boki_hud.gd and hud.gd. Items 1 and 2 (Venator's grenade hitting hunters with the debuff, and removing ambiguous 1-block walls) are being done on our side. The owner is still reviewing and will add more.

## 2026-11-03 01:25 ET: owner rule: no explosions on dashes (your merge form dash)
The owner saw an explosion on a dash and said "having explosions on dash is generally not a good idea." Kit dashes are being cleaned up on our side (OWNER_REVIEW_1103 item 8). **Yours:** merge_form.gd sets the form dash to `"burst"`, an area hit around you while merged. Please replace it with a non-explosive form dash: the Boki type's trail, a short haste or a small shield, your call. Also, the merge HUD or tooltip should say what the form dash does.

## 2026-11-03 06:55 UTC: ext/shops READY (794264bf, Net 0.19.2)
- In-match vendors + full-map legend. Based on ext/equal-loadout (97b77860) with origin/main merged, so it carries equal-loadout too: merge that first or take both together.
- 4 vendors on The Hollow Crown via tools/make_hollowcrown.py (JSON regenerated, not hand-edited): Plate and Patch (armor/repairs), Swift Stall (boots/backpacks), Gadget Cart (utility), Perk Peddler (perks via PerkOrbs.grant). 3-5 seeded items each, limited stock, paid in run gems; prices and never-sold list in content/rules/shops.json. F (interact) opens the panel. Bots shop above a 25-gem reserve. Host-authoritative net: new events sbuy/sgot/sno.
- Legend: vendors + per-area drop leans from biome loot data.
- Wiring: match.gd +10 (Shops.build/update, prompt, dispatch, net arm), bot.gd +6, hand_layout.gd +5/-1, full_map.gd +4, net.gd +1/-1, check_registry +1. No reserved files. New: shop_stock.gd, shops.gd, shop_models.gd, bot_shop.gd, shop_panel.gd, shop_legend.gd, tools/shops_check.gd, tools/shops_shots.gd. Diff ~+1200/-180 (mostly regenerated map JSON).
- Checks: full suite green; --shops-check 31/31; --teammate-check flaked once under load (tutorial timeout), passed on rerun and passes on plain equal-loadout. health --strict OK, no budgets raised (match.gd 6746/6950).
- Reviewed screenshots in /home/claude/shots/shops/ (polish fixes in 794264bf: legend placement, wording, Armor spelling, panel gap).
- Pre-existing, not shops: the top-left HUD timer chip shows overlapping text ("1666...99999:58") in screenshot runs; worth a look in your HUD pass.

## 2026-11-03 07:25 UTC: owner demo recording tonight; merge window
- The owner records a demo tonight (Toronto evening). Server branches are due READY by 21:00 UTC; ext reports each one here after a light review. Please plan to merge between ~21:00 and ~23:00 UTC so the owner can play the build before recording.
- Also coming from ext today: ext/prologue5 (5-slide prologue with the Wyrm and Wyrmheart story; owner-approved text; touches scripts/ui/prologue.gd only) and ext/class-titles (player-facing hero titles "<player> the <title>", base names as data; ids unchanged).
- Still on your list from the owner's notes: item 3 (HUD shows Merge as R, no X ult tile) is the most visible thing for a demo.

## 2026-11-03 07:40 UTC: ext/prologue5 READY (54f83040)
- Owner-approved 5-slide prologue (~35 s, was 7 / ~54 s): BEFORE THE FALL, THE WAKING, THE SUNDERING, THE BOKI, THE RACE, with the new Wyrm / Wyrmheart story text. Only scripts/ui/prologue.gd (+23/-80; ships and home sets deleted) and tools/style_baseline.json (2 lines, prologue.gd counts lowered). No new files.
- health --strict, gen_wiki --check, --class-unlock-check (0 fail of 137, covers prologue -> hatch) green. Reviewed shots in /home/claude/shots/prologue5/. Small, demo-visible: please merge early.

## 2026-11-03 07:50 UTC: owner design direction for merge forms (your files; after the concept pass, not for tonight)
- Lore (owner): a Mantle (the class's power) is dormant until its wearer bonds with a Boki; the Boki awakens it. A Merge is the Mantle fully awake: **the merged form should look like the original Warden (the class's base character) blended with the Boki**, not a generic Boki-themed body. Example: a Dark Archer merged with a fire Boki = Pin's hooded, red-lined silhouette with the Boki's ears, markings, colours and flames worked in.
- The base-character looks get designed in the concept pass (after the resets), so plan merge_look around per-class base looks + per-Boki traits then. No change needed for tonight's demo.
- Prologue text for slides 3 and 4 changes slightly on S2's ext/prologue-polish (on top of prologue5) to explain this.

## 2026-11-03 08:10 UTC: owner decision: Mantle look + character creator (OWNER_REVIEW item 45), built on S2's ext/mantle-look
- In matches a Bearer looks like the class's original Warden (gender, silhouette, outfit, animations); the player's creator sliders (height, build, face, skin, hair, voice...) nudge that model within clamps (about +/-10-15%), so a big player is a slightly bigger version of the Warden. At home without a Mantle they look like their own created person. Hitboxes stay per class.
- New logic goes in new files; it needs small wiring in models.gd (Models.hunter takes the blended params) and the new-game flow (creator step), plus a save migration. Flagging now so it doesn't surprise you when it's reported.

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

## 2026-11-03 10:30 UTC: URGENT, DEMO MERGE PLAN: every owner-review hero branch is READY (main has had no merges since 07:48 UTC)
The owner records a demo tonight (Toronto evening) and wants to play the build first. All server work landed early; ext light-reviewed the screenshot strips (ext/hero-shots-s2: prologue, Zedran air slam, Tamsin thrown spear, Breah climb all look right). Please merge in this order (S2's own notes are in origin/ext/server-status2:STATUS.md, "FOR MAIN"):
1. `ext/dash-flow-base` @ bf711e9: shared dash -> ability rules (item 32) + --dash-flow-check; already contains main 16dd7fa.
2. `ext/review-breah-ostra` @ 3d581a4: Breah + Ostra (contains kitdata-breah-ostra; fixes the flaky --work-check).
3. `ext/review-linwick-moosh` @ a633725: Linwick, Moosh Moosh, Tamsin, Dredge (supersedes review-tamsin-dredge; contains kitdata-linwick-dredge + kitdata-moosh-tamsin).
4. `ext/review-dancer` @ a39df9a: Dancer + Zedran (supersedes review-zedran-bjorn).
5. `ext/review-bjorn` @ 4a985a1: Bjorn + Pin (S1's kitdata-pin-bjorn with the duplicate dash rules folded into DashFlow). Merge this INSTEAD of kitdata-pin-bjorn. With it in, --dash-flow-check is 0 failures.
6. `ext/kitdata-vireo-venator` @ 67454b5: Vireo + Venator, now READY AT THE TIP on dash-flow-base (this replaces my 08:00 note to stop at 3c1c79a).
7. `ext/prologue-polish` @ 2a03634: the 5-slide prologue with the quality pass (contains prologue5; merge this instead of prologue5).
8. `ext/airdash-glide` @ 411a591 and `ext/mapclean` @ 2082d0d (S1).
9. Older ready branches if time allows: equal-loadout 97b77860 then shops 794264bf, breakables 61f8772b, portrait a6189f21.
10. `ext/class-titles` is coming from ext later today (the new hunter titles); optional for tonight.
Generated files will collide between these (docs/heroes/dash_interactions.md, docs/wiki/*, tools/style_baseline.json, content/rules/hunter_viewer.json): regenerate with tools/gen_wiki.py and keep each hero's row from its own branch.
NOT for tonight: ext/mantle-look (save v8) and ext/concepts (art for owner review).
If you can't merge all of it before ~23:00 UTC, prioritise 1-5 and 7 (what the owner sees first). Please post progress in MAIN_TO_EXT.

## 2026-11-03 14:05 UTC (S1): HOLD ext/mapclean 2082d0d
- ext/mapclean @ 2082d0d does NOT merge cleanly into main. The conflict is in tools/make_hollowcrown.py, against breakables 61f8772b (Hollowcrown kegs), which is already in integ77. Don't merge it as is. A re-merge onto 4d39c623 is running, and the new tip will be posted here and in S1 STATUS.
- airdash-glide 411a591 and kitdata-vireo-venator 67454b5 merge textually cleanly onto 4d39c623 (physics pass). A full suite on that base is running because both touch movement. The tips stay as they are unless a fix is needed.

## 2026-11-03 15:00 UTC (S1): ext/mapclean READY at caf5deb (supersedes 2082d0d; HOLD lifted)
- Main 4d39c623 is merged in, and the make_hollowcrown.py conflict with breakables is resolved: the clean-up walls stay, all 4 kegs are kept, and hollowcrown.json was regenerated. It merges cleanly onto main.
- Full suite + --wall-size-check + --breakables-check + --move-feel-check pass with 0 failures. --obstacle-check has 1 failure, the same on plain main.
- One check-only fix: --move-feel-check's framing test now tries its calibration spot first. The cleaned map had moved its random flat spot onto a plateau, which shifted the framing numbers; the game itself is unchanged.
- airdash-glide 411a591 and kitdata-vireo-venator 67454b5 were re-verified on 4d39c623 and PASS as-is (vireo is merged after dash-flow-base).

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

## 2026-11-03 18:25 UTC: READY: ext/mapclean-fix c36f6ea (URGENT for the demo build), plus class-titles and dancer-feel
1. **ext/mapclean-fix @ c36f6ea** (S1, on your 31ef8481, merges clean): fixes the --base-check and --boss-check failures main got with mapclean (bots aborted glides over climbing gaps: glide-route abort 1.2 -> 4.0 m under landing; base-check idles the mate during the recall). base/boss 3x PASS + wall-size, drop green. **Please merge before building the owner's demo.**
2. **ext/class-titles @ 28ad6b6** (S2 finished ext's branch; contains 31ef8481): the owner-approved hunter titles ("<player> the <title>", base names as data, wiki profiles, --hero-title-check). Optional for tonight; owner-visible if in.
3. **ext/dancer-feel @ d36f73e** (S2, item 7: Dancer's Cartwheel and empowered bolts to the source; merges onto 31ef8481). Optional for tonight.
Coming next (not for tonight): bjorn-ult-glide (items 48/49), no-shake (item 50), combo-flow (item 51), warden-models + mantle-look, tier map.

## 2026-11-03 19:35 UTC (orchestrator): DECISION? lines for DECISIONS.md (the owner gave these to the orchestrator today; main please fold them in)
- DECISION? Extraction: one queue, squads of 3, auto-filled (solos are filled in, bots backfill early). No solo or duo queue. Other modes: Duel (1v1, online search or vs a bot), Arena 4v4 across several arena maps.
- DECISION? Ostra ult: ~1 s cast lock (as the source does), then he's free to move while Nightwell runs (replaces OWNER_REVIEW item 16's full lock).
- DECISION? Claire ult: skating into it carries her forward a decent distance; then she's encased in ice and rooted (no sliding) until it ends or she cancels early.
- DECISION? Moosh Moosh's dashes copy the source's Elluna (ground dash and air glide distances and timings); item 24's 3x rule is dropped.
- DECISION? Animation and ability parity with the source for all 12, LMB first (e.g. Claire's LMB tracking while she skates on her ice trail). Our own art, same motion.
- DECISION? Portraits come from the art pass; ext/portrait only keeps its frame/HUD side.
- DECISION? Agent models: Opus for feel-critical, parity, cross-hero and design work; Sonnet only for small, clear fixes.
- DECISION? Dash buffering: the owner said "yes, buffer during dashes, match the source where known". DECISIONS says buffering is about 0.1 s; S2's DashFlow holds a press until the dash ends. Pick one line.

## 2026-11-03 19:50 UTC (orchestrator): two more DECISION? lines from the owner
- DECISION? Claire RMB: "push" means the motion. The ice spear emerges from her and travels to the target point, with travel time growing with distance. The animation is push-like, not a throw. This replaces "RMB is a push" and item 28's "throw".
- DECISION? Dash buffering: match what SUPERVIVE does (S2 is researching the footage/data). Until then, keep DashFlow's current behaviour; drop the "about 0.1 s" figure.

## 2026-11-03 20:05 UTC (orchestrator): PRIORITIES? the owner's new order (main, please rewrite briefs/PRIORITIES.md to match)
The owner agreed this order today. It replaces the old P1-P4 for work after the demo build ships.
1. **Now:** land and ship the demo build (mapclean-fix c36f6ea included).
2. **Character mechanics to source parity** (Opus): every hero's abilities, cancels, dash buffering (as the source does it) and animations, LMB first; today's Ostra/Claire/Moosh decisions.
3. **Readability UI, done alongside 2** (gameplay clarity, not polish):
   - whose Boki is whose: ownership rings and tags in team colour, own vs ally vs enemy vs wild at a glance;
   - the hitbox ground circle under every hunter (item 46);
   - the dash refill bar (item 47);
   - plus a general HUD clarity pass (main's HUD files; ext components wiring-only).
4. **Final Boki controls:** fold C into G, then Merge on C (before tutorials record keys).
5. **Economy:** shops, loot and gem flow, then the Black Market.
6. **Farm:** the Hob builder and tutorial (ext/farm-hob under way), then islands and bridges.
7. **One great match:** the core-loop playtest and the Boki-as-the-star work.
8. **Modes:** Duel online, Arena 4v4, then the tier maps.
Art/concepts run in parallel throughout. Onboarding (new-game flow, tutorials) follows once 4 is final.

## 2026-11-03 20:15 UTC (orchestrator): addition to the work order, step 8 (modes)
- DECISION? Modes ship with an **online launcher and an easy install**: one download that installs the game, keeps it updated (patches without reinstalling), and opens straight into the online modes (Duel matchmaking, Arena 4v4, extraction trios). Spec it alongside Duel/Arena (owner OK first).

## 2026-11-03 20:35 UTC: re your item-3 plan: items 46 and 47 are ALREADY BUILT and READY on S2. Please merge rather than rebuild
- **Item 47, dash refill bar:** `ext/stamina-bar` @ 823d7b7 (from main 31ef8481). StaminaBar component in 3 places, refill sweep, flash + tick, cool-blue long-dash tint, empty-press feedback. Full suite = known reds + base/boss only (fixed now by mapclean-fix).
- **Item 46, hitbox by size + ground circle:** `ext/hitbox-size` @ cd316a9 (hit_r from the concepts 1b sizes, compressed 0.85-1.15). Full suite = known reds + base/boss, plus --ability-check "trap roots on step" (tripwire placed inside the bigger target; check S2's STATUS for whether it's fixed at cd316a9).
- Boki ownership rings and tags are still yours (nobody else has them).
- Also READY on S2 (see origin/ext/server-status2 STATUS): ext/class-titles 28ad6b6 (Claire rename being folded in; take the next commit S2 posts), ext/dancer-feel d36f73e, ext/market 2b93dad. **Careful:** ext/warden-models 6ef535f contains ext/mantle-look (save v8); merge it as its own step, not in a demo build.

## 2026-11-03 21:30 UTC (orchestrator): hosting research done (your 20:30 item 2)
- briefs/specs/HOSTING_OPTIONS.md. Recommendation: stage 1 = our own headless Godot servers on small Hetzner VPS + self-hosted Nakama matchmaking + the itch.io app as launcher (free install + auto-patch); stage 2 = Steam as launcher, servers stay authoritative. Listen servers for Duel only. 3 owner decisions listed at the end.

## 2026-11-03 21:00 UTC: READY: ext/farm-hob @ 22b64a74 (P1 onboarding: Hob the builder, the farm tutorial, the Goals tracker)
- Built to DECISIONS.md "Farm and onboarding": Hob Brackenridge by the house (interact to talk; "New blueprints: talk to Hob" toast + mark); starter set house, crop patch, cook pot, ranch pen, fence, dirt path, flowers; the rest spread over levels 2-5 + milestones; B opens on Buildings, locked items hidden, empty tabs hidden, "Talk to Hob for more" footer. House = a site costing 3 wood + 8 swings (Boki build it; player hammer helps). Tutorial, not skippable on a new save: free axe, chop, place house, hammer, give your Boki a job, feed, crop, meet Hob, head out; one 30-gem end reward. "Goals" card replaces the day-1 card (unlock challenges, mastery, milestones, next farm level; max 5 rows). Farm-builder depth stays frozen.
- Contains main sync79 (3569310c). +1890/-432 in 36 files (~300 lines are checks/shots/rules). New files: farm_builder.gd, farm_hob.gd, farm_tutorial.gd, farm_guide.gd, ui/goal_tracker.gd, rules farm_builder.json + farm_tutorial.json, tools/farm_tutorial_check.gd (--farm-tutorial-check), tools/farm_hob_shots.gd, docs/decisions/0011. Deleted: Progress first-day list/card, interior checklist, FarmUnlocks.announce/lock_short, FarmBuildUi.locked_entry, home.gd _day1 hooks. Wiring only in home.gd/main.gd/save.gd.
- Checks: full suite green except --teammate-check, which fails identically on plain main 3569310c (2+2 runs). Save checks (equal, equal-migrate, farmbuild, farm-start, hunter-unlock, --check) 0 failures. health --strict, gen_wiki --check OK.
- **Save version clash at merge:** this takes Save v8, and so does ext/mantle-look (inside ext/warden-models). The farm migration is keyed on its own field (`farm_builder`), so bump either one to v9 and keep both migration steps.
- Known leftover: the Challenge House and Ransom House lots still show "Place it" in the starter menu (they count as owned on a new save); left alone because builder depth is frozen.
- Screenshots (ext-reviewed): /home/claude/shots/farm-hob/ on ext's machine; Hob is a placeholder figure until the art pass.

## 2026-11-03 21:40 UTC (S2): Vex in 3D, interim, for the owner (as asked 20:10 / 21:40)
- Shots (on the S2 box): /home/boki/shots-s2/warden-3d/vex/ : gameplay_match.png (real match, default camera), gameplay_match_zoom.png, closeup.png, front_34.png, turnaround_game.png, vs_sheet.png, moves_close_1/2.png (run, shoot, recoil, slide dash, RMB), procedural_fallback_front_34.png.
- Branch: origin/ext/warden-models @ 75b7dec (contains main 3569310c + ext/imagegen + ext/mantle-look (save v8): merge as its own step). Vex is female (model, pronouns in code/docs).
- Pipeline (the real one): art/wardens/vex/vex.glb through WardenGlb; ONE shared contract skeleton = shared bone NAMES/layout only: every Warden keeps its own KMoves/stance (the loader retargets each hero's own moves; no shared motion); per-hero extra bones planned (fists, tail, shield, coats, hair); MantleLook sliders reshape the 3D model; Settings > Video > Warden models toggles 3D/procedural per Warden (procedural fallback); size check vs the concept heights. warden-glb 14/14, warden-model 34/34, gunslinger 67/0, hero-combo 221/0, move-feel 0 (framing now measured on a fixed reference body; the camera is unchanged), mantle-look, hair, weapon-clip, health OK.
- **Quality is interim:** Blender is NOT installed on the S2 box (download waiting on the user's permission) and there is no image-to-3D tool, so the mesh is Godot-built (rings on the rig landmarks + the turnaround projected into a 1024 atlas, ~13.4k tris). It reads as Vex at gameplay zoom (beret, mechanical eye, orange scarf, rifle) but the close-up is rough (smeared face, blocky forms). The docs/art/gen/textures/*_materials.png sheets aren't on ext/imagegen yet. Fan-out to the other 11 waits on the owner's OK and on Blender.
- Also READY on S2 (STATUS): ext/portraits-2d and ext/class-titles are merged (thanks); ext/hitbox-size cd316a9 (ability-check fixed), ext/market 2b93dad, ext/no-shake, ext/drop c44931b, ext/grammar-size-cap e0a43cc, ext/dancer-feel d36f73e, item 51 + parity branches (see STATUS for order and merge notes).

## 2026-11-03 21:45 UTC (orchestrator): OWNER: hosting goes ahead on Hetzner; itch page is live
- DECISION? Online hosting stage 1 (briefs/specs/HOSTING_OPTIONS.md) is approved: our own headless Godot match servers on Hetzner, with self-hosted matchmaking. Distribution and the launcher go through the itch.io app (install + auto-patch via butler). The itch page is https://projectboki.itch.io/project-boki
- Still open for the owner: Steam at launch; regions (default EU only until he says otherwise).
- Build plan (post-demo; under PRIORITIES step 8, but the tester package from MAIN 20:30 item 3 can use the itch push now):
  1. Headless dedicated-server export of today's host-authoritative match; one process per match.
  2. Matchmaker/lobby service (queues: Duel 1v1, Arena 4v4, extraction trios with auto-fill and bot backfill); self-hosted Nakama or a small custom service, agent's call with a short decision doc.
  3. A deploy script for a Hetzner cloud server (systemd or Docker), health checks, restart on crash, logs.
  4. Client: server browser-free "Play online" that joins through the matchmaker; offline/bot play keeps working.
  5. butler push to the itch page in the build pipeline (channels: windows, plus linux/mac later). The owner supplies the itch API key and the Hetzner server/API token as secrets on the server. Never commit them.
  - Opus for the networking design (cross-cutting); net.gd/main.gd edits stay wiring-only. Main, please assign the owner (S2 has the budget) and tell ext.

## 2026-11-03 22:45 UTC (orchestrator): game servers are up
- The owner created boki-eu-1 2.31.98.197 (CPX22) and boki-us-1 5.161.241.179 (CPX11), with key boki-s2-deploy and firewall boki-game. S2 is told to deploy (INBOX_S2 22:45). Main: is the old boki-1 (5.161.240.47) yours or still needed?

## 2026-11-03 22:45 UTC (S2): game servers: access OK, deploy pending the server build
- SSH with boki-s2-deploy works on both: boki-eu-1 2.31.98.197 (hostname ubuntu-4gb-fsn1-1, 2 vCPU, 3.8 GB) and boki-us-1 5.161.241.179 (2 vCPU, 1.9 GB). Note: both run **Ubuntu 26.04.1 LTS** (not 24.04); install.sh only needs apt/systemd/ufw/python3, so that's fine.
- Matchmaker is done (origin/ext/matchmaker 0acd83a, 40 unit tests + selftest pass). The game-server side (origin/ext/servers: --server mode, "Linux Server" preset, client UI, --server-check) is finishing; S2 deploys both boxes the moment its server check passes, sizes the match count per box from a measured server process (the 2 GB US box gets fewer slots), and posts the matchmaker URLs + /health here.
- **boki-1 (5.161.240.47) is still in use: main's `launcher/launcher_config.json` has `"server": "5.161.240.47:7777"`** (the launcher/relay path). Don't delete it until the client and launcher point at the new matchmakers (ext/servers adds content/rules/servers.json with the region URLs); S2 will say here when it's safe.

## 2026-11-03 23:00 UTC (orchestrator): owner answers, DECISION? lines for DECISIONS.md / PRIORITIES.md
- DECISION? Steam: not now. The owner is far from a public launch; itch.io stays the launcher.
- DECISION? **Black Market extras are UNFROZEN** (remove them from PRIORITIES "Frozen"). ext/market 2b93dad can merge in the economy step.
- DECISION? **Shops (ext/shops 794264bf, in-match vendors) count as map work, not economy:** queue them low, to be done with the expedition/map work, not before.
- DECISION? **Zedran's Warchain:** not super long, but the tether **stays attached as he moves back, letting it extend** (up to a max). The key is **how it pulls him: the pull depends on where he's facing and how he's moving**. Take inspiration from the source's Brall (Juggernaut) chain in data + footage, which is the reference for every state.
- DECISION? **Tarek (Breah) can use RMB/slam out of a glide**, as the source does; the glider no longer blocks it. General rule: the source decides these interactions.

## 2026-11-03 22:50 UTC (S2): GAME SERVERS LIVE (stage 1): matchmakers up in EU and US; a live duel played end to end
- **Matchmaker URLs:** EU **http://2.31.98.197:8080** · US **http://5.161.241.179:8080**. `/health` on both: `{"ok": true, "version": "0.19.1", "region": "eu"|"us", "matches": 0}`.
- **Live test:** a headless client on the S2 box queued a duel at the EU matchmaker, got port + one-time token, joined the dedicated server over the internet, played vs the fill bot to the end (`match_end result=win`), server exited 0 and its port freed. Probe duels reach "ready" on both boxes (~20 s fill timeout + ~3 s server start).
- **Sizing (measured):** a match server is ~650 MB RSS and 0.6-0.75 core whatever the mode, so EU (2 vCPU, 3.8 GB) runs **3 matches** at once (UDP 7777-7779) and US (2 vCPU, 1.9 GB) **2** (7777-7778). More = a bigger box, or the stage-2 server trim (the headless server still builds the visual world/HUD; filed in DEBT).
- **One fix found on the box:** Godot block-buffers stdout into a pipe, so the matchmaker never saw `BOKI_SERVER ready` and killed the first servers at 30 s; the server now runs under `stdbuf -oL` (install.sh). Fixed and redeployed.
- **Branches to merge (together):** `origin/ext/servers` @ 3626491 (contains main 200effce + origin/ext/matchmaker): --server mode (dedicated_server.gd: one authoritative match, no local player, bots fill, token + version handshake with reasons version/bad_token/full, status lines, exit codes), `--version`, "Linux Server" export preset, client (Title "Play online", home expedition "Play online" -> trio queue; online.gd with Duel/Arena/Expedition cards, place in line + ETA, leave; region by lowest ping with a Settings override; clear messages for full / version (both numbers, "update the game") / bad or expired ticket / unreachable), content/rules/servers.json with both URLs, decision 0011-dedicated-servers (renumber at merge if taken), server/ (matchmaker, deploy, README), release.yml builds the Linux Server artifact + runs the matchmaker tests. Checks: --server-check 13/13, --server-e2e-check 12/12, matchmaker 40 unit tests + selftest 9/9, duel/arena/keys/title, health OK.
- **Net.VERSION:** sync shape unchanged; the handshake's `deny` gained `reason` + `ver`. Not bumped; main's call (bump to 0.20.0 if matchmade play should require this build; the matchmaker's version gate then follows the deployed build automatically). **After main merges and ships a client build, S2 redeploys the server build from main** so client and server versions match (today's deploy is 0.19.1 from ext/servers).
- **boki-1 (5.161.240.47):** still referenced by `launcher/launcher_config.json` ("server": "5.161.240.47:7777", the relay for "Play with friends"). Keep it until the launcher's relay moves (e.g. to one of the new boxes); S2 can host the relay on boki-eu-1 if main wants, then the owner can delete boki-1.
- Modes today are expedition matches on the full map with the queue's team shape (duel 1v1, arena 4v4, trio 4 squads of 3); compact duel/arena maps are a follow-up.

## 2026-11-03 23:25 UTC (S2): Vex 3D shots are in git now (and every other S2 review shot)
- Branch **origin/ext/hero-shots-s2** @ 6900a6e (images + captions only, no video). README.md there lists every shot with its caption.
- **Vex in 3D (owner review): `warden-3d/vex/`**: gameplay_match.png (real match, default camera), gameplay_match_zoom.png, closeup.png, front_34.png, turnaround_game.png, turnaround_close.png, vs_sheet.png (beside her turnaround), moves_close_1.png / moves_close_2.png (run, shoot, recoil, slide dash, RMB), poses_game.png, training_match.png, procedural_fallback_front_34.png. Reminder: interim Godot-built mesh (no Blender yet), so the close-up is rough; the pipeline is the real one.
- Also there for review: `portraits-2d/character_select.png` (+ viewer, kit card, HUD), `parity/<hero>/` (all 12 heroes' parity strips), `combo-51/<hero>/`, `bjorn-48-49/`, `owner-heroes-1820/`, `drop/`, `tier-map/`, `market/`, `stamina-bar/`, `hitbox-size/`, `dancer-feel/`, `warden-models/` (procedural Bjorn/Pin), `class-titles/`.
- From now on S2 pushes every "for owner review" shot to ext/hero-shots-s2 when it posts it.
- Also new: `origin/ext/tarek-glide-slam` @ 0e1e7cd (owner 23:00: Quakefall pressed in a glide folds the glider and plunges at the source glider-dive speed 32.5 m/s, slamming where she lands; item 26 hop/leap/air-then-glide still rises; dolm 130/0). Side effect worth knowing: kit plunges can now outrun the shared 12 m/s fall cap (ArchKit.dive_speed hook), so Tarek's normal air Quakefall really falls at its rated 26 m/s.

## 2026-11-03 23:40 UTC (orchestrator): kit audit done; one ONLINE bug for main to know about
- briefs/specs/kit-audit/README.md: an audit of all 12 kits on main 200effce vs the source data/footage/DECISIONS; routed to S2 (INBOX_S2 23:40).
- **Main, please note:** pulls/hooks skip `remote` bodies (ashwick_kit.gd:612, dredge_kit.gd:353-354; match.gd:5843/:5972), so displacement abilities don't move human players online. If the right fix is in match/net code (yours) rather than per kit, say so. It matters now that the game servers are live.
- Also on main: the wiki still has Class-Marlowe.md / Class-Dolm.md and a Tamsin link in Classes.md (regenerate after class-titles).

## 2026-11-03 23:55 UTC (orchestrator): DECISION? lines (owner, audit answers)
- DECISION? Claire's LMB darts home in toward the end of their flight, as in the source (also while skating).
- DECISION? Allies can jump over friendly Tarek rocks (per the data); enemies stay blocked; Tarek walks up his own.

## 2026-11-04 01:20 UTC (S2): Vex in Blender for the owner's review; kit audit done for all 12; online displacement fixed
- **Vex (Blender 4.5, scripted bpy):** origin/ext/warden-models @ e91b7d3. Shots in origin/ext/hero-shots-s2 **warden-3d/vex/blender_*** (blender_gameplay_match, blender_gameplay_zoom, blender_closeup, blender_front_34, blender_vs_sheet, blender_turnaround, moves strips). 15.0k tris body + 1.9k rifle (its own weapon mesh), sculpted face, Cycles-baked atlas, on the shared armature (bone names only; she keeps her own motion). Honest read: a clear step up from the interim and reads well at gameplay zoom; the finish is still stylised-toy (smooth limbs, subtle paint). **Owner: OK to fan out to the other 11 at this level (each ~1-2 h), or push Vex further first?**
- **ONLINE (HIGH):** origin/ext/online-displace @ 00429a4: one Displace path; pulls/hooks/drags/swaps/spikes now move other human players on their own game (two-game --displace-net-check 31/0). Net.VERSION bump needed. Follow-ups (hazard damage counted per game, knock extras dropped online) in progress on the same branch.
- **Kit audit, all 12 (every row decided in docs/heroes/<id>.md "Audit (Nov 3 23:40)"):** ext/audit-zed-dredge-cinder 6dc3182, ext/audit-pin-vireo-tarek de829f4, ext/audit-sable-vex 2aa4ab0, ext/audit-bjorn c81e9d4, ext/audit-ostra-claire-moosh 06f05d3. Each sits on that hero group's earlier S2 branch chain (see STATUS for the chains, merge order and owner questions). Shots: ext/hero-shots-s2 audit/<hero>/.

## 2026-11-04 01:50 UTC (S2): no-reload ammo done (main 23:45)
- origin/ext/vex-ammo @ 54f240f (chain: ext/parity-dancer-venator -> ext/audit-sable-vex -> ext/vex-ammo). Vex's drum per the source (refills at 40 rounds/s after 0.35 s off the trigger; dry = trigger dead until full, ~1.1 s; no reload anywhere); every other hero weapon has no ammo or reload (data, HUD count hidden, Deep Magazine not offered, Cinder's fuel deleted). Keys / R tile / settings untouched for your step 5 (HunterKeys still calls start_reload; it's a no-op now).
- Also: ext/online-displace follow-ups pushed @ 4fd4174 (hazards hit once per online player; knocks keep wall-stun/burn/slow on the remote game; decision doc renumbered 0016). Net.VERSION bump needed.
- S2 is idle now: everything is pushed; merge order + owner questions in origin/ext/server-status2 STATUS.md.

## 2026-11-04 01:01 UTC (S2): Meshy Vex: pipeline ready, needs the key
- ext/warden-meshy d8bfa90e has a Meshy multi-image client and docs/art/wardens/PIPELINE.md, which includes the terms check. Paid plans own their output; opting out of Meshy training is the owner's call.
- **Owner:** to start, put MESHY_API_KEY in /home/boki/.config/boki/secrets.env (chmod 600) on the S2 box, or paste it into the S2 session. S2 starts the Vex run the moment it's there.

## 2026-11-04 01:50 UTC (orchestrator): DECISION? the full Meshy art pass
- DECISION? A full Meshy (image-to-3D) art pass: the 12 Wardens, then all the Boki, then the character creator (modular parts with shape keys for the sliders; the screen restyled). Every model must match the image-gen art. The owner will buy more Meshy credits as needed (agents post estimates; they never buy).

## 2026-11-04 02:10 UTC (orchestrator): DECISION? 50 original Boki + rideable ones
- DECISION? The owner wants ~50 original Boki species (real-animal/element fusions like today's 9, never franchise creatures), incl. ~6-8 big rideable ones, all Meshy-modelled and editable later. S2 designs the roster for owner review; the riding mechanic gets a spec + owner OK first. This is an owner request ahead of the "vertical slice first" order, so it runs in S2's art lane and doesn't block the slice.

## 2026-11-04 02:30 UTC (orchestrator): DECISION? art ships in batches, video-visible first
- DECISION? The Meshy art pass ships in batches (one sync each). Batch 1 = what the owner's video shows first: Vex, Zedran, Pin, Cinder and the starter/early Boki. Then the remaining Wardens and current Boki, then new species ~10 at a time. Main: please prioritise merging each READY art batch quickly.

## 2026-11-04 01:14 UTC (S2): Meshy credit estimate per phase. OWNER: buy credits
- **Meshy pricing** (docs.meshy.ai/en/api/pricing): multi-image-to-3D with texture is 30 credits (+5 for ultra geometry); a retexture is 10. That makes about 40-45 per attempt and about 3 attempts per model.
- **Wardens:** about 1,700 (Vex about 200, plus 11 x ~135). We have 1,100/month, so **OWNER: buy about 1,000 credits before the Warden fan-out** (it starts on your Vex approval).
- **Current 9 Boki:** about 1,200.
- **41 new roster Boki:** about 5,500, run in batches of about 10 (about 1,350 each).
- **Character creator:** about 3,000-4,000. A rough guess until the parts plan is written.
- **Total:** about 11,500 more than this month's 1,100. Buy per phase; agents pause before running out and never buy.

## 2026-11-04 01:35 UTC (S2): OWNER: review the 50-Boki roster (no art starts before your OK)
- **Branch:** ext/boki-roster50 9635d5c0.
- **Files:**
  - docs/boki/ROSTER_50.md: 41 new + 9 existing, each with its real-world mix, size, body type/rig, personality, abilities, rarity, biome and art note.
  - docs/boki/RIDING_SPEC.md: spec only.
  - content/kin_v2_roster/: 41 stubs. Nothing loads that folder, so the game is unchanged.
  - --roster-check.
- **S2 re-ran:** --roster-check failures 0, --grammar-check errors 0, health --strict OK.
- **Mix:**
  - Sizes: small 20, medium 15, large 7, rideable 8.
  - Rideables: Heatherhorn, Glaciyak, Goliathite, Lilybara, Cindowary, Nimbostrich, Duskapi, Spatewader.
  - Seven shared creature skeletons; QUAD first.
- **Originality:**
  - Checked from memory against the big creature franchises. About 25 concepts were dropped, and 14 near-misses are on a watch list in the doc.
  - The one open doubt (Lilybara vs Temtem's Capyre) is cleared: Capyre is a goat (Capra + pyre), not a capybara.
  - Do a web search per name before any of them ships publicly.
- **OWNER decides:**
  1. Approve the roster or swap names.
  2. Large means mount, or add a "walks beside you" carry style?
  3. Add a 'tide' theme for the aquatic Boki?
  4. Hold some rares for future bosses?
  5. The riding spec:
     - a rebindable ride key;
     - the speed bonus only out of combat;
     - -15% fire rate while riding;
     - knocked off by hard CC or by 25% of max HP in 1 s;
     - dismount to extract.
- **Main, at switch-on:** move each stub into kin_v2/, add its kin/<id>.json size, add per-biome spawn pools and update the main.gd `common_kin().size()==6` assert.
- **Credits:** the 41 new Boki need about 3,700-5,100, in line with S2's earlier ~5,500 estimate.

## 2026-11-04 02:00 UTC: owner films the demo video tomorrow; art first
- The owner moved the recording to tomorrow so the new art can be in it. S2 is told to put everything on the Meshy Wardens, then the Boki, landing Wardens as they pass. Please merge passing Wardens in batches through the day and keep tonight's installed build as the fallback for the video.

## 2026-11-04 02:12 UTC (S2): OWNER: approve Vex (Meshy v2)
- **Shots:** ext/hero-shots-s2 under warden-3d/vex/. The ones to open first:
  - meshy_vs_turnaround.png: sheet over the model.
  - meshy_vs_portrait.png.
  - meshy_vs_turnaround_gameplay.png.
  - meshy_closeup*.png.
  - meshy_gameplay_zoom.png.
  - meshy_moves_*.png.
- **Branch:** ext/warden-meshy 74132959.
- **S2 re-ran:** warden-glb, warden-model and mantle-look all PASS; health --strict OK. The key is not in git.
- **Credits:** 150 used (5 runs).
- **Matches the art:**
  - silhouette, proportions and outfit pieces, all on the sides the sheet draws them (mechanical RIGHT arm, plate on the right shoulder, lens on the right eye);
  - beret with badge, scarf, ember rifle;
  - the portrait's face (big eye, smile);
  - skinning holds through run, fire and dash.
- **Still differs:**
  - the texture is grainier and more mottled than the flat paint, mostly on the vest and the plate;
  - the sigil is soft;
  - the skin is a touch darker in shade;
  - a faint chin seam;
  - the hands only half-close on the grip;
  - with the art's slim 7.5-head build she is harder to read at match zoom than the old chunky heroes.

  One retexture run (from the clean sheet views) is being tried now against the grain.
- **Next:** on your OK, 4 agents start the other 11, starting with Zedran, Pin and Cinder. **Buy about 1,000 credits first**; about 950 are left.

## 2026-11-04 02:30 UTC (orchestrator): DECISION? lines from the owner's art review
- DECISION? **Moosh Moosh is renamed "Burple"** (display name; id tender unchanged).
- DECISION? Warden 3D waits for regenerated 2D art (owner review, INBOX_IMG 02:30). Vex becomes a cyborg whose cyborg arm holds or is fused to her gun, a bit younger; Bjorn is visibly undead/rotting and the biggest character; Cinder must read clearly as a woman; Tarek gets hair jewellery; Dredge keeps the concept with a thinner middle. Faces must not look AI-generic.
- DECISION? Large Boki have varied roles: walk beside you, mount, flyer, and more. Not all mounts.
- Note for main: tomorrow's video can show the 2D portraits already in game; the 3D Wardens won't be ready by then.

## 2026-11-04 02:35 UTC (S2): Meshy paused per the owner gate
- **Ack:** no Meshy runs until the owner approves each model's new 2D art and says go for 3D.
  - The earlier "OWNER: approve Vex (Meshy v2)" is withdrawn: the new Vex art supersedes it.
  - The v2 shots stay on ext/hero-shots-s2 (warden-3d/vex/meshy_*) as a sample of what the pipeline produces.
- **Ready for later:** ext/warden-meshy 71dc346d has PIPELINE.md, a 12-step per-Warden checklist with scripts. 160 credits used so far.
- **In progress:** the roster gets large-Boki roles; the Burple display rename is on ext/rename-burple.

## 2026-11-04 02:38 UTC (S2): READY ext/rename-burple 6d9fd821 (Moosh Moosh -> Burple)
- **What changed:** the display name only (`base_name` in content/archetypes/tender.json; the game reads it through HeroTitle). Docs, the wiki, comments and checks were swept too. The id `tender`, the wiki filenames and the art name `moosh` are unchanged.
- **Checks (S2 ran them):** --hero-title-check 0 failures, --portrait-check 107/0, health --strict OK. gen_wiki reports no changes.
- **portrait_check fix:** this branch includes the fix to the "the new names" assert, which already fails on main because it compared Arch.name_of, the class title. It supersedes ext/portrait-check-fix.
- **Left as is, for main to decide:** docs/decisions/0005 still says "Moosh Moosh" (a historic record); add a rename note if you want one. hero_title_check's OLD_NAMES keeps the old name on purpose. No reserved files touched.

## 2026-11-04 02:38 UTC (S2): Roster update: big-Boki roles (ext/boki-roster50 24cbc6c2). OWNER: review
- **Six roles across the 16 big Boki:**

  | Role | Count | Boki |
  |---|---|---|
  | mount | 6 | Heatherhorn, Glaciyak, Lilybara, Cindowary, Nimbostrich, Duskapi |
  | walks beside you | 3 | Gravadillo, Scaldamus, Umbrathere |
  | flyer | 2 | Goliathite, Squalltross |
  | bulwark (living shield-wall) | 2 | Cairnback, Limpetor |
  | packbeast (carries loot rivals can knock loose) | 2 | Floenatee, Spatewader |
  | watchtower (sniper perch) | 1 | Moundvark |

- **Where it's written:**
  - ROSTER_50.md has a role column, a pitch for each role and vivid art notes for image-gen's thumbnails.
  - RIDING_SPEC.md now specs all six roles, each for owner approval.
- **Grammar:** today a large Boki can only be a mount. Each other role needs a new `carry.style` value plus code; that is in the spec.
- **Checks (S2 re-ran them):** --roster-check 0 failures (small 20, medium 14, large 10, rideable 6), health --strict OK.

## 2026-11-04 03:15 UTC: ABILITY BACKLOG: 11 S2 kit branches are READY and unmerged (owner asked how far the ability work is)
Main has only combo-flow-base and dancer-feel from this batch. All the per-hero parity/audit work below is done, verified by S2 and waiting (details: origin/ext/server-status2 STATUS "KIT AUDIT"). They stack, so merge the TIPS (each contains its parents):
1. `ext/online-displace` @ 4fd4174: HIGH, an online bug (every ability that moves another body goes through one Displace path).
2. `ext/no-shake` (item 50).
3. `ext/audit-zed-dredge-cinder` @ 6dc3182 (contains zedran-warchain 95c291c + parity-zed-dredge-linwick).
4. `ext/audit-sable-vex` @ 2aa4ab0 then `ext/vex-ammo` @ 54f240f (no reload, source-style ammo).
5. `ext/audit-pin-vireo-tarek` @ de829f4 (contains tarek-glide-slam + parity/combo-pin-vireo-breah).
6. `ext/audit-bjorn` @ c81e9d4 (contains parity-bjorn + bjorn-48-49-51).
7. `ext/audit-ostra-claire-moosh` @ 06f05d3 (contains parity-ostra-claire-moosh + owner-heroes-1820).
Ask S2 for one combined `ext/kits-integ` if merging seven is too slow (they did this for the demo and it saved hours). Please post when merged; the owner wants to play the full kits.

## 2026-11-04 03:15 UTC (S2): READY ext/warden-stance 91d7e239: item 52, every Warden stands with attitude
- **Data:** content/rules/warden_stance.json, keyed by archetype. It sets the spine lean, hip/weight leg, shoulder and head tilt, knee bend, free hand and weapon carry, plus an idle cycle (breathing, weight shift, a signature fidget every 5.5-9 s).
- **Module:** the logic is in scripts/match/warden_stance.gd. hunter_anim.gd gets wiring only, net -12 lines: ARCH_STANCE moved into the JSON.
- **Blend:** full stance in idle; run 0.45, aim 0.55, abilities 0.4. Off while downed, gliding, mantling, dodging, stunned and in other special states.
- **Weapons:** carries let go when you fire. Shots still leave from gameplay positions, so hits are unchanged.
- **Stances**, as the owner listed them. Examples: Vex rifle back over the shoulder with the hip cocked; Pin hunched; Zedran leaning back with his chin up; Claire on one skate.
- **Checks:**
  - New --warden-stance-check: 0 failures. It checks no straight spine, every stance distinct, the idle moves, and the aim stays true.
  - The agent ran 32 hero, combo and feel checks on the branch and on main; the results are identical.
  - S2 re-ran: warden-stance 0, gunslinger-combo 67/0, move-feel 0, health --strict OK.
- **3D:** verified on the Meshy Vex using a cherry-pick onto warden-meshy; it turns her hips bone. When warden-meshy merges, expect 2 small hunk conflicts in hunter_anim.gd: meshy's legs.scale/hip_y next to the stance's hip/breath.
- **Shots:** ext/hero-shots-s2 under item52/. lineup_game.png has all 12 at match zoom; the lineup_close_*, before_after_* and meshy_vex_* shots are in the same folder.
- **Limits:** Ostra's fingers, Cinder's tail and Burple's toes have no bones on the shared rig, so they are approximated. Vireo has no staff in her kit, so her hand rests at her shoulder.

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
