## Glider parity, 11-27 (`--glider-parity-check`)

Owner 11-27: the reference is right on every metric unless proven otherwise. Numbers are from the private reference
notes (glider fuel 11-25, slam/spike/abyss 11-25, practice update 11-26; the newer note wins). Each row is measured from
the running game by `tools/glider_parity_check.gd`, which prints a "before" column when run on the old tree.

| Item | Before | Now | Where |
|---|---|---|---|
| Spike dive | 0.35 s stun, fall 6 m/s | hangs 0.18 s, then speed is SET to 80 m/s straight down; the body can't be steered or caught | `glide_spike.air_stun`, `fall_vy`, `keep_hv` 0; `GlideSpike.plunge` |
| Glider regen stun | heat refilled on landing | after a slam's heat, or after the spike landing's 0.7 s stun, the heat stays empty 1.5 s more (2.2 s from the landing) | `regen_stun`, `Hunter.glide_regen_t` |
| Slam heat | a slam on any glider spiked it | the victim loses 0.5 x max heat plus the 1.5 s regen stun; the slammer pays nothing; only a glider the slam empties (or one already empty) spikes; a slam under `slam_min` does nothing | `slam_heat`, `GlideSpike.slam` / `spikes` |
| Level glide | 9 s cool to overheated | 6.25 s (500 fuel at 80 a second); the owner's 11-02 "lasts too long" goes the same way | `glide_heat_s` |
| Opening | a second Space opened it at once (a tap), the button at once | held 0.4 s from the press; a tap never opens it, Space held since the jump still never does (owner 11-08) | `tuning.glide_engage`, `Hunter._glide_press_t` |

Measured by `--glider-parity-check` (main -> this branch): spike hang 0.00 s -> 0.17 s; spike fall 12.0 -> 80.0 m/s; slam
heat burned 1.00 -> 0.50 of the tank (a full glider was spiked, now it is not); heat refill after a spike landing 0.02 s ->
2.22 s; after a slam's heat 1.52 s (no such rule before); level glide 9.00 -> 6.25 s; a held Space or glide button opens the
glider after 0.02 s -> 0.42 s; a 0.05, 0.15 or 0.30 s tap opened it at 0.02 s, now never. 13 rows fail on main, 0 here.

**Feathering becomes a hold.** Letting go still closes the glider at once, and a new press needs its 0.4 s hold before
it reopens. So each on/off toggle costs about 0.4 s of free fall (a tap does nothing). A feather that lifts you out of an
abyss needs the same hold. The price is what bounds the old "feather beats hold 2x" gain.

**Lift cost retuned (`lift_heat` 4.0 -> 2.8).** The 11-27 bar is 6.25 s, not 9 s, so the same 4x lift cost burnt 39% of
it for the ~8 m, ~1 s abyss lift. The footage says a quarter to a third of the bar; 2.8x keeps that (about 27%).

**The garden follows the same hold.** The home mover (`FarmStep.glide_open`) opens its glider after the same 0.4 s hold, so
the garden and a match do not feel different.

**Open:** the 11-26 practice update measured the spike fall at -4000 uu/s with one -8000 kick at 0.305 s after the hit.
We follow the 11-25 notes and the task (80 m/s after the 0.18 s freeze) and do not model the 0.125 s gap.
At 80 m/s a step is 1.33 m, so the landing test widens by the step (`Hunter` landing window) or the body tunnels the floor.
