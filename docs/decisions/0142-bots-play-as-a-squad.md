# 0061: Bots play as a squad and back out of lost fights

- **Status:** proposed (ext/bots-human-1111; evidence in docs/BOTS_HUMAN_1111.md)
- **Date:** 2026-11-11
- **Area:** match / bot AI

## Problem
An expedition fills its 30 slots with bots, and each bot ran its own errands. Squadmates drifted islands apart,
looted a chest next to a squadmate's fight, picked targets on their own, traded down to nothing with tonics still on
the belt, and walked around hurt between fights. A player reads all of that as "not a person" within a minute.
`Bot._choose` and `Bot.think` live in scripts/match/bot.gd, which is over a thousand lines already.

## Options
1. Add the rules inline in bot.gd. Smallest diff, but the file grows by about 300 lines and the rules cannot be
   switched off to measure them.
2. Two focused modules, `BotSquad` (who the squad is, whose fight to join, when to regroup, shared decisions) and
   `BotRetreat` (when a fight is lost, the way out, when a drink is safe), with one-line hooks in bot.gd and
   bot_belt.gd. A match option `bot_plain` turns both off.
3. A squad-level planner object that hands each bot its orders. Closest to how a squad on voice works, but it
   replaces the per-bot goal chain, which every lair, exit and revive rule is written against.

## Decision
Option 2. bot.gd grows by 30 lines of hooks; the rules sit in scripts/match/bot_squad.gd and
scripts/match/bot_retreat.gd. Every rule is scaled by the tier's own numbers (`skill`, `abil`), so `Data.BOT_DIFF`
is untouched and Easy still plays worse than Expert: an Easy bot notices a squadmate's fight from 24 m, an Expert
from 38 m; an Easy bot notices it is losing about half the time and at 32% health, an Expert every time at 44%.
`bot_plain` stays as a test switch only: `--bot-human-check --bh-plain` measures the old behaviour from the same
build, which is how the before/after numbers were taken. It is not a player-facing setting. The rules are off in
the duel room as well: one against one with nowhere to go, a bot fights it out.

A squad with a player on it keeps to the player: bots regroup to them and roam where they are.

## Consequences
- No Net change and no save change: bots are simulated on the host, and the new state is in the bot's own mind
  dictionary (`rt_wise`, `rt_t0`, `regroup`; second pass: `rt_rate`, `rt_left`, `rt_at`, `tgt_t`, `guard`).
- Fights are more often three against three, and a bot leaves a fight it is losing. Time to kill is short (the last
  third of a health bar lasts about a second under focus fire), so a retreat often fails; see the doc for the rate.
- New check `--bot-human-check` (tools/bot_human_check.gd): one headless expedition; fails if hurt bots stop
  healing when it is calm, squads drift far apart again, or squadmates stop joining fights. One match is a noisy
  sample, so the limits are wide. It skips them when the wall clock cuts the run short.
- Not done here: dodging telegraphed abilities (ext/combat-bot-dodge-rebased), ring and downed play
  (ext/combat-bots-ring, ext/combat-bots-downed), Boki summons (ext/bot-boki-summon), and getting more squads to
  the four ways out.
