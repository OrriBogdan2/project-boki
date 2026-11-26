## One reticle per Hunter (11-26)

The reticle's "default" shape (Settings > Gameplay > Reticle > Shape "Hunter's own") is each Hunter's own small look,
named by `content/archetypes/<id>.json` "reticle" and drawn by `scripts/ui/reticle_looks.gd` (`ReticleLooks`): Lace
stitches, Kael shackle arcs with an ember blade tick, Vex a coin rim with scope ticks, Albert an aegis hexagon, Neve a
snowflake, Cinder the fire triangle, Tenzo a rune ring, Sparkle a four-point spark, Grimble a goo drop, Meeko a sun,
Sable corner brackets, Motley a harlequin diamond, Gil a ring with a fin. With the "hunter" colour the strokes take the
Hunter's colour lifted by tuning `look_lift` (dark colours still read on dark ground); the dot keeps the plain accent.
Every look is strokes only, at most 3 px past the plain ring, and opens with bloom.

The ammo no longer draws at the cursor (tuning `reticle.ammo_at_cursor`, default 0): next to the ring it read as a
second ring on most Hunters, and the reference game keeps ammo in the weapon panel, not at the cursor; ours is in the
HUD's weapon panel too. Set it to 1 to bring the thin ammo arc back. The other gauge arcs (resource, charge, and the
AimKit charge ring) draw only their filled part over a thin dark edge (`Reticle.arc`, edge only with the outline
setting on): the black full-length track they used to sit on read as a shadow ring round the reticle. Kael's blade tick
above his shackle arcs is part of his look.
Checks: `--reticle-check` (every Hunter's look is known and its own; every look draws).
Proof (real GPU, `--resolution 1920x1080`): `--reticle-looks-shots` (dark/light/grass swatch rows, labelled, at rest)
and `--reticle-proof-shots` (every Hunter full frame at rest and firing, contact sheets of 3 tiles a row with 2x zoom).
