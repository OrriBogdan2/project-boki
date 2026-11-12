# Source map utilities, shops, regions, hot zone and train

Research for the owner's Nov 7 decision "Utilities and shops" (briefs/DECISIONS.md on ext/agent-briefs): copy all of the source's map utilities under our own names and art, sell them in the in-match shops, and give every shop its own **fixed** set. Our names below are proposals; nothing here is built yet. The build job is ext/utilities-shops.

**Which version.** The source's last patch was 2.04 (Dec 17 2025); live service ended Feb 25 2026 [S-sunset]. "Final" here means 1.0 (Jul 24 2025) to 2.04. The wiki item pages are mostly from before 1.0 (the "Powers" era, which 1.0 retired: some powers became consumables, others relics or perks [W-Powers]). Where only a pre-1.0 number exists, it is marked *(pre-1.0)*. **[?]** = not confirmed for the final version.

Source currency is gold ("Coin" from 1.0). Ours is run gems. Proposed gem prices use **gems = 30 + gold / 100**, rounded to 5. This keeps the cheap staples near today's tonic (30) and armor kit (40). Items we already have keep their price.

## 1. Source utilities, mapped to Boki

The Boki and Status columns are the Nov 8 audit, before the builds below; what each item does now is in
"Every belt item: source vs ours" near the end.

Status: **have** = we have an equivalent. **differs** = we have one, but it works differently (see notes). **missing** = we don't have it. **skip** = it needs a system Boki doesn't have.

### 1a. Sold in the source's shops (final version)

| Source item | What it does (numbers) | Price, stack | Boki | Status |
|---|---|---|---|---|
| Vive Brew | Restores 304 HP and 120 mana after a 1s drink. You are Vulnerable while drinking, and taking damage cancels it. Cleanses anti-heal [W-ViveBrew]. Has a fixed slot (slot 1) [W-Consumables]. Every shop sells it [W-WorldObj]. Holding the key chains drinks (1.02) [P-1.02] | 200 gold, stacks to 8 [W-ViveBrew] | `tonic` Tonic | **have**. Ours heals 40% HP, has no mana and is "open while you drink". Close enough. |
| Portable Armor Repair / Armor Shard | Press to repair 1 bar of armor (1 bar = 500 armor), with a short cast [W-PAR]. Has a fixed slot (slot 2). From 1.0, armor is repaired only with Armor Shards or at the Forge [P-1.0]. From 1.04 a repair restores more on low tiers: grey 2000 (80%), green 1000 (40%), blue 750 (30%) [P-1.04]. Every shop sells it [W-WorldObj] | 400 gold, stacks to 8 [W-PAR] | `armor_kit` Armor kit | **have**. Ours repairs to full and leaves you open. Source repairs part of the bar, more on low tiers. |
| Hypervive | Slows you by 60% and makes you Vulnerable for 5s, then fully restores HP and mana. Taking damage cancels it [W-Hypervive] | 1,000 gold (2,000 → 1,000 in Feb 2025) [W-Shops][P-Feb5], stacks to 1 | **Deep Draught** | **differs**. The closest we have is `medkit` (40 HP + 20 armor, instant). Proposal: add Deep Draught as a new item and keep the medkit. |
| Pocket UAV / Pocket Oracle | Marks enemy hunters on your squad's map for a short time [W-PocketUAV]. Removed from shops in 2.02 [P-2.02] | 1,500 gold, stacks to 2 [W-PocketUAV] | **Hawk Whistle** | **differs**. `scanner` Seeker flare reveals rivals within 26 tiles for 3s, around you only. The source covers the whole map but shows map marks only. Duration [?]. |
| Jump Pad | Placed pad. It arms after 2s and launches anything that steps on it. It lasts 30s, or 10s after its first use. Dashing into it keeps your momentum [W-JumpPad] | 3,000 gold (2,000 → 3,000 in Feb 2025) [W-JumpPad][P-Feb5]. Stack 1 → 2 in Season 2 [P-S2] | `jump_pad` Spring pad | **differs**. Ours lasts 20s, arms at once, and stacks to 3. Proposal: arm after 2s, last 30s or 10s after first use, stack to 2. |
| Emergency Platform | Over open air or hazards only. Makes a platform for 30s that refills ally gliders and gives vision [W-EmPlatform]. From 1.03 it casts after 0.3s instead of at once, and floats you during the cast [P-1.03]. Things you place on it stay after it fades [W-EmPlatform] | Added to every shop in 1.01 [P-1.01]. Cost 500 → 1,500 in 1.02 [P-1.02]. Stack [?] | **Cloud Raft** | **have** |
| Deployable Fan | Builds a fan at a target spot that launches anyone who touches it. Lasts 60s, 2 charges. Fan HP is 750 or 3,000 (the wiki gives both) [W-Fan]. Launches stack [W-Fan] | 1,000 gold [W-Shops] (2,000 as a power [W-Fan]). In the final version [?] | **Gust Fan** | **have** |
| Two-Way Teleporter → "Group Teleport" | Opens a portal at a target spot and one at your feet. After 8s you can reactivate to swap everything standing in each portal [W-2Way] | 3,000 gold [W-Shops]. "Group Teleport" was re-enabled in 1.05 [P-1.05] and its stack raised to 2 in Season 2 [P-S2]. Group Teleport = Two-Way Teleporter renamed [?] | **Twin Gate** | **have** |
| Pocket Anomaly | Places a warp anomaly that works like the ones in the world: step in, channel briefly, then get teleported somewhere random. The world anomaly behaves like Anywhere But Here [W-ABH][P-Jan8]. A placed one disappears after a timer [P-1.02] | 3,000 gold, new in 1.02 [P-1.02]. Stack raised to 3 in Season 2 [P-S2]. Timer [?] | **Warp Seed** | **have** |
| Most Wanted | Starts a 2-minute timer and reveals you to every enemy. If you survive, all your allies are revived and gain XP, and you get a rare or epic reward. Knocks, kills and assists shorten the timer. If you are knocked while carrying it, you go straight to your deathbox and the team that knocked you takes the reward. One per team at a time. It also spawns in the world at night [W-MostWanted][S-data §10] | 3,000 gold [W-MostWanted][P-Feb5] | **Bounty Banner** | **have** |
| Mobile Respawn Beacon | Places a respawn beacon for your squad. It can be set on temporary terrain [W-Beacon]. Final revive time on a beacon: 6s, then 12s of resurrection sickness (−25% damage and healing) [P-1.0] | 8,000 gold [W-Beacon][P-Feb5] (25,000 in Jan 2025 [P-Jan8]) | **Hearth Lamp** | **have** |
| Tactical Nuke | Calls a warhead on a target spot. It lands after 5s, deals 5,000 damage, and leaves fire that deals 720/s for 3s. It hurts you and your allies too, and destroys beacons and basecamps [W-Nuke] | 3,000 gold [W-Shops]. Shop in the final version [?] | **Skyfall Charge** | **have** |
| Mass Heist | Target a spot and channel for 1.5s. Raccoons steal items and gold there, including 50% of a hunter's gold and loot from unopened vaults [W-MassHeist] | Shop, price unknown ("XXXX") [W-MassHeist] [?] | **Pilfer Pouch** | **have** |
| Basecamp Recaller | After a 4s channel, pulls your basecamp and everyone standing on it to you [W-Basecamp] | 1,000 gold [W-Basecamp] | — | **skip**: Boki has no capturable basecamps |
| Basecamp Deployment Beacon | Drops a basecamp your team owns. It deals 650 damage where it lands. You get it by packing up your camp for 800 gold [W-Basecamp] | 5,000 gold [W-Shops] | — | **skip**: no basecamps |

