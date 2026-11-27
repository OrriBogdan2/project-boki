# Boki growth by playstyle (owner direction 2026-11-27)

Owner: stats should come from doing lots of expeditions, as in the genre reference. How you play with a
Boki should decide how it evolves, which mutations it gets and which stats it focuses, not hand out raw stats.

Every number below is in `content/rules/playstyle.json` (code: `scripts/core/play_style.gd`; check:
`--playstyle-check`). It builds on the stat economy of 11-26 (GARDEN_MODERN_BALANCE.md): bites, limited runs.

## The rule in player words

1. **Expeditions grow stats.** Every expedition a Boki goes on teaches it stat points. Getting out teaches
   three times what a lost run does. It is a long road: on this growth alone a Devoted Boki's stat takes
   about 46 expeditions from 0 to 100.
2. **The garden gives direction, not points.** Toys, games, drills, petting, talking and fetch never add a
   stat point. They build its **leaning**: Fierce, Steadfast, Curious or Swift.
3. **What it does out there counts most.** Hitting and knockouts lean it Fierce, reviving you and getting out
   Steadfast, using its skill and catching Boki Curious, being thrown Swift.
4. **The leaning decides what it becomes:** which stat takes the larger share of each expedition, which
   final form it grows toward, and which body parts its mutations roll.
5. **Two Boki of one species end up different.** In the check, two Zapple go on 20 expeditions each: the
   fighter ends Power 63 / Focus 14 and grows toward Howlop, the scout ends Focus 63 / Power 14 and grows
   toward Chimelop.

## Leaning points

The leaning is the affinity with the most points (`Evo.scores`: points earned plus a small nudge from its
inborn personality). Its strength is how far it leads the next affinity. Worn path tokens are not a
leaning: they keep steering the form by themselves, as before.

| Garden activity (at most 10 points a Boki a day) | Points |
|---|---|
| Petted (first of the day) | Steadfast 1 |
| Talked to (first of the day) | Curious 1 |
| Fetch (first of the day) | Swift 1 |
| Won a tussle with you (first of the day) | Fierce 1 |
| A meal of an affinity's food (as before; not under the cap) | that affinity 6 |
| Toy play: ball / climbing post / tub / basking stone / dig patch | Swift / Fierce / Curious / Steadfast / Curious 1 |
| Garden game: Dash, Relay Cup, Kite Tow | Swift 2 |
| Garden game: Seek, Echo Steps, Lantern Match | Curious 2 |
| Garden game: Stump Shove | Fierce 1 + Steadfast 1 |
| Garden game: Spark Volley | Curious 1 + Swift 1 |
| Training post drill: Power / Guard / Speed / Focus (a training lap = Speed) | Fierce / Steadfast / Swift / Curious 2 |

| On an expedition (no cap) | Points |
|---|---|
| A hit it landed | Fierce 0.4 |
| A knockout | Fierce 3 |
| It revived you | Steadfast 6 |
| You got out | Steadfast 2 |
| It used its skill | Curious 0.6 |
| You caught a wild Boki | Curious 4 |
| You threw it | Swift 0.8 |

A busy day at home (10 points) weighs about as much as one expedition (10 to 25 points).

## Leaning tiers and what they unlock

| Tier | Lead over the next affinity | Share of expedition stat growth to its stat | Path meter pips | Mutation from another affinity | Signature part |
|---|---|---|---|---|---|
| Balanced | under 20 | 25% (even) | 0 | 50% | no |
| Leans | 20 | 40% | 1 | 30% | no |
| Strongly | 60 | 55% | 2 | 15% | yes |
| Devoted | 150 | 70% | 3 | 5% | yes |

- **Stat focus.** Fierce grows Power, Steadfast Guard, Curious Focus, Swift Speed. The other three stats
  split the rest evenly. The caps of the stat budget still apply (100 a stat, 240 in all, level cap).
- **Evolution.** Lines that branch by affinity (evolve.json `path`) take the leaning's branch, as before.
  Lines with a path meter (Sporcupine, Vespox, Glassolotl, Zapple) add the pips above to the end that matches
  the leaning. The stat lead (3 pips) follows too, because the leaning grows that stat.
- **Mutations** (a body part every 4 levels). A strong leaning rolls its own parts almost every time. Each
  affinity has one signature part only a Strongly or Devoted Boki of that leaning can grow: horns (Fierce),
  shell ring (Steadfast), third eye (Curious), little wings (Swift).

## Expedition stat growth

| | Stat units |
|---|---|
| Got out | 6 |
| Did not get out | 2 |
| The second Boki you brought | 70% of that |

A unit is one point below 50, half a point to 80, a quarter to 100 (the stat budget's bands). Parts of a
unit carry over to the next expedition. The results card lists the points ("+80 XP, bond up 3, Power +2").

## Where raw stats come from now

| Source | Units a day (2 expeditions) | Needs an expedition |
|---|---|---|
| Expedition growth (new) | 12 | yes |
| Bites from kills (~1.8 a match) | ~11 | yes |
| Drill and race runs earned by matches (1 of each per match) | ~19 | yes |
| Free drill and race run (1 of each a day, was 2) | ~9 | no |
| Toys (at most 3 points a day) | 3 | no |

About 78% of a regular player's stat units now need an expedition (was about 58%: 30 of 52). One stat takes
190 units from 0 to 100. A player who never leaves the garden gets about 12 units a day (16 days for one
stat, if the level cap allowed it); a player who runs twice a day gets about 54.

Not solved here: with bites and earned runs all aimed at one stat, about 9 expeditions fill it, and only the
level cap (12 + 6 a level) slows that. If the road should be longer, lower `train_runs.per_match` or the bite
chances (both data).

## Built and not built

Built (this branch): leaning points from garden activities and expeditions, the day cap, tiers, stat focus
on expedition growth, path meter pips, leaning-driven mutation odds and signature parts, the Boki card line
("Strongly Fierce: it fights hard. Power takes 55% of what expeditions teach it."), stat points on the
results card, free daily runs 2 to 1.

Designed only:
- How it is treated: neglect (sulky, unfed days) leaning it away from Steadfast. Needs a day-end hook.
- Combat roles beyond today's seven counters: time merged, time carried, summon uses, damage soaked.
- A leaning-coloured bite bonus (a bite of its focus stat counts for more).
- New mutation art. The signature parts use parts that exist.
- Alternative kept open: no free daily runs at all (`train_runs.daily` 0, one data change). It makes the
  garden give no bites without expeditions, but a home-only player's first race of the day would pay nothing.
