# 0100: First-time Hunter hints

- **Status:** accepted
- **Date:** 2026-11-17
- **Area:** save / match tips

## Problem
A save that picks a new Hunter has to learn its four fighting slots from the kit panel alone. Main's first-time tips (`Match._tip`, one flag per line in `Save.d.tutorial`) have no line for them. Port of old ext/hunter-first-hints, which was built on a hint system main never took.

## Options
1. Port the old `FirstTimeHint` / `MatchHints` system as well. Cons: a second tip system next to `Match._tip`.
2. Add one module on `Match._tip`. The words live in each `content/archetypes/<id>.json` `hint` block.

## Decision
Option 2: `HunterHints` (scripts/match/hunter_hints.gd), asked once per frame from `Match._tips`. Four lines per Hunter (primary, right click, E, dash), shown in that order once a foe is within 9 m, 8 s apart. The player's own keys fill `{fire}`, `{secondary}`, `{signature}`, `{dash}`. The old fifth line (ultimate) is dropped: `FirstUltHint` already says it when the ultimate is ready. Flags are `hh_<hunter>_<slot>`.

Save v20 -> v21: a Hunter the save has already played (any count > 0 in `classes.hunters`) gets all its flags set, so only new Hunters teach. No Net change. Check: `--hunter-hint-check`.
