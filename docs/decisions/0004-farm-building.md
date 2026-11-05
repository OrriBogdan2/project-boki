# 0004: Farm building pass (unlocks, construction sites, tiers)

- **Status:** accepted (owner decisions in the main-overflow handoff, section 4)
- **Date:** 2026-11-02
- **Area:** farm / save / UI

## Problem
A new farm let you buy every building at once and placing one was instant, so the farm had no pacing and the Boki did nothing for it. The owner wants a farm that grows: a house, a crop patch and a pot to start, the rest earned, built by Boki with materials and labour, and upgradable.

## Options
1. Gate by gems only (price rises). Rejected: no reason to go on runs or hatch.
2. Unlock by farm level (points from play) and three milestones; construction as saved "sites" on the deco entries; tiers as a field on the entry (decided).
3. A separate building list next to the layout. Rejected: it would duplicate placement, moving, blocking and the save.

## Decision
- **Farm level** is derived from lifetime stats (extractions, bosses, scanned, hatched, harvests, buildings built), never saved; thresholds in `content/rules/farm_build.json`. Milestones: first extraction, first boss (new stat `bosses`), three scanned.
- **Gating** applies to layouts with `layout["fb"] = 1` (set when a farm-start island is made). Older layouts keep everything open and instant. Something you already own stays open. The first three (house, crop patch, pot) are never gated and go up at once (a new farm has no builders).
- **Sites (items 90, 91):** putting a new building or station down in an `fb` layout is free: it becomes a deco entry with `site = {need, got, to, up, cost, paid, steps}`. The cost (gems + wood, stone, fibre, Ember Coals) is spent in four quarters (`FarmSites.STEPS`): each quarter's share is paid when its first swing is due, and with too little the site waits (`FarmSites.stalled`, "Needs 2 more wood" on the site and the prompt) until you bring it; `paid` is what has been spent so far and is what taking a site down refunds. You hammer by holding interact (`FarmHob`, a beat of `HunterTool.TOOLS.hammer.period`); when you start, Boki within `FarmSites.CALL_R` that can work drop their job and come (`FarmSites.call_helpers`), each adding swings of its own (HomeWork job `build`, up to two per site, one swing about 3 s at skill 1; Craft level makes it quicker). They go back to their jobs when the site stands. Sites are not stations or fixtures until finished. Old sites (no `cost`) load as fully paid (`FarmSites.clean`). The house costs 10 wood + 6 stone; the tutorial has you chop and mine for them before it places the house.
- **Tools (item 91):** chopping, mining and hammering run on `ToolWork` (the swing clock, holding interact loops it) and `HunterTool` (axe, pickaxe and hammer poses, the tool node in the hands, the weapon stowed through `HunterAnim`'s `stow_k`). At home the Empty carries no class weapon (`holster`).
- **Tiers:** `t` on the entry (1..3). An upgrade is a site with `up = true` (the building keeps working). Stations work 25% / 50% faster at tier 2 / 3. Tier 2/3 need farm level 3/5.
- **Fibre** is a new material in `Save.d["mats"]`: one per harvest of two or more, and one per tile of wild cleared.
- **Build mode:** locked entries with their requirement, cost icons (FarmIcon), an Upgrades tab, footprint outline + snapping grid + floating refusal reason, a pop when something lands.

## Consequences
- Files: `farm_unlocks.gd`, `farm_sites.gd`, `farm_models.gd`, `farm_build_ui.gd`, `farm_icons.gd` (scripts/home); hooks in `home_build.gd`, `home_work.gd`, `home_layout.gd`, `incubator.gd` (cradles 6 to 8 need farm level 4/5/6), `lairs.gd` (boss stat), `game.gd` (counts it).
- Save stays v4. New optional fields only: `layout.fb`, `layout.fbs`, `deco[].t`, `deco[].site`, `mats.fibre`, `stats.bosses`, `stats.fb_built`. `HomeLayout.ensure` tidies them (JSON floats). Old saves load unchanged and stay ungated.
- Net: nothing synced changes (the farm is local), `Net.VERSION` unchanged.
- Checks: `--farmbuild-check`. `--farm-start-check` now runs its older instant-placement sections on a layout with the pass switched off.
- Not done: assigning a Boki to one site from a panel (use the Job Board: Craft priority and pins), progress of sites while you are away on a run.
