# Source map utilities, shops, regions, hot zone and train

Research for the owner's Nov 7 decision "Utilities and shops" (briefs/DECISIONS.md on ext/agent-briefs): copy all of the source's map utilities under our own names and art, sell them in the in-match shops, and give every shop its own **fixed** set. Our names below are proposals; nothing here is built yet. The build job is ext/utilities-shops.

**Which version.** The source's last patch was 2.04 (Dec 17 2025); live service ended Feb 25 2026 [S-sunset]. "Final" here means 1.0 (Jul 24 2025) to 2.04. The wiki item pages are mostly from before 1.0 (the "Powers" era, which 1.0 retired: some powers became consumables, others relics or perks [W-Powers]). Where only a pre-1.0 number exists, it is marked *(pre-1.0)*. **[?]** = not confirmed for the final version.

Source currency is gold ("Coin" from 1.0). Ours is run gems. Proposed gem prices use **gems = 30 + gold / 100**, rounded to 5. This keeps the cheap staples near today's tonic (30) and armor kit (40). Items we already have keep their price.

## 1. Source utilities, mapped to Boki

Status: **have** = we have an equivalent. **differs** = we have one, but it works differently (see notes). **missing** = we don't have it. **skip** = it needs a system Boki doesn't have.

### 1a. Sold in the source's shops (final version)

