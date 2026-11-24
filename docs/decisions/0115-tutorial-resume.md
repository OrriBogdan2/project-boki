# 0022: Quit the tutorial, carry on where you were

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** save / match flow

## Problem
Quit during the combat tutorial and Continue dropped you on the farm with the whole combat course unplayed (it only ever restarted from the hatch). The farm tutorial already keeps its steps in the save; only the combat course had no memory.

## Options
1. Restart the course from beat 1 on Continue: simple, but replays what was learned.
2. Save the last finished beat and resume after it: needs a save field and a place to put the player back.
3. Save a full match snapshot: far too much for a scripted course.

## Decision
Option 2. `Save.d.tutorial.tut_beat` holds the id of the last finished beat (an id, so reordering steps cannot point at the wrong one). Continue on the title opens the tutorial again while the player has hatched and `tutorial.match` is not set (finished or skipped; `home` and `day1_done` also end it). After the drop the course jumps to the beat after the saved one, puts the hunter at the last stop that beat left (what a fall does), gives the chest key for the chest beat, and the beat's own setup brings the foes back. The outpost beats (uplink, defend, extract) keep their state in the world, so they resume at the outpost's start (goexit). The pause menu's Skip stays as it was. The farm tutorial needed nothing: its steps, tools, food and the house are already in the save; the check proves it.

## Consequences
Save v12 (`TutorialResume.migrate`: a save that played or reached the farm is marked finished). New `scripts/match/tutorial_resume.gd`, a hook in `Tutorial._finish`, Continue in `title.gd`. No Net change. Check: `--tutorial-resume-check` (migration, a saved beat per step, quit after each beat and resume, farm save/reload per step). Not restored: skill points of the rank beat.
