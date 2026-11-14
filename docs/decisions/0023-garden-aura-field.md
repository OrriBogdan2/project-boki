# 0023: A worn aura on each Boki (rec.aura)

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** save

## Problem
GARDEN_MODERN.md section 1 makes auras worn looks, one at a time (Glowmoss Sprig first, a Lantern Match prize). A Boki record needs to say which aura it wears so the model draws it after a reload.

## Options
1. A new save version with a migration that adds the field: an explicit step, but v13 is already claimed twice (shaping items on ext/garden-integrated, zones on ext/garden-hub-zones), so a v14 here would have to be renumbered at merge.
2. A defaulted field in Care.ensure, like rec.hold: every load runs Care.ensure on each Boki, so old saves gain rec.aura = "" with no version step.

## Decision
Option 2. The field is additive with an empty default, the same pattern the design lists for rec.path / rec.stay / rec.loose, and it keeps clear of the v13 clash.

## Consequences
scripts/core/care.gd (default), scripts/core/garden_items.gd (kind "aura": preview, swap back to the bag, take_off), scripts/home/garden_aura.gd (the motes; one line in Models.kin). No Save.VERSION change, no Net.VERSION bump (rec.aura is not synced). --garden-items-check asserts an old record loads with no aura. 0023 because ext/garden-hub-zones holds 0022.
