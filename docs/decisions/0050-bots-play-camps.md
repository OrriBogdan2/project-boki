# 0050: Bot squads drop on camps and clear their region

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** bots / match flow

## Problem
With the camps in (0048) and laid out on the 2x map, bots still dropped on a random spot or a vault and fought for the first minutes. They neither earned the early levels the camps pay nor left the camps to the humans' pace, so the level curve could not be tested.

## Options
1. Bots pick a camp region at the ping and clear it smallest to biggest, then go back to the old objectives (chosen).
2. Teach every bot goal about camps. Too wide a change in `bot.gd`, which is at its budget.
3. Keep the old drop and only add a camp goal on the ground. Squads would still land on top of each other.

## Decision
- `BotCamps` (`scripts/match/bot_camps.gd`) holds all of it; `Bot._choose` gets one wiring block, `DropSquad._leader_pick` replaces the old random ping. Numbers are the `bots` block of `content/rules/camps.json`.
- Drop: a bot leader with no human ping takes the hot zone at the existing `HotZone.BOT_PICK` when no squad pinged it, else a region no other squad pinged (its Small Camp on a rim, its Camp in the middle), the Crown with at most one bot squad a match.
- Ground: the squad clears its region's live camps smallest first, nearest first, using the leader's camp as the squad's goal (teammates stay within 25 m of the leader so XP reaches them). A camp where a squad with a higher total level is within 30 m is skipped. Camping stops at 2:30, when `Camps.safe_for(pos, 60)` turns false or the Blight is within 40 m. Squads with a person in them follow the person.
- Later, a squad whose best level is under 5 detours to a returning camp within 60 m.
- `--camp-pace-check` runs 10 bot trios on the 2x map over 5 seeds and asserts the pace (levels at 2:30 and 5:15, no level 6 before 2:30, the best squad near the median, camp XP share, an idle squad stays low).

## Consequences
- There are 10 squads and 9 regions, so "never two bot squads in one region" cannot hold for all ten: one region has to double. The pick fills every free region first and lets one other squad share only when none is left; the check asserts exactly that.
- Camping bots are an easy target for a human who lands on the same region; that is the intended risk of the early game.
