# 0011: Hob the builder, the guided farm tutorial and the Goals card

- **Status:** accepted (owner answers of Nov 2 20:40 ET and the Nov 3 04:55 UTC ask); the six tutorial questions use the stated defaults, kept as data
- **Date:** 2026-11-03
- **Area:** farm / UI / save

## Problem
The build menu showed the whole catalogue, locked items greyed out ("everyone has admin view"). A new farm began with a house that was simply placed, and the first-day card in the top right mixed tutorial steps with goals.

## Options
1. Keep the menu and only grey out less: rejected, the owner wants the future hidden.
2. A builder who unlocks by level on his own, with no talk: rejected, the owner wants to walk up and get "new blueprints".
3. Hob draws up what the farm has earned when you talk to him; the menu shows only what can be built now; a short tutorial teaches the first day; the top card shows goals (decided).

## Decision
- **Hob Brackenridge** (`FarmHob`, `FarmBuilder`, `content/rules/farm_builder.json`) stands in front of the house once it is down. Interact talks. Everything in `farm_build.json` "unlock" opens by farm level or milestone as before, but only becomes buildable once he has drawn it (`layout["hob"].given`). A level-up or milestone makes a toast and a gold mark over his head. Starter set: every item with no unlock entry (house, crop patch, cook pot, ranch pen, fence, dirt path, flowers) plus the trough in storage. The T1 list is spread over farm levels 2 to 5 (8, 10, 10, 8 items).
- **Menu:** B opens on Buildings. Locked items are not drawn. A tab with nothing to build is hidden (Buildings, Upgrades and Island always stay). The footer says "Talk to Hob for more" while anything is locked.
- **The house is a site.** `build.house` is labour only (8 swings, free). Boki build it like any building; the player can swing a hammer too (`FarmHob`, option `player_swing`), so one Boki is enough.
- **Tutorial** (`FarmTutorial`, `FarmGuide`, `content/rules/farm_tutorial.json`): house, feed, crop, pet, meet Hob, head out. A marker in the world and one hint line with a Skip button. One reward at the end. Skipping grants nothing and puts the house down as a site if it is not there.
- **Goals card** (`GoalTracker`): replaces the first-day card in the top-right slot. Rows: Hunter unlock challenges, mastery goals, farm milestones, the next farm level; at most 5, ready-to-claim first. It never shows tutorial text.
- **Defaults awaiting the owner**, all in `farm_tutorial.json` "options" (and `build.house`): tracker replaces the day-1 card, house free, player swing on, end reward 30 gems, house first then free order, skippable.

## Consequences
- Save v8: a save with a Boki skips the tutorial (`tutorial.ft.done`, `day1_done`) and keeps every blueprint it could already build (`layout.hob.legacy`, resolved on first look). `Progress` first-day code and the interior checklist are gone. Net.VERSION unchanged.
- Checks: `--farm-tutorial-check` (new), `--farmbuild` updated (locked entries are now hidden, the house is a site). Screenshots: `--farm-hob-shots=<dir>`.
- Main wiring left: none beyond the few lines already in home.gd.
