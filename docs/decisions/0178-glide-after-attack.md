# 0178: The glider is never eaten by an attack's recovery

- **Status:** accepted
- **Date:** 2026-11-26
- **Area:** movement / combat

## Problem
Owner playtest 11-26: "if i lmb, then let go then try to glide it doesn't work sometimes". AirLimits kept the glider
shut for as long as a kit move's pose played (an LMB tap's ~0.35 s, an ability's up to ~1 s), and a second Space
that was let go inside that window was forgotten (the arm needed glide still held). 131 of 624 air trials
(13 hunters x LMB, RMB, E, Q, X, Shift x 4 delays x hold/tap) lost the press.

## Options
1. A glide buffer per kit: the kits that hit it get their own timers.
2. The shared path: a fresh glide press cuts a recovery pose short, and stays armed for `Loco.press_buffer`.

## Decision
Option 2. `AirLimits.glide_locked` keeps only the action itself shut (wind-up, hold, cast, dash, planted ult, a
knock); a kit move's pose no longer blocks an armed press, and opening the glider ends the pose
(`AirLimits.end_move`, from `HunterLoco.open_glider`). The shot or cast already went off: the pose is cosmetic.
Hunter keeps an armed press for `Loco.press_buffer` (0.15 s) after glide is let go, so a tap that lands inside a
real lock opens as the lock ends and a tap that lands inside a pose opens at once. A tap earlier than that is
refused as in DashFlow. Folding the glider on release is unchanged (the buffer is ignored while gliding).

## Consequences
`--glide-after-attack-check`: every hunter, six actions, delays 0/50/100/200 ms, hold and tap. Held ults and
channels (Rimewright X, Motley X, Vex E hold, Tenzo's Quakefall) still delay it to the action's end. No Net or
save change.
