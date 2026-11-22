# The Boki base (design brief)

Draft for owner approval, 2026-11-09. Source: DECISIONS.md 2026-11-09 "the farm becomes a simple Boki garden", plus the owner's same-day note: it is a Boki base with playthings they use on their own. A modern take on the creature-raising garden genre; we copy no game's systems, names, creature mechanics or look. Our hooks: the 18 Boki elements, personality, memory and trust, Boki work skills, and the link to expeditions. Research on the genre: design/CHAO_RESEARCH.md. Code read at origin/main. Until this is approved, no new farm-economy work.

Genre, not copy. What made the classic iconic: a living place inside an action game, creatures whose look tells their story, hidden depth found together, a lineage. What aged badly: opaque rules, hundreds of hours of grind, waiting, fear of death, nothing to do but races. We keep the first list and fix the second: rules you can read in-game, a cap that kills the grind, no death, several sports, and a base that feeds a real game. From the research's too-close list we do not use: good/evil alignment, coloured stat orbs, letter grades S to E, a lifespan with a reset, fixed gardens, a kindergarten, or the "Black Market" name (Old Pell's shop gets a new name, see 8).

## 1. The pitch

Your home is a base where your Boki live their own lives: they eat, play, nap in piles, make friends and rivals, and remember what you do with them. What you feed them and how you raise them changes how they look, which element they lean to, and who they become. Race them, pit them against each other, breed them, take the best on expeditions, or never leave the base at all.

## 2. The core loop

Base-only: come home and see what changed (a new part, two Boki became friends, an egg is ready). Feed and play, which nudges looks and stats. Run a minigame for gems and bragging rights. Pair two Boki you like, wait for the egg, raise the baby. Repeat with a bigger, stranger family.

The paths feed each other. Expedition to base: Inks, Rare Eggs, wild snacks and soul echoes make bigger changes than base food, and expedition memories colour what a Boki says at home (bridge.gd, kin_speak.gd do this today). Base to expedition: a raised Boki has more trust, better stats inside the +10% cap, a lean that shapes its kit, and a longer bond; bred babies carry two parents' strengths. The base makes your partner better, never required.

Coming home is a ritual, not a chore. One "while you were away" card: who played with whom, what someone ate, a new part, an egg ready. Absence gives small gifts (a Boki saved you a snack), never penalties; needs bottom out at sulky, not sick. Every cause is visible: the Boki card gets a journal line for each food, toy and win ("ate 3 Ember snacks: Fire lean up, ember flecks"). No hidden rules; the depth is in combinations, not in guessing.

## 3. What raising changes (four levers)

1. Food = element lean and look. Every food has an element. Fire foods lean a Boki to Fire: a warm tint, ember flecks, then a fire part (horns, flame tail tip) at its next form. The lean is a second element on top of the species type, with a small stat nudge and a minigame edge. Reuses Evo's affinity-and-parts system (scripts/core/evo.gd, scripts/kin/parts.gd) with the 18 types in place of fierce/steadfast/curious/swift. It shows within one or two feedings, not only at level-ups.
2. Play = stats. The toy or minigame it spends time on trains Power, Guard, Speed or Focus (Care.STATS, capped by level as today).
3. Company and care = personality and trust. Who it lives with drifts its four traits (a base of brave Boki makes a timid baby braver). Petting, favourite food and winning together raise trust (Care.BONDS unchanged). Neglect never kills (natural_death: false).
4. Expedition loot = the big jumps. Inks force an evolution branch (11-08 decision); Rare Eggs hatch rares; soul echoes make a species likelier. Base food never does these.

IVs, mutations, shimmer, size and coat stay as they are: flavour you discover, not levers you grind.

Legacy, not death. An Elder (stage 16) can retire to the Soul Shrine as a mentor. It stays in the base as a slow, calm presence and passes one thing to the next egg laid there: a trait, a habit, or a memory line. Nothing resets; the Boki is never lost.

## 4. Base life (autonomous Boki)

