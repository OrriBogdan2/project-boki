# The modern garden: items, evolution, minigames (design brief)

Draft for owner approval, 2026-11-10. Owner order: "a research agent for chao garden, who can develop a modernized version of it (where we can get items that change how our boki evolve and their stats, and minigames, and more stuff)".

Builds on design/GARDEN.md (section 10, hub and zones, is kept as is) and design/CHAO_RESEARCH.md (not repeated here). DECISIONS.md wins over everything. Code read at origin/main d255acbee and origin/ext/garden-integrated 58686d0 (the garden code is not on main yet). Where this brief changes an older rule, the change is listed in section 8 and nothing else is edited.

IP rule: sections 1 to 8 use only our own names. Other games are named only in the research section (R) and the sources (9).

## Owner summary (one page)

**The idea in one line.** Everything you bring home is a small, visible push on one Boki: this one gets stronger here, leans to that element, grows toward that final form. You always see the push before you give it.

**What is new**

1. **30 shaping items in six families** (section 1): stat bites (Thumpnut: +3 Power), path tokens a Boki wears (Keepstone: one step toward its sturdy final), zone sweets (jump its element lean), auras and keepsakes (looks only), personality treats, and nest items for breeding. They come from zone patches, minigame prizes, a small Mixing Bowl, and hatching eggs.
2. **Hold to preview.** Hold any item near a Boki and its card shows ghost bars with the real numbers, the lean ring, and the silhouette of the final form it would grow toward. Nothing is hidden and nothing is random.
3. **The path meter** (section 3). Lines with two finals (Mycroll, Vespyx, Prismander, Echolop) get a tug bar with a silhouette at each end. Trained stats, element lean, worn tokens, personality and minigame ribbons each add pips you can count. The side with more pips is the form it takes. You can keep shifting it until you press Evolve. Inks still decide Minkee and Jarmit.
4. **Stats with a build, not a ladder** (section 2). The four real stats stay (Power, Guard, Speed, Focus). New: 100 a stat, 240 in total, so a Boki has a shape (a sprinter, a wall) instead of maxing everything. Expeditions count only the first 25 points (about +10%), so a garden champion is a little better on runs, never required. A tea gives points back, so trying things costs nothing.
5. **Seven new minigames** (section 4), each 1 to 3 minutes, on top of the four that are built. First two to build: **Tumble** (a three-move duel where you read the rival's tell) and **Echo Steps** (a call-and-answer rhythm dance on humming stones).
6. **More stuff, ranked by fun per build day** (section 5): today's three wishes, first win of the day, away gifts with a cap, duo tricks for friends and grudge matches for rivals, wild visitors, cups with ribbons, seasons, sleepovers.

**Three things found in the code that need a decision**

- **A Boki raised only at home cannot level, so it cannot evolve.** XP comes only from expeditions (game.gd). Fix: garden XP (section 2.5, backlog item 5).
- **Trained stats have no real cap today.** The cap is 12 + 6 a level; with the level cap of 100 that is 612 points, or +245% damage. GARDEN.md says "inside the +10% cap", but only IVs have that cap. Fix: section 2.
- **Nine of the 18 types have no snack** (Ice, Rock, Dragon, Dark, Poison, Bug, Steel, Crystal, Sound), so every zone has a type food cannot lean to. Fix: backlog item 6 (data only).

**What we take from the research (R).** The genre's best systems were item-driven and personal, and its worst were hidden: the classic garden picked a form from the last things you fed, not the highest stat, and never said so; another classic needed three of four secret conditions; a third shortened a hidden lifespan when you trained hard. Modern games fixed this with a visible budget, a refund, a preview at the moment of choice, and no loss while you are away. We do all four.

**Build plan.** 13 backlog items, each under a day for one agent (section 6), appended to /home/boki/cj/backlog.proposed.jsonl. Order: item engine, preview card, stat budget, garden XP, missing snacks, prizes, path meter, then Tumble and Echo Steps.

**Open questions** are in section 7, each with a default in bold. Nothing waits on them.

---

## R. Research: item-driven raising, and what to learn

Confidence: numbers come from fan wikis, strategy guides and search summaries; where guides disagree it is said. Rows marked (m) are from memory and unverified. Sources in section 9.

### R1. How items shaped stats and forms

| Game | The rule | What was fun | What was grindy or hidden | Modern fix we take |
|---|---|---|---|---|
| Sonic Adventure 2 garden | A coloured drive fills 24% of one stat's level bar (five to a level) and never changes looks. A small animal gives stat progress, a body part, and can lower other stats. You carry ten at most. Garden fruit is +40% of a stamina level; shop fruit raises all four stats, shifts alignment or starts mating [1][2]. | Two item kinds with clear jobs: pure numbers, or numbers plus a look. Loot from the action game mattered at home. | The form was set by the group of items given most recently, not the highest stat ("100 Run, then end with only Swim, makes a Swim type"), and fans believed the opposite for years [3]. The second evolution is a hidden slider from -1 to +1 on two axes with cut-offs at 0.5 [4]. | Keep "numbers item" and "look item" apart. Make the slider visible: our path meter is that slider with pips you can count. |
| Digimon World (1999) | Each form has four requirement groups (stats, weight, care mistakes, a bonus) and needs three of them [5]. Guides give different numbers for the same form. | Care history mattered; every raise was a different creature. | Nothing was shown, and "care mistakes" rewarded neglect for some forms. | The 2016 sequel lists "key points" in a menu [6]. We list every source of pips, and only positive actions count. |
| Tamagotchi | The adult depends on the count of care mistakes (0-1 best, 7+ worst on one model); a 2024 model splits them into physical and mental and lets minigames undo them [7]. | Simple cause and effect; minigames as a repair tool. | Punishes being away. | No mistake counter. Being away never moves a meter. |
| Monster Rancher 2 | Fatigue + 2 x stress is a hidden "lifespan index"; a hard drill adds 15 and 12; one item halves stress, another removes 28 fatigue; winning a tournament removes stress [8]. | A real trade: push harder or rest. Items as relief valves. | The cost was invisible, so fans built week-by-week planners. | Keep "relief items" (our Unwind Tea). No lifespan. Show the cost before the choice. |
| Ni no Kuni | Treats raise one stat each; a creature can gain 50 points in total across six stats; a stomach of ten pips empties one per battle; a matching "drop" item evolves it, and the last step offers two finals to pick from [9]. | A hard total made feeding a build choice. The stomach pips were readable. | Forms restart at level 1. | A total budget with a visible ring. The choice of final is shown at the moment it happens. |
| Pokemon effort values | Vitamins were capped at ten a stat until 2019; a 2013 training minigame added a graph of the spread and a meter of what is left [10]. Later games added items that lower a stat and items that change nature (m). | The graph turned a hidden system into a build screen. | Hidden for 15 years; refunds came late. | The graph and the refund from day one. |
| Pokemon contests | Flavoured snacks raise five show stats; each snack also adds "sheen", and at full sheen the creature can never eat again [11]. | Snack quality mattered more than quantity. | The cap was permanent, so a bad early snack ruined a contest creature. | Caps yes, permanent regret no. |
| Palworld | Duplicates are condensed into one creature for stars; souls spent at a statue raise a stat by a percentage and can be refunded in full for coins [12]. | The refund makes trying safe. | Feeding duplicates of your pets into a machine. | Refund. No sacrifice of Boki, ever. |
| Viva Pinata | A specific food recolours a species (one food or a pair); two of one seed evolves another; a journal lists the requirements in the handheld version; a recolour is one-time [13]. | Checklists you can read in the game are a to-do list, not a secret. | One-time changes. | The Boki card is the checklist. |
| Slime Rancher | A slime that eats another's plort becomes a hybrid of both; a favourite food doubles output; a third plort makes a pest [14]. | A two-ingredient rule with a known, gentle risk. | - | Our unstable mix (already in the Nook) and the Mixing Bowl showing its result. |
| Temtem | Fruits raise or lower trained values; an item adds one inborn point but costs fertility [15]. | Lowering fruits are a respec. Fertility ends the breeding ladder. | - | One nest, one egg (already in GARDEN.md 6). |
| Monster Hunter Stories 2 | Genes sit on a 3 x 3 grid; three in a line of the same kind give a bonus; moving a gene uses up the donor [16]. | Inheritance as a board you can see. | Donor loss. | The Nook preview shows what each nest item will pass on. |
| Final Fantasy VII birds | A nut used at mating picks the offspring's kind; greens raise racing stats; race rank gates the best pairings [17]. | Racing, breeding and items feed each other. | Recipes were hidden and guides disagree. | Ribbons from minigames count toward a form (one pip each), shown on the meter. |
| Cassette Beasts | Any two of 120 forms fuse into one of 14,000+ results; a stronger bond gives a stronger fusion [18]. | The result is visibly new. | - | Looks combine: lean part + aura + keepsake + mutation tell a Boki's story. |
| Neopets | Training costs random stones and hours of waiting; a daily ray changes a stat at random and can even change the species [19]. | One free surprise a day brought people back for 20 years. | A surprise that can wreck your pet. | A daily surprise that is always a gift (today's wishes). |
| Pokemon Sleep | Helpers have a carry limit; overflow goes straight to the big sleeper, even offline, so nothing is wasted [20]. | Leaving is safe. | - | Away overflow goes to the feeder bowl. |

### R2. Minigame suites that kept people coming back

- **Garden races and karate.** Races are mostly watched; in the sequel you cannot even cheer outside party mode [21]. Karate uses two hidden stats that only change a "zeal" bar [21]. Lesson: the four games we have built (back one Boki, one timed press) sit close to this. The next ones need real choices: reading, rhythm, aiming, steering, team order.
- **Pokeathlon.** Ten events in five courses of three, five performance stats, and a juice that lifts one stat and lowers another for the day [22]. Lesson: group games into short cups; let a prep item shift a Boki for one cup.
- **Contests.** Looks and care are scored, not strength [11]. Lesson: one game must reward the raising itself (our Show Ring).
- **Dance battles (Ooblets).** Loved for charm; reviews say they "never evolved enough" and became "an uninteresting formality" [23]. Lesson: a cute skin still needs growing difficulty and a real decision each round.
- **Camp cooking (Sword and Shield).** A short cooking game raises friendship, and friendship gives small clutch perks in battle [24]. Lesson: care pays out as small, bounded combat perks (we have Care.BONDS).
- **Idle and gacha pet loops.** Offline earnings are capped at 8 to 24 hours and shown on a welcome-back screen (weak sources [25]). First-win bonuses and three daily tasks are the standard return hooks (m). Lesson: cap the away gifts, keep the daily list to three, never take anything away.

### R3. The seven lessons used below

1. One item, one visible effect. Numbers items and look items are different things.
2. Every meter the game uses is on the Boki card, with its sources listed.
3. A total budget turns feeding into a build. A refund makes it safe.
4. Forms are picked by positive actions and shown as a silhouette before the choice.
5. Caps, not clocks: nothing waits on a timer except an egg.
6. Being away never costs anything; overflow is kept.
7. Minigames need a decision each round and should pay out the items.

---

## 1. Evolution-shaping items

### 1.1 Rules for every item

- **One item, one job.** Each item moves one thing. The item card says what, in one line, with the number.
- **Always shown.** Shaping items never use the "Effect: ?" discovery rule (ext/farm-food-journal). That rule stays for plain snacks only. A rare item you waste is a punishment, not a discovery.
- **Hold to preview** (1.3). The number you see is the number you get for this Boki, after caps.
- **Eaten or worn.** Eaten items are used up. Worn items (tokens, auras, keepsakes) can be taken off and given to another Boki at any time.
- **No timers, no belly limit.** Scarcity comes from where items drop; the caps in section 2 bound the total.
- **Sources.** Zone snack patch (a "golden ripening": 1 ripening in 6 adds one zone item), the zone's playthings (the dig patch finds things today), minigame prizes (4.4), the Mixing Bowl (1.4), hatching, the Drift Trader (one shaping item a week, gems), and expedition loot (any item here may also drop on runs at the coordinator's choice; nothing here requires a run).

### 1.2 Catalog (30 items)

| # | Item | Get it from | What it does | What you see |
|---|---|---|---|---|
| | **Stat bites** (eaten) | | | |
| 1 | Thumpnut | Cinderstep patch; Stump Shove and Tumble prizes | Power +3 | Power bar ghost segment "+3 (41 to 44)" |
| 2 | Shellbark Chew | Bramblebank dig patch; Stump Shove prize | Guard +3 | same, Guard |
| 3 | Zipseed | Kitewind patch; Dash and Relay prizes | Speed +3 | same, Speed |
| 4 | Hushpearl | Glint Fishing; Seek and Spark Volley prizes | Focus +3 | same, Focus |
| 5 | Fourfold Bun | Mixing Bowl: any two different bites | +1 to all four stats, ignores the bands in 2.2 | four small ghost segments |
| 6 | Sunsap | today's wishes; first win of the day; away gift | +40 garden XP | level ring ghost arc; "evolves at 16: 2 levels to go" |
| | **Path tokens** (worn, 3 slots, come back when taken off) | | | |
| 7 | Bristlethorn | Tumble cup; Cinderstep patch | 1 pip toward the Fierce final | path meter: one pip slides to that end, the silhouette brightens; a thorn charm on the Boki |
| 8 | Keepstone | Stump Shove cup; Bramblebank dig patch | 1 pip toward the Steadfast final | same; a stone bead |
| 9 | Puzzlenut | Echo Steps and Seek cups; Hushwood patch | 1 pip toward the Curious final | same; a carved nut |
| 10 | Galeribbon | Dash and Relay cups; Kitewind patch | 1 pip toward the Swift final | same; a ribbon on the tail |
| 11 | Stayleaf | Bramblebank nap tree; Drift Trader | The wearer does not evolve | the level ring shows a leaf lock: "staying small" |
| | **Lean** (eaten) | | | |
| 12 | Bramble Honey | Bramblebank golden ripening; Bowl: 3 snacks of one type | Pick Grass, Bug or Spore: that lean jumps to half (12 of 24) and does not fade for 7 garden days | lean ring fills to half in the type colour; the Boki tints for a second as a try-on |
| 13 | Glassdew | Glasswater ripening; Glint Fishing | same for Water, Ice or Crystal | same |
| 14 | Cinderbrittle | Cinderstep ripening; Tumble cup | same for Fire, Rock, Steel or Dragon | same |
| 15 | Hush Truffle | Hushwood ripening; Lantern Match | same for Dark, Psychic or Poison | same |
| 16 | Windfloss | Kitewind ripening; Echo Steps cup | same for Flying, Electric, Fairy or Sound | same |
| 17 | Rinse Melon | Glasswater patch; Drift Trader | Clears all lean. Parts already grown stay | lean ring empties; tint fades in the preview |
| | **Looks** (worn, one aura at a time; no stats) | | | |
| 18 | Glowmoss Sprig | Hushwood; Lantern Match | Aura: slow glow motes at night | plays on the Boki while you hold it |
| 19 | Mistbloom | Glint Fishing | Aura: a trail of mist in its lean colour | same |
| 20 | Chimegrass | first Echo Steps Crown | Aura: soft notes when it is happy or wins | same, with sound |
| 21 | Cup Ribbon | only from winning a Crown cup (4.4) | Keepsake naming the sport; counts as 1 ribbon pip (3.2) | ribbon on the Boki; a row on its card |
| | **Personality** (eaten; counts inside the weekly drift cap of 0.12) | | | |
| 22 | Dare Pepper | Cinderstep patch | bravery +0.04 | trait bar ghost tick; "Nature: Gentle, would become Daring at 0.62" |
| 23 | Lullwort Tea | Glasswater patch | temper -0.04 (calmer) | same |
| 24 | Peekbox | Hushwood; Lantern Match | curiosity +0.04 (it has to open the box itself) | same |
| 25 | Twinbun | Bramblebank patch; Bowl: 2 sweet buns | Two Boki share it: loyalty +0.04 each, their bond +0.1 | both cards side by side; the bond line thickens |
| | **Nest** (placed in the Nook with a pair) | | | |
| 26 | Heirloom Thread | Soul Shrine mentor gift; rare Crown prize | The baby takes 4 inborn gifts from its parents, not 3 (two Threads: 5). Uses the existing Care.IV_INHERIT_MAX hook | Nook preview: "4 of 5 gifts from parents" |
| 27 | Likeness Locket | Show Ring cup | Worn by one parent: the baby is that parent's species (not 50/50) | Nook preview shows one species, not two |
| 28 | Lullaby Shell | Glint Fishing (rare) | Worn by one parent: the baby gets that parent's habit and strongest trait with no wobble | Nook preview names the habit and trait |
| 29 | Hatchling Down | drops at every hatch | Feed to any Boki: trust +3 and a memory line about the baby. Also a Bowl ingredient | trust ring ghost; the line it will remember |
| | **Respec** (eaten) | | | |
| 30 | Unwind Tea | Drift Trader; today's wishes | Pick a stat: up to 20 points come out and become loose points. Loose points go back into any stat at double speed and ignore the bands | the bar shrinks, a "20 loose" chip appears |

Already in the game and unchanged: the 18 type snacks (small lean, 6 of 24 a meal), Inks (force a branch for Minkee and Jarmit), Wayseeds (open a zone), Rare Eggs, soul echoes.

### 1.3 How the player sees the nudge

Hold an item near a Boki (or hover it in the feed menu). Its card slides in with every change drawn as a ghost. Release on the Boki to give it; walk away to cancel.

```
 PIP  the Sporcupine   Lv 14   Nature: Gentle          [holding: Keepstone]
 Power  ████████████░░░░░░░░  46        Budget  ◔ 152 of 240
 Guard  ██████████░░░░░░░░░░  38        Lean    ◑ Grass (full)
 Speed  ██████░░░░░░░░░░░░░░  24        Loose   0
 Focus  ███████████░░░░░░░░░  44

 PATH   [Amanitusk]  ●●●○○○ | ○○●●●●+◌  [Ringrove]     evolves at Lv 16
         Fierce 3                    Steadfast 5 -> 6
         stat lead ●●●               lean ●●  tokens ●●+◌  loyal ●
 "With this Keepstone Pip keeps growing toward Ringrove (6 to 3)."     [Why?]
```

- **Ghost segments** show the gain with the real number after caps ("+3" becomes "+2, upper band").
- **The path meter** has the two finals as silhouettes. A form you have never met is a black shape with "?" for a name; the shape is still the real one.
- **Try-on.** Tint, aura or token appears on the model for a second while you hold the item.
- **Why?** lists every pip and where it came from. All numbers live in content/rules and the card reads them from there.
- **After.** One journal line with the cause ("wore a Keepstone: 1 step toward Ringrove"), as ext/farm-stat-causes does for stats.

### 1.4 The Mixing Bowl (the only crafting)

A bowl at the Drift Trader's stall in the hub. Put in two or three things; the bowl shows the result before you confirm. Six recipes, all listed on the bowl from the start: Fourfold Bun (two different bites), the five zone sweets (three snacks of one type from that zone's group), Twinbun (two sweet buns). No recipe hunting, no failures. This is one screen, not an economy; it is the smallest thing that makes spare snacks useful.