### 1b. Found only in the world (not sold)

| Source item | What it does (numbers) | Where found | Boki | Status |
|---|---|---|---|---|
| Anywhere But Here | Channel for 4s, then teleport to a random spot inside the next circle. Works inside the storm, so it can replace a recall [W-ABH] | World only, rare, stack 1 [W-ABH]. It made up 14% of Little Helper drops (pre-1.0) [P-Jan22] | **Lostway Scroll** | **have** |
| Ethereal Smoke | You and nearby allies get stealth and +50 move speed for 30s. Stealth breaks in combat or within 1,500 units of an enemy hunter [W-EthSmoke], and on dash [P-Jan8] | World [W-EthSmoke] | `smoke` Smoke bomb | **differs**. Ours is a fixed cloud that hides everyone inside it for 8s. Keep ours; the source's is a moving team cloak. |
| EMP / Disruption Grenade | Thrown. Bursts 0.3s after landing: shreds 1,600 armor and slows enemies by 30% for 2s. Neutralizes enemy basecamps [W-EMP] | World, common [W-EMP] | **Shatter Charge** | **have** |
| Storm/Death Circle Grenade | Makes a pocket of storm. It grows for 15s, holds for 10s and shrinks for 15s. Damage scales with the night [W-DeathCircle]. It blocks all healing inside it [P-2.0x] | World [W-DeathCircle] | **Blight Flask** | **have** |
| Scanner Ward (Scan Grenade) | Thrown ward. Gives vision for 60s and reveals stealthed enemies. Enemies stay visible for 3s after leaving its view. Anyone can pick one up, including enemy wards [W-ScanGren] | World, stacks to 4 [W-ScanGren] | **Lookout Lantern** | **have** |
| Spike Wall | You root yourself for 2s to build a wall (3s → 2s in Feb 2025 [P-Feb19]). The wall damages hunters who touch it, based on their speed [W-SpikeWall] | World, stacks to 10 [W-SpikeWall] | **Thorn Wall** | **have** |
| Prophet's Potion | Channel for 1s: your team sees future storm locations for 30s [W-Prophet] | World, uncommon [W-Prophet] | **Omen Draught** | **have** |
| Vive Packs | Throws a health pack that lasts up to 30s. Whoever picks it up heals 140 HP/s for 5s, until hit. If they're in the air, it also bounces them up. 2 charges [W-VivePacks] | World, epic [W-VivePacks] | **Toss Satchel** | **have** |
| Gold Key | Points to the nearest golden chest and opens it. Can also open a vault instantly [W-GoldKey] | World, rare [W-GoldKey] | `chest_key` Chest Key | **have**. Ours pings and opens locked chests. It doesn't open vaults. |
| Evil Key | Points to the nearest evil chest (exotic loot). Dropped by PvP combat [W-EvilKey] | PvP drop [W-EvilKey] | `rift_key` Rift Key (nearest) | **gone** on the 0.24.6 line: 0.24.5's Ways Out has no hatches for it to open. |
| Orb of Life / Orb of Revival | Revives your team; revives at full HP from 1.03 [P-1.03]. Final-boss reward from Season 2 [P-S2] | Boss only [P-S2] | **Revive Ember** | **have** |
| Tome of Knowledge / Codex of Mass Enlightenment | 1s channel. The Tome gives +20% of a level's XP (Academy only); the Codex gives the team +1 level [W-Tome][W-Codex] | World | — | **skip** [?]: only if Boki gets in-match levels |
| Little Cook, Snowball, Chonker Cannon, Penguin Egg, Avalanche, Present, Tree Costume, Money Tree | Event and power-era fun items, e.g. Little Cook makes 8 consumables over 32s, cooldown 150s [W-LittleCook]. They are listed as consumables [W-Consumables], but the only final-version notes are Little Cook buffs in 1.02 [P-1.02] | Vaults, bosses, events | — | **skip for now**: seasonal; revisit for events |

