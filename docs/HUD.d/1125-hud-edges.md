## HUD on the edges, gaps against the reference layout (11-25)

Owner 11-25: every group sits on the screen edge or corner it hangs from, 12 units in (`HudStyle.hud_pad`, 18 px
at 1080p; menus and cards keep `safe_pad`), and nothing floats in the middle or mid-bottom except the ability row.

| Where | What | Code |
|---|---|---|
| Top left | minimap; right of it a vertical stack, squads left over players left (solos: players only) | `AliveCounter.draw_left` |
| Under the minimap | ONE clock row: sky dot + short name (+ sight %), the tide's phase with a clock icon, the ring's next close, time left, LV; a thin progress line under it | `ClockRow` |
| Left column | squad frames right under the clock line, then the NEXT objective card under them | `SquadFrames.bottom`, `ObjectiveTracker.draw` |
| Top right | your numbers: knocks, kills, assists, damage dealt (small icon over its number, a hairline under the icons), then gems to the right; the kill feed hangs under it | `AliveCounter.draw` |
| Right edge, under `BuffStack` | stat column: bonus damage, bonus health, move speed, cooldown haste (icon + value, dim at zero) | `BonusStats` (staged: `bonus_stats`, match 4) |
| Bottom left | portrait with the health, armour and shield bars stacked beside it (`HudVitals.BAR_DROP`); the perk row and the hidden / crouched tag sit over the portrait's top edge | `HudVitals`, `Hud._draw_perks` |
| Bottom centre | the ability row only, nothing stacked above it | `HudSlot.row_origin` |
| Bottom right | weapon card, belt, gear (unchanged) | |

- Assists: `Hunter.assists` counts a takedown a teammate got on a victim you hit or controlled within
  `DashReset.ASSIST_WINDOW` (`DashReset.takedown`). Local only, not synced.
- HUD size: the vitals and the ability row share the bottom edge, so a growing HUD steps both down to what keeps them
  apart, never below 100% (`HudScale._across`; on 1280x720 that is about 107%). `BuffStack` and the stat column hang from
  `HudScale.from_edge(TOP)`, under the feed and toasts as they are once the HUD has grown.
- The hudref demo (`--hudref-demo=fight`) turns "Show full HUD" on and gives you numbers, perks, gear and two feed
  lines so every group shows in one frame.
