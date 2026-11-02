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
- **Sites:** a new building or station in an `fb` layout pays gems + materials (wood, stone, fibre, Ember Coals) and becomes a deco entry with `site = {need, got, to, up, paid}`. Boki work it with the Craft element (any Boki that can work builds at skill 1 or better): HomeWork job `build`, up to two Boki per site, one swing about 6 s at skill 1. Sites are not stations or fixtures until finished. Taking a site down refunds `paid`.
- **Tiers:** `t` on the entry (1..3). An upgrade is a site with `up = true` (the building keeps working). Stations work 25% / 50% faster at tier 2 / 3. Tier 2/3 need farm level 3/5.
- **Fibre** is a new material in `Save.d["mats"]`: one per harvest of two or more, and one per tile of wild cleared.
- **Build mode:** locked entries with their requirement, cost icons (FarmIcon), an Upgrades tab, footprint outline + snapping grid + floating refusal reason, a pop when something lands.

## Consequences
- Files: `farm_unlocks.gd`, `farm_sites.gd`, `farm_models.gd`, `farm_build_ui.gd`, `farm_icons.gd` (scripts/home); hooks in `home_build.gd`, `home_work.gd`, `home_layout.gd`, `incubator.gd` (cradles 6 to 8 need farm level 4/5/6), `lairs.gd` (boss stat), `game.gd` (counts it).
- Save stays v4. New optional fields only: `layout.fb`, `layout.fbs`, `deco[].t`, `deco[].site`, `mats.fibre`, `stats.bosses`, `stats.fb_built`. `HomeLayout.ensure` tidies them (JSON floats). Old saves load unchanged and stay ungated.
- Net: nothing synced changes (the farm is local), `Net.VERSION` unchanged.
- Checks: `--farmbuild-check`. `--farm-start-check` now runs its older instant-placement sections on a layout with the pass switched off.
- Not done: assigning a Boki to one site from a panel (use the Job Board: Craft priority and pins), progress of sites while you are away on a run.
