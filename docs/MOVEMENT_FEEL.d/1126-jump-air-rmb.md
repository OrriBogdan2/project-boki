## Jump height to the source, and Kael's jump -> RMB (11-26, `--move-feel-check`, `--air-rmb-feel-check`)

Owner 11-26: "how high do we jump compared to the reference game? it seems like not as high", and "the Kael jump ->
RMB feels a lot worse than Brall jump -> RMB" (Brall is the source's juggernaut). Parity first.

**Jump.** `Hunter.JUMP_V` 6.8 -> 7.5 m/s ([game data] JumpZVelocity 750 uu/s, gravity 1470 uu/s²). The farm shares it.

| Row | Before | After | Source |
|---|---|---|---|
| jump_apex | 1.52 m (1.57 m v²/2g) | 1.913 m | 1.91 m |
| jump_airtime | 0.900 s | 1.017 s | 1.02 s |
| lift-off / source | 0.87 | 0.967 (one step of gravity) | 1.0 |
| wall kick peak (`--wallmove-check`) | 2.40 m | 2.71 m | - |

The old jump was held low so jump + mantle stayed under the four-terrace wall tier. Now the cap is direct:
`HunterMove.ledge_reach` keeps the source's 1.5 m suction reach (the source runs it only over the abyss, so the
terrace rule is ours) but a jump never catches a lip more than `JUMP_TIERS` (3) terraces over where you stood; one
more after a wall kick (`WallMoves.chain`) or for the tall climbers. A glide, or a launch higher than a jump explains,
keeps the whole reach. `WallMoves.HOP_CLIMB_CAP` 1.6 -> 1.95 m (the new apex: a kick at the top of a jump still
goes). The wall tier results are unchanged: 1.6/2.4 m top from a jump, 3.2 m never (kick + mantle: yes), 4.0 m
never however much you kick.

The higher jump meets a one-terrace face with its lip 0-0.37 m over the feet on a dash + jump (under the ledge
catch's floor), where the wall used to stop you dead (`--cliff-mantle-check` face 1 dash_jump: kept 0.6x of the
speed 0/80, lip 5.3 m/s). `WallMoves.stopped` now holds the speed while you rise past a lip that close; you go over
it a step later still moving (80/80, lip 11.0 m/s; main 80/80 at 6.3 m/s through the ledge rise).

**Kael's air RMB (the Meteor Drop)**, headless, run 5.28 m/s, jump, RMB at the apex (1.91 m), 60 Hz steps:

| | Kael before | Kael after | Brall (source) |
|---|---|---|---|
| press to action | same step (hang) | same step | on the press (`bUsableMidAir`, client-predicted warm-up) |
| hang | 0.083 s, drift stopped | same (owner spec 11-10) | [?] |
| fall | 24 m/s, at least 0.12 s | 30 m/s, at least 0.08 s | [game data] 3000 uu/s (30 m/s) |
| press to hit, from the apex | 0.233 s | 0.183 s | montage hit notify 0.617 s; [footage] hang to impact f263-288 |
| run-up speed at the press / after | 5.28 / 0 m/s | same (straight down: owner spec) | the slam goes to the cursor (~5 m) |
| recovery | planted 0.2 s, walk back by 0.5 s | same | montage 1.567 s, blend out 0.25 s |
| Drop resting (7.2 s, source 9 s) | the ground Smash: tap acts on its release (+1 step), 0.6 s wind-up | same | HeavySlam, also mid-air, same 0.3 s tap/hold split |

So Kael was already at least as quick as Brall from the press; the fall now matches the source's speed. The open
difference is the momentum: Brall's slam carries to the cursor, Kael's stops dead and drops straight (owner spec).
