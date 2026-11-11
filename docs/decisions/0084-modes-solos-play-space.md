# 0084: Solos and trios, and a play space that starts smaller than the map

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** match flow / UI

## Problem
Owner playtest of 0.24.4 (briefs/DECISIONS.md "modes + incubator"): rolling sessions go as a player option, solos come back (20 hunters, bots fill) beside trios (10 squads of three), and the map follows the player count: every match starts with part of the map already in the Blight, solos on a smaller play space than trios.

## Options
1. A separate solos map, or a scaled copy of each map: a second map per mode to build, light and keep in step.
2. Start the Blight's tide already in: one radius round the Heart per map and mode (the map's `play_space`), the ring holding there until the closing ring (heart.json) is smaller. Same maps, one number per mode.
3. A polygon play space per map: fits odd shapes better, but the tide, the wall and the map rings are circles round the Heart.

## Decision
Option 2. `Heart.start_r_of(layout, opts)` reads `play_space[mode]` (solos when squads are of one); `Heart.tide_r` is `min(start_r, closing ring)` from the first second, so the wall, the maps' ring and the tide's damage (stage 0 until the close starts) all show it with no new system. Squads start inside it (`Heart.in_play`); riders on the skyship take no tide. Modes are `Data.MODES` / `Data.mode_opts`, used by the expedition panel and the online lobby (duos and free-for-all leave the lobby: trios only, now plus solos).

## Consequences
heart.gd, match.gd (the Heart is set up before the hunters: +2 lines), data.gd, home.gd (Trios / Solos tabs replace the rolling tabs), lobby.gd, ways_out_hud.gd ("Hunters left" in solos), prematch_view.gd, the two map generators and maps. No Net.VERSION bump (the start message keeps its shape); no save change (`exp_mode` is optional, a stale `exp_rolling` is ignored). Rolling sessions stay behind the `--rolling` dev flag (docs/DEBT.md). Checks: --modes-check (new), --heart-check, --blight-check, --ways-out-map-check, --ways-out-map-ui-check updated for the ring at the start; --modes-shots for the start zones.

## Mode cards (ext/ui-mode-cards)
The Trios / Solos choice is two cards side by side (`ModeCards`, scripts/ui/mode_cards.gd) on the expedition panel and the online lobby, replacing the tab strip: a title and one plain line each (`Data.MODE_LINES`: "10 squads of 3, bigger map", "20 Hunters, every one for themself, smaller map"). The last pick is `Save.d["exp_mode"]` (`Data.saved_mode`), saved on the pick, so the panel and the lobby open on it. No save migration (the key was already optional), no Net change. Shots: --mode-cards-shots (720p and ultrawide) in docs/shots/mode-cards/.
