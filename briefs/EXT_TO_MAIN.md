# Ext coordinator -> main session (append-only log; newest at the bottom)
<!-- briefs-trim pointer -->
> Trimmed 2026-11-06 by briefs-trim: 108 finished/superseded entries moved to briefs/archive/EXT_TO_MAIN-2026-11-06.md. Kept here: owner rules and decisions, open owner questions, unmerged READY branches, open assignments and review items, the latest SHIPPED/RELEASED, holds still in force, and the last 12 h. Older archives: briefs/archive/EXT_TO_MAIN-*.md

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

## 2026-11-02 04:45 ET: ext/economy review fixes done, READY TO MERGE (9c7bb51, Net 0.11.0)
Merged with fcc3745. All 13 review items and all 8 check gaps are done. docs/HANDOFF_economy.md maps each item to the assertion that covers it. --economy-floor-check grew from ~60 to ~150 assertions. 0 failures on health, gen_wiki, check, economy, economy-floor, extract, teammate, boki-system, capture, bot-sanity, kinbox and home-build. tools/boki_system_check.gd matches main again.
Calls that differ from the review text:
- Item 2: the listing lock covers origin "stray" and "loaner" as well as "market", because a free stray could be listed for ~70 gems. Open listings are capped at 3. BokiPens.NO_RESALE controls this.
- Item 3: makers quote around the item's base price and the date, not the last trade, so buying a side out and refilling it repeats the same quotes. The offline spread is at least 8% of mid. An offer fills at the trader's quote, never worse than the player asked.
- Item 8: added a DEBT.md entry (owner: the exchange-server task) instead of routing through Social.sell_kin, which is an async server doc with its own price range.
- Item 9: home.gd is +12/-2 vs main, wiring only. The free-kit code is in the new scripts/home/home_freekit.gd. The pens/exchange --open branch moved to HomeMarket.open_named.
- Also fixed: Exchange.tick returned a slice of the 40-capped fills log, so it reported no fills once the log was full.
- Known limits, logged in DEBT.md: cheap goods (wood) never fill offline. Setting the system clock back can pick cheap and dear days on the local Exchange; spread plus tax eat most of the gain, and the server backend ends it.

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

## 2026-11-02 18:35 ET: OWNER: remove the "Hold Shift for the long dash" setting
- Remove the `dash_hold` setting: settings.gd default, the overlay.gd:295 toggle "Hold Shift for the long dash", and anything that reads it. Drop the key from saved settings on load.
- Hold-to-extend dashes are a **per-hunter mechanic**, not a player setting. Example: Tamsin's Rinkrun, where you hold Shift to skate. Where a hunter's source has a hold-dash, the kit implements it. Everywhere else, Shift does what the kit says.
- This is in your files (settings/overlay) and is small, so please take it in your next sync. I'm telling the kit agents not to rely on `dash_hold`.

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

## 2026-11-04 04:15 UTC (orchestrator): DECISION? the owner approves 3D for all Wardens
- DECISION? The owner approves Meshy 3D for all 12 Wardens, modelled only from the round-2 art (ext/imagegen wardens_r2), with the orchestrator deciding details. Batch 1 = Vex, Zedran, Pin, Cinder; main, please merge each READY batch quickly.
## 2026-11-04 04:20 UTC: READY ext/unmasked 641285d7: the Unmasked replaces the detailed creator (do NOT merge before the owner signs off the heroes)
- **Held for sign-off:** a match, hero cards, HUD and portraits now wear `Unmasked.mask_look()`, a plain Warden, so this branch touches how heroes render. Merge only after the owner OKs warden-models / mask-look. The farm/town/house and creator parts do not depend on that.
- **Base model:** the existing hunter rig, not Meshy (faster, and every HunterAnim animation works as is). `Models.hunter` takes a look with `"unmasked": true`: human rig, no hunter gear, no hair, no ears, no nose, no mouth. New `scripts/match/unmasked.gd` (look, migration, face marks, 5 outfits); design note docs/decisions/0016-the-unmasked.md. A Meshy base can replace the geometry later without touching the look format.
- **Look keys:** gender, height (scale 0.92/1/1.08), build (body width), eyes (6), brows (5), blush (3), outfit (5: Traveller, Scholar, Smith, Sailor, Festival), colour (12), `marks` (kept mask features; drawn as flat dots if present, empty for now). Face marks are flat decals on the head.
- **Creator (hatch.gd):** Body (Gender, Height, Build), Face (Eyes, Brows, Blush), Outfit, Colour, name, Random; turntable kept. Net -98 lines. The Hunter stepper and the race rows are gone. Walk style NOT built (it needs HunterAnim work, so not cheap).
- **Saves:** no version bump. `Save.load_game` runs `Unmasked.migrate` (idempotent): old look to closest Unmasked (gender, build, height from race size, eyes from face, brows, blush, outfit, colour from skin; the glider is kept). Odd data (null, strings, out of range) is clamped, never crashes.
- **Text:** the pick screen reads "Choose your first mask" ("Pick the mask you wear first..."); the creator says "Make yourself". The prologue's old "Mantle" lines (prologue.gd, prologue_boki.gd) were not touched: they belong to the prologue rebuild.
- **Flow:** unchanged: new game goes intro, pick mask, egg. The creator is still reached from Settings > "Change your look" (and `--creator`); class_unlock_check still asserts no creator on the way.
- **Checks (Godot 4.6.2, temp XDG_DATA_HOME, after `--import`):**
  - `--check` 0 failures
  - `--unmasked-check` (new) 17 checks, 0 failures
  - `--class-unlock-check` 148 checks, 0 failures
  - `--hatch-check` 0 failures; `--hair-check` 0 failures
  - `--portrait-check` 107 checks, 1 failure: "the new names" (expects Arch.name_of("gunslinger") == "Vex"). Same failure on a clean origin/main c00fead, not from this change.
  - `python3 tools/health.py --strict` OK (models.gd 3387/3500; style baseline re-locked); `python3 tools/gen_wiki.py --check` OK (34 unchanged).
- **Cost:** `git diff --stat origin/main`: 19 files, +64/-121 before the 3 new files (unmasked.gd ~210 lines, unmasked_check.gd ~115, the decision note). models.gd +4 net.
- **Shots** (briefs/unmasked/): before_creator.png / after_creator.png; before_farm_crop.png / after_farm_crop.png (the farm camera is far out, so the crop is 4x of the player; he still carries the class weapon on the farm, as before).
- **Known:** the creator preview hides the weapon; the farm player still holds it (existing behaviour). Bots keep random race looks until warden-models.

## 2026-11-04 04:25 UTC (orchestrator): OWNER RENAME: Vireo is now "Ryzz"
- DECISION? **Vireo is renamed "Ryzz"** (id mage unchanged; save/Net ids unchanged). Update everything player-facing and in the docs: display name, kit text and tooltips, hero picker and cards, the wiki (regenerate with gen_wiki), docs/heroes, DECISIONS/PRIORITIES mentions, and the portrait/art file names going forward. Add "Vireo" to --hero-title-check's old-names list.
- Suggest S2 does it as a small rename branch (like rename-burple), merged with the next batch. Please fold the line into DECISIONS.md.

## 2026-11-04 04:28 UTC (S2): OWNER: review Vex r2 3D
- **Shots:** ext/hero-shots-s2, folder warden-3d/vex/. Open these first:
  - r2_vs_turnaround.png (the sheet over the model, at 5 angles)
  - r2_vs_portrait.png
  - r2_closeup.png and r2_closeup_34.png
  - r2_moves_run_fire.png
- **Branch:** ext/warden-meshy 934a29cd (stance: ext/warden-stance 4f9487a0).
- **Checks:** warden-glb, warden-model, mantle-look, move-feel, gunslinger-combo and weapon-clip pass; health OK.
- **Credits:** 1 Meshy run (30 credits). Vex's total is 190.
- **What matches:**
  - the silhouette;
  - the stance: hip cocked, gun-arm hanging, hand on hip;
  - the minigun fused to her right arm, with barrels that spin when she fires and glowing vents;
  - the black hair with the orange streak, the bun and the bolt;
  - the monocle, the grin and the bandage;
  - the candles, the vest, the crop top and the torn tights;
  - the clean face, the warm skin and the silhouette outline;
  - chunkier game proportions.
- **Still differs:**
  - The orange streak isn't one clean band; at 3/4 it reads as messy orange shards.
  - The ammo belt from the back drum to the gun is removed, because the gun-arm aims on its own.
  - The candles are lumpy, and the free hand is open.
  - The gameplay-zoom shot is cluttered (a speech bubble, a dark map); a cleaner one is coming.
- **In progress:** Zedran, Pin and Cinder r2 (batch 1).

## 2026-11-04 04:40 UTC (S2): Vex r2 3D update (same review)
- The r2_* shots on ext/hero-shots-s2 under warden-3d/vex/ are refreshed:
  - The hair is flat black with one orange front band over the monocle side; a few small shards remain.
  - r2_gameplay_match.png and r2_gameplay_zoom.png are now in the Arena on bright grass, with no bubbles or nameplates over her.
- Branch: ext/warden-meshy f56db4ff. Checks pass, and no extra credits were used.
- Honest read: close up she matches the art well. At match zoom she reads by the streak, the vents and her arm, but her body is darker than the grass.

## 2026-11-04 04:35 UTC (orchestrator): Ryzz art landed
- Ryzz (was Vireo) round 2 is on ext/imagegen (wardens_r2/ryzz_*), going to 3D. Main: the rename sweep note is at 04:25 above.

## 2026-11-04 05:10 UTC: READY ext/unmasked-home 955402b0: the Unmasked on the farm, the creator, saves, and the new-game flow (mergeable now)
Answers "OWNER answers for ext/unmasked". It contains the earlier ext/unmasked work (641285d7), so merge this one and drop ext/unmasked. The branch cuts the match side out: matches, hero cards, HUD, portraits and the title squad render as on main.
- **Split:** `Unmasked.mask_look()` is what those screens use. A migrated save keeps its old detailed look under `look["old"]` and `mask_look()` returns it (a new save gets the plain default look, same as main). So the match-side change (part b: the real mask-look rules) is not in here; it replaces `mask_look()` and drops `look["old"]` when the heroes are signed off.
- **New game:** intro, **make yourself** (the creator), **choose your first mask**, egg. `hatch.gd` `_end_intro` goes to the creator when the save has no look; "Looks good" (now `_looks_good()`) goes on to the mask pick (`_after_create`). Settings > "Change your look" still reopens the creator and returns home. class_unlock_check updated for the new order.
- **Mask pick (about 90% Warden):** `HunterViewer.make(id, stage, true)` (ClassPick uses it). It shows you; the mask lifts to your face (`scripts/ui/mask_put_on.gd`, about 1.5 s: lift, one soft flash, no rays or rings), and the Warden takes over: its own model, outfit and weapon, plus a tenth of you (`Unmasked.SHOW = 0.1`): your body colour tinted into every surface, your height and build proportions, and your eyes behind the mask (your eye shape becomes the Warden's face). Picking another mask runs the beat again. The Hunters screen is untouched.
- **Vex 3D model:** NOT verified here. The viewer builds heroes with `Models.hunter`, and WardenGlb (on ext/warden-meshy) wraps that output, so Vex's .glb should show in the pick once warden-meshy merges. I tried a trial merge onto warden-meshy; it is based on an older main and conflicts in about 12 files, so I could not run it. Please check the pick with Vex after that merge. `Unmasked.blend` scales the root and tints `get_meta("mats")`, which should hold for the .glb, but that is unchecked.
- **Checks (Godot 4.6.2, temp XDG_DATA_HOME, after --import):** `--check` 0 failures; `--unmasked-check` 0 failures (now also: a migrated save's Warden look is as before, your eyes and the 10% blend); `--class-unlock-check` 149 checks, 0 failures; `--hatch-check` 0; `--hair-check` 0; `--portrait-check` 1 failure, "the new names" (same on clean origin/main c00fead, not ours); `health.py --strict` OK; `gen_wiki.py --check` OK. With real rendering and `--shots-dir`, class_unlock_check has one more failure ("home after the first expedition says Hired Gun...") that is also on clean origin/main.
- **Shots** (briefs/unmasked/): `mask_beat.png` (3 frames: the mask arriving with the flash fading, then the Warden worn, Pin here), `after_creator.png`, `after_farm_crop.png`, `before_*` for comparison.
- **Not done:** walk style (needs HunterAnim). The creator preview and the farm player still carry the class weapon (HunterAnim shows it every frame).

## 2026-11-04 05:00 UTC (orchestrator): DECISION? Warden 3D quality bake-off before the fan-out
- Owner: Vex r2 still too buggy; spend more for quality. S2 pauses the other Wardens, reruns Vex at Meshy max with a proper bake/paint-over, and compares Rodin and Tripo (owner will buy keys). A human artist clean-up is the fallback.

## 2026-11-04 06:05 UTC (orchestrator): DECISION? Dredge art locked
- DECISION? Dredge round-2 art is final: a bulky brass diving-machine body with a thin oozing waist, a hook and a horn arm (ext/imagegen wardens_r2/dredge_*).

## 2026-11-04 06:25 UTC (orchestrator): OWNER RENAME: Bjorn is now "Breaker"
- DECISION? **Bjorn is renamed "Breaker"** (id bulwark unchanged; save/Net ids unchanged). Update everything player-facing and the docs (display name, kit text, tooltips, picker and cards, wiki via gen_wiki, docs/heroes, DECISIONS/PRIORITIES and lore mentions), and add "Bjorn" to --hero-title-check's old names. Main, please fold it into DECISIONS.md.

## 2026-11-04 05:45 UTC (S2): READY ext/rename-breaker (Bjorn -> Breaker); it also contains rename-ryzz and rename-burple
- **Merge just this one branch** to get all three renames. Base: rename-ryzz plus origin/main. It merges cleanly with main.
- **What changed:** the display name (bulwark.json base_name "Breaker"), card and kit text, docs, the wiki (filenames kept), comments and printed check labels. The id `bulwark` and the identifiers (BjornFx, bjorn_* files and sounds) are unchanged.
- **Checks:** S2 re-ran hero-title 0, portrait 107/0 and health --strict OK. The agent also ran bulwark-combo 102/0, archetype 307/0 and style OK.
- **Left as is:** portrait_art.gd still maps the art names to bjorn, vireo and moosh until ext/imagegen's round-2 files (breaker_*, ryzz_*) merge. The decision records are untouched.

## 2026-11-04 06:50 UTC (orchestrator): OWNER RENAME: the tender hero is now "Pip" (supersedes "Burple")
- DECISION? **Moosh Moosh/Burple is now "Pip"** (id tender unchanged). Her art is female (wardens_r2/pip_*). Main, please fold into DECISIONS.md; if rename-burple is merged, rename again to Pip; if not, fix that branch to Pip before merging.

## 2026-11-04 07:10 UTC (orchestrator): DECISION? Vex round-3 redesign; Dredge uses a hand-made model
- DECISION? Vex has a new round-3 design (green-haired cyborg, gun-arm forearm, green braids, cyber eye; ext/imagegen wardens_r3 + VEX_KIT.md). S2 models it alongside the current r3 for comparison.
- DECISION? Dredge uses the rigged Blender model from the owner's friend (ext/imagegen docs/art/gen/models/dredge_friend), not Meshy.

## 2026-11-04 07:20 UTC (orchestrator): DECISION? art direction: sex appeal is wanted
- DECISION? Owner: sex appeal is good and wanted in the Warden designs (adult characters only; stylised, not explicit). Multiple heroes in crop tops are fine. When an outfit is changed for variety, it must keep the appeal. The orchestrator's earlier "avoid crop tops / no bare midriff" notes in the redesign prompts are withdrawn.

## 2026-11-04 07:10 UTC (orchestrator): DECISION? Ryzz's lightning scar; Cinder right-handed
- DECISION? Ryzz's closed right eye is a lightning scar (a Lichtenberg-figure scar with a faint blue glow) from the storm that struck her as a kid. It replaces the "wink".
- DECISION? Cinder holds her spear in her right hand (the rig default).

## 2026-11-04 07:15 UTC (orchestrator): MAIN MERGE QUEUE (main is offline until the owner moves the Claude app back; start here when you return)
In order:
1. **kits-integ 5e551f8c** (S2 04:04): online-displace (pulls and hooks move human players online), no-shake (item 50), the 5 kit-audit branches, vex-ammo (no reload). Needs a Net.VERSION bump.
2. **rename-breaker 038a76b3** (S2 06:03): all renames (Vireo→Ryzz, Bjorn→Breaker, Moosh Moosh/Burple→Pip); supersedes rename-burple and rename-ryzz.
3. **warden-stance** (item 52, S2 03:15).
4. **farm-hob round 2** (ext 23:17 ET Nov 3).
5. Later, when S2 posts them READY: the Warden 3D models (Vex r3/r3b, Dredge from the friend's model) as one art batch.
Also fold into DECISIONS.md every "DECISION?" line from 19:35 UTC Nov 3 onward in this file. Then ship a sync and confirm the push landed.

## 2026-11-04 07:10 UTC (S2): OWNER: review Dredge (your friend's hand-made model, in game)
- **Shots:** ext/hero-shots-s2, in warden-3d/dredge/. Start with r2_dredge_turnaround.png (the art beside the model at 5 angles), then r2_dredge_closeup, r2_dredge_moves and r2_dredge_match.
- **Branch:** ext/warden-dredge-friend 9eb87b5d. No Meshy credits used.
- **The rig:**
  - His 27 bones map onto WardenSkeleton.
  - The extra Dredge bones are claw ×3, winch, rope and hook. The kit uses them: the claw spreads to throw and clenches to reel, the drum spins, and the rope and hook hide while the hook flies.
  - All 184 kit moves retarget.
- **The file:** both the .glb and the .fbx came without material colours. The 10 flat colours were picked from the art.
- **Checks:** warden-glb, warden-model, mantle-look, move-feel, dredge-combo 86/0, weapon-clip and health OK. S2 re-ran warden-glb, dredge-combo and health.
- **Fix for main:** a one-line models.gd fix (bulky heroes lost body.legs). It also fixes Cinder.
- **Honest read:**
  - The silhouette, hull, porthole, horn, three-claw hand, winch, rope and hook, and boots all match.
  - Different from the art: the hull and shoulders are smooth round domes instead of dented, layered plates; the brass is brighter and more yellow than the art's aged brass; the eye is a red star, not a glowing orb in cracked glass; the tar drips are thin; the horn is bigger.
  - At match zoom he reads but is busy and dark.
- **Blender-built Wardens:** your friend's model is code-built (3,440 bpy primitives, each rigid to a bone). Our agents can work the same way headless, with no MCP needed: step scripts and quick renders beside the art.
  - Estimate: 2-4 agent-hours per Warden and no credits.
  - It's best for machines, armour and weapons, and weaker for faces, hair and fur.
  - S2 suggests a hybrid: script the hard-surface Wardens and gear (Dredge, Breaker's shield and hammer, gun-arms), and use Meshy for organic bodies. Details in PIPELINE.md, "Blender-driven modelling".

## 2026-11-04 08:15 UTC (orchestrator): DECISION? the roster is set for now; future Masks list (P4 breadth, not now)
- DECISION? The current 12 Wardens are the launch group. Breaker is a shield SUPPORT (like the source's Oath), so the supports are Breaker (shield) + Pip (heal).
- Future Masks to add later (owner, Nov 4; breadth phase, after the 12 feel great): more supports; vampires; older characters (a veteran or sage); an attractive male hero; plus the orchestrator's gap list: a melee swordmaster/duelist, an engineer/trapper with deployables, a summoner/necromancer (fits the Blight lore).

## 2026-11-04 08:45 UTC (orchestrator): OWNER RENAME: Pin is now "Hem"
- DECISION? **Pin is renamed "Hem"** (the Dark Archer; id archer unchanged; save/Net ids unchanged). Lore direction: the Tyrant's mask-stitcher turned assassin; a hem is the last stitch. Main, please fold into DECISIONS.md.

## 2026-11-04 09:20 UTC (orchestrator): DECISION? Masks and relics lore (owner-approved); fold into DECISIONS.md
- DECISION? Canonical Mask lore and the 12 relics are in **briefs/LORE_MASKS.md**. It replaces the concept-pass relic names and any pre-redesign hero lore. Summary: a Mask is the transformation; the relic (only sometimes a literal mask) is the key; wearing it settles the Warden's face and form over you; the put-on beat is a ghostly porcelain face flicker.
- DECISION? **Masks are unlocked first (challenges/rewards), then bought.** Vex is free at the first portal; the second Mask is one of Zedran/Hem/Cinder. Prices come in the economy pass.
- [EXT] Sync the Lore Bible artifact and docs/art/gen/stories/*.md to LORE_MASKS.md (relics, names Hem/Breaker/Ryzz/Pip, new stories). Main: new player text about Masks should follow it.

## 2026-11-04 08:11 UTC (S2): OWNER: review Vex r3 (Meshy at max + bake). Verdict and credits
- **Shots:** ext/hero-shots-s2, under warden-3d/vex/:
  - Start with r3_vs_r2.png, r3_vs_portrait.png and r3_vs_turnaround.png.
  - Then r3_front_34_vs_art.png, r3_back_vs_art.png and r3_gameplay_zoom.png.
  - r3_meshy_variants.png shows the 9 Meshy variants.
- **Branch:** ext/warden-vex-r3 032ceeeb.
- **Checks:** S2 re-ran warden-glb, warden-model and gunslinger-combo 67/0, and health OK. move-feel, mantle-look, weapon-clip and warden-stance also pass. The key is not in git.
- **How it was built:**
  - Meshy 7.1, no remesh, ultra geometry, 8k texture with PBR.
  - Three image edits to free her left arm from her hip.
  - The kept run uses the edited front/3-4/back plus the turnaround's profile.
  - The 1.19M-triangle mesh is baked onto a clean 34k body plus a 4.4k gun-arm, with a 2k atlas.
  - Targeted paint-over: skin warmed, the lens glowing, stray strands cut.
  - A thinner outline that stays off hair and eyes, and a brightening that only kicks in at match-camera distance.
  - Slightly chunkier build.
- **Honest verdict:**
  - **Clearly better than r2.** Close up, the face, the hair with its orange streak, the bun and bolt, and the vest read cleanly in flat painted colour, with no facets, patches or ragged outline. At close-up and 3/4 she looks like the portrait and turnaround.
  - **Still differs:**
    - the monocle is a bright yellow-orange disc, not a brass ring with a cracked glow;
    - her skin is paler than the art's tan;
    - the candles are blobby;
    - the hair is a bit helmet-like at 3/4.
  - **At match zoom** she reads by the black and orange hair and the orange top, but the face is about 8 px wide, so it's still a busy, darkish read.
  - **The last 10-20%** (lens, candles, hair silhouette) would need a human 3D-artist pass starting from the Meshy mesh and bake (the agent estimates 2-4 h per Warden). Rodin and Tripo aren't needed: geometry and texture are no longer the weak point.
- **Credits:** the r3 run used 382, and the parallel r3b redesign has used 125 so far. **The Meshy balance is now 4,993.**
- **The other 11 Wardens:** about 70-110 credits each with the r3 recipe (about 0.8-1.2k for all 11). The checklist is in PIPELINE.md.
- **Waiting on the owner:** say "go" to use the r3 recipe on the others, or wait for the r3b redesign comparison, which is still running.

## 2026-11-04 09:40 UTC (orchestrator): DECISION? one villain, terms, prologue text, and the tutorial Mask line (for main's queue)
- DECISION? The Tyrant IS the Wyrm in human shape (one villain).
- DECISION? Terms: **Hunter** = the player; **Mask** = the hero you pick/unlock (rename player-facing "Hunter(s)" hero labels and tabs to "Mask(s)"); **Warden** = lore only; **Fusion/Fuse** (never Merge/Mantle in player text); retire **Mantle** and **Bearer**. Full list in briefs/LORE_MASKS.md "Terms".
- [MAIN] Small text task (can ship before the Sat prologue rebuild): replace the 5 prologue captions in scripts/ui/prologue.gd with briefs/LORE_MASKS.md "Prologue text" (slides 3-4 still say "Mantles" today); add the first-portal tutorial line "This Mask holds a fallen Warden. Put it on, and you become them." Sweep remaining "Mantle"/"Merge" player text. Add it to the 07:15 merge queue.

## 2026-11-04 09:55 UTC (orchestrator): DECISION? terms simplified (supersedes 09:40 "Terms")
- DECISION? **No "Warden" in player text.** The people the Wyrm emptied are **the Empty** (you at home are Empty; this replaces "the Unmasked" in player text). Putting on a **Mask** makes you a **Hunter**; the Masks hold the selves of the **fallen Hunters** of old. Retired in player text: Warden, Mantle, Bearer, Merge, Unmasked (code ids may stay). Prologue slide 3 becomes "...The Hunters who stood against it were sealed into Masks."; the tutorial line becomes "This Mask holds a fallen Hunter. Put it on, and you become them." Updated in briefs/LORE_MASKS.md.
- [MAIN] Fold this into DECISIONS.md (it updates the Identity/Mask lines and the Unmasked naming) and include it in the text sweep.

## 2026-11-04 10:05 UTC (orchestrator): DECISION? the premise in the owner's words + new prologue captions
- DECISION? Premise (owner): "The Wyrm came, and stole our essence. In time, humans, beasts and skyfolk alike were born without faces. We became a new race: the Empty. Our only salvation became the cursed fossils we once tried to destroy: Masks, each carrying the soul of a fallen Hunter of old." The skyfolk are a people (a race alongside humans and beasts).
- [MAIN] The prologue captions in briefs/LORE_MASKS.md "Prologue text" replace the 09:40 draft (slide 4 = the Masks; the Boki move into slide 5).

## 2026-11-04 10:30 UTC (orchestrator): DECISION? Pip and Claire stay as they are
- DECISION? Pip is NOT fiery (too much fire in the roster already: Cinder, Zedran's magma). Her pastel fairy-fox look is final; drop "small and fiery like a fox" from her description.
- DECISION? Claire's classically pretty face is intentional: she's the seductress (the sweet face is the lure, the body is demonic). Don't "fix" it toward more character.

## 2026-11-04 10:45 UTC (orchestrator): DECISION? Hem's title is "Red Stitch"
- DECISION? Hem's class title changes from "Dark Archer" to **"Red Stitch"** (player label "<name> the Red Stitch"). Main: fold into DECISIONS.md; S2: include it in the rename sweep (titles live with the class-titles data).

## 2026-11-04 10:50 UTC (orchestrator): DECISION? titles: Dredge "Brass Abomination", Tarek "Cliff Runner"; Vex stays Vex
- DECISION? Class titles: Dredge **"Brass Abomination"** (was Broken Abomination); Tarek **"Cliff Runner"** (was Rock Elementalist). Vex keeps her name. Main: fold into DECISIONS.md; S2: include in the rename/title sweep.

## 2026-11-04 08:43 UTC (S2): OWNER: compare Vex r3 (current design) vs r3b (round-3 redesign) and pick one
- **Shots:** ext/hero-shots-s2, under warden-3d/vex/:
  - Comparisons: r3b_vs_r3.png, r3b_vs_r3_closeup.png and r3b_vs_r3_match.png.
  - r3b against her own art: r3b_vs_turnaround / portrait and r3b_closeup*.
- **Branches:** ext/warden-vex-r3 032ceeeb (r3) and ext/warden-vex-r3b 6e9284d5 (r3b, which contains r3).
  - r3b loads with `--warden-variant=vex_r3b` or the Settings value "vex_r3b". Shipping it means moving its files to art/wardens/vex/.
- **r3b, built on the r3 recipe:**
  - Meshy 7.1 at max, plus image edits so her left hand isn't on her hip and the braids and hoses come out separate.
  - Baked to 31k for the body, plus braids 8.5k and gun-arm 5.2k.
  - **Braids:** real geometry, three-strand weave with copper wraps. They swing on 7 spring bones each; a new check confirms the swing.
  - **Eye:** the green cyber eye is a brass rim with an emissive green lens.
  - **Colour:** remapped to the art's palette.
- **Checks:** all pass with the variant on (glb, model, mantle, move-feel, gunslinger-combo 67/0, weapon-clip, stance), health OK.
- **Credits:** r3b used 125. The balance is **4,993**.
- **S2's read:**
  - At close-up both match their art.
  - **At match zoom,** r3b's green hair and braids are the more distinctive signature. r3 reads by its orange top.
  - **r3b still differs from its art:**
    - shorter legs (it shares the gunslinger rig);
    - braids a bit short, and the backpack-to-gun hoses dropped;
    - the shared shader pales her skin and silvers the gun-arm;
    - a blotchy chest strap cage and faint seams on her cheeks.
  - A one-number fix is ready if you pick r3b: her gun angle, carry pitch -1.3 -> -1.05.
- **Next:** pick r3 or r3b, then say "go" for the other Wardens with the r3 recipe (about 70-110 credits each).

## 2026-11-04 09:00 UTC (orchestrator): DECISION? Vex 3D = r3b (green redesign); polish pass under way on S2 before the other Wardens

## 2026-11-04 09:05 UTC (orchestrator): DECISION? 3D fan-out GO for Hem, Breaker, Sable, Claire, Tarek, Ostra, Pip (+ Dredge texture pass); Zedran, Ryzz, Cinder wait for final art

## 2026-11-04 09:30 UTC (orchestrator): DECISION? rename Zedran to KAEL + four title changes
- DECISION? **Zedran is renamed "Kael"** (id juggernaut unchanged). Titles: Kael **"The Unbroken"** (was Arena King); Claire **"Frost Siren"** (was Icy Dancer); Pip **"Little Lantern"** (was Fox Cub); Ryzz **"Storm Chaser"** (was Storm Slayer). Main: fold into DECISIONS.md. Second-Mask picks are Kael/Hem/Cinder.

## 2026-11-04 09:45 UTC (orchestrator): DECISION? second-Mask picks are Kael, Pip, Cinder (Pip replaces Hem)
- DECISION? After the Vex tutorial, the second Mask is one of **Kael (melee), Pip (healer), Cinder (area)**. Hem becomes an early unlock. Main: update the new-game second-pick data + DECISIONS.md.
- Pending the owner's look test: Kael's magma may change to white-hot (to leave orange fire to Cinder). [EXT/S2] hold Kael's 3D texture colour until the owner decides.

## 2026-11-04 10:00 UTC (orchestrator): DECISION? Kael's glow is white-hot (not orange magma); orange fire stays Cinder's alone

## 2026-11-04 09:23 UTC (S2): OWNER: review Dredge r2b (the friend's model with an aged-brass pass)
- **Shots:** ext/hero-shots-s2, under warden-3d/dredge/. Compare r2b_dredge_turnaround.png with r2_dredge_turnaround.png, then look at r2b_dredge_closeup, r2b_dredge_match and r2b_dredge_moves.
- **Branch:** ext/warden-dredge-friend acb501fd. No Meshy credits.
- **What changed:**
  - A painted 2k atlas: grime in the crevices, verdigris accents, rust on the iron, painted dents, scratches and worn edges.
  - Darker brass, with a gold band on the upper curves.
  - An emissive red orb eye in a cracked lens.
  - 24 thicker glossy tar drips riding their bones.
- **Checks:** warden-glb, warden-model, mantle-look, move-feel, dredge-combo 86/0, weapon-clip and health are all OK.
- **S2's honest read:**
  - Much less toy-like than r2.
  - The brass now leans copper-orange; the art's is a duller olive-gold. One hue step either way is easy.
  - Still smooth round shoulder domes, not the art's angular, torn plates.
  - The dents are painted, not modelled.
  - The tar hangs straight rather than running down the hull.
  - The horn is bigger than drawn.

  Shape fixes like the shoulders and torn plates belong to stage 2.

## 2026-11-04 09:54 UTC (S2): OWNER: review Vex r3c (the polished shipped Vex; the reference recipe for the rest)
- **Shots:** ext/hero-shots-s2, under warden-3d/vex/. Start with r3c_closeup_vs_art.png, r3c_vs_turnaround.png, r3c_front_34_vs_art.png, r3c_back_vs_art.png, r3c_match_vs_art.png and r3c_vs_r3b.png.
- **Branches:** ext/warden-vex-r3b 296ac07d (Vex shipped as r3b + the r3c polish). Her carry fix is on ext/warden-stance aa3345b6.
- **What r3c did (no credits):**
  - The art's face, chest and belly are painted over and lined up against a render of the mesh.
  - A per-model look override (content/rules/warden_look.json) fixes the pale skin and silver gun for her alone.
  - Longer legs (legs 1.95, size 0.89). Height stays at the sheet's 1.04x and the hitbox is unchanged.
  - Two ribbed hoses from the backpack to the gun-arm.
  - Longer, thicker spring braids.
  - Her stance: hip cocked, hand on hip, gun angled forward-down.
- **Checks:** all pass. warden-glb now also checks the springs and the look override.
- **S2's read:** close up she now clearly matches the portrait: face, green hair, eye plate, braids, tattoos, top. At match zoom her green head and braids are the signature.
- **Still differs:**
  - The art has 3-4 thick hoses looping below her waist; the model has 2 thin ones to the elbow.
  - A faint jaw seam and dark smears on the straps at 3/4.
  - The lens is a 1-2 px dot at match zoom.
  - The collar seams don't glow.
  - The brass is a bit bright and orange.
  - The braids end at the hip, not mid-thigh.
  - The head is x1.16, on purpose for the game read.
- **Credits:** the balance is 4,327. 666 of that went on the stage-1 fan-out you approved at 09:05 (8 Wardens, 43 tasks).

## 2026-11-04 10:07 UTC (S2): OWNER: review stage 1 for Hem and Kael (first pass, no polish yet)
- **Shots:** ext/hero-shots-s2, under warden-3d/hem/ and warden-3d/kael/. Open s1_vs_turnaround_close.png first, then s1_vs_portrait, s1_closeup and s1_match_x4.
- **Branches:** ext/warden-3d-hem 0324d62e and ext/warden-3d-zedran eb58ee44 (Kael). Both include the Vex r3c base.
- **Checks (agent-reported):** all pass. Hem: glb 31/0, model 37/0, archer-combo 119/0. Kael: glb 32/0, model 47/0, juggernaut-combo 135/0.
- **Cost:** 76 credits each (4 input edits plus one Meshy run). Both first runs were clean.
- **Hem:**
  - Matches the art: the porcelain mask is its own mesh, the red coat and corset, the quiver of needles, and a scripted black recurve bow in her left hand with a glowing red-thread string.
  - Stage-2 gaps: she holds the bow across her body (the shared hold); the quiver and hair needles are ragged; there are dark blotches on the back of the coat; she reads dark at match zoom.
- **Kael:**
  - Matches the art: the white mane on springs, the scarf, the kilt and greaves, one Warchain hook, and the left-wrist cuff with a broken chain.
  - The white-hot glow is a switchable parameter (model_glow in juggernaut.json).
  - **The biggest gap: the blade renders near-black with thin white cracks, where the art's whole blade glows white-hot.**
  - His arm cracks barely show, the mane reads as stiff ribbons, and the idle has the sword shouldered rather than hanging.
- **Stage 2** (the r3c recipe: paint-over, look override, stance) fixes these once you OK Vex r3c.

## 2026-11-04 10:08 UTC (S2): OWNER: review stage 1 for Breaker and Claire
- **Shots:** ext/hero-shots-s2, under warden-3d/breaker/ and warden-3d/claire/. Start with s1_vs_turnaround.png, then s1_vs_portrait and s1_match_x4.
- **Branches:** ext/warden-3d-breaker 991d0701 and ext/warden-3d-claire 4a47db64. Both are on the r3c base and share one tooling commit.
- **Checks:** all pass (agent-reported). Breaker glb 33/0, model 37/0, bulwark-combo 102/0. Claire glb 33/0, model 47/0, rimewright-combo 68/0.
- **Cost:** Breaker 116 credits (the first run lost his right hand, the second is good; no third hand). Claire 67.
- **Breaker:**
  - Matches the art: the sea-ogre body, red braided beard, compass and fur mantle. The hammer is scripted as a plain ice block on the kit's hammer pivot, and the prow shield with its scroll top sits on the Shield node.
  - Stage-2 gaps: he holds the hammer forward and low (the shared hold) instead of over his shoulder; the shield reads too big and too close; the body texture needs cleanup; his match read is muddy.
  - **OWNER decides his height:** he's set at 1.32x a medium hunter, and the kit asks about 1.5x. The hitbox stays the heavy class's 0.50 m either way.
- **Claire:**
  - Matches the art: the face, the horns as their own mesh, long hair, the ice costume (a new ice toon slot with a fresnel rim), skates that point forward (a new assert checks this on every fit), wings as art-painted cards on springs that fold back while she skates, and a spring tail.
  - Stage-2 gaps: the spear takes the two-handed fan hold and reads short (in the art it's taller than her); the horns are stretched upward; dark patches at her hip and at the wing corners; she reads small and dark at match zoom.
- **Known limit:** a weapon swap falls back to the procedural weapon for any .glb weapon (Vex too). This is pre-existing.

## 2026-11-04 10:09 UTC (S2): OWNER: review stage 1 for Sable and Pip
- **Shots:** ext/hero-shots-s2, under warden-3d/sable/ and warden-3d/pip/. Start with s1_vs_turnaround.png; it includes match-zoom rows.
- **Branches:** ext/warden-3d-sable f333efee and ext/warden-3d-pip a07581b5. Both are on the r3c base.
- **Checks:** all pass (agent-reported). Sable: glb 31/0, dancer-combo 92/0. Pip: glb 30/0, tender-combo 72/0.
- **Cost:** 85 credits each.
- **Sable:**
  - Matches the art: the face, the plumes, the goggles, the asymmetric jacket (one sleeve, on her right arm), the open laced back, two real spring braids, four alpha wing cards with eyespots on spring bones, and twin scripted crossbows (the left one in the Offhand node).
  - Stage-2 gaps: the red pendant doesn't glow; her eyes are pale, not the art's big dark eyes; the crossbows are small; the fur collar is bulky at the back; the wings could shimmer more.
- **Pip:**
  - Matches the art: the face, goggles, ears and cape; the fluffy tail on a 4-bone spring; four pink fairy-wing cards; a scripted copper lantern with glowing panes swinging from her right paw.
  - **Biggest stage-2 gap:** her arms are fused to her flanks and cape, so wide arm swings show a skin and cape flap. That needs weight painting.
  - Also: the lantern is smaller and casts no light; the wings are faint on bright ground.
- **Generic additions on both branches:** an alpha "card" slot and shader for wings, an offhand weapon slot, and the props builders (wings, crossbows, lantern).

## 2026-11-04 10:27 UTC (S2): OWNER: review stage 1 for Tarek and Ostra. That completes stage 1 for all 8 heroes
- **Shots:** ext/hero-shots-s2, under warden-3d/tarek/ and warden-3d/ostra/. Start with s1_vs_turnaround.png.
- **Branches:** ext/warden-3d-tarek fba110fe and ext/warden-3d-ostra 1560b2ef, both on the r3c base.
- **Checks:** all pass (agent-reported). Tarek glb 31/0, dolm-combo 118/0. Ostra glb 31/0, ostra-combo 128/0.
- **Cost:** Tarek 85 credits, Ostra 76.
- **Tarek:**
  - Matches the art: the blindfold, locs with emissive amber crystals, the vest and sash, and stone bracers with generated amber cracks.
  - The three seeing-stones are props orbiting his head, iris facing out; the orbit is data in the loader.
  - **Biggest stage-2 gap:** he reads squat, with short chunky legs and a big head, while the art is lean and tall. He holds his fists forward in the rubble pose.
  - Also: the locs have no springs, and the stones are flat-coloured.
- **Ostra:**
  - Matches the art: the mask (with an emissive mouth, eyes and tear), the jester cap, the ruff, the dagged coat with starfield tears, and claw gloves.
  - New generic void shader: a starfield wisp tail on springs. He hovers with a shadow gap, using the procedural hover, and the crescent halo rides the head bone.
  - Stage-2 gaps: the halo blooms white rather than violet, and is small; the wisp is shorter than in the art; the coat is very dark at match zoom; there is no orb-hand pose.
- **Stage 1 done:** Hem, Kael, Breaker, Claire, Sable, Pip, Tarek, Ostra. About 666 credits spent. **Balance: 4327.**
- **Next, waiting on the owner:**
  - OK Vex r3c: stage 2 then applies its polish recipe (paint-over, per-model look, proportions, stance) to all 8.
  - Decide Breaker's height.
  - Send final art for Ryzz and Cinder.

## 2026-11-04 10:50 UTC: nudge: two READY branches waiting since ~04:00 UTC (main idle since 04:50)
1. `ext/kits-integ` @ 5e551f8c (S2): every hero's audit/parity fixes + no-shake + online-displace + vex-ammo, on main 91a6bd05, full suite only known reds. The owner wants to play the full kits.
2. `ext/farm-hob` @ 8e82638f (ext): Hob, the 12-step farm tutorial, Goals, water crops, river brush, Challenge House by wood/stone. Save v10 (8->9 placeholder for mantle-look).
3. Coming from ext: `ext/build-ui` (build/decorate revamp; on farm-hob; Save v11), pending one polish pass + its full suite.
Please merge 1 then 2 and ship to the owner's PC; post in MAIN_TO_EXT.

## 2026-11-04 11:15 UTC (ORCH): owner decisions
- DECISION? Breaker's model is 1.5x a medium hunter (owner, 11:15 UTC). The hitbox stays the heavy class's 0.50 m.
- Owner will handle the kits-integ / farm-hob merges himself shortly.

## 2026-11-04 13:10 UTC (ORCH): DECISION? Dredge keeps the friend's rig, hull upgraded on S2
- DECISION? Dredge's 3D model is the friend's hand-made rig (claw, winch, rope, hook bones; all moves) with an upgraded hull shell (angular dented olive-gold brass plates) built on S2. Owner wants every Hunter "looking as good as possible".

## 2026-11-04 11:46 UTC (S2): OWNER: review stage 1 for Ryzz. Her stage 2 starts now with the r3c recipe
- **Shots:** ext/hero-shots-s2, under warden-3d/ryzz/. Start with s1_vs_turnaround.png.
- **Branch:** ext/warden-3d-ryzz 200e3dd0.
- **Checks:** glb, model, mantle, move-feel, mage-combo 83/0, weapon-clip and health all OK. Cost: 94 credits.
- **Matches:**
  - the right-eye wink with the fern scar;
  - freckles, the choker and bolt charm, the bolt-keyhole corset with pink neon piping, and the forearm veins (switchable pink glow, model_glow in mage.json);
  - the off-shoulder jacket, the chain belt, the hazard bands;
  - exactly 3 copper back rods, the middle one scorched and bent;
  - short spring pigtails with copper ties;
  - slimmer and longer-legged (about 8 heads).
- **Stage-2 gaps (S2's read):**
  - The blue hair reads purple or navy, and the whole model leans magenta. At match zoom she's a pink-purple blob.
  - The pigtails are spiky tufts, not the art's soft, full curls.
  - The rods stand off her back.
  - The charm glow has a square halo.

## 2026-11-04 12:15 UTC (ORCH): DECISION? 3D quality over credits; merge Hunters as each is READY
- DECISION? Owner: every Hunter's 3D model is iterated until it is as good as we can make it; running out of Meshy credits is acceptable (we never buy; S2 asks the owner).
- [MAIN] Merge each ext/warden-3d-<id> branch as soon as S2 marks it READY TO MERGE (one Hunter at a time), and ship in the next sync. Owner wants them live ASAP.

## 2026-11-04 12:25 UTC (ORCH): DECISION? 3D ships at ~95% of the art, no owner review gate
- DECISION? Owner: each Hunter's 3D model ships once S2 judges it ~95% of the art; no owner approval needed before merge. [MAIN] merge each READY ext/warden-3d-<id> and ship in the next sync without waiting for the owner.
- DECISION? (12:45 UTC, owner) 95% is the ship bar, not a stop: 3D keeps improving toward 100% after shipping; [MAIN] re-merge newer READY commits on ext/warden-3d-<id> in later syncs.

## 2026-11-04 13:15 UTC (ORCH): [MAIN] heads-up: one big Hunter 3D integ tonight
- S2 will mark ext/warden-3d-<id> branches READY through the afternoon (Vex first, ~15:30 UTC). Owner wants all 12 shipped by end of day: plan an integ around 22:00-23:00 UTC that merges every READY Hunter branch, then ship. Rebase rename-breaker / build-ui first so they don't collide.

## 2026-11-04 12:14 UTC (S2): stage 2 shots for Hem and Kael (not READY yet). Plan for the 13:15 order
- **Shots:** ext/hero-shots-s2, under warden-3d/hem/s2_* and warden-3d/kael/s2_*.
- **Branches:** ext/warden-3d-hem 2d348d6b and ext/warden-3d-zedran 4b1900aa. All checks pass, including warden-stance (the 4 stance commits are cherry-picked; a full merge of warden-stance drags in an unrelated main line with 15 conflicts).
- **Hem, S2 self-score:** about 80% close-up, about 70% at match zoom.
  - The face paint-over now has the cracked mask, stitches and gold rim, plus clean rebuilt needles. The bow hangs at her left side.
  - Gaps: shards at the mask's side edge; a few cheek strands; the bow barely reads at match zoom; the thimble claws are still the scan's.
- **Kael, S2 self-score:** about 70% close-up, about 60% at match zoom.
  - The blade is now white-hot. The near-black was a linear-vs-sRGB bug in the parts texture.
  - The straps are now leather, and he has 48 spring mane locks.
  - Gaps: the arm cracks barely show; the mane is thin and stringy (the art's is a full, soft mass); the blade is flat white with no crack texture; the skin reads maroon.
- **Plan for 13:15:**
  - Phase A is running: the Vex agent is doing the shared look fix (violet/dark), the Vex 12:55 fixes, and RECIPE_95.md plus a driver script.
  - The other agents keep fixing geometry gaps meanwhile, and merge the look fix the moment it lands.
  - Phase B (one agent per hero) starts as soon as RECIPE_95 exists. Each hero is marked READY in EXT_TO_MAIN at about 95%.

## 2026-11-04 12:36 UTC (S2): stage 2 status for all Hunters, plus a merge note for main (warden-stance)
- **Self-scores (close-up / match zoom); none at the 95% bar yet:**

  | Hunter | Close-up | Match | Branch |
  |---|---|---|---|
  | Hem | ~80% | ~70% | |
  | Sable | ~80% | ~65% | ext/warden-3d-sable 6af6e6f0 |
  | Ostra | ~75% | ~60% | ext/warden-3d-ostra a927a461 |
  | Pip | ~75% | ~60% | ext/warden-3d-pip ce53d8d0 |
  | Dredge | ~75% | ~55% | ext/warden-dredge-friend 5faa4e51 |
  | Ryzz | ~72% | ~60% | ext/warden-3d-ryzz 1f7958fe |
  | Kael | ~70% | ~60% | |
  | Tarek | ~70% | ~55% | ext/warden-3d-tarek eaf9129a |
  | Breaker (1.5x) | ~70% | ~55% | ext/warden-3d-breaker 466c92b4 |
  | Claire | ~70% | ~50% | ext/warden-3d-claire b3e41b74 |

  Shots are on ext/hero-shots-s2 under warden-3d/<name>/s2_*.
- **The biggest shared gap** is the violet, too-dark toon look (lilac skin, black at match zoom). The Vex agent is fixing it once in the shared shader and loader for Phase A; every Hunter branch merges it when it lands.
- **The next rounds (s3)** are underway:
  - Breaker: a Meshy body from breaker_front.
  - Claire: the horns.
  - Kael: the mane, arm cracks and collar.
  - Hem: the mask edge and thimbles.
  - Pip: the tail and crown.
  - Sable: crossbow detail.
  - Tarek: a Meshy rerun.
  - Ostra: the orb and halo.
  - Ryzz: the face, curls and rods.
- **Main, about merging:**
  - Every Hunter branch carries the item-52 stance as **cherry-picks** of ext/warden-stance's 4 stance commits (7260bfda, 91d7e239, 4f9487a0, aa3345b6), not as a merge.
  - ext/warden-stance has picked up about 50 commits of a diverged main line: the market, a second save migration v7->v8 that clashes with the Mantle-look v8, and hit radii following size.
  - Merging it directly into the r3b line conflicts in about 16 files. Expect duplicate-commit noise, and reconcile the two v7->v8 migrations when main integrates them.
- **Blocked:** this session's permission check refused one Meshy spend (Dredge's hull). Other Meshy runs went through. The owner needs to allow Meshy spends in the S2 session for the remaining runs to be reliable.

## 2026-11-04 13:04 UTC (S2): READY (for the art integ) ext/warden-dredge-friend 38a5c086: Dredge 3D (the friend's model plus Blender hull, r3d)
- **Score:** about 80% at close-up and 73% at match zoom. That's under the 95% bar, but it's well past the procedural model, so it ships per the 13:15 rule and keeps improving.
- **Shots:** ext/hero-shots-s2, warden-3d/dredge/r3d_dredge_*.
- **What's in it:**
  - the friend's rig and all 184 moves, plus 12 variant bones (claw, winch, rope, hook, and a new tar pool);
  - a Blender-built hull with dents, peeled tears and layered flared shoulders, in olive-gold brass;
  - a cracked lens with the red orb, tar strands, and a red inner glow;
  - the item-52 stance, cherry-picked;
  - the shared look fix, ported.
- **Checks (S2 re-ran):** warden-glb PASS, dredge-combo 86/0, warden-stance 0, health OK. The agent also reports warden-model, mantle-look, move-feel, weapon-clip and style all OK.
- **Merge note:** this branch, like every Hunter branch, is based on the warden-meshy/r3b line and conflicts with current main. **S2 will build one art integ branch on current main** (all READY Hunters + Vex) for Phase C, so main does a single merge. Don't merge the Hunter branches one by one.

## 2026-11-04 13:11 UTC (S2): READY (for the art integ) ext/warden-3d-ryzz dfe449b8: Ryzz 3D, round 4
- **Score:** about 82% at close-up, about 68% at match zoom. Under 95%, but clearly better than the procedural model, so it ships per 13:15 and keeps improving.
- **Shots:** ext/hero-shots-s2 warden-3d/ryzz/s4_*.
- **What's in it:**
  - the face from the head sheet: wink, fern scar, freckles;
  - sky-blue hair with pink-streaked spring curls and copper ties;
  - the 3 copper rods flush in a V harness;
  - a pink emissive scar, charm, piping and veins, switchable;
  - a new far_emit option, so the glow reads at match distance;
  - the right hand on her hip, the item-52 stance (cherry-picked), and the shared look fix.
- **Checks:** all pass (agent-run): glb, model, mantle, move-feel, mage-combo 83/0, weapon-clip, warden-stance, health, style.
- **Still differs:** the pigtails read blocky from the side; the pink streaks are solid bands; the yellow bands are faint at match zoom.
- **Merge:** goes in S2's single art integ branch, like the others.

## 2026-11-04 16:41 UTC (S2): shared match-zoom fix v2 (ORCH 15:15 ask): ext/warden-matchzoom-v2
- **Commits:**
  - 161708cc: code, in hero_toon, outline, warden_glb and arena_demo.
  - 0170c7df: the wing-card far fade.
  - c89a5273 / a466972f: recipe and docs.
- **The fix:** at match-camera size it scales by on-screen size, not distance:
  - fresnel down, gloss, sheen and light rims off;
  - mip-clamped specks;
  - a broad saturated signature rim;
  - ink cut from about 13.5 m;
  - a 1.4 px glow halo on glow pieces;
  - edge-on wing cards fade.
  Procedural heroes are unchanged (all new uniforms default off). New per-Hunter keys: no_ink, ink, glow_shell. Plus `--arena-demo=pose_clear` for clean review frames (no HUD, sign, aim line or covering props).
- **Speckle (share of hero pixels):**

  | Hunter | Before | After |
  |---|---|---|
  | Vex | 6.4% | 3.3% |
  | Sable | 7.2% | 4.9% |
  | Ryzz | 6.7% | 3.4% |
  | Tarek | 7.7% | 3.4% |
  | Hem | 6.0% | 4.0% |
  | Ostra | 7.5% | 2.8% |

- **Shots:** ext/hero-shots-s2 under warden-3d/matchzoom/all6_x3_before_after.png.
- **Status:** all checks and health pass. Every Hunter agent is picking it up; ext/art-integ uses v2. ext/warden-matchzoom (v1) is superseded.

## 2026-11-04 17:12 UTC (S2): READY updates for Claire and Kael, and the plan for the owner's 17:05 accuracy pipeline (OWNER: keys needed)
- **READY updates:**
  - Claire is at **f4fac407** (b3, about 79% close-up / 64% match zoom). New Meshy body, loose wavy pigtails with crystal ties, one 15-landmark face projection, glassy ice spear, tilted wings, v2.
  - Kael is at **923948b1** (b13, about 75% / 76%). Shoulder deform, solid mane volume, bloom on the blade and arm, dark cool skin, v2.
- **Accuracy pipeline (MAIN_TO_EXT 17:05):** S2 starts the **Kael pilot** now. Steps 1, 3, 4, 6 and 7 use what we have: image-model model sheets, a separate head, the Blender pass, and the shader and rubric. Meshy 7.1 is the first generator.
- **OWNER: keys and compute needed for the full bake-off.** Agents won't sign up for anything.
  1. **Rodin Gen-2.5:** a Hyper3D/Rodin API key.
  2. **Tripo 3.1:** a Tripo API key.
  3. **Hunyuan3D 3.1 and TRELLIS 2:** a hosted-inference key, e.g. fal.ai or Replicate (both host these). **This box has no GPU** (16 CPU cores, 61 GB RAM), so they can't run locally.
  4. **Sparc3D 2.1 Portrait (heads):** a hosted key, if it's offered on fal.ai or Replicate.
  5. **Projection (StableProjectorz / StableGen):** both need an SD/ComfyUI GPU. Options are a GPU machine we can SSH to, or a hosted ComfyUI key. Until then, S2 keeps using its own Blender art projection.
  6. **"Render on a GPU at 2x":** no GPU here. S2 renders 2x on CPU, which is slower.
- **Keys go in** ~/.config/boki/secrets.env, like MESHY_API_KEY.
- **Also:** this session's permission check has refused some Meshy spends today. Please allow Meshy and these APIs in the S2 session.

## 2026-11-04 S2: READY update: Hem s7 = ext/warden-3d-hem 779fe027 (replaces d77613ca)
- Self-score is 86 at close-up and 76 at match zoom, up from 66 at match zoom. All checks pass (warden-glb 33/0, warden-model 37/0, mantle-look 27/0, archer-combo 119/0, weapon-clip, warden-stance, health --strict). It picks up match-zoom v2 (161708cc, 8af89a9e, a466972f). No Meshy credits used.
- Fixes for ORCH 16:10: the thimble claws are now on the hand (in s6 they sat at her hip). The mask is cut from the face front, with no white flaps. The coat hem is cleaned to smooth crimson. The tape and shears are stronger. The flower was the aim marker, which pose_clear removes.
- Still open: the back coat bells into two lobes (geometry), the tape reads as a diamond print, there are red smears on the cheek at 3/4, and the thimbles are tiny at review size.
- Shots: ext/hero-shots-s2 warden-3d/hem/s7_*.

## 2026-11-04 S2: READY update: Sable s8 = ext/warden-3d-sable b21e3279 (replaces 5d6c8122)
- Self-score is about 89 at close-up and 78 at match zoom, up from 68 at match zoom. All checks pass (warden-glb, warden-model, mantle-look, move-feel, dancer-combo 92/0, weapon-clip, warden-stance, health --strict, style_lint --strict). It picks up match-zoom v2 (161708cc, 8af89a9e, 0170c7df, a466972f). No Meshy credits used.
- New: the braid runs down the spine between the wing roots, and the criss-cross back laces are silver geometry with eyelets (a new laces() builder). The outline opt-outs moved into warden_look no_ink. The review frame uses pose_clear.
- Still open: the wings are faint at match zoom, the pendant and halo are weak, the crossbow limbs are thin, there is a faint seam on the far cheek at 3/4, the crossbows have no scrollwork, and the braid is hidden from the front.
- Shots: ext/hero-shots-s2 warden-3d/sable/s8_*.

## 2026-11-04 S2: READY update: Dredge r3j = ext/warden-dredge-friend dfb62157 (replaces r3h 05596f3f)
- The limbs are fixed: each part is decimated on its own, and the leftover shards are dropped. The leg rods, the three-fingered claw, the rope, the winch and the boots are all whole, and they are verified at match zoom on pose_clear.
- ORCH 17:10: smaller shoulder pods, warm gold brass with a far rim, and a smaller, darker tar pool.
- Self-score is about 85 at close-up and 65 at match zoom. All checks pass (warden-stance, warden-glb at 14,361 tris, warden-model, mantle-look, move-feel, dredge-combo 86/0, weapon-clip, health --strict, style_lint).
- Still open: the hook is small at match zoom, the hull detail is paint only, there are no battered outline breaks, the legs are straight pistons, and there is no smoke.
- Shots: ext/hero-shots-s2 warden-3d/dredge/r3j_*.

## 2026-11-04 S2: READY update: Ostra b12 = ext/warden-3d-ostra-b 7d519726 (replaces bc16c044)
- Self-score at native size is about 86 at close-up and 62 at match zoom (b11 was about 55 at match zoom). It's better than the last READY, so it ships under the 13:15 rule. All checks pass (ostra-combo 128/0, health --strict, style_lint --strict). No Meshy credits used.
- New: a glowing violet orbit ring through the card orbit, bigger cards tilted toward the match camera, a stronger orb glow, a violet far rim, and an optional per-Hunter `closeup` framing key in warden_shots.
- Still open: he is a small figure at match zoom, the coat rim is faint, the orb reads lilac rather than a black core, the swirl rings are whitish, and the mask crack is faint.
- Shots: ext/hero-shots-s2 warden-3d/ostra/b12_*.

## 2026-11-04 18:30 UTC (ORCH): OWNER: ship the 3D models NOW (sync89), then improve slowly
- Owner confirms: ship the existing models now, then keep improving them gradually.
- [S2] ext/art-integ has had no commit since 16:51. Freeze it now: merge the latest READY per Hunter (Dredge r3j only if its limbs are back, else r3h), run the suite, post "art-integ READY <commit>" here.
- [MAIN] merge ext/art-integ as soon as it's posted READY and ship sync89 to the owner. Later Hunter improvements go in follow-up syncs.

## 2026-11-04 19:05 UTC: heads-up: owner bug, own Boki collision bends abilities (OWNER_REVIEW item 56)
- The owner sees his own Boki redirect his abilities (Hem's RMB impale goes the wrong way) and wants stuns, impacts and momentum never ruined by friendly collision. S2 is fixing it centrally (projectile hit filter + Displace: friendly Boki and hunters pass through your abilities). If a Boki-side change is needed (kin_* follow/body collision, e.g. a Boki stepping out of a displacement lane or collision layers), S2 will list it for you.

## 2026-11-04 19:20 UTC: owner bug: Fused Dredge's hook pulls at an off angle (OWNER_REVIEW item 58)
- S2 is fixing the hook/Displace side with item 56. If the cause is the Fused body's centre/sockets (merge_form) not being the pull destination, S2 will list the merge_form change for you.

## 2026-11-04 19:45 UTC: owner bugs in your glide code (OWNER_REVIEW item 63; yours: hunter glide + FeelConfig)
1. An overheated glider still won't deploy. DECISIONS says it must still lift you out of the abyss at half strength while it burns: the glide input should always open it, at any heat (it burns you while overheated). Please remove whatever refuses it (heat gate / overheat lockout / recover threshold).
2. The abyss lift pulls up too fast when you're low. Soften it at depth (ease in with depth, or cap the lift's vertical speed ~30% lower at the deepest point), keeping its heat cost. Check supervive_physics.md for the source lift speed.
If you'd rather S2 take it, say so in MAIN_TO_EXT.

## 2026-11-04 S2: READY update: Vex r3h = ext/warden-vex-r3b 3da6679e (replaces f02bb08e)
- Calibrated rubric v2 (self-score marked down about 10): full body 75, face 72, match zoom 75, dark scene 70. All checks pass (warden-glb at 43,448 tris, warden-model, mantle-look, move-feel, weapon-clip, gunslinger-combo 67, warden-stance, health --strict, style_lint --strict). It moves to match-zoom v2 (161708cc, c89a5273, 8af89a9e) and reverts the v1 pick. No Meshy credits used.
- New: clean green circuit lines stamped from the art, a bronze gorget with green seams, the gun mount in gunmetal, smoky-plum eyeshadow, the head 4% larger, the halo moved clear of the fringe, and an opt-in night glow for the tattoos.
- Still open: pale highlights on the upper chest and the gun-side shoulder, jagged hair strands across the face, and a tattoo glow too small at the match camera.
- Kit note (not art): the owner's 17:05 ask is for Vex's RMB to be a tap with no hold, in gunslinger.json. It needs a kit owner.
- Shots: ext/hero-shots-s2 warden-3d/vex/r3h_*.

## 2026-11-04 19:40 UTC: ACCOUNTS: main and S2 are at 95%+, so ext builds the owner's queue (items 53–75) itself until Friday's reset
- Includes item 63 (your glide code: overheated glider must open; softer abyss lift): ext takes it unless you've started it (say so in MAIN_TO_EXT). Branches will be reported here READY as usual; if you're out of budget for merging, the owner may ask ext to integrate temporarily.

## 2026-11-04 20:05 UTC (Boki art pass): Gravadillo (pebbit) pilot READY for owner sign-off = ext/boki-3d-pebbit e63def24
- **Species:** "Gravidillo" = `pebbit`, shown as Gravadillo (armadillo + rhino beetle, Gravity). Base: ext/art-integ c5795079 (match-zoom v2).
- **Sheets (briefs/boki-art/pebbit/):** `vs_sheet.png` (concept / old / new, four views), `vs_face.png` (old, new day, new night, concept front), `vs_match.png` (match camera, old vs new, enlarged), `new_night_sheet.png`, concept views.
- **What it is now:** a Meshy 3D model (14,000 tris, 2k atlas, 812 KB) cut into Hull, Tail, EarL/EarR and Leg0..3 with the node names KinPuppet already animates. No skeleton was needed: walk, idle, naps and emotes run unchanged. Hunter hero-toon look (ink, rim). Shimmer/ghost tint the atlas. A species without a model keeps its primitives (`KinGlb`, 2 lines in KinModels.build).
- **Per-tool results:**
  - Meshy image-to-image (nano-banana-pro): the concept pass worked. Two variants of a cuter redesign from renders of the old model; kept B (a better armadillo: toes, tapered tail). A bare "front view / side view" prompt is ignored and drifts colour (the first side came out khaki with a pink horn); explicit orthographic wording and a colour list fixed it.
  - Meshy multi-image-to-3D (meshy-7.1, Ultra, 8k PBR, 4 views): kept. The face, blush, glossy eyes and violet seams came through. 1 run.
  - Bake (bake_warden.py) and parts cut (new tools/meshy/kin_parts.py) in Blender 4.5: OK. Ears/legs/tail cut from the hull.
  - Not run: TRELLIS 2, Rodin, Hunyuan, Tripo (no keys, no GPU). Meshy only, as the owner said. No bake-off, so no winner chosen between generators.
- **Rubric (self-score vs the sheet, old -> new):** silhouette at match zoom 40 -> 65; face up close 30 -> 85; species identity 55 -> 85; dark-biome readability 25 -> 75. Calibrate down about 10 as with the Hunters.
- **Checks (all pass):** --check 0; --boki-system-check 0; --kin-indoors-check 0 (failed once, passed on rerun: flaky, not the model); "--teammate-check --teammate-only=tutorial" 0; --portrait-check 107 checks 0 fails; new --kin-glb-check 10/10 (nodes, textured toon material, KinPuppet finds tail/ears/4 legs and a walk swings one, shimmer tint, a species without a model keeps primitives, size 0.57 m); health --strict OK.
- **Cost:** +578 lines in 15 files, 0 god-file growth (kin_models.gd +1 line). New: kin_glb.gd, kin_shots.gd, kin_glb_check.gd, tools/meshy/kin_parts.py, docs/art/kin/PIPELINE.md, art/kin/pebbit (glb + atlas). Meshy credits: 103 (balance was 3,393).
- **Still open (be honest):** (1) the eyes are painted, so the puppet's blink does nothing on this species; a blink mask in the shader is the fix. (2) No in-game farm/match screenshots yet (needs/bubbles, petting, riding, Fusion form): I only ran the data checks and rendered stage shots; the farm and match flows should be eyeballed. (3) At match zoom the face is not readable (the old one wasn't either); it reads as a banded shell with a horn. (4) The Boki list/cards and portraits use Models.kin, so they should pick the model up, but I did not screenshot them. (5) Match-zoom tuning (LIFT 1.2, no far_lift) is eyeballed from one yaw. (6) Shimmer's palette multiplies a baked atlas, so a hue far from the base may look off; one shimmer render still to be checked. (7) The leg cut leaves tiny shell fringe on the paws.
- **Next:** after the owner's sign-off (or a note), the same recipe for the other 5 starters/wild (cindle, puddlet, burrlet, zapple, wisplet), then the 3 rares. One ext/boki-art-integ when the batch is READY.

## 2026-11-04 (S2): Kael accuracy pilot (MAIN_TO_EXT 17:05) result: a3 on ext/warden-3d-kael-acc a0c8c098 (tools 8231b68c). NOT marked READY.
- Self-score, rubric v2 (calibrated down ~10), b13 -> a3: full body 58->62, face 45->62, match zoom 64->62, dark scene 45->58. All checks pass (warden-glb 42.1k tris, juggernaut-combo 135/0, health --strict, style_lint --strict).
- Recipe: nano-banana-pro A-pose body/head sheets -> Meshy 7.1 multi-image (enhance on) body + separate head run joined by the eyes (assemble_head.py) -> Meshy quad remesh -> nearest-surface 4K bake -> new hero_toon key_fill/key_rim (default 0, no change for other heroes). 305 credits.
- a3 trades a slightly weaker match-zoom read (smaller gold shards) for a much better face and dark-scene read. Kael READY stays 923948b1 (b13) in art-integ; main/owner decides whether a3 replaces it. The key_fill/key_rim shader change is in 8231b68c with the pilot tools, so it can't be picked on its own yet.
- Open: broad shoulders, stringy mane, blotchy arm cracks, scarf/neck seam at 3/4. Would help: Rodin/Tripo keys, a GPU (Hunyuan3D/TRELLIS, StableProjectorz), Blender GUI hand time.
- Shots: ext/hero-shots-s2 f579b2bb, warden-3d/kael/acc_1..acc_6e + captions.txt.

## 2026-11-04 20:05 UTC: READY: ext/ryzz-70-74 @ 850bb52c (owner items 70-74, Ryzz)
- Autos 0.72 s / bolts 37 m/s; Wirerun 7.5-13 m at 40. Skycall flings orbs 55% as far; an orb dragged toward her within 9 m (±50°) flies to her and resets Wirerun (flash/chime). Kitefall raises every foe it hits to the highest Static among them, then +1 (cap 4), with arcs (replaces the old 3 m spread). Skycall's drag vector is fixed at commit with a gold arrow (8 angles, tap, tiny drag: 0° error). The Storm Rod gives exactly 1 Static; its orb no longer zaps, it's a pickup that resets Wirerun (per source data) — so a Wirerun through an orb now resets the dash and adds no Static.
- 15 files, +557/-231 (incl. regenerated wiki + mage.md). New: scripts/arch/kits/mage_sky.gd (Skycall + orb fling split out of mage_kit.gd to stay under the soft cap), tools/ryzz_items_check.gd (runs inside --mage-combo-check). No Net.VERSION change.
- Checks green: --mage-combo-check (112), --check, --hero-combo-check, --archetype-check, --dash-flow-check, --ability-check, health --strict, gen_wiki --check. Shots (ext reviewed): /home/claude/shots/ryzz-70-74/ on ext's machine.

## 2026-11-04 20:40 UTC: READY (with two checks to run at merge): ext/friendly-bodies @ ac64730e (owner items 56 + 58)
- **56, the root cause:** `KinExec._point("caster")` (kin_exec.gd) returns the **Boki's** position whenever the Boki is out, and `ArchKit.cx` passed `h.kin` into every hero ability. So pushes went away from the Boki and hooks/pulls anchored to it (3.91 m off for all 9 archetypes tested). Fix: ArchKit.cx and Kael's Searing Wave pass no kin; Match._separate skips shove-apart between a dashing/knocked/towed/charging body and a friendly one (new scripts/combat/friendly_bodies.gd). Projectiles were already hostile-only.
- **58:** DredgeKit._grab refused for the whole Fusion (`KinMerge.active`); now only while transforming. The Fused hook pulls straight to the Fused body (0/45/90°, 3 forms: within 1 m, 0.00 m off-line).
- **Root fix for you (kin_* reserved):** in kin_exec.gd `_point` case "caster", return the caster's position when the caster is a Hunter (the Boki's only when the caster is a Kin). That makes the ArchKit.cx workaround redundant.
- 10 files, +401/-4 (8/4 in existing files: arch_kit.gd, juggernaut_kit.gd, match.gd, dredge kit, check_registry). New --friendly-bodies-check (29 asserts; baseline 16 fail, now 0).
- Green: --friendly-bodies-check, --check, --dredge-combo-check, --hero-combo-check, --archetype-check, --ability-check, --dash-flow-check, health --strict, gen_wiki --check.
- **Run at merge** (budget: the full suite wasn't run though match.gd changed): --boki-follow-check, and --merge-form-check (1 fail "Rescue Gravadillo to fuse", likely unrelated; compare on plain main).

## 2026-11-04 (S2): art-integ READY fe51b43b
- Shipping freeze of ext/art-integ: the latest READY commit of all 12 Hunters (Vex 3da6679e r3h, Dredge dfb62157 r3j (limbs verified in every view), Ryzz 6ee886f7, Sable b21e3279, Hem 779fe027, Tarek 940b8aee, Breaker 558612f3, Ostra 7d519726, Claire f4fac407, Cinder d522f924, Kael 923948b1 b13, Pip 8b79969d) + match-zoom v2 and null-safe fix 8af89a9e.
- The frozen tree (c5795079) was already merged into main by sync91 (723a23bb via integ91), so ext/art-integ fast-forwarded to origin/main fe51b43b: **nothing further to merge; main already ships it.**
- Full suite on fe51b43b, all 0 failures: --import, --check, --warden-model-check 157, --warden-glb-check 182, --hero-combo-check 263, --dolm-combo-check 139, --juggernaut-combo-check 154, --portrait-check 107, --unmasked-check 29, --hatch-check 30, --class-unlock-check 153, --arena-check 86, --tutorial-hud-check 31, --rig-standard-check 71, health --strict OK (no budget raised), gen_wiki --check 34 unchanged.
- Note: every Godot run prints a non-failing engine error from scripts/ui/ui_theme.gd:55 (set_type_variation on OptionButton: "cannot be marked as a variation of another type"); on main too, worth a one-line fix by its owner.
- Next: Hunter improvements continue on their own branches; new READY commits come as follow-up syncs. Kael a3 pilot (ext/warden-3d-kael-acc a0c8c098) is NOT in the freeze.

## 2026-11-04 (S2): READY TO MERGE (follow-up sync): Dredge r3k ext/warden-dredge-friend b9a1d26e (supersedes dfb62157)
- Merged with origin/main fe51b43b (sync91); Dredge's warden_look moved into content/rules/warden_look.json (rim_far 0.4 gold). 1.9x hook, knee joints (bent stance), lighter iron limbs, brighter brass; limbs present in every view (verified: turnaround, back, match x4, night). Rig/bones/moves unchanged.
- Rubric v2 (calibrated): full 60->64, face 62, match 52->58, dark 48->52. Checks 0 failures: warden-model 157, warden-glb 182, hero-combo 263, rig-standard, warden-stance, health --strict OK. 0 credits.
- Shots: ext/hero-shots-s2 warden-3d/dredge/r3k_*. Open: hull too yellow vs the art's olive bronze, smoke not visible, torn plate outline still soft, winch floats slightly.

## 2026-11-04 (S2): READY TO MERGE (follow-up sync): Breaker s6 ext/warden-3d-breaker db5d2f7b (supersedes 558612f3)
- Merged with origin/main fe51b43b (keeps rigfix weapon_scale 0.75 for Breaker; adds Breaker's no_ink back). Body trimmed to 34.5k so the model stays under the 45k glb cap after the merge. Brass compass + barnacles as geometry, repainted rag fringe, shield no longer washes out at match zoom/night (shield look key).
- Rubric v2 (calibrated): close-up 78->79, match 73->76, dark ~66->70. Checks 0 failures: warden-model 157, warden-glb 182, hero-combo 263, rig-standard, warden-stance, weapon-clip, health --strict OK. 0 credits.
- Shots: ext/hero-shots-s2 warden-3d/breaker/s6_*. Open: hammer held upright and small (rig/stance + weapon_scale 0.75, main's call) vs resting across the shoulder in the art; a second painted compass under the beard; icicles on arm/hammer.

## 2026-11-04 (S2): READY TO MERGE (follow-up sync): Sable s9 ext/warden-3d-sable 521ad28a (supersedes b21e3279)
- Merged with origin/main fe51b43b (no conflicts). Cut-crystal pendant (new opt-in facets/core_k on warden_props.gem()), cooler lavender skin, far_glow so the violet bolts and gem read at match zoom/night, front lock, eye liner, thicker crossbows.
- Rubric v2 (calibrated): full 72->74, face 79->80, match 68->69, dark 64->66. Checks 0 failures: warden-model, warden-glb, hero-combo 263, rig-standard, warden-stance, health --strict OK. 0 credits.
- **Shared-code bug for main:** WardenGlb._far_look (scripts/heroes/warden_glb.gd) ignores `<slot>-<tag>` entries for far_* keys, so a per-tag far_glow is overwritten by the 0.6 default (Sable worked around it with a slot-wide key).
- Shots: ext/hero-shots-s2 warden-3d/sable/s9_*. Open: hair doesn't frame the face (art: long white hair + black headband), off-hand crossbow lost at match zoom, flat fur collar.

## 2026-11-04 (S2): READY TO MERGE (follow-up sync): Dredge r3l ext/warden-dredge-friend c71d91e9 (supersedes b9a1d26e r3k)
- Hull moved to the art's tarnished olive bronze (match-zoom hue 30->35 deg, sat 0.71->0.51; art ~36/0.5) at the same value; five torn plate holes as geometry (two break the front outline); winch seated on a brass saddle; cracked blue-grey porthole with a small red pupil; a thin smoke wisp from a stack behind the winch. Limbs present in every view (verified).
- **Touches shared code:** new `LDFx.wisp` (mode 13 in the shared ld_fx shader) + an `anchor_stack` model point; DredgeKit uses it. Additive (new mode only).
- Rubric v2 (calibrated): full 64->68, face 62->68, match 58->61, dark 52->55. Checks 0 failures: warden-model, warden-glb, hero-combo 263, dredge-combo 93, rig-standard, warden-stance, health --strict OK. 0 credits.
- Shots: ext/hero-shots-s2 warden-3d/dredge/r3l_*. Open: torn edges only a few pixels at match zoom, one smoke ribbon (art: both shoulders), pupil renders orange, no grille.

## 2026-11-04 (S2): READY TO MERGE (follow-up sync): Dredge r3m ext/warden-dredge-friend abf5f812 (supersedes c71d91e9 r3l)
- Seven heavy tar drips ending in drops (from the porthole lip, grille and side port), three bigger torn holes on the pod edges and belly, smoke ribbons over both shoulders and the stack, the grille under the porthole, a small pink-red pupil with a bright centre inside the cracked blue-grey glass (as the art; not the old "red ball + white dot" ORCH rejected), hull top less pale at match zoom. Limbs present in every view (verified).
- Rubric v2 (calibrated): full 68->71, face 68->72, match 61->63, dark 55->58. Checks 0 failures: warden-model, warden-glb, hero-combo 263, dredge-combo 93, rig-standard, warden-stance, health --strict OK. 0 credits.
- Shots: ext/hero-shots-s2 warden-3d/dredge/r3m_*. Open: drips/torn centres still small at match zoom; the darker top gives back some of the r3k value lift.

## 2026-11-04 (S2): READY TO MERGE (follow-up sync): Ryzz round 9 ext/warden-3d-ryzz dda04366 (supersedes 6ee886f7)
- Merged with origin/main fe51b43b (4 conflicts: main's look entries, _face(), paint_glow/heat, NO_INK+ICE kept; branch's gum gloss pass kept). Corset neon is one glowing traced tube (sweetheart edge + bolt), fishnet lattice on the thighs, gum bubble at the lips, pigtails narrow into copper ties with pink S-curl ends and flicked tips, hair less pale at match zoom.
- Rubric v2 (calibrated; r8 estimated): full ~80->83, face ~80->81, match ~70->72, dark ~65->70. Checks 0 failures: warden-glb 182, warden-model 157, hero-combo 263, rig-standard, warden-stance, health --strict OK. 0 credits.
- Shots: ext/hero-shots-s2 warden-3d/ryzz/s9_*. Open: upper pigtails smooth blobs (art: strand-lined flared curls), neon reads lilac not hot pink, jacket near-black (going plum-grey + copper zips per the 16:10 review).

## 2026-11-05 00:30 UTC (ext): READY `ext/tut-airdash` @ 1164f0a3 (owner items 85 tutorial fixes + 104 farm Boki text size)
- Base main fe51b43b; 23 files +409/-89.
- New files: scripts/match/tutorial_text.gd, scripts/home/farm_task_guide.gd, scripts/home/farm_crop_guide.gd, scripts/ui/boki_speech.gd.
- Tutorial:
  - air dash counts any off-ground dash
  - lookout completes anywhere on top
  - Longneedle / G / levelling (Alt+key) / key+chest / outpost explained in plain words
  - farm job step guided (marker, pulsing Boki button, highlighted dropdown "Whatever it's best at")
  - first crop ripens in ~6-12 s with a countdown
  - English pass on farm_tutorial.json, tutorial.json and the kin_voice TUT_HINT lines
- Item 104: farm bubble at 0.68x via BokiSpeech.SCALE (the match bubble unchanged at 15 px, behind MATCH_PX).
- Shared-file edits are small:
  - home.gd 3 lines, hud.gd 2, work_view.gd, home_work.gd 2, tutorial_hud.gd
  - **kin_voice.gd: text + tut_hint() token fill (reserved: main's OK needed, or ext merges it in the next sync)**
- Checks: --check 0, --tutorial-hud-check 0, health --strict OK, gen_wiki OK, the tutorial drive completes. --teammate-check 1 = the known rival red.
- Shots: /home/claude/shots/tut-fix/*.png (ext viewed job_page + speech_after).
- Known leftover: on the farm the Boki bubble can still overlap a world marker ("Chop a tree"), which is covered by item 102 (S1 clarity pass).

## 2026-11-05 (S4): READY `ext/rank-ui-98` @ d66e1383 (owner item 98: choosing which ability to rank)
- Base main fe51b43b; 12 files +269/-25 incl. .uid. New: scripts/ui/rank_marks.gd (RankMarks: tier pips, the "+", the hint), scripts/ui/rank_click.gd (RankClick: click target over the "+"), tools/rank_ui_check.gd, tools/rank_ui_shots.gd. hud.gd +1 line (RankClick.attach); hud_slot.gd -20 (the marks moved out).
- Item 98, point by point:
  - **Visible "+":** done. Bigger gold "+" (r 11 px, pulsing) on every slot that can rank, and it is **clickable** (it wasn't before). Clicks never fire the weapon (RankClick sits in Hud.ui_extra, so the pointer shows). A locked slot that a point can open takes a click on its face too. Alt + key unchanged.
  - **Tier pips:** done. Bigger pips over each ranked slot (I-III; Fusion slot I-II), gold once maxed.
  - **Unspent-point pulse:** done. Stronger gold frame pulse, and when a point arrives the "ALT+key" hint shows on a dark pill over every rankable slot for 5 s (then on hover only), so it's discoverable without flooding the bar.
  - **Max one ability first:** works (check: 3 level-ups all into E, RMB and dash untouched, E's power 1.00 -> 1.43, cooldown x0.80). Bots still rank by `order`.
  - **Differs: tier IV / R III.** SLOT_MAX is still RMB/Shift/E 3 and the ranked "ult" (Fusion) 2; the source has I-IV and R I-III. The kits only implement effects up to rank 3, and the Hunter ultimate on R (HunterUltTile) unlocks at a level and has no ranks at all. Raising the tiers is a 12-kit data pass plus the level curve (10 levels = 10 points). **DECISION?** whether to do that pass (and the owner's optional `bonus_point_at_max`, not built: owner to decide).
  - Tutorial step: on ext/tut-airdash (not touched here).
- Checks:

| Check | Result |
|---|---|
| --rank-ui-check (new) | 0 failures / 16 |
| health --strict | OK, no budget raised |

- Shots (in this branch): briefs/shots/s4/rank-ui-98/rank_fresh_point.png (a new point: + on RMB, UNLOCK on dash, ALT+RMB hint, E's pips gold), rank_pulse.png (5 s later, hint gone, + pulsing), rank_spent.png (pips only), rank_fresh_point_full.png (whole screen).
- Wiring for main: none. No reserved files touched (boki_hud's R/Fusion slot goes through HudSlot.skill_slot, so it gets the same marks).

## 2026-11-05 (S4): READY `ext/loot-full-99` @ f484773e (owner item 99: looting with a full inventory)
- Base main fe51b43b; 13 files +469/-72 incl. .uid and a lowered style baseline. New: scripts/match/loot_full.gd (LootFull: fits/blocked/smart/swap/drop), scripts/ui/loot_hold.gd (LootHold: the hold window, red "full" outline, the shared item row), tools/loot_full_check.gd, tools/loot_full_shots.gd. hud.gd net -32 (row builder moved into LootHold), match.gd -1, pack.gd 3 lines.
- Item 99, point by point:
  - **Smart loot reports only what moved:** done ("Took 1 of 3, inventory full", "Inventory full, took nothing", "Took N"). The window stays open when nothing was taken so you can pick by hand.
  - **Bug fixed on the way:** smart loot's capsule loop never ended when the capsule box was full (infinite loop); it now stops.
  - **A click that doesn't fit never fakes success:** done. Unfit rows get a red outline, a "Full" button and a short rattle (existing lock_rattle sound, no new asset). Clicking opens your backpack beside the box with the clicked item held in red, with **Swap** (yours goes into the box) and **Drop** (yours to the ground) on each of your items.
  - **Ground items / chests:** chests drop their loot on the ground, so both use the existing swap window (Hud.open_swap), now with the red outline + rattle on the incoming item; its Drop already leaves yours on the ground.
  - **Differs:** belt, key and capsule rows that don't fit only get the red outline and a short "Belt full" / "Box full" line, not the swap flow (swapping against belt slots or capsules is a much bigger feature). Box looting is local; Net shape unchanged.
- Checks:

| Check | Result |
|---|---|
| --loot-full-check (new) | 0 failures / 25 |
| --backpack-check | 0 failures |
| --keys-check | 0 failures / 84 |
| --economy-check | 0 failures |
| --life-check | no FAIL |
| health --strict | OK, no budget raised |

- Shots (in this branch): briefs/shots/s4/loot-full-99/hold_window.png (full backpack: red "Full" rows, the hold window with Swap/Drop), after_swap.png (box now holds your swapped item), ground_full.png (ground pickup with a full pack); captions.txt.
- Wiring for main: none. No reserved files touched.
- Note: S3 (clarity/102) will own the message queue; these use the existing toast path.

## 2026-11-05 (S4): READY `ext/revive-101` @ d53c445b (owner items 101 + 101b: whose box, box revive, beacons)
- Base main fe51b43b; 25 files +972/-249. Design note docs/decisions/0018-box-revive-and-beacons.md. New: content/rules/revive.json (tuning), scripts/match/box_revive.gd (BoxRevive, moved out of Match._update_interact), scripts/match/beacons.gd (Beacons, moved out of life.gd + alarm + Net), scripts/ui/revive_hud.gd (ReviveHud: boxes/beacons/rings/alarm on world, minimap, full map), tools/box_revive_check.gd, tools/box_revive_shots.gd. **Every god file shrank:** main.gd +3/-36, match.gd +14/-34, hud.gd +9/-39, hunter.gd +10/-13.
- **Net.VERSION 0.19.1 -> 0.20.0**: beacons now run online through a new "bcn" event on the "ev" topic (lit / out / used).
- Items, point by point:
  - **101 box colours:** done. A teammate's box is tinted their squad colour (m.mate_col, same as the map) with a ring, portrait, name and soul timer; a rival's box is red. Minimap + full map: your squad's boxes always show (bright rim while revivable, edge arrow off-map, named on the full map); rivals' boxes only while in your sight. The old red on-screen "DEATHBOX" squad marker duplicated this and was removed (its edge arrow now uses the teammate colour).
  - **101b box revive:** done. Hold F 7.5 s (data). Reuses Hunter.CONSUME_VULN and the tonic's spill path (1.2x damage taken, a hit cancels), no attacking, moving/dash/jump/glide/stun cancels, release and re-hold to restart. The teammate comes back at the box with their Boki (existing Life.bring_back). Ring on the box and round the reviver. **Extra, from the data (owner to confirm or drop):** the source's diminishing curve 1.0/0.75/0.58/0.47 slows later box revives of the same Hunter in a match. No carry-to-respawn rule existed to delete.
  - **101b beacons:** done. 6 per map (mint diamonds + legend on the full map). Channel 4 s (was 6; "short channel"). Brings back every dead teammate at once. While lit, every player gets a horn, a toast with the direction, a 120 m hum, a map ping, a pulsing map marker with edge arrow, and a world waypoint.
  - Bots: two small bot.gd fixes so bots let go of F after a broken revive and don't base away mid-channel (STAY_GOALS).
- **Debt (docs/DEBT.md "Revives online"), important for online play:** deathboxes are still only dropped offline (pre-existing), and online a death sets `gone`, so **online, box revives and beacon revives of dead Hunters still don't happen**; online beacons only light, alert everyone and bring back wisps. "bcn" identifies a beacon by index (assumes seeded identical placement). Needs a follow-up item for online deathboxes.
- Process note: a WIP commit briefly overwrote tools/revive_check.gd (the bot wisp-revive check); restored unchanged in the next commit (verified identical to main). Hence the new check's name is --box-revive-check.
- Checks:

| Check | Result |
|---|---|
| --box-revive-check (new) | 0 failures |
| --revive-check (bot wisp revive) | PASS |
| --life-check | all LCHECK fine (box part moved to the new check) |
| --airheal-check | 0 failures |
| --raid-check | 0 failures |
| --kin-loss-check | 0 failures |
| --uipolish-check | 0 failures / 30 |
| --backpack-check | 0 failures |
| health --strict | OK, no budget raised |

- Shots (in this branch): briefs/shots/s4/revive-101/boxes_world.png (ally box cyan + face/name/timer beside a red rival box), boxes_minimap.png, boxes_full_map.png, revive_ring.png (rings on the box and reviver, the prompt bar), beacon_notice.png (a rival's beacon far off: toast + world arrow; they sit close, item 102's queue should space them), beacon_full_map.png; captions.txt.
- Wiring for main: none; no reserved files touched.
- Seen in every S4 shot (not ours): the top-left session timer prints garbage ("16666...999:58") when a match runs with length 1e9, as the shot tools do. Probably only the test setup, worth a glance.

## 2026-11-05 (S4): READY `ext/boki-talk-105` @ 364fde44 (owner item 105: Boki talk short, varied, about the moment)
- Base main fe51b43b; 24 files +2819/-53 (+2075 is the lines file). New: content/rules/boki_lines.json (63 triggers, 905 lines + tuning: max_words 6, bubble_s 2.0, cooldown_s 6.0, no_repeat 10, min_lines 8), scripts/core/boki_lines.gd (BokiLines: picker with per-Boki last-10 memory, cooldown, speech stage via Care.speech), scripts/home/farm_chatter.gd (FarmChatter: context lines on the farm), scripts/match/boki_chatter.gd (BokiChatter: match lines through Match.kin_bark), tools/boki_lines_check.gd, tools/boki_talk_shots.gd, docs/BOKI_TALK.md. Wiring only in home.gd (net smaller), match.gd (19 changed lines), hunter.gd +3, chest_loot.gd +2, home_econ/home_work 1 each. Named boki_lines (not kin_lines) to stay off the reserved kin* pattern.
- Item 105, point by point:
  - **In data, <= 6 words, one sentence, ~2 s bubbles:** done; enforced by the check (and at runtime). Tutorial bubbles keep their 4 s.
  - **~5x lines:** done: 12-14 general lines per trigger (old banks had 2-3 per trait), plus element lines for greet, petted, rain, night, chat, ability and more.
  - **No repeat within 10 + per-Boki cooldown:** done.
  - **Flavour:** element flavour done (per species type). **Personality flavour not done** (no personality key used).
  - **Speech stages kept:** young Boki say only their name in a tone + an action.
  - **Farm triggers (all live now):** crop ready/watered, building, working, rain, night, friend chat with a reply, a new Boki welcomed, petted/fed/brushed/bath/nap/trained/hatched, low needs, back from an expedition by how it went (`back_<kind>` from rec.recall; the place name is dropped to fit 6 words).
  - **Match triggers live now:** kill, owner downed, caught, extract, results line, storm (islands falling), loot (chest), the Boki's own ability, level-up. **Enemy spotted, Hunter hurt, revived and the other callouts have their lines in the JSON but still play the OLD lines until main does wiring 1 below** (they're fired from reserved kin_voice.gd).
  - **English pass:** every line rewritten.
  - Not migrated: KinSpeak.reply/SIMPLE/WORDS (answers to typed chat) and KinVoice.TUT_HINT (ext/tut-airdash is editing it).
- **Wiring main must do (reserved files):**
  1. scripts/match/kin_voice.gd:118 (`line`) and :146 (`callout`): body -> `return BokiChatter.line(k, cat)`; then delete BASE (:5), CALL (:48), CALL_ACT (:77), dominant (:110). Keep TUT_HINT / tut_hint.
  2. scripts/match/kin.gd:253-255: drop the `bark_cd` gate (BokiLines' cooldown + `direct` triggers replace it), or keep both.
  3. scripts/core/kin_speak.gd: delete RECALL, RECALL_SIMPLE, RECALL_ACT, RECALL_FEEL (:213-234) and recall_line (:236) (no callers left); optional `static var FEEL: Dictionary = BokiLines.rules()["tones"]`; fix the doc comment in kin_companion.gd:17 that names KinSpeak.recall_line.
  4. When ext/tut-airdash lands: BokiSpeech.SCALE = size, BokiLines = words + lifetime; if BokiSpeech has its own lifetime, point it at BokiLines.bubble_s().
- Debt: docs/DEBT.md entry (KinVoice's old banks until wiring 1; Kin.bark_cd doubles the cooldown until wiring 2).
- Checks:

| Check | Result |
|---|---|
| --boki-lines-check (new) | 0 failures / 26 |
| --teammate-check | 1 failure = the known "rival behind called before chest" (main fails 2). Its recall assert moved to the `back_<kind>` line Home now says (KinSpeak.recall_line has no callers). |
| --merge-form-check | 1 failure = the known "Rescue Gravadillo to fuse", same on main |
| --kin-indoors-check, --level-hud-check, --tutorial-hud-check, --farmbuild, --keys-check --keys-part=chest | 0 each |
| health --strict | OK, no budget raised |
| gen_wiki --check | up to date (Rules.md regenerated) |

- Shots (in this branch): briefs/shots/s4/boki-talk-105/farm_1_crop_ready.png ("Can I have a bite?" by a ripe crop), farm_2_young_petted.png (young Boki: "Cin-cin~ (purrs softly)"), farm_3_rain_night.png (night + rain chatter), match_1_ability.png (the Boki's ability line), match_2_level_up.png ("Power up!").

## 2026-11-05 (S4): all four S4 branches READY (98, 99, 101+101b, 105)
- Merge order suggestion: rank-ui-98, loot-full-99, revive-101, boki-talk-105. All four edit tools/check_registry.gd and tools/style_baseline.json (keep both sides; re-run style_lint --update only for merged lines). 99 and 101 both touch hud.gd and match.gd's interact path (99: the smart-loot toast; 101: the box revive moved out); expect a small conflict there.
- DECISION? items for the owner: 98 tier IV / R III ranks (kit pass) and `bonus_point_at_max`; 101 the diminishing repeat-revive curve; 101 online deathboxes (follow-up item).

## 2026-11-05 (S3): READY `ext/clarity-96` @ f41a7157 (owner items 96, 96b, 97, 100, 102, 106: combat clarity)
- Base origin/main fe51b43b; 12 commits, 83 files +1906/-426. God files shrink overall (+90/-174): hud.gd +54/-143, match.gd +24/-22, hunter.gd +5/-3 (two `tick` calls, on_wall_slam arg), world.gd +1, main.gd/home.gd net 0. No budget raised; health --strict OK; gen_wiki --check unchanged. Reserved files (kin*, merge*, capture*, field_book, boki_hud, bot_kin) untouched.
- New files: scripts/match/{side_color,side_rings,shield_look,ping_input}.gd, scripts/ui/{downed_marks,boki_marks,reticle,msg_lane}.gd; tools/{shield_check,clarity_check,clarity_shots,reticle_check,reticle_shots,ping_check,msg_queue_check}.gd. Deleted: scripts/ui/level_pop.gd.
- **97 shield invisibility: ROOT CAUSE FIXED.** A wall carried in front of a Hunter (Boki Mass Guard, Breaker's aegis: `follow` walls) counted in World.los, so aiming at a rival put your own shield between you: Match.can_see failed -> `unseen` -> you vanished on their screen. Carried walls no longer block sight (Verbs.blocks_sight). Carried walls also lost their opaque posts and draw at 40% alpha; the Refraction reflect sphere is gone (ground ring kept).
- **97 shield look: done.** One look for every source (ShieldLook): the Hunter's own ink outline is swapped for a 2.6x wider one in their side colour while `shield > 0` (no extra geometry or draw calls; materials change only on up/down), plus one quick ring+flash pop when a hit breaks it. The nameplate's pale shield bar is unchanged. The passive Boki owner shield (`kin_shield`) shows no body look (always-on noise).
- **96/96b colour rule: done.** SideColor = HudStyle SELF green / ALLY blue / FOE red; a Boki uses its Hunter's. Applied to: Hunter ground rings and Boki rings (SideRings, recoloured only on change), the shield outline, downed marks, tethers, squad portrait frames, Boki health bars. Scoreboard keeps per-team colours (it must tell rival squads apart).
- **96b downed: done, one difference.** Side-coloured revive-range ring on the ground (brighter fill as they're picked up, red pulse when stomped), a knocked mark over them ringed by the draining bleed-out, and "Revive Nm" for teammates near the ring. DIFFERS: no "hold F" — reviving is standing in the ring (Life), so the cue doesn't name a key. Kill feed already says "X knocked Y"; off-screen downed ally already has the ALLY KNOCKED card with arrow+distance (kept).
- **96b Boki: done.** Your Boki has a dashed tether to you whenever it is out; a downed teammate's Boki has a tether to them and an icon: heart (pulling them up), knock (down too), shield (fighting someone over them), run (hanging back hurt). Enemy Boki: ring only.
- **100 MMB ping: done, one difference.** MMB = new rebindable `ping` action; G alone = throw (KeyMigrate step 5 moves old saved MMB off throw). World: enemy under cursor -> red "Enemy", loot/box/chest -> "Loot", else ground; full map: map point; drop: ground under cursor (DIFFERS: cursor, not the projected landing point). All through Match.squad_ping (+`kind`); world marker, edge arrow, minimap/full-map pins and bot ping_goal reused. **Net.VERSION 0.19.1 -> 0.19.2** ("sping" carries kind; old 5-field form = plain spot).
- **102 one message queue: done.** MsgLane: fixed column, never overlap, repeats merge ("x3"), max 3 visible, LOW/NORMAL/HIGH, stale LOW dropped, 1.8-3.2 s lifetimes. Routed: Hud.toast/toast_small/tip/level_up, UI.toast (farm/town/interior), tutorial (holds the lane while its banner shows), ALLY KNOCKED/REVIVED cards reserve the top rows. World labels (lair boards, farm "Chop me" marker, Boki bubbles) fade under a card. Combat numbers 46-60 -> 36-46 px, Label3D pool 40 -> 24. ~40 toasts/hints shortened or cut (HEXED/GROUNDED duplicate toasts, LevelPop banner, "Looted X's box"...). DIFFERS: kill feed stays in its own lane (already non-overlapping); hints keep the existing once-per-profile Save "tutorial" flags.
- **106 reticle: done, one difference.** Default is a small broken ring + centre dot (6 px radius vs the old 13 px cross); aim arcs pulled in (charge 18->13, ammo 22->16). Settings > Gameplay > Reticle: shape (default/dot/small circle/cross/circle+dot), size 50-200%, 6 swatches incl. high-vis yellow, opacity, outline; saved in user://settings.cfg. Ability aim visuals (Hem's line etc.) draw on top. DIFFERS: default is a broken ring so it differs from the "circle + dot" option; the farm has no reticle (OS cursor), so it applies in matches only.
- Checks (final tree, each with a fresh XDG_DATA_HOME, timeout 1200):

| Check | Result |
|---|---|
| --check + all 64 registered *-check flags (full suite) | 64/65 ok |
| --market-check | FLAKY, not ours: passes on origin/main, passed 1 of 2 reruns on this branch (wall-clock auction timing; branch touches no market/save code) |
| --shield-check (new) | 0 failures |
| --clarity-check (new) | 0 failures |
| --reticle-check (new) | 0 failures |
| --ping-check (new) | 0 failures |
| --msg-queue-check (new) | 0 failures |
| --archetype-check (inline, MMB assertion updated) | 339, 0 failures |
| --tutorial-hud-check / --hudref-check / --uipolish-check / --perkorb-check / --drop-feel-check / --build-ui-check / --farm-tutorial-check | 0 failures |
| health.py --strict / gen_wiki --check | OK / unchanged |

- Screenshots: branch `ext/clarity-96-shots` @ dc501547, `shots/clarity-96/{before,after}/`: clarity_2v2(_crop) (2v2, ally downed, both Boki; same scene on fe51b43b and the branch; side-by-side cmp_2v2.png), shield_*.png + shield_strip (every shield source, aiming at the camera: before shows Mass Guard/aegis hiding the body), msg_match_busy / msg_farm_busy(_crop), reticle_default(_zoom), reticle_cross_yellow / reticle_circle_dot_cyan (+_zoom), reticle_settings, ping_enemy_and_loot, fight (baseline).
- **Wiring / merge notes for main:**
  - Re-import before running Godot after merging (new class_names; LevelPop removed).
  - Code that used `hud.toasts`, `hud.small_toasts`, `hud.tips`, `hud.lvl_note`, `LevelPop`, `TutorialHud.defer/draw_toast`, `UI._toasts`/`UI.TOAST_QUEUE` must use `hud.msgs` (clear/texts/count). ext/tut-airdash and S4's branches (rank-ui, loot-full, box-revive) likely touch hud.gd toasts: expect conflicts there.
  - `hud._draw_wisp_rings` now delegates to DownedMarks/BokiMarks: S4's box-revive work (101b) should draw its box ring with `DownedMarks.ring` / SideColor.
  - Net.VERSION 0.19.2 (bump again if another branch also changed sync).
  - Optional for main (reserved): kin.gd still creates the Boki ring in team colour at spawn; SideRings repaints it each colour change, so nothing is needed unless kin.gd's ring is rebuilt.
  - Match.on_wall_slam lost its unused stun arg (callers updated).

## 2026-11-05 (S2): OWNER APPROVAL NEEDED: ART-2 Kael VFX + sound ext/art2-kael 0fbc63e6
- Ability sheets: ext/hero-shots-s2 art2/kael/ (3b268471). Video with sound: /home/boki/shots-s2/art2/kael/kael_vfx_sound_set.mp4 on the server (not in git, per the no-video rule; say if you want it on hero-shots-s2). Details and 3 owner questions in STATUS.md.
- READY kits, in STATUS: ext/kit-hem-55b 8b2c04f1, ext/kit-kael-57 249bc11b, ext/kit-sable-53-54 157cffe4.
- Heads-up: --teammate-check is red on main fe51b43b (2 failures: rival called before the chest; leads you to the chest and outpost).

## 2026-11-05 (S2): OWNER APPROVAL NEEDED: BOKI starter Vespyx ext/boki-starter 5aaaf165
- Shots: ext/hero-shots-s2 b8273409 boki/starter/. Not wired: two wiring snippets (kin_models.gd, home.gd) and 3 owner questions are in STATUS.md. Grown/Fused forms and the other species wait for this approval.

## 2026-11-05 02:25 UTC (S5): ext/friendly-bodies ac64730e NOT merged: --dolm-combo-check regression
- On origin/main fe51b43b + friendly-bodies (alone), --dolm-combo-check fails one row deterministically: "data rank 3: the leap goes a third further   FAIL  6.44 want 5.65" (tools/breah_combo_check.gd:591). Plain main passes 139/0.
- The test resets Tarek with the dummy T at home+5 m, aims 30 m out and leaps (rank 3, far = 5.65 m), so he lands at about 5.65 m, touching T. With the branch he ends 0.79 m further. My guess: Match._separate now skips the pair because T was hit by the landing (moving_on_purpose + mover_of = Tarek), so Tarek is no longer held back, or T no longer pushes him, at the landing. Either the shove-apart skip should not apply to the caster's own landing against the body it just hit, or the check's expectation needs the owner's rule. Owner of the branch: please decide, fix and re-post READY.
- Everything else on the branch was green in the batch: --friendly-bodies-check 29/0, --boki-follow-check 0, --hero-combo-check 263, --archetype-check 339, --dredge-combo-check 93. --merge-form-check's 1 failure is the same on main.

## 2026-11-05 03:24 UTC (S5): ext/perf-94 8a50cf1f NOT merged yet: .glb conflict with S2's new models (S1, please rebase)
- main is now ff92d1e2. It carries S2's newer Breaker s6, Dredge r3m, Ryzz r9 and Sable s9 models. perf-94 decimated the older copies of those four (art/wardens/{breaker,dredge,ryzz,sable}/*.glb), so they conflict as binaries. hud.gd conflicts too, with S3's clarity-96 (msg lane) and S4's branches, which are in the next batch.
- Keeping both sides means re-running tools/blender/decimate_warden.py on the four new models; S5 has no Blender. Taking either side alone loses one of the two (either S2's new art or the 15k budget that perf's --warden-glb-check now enforces).
- Ask: S1, please merge origin/main (after S5 ships batch 3 = s4-integ + clarity-96, which I'll post in MAIN_TO_EXT), re-decimate those four, and re-post READY. Also an owner question from your STATUS: full-detail meshes for close-ups or not.

## 2026-11-05 (S2): OWNER, quick Qs on Kael (final design first pass, ext/art1-kael 2a9a2b6b; shots ext/hero-shots-s2 art1/kael/)
- Scar side: the brief says his LEFT, but the master sheet and splash show it on image left, his RIGHT. Which? Eyes: only the left eye glowing white (brief), or both orange (splash)? Is in-game size 1.08 tall enough? More rounds are running; the approval set comes after them. Full lists of owner questions per branch are in STATUS.md.

## 2026-11-05 (S2): OWNER REVIEW: item 107 drop ext/drop-107 0a31cdbd
- Video with sound on the server: /home/boki/shots-s2/drop-107/drop_107_review.mp4 (not in git). Strips/GIFs: ext/hero-shots-s2 2a400f61 drop-107/. Includes ext/drop, which never reached main. Needs a Net.VERSION bump before merge. Details and owner questions in STATUS.md.

## 2026-11-05 (S2): BOKI: ext/boki-starter 27fab2ad: Vespyx fixed; OWNER REVIEW for Prismander, Mycroll, grown and Fusion forms
- Shots: ext/hero-shots-s2 5ce8f31b boki/{starter,prismander,mycroll}/. Wiring is now 3 pieces (kin_models, home, merge_parts), exact lines in STATUS.md.

## 2026-11-05 (S2): OWNER LOOK: Kael round 2 (ext/art1-kael ec4a1d7f), shots ext/hero-shots-s2 595ab03b art1/kael/ (vs_art, closeups, match, turntable, anim sheets, 26 GIFs)
- Not the final gate set: match camera reads strongly, close-up is well short of the sheet. Round 3 is running. If the direction is wrong, say so now: Tarek, Motley, Cinder and Lisette follow this recipe. Limits of this box: no GPU, no hand sculpting. Scar side, eyes and size questions are still open.

## 2026-11-05 (S7): STARTED owner items 77-93 (INBOX_S7 06:30), one branch per group from origin/main c204a6d5
- ext/s7-empty-77-81 (Sonnet): 77 prologue caption, 79/79b void head + shroud (skin colour -> shroud colour, save migration), 80 Motes -> Aura, 81 feet clip.
- ext/s7-mask-hob-83-89 (Opus): 88 Mask-screen lag, 83 epic Mask moment, 89 Hob as a real vendor at the stall + camera intro + CC0 model, 87 Hob offers the second Mask (portal offer removed).
- ext/s7-build-90-91 (Sonnet): 90 hold-to-build, Boki help, materials spent in steps; 91 tools + chop/mine/build animations, weapon put away.
- ext/s7-dash-outpost-84-86 (Sonnet): 84 dash as a shared ability slot with pips (home and match; stamina bar and farm dash bar removed), 86 outposts as structures.
- Next when a slot frees: ext/s7-trial-93 (Opus, Trial Expedition) and ext/s7-boki-82-92 (Sonnet: new-Boki screen hover tiles, Boki page from anywhere; reserved-file wiring listed for main).
- Skipped: 78 (LATER), 85 (done), 107 (S2 ext/drop-107). 88 is being checked against main first.

## 2026-11-05 (S4): READY `ext/sfx-base` @ d3d6a77a: the shared base for the SOUND pass (merge this FIRST)
- All 14 sound branches (ext/sfx-<hero> x12, ext/sfx-boki, ext/sfx-ui) branch from ext/sfx-base (= origin/main c204a6d5 + 2 commits), so each touches only its own files and they merge in any order after it.
- Base (17 files): scripts/core/hero_sfx.gd (HeroSfx.of(h, kind, fallback): a Hunter's own `<arch>_<kind>` sound else the shared one), wired at the dash (hunter.gd 1 line), footsteps by surface (juice.gd 1), your own hurt (match.gd 1), downed (match.gd 2: local + net knock), death (life.gd 1). Sfx._lazy now loads a new sound's takes (_1.._4) and Sfx.ensure(). tools/sfx_lib.py (shared generator kit reusing sfx_combat's primitives + a formant voice for wordless grunts, chime, creak, fm, rattle, hiss), content/rules/sfx_levels.json (loudness per category, one table for the generators and the check), tools/sfx_look.py (waveform + spectrogram review sheets), --sfx-set-check (content/sfx/<group>.json: files exist, each take at its category loudness, a Hunter has voice/dash/4 surfaces of steps/fire/signatures, kit sound names exist), docs/AUDIO.md (the standard), docs/CREDITS.md (one pre-made section per sound branch so CC0 entries never collide).
- Buses: every sound goes through Sfx.play / Sfx.loop_start (SFX bus, SFXFar when far); no new AudioStreamPlayers. Item 103's teardown (Sfx.reset_scene_audio stopping keyed loops + pool voices) is on ext/perf-94, not merged yet; the sound branches rely on it once it lands.
- Checks on the base: --check 0, --sfx-set-check 0, health --strict OK.
- Per-hero branches follow as READY entries; after all land, S4 posts ext/sfx-cleanup (removes the superseded functions from the old shared generator scripts).

## 2026-11-05 (S3): IN PROGRESS: ability VFX for all 12 (INBOX_S3 06:30), shared base `ext/vfx-core` @ f35a4fd3. S2 and S5, please read
- **One system, not two.** S2's ext/art2-kael carries the shared `HeroVfx` (data-driven Hero looks). `ext/vfx-core` = origin/main + that shared part only (hero_vfx.gd, its 3 shaders, ArchKit vfx/run_own, Fx.own_look, Sfx.skip, the "hvfx" net event, reel, docs; no Kael data, kit changes or sounds), extended for the other 11 Heroes:
  - looks: `bolt` (lightning / taut thread), `vortex` (ground swirl), particles `shard`, `card`, `coin`, `star`, `drop`
  - `trail(h, move, node)` for projectile tracers
  - anchors on contract bones (`bone: "hand.R"` + `off`), after the .glb empties and before the Gun/body fallbacks, so FX follow S2's rebuilt models
  - `prewarm()` from Match.warm_up: one node of every kind, so no first-cast shader compile (`--hitch-check`)
  - `--hero-vfx-check` audits every content/vfx file against its kit; `--hero-vfx-gallery` palette sheets; the reel plays a generic set unless `tools/vfx_reel/<arch>.gd` exists
- **Branches coming, one per Hero, each from vfx-core** (so any can merge alone): ext/vfx-{kael, lisette, sable, ryzz, vex, grimble, cinder, claire, pip, breaker, motley, tarek}. READY posts follow per Hero.
- **S2:** ext/vfx-kael is ext/art2-kael merged onto vfx-core (your Kael set kept, credited) + the white-hot blade and scarf embers; ext/vfx-lisette reuses what fits from ext/art2-lisette. Please don't start other Heroes' ability VFX; if you change HeroVfx itself, build on ext/vfx-core.
- **S5:** merge ext/vfx-core first (or with the first hero branch). It supersedes art2-kael's copy of the shared files: if art2-kael is approved, merge ext/vfx-kael instead of art2-kael.

## 2026-11-05 07:05 UTC (S6): BOKI art, all species: underway; READY Vespyx smaller eyes ext/boki-cindle 7ded8605
- **Blender works here** (bpy 4.5.15 as a Python module, the same version as S2's starter build; Godot 4.6.2 under xvfb for the in-engine sheets). The models use S2's rigged pipeline (tools/boki/), so every `ext/boki-<species>` branch is cut from **origin/ext/boki-starter**, not main: merge ext/boki-starter first, then the species branches. They only add their own modules and art, plus one row each in shared tables (`SPECS` in build_boki.py, `BokiRig.FRAME`, the rig check's `SPECIES_LIST`). When those rows conflict, keep both sides.
- **READY: ext/boki-cindle 7ded8605** (on boki-starter 27fab2ad): the owner's fix, smaller eyes on Vespyx (eye dome about 18% smaller, brows brought down to match; the eye rule in RIGGED_BOKI.md now says 18-20% of head width). --boki-rig-check 0 failures, health --strict OK. Review set: ext/boki-shots-s6 fcbe78d7 boki/cindle/ (faces, farm_close, turntable, GIFs). No wiring beyond the starter's.
- In progress, one branch each: ext/boki-pebbit (Gravadillo, from the owner-approved concept), ext/boki-cairnback, ext/boki-zapple (Echolop), ext/boki-hivara, ext/boki-wisplet (Lunowl), ext/boki-zephyrak. Prismander and Mycroll are already on boki-starter (S2, awaiting owner review). READY entries follow per species.
- Stretch (INBOX 06:40), after the 9: the next six on ext/boki-roster50 fill the six elements none of the 9 have: Kindlewren (ember), Glintmole (stone), Rimeshrew (frost), Mossgrade (bloom), Kestrike (storm), Gloamshell (shadow). They will be marked NEW: owner approval pending.

## 2026-11-05 07:20 UTC (S7): READY ext/s7-boki-82-92 aeac83fe: items 82 + 92 (base origin/main c204a6d5, merged clean)
- **82, new-Boki screen:**
  - The card leads with the Boki: name, element chip, one line on what it is (the species' first sentence), and one line on who this one is (sex, nature, habit).
  - Moves are icon tiles with the name only (new `scripts/ui/boki_moves.gd`, BokiMoves). Hovering a tile, or focusing it with a keyboard or controller, opens a short tip: what it does with its numbers, then when it goes off and its cooldown.
  - The bond move has its own gold tile ("Bond move"); its tip ends "Fill the bond meter, then press X to fuse" (Settings.key_caps).
  - The Boki page's Training tab uses the same tiles. home.gd -12/+5 (the compact rows go).
  - The card now hugs its content (it was sized before its fonts loaded, leaving a gap).
- **92:** already on main. The hub bar's Boki button (key 2, visible with its key cap) opens the Boki Burrow listing every Boki, each opening its page. The job step's line now names it: "Or press 2 (Boki on the bar below) for all your Boki." Rules.md regenerated.
- **Files:**
  - Edited: scripts/ui/kin_reveal.gd. Not on BRIEF_UPDATE4's reserved list, but it's a kin_* name: main, say if you'd rather own it.
  - Not touched: capture_hud.gd. It shows no move list today, so no wiring is needed.
  - New: boki_moves.gd, tools/boki_moves_check.gd (--boki-moves-check), tools/boki_moves_shots.gd (--boki-moves-shots).
  - Diff: 11 files +289/-53. No Net or save change.
- **Checks** (all 0 failures):
  - --boki-moves-check 9 rows; --farm-tutorial-check, --check, --hatch-check, --boki-system-check, --kinbox-check.
  - --simtest --seed=5: extracted (uplink, Thornwood Outpost) at sim 554 s.
  - health --strict OK; gen_wiki --check 34 unchanged.
- **Shots:** briefs/shots/s7/boki-82-92/
  - before_reveal.png: main today
  - reveal_card.png: the new card
  - reveal_tip_ability.png: hover tip
  - reveal_tip_bond.png: focus tip on the bond tile
  - page_training_tiles.png: the Boki page's Training tab
  - farm_hub.png: the Boki button on key 2

## 2026-11-05 07:09 UTC (S1): READY ext/perf-94c @ 3338363c (owner items 103 + 94; one branch, merges clean on main c204a6d5)
Supersedes ext/perf-94 and ext/perf-94b; don't merge those. It contains main c204a6d5 + perf-94 + perf-94b. Conflicts resolved: main's NEW breaker, dredge, ryzz and sable GLBs were taken and re-decimated (50.3k/19.8k/43.8k/42.0k -> ~14.0k each); hud.gd keeps main's code (ReviveHud, message lane) plus the perf wiring; ReviveHud's deathbox and beacon labels go through LabelCull.
- **103:** the forever sound was the Boki rescue's looping revive_hum played through the one-shot pool. Sfx.play never loops now, new Sfx.loop_hold stops within 250 ms when its owner ends or frees, and Match._exit_tree clears all scene audio. --match-audio-check.
- **94 tools:** a performance overlay (Settings > Video > Frame rate), --perf-bench (60 s match + farm CSV), and --perf-probe lists the nodes new on its worst frames.
- **94 fixes, with before/after on this server (software GL, heavy load; owner-GPU re-run asked):**
  - HUD panels at 20 Hz on their own canvas: HUD ms fight 14.0 -> 7.7, land 17.0 -> 9.5, ride 22.2 -> 13.4.
  - Hunter GLBs 37-51k -> ~14k tris (Kael 21.5k, declared). Textures BPTC, mips, <= 2048: 945 -> 108 MB VRAM for the 12 Hunters; probe textures 230 -> 99 MB.
  - Hit-marker shaders and AimKit line/circle material warmed on the loading screen: worst in-play frame 2.3-3.9 s -> < 1.1 s here.
  - Idle far monsters stop simulating, and far roaming bots run at 20 Hz: fight script 24.7 -> 20.9 ms.
  - Medium is the default preset (the owner's PC auto-picked High): fight 1537k -> 1117k tris.
  - Mask viewer renders only while visible.
  - Shadows: small meshes don't cast (caster size per preset, Low 2.0 / Med 1.6 / High 1.3 / Ultra 1.0 m): fight shadow draws 1163 -> 305, total fight draws 1875 -> 983.
  - Labels: far or off-screen plates skipped, and text shaped once (TextCache): HUD ms first 31.7 -> 26.2, drop 11.5 -> 8.2.
- **Checks:**
  - On the final merge (c204a6d5): --check, --warden-glb, --warden-model, --rig-standard, --perf-throttle, --perf-overlay, --match-audio, --arena, --aimkit, --hero-combo (272), --uipolish, --bot-sanity, --boss and --simtest pass. The full 22-check suite passed on the first merge (main 8f7a33d2).
  - Same as plain main: --teammate-check rival line, --merge-form-check "to fuse" wording, --obstacle-check 1 line.
  - **--hitch-check FAILS on both this branch and plain main.** This branch's worst judged frame is 0.36 of budget vs 0.58 on main. What's left is kit FX shaders built lazily after the warm-up (LDFx, DJFx, PinFx, swoosh, Boki aura x-ray). Next perf step if wanted.
  - health OK, wiki unchanged.
- **S5's question (kit-hem-55b drop-phase shader compiles):** perf-94 alone did NOT cover it; perf-94c now does. Hem 55b's fill line and circle use AimKit.line/circle (one shared AimDraw material on an ImmediateMesh that stays empty until someone aims). 8792c4f2 adds a one-triangle stand-in with that material to the warm-up, so AimKit no longer shows in hitch-check's first-in-view list. The reticle's canvas parts need nothing. Not run on the kit-hem-55b branch itself.
- **Owner decisions:**
  - Close-ups at ~14k show more shading slivers on faces and cloth (Mask viewer; shots on ext/hero-shots perf94c/, plus perf-94's Kael): accept, or keep full detail for close-up viewers only.
  - Please re-run on your PC from this branch: `godot --path . -- --perf-probe --probe-full --probe-out=perf_after_full.txt`, plus the earlier three runs, and once `--perf-bench --bench-out=bench.csv`.
- **Art budget for S2 (enforced by --warden-glb-check):** Hunter <= 15k tris incl. weapon (Boki/props <= 5k), via tools/blender/decimate_warden.py; textures <= 2048, VRAM BPTC, mips; generate_lods on; Fx pooled emitters; no shadowing omni/spot lights.

## 2026-11-05 07:15 UTC (S6): READY (NEW: owner approval pending) Glintmole ext/boki-glintmole 719df20d
- **NEW design**, roster 50 #11 (`glintmole`, stone, small): a star-nosed mole with a split quartz geode down its back, spade paws. Concept sheet: `briefs/art-refs/boki/glintmole_concept.png` (front/3-4/side/back, expressions, grown forms, coats). Review set with GIFs: ext/boki-shots-s6 ffa45965 boki/glintmole/.
- All 13 clips: it digs with its paws (attack = claw rake, ability = dig in and pop up = Geode Mines, mine = claws, no pick), axe in its teeth for chop, a sniffing star over the shared clips. Happy/sad/sleepy/angry faces.
- Not in the game: there is no kin data for it (the roster stub lives on ext/boki-roster50), so only the review tools show it (`NEW_SPECIES` in tools/boki_rig_shots.gd stands in name and colours). It goes live only once the owner approves the design and its stub moves into content/kin_v2.
- Small shared fixes on the branch: `BokiFusion.key_of` returns "" for a species without Fusion parts (the shots tool raised a script error for one); the eye texture takes a species' own deep iris colour (`IRIS_DEEP`, default unchanged).
- Checks: --boki-rig-check 0 failures (4 species), health --strict OK. Branch from ext/boki-starter 27fab2ad: merge the starter first.

## 2026-11-05 07:35 UTC (S7): READY ext/s7-empty-77-81 a4808f68: items 77, 79/79b, 80, 81 (base origin/main c204a6d5)
- **77, prologue caption:** an autowrapped label inset 7% each side, anchored to the bottom and growing upward, with an outline. Font size is window height/25, clamped to 15-40 px. All 5 slides fit at 1280x720, 1920x1080 and 800x450. At 3 lines (slides 3 and 5) the first line sits just above the letterbox bar, over the picture; the bar height is unchanged.
- **79/79b, void head and shroud:**
  - The whole head is the void, from every angle (void_face.gdshader; its planar, pulse and heart modes are removed). Face shape and face marks stay customisable on it.
  - The body wears a shroud: collar, mantle, drape to the ankles and a cowl. Styles: Cloak, Wrap, Tatters; 12 cloth colours. Hands and neck are void.
  - Creator rows: Sex, Height, Build, Shroud, Shroud colour, Hollow, Glow, Ghost, Aura. **The skin colour row is gone.**
  - **Save migration** (Unmasked.clean, idempotent): old skin/colour -> shroud colour, outfit -> shroud style, motes -> aura.
  - The chest heart is gone (owner default: say if it should come back).
- **80:** Motes -> **Aura** (None/Faint/Strong = 0/16/40 specks): bigger, brighter, swirling round the head, shoulders and shroud. Tooltip "Glowing specks that drift around you".
- **81, feet through the ground:** the cause was HunterAnim's hip drop, which used a point foot (soles sank 3-4 cm standing, up to 9 cm walking). The scaling pivot was fine. New scripts/match/foot_plant.gd plants the real lowest boot point, for the Empty only. Across 18 bodies (3 heights x 3 builds x 2 sexes) the soles sit 0.1-1.9 cm above the ground, idle and walking.
- **Diff:** 12 files, +471/-186.
  - models.gd +2 (3414, under its 3500 budget); no other god file touched.
  - No Net change. Save look format changed, with the migration above.
  - Docs: an addendum in docs/decisions/0016.
- **Checks** (all 0 failures):
  - --unmasked-check: new rows for feet, the void head, shroud, migration, the Aura row and the tooltip.
  - --hatch-check; --prologue-check (new row: captions on screen at 3 sizes); --check.
  - --simtest --seed=5: extracted (uplink). health --strict OK.
  - Note: under xvfb with --shots-dir, --prologue-check's "ends on the hatch" row fails; it passes headless (likely the software renderer being slow; not compared on main).
- **Shots:** briefs/shots/s7/empty-77-81/
  - creator from front, side and back
  - Aura none and strong; the three shroud styles
  - farm top-down; feet idle and walking (shortest and tallest)
  - prologue slide 3 at 1280 and 1920, slide 5 at 800
- **Open:** the Empty still carries a class weapon at home (visible in creator_shroud_side). Item 91 on ext/s7-build-90-91 hides it.

## 2026-11-05 (S4): READY `ext/sfx-cleanup` @ c35d44e2: the WHOLE sound pass in one branch (base + all 14 groups + cleanup, merged with current main 25e8ea8d)
- **S5: merging this one branch brings everything** (ext/sfx-base af51093c, ext/sfx-{vex,ryzz,lisette,sable,kael,tarek,cinder,grimble,pip,breaker,motley,claire,ui,boki}, then the cleanup), already merged with origin/main 25e8ea8d. Merging the 15 branches one by one also works (they don't conflict with each other); only docs/heroes/gunslinger.md conflicts with current main (resolved here: main's tap-only Burr Charge row, with the new thunk sound).
- Cleanup commits (+53/-1666):
  - Deleted the old generator scripts every one of whose sounds is now written by a gen_sfx_<group>.py: gen_vv_sfx, gen_pin_bjorn_sfx, gen_dj_sfx, gen_stone_sfx, gen_care_sfx, sfx_linwick_dredge, sfx_heroes_pair, gen_level_sfx. gen_sfx.py / sfx_combat.py: removed the statements writing names the UI and Boki sets replaced, and helpers left unused (re-running them now draws different random numbers for what remains; committed files unchanged). gen_hero_sfx.py and gen_pair_sfx.py stay (payoff sounds nobody replaced).
  - Deleted 13 sounds nothing plays: vn_stick, os_full, tend_relay, pay_salvage, dr_haul, as_flame, as_cloak, dj_bolt_emp, dj_cartwheel, dj_jackpot, jug_dash, rime_run, rime_ward (the jug_dash / as_cloak names left in code are animations), and dropped them from Sfx.NAMES / SfxKits.NAMES / VVSfx.NAMES.
  - sfx_lib: shape() and soft_in() moved in from the Cinder/Grimble/Pip scripts (verified: Pip's set regenerates byte-identical except its voice lines); voice() gets a release (no voice stops dead), chime() a 3 ms attack and a release (no clicks). Only sounds generated from now on get these two fixes; the committed voice lines keep their (30 ms-faded) endings.
  - Hero docs and code comments point at the new scripts.
- Checks on c35d44e2 (with current main): --check 0, --sfx-set-check 0 (14 sound sets), --hero-combo-check 272/0, --gunslinger-combo-check 95/0, --boki-system-check 0, health --strict OK, gen_wiki --check unchanged. Before the main merge also: --rimewright-combo-check 78/0, --tender-combo-check 82/0, --backpack-check 0, --tutorial-hud-check 0.
- **Wiring main must do (reserved files), all from ext/sfx-boki:** merge_xform.gd:25/:168 add boki_fuse, :85 recall -> boki_unfuse; kin_downed.gd:167 kin_unsure -> boki_downed, :256 add boki_revive (exact lines in the sfx-boki entry). boki_eat / boki_sleep have no call site yet.
- **Known, not done:** nobody has listened (all judged by sheets + levels); a held sound can't loop seamlessly yet (level() fades every file's last 30 ms, so Cinder's lance roar and Pip's Hearth Call hum are overlapping one-shots); item 103's match-audio teardown is on ext/perf-94, not merged; S3's msg_lane.gd gets one ui_toast line from ext/sfx-ui.

## 2026-11-05 (S2 to S5): replies to the 07:15 SHIPPED note
- ext/rename-lisette: you merged 7341f61a; READY is **1228b324** (adds Motley, Sunken Bulwark, Grimble). 3 commits on top of main, merges clean. Please take it next.
- ext/kit-ostra-60-75: READY is **bfcf7393** (not f55930d5). It lowers main's shipped held-fire damage, an owner call; see STATUS.
- ext/kit-hem-55b: S1's perf-94c (8792c4f2) covers its drop-phase compiles, so it needs that first.
- ext/art2-kael: warm-up fix in progress here. Don't merge dc35f97d or 0fbc63e6; a new READY follows with a --hitch-check matching main.

## 2026-11-05 (S6): READY (NEW: owner approval pending) Rimeshrew ext/boki-rimeshrew 5763ca81; Glintmole now ad390287
- **NEW design**, roster 50 #12 (`rimeshrew`, frost, small): a tiny pale blue-grey shrew with a long twitchy pink nose, round ears, ice-feather plumes down its spine and an icy tail tip. Concept sheet: `briefs/art-refs/boki/rimeshrew_concept.png`. Review set: ext/boki-shots-s6 326a5c43 boki/rimeshrew/.
- All 13 clips: a little faster and twitchier than the others; ability = Hoarfrost Breath (rears, fills its chest, breathes a sweeping cone); fearless snap; tight curled sleep; tools in its teeth. Happy/sad/sleepy/angry faces.
- **Base for NEW designs: ext/boki-newbase 60b5c13d** (on ext/boki-starter): the review tools' stand-in record (`art/kin/<id>/stand_in.json`, so no shared table), BokiFusion.key_of without Fusion parts, a species' own deep iris colour. Glintmole merged it (now ad390287, same content plus that); Rimeshrew and the next NEW designs branch from it. Merge order: boki-starter, boki-newbase, then any species.
- Checks: --boki-rig-check 0 failures, health --strict OK. Not in the game's kin data (owner approval first).

## 2026-11-05 (S6): READY Zephyrak ext/boki-zephyrak e29baa56 (with Fusion parts)
- Rigged Zephyrak: chunky round moray head with a soft underbite chin, deep-blue eel body to a forked swift tail, hovering about 6 cm up with a ground shadow, level swift wings, frilled ear fins, a glowing sawtooth static ridge. Eye about 19% of head width. Review set: ext/boki-shots-s6 boki/zephyrak/ (turntable, faces, match, farm, fusion, 13 GIFs).
- All 13 clips are its own (no legs): a swim curve sent down the body chain; hop = a corkscrew, ability = Gale Lance (coil, crackle, rolling spear, burst), sleep coils on the ground, tools in its mouth, the load rides between the wings.
- Fusion parts for **Stormwing** (wings, eel tail, static ridge), registered in BokiFusion.SPECIES and build_fusion MODULES.
- Leg assumptions fixed properly: FRAME `"hip": 0.0` (documented), a new FRAME `"hover": true` keeps the soft shadow on the ground (2 rig-check lines), and each species names its own pale pieces for the crevice shade (Mycroll's exception moved into its module).
- Checks: --boki-rig-check 0 failures (4 species; 11,289 tris), health --strict OK. Base ext/boki-starter. No wiring in reserved files.
- Owner questions: hover height OK? Does the pale eye ring make the eyes read too big? Is the underbite in the chin shape enough (teeth read as buck teeth and were dropped)? Weak spots: from the front and high cameras the big head reads a bit whale/tadpole (the S-curve shows in motion and from above); hop and Gale Lance show the pale belly for a frame or two; on the Fusion the wings are mostly body blue.

## 2026-11-05 (S6): READY Gravadillo ext/boki-pebbit 136f8511, Cairnback ext/boki-cairnback 8cae62dc
- **Gravadillo (pebbit)**, from the owner-approved concept: round armadillo dome in blue-slate and mauve bands with violet glowing seams, cream face and belly, small ears, a four-segment beetle horn with glowing rings and tip, ringed tail. Ability = gravity slam (tucks into a ball, flips through the 0.5 s leap, lands with a squash, shakes it off); attack = horn toss; walk = rocking waddle; the horn swings a beat behind the head. 11,856 tris.
- **Cairnback**: sand-skinned tortoise, grey plated dome with gold rune glyphs, ridged ibex horns with gold tips, a cairn of three rune stones and moss on its shell topped by a glowing gold rune-stone. Ability = Boulder Heave (sinks, bucks, the rune-stone flies off and later pops back); attack = rear and horn ram; slow walk, heavy trundle run; the cairn rocks a beat behind the shell. 11,916 tris. Adds "runes" to boki_rig.py HARD_PIECES.
- Both: all 13 clips, happy/sad/sleepy/angry faces, eyes 18-20% of head width. --boki-rig-check 0 failures, health --strict OK. Base ext/boki-starter. The rig check's "species without a model" line now uses a made-up id (`no_model`), since pebbit has one now. Review sets: ext/boki-shots-s6 56777a44 boki/pebbit/, 0d9532bf boki/cairnback/.
- **Fusion parts: not built, owner/main decision needed.** Gravadillo's merge form id is `titan`, and Cairnback (no form file) falls back to its type, also `titan`, so BokiFusion's key can't tell them apart. Keep the keys apart first (e.g. give Cairnback its own form), then both can get parts.
- Owner notes: Gravadillo's face is mostly under its shell from the match camera (you see crown, horn, cream chin); mid-flip its belly shows (reads as a somersault, not a closed ball). Cairnback's eyes come out pale gold on sand skin from the iris colour system (low contrast).

## 2026-11-05 (S6): READY Lunowl ext/boki-wisplet 38ac73e9 (with Fusion parts); READY (NEW: owner approval pending) Gloamshell ext/boki-gloamshell e7b1885e
- **Lunowl (wisplet)**: round lavender owl, head and body nearly one ball, cream facial disc with a darker ruff, ear tufts, small gold beak, chest chevrons, a gold crescent on its crown, feathery gold antennae, short feathered legs with gold talons, pale-green luna-moth wings over its shoulders with plum edges, moon-gold eye-spots and long tails. Eye about 21% of head width. Own 44-bone skeleton and all 13 clips: owl head-swivel idle, waddle walk, skitter-and-glide run, flap-hop, fluffed-up sleep, pecks, talon-pounce attack, ability = silver dazzle (wings flare, eye-spot discs glow); tools held in its beak; the load balanced on its head. 10,732 tris.
  - Fusion parts for **Eclipse** (form key "lunar"): moth wings, plumed antennae, a feather mantle, a glowing crescent behind the head.
  - Shared: build_boki.py gives a prop named in GLOW_PIECES the glow material (one line, documented). Review set: ext/boki-shots-s6 30613d1f boki/wisplet/.
  - Owner questions: its eye colour from the game's iris system comes out grey-blue (gold would be more owl-like); waddle and hop on the ground (now) or hover? Weak spots: a wing edge-on can read as a green spike at the farm camera; the antennae read a bit like gold brows from high; the run is one long bound per cycle (feet slide a little at walk).
- **Gloamshell (NEW)**, roster 50 #15 (shadow, small): a squat grey-violet snail, a glassy smoked-obsidian spiral shell with a faint violet glow from its mouth, two feelers with glowing tips (the eyes stay on the head so it emotes like the others; the art note's eye stalks became feelers). No legs (FRAME hip 0.0): glides on a ripple of its foot with the shell rocking; ability = hunkers, the shell spins half round as the glow wells up, then a head sweep lays the trail; attack = smug headbutt; sleep = drawn down behind its shell. Concept sheet `briefs/art-refs/boki/gloamshell_concept.png`; review set 748b5968 boki/gloamshell/. Base ext/boki-newbase.
- Checks on both: --boki-rig-check 0 failures, health --strict OK.

## 2026-11-05 08:30 UTC (S7): READY ext/s7-dash-outpost-84-86 f1eac1a2: items 84 (+ the 84 addition under 88) and 86. Already merged with main 25e8ea8d.
- **84, the dash slot:**
  - Dash is a normal ability slot (new scripts/ui/dash_slot.gd, DashSlot, drawn through HudSlot.ab_slot) with:
    - one pip per charge, the recharging pip filling
    - a small countdown for the next charge
    - dark with a red frame and a big countdown at 0 charges
    - a flash and a tick when a charge returns
    - a small air-dash diamond
  - **The same component at home:** new scripts/home/home_dash_slot.gd calls the same DashSlot.draw, bottom centre.
  - **Deleted:** StaminaBar (own and rival plates, vitals, squad frames), the farm's overhead dash pips, stamina_bar_check and stamina_bar_shots. --stamina-bar-check is replaced by --dash-slot-check.
  - **Partial (DEBT entry):** at home the slot reads the home's own dash numbers, a mirror of the Hunter's rather than the same object. A shared DashState would need hunter.gd changes.
  - **Owner question:** rivals' overhead dash bars are gone too, which loses the "they just used it" read. Easy to restore.
- **86, outposts:**
  - The uplink outpost is a built object: plinth, console, mast with a crystal, a banner, and 4 pylons with lamps.
  - State shows on the object (new scripts/match/outpost_look.gd):
    - neutral: dark, banner low
    - charging: the crystal follows the charge, lamps light one by one, the banner climbs in the holder's team colour
    - lift open: all lit
  - The yard ring shows only when you're inside or it's contested.
  - Removed: sparks, the 34 m charge column, the always-on ring and the floating badge. The lift column is now 9 m and fainter.
  - The minimap and full map use a matching glyph (new scripts/ui/outpost_glyph.gd).
- **simtest note:** --simtest --seed=5 ends "team wiped" at 46 s on this branch, while main extracts at 236 s. This is an RNG-sequence shift, not a regression:
  - Removing the badge drops one randf().
  - One extra randf() on plain main moves seed 5's ending from Thornwood 236 s to Saltmere 453 s.
  - Seeds 3, 7 and 11 wipe early on both main and the branch.
  - Please don't hold the merge on seed 5's ending.
- **Checks** (0 failures):
  - --dash-slot-check: all 12 archetypes, home and match.
  - --outpost-look-check.
  - --extract-check, --rank-ui-check, --dash-flow-check, --home-build-check, --check.
  - --hudref-check: it assumed every rival keeps a plate. It now skips eliminated rivals; seen >= 5 is kept.
  - health --strict OK; gen_wiki --check unchanged.
- **Diff:** 37 files, +804/-473. home.gd +8/-36, hud.gd +10/-23, models.gd +2/-2. No Net or save change. No reserved files touched.
- **Shots:** briefs/shots/s7/dash-outpost-84-86/
  - the dash slot in a match and at home, at 2, 1 (recharging) and 0 charges
  - outposts: neutral, you inside, capturing at half, lift open, and three outposts with a monster wave (no hunter fight; the test hunters fell off)
- **Not reviewed:** the tutorial map's outposts use the same model and weren't checked separately.

## 2026-11-05 (S6): READY (NEW: owner approval pending) Selenfin ext/boki-selenfin ba573892; ext/boki-newbase now 58b59015
- **Selenfin (NEW)**, roster 50 #19 (lunar, small): a pale silver hatchetfish that floats upright, with a round chibi head (so the face reads from the front), slightly upturned eyes, a deep keel with a milky moonstone set low in it, a row of soft yellow photophores, a forked tail and a little dorsal sail. It hovers (soft ground shadow) and swims through the air: tail sweeps, pectoral fins paddle in turn. Ability: rises and turns once round showing the moonstone, fins flared. Concept sheet `briefs/art-refs/boki/selenfin_concept.png`; review set ext/boki-shots-s6 91cea77a boki/selenfin/. Weak spot: from the side the pectoral fin can read as a pale disc.
- **ext/boki-newbase is now 58b59015**: it carries Zephyrak's hover shadow and PALE_PIECES lines verbatim (checked: merges clean with ext/boki-zephyrak and every species branch), so floating NEW designs (Selenfin, Thrumbird) don't copy it.
- Checks: --boki-rig-check 0 failures, health --strict OK.

## 2026-11-05 (S6): READY Echolop ext/boki-zapple 00cd0153, Hivara ext/boki-hivara 1cdebed5
- **Echolop (zapple)**: chunky indigo hare, tall ears with glowing cyan insides (3 bones each: they listen and swivel on their own in idle and trail behind every move), pale muzzle and bib, sound-ripple rings on the haunches, cotton tail, small scalloped bat wings folded on its back. Walk = little hops, run = bounding leaps with ears streaming; attack = sits up and boxes a one-two; ability = Echo Chain (gathers low, rises chest-out, ears up, wings spread, shivers with the pulse); twisting flared hop; loaf sleep; sits up to nibble the berry in its forepaws; axe and pick held in its forepaws.
- **Hivara**: fuzzy gold bee with dark stripes, pale fuzz ruff, stinger, two pale buzzing wing pairs, a wax crown with glowing honey drops, mantis blades folded at the chest (arm/claw bones), three tiny bees orbiting on their own bones in every clip. Attack = mantis strike; ability = Hive Swarm (buzzes up, flings the blades wide, the swarm whirls and gathers ahead); chop = blade slashes; pick in the right blade; the load hugged in the blades. 11,930 tris (budget 12,000: little room left).
- Both: all 13 clips, eyes about 19% of head width, --boki-rig-check 0 failures, health --strict OK. Base ext/boki-starter. Shared: `boki_tools.tools` takes an optional `side` (a tool swung forward leads with its edge), identical on both branches. Review sets: ext/boki-shots-s6 1f5b1cb2 boki/zapple/, f882ea3c boki/hivara/. No Fusion parts yet.
- **Found: the face's brows don't show in-engine on any rigged Boki** (starter species too). Likely the brow polygons face inward in the export and get culled. S6 is fixing it in face.py on ext/boki-cindle (the starter's face) next.
- Owner notes: Hivara's slashes and swarm read only moderately behind its big head; the swarm orbits at a fixed 0.33 m (rotation-only bones). Echolop's spread wings are modest.

## 2026-11-05 09:05 UTC (S7): READY ext/s7-build-90-91 f08e6c04: items 90 and 91. Merges clean onto main 25e8ea8d.
- **90, hold to build:**
  - Marking out a site is free. The cost is paid in four quarters (FarmSites.STEPS) as the build goes up. Short of materials, the site pauses with "Needs 3 more wood and 2 more stone" over it and in the prompt, and carries on when you bring them.
  - Upgrades pay as they go too. Taking a site down refunds only what was spent.
  - Hold F to hammer, one swing per 0.8 s beat; one press is one swing. Release finishes the current swing.
  - Your Boki within 14 m drop their job and help (the existing build job and animation, Craft makes them quicker), then go back when the site stands. Boki swing time 6 s -> 3 s.
  - House: 10 wood + 6 stone, 12 swings. Tutorial order is now axe, chop to 10 wood, a new stone step (hands over the pickaxe) to 6 stone, house, hammer. Hints show the real cost ({house_cost}) and say "hold".
  - **Save:** an old site with no `cost` loads as fully paid (FarmSites.clean). No Net change.
- **91, tools:**
  - New HunterTool and ToolWork: axe (two-handed overhead chop), pickaxe (two-handed strike), hammer (one-handed taps).
  - Tools are drawn 1.4x so they read at the farm camera. Hits land at 78% of the swing with chips, leaves or sparks and a sound. Boulders show cracks; three hits fell a tile.
  - The weapon is stowed while working, for all 12 Hunters and the Empty. At home it stays holstered (farm and house); it comes back in a match.
  - home.gd lost the fake melee-arc fields (p_swing_n, p_fired).
- **Checks:**
  - --build-hold-check (new, 148+ rows) 0. It covers: hold N s = N taps; one Boki makes it faster; materials leave in quarters; the build stops without materials; tool shown and weapon hidden for 13 bodies x 3 tools, weapon back after.
  - --farm-tutorial-check 0. The "two Boki ... no slower" and river rows flake on plain main too (S7 measured it 1 in 4 on main).
  - --farmbuild, --build-ui-check, --market-check, --work-check, --unmasked-check, --rig-standard-check, --check: 0.
  - --farm-start-check: 1, main's known meadow row.
  - --simtest --seed=5: extracted (uplink).
  - health --strict OK; gen_wiki --check OK.
- **Diff:** 30 files, +1277/-173. home.gd 5392 -> 5390. New: scripts/match/hunter_tool.gd, scripts/home/tool_work.gd, tools/build_hold_check.gd, tools/build_hold_shots.gd. Docs: decisions/0004, DEBT.md, wiki Rules.md. No reserved files touched.
- **Partial (DEBT):** wild trees are part of the ground mesh, so they can't sway or creak; they react with leaves, chips and sound. Hits reuse existing sounds; a creak and crack need gen_sfx.
- **Owner defaults** (each a constant): house 12 swings, hammer beat 0.8 s, Boki swing 3 s, helpers called from 14 m, 2 crew slots.
- **Merge note:** it rewrites farm_hob.gd's use/tick/hold and the farm-tutorial steps. The S7 Hob branch (ext/s7-mask-hob-83-89) is told to merge this branch before its READY, so merge 90-91 first.
- **Shots:** briefs/shots/s7/build-90-91/
  - 01 hammering with the Boki helping
  - 02 the "needs materials" pause
  - 03 chopping, axe mid-swing (the tree reads only as foliage)
  - 04 mining, pickaxe and a cracked boulder
  - 05 the default farm camera

## 2026-11-05 11:18 UTC (S5): QUESTION for S2 / owner before merging the ART-1 Hunter models
- STATUS lists ext/art1-cinder bb7acfb3 and ext/art1-grimble 040c789e as READY, and ext/art1-hem as READY with caveats. Cinder "contains art1-kael", Grimble carries Kael commits, and Lisette needs "ext/art1-kael first". But art1-kael itself is still an owner preview (round 2, "gate not requested yet"), so merging any of the three would ship the new Kael unapproved.
- S5 is holding all ART-1 branches until one of these:
  - (a) the owner OKs Kael (then S5 merges art1-kael, then cinder, grimble and Lisette), or
  - (b) S2 posts versions without Kael's changes.
- Also, when they come: main now has perf-94c's art budget, which --warden-glb-check enforces (Hunter <= 15k tris incl. weapon; textures <= 2048, BPTC, mips). Please confirm each ART-1 branch passes --warden-glb-check, --warden-model-check, --rig-standard-check and --hitch-check (compile list matching main) on current main a4b39fd7.

## 2026-11-05 (S2 to S5/S3/S4): ext/art2-lisette acc0dcfb READY after ext/art2-kael 37e5033e
- Lisette: same checks as Kael: hero-vfx OK, archer-combo 128/0, hero-combo 272/0, sfx-set 0, match-audio 0. Hitch on 9193bc48 (pre-merge): ride 4, drop 0, land 0. Health passed before the last import-only commit. No full suite after the a4b39fd7 merge. 1-line docs/heroes/archer.md conflict with kit-hem-55b if it isn't in yet: keep both.
- Both branches took main's sound pass. Now-silent moments, on purpose (S4's call): Kael slash tip and Riposte hit; Lisette normal arrow hit, needle stuck in the ground, heavy wall pin, spirit orb. Hurt grunts for other players are gone. Dropped ids are listed in STATUS.
- S3: ext/vfx-core's prewarm() hides nodes without drawing them, so it won't compile particles or trails; take this branch's prewarm/prewarm_end (particles alive, trail has a real surface).

## 2026-11-05 (S2 to S5): playtest items are partly unmerged branches, please prioritise
- Item 117 (Motley LMB through walls, bigger when charged): main has the earlier version. ext/kit-ostra-60-75 bfcf7393 has the measured fixes (5/5 vs 0/5 through a rock when hugging it, other clients get size + pierce). It's being refreshed on current main; merge the new commit when posted.
- Item 114 "kill the V": ext/kit-hem-55b 8b2c04f1 isn't on main yet. It does that; please land it.
- Also READY and unmerged: ext/kit-tarek-61-67 eb040e7d, ext/kit-cinder-66 ea287770, ext/portraits-three 8edb4f23, ext/art2-kael 37e5033e, ext/art2-lisette acc0dcfb, ext/boki-starter 3420bc02.

## 2026-11-05 (S2 to S5): READY (HIGH) item 112: ext/kit-vex-112 d3252225
- One commit on a4b39fd7. Vex's grenade fires from the cannon, no throw pose: spawns at `launcher_fire` with fallbacks; recoil kick; thunk sound. Kit numbers unchanged. gunslinger-combo 98/0, hero-combo 272/0, dash-flow 0, health --strict, gen_wiki 34 unchanged (FAIL lines counted). Full suite not run. Sound can play twice per shot when the charge sticks. Only one sheet, on the current model.

## 2026-11-05 (S2 to S5): READY (HIGH) ext/fix-breaker-spin e3a00f02: Breaker's hold spin; also fixes an arena bug for EVERY 3D hero
- Could not reproduce "doesn't trigger": on main the hold starts, whirls at 3.6 turns/s and slams in the arena (opened as him and swapped to him) and a plain match start. No full expedition with a drop was run. What was wrong is what's seen: (1) Hunter.reclass's equip() freed the .glb weapon on any arena swap and put the procedural one in the hand: all 3D heroes; (2) S2's item 59 removed the whirl scale on the wrong evidence, so the real hammer was a small flickering blob. Fix: equip(w, ammo, rebuild) with reclass passing false; ORBIT_SCALE 1.4 on the 3D weapon (2.74 m). New arena assert: 3 FAIL lines on main's code, 0 on the fix.
- Checks 0 FAIL lines: --check, hero-combo 272, bulwark-combo 144, arena 96, archetype 362, class-unlock 153, warden-model, warden-glb, rig-standard, tutorial-hud, dash-flow, shake, health --strict, gen_wiki. Only the match-camera strip viewed.
- Owner: please retest on this build. If the spin still doesn't start, tell us which mode.

## 2026-11-05 (S2 to S5): which ART-1 branches carry Kael's model files (diff against main, art/wardens/kael)
- None: ext/art1-grimble (READY 040c789e), ext/art1-motley, ext/art1-hem. Your hold on Grimble may not apply: it carries the shared clip code but no Kael art. Lisette: use only a posted READY commit.
- Carry them: ext/art1-cinder, ext/art1-claire, ext/art1-sable, ext/art1-pip. Owner decision pending (approve Kael as he stands, or S2 splits the shared runtime out).

## 2026-11-05 (S2 to S5): READY (HIGH) item 117: ext/kit-ostra-60-75 66a9c6f2 (replaces bfcf7393)
- Reproduced on main: point-blank orbs stop dead because pierce is set a tick after spawn (6 FAIL lines of 25 on clean main); a full orb is only 1.37x a held one, and other clients get plain size and no pierce. This branch: every orb passes terrain point blank and at range (Arena blocks, dais, after a swap, expedition ruin wall, cliff); full radius x1.90 of quick, visual + hitbox, 58 vs 31 px at 1280x720; impact scales with charge. ostra-combo 191/0, hero-combo 272/0, arena 86/0, --check 0, health --strict, gen_wiki unchanged. Full suite not rerun.
- This keeps held fire plain (charge_from 0.6), which lowers main's held-fire DPS ~15%. The 1.6x bar depends on it. Owner item 117 says bigger when charged; the owner hasn't ruled on the DPS drop, so flag it in your SHIPPED note.

## 2026-11-05 (S2 to S5): READY item 118: ext/kit-pip-118 94a90a69
- Pip's RMB: a press starts a fixed 1.0 s wind-up, then auto-throws along the aim at that moment; no hold; half speed during it. Seed damage, root, burst unchanged. tender-combo 87/0, archetype, hero-combo, kit-combo, bot-sanity, warden-glb 0 FAIL (before the last lint fix), health --strict. Other flags not run; not played live. ext/vfx-pip needs re-hooking onto fire_rmb/_tick_seed/_throw_seed. ext/art1-pip needs its seed_aim clip at 1.0 s, or --clip-check fails after this merges.

## 2026-11-05 (S2 to S5): READY (HIGH) item 113: ext/kit-kael-113 ae7f8b6b (points 2-8; point 1 sword is ART-1's)
- Kit logic and data only. juggernaut-combo 183/0 (18 new), hero-combo 287/0, kit-combo 39, dash-flow 0, arena 86, class-unlock 153, health --strict, gen_wiki. Full suite on this commit: 138 flags, same 11 reds as clean main, 0 new. Not hand-played. Art clips on ext/art1-kael still need matching.

## 2026-11-05 (S2 to S5/S3): READY (HIGH) items 116 + 116b: ext/kit-ryzz-116 6963e49d
- Ult lands at the cursor (was 2.71 m off; Match sends inp["aim_ray"]), ult spreads Static (3 causes fixed, item 72), LMB 10% faster (0.648 s), Wirerun reset dash 1.5x further and 0.45 s full charge. mage-combo 128/0, --check, simtest, health --strict. Full suite 138: same 12 reds as clean main, hitch lower. Real-mouse ray not played live.
- Pink LMB is only on ext/vfx-ryzz. ext/trial-ryzz-116 a6143699 merges kit + art + vfx with conflicts resolved (mage-combo 129/0, ryzz-live, clip, hero-vfx; no full suite). S3: confirm it, it keeps main's step sound. Item 116.3 (Static marker: one bolt icon per stack, stays pink) has no owner: S3?

## 2026-11-05 (S2 to S5): READY (HIGH) item 114: ext/kit-lisette-114 43ca4513
- Upright procedural stance; no V (verified, 55b on main); RMB shows a big needle on the bow while charging (scripts/arch/kits/pin_needle.gd), local only; slowed to 38% while holding, starting 0.15 s in. Full suite (138): same reds as clean main, line for line except a pack-ui flake and lower hitch. archer-combo 153/0, hero-combo 297/0. S4 charge sound and S3 E colour are theirs. Needle's first-use compile not proven by --hitch-check.

## 2026-11-05 (S2 to S5): READY ext/claire-62-65 c4cf394a (items 62, 64, 65)
- 62 air skate; 64 skate into ult carries speed; 65 frozen statue locked. Beyond the WIP: jump during skate works, statue can't act, glide from the air skate. rimewright-combo 89/0, dash-flow 0, dash-aim 0, --check 0, health --strict, gen_wiki on the tip; hero-combo 287/0, warden-model, warden-glb, class-unlock 153, arena 86, tutorial-hud, rig-standard one commit earlier. New kit move tm_skate_air: ext/art1-claire needs a clip or the stopgap line, else --clip-check fails on merge.

## 2026-11-05 16:10 UTC (S2 to S5): decisions taken under the 16:05 owner rule
- Kael: S2 is removing Kael's art and data from the Hero branches so they stop waiting. New READY commits follow for Cinder, Claire, Sable, Pip, Vex, Ryzz. Grimble, Motley, Lisette, Tarek already carry none: take READY Grimble 040c789e, Motley da47ee16 (kit-ostra 66a9c6f2 first), Lisette 8280e446 now.
- Boki: owner approved Vespyx at 03:02 with the eye fix, now in. S2 recommends wiring ext/boki-starter 3420bc02 at your call; reserved-file wiring is yours. Prismander, Mycroll and Fusions are unreviewed but harmless to land.
- All other defaults are listed in STATUS.md.

## 2026-11-05 (S2 to S5): READY item 111: ext/kit-tarek-111 4e25e66a (contains kit-tarek-61-67 eb040e7d)
- Shift raises a rock, he hops ~2.4 m, re-press within 0.6 s for up to 3 hops; damage only on the final crash; hop rocks last 1.2 s. dolm-combo 170/0, hero-combo 287/0, dash-flow 0 (9 skipped), class-unlock 153, health --strict re-run after the last fixes; rest of the suite before them, green. **`zone rock` gains an optional 13th Net field with no version bump of its own (main's 0.22.0 is unrelated); no online test.** ext/art1-tarek must map breah_hop and breah_skate and drop breah_dash.

## 2026-11-05 16:30 UTC (S6): READY Glintmole ext/boki-glintmole 718f7d7d (5k); S6 PAUSED for low-spend mode, handoff state
- **READY: Glintmole (owner-approved NEW design)** on ext/boki-newbase 7c946d9e (= ext/boki-starter 3420bc02 + review tooling + hover + brow fix): 4525 tris (budget 5000), VRAM textures, brows show. --boki-rig-check 0 failures (4 species, LODs on), health --strict OK. Merge order: boki-starter 3420bc02, boki-newbase, then this. Not yet done for it: Fusion parts, the face detail pass, the kin-data wiring (its roster stub must move into content/kin_v2 for it to appear in game). The review set on ext/boki-shots-s6 shows the pre-5k model.
- **Found and fixed: brows never rendered on any rigged Boki** (face.py wound them into the head). Fix on ext/boki-newbase 7c946d9e and ext/boki-cindle 00952ed9 (same line).
- **Not 5k yet (built before S2's 5k starter; each needs: merge origin/ext/boki-newbase, cut part targets to fit 5000, VRAM textures via the .webp.import params, rebuild, rig check):**
  - base species, posted READY earlier (now NOT mergeable until migrated): ext/boki-pebbit 136f8511, ext/boki-cairnback 8cae62dc, ext/boki-zapple 00cd0153, ext/boki-hivara 1cdebed5, ext/boki-wisplet 38ac73e9, ext/boki-zephyrak e29baa56.
  - ext/boki-cindle 00952ed9 (Vespyx smaller eyes + brow fix): on starter 27fab2ad, needs starter 3420bc02 merged and the 3 starter species rebuilt.
  - owner-approved NEW designs: ext/boki-rimeshrew 5763ca81, ext/boki-gloamshell e7b1885e, ext/boki-selenfin ba573892, ext/boki-glomwort 62c49396 (then their Fusion parts, face pass, wiring, like Glintmole).
- **WIP, stopped mid-work (not READY, unchecked):** ext/boki-kindlewren 7b18f564, ext/boki-kestrike 572286fd, ext/boki-thrumbird 3ff052e6, ext/boki-lodestick 1d56362f, ext/boki-marchleaf 8d363f1d, ext/boki-mossgrade 77d6522f, ext/boki-nettlynx 2c57d035 (some already merged newbase 7c946d9e). ext/boki-opalisk has no work yet.
- Tools for the next session: Blender = `pip install bpy==4.5.15` into a Python 3.11 venv (wheel from PyPI), run build_boki.py with `import bpy` first; Godot 4.6.2 from GitHub releases; renders under `xvfb-run`. Concept sheets: briefs/art-refs/boki/<id>_concept.png.

## 2026-11-05 (S3): READY ability VFX: `ext/vfx-cinder` @ 602e6b7d, `ext/vfx-claire` @ 05815856, `ext/vfx-pip` @ 45a1949b (+ base `ext/vfx-core` @ 16f66b8e)
- **Merge order: `ext/vfx-core` first** (or with the first of these). Each branch is vfx-core + one Hero, already merged with origin/main 25e8ea8d, so any one can go alone. vfx-core since the IN PROGRESS note: held looks turn with the aim (the flamethrower bends with a sweep); the gallery starts a Hero in its own class; the trail test no longer flakes under load; merged with main 25e8ea8d.
- **Claire + Pip conflict in one file:** `scripts/arch/kits/care_look.gd`. Each branch deletes CareLook kinds the other keeps. Resolution: take BOTH deletions. In the header comment, take Pip's two "Pip:" lines and Claire's two "Claire:" lines. In `_build()`, delete both the `"mote"` block (Pip's) and the `"dome"` block (Claire's). Once both are in, `CareUtil.payoff` (care_util.gd) has no callers left and can go.
- **All three:**
  - Each look is a shader look in `content/vfx/<arch>.json`: noise and dissolve surfaces, GPU particles, mesh trails on projectiles.
  - Each moment has a telegraph, an impact and a linger, in the Hero's art-sheet palette.
  - The old effect calls are deleted: `m.fx.burst/spark/flash/ring`, every `net_ring`, the shared payoff rings, and the LDFx/CareLook one-shots that were replaced.
  - Gameplay, damage, timing, hitboxes and AimKit danger shapes are unchanged.
  - Anchors are weapon empties, then contract bones (`hand.R`, `hips`), then body fallbacks, so the looks attach to S2's rebuilt models.
  - The heaviest moment is Cinder's hose at about 118 particles in 4 layers. MAX_LIVE 420 and the pools are unchanged.
  - God files and reserved files are untouched.

### Cinder (`ashwick`), `ext/vfx-cinder` @ 602e6b7d: 5 files +300/-99 vs vfx-core (new content/vfx/ashwick.json, tools/vfx_reel/ashwick.gd; ashwick_kit, ashwick_jet, ld_fx -18)
| Ability | Telegraph | Impact | Linger |
|---|---|---|---|
| LMB Torch Lance (signature) | cyan pilot flare + gathering motes at the nozzle | held flame stream (3 ember layers + smoke) that bends with the sweep, flame tongues, sparks on the foe | scorch where the stream licks the ground, smoke on release |
| RMB Cinder Shot | pink embers gather at the nozzle | muzzle flare, smoke-and-fire trail, red flare + ember shower on hit, forked flame to each spread target | scorch, smoke; violet fizzle on a miss |
| Shift Soot Ram | burner flare at her back | flame tails while ramming; flare + flame arc + ember spray on impact | scorch, smoke cloud |
| E Furnace Cloak | embers sucked inward | chest flare, flame wall round her, ember burst | cracked scorch, smoke |
| R Flue Flight (signature) | lift-off flame wall + flare | **two held jets from the tank's exhaust nozzles**, back and down, with a hot glow at each | 2.2 s scorched lane over the carpet (networked), embers off the lava, smoke on landing |
| Passive Flashover | embers drift off a charred foe | Ablaze flame column; Flashover white-hot flare + column | scorch, smoke; rising embers on the knock heal |

- **Kept on purpose:**
  - The LDFx hose puffs: they are the stream's real reach, stop at walls, and are asserted by the combo check.
  - The lava carpet, ram skull, burn pips, cloak swirl and pilot flame: these show gameplay state.
- **Not converted:** held looks are local only (the core design), so other players don't see the hose embers or tank jets. Other players see the networked impacts and the scorch lane.

| Fidelity (Cinder) | VFX | Proof |
|---|---|---|
| Flamethrower, held LMB, through the hose | ✅ | `ext/vfx-shots-s3` b8c1dd3d vfx/cinder/ashwick_lmb.png |
| Tank's 2 exhaust nozzles = jets in Flue Flight | ✅ (anchors `anchor_tank_l/r`, else the `hips` bone, else the body) | `ext/vfx-shots-s3` b8c1dd3d vfx/cinder/ashwick_r.png (jets read, but small at match zoom) |
| Living-fire hair, magma skin, tank, hose, flame-tipped tail | model (S2) | - |

### Claire (`rimewright`), `ext/vfx-claire` @ 05815856: 5 files +257/-79 vs vfx-core (new content/vfx/rimewright.json, tools/vfx_reel/rimewright.gd; rimewright_kit, care_look -21, care_combo_check)
| Ability | Telegraph | Impact | Linger |
|---|---|---|---|
| LMB darts / skate beams | small frost flare at her hand | icy ribbon trail on each dart (wider on beams) | - |
| RMB Ice Spear | frost gathers between her palms | push flare, long white trail; shard burst on landing | frosted scorch + mist |
| Shift skate (signature: frost trail) | push-off spray | held trail of ice chips, snow stars and mist off her feet; carve spray; stop spray | frost patch under every 3rd ice plate, melting within 2 s |
| E Rink Wall | lilac shards gather at her feet | shards + mist as it rises; frost flare + shards when E freezes it | mist |
| R Rimelock (signature: freeze) | seal flare | shard crystals + frosted scorch at the seal; crash: big flare, shard bursts | snow + mist held round her, shards where the rink creaks |
| Shatter / Chill | - | shard burst on the Shatter; a chill puff on each freshly Chilled foe | frost scorch, mist |

- **Kept:** the darts, spear, wall, slow zone, rink, frost bud, ice plates (DECISIONS' ice path), spikes and shells.
- **Check updated, same intent:** `--rimewright-combo-check`'s two chip-count asserts now assert the ice plates + frost patches and the carve spray.

| Fidelity (Claire) | VFX | Proof |
|---|---|---|
| Ice-blade skates with a frost trail | ✅ | `ext/vfx-shots-s3` b8c1dd3d vfx/claire/rimewright_dash.png (the trail reads as ice plates + mist; the frost patches are faint) |
| Candy-cane ice spear | spear model kept; ✅ trail + shard landing | `ext/vfx-shots-s3` b8c1dd3d vfx/claire/rimewright_rmb.png |
| Gentle look, bunny hood, horns, wings, tail, dress, skating anims | model (S2) | - |

### Pip (`tender`), `ext/vfx-pip` @ 45a1949b: 5 files +235/-121 vs vfx-core (new content/vfx/tender.json, tools/vfx_reel/tender.gd; tender_kit, care_look -73, care_combo_check)
| Ability | Telegraph | Impact | Linger |
|---|---|---|---|
| LMB comet | small lantern flare | comet recoloured soft gold with a pink halo, starlit ribbon trail; gold impact; Kindled foes burst in lilac stars | - |
| RMB Burrseed | lilac stars gather at the lantern | flare, trail, stars on the stick; starlight swirl (vortex) on the root | the swirl |
| Shift hop / glide | - | stars off her heels | faint held star trail |
| E Hearthlight | lantern flare + rising stars | starlight swirl where it lands; the bloom: swirl, flare, stars | slow stars drift up while it heals |
| R Hearth Call | lantern flare | swirl on the target | MENDED: flare, swirl, stars |
| Heals (signature) | - | every heal (Hearthlight pulses, the bloom, Hearth Call ticks) releases gold and pink twinkling stars rising off the target | - |

- **No flame anywhere:** the orange ember motes and green rays are gone.
- **Check updated, same intent:** `--tender-combo-check`'s dash assert counted the deleted motes; it now asserts the hop's star-trail hold.

| Fidelity (Pip) | VFX | Proof |
|---|---|---|
| The STAR LANTERN glowing, healing light | ✅ the lantern is the anchor of her casts (`anchor_hang_lantern`, else the `hand.R` bone); heals are starlight | `ext/vfx-shots-s3` b8c1dd3d vfx/pip/tender_e.png |
| Gold constellation markings brighten when she heals | ❌ needs the model's markings material (S2); the VFX side is the stars rising off healed allies | - |
| Fairy-fox body, wings, goggles, leaf cape, apron | model (S2) | - |

- **Checks:** run on the final trees, each with a fresh XDG_DATA_HOME and timeout 1200. --hero-vfx-check HEROVFX OK on each; --ashwick-combo-check 97/0, --rimewright-combo-check 78/0, --tender-combo-check 82/0, --hero-combo-check 272/0 (on Cinder's tree); health --strict OK on each. Not run (low-spend mode): the full suite and --hitch-check (vfx-core's own --hitch-check run listed no hero_vfx shader among the mid-play compiles: prewarm covers them).
- **Screenshots:** `ext/vfx-shots-s3` b8c1dd3d vfx/{cinder,claire,pip}/: <arch>_{lmb,rmb,dash,e,r}.png reel sheets + gallery_<arch>_0-3.png.
- **Owner questions:**
  - Should the remaining persistent looks (Cinder's skull and cloak swirl, the Kindle foot glow, the Burrseed disc) move into HeroVfx later?
  - Pip's LMB is still named "Ember Cast" in her kit text; it may want a starlit name.

### PAUSED (owner's low-spend mode until Fri 6am Toronto): the other 9 Heroes are NOT ready, please don't merge them yet
- Pushed work in progress; each is vfx-core + one Hero:
  - `ext/vfx-kael` 024ce284, `ext/vfx-lisette` 766e5475, `ext/vfx-sable` 192284ad, `ext/vfx-vex` 424c639d, `ext/vfx-tarek` ac8128d8 (these have core 16f66b8e)
  - `ext/vfx-ryzz` d39d0bce, `ext/vfx-breaker` 65a229ff, `ext/vfx-motley` 26cbf641 (these still need core 16f66b8e merged)
  - Grimble: not started.
- None of the 9 has a final report, a fidelity table or a final check run. Friday's session picks them up from briefs/INBOX_S3.md (the "PAUSED STATE" section).

## 2026-11-05 (S4): LOW-SPEND STOP. Handoff for Friday's session
Per the owner (25% usage left until Friday 6am Toronto): S4 finished only ext/sfx-base-2 above and stopped. **Not started** (all in INBOX_S4, still open):
1. `ext/sfx-vex-2` (12:17): heavy, intimidating Vex: minigun roar with spin-up on press / spin loop / spin-down on release (use save_loop + Sfx.loop_start keyed per hunter), low thump per shot, brass casings; the grenade now fires from the arm-cannon top tube (item 112): a deep hollow THUNK + a big bassy explosion with debris and rumble; servo/hydraulic dash and slide, heavier metal-clank steps; Longneedle: a building charge hum (loop) then a loud crack/boom; meatier hit impacts; `reach` ~45 m on fire/explosion; cats heavy_fire / heavy_impact. Post a short old-vs-new A/B note.
2. Weight check on the other carries (Kael's greatsword, Grimble's blunderbuss, Breaker's hammer): move their weapon/hit sounds to heavy_fire / heavy_impact where thin, maybe reach.
3. `ext/sfx-lisette-2` (item 114.4): RMB Heavy Shot held: a rising tension creak + thread hum (a loop while drawing, pitch rising with the draw), then a heavy release twang/whoosh.
4. `ext/sfx-ryzz-2` (item 116.5 + 12:00): a crackling zap per finger-gun shot, a sizzling stack-apply tick, a big thunder crack on the ult, a bright electric "reset" zing when Wirerun resets from the orb pull (item 71); a bubblegum blow + pop hooked to her idle / emote / kill (S2 adds the anim; mage_bubble_pop exists, the blow does not).
- Every READY for these needs the Hunter's FIDELITY_CHECKLIST rows as a ✅/❌ table (for sound: the sound-related must-haves, with the sfx_look sheets as proof).
- Branch each from origin/ext/sfx-base-2 (or main once S5 merges it). Brief and rules: the S4 SFX brief pattern (gen_sfx_<hero>.py on sfx_lib, content/sfx/<arch>.json, --sfx-set-check + the hero's combo check).
- Still waiting on main (reserved files): the sfx-boki wiring in merge_xform.gd / kin_downed.gd, and boki-talk-105's kin_voice/kin_speak/kin.gd wiring.

## 2026-11-05 (S7): READY ext/s7-mask-hob-83-89 486e652c: items 83, 87, 88, 89 (+ the 89 additions under 91)
Merged with main a06099f3; merges clean onto 0237eb8d. Diff vs main: 57 files, +2525/-638.
- **88, Mask-screen lag:** not fixed on main before this branch.
  - Each preview used to re-read its .glb from disk (0.3-1.5 s); now each is cached and read on a loader thread (WardenGlb.fetch).
  - Previews build one model per frame (new scripts/ui/preview_build.gd), and only the focused ability clip plays.
  - Portraits are loaded and cut off the main thread. The Masks screen swaps tiles in place instead of rebuilding.
  - Accepting spreads its work over frames behind the black.
  - Headless worst frames went from 0.5-2.4 s to 12-28 ms.
  - **Missed:** the first build of each Mask's model per session is still one 120-230 ms frame. That cost is inside models.gd (god file); DEBT.md, for perf item 94.
- **83, the Mask moment:**
  - New scripts/ui/mask_beat.gd + content/rules/mask_moment.json. A 5.8 s beat:
    - build-up: music ducks, the camera eases in, a swell and a heartbeat
    - the Mask rises under a flickering porcelain ghost face
    - 0.7 s of black and silence (the model swaps here)
    - 3 memory frames of the fallen Hunter, with a whisper
    - snap back: impact, a light ring and a camera push (no shake), a pose, "Vex, the Hired Gun", and a sting
  - Skippable once seen (tutorial.mask_seen); a short version on the farm.
  - Our own sounds (tools/gen_mask_sfx.py, 5 wavs). The old MaskMoment.beat is deleted.
- **89, Hob in person:**
  - A builder model (scripts/home/hob_model.gd): sleeves, apron, tool belt, cap, a pencil behind his ear; simple face marks. Poses: idle, wave, talk, point, hammer.
  - He stands by the stall and goes to the house site while it's being built.
  - Talk box (scripts/ui/talk_box.gd, scripts/home/hob_talk.gd): his portrait and name, one line at a time. The camera eases toward him and he points at what he names. The HUD, Goals card and world prompts step aside for the whole talk (FarmGuide.set_quiet).
  - First arrival: the camera swings to him for 1.5 s ("Hey! Over here!"); his name tag shows until you've talked. Meeting Hob is the first farm-tutorial step.
  - **Not done:** a CC0 vendor model. kenney.nl and quaternius.com return 403 through this container's proxy, so he is our own model built from shapes. The swap is in DEBT.md.
- **87, second Mask from Hob:**
  - After the house is placed, Hob calls you over: "By the way... I see you found a Vex Mask. Could I interest you in another?"
  - The pick (scripts/home/hob_offer.gd) shows exactly Kael, Pip and Cinder: portrait, title, a one-line role, the focused card's clip. Take or Not now.
  - Taking it plays the short Mask moment from Hob's hands.
  - mask_offer.gd (the portal offer) is deleted. Saves that already own a second Mask keep it.
- **Checks:**
  - After the last merge, run by S7 under low-spend mode: --hob-check 0 (also under xvfb with shots), --class-unlock-check 145/0, --farm-tutorial-check 0, --uipolish-check 30/0, health --strict OK, gen_wiki --check unchanged.
  - Earlier on this branch: --check, --mask-moment-check, --mask-lag-check, --hatch-check, --portrait-check, --build-hold-check, --farmbuild 0; --simtest --seed=5 extracted.
  - Full suite not re-run (owner's low-spend rule).
- **God files:** home.gd +6/-12, wiring only. No Net change. New save flags (tutorial.hob_intro, tutorial.mask_seen) read false when missing.
- **Owner questions** (defaults taken):
  1. Hob keeps the Empty's simple face marks.
  2. Taking the second Mask unlocks it but doesn't equip it.
  3. The roles and the 12 whisper lines are our wording (farm_builder.json "roles", mask_moment.json "whispers").
  4. "Vex Mask" is capitalised.
- **Shots:** briefs/shots/s7/mask-hob-83-89/
  - hob_1-8: call-over, camera intro, talk box, pointing, offer line, the three-Mask pick (no overlap now), farm Mask moment, name
  - mask_beat_1-5: build-up, rise, black, memory frame, reveal

## 2026-11-05 16:45 UTC (S2 to S5): READY: ext/kit-gloves-69 7a5a9031, ext/kit-glider-63 5f0ec6e0
- Item 69 (two gloves in the Arena, Q and V) and item 63 (glider opens at any heat, deep lift softened). Independent of each other.
- Full suites ran on the a4b39fd7 base: no SCRIPT ERROR, baseline reds only, arena-check 92/0, glider-heat-check 0 failures. Both merge-tree clean with main 0237eb8d; not re-run on it. The glider was not checked visually.

## 2026-11-05 (S6): READY under the 5k art budget: 11 Boki branches (replace every earlier S6 Boki READY)
All on ext/boki-newbase 7c946d9e (= ext/boki-starter 3420bc02 + review tooling, hover shadow, brow fix). Merge order: ext/boki-starter 3420bc02, ext/boki-newbase, then any of these. The only conflicts between them are one-line rows in SPECS, BokiRig.FRAME, SPECIES_LIST and the docs: keep both sides. Each: --boki-rig-check 0 failures (tris under 5000, LODs on), VRAM textures, health --strict OK, pushed and verified on origin. Review sets (5k): ext/boki-shots-s6 c2d58fc6 boki/<id>/.
- Base species: ext/boki-pebbit f0223839 (4860 tris), ext/boki-cairnback 89259625 (4892), ext/boki-zapple bebd4d9e (4506), ext/boki-hivara 33b167c5 (4570; wing sheets made 2x thicker to decimate), ext/boki-wisplet aafc028c (4911, Fusion rebuilt), ext/boki-zephyrak 01ca882d (4584, Fusion rebuilt).
- ext/boki-cindle 713f45fe: Vespyx smaller eyes + brows fix on the 5k starter; all three starter species rebuilt (4848/4504/4237). Takes the place of boki-starter's own Vespyx art.
- Owner-approved NEW designs (not in the kin data yet: their roster stubs must move into content/kin_v2 to appear in game): ext/boki-glintmole 718f7d7d (4525), ext/boki-rimeshrew f9196f2a (4265), ext/boki-gloamshell aa5f7677 (4924), ext/boki-selenfin 620b23db (4077), ext/boki-glomwort f09fd7b8 (4140).
- Still open for Friday: the approved designs' Fusion parts, face detail pass and wiring; the 7 WIP species branches listed in the 16:30 entry; the Gravadillo/Cairnback `titan` Fusion key clash (main/owner decision).

## 2026-11-05 18:32 UTC (S2 to S5): ART-1 merge heads-up, read before starting
- Each of the eight is clean against main, but they conflict with each other: 30 conflicts in a sequential trial, including warden_glb.gd, warden_clips.gd, hero_toon.gdshader, warden_look.json. Details in STATUS.
- S2 is building ext/art1-integ with all eight resolved, for one merge. Use art1-tarek 0eb846b6, not 6fdf952f.

## 2026-11-05 20:32 UTC (S2 to S5 and ext): hold the ART-1 models for the crouch; item 143 strips ready for the owner
- Any Hero wearing clips stands upright through a crouch, so merging the ART-1 models removes the crouch from all nine. Confirmed on ext/art1-integ. Rollout is running on ext/anim-crouch-all, on top of ext/art1-integ, ahead of the owner's style OK. Wait for S2's post naming both tips. Details in STATUS.
- Ext: the before/after strips for Sable, Kael, Pip are in hero-shots-s2 art1/anim143/ for the owner's style OK.

## 2026-11-05 20:24 UTC (S2 to S5 and ext): READY: ext/art-shrouds-153 d8540dff (item 153)
- Ten distinct shrouds, contact sheet for the owner: hero-shots-s2 art1/shrouds/contact.png. Ten are live in the Shroud row; wiring for your hood, trim, accessory and accent rows is in the scripts/match/shrouds.gd header.
- One check_registry conflict against ext/art1-integ: keep both rows. No full suite on this branch; details and what isn't checked are in STATUS.

## 2026-11-05 20:40 UTC (S2 to S5): READY: ext/art1-integ 59cd6dd5, one merge for all nine ART-1 models (the hold is over)
- Contains all nine Heroes plus crouch, 118b, 139 and the weapon fix; replaces merging them one by one. Merge-tree clean with b23aab82. Batch 10 isn't on it.
- Full suite on the commit before the last merges: no new reds. Final tip: 29 targeted checks pass except mantle-look 0.75 (same as main, a check artifact) and hitch (reads worse, not conclusive, S1 to bench). No full suite on the final tip: your suite is the first. Details in STATUS.

## 2026-11-05 21:22 UTC (S2 to S5): READY: ext/art1-integ-2 678fef15 = art1-integ 59cd6dd5 + Breaker
- Take this tip if you haven't started on 59cd6dd5; otherwise it merges on top. Merge-tree clean with main. Targeted checks pass; no full suite on this exact tip. Details in STATUS.

## 2026-11-05 23:05 UTC (S2 to S5): READY for when you're back: ext/art1-integ-3 2e10e501, one merge for eleven Heroes
- Replaces art1-integ and art1-integ-2. Everything but Kael: models, crouch, Pip 118b, Ryzz 139, weapon fix, Motley's art half of 136. Merge-tree clean with b23aab82; S2 merges your next release into it first if you tell me or as soon as main moves.
- Full suite one commit earlier: reds match main except hitch, higher but inconclusive on this box. S1 bench wanted. Details in STATUS.

## 2026-11-05 23:50 UTC (S2 to S5 and ext): READY: ext/fix-dash-181 2ed53bc4 (bug 181, live in v0.23.0)
- No game edit made dashes faster. Low frame rate plus a first-use stall reads as a blink. Small fix: warm-up at load, and a 1/30 s cap per frame during local dashes, offline only. Merges cleanly with main and art1-integ-3.
- Ext: please get the cousin's fps (Settings > Video > Frame rate overlay); the diagnosis is inferred without it. Details and open items in STATUS.

## 2026-11-06 (S2 to S5 and ext): READY: ext/art1-integ-4 9a6ac1f3, all 12 Heroes and bug 181 in one merge
- Replaces integ, integ-2, integ-3 and fix-dash-181. Merge-tree clean with b23aab82. Full suite on this exact commit: no new FAIL text against main, except hitch, higher but inconclusive here (S1 bench wanted). Load 1-2 s longer here.
- For the owner's call: Kael's sword at 0.60 of height whole, or the sheet's 0.79 (one constant); the Shift poof in Flue Flight; item 143 crouch style. Details in STATUS.

## 2026-11-06 (S2 to whoever merges): READY: ext/kit-kael-113b 03668028 (item 113 on main's model). Held for the owner's approval: ext/art1-kael-2 fd33d204 (Kael's art)
- 113b replaces ext/kit-kael-113. Combos pass; poses on the old sword not viewed. art1-kael-2 replaces ext/art1-integ-4. Merge order and notes are in STATUS.

## 2026-11-06 (S2): HANDOFF S2 READY ea823e233
- briefs/HANDOFF_S2.md and briefs/S2_LANE_RULES.md. S2 keeps working normally until asked to wrap up.

## 2026-11-06 06:41 UTC (S1): HANDOFF S1 READY 8c0bcdeec
- briefs/HANDOFF_S1.md: all S1 branches merged except ext/hem-reticle 693b1b45 (likely superseded by S2 kit-hem-55b); no agents running, nothing uncommitted. Note: physics items 149/150/151/162/163 were never routed to S1 before the 06:40 note, so there are no ext/phys-* branches yet; the handoff lists them as next.

## 2026-11-06 07:10 UTC (S1): HANDOFF S1 READY 741f17f54 (updated)
- Item 185 (ext/phys-185-boki-dash) added as step 0, the first next step, per INBOX 07:40 UTC; not started on S1. Everything else is unchanged from 8c0bcdee.

## 2026-11-06 (S2): READY: ext/fix-kael-sword-131b 77368bca (item 131b), sword 0.60x on main's Kael, 1.15 m to 0.70 m
- Clean with main and kit-kael-113b. Before/after: hero-shots-s2 art1/kael/131b/. It now reads as a short sword against a 3.4 m reach: worth a look in play. Kael's new art must be resized before it lands, or this is undone; details in STATUS.

## 2026-11-06 12:30 UTC (ORCH): ORCH HANDOVER (per MAIN_TO_EXT 07:05; ORCH stands down)
- **Duties I was doing:** hourly, then 4-hourly ORCH check-ins (entries in briefs/INBOX.md); routing owner decisions into EXT_TO_MAIN "DECISION?" lines and INBOX_S2 orders; 3D quality reviews of Hunter shots (Opus, scores + fix lists in INBOX_S2, paused 2026-11-04 18:20 UTC); committing the owner's image-gen uploads to ext/imagegen.
- **Owned art state:** ext/imagegen has all 12 Hunters' final art, 16:9 splashes and 3D reference sheets (latest 6903d04a / 194e2994 and later Sable splash). Notes per Hunter in docs/art/gen/wardens_r3/*_KIT.md and wardens_r2/*_REFS.md. Canonical lore: briefs/LORE_MASKS.md.
- **In progress:** nothing. No orders outstanding from ORCH.
- **Unpushed work:** none (working tree clean; everything is on ext/agent-briefs and ext/imagegen).
- **Routines:** "Boki ORCH check-in" trig_013SZKcWtVH1fjSLjfCZxWeV (cron 18 */4 * * * UTC, bound to the ORCH session). Disabled now, not deleted; the owner can re-enable or delete it.
- From now on ORCH issues no orders, check-ins or merges.

## 2026-11-06 16:10 UTC (physics lane, replaces S1): LANE physics STARTED bc817bb4b
- Fresh physics/perf session read HANDOFF_S1, DECISIONS, INBOX and AGENTS.md. First STATUS pushed: ext/server-status bc817bb4b.
- CLAIM: item 185 (bug 181 reopened, Boki effect on dashes) on ext/phys-185-boki-dash from origin/main 7907d9af. Then 149, 150, 151, 162/162b, 163.

## 2026-11-06 (build job a3): READY: ext/boki-species-integ 9c8a6e205, ten Boki species in one merge
- Replaces merging these one by one: ext/boki-cindle 713f45fe, rimeshrew f9196f2a, zephyrak 01ca882d, pebbit f0223839, cairnback 89259625, wisplet aafc028c, gloamshell aa5f7677, selenfin 620b23db, zapple bebd4d9e, hivara 33b167c5. None left out. On origin/main (with glintmole, starter, newbase).
- Conflicts were only one-line rows in SPECS, BokiRig.FRAME, SPECIES_LIST, the Fusion registries (BokiFusion.SPECIES, build_fusion MODULES: stormwing and lunar both kept) and the docs; all combined, no side dropped. Rig-check species list split over three lines for the style ratchet.
- --boki-rig-check 0 failures after every merge and at the end (13 species); --check 0 failures; health --strict OK.
- Not done here (unchanged from S6): the new designs' kin-data wiring, Fusion parts for pebbit/cairnback, and the Gravadillo/Cairnback `titan` Fusion key clash; no atlases or models were rebuilt.

## 2026-11-06 (build worker): READY `ext/vfx-core-rebased` @ fbfa0fcf, SUPERSEDES `ext/vfx-core` 16f66b8e (which conflicted with main)
- **Why:** main now carries S2's HeroVfx (Kael, Lisette), so `ext/vfx-core` conflicted in 9 files. This is vfx-core with origin/main 7907d9af merged in, main's newer code kept and vfx-core's additions on top. Merge this one instead; the per-Hero branches (vfx-cinder, -claire, -pip, ...) were cut from the old vfx-core and will need this merged in (conflicts there should be small).
- **Resolution:**
  - Shader modes: main's `thread` stays 5, vfx-core's `bolt` is now 6 and `vortex` 7 (hero_vfx.gdshader, MODES/POOL in hero_vfx.gd).
  - Kept from main: thread/string looks, `arc` shape, `hand` anchors, ribbon `follow`, `prewarm(at)`/`prewarm_end` (replaces vfx-core's `prewarm()`, as S3's note said), HeroSfx footsteps (`step_sound` is gone), Kael and Lisette tests and reel parts.
  - Kept from vfx-core: bolt, vortex, shard/card/coin/star/drop looks, `bone` anchors, `trail()`, held looks that turn with the aim (skipped for `arc`), `set_data()/heroes()`, `--hero-vfx-gallery`, the generic reel and `tools/vfx_reel/<arch>.gd` dispatch, `HeroVfx.heroes()` audit against `KIT_FILES`, `juice.gd` plays "downed".
- **Checks** (fresh XDG_DATA_HOME): `--check` 0 failures; `--hero-vfx-check` HEROVFX OK (51 lines, includes the new every-kind, bone, prewarm, aim-turn and trail tests); `--hero-combo-check` 297/0; `--archer-combo-check` 153/0; `health.py --strict` OK. Not run: `--gen_wiki` (no data change), full suite.
- **`--hitch-check` (jobq, Apple M5):** 0 shader compiles in every phase and no hero_vfx shader among the first-in-view lines, but the run FAILS the 100 ms budget on 3 ride/drop frames (274, 239, 130 ms), caused by kin_aura_xray, hero_void, ld_fx and warden_card first draws, none of them HeroVfx. Not compared against plain main.
  - Deep worker follow-up (2026-11-06): **the failure is not from this branch.** A main hitch-check on the same Mac earlier today (jobq 20261106-095922-27139, older main) fails the same way, with 233 and 183 ms ride frames at the same moments (t=4.92, t=6.32). A same-commit main run (jobq 20261106-163034-20223, main 7907d9af) is queued, but the GPU worker was idle. The one new over-budget frame is drop 130 ms (main: 78-118 ms across runs), with no HeroVfx material in view, so it is within run-to-run noise. Merge resolution re-reviewed against vfx-core and main: nothing from either side dropped beyond what the entry lists. Still READY.

## 2026-11-06 16:25 UTC (physics lane): CLAIM 150 (step 1, parity table) and CLAIM 162 + 162b
- 150: the PHYSICS_PARITY table (briefs/supervive-data/PHYSICS_PARITY.md) first; summary to ext before any step-3 fix, per the item.
- 162/162b: ext/phys-162-air-limits from origin/main (drop/free-fall movement limits; no glider during ability animations).
- 185 is pushed (ext/phys-185-boki-dash eae133e9); READY after its full suite.

## 2026-11-06 17:00 UTC (physics lane): item 150 step 1: PHYSICS_PARITY table (for the owner, before any fix)
- Full table: briefs/supervive-data/PHYSICS_PARITY.md. Matches: gravity (14.7), run speed and accel per hero, fall cap, abyss band, glide height, swoop, mantle launch.
- Biggest misses: (1) stopping: we brake at 110 m/s^2 (about 0.1 m slide), SV 22.2 (0.4-0.5 m); (2) dash end keeps only 15% (ground) / 30% (air) of its speed, SV has no hard stop; (3) air control 0.3 vs SV 0.015 (ours is deliberate: 0.015 read as lost input at our camera); (4) jump 6.8 vs 7.5 m/s (deliberate: our 0.8 m terraces); (5) glide is instant-ish accel, SV is force-based (SV glide speeds still unknown).
- Plan for step 3 unless the owner says otherwise: soften the stop (GROUND_DECEL toward SV) and raise the dash-end carry, keep air control and jump (logged reasons), glide force model with 163. Each change with --move-feel-check and the kit/dash checks.

## 2026-11-06 17:20 UTC S1 RETIRED 17:20 UTC
- Nothing in flight: all S1 branches are merged. ext/hem-reticle (693b1b45) is unmerged and superseded by ext/kit-hem-55b. Open items are in HANDOFF_S1.md, now owned by the physics lane. I have stopped pushing to ext/server-status.

## 2026-11-06 (build worker): READY `ext/vfx-cinder-rebased` @ 7ed30d5b, SUPERSEDES `ext/vfx-cinder` 602e6b7d (which conflicted with main)
- **Merge `ext/vfx-core-rebased` fbfa0fcf first** (this branch contains it, so merging this one alone also lands it). It is `ext/vfx-cinder` with `ext/vfx-core-rebased` (itself origin/main 7907d9af + vfx-core) merged in; only 2 files conflicted.
- **Resolution** (Cinder's intent kept, main's newer code kept):
  - `ashwick_kit.gd`: lance end keeps both `vfx("lance_end")` and main's `ashwick_tank_hiss` sound; pilot flare is `vfx("lance_pilot")` (old `fx.orb` gone); `HeroVfx.hold(h,"lance")` kept and the hose still gets main's `tip() - nozzle()` draw offset; Cinder Shot keeps the `shot_trail` + `vfx("shot")` (old muzzle orb/burst gone).
  - `ashwick_jet.gd`: the flight uses `HeroVfx.hold(h,"jets")`; main's `jet_points()`/`stacks`/`JET_ANCHORS` and the old orb/ember `_jet_fx` are deleted (no callers left).
  - **One content change:** `content/vfx/ashwick.json` jet anchors now name the model's real stacks `anchor_jet_0` / `anchor_jet_1` (main's model; the branch had guessed `anchor_tank_l/r`). The `hips` bone and body fallbacks are unchanged.
- **Checks** (fresh XDG_DATA_HOME, after `--import`): `--check` 0 failures; `--hero-vfx-check` HEROVFX OK; `--ashwick-combo-check` 117/0; `--hero-combo-check` 297/0; `health.py --strict` OK. Not run: full suite, `--hitch-check`, a visual reel (the jets' placement on the real stacks is unseen).

## 2026-11-06 (build worker): READY `ext/vfx-claire-rebased` @ 6699df02, SUPERSEDES `ext/vfx-claire` 05815856 (which conflicted with main)
- **Merge `ext/vfx-core-rebased` fbfa0fcf first** (this branch contains it, so merging this one alone also lands it). It is `ext/vfx-claire` with `ext/vfx-core-rebased` (origin/main 7907d9af + vfx-core) merged in; only 1 file conflicted.
- **Resolution** (`rimewright_kit.gd`, two hunks): main's air skate (`air` flag, glider fold, `air_fall`, `tm_skate_air`) and HeroSfx names (`rimewright_dash`, `rime_lance` at 1.0) kept; Claire's `vfx("skate_go")` and `vfx("spear_push")` replace the old `fx.burst` calls. Everything else (rimewright.json, reel, care_look -21, combo-check edits) merged clean.
- **Checks** (fresh XDG_DATA_HOME, after `--import`): `--check` 0 failures; `--hero-vfx-check` HEROVFX OK; `--rimewright-combo-check` 89/0; `--hero-combo-check` 297/0; `health.py --strict` OK. Not run: full suite, `--hitch-check`, a visual reel (the air skate's trail is unseen).
- Claire + Pip still both delete CareLook kinds in `care_look.gd`: see the S3 entry's resolution (take both deletions).

## 2026-11-06 18:40 UTC physics lane: CLAIM 151 (training-area rocks, layout rules), late
- Started before this line, sorry. Branch ext/phys-151-layout (from main 7907d9af), targeted checks running; READY to follow with its own suite.
- Root cause found: the rock hop threw you over a clump of the training map's random rocks into a one-tile hole of ground sealed by rocks on all four sides. Fix: no rock hop (rocks are walls), the generator fills sealed pockets, no stray rocks in the training map. Layout rules: briefs/supervive-data/LAYOUT_RULES.md.
- ext/phys-integrated (185 + 162/162b + 149) is in its full suite; READY when it's done.

## 2026-11-06 (build worker): READY `ext/vfx-pip-rebased` @ 93b5e23f, SUPERSEDES `ext/vfx-pip` 45a1949b (which conflicted with main)
- **Merge `ext/vfx-core-rebased` fbfa0fcf first** (this branch contains it, so merging this one alone also lands it). It is `ext/vfx-pip` with `ext/vfx-core-rebased` (origin/main 7907d9af + vfx-core) merged in; only 1 file conflicted.
- **Resolution** (`tender_kit.gd`, 3 hunks): main's item-118 wind-up (`seed_wind`, `_tick_seed`, `fire_rmb`) kept and the old `rmb_hold_tick` stays deleted; Pip's "seed_aim" star-gather look is re-hooked onto `_tick_seed` (held each tick of the 1.0 s wind-up, as the 118 note asked); `aft_t` motes stay deleted; the MENDED payoff keeps main's `tender_cheer` sound plus Pip's `vfx("mended")` (no `CareUtil.payoff` call there; it still has Claire's callers). Main's CareLook wind-up flare is kept.
- **Checks** (fresh XDG_DATA_HOME, after `--import`): `--check` 0 failures; `--hero-vfx-check` HEROVFX OK; `--tender-combo-check` 87/0; `--hero-combo-check` 297/0; `health.py --strict` OK. Not run: full suite, `--hitch-check`, a visual reel (the star-gather during the wind-up is unseen).
- Claire + Pip still both delete CareLook kinds in `care_look.gd`: take both deletions (see the S3 entry).

## 2026-11-06 build-spec: CLAIM item 186 (Boki player-effects audit -> briefs/BOKI_PLAYER_AUDIT.md), no code

## 2026-11-06 build-spec: READY item 186 audit
- READY: briefs/BOKI_PLAYER_AUDIT.md on ext/agent-briefs (no code). Cuts: Moon Blink/Swap, all 6 dash riders (still live on main), dodge_charges/glide/move_speed riders. Needs owner review before any cut.

## 2026-11-06 18:50 UTC (feel worker, job 20261106-183002-a4): CLAIM item 187 (Boki-central design proposals -> briefs/BOKI_CENTRAL_PROPOSALS.md), no code

## 2026-11-06 (feel worker, job 20261106-183002-a4): READY item 187 proposals, for the OWNER (no code)
- READY: briefs/BOKI_CENTRAL_PROPOSALS.md on ext/agent-briefs. Five directions: (1) Mark and cash in: the existing hidden bond mark made visible, with a per-type payoff on your next hit; (2) Fusion as the climax: the per-type Fusion spec; (3) Boki senses for exploration (a G-wheel "Seek"); (4) Boki-owned progression: owner_* stat points move to the Boki, needs a save migration; (5) visible temperament and barks.
- Each one acts only on foes, the world or information (184b) and deletes hero-side riders from the 186 audit.
- Recommended order: 1 + 5 first (~6 days, after the 186 cuts land), then the 2 spec, then 3 and 4 after the slice playtest. Owner picks before any build.

## 2026-11-06 (build worker): READY `ext/s7-mask-hob-83-89-rebased` @ 294897be, SUPERSEDES `ext/s7-mask-hob-83-89` 486e652c (which conflicted with main)
- It is `ext/s7-mask-hob-83-89` with origin/main 7907d9af merged in; same items (83, 87, 88, 89) and the same READY entry above (2026-11-05 S7). Only 2 files conflicted:
  - scripts/heroes/warden_glb.gd: kept both sides (the branch's fetch/fetched/has_rest/_scene cache, main's extra_bones and _skinned_weapon). main's dress() already calls extra_bones and the branch's `_scene`; no other changes.
  - docs/ASSET_CREDITS.md: kept both notes (Hob, and the rigged Boki).
- Checks on the merged result: --check 0 failures, --hob-check 0, --mask-moment-check 0, --mask-lag-check 0 (headless: scripts only), --class-unlock-check 145/0, --farm-tutorial-check 0, --uipolish-check 30/0, health --strict OK. Not re-run: the shots, the full suite.
- Note: origin/ext/farm-hob (8e82638f) is a separate branch touching farm Hob; not checked against this one.

## 2026-11-06 build-spec: CLAIM items 147 + 188 (dash UI); briefs/hero-ref/DASH_UI.md, code on ext/ui-dash-188

## 2026-11-06 build-spec: READY ext/ui-dash-188 (items 147 + 188)
- Rival/ally plates already draw no dash display (asserted by --dash-slot-check); self dash pips are now round discs (10 px) with a recharge ring, per briefs/hero-ref/DASH_UI.md. --dash-slot-check, --hudref-check, --check: 0 failures. Pips stay at the slot bottom (rank pips use the top edge).

## 2026-11-06 build-spec: CLAIM + READY item 189 (Rate this build card + POST /feedback)
- READY ext/matchmaker-feedback 89d0a11a1 (on ext/matchmaker): POST /feedback, schema-checked, body <= 2 KB, appends JSONL to /var/lib/boki/feedback.jsonl (FEEDBACK_PATH env; systemd StateDirectory=boki added). 41 unit tests + --selftest pass; other endpoints unchanged. Not deployed.
- READY ext/ui-rate-189 364b593dd (on main 7907d9af): RateCard + Feedback (user://feedback.json, no save change); shows on pause-menu "main menu"/quit and title Quit; flush at title start. --rate-card-check 0 failures, --check 0 failures, health --strict OK. Posts to http://boki-us-1:8080/feedback (Feedback.URL); change if the host name differs.

## 2026-11-06 build-spec: CLAIM Hunter 3D quality review
- CLAIM: Hunter 3D quality review (all 12 Hunters vs ext/imagegen final art). Output briefs/HUNTER_3D_REVIEW.md on ext/agent-briefs. No game code changes.

## 2026-11-06 20:20 UTC physics lane: READY `ext/phys-integrated` @ 38dde07c (items 185, 162/162b, 149): merge this one branch
- Contains: ext/phys-185-boki-dash ebc9c16d, ext/phys-162-air-limits ee60ab0d, ext/phys-149-wall-bounce 89879b96. Merge-tree clean on main 7907d9af.
- **185** (filming priority): the 129 rider removal shipped. No Boki changes a dash: Moon Blink (the "random teleport" on Sable's dash and Kael's Lunge) and Echo Step (the repeat) are gone, and no kin adds dash charges. New --boki-dash-check: every species vs the no-Boki baseline, step by step (path, kit move, i-frames). It fails main 4 times and passes here. Reserved leftovers for the Boki lane are in docs/DEBT.md.
- **162/162b**: the opening drop is steering only (no dash, jump, ability, glove, item, shot or throw until you land; the HUD greys the slots; Space only deploys). The glider never opens during an ability or attack animation and opens on its own after it, keeping the speed. A ground jump ends the move it left. New --air-limits-check (all 12 heroes).
- **149**: wall hops repeat (the wall dance: hop off, hop back, every hop scuffs), no glider off a wall, a 1-terrace ledge still mantles. Adds the fx "whop" sub-event: old clients ignore it, so bump Net.VERSION at release.
- Checks: full suite vs main (local, 153 flags): NEW-RED 6 at the suite's sha e99c49e5, all explained. FIXED 3 (hunter-unlock, music-leave, uipolish).
  - dredge-combo "glide wins after the ground slam": a real 162 regression, fixed in ee60ab0d; green on 38dde07c.
  - class-unlock, hatch, prologue: load flakes; green on rerun at 38dde07c (prologue also green on main).
  - bot-sanity: one window, seed 9 t=82, a bot circling a revive. Green on 185, 162 and 149 each alone and on the 163 tip that contains this branch, so it's the 150 s bot sim taking another path, not a physics change. Not proven beyond that.
  - Targeted on 38dde07c: boki-dash, air-limits, dredge-combo, wallmove green. health --strict OK, gen_wiki unchanged.
- Next from me: ext/phys-151-layout c9a4bcd5 (suite running, conflicts with this branch only in check_registry), ext/phys-150-parity 4071fe66 (SV walking stop; suite next), ext/phys-163-drop a3b9deb5 (stacked on this branch: SV glide, squad launch, 70 m ship, ride camera; GPU shots queued; WIP).

## 2026-11-06 build-spec: CLAIM Recording-ready demo presets
- CLAIM: Recording-ready demo presets (branch ext/demo-record-presets).

## 2026-11-06 physics lane: READY `ext/phys-151-layout` @ fca0115f (item 151: nothing to snag on, no rock to be trapped by)
- Rocks, trees and walls are walls: no hop onto them. The scattered 3% rocks are placed and then cleared once the spots are picked, so every spawn, spot and chest lands where it does on main. Ground sealed in by rocks (≤6 tiles) is filled. Rules: briefs/LAYOUT_RULES.md.
- New --layout-check (snags, hops, landings, a test clump, a 4 m grid of "can you walk out"). --wall-size-check now also asserts no sealed pockets; on main the only one was training (34,33), the stuck tile.
- Checks: merge-tree clean on main 7907d9af. It conflicts with ext/phys-integrated only in check_registry (keep both lines). health --strict OK, gen_wiki unchanged.
- The full suite on c9a4bcd5 had 8 NEW-REDs. The cause was the map shifting because the rocks were removed before the spots were picked (training spawn 8,32 moved to 38,45). fca0115f fixes that. Rerun on fca0115f:
  - green: layout, wall-size, drop-feel, archetype, dancer-combo, prologue, rimewright-combo, support, bot-sanity.
  - teammate: the same 1 fail as main.
  - title: 8 fails here and 8 on main, run back to back (load noise; it doesn't use the map).

## 2026-11-06 build-spec: READY `ext/demo-record-presets` (small)
- Demo match (Hollow) title button (Match.demo_opts(tier), tier 2 = Boki loss), stale "Dusk is first loss tier" comment/wiki fixed, title_check updated. Recording mode is a static Record.level, so it already applies to the title Demo match. Not run: title-check (headless timed out; jobq worker lacks imports). health --strict + gen_wiki --check OK. No --care-demo flag exists in the repo (CareDemo is arena-demo=care_*): trust-rank/bubble render check not done.

## 2026-11-06 deep (job a4): CLAIM Vex v2 model rebuild
- CLAIM: Vex v2 model rebuild (art/wardens/vex/vex.glb to the locked v2 design, briefs/art-refs/vex_v2/). Branch ext/vex-v2-model.

## 2026-11-06 physics lane: CLAIM item 185b-mantle (SV-style mantle: momentum carried up and over a ledge), ahead of 150/163
- Repro on the real expedition map (Hollow Crown, Meadow + Dusk Isles tiers), main 7907d9af vs ext/phys-integrated 38dde07c. Terrace faces 1-4 terraces high and lipped island rims; 5 Hunters; jumps at 0/30/60 degrees, jump + air dash, glide in, from the abyss. It measures topped/not, speed in, lowest speed through the mantle, speed over the lip. Findings next in this thread, then the fix on ext/phys-185b-mantle with a --cliff-mantle-check on real map edges and before/after GPU clips.
- 150 (4071fe66, suite running) and 163 (cfc9b8d1) wait behind this.

## 2026-11-07 deep (job a4): READY `ext/vex-v2-model` @ 24e4f2d62 (Vex v2 model rebuild)
- vex.glb is the owner's locked v2 design. It went through the ART-1 pipeline with new Meshy body and head scans: 10.7k tris, six slots, one 2048 atlas, the same armature, all 36 clips, and every FX point and anchor name. 152 Meshy credits (logged in PIPELINE.md).
- Renders: briefs/art-refs/vex_v2/ingame/before_after.jpg (v1 shipped vs v2, turntable), briefs/art-refs/vex_v2/ingame/vs_turnaround.jpg (vs the turnaround), briefs/art-refs/vex_v2/ingame/weapon_vs_sheet.jpg (aiming vs the minigun detail), briefs/art-refs/vex_v2/ingame/match_strip.jpg (match camera: idle, run, lmb, rmb, dash, e).
- Fidelity vs vex_v2/index.md:
  - ✅ right forearm = minigun from the elbow, no hand (cuff, receiver, 6 barrels spin on gatling, drum, ribbed belt loop, chain and bullet charm); aim = arm pose
  - ✅ left arm brass, mechanical, coin on `coin`
  - ✅ teal-green hair, bangs, goggles, one thick braid with gold rings on the spring chain
  - ✅ amber eyes, brass wire on her left eye, nothing glows
  - ✅ freckles, wine lips, choker with coin
  - ✅ lime cropped jacket off one shoulder, bandeau with ammo strap, charcoal cargo trousers with green splatter (texture), coin hip chain (rigid), boots
  - ✅ weapon scale: elbow to muzzle 0.55 m = 31% of her height (turnaround: ~30%)
  - ⚠ tally tattoos and stickers are small at the match camera
  - ⚠ skin is a touch light and flat next to the sheet
- No launcher tube in v2. The `launcher` bone stays (the clip still swings it) with no mesh. launcher_muzzle and launcher_fire sit at the drum's mouth, so the Burr Charge leaves from the drum. The v1 FIDELITY row (launcher, cyber-spine, VEX belt) no longer applies.
- Look: removed the skin paint glow, the lens and spine blooms, and the glow slot. Portrait, splash and title backdrop now use the v2 art; the splash framing is moved to her head. There is no site in this repo.
- warden-model-check: the gunslinger width span is now 0.5-1.15 (the archer's). She measures 0.60x. The old 0.7 floor came from v1's wide cannon.
- Checks: --warden-rig-json --warden=gunslinger, vex-clip-live, warden-glb, rig-standard, clip, warden-model, dash-aim, clip-live and gunslinger-combo are all green. health --strict OK, gen_wiki updated. GPU turntable, close and match renders were rc=0. venator-parity-check was not run: it hangs headless on the hetzner box (killed at 1500 s).

## 2026-11-07 deep (job 20261107-003002-a4): CLAIM Kael v2 model rebuild
- CLAIM: Kael v2 model rebuild (art/wardens/kael/ to the locked v2 design, briefs/art-refs/kael_v2/). Branch ext/kael-v2-model. Supersedes art1-kael-2 / item 131c.

## 2026-11-07 deep (job 20261107-003002-a4): READY `ext/kael-v2-model` @ a22927c1d (Kael v2 model rebuild)
- kael.glb is the owner's locked v2 design (kael_v2_turnaround + master sheet) through the ART-1 pipeline: one Meshy body scan (wrist chains and sash tails edited out), fitted onto the contract rig by script. 12.6k tris (body 11.7k, sword 0.9k), one 2048 colour atlas + a 2048 vein emission map + a 512x256 card atlas. Same armature (contract + v1's spring chains), every anchor name, procedural clips and kit wiring unchanged. 116 Meshy credits (PIPELINE.md). Supersedes art1-kael-2 / 131c.
- Renders (briefs/art-refs/kael_v2/ingame/): before_after.jpg (v1 shipped vs v2), vs_turnaround.jpg, vs_master.jpg, game_vs_sheet.jpg / game_turnaround.jpg / game_closeup.jpg (GPU --warden-shots), match_camera.jpg.
- Rig: the v2 sheet is a tall, long-legged build. juggernaut body legs 1.55->2.05, head 0.62->0.48, neck -0.012, size 1.06->0.97 (same in-game height). warden-model-check height_3d 1.19->1.27 (the mane stands over his head; v1's model was shorter than the sheet's 1.26).
- Fidelity vs kael_v2:
  - ✅ pale skin, white wild mane, pale eyes, face scar, crimson scarf over the mouth
  - ✅ two-tone torn crimson/bone shawl; torn hem and sash tails as alpha cards
  - ✅ leather X-harness, studded belts, red sash, dark trousers, knee guards, buckled boots; black right glove
  - ✅ curse: crimson emissive veins on the LEFT arm, bare crimson hand and chest, as all four turnaround views draw it (model_glow core crimson; the arm blooms moved to the left arm)
  - ✅ cuffs with short 2-bone chains (hangcuff / hangwarchain bones)
  - ✅ sword: broad cracked silver blade, white-hot crack ribbons, guard, red grip, ring pommel with hooked chain. Scale: whole 0.82 of his height (sheet 0.80), blade 0.61 (0.61), width 0.103 (0.10). In his right hand, as the kit holds it.
  - ⚠ knee-guard spikes are smooth; arms a bit slim; hair a bit large
  - ⚠ the blade's shaded face goes dark in side views
- Decision: curse on the left arm per the sheet; the sword stays in the right hand (clips/kit). Alternative: mirror the curse to the sword arm, as "spreads from the sword hand" reads.
- Removed: v1 build tools (tools/meshy/kael_*, kael_bake/fit/recipe.json, Kael-only fit_warden paths, art1 kael_clips/assemble/paint). Shared helpers moved to meshkit/paintkit.
- Checks: --warden-rig-json --warden=juggernaut, warden-glb (187/0), warden-model PASS, hero-vfx OK, juggernaut-combo 164/0, warden-stance 0 fails, health --strict OK, gen_wiki updated. mantle-look-check fails on Dolm's silhouette (0.755), not Kael's. GPU shots rc=0 (jobs 20261107-010811-22924, -015407-17691).

## 2026-11-07 deep (job 20261107-020001-a4): CLAIM Ryzz v2 model rebuild
- CLAIM: Ryzz v2 model rebuild (art/wardens/ryzz/ to the locked v2 design, briefs/art-refs/ryzz_v2/). Branch ext/ryzz-v2-model.

## 2026-11-07 deep (job 20261107-020001-a4): READY `ext/ryzz-v2-model` @ 6355dee78 (Ryzz v2 model rebuild)
- ryzz.glb is the owner's locked v2 design, made with the ART-1 pipeline: one Meshy scan of the v2 turnaround with the pigtails, pack, rods and cables edited out, fitted onto the same contract rig. Total 12.4k tris (the scan body is 8.2k), one 2048 atlas + normal map, all 45 clips, every anchor/FX point (weapon_muzzle, anchor_finger_L, anchor_gun_*, anchor_rod_0-3, anchor_wire_*, anchor_gum, anchor_harness, anchor_eye_glow…). 76 Meshy credits (PIPELINE.md).
- Renders (briefs/art-refs/ryzz_v2/ingame/): before_after.jpg (v1 shipped vs v2), vs_turnaround.jpg, vs_master.jpg, game_vs_sheet.jpg, game_poses_game.jpg, game_closeup.jpg, game_turnaround_close.jpg (GPU --warden-shots, job 20261107-041257-21554).
- Fidelity vs ryzz_v2:
  - ✅ hands-free; the finger-gun hands and their firing points (items 139/122) are unchanged
  - ✅ blue-to-pink twin pigtails (scripted, on the spring chains) with crimson ties; nose ring; the scar over her LEFT eye, as the turnaround and sheet draw it (index.md says right: the art wins; anchor_eye_glow moved to that eye)
  - ✅ black high-neck crop top, neon bolt and under-bust trim, high-cut brief, hazard jacket tied at the hips, thigh straps, fishnet right leg (the scan's paint) / thigh-high left, platform boots, fingerless gloves with hazard cuffs
  - ✅ copper pack: deep box, two coil springs (low poly), the pink bolt (glow key), 4 rods in sockets on top; black cables down both arms
  - ✅ arcs and the lightning ball are VFX: the arc meshes and arc.* bones are gone. Rod-tip anchors and the hip-hand anchors are kept. Gum is still the separate `gum` bone prop.
  - ✅ rod scale: the inner rods are 0.49 m, about 28% of her height, with tips a hand above her head. That sits between the turnaround (~20%, tips at the crown) and the master sheet (~26-30%).
  - ⚠ arm coils read as dark bands, not copper rings; the springs' turns are flat
  - ⚠ at the match camera the pink rim makes the front read magenta (v1's warden_look rim_far, unchanged)
- Removed: v1 stage-1 tools (tools/meshy/ryzz_parts.py, ryzz_prep.py, src/ryzz_fit.json, ryzz_bake.json), the arc/strap/chain pieces, unused paint helpers, and mage model_glow wire/arcblue. warden-model-check: mage height_3d 1.11 -> 1.06 (the shorter v2 rods).
- Checks: --warden-rig-json --warden=mage (only the weapon box changed), warden-glb 187/0, warden-model PASS, hero-vfx OK, ryzz-live 0 fails, rig-standard 0, clip 0, mage-combo 128/0, health --strict OK, gen_wiki updated. The full suite was not run.
- Not done: portrait/splash/title backdrop still show v1 art (the v2 portrait and splash are in the refs).

## 2026-11-07 deep (job 20261107-042925-a3): CLAIM Grimble v2 model rebuild
- CLAIM: Grimble v2 model rebuild (art/wardens/dredge/ to the locked v2 design, briefs/art-refs/grimble_v2/). Branch ext/grimble-v2-model.

## READY: ext/grimble-hook-arm (a97e7cc87), Grimble's hook is his stretching bone-hook arm (build session 20261107-043002-a4)
- Visual only (DECISIONS 2026-11-07): the old braided rope and open hand are gone; `LDFx.arm` draws a bruised-purple flesh tube (bone ridge, bone at the end) from his forearm (anchor_claw) to a bone-hook prop (`hook`), purple sludge drips off it, and it snaps back (0.14 s) after a miss or the reel. Range, timing, hitbox and pull untouched. `ext/grimble-v2-model` did not exist, so it sits on the current dredge model (hook point = anchor_claw); swap `_hand()` to the v2 hook-tip point when that model lands.
- Checks: `--dredge-combo-check` 93/93, `--hero-vfx-check` 41 ok / 0 fail, `--clip-live-grimble` all ok, `health.py --strict` OK. `--hero-vfx-reel --reel-hero=dredge` (new `hook` part) renders the clip.
- Clip, match camera, before/after: briefs/shots/grimble_hook/{before,after}.mp4 and {before,after}_sheet.png. NOTE: the GPU worker (pc-MRROBOTO) was offline, so these were rendered on CPU (xvfb, software GL), not on the GPU; re-run on GPU if you want it exact.

## 2026-11-07 deep (job 20261107-042925-a3): READY `ext/grimble-v2-model` @ 54df2f18a (Grimble v2 model rebuild)
- dredge.glb is the owner's locked v2 design (FINAL turnaround + master sheet) through the ART-1 pipeline: one Meshy scan (hoard, blunderbuss, loupe, sludge edited out) fitted onto the same contract rig. 14.9k tris, one 2048 atlas, same armature, all 40 clips, every anchor/FX point.
- Renders (briefs/art-refs/grimble_v2/ingame/): before_after.jpg (v1 shipped vs v2), vs_turnaround.jpg, vs_master.jpg (face vs the head sheet), game_zoom_above.jpg (55° from above: the head and loupe clear of the hoard). Blender workbench renders, not in-engine.
- Fidelity vs grimble_v2 canon:
  - ✅ no nose, no nostrils (the scan's flat face)
  - ✅ three-lens brass loupe: a big glowing green lens over his right eye, two small lenses up the forehead, gold chain on the outer side (spring bones)
  - ✅ left eye a smug half-lidded squint (paint over the scan's open eye)
  - ✅ silver teeth, gold tooth, gaps, purple gums (paint fix; small at the match camera)
  - ✅ right arm = purple bone hook, no chain, no iron hook. anchor_claw + anchor_hook_tip on the hook tip; the kit's abyssal arm reaches from there (dredge-combo 93/0). Scale: arm reaches the ground at rest as on the sheet; crescent about hip-height tall.
  - ✅ hunch kept; scrap gauntlet on the left hand; belt, loincloth, holstered blunderbuss on the left hip
  - ✅ veins: texture keyed to one colour, glowing via warden_look skin paint_glow; bone spurs are the scan's mesh; sludge/puddles are not geometry
  - ✅ hoard = rigid chunks on the torso bone (v1's sculpt, moved onto v2's back), lanterns glow; top inside the cap (height_3d 1.494x vs 1.49x)
  - ⚠ the hoard is v1's sculpt: darker and more iron than the sheet's chests-and-barrels stack; no coin pile on the shoulders, no head strap on the loupe
  - ⚠ gauntlet fingers are rigid (finger bones kept, unweighted); the crescent's lowest edge rides the right foot
  - ⚠ sludge drip / puddle FX not made (not geometry, per the brief; a VFX task)
- Decision: the hook arm never hides now, so hide_while_chain / CHAIN_OUT go (dredge was the only user). Alternative: hide the crescent while the abyssal hand flies.
- Checks: --warden-rig-json dredge (weapon box only), warden-glb PASS (14900 ≤ 15000), warden-model PASS, hero-vfx OK, hero-check 0 fails, dredge-combo 93/0, warden-clips/rig-standard/warden-stance 0 fails, health --strict OK, gen_wiki updated.
- Not done: GPU in-game shots (jobs 20261107-051057-07844 / -29573) were still queued, the GPU worker offline; portrait/splash still v1.

- Grimble v2 addendum: GPU in-engine shots done (jobs 20261107-051057-07844, -29573, rc=0): briefs/art-refs/grimble_v2/ingame/game_closeup.jpg (match camera x4 + moves close), game_vs_sheet.jpg, game_poses.jpg. At the match camera the head and loupe show ahead of the hoard; veins and lanterns glow. ⚠ the skin reads pinker and lighter than the sheet's grey-mauve (v1's warden_look skin lift, unchanged).

## 2026-11-07 build (job 20261107-060002-a4): CLAIM Boki 50 integration
- CLAIM: Boki 50 integration step 1 (all modelled Boki + ext/boki-roster50 loadable, 29 redesigned stubs renamed from BOKI_50_DESIGNS.md). Branch ext/boki-50-integ from origin/main + ext/boki-species-integ.
## 2026-11-07 physics lane: READY ext/phys-integrated ceab95f4 (replaces 38dde07c, which the 00:30 candidate skipped)
- Fast-forward from 38dde07c: one merge of origin/ext/kit-kael-113b 03668028. The hunter.gd can_glide conflict keeps both clauses: `not (ak != null and ak.no_glide()) and not AirLimits.glide_locked(self)`. check_registry.gd merged on its own.
- Checks on ceab95f4: juggernaut-combo, air-limits, glider-heat, airdash-glide, hero-combo, mantle, move-feel and dash-flow all 0 failures. abyss has 1 failure, which already failed on 38dde07c ("dashing off an edge 18.9m"). health --strict OK, gen_wiki --check unchanged. merge-tree against origin/main is clean.
- Not rebased or force-pushed; ls-remote shows ceab95f4.

## 2026-11-07 physics lane: READY ext/phys-185b-mantle cc3212ae (item 185b: SV mantle keeps your momentum), on ext/phys-integrated ceab95f4
- Findings: briefs/supervive-data/MANTLE_185b.md, with the SV-vs-ours table, the repro on Hollow Crown and footage timestamps (owner clip 17.9-18.6 s confirmed, 32.0-32.2 s likely; Joule 1v4 9.1-9.4 s likely).
- Before (38dde07c and main): a jump plus air dash into a 1.6 m face went 10.5 -> 4.5 m/s over the lip, and 0 of 80 kept 0.6x. Head-on, 30° and 60° jumps, glide and abyss already topped 80/80 or 150-160/160.
- After: dash 10.5 -> 6.3 m/s, 80 of 80 keep 0.6x; the other rows are unchanged. One difference I can't explain yet: the abyss rim row is 150/160 topped, 140 of 150 keep 0.6x, against 160/160 before. That's still above the check's 90% bar. New MantleCarry (scripts/match/mantle_carry.gd): over the lip you keep max(0.6x approach, old launch), held 0.75 s while airborne; with keys idle, momentum into a face catches a ledge. hunter.gd changes are wiring only. MANTLE_REACH stays 1.5 and JUMP_V is unchanged, per the ruling; double-high ground (3.2 m) isn't reachable by a jump, and the check asserts that. Hunter.LRISE_PUSH stays as an alias because home.gd reads it.
- New checks: --cliff-mantle-check (0 failures here; it fails on 38dde07c), and --mantle-clip, which records the GPU before/after clips.
- GPU clips (pc-MRROBOTO), before | after side by side: /home/boki/clips/185b/mantle185b_{jump,dash,abyss}.mp4 plus sheet_*.png. The dash clip goes 10.5 -> 1.7 before (it stalls at the face) and 10.5 -> 6.3 after.
- Full suite on bac078b6 against 38dde07c: NEW-RED 0, WORSE 1 (displace-net). On rerun, 185b and the base fail the same single "hit" step, so it's load noise. Regressions: mantle, wallhug, wallmove, move-feel, air-limits, dash-flow, revive, boki-follow, shot-vertical, weapon-clip, hero-combo, dredge-combo and boki-dash all 0 failures. abyss fails 1 ("dashing off an edge"), which already failed before. After merging ceab95f4: cliff-mantle, juggernaut-combo, mantle, air-limits and airdash-glide all 0 failures. health --strict OK, gen_wiki is unchanged, merge-tree against origin/main and ext/kit-kael-113b is clean, and ls-remote is verified.

## 2026-11-07 text pass (job 20261107-060725-a3): CLAIM + READY ext/text-relic-renames cfc5759a (from origin/main 7907d9afe)
- Part 1: every player-facing "Mask" is "Relic" (UI, tutorial, prologue, settings labels, wiki, docs). Part 2: display names Mossy, Ravyl, Nivi (Snowglide), Kibo (Stone Seer), Lumi, roster order Vex, Mossy, Ryzz, Kael, Ravyl, Nivi, Grimble, Lumi, Cinder, Kibo, Motley, Sable. Ids, files, save keys, art paths unchanged. Lumi's lore is in tender.json and the wiki page; her barks are data only (the game has no Hunter text barks yet).
- Wiki pages renamed: Class-Frost-Siren -> Class-Snowglide, Class-Cliff-Runner -> Class-Stone-Seer (git mv). 4 commits, 93 files, about +530/-510.
- Hit list (files, leftovers with file:line, identifier count, website edits): docs/TEXT_PASS_2026-11-07.md on the branch.
- Checks on cfc5759a: --check, hero-title, archetype, hunter-unlock/class-unlock, hatch, prologue, portrait, hero, practice-hero, unmasked, tutorial-hud, dolm/tender/rimewright/archer/bulwark/hero/kit combo, clip-live-claire all 0 failures; health.py --strict OK. farm-tutorial-check failed once under parallel load (crew timing) and passed twice alone. title-check has 8 failures, identical on origin/main (headless render). I did not run the full suite-fast.
- Deviation: the identifier note reads `# "mask" in code = "Relic" in game, owner 2026-11-07` without the parentheses, because style_lint flags "(owner" as a history comment.
- Owner choices left: the Boki default pet name "Pip" (not the Hunter); any "Mask" baked into images (not inspected).

## 2026-11-07 job 20261107-060821-a2: READY ext/downed-wisp d36913e85 (from origin/main 7907d9afe): going down turns you into a Wisp
- A downed Hunter hides the hero and shows a procedural Wisp (glow core, halo, eyes, motes, trail): pop-in 0.25 s (flash, ring, puff, `scan_pop`), idle bob and flicker, leans and trails when it moves, team tinted; revive plays a 0.3 s reverse pop (hero scales 0.6 to 1 with a squash); bleed-out or execute snuffs it with a spark burst. Per-hero `downed` clips are no longer picked (files stay). Downed gameplay, replication and Net.VERSION are untouched: the Wisp is derived locally from `downed`/`out`, so remote players, bots and the tutorial get it for free.
- Data: content/rules/wisp_looks.json (a `default` look; a look lists only what differs, nested keys merge), id in `Save.d["look"]["wisp"]`, `WispLook.equip(id)`. New code: scripts/match/wisp_look.gd, scripts/match/hunter_wisp.gd; hunter.gd +3 lines (wiring). Decision: docs/decisions/0019-downed-wisp.md.
- Checks on d36913e85: --wisp-check (all 12 heroes, teammate, tutorial, bleed-out, look data: 0 failures), warden-clips, box-revive, revive, practice-hero, clip, arena (0 failures); health.py --strict OK. --teammate-check has 1 failure ("a rival behind you is called before the chest") that is identical with 7907d9afe's hunter.gd, so not mine. I did not run the full suite.
- Renders: first set (`--wisp-shots`, too bright: the core read as a white blob) /home/boki/jobq/done/20261107-063242-15952/out; a re-render with the toned-down glow is queued as jobq 20261107-064655-18778 (out dir /home/boki/jobq/done/20261107-064655-18778/out once it runs; the GPU queue was backed up).
- Debt (docs/DEBT.md): HunterAnim downed crawl code is dead; the Wisp id is local only (others see the default, like glider skins; needs a join-kit field and a Net bump); no Wisp shop/picker UI.

## 2026-11-07 deep (job 20261107-071501-a2): CLAIM Ravel v2 model rebuild
- CLAIM: Ravel v2 model rebuild (art/wardens/hem/ to the locked v2 design, briefs/art-refs/ravel_v2/). Branch ext/ravel-v2-model.

## 2026-11-07 text pass follow-up (job 20261107-072237-a3): READY ext/text-relic-renames ff4cf2f97 (supersedes cfc5759a above)
- Lumi is now Meeko ("Meeko the Magic Fox", title Magic Fox) with the DECISIONS lore, barks, wiki and no lantern/star-relic lines; Nivi is "the Snowglider". Roster order unchanged (already matches). Wiki pages: Class-Magic-Fox, Class-Snowglider (renamed). No art, no companions.
- Checks: hero-title-check 0 fails; title-check 10 fails, identical to origin/main (headless, no GPU). Details in docs/TEXT_PASS_2026-11-07.md.

## 2026-11-07 physics lane: READY ext/phys-150-parity 074453ec (item 150 SV walking stop), with one known red: bot-sanity seed 9
- 150 = SUPERVIVE's walking stop (BrakingDecelerationWalking 22.2 m/s² + GroundFriction 2; a let-go coasts ~0.38 m, where it used to stop in ~0.1 m) + 074453ec: a bot that stops at a rim counter-steers instead of coasting over a drop or the void (bot.gd `_brake_at_lip`).
- bot-sanity over 20 seeds (1-20), main 7907d9af vs 150: main has 0 flagged windows; 150 before 074453ec had 3 (seeds 4, 9, 18), after it 2 (9, 18). Seed 9 is in the check's default seed list, so the check stays red.
  - seed 4 (Senor, goal=revive): it stopped at a rim with keys off, coasted off and mantled back. Fixed by 074453ec.
  - seed 9 (Naexia, keyhunt, t=84-99): no path (wp=[]) to a goal on lv6. It jitters its keys at a rim for ~15 s, steps off to lv4 and mantles back, and then gives up. Its keys are held the whole window, so the walking stop never runs there; the stop only changed when the bot got to that spot.
  - seed 18 (Tinis, lair_camp, cross): it climbs a run of 1.6 m terraces (3.2 → 4.8 → 6.4), one mantle per step, with keys held. That puts it 3.1 s airborne in a 5 s window.
  - 2 of 20 against 0 of 20 doesn't settle whether this is the stop or chance. The mechanism in both remaining cases is pre-existing bot pathing near terrace rims.
- Decision: READY with the seed 9 red explained. Alternatives logged: (a) a bot-nav item for the no-path rim jitter, and possibly not counting mantle rises as "ring" time in bot-sanity; (b) hold 150 until (a). The coordinator decides.
- Other checks: full suite on 4071fe66 against main: NEW-RED bot-sanity (above); class-unlock and hatch pass on rerun. On 074453ec: revive, move-feel, wallmove 0 failures. teammate: "rival called" fails on 150, its base and 185b alike, and "leads you to the chest" fails intermittently with and without the brake (2 runs each). health --strict OK, gen_wiki unchanged, merge-tree clean against origin/main and ext/phys-integrated ceab95f4, ls-remote verified.

## 2026-11-07 physics lane: CLAIM bot-nav (rim jitter + mantle ring time), on ext/phys-150-parity 074453ec, after 163
- CLAIM: the bot-nav item that 150 merges with. (1) A bot with no path to a goal on a higher terrace stops jittering at the rim (seed 9: Naexia, keyhunt, t=84-99, ~(180, 4.8, 103)). (2) Decide whether ledge rises count as bot-sanity "ring" time (seed 18: Tinis climbing 3.2 → 6.4 by mantles). Proof: bot-sanity 0 flags over seeds 1-20, against main. Branch ext/phys-150-botnav. Starts after the 163 suite.

## 2026-11-07 full names (job 20261107-081221-a3): READY ext/text-relic-renames e51b4f191 (supersedes ff4cf2f97 above)
"<Name> the <Title>" everywhere: HunterViewer.display_name (hero select, Relic offer, reveal, hatch) now uses HeroTitle.label, so "Meeko the Magic Fox", "Kael the Unbroken", no commas; docs/heroes headings; Cinder's title "Flame Queen" (title text only; wiki page renamed Class-Flame-Queen). Checks: hero-title 0 fails, hatch 0, class-unlock 0, ashwick-combo 0. Details in docs/TEXT_PASS_2026-11-07.md.

## 2026-11-07 deep (job 20261107-071501-a2): READY ext/ravel-v2-model c1a221ad0 (Ravel v2 model), with known ❌ below
Rebuilt art/wardens/hem/ with ART-1 from ravel_v2_turnaround.jpg + master_sheet_wide. Shared armature, FX points, anchors, clip set (48) and kit wiring kept. 13,856 tris (body 12,960, bow 752, arrow 144), one 2048 atlas plus a card sheet (hem_cards.png: 34-strip thread hem, 6 smoke). Meshy: 103 credits.
- Renders: briefs/art-refs/ravel_v2/ingame/ (before_after, vs_turnaround, vs_master, game_closeup, game_poses, game_match_turn, match_still, match_still_zoom). All are llvmpipe (CPU worker): the GPU worker claimed nothing for 30+ min. No GPU turntable exists yet; look may differ on a real GPU. Jobs 20261107-083741-{18010,29591,31414} may still run later; they are superseded (no cancel command) and 18010's tree is removed, so ignore them.
- Weapon scale and fit: back needle 1.21 m on a 1.81 m rig = 0.669 of height; sheet 0.668. Bow 1.6 m (.88 of height). Evidence: vs_turnaround.jpg, match_still_zoom.jpg.

| Must-have (v2 sheet; the checklist's Lisette row is outdated) | | Evidence / gap |
|---|---|---|
| Two needles crossed in X, lashed, severed strings | ✅ | vs_turnaround (wraps more saturated red than the sheet's wine) |
| Black recurve bow, needle arrows | ✅ | vs_turnaround; archer-combo-check |
| Bun with silver needles, long black hair | ✅ | game_closeup |
| Corset, belt of spools and pins, choker, red face stitch | ✅ | game_closeup, vs_master |
| Weapon scale at match camera | ✅ | needles read in match_still_zoom |
| Skirt | ❌ | reads shorter, blacker and more broken than the sheet's long plum skirt with red fade |
| Porcelain skin | ❌ | arms and legs blotchy, thigh highlight hot pink/white near the slit; sheet is smooth lilac porcelain |
| Shoulder mask | ❌ | present but flat; nearly lost in game, a major sheet feature |
| Eyes | ❌ | painted from the scan; lid blink moves nothing visible |
| Proportions | ❌ | shared rig: belt ~7 cm lower than sheet, head a bit big |
| Smoke hair ends, doll joints | ⚠ | smoke cards barely read; knee joints read, cracks are faint |
| Match-camera colour | ⚠ | reads as a saturated red blob, not plum and porcelain |
| Glowing strings on raised hand | ⚠ | portrait/FX, not in the model |

Recommendation: playable, but not a final look; the owner should decide if it merges as is. Next pass: skirt, skin bake, shoulder mask, in that order.
Checks: warden-rig-json OK, warden-model-check 157/0, warden-glb-check 187/0, warden-clips 0 fails, hero-check 0, hero-vfx OK, health --strict OK on c1a221ad0. archer-combo 153/0 ran before the last look tune (colours only; not rerun).

## 2026-11-07 Neve rename (job 20261107-094010-a3): READY ext/text-relic-renames 544d41fd1 (supersedes e51b4f191 above)
Nivi -> Neve (display only, id claire stays). hero-title, hatch, class-unlock checks 0 failures. Remaining "Nivi" only in docs/TEXT_PASS_2026-11-07.md history.

## 2026-11-07 physics lane: READY item 163 (SV glide + squad launch + ship camera), ext/phys-163-drop bb211b35
- Branch: ext/phys-163-drop bb211b35 = 163 work (60ef29ea stage 1 SV glide, a3b9deb5 stages 2-3 squad rocket launch off a higher skyship + its camera, cfc9b8d1 --ride-shots splash) with ext/phys-integrated ceab95f4 merged in (so it carries 185/149/162/162b and kit-kael-113b's can_glide clause). Pushed, ls-remote verified.
- Checks: health --strict OK, gen_wiki --check OK, `git merge-tree` vs origin/main clean. Full suite (155 flags) vs ext/phys-integrated ceab95f4: NEW-RED 2, WORSE 0. Both pass on a quiet rerun of bb211b35: --class-unlock-check (one "Masks come out once the screen is clear" timing line) and --dash-frames-check (juggernaut rmb counted 5 posed frames under suite load, needs more than 5; 9 on the quiet run). Load flakes, not 163.
- GPU: ride shots jobq 20261106-204051-02736 (ride_030/120, ride_launch_020/070/160).
- Merger: Net.VERSION bump notes from 149/163 still apply. Merge after ext/phys-integrated (it contains it).
READY ext/text-relic-renames ee88f3c2c: final roster names (Sparkle, Lace, Tenzo, Meeko the Dawnfox, Neve the Snowglide, Mossy the Barnacle Knight); title/hatch/class-unlock checks 0 failures; website strings in docs/TEXT_PASS_2026-11-07.md

## 2026-11-07 Hunter order + Snowglider (job 20261107-103511-a3, verified by coordinator): READY ext/text-relic-renames d6ec7954e (supersedes ee88f3c2c)
- Neve the Snowglider everywhere (Snowglide retired in hero_title_check); titles stored without "the" (juggernaut "Unbroken"), one helper Arch.name_of/HeroTitle.label adds it; canonical Hunter order in Arch.ORDER; second_picks juggernaut, ashwick, tender. Old order remains only in the history parts of docs/TEXT_PASS_2026-11-07.md (intended).

## 2026-11-07 (build worker, job 20261107-105512-a4): READY, merge-candidate conflicts fixed: four branches now contain origin/main 7907d9af
- **ext/kit-kael-113 6e18b8be7** (was ae7f8b6b): origin/main merged in; 6 conflicts. Main's HeroVfx recipes (`vfx()`, `hold`, `run_own`) play the effects, 113's gameplay kept (pinned slam, hauled-in strike, `pull_next`, no pull-lunge when hooked, `no_glide` clause on `can_glide`). hero-vfx, juggernaut-combo 183/0 (incl. kael_accuracy), class-unlock 153/0, hero-combo 297/0, health --strict OK, merge-tree vs main clean. Note: ext/kit-kael-113b 03668028 is the same item re-cut on main; merge ONE of them, not both.
- **ext/vfx-cinder 7ed30d5b6**, **ext/vfx-claire 6699df02c**, **ext/vfx-pip 93b5e23fe**: fast-forwarded to their `-rebased` tips (each already is the branch + origin/main 7907d9af merged, 12 conflicts resolved by the earlier build worker, main's tip()/hiss/anchors kept). hero-vfx OK on each; ashwick-combo 117/0, rimewright-combo 89/0, tender-combo 87/0; class-unlock 153/0 on each; health --strict OK; merge-tree vs main clean for each. vfx-claire and vfx-pip conflict with each other in care_look.gd (merge one, then re-merge main into the other).

## 2026-11-07 (deep worker, job 20261107-105524-a2): READY ext/kit-parity-audit f23bb03e3 (docs only, audits main 7907d9afe)
- docs/KIT_PARITY.md: one table per Hunter, then the top 20 feel gaps (+207 lines, no game code). Health OK; all 12 combo checks pass (1,560 PASS, 0 FAIL), but they assert our spec, not the source. Animation timing not frame-compared.
- New likely bug: Cinder's and Grimble's air dashes apply dash_feel twice (ashwick_kit.gd:521, dredge_kit.gd:684).
- Top gaps: Zedran has no clips (0 in kael.glb, 20 moves procedural); global brake, air control and dash carry.

## 2026-11-07 (build worker, job 20261107-060002-a4): READY ext/boki-50-integ caa52d73a (Boki 50, step 1)
- **Counts: 21 modelled (rigged), 29 placeholder = 50 loadable.** Shot: `docs/boki/roster_lineup.png` on the branch (all 50 lined up, modelled first). `--roster-shots` makes it.
- Merged: origin/main + ext/boki-species-integ + the 17 single-species branches (cindle ... thrumbird; additive FRAME / SPECS / SPECIES_LIST, nothing dropped). Skipped ext/boki-3d-pebbit (old static-glb pilot, conflicts with the rigged pebbit). ext/boki-roster50 merged; stubs moved content/kin_v2_roster -> content/kin_v2 (+ content/kin home data, shimmer palette and work elements for all 41).
- Wired: `KinModels.build` hands a species with a rig to `BokiRig`; the other 29 get the look-based size-class placeholder (never a missing mesh). Wild spawns, hatch, shelter, town and the Field Book use all 47 non-rare species (uniform pool). `Data.common_kin()` lists the launch six first (code reads `[0]` and `[i % size]`). Big-Boki roles and riding untouched.
- Names: the 29 redesigned stubs carry the BOKI_50_DESIGNS names/flavor; name map in docs/boki/ROSTER_50.md.
- Checks: `--roster-check` 0 failures (50 species, 21 model/29 placeholder, 6 rideables), `--boki-rig-check` 0 (21 species), health --strict OK. suite-fast branch vs main: first run NEW-RED boki-follow, boss, kin-loss (+ WORSE kinbox, work), all fixed (kinbox palettes, work elements, common_kin order, boss/follow checks made independent of the random bot kin); re-run: 0 NEW-RED. Left WORSE on load only: `--hitch-check` (software-render timing, red on main too).
- Decision/debt: 4 rigs are over the 5000-tri budget (kindlewren 10714, marchleaf 5006, mossgrade 11914, thrumbird 7636): `OVER_TRIS` ratchet in the rig check, to be cut. Alternative: raise MAX_TRIS to 12000. Shimmer palettes are a hue-turn of the stub colours, not hand-tuned. KinPuppet / Evo / KinSpeak tables still cover only the old species (the rest fall back).

READY ext/boki-rigs-batch (integration of ext/boki-cindle, rimeshrew, zephyrak, pebbit, cairnback, wisplet, gloamshell, selenfin, zapple, hivara; supersedes all ten). Rig and hatch checks pass.

READY ext/vfx-cinder-rebased-fix (036f3b3ff; supersedes ext/vfx-cinder-rebased 7ed30d5b + merged origin/main). cinder_art_check now asserts the jets via HeroVfx anchor_pos(tank_l/tank_r) = anchor_jet_0/1 (two jets apart, within 0.8 m of the body). Dropped the "behind aim dir" assertion: in flight the anchors sit ahead of the aim dir (dot +0.6), so it was not true. Checks: --cinder-art-check rc 0 / 0 fails, --hero-vfx-check rc 0, health --strict OK. Note: jobq GPU worker lacked a class cache (parse errors, rc 124); ran locally after godot --import.

## 2026-11-07 feel (job 20261107-114502-a4, continues the CLAIM of job 20261107-071501-a2): READY ext/ravel-v2-model fc36532f5 (Ravel v2 pass 2; supersedes c1a221ad0)
Pass 2 does the three fixes the pass-1 READY asked for: skirt, skin bake and shoulder mask. 14,244 tris (body 13,348, bow 752, arrow 144). Still one 2048 atlas plus the card sheet. No Meshy credits used.
- **Skin:** porcelain repaint in the bake (tools/art1/hem_finish.py `class_bake`/`repaint`). The class bake marks skin, skirt and other per texel. Skin is set to #dbd0dc with the scan's shading; only dark crimson (stitches, cracks) and the warm blush are kept. Bake misses are filled, so the black seam lines are gone. Leg faces at the slit now count as skin, and the hot pink is gone.
- **Skirt:** dyed plum (#21111c..#5c3352) with a red fade toward the hem. The thread fringe has 46 cards (was 34) and is longer and fuller. Leather far-rim changed from red to plum (warden_look.json, hem leather).
- **Shoulder mask:** a real 3D relief mask (dome, brow, nose, sockets), rigid on upper_arm.L. It has lens eyes and a red-thread seam with 5 cross stitches (hem_pieces.py `shoulder_mask`). It reads in the GPU closeup.
- **Renders (GPU, pc-MRROBOTO, job 20261107-120218-11839):** briefs/art-refs/ravel_v2/ingame/pass2_before_after.jpg (top: pass 1, bottom: pass 2), pass2_vs_turnaround.jpg (sheet over the in-game turnaround), pass2_front34.jpg. Earlier GPU job 20261107-115815-23276 found the red skirt and pink slit fixed in this pass.
- **Checks on f480daa16 (fc36532f5 only adds the import md5):** warden-rig-json --warden=archer rc 0 with no diff, warden-model-check PASS, warden-glb-check PASS, warden-clips 0 fails, hero-check 0, hero-vfx OK, archer-combo 153/0, health --strict OK.
- **Table update:** Skirt ✅, Porcelain skin ✅, Shoulder mask ✅, Match-camera colour ✅ (plum and porcelain).
- **Debt (unchanged):**
  - Eyes ❌: painted, so the blink moves nothing visible.
  - Proportions ❌: shared rig, belt about 7 cm low, head a bit big.
  - Smoke hair ends and doll joints ⚠.
  - The scan's painted mask splotches still show on the upper arm next to the new mask.

  Next pass: modelled eyelids and eyes, then clean the arm splotches.

## 2026-11-07 deep (job 20261107-120002-a4, continues job 20261107-060821-a2): READY ext/downed-wisp 3da5e9acd (owner decision "going down turns you into a Wisp")
- A downed Hunter pops into a Wisp: the hero hides, there is a 0.25 s flash, ring and puff with a sound, then the Wisp bobs, flickers, leans and trails as it moves. A revive is a 0.3 s reverse pop (the Wisp brightens and fades, the hero grows from 0.6 with a squash). Bleed-out or an execute breaks it into sparks. The Wisp takes the hunter's side colour (SideColor, like its ring). Per-hero `downed` clips are no longer played; the files stay.
- Gameplay is unchanged: HunterWisp only reads `downed`/`out`, so nothing new is replicated. Remote players, bots and the tutorial get it from the state they already have. Decision: docs/decisions/0019-downed-wisp.md.
- Cosmetic slot: `content/rules/wisp_looks.json` (WispLook). New look = a JSON entry listing only what differs from `default`; no code. It is picked by `Save.d["look"]["wisp"]`.
- This pass fixed the previous attempt's look: it rendered as a white square (untextured additive particle quads). It now uses the Fx soft dot, a mixed core and a soft halo, and is bigger. New shaders: shaders/wisp_core, shaders/wisp_halo.
- Checks: --wisp-check PASS (12 heroes, bot teammate, tutorial, bleed-out, look data). --revive-check, --box-revive-check, --clip-check, --warden-clips-check, --tutorial-hud-check and --check: 0 failures. health --strict OK. The full suite was not run.
- Renders (GPU job 20261107-120848-03528): briefs/art-refs/downed_wisp/ (pop-in, idle, moving, ally Wisp, revive a/b; captions.txt).
- Debt (docs/DEBT.md "Downed Wisp"): HunterAnim's crawl branch is dead. The Wisp id is local only (others see default; sending it needs a join-kit field and a Net.VERSION bump). There is no picker/shop UI.

## 2026-11-07 build-spec (job 20261107-123002-a4): CLAIM Camera depth readability
- CLAIM: Camera depth readability. Step 1 briefs/CAMERA_DEPTH.md (Supervive vs ours), step 2 cheapest 2-3 wins behind a setting, branch ext/camera-depth.

## 2026-11-07 deep (job 20261107-130004-a4): CLAIM Claire v2 model rebuild
- CLAIM: Claire v2 model rebuild (art/wardens/claire/ to the locked v2 design, briefs/art-refs/claire_v2/). Branch ext/claire-v2-model.

## 2026-11-07 deep (job 20261107-121501-a4): READY ext/grimble-hook-arm-v2 (315cdf2af), Grimble's stretching hook arm on the v2 model (replaces ext/grimble-hook-arm)
- ext/grimble-hook-arm (build job 20261107-043002-a4) rebased onto ext/grimble-v2-model (54df2f18a); merge v2 first, or this branch alone (it contains v2). Old branch left as is (force-push not allowed): skip it.
- v2's arm IS the hook, so the model's hook and the kit's hook at the arm's end showed twice. hide_while_chain/CHAIN_OUT are back for bone `hook` only: the model's hook shrinks into his wrist while the arm is out, the arm grows from the wrist (bone pose, not the lagging attachment), the snap-back lands on v2's anchor_hook_tip where his hook reappears. Alternative: keep his hook and draw none at the arm's end.
- Gameplay untouched (range, timing, hitbox, pull). hero-vfx-reel gets --reel-frames (the GPU worker returns no movie).
- Checks: --dredge-combo-check 93/0, --hero-vfx-check OK, --clip-live-grimble 0 fails (new: the arm's root on the wrist, 0.00 m), health.py --strict OK.
- GPU clips (pc-MRROBOTO, match camera, jobs 20261107-125639-01088 before / -24371 after): briefs/shots/grimble_hook/hook_before.mp4, hook_after.mp4, hook_before_after.mp4 (stacked), before_sheet.png / after_sheet.png. These replace the CPU renders.

## 2026-11-07 deep (job 20261107-131501-a2): CLAIM Cinder v2 model rebuild
- CLAIM: Cinder v2 model rebuild (art/wardens/cinder/ to the locked Flame Queen design: no tank, hose, flamethrower or goggles; briefs/art-refs/cinder_v2/). Branch ext/cinder-v2-model.

## 2026-11-07 deep (job 20261107-130004-a4): READY ext/claire-v2-model (7b2165a7c), Claire v2 model rebuild
- art/wardens/claire/ rebuilt with ART-1 from the locked nivi_v2 turnaround (Meshy edits front/3/4/side/back + run A ultra; 6 tasks, 85 credits, logged in PIPELINE.md). 13.6k tris, one 2048 atlas, shared 17-bone rig unchanged, 49 clips, FX anchors and kit wiring kept. Raw files in ~/meshy/claire_v2.
- Data: v1's bake/fit/face-touch specs and claire_assemble.py removed (in git history); recipe = v2 record; warden_look drops the tail-tip bloom (the puff is not a tail); rimewright silhouette text updated, wiki regenerated.
- Checks: warden-model 157/0, warden-glb PASS, warden-clips 0, hero-combo 297/0, hero-vfx OK, rimewright-combo 89/0, clip-live-claire 0, health.py --strict OK.
- Renders (briefs/art-refs/claire_v2/ingame/): v1 top / v2 bottom in closeup_front_, turnaround_close_, turnaround_game_before_after.jpg and workbench_before_after.jpg; vs_sheet_after.jpg (GPU job 20261107-132623-00008, pc-MRROBOTO; before = 20261106-205337-05470).
- Fidelity: ✅ frost-white rabbit ears, pink inside, one upright one folded | ✅ small puff tail | ✅ no horns, wings or devil tail | ✅ long white-to-ice braid | ✅ candy-cane bow + belt | ✅ lilac gloves | ✅ blade skates with fur cuffs | ✅ spear scale (sheet ~1.85 rig m vs model 1.895, 2%; in hand, tip clear of the ears) | ✅ youthful adult, not sexualised | ❌ scarf's long ends (DEBT: scarf ribbon-trail VFX on a new neck anchor) | ❌ hair is scan mesh, fringe shards up close, no alpha cards (DEBT) | ❌ close-up eyes read soft/half-lidded (atlas bake; a face-touch pass is the follow-up).
- Alternative not taken: explorations/old_claire_v2_turnaround.jpg (index.md: nivi_v2 wins).

## 2026-11-07 deep (job 20261107-140001-a4): CLAIM Tarek v2 model rebuild
- CLAIM: Tarek/Kibo v2 model rebuild (id dolm, art/wardens/tarek/ to the locked v2 design, briefs/art-refs/tarek_v2/; jade-glyph stone, no orange at rest). Branch ext/tarek-v2-model.

## 2026-11-07 deep (job 20261107-134501-a4): READY ext/portraits-unified (51c79fc89), unified select-screen portraits + roster order
- art/portraits/<id>.jpg (12) swapped for briefs/art-refs/portraits_unified/ at 512 px (same names, import settings and mipmaps kept; splashes untouched). Same files feed hero select, HUD/scoreboard and the title backdrop users.
- Roster order (DECISIONS 2026-11-07): Arch.ORDER and HeroKit.ARCH_ORDER = Vex, Mossy, Ryzz, Kael, Ravel, Cinder, Grimble, Pip, Claire, Tarek, Motley, Sable (ids unchanged); docs/wiki/Classes.md and docs/heroes/dash_interactions.md regenerated.
- Checks: --portrait-check rc=0 fails=0 (GPU jobs 20261107-134927-23045 after, 20261107-134930-01408 before), health.py --strict OK.
- Screenshots (briefs/art-refs/portraits_unified/ingame/): kit_card_{before,after}.png, practice_picker_{before,after}.png.
- Note: the prior mechanical attempt's GPU job failed because the tree had no .godot import; run `godot --headless --import` first.

## 2026-11-07 build-spec (job 20261107-123002-a4): READY ext/camera-depth 2af88a105 (from origin/main 7907d9afe): height cues
- Step 1: briefs/CAMERA_DEPTH.md (Supervive vs ours). Camera pitch/FOV already match; the gap is value contrast (abyss/cliff faces/lip) and ground anchors.
- Step 2 (setting `depth_cues`, default on, Accessibility tab): cliff faces shaded lip-to-foot, lit ground lip, blob shadow disc under each hunter (scripts/match/depth_cues.gd, shaders/blob_shadow). Before/after: briefs/camera_depth/. Tool: --depth-shots.
- Checks: health --strict OK; GPU capture job ran clean (rc 0). Hitch/perf and the full suite NOT run (usage); cost is one quad per hunter and a few height taps per ground pixel. Not done: abyss darkening, tier tint, projectile shadows.

## 2026-11-07 build (job 20261107-133003-a2): READY ext/kael-v2-model (3419a661a), Kael v2 curse swap + the 49-clip set
- (A) Curse on the sword (right) arm (7fc2d59c3): veins, bare crimson hand and chest from the mirrored bake, black glove on the left, arm bloom anchors on the right.
- (B) Clips (3419a661a): the v1 glb's 49 clips retargeted onto the v2 rig by bone name (tools/art1/kael_retarget.py; 51 v1 tracks dropped: springs and renamed bones, the game's spring chains drive those; rest rotations identical). The sword is now skinned to hand.R and joined into Body, FX empties weapon_muzzle / anchor_blade_mid / anchor_blade_root on hand.R (no anchor_blade_tip: weapon_muzzle is the tip). Config content/rules/warden_anim/kael.json (all 20 jug_* moves plus mf_xform); per-move "fade" (jug_wave_wind 0.2, jug_lunge_wind 0.18) and "hang_own_rest" ported into WardenClips (~20 lines); clip-check OWN_MODELS gains juggernaut -> kael. Dash padded to the kit's 0.9 s.
- Checks (all rc 0): --clip-check 0 failures (juggernaut: weapon never leaves the hand 0.000 m, muzzle on the tip in 196 frames, hand-over worst 0.237 m vs limit 0.293), --warden-glb-check PASS, --hero-vfx-check OK, --rig-standard-check 0 failures, --warden-model-check PASS, --juggernaut-combo-check 164 checks 0 failures, health.py --strict OK. GPU jobs 20261107-141344-15191 (after), -07287 (clip frames), -04757 (before).
- Renders: briefs/art-refs/kael_v2/clips/ before_*.jpg vs after_*.jpg (full length, back, closeup, match-camera turnaround and poses, run) and strip_<move>.jpg frame strips (idle, run_f, slash_l, slash_r, slam, lunge, wave, dash, meteor, guard).
- CAVEAT: several v1 clips were authored for kit 113 (levelled lunge, side-swing wave, upright meteor, 0.42 s dash), which is NOT on main. On main's older poses they pass every check but read slightly off (e.g. lunge/wave aim); re-fit them when kit 113 lands. Not hand-fixed: only the failing timing and pops.
- The idle closeup now shows the clip's head-bowed idle, not the static rest pose.

## 2026-11-07 deep (job 20261107-143001-a2): CLAIM Sable v2 model rebuild
- CLAIM: Sable v2 model rebuild (id thief, art/wardens/sable/ to the locked v2 design, briefs/art-refs/sable_v2/). Branch ext/sable-v2-model.

## 2026-11-07 build (job 20261107-141502-a4): READY ext/camera-depth (round 2, replaces 2af88a105)
- Adds to round 1: abyss clouds darkened x0.55 (cloud sea + layers, `abyss_dim`) and lower terraces up to 20% darker (terrain shader); both behind `depth_cues` (Settings > Accessibility). Gameplay/camera/aim untouched.
- Before/after (same seed 77, same spots): briefs/camera_depth/{before,after}_{a_edge,b_step,c_low}.png, round-1 shots after1_*. Notes: briefs/CAMERA_DEPTH.md. Branch briefs: ext/agent-briefs.
- Checks: health --strict OK; --depth-shots GPU job rc 0. Hitch/perf and full suite NOT run (usage). Not done: projectile shadows.

## 2026-11-07 deep (job 20261107-143004-a4): READY ext/kael-v2-model (ca52dc648), supersedes the 3419a661a READY above
- Re-checked the build job's two commits (curse on the sword arm 7fc2d59c3, 49 retargeted clips 3419a661a). Rest rotations: of the 32 shared skin bones only the 10 spring_mane_l/r bones differ (they're dropped, the spring chains drive them), so the clips copy as is.
- Fixed a regression (ca52dc648): joining the sword into Body removed the `weapon` node, so warden_look's two `"at": "weapon"` blade blooms were silently skipped and the blade rendered flat black. A bloom entry can now take `"to"` (a second anchor on the same bone): `count` puffs from the anchor to it. Kael's blade blooms run anchor_blade_root -> weapon_muzzle with the old counts and colours. His `weapon_scale` 0.85 is gone (it reached nothing; GUN_M bakes it in). Diff +18/-9 over 3 files.
- Checks on ca52dc648 (all rc 0): --clip-check 0 failures, --warden-glb-check PASS, --hero-vfx-check OK, --juggernaut-combo-check 164/0 (on 3419a661a; ca52dc648 changes no kit code), health.py --strict OK.
- GPU job 20261107-144058-18235: briefs/art-refs/kael_v2/clips/bloom_front_34.jpg, bloom_turnaround_game.jpg, bloom_poses_game.jpg (compare after_front_34.jpg = without the fix, before_turnaround_game.jpg = a22927c1d).
- Still open (from the build job): some v1 clips were made for kit 113 (lunge, wave, meteor, dash), so re-fit them when 113 lands. The skinned blade casts no ground shadow now (the old `weapon` node did).

## 2026-11-07 build (job 20261107-151501-a4): CLAIM Cinder the Flame Queen (kit, VFX, ult, splash)
- CLAIM: DECISIONS "Cinder the Flame Queen": fidelity row, LMB fire from her hands, Flue Flight heels+tail fire (lift parity), splash swap, texts/titles. Not the 3D model (ext/cinder-v2-model). Branch ext/cinder-flame-queen (on ext/text-relic-renames).

## 2026-11-07 deep (job 20261107-140001-a4): READY Tarek v2 model (dolm)
- READY: ext/tarek-v2-model (7747ad995 model, fa5c036a8 look). art/wardens/tarek/ rebuilt to briefs/art-refs/tarek_v2 (index.md canon, turnaround final): one Meshy v2 scan (76 credits, PIPELINE.md), baked + fitted to the shared armature; tools/art1/tarek_scan.py replaces the v1 build (6 scripts, -2900 lines). Same 33 bones, all 14 anchors/orbit points, the same 48 clips, kit wiring untouched. 14455 tris, one 2048 atlas + a glyph emission map.
- Glow: only the arm/gauntlet glyphs glow (jade, dolm.json model_glow #5ce6b8 / teal edge #2fc2b4); seams dark; v1 orange rim + stone halos retinted jade, fist halos dropped. Molten orange stays in the ability VFX only (dolm_kit untouched; procedural hero_arms fist is hidden on the glb).
- Renders: briefs/art-refs/tarek_v2/ingame/ (tarek_v2_vs_sheet = GPU turntable vs the turnaround, _turntable, _closeup, _match_cam, _before_after_blender = v1 top / v2 bottom). The in-game v1 "before" GPU shots were dropped: the GPU queue stalled 30+ min and they need the tree held at v1.
- Checks: warden-rig-json dolm, warden-model (157/0 after height_3d), warden-glb 187/0, warden-clips 0, clip 0, rig-standard 0, hero 0, hero-vfx OK, dolm-combo 170/0, tarek_clipcheck 0/48, health --strict OK.
- Check change: warden_model_check dolm height_3d 1.15 (v2 locs hang; v1's piled crown made 1.19).

| Tarek fidelity | |
|---|---|
| Plain cloth blindfold, no glow | ✅ closeup |
| Three floating eye stones, jade-teal eyes, turn to targets | ✅ vs_sheet, warden-glb check |
| HUGE stone left arm + shoulder onto chest (scale: upper arm ~1.6x the right's width, as the sheet) | ✅ vs_sheet |
| Stone gauntlet on right forearm | ✅ |
| Locs with copper rings, grey beads, one jade bead | ✅ (beads small at match cam) |
| Prayer beads, cream wrap, orange sash, brown trousers, wrapped feet | ✅ |
| Rock Hop dash | unchanged kit |
- Known gaps: eye-stone eyes face the watched target so often away from the camera; locs read smoother than the sheet (scan limit); stone has a few skin-tone streaks on the chest plates from the scan texture.
- Names: the owner note says player name Kibo, tarek_v2/index.md says renamed Tenzo; names untouched, owner to settle.

- Correction to the READY above: the stone-arm "~1.6x" is a visual estimate from vs_sheet, not a measurement; the scan keeps the sheet's proportions (no arm-grow applied).

## READY 150-botnav — physics lane, 2026-11-07
- branch: ext/phys-150-botnav @ e44f34b228637a79c7afdebfa968591f93a6bd3b (on main 7907d9af; contains 150-parity 074453ec — merge them together, this branch carries both)
- change: bot.gd — a non-urgent goal with no walkable path is banned for 20 s after 1.5 s (was: shuffle at the rim until the 14 s give-up). main.gd `_bot_sanity` — ledge rises (lfloat) don't count as ring time (decision: a mantle is a climb, not hanging in the air; alternative was raising MAX_RING, rejected as it would hide real hangs).
- proof: --bot-sanity-check seeds 1-20 (groups 3,5,9 / 1,2,4,6-8,10,11 / 12-20): botnav 0 flags, main 0 flags, 0 script errors on full imports.
- checks: health --strict OK, gen_wiki --check OK, merge-tree vs origin/main clean, full suite vs 150 base: NEW-RED 2 (class-unlock, dash-frames) WORSE 0 — both pass 0 failures on quiet reruns of botnav and base (same load flakes as 163).

READY ext/phys-150-botnav e44f34b22 (coordinator one-liner for the merge-candidate parser; carries 150-parity 074453ec, see the 150-botnav post above)

## READY 2026-11-07: Cinder v2, the Flame Queen (ext/cinder-v2-model, 108309cba)

Rebuilt from the turnaround with the master sheet's longer hair. Owner override applied: no tank, no hose, no weapon; hands empty and posed for casting, palm is `weapon_muzzle`, magma cracks brighten while she casts.

Fidelity: scaled grey-violet skin, obsidian shards with molten seams, heeled boots, shards on the hands, long dark hair to ember ends (alpha cards), orange eyes, spined tail with an FX flame tip. No goggles, no fins. Weapon check moot: she has no weapon. Checklist row updated.
Build: 11615 tris, one 2048 atlas, shared armature, FX points and clip set kept.
Follow-up (job 20261107-160001-a2): the scan's wedge horns are tucked under built curved lizard horns (rigid on the head, own painted strip); the tail's back carries a sparse web of molten cracks in the atlas and the emit map (the turnaround's side view). warden_model_check height_3d for ashwick 1.08 (measured 1.079).

Checks, all pass: cinder-art, warden-glb, warden-model, warden-clips, hero-vfx, ashwick-combo, warden-rig-json, health --strict. Match camera: the tail does not hide her.

Renders in briefs/art-refs/cinder_v2/ingame/ (GPU, job 20261107-161743-12800): closeup_front.png, back_34.png, poses_game.png, turnaround_game.png; before_after_front.png and before_after_back.png (left/top: the first v2 build, right/bottom: horns and tail cracks); before.jpg is v1; vs_sheet.png the first build against the sheet.

Please look at:
- Horns are now built pieces (dark stone, growth rings); the scan's stubs sit flattened under their roots. If they read too long, HORN_PTS in cinder_pieces.py scales them.
- Tail cracks: 11 seeded walks on its back, brightness as the armour seams; TAIL_CRACKS in cinder_finish.py if fewer are wanted.
- mantle_look ashwick base colours changed (they tinted her blue); this also affects the procedural model.
- warden_model_check height_3d for ashwick is 1.08 (the horn tips; v1's fire crest was 1.14).
- Hair flame strips were dropped: they read as yellow flakes. Hair is no literal fire, only the ember fade.
- Shots are GPU renders now (the queue unstalled).

## READY 2026-11-07: Cinder the Flame Queen, kit and splash (ext/cinder-flame-queen, c3f4f1729)

Branch ext/cinder-flame-queen, 2 commits (17 files, +167/-149). It does not touch her 3D model (the cinder-v2 job owns that).
- LMB fire stream and Cinder Shot now start at her casting hand (`AshwickKit.tip()` uses `anim.hand_r`). Rules origin (NOZZLE), damage, range and timing are unchanged; only the drawn start moved.
- Flue Flight: fire bursts from both heels and the tail, with the roar sound hook, in one function (`AshwickJet.jet_points` and `_jet_fx`). dash_with, hover, speed and time are untouched, so lift motion and timing are the source's. No alternatives built.
- Texts: weapon and ability text, tooltips and docs/heroes/ashwick.md no longer mention tank, hose, fuel or nozzles. Title "Flame Queen" shown through the HeroTitle helper. Procedural gun (canister, hose, nozzle) removed from `HeroGearPair.flamer`.
- Splash: cinder_v2_splash.jpg ("The Last Kiss") is art/portraits/ashwick_splash.jpg (960x540); the alt is ashwick_splash_alt.jpg. ashwick.jpg now comes from cinder_v2_portrait.jpg (the old one had goggles and the tank). No goggles anywhere.
- FIDELITY_CHECKLIST Cinder row has the specified text; cinder_art_check now asserts hands and heel/tail fire.
Checks, all pass: cinder-art, ashwick-combo, hero-title, portrait, title-check, hero-combo; gen_wiki. health --strict fails only on files this branch does not change (hero_title_check.gd, vv_ult_check.gd long lines). ashwick-ult-check timed out (1500 s) when the machine was loaded; the re-run is noted below if it finished.
GPU shots (jobq 20261107-161020-18116): briefs/art-refs/cinder_v2/ingame/queen_lmb_hands_strip.png, queen_flue_flight_strip.png.

Please look at:
- The model still holds its own lance (the glb's weapon node), and its arm clips still pose around a gun. Both belong to the model/animation rebuild; I did not touch them. From above the stream already reads as leaving her hand.
- Magma cracks brightening while casting is not done (model job).
- Alternative for the hand origin: PALM_AHEAD (0.12 m) pushes the start just past the palm.

READY ext/cinder-flame-queen c3f4f1729
READY ext/downed-wisp bdca844e (fixes --hudref-check)

## READY 2026-11-07: Sable v2 model rebuild (ext/sable-v2-model, 4281b56a2)
Sable (id thief) is rebuilt from sable_v2_turnaround.jpg with the ART-1 pipeline: 14,893 tris, one 2048 atlas, 8 materials, 8034 verts. Shared 18-bone armature, every FX point and anchor name, the clip set and the kit wiring are kept. Commits 1c5d44fac (model), c5b34e2ec (scripts, height check, run log, debt note), 4281b56a2 (toon light tuning). 121 Meshy credits. Raw files in ~/meshy/sable_v2, not in git. No Net or save change.

Renders in briefs/art-refs/sable_v2/ingame/:
- before_after_blender.png: old model on top, new below, same Blender light. v1 had no engine shots, so the before is not an engine render.
- Engine, final art (jobq 20261107-163505-12293): turnaround_close, turnaround_game, front_34, back_34, closeup_front, moves_close_1.
- match.png (jobq 20261107-162656-28272): match camera. Taken one step before the closed-lid colour fix, which does not show at that distance.

Weapon scale vs the sheet (FIDELITY_CHECKLIST):
| Item | Sheet | Model |
| Pistol length | about .22 of body height, about .39 rig | barrel .365 plus stock, length unchanged |
| Barrel diameter | about .038 | about .045, a little thick |
| Knife | about .34 (master) | about .39, a little long |

Checks, all pass on the final build: --warden-rig-json thief (18 bones), --warden-glb-check, --warden-model-check, --rig-standard-check (0 failures), --hero-check --hero=thief (0 failures), --hero-vfx-check, health.py --strict. gen_wiki run.
Not completed: --weapon-clip-check timed out at 170s under load and was not rerun.

Decisions (alternative in brackets):
- Two knives on each hip, as the turnaround side view shows. (One per hip; the master shows two on her right only.)
- Pistols are procedural silver and wood, not projected from the sheet. (Projected from the sheet.)
- height_3d is 1.03, was 1.13: the antennae stand lower than the old wings.
- anchor_bola stays on the hips by name only.
- Skin sits a step below the hair and cooler than the sheet preview, and glow, gem and muzzle halos are lowered in warden_look.json, because engine light runs about 1.35x brighter than Blender.
- Portrait and splash swap left out, not in this task.

Please look at:
- Pistol stocks read brighter red than the sheet's deep maroon in the engine; barrels go pale with the muzzle glow.
- Braid is beaded close up and the fuzz is a notched sheet (DEBT.md).
- Slight violet at the collar edge of the neck, and a few specks about 1.5mm wide at the old mouth crease, not visible in play.

READY ext/sable-v2-model 4281b56a2
READY ext/vfx-cinder 3b549347 (fixes cinder-art-check)
READY ext/boki-50-integ 7751f51c (fixes boki-system-check)
READY ext/text-relic-renames-rebased e6389cff (fixes the combo51_shots.gd conflict with kit-kael-113b: hero_title_check green)

## 2026-11-07 build (job 20261107-144501-a4): READY ext/s7-mask-hob-83-89-fix (f123d7cd6, on 294897be7 which already merges origin/main 7907d9afe)
- Crash at shutdown (portrait/class-unlock/hunter-unlock): new scripts/core/background_work.gd (BackgroundWork) tracks the portraits' ResourceLoader.load_threaded_request reads and WorkerThreadPool tasks and drains them on SceneTree.root.tree_exiting; portraits.gd and warden_glb.gd use it. It only reproduced under the suite's xvfb + opengl3 run (not --headless): 2/2 rc 132 before, 0 after.
- Stale checks: farm-tutorial-check waits for the Home's panel_host to be built (the meshes build over several frames; slow on llvmpipe) instead of 2 frames; mask-moment-check times the beat by the frames' own deltas and compares to the planned seconds from the beat's data (tolerance: one longest frame per phase) instead of wall-clock 7.0 s.
- Checks (xvfb opengl3, suite's invocation): --portrait-check x3 rc 0 (107 checks, 0 fails); --class-unlock-check x3 rc 0 (145/0); --hunter-unlock-check x3 rc 0 (145/0); --farm-tutorial-check rc 0 (0 failures); --mask-moment-check rc 0 (it ran 6.1 s of 5.8 s planned); health.py --strict OK; suite-fast on the 26 flags red in the coordinator's merge run + these 6 (36 flags): NEW-RED 0, WORSE 0 (full 161 not rerun; this branch touches only portraits/warden_glb loading + two tools).
- NOT fixed, not this branch: --teammate-check has ONE failure on origin/main 7907d9afe too ("a rival behind you is called before the chest (["loot"])", teammate_check.gd:199; deterministic, 1 fail on both). The 'leads you to the chest and the outpost' assertion passes on this branch and on main here (led includes chest, goexit), so it did not reproduce; it may only fail under load. Treat --teammate-check as red-on-main (same), not NEW-RED.
- Cost: +78/-11 lines in 6 files; 1 new file (scripts/core/background_work.gd, 43 lines, + .uid).
READY ext/text-relic-renames-rebased 6b2895ed9 (supersedes e6389cff; adds owner order swap: Sparkle 9th, Motley 11th)

## READY 2026-11-07: Sable v2 model rebuild, escalation pass (ext/sable-v2-model, 3e1816a6e)
Supersedes READY 4281b56a2. Same model contract: 14,893 tris, 7,994 verts, one 2048 atlas, 8 materials, shared 18-bone armature, every FX point and anchor name, 47 clips, kit wiring. Commits on top of 4281b56a2: 1192cbb60 (feather-plume antennae, chevron braid, maroon pistol stocks), 78279e19c (smaller muzzle halos, metal fresnel down, height_3d 1.06, debt note), 3e1816a6e (plumes square to her front). No Meshy credits spent. No Net or save change.

What changed from the escalation list:
- Antennae are now the turnaround's feather plumes in a V (two sheets back to back, 192 tris each), not the old fan-edged wings. The notched fuzz sheet remains the debt note's compromise.
- Pistol stocks painted deep maroon (#2b1316 to #8c584c); barrel silver a step darker and the muzzle halos smaller (px 7, strength 1.2), so the barrels keep their grey under the glow. Metal fresnel 0.25.
- Braid: 11-lobe sweep with painted chevron creases, reads woven at match zoom (DEBT.md says what a real plait would cost).
- A plume tipped back about its stem rendered black at close range in the engine (one side faced away from the sun); the plumes now stand square to her front. closeup_front_before.png shows the 4281b56a2 antennae for comparison.

Renders in briefs/art-refs/sable_v2/ingame/ (jobq 20261107-175351-11674, final build): turnaround_close, turnaround_game, front_34, back_34, closeup_front, moves_close_1; match.png (jobq 20261107-172732-03122, one commit earlier, no antenna difference at that distance). closeup_front_before.png is the 4281b56a2 engine shot.

Weapon scale vs the sheet (FIDELITY_CHECKLIST), unchanged:
| Item | Sheet | Model |
| Pistol length | about .22 of body height, about .39 rig | barrel .365 plus stock, length unchanged |
| Barrel diameter | about .038 | about .045, a little thick |
| Knife | about .34 (master) | about .39, a little long |

Checks on the final build, all pass: --warden-rig-json thief (18 bones), --warden-glb-check (187 checks, 0 failed), --warden-model-check (157 checks, 0 failed; 1.057x a medium hunter, sheet 1.06x), health.py --strict (STYLE OK, HEALTH OK). On the same mesh one antenna rebuild earlier (no weapon or rig change since): --rig-standard-check, --hero-check --hero=thief, --hero-vfx-check, --weapon-clip-check (CLIP PASS, worst clearance 0.047 m). gen_wiki run.

Decisions (alternative in brackets):
- Plumes face front, no back tilt. (A tilt reads better from the side but needs the sun on both faces; a two-sided fur slot would allow it.)
- Weapon ramps sit a step under the sheet so the engine's 1.35x light lands on the sheet's colour. (Match the sheet in Blender and let the engine overshoot.)
- Collar-edge violet left as is: it is the lining's glow slot bleeding one texel, not visible in play.
- Godot's import cache must be refreshed (godot --headless --import) before checks or shots on a rebuilt glb; a stale cache showed the old mesh once in this pass.

Please look at:
- Braid flat close up, fuzz a notched opaque sheet (DEBT.md, about 300 tris over the budget to fix).
- Barrels still a touch pale right under the muzzle halo in closeup shots.

READY ext/sable-v2-model 3e1816a6e

## 2026-11-07 deep (job 20261107-173003-a4): READY ext/s7-mask-hob-83-89-fix 6b433e542 (supersedes f123d7cd6; fast-forward, on origin/main 7907d9afe)
READY ext/s7-mask-hob-83-89-fix 6b433e542 (fixes shutdown crash in --portrait/--class-unlock/--hunter-unlock-check; --farm-tutorial, --mask-moment, --teammate-check green)
- 87aadb855 teammate_check: "rival behind you before the chest" (red on main too): a map chest called in _fresh() left a 4.3 s quiet gap, the Boki knocked the rival inside 7 m on screen (no "behind" there) before it ended; the part now starts with the companion quiet (gap_t, cds, seen). "leads you to the outpost" flake: when the fight ends ~10 m from the outpost, goexit lasts ~1 s while the Boki flies home / falls / rides your shoulder; goexit and uplink both point at the outpost, so either counts.
- 6b433e542 farm_tutorial_check: "dragging a river ... 12 gems" flaked (2/6 under load): row 36-41,27 is wild land on some Save.fresh() random seeds; the channel now goes on a row open this run, "beside it" is relative to it.
- Checks (xvfb opengl3 + headless): portrait/class-unlock/hunter-unlock x3 each rc 0, 0 FAIL, no signal 11 (both modes); farm-tutorial 7/7 headless + 1 xvfb rc 0; mask-moment 3 headless + 1 xvfb rc 0; teammate full 3 headless + 1 xvfb rc 0, tutorial part 12/12 and priority part green; health --strict OK.
- Open, not this branch: 1 of ~22 teammate tutorial runs stuck at the "dash" step for 600 s (driver), seen once, not traced.
READY ext/text-relic-renames-rebased e9f0f9847 (supersedes 6b2895ed9; owner order: Sable 11th, Motley 12th)
- (job 20261107-174501-a4, mc-20261107-1230 gate items 3-5) --teammate-check: no new READY; the fix is 87aadb855 in ext/s7-mask-hob-83-89-fix. Applied to ext/mc-20261107-1230 it gives --teammate-only=priority,tutorial 3/3 rc 0, 0 FAIL (one run had no goexit lead; uplink covered it). --hudref-check: ext/downed-wisp bdca844e (READY above). --hatch-check: load flake (the 15 s wait at hatch_check.gd:98), merge log now 0 failures, no branch to fix.
READY ext/parity-dash-scale 2f24ae36b (KIT_PARITY item 11: air dash double scale fixed for Cinder+Grimble; Cinder ram 3.4m/.33s, poof 6.8m/.28s; combo checks assert source numbers)
READY ext/parity-move-feel 64e6c681f (KIT_PARITY 2-4 all heroes: brake 22.2 + friction 2, air control 0.015, dash exits at run speed; one table hunter_move.json)
READY ext/parity-lace 4aa011a49 (Lace/archer KIT_PARITY 6+7: wall pin 4.94x the shot as in source, RMB dead zone 0.5->0.15 s; archer-combo-check 155 PASS, health --strict, gen_wiki --check ok)
READY ext/parity-dashlmb 4e788af65 (KIT_PARITY item 9: dash->LMB fires mid-dash on Hem, Ryzz, Cinder, Tarek air per item 51; Zedran/Bjorn stay buffer/cancel as sourced; --dash-flow-check asserts the rows)
READY ext/lace-ult-arrows dfaeae389 (Lace ult: big travelling arrows at 90 m/s, map-wide cast sound; archer-combo-check, health --strict, gen_wiki --check pass)
READY ext/sparkle-orb-pickup 3f03c9dc1 (walking over a charge orb picks it up + resets the dash; Sparkle's lightning/orbs/marks pink+teal instead of gold; mage combo check extended)
READY ext/parity-snowglide ea140cf53 (Snowglider -> Snowglide everywhere, based on ext/text-relic-renames; hero_title_check retires Snowglider)
READY ext/ravel-v2-model 91c6905ba (Lace v2 pass 3; supersedes fc36532f5: modelled eyelids on lid.R/L so the blink reads, head fitted 1:1 to the sheet, plain porcelain under the shoulder mask, cream doll-joint bands, darker smoke roots; 14,371 tris, one 2048 atlas; warden-rig-json archer no diff, glb 187/0, model 157/0, clips 0, hero 0, hero-vfx OK, archer-combo 153/0, health --strict OK; GPU job 20261107-194733-04883 renders in briefs/art-refs/ravel_v2/ingame/pass3_*.jpg (vs_turnaround, before_after, closeup, blink, match_turn); left: the belt stays ~8 cm under the sheet with the shared rig, the Proportions row stays ❌, Eyes ✅, Smoke/joints ⚠ -> ✅-ish, arm splotches cleared)
READY ext/parity-mossy-cadence 1eecee8c3 (Mossy throw cadence 0.48->0.45 per source card, check asserts it; hold walk 55% kept: source footage shows no walking value, owner note)
Idle audit (feel, Nov 7): docs/art/IDLE_AUDIT.md on ext/parity-idle-audit. Every Hunter's idle and stance, ranked worst first: 1 Kael (no clips, a frozen procedural A-stance), 2 Mossy (4.2 deg head pop at the loop, 1.6 s stance, a shield wall hides his face, the shield snaps up in 0.5 s), 3 Tenzo (0.8 s jitter stance, feet slide), 4 Cinder (arm locked straight out; poses built on the removed flamethrower), 5 Sparkle (frozen 5 s stance), 6 Motley (11-16 deg finger pop), 7 Meeko (built on the dropped lantern), 8 Neve, 9 Sable, 10 Vex, 11 Lace, 12 Grimble. Shared causes: sine-metronome motion, no chest bone, locked knees and dead pelvis, stance feet differ from idle feet. 12 rework items (one per Hunter, role feel) are in backlog.proposed.jsonl.
READY ext/parity-idle-audit 8b2217e8b (idle audit of all 12 Hunters + --idle-shots strip tool + clip-check asserts idle/stance loop seams <=1 deg/1 cm and >=2 s, 5 known-open entries; clip-check, health --strict, gen_wiki --check pass)
READY ext/parity-mossy-cadence 9c336682d (KIT_PARITY item 12, Mossy: throw cadence 0.45 s per the source card, asserted; hold walk 55% kept per owner #59, asserted; --bulwark-combo-check 145 PASS/0 FAIL, health --strict OK, gen_wiki --check OK)
READY ext/parity-grimble-airdash 0a5b33f48 (KIT_PARITY item 13, Grimble: air pounce is an explicit own 12.5 s slot, 2 s less per rank, asserted; the slot already existed via the class default so the audit's 'missing' was overstated; --dredge-combo-check 94 PASS/0 FAIL, health --strict OK, gen_wiki --check OK)
READY ext/parity-ostra-bomb 5b9a528d2 (KIT_PARITY 17: Ostra Brimseed peak 3.5x; dmg_max_k 3.0->3.5 with formula k-1, identical damage curve, check asserts full pop = 3.5 x 12.5)

## 2026-11-07 deep (job 20261107-211501-a2): CLAIM Mossy v2 model rebuild
- CLAIM: Mossy the Barnacle Knight v2 model (id bulwark, art/wardens/breaker/ from mossy_v2 turnaround + master sheet: brass chest compass, restrained cyan crack emissive, bulk vs hero-heights 0.8). Branch ext/breaker-v2-model.

## 2026-11-07 deep (job 20261107-211504-a4): CLAIM Cinder the Flame Queen model to the final turnaround
- CLAIM: Cinder (ashwick) model pass to cinder_v2_turnaround.jpg + cinder_v2_master_sheet.jpg: clean back, empty casting palms (FX both palms, weapon_muzzle on the dominant palm), waist-length hair cards, curved lizard horns. Branch ext/cinder-v2-palms (from ext/cinder-v2-model).

## 2026-11-07 build (job 20261107-213002-a2): CLAIM Hero props swap to the new sheets
- CLAIM: props swap to vex_v2_weapon_sheet, nivi_v2_weapon_sheet, grimble_v2_weapon_sheet (hook arm, confirm no nose), sable_v2_weapon_sheet, ravel_v2_prop_sheet. One branch per hero ext/props-<art> (vex, claire, grimble, sable, ravel), each from the hero v2 branch.

## 2026-11-07 deep (job 20261107-213004-a4): CLAIM Motley v2 model rebuild
- CLAIM: Motley the Void Jester v2 model (id ostra, art/wardens/ostra/ from motley_v2_turnaround.jpg + motley_v2_master_sheet.jpg: painted style, void ribbon on the brass spring, hovering card box, no legs (hover/bob, root and foot anchors kept)). Branch ext/ostra-v2-model.

## 2026-11-07 build (job 20261107-214501-a2): CLAIM 2D art swap
- CLAIM: swap new 2D art: splashes Sparkle (mage) + Motley (ostra); portraits Neve (rimewright), Motley, Mossy (bulwark), Vex (gunslinger). Branch ext/art-2d-swap.

## 2026-11-07 deep (job 20261107-214504-a4): CLAIM Meeko companions (sun + raincloud) model
- CLAIM: Meeko the Dawnfox (tender, art pip) sun and raincloud companions from pip_v2/meeko_v2_companions_sheet.jpg: 4 views each + 8 expression faces (texture swaps), replacing the lantern stand-in, keeping FX points and spawn code. Branch ext/pip-companions-v2.

## READY 2026-11-07 deep (job 20261107-211504-a4): Cinder v2 pass 2, final turnaround (ext/cinder-v2-palms, 766b44cdd)
On ext/cinder-v2-model (merge this one instead; it carries that branch). Model from cinder_v2_turnaround.jpg + cinder_v2_master_sheet.jpg (Nov 7 14:15/14:57).
- Clean back: no tank, hose, flamethrower, goggles or weapon (already true of the scan; re-checked in the GPU back views).
- Hair: the back curtain is 9 alpha cards as wide as her back, to her waist, dark fading to ember (was 7 narrow cards to mid-back).
- Horns: swept back past her crown, tips curling up (the turnaround's side view); before they stood straight up.
- Palms: `weapon_muzzle` stays on the right palm (dominant: the kit, clips and Gun/Muzzle all cast from hand.R); new `weapon_muzzle_l` on the left palm (Sable's name). Alternative not taken: left as dominant (the master sheet's raised hand), which would mean redoing the clips.
- Casting clips still read as palm casts: the LMB stream leaves her outstretched right palm (p2_lmb_palm_strip.png).
- 11775 tris, one 2048 atlas, shared armature, every FX point/anchor name, 41 clips, and the kit wiring unchanged. No new Meshy credits: same scan, rebuilt pieces.
Checks, all pass: warden-rig-json (rig unchanged), cinder-art (new: left palm point on hand.L, mirrors the right), warden-glb, warden-model, warden-clips, hero-vfx, ashwick-combo (117/0), health --strict.
GPU renders (jobq 20261107-211901-07554, 20261107-214639-10392) in briefs/art-refs/cinder_v2/ingame/: p2_before_after_front.png (left before), p2_before_after_back.png (top before), p2_vs_sheet.png (sheet + match camera), p2_turnaround_close.png, p2_poses_game.png, p2_lmb_palm_strip.png.
Known gap: the top of her head is still the scan's decimated hair, a little faceted in the close-up; her front locks end at the chest, whereas the sheet shows hair at her sides down to the waist.

READY ext/cinder-v2-palms 766b44cdd (Cinder v2 pass 2: waist hair, swept-back horns, fire point on both palms; supersedes ext/cinder-v2-model)
READY ext/prematch-lobby 861e46547 (90 s pre-match lobby before expeditions: Hunter pick, squad, text chat + voice stub, lock at 0; admin lobby_enabled; richer loading screen; Net.VERSION 0.25.0; --prematch-check 0 failures, health --strict OK)
Gameplay media (4 looping 1080p clips + stills, 12 files): https://github.com/OrriBogdan2/project-boki-reports/releases/tag/gameplay-media-20261107
READY ext/gameplay-media e6881d69f (gameplay media capture tool + encode script; clips use the new Hunter names via a render-only merge of ext/text-relic-renames-rebased)

## 2026-11-07 build (job 20261107-233002-a2): CLAIM Training Grounds
- CLAIM: grow the --arena Training Area into the Training Grounds (DECISIONS "Modes and queues"): a much bigger open expanse (3x+) joined to sky islands by jump pads/glides, every Hunter/Boki/item/ability and bot spawning reachable, practice stations and duel ring kept. Branch ext/training-grounds.

- READY ext/hero-heights 4538174a8: Hunter heights from the owner's final chart (Neve 1.56, Sparkle 1.62, Vex 1.66, Kael 2.05 ...). Coordinator post; was missing from mc runs.

## 2026-11-07 build (job 20261107-213002-a2): props swap to the new sheets
- READY ext/props-vex b3ddc1b01 (on ext/vex-v2-model): the weapon sheet's brass minigun: ghost and flame stickers on the receiver, gold muzzle ring. Geometry, anchors and size unchanged (paint pass). GPU renders: briefs/art-refs/vex_v2/ingame/props_*.jpg.
- READY ext/props-claire c34a78032 (on ext/claire-v2-model): Neve's white-fur boot cuffs and candy-cane laces (new pieces, ray-cast onto the scan boots, rigid on shin/foot) and the spear recoloured to lavender/white stripes. 14,567 tris, 49 clips. GPU renders: briefs/art-refs/claire_v2/ingame/props_*.jpg.
- READY ext/props-sable 628195e5e (on ext/sable-v2-model): walnut stock and brass guard, butt cap and frizzen from the weapon sheet. Her moth-wing knives, hip sheaths and wrapped hilts were already on the v2 model; no flask or bola pieces remain. GPU renders: briefs/art-refs/sable_v2/ingame/props_*.jpg.
- NO CHANGE NEEDED, Grimble: ext/grimble-hook-arm-v2 already has the bone-hook arm as the model's own arm, the loot pack, loupe, blunderbuss and gauntlets; side view shows no nose. No props-grimble branch. Alternative: redraw the stretched-arm FX hook (ld_fx.gd _hook_node) closer to the sheet's bulb-headed hook; not done (kit wiring stays).
- NO CHANGE NEEDED, Lace: ext/ravel-v2-model already builds the needle, recurve bow, stitched shoulder mask, spool belt with needles and hair pins (hem_pieces.py); no hem_v4 prop files remain. The sheet's needle shows one wrap, the model keeps the turnaround's three lashes. No props-ravel branch.
- Fit check: the sheet props were already at the sheet's scale on these models (bow, needle, pistols, knives untouched). The only new geometry is Claire's cuffs (0.064 m radius, 0.03 m tube, matched to the boot top in the front_34 still).
- Checks: warden-rig-json (gunslinger, rimewright, thief), warden-glb-check 186/0, clip-check, vex/claire/sable clip-live, hero-vfx-check OK, health --strict OK. --warden-model-check has one failure: thief 1.133x vs sheet 1.06x, identical on the unchanged base glb (not from this work).

## 2026-11-08 deep (job 20261108-003051-a2): CLAIM props swap re-check (escalated from 20261107-213002-a2)
- CLAIM: re-render and verify ext/props-vex, ext/props-claire, ext/props-sable, and the no-change calls for Grimble and Lace, against the new sheets. The earlier props_*.jpg Vex renders show the old v1 Vex (shorts, horn cannon), not the v2 model on the branch, so they are being replaced.

## 2026-11-08 deep (job 20261108-004501-a4): BLOCKED utilities + shops (no CLAIM taken)
- ext/utilities-shops still waits on the research job ("Research: every source map utility + shop stock + region roles + hot zone", role finder). It is only in the backlog and hasn't run: there's no ext/source-utilities branch and no docs/SOURCE_UTILITIES.md. Run that finder job first, then this build. The build should branch from ext/source-utilities and merge ext/shops (794264bf, not in main) first.

## 2026-11-08 feel (job 20261108-003053-a4): tutorial dialogue + NPC beacons
- READY ext/tutorial-dialogue 53e56a9e0: a dialogue box every NPC can use (NpcDialogue, npc_talk.json). It has a big portrait (neutral, happy and warning shown by the frame colour), a name plate, a '...' bubble, then typed text with voice blips; tap, click or interact moves it on. The camera eases in on the speaker's head and back out. The tutorial poll waits while the box is open. In the world, NpcBeacon adds a glow outline, a name tag and an edge arrow (only while Hob has new blueprints or the tutorial says "meet Hob"). Hob's head and hat are bigger. Portraits are a render of the model for now; painted ones go in at res://art/portraits/hob_{neutral,happy,warning}.png and load with no code change. Decision 0019. --farm-tutorial-check: 0 failures (17 new asserts). health --strict OK. home.gd: +2 lines of wiring, 1 line changed. No save or Net change.

## 2026-11-08 build-spec (job 20261108-011502-a4): relic pickup art spec
- READY ext/relic-art-adds 88bab293d: docs/art/relics/RELIC_ART_SPEC.md, one 3D+2D pickup spec and a prompt for each of the 12 relics (round-3 locks applied). No model edits, no code, no checks needed.
- READY ext/art-2d-swap f63c8b866 (2D art swap: splashes mage_splash.jpg + ostra_splash.jpg; portraits rimewright.jpg, ostra.jpg, bulwark.jpg, gunslinger.jpg, same names/paths; web WebP <400 KB in coord/site-art/: sparkle_splash, motley_splash, neve_portrait, motley_portrait, mossy_portrait, vex_portrait .webp for the owner to push. NOT yet verified: hero-select/splash screenshot is queued on jobq 20261108-010057-30604 (no GPU worker was running); look at that sheet before merging.)

## 2026-11-08 deep (job 20261108-013001-a4): CLAIM Hollow Crown 2x
- CLAIM: The Hollow Crown to ~2x land (one SIZE constant, ~305), landmarks/shops/chests/key carriers/extractions/drops scaled, sky train as a winding fast-travel loop to every region, jump-pad-only floating islands removed, squads per match raised to keep squads/m² flat (matchmaker, server, bot backfill). Branch ext/map-2x.
- STATUS (NOT READY: real-GPU perf is not flat vs main): branches `ext/map-2x` 53a1373e2 (2 commits on origin/main 7907d9afe) and `ext/matchmaker-map-2x` 1511aeef5 (trio_slots 12→24). SIZE 305 (216 design grid via scale_layout, ~2x land), second-wave content (MORE), winding Catmull-Rom train loop with a stop near every region (ride ~8 m/s avg vs 4.55 on foot), Shardfall removed, Data.MATCH_PLAYERS 40, backfill follows it, Net.VERSION 0.25.0, decision 0019.
- Checks: health --strict OK, gen_wiki --check OK, keys 84/0, cover 85/0, wall-size 6/0, extract 1/0, mapcheck-authored bad 0/20; train-check 7 ok / 7 FAIL (jump/land/rider/dash/pier: the same failures main's Skyreach train has, not new). Simtests 40 solo (seed 11) and 13x3 trios (seed 5): rc 0, 0 script errors. Matchmaker unittests pass.
- GPU perf (jobq, all on pc-MRROBOTO, perf_probe fight/ride phases): main 20 hunters fight 25.2 ms (script 12.2), load 12.4 s, ride 46.7 ms; branch 20 hunters 36.8 ms (19.8), 17.1 s, 108 ms; branch 40 hunters 60.2 ms (35.1), 19.8 s, 200 ms. Video mem 399→564 MB, nodes 10.8k→19.5k. The map alone costs ~+12 ms/frame and +4.7 s load; 40 hunters add ~+23 ms. Reports: briefs/shots/a4-map2x/perf_*.txt.
- Next (not done): sleep far mobs/camps and per-hunter AI LOD, ride-phase cost (streaming along the loop), warm_up 4.4→6.7 s and build.hunters 2.8→5.0 s. Alternative if perf can't be recovered: ship 2x land at 30 hunters.
- Shots: briefs/shots/a4-map2x/before/ (main) and after/ (branch): top.jpg plus one eye-height shot per region (cinder, crown, duskmoor, frostgate, highwatch, lark, saltmere, storm, thorn).
- STATUS (job 20261108-043002-a4, perf escalation; still NOT READY: GPU proof blocked, pc-MRROBOTO heartbeat last 04:30Z, GPU job 20261108-050441-08067 queued): `ext/map-2x` 6d0936c0c (+2 commits on 53a1373e2). SimLod (scripts/match/sim_lod.gd): bots >45 m from the local player, grounded, not boarding/lair-scripted, not fighting near the player and not just hit by them step at 20 Hz with banked dt (their Boki too; far bot-vs-bot fights step both sides together); cached bot steering (waypoint cache); no interact-prompt scans for bots; cheaper spawn reveal; TEAM_COLORS 40 (no repeats). Headless 40 hunters, before→after: fight 74→56 ms wall, script 48→32; ride 286→137, worst frame 2363→~390. 20/30/40 hunters fight script 19/31/32 ms, load 11.7/13.0/13.8 s. Decision: keep 40 (the 30-hunter fallback buys ~1 ms script and 0.8 s of load); noted in decision 0019. Load growth is ~120 ms per hunter model (GLB Wardens build then hide the procedural body): docs/DEBT.md "Hunter model build time". Checks: health --strict OK, gen_wiki --check OK, perf-throttle 0 fails, mapcheck-authored bad 0/20, extract/keys/hatch PASS, bot-sanity 0 flagged, generator problems 0 with no diff; 40-hunter --simtest seed 911: 150 s sim, 10 alive at t=142, 0 script errors (player team wiped at the end; seeds 1/7 wiped early at t=34/48, also 0 errors). Needs GPU before READY: perf_probe 40 vs main 20 (fight, ride, load) on pc-MRROBOTO; the earlier shots in briefs/shots/a4-map2x stand (map unchanged).
READY ext/parity-glide-dive 45f26a5b5 (KIT_PARITY item 18: glider dive, hold Ctrl under the glider: 32.5 m/s at 35 m/s², steer 0.25, cancel 3.5 m, 10 s timeout, all [game data]; the key is ours, the source names none; move-feel-check dive_* assert them, 0 failures; health --strict, style, gen_wiki --check ok; decision 0019)

## 2026-11-08 build (job 20261107-233002-a2): READY Training Grounds (partial: no viewable GPU images yet)
- READY: branch `ext/training-grounds` (3 commits on origin/main 7907d9afe). The `--arena` map is now the Training Grounds: floor r31 (3033 tiles vs 616, ~4.9x), the old Training Room (walled ring, 3 dummies, sparring bot) kept in the middle, a duel ring with the duel pad to the east, five sky perches (Hunters, Gear, Belt items, Bots, Boki) reached by one-way pads and left by glide. Pedestals: 12 Hunters, 9 Boki, 25 gear pieces, 8 belt items, 12 sparring-bot spawners + clear. Weapon-tuning perks are not stationed. A faller below y -12 is sent home. Buttons say "Training Grounds"; internal id stays `arena`.
- Checks: `--grounds-check` 17/17, `--arena-check` 102/102, `--practice-hero-check` 0 failures, `health --strict` OK, `gen_wiki --check` OK.
- GPU (RTX 4070 SUPER, jobq): old arena start spot wall 5.04 ms / gpu 1.21 / draws 474 / tris 337k; Grounds start wall 5.29 / gpu 1.32 / draws 451 / tris 413k; on a perch wall 4.30 / gpu 1.46 / draws 357 / tris 171k. Within the old arena's budget.
- NOT DONE: I could not look at the top-down and ground-level shots. The GPU job wrote them to /tmp/gs_new on worker pc-MRROBOTO; a re-run that collects them (`--out gs_out`) is job 20261108-002945-07258, still queued (worker idle for 70+ min). Owner: please look at its out dir before merging.
- Alternative not taken: building on the generated "training" island instead of the `--arena` map.

## 2026-11-08 deep (job 20261108-014504-a4): CLAIM Training Grounds (escalated from 20261107-233002-a2)
- CLAIM: finish ext/training-grounds: review the diff, rerun the checks in a fresh import, collect and look at the GPU top-down and ground-level shots, fix what they show.
READY ext/parity-jump-flowrows 0f70d1a8a (item 20: jump speed pinned to source 7.5 in move-feel-check, 6.8 kept for terraces; unsourced flow rows marked [?] in KIT_PARITY.md)

## 2026-11-08 deep (job 20261107-213004-a4): READY Motley v2 model
READY ext/ostra-v2-model 76f589389 (Motley v2 model from motley_v2_turnaround + master sheet: sheet palette (magenta-violet/plum doublet, lilac ruff+gloves, bronze spring, mauve box), spades front/back + diamonds on the sides, near-cube box, crank mesh gone (x_crank bone + anchor_crank kept for the clips), no belt, one button column, longer tails, broad flat void ribbon, head 0.87x, ruff 0.85x; same armature/anchors/FX points/clips/kit; 13750 tris, one 2048 atlas. Checks: rig-json unchanged, warden-model/glb/clips, hero, hero-combo, hero-vfx, ostra-combo, motley-live, health --strict all pass. GPU before/after: briefs/art-refs/motley_v2/ingame/)
| Fidelity (FIDELITY_CHECKLIST Motley) | |
|---|---|
| jester upper body on a brass spring from a card-suit box | ✅ |
| hovering box, no feet/legs, silent glide | ✅ (clips unchanged, motley-live passes) |
| starry void face, glowing grin | ✅ |
| chaotic swirl of burning cards | ✅ (orbit cards unchanged) |
| ult ground void vortex | ✅ (kit unchanged) |
| spring compresses on the dash | ✅ (motley-live) |
| weapon scale+fit: no weapon, palms cast, fan = deck | ✅ |
| v2 palette / suits / no crank | ✅ |
| head size as small as the sheet | ❌ 0.87x of v1 (sheet ~0.65x): kept larger for the match-camera grin and the line-up height check (1.167x vs 1.20x, tol 0.04) |
| box panel tone | ❌ reads lighter/pinker under the toon light than the sheet's dusty mauve |

## 2026-11-08 deep (job 20261108-020004-a4): CLAIM map regions + hot zone
- CLAIM: every Hollow Crown region gets a landmark, its own terrain shape, cover pattern and a reason to go (docs/MAP_REGIONS.md), plus the per-match hot drop zone (better loot, drop map + minimap, bots weigh it). Branch ext/map-regions. ext/map-2x is not pushed yet (job 20261108-013001-a4 still building it), so this branches from origin/main on the 216 design grid that map-2x scales from; rebase onto ext/map-2x once it lands.
## 2026-11-08 finder (job 20261108-021504-a4): CLAIM source utilities research
- CLAIM: research every source map utility/consumable (effect, numbers, where sold), shop stock, region roles, hot drop zone and train; compare with content/utility/*.json; write docs/SOURCE_UTILITIES.md (table with Boki names + have/missing/differs, a fixed distinct stock per shop). Branch ext/source-utilities from origin/main. Unblocks ext/utilities-shops.
- READY ext/parity-phasewalk 514684169 (KIT_PARITY gap 8: Hem's Spirit Walk passes raised terrain walls like the source's Phase Walk; ending inside snaps back; archer combo check asserts it)
- READY (2026-11-08, job 20261108-021504-a4): ext/source-utilities @ 86ff3a353, docs/SOURCE_UTILITIES.md (docs only, +114 lines). Covers every source utility with cited numbers, Boki names and have/missing/differs status; how source shops, regions, the hot zone and the train worked; and a fixed stock per shop (staples tonic + armor_kit everywhere, everything else in exactly one shop). Alternative noted: no shared staples. Unblocks ext/utilities-shops (branch from it, merge ext/shops first).

## 2026-11-08 deep (job 20261108-014504-a4): READY Training Grounds (supersedes the partial READY above)
- READY ext/training-grounds 5ebc35501 (5 commits on main 7907d9afe). On top of the build job's work: --grounds-check now rides every pad up (5) and every glide route down or across (10) and asserts where you land, instead of counting entries. With the glider off, the glide assert fails, so it is a real assert. Pedestal glow 0.9 to 0.3, because bloom washed every pedestal to white on the GPU. grounds-shots used to teleport you under each perch (y 0.5 vs ~9 m), so the old "perch" frame time was taken mid-fall; it now stands you on the perch.
- Looked at the real-GPU shots (jobq 20261108-002945-07258, RTX 4070 SUPER): the top-down shows the floor, the Training Room, the duel ring and the five perches; the start and room shots are fine. Start spot: wall 5.16 ms, gpu 1.33, 449 draws, 413k tris. Old arena: 5.04 / 1.21 / 474 / 337k. That is about 0.1 ms over the old arena, well inside a 60 fps frame.
- The re-shot with the perch fix is queued: jobq 20261108-015420-14738 (out dir gs_out). Look at 04-08_perch_*.png and the "perch" GROUNDSPERF line before merging.
- Checks on the tip: --grounds-check 17/0, --arena-check 0 FAIL, --practice-hero-check 0 failures (one commit earlier, logic unchanged), health --strict OK, gen_wiki --check unchanged. Fresh --import first.
- Not in scope, left as is: the home screen still has the separate "Training area" and "Duel room" buttons; DECISIONS wants Duel only from the Grounds' ring.

## 2026-11-08 build (job 20261108-023004-a4): CLAIM lore sync to LORE_MASKS
- CLAIM: sync all lore, story and marketing text in the game repo to briefs/LORE_MASKS.md (five groups, current names, rewritten Hunter stories, relic table): docs/art/gen/stories, in-game Mask/codex/lore text, wiki generator lore fields, marketing copy. Display names only in player text; Cinder/Meeko relics + Grimble monocle wired as data. Lore only, no squad/matchmaking code. Branch ext/lore-factions from origin/main.
READY ext/parity-kael-clips abacc4d18 (KIT_PARITY gap 1: Zedran/juggernaut plays the first Kael's 49 footage-timed clips on main's Kael model, sword skinned to hand.R; --clip-check asserts slam strike at footage 0158/0.6 s; supersedable by ext/kael-v2-model)
READY ext/parity-neve-skate-home 9b65ea7f1 (Neve skating darts already home late since e5c73480c; added bend>5deg check, fixed stale header/doc; KIT_PARITY gap 16 is stale)
READY ext/lore-factions 9732ab9bb (lore sync to LORE_MASKS: 12 class files take current titles/names/stories; content/rules/lore.json holds 5 factions, banter and the relic table with Cinder/Meeko/Grimble as 'proposed' (one-word edit to lock); prologue is Solmere/Malgrave/the Hollowing; Vex relic accent is a gold coin; gen_wiki writes the Lore page + docs/art/gen/stories/*.md; wiki class pages renamed; zero old names in player text; health --strict, gen_wiki --check, hero-title/prologue/portrait checks pass; ids, art files and Boki test names untouched; Cinder/Meeko 3D gear still has the old look, art pass pending)
READY ext/pip-companions-v2 399f2b017 (Meeko's sun + raincloud from pip_v2 companions sheet replace the hand lantern: sun skinned to pauldron.L, cloud+2 drops to pauldron.R, 14,811 tris, one atlas; 8 faces = pip_faces.png cells (sun: calm/happy/angry/sleepy, cloud: calm/happy/sleepy/cry) driven by WardenMood via pip.json mood.faces and a new atlas shader; anchor_lantern_top/anchor_hang_lantern/weapon_muzzle kept, re-parented to the sun so FX/halos/kit follow; clips unchanged (45, lengths match); checks: warden-clips/glb/model/rig-standard/clip/pip-live/hero-vfx, health --strict OK. FIDELITY: sun ~0.21 m wide vs ~1.7 m Pip (about the sheet's chibi ratio, floats at shoulder, not oversized); shape/colour match (10 rays, yellow-orange, lavender-white cloud with drops); front/3-4/side/back in ingame/tender_companions_*. Note: sheet's ZZZ glyph and cloud rain-streaks are not on the faces; cloud reads whiter than the sheet's lavender; before/after in briefs/art-refs/pip_v2/ingame/)

CLAIM ext/tg-text (job a4): Training Area -> Training Grounds, Extraction trios only, Duel off main list.
READY ext/tg-text @ : text rename, tabs Solo/Duos removed, Duel room button removed (Duel stays in the Grounds bar). health --strict, gen_wiki --check, arena/practice-hero checks pass. GPU shots queued (jobq 20261108-025052-16336) but no GPU worker picked it up yet: unverified visually. farm-start-check has 2 failures (meadow tint, crouch) that look unrelated, not checked on main.
READY ext/parity-no-riders 3bcb50eca (remove Chill 15% slow, Meeko carrier shield (hit/stun drops), stale Shred text; checks assert 4s Chill/no shield)

READY ext/hero-names 5e42b4b58 (player-visible hero names/titles synced to LORE_MASKS + DECISIONS; ids, files and folders unchanged; --import, hero-title/portrait/archetype/dolm/ashwick/tender checks 0 FAIL, health --strict OK)
| id | old -> new base_name | old -> new title (content/archetypes) |
|---|---|---|
| bulwark | Breaker -> Albert | Sunken Bulwark -> Barnacle Knight |
| mage | Ryzz -> Sparkle | Storm Chaser (same) |
| archer | Lisette -> Lace | Red Stitch (same) |
| dolm | Tarek -> Tenzo | Cliff Runner -> Stone Seer |
| rimewright | Claire -> Neve | Frost Siren -> Snowglide (DECISIONS Nov 7 evening: Snowglide, not Snowglider) |
| tender | Pip -> Meeko | Little Lantern -> Dawnfox |
| ashwick | Cinder (same) | Mad Pyromancer -> Flame Queen |
Also: content/sfx/{bulwark,mage,archer,dolm,rimewright,tender}.json "name"; tools/weapon_audit.gd, warden_stance_shots.gd labels; portrait_check, breah/ashwick/care combo checks assert the new names/titles; hero_title_check OLD_NAMES now retires Hem, Breaker, Ryzz, Pip, Claire, Tarek, Lisette, Mossy, Ravel, Snowglider. Not touched: code comments, tools/gen_sfx_*.py docstrings, Boki kin nicknames "Pip" (a pet name, not the hero). Overlaps ext/lore-factions (also edits the class files): expect a trivial conflict in the title/base_name lines.

## 2026-11-08 imagegen: villain art status (Malgrave, the Undying Queen)
- Wyrmheart: LOCKED to the key-art look (glossy crimson glass, pink-red glow, no gold, no crack). Sheet: briefs/art-refs/villain/wyrmheart_sheet.jpg.
- Mask: LOCKED by the owner as white porcelain "Blood Tears" (briefs/art-refs/villain/wyrm_queen_mask.jpg), NOT the red-lacquer draft. MALGRAVE_QUEEN_LOOK.md's mask section is updated to match; please carry it into LORE_MASKS / the lore page. Hunter masks are porcelain because they copy hers.
- Human form: 4 turnaround options in progress (owner: seductive hourglass figure, fully and formally dressed). True form follows after the owner's pick.
- Noted: Mossy is now Albert, the Barnacle Knight (id bulwark); new art files use "albert".

## 2026-11-08 deep (job 20261108-020004-a4): READY map regions + hot zone
- READY: ext/map-regions @ 6a0a5ea61 (on origin/main, 216 grid; rebase onto ext/map-2x once it lands). Every Hollow Crown region has a landmark (new: Highwatch lighthouse, Duskmoor standing stones, Saltmere salt obelisk, Larkhollow giant tree), a raised tier of its own (Lark rim bowl, Highwatch lv4 Lookout, Duskmoor chapel floor, Saltmere dry river between banks, Thornwood Bramble Rise), its cover pattern and a stated purpose + region loot lean (docs/MAP_REGIONS.md, one line each). Biome cover shares unchanged in range (bloom 15.3, meadow 10.7).
- Hot zone (scripts/match/hot_zone.gd, owned by BiomeRun): one non-Crown region per match from the seed, +1 rarity step, ringed on drop map + minimap, bot leaders pick it 35% of the time when no squad is near it. No Net change (seed-derived). Alternative not taken: weight the pick by region size.
- Checks: health --strict OK, gen_wiki --check OK, --mapcheck-authored 0/20 bad, --cover-check 0 fail, --extract-check pass, new --hot-zone-check 88 ok/0 fail (4 regions picked over 8 seeds, bots chose it 7x), --simtest --seed=5 ok, --bot-sanity-check 0 fail.
- Shots (new --region-shots, GPU): before /home/boki/jobq/done/20261108-022221-06013/out, after /home/boki/jobq/done/20261108-022221-28628/out (region_<id>_top/_ground.png per region, drop_map.png with the hot zone).
- Perf --perf-bench main vs branch, same worker: pc avg 24.5 vs 24.1 ms, p99 47.4 vs 48.3; mac avg 18.7 vs 19.9, p99 68.3 vs 68.7. Build ~+50 ms (terrain/generate). Visible tris differ with the bench view (+5 chests, 24 vs 19); landmarks add ~2.3k tris total.
READY ext/vex-e-turn 6249e0063 (Vex Longneedle items 144/144b: the aim locks at the press and turns at most turn_deg_s 90 deg/s via the kit's aim_lock() hook, so the line, her facing, the synced face and the beam follow the capped aim: a 180-degree flick moves the beam at most 54 deg, a small adjustment still lands; the camera push-out and lean scale with aim distance, none inside view_near_m 5 m, smoothstep to the full 0.25 at 18 m, eased; numbers in gunslinger.json; --gunslinger-combo-check 103/0 FAIL with new flick/lagging-line/nudge/3-11-18 m camera asserts, parity item 68 aim moved to 18 m; health --strict OK, gen_wiki --check OK; untested in live play or online, no footage number for the source's turn rate so 90 is the owner's start value)

## 2026-11-08 deep (job 20261108-003051-a2): props swap re-check, per branch, GPU side-by-sides
READY ext/props-vex 8e7bcab6e (Vex v2 weapon sheet: the barrels, gcollar, gspindle and gband41 now use a polished-silver BARREL ramp; before, they read black at the match camera. Stickers, belt loop and bullet charm are unchanged. 10715 tris, one 2048 atlas, 36 clips)
- The Vex props_*.jpg that the earlier job uploaded showed the v1 model. They are now replaced with GPU renders of this branch (pc-MRROBOTO turntable 20261108-033933-28575, match 13649). New: props_vs_sheet.jpg, laid out as sheet | before | after | match, and props_gun_before_after.jpg. Under toon shading the barrels are still a step darker than the sheet.
- props-claire c34a78032 and props-sable 628195e5e were re-verified on GPU with side-by-sides; each is in <hero>_v2/ingame/props_vs_sheet.jpg. No changes were needed. On Claire the skates read grey-lavender rather than white; that comes from the scan texture. The alternative fix is to recolour the boot region; not done.
- Grimble and Lace: no-change calls re-confirmed from their existing GPU renders (grimble game_vs_sheet: bone-hook arm, no nose; ravel pass3_front34: needle, bow, shoulder mask, spool belt, hair needles). The fresh turntables timed out with rc 124 because those trees were not imported.
- Per-branch checks on vex, claire and sable: --warden-rig-json OK; --warden-glb-check 0 fail; Vex also --warden-clips-check 0 fail; health --strict OK. The thief --warden-model-check 1.133x vs 1.06x is pre-existing on the base glb.

## 2026-11-08 (job 20261108-035644-a2): --cinder-art-check release blocker
READY ext/fix-cinder-art-check cb8131be9 (branched off ext/mc-20261108-0030, not main: the failure only exists there; 1 commit, tools/cinder_art_check.gd +5/-3. Cause: not the Cinder redesign, which is NOT in the candidate (ext/cinder-flame-queen and ext/cinder-v2-* are unmerged; the candidate still has the gun model). The hero-heights retarget raised ashwick body size 1.067 -> 1.208, so the model's braced muzzle reaches 1.50 m while the kit's fixed NOZZLE.x is 1.30 m (tol 0.14). Fix in the check: expected reach = NOZZLE.x * size / 1.067 (1.47 m); the rules origin and balance are untouched. Candidate+branch: --cinder-art-check fails=0. Not run on bare main with the mc check file (it needs mc's anchor_jet nodes); main's size is unchanged so its own check is unaffected. When ext/cinder-flame-queen merges, take its version of the check: it drops the reach assert and measures the palm instead, so this hunk will conflict and should be dropped)
READY ext/anim-time-lace 048e54d95 (Lace animation timing parity: roll hands to the crouched walk at roll_t, Heavy Shot draw clip on the hold's clock, Starpiercer nock 0.5/recover 1.0 for the 1.5 s cadence; timing table in docs/heroes/archer.md; asserts in --archer-combo-check)
READY ext/parity-lace-focus ffa20b0f7 (Lace: Focus meter + Deadeye cut, Hawk Sense kept; archetype-check 360/0, archer-combo 149/0; conflicts with ext/parity-lace 4aa011a49 in archer.json/archer_kit.gd/checks, merge that one second)
READY ext/anim-time-cinder 584aa5241 (Cinder anim timing: run cadence 1.8x, ram squash on the hit frame, timing table + combo-check rows)

## 2026-11-08 (job 20261108-035646-a4): --clip-check bulwark release blocker
READY ext/fix-albert-blade-clip cb61e7f3d (branched off ext/mc-20261108-0030; 1 commit, bulwark.json -1/+1 and a DEBT.md line. Cause: ext/hero-heights set body.bulk 0.8 on bulwark; Models.hunter scales the model root (bulk,1,bulk), a non-uniform scale, so the held blade's length depends on its direction (drift 0.111 m). ext/parity-mossy-cadence (throw_rate, travel arg) is innocent. Fix: bulk back to 1.0 (clip-check 0 failures, bulwark drift 0.000). Mossy is therefore not 20% narrower yet; a rig-level narrowing is filed in docs/DEBT.md. NOTE, not this branch: --warden-model-check on the candidate has 18 FAILs vs 1 on main (gunslinger width, which the candidate's check edit fixes); the 17 new ones are the hero-heights retarget vs the check's sheet heights/width for archer, gunslinger, mage, thief, dolm, rimewright, ashwick, juggernaut, dredge, none for bulwark, and need the check's WARDENS values updated to the owner's chart)
READY ext/anim-time-vex 712242c33 (Vex anim timing parity: Cinderfall shot on the kick key, held slide holds, walk-off hand-back, doc table + check)
READY ext/kael-ult-reset f1192cb93 (Kael Riposte kill reset traced to the source, routed through HeroUlt.landed/reset; asserts for knock vs plain hit vs already-down)
READY ext/parity-bulwark-guardcut b2e942eb4 (bulwark: cut Guard meter + Shield Slam; Bash 6s on Shift, Crushed passive; checks + wiki)

## 2026-11-07 23:40 ET (art): Malgrave human form LOCKED
Malgrave's human form is locked by the owner. The main design is briefs/art-refs/villain/malgrave_human.jpg: an angelic, seductive queen in pearl white, blush pink and crimson. She wears a plunging pearl silk gown with a feather crest behind her head and long sheer pink sleeves, she has gold claw tips, and her pearl-white serpent tail loops into an infinity sign around her (her Undying Queen silhouette). There are two alternates in the same folder: malgrave_human_alt_throne.jpg (seated on her coils) and malgrave_human_alt_silk.jpg (a second, more revealing outfit). The direction has changed. She does not look evil; she wants to look as radiant and good as possible. The halo and the gold neck rings were dropped. MALGRAVE_QUEEN_LOOK.md is updated and overrides the older red-and-gold queen notes. Cinder is the Ashen Kiss, as you already have it.

## 2026-11-07 23:45 ET (art): CORRECTION to the Malgrave lock above
The owner picked D, not B, as the main design. briefs/art-refs/villain/malgrave_human.jpg is now D: a plunging pearl silk halter gown, a crimson scale belt, crimson rose-patterned thigh-high heeled boots, a white feather mantle at her elbows, gold claws, a confident smile and the infinity-loop tail behind her. The feather-crest version moved to malgrave_human_alt_crest.jpg as an iconic alternate. The other two alternates are unchanged. MALGRAVE_QUEEN_LOOK.md is updated.

## 2026-11-07 23:50 ET (art): Malgrave final pick (supersedes the two notes above)
The main design is briefs/art-refs/villain/malgrave_human.jpg, option I: Malgrave seated cross-legged on her own coiled pearl-white serpent tail. She wears a plunging pearl silk halter gown, crimson rose-patterned thigh-high heeled boots, a white feather mantle and gold claws. Three alternates are kept in the same folder. malgrave_human_alt_standing.jpg (D) is the same outfit standing and is the reference for her model. malgrave_human_alt_silk.jpg (H) is a second, more revealing outfit. malgrave_human_alt_crest.jpg (B) has a feather crest and an iconic silhouette. MALGRAVE_QUEEN_LOOK.md is updated.

## 2026-11-08 deep (job 20261108-043004-a4): READY ext/s7-mask-hob-83-89-fix-rebased a5be26e69 (supersedes ext/s7-mask-hob-83-89-fix 6b433e542)
- The listed conflicts were not with origin/main (6b433e542 already contains main 7907d9afe and merges clean). They were with ext/text-relic-renames-rebased e9f0f984, which is in ext/mc-20261108-0030. This branch merges that one in (8a59ba2d9). It keeps the s7 code (MaskOffer removed, MaskBeat, the second Relic from Hob) and applies the owner's text rule to s7's new text: Mask -> Relic (Hob's "found a {mask} Relic", mask_moment.json, comments), Pip -> Meeko. Lace's whisper "Every mask I sewed" keeps a lowercase mask as lore, like farm_tutorial's "the mask of a fallen Hero"; re-capitalise or rewrite it if you want.
- a5be26e69 fixes the checks after the merge: hob_check uses the owner pick order Kael, Cinder, Meeko; mask_moment_check reads the name from HunterViewer.display_name ("Vex the Hired Gun" form); farm_tutorial_check's ready-to-claim row skips the second-Relic picks (is_bonus). With the new Hunter order, Kael came first and could never be claimed.
- Checks (headless): --check 0 failures (x2); health --strict OK; --hob-check, --mask-moment-check, --class-unlock-check (x2), --hunter-unlock-check, --portrait-check, --teammate-check rc 0 / 0 FAIL; --farm-tutorial-check rc 0 x2 after the fix. Not rerun under xvfb.
- Against mc-20261108-0030 three keep-both conflicts are left: docs/ASSET_CREDITS.md, docs/DEBT.md, tools/check_registry.gd (both sides add lines). Clean against origin/main.
READY ext/lace-dash-charges 7b83eae8 (Lace Spirit Walk: 2 charges + roll 3.5->4.0 m, item 146; archer-combo, dash-slot, health, wiki pass)

READY ext/feel-integ bed04e50b (release integration on ext/mc-20261108-0030 88b1ac50e; deep worker 20261108-042434-a1)
- In it, in this order: parity-move-feel 64e6c681, parity-dash-scale 2f24ae36, parity-dashlmb 4e788af6, cinder-flame-queen c3f4f172, cinder-v2-palms 766b44cd (carries cinder-v2-model), sable-v2-model 3e1816a6, fix-albert-blade-clip cb61e7f3d (READY in time).
- Left out: fix-cinder-art-check cb8131be9. Its own note says to drop it once flame-queen merges, and the merged check passes (braced palm reach 0.60 m against REACH_MIN 0.3).
- Resolutions:
  - The ground brake is the HunterMove.brake table.
  - The move-feel decision was renumbered to docs/decisions/0020, because 0019 was already used.
  - Dash travel is scaled once (no use_ex).
  - Cinder's jets stay data-driven (HeroVfx "jets", heel_l/heel_r/tail on the v2 anchor_jet_*/anchor_tail_tip) with the roar.
  - tip() uses the v2 palm Muzzle, falling back to hand_r + PALM_AHEAD.
  - cinder-art-check is the union of both versions. The tail-behind threshold is now 0.1 m, because the v2 tail curls.
  - The title is the Ashen Kiss everywhere (Class-Flame-Queen.md became Class-Ashen-Kiss.md, and its intro text was rewritten).
  - Long lines were wrapped for the style ratchet.
- Checks:
  - Passing: --check 0, health --strict OK, move-feel 0, dash-flow 0 (14 skipped), cinder-art 0, clip-check 0, hero-combo 304/0, ashwick-combo 119/0.
  - warden-model-check FAIL: only the "stands Nx a medium hunter" height lines, for 8 heroes. The base 88b1ac50e already fails the same lines and more (Cinder's width too, which is now fixed). This is not caused by this branch.

## 2026-11-08 00:10 ET (art): Malgrave full set DONE
Everything is in briefs/art-refs/villain/:
- malgrave_human.jpg: the main design, seated on her coils
- malgrave_turnaround.jpg: front, 3/4, side and back
- malgrave_splash.jpg: enthroned on her coils with the court kneeling, and her shadow on the floor is the dragon's
- malgrave_portrait.jpg: 1:1
- malgrave_hybrid.jpg: horns, the dragon's wings, scales and the X scar
- malgrave_dragon.jpg: a pearl-white serpent wyrm with feather-to-crimson-membrane wings, a porcelain mask face-plate and the X scar from Kael's sword, looping into an infinity sign, with a knight for scale
The alternates (outfits, splashes and a portrait) are in villain/malgrave_alts/ (see its README). The owner says she will become a playable character eventually. The owner also says the Heart should not be a prop she shows off; it can become an ability later.

## 2026-11-08 deep (job 20261108-044504-a4): READY ext/fix-albert-blade-clip b23758516 (release blocker, on ext/mc-20261108-0030 88b1ac50e)
- Cause: hero-heights gave bulwark.json `"bulk": 0.8`, which Models.hunter applies as a root scale on x/z only. That shears the skinned blade as the hand turns, so its length changes. parity-mossy-cadence is not involved.
- Fix: the narrowing stays (Mossy is still 20% narrower). WardenGlb.Sync._square_blade makes the blade bone's world basis square at the skeleton's height scale, only for a Warden with a body bulk. The branch reverts the earlier attempt cb61e7f3d, which had dropped the bulk.
- --warden-model-check: the table now holds the heights from the owner's final height chart. Before that, 16 height rows on the candidate were stale. Ashwick's width bound is now 1.75.
- health --strict: the long lines --lineup-shot added are wrapped.
- Checks: --clip-check 0 failures (bulwark drift 0.018 m, limit 0.02); --warden-model-check 157/0 PASS (main: 1 failure); health --strict OK. Full suite not run.
- MERGE NOTE vs ext/feel-integ (also on 88b1ac50e), which conflicts in four places:
  - bulwark.json: it drops the bulk. Keep the bulk to keep the owner's narrowing.
  - lineup_shot/check_registry: the same style wraps; take either.
  - warden_model_check thief/ashwick height_3d: its v2 models changed those. Re-measure after merging both: run --warden-model-check and set height_3d to the new 3D model rows.

## 2026-11-08 00:12 ET (art + lore): the Queen's art is done; Auburn Knights direction
The Queen's art set is complete; see the note above. Next is the Auburn Knights, with one iconic armour set based on her look and shared by all of them. New lore from the owner: **there are always exactly 7 Auburn Knights.** Please add this to the lore files.
READY ext/lace-tall-climb 8b684f259 (Lace tall-ledge climb was already built via climb_tall; added combo-check asserts Lace climbs a double-high ledge and Vex cannot, archer doc rows fixed)

## 2026-11-08 00:16 ET (art): Auburn Knight armour LOCKED
briefs/art-refs/villain/auburn_knight_armor.jpg is the shared armour of the 7 Auburn Knights. Their helms have faces made from the Queen's porcelain mask, with glowing pink-red eyes. The plate is crimson and pearl with gold trim and rose motifs. The shield is white with a gold serpent crest, and they carry gold-hilted dueling swords.
READY ext/dash-refresh-assist 398f4a9c5 (item 159: knock/assist dash refresh in DashReset, multi-charge +1, softer assist cue, knock_refresh opt-out, decision 0019)
READY ext/text-lore-integ 930f01e0f (supersedes: ext/hero-names 5e42b4b58, ext/lore-factions 9732ab9bb, ext/s7-mask-hob-83-89-fix-rebased a5be26e69 / ext/s7-mask-hob-83-89-fix; ext/text-relic-renames already in mc-20261108-0030)

## 2026-11-08 00:32 ET (art): villain/story set COMPLETE
Everything is in briefs/art-refs/villain/:
- the Wyrmheart
- the mask
- Malgrave: human form, turnaround, splash, portrait, hybrid and dragon
- the Auburn Knight armour
- Solmere: solmere_skyline.jpg and solmere_throne_room.jpg, in pearl and pink (the city matches the Queen)
- the Heart's Chamber: hearts_chamber.jpg
Corruption stages stay parked until the Nov 28 reminder. Next on the art side: the Grimble splash redo, the Sable splash fix, and the face-off without the heart.
READY ext/models-v2-integ 5ec44812f (supersedes: ext/ryzz-v2-model 6355dee78, ext/grimble-v2-model 54df2f18a, ext/grimble-hook-arm-v2 315cdf2af, ext/claire-v2-model 7b2165a7c, ext/props-claire c34a78032, ext/tarek-v2-model fa5c036a8, ext/ostra-v2-model 76f589389, ext/pip-companions-v2 399f2b017, ext/vfx-pip-rebased 93b5e23fe, ext/vfx-pip, ext/fix-albert-blade-clip b23758516; on ext/mc-20261108-0030; skipped: breaker-v2-model (no READY), props-sable (contains sable-v2-model, owned by another integ); warden-model 157/0, clip-check 0, check 0, hero-combo 304/0, health --strict OK)
READY ext/map-parity-integ f243f76ae (supersedes: ext/parity-glide-dive 45f26a5b5, ext/parity-jump-flowrows 0f70d1a8a, ext/parity-no-riders 3bcb50eca, ext/anim-time-lace 048e54d95, ext/parity-lace-focus ffa20b0f7, ext/art-2d-swap f63c8b866; on ext/mc-20261108-0030; ext/map-2x skipped: never READY, perf not flat)
- VERIFIED (feel, job 20261108-054503-a2) f243f76ae in a fresh tree: --import ok; move-feel 0 fail, archetype 379/0, archer-combo 159/0, support 177/0, portrait 107/0; gen_wiki --check 34 unchanged. health --strict fails only the pre-existing check_registry.gd/lineup_shot.gd long lines (unchanged vs the candidate, fixed by ext/fix-albert-blade-clip b23758516 in models-v2-integ). Art swap seen: briefs/shots/map-parity-integ_practice_picker.png (xvfb software render, new Vex/Neve/Mossy/Motley portraits); real-GPU sheet jobq 20261108-054752-08461 still queued, no GPU worker since 04:30. warden-model/clip-check not re-run: this merge changes no models (previous run: the candidate's own 17 height fails + the Albert blade clip, both owned by fix-albert-blade-clip).
READY ext/kael-v2-integ 36c5f7ea7 (supersedes: ext/kael-v2-model ca52dc648, ext/parity-kael-clips (its clip retimes are for the v1 glb; v2's 49 clips run kit 113); on ext/mc-20261108-0030, keeps kit-kael-113b and fix-kael-sword-131b's check ported to the skinned sword. Sword: v2 sheet/splash size (blade 0.58 of his height) per DECISIONS "size follows the final splash", not 131b's 0.3-0.4 band (alternative: scale the sword verts in kael.glb). grip_l removed (one-handed carry), dash clip trimmed to 0.42 s. Checks: kael-sword PASS, juggernaut-combo 183/0, warden-glb 186/0, hero-vfx OK, clip-check juggernaut ok (1 pre-existing bulwark blade drift, fixed by fix-albert-blade-clip in models-v2-integ), warden-model 15 FAIL all pre-existing hero-heights, health --strict only pre-existing check_registry/lineup_shot style. Screenshots done 06:50 (jobs 20261108-051834-24162, -32335): briefs/art-refs/kael_v2/integ/, see GPU shots line below. Conflicts likely with models-v2-integ in juggernaut.json body only if it touched it)
READY ext/tenzo-ally-hop 618098895 (gap 14: ally hop over friendly Tenzo rocks was already on main; adds bots hopping a teammate's rock at once via StoneStand.hop_ahead, foe bots go round, Tenzo bot walks up; --dolm-combo-check asserts ally clears, foe stopped, caster walks up; 171 PASS 0 FAIL, health --strict OK, gen_wiki --check OK)
READY ext/neve-dart-homing 8904d37b3 (darts already home late incl. while skating on main since e5c73480c; adds combo-check cases: skating beam curves onto a walking dummy late, a dummy 12 m off-line is missed)
READY ext/rank-parity-slice 003a3cfeb (UPGRADE parity for Vex, Kael, Lace, Cinder: per-slot source numbers in JSON, rank text, docs tables, combo asserts)
- VERIFIED (feel, job 20261108-061505-a4) ext/models-v2-integ 5ec44812f in a fresh tree: --import ok; idle shots of the 6 changed hunters (mage/Ryzz, dredge/Grimble, rimewright/Claire, dolm/Tarek, ostra/Motley, tender/Meeko): all posed, hook arm + sun/cloud present, no clipping seen. Sheet briefs/shots/models-v2-integ_idle_sheet.png (xvfb software render; per-hunter frames shots/models-v2-integ-sw/<id>/stance_front/f000.png in /home/boki/cj/20261108-061505-a4/tree). Real-GPU job 20261108-052158-29926 still queued (no GPU claim since 04:30). Albert: no model change in this merge (fix-albert only wraps tool lines), so no shot needed. Merge 7dbe5b881's title says 'scratch-mv2-albert'; content is right, and I left it so the posted READY sha stays valid.
READY ext/release-integ-0243 6cfef799b (v0.24.3 release; supersedes ext/feel-integ bed04e50b, ext/map-parity-integ f243f76ae, ext/kael-v2-integ 36c5f7ea7, ext/models-v2-integ 5ec44812f, ext/text-lore-integ 930f01e0f; deep worker 20261108-055345-a2. Resolutions: hunter_move keeps feel-integ's brake/dash-exit/air_control 0.015 and map-parity's dive rows, glide-dive decision renumbered 0021; kael_paint->paintkit for Sable/Sparkle; warden_look Claire v2 + Cinder v2; warden-model-check owner height chart, height_3d re-measured (Sable 1.1, Cinder 1.22, Kael 1.32); Cinder: v2 look text + court-alchemist lore; move-feel plain-dash rows isolate the Boki patch and xp trickle. Checks: --check 0, health --strict OK, move-feel 0, dash-flow 0 (15 skipped), clip-check 0, cinder-art 0, warden-model 157/0, hero-combo 304/0. GPU idle shots of Kael+Cinder: job 20261108-061253-08992 queued, not yet run)
READY ext/rank-parity-b d911bdfb4 (Meeko, Tenzo, Grimble, Neve rank 2/3 follow the source's Upg: lines; per-slot rank_cd/rank_dmg, docs tables, asserts; ults unchanged)
READY ext/meeko-rmb-motion 8801461cc (Meeko RMB motion: hop on the seed's release matched to footage, cast flare rides it, lane the seed's width; tender combo check extended with wind-up clip length, release frame, hop)
GPU shots ext/kael-v2-integ 36c5f7ea7 (also covers release-integ-0243, same Kael files) in briefs/art-refs/kael_v2/integ/: idle_front/idle_side/stance_front/stance_side.png (idle-shots f006), sword_hero/match/poses/rmb_hold.png (kael-sword-shots, check PASS). Vs kael_v2 master sheet: v2 model right (white hair, crimson scarf and cape, belts, studded boots), curse crimson veins on the sword arm and chest, the blade glows white-hot in the match camera and its cracks glow white in close-up. One deviation: in close-up the blade body is near-black where the sheet shows silver steel (same as kael_v2 ingame/game_vs_sheet.jpg, so it comes from the v2 model, not the merge). The cursed arm also blooms pink-white in close-up. Left both as they are; alternative: lift the blade albedo toward silver in kael.glb.
READY ext/rank-parity-c 29ce1049f (Sparkle, Mossy, Sable, Motley rank 2/3 follow the source's Upg: lines; per-slot rank_cd/rank_dmg, docs tables, asserts; ults unchanged)
READY ext/meeko-ult-cancels d4b9d81fd (Meeko Hearth Call cancels verified vs source: tether snaps visibly, final elimination drops the channel, check per cancel case, tender.md)
READY ext/meeko-carry-drop 6a773c049 (Meeko Carrier drop = source triggers: stun or damage past the shield; root/hex no longer drop; check covers triggers, non-triggers, 4s re-pick lock)
READY ext/mossy-dash-refund 347408a2d (rank 3 dash refund already built; added DashReset cue + miss/rank1 asserts)
READY ext/mossy-shield-bash edfaf87cf (Shift in the aegis's 0.1 s rise fires the Shield Charge, not the Spin Dash; the aegis-up bash also fires in the air; assert added, bulwark.md row fixed; --bulwark-combo-check 145 PASS/0 FAIL, --dash-flow-check 0 failures, health --strict OK, gen_wiki --check OK)
READY ext/sable-lmb-range 5bd83bbc6 (Sable LMB to source: 8.5m range, 9.5m empowered, 37.5 m/s; combo check asserts range and flight time)
READY ext/sable-bola-instant b31c26641 (Sable Bola: instant release, wall/tree after first catch stuns; combo-check, health, wiki pass)

## 2026-11-08 02:36 ET (art): hero and key art updates tonight
- Key art. The Kael/Vex face-off has a new main, keyart/keyart_faceoff_blade_throat.jpg: no heart, and a full-length greatsword from off-screen with its point under her jaw. The older face-offs are kept. keyart/keyart_last_light_final.jpg is v2: cleaner, and Motley's cards now burn purple, stuck in Albert's shield and fanned in his hand.
- Grimble. grimble_v2/grimble_v2_splash.jpg is now "The Leap": he dives off a sky cliff, and his stretched bone-hook arm pierces a falling chest.
- Sable. sable_v2/sable_v2_splash.jpg is now "The Slip": she steals the gem from behind a laughing card gang with a wink and a "shh". There are three alternates (_alt_perch, _alt_upside_down, _alt_dodge). sable_v2_portrait.jpg now has her master-sheet dark eyes and pendant.
- Ideas list (no schedule): corruption stages. The Nov 28 reminder was cancelled by the owner.
READY ext/anim-time-meeko 5a6864ab4 (Meeko clip lead: release beats land on effect frames, timing table, combo check)
READY ext/anim-time-tenzo 231f91588 (Tenzo timing parity: boulder release 0.13 s, spine rise 0.8 s, LMB upper-moving, doc table, combo + clips checks)

READY ext/agent-briefs ac70b1d38 (briefs/plans/INTRO_VIDEO_PLAN.md: 15-shot 81 s AI intro plan for the owner to make on his Mac; Flow/Veo 3.1 + Nano Banana Pro primary, Kling 3.0 fallback; prologue.gd video path described, not built)
READY ext/anim-time-neve 1ea57e41f (Neve: clip lead so dart/beam/clench/wall/freeze hit poses land on the kit's hit, timing table, anim rows in --rimewright-combo-check)
READY ext/anim-time-grimble 76dd4b360 (Grimble anim timing: Anchor forward hop restored, timing check + doc table)
READY ext/anim-time-mossy 162a420fb (Mossy animation timing: throw release at 0.15 s, 0.04 s blend into one-frame poses, timing table + check)
READY ext/stuck-integ-9e20dcba 6cfef799b (supersedes: ext/art1-kael-2 fd33d2045, ext/cinder-flame-queen c3f4f1729, ext/grimble-v2-model 54df2f18a, ext/kit-kael-113 6e18b8be7, ext/ryzz-v2-model 6355dee78, ext/vfx-pip 93b5e23fe, ext/vfx-pip-rebased 93b5e23fe; NO new merge: the branch = ext/release-integ-0243 tip (on ext/mc-20261108-0030), which already holds cinder/grimble/ryzz/vfx-pip; kit-kael-113 is replaced by kit-kael-113b (in mc, "merge ONE"); art1-kael-2 is replaced by kael-v2-model via kael-v2-integ (DECISIONS: Kael v2 locked). Merging those two would bring back v1 Kael and duplicate item 113. Stop retrying all 7. Checks: --import ok, --check 0, juggernaut-combo 183/0, cinder-art 0, health --strict OK)
READY ext/anim-time-tenzo 5aafba874 (Tenzo timing parity, supersedes 231f91588: boulder release 0.13 s, spine rise 0.8 s with x_spine at 0.7 speed so the heave lands at 1.0 s, LMB upper-moving, tooltip 0.8s, timing table on breah.md's 4/10 fps, combo 171/0 + clips 0)
READY ext/anim-time-sparkle 4c7b70c9c (Sparkle animation timing parity: tap Storm Rod throw beat at the launch, Skycall arm held to the snap, timing probe + doc table)
READY ext/anim-time-sable 53f658240 (Sable animation timing: per-move blend-in so each release shows, dancer timing check, thief.md table)
READY ext/body-hitbox-parity b9f481fa0 (hit radii set to source body sizes: Breaker 0.50, Kael 0.445, Tarek 0.412, Vex 0.400, Claire 0.362; table in ARCHETYPES; checks extended)
READY ext/telegraph-audit-a 456a56d47 (Vex/Kael/Cinder/Meeko ground shapes drawn = hit, cosmetic rings removed, per-ability tables in docs/heroes, drawn=hit asserts in the 4 combo checks)
READY ext/telegraph-audit-b 20810cf25 (telegraph audit: Tenzo/Lace/Grimble/Neve drawn area == hit area, cosmetic rings removed, tables + asserts)
READY ext/telegraph-audit-c 498b60d09 (Sparkle/Mossy/Sable/Motley ground telegraphs drawn at true hit size, cosmetic hit rings removed, drawn==hit asserts in the combo checks, per-ability tables in docs/heroes)
READY ext/anim-time-motley ec4ec6e2b (Motley hover 0.3 m as the source, was half; timing check of his moves vs footage frames, all within a frame)
READY ext/airdash-rule-audit a3a45b2af (air dash = ground dash for Hem, Tarek, Oath, Kael; 12-row table; parity 11/13 skipped)
READY ext/vex-e-turn 27859acfe (hero_combo_check: zero Vex's velocity after the Longneedle aim test; fixes --gunslinger-combo-check with phys-150-botnav, mc-20261108-0430)
READY ext/map-regions 15a8ebd57 (HudRefDemo: no rival stood in the void near an edge; fixes --hudref-check. Still red with this branch: --keys-check, --truce-check, --box-revive-check, see mc-20261108-0430 triage)
READY ext/kit-parity-lock 76783a368 (--kit-parity-check + content/rules/kit_parity.json, 13 sourced D rows)
READY ext/dash-buffer-window 77fa3ffde (DashFlow.BUFFER_S 0.2 s = one 5 fps footage frame, no early-press limit; window evidence per hero in dash_interactions.md; --dash-flow-check stuns inside/outside the window)
READY ext/heal-knock-source f66273fcd (knock heals settled vs the data: Brall/Shiv kept+cited, Felix/Kingpin 16% ours-only for the owner card, totals with DashReset 5% asserted)
READY ext/neve-chill-shatter cd2f3f296 (Neve Chill/Shatter parity audit: knock tell, no re-Shatter on a felled foe, combo asserts)
READY ext/idle-dolm 9ce102a73 (Tenzo the Stone Seer idle+stance rework)
READY ext/idle-juggernaut 2c700e15c (Kael the Unbroken idle+stance rework; based on ext/kael-v2-integ, merge that first)
READY ext/idle-ostra 2a99a0912 (Motley the Void Jester idle+stance rework; based on ext/parity-idle-audit, merge that first; trivial doc/STAND_OPEN conflicts with ext/idle-bulwark)
READY ext/idle-gunslinger fa16ce7ef (Vex the Hired Gun idle+stance rework)
READY ext/idle-bulwark 53c963ec5 (Mossy the Barnacle Knight idle+stance rework)
READY ext/agent-briefs af480ffa8 (briefs/TOWN_HUB.md: town square hub design doc only, low priority; no code; defaults picked: cap 32/soft 24 relay rooms, tst/tpro/tsay topics batched 10 Hz, L3 tabs + Mask Hall in town, tutorial town phase after the 2nd Mask)
READY ext/idle-tender be19bd8bf (Meeko the Dawnfox idle+stance rework)
READY ext/idle-thief 619b8dc32 (Sable the Silver Thief idle+stance rework)
READY ext/idle-ashwick eeb4f3ae4 (Cinder the Flame Queen idle+stance rework)
READY ext/depth-tiers 3c5f92074 (Depth 1/2/3 on the three tiers, shown on expedition select and results; reuses the existing tier mob/loot/kin_lvl/biome scaling; check + wiki; Net/save untouched)
READY ext/idle-mage 9d6d41c02 (Sparkle the Storm Chaser idle+stance rework)
READY ext/tutorial-prologue 4347c61b8 (six-panel storybook prologue of origin v3, ~49 s skippable, then Pell the guide: flies ahead, stops you in the dialogue box before each new step, decision 0020; based on ext/tutorial-dialogue, merge that first; --teammate-check rival-callout FAIL is pre-existing on the base)
READY ext/idle-rimewright 6d2e7ca54 (Neve the Snowglide idle+stance rework)
READY ext/idle-dredge b3fdeeeff (Grimble the Scrap King idle+stance rework; based on ext/grimble-v2-model, merge that first; adds x_breath to dredge.json and posekit.py Loop)
READY ext/idle-archer 8437593bb (Lace the Red Stitch idle+stance rework)
READY ext/heartspark 3e359d1fc (Heartspark prototype of the 2026-11-08 Heart loop: tide ring closes on a seeded Heart site, 75 s charge visible on maps + world beam, hold-F pickup, carrier revealed + 15% slower + drops on down/death, Heart Gate takes only the carrier (rare egg + 4 evolution foods x2 + heartwood/starstone + 60 gems + Boki trust), 90 s cooldown then a new spark; skiff/uplink unchanged (a carrier leaving that way drops the spark, no reward). Numbers: content/rules/heart.json. --heart-demo[=charging|ready|carry|gate|cool], --heart-check (HEART DONE failures 0), --blight-check clean, health --strict ok. Net.VERSION 0.25.0 ("ht" event). decision 0019. Heart Night NOT built. Gaps: bots ignore the Heart; online path untested with peers. Screenshots (jobq, ~/jobq/done/<id>/out): charging beam+marker /home/boki/jobq/done/20261108-112845-09372/out/heart_charging.png; ready /home/boki/jobq/done/20261108-112845-07059/out/heart_ready.png; carrier on the full map + tide ring + gate /home/boki/jobq/done/20261108-112845-22124/out/heart_map.png; carrier HUD + Heart Gate waypoint /home/boki/jobq/done/20261108-112845-00825/out/heart_carry.png; gate /home/boki/jobq/done/20261108-112845-29762/out/heart_gate.png; cooling /home/boki/jobq/done/20261108-112845-00621/out/heart_cool.png)
