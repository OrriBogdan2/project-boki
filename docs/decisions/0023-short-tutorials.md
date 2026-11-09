# 0023: Shorter tutorials, one-time hints, and Skip
- **Status:** accepted · **Date:** 2026-11-08 · **Area:** tutorial / farm / save

**Problem.** The owner said the tutorials were too long: 22 match steps and 11 farm steps, with no way out.

**Decision.**
- Match, 8 steps: land and move; dash then glide (one step with two legs, named by `Tutorial.stop_id()`); shoot; E ability; send your Boki; a fight; a chest (the key is handed over); extract (`Exits.open_now` opens the lift). Pell talks for 3 s at most (`TALK_MAX_S`).
- Farm, 5 steps: chop, place the house, feed, plant, head out.
- The cut steps become one-time hints. `FirstTimeHint` (with `content/rules/hints.json`) shows one line once; `MatchHints` and `FarmHints` decide when. If the player does the thing first, the hint is marked seen and never shows.
- Both tutorials get a visible Skip:
  - Match Skip leaves as extracted, so the tutorial counts as done.
  - Farm Skip (`FarmGuide.skip`) finishes the house and gives the food and end gems once.
- Save v12 stores `tutorial.hints {id: true}`. Migration 11 -> 12 (`FirstTimeHint.migrate`) marks a group's hints seen if its old tutorial is done.

**Not done.** Auto-farm (out of scope). A Skip confirm: skipping costs nothing.

**Consequences.**
- Only 3 lines added to match.gd. No Net change.
- New check: `--first-time-hint-check`. `--farm-tut-time` times the farm tutorial.
- Headless timings of driven play: match 91.1 s for 22 steps -> 41.9 s for 8 (`--tutorial-hud-check`); farm 117.4 s for 11 -> 63.2 s for 5 (`--farm-tut-time`).

## Addendum: first-time Hunter hints (Nov 9)
The first time a save plays a Hunter, five one-line hints show as each slot first matters (primary, right click, E,
dash, ultimate; a two-step move tells both steps), with the player's own keys. The words are each archetype's `hint`
block; `HunterHints` picks the one due and `FirstTimeHint` shows it once. Seen ids are `"<hunter>.<slot>"` in
`Save.d.tutorial.hints`. Save v12 -> v13 marks the hints of every Hunter the save already played (`classes.hunters`) as
seen. No Net change. Check: `--hunter-hint-check`.
