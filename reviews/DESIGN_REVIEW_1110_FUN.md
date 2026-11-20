# Design review 11-10, lens: FUN

Reviewer: Fable worker (rpc1), 2026-11-10. Read-only: no code, no DECISIONS edits. Read every source in the brief (DECISIONS wins), plus decision 0039 and `boki_summon.json` on the summon branches.

## Verdict

1. The loop is the right loop, and the garden half is the best-designed thing in the project: kind rules, visible causes, a real first ten minutes.
2. The seam between the halves breaks the garden's promise: a caught Boki is lost with the deathbox about 7 runs in 10, the first form change is weeks away, and "up to three Boki" out exists in one doc only.
3. Nobody owns the first hour as one sequence. Four docs each own a slice, and together they put two menus in front of the first Boki.

## Findings, ranked by impact on a player

### 1. The first catch dies with you
LIMITED_WAY_OUTS 7: "Carried loot (gems, seeds, goods, scans, belt, backpack): lost, into the deathbox as today." Same section: "Your own Boki always come home, at every tier." A scan is a catch (`capture.json`, box of 3). Section 1: "At most 4 of 10 squads (12 of 30 Hunters) get out. Expected about 3." So "I caught it", the peak of a creature game, is undone about 7 times in 10, and for the new player nearly always. CHAO_CORE 3 promises the opposite: "a Boki never dies or leaves from neglect (sulky at worst), stats never go down".
Fix: a scanned Boki is soul-linked at the scan (the lore says a linked soul "always finds its way home"). At tiers 0 and 1 it rides home as a wisp whatever happens; carried loot still dies. At The Hollow a catch stays loot. Extraction keeps its stakes on gems and gear; the collector keeps the creature. Same seam, smaller: CHAO_CORE 4 pays a lost run "XP, a journal line, and tired Boki", nothing you can hold up to a Boki. Let the wisp eat wild snacks on pickup, so lean points survive a wipe and every run changes a Boki at the homecoming.

### 2. Two menus before the first Boki
CHAO_CORE 2: "A new save lands in Bramblebank, not the hub: the first thing on screen is a Boki, not a menu." DECISIONS 11-10: "The opening "Choose your first Mask" offers three: Lace, Kael, Vex." DECISIONS 11-08: "The 3 starter eggs (cindle, puddlet, burrlet) stay front and obvious". Together: captions, a Mask menu, an egg menu, then a garden whose 0:00 beat has a starter "waiting for you" plus a welcome egg, as if the egg pick never happened.
Fix: one owner-signed first-hour order. Recommended: garden first, and the hatch scene IS the 0:00 beat (three eggs on the bank, the black one half hidden). The Mask pick moves to the portal at 9:30 as the put-on beat DECISIONS already asks for ("First portal: the put-on beat"): you are the Empty at home, the Mask is for leaving. Then the 9-beat combat tutorial, then the first real drop near minute 20.

### 3. "Up to three Boki" out lives in one doc
CHAO_CORE summary 4: "You take up to three Boki on an expedition." WISP_DESIGN_OPEN Q3: "one summoned Boki at a time, per Hunter, in every tier. More Boki means more summons, never more bodies." DECISIONS Boki HUD: "your Boki lives in the right-side box", one. Nothing designs three passives, three rings or 90 wisps on screen, and the tutorial teaches one.
Fix: one Boki per run in 0.24.4, and make the choice the fun: the 9:30 portal beat becomes "who comes with you", each card showing its summon tempo and what its care gives it. A second slot waits for the Hollow tier.

### 4. The first form change is far away
Shipped: level n needs 100 x n XP (game.gd). GARDEN_MODERN 2.5: a run gives "about 40 to 120", a good garden day "about 150". DECISIONS 11-08 gives each species its own evolution level, not in code yet, and GARDEN_MODERN's worked example has a Sporcupine that "evolves at Lv 16": 12,000 XP, about 80 garden days or 150 runs.
Fix: pin the first form change inside the first evening (first stage by level 5 for the starter lines and Minkee) and retune the curve now, not in a later balance pass. A colour shift at minute one and a new body at hour two is the hook.

