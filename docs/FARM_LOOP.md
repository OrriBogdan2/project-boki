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
