# Dash poses by direction

Dashes follow WASD (DECISIONS), so a Hunter aiming forward often dashes back or sideways. What the body does then,
per Hunter, from the source (data `briefs/supervive-data`, footage `briefs/hero-ref`). Read it with
`--dash-dir-shots` (a `DASHDIR_SHOT` line per frame: how far the body is off the dash, the clip's own turn, the move).

The body turns to the dash by itself (`Hunter._process`, `roll_dir`) unless the kit keeps the aim through it
(`aims_in_dash`: the dash fires). Then the clip has to turn, or a forward roll plays moving backwards.

| Hunter | Source | Now |
|---|---|---|
| Vex | slide feet-first, torso keeps the aim (venator.md) | legs turn, torso keeps aim (`legs_heading`, unchanged) |
| Lace | roll in the move direction, body dives forward (pin.md) | roll and flick turn all the way to the dash (`heading`, `turn_max`) |
| Cinder | head-first lunge, body stretched forward (linwick.md) | leap and air hop turn to the dash |
| Tenzo | ground hop goes to the cursor; air dash silent | air dash turns to the dash (our own call) |
| Sable | always a sideways cartwheel in the plane of travel (dancer.md) | cartwheel turns its side to the way she goes (`heading_off`), air tumble turns forward |
| Kael, Grimble, Albert, Meeko, Neve | body turns to the dash (no aim in the dash) | already so, unchanged |
| Sparkle | Surge goes toward the cursor | unchanged (the lane is the aim) |
| Motley | no body dash (Lantern Trade) | unchanged |

Not done: a Sable somersault or twist in a chain (our own flips, no source) still play as they were.
