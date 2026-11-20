# Design review 11-10: garden, new expedition rules, Boki use (merged)

Lead reviewer, 2026-11-10. Read-only. Owner rulings in DECISIONS.md win.

**What this is built on.** Only the FUN review exists; the RULES and BUILD reviewers were killed before writing anything. I covered those two lenses myself from the source docs, in less depth. "0.25" means the next release; the specs still call it 0.24.4.

## 1. Verdict

The loop is right and the garden is the best-designed part of the game. It breaks where garden and expedition meet: a caught Boki is lost when you fail to get out, the docs disagree on how many Boki you take, and the first new body is weeks away. Three specs target the same release on the same code, and nobody owns the first hour or the order they land in.

## 2. The one core loop

1. **Home:** pet, feed and play with your Boki. Its colour shifts in the first minutes; it gets a new body in the first evening.
2. **Leave:** pick ONE Boki at the portal. It rides with you as a wisp, its passive always on, and one button (G) calls it out for the fights that matter.
3. **Drop:** land on camps and level up by kills only. One clock: every 2 minutes the Blight closes and a way out changes.
4. **Get out:** win one of four seats or be the last squad. What you carry is at stake; your own Boki and your first catch never are.
5. **Come home:** finds open zones, eggs and coats, and a well-kept Boki is stronger next run.

## 3. Top 8 changes, ranked

1. **The first catch must come home.**
   Why: scans count as lost loot and at most 4 squads in 10 get out, so the best moment in a creature game is often undone.
   Fix: the first Boki you scan each run comes home whatever happens (tiers 0 and 1, legendaries excepted); catches 2 and 3 stay loot.
2. **One first hour, written once.**
   Why: the garden spec opens with a starter already waiting, while DECISIONS asks for a Mask pick and an egg pick: two menus and a starter you never chose.
   Fix: garden first, the three eggs (and the hidden black one) are the opening beat, the Mask pick moves to the portal, then the combat tutorial.
3. **One Boki per run.**
   Why: the garden spec says "up to three Boki", the wisp design says "one summoned Boki at a time", and the HUD has one box.
   Fix: one; the portal card shows each Boki's summon tempo and what its care gives it.
4. **The first new body arrives in the first evening.**
   Why: a Boki level costs 100 x level XP and a garden day gives about 150, so the example "evolves at Lv 16" is 12,000 XP, about 80 days.
   Fix: starter lines and Minkee change form by level 5, with the curve retuned so that is about two hours of play.
5. **Close two holes in the seat rules.**
   Why: the camps spec counts the Sealed Lair boss as mid-game XP, but killing it means you leave the match; and a seat takes only the squad members standing in it, so one left behind plays on alone and can take a second seat.
   Fix: the two unsealed lairs keep a boss as the mid-game XP prize; the Sealed Lair boss is only the exit. One seat per squad: a member left behind gets 20 seconds to reach it, then goes home without carried loot.
6. **One Boki button, one meaning for "wisp".**
   Why: DECISIONS says "G is the single Boki button" but the summon branch adds a second key (C); and the camps spec's guarded wild "Boki wisp" reads like a stolen wisp.
   Fix: G tap = summon or recall, G hold = wheel, no C. A guarded Boki is a full-size sleeper in a nest; "wisp" means linked souls only.
7. **Three build plans, one release: land them in order.**
   Why: the garden merge has 27 conflicts and the hub draws 689 against a budget of 200; the Blight zone is still paper and bots have no zone code, so they would all die to the wall.
   Fix: Blight zone and bot zone sense first, then levels and camps, with the garden merge beside them on its own branch. If time is short, the drop's show (higher ship, Hard Landing) slips first.
8. **Too much new HUD at once.**
   Why: the specs add an XP bar, pace tags, coloured nameplates, a beat clock, four seat pips and a summon ring; DECISIONS says "no more than about 5 HUD groups".
   Fix: matches 1 to 3 show level, XP bar, camp icons, beat clock and summon ring; the rest appears from match 4 or on Tab.

**Where I differ from the FUN review.** It wanted every catch to come home. I say only the first: if all three are safe, catching and dying on purpose becomes the fastest way to collect, and getting out stops mattering. I dropped its "four friends, three seats" call: trios are already ruled, so it needs one party-screen line.

## 4. Calls only the owner can make

| # | Call | My default | If you say nothing |
|---|---|---|---|
| 1 | Does a catch survive failing to get out? | The first catch each run does; legendaries never | Built that way |
| 2 | First-hour order | Garden and eggs first, Mask at the portal, then tutorial | Built that way |
| 3 | Boki per run | One, chosen at the portal | One; the garden spec is corrected |
| 4 | Wisps and summon on for everyone in 0.25? (DECISIONS: behind a setting first) | Yes, if the GPU bench and one readability playtest pass | On if both pass; otherwise behind the setting, and the Boki-led tutorial waits |
| 5 | Boki ransom at The Hollow? The Way Outs spec says "always come home, at every tier", then lists a ransom case | No ransom in 0.25; later only as an opt-in hard tier | Ransom stays off |

## 5. Build list, smallest fun first

**0.25**
- Fold the summon into G (tap summon or recall, hold wheel); remove the C action.
- Docs and text: "one Boki per run"; a guarded Boki is a sleeper in a nest.
- Party screen line: "Expeditions take 3."
- No placement gems for a squad still at run level 1 (today hiding pays as much as the early Heart seat).
- Portal card: summon tempo and care bonus per Boki.
- First catch of the run comes home on any result; the results screen says so.
- Boki XP curve: starters and Minkee change form by level 5.
- Seat rules: one seat per squad, 20-second grace; unsealed lairs keep a boss; fix the pace table.
- First hour: eggs open the garden, Mask pick at the portal.
- HUD staging for matches 1 to 3.
- Merge the READY Way Outs branches, then Blight zone core, then bot zone sense.
- Merge the READY wisp and summon branches (after call 4).
- Levels core, camps core, camps on the map.
- Garden: merge onto the release line, always on, three zones, save gate, frame-time pass.

**Later**
- The drop's show: 110 m ship, clouds, Hard Landing.
- Wisp scout: between fights it darts at the nearest wild Boki, camp or chest.
- Camp clears refund summon cooldown; guarded sleeping Boki in two Great Camps.
- Each zone gets its own race shape (The Dash's course is too close to the game that inspired the garden).
- Raider and Holder bots; the four-pip Ways Out strip; pace tags.
- Second Boki slot and ransom as Hollow-tier options.
- Hushwood, Kitewind Ridge, the Workyard island.

**Keep:** the garden's first ten minutes, "stats never go down", two keys per zone, five beats on one clock.
