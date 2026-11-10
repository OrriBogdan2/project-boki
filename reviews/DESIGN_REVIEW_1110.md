# Design review 11-10: garden, new expedition rules, Boki use (merged)

Lead reviewer, 2026-11-10. Read-only. Owner rulings in DECISIONS.md win everywhere below.

**What this is built on.** Only the FUN review exists. The RULES and BUILD reviewers were killed before writing anything (exit code 137, empty answer files, no branches). I covered those two lenses myself from the source docs, in less depth than a full review would. Every quote I rely on was checked against its source. "0.25" below means the next release; the specs still call it 0.24.4.

## 1. Verdict

The loop is right and the garden is the best-designed part of the game. The join between garden and expedition is where it breaks: a caught Boki is lost when you fail to get out, the docs disagree on how many Boki you take, and the first new body is weeks away. Three specs each plan about 12 hours of work for the same release on the same code, and nobody owns the first hour or the order they land in.

## 2. The one core loop

1. **Home:** pet, feed and play with your Boki. It changes colour in the first minute and gets a new body in the first evening.
2. **Leave:** pick ONE Boki at the portal. It rides on your shoulder as a wisp, its passive always on, and one button (G) calls it out for about one fight in six.
3. **Drop:** land on camps and level up by kills only. One clock to learn: every 2 minutes the Blight closes and a way out changes.
4. **Get out:** win one of four seats or be the last squad. What you carry is at stake. Your own Boki and your first catch never are.
5. **Come home:** finds open zones, eggs and coats; the Boki that went tells the ones that stayed; a well-kept Boki is stronger next run.

## 3. Top 8 changes, ranked

1. **The first catch must come home.**
   Why: LIMITED_WAY_OUTS 7 puts scans in the lost loot, and it expects about 7 squads in 10 to never leave (about half against bots), so the best moment in a creature game is often undone.
   Fix: the first Boki you scan each run comes home whatever happens (tiers 0 and 1, legendaries excepted); catches 2 and 3 stay loot.
2. **One first hour, written once.**
   Why: the garden spec opens on "a Boki, not a menu" with a starter waiting, while DECISIONS asks for a Mask pick and an egg pick first; together that is two menus and a starter you never chose.
   Fix: garden first, the three eggs (and the hidden black one) ARE the opening beat, the Mask pick moves to the portal, then the combat tutorial, then the first drop near minute 20.
3. **One Boki per run.**
   Why: CHAO_CORE says "up to three Boki", the wisp design says "one summoned Boki at a time", the HUD has one box, and nothing designs three passives or three rings.
   Fix: one, and make the choice the fun: the portal card shows each Boki's summon tempo and what its care gives it.
4. **The first new body arrives in the first evening.**
   Why: a Boki level costs 100 x level XP (checked in game.gd) and a good garden day gives about 150, so the example "evolves at Lv 16" is 12,000 XP, about 80 days.
   Fix: starter lines and Minkee change form by level 5, and the curve is retuned so that is about two hours of play.
5. **Close two holes in the seat rules.**
   Why: EARLY_CAMPS counts the Sealed Lair boss as "a level and a half in one kill", but in LIMITED_WAY_OUTS killing that boss means you leave the match; and a seat takes only the squad members standing in it, so one left behind plays on alone and can use up a second seat.
   Fix: the two unsealed lairs keep their boss as the mid-game XP prize; the Sealed Lair boss is only the exit. One seat per squad: a member left behind gets 20 seconds to reach it, then goes home without carried loot.
6. **One Boki button, one meaning for "wisp".**
   Why: DECISIONS says "G is the single Boki button" but the summon branch added a second key (C); and the camps spec has a guarded wild "Boki wisp" that looks like a stolen wisp in the seconds a fight ends.
   Fix: G tap = summon or recall, G hold = wheel, drop C before the tutorial teaches it. A guarded Boki is a full-size sleeper in a nest; "wisp" means linked souls only.