| Source item | What it does (numbers) | Price, stack | Boki | Status |
|---|---|---|---|---|
| Vive Brew | Restores 304 HP and 120 mana after a 1s drink. You are Vulnerable while drinking, and taking damage cancels it. Cleanses anti-heal [W-ViveBrew]. Has a fixed slot (slot 1) [W-Consumables]. Every shop sells it [W-WorldObj]. Holding the key chains drinks (1.02) [P-1.02] | 200 gold, stacks to 8 [W-ViveBrew] | `tonic` Tonic | **have**. Ours heals 40% HP, has no mana and is "open while you drink". Close enough. |
| Portable Armor Repair / Armor Shard | Press to repair 1 bar of armor (1 bar = 500 armor), with a short cast [W-PAR]. Has a fixed slot (slot 2). From 1.0, armor is repaired only with Armor Shards or at the Forge [P-1.0]. From 1.04 a repair restores more on low tiers: grey 2000 (80%), green 1000 (40%), blue 750 (30%) [P-1.04]. Every shop sells it [W-WorldObj] | 400 gold, stacks to 8 [W-PAR] | `armor_kit` Armor kit | **have**. Ours repairs to full and leaves you open. Source repairs part of the bar, more on low tiers. |
| Hypervive | Slows you by 60% and makes you Vulnerable for 5s, then fully restores HP and mana. Taking damage cancels it [W-Hypervive] | 1,000 gold (2,000 → 1,000 in Feb 2025) [W-Shops][P-Feb5], stacks to 1 | **Deep Draught** | **differs**. The closest we have is `medkit` (40 HP + 20 armor, instant). Proposal: add Deep Draught as a new item and keep the medkit. |
| Pocket UAV / Pocket Oracle | Marks enemy hunters on your squad's map for a short time [W-PocketUAV]. Removed from shops in 2.02 [P-2.02] | 1,500 gold, stacks to 2 [W-PocketUAV] | **Hawk Whistle** | **differs**. `scanner` Seeker flare reveals rivals within 26 tiles for 3s, around you only. The source covers the whole map but shows map marks only. Duration [?]. |
| Jump Pad | Placed pad. It arms after 2s and launches anything that steps on it. It lasts 30s, or 10s after its first use. Dashing into it keeps your momentum [W-JumpPad] | 3,000 gold (2,000 → 3,000 in Feb 2025) [W-JumpPad][P-Feb5]. Stack 1 → 2 in Season 2 [P-S2] | `jump_pad` Spring pad | **differs**. Ours lasts 20s, arms at once, and stacks to 3. Proposal: arm after 2s, last 30s or 10s after first use, stack to 2. |
| Emergency Platform | Over open air or hazards only. Makes a platform for 30s that refills ally gliders and gives vision [W-EmPlatform]. From 1.03 it casts after 0.3s instead of at once, and floats you during the cast [P-1.03]. Things you place on it stay after it fades [W-EmPlatform] | Added to every shop in 1.01 [P-1.01]. Cost 500 → 1,500 in 1.02 [P-1.02]. Stack [?] | **Cloud Raft** | **missing** |
| Deployable Fan | Builds a fan at a target spot that launches anyone who touches it. Lasts 60s, 2 charges. Fan HP is 750 or 3,000 (the wiki gives both) [W-Fan]. Launches stack [W-Fan] | 1,000 gold [W-Shops] (2,000 as a power [W-Fan]). In the final version [?] | **Gust Fan** | **missing** |
| Two-Way Teleporter → "Group Teleport" | Opens a portal at a target spot and one at your feet. After 8s you can reactivate to swap everything standing in each portal [W-2Way] | 3,000 gold [W-Shops]. "Group Teleport" was re-enabled in 1.05 [P-1.05] and its stack raised to 2 in Season 2 [P-S2]. Group Teleport = Two-Way Teleporter renamed [?] | **Twin Gate** | **missing** |
| Pocket Anomaly | Places a warp anomaly that works like the ones in the world: step in, channel briefly, then get teleported somewhere random. The world anomaly behaves like Anywhere But Here [W-ABH][P-Jan8]. A placed one disappears after a timer [P-1.02] | 3,000 gold, new in 1.02 [P-1.02]. Stack raised to 3 in Season 2 [P-S2]. Timer [?] | **Warp Seed** | **missing** |
| Most Wanted | Starts a 2-minute timer and reveals you to every enemy. If you survive, all your allies are revived and gain XP, and you get a rare or epic reward. Knocks, kills and assists shorten the timer. If you are knocked while carrying it, you go straight to your deathbox and the team that knocked you takes the reward. One per team at a time. It also spawns in the world at night [W-MostWanted][S-data §10] | 3,000 gold [W-MostWanted][P-Feb5] | **Bounty Banner** | **missing** |
| Mobile Respawn Beacon | Places a respawn beacon for your squad. It can be set on temporary terrain [W-Beacon]. Final revive time on a beacon: 6s, then 12s of resurrection sickness (−25% damage and healing) [P-1.0] | 8,000 gold [W-Beacon][P-Feb5] (25,000 in Jan 2025 [P-Jan8]) | **Hearth Lamp** | **missing** |
| Tactical Nuke | Calls a warhead on a target spot. It lands after 5s, deals 5,000 damage, and leaves fire that deals 720/s for 3s. It hurts you and your allies too, and destroys beacons and basecamps [W-Nuke] | 3,000 gold [W-Shops]. Shop in the final version [?] | **Skyfall Charge** | **missing** |
| Mass Heist | Target a spot and channel for 1.5s. Raccoons steal items and gold there, including 50% of a hunter's gold and loot from unopened vaults [W-MassHeist] | Shop, price unknown ("XXXX") [W-MassHeist] [?] | **Pilfer Pouch** | **missing** |
| Basecamp Recaller | After a 4s channel, pulls your basecamp and everyone standing on it to you [W-Basecamp] | 1,000 gold [W-Basecamp] | — | **skip**: Boki has no capturable basecamps |
| Basecamp Deployment Beacon | Drops a basecamp your team owns. It deals 650 damage where it lands. You get it by packing up your camp for 800 gold [W-Basecamp] | 5,000 gold [W-Shops] | — | **skip**: no basecamps |

### 1b. Found only in the world (not sold)