Boki choose from needs, traits and memory, not your orders. One explicit state machine per Boki (STATE_MACHINES.md): Roam, Eat, Nap, Play(toy), PlayWith(other), Watch, React, Chore.
- Playthings, placed like decorations, used on their own: a ball (chase, nudge to a friend), a climbing post (Flying and Rock leans), a splash tub (Water, Ice), a warm stone (Fire), a dig patch (Grass, Bug). Each trains one stat and shows one element preference. Boki queue, share, or squabble over them.
- Friends and rivals. Playing, napping or winning together builds friendship; losing to each other, toy squabbles and clashing tempers build rivalry. Saved as rec["bonds"] = {uid: -1..1}. Friends greet, nap in a pile, team up in tag. Rivals stare, huff, race unprompted. Friendship gates breeding.
- Napping where they are; friends pile on, grumpy ones nap alone. Night is nap time except nocturnal species (Work.NOCTURNAL).
- Reacting to new things: a new Boki, a new toy, a Rare Egg, you arriving with loot. Nearby Boki come to look and chatter (FarmChatter triggers); the curious one tries the toy first; "the day X arrived" goes into rec["memory"].
- Work skills become chores, not economy: a Tide Boki waters the snack patch, an Ember one minds eggs, a Mend one cheers up a glum friend, a Haul one fetches the ball. Because of who they are, not a Job Board.

## 5. Boki vs Boki minigames

Scored by stats, lean, mood and trust, with a small player input so it is a game and not a dice roll. Winners gain joy, trust and a few gems; losers sulk and remember.
1. The Dash (FIRST TO BUILD). Two to four Boki race a short loop: a straight, a water stretch, a climb, a jump. Speed sets the pace; a lean boosts its own stretch (Water swims the pond, Flying glides the gap). You back one Boki and cheer with a timing press at three marks (the Training post drill is this already). Friends run side by side; rivals bump.
2. Stump Shove. Two Boki push on a stump until one falls. Power vs Guard, the element table gives a 10% edge. Input: one timed shove.
3. Seek. You hide a scented item; two Boki hunt. Focus and curiosity decide; Spore and Dark track better at night. Input: where you hide it.
4. Spark Volley. Two Boki bat a glowing seed over a log; Focus and Speed, a miss loses a point. Input: call the spike.

The Dash goes first: it reads instantly on video, uses existing movement and the timing drill, and shows lean, stats, friends and rivals in one 20-second scene. The Training post folds in: training is practising a minigame alone. Later these are a sport: a weekly event rotates format and rules (a night Seek, a Dash with two water stretches), posted on the race post, with a photo of the winner saved to the base's showcase wall. Friends who visit (social.gd snapshot) see the wall and can watch a race.

## 6. Breeding

The Nesting Nook stays (home.gd nook UI, Care.breed). Gates change from "level 5, trust 50, 3 expeditions rest" to: both Grown, both friends, both rested since their last egg, one egg in the nest at a time. A base-only player can meet every gate. The egg hatches after one expedition or 10 minutes at home (unchanged); an Ember Boki minding it halves that.

Inherited (mostly in Care.breed today): species from one parent, sex 50/50, traits averaged with a wobble, 3 of 5 IVs, a parent's mutation at 35%/60%, looks blended (Unique.inherit). New: the stronger parent's lean as a head start, one habit (favourite toy or food) from each parent, and the baby knows its parents: it greets them and naps with them first.

The Nook shows a preview before you commit: the two possible species, the blended look, the lean head start, and a note when the pair is an unstable mix (clashing elements or tempers): the baby then hatches with low joy and needs more care for a day, which is a story, not a punishment. Which parent gave which gift is revealed at the hatch.

What stops the grind: the +10% IV cap means a "perfect" Boki is barely better, so there is no ladder. One nest, one egg, real waiting, no reroll. The base cap limits the family (6 out, the rest in the Burrow); extras go to friends or the Drift Pens listing. You breed for looks and lean, which is taste, not numbers.

## 7. Clans (later, shape only)

A clan is a shared base plus a roster. Roles fall out of taste: Raisers run the base (feeding, toys, a minigame league), Breeders pair across members' Boki, Extractors bring back Inks and Rare Eggs for everyone. Each member owns a corner of the clan base with their own toys and Boki; the middle is shared (race loop, nest, showcase wall). Clan-specific systems: the league and a clan egg. Builds on social.gd guild isles and the visit snapshot. Nothing to build now.

