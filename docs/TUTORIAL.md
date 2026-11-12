# Match tutorial: steps and hints audit (origin/main fb360f614, 2026-11-12)

Owner decision 2026-11-08: the match tutorial is about 8 steps (land+move, dash+glide, shoot, E, send your Boki, a fight,
open a chest, extract); everything else is a one-line hint the first time it matters.

## 1. Step count: the cut is NOT on main

`content/rules/tutorial.json` has **23 steps** (ids 0-22). A bot-driven run per starter (`--tutorial-fight-check`, Lace/archer,
Kael/juggernaut, Vex/gunslinger) visits all 23 for each, so the count is **23 / 23 / 23** (`gkey` is the only step a kit can skip,
and only without a Boki).

`land, points, pick_sec, sec, shoot, pick_dash, dash, exdash, glide, wallkick, crouch, gkey, pick_kin, kin, glove, hook,
pick_ult, ult, ranks, wayout, uplink, defend, extract`

The 22 -> 8 cut (decision 0023, `37dc18d84`) exists only on `origin/ext/tutorials-cut` (2026-11-08, ~1550 commits off main,
pre-run-levels, pre-Ways Out). It was never merged; main grew its own ability-point course instead (pick steps, one camp per
ability, then Ways Out steps). Nothing on main "crept back": the cut never arrived. It cannot be merged or cherry-picked as is;
it needs a port to the run-levels course (TutorialCamps, TutorialDrive, Ways Out steps) and 6 checks that pin the step ids
(`--tutorial-fight-check`, `-clean-check`, `-hud-check`, `-idle-check`, `--new-player-flow-check`, `--kit-drill-check`,
teammate/drop-feel rows). Mapping of the 23 to the 8: land+move = `land`; dash+glide = `dash, exdash, glide`; shoot = `shoot`;
E = `kin`; send your Boki = `gkey`; a fight = `sec, ult, hook`; chest = none (no chest step; the first-match guide has one);
extract = `wayout, uplink, defend, extract`. Cut to hints: `points, pick_*, ranks, wallkick, crouch, glove`.

## 2. Hints on main and when they fire

Match tips (`Match._tips`, once per save in `Save.d.tutorial`, not in the tutorial, not with tips off):
| key | fires |
|---|---|
| move | 1 s after landing: shoot, dash, glide keys |
| ability | 14 s in: Boki key / signature, fuse key |
| ult | bond full and the Boki has a fusion |
| throw | a rival within 9 m and the Boki is out |
| skill | the Boki is active: stun then shoot combo |
| catch | the interact prompt is a scan |
| exit_uplink | the interact prompt kind is `exit` (an outpost only) |
| down | you are downed |
| rings | within 9 m of an air ring |
| stagger | first staggerable monster |

First-match guide (`FirstMatchGuide`, first 2 Extractions): land, chest, rank, send, squad, blight, exit.
Hub: `HubHints`. Farm: `FarmKeyHints` and the farm tutorial.

## 3. Gaps (hints that never fire, or say the old thing)

- **Ways Out:** `exit_uplink` and the guide's `exit` line ("Go to an exit and hold F to leave") only know outposts
  (`Exits.spots()`, kind `outpost`). Heart, Lair, quest and final-seat ways out never trigger either, so "extract now means
  Heart/quest exits" is not told anywhere. Branches with the fix: `ext/tut-first-ways-out`, `ext/tut-heart-raid-hints`.
- **Mini-rockets:** no hint on main; `ext/tut-rocket-hint`.
- **Stomps:** no hint on main; `ext/tut-stomp-hints`.
- **Closing zone:** the guide's `blight` line fires at 40% left; no "get inside the circle" line on main; `ext/tut-first-zone`.
- **Hot zone / Waystone:** `ext/tut-hot-zone-line`, `ext/tut-waystone-hint`.
- Also open on main: `--new-player-flow-check` stalls at the `glove` step (900 s, 2 FAIL rows), see DEBT.

Not changed here: porting the cut is a core change to the tutorial and its checks and collides with the open `ext/tut-*`
branches above, so it needs the owner's order (merge those hint branches first, then cut the course).