### 1c. Built-in (not items) and our extras

| Source | Numbers | Boki | Status |
|---|---|---|---|
| **Teleport to a teammate**: in the final source this is not an item. B recalls you to your claimed basecamp or any living ally, at any time [P-1.0]. 4s channel, cancelled by damage, and others can see it [W-Basecamp]. On arrival at an ally: 3s slow and silence (1.0) [P-1.0] → 5s silence and a 50% decaying slow [P-May28] → from 1.03, 30% damage dealt and 30% crowd-control duration for 5s [P-1.03] | see left | B "base to a teammate" (scripts/match/hunter.gd): 3s channel, then 3s weakened with half damage and half CC | **have** (numbers differ: 3s channel/3s weak vs 4s/5s at 30%). The group version is Twin Gate. |
| Free mini-UAV at capture points, every 60s (1.04) [P-1.04]. Oracle scanners: world objects that show rough positions of everyone [W-WorldObj] | 60s | uplinks/outposts | partly have [?] |
| — | — | `shield_cell` Shield cell (40 shield, 8s), `stim` Swift draught (+35% speed for 6s), `medkit` Mending kit | ours only. Nearest source items: Elixir of Speed and Elixir of Health (1,500 gold each, Feb 2025 [P-Feb5], gone by 1.0 [?]). Keep. |

## 2. How the source's shops worked

- **Final (1.0+): two shop kinds, spread over the map "to encourage map movement."** Base Shops sell Grips and Kicks. Relic Shops sell Relics and Perks [P-1.0]. Every shop also sells Vive Brew and armor repair [W-WorldObj]. Shops sell only gear you've unlocked in your Armory, so stock is per player, not rolled per match [P-1.0]. Forges (marked OUTPOST) always have a Relic Shop, an extractor and an armor-repair zone [W-WorldObj].
- **Timing:** Day 1 sells only Grips, Kicks and consumables; Relics and Perks unlock on Day 2 [P-1.04]. From night 2 (about 7:05), extra Relic Shops are airdropped each night if the next circle has fewer than 2 [P-1.02]. Perks left the shops in 2.03 [P-2.03].
- **Consumables** were one set sold everywhere (Emergency Platform "added to all in-game shops" [P-1.01]). The final per-shop consumable list was never published [?]. Remote shopping ("V") and item queueing came in 1.04 [P-1.04].
- **Before 1.0 (precedent for distinct shops):** each region's shop had its own default powers "that you can reliably find" [P-Jan8]. Examples: Chaos Steppes sold Chonker Cannon [W-Chonker], Scavenger Bay Emergency Platform [W-EmPlatform], Veingrove Little Cook [W-LittleCook], Shards of Fate and Frag Isle Snowball and Present [W-Snowball][W-Present], The Heart Tree Costume [W-TreeCostume]. Basecamp shops held a fixed set of 4 powers that rotated every real hour, priced 1,000/1,000/1,500/2,000 [P-Feb19].
- **Takeaway for us:** the owner's fixed, per-shop sets match the source's pre-1.0 regional shops. They differ from 1.0, where every shop sold the same consumables. We copy the source's one rule that every shop sells the two staples (heal and armor repair).

## 3. Proposed fixed stock per Boki shop

This replaces the random `pool`/`stock` roll in content/rules/shops.json (ext/shops, not in main yet). Each shop sells its **whole** list every match. **Staples in every shop: `tonic`, `armor_kit`** (as in the source). Everything else appears in exactly one shop, so each set differs and players can plan drops around them. Keys, shards and boss rewards (Revive Ember) are never sold (the existing `never` list).

| Shop (island, theme) | Fixed stock besides staples | Why here |
|---|---|---|
| **Plate and Patch** (Frostgate, armor) | armor_up, repair, `shield_cell`, `medkit`, Deep Draught (40), Hearth Lamp (110) | the north Keep is where you level up and hold, so it sells recovery and the respawn beacon |
| **Swift Stall** (Stormbreak, move) | backpack, boots:quickstep_boots, `jump_pad`, `stim`, Cloud Raft (45), Gust Fan (40), Twin Gate (60), Warp Seed (60), Lostway Scroll (60) | the east tableland with its launch pad to Shardfall: movement and escape |
| **Gadget Cart** (Cinder Steps, fight) | `smoke`, Shatter Charge (45), Thorn Wall (40), Blight Flask (50), Skyfall Charge (60), Pilfer Pouch (60) | the west forge country faces the Crown: siege and control tools |
| **Perk Peddler** (Thornwood, perks + scouting) | perks (as on ext/shops, fixed list), `scanner`, Lookout Lantern (40), Hawk Whistle (45), Omen Draught (40), Bounty Banner (60), Toss Satchel (45) | tall-grass ambush wood: information, and the high-risk Bounty Banner |