## 2. Stat model

### 2.1 What exists, and where the garden touches it

No new combat stat is added. Everything below is in the code today (scripts/core/care.gd, content/kin_v2).

| Thing | Field | What moves it in the garden | In an expedition (Care.match_mods) | In minigames |
|---|---|---|---|---|
| Power | rec.stats.power | toys, the drill, bites | +0.4% damage a point | push in Stump Shove and Tumble |
| Guard | rec.stats.guard | same | +0.5% health a point | hold in Shove; stamina in Kite Tow |
| Speed | rec.stats.speed | same | +0.25% move speed a point | pace in the Dash and Relay |
| Focus | rec.stats.focus | same | skill recharges 0.3% faster a point | timing windows, tells, tracking |
| Trust | rec.trust (0-100) | petting, habit food, wins, Hatchling Down | Close (50): skills +5%. Soulbound (90): +10% health and damage | small edge; remembers a step in Echo Steps |
| Condition | the four needs | feeding, play, naps | 0.82 to 1.1 on damage and health | mood changes pace and push |
| Element lean | rec.lean | snacks, zone sweets | GARDEN.md Q2: a 5% edge. **Not in match code yet** | its own stretch, a 10% type edge |
| Affinity | rec.aff | food, expeditions, traits | picks stat-flavour nodes | - |
| Traits | rec.traits (4) | friends, zone, personality items | the Boki's AI and nature | tells in Tumble; the Bond round |
| Inborn gifts (IVs) | rec.ivs (hp, atk, spd, work, bond) | **nothing**; fixed at birth. Heirloom Thread only changes what a baby inherits | up to +10% (+5% speed) | - |
| Species base stats | kin_hp, kin_damage, kin_speed, owner_max_hp, owner_move_speed | **nothing** | the species' kit | - |
| Mutations, shimmer, size | rec.muts and others | **nothing** (GARDEN.md 3: flavour, not levers) | perks kept within 0.85 to 1.15 | - |

