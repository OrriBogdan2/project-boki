# Pose pops at land, glide exit, dash end and cast end (owner concern 4)

`--cast-pop-check` (tools/cast_pop_check.gd) now has a second pass, the POPDEG lines. It drives every Hunter with clips
(12 of the 13 v95 Hunters; Gil has no clips, his rig is procedural) through four hand-overs on the live AnimationTree, 60
frames a second, with the state the game feeds it, and fails any bone that turns more than 25 deg between two frames:

- jump-land: a hop (6 m/s) and a drop (10 m/s), standing and running;
- glide exit to run: the glide's touchdown (`was_glide`, tier 2) and the dive's (tier 3) into the run;
- dash end: the Hunter's dash move (`DASH_END` in the tool) from its last frame into the run;
- cast end: every keyed move, from its last frame, standing and running.

How a pop is told from the motion a bone has anyway: some arms and legs are keyed a swing a frame (the run cycle of
Albert, Sparkle, Meeko, Neve, Cinder, Grimble turns a leg or an arm 40 to 150 deg a frame at 60 fps). A bone counts only
for a frame past 1.25 times its own fastest frame in the steady idle and run, and past 1.25 times its fastest frame in the 30
frames before the hand-over (a spinning barrel); a bone whose steady frame is already past 25 deg is listed as a seam
and not judged. Each hand-over is driven three times with the run's phase moved on between them, and a bone's turn counts
as the least of the three, so a seam of the run cycle (it lands on other frames each time) is not a pop of the
hand-over (the same frame each time). Springs and extras (`spring_*`, `x_*`) and the gatling barrel are not judged.
Table cells are the worst frame turn of any judged bone, deg a frame; 0 means nothing went past its own steady turn.
Whole-run numbers: `--cast-pop-check` prints every Hunter's row (`--cast-pop-check=<ids> --pop-move=<kit move>` one move).

## Before and after (main facb5c3e22 against this branch, same tool)

| Hunter | jump-land | glide exit to run | dash end | cast end (worst move) |
|---|---|---|---|---|
| Lace (archer) | 23 -> 19 | 30 -> 0 | 0 -> 0 | 90 -> 6 (arc_draw -> arc_heavy_wind) |
| Kael (juggernaut) | 47 -> 25 | 66 -> 0 | 0 -> 0 | 11 -> 11 (jug_meteor -> jug_wave_wind) |
| Vex (gunslinger) | 7 -> 7 | 12 -> 12 | 0 -> 0 | 3 -> 3 (gunslinger_e -> gunslinger_e) |
| Albert (bulwark) | 19 -> 18 | 26 -> 24 | 0 -> 0 | 142 -> 56 (bul_smash_wind -> bul_smash_wind) |
| Neve (rimewright) | 37 -> 2 | 3 -> 2 | 0 -> 0 | 22 -> 22 (tm_spear_aim -> tm_spear_aim) |
| Cinder (ashwick) | 6 -> 6 | 1 -> 1 | 0 -> 0 | 2 -> 2 (lw_stoke_lance -> lw_stoke_lance) |
| Tenzo (dolm) | 34 -> 22 | 0 -> 0 | 0 -> 0 | 49 -> 34 (breah_leap -> breah_exdash) |
| Sparkle (mage) | 0 -> 0 | 7 -> 7 | 0 -> 0 | 14 -> 14 (mage_e -> mage_e) |
| Grimble (dredge) | 8 -> 5 | 45 -> 2 | 0 -> 0 | 6 -> 6 (dr_throw -> dr_throw) |
| Meeko (tender) | 7 -> 7 | 12 -> 12 | 0 -> 0 | 5 -> 5 (mm_call_hold -> mm_call_hold) |
| Sable (thief) | 6 -> 6 | 4 -> 4 | 0 -> 0 | 134 -> 2 (thf_encore_dance -> thf_flourish) |
| Motley (ostra) | 50 -> 33 | 50 -> 33 | 0 -> 0 | 31 -> 31 (ostra_seed -> ostra_seed) |

## What fixed what

- Land and air blends (new keys, `warden_anim/<art>.json`): `land.hop|drop.fade` / `.out` (s, the land clip's blend in and
  back to the legs, default 0.1 / 0.16) and `air.fade_out` (s, the fall and glide poses letting go of the body on touchdown,
  default 0.12). Set to 0.2-0.35 for Kael, Lace, Albert, Neve, Tenzo, Grimble, Motley. Cost: a softer landing entry on
  those Hunters (the crouch shows a little later); the land pose of a running landing may not reach full weight where the
  fade is longer than its 0.08-0.13 s hold.
- Cast ends: `fade_out` 0.34-0.6 s on Lace's torso moves, Albert's `bul_smash_wind`/`bul_launch`/`bul_break`, Sable's
  `thf_lmb_*` and `thf_encore_dance`, Tenzo's `breah_leap` (upper-body moves: the legs keep running, so a longer blend back
  costs the torso only). Lace's seven blend-outs the gap check (`POP`) asked longer (it was red on main) are set to what it asks.
- Code, `WardenGait.apply`: the arm swing's running mean pitch kept tracking the arm while a clip owned it (a bow drawn
  over the run), then the swing pulled the arm to that stale pose as the move ended: a 90 deg a frame whip of the upper
  arm at the end of Lace's draw. The mean now stands still while the swing is off.

## Still over 25 deg (the check holds each at its ceiling, `KNOWN` in the tool; art lane)

| Hunter | what | deg a frame | why a blend time does not reach it |
|---|---|---|---|
| Albert | `bul_smash_wind` ends on the run, forearm.R | 56 | any `fade_out` from 0.3 to 0.9 s gives 56-142: the clip's forearm and the run's sit near opposite sides of the blend, the shortest path flips mid-blend. Re-key the clip's last frame near the run's forearm. |
| Tenzo | `breah_exdash` standing, shin.R | 34 | the same at 0.4-1.2 s fade: the clip's own last two frames turn the shin 34 deg a frame. Ease the clip's end. |
| Motley | the land clip, hand.L (hop, drop, glide) | 33 | 50 before, 39 at fade 0.25, 33 at 0.35: the land clip's hand.L is far from the air pose. Retarget hand.L in `land`. |
| Motley | `ostra_seed` on the run, `ostra_swap_air` standing, hand.L | 31, 30 | the same hand.L. |

Kael's hop is at 24.9 deg (limit 25): no room left on his side.

Dash end is 0 for all twelve: every dash hands over to the run inside the steady run's own turn
(DASH_TRAVEL.md covers the body's travel and the ride of the dash pose over the run).

Seams of the steady run that the check lists but does not judge (the run cycle itself turns the bone this far in one
frame in this drive; not looked at in a live match): Albert's legs and left arm 106-130, Sparkle's forearms 102, Meeko's right upper arm 159,
Grimble's right forearm 80, Neve's right upper arm 77, Cinder's forearms 47-55. Not a blend problem; the cause is in the
run clip or in WardenGait's swing, and wants its own look.
