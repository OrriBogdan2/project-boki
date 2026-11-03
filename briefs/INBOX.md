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

## 2026-11-02 23:45 UTC
Body, scale and movement sections are now in for **all 12** hunters (bjorn, pin, dancer, juggernaut/Zedran, vireo, venator just added). Fold them into each pair's polish pass:
- **Scale targets:** bjorn ~1.15 tall / 1.35 wide; pin ~0.98; dancer ~0.95; Zedran ~1.12, hunched; vireo ~0.96 with a wider upper body; venator 1.0 (unchanged). Hitbox radius 0.37 for pin and vireo if scaled up.
- **Dashes:**
  - Bjorn's Smash run-up: ~0.17 s at ~20 m/s, ~5 m, moving through the spin.
  - Dancer's Cartwheel: ~4.5 m sideways flip; from the air it holds ~2× run speed to the landing, ~8 m.
  - Zedran's Quick Dash: 0.15–0.2 s crouch, a ~0.3 s streak covering 4.3–5.8 m, ~0.35 s low recovery.
  - Vireo's Surge: a constant ~30–35 m/s, so its duration scales with distance.
  - Venator's tap slide: a ~0.45 s decelerating skid peaking at ~17 m/s, ~4.8 m.
  - Pin's roll flows straight into the crouched Spirit Walk run (×1.1 speed).
- **Running poses:** Bjorn pitches forward, shield shoulder first; Dancer leans hard forward; Vireo runs upright with her arms out wide.
- **Per-hero nameplate offsets** are in each sheet. hud.gd's fixed +2.35 m belongs to ext/hudref, so expose a per-hunter offset hook rather than editing hud.gd yourselves.
- **Global** (main's call, don't change it in kit branches): the source run speed is the same for every hunter (3.9–4.4 m/s), with short, quick steps (~2.3 strides/s). That's been sent to the main session.

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

## 2026-11-03 02:30 UTC: KIT REVIEW round 2 (8 polished hunters). Small fixes, then ready
The reviews are in briefs/kit-review/round2/. **PASS (minor nits): Pin, Bjorn, Vireo, Linwick, Moosh Moosh. FIX: Venator, Dredge, Tamsin.** Fix these on the same branches (Opus), then report ready:
- **All branches: no hard-coded key letters.** kit_card.gd says "ready for the Merge on R" on pin-bjorn (line 309) and moosh-tamsin (line 308). ashwick.json lines 8 and 26 and dredge.json line 8 hard-code "X". Use `Settings.key_cap("ultimate")` / `key_cap("hunter_ult")`. Merge is on **C** now (owner, 02:05).
- **pin-bjorn:** only the key-text fix is needed, then report ready. Optional nits: a stronger spin trail on Bjorn; his ult slam folds him head-down (pitch 0.75), so cap it at about 0.4.
- **vireo-venator:** Venator's new ember after-image on the slide draws as an opaque salmon blob over his body. Make it a translucent trail behind him: alpha, depth sorting, offset. Nit: a white glow ball at Vireo's hand on the first firing frame; tint it.
- **linwick-dredge:** Dredge's ult slug waves can't be seen at gameplay zoom, and the fan telegraph is near-white. Use bigger, saturated slug projectiles with trails and a coloured fan. Plus the X text fix.
- **moosh-tamsin:** Tamsin's skate lean stacks with the shared light-dash lean to about 60°, so she lies nearly flat. Clamp the combined lean to about 20-25°. Her Ice Spear still reads white; colour it ice-blue. Plus the Merge text fix. Nit: brighten Moosh Moosh's shot in flight.
- **For whoever merges second and later:** the branches use three different hooks for per-hunter nameplate height. Converge on ext/hudref's `HudPlate.plate_offset(h)`, which reads `plate_offset` from the archetype JSON.

## 2026-11-03 02:20 UTC: owner answers
- **moosh-tamsin:** Moosh Moosh's air glide goes to the **source distance, about 11–15 m (start at 12 m)**. The owner's rule is "go to the source where possible". Data only; update the check bound.
- **General rule for every kit pass:** where a number or behaviour is an open call, go to the source.

## 2026-11-03 02:45 UTC: MODEL SWITCH (owner: usage at 75% this week)
The video-understanding work is done: every reference sheet is written. From now on:
- **Let running Opus agents finish**: the round-2 fix passes, breah-ostra polish and the ext/classes rework. Don't restart them, since that would waste what's already spent.
- **Every new agent you start uses Sonnet**, including further kit fix rounds, re-merges, test runs and ult tweaks. The reference sheets and review fix lists are concrete enough for Sonnet.
- Exception: if a fix is mainly about judging art against the source footage and Sonnet fails it twice, report it in STATUS.md instead of escalating it yourself.
- **Run fewer redundant full suites.** Run the targeted checks plus one full suite at the end of each branch.