Stats this brief does **not** invent: stamina, luck, intelligence, charm. Games that need "stamina" read Guard plus the energy need; the Show Ring scores looks and care directly.

New save fields (each defaulted in Care.ensure, so old saves load): rec.path (worn tokens), rec.ribbons, rec.aura, rec.loose (loose points), rec.stay (Stayleaf). Garden XP uses the existing rec.xp and rec.level.

### 2.2 Caps and diminishing returns

Today a stat's cap is 12 + 6 a level and nothing limits the total. That was written for a low level cap; at the level cap of 100 (DECISIONS 11-08) it allows 612 points a stat.

- **100 a stat.** The level rule stays as the early gate (level 1: 18, level 8: 60) and stops at 100, reached at level 15.
- **240 in total** across the four stats, shown as the budget ring. Two stats at 100 and 40 to spare, or 60 in each. This is what makes two Boki of one species different.
- **Three bands, shown on the bar.** Points 1 to 50: full gain. 51 to 80: half (a bite gives +2, a toy gives a point every second play). 81 to 100: quarter (a bite gives +1, a toy a point every fourth play). The card always says "next point: 3 more plays".
- **Old saves:** a Boki over a cap keeps its points and simply cannot gain more. Nothing is taken.

### 2.3 In expeditions: the first 25 points count