## 8. Cut list

Hide behind one `base_mode` flag in content/rules first; delete after the owner signs off.
- Gathering: chop and mine (scripts/home/home_gather.gd, tool_work.gd; axe and pickaxe in the market). Wood, stone, scrap, Save.d["mats"].
- Construction and blueprints: farm_sites.gd, farm_builder.gd, farm_hob.gd, hob_offer.gd, hob_talk.gd, farm_unlocks.gd, content/rules/farm_builder.json, farm_build.json "unlock"/"lots". Hob stays as a person who hands you the first toy and the second Mask.
- Work stations and the Job Board (home_work.gd, home_layout.gd CATALOG "Work"): Lumber Camp, Quarry, Storage Chest, Workbench, Spark Mill, Cold Store, Kiln, Ranch Pen, Infirmary, Seed Garden, haul piles. The knacks in scripts/core/work.gd stay as chores.
- The crop economy: 7 crops, selling at the stall, the Tradewind Exchange (scripts/core/exchange.gd, home_trade.gd), the kibble and Ember Coal chain. Replaced by one snack patch of four element snacks that never sells (Q1).
- Old Pell's "Black Market" (scripts/core/black_market.gd, data.gd "ransom" name) is renamed; proposal: the Drift Trader, a visitor whose stock follows your last runs and the weekly event. Same stall, new name, gems only.
- Tutorial crop/chop/mine/buy/sell steps (farm_tutorial.json, farm_crop_guide.gd, farm_task_guide.gd). New tutorial, 4 steps: meet your Boki, feed it and watch it change, place a toy and watch it play, head out or stay. This supersedes the 11-08 "farm tutorial 5 steps" line and the Auto-farm toggle for the base.
- Build mode shrinks to Base (toys, beds, tubs, feeders, Nook, Incubator, race post), Garden (plants and paths, decoration only), Island (themes, expansion). Indoor decorate.gd stays.

Stays: care.gd, kin_wants.gd, farm_chatter.gd, kin_speak/kin_brain, evo.gd (recut to leans), mutations, shiny, Unique, incubator.gd, the Nook, the Burrow, feeders, the Drift Pens, the Armory, the Ransom House, Graveyard and Soul Shrine, the portal, visiting and the town. Gems come from expeditions, minigame wins and Goals.

## 9. FIRST SLICE (for the gameplay video)

A 60-second clip: feed a Boki and watch it change; four Boki living with toys, two friends, two rivals; one race.

1. Element foods change a Boki on the spot (M). Files: scripts/core/evo.gd (AFF keyed by type, or by 6 type groups if 18 is too many parts), scripts/core/care.gd FOODS (element snacks), scripts/kin/parts.gd (tint and first part on lean), home.gd feed path calls Evo.dress at once. Check: new `--lean-check`: 3 Fire snacks to a fresh Prismander raise rec["lean"]["fire"]; before/after screenshots differ in tint and a part.
2. Base life state machine (L). Files: new scripts/home/base_life.gd (enum, one state var, guarded transitions, debug readout), hooked from home.gd _move_kin and _separate_kin; save.gd rec["bonds"]. Behaviours: tag, nap pile, rival stare-off, come look at a new arrival. Check: new `--base-life-check`, 10 simulated minutes with 4 Boki: at least one friend pair and one rival pair form; no state but Nap lasts over 90 s.
3. Three playthings (M). Files: home_layout.gd CATALOG (new cat "Base": ball, climbing post, splash tub), farm_models.gd, base_life.gd Play(toy) chosen by lean and trait, Care.add_stat on use. Check: place a ball; a Boki uses it within 60 s and a second joins; `--farmbuild` passes.
4. The Dash (L). Files: new scripts/home/base_race.gd (start post, loop waypoints, pace from Care stats + lean + mood, cheer timing from the Training post drill), home.gd prompt at the post, result card (winner heart, loser sulk, gems, memory line). Check: new `--race-check`: 20 headless races of 3 Boki; the highest expected pace wins at least 60%; joy, trust, gems and bonds update.
5. Hide the economy behind `base_mode` (M). Files: farm_build.json, farm_builder.json, farm_tutorial.json (4 steps), home_build.gd (tabs), home_gather.gd, home_trade.gd, home_work.gd (stations off, chores on), the market Farm tab. Check: a new base_mode save shows only Base/Garden/Island, no axe, no Job Board; `--farm-tutorial-check` passes; an old save still loads.
6. Nook shows lean and the friend gate (S). Files: home.gd _can_pair, _nook_pair, care.gd breed (lean head start, habits). Check: `--iv-check` passes; 20 of 20 headless babies take the stronger parent's lean.
7. Journal lines and the away card (S). Files: care.gd (rec["journal"], last 20 lines, written by feed, toy use, race), the Boki card UI, home.gd arrival hook showing one "while you were away" card from the journal since last visit. Check: feed 3 snacks, leave, return: the card lists the feed and the lean change; no line ever says "lost" or "starved".
8. Demo seed (S). `--base-demo` loads a base with 4 Boki (two friends, two rivals), toys, snacks, a ready egg. Check: ready in under 10 s on the M5; the shot list (feed, change, play, nap pile, rival huff, race, hatch) fits 60 s.

