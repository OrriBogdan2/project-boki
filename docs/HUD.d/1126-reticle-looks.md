## One reticle per Hunter (11-26)

The reticle's "default" shape (Settings > Gameplay > Reticle > Shape "Hunter's own") is each Hunter's own small look,
named by `content/archetypes/<id>.json` "reticle" and drawn by `scripts/ui/reticle_looks.gd` (`ReticleLooks`): Lace
stitches, Kael shackle arcs with an ember blade tick, Vex a coin rim with scope ticks, Albert an aegis hexagon, Neve a
snowflake, Cinder the fire triangle, Tenzo a rune ring, Sparkle a four-point spark, Grimble a goo drop, Meeko a sun,
Sable corner brackets, Motley a harlequin diamond, Gil a ring with a fin. With the "hunter" colour the strokes take the
Hunter's colour lifted by tuning `look_lift` (dark colours still read on dark ground); the dot keeps the plain accent.
Every look is strokes only, at most 3 px past the plain ring, and opens with bloom.

The gauge arcs round it (ammo, resource, charge, and the AimKit charge ring) draw only their filled part over a thin
dark edge (`Reticle.arc`, edge only with the outline setting on). The black full-length track they used to sit on read
as a second, shadow ring round the reticle (an empty gauge, like Kael's rage at the start, showed only that track).
Checks: `--reticle-check` (every Hunter's look is known and its own; every look draws), sheet: `--reticle-looks-shots`.