Expeditions read at most 25 points of each stat: +10% damage, +12.5% health, +6% speed, 7.5% faster skills, about the size of the IV cap. This is the "+10% cap" GARDEN.md already promises, made real. Minigames read all 100, so depth past 25 is for the garden's own sports. The number lives in content/rules/care.json. It changes combat, so it needs a design note (AGENTS.md 1). Alternatives are in question 1.

### 2.4 Respec

- **Stats:** Unwind Tea (item 30). The points are not lost; they come back at double speed.
- **Lean:** Rinse Melon, or simply feed another type (leans fade as another grows; that exists).
- **Path:** take the tokens off. They return to your bag.
- **Personality:** drifts back toward its friends on its own (base_drift.json).
- **Never respec-able:** IVs, species, a final form once taken (question 4).

### 2.5 Garden XP (so a home-raised Boki can evolve)

Today only expeditions give XP (about 40 to 120 a run; level n needs 100 x n). Proposal, all numbers in content/rules/garden_xp.json:

- A minigame: 8 XP to each Boki that played, 15 to the winner. **The first win of the day in each game: three times that.**
- The first care of each kind in a garden day (a meal, a pet, a play): 3 XP.
- Sunsap: 40 XP.

A daily visit with three first wins gives about 150 XP, the same order as two runs. Playing one game twenty times in a row gives little, on purpose. The XP curve itself (100 x level up to level 100) is outside this brief and is flagged for the balance pass (backlog 13).

## 3. Evolution branching

### 3.1 What is already decided (kept)

- Every species has its own evolution level. A Boki never evolves into a form whose art is not in the game; it waits (DECISIONS 11-08).
- Four lines end in one of two finals: Mycroll, Vespyx, Prismander, Echolop. The two finals share one Bokidex entry (GAME_RULES_NOV8 3).
- Inks decide Minkee (nine forms) and Jarmit (three). Each line has at most one special rule.
- Base food never forces a branch (GARDEN.md 3).

### 3.2 The rule: count the pips

Each branching line has a path meter. Each final is one end. Pips come from five visible sources:

| Source | Pips | Rule |
|---|---|---|
| Stat lead | 3 | The end whose key stat is higher gets 3. Fierce: Power. Steadfast: Guard. Swift: Speed. Curious: Focus. This is the 11-08 rule, and with nothing else it still decides alone. |
| Element lean | up to 2 | Each final has a second type. A lean of half or more in that type: 1. A full lean: 2. |
| Path tokens | up to 3 | One for each token worn (items 7 to 10). |
| Care | up to 2 | The end's trait at 0.6 or more: 1 (Fierce: bravery or temper. Steadfast: loyalty. Curious: curiosity. Swift: bravery). Its most-used toy trains the end's key stat: 1. |
| Ribbons | up to 2 | One for each Cup Ribbon in the end's sport (Fierce: Tumble. Steadfast: Stump Shove. Curious: Seek, Spark Volley, Echo Steps, Lantern Match. Swift: the Dash, Relay Cup). |

- **The end with more pips is the form.** On a tie the stat lead decides. If that is tied too, the Boki waits and the card says "undecided: tip it either way".
- **You press Evolve.** At its level the Boki glows and the card offers "Evolve now" (showing the silhouette) or "Not yet". Not yet is free and lasts as long as you like. So the meter is never a trap, and the player never picks the form from a menu either: you change the form by changing the Boki.
- **Why not stats alone?** With stats alone the form and the build are the same choice: every Ringrove is a Guard Boki. With pips, a fast Ringrove exists, at the price of tokens, lean and care. That is the "items change how they evolve" the owner asked for.
- **General rule for three ends** (for a later line): same table, three ends, most pips wins, ties as above.

### 3.3 Worked examples (real lines)

**Mycroll > Sporcupine > Amanitusk (Fierce, Spore/Poison) or Ringrove (Steadfast, Spore/Grass).** Pip is a Sporcupine at level 14 with Power 46 and Guard 38: stat lead gives Amanitusk 3. You fed it sunroot to a full Grass lean: Ringrove 2. It wears two Keepstones: Ringrove 2. Its loyalty is 0.7: Ringrove 1. The meter reads 3 to 5 and the card says "growing toward Ringrove". Feed it Hush Truffle (Poison) instead and take the stones off, and the same Pip becomes Amanitusk.

**Vespyx > Vespox > Glaivyx (Fierce, Poison/Steel) or Lashyx (Swift, Poison/Dark).** A Vespox that lives in Cinderstep, eats Steel snacks and wins the Tumble cup stacks Glaivyx: stat lead 3 (Power), lean 2, ribbon 1. To get a Lashyx from the same hot-headed fox: a Dark lean from Hushwood (2), two Galeribbons (2), a Dash ribbon (1) and Speed above Power (3).

**Prismander > Glassolotl > Chandelotl (Curious, Crystal/Fairy) or Geodelotl (Steadfast, Crystal/Rock).** The splash tub trains Focus, so a Glassolotl that loves its tub drifts to Chandelotl on its own (stat lead 3, toy habit 1). Starfruit (Fairy) adds 2. A player who wants Geodelotl moves it to Cinderstep: the warm stone trains Guard, the patch grows Rock snacks, and Keepstones finish it.

**Echolop > Howlop (Fierce, Sound/Dark) or Chimelop (Curious, Sound/Fairy).** A two-stage line, so this is the first branch most players meet. An Echolop that wins Echo Steps earns a curious ribbon and Chimegrass: Chimelop. One raised among rivals in Hushwood with a Dark lean and a Tumble ribbon: Howlop.

**Jarmit > Lanternmit, Stormit or Terrarimit (three ends, by Ink).** The Ink decides alone. The garden adds the preview: hold an Ember Ink near Jarmit and the card shows the Lanternmit silhouette and "art not in the game yet: it will wait" when that is the case. No pips. Same for Minkee's nine Inks.

**A line with no branch: Teapotamus > Puffamus > Chuggamus (Fire, then Fire/Steel).** The form is fixed; the finish is yours. Its lean grows a part at the next form (lean.json: Rock gives plates, Flying gives wings), its aura and keepsakes stay on, and when the lean matches the type the next form adds (Steel for Chuggamus; Flying for Kindlewren's final, Pyrraven) the evolution scene plays a "true bloom": the new part comes in the lean's colour and the journal keeps the line. Looks only, no stats. Every one of the 100+ linear forms gets this for free.

### 3.4 What this needs

rec.path, the meter on the Boki card, a per-line table in content/rules/evo_paths.json (ends, key stat, second type, trait, sports), and the Evolve prompt. The old "form every 4 levels along the strongest affinity" in evo.gd is already being replaced by real form swaps (GAME_RULES_NOV8 2); the meter is how the swap picks its end.

## 4. Minigames

### 4.1 Built today (ext/garden-integrated), kept

| Game | Zone | Stat | Your input |
|---|---|---|---|
| The Dash | Bramblebank, Kitewind | Speed, lean on its stretch | three timed cheers |
| Stump Shove | Cinderstep | Power against Guard | one timed shove |
| Seek | Hushwood | Focus, curiosity | where you hide the item |
| Spark Volley | Glasswater | Focus, Speed | call the spike |

All four are "back one Boki and press once". The seven below each add a different kind of play. Any Boki can enter any game. A match is two of your Boki, yours against a garden visitor, or yours against a friend's Boki from their visit snapshot (it plays by its own nature, so no live connection is needed).

### 4.2 The seven new games

**1. Tumble (FIRST BUILD).** A duel on Cinderstep's warm ledge.
- Rules: best of five exchanges in a ring three steps deep on each side. Both sides pick one move at once: Rush (Power), Brace (Guard) or Dodge (Speed). Rush catches Dodge, Dodge gets around Brace, Brace throws back Rush. The winner pushes the loser one step, two if its stat for that move is 20 or more above the loser's. The same move is a clash: the higher stat pushes half a step. Pushed out of the ring, or further back after five: you lose. The type edge is 10% (the Shove table).
- The read: before each exchange the rival shows a tell for 1.5 seconds. Hot-tempered Boki rush more, loyal ones brace, curious ones dodge, and the tell is marked "probably". The Boki with the higher Focus gets the more honest tell (right 7 times in 10, otherwise 5 in 10). Your own Boki shows what it wants to do; going with it gives a 10% stronger push and trust, overriding it is free.
- Controls: 1, 2, 3 (or click a move) within 3 seconds, then one timed press on impact for a clean hit (the drill bar we have).
- Stats: Power, Guard and Speed all matter; Focus reads. Length: 60 to 75 seconds.
- Prizes: gems; Thumpnut; cup: Bristlethorn, Cinderbrittle.
- Why first: it is the duel the owner named, it uses three stats so builds matter, it reads on video, it works against friends' Boki, and it reuses the Shove ring, the drill bar and the brace and push clips.

**2. Echo Steps (FIRST BUILD).** A call-and-answer dance on four humming stones on Kitewind Ridge.
- Rules: three rounds of 4, 6 and 8 beats at 100 beats a minute. The lead Boki hops a pattern across the stones; each stone has a note. You answer by sending your Boki to the same stones on the beat. In round three you make the pattern and the rival copies; its Focus decides how many it misses. Hits and streaks score.
- Stats: Focus widens the "good" window (120 ms, up to 180 at Focus 100). Trust: at Close the Boki fixes one miss a round for you, at Soulbound two ("it remembered"). Sound types and leans keep a streak through one miss.
- Controls: W, A, S, D for the four stones. Length: 90 seconds. Solo for a score or against a Boki.
- Prizes: gems; Hushpearl; cup: Puzzlenut, Windfloss; first Crown: Chimegrass.
- Why first: nothing else here uses rhythm or sound, the Sound type finally has a home game, the moves can be hops and spins on the existing rig, and it is the cutest 20 seconds for a trailer. Difficulty grows by tempo and pattern length, which answers the research warning about dance games that never get harder.

**3. Show Ring.** A judged show on a small stage by the games board in the hub.
- Rules: three rounds. Look: up to 10 points for joy, cleanliness, a full lean ("in full colour"), grown parts, an aura and keepsakes. Trick: a three-press timing trick picked by its best stat. Bond: it walks to you past a snack, a toy and a rival; you call at the right moments; trust and loyalty shrink the pull. Three judges, retired mentors where you have them, each post this week's taste on the board beforehand (a zone's types, a trait).
- Stats: care and looks first, trust second. Length: 2 minutes.
- Prizes: Likeness Locket, auras, the weekly photo on the showcase wall.
- Why: the only game that rewards the raising itself. Build it third, once auras and keepsakes exist.