- Prices in brackets are proposals (gems = 30 + gold/100). For world-only source items I used the price of their closest sold item.
- **Alternative (not chosen):** no shared staples, each item in exactly one shop. I didn't choose it because it forces every squad to one shop for heals.
- If more shops are added later, split the longest list (Swift Stall) first.
- **Owner's word wins over the source:** Lostway Scroll, Omen Draught, Thorn Wall, Shatter Charge, Blight Flask and Toss Satchel were world-only in the source. The owner said to sell them, so they're in shops. They can also stay in chest loot.

## 4. What each source region was for

The Breach has 8 regions [W-Breach]: Scavenger Bay, Forest, Snow, Abyssal, Fallen Splendor, Chaos Steppes, Desert, and Kobayashi's.
- **Kobayashi's** (town): PvP is banned by day. Damaging a player there makes you a Criminal, and guards hunt you; PvP is open at night [W-Breach]. Its biome leaders drop many power-era items (Rally, Two-Way Teleporter, Nuke, Fan) [W-2Way][W-Nuke][W-Fan].
- **The Heart** (centre): an unlimited revive "Everbeacon" [S-data §9][W-2Way].
- **Academy / Fallen Splendor:** XP books, the Tome of Knowledge (only found here), and a giant warp anomaly that teleports you "anywhere" [W-Tome][P-Jan8]. Fallen Splendor's leader dropped Money Tree Seeds [W-MoneyTree].
- **Chaos Steppes, Forest, Desert, Snow:** regional shops and biome-leader drops (section 2) [W-Chonker][W-LittleCook][W-Snowball].
- **Gold armor:** the hot zone (section 5), Day 1 boss rewards ("Gold Armors", "Blue Armor") from Season 2 [P-S2], and supply drops (gold crate = gold armor) *(pre-1.0)* [W-SupplyDrops].

Boki already gives each Hollow Crown region a `purpose` in content/maps/hollowcrown.json. For the shops in section 3: Frostgate = recovery, Stormbreak = mobility, Cinder Steps = siege, Thornwood = scouting.

## 5. Source hot zone (= gold armor zone)

- **How it's chosen:** at the start of every drop phase, random biomes become **Gold Armor Hot Zones** *(pre-1.0)* [W-HotZone]. From Oct 2024 any biome can be picked (before that, only outer ones), the train can be one, and there is a 25% chance (was 10%) that all gold armor lands in one biome [P-Oct24]. A central **Blue Armor** hot zone (2 blue armor in its vault) and a **Kaiju-vault** zone also existed *(pre-1.0)* [W-HotZone].
- **Loot boost:** many extra chests across the biome, with early gear and a chance of gold armor, plus the zone's vault [W-HotZone]. Totals: 4 gold armor [W-HotZone]; "2 or 4 legendary armors", rarely exotic (Jan 2025) [P-Jan8]; in trios the zone vault holds 1, for 3 in the zone (Apr 2025) [P-Apr2]. It was still in the final game: "Gold Armor zones as a hot drop option" (1.04) [P-1.04].
- **How it's shown:** on the drop map and the map, the zone's name is orange with an orange vault + shield icon [W-HotZone][W-Vaults].
- **Drop update (2.02):** in about 1 match in 3, squads pick a drop point along a rotating zone. After one full turn, anyone left is auto-launched [P-2.02].
- **Boki (owner Nov 7):** one hot zone per match, better loot, shown on the drop map and minimap. That matches the source's single-biome case. Being built on ext/map-regions.

## 6. Source train

- One train runs the map's tracks **clockwise without ever stopping** [W-Train]. It is not a fast-travel line with stops. Long-distance travel in 1.0 used Skysharks (2-seat, fuel-limited, faster over the abyss) plus wind rings and tunnels [W-Skysharks][W-WorldObj][P-0828].
- **Front:** a locked chest opened by a 4-square match puzzle (one square per car). Inside: 4 powers, 4 backpacks and one of each weapon; it upgrades each day *(pre-1.0)* [W-Train]. It always holds a legendary at the start (Jan 2025) [P-Jan8]. In 1.0, Grips, Kicks and Relics can be found on the train [P-1.0]. The best item is shown on the map [W-Train].
- **Second-to-last car:** a box that grants circle (storm) immunity until endgame [W-Train]. **Rear car:** a revive Everbeacon [W-Train][W-2Way].
- **Bullet Trains** storm shift: 3 shorter, much faster trains [W-Train].
- **Boki (owner Nov 7):** the sky train *is* the fast travel, a winding loop with stops (scripts/match/sky_train.gd already stops at piers). The owner's choice wins. Worth copying: the storm-safe car and a beacon car [?: owner].

## Built Nov 8 (ext/utilities-shops)

