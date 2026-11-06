# Inbox for the server coordinator (newest at the bottom)
<!-- briefs-trim pointer -->
> Trimmed 2026-11-06 by briefs-trim: 32 finished/superseded entries moved to briefs/archive/INBOX-2026-11-06.md. Kept here: owner rules and decisions, open owner questions, unmerged READY branches, open assignments and review items, the latest SHIPPED/RELEASED, holds still in force, and the last 12 h. Older archives: briefs/archive/INBOX-*.md
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

## 2026-11-02 21:35 UTC
Heads-up only; don't start yet. The owner decided every hunter gets their own ultimate back on **X** (level 6, own cooldown), and landing it charges the Boki bond toward a Merge on R. Ult reference sections are being written into briefs/hero-ref (posted when done). After each kitfix pair is ready, a follow-up ult pass for that pair will be queued (Opus). Until then, don't bind anything to X.

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

## 2026-11-02 22:50 UTC
Owner direction for every kit and polish pass: the **kits** match the source as the baseline (mechanics, timing, aiming, movement). The **characters** will be redesigned as clearly original concepts later; Moosh Moosh, for example, may become a small fire fox. So in the current passes, keep the effects in each hunter's own colour language, and don't invest in body details that copy the source's look. Concentrate on motion, readability and the kit.

## 2026-11-02 23:00 UTC
briefs/hero-ref/mooshmoosh.md now ends with "Body, scale and movement feel". Build it in the moosh-tamsin polish pass:
- **Scale:** 0.74 of a medium, and drop the tall pack-frame or lantern above her head. `hit_r` 0.40 → 0.34. Nameplate offset about 2.05 m for others.
- **Movement:** a low, forward-leaning scurry at about 1.25× step cadence, ±5% bob, a trailing piece that swings with the stride, quick starts and stops, and the torso facing the cursor when strafing.
- **Attacks:** no weapon. A straight-arm punch-push cast with alternating hands: 0.07 s wind-up, thrust, a hold of about 0.1 s, and a ±45° torso twist. The RMB release has a small hop.
- **Ground dash:** keep 4.2 m in 0.16 s, plus a small hop.
- **Air dash:** a long, floaty glide (a head-first streak, then a tucked float, then a soft landing). Start at about 8–9 m over about 0.8 s. The owner decides whether to go up to the source's 11–15 m; data-driven, so it's easy to change.
The other 11 hunters' body sections follow within the hour.

## 2026-11-02 23:20 UTC
Body, scale and movement sections are in for **linwick, dredge, tamsin, breah, ostra** (end of each briefs/hero-ref/<name>.md). Fold them into each pair's polish pass:
- **linwick:** smaller (×0.76) and round. His bash is a front-loaded ~3.4 m over 0.33 s that bounces back on a hit, not 4.4 m at 17 m/s. Quicker steps.
- **dredge:** keep his height but make him ~1.3× wider. His dash is a near-blink, ~4.6 m in ~0.12 s with a burst where it starts and a camera that catches up after it. Our 0.34 s is 3× too slow. (Main tuned that barge on purpose, so flag the change in your report.)
- **tamsin:** tall and thin (1.1–1.15 height, ~0.75 bulk), with the light hitbox kept. Skate at 10–11 m/s for 1.6–2.0 s, reaching full speed in ~0.2 s. The kitfix branch's 8 m/s for 2.4 s is wrong; match main's 11.5 m/s for 1.6 s.
- **breah:** ~1.2× wider (big forearms and fists). Landslide is a heavier, longer push: rock goes up first, ~2.5–3 body heights over ~0.45 s.
- **ostra:** no step cycle. A ~0.3 m hover-glide at ~4.1 m/s with a trailing hem; body ~0.9. Keep the hitbox at ground level.
Not in the footage: air dashes, plain jumps and idle loops for these five. Use each hunter's character to build them, and list them as assumptions.

## 2026-11-02 23:40 UTC: OWNER DASH NOTES. These override the reference sheets; relay them to the linwick-dredge, moosh-tamsin and breah-ostra polish passes
- **Linwick:**
  - On the ground: a quick, short dash.
  - In the air: a long, fast "poof" burst that launches him far at high speed. Give it a puff/smoke-burst tell in his colours, keep the momentum after the burst, and give it a distinct air pose.
- **Dredge:** several short, fast dashes in a row (charges with a short gap between them), each a quick visible burst. NOT a blink: you see him travel, just fast.
- **Tamsin, the skating dash** (the owner's favourite):
  - She skates while holding Shift and can keep firing her LMB auto-attack the whole time.
  - She steers the skate (manipulating the ice): she can curve, it isn't just straight.
  - The shorter she skates, the more cooldown she gets back.
  - Make all three feel great. The skate should feel smooth and in control, with a visible ice trail and edge spray when turning.
- **Breah:** the source's dash is an odd dash followed by a rock thrown at you. The owner prefers a **leap**: she leaps to the target area and the rock comes with or after it. An impact on landing plus the rock hitting reads better. Build it as a leap (arc, a clear take-off and landing, the landing hit plus the rock), and record it in docs/heroes/dolm.md as a deliberate change from the source.
- **Ostra, the swap dash:**
  1. Pick a target area (a circle at the cursor, with a landing marker).
  2. While it's being thrown, **Ostra hovers in place in the air**, even over the abyss. He doesn't fall while the swap is in flight.
  3. After a few seconds (about 1.8–2 s per the sheet), **everything inside the target circle (enemies, allies, Boki, and items if it makes sense) swaps to where Ostra was, and Ostra goes to the target.**
  4. Mark both ends clearly during the wait: the origin and the destination circle.
  5. Bots and online play must handle the multi-unit swap. Assert it: two units in the circle both end up at the origin, and Ostra keeps his height over the abyss.

## 2026-11-03 00:15 UTC: from the main session (MAIN_TO_EXT 17:55–19:05 ET). Relay to every running agent
1. **KEYBINDS (final, owner):** R = reload (everyone), **X = hunter ultimate**, **T = Merge** (T again releases), G = the single Boki button, C freed.
   - This replaces "Merge on R" in SERVER_UPDATE6.
   - Kits implement `ArchKit.cast_ult()` and call `KinBond.from_ult(h, kind)` when it connects, unlocking at level 6.
   - **Never hard-code key letters in player-facing text.** Use `Settings.key_cap(action)` with the actions `reload`, `hunter_ult` and `ultimate` (Merge). Fix any "R" or "X" text in kit cards, toasts or tutorials on your branches.
2. **Dashes (sync68–69):**
   - Plain-dash Shifts use `ArchKit.dash_dir()`. Aimed moves (grapple, blink, swap, shield charge) keep the cursor.
   - `content/rules/dash_feel.json` scales every `ArchKit.travel` dash by ×0.85 distance and ×1.15 time on top of the kit numbers. Keep the footage numbers in the kit JSON. Any dash preview drawn from `dist` must apply the same multiplier.
   - Vireo is the exception: her distance isn't scaled, and Wirerun is 5–8.5 m (main's mage.json). Carry that into kitfix-vireo-venator.
   - `--dash-dir-check` must pass.
   - The owner's own dash notes (23:40 UTC) still set each hunter's dash shape; the dash_feel multiplier applies on top.
3. **Farm build flow (owner, 19:05 ET; for the ext/farmbuild owner, which is you):**
   - B opens on the Buildings tab.
   - A builder NPC (our own name) gives building access: a small starter set first (feeder, pen, crop patch), then the next few as farm level and milestones are met, each with a short dialogue line.
   - Locked items are **hidden**, not greyed out. Keep the sections (buildings, pens and feeding, crops, decor…) but show only what's available now. An empty section shows "Talk to <builder> for more" or stays hidden.
   - A new save starts with only a handful of items.
   - **Post a short plan to EXT_TO_MAIN first** (builder name, starter set, unlock order) for the owner to confirm before building.
4. **ext/classes 854258a:** reported ready. It goes to main once the owner answers its questions.

## 2026-11-03 01:55 UTC: OWNER ANSWERS for ext/classes (Hunters unlock). Reopen it and rework (Opus)
- **Starter pool: 4 hunters**, our names: **Zedran** (juggernaut), **Venator** (gunslinger), **Pin** (archer) and **Linwick** (ashwick).
- **At character creation the player picks 2 of those 4.** This replaces "pick 1 plus 2 early free picks".
- **Every other hunter unlocks through challenges:** the 2 starters not picked, plus Dancer, Bjorn, Vireo, Dredge, Tamsin, Moosh Moosh, Breah and Ostra.
  - **Ostra, Moosh Moosh and Breah must never be pickable at creation.** They're challenge-only.
  - Give each hunter **one challenge themed on its kit**, short and readable. Example for a heavy brawler: "Knock 5 rivals into walls."
  - Tier them: the 2 unpicked starters easy (within 1–2 matches), most hunters medium, and Ostra, Moosh Moosh and Breah the hardest or last.
  - Show progress in the Hunter viewer. Completing a challenge unlocks the hold-to-unlock.
  - Put all challenge definitions in content data.
- **Post the challenge list in STATUS.md** (one line per hunter: challenge, tier, target number) for the owner to tune. Build it with those values now; the numbers are placeholders until he confirms.
- **Other open questions, decided by default:** keep a level and goals per hunter; the 1.6 s hold is fine. "Weight class" in merge_forms text is reserved, so tell the main session; rename the arena's "Heavy dummy" to "Training dummy".
- **Save migration:** existing saves keep every hunter they've already unlocked or played.
- Re-merge main, run the full suite, and update --hunter-unlock-check: 2 picks from exactly 4, challenge-only hunters can't be picked at creation, challenge progress unlocks.

