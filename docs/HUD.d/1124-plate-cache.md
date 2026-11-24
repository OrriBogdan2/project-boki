## Overhead plates repaint on change (11-24)

Each plate (`HudPlate.Item`, a `Node2D` under the Hud, right below `Hud.c`) is moved to its anchor every frame and
repainted only when its key changed: the key is everything the plate shows (health, armour and shield in 0.5-point
steps, the chip in 0.4% steps, flashes and pulses in 0.2 steps, level, name, status word, level gap). A still plate costs
a transform and an array compare. `Hud._draw_all` ends with `plates.end_frame()` so plates not placed this frame hide;
unseen ones are freed after `PRUNE_T`. Everything the plate keeps (chip, flash, armour crack, `shown`) still advances in
`HudPlate.draw`, per frame. Plan and numbers: `docs/PERF_DRAW_1124.md` (step 1).
