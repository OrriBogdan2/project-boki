# The raising loop: ours vs the design (ext/farm-loop, 2026-11-09)

Source: briefs/DECISIONS.md (owner 11-08, 11-09) and briefs/design/GARDEN.md (draft, waiting for
owner approval) on ext/agent-briefs. The genre research (CHAO_RESEARCH.md) gives no numbers we may
copy, so every new number below is tied to one already in the code. [?] = the source has no value.

| Loop step | Source says | Before | After (this branch) |
|---|---|---|---|
| Neglect | never kills: `natural_death: false` (DECISIONS 11-08) | died after 72 h unfed (day 4) | sick at worst; clock capped at 72 h; meals bring it back (content/rules/care.json) |
| Bond from care | petting, favourite food, playing raise trust (GARDEN 3.3) | once per expedition: a stay-home Boki stopped at ~+5 | once a farm day per kind (care_day_s 300 = DAY_LEN) [?]; a week of farm days reaches Close |
| Play | play trains a stat (GARDEN 3.2) | fetch: joy only | fetch +1 Speed while energy >= 35 (the Training post's tired line) [?] |
| Food | changes look within 1-2 feedings (GARDEN 3.1) | affinity +6, nothing visible before level 4 | lean tint up to 0.3 (forms 0.1 each), 2 meals = 62%, last meals decide [?] |
| Bond rank | readable rules, trust is the long meter (GARDEN 2-3) | ranks changed silently | rank-up moment: heart, line, card with the perk and the next rank |
| Coming home | a ritual, not a chore (GARDEN 2) | Boki stayed where they spawned | after 2+ min away they run over and say hello, most trusted first [?] |
| Stat gain | a gain should read on the Boki, not only on its card | the number on the card | StatGlint (scripts/home/stat_glint.gd): heal motes in the stat colour + its icon rise over the Boki; gains within 0.5 s merge, none at the cap or asleep; `--stat-up-vfx-check`, `--stat-up-vfx-shots` |
| Into expeditions | raised Boki are better partners (GARDEN 2) | match_mods applied, never shown | one line on the expedition panel: what care does for the run |

Checks: `--raising-check` (new, all of the above but neglect), `--economy-check` (neglect).

## Not done here (next, in the brief's order)
- Leans on the 18 types instead of the 4 affinities: waits for GARDEN.md open question 2 and the
  unmerged type registry (ext/game-rules-nov8).
- Base life state machine with friends and rivals, playthings, the Dash race, base_mode cut, Nook
  preview, the away card with a journal (GARDEN 9.2-9.8).
- Levels without expeditions: a home-only Boki stays level 1, so trained stats cap at 18. The brief
  gives no XP source at home [?]; needs an owner call.
- Not verified: whether other players' clients see the meal tint (it rides on the kin record;
  nothing was added to the Net sync shape, so Net.VERSION is unchanged).

## Placed blocks are climbable (owner, 11-11: "all farm blocks are climbable")
Every solid thing you place (walls, fences, hedges, crates, benches, trees, statues, stations, buildings) stands
you at a low top, not at a 3 m wall: `HomeLayout.CLIMB_TOP` 1.2 m, or a catalog `"top"` for a low item (bench, tub,
warm stone: 0.5 m). `HomeBuild._apply_blockers` writes it into `World.block_top`; `ground_at` and the block
collision read it, so the farm's one jump-and-mantle (`Home._mantle`, reach 1.5 m) climbs it and you walk off the
edge back down. No second climbing system. A Boki stays on the ground: it walks round blocks on the same tile
grid (`HomeBuild.refresh_grid` after every placement); one set down on a block (dropped from up there, or there
when the layout changes) is stepped off by `HomeCarry.drop` / `Home.unstick`, and you are not pushed off a block you
climbed. The wild trees and rocks of the meadow stay 3 m walls. Check: `--farm-climb-blocks-check`. Not built: Boki
walking onto blocks (Boki have no height on the farm; say so if you want it).
