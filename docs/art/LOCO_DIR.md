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

`--loco-dir-shots --shots-dir=<dir>` films 8 copies of a Hunter, one per direction, each on a checker floor that
scrolls at the ground speed (a slide shows against the squares). Before/after MP4: `~/meshy/anim-dir-1112/` on hetzner.

## Grid: failing cells of 8, before (the 0.24.5 integ + the READY dirloops, crouch-rest-2, run-aim-twist branches) -> after
| Hunter | walk | run | sprint | crouch_walk | crouch_idle | strafe | aim_walk | total |
|---|---|---|---|---|---|---|---|---|
| Lace (archer) | 1 → 0 | 1 → 1 | 4 → 0 | 3 → 0 | 0 → 0 | 4 → 0 | 1 → 0 | 14 → 1 |
| Cinder (ashwick) | 2 → 2 | 7 → 6 | 6 → 7 | 4 → 1 | 1 → 1 | 7 → 7 | 2 → 2 | 29 → 26 |
| Albert (bulwark) | 3 → 1 | 8 → 3 | 4 → 2 | 6 → 6 | 3 → 3 | 1 → 4 | 3 → 1 | 28 → 20 |
| Tenzo (dolm) | 0 → 0 | 6 → 5 | 6 → 1 | 7 → 1 | 0 → 0 | 6 → 1 | 0 → 0 | 25 → 8 |
| Grimble (dredge) | 6 → 3 | 5 → 5 | 5 → 4 | 4 → 0 | 0 → 0 | 4 → 4 | 5 → 4 | 29 → 20 |
| Vex (gunslinger) | 3 → 3 | 6 → 5 | 4 → 4 | 3 → 0 | 0 → 0 | 4 → 5 | 3 → 3 | 23 → 20 |
| Kael (juggernaut) | 2 → 1 | 3 → 8 | 4 → 5 | 4 → 7 | 1 → 0 | 4 → 8 | 3 → 1 | 21 → 30 |
| Sparkle (mage) | 2 → 3 | 6 → 4 | 3 → 3 | 4 → 0 | 0 → 0 | 3 → 4 | 2 → 4 | 20 → 18 |
| Neve (rimewright) | 1 → 6 | 8 → 8 | 7 → 2 | 4 → 0 | 0 → 0 | 7 → 2 | 2 → 1 | 29 → 19 |
| Meeko (tender) | 5 → 2 | 6 → 4 | 4 → 2 | 6 → 0 | 0 → 0 | 4 → 4 | 7 → 2 | 32 → 14 |
| Sable (thief) | 3 → 1 | 3 → 5 | 1 → 1 | 4 → 0 | 0 → 0 | 1 → 1 | 2 → 1 | 14 → 9 |
| **all 11** | 28 → 22 | 59 → 54 | 48 → 31 | 49 → 15 | 5 → 4 | 45 → 40 | 30 → 19 | **264 → 185** |

By test, before → after: DIR 33 → 19, SKATE 70 → 9, SLIP 74 → 68, SNAP 87 → 89.

## What was broken, what changed
- **Crouch walk backwards and sideways skated:** several shipped crouch_b/l/r planted at a fraction of crouch_f's
  speed (Tenzo crouch_b 0.31 m/s against 2.66), and the sneak ring had no diagonals: at 45 deg it blended crouch_f
  with crouch_r out of step, and the feet went sideways or nowhere (DIR on every diagonal). hunter_dir_gait.py now
  builds a crouch ring (GAITS `crouch`): b, l, r and the four diagonals at crouch_f's own sole speed and length, in step;
  WardenClips syncs the ring and adds the diagonals. Baked for 10 Hunters; Albert is left (below).
- **Walk to run:** the blend rested between the walk and run rings, which differ in length, so their feet cancelled
  (Lace's run, Tenzo's sprint). It now holds one ring (switch at 1.3x `walk_speed`, back at 1.2x) on a critically
  damped spring; the rates ease.
- **Rates:** `foot_mps` was measured at the shin's tip, which a heel-to-toe roll over a pinned sole reads as a slide,
  and the pilot rings (Tenzo, Vex, Albert, Neve) had none, so they played at speed / walk_speed while the model is
  scaled (Tenzo x0.75): the feet carried ~55 %. Every Hunter's `foot_mps` is now the in-game sole median of its ring;
  the rate cap is 1.8 (was 1.4).

## Left (docs/DEBT.md)
- Albert's crouch: his crouch_f plants at 0.39 m/s with the hips 9 cm up on 14 cm legs; the recipe can't build a ring
  from it. Needs a hand-made sneak.
- SNAP (89 cells): mostly Cinder, Kael, Neve, Vex at run/sprint start and stop: WardenGait's stride layer fades in and
  out at 8/s as the speed crosses 0.25 m/s, and walk and run loops of unequal length meet mid-blend.
- SLIP (68 cells, most within 1.2x the bar; Kael's crouch ring overruns at the crouch-rest-2 speed that --crouch-check holds): a ring whose directions plant at different speeds (one rate per ring);
  per-direction rates, or re-baked rings on the pilot recipe, would close it.