| Source item | What it does (numbers) | Where found | Boki | Status |
|---|---|---|---|---|
| Anywhere But Here | Channel for 4s, then teleport to a random spot inside the next circle. Works inside the storm, so it can replace a recall [W-ABH] | World only, rare, stack 1 [W-ABH]. It made up 14% of Little Helper drops (pre-1.0) [P-Jan22] | **Lostway Scroll** | **missing** |
| Ethereal Smoke | You and nearby allies get stealth and +50 move speed for 30s. Stealth breaks in combat or within 1,500 units of an enemy hunter [W-EthSmoke], and on dash [P-Jan8] | World [W-EthSmoke] | `smoke` Smoke bomb | **differs**. Ours is a fixed cloud that hides everyone inside it for 8s. Keep ours; the source's is a moving team cloak. |
| EMP / Disruption Grenade | Thrown. Bursts 0.3s after landing: shreds 1,600 armor and slows enemies by 30% for 2s. Neutralizes enemy basecamps [W-EMP] | World, common [W-EMP] | **Shatter Charge** | **missing** |
| Storm/Death Circle Grenade | Makes a pocket of storm. It grows for 15s, holds for 10s and shrinks for 15s. Damage scales with the night [W-DeathCircle]. It blocks all healing inside it [P-2.0x] | World [W-DeathCircle] | **Blight Flask** | **missing** |
| Scanner Ward (Scan Grenade) | Thrown ward. Gives vision for 60s and reveals stealthed enemies. Enemies stay visible for 3s after leaving its view. Anyone can pick one up, including enemy wards [W-ScanGren] | World, stacks to 4 [W-ScanGren] | **Lookout Lantern** | **missing**. Ours (`scanner`) is a short reveal pulse, not a ward. |
| Spike Wall | You root yourself for 2s to build a wall (3s → 2s in Feb 2025 [P-Feb19]). The wall damages hunters who touch it, based on their speed [W-SpikeWall] | World, stacks to 10 [W-SpikeWall] | **Thorn Wall** | **missing** |
| Prophet's Potion | Channel for 1s: your team sees future storm locations for 30s [W-Prophet] | World, uncommon [W-Prophet] | **Omen Draught** | **missing** |
| Vive Packs | Throws a health pack that lasts up to 30s. Whoever picks it up heals 140 HP/s for 5s, until hit. If they're in the air, it also bounces them up. 2 charges [W-VivePacks] | World, epic [W-VivePacks] | **Toss Satchel** | **missing** |
| Gold Key | Points to the nearest golden chest and opens it. Can also open a vault instantly [W-GoldKey] | World, rare [W-GoldKey] | `chest_key` Chest Key | **have**. Ours pings and opens locked chests. It doesn't open vaults. |
| Evil Key | Points to the nearest evil chest (exotic loot). Dropped by PvP combat [W-EvilKey] | PvP drop [W-EvilKey] | `rift_key` Rift Key (nearest) | **differs**. Ours opens an extraction hatch. Keep. |
| Orb of Life / Orb of Revival | Revives your team; revives at full HP from 1.03 [P-1.03]. Final-boss reward from Season 2 [P-S2] | Boss only [P-S2] | **Revive Ember** | **missing** (boss reward, not shop) |
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

## Sources

- [W-x] wiki pages, `https://supervive.wiki.gg/wiki/<Page>` (raw wikitext read Nov 8 2026): Consumables, Powers, Shops, World_objects, Anywhere_But_Here, Vive_Brew, Portable_Armor_Repair, Hypervive, Pocket_UAV, Jump_Pad, Emergency_Platform_(Power), Deployable_Fan, Two-Way_Teleporter_(Power), Most_Wanted, Mobile_Respawn_Beacon, Tactical_Nuke_(Power), Mass_Heist, Basecamp, Ethereal_Smoke, EMP_Grenade, Death_Circle_Grenade, Scan_Grenade, Spike_Wall, Prophet's_Potion, Vive_Packs, Gold_Key, Evil_Key, Tome_of_Knowledge, Codex_of_Mass_Enlightenment, Little_Cook_(Power), Chonker_Cannon, Snowball_(Power), Present!_(Power), Tree_Costume_(Power), Money_Tree_Seeds, The_Breach, Hot_Zone, Vaults, Supply_Drops, Train, Skysharks.
- [P-x] official patch notes, `https://store.steampowered.com/news/app/1283700/view/<id>`: Oct24 = 6931694080291999956 (Oct 10 2024); Jan8 = 1788311418987033; Jan22 = 1789580505277155; Feb5 = 1790848102589412; Feb19 = 1792116353164260; Apr2 = 1795917897275785; May28 = 1800991756261724; 1.0 = 1806064758588867 (Jul 23 2025 rundown); 1.01 = 1807332909521300; 1.02 = 1808601382394244; 0828 = 1809235871570202 (dev blog); 1.03 = 1809869179984309; 1.04 = 1811138915342384; 1.05 = 1811772772426214; S2 = 1814309641394166 (Oct 22 2025); 2.02 = 1816849002006271; 2.03 = 1818118366168887; 2.0x = the "Death Circle now blocks all healing" fix (2.0x notes, exact patch [?]).
- [S-sunset] 1819386365085433 (Dec 17 2025). [S-data] docs/SUPERVIVE_DATA.md and /home/boki/briefs/supervive-data.