Every row above marked missing is now an item in `content/utility/` (Boki names). Where a number
changed on the way: Deep Draught, Jump Pad and Seeker use the numbers in their JSON. A few
deviations:

- No storm in Boki: Blight Flask is a Blight zone, Omen Draught shows the Blight Wardens (your team only),
  Lostway Scroll warps you to a random spot on the map.
- Shatter and the other thrown items hit foes only. Pilfer Pouch destroys the gems; the thrower does not gain them.
- Revive Ember is never sold: a rare chest find only (no boss drop is wired).
- Online, gates, seeds and pilfer move only the bodies this game owns, like the spring pads.
- Each shop sells a fixed list (`sells` in content/rules/shops.json), the same every match.

## Built Nov 9 (ext/utility-parity)

Behaviour brought in line with the source, each number in the item's JSON `src` field:

- Six belt slots: 1 and 2 pinned to the tonic and the armor kit (`slot` in their JSON), 3 to 6 open.
  Pinned items stack to 8. The home belt picks the open slots only (`UtilityBelt.free_slot`).
- Tonic: 1.0 s drink, no slow, a flat 42 health (`channel.heal`; the source's 300 over our HP ratio).
- Armor kit: 1.6 s at 45% speed, repairs 80 / 40 / 30% of the armor bar by armor tier (`channel.repair`).
- Deep Draught slows you to 40% for its 5 s. Thorn Wall stacks to 10.
- Skyfall Charge: 5 s fuse, a lethal blast (690) then a 3 s fire patch on the spot.
- Bounty Banner: knocked under it you are out at once (no wisp, no spare life) and the knocker
  pockets the reward.
- Blight Flask: a 40 s patch that blights (healing in it barely takes) besides burning and slowing.
- Checked by `--utility-parity-check` (banner, skyfall, blight) and `--equal-check` (slots, tonic, kit).

Still ours, on purpose or for lack of a system: Lostway has no circle to aim for, smoke does not cloak
the team, prices and bring caps follow our economy.

## Built Nov 10 (ext/utility-parity-2)

The rest of the Nov 9 list, each number in the item's JSON `src` field (source numbers over the HP ratio 7.2):

- Twin Gate: opens two gates for 30 s; once 8 s have passed, pressing the item again swaps everyone in
  each gate and closes them (no second charge). One pair per hunter at a time. No auto swap any more.
- Pilfer Pouch: a 1.5 s channel (you stand rooted; knocked meanwhile and nothing happens), then half the
  gems of every rival in the circle go and every locked chest there is emptied (the loot is lost, not taken).
  Our locked chests are the vaults.
- Skyfall Charge: the blast hurts allies and the thrower too (`friendly`) and wrecks revive beacons (`raze`).
- Gust Fan: 104 HP (750 / 7.2, the wiki gives 750 or 3000); a rival's bullet stops in it and hurts it.
- Lookout Lantern: anyone who steps on it after 2 s takes it onto their belt (a rival's too, if there is room).
- Toss Satchel: a body in the air within 4 m above the pack is thrown up (14 m/s) and the pack is used up.
- Thorn Wall: you are rooted 2 s and the wall rises when the root ends.
- Revive sickness: 12 s after any beacon revive (Hearth Lamp included) now cuts healing by a quarter as
  well as damage (`sickness_heal` in Life). It is a status on the plate and the squad row (heart icon, seconds
  left) and rides the hunter snapshot (`sk` pair in HunterNet; Net.VERSION 0.26.1 there, 0.26.3 on the 0.24.6 line).
- Tonic: lifts anti-heal (blight) before its heal, so the heal is whole.
- Bounty Banner: each knock the squad makes takes 15 s off the timer (the source gives no number; assists
  and kills count only through the knock).
- Cloud Raft: squadmates on it or gliding within 6 m of it get their glider cooled, 2 gliders' worth a second.
- Checked by `--utility-parity-check` (one block per item).

Online, as with the gates and seeds before: razed beacons, raided chests, fans shot down and lanterns
taken are handled by the game that did it; the other games are not told (no Net change).

## Built Nov 11 (ext/feel-utility-move): using an item and moving

How pressing a belt item treats your movement, settled from the wiki pages and patch notes above (the footage
is not on this worker, so anything only footage could settle is [?]). Columns: what the source says about the
cast, moving while it runs, a dash and a hit; then ours. Checked row by row by `--utility-parity-check`
(MOVES: on the ground, mid-air, mid-dash, while hit).

| Item (source) | Source | Ours | Status |
|---|---|---|---|
| Tonic (Vive Brew) | 1 s drink, Vulnerable while drinking, cancelled on taking damage [W-ViveBrew]. Holding the key chains drinks [P-1.02]. Nothing on moving or dashing | 1.0 s at full speed, run kept; folds the glider; a hit spills it, nothing spent; a dash spills it, and a press mid-dash is denied (was: started and spilled the same step) | have. Moving, gliding and dash [?] |
| Armor kit (Portable Armor Repair) | "a short cast time" [W-PAR]. Nothing on moving, dashing or damage | 1.6 s at 45% speed (ours), a hit or a dash spills it | have. Length, slow, hit and dash [?] |
| Deep Draught (Hypervive) | 5 s, slows you 60%, Vulnerable, taking damage cancels it [W-Hypervive] | 5 s at 40% speed, a hit spills it | have. Dash [?] |
| Lostway Scroll (Anywhere But Here) | "Channel for 4s" [W-ABH]. The recall it replaces is cancelled by damage [W-Basecamp] | a 4 s drink at full speed, a hit spills it | have. Whether you may walk [?] |
| Omen Draught (Prophet's Potion) | "Channel for 1s" [W-Prophet] | a 1 s drink at full speed, a hit spills it | have. Walking and hit [?] |
| Thorn Wall (Spike Wall) | "Root yourself for 2s" [W-SpikeWall] | rooted 2 s, Shift denied while rooted, a hit changes nothing, the wall rises after | have. Hit [?] |
| Pilfer Pouch (Mass Heist) | "Target a location and channel for 1.5s" [W-MassHeist] | rooted 1.5 s, Shift denied, a hit changes nothing, knocked and the raid is off | have. Whether the source roots, and a hit [?] |
| Cloud Raft (Emergency Platform) | "Only usable if you're over abyss or hazards" [W-EmPlatform]; "casts after 0.3s instead of instantly; if used over Abyss floats the caster for this duration" [P-1.03] | **FIXED**: denied unless you are over the abyss; held in the air (no fall) for the 0.3 s, then the raft forms under your own feet (before: it could form a terrace above you or miss your tile) | closed. A hit during the cast [?] (ours: the charge is spent at the press, the raft comes) |
| Twin Gate (Two-Way Teleporter) | no cast noted for the consumable [W-2Way]; the power-era Two-Way Tunnel had a cast, 1.5 s → 0.75 s [P-Feb19] | at once, run kept | have. Whether 1.0's Group Teleport kept the 0.75 s cast [?] |
| Jump Pad | "Place a jump pad" [W-JumpPad], no cast noted. Riding it: "Dashing into jump pads preserves forward momentum and provides a small speed boost" [W-JumpPad] | placed at once; a body on the pad keeps the faster of its speed and the pad's push, no extra boost | have. The boost [?] |
| Gust Fan, Skyfall Charge, Shatter Charge, Blight Flask, Lookout Lantern, Toss Satchel, Hearth Lamp, Warp Seed, Hawk Whistle, Bounty Banner, Revive Ember | thrown or placed; no cast, slow or cancel noted on any page [W-Fan][W-Nuke][W-EMP][W-DeathCircle][W-ScanGren][W-VivePacks][W-Beacon][W-ABH][W-PocketUAV][W-MostWanted] | at once, one charge spent; run and air momentum kept; usable mid-air and mid-dash; a hit changes nothing | have. Mid-air and mid-dash in the source [?]. Most Wanted takes no slot and fires on pickup [W-MostWanted]; ours is a belt item (ext/utility-parity) |
| Warp Seed, stepping in | "players will begin to channel for a short time before teleporting" [W-ABH] | stand in it 1.5 s | have |
| Toss Satchel, picking up | "picked up while airborne, it will launch the target upwards" [W-VivePacks] | a body in the air is thrown up | have |
| Chest Key (Gold Key) | "Activating points near the closest ... chest" [W-GoldKey], no cast | at once | have (not in MOVES: needs a lock) |
| Medkit, Shield cell, Swift draught | ours only | at once, run kept | ours |
| Silence | "no abilities, powers or consumables" [S-data §4]; the final ally recall gives a damage and CC cut, not a silence [P-1.03] | no silence in Boki | n/a |

Not changed, for the owner: the source's Vulnerable is double damage ("Gliding players will take double damage"
[W-Gliding], "Vulnerable: takes 2x" [S-data §4]); ours is 1.2x while drinking, repairing or reviving a box
(`Hunter.CONSUME_VULN`, shared with the box revive). Changing it is a one-line parity fix that also changes
box revives, so it is left for a decision.

## Every belt item: source vs ours (0.24.6 line, ext/utility-parity-0246)

One row per item id in `content/utility/`, as built on the 0.24.6 train (0.24.5's belt code plus the
three parity branches above). Ours is read from the item's JSON: a drink's or a repair's numbers sit in its
`channel` block (`time` s, `move` = speed share while it runs, `heal` hp, `heal_max` share of max health,
`repair` share of the armor bar by armor tier), as 0.24.5 laid them out; docs/CONSUMABLES.md has the
drink and repair rows in more detail. Gems are run gems (section 1's price rule); HP over the ratio 7.2.
Checked by `--utility-parity-check`, `--equal-check` (slots, tonic, kit) and `--airheal-check` (the drink's cost).

| Item (`id`) | Source | Ours | Verdict |
|---|---|---|---|
| Tonic (`tonic`) | Vive Brew: 304 HP after a 1 s drink, Vulnerable, damage cancels it, cleanses anti-heal; slot 1, stack 8, 200 gold [W-ViveBrew][W-Consumables] | slot 1, stack 8, 30 gems; 1.0 s at full speed, a flat 42 HP (304 / 7.2), lifts blight first; a hit or a dash spills it and keeps it | match, but for Vulnerable (ours x1.2, the source's 2x: owner card) and chained drinks on hold [P-1.02] |
| Armor kit (`armor_kit`) | Portable Armor Repair: "a short cast", 1 bar a press, from 1.04 80 / 40 / 30% on grey / green / blue; slot 2, stack 8, 400 gold [W-PAR][P-1.04] | slot 2, stack 8, 40 gems; 1.6 s at 45% speed, puts back 80 / 40 / 30% of the armor bar by armor tier | match on amount, slot and stack; 1.6 s and the slow are ours [?] |
| Deep Draught (`deep_draught`) | Hypervive: 5 s, 60% slow, Vulnerable, then full HP; damage cancels it; stack 1, 1,000 gold [W-Hypervive] | stack 1, 40 gems; 5 s at 40% speed, then all your health; a hit spills it | match |
| Lostway Scroll (`lostway_scroll`) | Anywhere But Here: channel 4 s, then a random spot inside the next circle; world only, stack 1 [W-ABH] | stack 1, 60 gems; a 4 s read at full speed, then a random spot on the map; a hit spills it | differs: no circle in Boki |
| Omen Draught (`omen_draught`) | Prophet's Potion: channel 1 s, your team sees future storm spots for 30 s [W-Prophet] | stack 2, 40 gems; a 1 s drink, then 30 s of every Blight Warden and where the Blight gathers, squad only | match, Blight for storm |
| Twin Gate (`twin_gate`) | Two-Way Teleporter / Group Teleport: a portal at the aim and one at your feet; after 8 s reactivate to swap everything in each; stack 2, 3,000 gold [W-2Way][P-S2] | stack 2, 60 gems; gates 9 m out and at your feet (2 m radius) for 30 s; a second press after 8 s swaps both and closes them, no charge | match; 30 s open is ours [?] |
| Warp Seed (`warp_seed`) | Pocket Anomaly: step in, channel briefly, then a random spot; gone after a timer; stack 3, 3,000 gold [W-ABH][P-1.02][P-S2] | stack 3, 60 gems; set 2 m out for 30 s, stand in it 1.5 s to be thrown to a random spot | match; timer and channel are ours [?] |
| Cloud Raft (`cloud_raft`) | Emergency Platform: over abyss or hazards only, a 30 s platform that refills ally gliders and gives vision; casts after 0.3 s and floats you meanwhile; 1,500 gold [W-EmPlatform][P-1.03] | stack 2, 45 gems; over the abyss only; you hang for the 0.3 s cast, then a 5 x 5 m raft forms under you for 30 s and cools the gliders of squadmates on or near it (2 a second) | match, no vision part |
| Spring pad (`jump_pad`) | Jump Pad: arms after 2 s, lasts 30 s or 10 s after its first use; dashing in keeps momentum and adds a little; stack 2, 3,000 gold [W-JumpPad][P-S2] | stack 2, 35 gems; arms after 2 s, 30 s or 10 s after first use; a rider keeps the faster of its own speed and the pad's push | match; the small boost [?] |
| Gust Fan (`gust_fan`) | Deployable Fan: launches anyone who touches it, 60 s, 2 charges, 750 or 3,000 HP [W-Fan] | stack 2, 40 gems; 60 s, launches anyone on it; 104 HP (750 / 7.2), a rival's bullet stops in it and hurts it | match on the wiki's lower HP |
| Skyfall Charge (`skyfall_charge`) | Tactical Nuke: lands after 5 s, 5,000 damage, fire 720/s for 3 s; hurts you and allies, destroys beacons and basecamps; 3,000 gold [W-Nuke] | stack 1, 60 gems; 5 s telegraph, 690 in 6 m (lethal), then 3 s of fire (50 every 0.5 s); hurts you and your squad, razes revive beacons | match |
| Shatter Charge (`shatter_charge`) | EMP / Disruption Grenade: bursts 0.3 s after landing, shreds 1,600 armor, slows enemies 30% for 2 s [W-EMP] | stack 3, 45 gems; bursts 0.3 s after the aim, 3 m: shreds 60% of armor and slows 2 s, foes only | match; the shred is a share, not a number |
| Blight Flask (`blight_flask`) | Storm Grenade: a storm pocket that grows 15 s, holds 10 s, shrinks 15 s; blocks all healing [W-DeathCircle][P-2.0x] | stack 2, 50 gems; a 4.5 m patch for 40 s: 6 a second, a slow, and blight (healing in it barely takes) | match on length and anti-heal; no grow and shrink |
| Lookout Lantern (`lookout_lantern`) | Scanner Ward: vision 60 s, reveals stealthed foes, 3 s linger; anyone can pick it up; stack 4 [W-ScanGren] | stack 4, 40 gems; shows every rival within 14 m for 60 s (3 s linger); after 2 s anyone who steps on it takes it onto their belt | match |
| Toss Satchel (`toss_satchel`) | Vive Packs: a pack that lasts up to 30 s; the picker heals 140 HP/s for 5 s until hit; in the air it bounces them up; 2 charges [W-VivePacks] | stack 2, 45 gems; thrown 6 m, 30 s; the first body in it heals 60% of its health over 5 s (a hit stops it); a body in the air is thrown up 14 m/s | match; 60% stands in for 700 HP |
| Thorn Wall (`thorn_wall`) | Spike Wall: root yourself 2 s to build a wall that hurts by the toucher's speed; stack 10 [W-SpikeWall][P-Feb19] | stack 10, 40 gems; rooted 2 s, then a 6 m wall (200 HP, 20 s) rises 2 m ahead; a touch costs 10 and slows | match; the touch is flat, not by speed |
| Pilfer Pouch (`pilfer_pouch`) | Mass Heist: channel 1.5 s at a target; raccoons steal 50% of a hunter's gold and loot from unopened vaults [W-MassHeist] | stack 1, 60 gems; rooted 1.5 s, then half the gems of every rival within 4 m of the aim (8 m out) go and its locked chests are emptied | differs: the gems and loot are lost, the thief gains nothing |
| Bounty Banner (`bounty_banner`) | Most Wanted: a 2 min timer that reveals you; live and your allies are revived with a reward; knocks, kills and assists shorten it; knocked, you go straight out; 3,000 gold [W-MostWanted] | stack 1, 60 gems; you show to every rival for 120 s; live and the squad returns plus 150 gems; each squad knock takes 15 s off; knocked under it you are out and the knocker takes the gems | match; the 15 s cut is ours (no source number) [?] |
| Hearth Lamp (`hearth_lamp`) | Mobile Respawn Beacon: a squad respawn beacon; 6 s revive, then 12 s of sickness (-25% damage and healing); 8,000 gold [W-Beacon][P-1.0] | stack 1, 110 gems; a revive beacon where you stand; 12 s of sickness (-25% damage and healing), a heart status on the plate and squad row | match |
| Revive Ember (`revive_ember`) | Orb of Life / Revival: revives your team, full HP from 1.03; a final-boss reward [P-1.03][P-S2] | stack 1, never sold; every fallen squadmate wakes where you stand; a rare chest find | match; found in chests, not from a boss |
| Hawk Whistle (`hawk_whistle`) | Pocket UAV / Oracle: marks enemy hunters on your squad's map for a short time; stack 2, 1,500 gold; out of shops in 2.02 [W-PocketUAV][P-2.02] | stack 2, 45 gems; reveals rivals within 120 m for 4 s | differs: a wide radius, not the whole map; time [?] |
| Seeker flare (`scanner`) | none (nearest: Pocket UAV, above) | stack 2, 50 gems; reveals rivals within 26 m of you for 3 s | ours, kept beside the Hawk Whistle |
| Smoke bomb (`smoke`) | Ethereal Smoke: you and allies get stealth and +50 speed for 30 s; breaks in combat, near foes or on a dash [W-EthSmoke][P-Jan8] | stack 3, 35 gems; a 3.6 m cloud for 8 s that hides everyone in it | differs, kept (section 1b) |
| Chest Key (`chest_key`) | Gold Key: points to the nearest golden chest and opens it; opens a vault at once [W-GoldKey] | found only, never sold; pings the nearest locked chest, opens the one beside you | have; no vaults to open |
| Mending kit (`medkit`) | none (Elixir of Health, gone by 1.0) | stack 3, 45 gems; at once 40 HP and 20 armor | ours |
| Shield cell (`shield_cell`) | none | stack 3, 45 gems; at once 40 shield for 8 s | ours |
| Swift draught (`stim`) | none (Elixir of Speed, gone by 1.0) | stack 3, 35 gems; at once +35% speed for 6 s | ours |

Gone on this line: the Rift Key (`rift_key`, the source's Evil Key) went with 0.24.5's Ways Out (no
hatches); a stash that still holds one gets its price back in gems (`EqualMigrate`).

## Sources

- [W-x] wiki pages, `https://supervive.wiki.gg/wiki/<Page>` (raw wikitext read Nov 8 2026): Consumables, Powers, Shops, World_objects, Anywhere_But_Here, Vive_Brew, Portable_Armor_Repair, Hypervive, Pocket_UAV, Jump_Pad, Emergency_Platform_(Power), Deployable_Fan, Two-Way_Teleporter_(Power), Most_Wanted, Mobile_Respawn_Beacon, Tactical_Nuke_(Power), Mass_Heist, Basecamp, Ethereal_Smoke, EMP_Grenade, Death_Circle_Grenade, Scan_Grenade, Spike_Wall, Prophet's_Potion, Vive_Packs, Gold_Key, Evil_Key, Tome_of_Knowledge, Codex_of_Mass_Enlightenment, Little_Cook_(Power), Chonker_Cannon, Snowball_(Power), Present!_(Power), Tree_Costume_(Power), Money_Tree_Seeds, The_Breach, Hot_Zone, Vaults, Supply_Drops, Train, Skysharks.
- [P-x] official patch notes, `https://store.steampowered.com/news/app/1283700/view/<id>`: Oct24 = 6931694080291999956 (Oct 10 2024); Jan8 = 1788311418987033; Jan22 = 1789580505277155; Feb5 = 1790848102589412; Feb19 = 1792116353164260; Apr2 = 1795917897275785; May28 = 1800991756261724; 1.0 = 1806064758588867 (Jul 23 2025 rundown); 1.01 = 1807332909521300; 1.02 = 1808601382394244; 0828 = 1809235871570202 (dev blog); 1.03 = 1809869179984309; 1.04 = 1811138915342384; 1.05 = 1811772772426214; S2 = 1814309641394166 (Oct 22 2025); 2.02 = 1816849002006271; 2.03 = 1818118366168887; 2.0x = the "Death Circle now blocks all healing" fix (2.0x notes, exact patch [?]).
- [S-sunset] 1819386365085433 (Dec 17 2025). [S-data] docs/SUPERVIVE_DATA.md and /home/boki/briefs/supervive-data.
