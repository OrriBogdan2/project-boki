# Uthana rank and cleanup test (job 20261110-234902-a6)

## Verdict: NO-GO

**Don't move hunters onto Uthana.** The cleanup pipeline works: it can make a raw Uthana clip game-ready on our rig, at our kit's timings. But even after cleanup, no clip is better than the hand-made clip it would replace, seen through the game camera. The best result was the cleaned death, at 18/25 against 19/25 for the current one. The parts that made the cleaned clips usable were mostly our own work, not Uthana's:

- the whirl's circling comes from orbit IK
- the bow string comes from our own draw clip
- the shield arm comes from our own idle

The style score stays at 2-3 out of 5. Uthana produces realistic mocap motion, and our style is snappy cartoon.

**Where it could still pay:**

- deaths and emotes: they're seen rarely, and weight matters more there than style
- a new hunter that has no clips yet

The pipeline is committed under `tools/anim/`, so either case can start from it.

**Cost, if this is ever revisited:** about $58 for all 12 hunters. That assumes 6 action moves per hunter, 2 takes per move, 4 s per take, at $0.10/s. This job's own calls matched $0.10/s. On top of that, each move took about an hour of recipe tuning.

- **Generate (if revisited):** deaths, victory/emotes, and the heavy slams (Faultline-type overhead strikes, which scored best raw).
- **Keep:** everything else, including all locomotion, idles, hits, dodges, light attacks and casts. In the rank below these score 9-15. Our clips already sync to the kit and fit the style.

**No clip has been swapped into a hunter's live animation set.**

## Spend

| | Balance (org payg_total_usd) |
|---|---|
| Start, 2026-11-10 23:51 UTC | $21.1791 |
| End, 2026-11-11 00:25 UTC | $18.3497 |

- The balance fell $2.83, under the $3 cap. The guard checked the balance before each call (`art/uthana_pilot/tools/spend.log`).
- This job made 2 generation calls, both 4 s TTM 3.0 (`whirl_v1` and `whirl_v2`, see `art/uthana_pilot/rank_motions.txt`). The first call cost $0.40.
- Most of the rest of the drop came from someone else using the shared org account at the same time:
  - The balance fell $2.02 across the second call.
  - It fell another $0.40 between 00:20 and 00:25, when this job made no calls at all.
- Once the cap was close, no more calls were made, so each move got only one take.

## Rank: every pilot clip, raw, on the real rig, at the game camera

**How the clips were rendered**

- Camera: `cam.gd` "supervive" (pitch 66°, 23 m back, 32° lens, the body leaned back 20°).
- Panel: a 480 px crop of a 1440p screen, with the current in-game clip on the left and the raw Uthana clip on the right.
- Videos: `/home/boki/art-review/uthana-rank-1110/rank_*.mp4`.

**How the clips were scored**

- Scores are 1-5 in five columns: readability (R), weight/impact (W), silhouette (S), foot contact (F), and style fit for snappy cartoon (St).
- Slide is how far the planted feet slid, in metres, over one play of the clip. Low is how far the lowest bone went below the floor.
- Every raw clip has the same problems: it faces about 180° away from our forward, and Albert's shield arm is splayed out.

| # | Clip (rig) | Stands in for | R | W | S | F | St | Sum | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | albert_heavy_v3 (breaker) | Faultline x_wind→x_slam | 4 | 4 | 4 | 2 | 2 | 16 | A big readable overhead arc. Sinks 0.19 m and slides 0.89 m. Never recovers from the crouch. |
| 2 | albert_victory_v3 (breaker) | emote | 3 | 3 | 4 | 4 | 2 | 16 | Clean, but a realistic gesture rather than a pose. |
| 3 | lace_light_v3 (hem) | LMB draw→loose | 3 | 2 | 4 | 4 | 2 | 15 | Good draw. Holds full draw for 1.6 s. The release is nearly invisible. Frontal stance. |
| 4 | albert_idle_v2 (breaker) | idle | 3 | 3 | 3 | 4 | 2 | 15 | A mocap idle (slide 0.13 m). |
| 5 | lace_death_v3 (hem) | death | 4 | 3 | 3 | 2 | 2 | 14 | A real fall, at 2.6-3.3 s. Sinks 0.25 m and slides 1.5 m. |
| 6 | walk_loop (breaker) | walk_f | 3 | 3 | 3 | 3 | 2 | 14 | Walks forward (the game moves the hunter itself). |
| 7 | run_loop (breaker) | run_f | 3 | 3 | 3 | 3 | 2 | 14 | |
| 8 | albert_whirl_v2 (breaker) | LMB hold whirl→slam | 2 | 3 | 3 | 3 | 2 | 13 | Only small circles overhead (0.3-0.9 m/s), then a big sweep at 2.9-3.5 s. |
| 9 | run_loop (hem) | run_f | 3 | 3 | 3 | 2 | 2 | 13 | Slide 2.3 m. |
| 10 | lace_hit_v2 (hem) | hit_f | 3 | 3 | 3 | 2 | 2 | 13 | Staggers 1.5 m (ours is in place, 0.37-0.43 s). |
| 11 | lace_hit_v2 (breaker) | hit_f | 3 | 3 | 3 | 2 | 2 | 13 | Staggers 0.9 m. |
| 12 | walk_loop (hem) | walk_f | 3 | 2 | 3 | 2 | 2 | 12 | Slide 3.1 m. |
| 13 | albert_whirl_v1 (breaker) | LMB hold whirl→slam | 2 | 2 | 3 | 3 | 2 | 12 | Holds the hammer still overhead (0.1 m/s). No circling. |
| 14 | albert_light_v2 (breaker) | LMB tap (lmb_slam) | 2 | 2 | 3 | 3 | 1 | 11 | A club jab, nothing like our overhead slam. |
| 15 | albert_light_v3 (breaker) | LMB tap | 2 | 2 | 3 | 3 | 1 | 11 | Same as v2. |
| 16 | lace_cast_v3 (hem) | hail | 2 | 2 | 3 | 3 | 1 | 11 | A generic cast. Doesn't read as a volley. |
| 17 | albert_light_v1 (breaker) | LMB tap | 2 | 2 | 3 | 2 | 1 | 10 | 6 s long, slides 1.7 m. |
| 18 | albert_idle_v2 (hem) | idle | 2 | 2 | 2 | 3 | 1 | 10 | Albert's idle on Lace. Floats 0.16 m. |
| 19 | lace_dodge_v3 (hem) | roll | 2 | 2 | 2 | 1 | 2 | 9 | Goes underground (feet −0.78 m, body −1.63 m). |

