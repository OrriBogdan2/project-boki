# S2 status (second server session)
Updated: 2026-11-03 08:50 UTC. Last INBOX_S2 entry handled: 08:10 UTC (mantle look).

## Infra
- Godot queue: wrapper default is nproc-2 = 14 slots (already >= 8), left as is. S1: no change needed.
- Agents (6 max per 07:30): ALL hero agents on Opus 5.5 medium per 08:00 (the Sonnet Breah/Ostra/Tamsin+Dredge agents were stopped at ~08:15 and replaced by Opus agents continuing from their commits), Breah, Ostra, Tamsin+Dredge, Zedran 21/22/35 (Opus 5.5 medium per owner), prologue-polish (Opus 5.5 medium, allowed by 07:45), dash-flow base (Opus 5.5 medium: shared core movement/combat helper for item 32 that all 12 heroes and both sessions build on; a mistake there multiplies).
- Source data copy: /home/boki/briefs-s2/briefs (from ext/agent-briefs).

## Item 32 shared base (for S1 too): PUSHED, ext/dash-flow-base @ d4182fa (on main 801bfbf), full suite running
- One helper `scripts/arch/dash_flow.gd` (DashFlow) + one data file per hero `content/dash_flow/<hero>.json` + generated `docs/heroes/dash_interactions.md` (gen_wiki) + `--dash-flow-check` (iterates every hero x slot x ground/air from the data, so new rows are covered automatically). Decision doc docs/decisions/0010.
- Row: `{"mode": "fire"|"buffer"|"cancel", "carry": bool, "variant": str, "source": "text"}` under `dash.ground|air.<lmb|rmb|e|x|q>`; missing row = buffer; reverse direction under `into_dash.<slot>`; `kit_owns` lists dashes the kit runs itself (Ostra swap, Tamsin Rink Run, Breah leap).
- Behaviour today is unchanged except presses that were LOST during a dash now buffer to the dash end (e.g. LMB taps for every hero but Venator, Vireo X, Zedran early air RMB). Wiring: hunter.gd +1, hunter_keys.gd +2, arch_kit.gd +4.
- **S1: for Pin/Vireo/Venator rows, merge ext/dash-flow-base and edit only `content/dash_flow/<your hero>.json` (+ kit only to override `in_dash()`/read rows), then rerun gen_wiki; the generated table conflicts resolve by regenerating.**
- Owner Qs: (1) buffer = held to the dash end, never expiring; 0.15 s is only the extra wait after the dash while busy (a literal 0.15 s expiry would drop presses in longer dashes). OK? (2) some kits add their own recovery after the dash, so a buffered LMB fires 0.2-0.7 s after (Zedran, Bjorn, Breah): make those cancellable per row?

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

## Pair 4: Linwick + Moosh Moosh
- Branch `ext/review-linwick-moosh` at 133a25c (same base as pair 3: main + both kitdata). In progress (Opus): Linwick 11, 19, 20, 35; Moosh Moosh 23, 24, 35.

## Dancer (taken from S1's queue per INBOX_S2 07:30: S1 lists ext/fix-dancer as queued, not started). **S1: please leave Dancer #8 + rows to S2.** Pin, Vireo, Venator stay with S1 (in progress).

## Prologue polish
- Branch `ext/prologue-polish` from origin/ext/prologue5 54f8304. In progress (Opus): framing/camera/animation/lighting per slide, THE BOKI clipping fix, slide 3/4 text per 07:50, slide 4 Mantle-wake staging.

## Queued new tasks (INBOX 07:55, 08:10)
- Character concept pass phase 1 (`ext/concepts`, Opus): starts when a slot frees after the demo-critical branches; not for tonight.
- Mantle look + creator (item 45, `ext/mantle-look`, Opus): after the hero pairs and prologue are underway; not for tonight.