Order: 1, 5, 3 in parallel, then 2, 4, 6, 7, 8.

## 10. Hub and zones (next garden milestone, owner 2026-11-10)

Source: DECISIONS.md 2026-11-10 "the garden gets a hub with a teleporter and zones you unlock". The first slice (9) does not change: it becomes the first zone. Genre pattern, not a copy. The research's too-close list says no "three fixed gardens" and no garden that opens just because you own a creature of its kind. So here, zones follow our 18 types and four traits, and you open a zone yourself: you bring back a key from a run and a Boki you raised wakes the zone. All names, layouts and looks are ours. Code read at origin/ext/garden-integrated (58686d0).

### 10.1 The hub

A small round island, about 20 m across, that you arrive on. No toys and no resident Boki, so it stays light and every zone keeps a reason to exist. What's in it:
- **The Waystone** (middle). The teleporter: a flat stone ring with five standing stones around it, one per zone. An open zone's stone glows in its colour and shows a tiny icon of who lives there. A locked one is dark and grown over, with its two keys drawn on it. Step on the ring and press E to get the destination cards (10.5).
- **The nest corner** (west): the Nesting Nook, the Incubator and the Soul Shrine side by side. Pairing and hatching happen here, and mentors pass their gift here (3, 6). It is the one place Boki from different zones meet on purpose.
- **The house** (north) and **the expedition portal with the glider rack** (south). Runs start and end in the hub, so loot always comes home past the Waystone.
- **The Drift Trader's stall and the games board** (east). The board shows which zone hosts which game, this week's twist and the showcase wall. The stall sells snacks, toys and, once a week, one Wayseed (10.3).
- **The Burrow door.** One Burrow shared by every zone.
- **On the horizon:** the five zone islands float in the sky as cheap low-poly silhouettes. Open ones are lit; locked ones are misty. You can see where you are going before you can go there.

Who is in the hub: your partner (following you) and an egg-minder doing its chore. Nobody else.

### 10.2 The zones

Five zones. The 18 types split into five groups with nothing left over, and each zone also matches one of the four traits (Care: bravery, loyalty, temper, curiosity). A Boki **thrives** in a zone when its strongest lean is one of the zone's types, or its matching trait is high (over 0.6). Thriving means joy falls half as fast and the zone's own toys train +25%. A Boki that doesn't thrive loses nothing: there are no penalties (2).

