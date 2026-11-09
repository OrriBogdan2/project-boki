# Firing on the run (job 20261109-063605-a1)

Every Hunter runs at full stick and fires LMB, RMB and E without letting go of the stick (`--fire-run-check`, a
real match). Slide: the planted feet's ground speed as a share of his speed (the `--anim-audit` measure), counted on
the frames he is still at full stick. "Body": the whole-body clip's weight (1.00: the legs play the clip, not the run).

| Hunter | move (slot) | before: body, slide | after: body, slide | his plain run |
|---|---|---|---|---|
| Kael | jug_slash_r (LMB) | 1.00, 115 % | 0.00, 24 % | 21 % |
| Kael | jug_chain (E) | 1.00, 107 % | 0.00, 30 % | 21 % |
| Cinder | as_cloak (E) | 1.00, 92 % | 0.00, 33 % | 32 % |
| Tenzo | breah_raise (E) | 1.00, 105 % | 0.00, 56 % | 44 % |
| Tenzo | breah_throw (LMB; slows him, 6 full-stick frames) | 1.00, 105 % all frames | 0.00, 67 % all frames | 44 % |
| Lace | arc_heavy (RMB) | 1.00, 100 % | 0.00, 54 % | 40 % |
| Sparkle | thf_knife (E) | 1.00, 109 % | 0.00, 58 % | 54 % |

Already on the upper body, within +25 of the plain run: Vex LMB/RMB, Cinder lance/aim/shot, Meeko shots/hearth,
Lace tap/hail, Grimble shot/reel/anchor, Motley all, Mossy throw/guard/mend, Sparkle throws/bola.
Not gated: rooted casts (Vex's Longneedle E stands her still), kit-driven lunges and leaps (Kael lunge, Tenzo slam),
Neve and Sable (they skate and hover: no stepping legs). Slow-downs (Cinder lance end, Meeko seed, Grimble throw)
slide on the walk/run blend: that is the gait layer's (WardenGait, ext/anim-quality-audit), not this one.

Strips (`--clip-shots --run-fire=<kmove> --yaw=100`, GPU; half a second of run, then the move): `<hunter>_<move>.png`,
top row before (main d255acbee), bottom row after.
