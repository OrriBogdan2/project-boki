## Grounded steps and dashes per Hunter (11-27)

Follows `1126-grounded-sfx.md` (owner 11-26: "sfx are too arcade-y across the board"). Wave 1 grounded the shared
`step0-2`, `dash_ground` and `dash_air`; every Hunter's own `<arch>_step_<surface>`, `<arch>_dash` and
`<arch>_dash_air` still used the old recipe, and they are what you actually hear (HeroSfx.of picks the Hunter's own).

`tools/gen_sfx_grounded_moves.py` rewrites them with the wave-1 recipe (transient + body + tail, weight in the lower
mids, foley not tones, nothing above ~4 kHz, a light dark room, 4 takes for steps and ground dashes, 3 for air dashes).
Run it after the group scripts and `gen_sfx_dash.py`. Per Hunter it varies MASS (how heavy the heel and push-off
land, how long the skid runs) and one GEAR foley layer (plate, leather, junk, stone, wet, cloth). Surfaces keep their
material: grass a soft swish, stone a hard tap with grit, wood a hollow knock, snow a packed crunch. The ground-dash skid
starts bright on contact and darkens as it slows, so it no longer rises like a sweep. Kept as ruled: the air dash has
no ground contact (wind, cloth, a soft whump and the Hunter's own trail: Kael's flame, Grimble's junk, ice, sparks),
so it stays different from the ground dash. Gil's dashes (water) and `water_dash` are not touched.

Arcade audit (`tools/sfx_arcade_audit.py`, the 72 base sounds of these sets, Gil's dashes and `water_dash` left out),
before -> after: bright 7 -> 0, rising 19 -> 6, one-take 6 -> 0. Median spectral centroid per file (Hz): steps
1307 -> 832, ground dashes 1864 -> 1084, air dashes 3670 -> 1083. Steps still read "dry" (under 4% of energy after
120 ms), like wave 1's `step0-2`: a footstep with a longer tail smears at 4-5 steps a second.
