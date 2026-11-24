# 0084: Solos and trios, and a play space that starts smaller than the map

- **Status:** accepted
- **Date:** 2026-11-18 (owner 2026-11-11 "Solos are back"; re-done on main from the old ext/modes-solos-1111 family)
- **Area:** match flow / UI

## Problem
Solos come back (20 hunters, bots fill) beside trios (10 squads of three), and the map follows the player count: a match starts with part of the map already in the Blight, solos on a smaller play space than trios. Solos also must not show squad cues.

## Options
1. A separate solos map per map: a second map to build, light and keep in step.
2. Start the Blight's tide already in: one radius round the Heart per map and mode (the map's `play_space`), holding until the closing ring is smaller. Same maps, one number per mode.
3. A polygon play space: fits odd shapes, but the tide, the wall and the map rings are circles round the Heart.

## Decision
Option 2. `Heart.start_r_of(layout, opts)` reads `play_space[mode]` (solos when squads are of one); `Heart.tide_r` is `min(start_r, closing ring)` from the first second, so the wall, the map rings, bot ring sense and the tide damage (stage 0 until the close starts) all show it with no new system. Squads spawn inside it (`Heart.in_play`); riders on the skyship take no tide. Modes are `Data.MODES` / `Data.mode_opts`, shown as two cards (`ModeCards`) on the expedition panel and as buttons in the online lobby (duos and free-for-all leave it: trios, solos, Heart Raid). The pick is `Save.d["exp_mode"]` (`Data.saved_mode`). Solo cues: `Life.has_mates` hides the squad panel, ping hints and sounds, squad words, the deathbox/beacon lines and the squad-only keys in Settings; no revive beacons stand; the result reads "You placed". The edge arrow to the nearest way in is always up while outside the ring.

## Affects
heart.gd, match.gd (the authored layout is a member; spawns filtered: +3 lines), data.gd, home.gd, expedition_panel.gd, lobby.gd, both map files and generators, hud.gd, full_map.gd, overlay.gd. No Net.VERSION bump (the start message keeps its shape: teams, squad); no save change (`exp_mode` is optional). The ShrinkZone (0060) is not changed: its first circle still covers the map. Check: `--modes-check`.
