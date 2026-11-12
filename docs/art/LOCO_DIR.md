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
scrolls at the ground speed (a slide shows against the squares). Before/after MP4: `~/meshy/anim-dir-1112/` on hetzner.

## Grid: failing cells of 8, before -> after
Before is the 0.24.5 integ with the READY dirloops, crouch-rest-2 and run-aim-twist branches (cfa684194b), read by
today's audit.

| Hunter | walk | run | sprint | crouch_walk | crouch_idle | strafe | aim_walk | total |
|---|---|---|---|---|---|---|---|---|
| Lace (archer) | 1 → 0 | 1 → 0 | 4 → 0 | 4 → 0 | 0 → 0 | 4 → 0 | 1 → 0 | 15 → 0 |
| Cinder (ashwick) | 2 → 0 | 7 → 0 | 6 → 0 | 4 → 0 | 1 → 0 | 6 → 0 | 2 → 0 | 28 → 0 |
| Albert (bulwark) | 2 → 1 | 8 → 2 | 1 → 2 | 7 → 7 | 3 → 5 | 2 → 3 | 2 → 2 | 25 → 22 |
| Tenzo (dolm) | 0 → 0 | 6 → 0 | 5 → 0 | 7 → 0 | 1 → 0 | 5 → 0 | 0 → 0 | 24 → 0 |
| Grimble (dredge) | 5 → 0 | 5 → 3 | 5 → 2 | 3 → 0 | 0 → 0 | 5 → 1 | 5 → 0 | 28 → 6 |
| Vex (gunslinger) | 4 → 0 | 6 → 0 | 5 → 0 | 4 → 0 | 0 → 0 | 5 → 0 | 3 → 0 | 27 → 0 |
| Kael (juggernaut) | 1 → 0 | 6 → 0 | 5 → 0 | 3 → 0 | 1 → 0 | 4 → 0 | 2 → 0 | 22 → 0 |
| Sparkle (mage) | 3 → 0 | 7 → 2 | 4 → 0 | 3 → 0 | 0 → 0 | 2 → 0 | 3 → 0 | 22 → 2 |
| Neve (rimewright) | 2 → 0 | 8 → 0 | 7 → 0 | 3 → 0 | 0 → 0 | 8 → 0 | 3 → 0 | 31 → 0 |
| Meeko (tender) | 5 → 0 | 7 → 0 | 3 → 0 | 6 → 0 | 0 → 0 | 4 → 0 | 7 → 0 | 32 → 0 |
| Sable (thief) | 3 → 0 | 4 → 0 | 2 → 0 | 3 → 0 | 0 → 0 | 2 → 0 | 3 → 0 | 17 → 0 |
| **all 11** | 28 → 1 | 65 → 7 | 47 → 4 | 47 → 7 | 6 → 5 | 47 → 4 | 31 → 2 | **271 → 30** |

By test, before → after: DIR 24 → 1, SKATE 77 → 0, SLIP 78 → 9, SNAP 92 → 20.

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

## Left (docs/DEBT.md)
- Albert (22): his crouch_f barely plants (0.39 m/s, hips 9 cm up on 14 cm legs), so neither the recipe nor a turned
  copy gives his front crouch diagonals; his hammer arm is keyed near half a turn off its rest in crouch_b/l/r, and
  Godot 4.6 blends a bone's rotation as a turn off its rest (not off a RESET clip), so every crouch start and stop
  flips it; his run_fl/fr slip. Needs a hand-made sneak and his arm re-keyed or re-rested in the .glb.
- Grimble run, sprint, strafe (6) and Sparkle run (2): a start or stop peaks 5-85 % over the snap bar while the walk and run
  rings blend at different points of their strides and a run arm swings hard (Grimble's hook arm: 0.22 m/frame^2 in a
  steady run). Running both rings on one phase (the run ring's clock at its length over the walk's) took Grimble to 2,
  but turned Albert's arms with their legs in `--anim-audit` (his walk loop holds two strides): it needs each ring's
  strides per loop in the data first.
- Vex's rebuilt run_f has a shorter stance than the old one, so its kept arm keys swung with the legs; `arm_swing`
  now drives both arms off the legs (0.5 each), as it did her right one.
