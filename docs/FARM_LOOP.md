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
| Stat gain | a gain should read on the Boki, not only on its card | the number on the card | StatGlint (scripts/home/stat_glint.gd): heal motes in the stat colour + its icon rise over the Boki; gains within 0.5 s merge, none at the cap or asleep; click an icon to open that Boki's Training tab with the risen stats marked old -> new for 2 s; StatMeaning (stat_meaning.gd): a stat's first rise on a save also puts one plain line on the tip strip (Care.STATS "means"), max one a minute, never in a garden game; `--stat-up-vfx-check`, `--stat-up-vfx-shots` |
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

## Water and ridges (owner notes 11-11, ext/farm-water-climb-1111)

Placing by the water (`FarmWater`, numbers in `content/rules/farm_build.json` "water"). Water is any
`layout.water` tile: a pond, a painted river, or the island's own wild pond or stream. The farm has no
well item, so there is nothing to count as a well.

| What | Away from water | Within `reach` of water | Why this number |
|---|---|---|---|
| Crop patch | you water each plot by hand (rain also wets it) | waters and tends itself | (unchanged) |
| Growth while home | 90 s a stage (`Data.WATER_TIME`) | `grow` 1.25: 72 s a stage | +25% is clear on the patch's timer without making hand-watering pointless (tending still gives the bigger harvest) |
| Trough (wooden, woven) | you fill it (Fill it up) | tops itself up from the pantry below half, like a hopper | a trough by the pond is the same trade as the crops: place it well, do less by hand |
| `reach` | | 2 tiles (2 m) from the footprint | close enough that the water visibly sits by the patch; one 2-gem river tile bridges it |

Growth after an expedition stays one stage per run for every patch (by water or not): a stage is
the smallest step there, so +25% has no whole-stage meaning.
Build mode: holding a patch or a plain trough in reach shows a blue water drop and "+growth" (patch) or
"fills itself" (trough) over it. Out of reach it shows nothing (the tutorial's dry-patch line already
says you water it yourself).

**The green blocks.** They were the farm-start island's cliff ridge (`HomeLayout.fs_plan` "cliff", picked
for about 2 in 7 islands for variety): 8 to 12 steps of a curved line two tiles thick, raised 2 terraces
(1.6 m) with grass on top and no props. They were wall tiles (`T_BLOCK`), so the mantle skipped them,
the tools skipped them and the Clear the wild brush refused them ("That's a cliff"). Where the
pocket opener cut a gap, the ridge broke up into short pieces: the "mini walls".
Now (`HomeBuild._apply_wild`): the ridge stays as 1.6 m ground. A running jump tops it: the jump
peaks at 1.57 m and the mantle (`home.gd MANTLE` 1.5 m above your feet) carries you over, and the shared
movement numbers are unchanged. You walk off the top. A Boki walks round it, because raised ground is
solid on the kin grid (`HomeBuild._solid_tile`). A stub that is not part of any 2x2 of ridge is levelled (`_settle_ridge`), because it is too thin to stop on after the climb and was most of the stray bits. The pocket opener still runs with the ridge as a wall, so
no meadow is shut in. The Clear the wild brush (Island tab, 3 gems a tile) levels it for good. Trees and
boulders are unchanged: chopped or mined with the axe and pickaxe.

Checks: `--farm-tutorial-check` (a crop by water grows a stage in 72 s, the same plot away from water
does not; troughs; the preview), `--farm-climb-check` (4 seeded islands with a ridge: every tile is
standable ground, a sample of faces is topped by a running jump, you walk off it, a Boki reaches every
open tile, the brush levels it).

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
