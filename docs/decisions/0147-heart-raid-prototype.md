# 0061: Heart Raid, the PvE mode (prototype)

- **Status:** prototype (owner 2026-11-11 7 PM EST via coordinator; design: docs/design/PVE_HEART_RAID.md)
- **Date:** 2026-11-12
- **Area:** match flow

## Problem
The owner wants a PvE mode for 1-4 players next to Expeditions. It reuses the map, the Heart and the Blight, and
fights waves and one boss instead of rival squads. Expeditions must not change.

## Options
1. A separate map and match type. Rejected: it rebuilds what the expedition already has.
2. Expedition opts plus one director (`HeartRaid`, built only when `opts.heart_raid`). One squad (`teams` 1), no lairs
   or outposts, and the Heart held shut (`Heart.locked`) until the director opens its final seat when the boss falls.

## Decision
Option 2. Match wiring is +9/-2 lines (match.gd): the var, the build, the tick, the results summary, the "hr" event and the wild
table. Lairs and Exits skip setup in a raid. The boss is a `Boss` with a lair-shaped dictionary round the Heart
(`"heart_raid": true`), so it never sleeps and Lairs leaves its death to the director. `Heart.pay` reads the raid's
reward. The opts key is `heart_raid`, because `raid` is already the weather condition (RaidLook).

## Consequences
Net: a new "hr" event ["hr", phase, wave, boss_nid] (host to all), and the lobby start message carries `heart_raid`.
Net.VERSION is left to the release bump. No save change. Mode-exclusive Boki: `content/kin` `"only_in"`, read by
`Data.wild_kin(mode)`. This removes 2 species from the Expedition wild table, so seeded wild rolls shift. Check:
`--heart-raid-check`.