7. **Three build plans, one release: land them in order.**
   Why: Way Outs, camps and the garden each assume the same base at once; the garden merge has 27 conflicts and the hub draws 689 against a budget of 200; bots have no Blight code, so today every bot dies to the wall.
   Fix: order is Way Outs zone + bot zone sense, then levels and camps, with the garden merge beside them on its own branch. If time runs short, the drop's show (higher ship, clouds, Hard Landing) slips first; it is not part of the loop.
8. **Too much new HUD at once.**
   Why: the three specs add an XP bar, pace tags, coloured nameplates, kill windows, a beat clock, four seat pips and a summon ring; DECISIONS says "no more than about 5 HUD groups".
   Fix: matches 1 to 3 show level, XP bar, camp icons, beat clock and summon ring. The rest appears from match 4 or on Tab.

**Where I differ from the FUN review.** It wanted every catch to come home. I say only the first: if all three are safe, the fastest way to collect is to catch and die on purpose, and getting out stops mattering to collectors. Its "lost 7 times in 10" is the equal-skill number; against bots the spec targets about half. I dropped its "four friends, three seats" call (trios are ruled twice; it needs one line on the party screen, not a decision) and moved its race finding to the later list (real, but it does not block the loop).

## 4. Calls only the owner can make

| # | Call | My default | If you say nothing |
|---|---|---|---|
| 1 | Does a catch survive failing to get out? | The first catch each run does; legendaries never | Built that way |
| 2 | First-hour order | Garden and eggs first, Mask at the portal, then tutorial | Built that way; the opening Mask menu moves to the portal |
| 3 | Boki per run | One, chosen at the portal | One; the garden spec's "up to three" line is corrected |
| 4 | Are wisps and the summon on for everyone in 0.25? | Yes, if the GPU bench and one readability playtest pass (both branches are READY) | On if the bench passes; otherwise behind the setting and the Boki tutorial rebuild waits |
| 5 | Is Boki ransom at The Hollow still alive? LIMITED_WAY_OUTS 7 says "always come home, at every tier" and then lists a ransom case | No ransom in 0.25. "Your Boki always come home" with no footnote; ransom returns only as a later opt-in hard tier | Ransom stays off |

## 5. Build list, smallest fun first

**0.25**
- Fold the summon into G (tap summon or recall, hold wheel); remove the C action.
- Docs and text: "one Boki per run"; a guarded Boki is a sleeper in a nest, never a "wisp".
- Party screen line before the queue: "Expeditions take 3."
- No placement gems for a squad still at run level 1 (stops hiding for pay; second place pays the same 40 gems as the early Heart seat).
- Portal card "who comes with you": summon tempo and care bonus per Boki.
- First catch of the run comes home on any result; one results line says so.
- Boki XP curve: starter lines and Minkee change form by level 5, about two hours in.
- Seat rules: one seat per squad, 20-second grace for a member left behind; unsealed lairs keep their boss; fix the pace table in the camps spec.
- First-hour sequence as one doc, then build: eggs as the garden's opening beat, Mask pick at the portal.
- HUD staging for matches 1 to 3.
- Way Outs: Blight zone core, then bot zone sense and the final (tasks already written).
- Levels core, then camps core, then camps on the map (tasks already written).
- Garden: merge onto the release line, always on, three zones, save gate, frame-time pass (tasks already written).

**Later**
- The drop's show: 110 m ship, cloud layer, Hard Landing (first to slip if 0.25 is tight).
- Wisp scout: between fights it darts at the nearest wild Boki, camp or chest within 30 m.
- Camp clears refund summon cooldown (10 / 20 / 35%).
- Guarded sleeping Boki in two Great Camps.
- The wisp eats wild snacks on pickup, so a lost run still changes a Boki.
- Each zone gets its own race shape; no single track with all four stretches (the one mechanic that sits close to the game that inspired the garden).
- Second Boki slot and ransom as Hollow-tier options.
- Hushwood, Kitewind Ridge, the Workyard island, live garden visits.

**Keep, do not lose:** the garden's first ten minutes; "stats never go down"; "the Workyard may add, it may never be needed"; two keys per zone, one from each half; summon tempo as each Boki's identity; five beats on one clock; kill-only XP with the last-hit steal as ruled.
