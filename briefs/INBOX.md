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

## 2026-11-02 21:35 UTC
Heads-up only; don't start yet. The owner decided every hunter gets their own ultimate back on **X** (level 6, own cooldown), and landing it charges the Boki bond toward a Merge on R. Ult reference sections are being written into briefs/hero-ref (posted when done). After each kitfix pair is ready, a follow-up ult pass for that pair will be queued (Opus). Until then, don't bind anything to X.

## 2026-11-02 22:05 UTC
The ultimate references are done: every briefs/hero-ref/*.md has a new "Ultimate (on X)" section. Read **briefs/SERVER_UPDATE6.md**. As each kitfix pair reports ready, queue that pair's ult pass (Opus). Don't interrupt the running kit work for it.

## 2026-11-02 22:10 UTC
From the main session. Relay this to every running agent (kitfix ult passes, ext/classes) and put it in queued prompts:
1. **Main is sync66 (Net 0.16.0).** aimkit, kits2-nor, farmbuild and perkorbs are merged. Kit branches re-merge main before reporting.
2. **Ultimates:** main is building branch `ultbond` with `KinBond.from_ult(h, kind)` (kind "hit", "knock" or "kill"; best event per cast; data in rules/boki_system.json `bond_from_ult`) and `ArchKit.cast_ult()` (stub returns false; kits override) on the new `hunter_ult` action (X). Ult passes call these; if ultbond hasn't landed yet, merge origin/ultbond.
3. **NEW RULES (owner):** read docs/STYLE.md and AGENTS.md section 3 "Keep it lean" once they land with branch cdfix. Rules:
   - one statement per line
   - lines of 120 characters or fewer
   - at most one ternary per expression
   - descriptive names
   - comments say why, never history
   - never shadow Godot names (name, position, owner, min, range...)
   - static types, small functions
   - build exactly what was asked, extend before adding, delete what you replace

   `health.py --strict` now runs `tools/style_lint.py` as a ratchet: no file may get worse. After merging main, run `python3 tools/style_lint.py` and clean any file you made worse; `--update` is only for locking in improvements. **Reports must state lines added and removed, plus any new files, assets or settings with the reason for each.** Leave the kit files you touch cleaner than you found them.
4. **Kit review:** an independent Opus review of all six kitfix pairs is running on the local machine. A fix list per hunter will come through INBOX within the hour; hold the kit merges until then. The ult passes can continue.

## 2026-11-02 22:40 UTC: KIT REVIEW, round 1 (first 6 hunters). Polish pass needed before any merge
Independent reviews are in **briefs/kit-review/REVIEW_<name>.md**. The mechanics and aim modes are largely right; the animations and effects mostly don't read at gameplay zoom. Verdicts:
- **Bjorn: REWORK, the visuals only.**
  - The held-LMB hammer spin needs a visible circle with a gold trail and a gold charge ring.
  - The shield needs to be a solid pale-gold slab with its sigil.
  - The slam needs a real 180° flaming crescent.
  - His body must not fall flat during the slam or Smash.
  - The planted hammer stands upright, with a vertical beam.
- **Pin, Dancer, Zedran, Vireo, Venator: PASS WITH FIXES.** Each file has a ranked fix list (and a few after-shots that don't show what they claim).

**Do:** run one Opus polish pass per pair (pin-bjorn, dancer-juggernaut, vireo-venator) on the same branch. If the ult pass on that branch is still running, run the polish right after it finishes; don't run both at once on one branch.
- Fix every item in the review, top-down.
- **Readability rule:** each key pose must be obvious at default gameplay zoom. Use exaggerated anticipation and follow-through, weapon arcs at least as large as the body, and trails, crescents and flashes in the hero's colour.
- Retake every screenshot at both default gameplay zoom and a close-up, and make sure each after-shot shows what its name says.
- Follow the style ratchet.
- Report lines added and removed.

The reviews for the other 3 pairs (linwick-dredge, moosh-tamsin, breah-ostra) follow shortly.

## 2026-11-02 22:55 UTC: KIT REVIEW, round 2 (other 6 hunters). Polish pass needed before any merge
More reviews are in briefs/kit-review/. Verdicts:
- **Moosh Moosh: REWORK.** The weapon hold overrides the moves, so the strips are frozen. The Hearthlight is a flat white "+". The demo captures after each move ends.
- **Tamsin: REWORK.** Ice Spear has no prop or throw pose. The Shatter can't be seen. The darts are tiny white flecks; make them bigger, ice-blue and more curved.
- **Linwick, Dredge, Breah, Ostra: PASS WITH FIXES.** Each has a ranked list. Breah's sizes are about 0.6x the source. Ostra's projectiles can't be seen. Dredge's ghost anchor can't be seen.

Same polish pass as the 22:40 entry: Opus, per pair (linwick-dredge, moosh-tamsin, breah-ostra), after that pair's ult pass, fixing every item top-down.

**Lessons for ALL six polish passes** (relay to the round-1 agents too):
- **Additive blend washes out on bright ground.** Fire, smoke and dark or saturated effects drawn `blend_add` turn beige or white on the grass. Use a mixed or alpha blend pass for colour and darkness, and keep additive only for glow.
- **Don't default to white.** No projectile, area or impact effect stays white; each uses the hero's colour language.
- **The weapon hold must not override a move's pose.** Check km_sample priority so the moves actually play.
- **Screenshot timing:** capture the frame at the moment itself (wind-up, release, impact), not after the move ends. Strips need 4-6 distinct frames, with no hover tooltips.
- **Status words must not overprint each other.** Stack or offset them, for example STUNNED plus GROUNDED. The text must match the real effect: a slow is not "DIZZY".
- **Air dash after-images:** each hero gets its own, not the shared generic pill.
- **Camera:** the air-dash strips end with the camera inside a pink sphere near a dummy. Find out why.

## 2026-11-02 22:35 UTC: owner on Pin's charged shot (relay to the pin-bjorn polish pass)
The owner wants Pin's draw readout to work the way the source does, **but not as a copy**. Match the *behaviour and the information it gives*:
- two lines from the bow converge on the cursor as the draw charges
- they merge into one bright line when a stage is ready
- at full draw the line strengthens and extends past the cursor, to the full shot's range
- a perfect release gives an unmistakable, very brief flash at the bow hand
- the glint only appears when a stage is ready

**Draw every element in Pin's own art direction:** her colour palette, our own line texture and shape language (for example a feathered or fletched line), and our own perfect-flash motif, not a generic four-point star. Don't trace or reproduce the source's sprites or exact shapes; same readability, different look. The draw-back pose and the fully charged arrow and its impact also get distinct, Pin-specific visuals (see REVIEW_pin.md).

## 2026-11-02 22:45 UTC
Owner: the "Hold Shift for the long dash" setting (`dash_hold`) is being removed by the main session. Hold-to-extend dashes are per hunter, only where the source does it (for example Tamsin's Rinkrun). Kit and polish passes must not read `Settings.dash_hold` or depend on it. If a kit branch references it, remove the reference. Relay this to the running kit agents.

## 2026-11-02 22:40 UTC: OWNER on Moosh Moosh (tender). Add to the moosh-tamsin polish pass; high priority
The owner says she "doesn't feel or look like Elluna at all".
1. **Very small.** She becomes a very small hunter. A body/scale/movement study is being written now and will be appended to briefs/hero-ref/mooshmoosh.md as "Body, scale and movement feel", with a target scale factor, collision size, bob and cadence, and the dash curve. Wait for it (about an hour) before tuning scale and movement; start on item 2 now.
2. **No weapon.** Remove the crook/staff prop. She attacks with her hands: casting her shots from the hand or fingertip (a finger-gun or palm cast, like Vireo's new finger gun), with a punch-like push on the cast.
   - Give each hand an alternating cast pose with anticipation, a release snap and recoil, plus a fingertip glow and muzzle burst in her colours.
   - The projectiles and their trails keep her own look.
   - Remove the weapon-hold logic that was freezing her poses (REVIEW_mooshmoosh.md item 1), and make sure the moves drive the arms.
3. **Feel:** light, quick and bouncy; a small support who darts around.
4. **Clean room:** match the source's scale, motion and attack style, but her look stays our own original design. Don't recreate the source character's outfit, hair, colours or silhouette.
