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

## 10. Open questions for the owner (defaults in bold)

1. Do crops survive? **Default: one snack patch growing four element snacks for feeding only, never sold.** Alternative: no patch; all food from runs and the stall.
2. How deep is the element lean? **Default: a second element shown in look plus a 5% stat and minigame edge; it never changes the species type, but may pick the evolution branch where the roster has one.** Alternative: the lean can overwrite the type (risky for kits and roster).
3. How many Boki out at once? **Default: 6 (today's cap), the rest in the Burrow, more with island expansion; safe for the 60-character perf budget.** Alternative: 10-12 with animation LOD after a real-GPU check.
