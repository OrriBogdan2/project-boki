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
- **Hob's talk camera** (owner, 11-08: too much camera movement): the talk keeps your zoom (no zoom in or out per talk or per step) and only leans the focus a little toward him, eased in and out by the camera's own follow; it drifts part way to a "show" only when that is too far to be on screen (HobTalk.SHOW_FAR_M). Measured with `--hob-cam-strip[=<dir>]` (zoom and focus every 0.25 s, frames with a renderer): before, the zoom swung 0.80-1.20 four times through the first talk and the focus jumped up to 9.8 m; after, zoom 1.20 throughout and the focus stays within 1.8 m of you.
- Main wiring left: none beyond the few lines already in home.gd.

## Round 3: Hob in person and the second Mask (items 87, 89; owner, Nov 4)
- **Hob is a person** (`HobModel`: a stocky builder in the toon style, built from shapes: rolled sleeves, apron,
  tool belt with a hammer, flat cap, pencil behind his ear, simple face marks like the rest of the Empty; poses
  idle, wave, talk, point, hammer). He waits by the market stall (`farm_builder.json` "stall_stand") and walks to
  the house while it is a site. His name shows over him until you have met him; a "!" while he has something.
- **Face to face** (`HobTalk`, `TalkBox`, lines in `farm_builder.json` "talk"): interact opens a talk box with his
  portrait (rendered from the model) and name, one line at a time (click or the interact key), you stand still
  and the camera eases toward him; a line with "show" makes him point at it while the camera looks there. The
  first talk introduces the farm (stall, house spot, axe); during the tutorial he explains the step you're on;
  after it, blueprints and the build menu. The tutorial's bottom line is only the goal reminder now.
- **First arrival:** the camera swings to him for 1.5 s while he waves and calls "Hey! Over here!"
  (`tutorial.hob_intro`). Meeting him is the tutorial's first step (axe needs it).
- **The second Mask** (`HobOffer`): once the house is down (or with no tutorial), he calls you over: "By the
  way... I see you found a Vex Mask. Could I interest you in another?" Exactly the three of
  `ClassUnlock.second_picks` as cards (portrait, name and title, a one-line role from "roles"), one ability clip
  for the card in focus. Taking one opens it and plays the short Mask moment (`MaskBeat`); "Not now" waits. The
  portal offer (`MaskOffer`) is gone; saves that already own a second Mask keep it and are never offered one.
- Checks: `--hob-check` (new, with `--shots-dir=`), `--farm-tutorial-check` updated.

## Round 2 (owner feedback, Nov 4)
- **Challenge House** is not given any more (`home.gd` no longer grants it). It is Hob's blueprint after the first expedition (milestone `first_run`: `matches >= 1`), a lot you mark and build for wood and stone (`farm_build.json` "lots": 6 wood, 4 stone; `FarmBuilder.lot_cost`). Saves that already have it keep it. Old Pell's Black Market is untouched.
- **Crops by the water** (`FarmWater`): a crop patch whose footprint is within 2 tiles of water (pond, painted river, or the island's wild water: all `layout.water`) waters its own plots as tended (`_farm_tick`). The patch tooltip, the plot prompt and the plot panel say so; build mode shows "Near water: waters itself" in green over the patch you are placing (and "No water within 2 tiles" otherwise).
- **River brush** (`river`, Paths tab, open from the start): the water brush at 2 gems a tile instead of 6, so a channel is cheap. It counts as water everywhere.
- **Tutorial, 11 steps** (in Hob's voice, one action each; you start with the axe and pickaxe, both owned from the new save): chop, house (mandatory first), hammer, task, mine a rock (teaches the pickaxe, says what stone is for), feed, crop (marker on the water; grow time never blocks: the next open step is shown meanwhile), buy a seed (Seeds tab; gems topped up to one seed so nobody is stuck), sell a crop (Sell tab; says gems come from selling, expeditions and Goals), meet Hob, head out. The market steps point at the stall when one stands, else at the Market on the bar.
- **Save v10** (main's numbering: market is v8, mantle-look v9). Step 8->9 is an empty placeholder for mantle-look; 9->10 is `FarmBuilder.migrate`, which is keyed by its own `farm_builder` field.
