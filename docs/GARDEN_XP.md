# Garden XP: the Boki level curve

Owner call 2026-11-18 (port of `ext/farm-boki-xp-curve`): the curve is `round(18 x L^1.5)` and the starter lines evolve at Lv 5.
Before it a level cost 50 x L, flat from Lv 20.

## The curve (data: `content/rules/garden_xp.json` "curve", code: `Game.xp_need`)

XP to go from level L to L + 1 = `round(18 x L^1.5)`. Levels cap at 100 as before.

| Level L | XP to L + 1 | XP from Lv 1 to reach L |
|---|---|---|
| 1 | 18 | 0 |
| 2 | 51 | 18 |
| 3 | 94 | 69 |
| 4 | 144 | 163 |
| 5 | 201 | 307 |
| 7 | 333 | 773 |
| 8 | 407 | 1106 |
| 10 | 569 | 1999 |
| 12 | 748 | 3225 |
| 15 | 1046 | 5760 |
| 16 | 1152 | 6806 |

## What a Boki earns (unchanged, `Game.add_xp`)

- An expedition: 40 XP, +40 for a win, +10 per knock; x0.7 when the Boki was not the lead; x1.5 with the XP treat.
- A Boki resting at home with a Dojo: +40 after each expedition.
- A Starfruit: +1 level, once a day (skips the XP).

## Two-hour estimate

A typical two hours is 4 expeditions (about 30 minutes each with the garden between), lead Boki, half won, 2 knocks each:
60 + 100 + 60 + 100 = **320 XP**. Lv 1 to Lv 5 takes 307 XP, so a new Boki is Lv 5 at the end of the second hour (Lv 2 after the first
expedition). `--boki-xp-curve-check` simulates exactly this with the game's own gain function.

## Evolution levels

- **Starter lines** (Vespyx `cindle`, Prismander `puddlet`, Mycroll `burrlet`): first form at **Lv 5** (`content/rules/evolve.json`), about two hours.
- Every other line keeps the level it has in `evolve.json`. They were set against the flat 50 x L curve; this curve is steeper past Lv 20
  (Lv 32 is about 41,000 XP, was about 22,000), so the later forms are further out. Re-tune them if play shows it.
- A Boki never evolves into a form with no model (`Evo.has_art`): at Lv 5 the starters wait until the art for Vespox, Glassolotl and Sporcupine lands.

## Saves

Save v21 (`Evo.migrate_xp`): saved XP is the progress inside the current level, so it keeps its share of the level
(`xp / (50 x min(L, 20))` of the new cost). Levels and forms are untouched; nobody loses progress or levels twice on load.
