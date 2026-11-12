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
scrolls at the ground speed (a slide shows against the squares). Before/after MP4: `~/meshy/anim-dir-1112/` on hetzner; Grimble, Sparkle and Albert run, sprint and crouch walk for the last 30 cells: `~/meshy/anim-loco-dir-last/loco_dir_before_after_v3.mp4` on rpc1 (jobs 20261112-103748-11485 before, 20261112-103907-24157 after).

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

## Starts (ext/anim-loco-starts)
Moving off from idle at walk and run, per Hunter and direction, the check's `start` JSON carries the first-pose gap
(the ring's pose as it starts showing against the idle's, worst point over his height), the ring's phase, and the
frame of the first plant against the frame the ring passes that foot's contact key (the phase the sole touches down
at in the steady loop). PLANT fails a cell whose first foot down lands over 2 frames off its key.
- **Before:** a ring at no weight stands still, so a start picked up wherever the last stop left it: any stride, a foot
  half through its swing. And the clip rate eased up from the stopped value (0.6x) while the body was at speed in 3
  frames (HunterMove accel 47-54 m/s^2), so the first steps played slow under him.
- **Now (scripts/heroes/warden_start.gd, WardenClips._loco):** one start for every Hunter. The rings pick up at the
  phase of the forward loop whose points (hips, head, hands, ankles: the clip's rotations on the rest) lie nearest
  the idle's top; the run ring picks up on the same stride (nearest that walk pose too), and whenever the run ring
  comes in from no weight it takes the walk ring's stride. Until the rings own the legs the rate is the ground speed
  over the loop's sole speed with no ease, so the stride covers what the accel carries him. No per-Hunter numbers.
- **Before -> after,** 176 start cells: first plant on its key 161 -> 166; first-pose gap mean 24.6 % -> 21.3 %,
  worst 49 % -> 39 %; starts over the snap bar 13 -> 7 (all snaps 22 -> 17); `--loco-dir-check` known cells 30 -> 35
  with PLANT new (9 cells left the list, 14 joined: 10 PLANT, 4 SNAP). Video: `~/meshy/anim-loco-starts/`.
- **The way he goes (ext/anim-loco-snap-startstop):** the rings' direction rode a spring from the last way he went,
  also from idle, so a start to the right after a stop going forward swept the rings forward-right-right over the
  first 0.2 s: the clips of three directions blended while the idle faded out, and a run arm that swings hard (Grimble's
  hook arm, 58 deg in two frames in run_fr) popped as the weights crossed. Grimble's "bone layer after the tree" was
  this (the gait, turn and free-arm layers off changed nothing). From idle (no ring showing) the rings now take the
  way he goes at once, as they already did with the ring weight at zero. Left known: 30 cells of 616 (was 35):
  Grimble run/sprint/strafe r, Albert run r, Kael walk bl, Vex walk f/fl gone; Albert aim_walk bl and Sable walk r
  in (the new first pose is another stride phase: Albert's walk_bl has a 57 deg shin key step at 0.52 s that a start
  now lands on, Sable's first foot comes down 3 frames late). Per-direction start phases and a phase summed over all
  eight loops were tried: 14 and 14 new fails (the PLANT test reads the forward loop's key), not kept.
- **Stops:** not in this pass. `ext/anim-stop-on-stride` (READY, WardenStride) owns the run stop; Albert's crouch stops
  (hand.R) are his half-turn rest below.

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

## One start (ext/anim-loco-snap-startstop): 30 → 19, SNAP 13 → 8
The two branches above each opened the rings their own way (WardenStart's per-ring seek to the pose nearest the idle;
a held `ring_seek` at `loco.ring_start`). One stays: WardenStart. Rings of one length (Albert, Grimble, Sparkle after
the re-timing) open both on `loco.ring_start` (0 by default: the strike key); other Hunters keep the pose nearest the
idle. The nearest-idle phase on Grimble's locked rings put 11 cells over the bar (his hook arm on run starts), so the
strike key it is. `rings.sync`, `rest_bones` and the leg-pitch arm fix come in as they were.
Per Hunter, SNAP before → after: Albert 13 → 7 (gone: crouch_walk r/b/l and crouch_idle r/br/bl/l by the
`rest_bones` forearm, run bl stop; new: walk/aim_walk fl stop), Grimble 0 → 1 (run f stop, new),
others 0.
All failing cells 30 → 19: SLIP 9 → 3 (ext/anim-loco-slip's turned run diagonals), PLANT 7 → 7.
Tried and dropped: the eased start rate (the 3 new stops pass, 5 starts land 4-11 frames off their contact key: the stop
cells read the stride phase the start left), and `rest_bones` on Albert's shins (7 cells fail: slips and plants).

## Left (docs/DEBT.md): 19 cells
- Albert crouch (5), **the clip**: crouch_f has no stance (crouch_walk fr/fl/br/bl, crouch_idle b); see above.
- Albert walk/aim_walk br/bl SNAP (4): his walk_b* shins sit 60-178 deg off their rest (a 57 deg shin key step in
  walk_bl), so a start or stop blended with the idle flips the toe. Needs the shins re-keyed (Blender).
- Stops over the bar by 2-6 % at the check's one stop phase (3): Albert walk/aim_walk fl toe 1.030 (bar 1.013), Grimble
  run f hand.L 0.510 (bar 0.480). The stop does not wait for the planted foot: ext/anim-stop-on-stride (WardenStride).
- PLANT (7): Albert walk fr/r/b, Kael run b, Sable walk r / run fr/fl: first foot down over 2 frames off its key.
- Vex's rebuilt run_f has a shorter stance than the old one, so its kept arm keys swung with the legs; `arm_swing`
  now drives both arms off the legs (0.5 each), as it did her right one.