**4. Glint Fishing.** Solo, with your Boki, on a rock in Glasswater Shallows.
- Rules: five casts. Hold to set the distance to a glint, wait, hook when the Boki's ears go up (Focus gives 0.3 to 0.8 seconds of warning), then hold and release to keep the line in the band while the Boki pulls (Power widens the band). A sign on the rock lists what is biting today. A Water lean doubles rare glints.
- Length: 2 minutes. Prizes: this is the item tap for home players: Hushpearl, Glassdew, Mistbloom, Rinse Melon, snacks, rarely a Lullaby Shell; a weekly "big one" for the wall.

**5. Relay Cup.** Three of your Boki against three, on the Dash loop in Bramblebank.
- Rules: you pick who runs the straight, the water and the climb, so lean and stats decide the order. Two hand-offs, each a timed press. Friends (bond 0.5 or more) hand off cleanly on their own; rivals fumble 0.3 seconds unless your press is perfect.
- Stats: Speed, lean, friendships. Length: 60 seconds. Prizes: Zipseed, Twinbun; cup: Galeribbon.
- Why: cheap (it reuses base_race) and the only game where your friendships are the stat.

**6. Lantern Match.** A memory game in Hushwood.
- Rules: twelve glowcaps in a ring flash in pairs, then go dark. Open two at a time to find the pairs. Every few seconds (faster with Focus) your Boki sniffs and points at the partner of the last cap you opened, if it saw it; a curious Boki points more often. Solo against the clock, or turn by turn against a Boki.
- Length: 90 seconds. Prizes: Peekbox, Glowmoss Sprig, Hush Truffle.

**7. Kite Tow.** A steering course on Kitewind Ridge.
- Rules: your Boki glides on a kite through twelve rings. Speed sets the pace. Flaps are limited (3, plus 1 for every 25 Guard); updraft vents give one back. A missed ring costs a second.
- Controls: A and D to steer, Space to flap. Length: 75 seconds. Prizes: Zipseed, Windfloss.
- Why last: the most game-like, and the most new code (glide steering). Large; split in two jobs when its turn comes.

### 4.3 Which stat matters where

| Stat | Games |
|---|---|
| Power | Stump Shove, Tumble (Rush), Glint Fishing (reel) |
| Guard | Stump Shove, Tumble (Brace), Kite Tow (flaps) |
| Speed | The Dash, Relay Cup, Tumble (Dodge), Spark Volley, Kite Tow |
| Focus | Seek, Spark Volley, Echo Steps, Lantern Match, Glint Fishing (bite), Tumble (tells) |
| Trust, care, looks | Show Ring, Echo Steps (remembered steps), every "go with what it wants" bonus |
| Friendships | Relay Cup |

### 4.4 Prizes, cups and ribbons

- **Any match:** gems as today (base_race.json and the others), garden XP (2.5), and one roll on that game's prize table for the winner. The table is printed on the games board.
- **First win of the day** in each game: a guaranteed item from the table and triple XP.
- **Cups.** Each game has a weekly cup of three matches in a row against stronger rivals: Sprout, Bloom, Crown. Winning the Crown gives that game's Cup Ribbon to the Boki that won it (item 21) and the cup prize. One Crown a game a week for each Boki, so ribbons stay worth having.
- Losing costs nothing but a short sulk and a memory line, as today.

## 5. More stuff, ranked by fun per build day

