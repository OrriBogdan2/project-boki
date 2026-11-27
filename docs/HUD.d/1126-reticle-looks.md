## One reticle per Hunter (11-26)

The reticle's "default" shape (Settings > Gameplay > Reticle > Shape "Hunter's own") is each Hunter's own small look,
named by `content/archetypes/<id>.json` "reticle" and drawn by `scripts/ui/reticle_looks.gd` (`ReticleLooks`): Lace
stitches, Kael shackle arcs with an ember blade tick, Vex a coin rim with scope ticks, Albert an aegis hexagon, Neve a
snowflake, Cinder the fire triangle, Tenzo a rune ring, Sparkle a four-point spark, Grimble a goo drop, Meeko a sun,
Sable corner brackets, Motley a harlequin diamond, Gil a ring with a fin. With the "hunter" colour the strokes take the
Hunter's colour lifted by tuning `look_lift` (dark colours still read on dark ground); the dot keeps the plain accent.
Every look is strokes only, at most 3 px past the plain ring, and opens with bloom.

The ammo no longer draws at the cursor (the arc and its tuning keys are gone): next to the ring it read as a second ring
on most Hunters; the ammo is in the HUD's weapon panel. The gauges (resource, charge, warm-up, spin-up and the AimKit
charge) are short bars under the reticle (`Reticle.bar`, tuning `bar_w`/`bar_y`/`bar_step`: charge in slot 0, resource
in slot 1), filled part only over a thin dark edge: a gauge that wrapped the ring read as a second ring (art-gate, twice).
Only the AimKit charge "body" mode still draws a ring, round the Hunter, not the cursor. Kael's blade tick above his
shackle arcs is part of his look.
Checks: `--reticle-check` (every Hunter's look is known and its own; every look draws).
Proof (real GPU, `--resolution 1920x1080`): `--reticle-looks-shots` (dark/light/grass swatch rows, labelled, at rest)
and `--reticle-proof-shots` (every Hunter full frame at rest and firing on flower-free grass, contact sheets of 5 Hunters, one row each (the frame and 3.6x zooms; the aim guides hidden)).
Shots: `docs/shots/reticle_looks_1126b_swatches.png` (dark/light/grass at rest), `reticle_looks_1126b_sheet1.png`,
`_sheet2.png`, `_sheet3.png` (every Hunter on a meadow at 1920x1080, a row = full frame, 3.6x zooms at rest and firing, cursor on flower-free grass). The 26 full
frames are in `/home/boki/gens/reticle-looks-1126b/`. A cursor sitting on grass at rest is the same size and colour as on dark/light.
