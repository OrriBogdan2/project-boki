# 0005: Garden-first home (care before the farm)

- **Status:** accepted (owner decision 2026-11-10, root DECISIONS.md; supersedes the farm tutorial as the first-home tutorial)
- **Date:** 2026-11-10
- **Area:** home / tutorial / save / UI

## Problem
A new player's first time at home was a resource loop: Hob, chop, mine, put up the house, sow, sell, then the portal. The Boki, the reason the home exists, was a bystander. The owner wants home to be garden-first and easy for a Chao Garden player to read: you pet your creature, feed it, play with it, give it things that change it (looks, stats, abilities) and train it at home. The Chao Garden is a feel reference only. Every system and name here is our own.

## Options
1. Keep the farm tutorial and add care steps to it. Rejected: the first ten minutes would still be about wood and stone, and the tutorial would grow to fifteen steps.
2. A short care tutorial on new saves, with the farm held back until a few runs have been played or the player asks Hob for it (decided).
3. Remove building and farming from the early game entirely. Rejected: the owner wants them optional and reachable through Hob from the start of the post-tutorial game, never required.

## Decision
- **New saves only.** The hatch (`hatch.gd _finish`) calls `GardenTutorial.begin()`, which writes `Save.d.tutorial.gt = {on, did, done, farm, m0, gift, food, given}`. Older saves never get `gt`: they keep the farm tutorial and their migration flags (`day1_done`, the v8 marks) exactly as before. A save with `day1_done` is never garden-first.
- **Steps** (data: `content/rules/garden_tutorial.json`, strict order): meet (walk over), pet, feed, play (a ball: fetch), give (the Sprout Cap), train (a three-round timing game where it stands), head out (the expedition screen opens). Only the current step counts.
- **The world is made ready for each step** (`GardenTutorial.prepare`): before the feed step nothing is wanted, so interact pets; at the feed step only food is wanted, and starter food (2 kibble, 1 sweet bun) is put in the bag. At the give step the gift is "found". At the train step there is enough energy and food to train. No gathering or farm produce is needed.
- **Give:** the Sprout Cap puts the `leafhat` accessory on the Boki (the model is rebuilt wearing it), gives +2 Guard, adds the steadfast affinity (evolution lean) and some joy, and records a memory.
- **Train:** `home._start_drill(rec, stat, here = true)` runs the existing timing game where the Boki stands, with no yard. It is also used on any island without a yard, where the yard drill used to look for a dummy that did not exist.
- **First 10 minutes rule (`GardenGuide`, owned by `FarmGuide`):**
  - A centred card ("2/7 Pet" and the instruction) shows when a step starts, then shrinks to a pill at the bottom. Standing still for 8 s brings the card back.
  - A tall gold light beam stands on the target, with a diamond, ring and "name · Nm" on screen, or an edge arrow with the distance off screen. It is never hidden; it fades to 15% under MsgLane cards, speech bubbles and the instruction card.
  - The Boki leads: it trots over to say hi and stays within about 3 m while you care for it. At the end it runs ahead toward the portal. More than 6 m ahead of you, it stops, looks back and calls "!". It never naps or wanders indoors mid-tutorial.
- **Farm gate (`GardenTutorial.farm_ok`):** on a garden save, building, farming and gathering stay closed until `farm_after_matches` (3) expeditions after the tutorial, or until the player talks to Hob (or presses Build) once the tutorial is over. Until then:
  - The farm tutorial does not run (`FarmTutorial.active`), and the Goals card is empty (`GoalTracker.lines`).
  - Hob gives no blueprint mark, toast or "come here" call, and while the tutorial runs he only says to settle in first.
  - Chop/mine and work-station prompts are off, and the Build entry is missing from the hub and the key row.
  - When the farm opens, a one-off toast says Hob has blueprints, the hub gets Build, and the farm tutorial starts at its Hob step as before.
  - Hob's second-Relic offer is not part of the farm and stays as it was.
- **Welcome card** on a garden save talks about the Boki, not Hob.

## Consequences
- Files: `scripts/home/garden_tutorial.gd` (rules/state), `scripts/home/garden_guide.gd` (screen + lead), `content/rules/garden_tutorial.json`. Hooks:
  - `home.gd`: events, gift, in-place drill, lead goal, interact/hub/key gates, welcome, Build gate.
  - `farm_guide.gd`, `farm_hob.gd`, `hob_talk.gd`, `farm_tutorial.gd`, `goal_tracker.gd`, `hatch.gd`.
- Save stays v4, with new optional fields only: `tutorial.gt`. Net unchanged.
- The farm tutorial's steps are no longer the first-home tutorial. They now run only when the farm opens on a garden save, or on older saves part-way through them.
- Checks: `--farm-tutorial-check` has garden sections: rules, gate, gift, and a home walk-through of all seven steps.
- Not done:
  - A fruit tree or other food source at home (the stall and the starter food cover it for now).
  - Gift sources after the tutorial, and a general Give menu.
  - A live playthrough review by a fresh player.
  - The key row's Build hint reappears only on the next home load once the farm opens (the hub bar updates at once).
