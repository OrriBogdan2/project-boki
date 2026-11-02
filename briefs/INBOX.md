# Inbox for the server coordinator (newest at the bottom)

## 2026-11-02 03:15 UTC
Set up the status channel in SERVER_UPDATE4.md and push STATUS.md now. Then continue SERVER_UPDATE3. When you assemble ext/hero-shots, include for every hero: the kit card, each ability, the payoff, one animation frame strip, and one full-body portrait of the hero standing in neutral pose, so the owner can review the original character designs.

## 2026-11-02 03:20 UTC
Owner granted standing permission to keep every slot busy (goal: maximum speed; weekly usage is low at ~22%). Changes:
1. Raise your cap to 4 sub-agents at once (sonnet).
2. Start `ext/farmbuild` now in the 4th slot, from current origin/main. Spec: section 4 of `git show origin/ext/main-overflow:docs/HANDOFF_main_overflow.md` (farm building pass: unlocks, build mode, Boki-built construction). Follow BRIEF_COMMON, BRIEF_UPDATE4 (reserved Boki files, Net rule: next above main at report time), AGENTS.md and docs/GAMEDEV_CHECKLIST.md; big files stay wiring-only (health.py --strict); add a --farmbuild-check; screenshots go in ext/hero-shots under farmbuild/; full suite once at the end.
3. Queue after kits2-nor: `ext/classes` (section 3 of the same doc: class unlocks + the "class" rename). Start it only once the hero finish passes are pushed, because the rename touches every archetype file; base it on main merged with the finished hero branches if they've landed, otherwise note the expected conflicts.
4. Never idle: whenever a slot frees, check this inbox, then start the next queued item. If the queue is empty, write "queue empty" in STATUS.md.

## 2026-11-02 05:00 UTC
Main is now sync59 (fcc3745, Net.VERSION 0.11.0): mergeforms landed (merge = transformation with per-form kits, R = form ult that separates you, shell health bar, 3.5s rescue cradle). Full notes from the main session: `git show origin/ext/agent-briefs:briefs/MAIN_TO_EXT.md` (read the whole file; it's the main session's log).
1. Every branch you report ready must merge fcc3745 or later first. The four "ready" hero branches (joule-ghost, elluna-celeste, kingpin-felix, tetra-void) need that re-merge, then re-run the suite. Net: branches with new sync events (elluna-celeste "carry", tetra-void "zone") take 0.12.0 and 0.12.1; branches with no new sync keep 0.11.0. Same rule for myth-oath, kits2-nor, farmbuild.
2. Reserved files grew: merge_kit.gd, every merge_*.gd, content/merge_forms/, boki_system.json, capture.json (plus the earlier list). Keep main's side in conflicts.
3. Hero kits with their own hold state (charge, aim, channel): don't keep it across a merge. List each such field per hero in STATUS.md under "Hold state for MergeKit.drop_class_holds"; the main session will extend that function. Channelled actions should use Capture.hunter_stop(h) for interrupts.
4. Raise your cap to 5 sub-agents. New item, start it now in the 5th slot: **ext/economy review fixes** on branch ext/economy (currently d45691d). The 13 items and check gaps are in MAIN_TO_EXT.md under "2026-11-01 23:05 ET: ext/economy review". Fix all three blockers and the should-fixes, add the listed checks to --economy-floor-check, merge fcc3745, full suite, push, report ready in STATUS.md (Net: keep 0.11.0 unless it syncs something new).
5. Owner questions you raised (Tamsin healing; Archer/Bulwark additions): I've passed them to the owner. Until he answers, keep the current design and don't block on it.
6. Merge order the main session wants: feelfix, polish, ext/fixes, rolling, ext/gear, hero pairs as each is ready, ext/farmbuild, kits2-nor, ext/classes, ext/cleanup last.

## 2026-11-02 08:20 UTC
Item 4 of the 05:00 entry (ext/economy review fixes) has been taken by the local machine. Don't start it. Everything else in the 05:00 entry stands. When you resume, push STATUS.md first; it has been silent since 04:20 UTC.

## 2026-11-02 09:50 UTC
Because you've been silent since 04:20 UTC, the local machine has taken over the sync59 re-merge of ext/heroes-joule-ghost, ext/heroes-kingpin-felix, ext/heroes-elluna-celeste and ext/heroes-tetra-void (item 1 of the 05:00 entry, for those four). Don't touch those four branches. You still own: ext/heroes-myth-oath (finish pass + sync59 merge), ext/kits2-nor, ext/farmbuild, ext/classes, ext/hero-shots. When you resume, fetch first: those branches may have moved. Push STATUS.md first.

## 2026-11-02 11:05 UTC
Still silent since 04:20 UTC, so the local machine has also taken ext/heroes-myth-oath (sync59 merge; its finish pass at 94c0df8 is done). Don't touch it. joule-ghost, kingpin-felix, elluna-celeste and tetra-void are re-merged and reported ready (see EXT_TO_MAIN.md). You still own: ext/kits2-nor, ext/farmbuild, ext/classes, ext/hero-shots. When you resume: fetch, push STATUS.md first, then continue those.

## 2026-11-02 11:45 UTC
ext/heroes-myth-oath is done (a2e572e, reported ready). ext/kits2-nor (0650f6f) and ext/farmbuild (b7537bd) look finished on sync59, so the local machine is now verifying them (suite, fixes only, push, report). Don't touch them. You still own ext/classes and ext/hero-shots. When you resume: fetch, push STATUS.md first.

