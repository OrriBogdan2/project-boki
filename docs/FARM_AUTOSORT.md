# Farm auto-sort rule table

Code: `Work.autosort()` (scripts/core/work.gd), run each farm scan (once a second at home) from `HomeWork.scan`.

| # | Rule |
|---|---|
| 1 | Only kin the owner never placed are sorted. Any owner assign, unassign, pin or rest sets `rec["work_manual"]`, and auto-sort skips that kin for good. |
| 2 | Skipped as well: kin already at a station, pinned, resting, building at a site, or unable to work (Burrow, mentor, away, starving). |
| 3 | A kin's best position = a station whose element is at the kin's top work level (with mutation, Elder and farmhand bonuses). A level-1 knack never beats a level-3 one. |
| 4 | Stations with slots: Lumber Camp (timber, 2), Quarry (stone, 2), Seed Garden (bloom, 1), Kiln (ember, 1). Only free slots count. |
| 5 | Order: the highest top level picks first (ties: roster order), then the first matching station in layout order. |
| 6 | No fitting station free: the kin stays on the open job board (existing best-suited rule), unchanged. |
| 7 | A station put away frees its crew (not counted as manual); they are sorted again. |

Slots and elements come from `Work.ASSIGN` and the station's `work` field in `HomeLayout.CATALOG`.

Check: `--work-check` (section 10b: right station, owner-placed and resting kin left alone, idempotent, an unassign sticks).
Clip: `jobq submit --needs gpu -- --farm-autosort-clip --clip-dir=autosort_clip` films it on the work demo farm
(`tools/farm_autosort_clip.gd`): nobody placed, then the sort, then an owner's move that the next sort keeps.