## Improvability: the 3 best moves and the new whirl, cleaned

**What was cleaned**

- Picked for cleanup: #1, #3 and #5. They rank high and the kit has a slot for them. #2 victory was left out because an emote is the least valuable slot.
- The new move is the whirl, Breaker's held-LMB overhead whirl into the slam. The v2 take was cleaned.

**Videos**

- `/home/boki/art-review/uthana-rank-1110/clean_*.mp4` (opened from `index.html`).
- Each shows current in-game | raw | cleaned, looped 3 times, in H.264.

| Move | Cleanup (recipe in `tools/anim/uthana_recipes.json`) | Raw → cleaned | In-game score | Cleaned score |
|---|---|---|---|---|
| Faultline (heavy_v3) | Trimmed 0.85-2.6 s and retimed: rise 0.30 s, hold 0.06 s, snap down 0.06 s, impact at 0.42 s (the kit's windup is 0.4 s), hold on impact 0.13 s. Aimed where the hammer lands. Shield-arm fix. Floor clamp. | Facing fixed. Shield tucked. Lowest bone −0.19 → +0.04 m. Strikes on the same frame as ours. | 19 (4/3/4/4/4) | 18 (4/4/4/3/3) |
| Whirl (whirl_v2, new) | **Hold:** wind-in 0-0.2 s, then a loop from 0.2 to 1.07 s. The loop plays its source forward then back, so the seam is invisible. Orbit IK puts hand.R on a 0.3 m circle 0.3 m above the head, locked to the kit's spin phase. **Slam:** the 3.0-4.0 s sweep, retimed so it strikes at 0.1 s after release. | The circling now reads at the game camera. It comes from the IK, not from Uthana. There's a pop between the hold and the slam, where the game would crossfade. | 19 (4/3/4/4/4) | 15 (3/3/3/3/3) |
| LMB shot (lace light_v3) | **Draw:** 0-1.0 s mapped onto 0-1.15 s (hold_from), then held. **Loose:** a 0.06 s snap at 2.3 s, then settles to 0.43 s. The aim line (hand.R→hand.L) is turned onto our draw clip's aim. The string (bow_s) and arrow are carried on hand.R as in our draw clip. | The arrow aims where ours does. The string sits at the hand. The body stays frontal (Uthana's stance), where ours is side-on. | 20 (4/3/4/5/4) | 15 (3/3/3/3/3) |
| Death (lace death_v3) | 2.2-3.9 s retimed into 1.5 s: hold 0.3 s, then the fall. Floor clamp on body bones only, so the bow tip may dip under the floor. | Lies on the floor (hips 0.22 m) instead of 0.25 m underground. Foot slide 1.5 → 0.1 m. | 19 (4/3/4/4/4) | 18 (4/4/3/4/3) |

### What the pipeline can't fix

- **Foot slide during a move.** There is no foot-lock step. Retiming even makes it faster: the cleaned Faultline slides 1.08 m against 0.89 m raw. A foot-lock IK pass would be the next step if this is ever revisited.
- **Style.** Retiming adds holds and snaps, but the poses stay realistic: no squash, no exaggerated arcs or silhouettes. That is why the style score stays at 3 at best.
- **Missing content.** If the prompt doesn't produce a motion, cleanup can't add it. The whirl's circling and the bow's string action had to come from our own rig.

## The pipeline (`tools/anim/`)

| File | What it does |
|---|---|
| `uthana_clean.gd` (`UthanaClean`) | The cleanup steps, all driven by data, run per frame in this order: warp (trim, retime, hold, snap, cut), yaw, in_place, arm_fix, ik (point or orbit), floor, carry. Bakes rotation tracks for every bone. |
| `uthana_bake.gd` | `godot --headless --path <proj> -s uthana_bake.gd -- --recipes=res://uthana_recipes.json --out=res://out/clean` writes one `.res` per clip. |
| `uthana_recipes.json` | The 6 clips above. |
| `uthana_view.gd` / `.tscn` / `.sh` | Renders the N-panel review at the game camera and prints METRIC lines (foot slide, lowest foot, lowest bone). |
| `uthana_mp4.sh` | `<frames dir> <out.mp4> [loops]`: H.264, yuv420p, faststart. |

**Running it**

- `tools/anim` has a `.gdignore`, so the game never loads these files.
- To run them, copy the scripts and `uthana_recipes.json` into a scratch Godot project, with the rigs and raw GLBs in its `glb/` folder.
  - The rigs are `art/wardens/{breaker,hem}/*.glb`.
  - The raw GLBs are in `art/uthana_pilot/motion/`.
- Use the gl_compatibility renderer, the same setup as the pilot (`docs/UTHANA_PILOT.md`).
