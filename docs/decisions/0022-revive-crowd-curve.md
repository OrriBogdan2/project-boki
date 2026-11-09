# 0022: Revive and stomp numbers from the source

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** match flow

## Problem
Life.R held most downed rules as [design] or [est]. The game data (briefs/supervive-data/supervive_physics.md) has
three rows we never applied: revive HP per tick 2, a stomp/revive curve "by count 1..4" of 1.0 / 0.75 / 0.58 / 0.47
("same curve for allies reviving and enemies stomping"), and recall 4 s. We used the curve as a penalty on repeat box
revives, and each extra reviver added a flat +50%.

## Options
1. Read the count as the number of Hunters on one wisp: each works at curve[n-1]. The totals are 1, 1.5, 1.75, 1.875,
   which is 1 + 1/2 + 1/4 + 1/8 to two decimals. That fits a curve made for a crowd, and the row says it covers
   stompers too, who are never "repeat" anything.
2. Read it as repeat downs or revives of one Hunter (what box revive did). Nothing in the row says so, and it can't
   cover stomping.

## Decision
Option 1. `Life.crowd(n)` scales both the wisp revive (teammates) and the stand-on drain (enemies). Box revives lose
the repeat penalty: the source shows none. Not settled, so the old values stay: revive time 4 s ([wiki] "a few
seconds"), radius 1.6 m, revive HP 25% (the wiki page has a placeholder "X%"), stomp ×2.5 and ×0.4, kin revive 8 s.
"2 HP per tick" can't become seconds without the tick length and the wisp's revive-bar size, which aren't in the data.
The footage (/home/claude/svvid) isn't on the worker that did this, so no revive or stomp has been timed yet. Recall
4 s has nothing to match here: we have no recall. Beacons: sickness 12 s / −25% stays [patch 1.0]. The wiki says
13 s and patch notes say 6 s for the channel; ours stays 4 s (owner, 101b).

## Consequences
life.gd (R["crowd"], `crowd()`), box_revive.gd (`time_for()` takes no Hunter now), revive.json loses
`box_diminish`. Net.VERSION unchanged: the sync shape doesn't change, only local rates. `--box-revive-check` now
checks two revivers (×1.5) and two stompers (×1.5 drain), and that a second box revive is no slower.