## 2026-11-02 18:10 UTC
New priority work from the owner: **briefs/SERVER_UPDATE5.md** (hero kits to match their sources, Opus 5.5 at medium effort, reference sheets in briefs/hero-ref/). Start ext/aimkit now, then the six kit agents.
Also, in parallel, use Sonnet for these: re-merge ext/kits2-nor (cb588ab) and ext/farmbuild (b7537bd) onto current origin/main (4f82978 or newer).
- kits2-nor: Net goes above main (0.13.x, so 0.14.3 to avoid ext/equal's 0.14.0-0.14.2).
- farmbuild: keep main's version.
- Full suite, push, report in STATUS.md.
ext/classes: base it on current main (it has all heroes). The renames in SERVER_UPDATE5 change display names only; if classes touches the same strings, use the new names.
Keep pushing STATUS.md on every agent start and finish.

## 2026-11-02 18:25 UTC
Corrections to my 18:10 entry:
- kits2-nor Net is **0.15.0**, as the main session asked (sync61 is already 0.14.0).
- Re-merge kits2-nor and farmbuild onto **sync62** (current main).
- SERVER_UPDATE5 now ends with "OWNER PLAYTEST NOTES". They override the footage where they differ, notably: Bjorn spins the hammer while LMB is held, Juggernaut's RMB hold flings you far, and Ostra's RMB has 1 charge and stuns. Re-read the file before starting the kit agents.

## 2026-11-02 18:50 UTC
New section at the end of SERVER_UPDATE5.md: **"OWNER, 13:46 ET: custom, noticeable animations for every ability and every dash"**. Relay it now to the three kit agents already running (dancer-juggernaut, pin-bjorn, vireo-venator) with SendMessage, and include it in the prompts for the three queued ones.

## 2026-11-02 19:06 UTC
Watcher test. When this reaches you, add the line `Watcher: received 19:06 UTC entry` to STATUS.md and push it. Nothing else changes.

## 2026-11-02 19:10 UTC: OWNER ANSWERS (relay to the running kit agents now)
**ext/classes** (reopen it; it isn't ready until these are in):
- Starting hunters: the player picks 1 hunter at character creation, and the next 2 unlocks come early (exact goal numbers to follow from the owner; until then, early, cheap goals).
- Terminology: they're **Hunters**, not heroes or classes. "Hunter unlock", the "Hunters" hub, and so on, everywhere player-facing.
- Drop the Light/Medium/Heavy labels from the UI.
- Build a much better **hunter viewer**:
  - a large rotating model per hunter
  - their abilities shown one by one, each with its key and a short animated preview or loop of the move
  - the plain-words card from the L picker
- **Hold to unlock:** hold a button, a bar slides and fills, the hunter animates (powering up), then a reveal burst.
- Use Opus 5.5 at medium effort for this rework.

**Kit agents** (SendMessage to the running ones; put it in the queued prompts):
- **juggernaut:** display name is **Zed** (owner). It goes in kitfix-dancer-juggernaut's rename.
- **dredge:** the grab goes through rocks and drags the target over them, like the original (owner). This overrides our doc's stop-at-walls.
- **pin:** Shift is the newer source behaviour (dodge roll, then walk through walls). Confirmed.
- **tamsin:** copy the base hero exactly: ice control and walls, no added healing. Confirmed.
- **dancer:** owner, "the only one that is very different is thief right now". Rebuild it as its source:
  - LMB is ranged, alternating-hand bolts that land at the cursor (ours is melee)
  - RMB is the bolas, done right
  - E is already correct
  Priority 1 in kitfix-dancer-juggernaut.

## 2026-11-02 19:15 UTC
New section at the end of SERVER_UPDATE5.md: **"OWNER, 14:07 ET: the small mechanics must transfer too"**. Example: Brall's tether can be steered sideways while pulling in. Relay it to every running kit agent now, and put it in the queued prompts.

## 2026-11-02 19:12 UTC
Name change from the owner: juggernaut's display name is **Zedran**, not Zed. Relay it to kitfix-dancer-juggernaut and ext/classes.

## 2026-11-02 20:05 UTC
From the main session (MAIN_TO_EXT, 14:30 ET):
- Main is now **sync64 (61e6041)**. Every kitfix branch must re-merge sync64 before it reports ready; hunter.gd and match.gd changed.
- sync63 changed the merge: KinMerge.cast calls `ak._drop_holds()` directly, so kits only need to implement `_drop_holds()`.
- sync64 adds `Match.shot_from_above_ok`, a fix for shooting from higher ground. Keep every kit shot going through `spawn_shot` so it applies. `--shot-vertical-check` must pass. Don't add a separate height fix in aimkit.
Relay this to the running kit agents and put it in the queued prompts. ext/aimkit: re-merge sync64 and re-report.

## 2026-11-02 21:30 UTC
For every kitfix agent: quiet level growth (ext/perkorbs, LevelGrowth) raises ability power through `ArchKit.power()` / `Effects._power`. Kit code that reads `m.dmg_mult(h)` directly for ability damage won't grow, so switch those reads to `power()` in the kit files you own. Relay this to the running kit agents.