### 5. Two Boki buttons
DECISIONS Controls: "G is the single Boki button (tap: send or recall; hold: order wheel)." Decision 0039 (ext/bot-boki-summon) picked "A new rebindable `summon` action (C ...)", and its Rules.md row reads "C | Summon your Boki out of its wisp". With wisps there is nothing to send or recall, so G's tap is free, yet a new player learns G and C for one creature.
Fix: G tap = Summon when ready, Recall when out; G hold = wheel (WISP_DESIGN_OPEN's own pick). Drop C before the tutorial's %T token locks it in.

### 6. The star is a dot for 85% of the match
`boki_summon.json` uptime band 0.09 to 0.20; WISP_DESIGN_OPEN Q1: "A Boki is out for roughly one fight in six". Q7: "While a wisp it has no AI at all: position = owner shoulder + a cheap orbit".
Fix: one between-fight verb with no pathing: the wisp darts ahead and chirps at the nearest wild Boki, camp or chest within 30 m (BOKI_CENTRAL_PROPOSALS 3; pings are local, no Net bump). The Boki leads in the match as it leads in the garden.

### 7. A guarded wild Boki must not look like a loose wisp
EARLY_CAMPS 2.9: "clear the camp, the Boki wisp floats free, scan it." WISP_ART_BRIEF: "Stolen wisp: when a Hunter is downed, their wisps break loose and float, and anyone can grab them." Two things with one look, in the seconds a fight ends.
Fix: the guarded Boki is a full-size sleeper in a nest at the camp's centre, dazed and scannable as today. "Wisp" stays the word for linked souls.

### 8. Too much new HUD language in one release
EARLY_CAMPS 6.7 adds an XP bar, pace tags, gap-coloured nameplates, kill windows, reels, 8 s bundles and link marks; LIMITED_WAY_OUTS 11 adds a beat clock, a four-pip strip and seat calls; the summon adds a ring. DECISIONS 11-08: "show only what's needed right now" and "no more than about 5 HUD groups at once".
Fix: stage it. Matches 1 to 3: level, XP bar, camp icons, beat clock, summon ring. Pace tags and nameplate colours arrive from match 4 or on Tab.

### 9. One race is the genre's race
GARDEN 5: "a straight, a water stretch, a climb, a jump ... a lean boosts its own stretch (Water swims the pond, Flying glides the gap)". One course where each stretch tests a different stat, boosted at marks, is the mechanic CHAO_RESEARCH 1 lists for the classic's races. Names and look are ours; the shape is theirs.
Fix: no track has all four stretches. Bramblebank's Dash is a bank-and-stream loop, Kitewind's is glide gaps, Glasswater hosts the water race. Keep the cheer press.

## Owner calls (recommended default first)

1. Caught Boki at tiers 0 and 1 come home on a wipe. Default: yes (finding 1). Alternative: catches stay loot and every scan leaves a soul echo in the Field Book.
2. First-hour order. Default: garden, hatch at 0:00, Mask at the portal, tutorial, first drop (finding 2). Alternative: Mask first as written, garden after the tutorial expedition.
3. Boki per run. Default: one, chosen at the portal (finding 3). Alternative: three, passives averaged, after a GPU bench of 90 wisps.
4. First evolution timing. Default: starter lines change form by level 5, inside the first two hours (finding 4). Alternative: keep the rostered per-species levels and accept a slow first form.
5. Four friends, three seats. DECISIONS: "Extraction matches are ALWAYS squads of 3"; Arena is 4v4; garden visits are snapshots, so a party of four cannot play the main mode together and learns it at the queue. Default: trios stand (ruled twice); the party screen says "expeditions take 3" before the queue, Arena and Training Grounds are the four-player rooms, and live garden visits (race a friend's Boki in their zone) are the milestone after the hub. Alternative: squads of 4, 8 teams, which moves every number in both expedition specs.

## Keep, do not lose

- CHAO_CORE 2's first ten minutes: Boki-led, every step skippable, the "let them be" beat, the race at 6:30.
- "stats never go down, and time away shows up as a short away card, not a bill."
- "the Workyard may add, it may never be needed."
- Two keys per zone, one from each half, and the founder's name on the stone.
- Summon tempo as identity: "Burst: out for 8 s, rests 60 s", never drifting with rank.
- The guardian summon's pre-fight "did I waste it" decision; stealing that loses nothing and leaves a soul echo.
- Five beats, one clock: the Blight closes and a way out changes together.
- Hold-to-preview and the path meter (GARDEN_MODERN 1.3, 3.2): no hidden recipes.
- The homecoming: the ones who went run over and tell the ones who stayed.
- Camps refunding summon cooldown (EARLY_CAMPS 2.9): the one rule that ties camps to the Boki.

Chao check: no names, characters or looks are copied; finding 9 is the one mechanic-shaped copy. The file name CHAO_CORE and "Chao-style" in DECISIONS are internal and must never reach player or store text.

STATUS: done
