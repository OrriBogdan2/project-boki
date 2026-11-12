# Animation tool shortlist (job 20261111-005144-a6, ext/anim-alt-1111)

## Owner summary

**Keep Uthana as the only paid text-to-motion tool, for deaths, emotes and missing heavies only. Add Meshy as a free-to-us second source. Skip HY-Motion unless the licence is cleared.**

- **Uthana** (GO, narrow): the $17.4 of takes this round produced 3 Albert clips that beat or fill the current set (death 19/25, victory 18/25, a new heavy 16/25). Nothing for Lace. Cost for all 12 hunters: about $14.5 with 1 take per move, about $29 with the usual retakes.
- **Meshy** (GO, backup): text-to-motion over an API, paid from the shared Meshy credit pool, so $0 cash. It is more dynamic than Uthana but slides more (Albert whirl 2.9 m). About 13 credits a clip.
- **HY-Motion 1.0 Lite** (NO-GO for now): cheap (RTX 4090 at $0.89/h, about $0.21 for the whole pilot) and it ran, but its clips were weak. Albert's whirl barely moves, Lace's clips slide 1.1-1.4 m. The Tencent licence also excludes the EU, UK and South Korea.
- **NVIDIA Kimodo** (blocked): the build failed twice and a local wheel build was denied, so it was not piloted.
- **DeepMotion, Replicate** (not piloted): no key on this machine.

Winning clips (MP4, in-game on the left, new on the right): `/home/boki/art-review/anim-alt-1111/`. Tool pilots and rejects are in `evidence/`. Nothing was swapped into a live animation set. READY is posted for the 3 winners only.

## How this was judged

- The same clean pipeline for every tool (`tools/anim/uthana_clean.gd`), the same game camera, the same metrics (planted foot slide in metres, lowest foot, lowest bone), and the same R/W/S/F/St scoring as `docs/UTHANA_RANK.md`.
- Pilot moves, one attack from the real kit and one death on each of Albert (breaker rig) and Lace (hem rig). Albert's attack is the overhead hammer whirl. Lace's is the bow shot.
- Scores come from contact-sheet frames and the metrics. I did not watch every video in full.

## Ranking

| # | Tool | Verdict | Pilot result (new / in-game slide, m) | Cash cost of the pilot | Cost, all 12 hunters |
|---|---|---|---|---|---|
| 1 | Uthana TTM 3.0 | **GO** for deaths, emotes, missing heavies | Albert death 0.058 / 0.075, Albert victory 0.111 / 0.124, Albert heavy 0.46 / 0.28. Lace shot ties the in-game loose (not worth a swap). Lace death 0.20 but sinks 0.17 m. | $17.4 (43 takes, about $0.4042 each) | About $14.5 (3 takes per hunter) to about $29 (with retakes). Plus tuning time per clip. |
| 2 | Meshy text-to-motion | **GO** as backup, deaths and emotes | Albert death 0.57 (body above floor), Albert whirl 2.87 (big motion, too much slide), Lace death 0.30 (feet float 0.18 m), Lace shot 0.24 (feet float 0.11 m). | $0 cash (52 credits from the shared pool of 2517) | About 13 credits a clip, so 36 clips is about 470 credits, still $0 cash. Check that the pool has room for others. |
| 3 | HY-Motion 1.0 Lite (RunPod RTX 4090) | **NO-GO** for now | Albert death 0.11, Albert whirl 0.14 (but nearly static), Lace death 1.39, Lace shot 1.06. | About $0.21 (2 pods, both terminated and checked gone) | About $0.80 of GPU for 36 clips, but the quality and the licence block it. |
| 4 | NVIDIA Kimodo | **NO-GO**, blocked | Not piloted. | $0 | Unknown. |
| 5 | DeepMotion | Not piloted (no key) | - | $0 | - |
| 6 | Replicate-hosted models | Not piloted (no key) | - | $0 | - |

Three tools were piloted on both hunters (Uthana, Meshy, HY-Motion). Kimodo was tried and blocked, and DeepMotion and Replicate need a key the owner has not given.

## Notes per tool

**Uthana**

- 4 s minimum, so short moves (deaths) need a warp trim in the recipe.
- Rig-retargeted GLBs have no root motion, so the clean step pulls the pelvis path from the Tar GLB.
- Albert's clips clean up well. Lace's (hem rig) stagger and slide, whatever the prompt.
- Details and the full clip table: `docs/UTHANA_RANK.md`.

**Meshy**

- Output is a 4 s clip on its own skeleton, retargeted with `tools/anim/retarget_meshy.py`.
- Clips are lively but not grounded. Expect to lean on foot IK and the floor step.

**HY-Motion**

- Ran on one pod for about 11 minutes of GPU time (last pod). Output is a 3.38 s clip on the SMPL skeleton, retargeted to our rigs.
- Motion is small and often stiff. The licence excludes EU/UK/KR, so it is a legal question before it is a quality one.

## Charges

| Item | Amount |
|---|---|
| Uthana, 43 takes this round | about $17.4 |
| RunPod RTX 4090, 2 pods at $0.89/h | about $0.21, both terminated and checked |
| Meshy, 52 credits from the shared pool | $0 cash |
| **Paid-trial total** | **about $0.21 for tool trials**, under the $30 cap. Uthana is the existing account, counted in `docs/UTHANA_RANK.md`. |

## What was reused and where

`tools/anim/`: `uthana_gen.py` (Tar generate + download), `meshy_t2m.py`, `retarget_meshy.py`, `uthana_recipes_alt{,2,3}.json`, `uthana_prompts{,2,3}.tsv`. Data: `art/uthana_alt/` (motion takes and ledgers, Meshy and HY retargets).