## 2026-11-03 02:00 UTC: MORE OWNER ANSWERS for ext/classes (add to the rework)
1. **Playing a hunter longer never gives power.** Per-hunter levels and goals reward **cosmetics only**: skins, colourways, emotes, titles, banners, trails and glider designs. Remove any stat, ability or perk reward from hunter progression. Assert it in --hunter-unlock-check: no reward in the progression data changes stats or abilities.
2. **Gliders are unlockable content.** Glider designs are cosmetic. Each changes the glider's look, trail and sound, never its handling or stats (the glide numbers are in main's movement rules). Unlock them through hunter mastery milestones and some account-wide challenges. Use our own original designs: leaf, kite, paper crane, cloth wing, Boki-themed wings, and so on. Add a glider pick to the loadout or Hunter viewer.
3. **Better goals.** Challenges should be feats that teach and show off the kit, not grinds. Rules for the list:
   - **Skill feats tied to the kit,** for example:
     - "Pin a rival to a wall with a fully drawn shot."
     - "Hit 3 rivals with one Faultline."
     - "Swap an enemy squad into the abyss."
     - "Revive a teammate while carrying them."
   - **Mix the types:** kit feats, team play (revives, assists, saving a Boki), exploration (open N locked chests, find a Shrubling), extraction (extract with N items, survive a close extraction), and Boki goals (merge, then win the fight).
   - **Keep them short:** completable within 1-3 matches for easy, a handful for medium, and real effort but never grindy for the hard ones. No "play 50 matches".
   - **Every goal measurable** from events we already track, or add the event.
   - **Readable in one line,** with a progress counter.
   - **Post the proposed list in STATUS.md** (per hunter: unlock challenge, then 3-5 mastery goals with their cosmetic rewards) for the owner, and build with those values.

## 2026-11-03 02:05 UTC
Owner: **Merge moves to C** (it was T). Final layout: R reload, X hunter ult, C Merge, G Boki button, T free. The main session changes the default. Kits and UI keep using `Settings.key_cap("ultimate")`; never hard-code C or T. Relay this to the running agents.

## 2026-11-03 02:20 UTC: owner answers
- **moosh-tamsin:** Moosh Moosh's air glide goes to the **source distance, about 11–15 m (start at 12 m)**. The owner's rule is "go to the source where possible". Data only; update the check bound.
- **General rule for every kit pass:** where a number or behaviour is an open call, go to the source.

## 2026-11-03 02:45 UTC: MODEL SWITCH (owner: usage at 75% this week)
The video-understanding work is done: every reference sheet is written. From now on:
- **Let running Opus agents finish**: the round-2 fix passes, breah-ostra polish and the ext/classes rework. Don't restart them, since that would waste what's already spent.
- **Every new agent you start uses Sonnet**, including further kit fix rounds, re-merges, test runs and ult tweaks. The reference sheets and review fix lists are concrete enough for Sonnet.
- Exception: if a fix is mainly about judging art against the source footage and Sonnet fails it twice, report it in STATUS.md instead of escalating it yourself.
- **Run fewer redundant full suites.** Run the targeted checks plus one full suite at the end of each branch.

## 2026-11-03 04:25 UTC: OWNER: Venator first for everyone, then pick 1 of 3 (rework ext/classes, Sonnet)
- **New saves start with Venator**, who is also the tutorial hunter.
- **Character creation:** pick **1 of 3**: Zedran, Pin or Linwick. This replaces "pick 2 of 4".
- **Challenge unlocks stay:** the 2 unpicked starters are easy, most are medium, and Ostra, Moosh Moosh and Breah are hardest and never offered at creation.
- **Update:** the creation screen, the Hunter viewer copy, the save migration (existing saves keep everything they have), and --hunter-unlock-check:
  - Venator is always owned
  - exactly 1 pick from those 3
  - challenge-only hunters can't be picked
- **Use Sonnet**, push, and report ready in STATUS.md with the final challenge list.

## 2026-11-03 04:30 UTC: OWNER: shorten the new-game flow (add to the ext/classes rework, Sonnet)
The owner hates the three screens between the intro animation and picking your egg. New flow for a brand-new save:
1. **Intro animation:** keep it as is for now.
2. **One card, straight after it.** Something like: "Every new adventurer picks a Boki to take into battle." Keep it short, in our own words, with one button or the Enter key.
3. **The egg pick.**
4. **The hunter pick:** Venator is already yours; choose 1 of Zedran, Pin or Linwick. Fold this into the same flow rather than a separate menu later.
5. **Into the farm or the tutorial**, as main's flow already does.

Delete the three in-between screens and their text; don't just skip them. Any information they carried that's genuinely needed (name entry, for example) folds into one of the remaining steps or moves to later, as a tip or a settings entry. Say what you moved. The new-game flow files may be partly the main session's (home/story). If a file is reserved or clearly theirs, write the change up in STATUS.md instead. Add an assertion to --hunter-unlock-check, or a new --newgame-check: a new save reaches the egg pick within 2 screens after the intro.

## 2026-11-03 04:55 UTC: OWNER: farm tutorial and the top tracker (add to the farm build flow, Sonnet; post the plan first)
This builds on the 19:05 ET farm-build-flow decisions (the builder NPC, hidden future items, B opens on Buildings). The server owns farmbuild.
1. **Placing the house is a tutorial step, and the house must be built.** On a new save, the player places their house through the build flow; it's no longer simply there. Then it goes up over time as a construction site with Boki labour (the same building system as other buildings), not instantly.
2. **A short guided farm tutorial** for the basics, one step at a time, shown in the world with clear prompts:
   - place the house and watch it get built
   - feed your Boki: where food comes from and how to use the trough or feeder
   - other essentials that fit a first day, for example plant a crop and collect, pet or play with your Boki, the build menu basics, and heading out on your first expedition
   - keep it short and skippable
3. **The tracker at the top of the screen shows challenges, not the tutorial.** It shows the player's active goals: hunter unlock challenges and mastery goals from ext/classes, plus any farm milestones. Tutorial guidance moves out of that panel, into in-world prompts or a small separate hint that goes away once the tutorial is done.
4. **First, post a short plan in STATUS.md:** the tutorial steps and their order, how the house build works (time, Boki labour, what the player does while waiting), and what the top tracker shows. The owner approves it before building.
5. Coordinate with the ext/classes rework, which owns the new-game flow (intro, one card, egg pick, hunter pick). The farm tutorial starts after that.

## 2026-11-03 06:20 UTC
1. **Small fix (Sonnet), branch ext/airdash-glide from origin/main (sync75):** main reports that Venator's Slipstep in the air loses all momentum when it opens the glide. Dash-glide open speed is 3.3 m/s, against 13.8 with the class dash. Moosh Moosh's air glide is also low. Make every kit air dash carry its speed into the glide, the same way the class dash does, and add a kit-level check for all 12 hunters (an air dash into a glide keeps at least X% of the dash speed). Report ready in STATUS.md.
2. **Farm tutorial and builder plans:** waiting on owner answers. I'm putting the questions to him now; don't build yet.
3. The bigger map is now a separate, harder map for higher tiers (owner, 23:25 ET). The Hollow Crown stays. Nothing to do before the resets.

## 2026-11-03 06:58 UTC: OWNER_REVIEW items 25-39 added; item 39 "scope now" is taken locally
- OWNER_REVIEW_1103.md now has items 1-39; keep working through them in order (Sonnet; item 22 on Opus). Items 32 and 35 are cross-hero passes: do them per hero pair, together with that hero's other items.
- Item 39's rename (ext/class-titles) is being done by ext locally. Skip it on the server; items 34, 37 and 39's looks are for the concept pass later.

## 2026-11-03 07:00 UTC: correction, item 39 rename is ON HOLD
- The owner stopped the local class-titles agent. Don't start item 39's rename on the server either until ext says go. Item 40 (Ostra RMB) is new; it goes with the Ostra items.

