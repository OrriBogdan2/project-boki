# Locomotion in every direction (--loco-dir-check)

Owner 11-11: "when are we gonna have all the animations not be broken? like crouch walk backwards". This page is the
audit that answers it per Hunter, state and direction, what was fixed on ext/anim-dir-all-1112, and what is left.

## The audit
`godot --headless --path . -- --loco-dir-check [--wardens=a,b] [--json=f] [--update]` (tools/loco_dir_check.gd, in the
suite). Each Hunter with stepping clips (not Motley, who rides his spring, nor Gil, who has none) goes through the
game's own path (HunterAnim -> WardenClips) at fixed 60 Hz steps, starting at its HunterMove accel and braking with
HunterMove.brake, in 7 states x 8 directions off the facing:
walk (`walk_speed`), run (halfway to full stick), sprint (full stick: there is no sprint key), crouch walk (0.55 of it),
crouch idle (a stop out of the crouch walk), strafe (full stick with the aim swinging 29 deg either side at 0.5 Hz) and
aim walk (the same at walk speed; the Hunter always faces his aim, so every walk is an aim walk).

A foot is its sole: a heel and a toe point riding the foot bone (the shin where no verts sit on a foot bone: Kael,
Albert's appeal3 body); the lower one is on the floor. Over 2 s of steady motion the planted sole must travel back
against the move within 40 deg (DIR: no forward loop walked backwards, no mirrored side loop), carry at least 55 % of
the ground speed (SKATE) and slip over it at most 45 % of it (SLIP); a start or stop must not change any point's
velocity in one frame by more than 2.5x the loop's own worst (SNAP). It is a ratchet: `tools/loco_dir_known.txt`
lists the cells failing today; any other failing cell fails the suite, and `--update` rewrites the list after a fix.
Its JSON carries each cell's ground speed and clip rate: a ring's planted-sole speed at rate 1 is carry x speed /
rate, and `loco.foot_mps` and `crouch.speed` are the median of the 8 directions.

`--loco-dir-shots --shots-dir=<dir>` films 8 copies of a Hunter, one per direction, each on a checker floor that
scrolls at the ground speed (a slide shows against the squares). Before/after MP4: `~/meshy/anim-dir-1112/` on hetzner; Grimble, Sparkle and Albert run, sprint and crouch walk for the last 30 cells: `~/meshy/anim-loco-dir-last/loco_dir_before_after_v3.mp4` on rpc1 (jobs 20261112-103748-11485 before, 20261112-103907-24157 after). Albert's last 9 (run and crouch walk before | after, strafe and aim walk after): `~/meshy/anim-loco-dir-last/loco_dir_before_after_v4.mp4` (jobs 20261112-103907-24157 before, 20261112-113614-27166 after).

## Grid: failing cells of 8, before -> after
Before is the 0.24.5 integ with the READY dirloops, crouch-rest-2 and run-aim-twist branches (cfa684194b), read by
today's audit.

| Hunter | walk | run | sprint | crouch_walk | crouch_idle | strafe | aim_walk | total |
|---|---|---|---|---|---|---|---|---|
| Lace (archer) | 1 → 0 | 1 → 0 | 4 → 0 | 4 → 0 | 0 → 0 | 4 → 0 | 1 → 0 | 15 → 0 |
| Cinder (ashwick) | 2 → 0 | 7 → 0 | 6 → 0 | 4 → 0 | 1 → 0 | 6 → 0 | 2 → 0 | 28 → 0 |
| Albert (bulwark) | 2 → 0 | 8 → 0 | 1 → 0 | 7 → 4 | 3 → 1 | 2 → 0 | 2 → 0 | 25 → 5 |
| Tenzo (dolm) | 0 → 0 | 6 → 0 | 5 → 0 | 7 → 0 | 1 → 0 | 5 → 0 | 0 → 0 | 24 → 0 |
| Grimble (dredge) | 5 → 0 | 5 → 0 | 5 → 0 | 3 → 0 | 0 → 0 | 5 → 0 | 5 → 0 | 28 → 0 |
| Vex (gunslinger) | 4 → 0 | 6 → 0 | 5 → 0 | 4 → 0 | 0 → 0 | 5 → 0 | 3 → 0 | 27 → 0 |
| Kael (juggernaut) | 1 → 0 | 6 → 0 | 5 → 0 | 3 → 0 | 1 → 0 | 4 → 0 | 2 → 0 | 22 → 0 |
| Sparkle (mage) | 3 → 0 | 7 → 0 | 4 → 0 | 3 → 0 | 0 → 0 | 2 → 0 | 3 → 0 | 22 → 0 |
| Neve (rimewright) | 2 → 0 | 8 → 0 | 7 → 0 | 3 → 0 | 0 → 0 | 8 → 0 | 3 → 0 | 31 → 0 |
| Meeko (tender) | 5 → 0 | 7 → 1 | 3 → 0 | 6 → 0 | 0 → 0 | 4 → 0 | 7 → 0 | 32 → 1 |
| Sable (thief) | 3 → 0 | 4 → 0 | 2 → 0 | 3 → 0 | 0 → 0 | 2 → 0 | 3 → 0 | 17 → 0 |
| **all 11** | 28 → 0 | 65 → 1 | 47 → 0 | 47 → 4 | 6 → 1 | 47 → 0 | 31 → 0 | **271 → 6** |

By test, before → after: DIR 24 → 1, SKATE 77 → 0, SLIP 78 → 3, SNAP 92 → 2.

ext/anim-loco-slip (merged into ext/anim-loco-dir-last): Albert's run_fl/fr turned from run_f
(art/wardens/breaker/IMPORT.md): run, sprint and strafe fl/fr clean.

## What was broken, what changed
- **Starts and stops popped:** the idle, a walk ring at radius 0.45 and a run ring at 1 sat in one BlendSpace2D, so
  every start, stop or walk/run change crossed the walk ring at speed, where the triangle weights turn a corner, and the
  feet and hands jumped. WardenClips now mixes the idle, a walk ring and a run ring (each a BlendSpace2D of the
  directions on the unit circle) with Blend2 weights on critically damped springs. A stop starts the idle from its top:
  Neve's idle spins at 4-5 s, and a stop that landed there swung her root through half a turn.
- **Run-and-aim slid sideways:** the aim twist turned the root's rotation but not its position, so a loop's sway of the
  root pushed a planted foot sideways once the legs turned (Vex: 19 cells); the turn rides the same spring now.
- **Diagonals walked the wrong way:** Grimble, Sparkle and Meeko had only f/b/l/r walk and run loops, so a diagonal
  blended two loops out of step. hunter_dir_gait.py builds their b, l, r and diagonals on the recipe at the forward
  loop's own sole speed; Albert's back crouch diagonals are crouch_b turned 45 deg into the move ("bl~").
- **Forward loops skated:** several shipped forward loops never planted at one speed (Tenzo's run_f 0.75..8.89 m/s, Vex's
  run_f 0.58..6.67, Neve's walk_f and run_f, Sable's and Meeko's walk_f); they are rebuilt on the ring's recipe, the
  upper body kept.
- **Rates:** `loco.stride` stretched the side and back loops of a recipe ring 1.3-1.6x faster than the rest; it is off on
  those rings (Grimble, Sparkle, Kael; Meeko keeps 1.3 on her run, whose short stride can't reach 4.55 m/s at the top
  rate), and `foot_mps` and every `crouch.speed` are the measured sole medians
  (Kael's sneak overran 1.5x at 1.55, Tenzo's 1.3x). `--crouch-check` no longer measures the plant: it read Kael at a
  point on his shin's line that a crouched shin swings off the boot.
- The audit named his left "r" (the model's yaw turns him left); every side cell was the mirror one.

## Last 30 cells (ext/anim-loco-dir-last): 30 → 6
Per cell: the clip, the ring blend or the foot_mps number? Grimble's and Sparkle's 8 were all one cause, **the ring
blend**: Grimble's run_f/fl/fr (and Sparkle's) swing an arm over 100 degrees from the walk loop's, and a start,
stop or walk/run change crossfaded a hidden ring at whatever stride it had frozen in (Godot's Blend2 does not advance a
hidden input), so the two arms sat near half a turn apart. `Quaternion` blends take the short way round, and at the
crossfade the forearm flipped 140-170 degrees in one frame (a hand 0.6 m away): with the walk ring only, or the run ring
only, every cell passed; spring rates, `arm_swing` and re-resting the arm did not move it. The fix is data and a few
lines: the run loops are re-timed to the walk loop's length (`tools/art1/glb_add_clips.py --stretch`; Grimble 0.63 →
1.0 s, Sparkle 0.60 → 0.75 s with her walk loops, both on one strike key), `foot_mps` is re-measured on the sole
(Grimble 1.59 / 4.71 → 1.59 / 2.98, Sparkle 1.11 / 3.47 → 1.38 / 2.77: the same cadence at speed, a longer stride per
turn), and WardenClips keeps rings of one length advancing in step (`rings.sync`) and holds them at `loco.ring_start`
(0 by default; Sparkle 0.25) while he stands, so a start opens on a stride the idle's arms can blend into.
Albert's hammer forearm (`forearm.R`) sits 177-179 degrees off its rest in every crouch clip, so crouch starts and stops
flipped it: `loco.rest_bones` re-rests it at the mean of its keys at load (`WardenClips._rerest`; the .glb's rest stays,
WardenGlb checks it) and 7 crouch cells pass.

Albert's run/sprint/strafe fl/fr (6) are ext/anim-loco-slip's turned run_f. His start snaps (walk br, strafe bl,
aim_walk br/bl) were **the ring blend**, hidden behind **an arm bug**: WardenGait's `arm_swing` set his left arm
against the pitch of his thigh's Y axis, but his thighs point every way but down (straight ahead for half a stride,
then out and up), so that pitch ran a full turn each stride and threw his hand 1.26 m in one frame (`--anim-audit`
arms read +0.36 or -0.5 by where the rings waited). The leg's pitch is now its lean ahead, hip to ankle (a rig
without feet: the knee); his hand moves at most 0.38 m a frame against 0.12 for the clip alone, arms 0.33, the same
at every start. With that, `loco.ring_start` 0.32 (clean 0.30-0.34, narrow) opens his walk ring on a stride the idle's
feet blend into, and the four start snaps pass. Other Hunters' arms: Lace 0.83 → 0.95, Cinder 0.79 → 0.91, Sable
0.83 → 0.94, Vex 0.95 → 0.92, Meeko 0.33 → 0.32.

