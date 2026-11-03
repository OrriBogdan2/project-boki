# Owner playtest review, 2026-11-03 (sync75 on his PC). Running list; more items will be added
Each item says which branch fixes it. Build on main sync75 or later. Use Sonnet. Keep fixes small, each with a check.

## 1. Venator's grenade (kit fix → ext/kitdata-vireo-venator, or a new ext/fix-venator-nade from main)
- **On a direct hit to a hunter:** it damages them and applies the damage-taken debuff (Dazed: they take more damage). It does NOT need to explode in a cone on a person, but it must hurt and debuff. Today it reads as passing through and only hitting walls.
- **On a wall or the ground:** it explodes in the visible cone as now, and **everyone hit by the cone also gets the same debuff**.
- Asserts: direct hit means damage plus debuff; wall cone means damage plus debuff on everyone in the cone; the debuff raises damage taken by the source's ratio (see the data in briefs/supervive-data/).

## 2. No ambiguous one-block walls (map design → ext/mapclean, from main)
- In the training area, a grenade thrown past a 1-block wall hit the wall unexpectedly. The owner wants no uncertainty: throwables and shots should go where you expect.
- **Remove isolated 1-tile (and tiny 1×2) wall or obstacle pieces** from the training area, arena and practice spaces, and from The Hollow Crown (generator: tools/make_hollowcrown.py; never hand-edit the JSON). Keep cover deliberate: larger, readable walls and structures placed with intent (lanes, cover lines, landmarks).
- Ruins or rubble decoration can stay only if it has **no collision** for projectiles, or is clearly big enough to read as a wall.
- Asserts: no wall or obstacle component smaller than N tiles exists (the check prints any it finds); --drop-check, --extract-check, --cover-check and --bot-sanity-check still pass.
- Screenshots: before and after of the training area and two Hollow Crown spots.