## 2026-11-03 04:20 UTC
New: **briefs/SERVER_UPDATE7.md**, a kit data pass from the owner's game data (Sonnet, at most 2 at once). Start when slots free up. Order: dancer-juggernaut and pin-bjorn first (on ext/kitdata-<pair> from main if they're already merged), then the other four on their kitfix branches before they land.

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

## 2026-11-03 05:25 UTC: all six kitfix pairs are reported ready to main. SERVER_UPDATE7 runs as follow-ups
Change to SERVER_UPDATE7: **do every data pass as an `ext/kitdata-<pair>` branch from origin/main**, after that pair is merged (or from its kitfix head if main hasn't merged it yet). Don't add commits to the kitfix branches now; they're frozen for merging. Order: dancer-juggernaut, pin-bjorn, linwick-dredge, moosh-tamsin, vireo-venator, breah-ostra. Sonnet, at most 2 at once. The review files in briefs/kit-review/round2/ list extra data-pass items per hunter.

## 2026-11-03 06:20 UTC
1. **Small fix (Sonnet), branch ext/airdash-glide from origin/main (sync75):** main reports that Venator's Slipstep in the air loses all momentum when it opens the glide. Dash-glide open speed is 3.3 m/s, against 13.8 with the class dash. Moosh Moosh's air glide is also low. Make every kit air dash carry its speed into the glide, the same way the class dash does, and add a kit-level check for all 12 hunters (an air dash into a glide keeps at least X% of the dash speed). Report ready in STATUS.md.
2. **Farm tutorial and builder plans:** waiting on owner answers. I'm putting the questions to him now; don't build yet.
3. The bigger map is now a separate, harder map for higher tiers (owner, 23:25 ET). The Hollow Crown stays. Nothing to do before the resets.

## 2026-11-03 06:25 UTC: OWNER PLAYTEST REVIEW (sync75). Running list in briefs/OWNER_REVIEW_1103.md
The owner is reviewing the build now and will add more. Start the two items there (Sonnet, at most 2 agents): (1) Venator's grenade hits hunters and the debuff, (2) remove the ambiguous 1-block walls from practice areas and The Hollow Crown. Re-read the file before each new item; it's being added to.

## 2026-11-03 06:58 UTC: OWNER_REVIEW items 25-39 added; item 39 "scope now" is taken locally
- OWNER_REVIEW_1103.md now has items 1-39; keep working through them in order (Sonnet; item 22 on Opus). Items 32 and 35 are cross-hero passes: do them per hero pair, together with that hero's other items.
- Item 39's rename (ext/class-titles) is being done by ext locally. Skip it on the server; items 34, 37 and 39's looks are for the concept pass later.

## 2026-11-03 07:00 UTC: correction, item 39 rename is ON HOLD
- The owner stopped the local class-titles agent. Don't start item 39's rename on the server either until ext says go. Item 40 (Ostra RMB) is new; it goes with the Ostra items.

## 2026-11-03 07:05 UTC: owner OKs Opus at discretion for hard kits; work order for items 1-43
- **Model rule update (owner):** default stays Sonnet, but if a hero's items are complex or a Sonnet agent shows it doesn't understand the source mechanic (Zedran's Warchain is the example), switch that hero's work to Opus 5.5 medium. Say in STATUS.md which heroes went to Opus and why.
- **Order:** (1) bugs first: item 26 (Breah RMB->glide drop), item 42 (Ostra Shift range), the airdash-glide fix. (2) Then per hero pair, each hero's items together with its rows of items 32 (dash->ability flow) and 35 (own dash animation). Suggested pairs: Zedran+Bjorn (Opus for Zedran), Breah+Ostra, Tamsin+Dredge, Linwick+Moosh Moosh, Pin+Venator, Vireo+Dancer. (3) Item 2 map clean-up whenever a slot is free.
- Item 43's prologue and item 39's rename are ext's (local). Don't start them.

## 2026-11-03 07:15 UTC: a second server session (S2, new account) is joining; work split
- S2 takes these hero pairs with all their OWNER_REVIEW items (incl. their rows of 32/35): Breah + Ostra (incl. bugs 26 and 42), Zedran + Bjorn, Tamsin + Dredge, Linwick + Moosh Moosh. See briefs/SERVER2_START.md.
- S1 (you) keeps: the airdash-glide fix, item 2 mapclean, Pin + Venator, Vireo + Dancer, the farm tutorial. If you already started any of S2's items, finish and push that branch, note it in STATUS.md, and S2 will build on it.
- The godot queue is shared; S2 may raise it to 8 slots on this 16-CPU box.

## 2026-11-03 07:20 UTC: owner demo tomorrow, quality first
- The owner is showing the game to someone tomorrow. Goal: speed AND quality. Finish fewer things completely rather than many halfway.
- Each branch must land whole: every item on it done, asserted, screenshots viewed, full suite green, then reported ready in STATUS. No half-done branches at the cutoff.
- Within your share, do bugs first, then the items a player notices in the first minutes of play: the look and feel of RMB/E/ult, the dashes, and obvious glitches. Leave subtle tuning for later.
- A delivery cutoff time will follow once the owner gives the demo time.

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
