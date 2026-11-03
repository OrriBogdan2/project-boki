# S2 status (second server session)
Updated: 2026-11-03 08:05 UTC. Last INBOX_S2 entry handled: 07:50 UTC (prologue text).

## Infra
- Godot queue: wrapper default is nproc-2 = 14 slots (already >= 8), left as is. S1: no change needed.
- Agents (6 max per 07:30): Breah (Sonnet), Ostra (Sonnet), Tamsin+Dredge (Sonnet), Zedran 21/22/35 (Opus 5.5 medium per owner), prologue-polish (Opus 5.5 medium, allowed by 07:45), dash-flow base (Opus 5.5 medium: shared core movement/combat helper for item 32 that all 12 heroes and both sessions build on; a mistake there multiplies).
- Source data copy: /home/boki/briefs-s2/briefs (from ext/agent-briefs).

## Item 32 shared base (for S1 too)
- Branch `ext/dash-flow-base` (from origin/main 801bfbf): one helper + per-hero data rows + generated docs/heroes/dash_interactions.md + `--dash-flow-check`. **S1: please don't build a second dash->ability helper; build your Pin/Venator/Vireo/Dancer rows on this branch once it's pushed (I'll note the API and the per-hero files to edit here).**

## Pair 1: Breah + Ostra
- Branch `ext/review-breah-ostra` = origin/main 801bfbf + ext/kitdata-breah-ostra d0d045e (merged first, since item 14 asks to build on it; style baseline + wiki from main, regenerated). Ostra work on a local sub-branch, merged back before push.
- In progress: Breah 26 (first), 14, 15, 25, 35; Ostra 42 (first), 17, 16, 40, 18 (concept note only), 35. Item 32 rows after the base lands.
- Screenshots: /home/boki/shots-s2/{breah,ostra}/review/ (to be pushed to ext/hero-shots-s2).

## Pair 2: Zedran + Bjorn
- Branch `ext/review-zedran-bjorn` from origin/main 801bfbf. Zedran 21, 22, 35 in progress (Opus).
- Bjorn 10/29/30: S1 started them on ext/kitdata-pin-bjorn; S2 builds Bjorn's 32/35 rows on top once S1 pushes.

## Pair 3: Tamsin + Dredge
- Branch `ext/review-tamsin-dredge` = origin/main + ext/kitdata-moosh-tamsin + ext/kitdata-linwick-dredge (both unmerged kit data passes; merge notes: hero_zones.gd bridge() kept main's formatting + kitdata's colour arg; ashwick.json took kitdata's RMB row, which drops main's `refund: 0.25` on Cinder Shot (kitdata removed it per data), wiki regenerated). Health OK.
- In progress: Tamsin 12, 13+28, 27, 35; Dredge 33, 36, 35, then 31 (shares the `CastHold` helper with Ostra 17; one copy, cherry-picked).

## Pair 4: Linwick + Moosh Moosh — queued (will branch from ext/review-tamsin-dredge's base, which already has their kit data)

## Dancer (taken from S1's queue per INBOX_S2 07:30: S1 lists ext/fix-dancer as queued, not started). **S1: please leave Dancer #8 + rows to S2.** Pin, Vireo, Venator stay with S1 (in progress).

## Prologue polish
- Branch `ext/prologue-polish` from origin/ext/prologue5 54f8304. In progress (Opus): framing/camera/animation/lighting per slide, THE BOKI clipping fix, slide 3/4 text per 07:50, slide 4 Mantle-wake staging.
