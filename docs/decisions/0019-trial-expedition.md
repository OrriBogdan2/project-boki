# 0019: The Trial Expedition, and quiet real expeditions

- **Status:** accepted
- **Date:** 2026-11-05
- **Area:** match flow / save / UI

## Problem
The owner got too many instructions during his first expedition (owner review item 93): the scripted
tutorial ran as a banner-and-pill course that never paused, and every real expedition then showed a
14 s kit panel and timed tips on top of play.

## Options
1. Trim the banners and keep teaching inside real expeditions: still teaching while playing.
2. Split teaching from playing: one guided Trial that pauses at each lesson, then expeditions with the
   normal HUD only, plus one-line tips the first time something new happens.

## Decision
Option 2. The tutorial course becomes the **Trial Expedition** (`Tutorial`, `TutorialHud`): each
lesson opens with a centred card and the match holds (`Match.step` returns while `tut.card`) until a
key; nothing moves on by itself. It runs after the hatch for a new save (skippable there and from the
pause menu) and is replayable from the expedition panel (`trial_replay`: nothing carries over). Real
expeditions drop the kit panel (training only) and the timed tips; contextual tips live in
`content/rules/tips.json` (`MatchTips`), show once, and go into a Tips log (pause menu, `TipsLog`).
Something that can't work (a locked chest) gets one short reminder card (`ReminderCard`).

## Consequences
Save: a new `tips` list (seen tip ids). `MatchTips.migrate` moves the old per-tip flags out of
`tutorial` on load, keyed by its own field like `FarmBuilder.migrate` (no version bump). Net: none (the
Trial is offline). Checks: `--trial-check` (new), `--tutorial-hud-check` (lanes and course).