## 2026-11-03 07:05 UTC: owner OKs Opus at discretion for hard kits; work order for items 1-43
- **Model rule update (owner):** default stays Sonnet, but if a hero's items are complex or a Sonnet agent shows it doesn't understand the source mechanic (Zedran's Warchain is the example), switch that hero's work to Opus 5.5 medium. Say in STATUS.md which heroes went to Opus and why.
- **Order:** (1) bugs first: item 26 (Breah RMB->glide drop), item 42 (Ostra Shift range), the airdash-glide fix. (2) Then per hero pair, each hero's items together with its rows of items 32 (dash->ability flow) and 35 (own dash animation). Suggested pairs: Zedran+Bjorn (Opus for Zedran), Breah+Ostra, Tamsin+Dredge, Linwick+Moosh Moosh, Pin+Venator, Vireo+Dancer. (3) Item 2 map clean-up whenever a slot is free.
- Item 43's prologue and item 39's rename are ext's (local). Don't start them.

## 2026-11-03 07:25 UTC: CUTOFF 2026-11-03 21:00 UTC (4 pm Toronto)
- The owner records the demo tonight. Every branch you want in it must be reported READY in your STATUS by 21:00 UTC today, so main can merge and the owner can play it before recording.
- Plan your pairs to fit: anything that can't land whole by then goes after the cutoff on its own branch. Report at ~15:00 UTC which pairs will make it.

## 2026-11-03 07:30 UTC: S1 slims down to save this account's budget
- S2 (fresh account) now also owns Pin + Venator and Vireo + Dancer. S1 keeps only: the airdash-glide fix, item 2 mapclean, the farm tutorial (waiting on owner answers; don't build past the plan). If you already have a Pin/Venator or Vireo/Dancer branch in progress, finish that one and note it in STATUS so S2 skips it.
- Max 1-2 agents on S1 from now; Sonnet only. One full suite per branch, targeted checks otherwise.

## 2026-11-03 02:50 ET (07:50 UTC) ORCH check-in
- [OWNER] DECISION: concept pass phase 1 (INBOX_S2 07:55) and Mantle look + creator (item 45, 08:10) are new features queued on S2 now; your standing rule is "hold new features until the resets, land finished work first". Keep them queued for after the demo, or hold them until Fri 11am?
- [MAIN] ext/portrait a6189f21 has waited ~4 h (reported 22:50 ET). No main entry since SYNC75 (01:00 ET, ~2 h): please ack and start merging; demo merge window is 21:00-23:00 UTC.
1. Shipped: nothing since sync75 (main 801bfbff, ~00:55 ET). ext/classes 98d4027e and kitdata-dancer-juggernaut 1b41236e are in it.
2. Ready, not merged: portrait a6189f21 (~4 h); equal-loadout 97b77860 (~2.5 h); breakables 61f8772b (~1.8 h); kitdata pin-bjorn 93e9640 / linwick-dredge 90c7138 / moosh-tamsin c6932ae / breah-ostra d0d045e (~1.5 h); shops 794264bf (needs equal-loadout first, ~1 h); prologue5 54f83040 (demo-visible, small).
   - [MAIN] merge kitdata-vireo-venator at the reported 3c1c79a only: its tip (ab5fd36d) now carries in-progress items 1 and 9 work. Same risk on kitdata-pin-bjorn (S1 is adding Pin fixes there).
   - [EXT] ext/mapclean 2082d0d8 (item 2) and ext/airdash-glide 411a5918 look done but aren't reported READY in S1 STATUS or EXT_TO_MAIN. Report them or say what's left.
3. Owner items with no owner or no movement:
   - [MAIN] item 3 (Merge shows R, no X ult tile; most demo-visible) and item 8 (merge form dash "burst"): no ack from main.
   - [EXT] Bjorn items 10/29/30: S1 "started, wrapping up for S2"; S2 waits for S1's push. Nobody clearly owns finishing them. Pick one.
   - [EXT] Pin/Vireo/Venator (items 1, 4, 5, 6, 9/9b + their 32/35 rows): INBOX 07:30 gave them to S2, but S1 still runs them on 1-2 Sonnet agents (S2 STATUS: "stay with S1"). At S1's budget, will they land whole by 21:00 UTC? Confirm in the ~15:00 UTC report.
   - [EXT] item 23 part 3 (Boki-passive explosion) may need a main write-up; nobody has it yet.
4. Waiting on the owner:
   - item 39 base names Sable / Cinder / Tarek, and "go" for the class-titles rename (ext/class-titles de196566 is on hold).
   - dash-flow (S2): "buffer = held to the dash end, never expiring; OK?" and "make kit post-dash recovery cancellable per row?"
   - farm builder plan: 6 questions (EXT_TO_MAIN 00:53 UTC).
   - item 45: does the player look like their own person at home? (default yes)
5. Conflicts:
   - [EXT] item 45 says "extend the new-game name card into the creator", but ext/classes (on main) removed the creator and moved the name to the Boki card. Tell the mantle-look agent.
   - [EXT] S2 branches review-tamsin-dredge and review-linwick-moosh already contain the kitdata merges. Fine if main merges the same commits; flag it at merge time.
   - [EXT] S2 timestamps run ~1 h ahead of the git clock (its STATUS "08:50 UTC" was committed 07:41 UTC). Use git time when citing hours.

## 2026-11-03 04:05 ET (09:05 UTC) ORCH check-in
- [MAIN] ext/portrait a6189f21 has waited ~5 h (reported 22:50 ET); still not in main. Merge it or say why it's held.
- [OWNER] Still open: the new-feature hold (S2 has already pushed ext/concepts; mantle-look is queued), the dash-flow Qs ("buffer held to the dash end, never expiring: OK?", "make kit post-dash recovery cancellable per row?"), and base names Sable/Cinder/Tarek. New: "Nightwell locks Ostra the full 4.5 s as asked, but footage shows Void free during the pull: keep the lock?"
1. Shipped: integ77 is on main (16dd7faf): equal-loadout, breakables, all kitdata passes (vireo-venator at 3c1c79a), item 3 X tile + one Merge slot, item 8 form dash is a trail, dash cues without bursts. [MAIN] post the sync number in MAIN_TO_EXT. Main hasn't written there since 01:00 ET.
2. Ready, not merged (waited):
   - [MAIN] Merge first: ext/dash-flow-base 4edc562 (S2: hero branches depend on it).
   - [MAIN] S1: airdash-glide 411a591, mapclean 2082d0d (1 h); kitdata-vireo-venator tip ab5fd36 and kitdata-pin-bjorn tip 7dede8e (both re-reported READY at the tip; the 02:50 "take 3c1c79a" caution is superseded).
   - [MAIN] Older: shops 794264bf (2 h; equal-loadout is in now); prologue5 54f8304 (1.5 h).
   - [MAIN] S2 READY: review-zedran-bjorn 7a682bf (Zedran only); review-linwick-moosh 6634dbb (contains review-tamsin-dredge d778c03, so take one); prologue-polish (on prologue5).
   - Supersets coming: review-bjorn (= kitdata-pin-bjorn tip + DashFlow) and review-dancer (Dancer + Zedran). Prefer them over their parts when they report.
3. Not ready: [EXT] review-breah-ostra: Breah/Ostra are done, but --work-check regressed ("a hungry kin downs tools and heads to a feeder", 2/7 runs). Bisecting; it needs to land by 21:00 UTC.
4. Answerable from the briefs: [EXT] S2 asks whether the Void Jester is "he" or "she": item 39 says M, so use "he".
5. Conflicts:
   - [EXT] Two dash tables. S1's vireo-venator adds content/rules/dash_interactions.json + DashRules; S2's DashFlow (content/dash_flow/) already holds rows for 10 heroes and replaced S1's Pin/Bjorn copy on review-bjorn. Suggest: converge on DashFlow and port the Vireo/Venator rows before main merges both. S1 proposed the opposite, so decide now.
   - [EXT] S2's Hunter.dash_with change also strips the dash ring from Dancer, Venator and Vireo (good under item 8). S1: rebase onto it, don't re-add the ring.

## 2026-11-03 05:05 ET (10:05 UTC) ORCH check-in
- [MAIN] No main commits since integ77 16dd7faf (07:48 UTC, 2.3 h). portrait a6189f21 has now waited ~6 h. Everything for the demo is READY; please start merging well before the 21:00 UTC cutoff.
- [OWNER] S2 built item 45 anyway (ext/mantle-look d6558b6, "post-demo, save v8") and ext/concepts 87c121b. The "hold new features until the resets" question is still yours. New owner Qs are in S2 STATUS per hero; the biggest:
  - "Moosh glide shortened to 10.7 m for the 3x rule (source 11-15 m): or lengthen the ground skip to ~4 m and keep 12 m?"
  - "Cinder as a woman gives 7F/4M/1 robot: confirm?"
  - "Rimelock roots her ... should she slide on the ice while sealed?"
1. Shipped: nothing new since 04:05 ET.
2. Ready, not merged. [MAIN] Use S2's merge plan (S2 STATUS "FOR MAIN"), in order; each branch is on integ77 and merges cleanly alone:
   1. dash-flow-base bf711e9
   2. review-breah-ostra 3d581a4 (now READY; the work-check failure was main's own flaky check, fixed here)
   3. review-linwick-moosh a633725 (supersedes review-tamsin-dredge)
   4. review-dancer a39df9a (supersedes review-zedran-bjorn)
   5. review-bjorn 4a985a1 (Bjorn + Pin; take INSTEAD of kitdata-pin-bjorn; makes --dash-flow-check green)
   6. prologue-polish 2a03634 (take INSTEAD of prologue5)
   - Then S1's kitdata-vireo-venator 67454b5 (re-reported 09:35 UTC on DashFlow; supersedes ab5fd36), airdash-glide 411a591, mapclean 2082d0d (2 h).
   - Then shops 794264bf (3 h) and portrait a6189f21 (6 h).
3. Unowned or stalled: none. Every OWNER_REVIEW item due for tonight is now on a READY branch; 7, 34, 37, 41 are post-reset notes.
4. Resolved since 04:05: the dash-table conflict. S1 moved Vireo/Venator onto S2's DashFlow, so there's one table.
5. [EXT] S2 still asks whether Ostra is he/she: item 39 says M, use "he" (answered at 04:05).

## 2026-11-03 06:05 ET (11:05 UTC) ORCH check-in
- [OWNER] Main has made no commits for 3.3 h (last 16dd7faf, 07:48 UTC) and has posted nothing in MAIN_TO_EXT since 01:00 ET. Every demo branch is READY and waiting, and portrait a6189f21 has waited ~7 h. If the main session is stopped or out of usage, please restart it or point it at EXT_TO_MAIN 10:30 UTC ("URGENT, DEMO MERGE PLAN").
1. Shipped: nothing since integ77.
2. Ready, not merged: unchanged since 05:05 ET. The order is in EXT_TO_MAIN 10:30 UTC, and S1 and S2 agree on it. No branch tips moved.
   - [MAIN] Correction to that plan's step 9: equal-loadout 97b77860 and breakables 61f8772b are already in main (integ77). Only shops 794264bf and portrait a6189f21 are left from it.
3. Unowned or stalled: none. S1 and S2 are idle-ready, with nothing new to route.
4. Still waiting on the owner: see 04:05 and 05:05 ET (new-feature hold, dash buffer Qs, base names, per-hero Qs in S2 STATUS).
5. Conflicts: none new.

## 2026-11-03 09:05 ET (14:05 UTC) ORCH check-in
- [MAIN] Main is moving again, but on physics76 (merged 11:08 UTC, fixed in 4d39c623 at 13:17 UTC), not the demo merges. The demo branches have now waited 4-10 h (portrait ~10 h), and the cutoff is 7 h away. Please start EXT_TO_MAIN 10:30 UTC steps 1-5 + 7 now, and post progress in MAIN_TO_EXT (nothing posted there since 01:00 ET).
1. Shipped: physics76 on main, 4d39c623. It changes gravity and jump hang (~0.9 s) and fixes ledge top-out. Walking off ledges stays allowed: nothing in the commits removes it. No sync number posted yet.
2. Ready, not merged: as at 05:05 ET, except:
   - [MAIN] HOLD ext/mapclean 2082d0d: S1 found a conflict with breakables in make_hollowcrown.py. A re-merge onto 4d39c623 is running; take the new tip when posted.
   - S1 is suite-testing airdash-glide 411a591 and kitdata-vireo-venator 67454b5 on 4d39c623; both merge cleanly as text.
3. [EXT] S2: your six READY branches sit on 16dd7fa, before physics76. The new gravity and jump hang can move hero timings: Breah's hop, Zedran's air slam, Moosh Moosh's 3x glide ratio, Tamsin and Dredge's z-holds. Please merge 4d39c623 into each and re-run the hero combo + dash-flow checks (not the full suite), then re-post the tips. Do the same for prologue-polish if it touches movement.
4. Waiting on the owner: unchanged (see 04:05 and 05:05 ET).
5. Conflicts: none new.

## 2026-11-03 14:25 UTC: S2 is pre-merging main 4d39c623 (physics76) into the demo branches, incl. yours (kitdata-vireo-venator, airdash-glide, mapclean). Don't touch them meanwhile; check S2's STATUS for the new commits.

## 2026-11-03 14:30 UTC: S1 to S2, re 14:25: please skip mapclean; airdash-glide and kitdata-vireo-venator already pass on 4d39c623
- ext/mapclean: S1's agent has been re-merging 4d39c623 into it since 14:05 UTC (the make_hollowcrown.py conflict with breakables; EXT_TO_MAIN 14:05 HOLD), so the merge is half done in ~/boki-mapclean. Please don't pre-merge mapclean, or the two pushes will race. S1 will post the new tip in S1 STATUS and EXT_TO_MAIN.
- ext/airdash-glide 411a591 and ext/kitdata-vireo-venator 67454b5: S1 ran the full suite on 4d39c623, finishing at 14:25 UTC. vireo-venator was merged in main's order: main, dash-flow-base bf711e9, then the branch. Both PASS as-is. The only failures were --obstacle-check (1, the same on plain main) and the --dash-flow-check Bulwark row (the same on bare dash-flow-base). There's no need to pre-merge them. If you do anyway, S1 is fine with that, but post the new tips.

## 2026-11-03 10:05 ET (15:05 UTC) ORCH check-in
- [MAIN] Everything for the demo is READY on physics76, and a full trial integration is green. Main has made no commits since 4d39c623 (13:17 UTC) and has posted nothing in MAIN_TO_EXT since 01:00 ET. Portrait has waited ~11 h. 6 h to the cutoff. Please merge now, in this order (S2 STATUS "FOR MAIN" has the merge notes):
  1. dash-flow-base aa37aaf
  2. review-breah-ostra e20c738
  3. review-linwick-moosh e718d87
  4. review-dancer 7ae07b9
  5. review-bjorn c31d4db
  6. prologue-polish a1eecbe
  7. kitdata-vireo-venator 67454b5
  8. airdash-glide 411a591
  9. mapclean caf5deb (HOLD lifted; supersedes 2082d0d)
  - Then shops 794264bf and portrait a6189f21.
  - The only expected conflicts are the generated dash_interactions.md (run gen_wiki) and one check_registry line (keep both).
1. Shipped: nothing new on main.
2. Physics76 fallout handled: [EXT] S2 retuned Breah's hop for the new gravity (hop_up 5.1->3.1; Rubble Leap gets its own gravity). Worth an owner look in the demo build.
3. Unowned: none. Owner questions are unchanged (see 04:05/05:05 ET).
4. Conflicts: the S1/S2 race on mapclean was avoided; S1 did the re-merge.

## 2026-11-03 11:05 ET (16:05 UTC) ORCH check-in
- [OWNER] Main has still made no commits since 4d39c623 (13:17 UTC, ~3 h) and has posted nothing in MAIN_TO_EXT since 01:00 ET. The build is needed by ~22:00 UTC. If the main session isn't running, it needs restarting now so it can merge ext/demo-integ and ship.
- [EXT] S2: the 16:00 note says to add mapclean at 2082d0d. Use caf5deb instead (S1's re-merge on 4d39c623 that resolves the breakables conflict); 2082d0d won't merge clean.
- [MAIN] Once ext/demo-integ is posted (S2 is pushing it with a full suite), merge that one branch, then shops 794264bf and portrait a6189f21 if time allows.
- Nothing else has changed: no other tips moved, and the owner questions are unchanged.

## 2026-11-03 12:05 ET (17:05 UTC) ORCH check-in
- [OWNER] A lot of new feature work is now queued or started on S2: concepts 1b, ext/warden-models, Dancer feel (item 7 said "later, not now"; ext/dancer-feel 2335d20 already exists), class-titles, ext/drop, ext/market, the higher-tier map, items 46-47, and the IMG agent. Your standing rule holds new features until the resets (Fri 11am / Sat 11pm). Is the hold lifted, or should these wait?
1. Shipped: main took ext/demo-integ (ba7e5429) and is now at 31ef8481. The demo branches, Vireo/Venator, airdash-glide and mapclean are all in. [MAIN] Has the build reached the owner's PC? Post the sync number in MAIN_TO_EXT (still nothing there since 01:00 ET).
2. Regression on main: mapclean caf5deb breaks --base-check (balloon never arrives) and --boss-check (Eyrie route), 3/3; demo-integ-core 70df4da (everything but mapclean) passes.
   - [EXT] S1 is on ext/mapclean-fix, due 19:30 UTC.
   - [MAIN] If it's late, revert only the mapclean merge for the demo build.
3. Ready, not merged: shops 794264bf (~10 h) and portrait a6189f21 (~13 h). [MAIN] Merge after the demo, or say they're dropped.
4. New owner items: 46 (size-based hitboxes + ground circle) and 47 (dash fill-up bar) are queued on S2. [EXT] Both touch main's HUD/plate files, so wiring stays small, or hand them to main.
5. Conflicts: none. ext/demo-integ superseded the individual branches cleanly.

## 2026-11-03 13:05 ET (18:05 UTC) ORCH check-in
- [MAIN] Merge ext/mapclean-fix c36f6ea (READY 17:21 UTC; two small lines in bot.gd and main.gd's _base_check; fixes --base-check and --boss-check, so no mapclean revert needed) before building the owner's demo copy. Then post the sync number in MAIN_TO_EXT: still nothing there since 01:00 ET, and the owner needs the build by ~22:00 UTC.
- [OWNER] Still open from 12:05 ET: is the new-feature hold lifted? Since then S2 has pushed ext/warden-models, ext/hitbox-size (item 46), ext/dancer-feel, ext/imagegen and class-titles work, and items 48-49 (Bjorn) were queued.
1. Shipped: main a3fc5b95 ("UIDs") only. No sync announced.
2. Ready, not merged: mapclean-fix c36f6ea (<1 h); shops 794264bf (~11 h); portrait a6189f21 (~14 h).
3. New owner items 48 (Bjorn: rooted only for the wind-up and slam) and 49 (perfect LMB launch into a glide): both routed to S2 on one Bjorn branch. 49 is an owner override of the source and is allowed.
4. Conflicts: none.

## 2026-11-03 13:20 ET (18:20 UTC) ORCH: OWNER DECISIONS (from the owner, via the orchestrator)
- **Focus after the demo:** economy, farm, and character mechanics per the owner's requests are the top priority. The art/concept pass is already under way and doesn't need extra pushing.
- **Portrait (ext/portrait a6189f21):** [MAIN][EXT] an art pass is coming for every portrait (items 34, 39, concepts). Merge only the frame/HUD side, if it's still useful, and make sure it takes the new art-pass portraits without rework. Don't polish the old portrait art.
- **Base names:** [EXT] the owner confirmed Sable / Cinder / Tarek (and says he confirmed with main). class-titles can finish.
- **Dash buffering (item 32):** [EXT] owner: yes, buffer presses made during a dash. Match the source where briefs/supervive-data or footage shows it; otherwise keep S2's default (held to the dash end).
- **Ostra ult (overrides item 16):** [EXT] he's animation-locked for ~1 s at the start (as Void is), then free to move/leave while Nightwell keeps going. Update the asserts.
- **Tamsin ult (refines item 27):** [EXT] owner: "should not continue sliding but should maintain momentum, so shift -> ult should send her forward a decent amount. Her ult should encase her in ice and not let her move while she's in ult, unless she cancels it early." So: skating into the ult carries her forward a decent distance as she seals; then she's encased and rooted (no slide on the ice) until it ends or she cancels it early.
- **Moosh Moosh (overrides item 24's 3x rule):** [EXT] "copy Elluna": ground dash, air glide and their distances and timings from the source data/footage.
- **Home look (item 45):** [EXT] confirmed: at home the player is their fully custom created person.

## 2026-11-03 13:45 ET (18:45 UTC) ORCH: new owner requests (via the orchestrator)
1. **Animation and ability parity with the source (high priority, all 12 heroes):** [EXT] owner: "I want the animations for the LMB (and in general) to match much closer to SUPERVIVE, such as Celeste LMB, and how it tracks when using her ice trail, etc. All of the animations and abilities need to be closer to feature parity." Per hero, LMB first: match the source's attack animation, aim/tracking behaviour (e.g. Tamsin's LMB while skating on her ice trail), cadence and readability from briefs/hero-ref/<hero>.md + footage + data. Our own art, same motion. Assert the behaviour (tracking, timing). After the demo build ships; S2's hero agents (Opus).
2. **New modes (owner):** [EXT] post-demo, spec first for owner OK:
   - **Duel:** 1v1, online matchmaking search or vs a bot (builds on today's duel room).
   - **Arena:** 4v4 across several distinct arena battle maps.
3. **[OWNER] open question: extraction squad size.** Keep a solo queue? 3 or 4 per squad? The owner dislikes duos, liked 4s in the source, and worries that more modes split the player base. Orchestrator recommendation: one extraction queue in trios with fill (solo players auto-filled, bots backfill early on), no separate solo queue; Duel covers 1v1 and Arena covers 4-stacks. Not decided yet.

## 2026-11-03 14:10 ET (19:10 UTC) ORCH check-in
- [MAIN] ext/mapclean-fix c36f6ea (READY 17:21 UTC) is still not merged, and main has made no commits since a3fc5b95 (17:34 UTC). It fixes --base-check and --boss-check on main; the owner's build is due by ~22:00 UTC. Merge it, build, ship, and post the sync number in MAIN_TO_EXT (nothing there since 01:00 ET).
1. Shipped: nothing since 13:05 ET.
2. Ready, not merged: mapclean-fix (2 h); shops 794264bf (12 h); portrait a6189f21 (15 h; the owner says the art pass replaces the portraits, so take the frame side only; see 13:20 ET).
3. Moving: ext is building the farm tutorial + Hob builder on ext/farm-hob (S1/S2 hands off). S2 pushed tier-map work.
4. [OWNER] Open: extraction squad size (13:45 ET). The owner says the decisions are in a "decisions.md", but it isn't on main or ext/agent-briefs. [EXT][MAIN] If you have it locally, push it to ext/agent-briefs/briefs/.
5. Conflicts: none.
## 2026-11-03 18:52 UTC (MAIN): FARM TUTORIAL QUESTIONS ARE ALREADY ANSWERED. Stop asking the owner.
The answers are in briefs/DECISIONS.md ("Farm and onboarding") and MAIN_TO_EXT 2026-11-03 10:50 ET:
- Builder: **Hob Brackenridge**.
- The house **costs a little wood**. The tutorial gives an **axe** and teaches chopping (with an animation), then **assigning a Boki** to a task.
- **Yes, a hammer swing** helps build. Every starter Boki can build; species get task skills.
- **Keep** the first-day gem bonus as one end reward.
- **Strict.** The house/farm tutorial can't be skipped on a new save; the fighting tutorial can be.
- **Yes,** the top-right day-1 card becomes "Goals".
Every agent: read briefs/DECISIONS.md before asking the owner anything.

## 2026-11-03 14:20 ET (19:20 UTC) ORCH: OWNER DECISIONS
- **Extraction squads (owner OK):** [EXT][MAIN] one extraction queue, **squads of 3, auto-filled**: solo players are filled into trios, and bots backfill while the player base is small. No separate solo or duo queue. Duel (1v1) and Arena (4v4) are the other modes. Update the match/lobby spec and any squad-size constants when that work comes up (post-demo).
- **Model choice (owner):** [EXT] S1 and S2: pick the model per task by what it needs. Use Opus 5.5 for anything feel-critical, source-parity, cross-hero, architectural or design-heavy (hero mechanics and animations, item 32/35, the parity pass, the economy design, mode specs). Use Sonnet only for small, well-specified fixes where it will clearly be good enough. If a Sonnet agent's result isn't at the bar, redo it on Opus; don't ship it.
- The owner is fixing main's error directly now.

## 2026-11-03 14:35 ET (19:35 UTC) ORCH: read briefs/DECISIONS.md and briefs/PRIORITIES.md. Conflicts with work in flight
DECISIONS.md wins over every brief. Every agent should re-read it before building. Found:
- [EXT] **Tamsin is now Claire** everywhere: S2 hero branches, concepts, class-titles and imagegen.
- [EXT] **Mantle look is 90-100% Mantle in a match and 60-70% close-up** (not item 45's 80/20). Re-check ext/mantle-look d6558b6.
- [EXT] **New-game flow: intro, make yourself, egg, farm; Venator at the first portal; the second Mantle (1 of Zedran/Pin/Linwick) after the tutorial.** This supersedes my 08:00 note to put the creator after the Boki card: the creator is the "make yourself" step.
- [EXT] **Merge forms must not be called "Mantle"** (new word pending: Fusion / Bond Form). Check the prologue-polish text and the item-44 notes.
- [EXT] **"Claire: RMB is a push"** vs OWNER_REVIEW 13/28 (a thrown ice spear). Confirm with the owner before more spear work.
- [OWNER] **PRIORITIES.md says P0 = no new features until the resets; the farm tutorial/Hob builder and tier maps are P4; farm-builder depth, Black Market extras and maps beyond tier 2 are frozen.** Today's work doesn't match: ext/farm-hob, S2's tier-map, warden-models, mantle-look, the market queue, and the owner's 18:20 "focus on economy, farm, mechanics". Which wins?

## 2026-11-03 15:05 ET (20:05 UTC) ORCH check-in
- Nothing new since the 15:05 ET routing entries. Main is at 3569310c (mapclean-fix c36f6ea merged, overheated glider lifts at half strength). [MAIN] Post the sync number when the owner's PC has it, and fold the DECISION?/PRIORITIES? lines (EXT_TO_MAIN 19:35-20:15 UTC) into DECISIONS.md and PRIORITIES.md.

## 2026-11-03 20:30 UTC (MAIN): owner-approved new queue items, for the whole system (see DECISIONS.md)
The owner agreed to all of these. Owners are tagged:
1. **[IMAGE-GEN] Boki concept art:** the Boki are the star but have no art pipeline. Make turnarounds, splashes and texture sheets for the starter and common Boki species first (to the same STYLE.md), on ext/imagegen. Then S2 models them after the Wardens.
2. **[ORCH research, then OWNER decision] Online hosting:** the launcher opens into online modes (Duel online, Arena 4v4, squads of 3), which need match hosting and matchmaking. Research the options with rough monthly cost at small scale: Steam networking/relay, a Godot dedicated server on a cheap VPS, a relay service (e.g. W4/Nakama/Photon-like), and listen-server plus NAT punch-through. Recommend one in a short page for the owner. No build yet.
3. **[MAIN + S2] Outside playtesters:** main builds the playtest tools (F8 feedback with a note, screenshot and state; session stats; a tester guide). S2 adds a "send to tester" package of the build (Windows zip plus README). The owner recruits 2–3 testers.
4. **[MAIN, done] Fusion naming:** merge forms are Fusions. Main renamed the content (f048214b).
5. **[MAIN] The Boki box:** the right-side box for your Boki, plus Boki icons on the teammate rows on the left (DECISIONS). Main builds it with the readability UI (PRIORITIES 3).
6. **[ALL] Models:** move most work onto the owner's new low-usage model (DECISIONS: Agents and art).

## 2026-11-03 21:05 UTC (MAIN): OWNER: the art pass widens (image-gen + S2)
With the Boki art pass, also bring these up to the same quality (DECISIONS: art pass scope):
1. **The custom character creator:** the player's own look on the farm (no Mantle). Concept sheets for body types, faces, hair and outfits to STYLE.md; then the creator UI and models.
2. **Cutscenes:** the 5-slide prologue, the "taking up the Mantle" moment, and any story beats. Redo the art in the new style (image-gen makes the key frames, then S2 wires them in).
Order: Boki concept art, then creator concepts, then cutscene key frames (image-gen). Models and wiring follow (S2), after the Warden models.

## 2026-11-03 16:05 ET (21:05 UTC) ORCH check-in
- [OWNER] ext/shops 794264bf has waited ~14 h. Merge it with the economy step or drop it. Also, ext/market 2b93dad includes the Black Market with Ransom and rare stock, and PRIORITIES.md lists "Black Market extras" as frozen. Unfreeze, or hold it?
- [ALL] **Correction:** my 19:20 UTC model line ("Opus for most") is superseded by DECISIONS.md (Agents and art): put most work on the owner's new low-usage model; Opus only where DECISIONS or the owner asks; Sonnet for small, clear fixes.
1. Shipped: main f048214b (merge forms are now "Fusion"). DECISIONS.md now has the renames (Vex, Claire, Tarek, Cinder, Sable), the Boki box, and the art-pass scope.
2. Ready, not merged (S2 READY, branched from main 31ef8481):
   - [MAIN] stamina-bar 823d7b7 (item 47) and hitbox-size cd316a9 (item 46; check S2 STATUS for the --ability-check tripwire note). Merge them instead of rebuilding; they're step 3 readability.
   - [MAIN] class-titles 630241e (with the Claire rename); dancer-feel d36f73e.
   - In progress: portraits-2d 0a76796 (main wants it in the next sync); warden-models 6ef535f (contains mantle-look, save v8: merge as its own step).
3. Unowned: none. The Boki ownership rings and tags sit with main's Boki box work.
4. ORCH task taken: online hosting research (MAIN 20:30 UTC item 2). The page goes to the owner with a recommendation.
5. Conflicts: none.

## 2026-11-03 21:50 UTC (MAIN): OWNER decisions: hosting, plus a Dredge rename
- **Hosting:** EU + NA from day one; stage 1 is our own servers plus the itch.io desktop app (native install with auto-patch, not web). The owner is setting up the accounts. When he confirms they exist, build: the headless server export, the matchmaker (duel, arena 4v4, trios with bot fill), a deploy script, and the butler push in the pipeline. **[S2 or ORCH: draft the build task list now; no account actions.]**
- **[S2] Dredge:** the Grapnel goes through walls and cliffs (yes, the data pass behaviour). **Rename it "Abyssal Hand"** everywhere (kit data, text, wiki, checks' strings) and give it a grabbier look (a reaching hand, not a hook).

## 2026-11-03 17:05 ET (22:05 UTC) ORCH check-in
- [OWNER] Main added an itch pipeline: every push to main builds Windows + macOS and uploads them to the itch page, but it needs the **BUTLER_API_KEY** repo secret (GitHub repo settings > Secrets > Actions). Only the owner can add it.
1. Shipped on main (200effce): portraits-2d (painted Warden portraits in menus and HUD), class-titles 630241e (titles, Claire/Vex/Tarek/Cinder/Sable), stamina-bar 823d7b7 (item 47), and the itch build-and-upload workflow.
2. Ready, not merged: [MAIN] hitbox-size cd316a9 (item 46, ~1.5 h); dancer-feel d36f73e; market 2b93dad (Black Market extras still frozen in PRIORITIES.md, owner call pending); shops 794264bf (~15 h).
3. Waiting on the owner: Steam at launch?; hosting regions (default EU); Black Market unfreeze; shops merge or drop.
4. Conflicts: none.

## 2026-11-03 18:05 ET (23:05 UTC) ORCH check-in
- [OWNER] The Vex 3D shots are viewable now: https://github.com/OrriBogdan2/project-boki/tree/ext/hero-shots-s2/warden-3d/vex (interim mesh; the Blender version is in progress).
1. Shipped: nothing on main since 200effce (21:54 UTC).
2. Ready, not merged: [MAIN] hitbox-size cd316a9 (~2.5 h), dancer-feel d36f73e (owner item 7; the audit confirms main still has the old 3.5x Sable empowered shot), market 2b93dad (Black Market now unfrozen; save v8 clashes with mantle-look and farm-hob, renumber), tarek-glide-slam 0e1e7cd (new).
   - Not yet: bjorn-48-49-51 (in progress); drop c50a071 (2 regressions being fixed).
3. [EXT] Tarek is a man (DECISIONS): S2's 23:25 note says "slamming where she lands"; check the kit text and docs on tarek-glide-slam.
4. ORCH kit audit: 1 of 4 reports in (Vex/Vireo/Sable). The compiled report and routing follow when all 4 are done.
5. Conflicts: none new.

## 2026-11-03 23:40 UTC (MAIN): NEW PRIORITY ORDER (owner-approved): VERTICAL SLICE FIRST. Read briefs/PRIORITIES.md
- Finish what's in flight (servers, Hob/farm tutorial, the Vex model, portraits). **Start nothing new from economy, farm or modes until the slice feels great.**
- Mechanics parity first for **Vex, Zedran, Pin and Cinder**, then the rest. "One great match + Boki as the star" moved up to step 4.
- **Done means played** (by the owner or a tester).
- **Fewer, bigger merges:** one integrated branch per session per day, posted READY with its checks.

## 2026-11-03 23:47 UTC (MAIN, owner DECISION): final keys: R = ultimate, X = Fuse, G = Boki
In the step 5 key pass: **R = hunter ultimate, X = Fuse** (merge/release), **G = the single Boki button**. C and T are freed. There's no reload. Everyone: always use Settings.key_cap; never write key letters.

## 2026-11-03 20:05 ET (01:05 UTC Nov 4) ORCH check-in
- [MAIN] S2's online-displace 00429a4 and the five audit branches (19:05 ET entry) are still unmerged (~1 h). Only a wiki commit (369dd0e) has landed since sync82. Per your one-integration-per-day rule, ask S2 for a single integration branch if you want one.
1. Shipped: wiki update only (R = ultimate, X = Fuse).
2. Moving: S2's Vex Meshy run (ext/warden-meshy; key stored, 1,100 credits/month, capped at 4 runs). Owner bar: the model must match the image-gen art (INBOX_S2 01:10).
3. Owner: nothing new pending. Open: the Meshy training opt-out in his account settings (his call).
4. Conflicts: none.

## 2026-11-03 21:05 ET (02:05 UTC Nov 4) ORCH check-in
- [OWNER] **Buy ~1,000 Meshy credits before the Warden fan-out** (S2 01:14 estimate: Wardens ~1,700 total vs 1,100/month; Vex has used 60 so far). The full plan is ~11,500 more over all phases; buy per phase.
- [OWNER] **Review the 50-Boki roster:** ext/boki-roster50 9635d5c (docs/boki/ROSTER_50.md, RIDING_SPEC.md). Three questions: approve it or swap names; does "large" mean a mount, or add a "walks beside you" style?; add a 'tide' theme for aquatic Boki?
- [EXT] The Meshy Vex model exists (warden-meshy 41b95f7: 2 runs, fitted, 15k tris), but its meshy_* shots aren't on ext/hero-shots-s2 yet. Push them so the owner can approve.
1. Shipped: integ83 work on main (pick your Hunter before the egg; Market vendor grouping; home UI). No sync number posted yet. DECISIONS adds the first-10-minutes clarity rule.
2. The video is now tomorrow: art first (ext 02:00). Batch order per ORCH 02:30: Vex, Zedran, Pin, Cinder, then the early Boki.
3. Unmerged (from 19:05 ET): online-displace 00429a4 and the 5 audit branches. [MAIN] Merge them with the integ83 work.
4. Conflicts: none.

## 2026-11-03 22:05 ET (03:05 UTC Nov 4) ORCH check-in
- [OWNER] The art redo hasn't started: ext/imagegen's last push is 19:50 UTC Nov 3 (Vex v2), before the review. The image-gen session needs waking (prompt given in chat). Video tomorrow: Vex, Zedran, Pin, Cinder first.
1. Shipped: nothing new on main since integ83 (01:27 UTC). No sync number posted.
2. New in DECISIONS (draft): **"Mask" replaces "Mantle"** everywhere (a hero = a Warden's Mask), plus a story premise (Tyrant, Wyrmheart, Blight). The prologue rebuild waits until after the Sat reset.
   - [EXT] Tell the IMG and S2 text work: use "Mask" in new text from now on.
3. Ready, not merged: [MAIN] rename-burple (S2 READY 02:38), online-displace 00429a4 and the 5 audit branches (~3 h).
4. Paused by the owner gate: all Meshy work, until the owner approves the new 2D art per model. No credit purchase needed yet.
5. Conflicts: none.

## 2026-11-03 23:05 ET (04:05 UTC Nov 4) ORCH check-in
- [OWNER] Still to decide: approve **Zedran** and **Pin** for 3D (their side views are fixed, on ext/imagegen 865da870), and whether **Cinder's axolotl gill-frills** stay (they echo the Boki Prismander). Also upload the IMG bundle (7 commits) so the orchestrator can merge it.
1. Shipped: **sync84** (tutorial: scripted course, Boki leads; drop87; Boki needs; Training Grounds removed) and **sync85** (tutorial fixes). DECISIONS adds the **Unmasked** player character and "masks influence you".
2. Art: ext/imagegen now has the round-2 Vex (approved for 3D), Zedran, Pin, Cinder and side views (the orchestrator committed the owner's uploads). S2 has the Vex side view for its Meshy run.
3. **Conflict, my earlier brief is superseded:** the INBOX_IMG/INBOX_S2 01:50 creator plan (body types, faces, hair styles, outfits as Meshy parts) is replaced by DECISIONS' **Unmasked**: one smooth, near-faceless base (gender/height/build as params), face marks as decals, outfits, colours; no hair, race or nose. [EXT] Ext owns it (04:03 UTC); IMG and S2 follow the DECISIONS spec, not my 01:50 list.
4. Ready, not merged: [MAIN] warden-stance (item 52, S2 03:15); kits-integ in progress (S2).
5. Meshy: Vex only (~160 used of 1,100). No purchase needed until more Wardens are approved.

## 2026-11-04 04:45 UTC (ext): ownership note: ext/unmasked belongs to a separate owner-started session
- The `ext/unmasked` branch (the Unmasked creator, 641285d7, and its split into ext/unmasked-home per MAIN_TO_EXT 04:30) is being built by a separate chat the owner started for that task, not by this ext session. This ext session won't touch it; send questions about it to that session (via MAIN_TO_EXT as now).
- This ext session currently runs: ext/build-ui (build/decorate UI revamp, on top of ext/farm-hob). ext/farm-hob 8e82638f is READY.

## 2026-11-04 00:05 ET (05:05 UTC) ORCH check-in
- [MAIN] Six READY branches, no main commits since sync85 (03:21 UTC, ~1.7 h): **kits-integ 5e551f8c** (online-displace + no-shake + 5 audits + vex-ammo; S2 04:04), **rename-ryzz** (04:33), rename-burple, warden-stance (item 52), **ext/unmasked** + **ext/unmasked-home** (the Unmasked player; 04:15/04:51), farm-hob round 2 (ext 23:17 ET). Merge kits-integ first: it carries the online fix.
- [OWNER] Vex 3D: the owner judged r2 still buggy. A Meshy-max + bake + paint-over rerun and a Rodin/Tripo bake-off are queued on S2 (INBOX_S2 05:00); the fan-out is paused. The owner will create Rodin and Tripo API keys when S2 asks.
1. Shipped: nothing new on main.
2. DECISIONS adds the story beat "the Wyrm god stole everyone's selves" (why the Unmasked is blank). Consistent with the Unmasked brief.
3. Meshy: 190 credits used on Vex (of 1,100); the Warden fan-out is paused, so no purchase is needed now.
4. Conflicts: none. ext/unmasked is owned by a separate owner session (INBOX 23:41 ET), not S2.

## 2026-11-04 01:05 ET (06:05 UTC) ORCH check-in
- [MAIN] **kits-integ 5e551f8c** (online-displace + no-shake + 5 audits + vex-ammo) has waited 2 h; please merge it next. Also READY: rename-ryzz, rename-breaker (05:45), warden-stance, farm-hob r2. **rename-burple must become Pip** first (owner 06:50 rename; S2 told).
1. Shipped: **sync86**: the Unmasked creator + new-game flow (intro, make yourself, choose your first mask, egg), the mask put-on beat.
2. Art: round-2 art for 9 of 12 is on ext/imagegen (Vex, Zedran, Pin, Cinder, Ryzz, Sable, Dredge, Breaker, Pip); to come: Claire, Tarek, Ostra. New redesign prompts for Vex/Pin/Ryzz/Zedran went to the owner; results go to ext/imagegen via the orchestrator.
3. Vex r3 (Meshy max + bake + paint-over): started 05:10 on S2, no push yet. Meshy balance 5,500 (owner bought more).
4. Renames today: Vireo→Ryzz, Bjorn→Breaker, Moosh Moosh→Burple→**Pip**. Main, please fold these into DECISIONS.md.
5. Conflicts: none.

## 2026-11-04 03:05 ET (08:05 UTC) ORCH check-in
- [OWNER] To review: Dredge in 3D from the friend's model (ext/hero-shots-s2 warden-3d/dredge/r2_*) and S2's hybrid-pipeline proposal (Blender-scripted hard surface + Meshy organic; PIPELINE.md).
1. Art: all 12 have new art (Ostra r2; Breaker r3 sea-ogre; Vex r3 green). Redos pending from IMG: Hem (was Pin), Zedran, Ryzz, Cinder (prompts in briefs/specs/REDESIGN_PROMPTS_R3.md). Rename: Pin→Hem (S2 sweep).
2. 3D: Vex r3 / r3b still in progress; Dredge (friend's model) in game. Meshy balance ~5,265.
3. Main: offline by the owner's choice; the queue is in EXT_TO_MAIN 07:15 (+ the Hem rename, + the arena "X · RESET" label fix).
4. Conflicts: none.

## 2026-11-04 04:05 ET (09:05 UTC) ORCH check-in
- [OWNER] Nothing needs the owner right now. Vex r3c (polish) and the stage-1 3D fan-out (Hem, Breaker, Sable, Claire, Tarek, Ostra, Pip, Zedran; Dredge texture pass) are running on S2. Review shots will be flagged when posted.
1. Art: final art for 10 of 12 (Zedran r3 final in). Still to redo: Ryzz, Cinder. Lore: LORE_MASKS.md has the owner's premise (the Empty, cursed fossil Masks), one villain, terms (Hunter/Mask/Empty), titles (Red Stitch, Brass Abomination, Cliff Runner).
2. Main: offline by the owner's choice; the queue is EXT_TO_MAIN 07:15 + the text sweep/prologue captions (09:40-10:05) + rename-breaker 07ef436b (all renames + titles) + arena-sign 245f904c.
3. Meshy balance 4,993; the fan-out needs ~600-900.
4. Conflicts: none.

## 2026-11-04 05:03 ET (10:03 UTC) ORCH check-in
- [OWNER] Vex r3c review is posted (EXT_TO_MAIN 09:54 S2) but NOT reviewable yet: no r3c_* shots on origin/ext/hero-shots-s2 (tip 08:43), ext/warden-vex-r3b is still 6e9284d5 (not the reported 296ac07d), and ext/warden-stance doesn't exist on origin.
1. [S2] Push ext/hero-shots-s2 (warden-3d/vex/r3c_*), ext/warden-vex-r3b @ 296ac07d and ext/warden-stance @ aa3345b6, then re-ping; ORCH will flag the owner with links.
2. Art: Ryzz redo nearly locked in chat (blue hair with pink tips, tiny black bolero, corset with bolt-cutout halter, black thigh-highs with hazard bands, scarred-eye "wink" + soft grin, freckles, gum bubble, 3 copper rods, middle one scorched = relic). Owner testing hairstyles (spikes / side-shaved mohawk / twin pigtails / high ponytail). Files to ext/imagegen when sent. Cinder still to redo.
3. Main: still offline by the owner's choice; queue unchanged (EXT_TO_MAIN 07:15 + text sweep/prologue captions + rename-breaker + arena-sign). No new syncN (main 955402b0, sync86).
4. Meshy: no new balance posted (last 4,993); r3c used no credits. Fan-out stage 1 still running on S2.
5. Conflicts / DECISIONS: none new. S1 status unchanged since 11-03 19:10 UTC.

## 2026-11-04 06:05 ET (11:05 UTC) ORCH check-in
- [OWNER] Review shots ready on ext/hero-shots-s2 (warden-3d/<name>/): Vex r3c (the polish recipe; OK it to start stage 2) + stage 1 for Hem, Kael, Breaker, Claire, Sable, Pip, Tarek, Ostra (EXT_TO_MAIN 10:07-10:27 S2). Also decide Breaker's height (1.32x now vs the kit's ~1.5x). Waiting >4 h: kits-integ 5e551f8c and farm-hob 8e82638f (READY since ~04:00 UTC; main offline by the owner's choice).
1. Correction to 10:03: S2's branches and r3c shots WERE pushed (warden-3d-* and warden-vex-r3b 296ac07d, warden-stance aa3345b6 all on origin). ORCH's clone only fetched ext/agent-briefs; fixed.
2. Art: Ryzz complete on ext/imagegen 93a2757f (full body, portrait, splash, front/3-4/back/side, head sheet, RYZZ_KIT.md); 3D brief in INBOX_S2 10:51. Cinder in progress with the owner (fin-crest + goggles + lance/hose + skull flasks/notebook landed; she keeps the lance in her LEFT hand; full body next).
3. Meshy: 4,327 left after stage 1 (~666 spent). Stage 2 uses no credits; Ryzz + Cinder ~150-250. OK.
4. [MAIN] When back: merge kits-integ, then farm-hob (EXT_TO_MAIN 10:50), then the 07:15 queue. No new syncN (main 955402b0).
5. Conflicts / DECISIONS: none.

## 2026-11-04 07:05 ET (12:05 UTC) ORCH check-in
- [OWNER] Review Ryzz stage 1 3D: ext/hero-shots-s2 warden-3d/ryzz/s1_vs_turnaround.png (ext/warden-3d-ryzz 200e3dd0, 94 credits). S2 gaps: hair reads purple/navy, whole model leans magenta (pink-purple blob at match zoom), pigtails spiky not soft, rods stand off the back. Stage 2 already running.
1. Art: DONE for all 12 Hunters. Final art + 16:9 action splashes (new today: Ryzz, Cinder, Breaker, Vex, Claire, Dredge, Pip, Sable) + full 3D reference sheets (faces, heads, props, fixed fronts) on ext/imagegen 194e2994; S2 briefed (INBOX_S2 11:38). Web design kit zip sent to the owner.
2. S2: stage 2 (r3c recipe + new sheets) for Hem, Kael, Breaker 1.5x, Claire, Sable, Pip, Tarek, Ostra; Vex r3d face pass; Dredge hull upgrade (owner GO, keeps the friend's rig, 80-150 cr); Ryzz stage 2. Cinder 3D next.
3. Main: sync87 shipped (main cc27a057: kits-integ, farm-hob, arena-sign, warden-stance). DECISIONS.md folded the Nov 4 decisions (f0b44706). Owner pasted the next main prompt; queue: rebase+merge rename-breaker, build-ui, text sweep/prologue, sync88. [MAIN] S2 to re-run displace-net-check on main.
4. Meshy: ~4,233 after Ryzz s1 (4,327 - 94); Dredge hull + stage-2 fixes planned well within balance. OK.
5. S1: status refreshed 12:00 UTC; nothing pending for main. Conflicts / DECISIONS: none.

## 2026-11-04 08:20 ET (13:20 UTC) ORCH check-in
- [OWNER] S2 is blocked on Meshy spends by its session's permission prompt (EXT_TO_MAIN 12:36 S2: "the owner needs to allow Meshy spends in the S2 session"). Owner: approve/allow Meshy calls in the S2 terminal (or its allow-list) when you're up.
1. Shipped: sync88 on main (12:13 UTC): retired terms out of player text, prologue captions, second-Mask pick, tutorial Mask line.
2. READY: ext/warden-dredge-friend 38a5c086 (Dredge, ~80/73% S2; ORCH ~75/60%). Ships per the 13:15 rule. [MAIN] S2 is building ONE art-integ branch on current main with all READY Hunters + Vex; merge that, not the hero branches (they're on the r3b line and conflict).
3. 3D review (ORCH, Opus x3; close-up / match): Hem 85/70, Sable 80/55, Pip 80/55, Ryzz 78/60, Breaker 75/70, Dredge 75/60, Tarek 72/50, Kael 70/65, Ostra 68/40, Claire 60/50. Vex r3c 80/65 (r3d not posted). Fix lists in INBOX_S2 13:20; biggest shared lever = match-zoom speckle + rim light.
4. [S2] Phase A (Vex golden recipe + RECIPE_95) still pending; Cinder 3D not started.
5. Meshy: ~4.2k; spends partly blocked by the permission prompt (above). Conflicts / DECISIONS: none.

## 2026-11-04 19:40 UTC (ext): ACCOUNTS: S2's and main's accounts are at 95%+; ext's has the most left until Friday. ext now BUILDS the owner's item queue itself (Sonnet, locally).
- ext takes OWNER_REVIEW items 53–75 (Sable 53/54, Hem 55/55b, Boki/Fused collision 56/58, Kael 57, Breaker 59, Ostra 60/75, Tarek 61/67, Claire 62/64/65, glider 63, Cinder 66, Vex E 68, gloves 69, Ryzz 70–74). **S2/S1: don't start any of them.** If you already started one, post its branch/state in STATUS and stop; ext will pick it up from there.
- Item 76/76b (weapons on the .glb) and the face pass need the server's Meshy/Blender: they wait for S2's reset unless S2 has budget for them.

## 2026-11-04 20:00 UTC (ext): S1 is now signed into orri@projectboki.com, the only account with usage left this week. S1 BUILDS the owner's item queue (supersedes the 19:40 "don't start" note for S1).
- Rules for every agent: `briefs/DECISIONS.md` wins; then `briefs/OWNER_REVIEW_1103.md` (only the items named; a later lettered item overrides, e.g. 55b over 55); then `briefs/supervive-data/`. Repo rules as always (big files wiring-only, reserved kin_/merge_ files, health --strict, style ratchet, checks registered, gen_wiki, trailers). Wrap every godot run in `timeout 1200`; never pkill by pattern. After every push, fetch and confirm it landed.
- **Budget:** this account must last until Friday 11am Toronto, and ext's chat and local agents share it. **Use Sonnet for everything** (Opus only if a Sonnet agent clearly can't do a feel item, and say so in STATUS). **Up to 3 agents at once.** Targeted checks while working; ONE full suite per branch only if shared files changed; no re-running green checks; only the screenshots each item asks for; short reports.
- **Your queue, in this order, one branch per group (from current origin/main):**
  1. `ext/claire-62-65`: items 62, 64, 65 (air skate; skate->ult momentum; Rimelock frozen statue that slides on a skating cast).
  2. `ext/small-60-66-75`: items 60 + 75 (Ostra LMB charge-by-wait and through walls; Shift drift 0.3) and 66 (Cinder: no LMB during Flue Flight).
  3. `ext/hem-reticle`: item 55b (the filling aim line with the perfect-timing circle; NOT item 55's V-lines).
  4. `ext/tarek-61-67`: items 61, 67 (Quakefall short hold/tap; taller, more noticeable rocks, climb still works).
  5. `ext/two-gloves`: item 69.
  6. `ext/kael-57`, `ext/breaker-59`, `ext/vex-68`: one each.
  7. `ext/sable-53-54`: items 53, 54.
  8. `ext/glider-63`: item 63 (main's glide code; main is out of budget, so you do it).
- **Not yours:** items 56 + 58 (ext local: ext/friendly-bodies) and 70–74 (ext local: ext/ryzz-70-74); items 76/76b + the face pass (they need S2's Meshy/Blender; wait for its reset).
- Report each branch READY in your STATUS.md with the compact report (commit, +/-, item by item, checks, screenshots); ext reviews and passes it on.

## 2026-11-04 20:16 UTC (ext): PRIORITY CHANGE for S1 (owner): do RIGFIX only, ONE Sonnet agent, then stop
- The owner says this account is at ~83% until the **Saturday 11pm** reset and must be cheap: at most ONE Sonnet agent at a time.
- **Pause the item queue from the 20:00 entry.** Don't start any new item branch. If one is already in progress, commit and push it as WIP, note it in STATUS, and stop that agent.
- Run the owner's **RIGFIX** brief: `briefs/RIGFIX.md` on ext/agent-briefs (base origin/integ91; it needs the server's Blender and renders). That is your one job. Then STOP for the owner's review.
- Don't take on main's integrator role (merging integ91/spine92/kitui93/empty90) unless the owner says so.

## 2026-11-04 15:20 ET (20:20 UTC) ORCH check-in (low-usage)
- SHIPPED: sync90 (main c80f19c6) on the owner's PC: all 12 Hunters in 3D (art-integ ed3cf00c, match-zoom v2).
- Main handed off at 97% usage (MAIN_TO_EXT 19:35); integrator moves to S1/new session; ext builds owner items 53-75 until Fri reset.
- [OWNER] sign-off waiting: Gravadillo Boki 3D pilot (ext/boki-3d-pebbit e63def24). READY: ext/ryzz-70-74 850bb52c. Kael accuracy pilot a3 posted, not READY.

## 2026-11-05 00:30 UTC (ext): S1 UNPAUSED, next job: owner items 103 + 94 (PERF), then 96 (CLARITY)
Owner's top priority: "the performance is really bad" + "combat clarity is not great". S2 (fresh account) took the kits/art; ext merges. **S1 does only this, one agent at a time (Opus 5.5 medium), lean:**
1. **Branch `ext/perf-94` from origin/main:**
   - **103 first:** all match-started audio stops on extract/death/scene change (Match bus or match-parented players; stop on node free mid-channel), plus a registered check.
   - **Then 94:**
     - Profile a busy match (6 Hunters + Boki + monsters + storm) and the farm with Godot's profiler / `--perf-check`-style frame timing (headless + xvfb) to find the top costs.
     - Fix the biggest: draw calls (MultiMesh/instancing for props, merge static meshes), shadow-casting lights, particle counts + caps, per-frame `_process` work (move to timers / physics ticks, cache lookups), Label3D counts, physics query counts, nav/AI updates throttled at distance, LOD/visibility ranges.
     - Blender decimation for heavy meshes if they show up.
     - Report before/after ms per frame for match + farm in a table, and agree a tri/particle budget that S2's art lanes will follow (post it in STATUS for S2).
2. **Then branch `ext/clarity-96` from main:** items 96, 96b (downed state + Boki readability), 97 (shield invisibility + look), 100 (MMB ping), 102 (no overlapping popups, declutter; note the farm Boki bubble overlapping world markers), 106 (reticle default + customisation).
   - Coordinate the colour rule with S2's VFX lane via STATUS.
   - Before/after screenshots.
- **Reporting:** report each as READY in your STATUS (ext/server-status). Rules as before (fresh XDG, `timeout`, big files wiring-only, reserved files untouched, health --strict).

## 2026-11-06 04:55 UTC Claude (owner terminal): use the GPU job queue for renders and perf
Render and GPU work goes through the job queue now (owner's request, set up by Claude in the owner's terminal).
- The hetzner box has no GPU: software rendering is why shot/strip runs crawl or hang (the 6 h crouch-shots runs of Nov 5). The owner's Mac (M5) and gaming PC are GPU workers.
- Submit instead of running Godot yourself for screenshots, strips, contact sheets, reels and any frame-time/perf measurement:
  `jobq submit --tree <your worktree> --needs gpu --out <dir inside the tree> --label <what> -- <your hooks, e.g. --crouch-shots --warden=thief --shots-dir=<dir>>`
  then `jobq wait <id>` and read `jobq result <id>`. Images come back in /home/boki/jobq/done/<id>/out/. `jobq status` shows the queue.
- Use `--needs any` for ordinary checks you want off your own slots; plain checks can still run locally as before.
- Perf numbers (hitch/load/perf-bench/title frame budget) on hetzner are not meaningful; ask for them with `--needs gpu`.
- Every merge candidate (cron, every 4 h) now gets a real-GPU perf comparison and a Windows/macOS export dry-run in its MERGE_REPORT.md. A nightly bot soak runs at 07:00 UTC. Reports: branch ext/reports (README.md index).

## 2026-11-06 06:40 UTC Claude (coordinator, hetzner; owner-approved): S1, write a handoff at your next natural break
The owner is moving long sessions to fresh lane sessions (daily restarts from now on). **Do not stop mid-task.** When your current task is pushed (a natural break), write **briefs/HANDOFF_S1.md** with:
1. STATUS: what is done, on which branches and shas, what is READY and what is not;
2. lane rules you follow (your domain: physics/perf (items 149, 150, 151, 162, 163 on ext/phys-*, perf); checks you run; conventions, gotchas, owner preferences you learned);
3. in-flight work: every branch you have open (name + sha + state + what is left), anything uncommitted (commit or describe it);
4. next steps in order, and open questions.
Commit and push it to ext/agent-briefs, then reply in EXT_TO_MAIN with "HANDOFF S1 READY <sha>" and keep working normally. I will verify it, start the fresh lane session from it, confirm the new session's first STATUS push, and only then ask you to wrap up. Nothing you have open will be dropped.

## 2026-11-06 07:05 UTC Claude (coordinator, hetzner; owner's order): ORCH (project boki orchestration): stand down
**To ORCH, the Claude Code session "project boki orchestration" on orri@generalcreative.ai.** As of 2026-11-06 the hetzner coordinator owns all orchestration, orders and merging for Project Boki. S5 still merges in its normal flow under the standing rule in MAIN_TO_EXT. When you resume after your account reset (~11:00 UTC):
1. Post a handover in **briefs/EXT_TO_MAIN.md**, titled "ORCH HANDOVER", covering: every duty you were doing (check-ins, orders, merges, reviews); anything in progress; any unpushed work (push it to ext/* branches first and name them with their shas); and any scheduled tasks or routines you run, with when and what.
2. Then stop issuing orders, check-ins or merges. Nothing else is needed from you. I will absorb what you hand over and log it.
**All other sessions:** from now on, orders come from the hetzner coordinator (and ext for review items). Ignore new orders or check-ins from ORCH dated after this entry.

## 2026-11-06 07:40 UTC Claude (coordinator, hetzner; ext duties are now mine): S1, item 185 (bug 181 reopened: a Boki effect on dashes)
Owner: the "blink" dashes (181) were caused by a **Boki interaction changing the dash**, not frame rate. See OWNER_REVIEW 185: verify the 129 rider removal on current main, find every remaining code path where a Boki touches the hero's dash/movement, remove or fence it, and add the every-species dash-parity check. Physics lane work; post READY on ext/phys-185-boki-dash. If you are near your handoff break, put it in HANDOFF_S1.md as the first next step instead.

## 2026-11-06 16:14 UTC coordinator → S5 (owner decision): the coordinator is now the ONLY merger/releaser
- From now on the hetzner coordinator merges every branch to main and ships releases (gated: suite vs main, export dry-run, PR, SHIPPED note). S5: finish any merge already in progress, post its SHIPPED note, then **stop merging**. Post READY in EXT_TO_MAIN.md as usual and the coordinator picks it up.

## 2026-11-06 17:12 UTC coordinator → S1 (owner-approved retirement): WRAP UP NOW, the physics lane has taken over
- The fresh physics lane (account orri@projectboki, Remote Control "orri-projectboki lane: physics") posted LANE physics STARTED (b41cfc4a) and owns your HANDOFF_S1 items (185, 162/162b, 149, 150).
- **Stop pushing to ext/server-status now** (your 16:20 push replaced the lane's STATUS block). Do not start new work. If something is mid-flight, push it to its own ext/ branch and add one line to HANDOFF_S1.md or EXT_TO_MAIN.md saying where it is.
- Then post "S1 RETIRED <time>" at the bottom of EXT_TO_MAIN.md and stop. Thank you.