| Rank | Feature | What it is | Build |
|---|---|---|---|
| 1 | **Today's wishes** | Each garden day three of your Boki each wish for one thing (a snack, a game, to see a friend in another zone). kin_wants.gd already picks wants; this puts three on one card at the Waystone. Granting one gives trust, 3 XP and a small item; all three give a Sunsap. Miss a day and nothing happens. | 0.5 day |
| 2 | **First win of the day** | Section 4.4. The cheapest return hook there is. | with prizes |
| 3 | **Away gifts, capped** | The away card stays. Add: for each 2 hours away one Boki saves you a small gift, three at most (8 hours fills it). Toys train at a quarter rate while you are away, at most 3 points a Boki. Patch overflow goes to the feeder bowl. Nothing ever drops. | 0.5 day |
| 4 | **Duo tricks and grudge matches** | Friends (bond 0.6 or more) get a duo bonus: clean hand-offs, a joint trick in the Show Ring, a shared nap that restores more joy. Rivals sometimes stand at the games board with a bubble: accept the grudge match and the prize doubles; afterwards the rivalry cools a little. Uses rec.bonds as it is. | 1 day |
| 5 | **Cups and ribbons** | Section 4.4. Gives every game a weekly goal and feeds the path meter. | 1 day |
| 6 | **Wild visitors** | A wild Boki wanders into a zone when the zone suits it (a toy it likes plus two residents of its type group), stays one garden day, and plays your games as a rival. Feed it its favourite three times and it leaves an egg, or asks to stay if there is room. The zone card shows who might come and what is missing. | 1 day |
| 7 | **Decor with a purpose** | Each decoration has one comfort tag (cosy, bright, wild, quiet). A zone with three of a tag gets a small named effect shown on its card: cosy, naps restore more; wild, visitors come more often. Four effects, no scores to chase. | 1 day |
| 8 | **Family tree** | The Boki card gets a lineage tab: parents, grandparents, the mentor's gift, which nest items were used. Data is saved today (uid and lineage). | 0.5 day |
| 9 | **Seasons** | Every two weeks one zone is "in season": its cup has a twist (a night Seek, a Dash with two water stretches), its patch grows one seasonal snack, and the Crown gives a seasonal keepsake. Reuses the weekly-event rotation in GARDEN.md 5. | 1 day, then data |
| 10 | **Sleepovers and gifts** | Send a Boki to a friend's garden for a day (their visit snapshot shows it). It comes home with a memory line, a small trait nudge toward their Boki and a gift from their patch. This is also how "evolves by trade" species evolve (DECISIONS 11-08) without giving a Boki away. Gift an egg or an item through the same door. Later the Drift Pens listing can carry item trades. | 2 days (needs the social backend) |
| 11 | **Item pages in the Field Book** | A page for each shaping item once owned: what it did, to whom. A star for each family completed. | 0.5 day |

The daily loop these make (about five minutes): arrive at the Waystone, read the away card, collect gifts and patches, grant a wish or two, take a first win, hold the prize up to a Boki and look at what it would do, check the path meter. Stay longer for a cup, a breeding pair or a visitor.

## 6. Build plan

Thirteen jobs, each under a day for one agent, appended to /home/boki/cj/backlog.proposed.jsonl. All branch from origin/main once it has the garden (scripts/home/base_life.gd), otherwise from origin/ext/garden-integrated. Each adds a check and passes `python3 tools/health.py --strict`.

| # | Label | Role | Needs |
|---|---|---|---|
| 1 | Item engine: garden_items.json, apply and preview, first 12 items | build | - |
| 2 | Stat budget (100 a stat, 240 total, bands) and the expedition clamp, with a design note | build-spec | - |
| 3 | Hold-to-preview card (ghost bars, lean ring, try-on) | feel | 1 |
| 4 | Path meter and the Evolve prompt for the four branching lines | build-spec | 1 |
| 5 | Garden XP, first win of the day | build | - |
| 6 | The nine missing type snacks and each zone's patch list | build | - |
| 7 | Prize tables for the four built games, cups and Cup Ribbons | build | 1 |
| 8 | Tumble | feel | 7 |
| 9 | Echo Steps | feel | 7 |
| 10 | Today's wishes and capped away gifts | build | 1 |
| 11 | Mixing Bowl, zone sweets, Fourfold Bun, Twinbun, personality items | build | 1 |
| 12 | Nest items in the Nook (Heirloom Thread, Likeness Locket, Lullaby Shell, Hatchling Down) | build | 1 |
| 13 | Balance pass: simulate 30 days for three kinds of player, tune the numbers | deep | 1, 2, 5 |

Order: 1, 2, 5, 6 in parallel; then 3, 4, 7, 10; then 8, 9, 11, 12; then 13. Later, not in this batch: Glint Fishing, Show Ring, Relay Cup, visitors, duo tricks, seasons, Lantern Match, Kite Tow, sleepovers.

## 7. Open questions for the owner (defaults in bold)

