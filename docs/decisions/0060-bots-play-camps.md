# 0060: Bots play the early game around camps

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** match flow / combat

## Problem
Bots fill most of the 30 seats, and since 0048 levels come from kills. A bot that drops on a random spot and wanders stays level 1-2, so a person meets no squad that levelled the way they are asked to (spec `EARLY_CAMPS_DROP.md` 2.5, 2.8, 6.2, 6.5, 6.8).

## Options
1. Give bots XP on a timer to match the pace table. Cheap and exact, but they would not be at the camps, and nothing a person sees would explain their levels.
2. Bots pick a camp from the drop map and clear camps under the same XP rules as people. Chosen.
3. For the "one bot squad per region" rule with 10 squads, 9 regions and a ship run that reaches 6-7 of them: let the squads left over share a region. Rejected: two bot squads on one camp starve both. A squad with no free region keeps the old drop spot and lives by the detour rule.

## Decision
- `BotCamps` (`scripts/match/bot_camps.gd`, numbers in the `bots` block of `content/rules/camps.json`). A bot leader with no human ping takes the hot zone at `HotZone.BOT_PICK` if no squad heads there, else a camp it can glide to in a region no squad pinged, else one a single squad of people pinged. Never a region a bot squad has, so the Crown goes at most once (`crown_pick`).
- On the ground the squad clears its region smallest camp first until `home_s` (2:00), then plays objectives and detours to a live camp within `detour_r` while its mean level is at or below the pace level (`pace_s`, spec 6.2). It stays within `together_r` of its leader, skips a camp a squad with more levels is on (outside its own region also an even squad), and leaves when `Camps.safe_for(pos, safe_s)` fails or the Blight is within `blight_r`.
- Steals (6.8): a bold bot within 25 m of a prize monster (Brute or Chief) at 25% health or less goes for the last hit 35% of the time; a squad that saw a rival within 30 m in the last 5 s holds its abilities from 30% health down to the kill window.
- Fights (6.8): `BotCamps.fight_reach` scales the reach Bot uses for a rival Hunter. None for a squad 2+ levels above its own unless that squad was hurt in the last 3 s, none while the squad has a camp to go to and either the opening (`home_s`) still runs or the camp would bring its next even level, 1.5 times for a squad 2+ below. A rival that hit the bot is always fought. The opening part goes past the spec: without it half the bot squads were out by 2:30 and camps were half of the early XP (6.2 wants 85%).
- `bot.gd` gets three lines of wiring (`BotCamps.goal`, `BotCamps.hold_burst`, `BotCamps.fight_reach`); `DropSquad._leader_pick` records each bot squad's region.

## Consequences
- New check `--camp-pace-check` (20 seeded bot matches against the 2.5 table; seeds can be split across machines, `--rows=FILE` judges saved rows). No Net shape change, no save change.
- Debt (docs/DEBT.md): `pace_s` and the kill window share duplicate numbers the XP and steal-window rules will own; Hard Land half the time (2.8) is not in (no Hard Landing on this base).