## Left (docs/DEBT.md): 6 cells
- Albert crouch (5), **the clip**: crouch_f has no stance. Each sole sits in its lowest band 1-2 frames a 0.6 s
  cycle (7-13 planted samples of 120 at 60 Hz), so a cell reads whatever instant the sampling lands on: crouch_f
  passes (0.62 carry) and the same loop turned 45 deg (`fl~`, a rigid turn in game: foot yaw 46 deg) carries 0.08-0.12.
  crouch_walk fr/fl blend crouch_f with crouch_r/l (137 deg off, slip 3.6 m/s), br/bl are crouch_b turned (slip
  1.45-1.49 at 2.67, bar 1.20), crouch_idle b pops 0.44 (bar 0.33). The recipe can't step it: its hips sit about a
  full leg over his floor, so `hunter_dir_gait.py ... crouch` plants no sole. Needs a hand-made sneak with real
  stances. One length for the sneak ring (crouch_bl/br 0.604 → 0.600 s) turns its sync on and adds 5 SNAP: no.
- Meeko run r (1): a start pop of her right hand, 0.098, the same as before; her steady run's arm is smoother with the
  new leg pitch, so the bar (2.5x the steady worst) fell 0.102 → 0.082. ext/anim-meeko-stride re-tunes her arms.
- Vex's rebuilt run_f has a shorter stance than the old one, so its kept arm keys swung with the legs; `arm_swing`
  now drives both arms off the legs (0.5 each), as it did her right one.
