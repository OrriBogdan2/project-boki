# Status looks on the body

`scripts/combat/status_looks.gd` (`StatusLooks.of(m)`), data in `content/rules/status_looks.json`.
The source makes every plain status readable at gameplay distance with its own body effect; this is ours.
Combo marks and two-hit combo states are the overhead tags' (the 11-08 recast/marks rule), not this.
**One look per status, whoever puts it there**: every source (a kit, a Boki, a monster) lands on the same timers,
so a stun reads as the same stars from Vex, Grimble or a Brute. A kit adds no body look of its own for these (Pip's
root beam is gone), and nothing lies flat on the ground, the look or a ring as it lands (a ground ring means gameplay).
The parts are cel-lit (the toon shader with a little glow, no outline pass); see-through parts stay unshaded. A big
hit's stagger (Oomph: a 0.28 s slow that is the hit's own feel) shows no slow look, so a stun hit is the stars alone.

| Status | Look | Where | Motion | Colour (owner) |
|---|---|---|---|---|
| stun | stars on a dark disc | over the head | fast spin | yellow |
| Daze | ring of crystals | high over the head | wobble | orange (Vex) |
| root | thorns | driven in round the feet, leaning over them | strain | violet (Meeko) |
| Grounded | cords and a down arrow | round the legs, arrow over the head | counter-turning, arrow stamps | amber (Bola) |
| slow | rings | knees to the ankles | slide down and tighten | lavender |
| Chill | ice shell, crystals | whole body | still | ice blue (Neve) |
| burning | flame tongues | up the body | flicker | orange/yellow (Cinder) |
| Static | jagged bolts | across the body | jump at 14 Hz | teal/pink (Sparkle) |
| Anti-Heal | streaks | rising out of the body | rise | magenta (Kael) |
| resurrection sickness | wisps | round the body | sink | pale lilac |

**Where a status comes from.** The body's own timers (`stun_t`, `root_t`, `slow_t`, `burn_t`, `blight_t`, `sick_t`,
the Grounded and Daze metas) on the game that owns the body. `keep()` once per tick for a kit's own status (Neve's
Chill, Sparkle's Static). `put()` for a remote body's kit status (KitStatus `kst`) and `from_hit()` for a hit sent
to another game. Every game sees a remote body's stun, root and slow from its owner's snapshot (`net_bits`,
Net 0.24.8: a Hunter's flags bits 25-27, the last field of a Boki's and a monster's), so the look is up exactly as
long as the owner runs the status, give or take one snapshot; `from_hit()` covers the first `BRIDGE` (0.5 s) until
that snapshot arrives. Grounded and Daze reach every game as the kit's `kst` event, shown for its length.

**Size.** A look is sized to the body's hitbox (`StatusLooks.body_k`): across, the hitbox radius over a Hunter's
0.38 m; up, a Hunter's scale, a monster's 2.2 hitbox radii over 2 m.

**On a summoned Boki.** The crowd control a summoned Boki takes (docs/specs/SUMMON_CC.md: stun, root, slow, Daze;
Grounded never lands) wears the Hunter's look, rig, colours and pace. Only the size differs (`StatusLooks.body_k`):
across it is the Boki's model scale x its girth x 0.7, up it is its model scale x 0.8 m / 2 m, so a ground or body
look (thorns, rings) wraps its squat body, and a look over the head (stars, the Daze ring) keeps its shape and sits
as far over the Boki's head as over a Hunter's; a giant ridden Boki's look grows with it. A stunned Boki keeps the
puppet's squint but not its own circling stars (model meta `starry`), so it shows one ring of stars, the shared one.
A monster is sized from its hitbox (above).

**Cost.** One rig of 3-12 meshes per (body, status) shown, shared meshes and materials (one toon material per colour), pooled per status;
nothing is built per frame once warm, and nothing draws past 34 m from the camera focus. A body with no status
costs one cheap test per frame.

**Checks.** `--status-look-check` lands each row of the crowd control table in `docs/KIT_PARITY.md` from a caster of
that kit the way the kit does (a hit carrying stun, root or slow; KitStatus for Grounded and Daze), and a Boki's and
a monster's, and asserts for each: the look comes up, the same rig whatever the source, sized to the hitbox, up for
every step the status runs and gone when it ends, no other look with it (a stun hit's stagger is not a slow), nothing flat below the ankle and no ring at the feet as it lands,
and a game that does not own the body shows it (snapshot or event) and drops it with the owner.
`--hero-vfx-check` puts each status on a body the way the game does and asserts its look comes up on that body only, uses at most 16 meshes, goes when the status ends, all ten fit one body from the pool, a hit sent
to another game shows and ends, and nothing draws far away. `--status-shots --shots-dir=<dir>` (GPU) writes one
sheet per ground (map grass, a pale floor, a dark floor): a row per status, 5 crops 0.2 s apart, the carrier on
the left and a clean Hunter beside it; with `--boki` the carrier is a summoned Boki (rows none, stun, root, Grounded,
slow, Daze; the Grounded row stays empty). `--hero-vfx-check` also puts each of the four on a summoned Boki and a
Hunter at once and asserts the Boki's look comes up and goes, matches the Hunter's colours and pace, sits over
the Boki's head or round its body, the puppet's stars stay off, Grounded shows nothing, and a remote Boki shows
what it is sent.

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
