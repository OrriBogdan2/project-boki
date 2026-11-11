# Glide set audit (2026-11-11, ext/anim-glide-set)

What each Hunter played while gliding, against the source (PARITY FIRST, DECISIONS 2026-11-07). Stacked on
ext/anim-glide-pose (the dive pose and the body tilt: [GLIDE](GLIDE.md)).

## Before
Every Hero had one `glide` loop and nothing else. The glider opening snapped from the fall into the hold over the air
fade (0.12 s), steering showed nothing in the clips (anim-glide-pose banked the whole body by the facing's turn rate,
so swinging the aim leaned a glide that flew straight), an overheated glider looked like a cool one, and a glider
shut in the air faded the hold into the fall.

## The source, and what we match
| State | Source | Ours |
|---|---|---|
| Open (double press) | opens "instantly": the canopy catches a terminal fall in ~0.13-0.15 s (MOVEMENT_FEEL `glide_catch_t`) | `glide_open` 0.23 s: hands up to the lines by 0.07 s, the bite (knees jerk up, head drops) at 0.13 s, settled on the hold |
| Hold | upright hang under the canopy | the Hero's own `glide` loop, 12 deg forward (anim-glide-pose) |
| Steer (WASD) | the glider turns 90 deg in ~0.2 s; the body banks into it | Blend3 `glide_lean_l` / hold / `glide_lean_r` driven by the keys against the heading, eased 1/s 9 (60% in 0.2 s); the whole body banks by the same value (WardenAirTilt `glide_bank`) |
| Overheat | still lifts you out of the abyss at half strength while it burns (DECISIONS) | `glide_burn` 0.6 s loop over the hold: arms yank the lines in turn, legs kick, head up at the canopy; eases in over 0.25 s |
| Close in the air | instant, no penalty | `glide_close` 0.17 s: the hands leave the lines, the body drops into the fall |
| Landing | lands at the glide sink, soft | the Hero's `land` clip, as any fall (no close plays on the ground) |

A remote Hunter has no keys in the snapshot: its lean follows its heading's turn (3 rad/s leans all the way), so no
Net change. The hold shows only while the state says gliding, which is the glide input (or a lair updraft's
auto-glide, a game rule left as is).

## Per Hero (`--glide-anim-check`)
Open and close length; open: the most a bone sits off the hold at 0.1 s (deg); lean at 0.2 s of full steer; body
bank right / left at full steer (deg, straight 0); struggle: the most a bone sits off the hold (deg).

| Hunter (art) | open / close | open | lean | bank R / L | struggle |
|---|---|---|---|---|---|
| gunslinger (vex) | 0.23 s / 0.17 s | 30 | 0.83 | 34 / -34 | 24 |
| juggernaut (kael) | 0.23 s / 0.17 s | 34 | 0.83 | 35 / -35 | 24 |
| ashwick (cinder) | 0.23 s / 0.17 s | 37 | 0.83 | 36 / -36 | 24 |
| tender (pip) | 0.23 s / 0.17 s | 38 | 0.83 | 35 / -35 | 25 |
| dolm (tarek) | 0.23 s / 0.17 s | 42 | 0.83 | 32 / -32 | 24 |
| archer (hem) | 0.23 s / 0.17 s | 22 | 0.83 | 34 / -30 | 24 |
| dredge (dredge) | 0.23 s / 0.17 s | 36 | 0.83 | 34 / -34 | 24 |
| rimewright (claire) | 0.23 s / 0.17 s | 30 | 0.83 | 34 / -34 | 23 |
| mage (ryzz) | 0.23 s / 0.17 s | 28 | 0.83 | 33 / -30 | 24 |
| bulwark (breaker) | 0.23 s / 0.17 s | 47 | 0.83 | 34 / -34 | 47 |
| thief (sable) | 0.23 s / 0.17 s | 31 | 0.83 | 34 / -34 | 23 |
| ostra (ostra) | 0.23 s / 0.17 s | 9 | 0.83 | 37 / -30 | 24 |

Ostra floats with no legs, so her open is only the hands (9 deg). Strips: `--glide-shots` (phases fall, open, hold,
turn right and back left, dive, catch, burn, close, reopen, air dash), [glide_set.jpg](glide_set.jpg).

## How the clips are made
`tools/art1/glide_set.py` (numpy, no Blender): every new clip starts from that Hero's own `fall` and `glide` keys and
turns contract bones about world axes on the animated pose, so each Hero keeps its own hold. Run it once on a fresh
export (a rerun leaves the old clip data in the buffer). A Blender re-key of any of them can replace it by name.
