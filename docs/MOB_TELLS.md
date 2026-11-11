# Monster tells: every attack can be dodged by watching it

Code: `scripts/match/mob_tell.gd` (`MobTell`), driven from `Mob` (`mob.gd`) and `Blight`. Check:
`--mob-tell-check` (tools/mob_tell_check.gd). Strips: `--mob-tell-check --shots-dir=<dir>` under
xvfb with a renderer (tools/mob_tell_shots.gd writes `mob_tell_<kind>.png` and `MANIFEST.txt`).

**One shape, two jobs.** `MobTell.shapes(mob, pad)` is the reach of an attack for a target of radius `pad`.
The ground tell is drawn from it and the blow is hit-tested with it (`AimMode.in_lane` /
`in_circle`), so they cannot drift apart. The tell is the Hunters' own delayed telegraph
(`Fx.telegraph_rect` / `telegraph_circle` with `telegraph_progress`, as `ArchKit.tele_lane` /
`tele_circle` use): it fills to the hit frame and stays up for `LINGER` (0.15 s) after it. A monster's
tell wears the rival tint (`Feel.hostile`: the colour leaned 45 % toward the hostile rim), the same as
an enemy Hunter's. The body glow is the model's flash mix in the same colour, rising linearly with the
wind-up to `GLOW_MAX` on the hit frame.

## Attacks (from `mob.gd`)

| Mob | Attack | Hit shape (centre line, before growing by the target's radius) | Wind-up | Hit frame |
|---|---|---|---|---|
| Skitter | lunge | lane from the body's back edge, 2.4 m dash + its own diameter long, as wide as its body (0.9 m) | 0.55 s, aim follows until the last 40 % | the lunge starts: all inside take the hit |
| Spitter | spit | one bolt lane: the bolt's swept circle (radius 0.32 + 0.08 m hit slack), 0.2 m to 9.5 m ahead (60 steps of 1/60 s), 0.8 m wide | 0.8 s, aim follows until the last 40 % | the bolt leaves; it flies 1.0 s at 8.5 m/s, so it is also dodged by watching it |
| Brute | slam | circle 2.3 m, centred 0.9 m ahead of it | 1.05 s, fixed from the start | the slam |
| The Watcher | slam | circle 3.3 m, centred 0.9 m ahead | 0.95 s, fixed | the slam |
| Puffbomb | fuse | circle 2.5 m around itself | 1.0 s, fixed | it bursts (and is gone) |
| Sentinel | volley | three bolt lanes at -0.2 / 0 / +0.2 rad: swept circles (0.28 + 0.08 m), 0.24 m to 11.57 m ahead (67 steps), 0.72 m wide | 0.95 s, aim follows until the last 40 % | the bolts leave; 9.5 m/s |
| Glimmerkin | none | it never attacks (it flees), so it has no tell | , | , |

Every shape also grows by the radius of whoever is attacked (`atk_pad`: the target's body, the stand-in
radius 0.4 m when nobody is targeted yet, as on a remote client). The vertical reach is `HIT_DY`.

## What the check proves
For each attacker: the tells read back off the telegraph nodes equal the real hit within 5 % (a stand-in
at 95 % of every edge is hurt, at 105 % and at 2 cm past the edge it is not, running the real attack); the fill reaches 1.0 on the
hit frame and not before; the full tell is still up on that frame; the body glow peaks on it; the tint is
the rival one; the tell is up for the whole wind-up (lead >= wind-up); and an instant blow (lunge, slam, burst) leaves a hunter on foot (4.4 m/s) the time to step
out while its shape is fixed.
The attackers are read from `Data.MOBS`, so a mob added with an attack id that has no tell fails
(lair bosses, attack `boss`, telegraph through `boss.gd`). Only the mob under test fights: the
map's own camps are taken out each step, because a wandering skitter pushing the stand-in moved it off
the edge probes. A bolt lane is the bolt's whole swept circle: its far end reaches the
bolt's radius and the hit slack past its last centre point, and a shot flies whole `Match.DT` steps, so a
life that is not a whole number of steps (the volley's 10.5 / 9.5 s) flies one step further. Before
0.24.6 the far end stopped at the centre line's end, so a hunter up to 0.5 m past the drawn tell was hit;
the 5 % probe (0.47 m on a 9.3 m lane) did not see it, the 2 cm one does.

## Low and Very Low presets
Nothing in a tell depends on the preset: the ground telegraph is the Fx telegraph shader (no particles,
so the `fx` amount does not thin it), and the body glow is an albedo mix, so it still shows under Very
Low's unshaded draw. At the default match camera (57 deg pitch, 32.2 m, 28 deg fov) the narrowest tell, the
skitter lane (0.9 m + the target's radius on each side = 1.7 m), is about 1/9 of the screen height. Strips
per preset: `--mob-tell-check --quality=low|very_low --shots-dir=<dir>`.
