# 0022: Pell, the tutorial's guide, and the storybook prologue

- **Status:** accepted
- **Date:** 2026-11-08
- **Area:** tutorial / match flow

## Problem
Owner, Nov 7: the tutorial opens with a ~45 s skippable storybook prologue in six panels (origin v3 in
briefs/LORE_MASKS.md), then a visible guide that walks ahead, is highlighted, and stops the player before
each new mechanic, using the dialogue box. The guide is Pell, a freed soul, part bird and part person.
Until now the Boki ran ahead (`KinCompanion` lead code) and nothing but the intro card paused play.

## Options
1. Keep the Boki as the guide and give it the dialogue box. The Boki is the player's own pet, and it
   can't fly gaps, so it needed path code and still lagged at the islands' edges.
2. A separate guide, `TutorialGuide` (Pell), owned by Tutorial: it flies (no path code), talks through
   `NpcDialogue` on the match HUD, and the match holds while it talks, through the hook the intro card
   already used (`Tutorial.holding()` / `hold_wait()`).

## Decision
Option 2. Pell's lines are in `content/rules/tutorial.json` ("pell", "pell_moods"), and its speaker entry is
in npc_talk.json. At each step with a line it flies to you and talks. The match holds (no time passes),
and then it flies ahead to the pad, goal or outpost, at most 6 m in front of you. NpcBeacon gives it the
glow, a name tag and an edge arrow. The Boki's lead code is gone, but its voiced hints and demos stay.
Pell's model is a placeholder built from primitives until the art lands. Alternative: ease the camera
onto Pell as FarmTalk does. Not done, because the match camera belongs to match.gd.
The prologue stays the new-game opener before the hatch. The alternative was to play it inside the
tutorial match.

## Consequences
- match.gd: one line changes (`tut.intro` to `tut.holding()`). No save or Net change.
- `--tutorial-hud-check` covers Pell's beacon, its stops, the hold and its lead; `--prologue-check` covers the panels.
