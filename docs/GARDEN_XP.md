# Garden XP: the Boki level curve

Tuned 2026-11-11 (job `ext/farm-boki-xp-curve`) after the 11-10 design review (fix 4): a Boki level cost
`100 x level` XP while a garden day gives about 150, so a Lv 16 evolution was about 80 days out.

## The curve (data: `content/rules/evolve.json` "xp", code: `Evo.xp_to`)

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

## What a Boki earns (unchanged, `Evo.run_xp` / `Evo.dojo_xp`)

- An expedition: 40 XP, +40 for a win, +10 per knock; x0.7 when the Boki was not the lead; x1.5 with the XP treat.
- A Boki resting at home with a Dojo: +40 after each expedition.
- A Starfruit: +1 level, once a day (skips the XP).

## Two-hour estimate

A typical two hours is 4 expeditions (about 30 minutes each with the garden between), lead Boki, half won, 2 knocks each:
60 + 100 + 60 + 100 = **320 XP**. Lv 1 to Lv 5 takes 307 XP, so a new Boki is Lv 5 at the end of the second hour (Lv 2 after the first
expedition). `--boki-xp-curve-check` simulates exactly this with the game's own gain function.

## Evolution levels

- **Starter lines** (Vespyx `cindle`, Prismander `puddlet`, Mycroll `burrlet`): first form at **Lv 5** (was 8), about two hours.
- **Ermink / Minkee** (the mystery egg): evolves by Ink at any level, never by level; it reaches Lv 5 in the same two hours, and the first
  boss Ink then evolves it. Nothing in its line changed.
- Every other first form stays at Lv 8 (7 hours: 1,105 XP, about 3.5 sessions) and every second form at Lv 16 (6,806 XP, about 21 sessions,
  40+ hours; about 45 garden days at 150 XP) so later evolutions stay further out.
- A Boki never evolves into a form with no model (`Evo.has_art`): at Lv 5 the starters wait until the art for Vespox, Glassolotl and Sporcupine lands.

## Saves

Save v13 (`Evo.migrate_xp`): saved XP is the progress inside the current level, so it keeps its share of the level (`xp / (100 x L)` of the
new cost). Levels and forms are untouched; nobody loses progress or levels twice on load.
