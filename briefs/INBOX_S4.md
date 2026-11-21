# INBOX for S4 (cloud session). ext (the coordinator) posts orders here; check every 30 min.
<!-- briefs-trim pointer -->
> Trimmed 2026-11-06 by briefs-trim: 2 finished/superseded entries moved to briefs/archive/INBOX_S4-2026-11-06.md. Kept here: owner rules and decisions, open owner questions, unmerged READY branches, open assignments and review items, the latest SHIPPED/RELEASED, holds still in force, and the last 12 h. Older archives: briefs/archive/INBOX_S4-*.md
## 2026-11-05 06:35 UTC (ext): OWNER REQUIREMENT: every READY report must include the hero's rows from `briefs/art-refs/FIDELITY_CHECKLIST.md` as a ✅/❌ table with proof screenshots (e.g. Vex's cannon IS her right arm, Ryzz fires PINK lightning from her fingertips). Check your in-flight work against it now.

## 2026-11-05 12:17 UTC (ext): OWNER PLAYTEST: Vex sounds too LIGHT. Make her intimidating
Owner: "Vex doesn't sound very intimidating; her sounds are kind of light for how dangerous she should be." Redo `ext/sfx-vex` (branch `ext/sfx-vex-2`):
- **Minigun (LMB):**
  - A heavy, chunky mechanical roar, not a pea-shooter. A deep low-end thump per shot, a metallic barrel-spin whine underneath, a rising spin-up on press, a spin-down tail on release.
  - Layer: a punchy low transient + mid crack + mechanical rattle + brass casings tinkling.
  - It should feel like a heavy weapon you fear hearing nearby.
- **Grenade (RMB, now fired from the arm-cannon top tube, item 112):** a deep hollow "THUNK" launch + a big bassy explosion with debris and a rumble tail.
- **Her cybernetic body:**
  - Servo whirs and hydraulic hisses on the dash/slide; heavier boot steps with a metal clank (robotic arm + chrome knees).
  - The dash = a hard mechanical burst.
- **Longneedle (E):** a deep charge hum building, then a loud piercing crack/boom on release.
- **Impact:** hits on enemies get a meatier impact sound.
- **Distance:** she should be audible and threatening from range: a distance-filtered low end so you hear her coming.
- **Mix:** louder/heavier relative to the lighter Hunters (still within the bus loudness targets).
- **Other carries:** apply the same "weight" check to the other damage carries (Kael, Grimble's blunderbuss, Breaker's hammer). The owner may say the same; strengthen them where they're thin.
- **Post:** a short A/B note in READY (old vs new).

## 2026-11-05 12:22 UTC (ext): OWNER (playtest): Lisette RMB charge needs a MUCH stronger sound while held (rising tension creak + thread hum), plus a heavy release twang/whoosh. Item 114.4. Same weight check as Vex.

## 2026-11-05 12:24 UTC (ext): OWNER (playtest, item 116.5): Ryzz needs WAY better lightning sounds (a crackling zap per shot, a stack tick, an ult thunder crack) + a distinct bright "reset" zing when her dash resets.

## 2026-11-05 16:05 UTC (ext): OWNER RULE: never stop to ask the owner a question and wait. He is often away. Make the most reasonable call, note it (with the alternative) in your READY/STATUS or EXT_TO_MAIN for review, and keep working. Only an irreversible, risky action (deleting data, force pushes, publishing outside your approved scope) waits, and then you continue with other work meanwhile.

## 2026-11-05 16:10 UTC (ext): OWNER: LOW-SPEND MODE until Fri 06:00 Toronto (the account has ~25% left; S5 + S2 get priority)
Use 1 agent at a time, Sonnet (not Opus), finish only your current in-flight branch(es), push, post READY, then wait. No new big tasks, no full-suite reruns. Full speed resumes Friday on a fresh account.

## 2026-11-05 17:58 UTC ext → all: the SUPERVIVE reference footage is on branch `ext/hero-ref-footage`
The frames behind briefs/hero-ref/*.md (5 fps JPGs; the README maps the folders to our heroes). Fetch only the folders you need (`git checkout origin/ext/hero-ref-footage -- footage/<id>`). Use them for any "like <SV hunter>" note. Don't merge that branch.
