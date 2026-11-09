# Status looks on the body

`scripts/combat/status_looks.gd` (`StatusLooks.of(m)`), data in `content/rules/status_looks.json`.
The source makes every plain status readable at gameplay distance with its own body effect; this is ours.
Combo marks and two-hit combo states are the overhead tags' (the 11-08 recast/marks rule), not this.

| Status | Look | Where | Motion | Colour (owner) |
|---|---|---|---|---|
| stun | stars on a dark disc | over the head | fast spin | yellow |
| Daze | ring of crystals | high over the head | wobble | orange (Vex) |
| root | thorns and a ring | ground at the feet | ring pulses | violet (Meeko) |
| Grounded | cords and a down arrow | round the legs, arrow over the head | counter-turning, arrow stamps | amber (Bola) |
| slow | rings | shins to the ground | slide down and spread | lavender |
| Chill | ice shell, crystals | whole body | still | ice blue (Neve) |
| burning | flame tongues | up the body | flicker | orange/yellow (Cinder) |
| Static | jagged bolts | across the body | jump at 14 Hz | teal/pink (Sparkle) |
| Anti-Heal | streaks and a dark ring | rising out of the body | rise | magenta (Kael) |
| resurrection sickness | wisps and a pale ring | round the body | sink | pale lilac |

**Where a status comes from.** The body's own timers (`stun_t`, `root_t`, `slow_t`, `burn_t`, `blight_t`, `sick_t`,
the Grounded and Daze metas) on the game that owns the body. `keep()` once per tick for a kit's own status (Neve's
Chill, Sparkle's Static). `put()` for a remote body's kit status (KitStatus `kst`) and `from_hit()` for a hit sent
to another game, shown for the status's length. A third player's game sees only kit statuses on a body neither
owns: plain timers are not in the synced state (that would be a Net shape change).

**Cost.** One rig of 3-12 meshes per (body, status) shown, shared meshes and unshaded materials, pooled per status;
nothing is built per frame once warm, and nothing draws past 34 m from the camera focus. A body with no status
costs one cheap test per frame.

**Checks.** `--hero-vfx-check` puts each status on a body the way the game does and asserts its look comes up on
that body only, uses at most 16 meshes, goes when the status ends, all ten fit one body from the pool, a hit sent
to another game shows and ends, and nothing draws far away. `--status-shots --shots-dir=<dir>` (GPU) writes one
sheet per ground (map grass, a pale floor, a dark floor): a row per status, 5 crops 0.2 s apart, the carrier on
the left and a clean Hunter beside it.

## Scores (11-09, match camera, 1280x720)

"Which status?" and "on this Hunter?" per ground, 1-5. Sheets: `docs/art/status_looks/status_{grass,light,dark}.jpg`.

| Status | Grass | Light | Dark | Notes |
|---|---|---|---|---|
| stun | 4 | 4 | 4 | the dark disc carries the yellow on bright ground |
| Daze | 4 | 4 | 4 | reads as an orange ring; at the wobble's peak it is busier |
| root | 4 | 5 | 5 | first pass's dark ring vanished on dark ground; ring now violet |
| Grounded | 3 | 4 | 4 | amber is close to yellow grass; the shape still separates it from slow |
| slow | 4 | 4 | 4 | |
| Chill | 5 | 5 | 5 | |
| burning | 4 | 5 | 5 | first pass's flames were low; now taller |
| Static | 4 | 4 | 4 | bolts are off ~30% of frames by design (they jump) |
| Anti-Heal | 4 | 4 | 4 | first pass's streaks were thin; now bigger |
| sickness | 3 | 3 | 4 | first pass 2: wisps bigger and paler; quiet on purpose (damage only) |

The ally/clean Hunter beside each carrier never shows a look in any frame.