1. **How much do garden stats count on expeditions?** **Default: the first 25 points of each stat, about +10%, as GARDEN.md says.** Alternatives: 50 points (about +20%: raising matters more, equal footing less), or no clamp (today's code: a level-16 Boki can have +43% damage and +54% health).
2. **Can pips outvote the stat lead?** **Default: yes. Stats give 3 pips; lean, tokens, care and ribbons can add up to 9 for the other end.** Alternative: stats always decide (the 11-08 rule as written) and items only break ties.
3. **Curious finals (Chandelotl, Chimelop): which stat?** **Default: Focus, since the roster calls them Curious and Focus has its own drill.** Alternative: Speed, as the 11-08 table says (written when the post trained three stats).
4. **Is a final form permanent?** **Default: yes. Raise a second one for the other form; owning both gives the "both forms" star.** Alternative: a very rare item that lets a final re-choose once.
5. **Can home players get Inks?** **Default: yes, slowly: the Drift Trader stocks one Ink a month, and a season's Crown prize may be one.** Alternative: Inks stay expedition-only (then Minkee never evolves for a home-only player).
6. **A crafting bowl at all?** **Default: yes, six recipes shown from the start, one screen.** Alternative: no bowl; zone sweets come only from patches and prizes.
7. **A third final for any line?** **Default: no new forms; every line gets finishes (3.3) instead.** If wanted later, candidates that fit the roster: a Swift final for Echolop (Sound/Flying) and a Curious final for Mycroll (Spore/Psychic). Each needs art first.
8. **Where does the Show Ring stand?** **Default: a small stage by the games board in the hub (a fixture, not a toy; one Boki on it at a time).** Alternative: it rotates between zones each week.
9. **Total stat budget.** **Default: 240 (two stats full, or all four at 60).** Alternative: 300 (three stats full) if builds feel too tight in the balance pass.

## 8. Proposed changes to existing docs (not applied)

- **GARDEN.md 2 and 3:** "better stats inside the +10% cap" becomes a real rule: section 2.3 here. Today there is no such cap on trained stats.
- **GARDEN.md 3, lever 2:** add the 100 and 240 caps and the bands (2.2).
- **GARDEN.md 3, lever 4:** "Base food never does these" stays true for Inks. Add: worn tokens and lean count as pips on lines that branch by raising (3.2).
- **GARDEN.md 5:** add the seven games, cups and ribbons (4).
- **GARDEN.md 10.1:** the hub gains two fixtures at the stall and board: the Mixing Bowl and the Show Ring stage. "No toys in the hub" stays.
- **GARDEN.md 10.2:** each zone hosts two or three games, not one: Bramblebank (Dash, Relay Cup), Glasswater (Spark Volley, Glint Fishing), Cinderstep (Stump Shove, Tumble), Hushwood (Seek, Lantern Match), Kitewind (ridge Dash, Echo Steps, Kite Tow).
- **GARDEN.md 10.2:** "every zone's patch grows its types' snacks from lean.json" needs nine new snacks: lean.json has none for Ice, Rock, Dragon, Dark, Poison, Bug, Steel, Crystal or Sound. Backlog 6.
- **GAME_RULES_NOV8 3:** "the final form is set by which trained stat is higher" becomes "stat lead is worth 3 pips of the path meter" (question 2), and Curious finals use Focus (question 3).
- **ext/farm-food-journal:** the "Effect: ?" rule applies to plain snacks only, never to shaping items (1.1).
- **Home levelling:** new. No doc covers it; section 2.5.

## 9. Sources

1. Chaos Drives, SA2: https://chao-island.com/info-center/training-sa2/chaos-drives.html
2. Feeding and fruit: https://chao-island.com/info-center/basics/feeding ; fruit prices and effects: https://www.cheatcodes.com/guide/chao-guide-and-faq-sonic-adventure-2-battle-gamecube-25880/
3. Evolution is set by recent items, not the highest stat: https://chao-island.com/info-center/life-cycle/evolution
4. The hidden -1 to +1 sliders: https://chao-island.com/guides/chao-hacking/hacking-pc/chao-offsets/chao-evolution.html ; type priority: https://retroachievements.org/forums/topic/16197 (search summary)
5. Digimon World, three of four requirement groups: https://almarsguides.com/retro/walkthroughs/PS1/Games/DigimonWorld/Misc/RaisingDigimon/ ; https://www.video-games-museum.com/en/faqs/Playstation/26217-Digimon-World.pdf (numbers differ between guides)
6. Digimon World: Next Order key points: https://gamerjournalist.com/?p=189937 (search summary only)
7. Tamagotchi care mistakes: https://gotchi-garden.blogspot.com/p/connection-20th-anniversary-character.html ; https://pausedisk.pages.dev/posts/tamagotchi-smart-colours-cases-888287
8. Monster Rancher 2 fatigue, stress and items: https://legendcup.com/MRM/discus/messages/12/16540b0c.php ; https://almarsguides.com/retro/walkthroughs/PS1/Games/MonsterRancher2/HowToRaiseMonster/FatigueandStress/ ; planner: https://legendcup.com/mr2trainingplanner.php
9. Ni no Kuni treats and metamorphosis: https://primagames.com/news/ni-no-kuni-wrath-white-witch-familiar-basics-feedi ; https://primagames.com/games/ni-no-kuni/news/ni-no-kuni-familiar-metamorphosis
10. Effort values, vitamins and Super Training: https://pokemondb.net/pokebase/434845/training-changed-between-older-pokemon-games-emerald-shield ; https://vgcguide.com/ev-training ; https://bulbapedia.bulbagarden.net/wiki/Talk:Super_Training
11. Contest condition and sheen: https://bulbapedia.bulbagarden.net/wiki/Condition ; https://bulbapedia.bulbagarden.net/wiki/Pok%C3%A9block ; https://www.smogon.com/ingame/guides/rse_contest_guide
12. Palworld condenser, souls and refund: https://xgamingserver.com/blog/palworld-pal-condensing-souls/ ; https://palworld.fandom.com/wiki/Statue_of_Power (guides disagree on the maximum, 30% or 60%)
13. Viva Pinata variants and evolving by food: https://vivapinata.fandom.com/wiki/Variant ; https://www.gamepressure.com/vivapinata/cluckles-cocoadile-sour-cocoadile/z3883
14. Slime Rancher hybrids: https://slimerancher.fandom.com/wiki/Slimes ; https://gamespot.com/articles/slime-rancher-2-tips-for-new-players-avoiding-the-tarr-plort-pricing-and-more/1100-6508028/
15. Temtem training values and fertility items: https://temtem.wiki.gg/wiki/Training_Values ; https://temtem.wiki.gg/wiki/Telomere_Hack_-_ATK
16. Monster Hunter Stories 2 genes: https://windowscentral.com/monster-hunter-stories-2-rite-channeling-guide ; https://www.pcgamer.com/au/monster-hunter-stories-2-gene-rainbow-rite-of-channeling
17. Final Fantasy VII breeding and racing: https://jegged.com/Games/Final-Fantasy-VII/Side-Quests/Chocobo-Racing-and-Breeding.html ; https://www.cavesofnarshe.com/ff7/chocobo.php
18. Cassette Beasts fusion: https://www.cassettebeasts.com/2020/05/11/fusion/ ; https://wiki.cassettebeasts.com/wiki/Fusion
19. Neopets training and the lab ray: https://www.thedailyneopets.com/battledome/mystery-island-training ; https://pinkpt.com/sub_basictrainingandweapon.htm
20. Pokemon Sleep carry limit and overflow: https://game8.co/games/Pokemon-Sleep/archives/419790
21. Garden karate and races: https://info.sonicretro.org/Chao_Karate ; https://chao-island.com/wiki/Chao_Races_(SA2)
22. Pokeathlon and its juice: https://bulbapedia.bulbagarden.net/wiki/Pok%C3%A9athlon ; https://bulbapedia.bulbagarden.net/wiki/Aprijuice
23. Ooblets dance battles in reviews: https://gameinformer.com/review/ooblets/a-cheerful-grind ; https://rpgfan.com/review/ooblets ; https://godisageek.com/?p=266798
24. Camp and curry: https://bulbapedia.bulbagarden.net/wiki/Pok%C3%A9mon_Camp ; https://www.imore.com/pokemon-sword-and-shield-cooking-guide
25. Offline caps in idle games (weak, mostly guide sites): https://blog.clickerheroes.com/offline-progression-in-clicker-heroes/ ; https://tapdynasty.pages.dev/idle-game-offline-earnings-explained/