| Zone | Feel | Types | Trait | Toys there | Game there |
|---|---|---|---|---|---|
| **Bramblebank** (open at start) | Soft green bank, a slow stream, a big nap tree. Today's garden. | Normal, Grass, Bug, Spore | loyalty: friends, nap piles, egg-minders | ball, dig patch, snack patch (today's four snacks) | The Dash (today's loop) |
| **Glasswater Shallows** | Clear knee-deep pools, ice-edged rocks, crystal stacks catching light | Water, Ice, Crystal | low temper: calm, patient | splash tub, pools to wade | Spark Volley (over a shallow channel; a miss splashes) |
| **Cinderstep** | Warm stepped terraces, glowing cracks, iron-red rock | Fire, Rock, Steel, Dragon | high temper: hot-headed rivals | warm stone, climbing post | Stump Shove (on a warm ledge) |
| **Hushwood** | A dusky wood, always evening, lantern moss, soft echoes | Dark, Psychic, Poison | curiosity: seekers, night-owls | dig patch, lantern moss to sniff | Seek (night all day, so Dark and Spore track better) |
| **Kitewind Ridge** | Windy high ridge, updrafts, humming stones | Flying, Electric, Fairy, Sound | bravery: daring jumpers | climbing post, updraft vents | The Dash, ridge track (glide gaps, an updraft climb) |

Every zone has one snack patch growing its own types' snacks from lean.json (for example, Hushwood grows mindmint and glowcap). The patch also gives a way to lean a Boki toward zones whose snacks Bramblebank doesn't grow. Every game can be played by any Boki you bring; the zone's types simply get their lean edge on their home course. Each zone also nudges its matching trait upward very slowly, on top of the drift from friends (base_drift.json): +0.01 per in-game day. That is the "where you live shapes who you are" hook. It never moves a trait past 0.8.

### 10.3 Unlocking

Each locked zone needs two keys, and the locked stone and its card list both of them:
1. **A Wayseed of the zone's group.** It drops from expedition lairs of a matching element (one per run at most), or the Drift Trader sells one for gems once a week. The trader only stocks a Wayseed for a zone that is still locked, so a player who never leaves the base still gets there.
2. **A Boki that leans toward the zone.** Its lean in one of the zone's types must be at least half (12 of Evo.LEAN_FULL 24). That takes about two meals of the right snack.

You carry or walk that Boki onto the Waystone with the Wayseed in your bag and press E on the dark stone. The Boki plants the seed, the stone lights up and the zone opens. That Boki becomes the zone's **founder**: it moves in, gets a memory line ("the day I woke Cinderstep") and a journal line, and the card names it from then on. Zones can be opened in any order. The suggested route, shown as a hint on the cards: Glasswater, Cinderstep and Kitewind can be leaned to with snacks the start garden grows. Hushwood needs mindmint or glowcap, which come from runs or the trader, so it tends to open last.

Alternatives not taken: the lean alone (too close to the genre's "own one, garden opens"); gems alone (a shop gate, with no story); expedition loot only (would lock out base-only players, which goes against 2).

### 10.4 How Boki move between zones

- Every Boki has a home zone, rec["zone"]. An old save puts everyone in Bramblebank. Only the zone you are in is loaded and simulated.
- **You decide; Boki ask.** Three ways to move one: carry it onto the Waystone and pick a zone; press "Move to..." on its Boki card (it walks to the zone's return pad and blinks out); or answer when it asks. A Boki that would thrive in another open zone sometimes waits at the return pad with a bubble ("Pip keeps looking at the ridge"). Press E to send it, or ignore it and nothing happens. Boki never change zone on their own, so you always know where everyone is.
- Your partner follows you through every hop and stays a resident of its own zone.
- **Up to 6 out per zone**, the same as today's cap (GARDEN.md 10, Q3). It is now per zone, so more zones means more Boki out, with no extra frame cost, because only one zone is loaded. The rest wait in the shared Burrow.
- Friends in different zones keep their bond; now and then one asks to visit the other (the same bubble). To pair two Boki, you take both to the nest corner in the hub.
- Zones you aren't in don't run frame by frame. When you arrive, the away-card catch-up runs once for that zone (bonds, joy, journal lines), so the "while you were away" card covers every zone.

### 10.5 Travel feel

Step on the Waystone: a row of five cards. Open ones show the zone's colour, who lives there with mood icons, and today's game. Locked ones are grey, with the two keys as ticks (Wayseed ☐, a Boki leaning Water, Ice or Crystal ☐) and where to get each. Pick one: a 0.5 s light-up and fade, then the zone loads with the fade covering it. You arrive on that zone's return pad. From any return pad you can go straight to the hub or to any open zone. It all uses the existing scene switch, Game.goto("home", {"zone": id}), the same way a visit passes {"visit": ...}.

### 10.6 Performance budget (per loaded zone; the hub is lighter)

Only one zone is in memory at a time, so each zone carries its own budget. These numbers are targets. Step 0 measures today's garden first and adjusts them.

| | Zone | Hub |
|---|---|---|
| Boki animated | 6 residents + partner + 2 visitors = 9 max | partner + egg-minder |
| Draw calls | ≤ 350 (match scene is 850-1000) | ≤ 200, the five horizon silhouettes ≤ 5 of them |
| Objects / nodes | ≤ 800 / ≤ 3000 | ≤ 500 / ≤ 2000 |
| Emitting particle systems | ≤ 12 | ≤ 6 (Waystone glow, portal) |
| Frame | ≤ 16.7 ms on the M5 at Medium; ≤ 33 ms on rp1-0 at Very Low | same |
| Script | base_life ≤ 1.5 ms for 9 Boki | ≤ 0.5 ms |
| Hop | ≤ 2.0 s from pressing E to control, M5 | |

Scatter (flora, crystals, lantern moss) uses MultiMesh, and each zone's props share one material per theme (GAMEDEV_CHECKLIST draw calls). The budget numbers live in content/rules/garden_zones.json "budget" so the check reads them.

### 10.7 Build plan (in order; each step runs its own checks plus `python3 tools/health.py --strict`)

0. **(S) Measure first.** Run `--perf-bench` on its home part with today's garden-integrated base, through `jobq submit --needs gpu` on the M5 and rp1-0. Record draws, objects, script ms and frame ms in briefs/PERF_AUDIT.md and set the 10.6 numbers from those results. Check: the bench rows exist for both machines.
1. **(S) Design note** docs/decisions/NNNN-garden-zones.md: save shape (Save.d["zones"], rec["zone"]), one scene per zone through Game.goto, the visit snapshot, deleting the side isles. This is required because it touches the save format (AGENTS 1). Check: review only.
2. **(M) Zone data and save migration.** content/rules/garden_zones.json (5 zones: name, types, trait, theme, toys, game, patch snacks, unlock, thrive, budget); new scripts/home/garden_zones.gd (is_open, keys_for, can_open, open_with, residents, move); scripts/core/save.gd migration: the current layout moves to zones["bramblebank"], every farm Boki gets rec["zone"] = "bramblebank", and the save version goes up. Check: new `--garden-zones-check` (the name `--zone-check` is taken by the match): an old save loads with everyone in Bramblebank and only Bramblebank open; the garden save round-trip check passes.
3. **(L) The hub scene.** New scripts/home/hub_layout.gd (the fixed hub template built with the same HomeLayout/World code). Hub fixtures: house, portal and rack, nest corner, stall, games board, Burrow door. home.gd gets only wiring: it reads the "zone" param (default "hub") and builds either the hub or a zone; build mode in the hub offers only the Garden tab. Check: `--garden-zones-check` hub part (every fixture present, no toys, no residents); `--farmbuild`, `--arrival-check` and `--farm-tutorial-check` pass.
4. **(M) Waystone and travel.** New scripts/home/hub_waystone.gd (ring, E prompt, fade, Game.goto); new scripts/ui/zone_cards.gd (open and locked cards with key ticks); Waystone, standing-stone and return-pad models in farm_models.gd; a return pad in every zone. Check: `--garden-zones-check` travel part: hub to Bramblebank and back keeps the partner and resident counts, a hop to a locked zone is refused and its card lists both keys, and `--load-check` shows a hop takes ≤ 2.0 s.
5. **(M) Residents and moving.** Only rec["zone"] Boki spawn in the loaded zone (home.gd kin spawn wiring, base_life.gd); a 6-out cap per zone; "Move to..." on the Boki card (scripts/ui); a carry drop on the Waystone; the ask bubble at the return pad (a Watch target in base_life.gd, no new state). Check: `--garden-zones-check` moving part (a moved Boki is gone from the old zone and present in the new one after a reload; the 7th move is refused); `--base-life-check` and `--garden-nav-check` pass.
6. **(M) Unlock path.** The Wayseed item (data.gd items, one per group) and its lair drop in the expedition loot rules; the Drift Trader's weekly Wayseed for a locked zone (home_black_market.gd, market.json); attuning at the Waystone (founder, memory line, journal line, toast); locked and lit stone looks. Check: `--garden-zones-check` unlock part: Wayseed plus a Boki at 12 lean opens the zone, either one alone does not, the founder moves in with its lines, and the trader never stocks a Wayseed for an open zone.
7. **Four zone builds, one job each (M each).** For each: the THEMES entry in home_layout.gd, MultiMesh scatter, the zone's toys and patch snacks, its game placed there.
   - 7a Glasswater: the splash tub and Spark Volley (base_volley.json position).
   - 7b Cinderstep: the warm stone, the post and Stump Shove.
   - 7c Hushwood: always-dusk lighting and Seek.
   - 7d Kitewind: updraft vents and a second Dash track in base_race.json.
   Check for each: `--garden-nav-check` in that zone (0 stuck, 0 inside), that game's check (`--volley-check`, `--shove-check`, `--seek-check`, `--race-check`), `--perf-bench` zone part through jobq gpu inside 10.6, and day and night shots.
8. **(S) Thrive and the zone's trait pull.** "thrive" and "trait_pull" in garden_zones.json, read by base_life.gd (joy) and base_drift.gd (trait). Check: `--garden-zones-check` thrive part (a thriving Boki loses joy at half rate, a non-thriving one loses joy as today, the trait pull stops at 0.8); `--trait-drift-check` passes.
9. **(S) Horizon silhouettes in the hub.** Five low-poly islands, lit or misty from Save.d["zones"]. Check: the hub stays inside its draw budget, and a hub shot shows lit and locked islands.
10. **(M) Away card, journal and visits across zones.** The catch-up runs once per zone on arrival; the away card groups by zone. The visit snapshot (Social.publish_profile / clean_island) carries the open zones' layouts, so visitors land in the hub and can hop to the owner's open zones; old profile docs still load. Home is not synced through Net, so Net.VERSION stays. Check: `--journal-check`, `--arrival-check`, and the visit test path in main.
11. **(S) Retire the bridged side isles.** Data.ISLES orchard, meadow, summit, grove and pines (their gem cost, bridges, signs, music) go behind base_mode and are deleted after sign-off, together with their checks. The 4-step tutorial gains one hint at the end: "the Waystone: one zone is open, here is how to wake the next". Check: `--farm-tutorial-check`, `health.py --strict`; then the full suite once, plus `--garden-soak` over two zones.

Order: 0 and 1 first; then 2; then 3 and 4 (3 before 4); then 5 and 6 in parallel; then 7a-7d in parallel; then 8, 9, 10 and 11.

## 11. Open questions for the owner (defaults in bold)

1. Do crops survive? **Default: one snack patch growing four element snacks for feeding only, never sold.** Alternative: no patch; all food from runs and the stall.
2. How deep is the element lean? **Default: a second element shown in look plus a 5% stat and minigame edge; it never changes the species type, but may pick the evolution branch where the roster has one.** Alternative: the lean can overwrite the type (risky for kits and roster).
3. How many Boki out at once? **Default: 6 (today's cap), the rest in the Burrow, more with island expansion; safe for the 60-character perf budget.** Alternative: 10-12 with animation LOD after a real-GPU check.
4. How many zones? **Default: 5 (the 18 types split cleanly, one per trait plus the start).** Alternative: 4 (merge Hushwood into Glasswater) or 6 (split Cinderstep into Fire/Dragon and Rock/Steel).
5. Do visitors see all your open zones? **Default: yes, they land in your hub and hop like you.** Alternative: hub and Bramblebank only (smaller profile doc).
6. Can toys go in the hub? **Default: no, toys belong to zones (keeps the hub light and the zones worth visiting).** Alternative: one toy slot in the hub.
