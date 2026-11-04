# Inbox for the second server session (S2)
## 2026-11-03 07:15 UTC: start
- Read briefs/SERVER2_START.md and begin with Breah + Ostra (bugs 26 and 42 first).

## 2026-11-03 07:20 UTC: owner demo tomorrow, quality first
- The owner is showing the game to someone tomorrow. Goal: speed AND quality. Finish fewer things completely rather than many halfway.
- Each branch must land whole: every item on it done, asserted, screenshots viewed, full suite green, then reported ready in STATUS. No half-done branches at the cutoff.
- Within your share, do bugs first, then the items a player notices in the first minutes of play: the look and feel of RMB/E/ult, the dashes, and obvious glitches. Leave subtle tuning for later.
- A delivery cutoff time will follow once the owner gives the demo time.

## 2026-11-03 07:25 UTC: CUTOFF 2026-11-03 21:00 UTC (4 pm Toronto)
- The owner records the demo tonight. Every branch you want in it must be reported READY in your STATUS by 21:00 UTC today, so main can merge and the owner can play it before recording.
- Plan your pairs to fit: anything that can't land whole by then goes after the cutoff on its own branch. Report at ~15:00 UTC which pairs will make it.

## 2026-11-03 07:30 UTC: S2 takes more (your account has the most budget)
- The other two accounts are at ~75-80% for the week; yours is fresh. **You now also own Pin + Venator and Vireo + Dancer** (all their OWNER_REVIEW items, incl. item 1 Venator grenade, 4, 5, 6, 8, 9) unless S1's STATUS shows one of those branches already in progress; in that case S1 finishes it.
- Raise your limit to **6 agents at once**. Suggested: one agent per pair (6 pairs), Opus 5.5 medium for Zedran; Sonnet elsewhere unless an agent misreads the source mechanic.
- Efficiency rules for every agent: read only the files you need; targeted checks while working and ONE full suite at the end; no re-running green checks; screenshots only for the listed items; short reports.

## 2026-11-03 07:45 UTC: NEW TASK for S2: prologue quality pass ("animated shorts"), demo-visible; 1 agent, Opus 5.5 medium allowed
- Branch `ext/prologue-polish` from `origin/ext/prologue5` (54f83040: the owner-approved 5-slide prologue in scripts/ui/prologue.gd, text final; don't change the text or the slide count). Main is merging prologue5 as-is; this polish lands on top.
- Owner: the scenes must feel higher quality, like animated shorts. Specific bug: in THE BOKI slide the first Boki clips into the hunter (it overlaps his legs and rifle), and another Boki is cut off at the bottom-right edge. Fix placement so nothing overlaps or is cut off by the frame unless that's intended.
- Raise each slide to short-film quality with what's in the engine (no new imported art):
  - Deliberate framing per shot: a clear subject, foreground/background layers, no clipping, nothing awkwardly cut by the frame.
  - Motivated camera moves (slow push-ins, parallax, one cut or reframe inside a slide where it helps) with eased motion; no linear drift.
  - Characters and Boki animate with intent: idles, looks, reactions (Boki hop up to greet the hunter, the hunter kneels or reaches out), staggered timing; nothing frozen in a T-pose or default pose.
  - Lighting and mood per beat: warm golden BEFORE THE FALL, red fire and shake for THE WAKING, falling debris and drifting dust for THE SUNDERING, soft morning light for THE BOKI, mystery glow for THE RACE. Use existing environment, fog, light and particle tools.
  - Polish the transitions between slides, and keep the text readable over every frame.
- Keep it lean: reuse Models, Look and existing scene code; delete what you replace; health --strict with no budget raised.
- Deliver: a 5-frame strip per slide (start, middle, end, plus 2 key beats) at 1280x720 in shots, viewed by you; the targeted checks (--class-unlock-check covers prologue -> hatch); health, gen_wiki --check. Report it READY in STATUS before the 21:00 UTC cutoff; ext reviews the strips.

## 2026-11-03 07:50 UTC: prologue-polish: two text lines change (owner wants the Mantles explained)
- In ext/prologue-polish, change slides 3 and 4 to (keep 5 slides; the rest of the text stays):
  - 3 THE SUNDERING: "It broke the land into a thousand isles.\nThe Wardens who stood against it fell, and their power scattered as Mantles."
  - 4 THE BOKI: "On the broken isles, survivors found the Boki.\nA hunter bonded to one could wake a fallen Warden's Mantle."
- Stage slide 4 to show it: the hunter kneels and the Boki touches the relic he wears (or holds), and it wakes with a glow in his class colour. Use existing glow/particle tools.

## 2026-11-03 07:55 UTC: NEW TASK for S2: character concept pass, phase 1 (Opus 5.5 medium, 1 agent; NOT for tonight's demo, lower priority than the hero pairs and prologue-polish)
- Owner: we need high-quality art of all 12 original Wardens (the base characters), aiming at the quality bar of top hero-shooter / MOBA character art. We're well below that today.
- Spec: `briefs/specs/CONCEPT_PASS.md`, and in `briefs/OWNER_REVIEW_1103.md` items 18, 34, 37, 39 (titles, base names, genders, looks), 41 (Bjorn: undead ferryman with a frozen ship-prow shield; Ostra and Tamsin must move further from their source looks), 43-44 (story: Wardens, Mantles, Wyrm). Obey item 39's originality guard strictly: mood references only, no signature features of any existing character.
- Phase 1 deliverable, branch `ext/concepts` (docs/art only, no game code): for each of the 12, one concept sheet as a hand-authored, layered SVG (render a PNG of each too):
  - front and 3/4 view, full body, a clear silhouette that reads at gameplay zoom (test: the 12 silhouettes filled black side by side are all identifiable);
  - a palette strip, the relic (their Mantle object), a face/bust close-up for the portrait;
  - 3 bullet notes: shape language, signature features, how it reads in-engine.
  Put them in `docs/art/concepts/<id>.svg|png` plus one `docs/art/concepts/lineup.png` (all 12 side by side, plus the silhouette row).
- Quality bar: deliberate shape language (big/medium/small shapes), strong silhouettes, consistent proportions and line weight across the roster, real lighting and shading (not flat fills), and appeal. Iterate: render, view, critique against the bar, redo. Two strong sheets beat twelve weak ones; if time runs short, deliver fewer, finished.
- Order: Bjorn, Pin, Zedran, Cinder, Ostra, Tarek first (the owner described these most), then the rest.
- Report in STATUS with the lineup PNG path; ext reviews and takes it to the owner for approval before any in-engine modelling (phase 2).

## 2026-11-03 08:00 UTC: hero pairs on Opus; use the footage studies
- Owner: getting the hero fixes right matters most. **Run every hero-pair agent on Opus 5.5 medium** (not just Zedran).
- Every hero agent must read, for its heroes, the frame-by-frame footage study in `briefs/hero-ref/<hero>.md` (timings in frames at 5 fps, poses, reticles, VFX, gaps vs ours) alongside `briefs/supervive-data/`. Precedence: owner notes > game data > footage.
- The raw footage itself is coming to the server (ext is arranging it with the owner): when it lands, the path will be posted here. Keep any frames or video OUTSIDE the repo (never commit them); describe, don't copy, in code and docs.

## 2026-11-03 08:05 UTC: the owner's bar for every hero agent
- The main thing (owner): **everything accurate to the source game, and animations and art improved drastically.** Accuracy: every ability's input, timing, range, aim, cancel rules and interactions match the source data and footage, asserted in checks. Animation: each move gets a deliberate, readable, weighty animation (anticipation, action, follow-through, recovery), not a tweak of the shared one. Art/VFX: each effect clearly readable, in the hero's own colours, at the quality of a polished hero shooter.
- Agents check their own work against `briefs/hero-ref/<hero>.md` frame timings and view their screenshot strips before reporting; anything that doesn't meet the bar gets redone, not reported.
- Footage: the owner will give you the YouTube links directly. Download them with yt-dlp outside the repo (e.g. ~/svvid), cut frames with ffmpeg (-nostdin) at 5 fps around each hero's section, and keep them out of git.

## 2026-11-03 08:10 UTC: NEW TASK for S2: the Mantle look + character creator (OWNER_REVIEW item 45). Opus 5.5 medium, 1 agent. After the hero pairs and prologue-polish are underway; not required for tonight.
- Branch `ext/mantle-look` from origin/main. Build item 45 against today's hunter models (it must plug into the concept-pass models later without rework). models.gd/home.gd/main.gd are main's: wiring only, logic in new files (e.g. scripts/hero/mantle_look.gd, scripts/ui/creator_panel.gd). Save fields need a migration with defaults (current players get a neutral look).
- The new-game flow already has a name card: extend it into the creator (or add one step after it). Keep it quick to finish for players who don't care: a "Randomise" button and sensible defaults.

## 2026-11-03 08:00 UTC (git time): ownership and a conflict
- **Bjorn:** S1 finishes only the Bjorn items it already began on ext/kitdata-pin-bjorn and lists them in its STATUS. **S2 owns everything else for Bjorn** (whatever of 10/29/30 is left, plus his 32/35 rows): build on S1's push when it lands; don't wait idle, start Zedran-side work meanwhile.
- **Pin, Vireo, Venator stay with S1** (already in progress there). Dancer is S2's.
- **Mantle look (item 45) conflict:** main's ext/classes removed the old creator card and moved the name entry onto the Boki card. Put the creator as its own new step after the Boki card (name stays where it is now), not as an edit of a removed card.
- Use git commit time when you write hours in STATUS (your clock reads ~1 h ahead).

## 2026-11-03 08:02 UTC: known-red checks, don't chase
- `--pack-ui-check`, `--simtest` and `--train-check` are known red/flaky on main (see COMMON rules); `--teammate-check` flakes under load. Don't spend reruns on them: note them as pre-existing in your report and move on.

## 2026-11-03 14:10 UTC (orchestrator): re-check your READY branches on main's physics pass
- Main landed physics76 (4d39c623: new gravity, ~0.9 s jump hang, ledge top-out). Your six READY branches sit on 16dd7fa, before it. Merge 4d39c623 into each, re-run that hero's combo checks + --dash-flow-check (targeted, not the full suite), and re-post the tips in STATUS. Watch Breah's hop, Zedran's air slam, Moosh Moosh's 3x glide ratio, and the Tamsin/Dredge/Ostra z-holds.

## 2026-11-03 14:25 UTC: main moved (physics76 landed, 4d39c623): pre-merge it into the demo branches
- Main merged its physics pass (gravity/jump/air control/ledges/glide) as 4d39c623 but hasn't started the demo merges yet. To save main time before the 21:00 UTC cutoff, merge origin/main 4d39c623 into each demo branch in the plan (dash-flow-base, review-breah-ostra, review-linwick-moosh, review-dancer, review-bjorn, prologue-polish; and S1's kitdata-vireo-venator, airdash-glide, mapclean if S1 isn't doing it), resolve conflicts, re-run the targeted checks for that branch (hero combo, dash-flow, move-feel, airdash-glide, class-unlock, archetype, keys) plus health, push, and update the commits in your FOR MAIN plan. Watch for physics76 changing glide/air-dash handoff values that the airdash-glide and dash-flow checks assert.
- Post the updated plan by 17:00 UTC.

## 2026-11-03 16:00 UTC: push your trial integration as ONE branch
- Excellent work. Push the trial integration you ran (main 4d39c623 + the six S2 branches + S1's airdash-glide 411a591 + kitdata-vireo-venator 67454b5, in plan order, generated files regenerated) as `ext/demo-integ`, and add S1's ext/mapclean 2082d0d if it merges clean and --wall-size-check passes. Run the full suite once on it (known-red checks noted, not chased). Put the commit and results at the top of your FOR MAIN section. Main can then merge one branch.

## 2026-11-03 16:05 UTC (orchestrator): demo-integ, use mapclean caf5deb
- For ext/demo-integ, take ext/mapclean at **caf5deb** (S1 re-merged it on 4d39c623, breakables conflict resolved, READY 15:00 UTC), not 2082d0d.

## 2026-11-03 16:10 UTC: owner approved the concepts; new queue (after ext/demo-integ's full suite is posted)
Owner on ext/concepts: "concepts are good, obviously a bit too shape-y and needs a good amount of polish". Specific: **Ostra more menacing; Moosh Moosh cuter**; polish everyone.
1. **Concepts 1b (Opus, 1 agent), on ext/concepts:** a polish pass on all 12 sheets: less geometric, more organic forms (tapered limbs, overlapping cloth and armour, varied curves, secondary detail where the eye lands), richer shading and rim light, expressive faces and poses. Ostra: more menacing (taller, sharper, a grin that unsettles, long fingers, a darker palette with sickly violet light), never the source's look. Moosh Moosh: cuter (bigger head and eyes, shorter limbs, rounder shapes, a bigger tail, a happier pose). Keep each silhouette identifiable. Redo the lineup. Report for owner review.
2. **Concept phase 2 (Opus), starting with the approved shapes (don't wait for 1b's polish on the silhouettes):** build the in-engine Warden models from the sheets, one hero at a time, starting with Bjorn, Pin and Zedran, on `ext/warden-models` from main: hero-quality proportions, materials, signature pieces, and nothing breaking hitboxes, animations or kit FX anchors. Each hero: a turnaround strip at gameplay zoom and close-up, next to its sheet. Models.hunter changes stay wiring-only (models.gd is main's): put the builders in new files. Fit item 45's MantleLook so the creator sliders apply on top.
3. **Dancer feel pass (item 7), Sonnet or Opus at your call:** her dash and dash-empowered autos to the source (data + footage + hero-ref), with item 32/35 rows.
4. **Finish ext/class-titles** (de196566, ext's stopped agent): merge main, take the screenshots (hero picker, "<player> the <title>" in a match and kill feed, a wiki page), run the final suite, report READY. Sonnet.
5. Then the post-reset work, in this order, one agent each: ext/drop, ext/market (incl. Black Market with a Ransom tab and rare stock), and the higher-tier map (briefs/specs/BIGGER_MAP.md as amended by MAIN_TO_EXT 23:25 ET: a separate map for higher tiers; The Hollow Crown stays the beginner map).
Keep up to 6 agents. Don't start anything that touches the demo branches until main has merged ext/demo-integ.

## 2026-11-03 16:15 UTC: more owner notes for concepts 1b (and the phase-2 models)
- **Cinder doesn't read as a salamander.** Make her unmistakably salamander-folk, distinct and cool: a reptilian head shape (wide, rounded snout, lidless-looking eyes with slit pupils, no human nose or ears), visibly scaled skin with ember speckles that glow, a dorsal crest or frill that flares, four-fingered hands, a long thick tail, digitigrade or splayed feet. Keep her mad-chemist kit (cracked goggles, apron, flask bandoliers) and give her a sly, gleeful attitude. She should be one of the coolest-looking in the lineup.
- **Tamsin (Icy Dancer): a pro female skater, younger-looking than her source** (late teens / early 20s). An athletic competition skater's build and posture, a sleek fitted performance costume in our own ice palette, skates as the clear signature, hair tied back for speed, confident and graceful pose (a spin or glide). Not a mage in robes; and not resembling the source's costume or face.

## 2026-11-03 16:20 UTC: concepts 1b: real height and build variety
- Owner: the Wardens should be clearly different heights and builds. Today most stand the same height. Spread them on one scale, e.g. Moosh Moosh ~0.6 of a standard hunter, Tarek and Sable lean and average, Tamsin slight and tall-ish, Cinder low and hunched with a long tail, Zedran and Venator broad, Bjorn and Dredge the biggest (Dredge hulking, Bjorn tallest-widest), Ostra tall and thin, floating. Show it in the lineup with a height scale. Gameplay hitboxes stay per class; this is visual.
- Owner wants the quality much higher, aiming at top-MOBA level. Push as far as the medium allows; ext is discussing art pipeline options with the owner separately.

## 2026-11-03 16:25 UTC: OWNER_REVIEW item 46 (hitbox by size + ground circle): queue it after main merges ext/demo-integ; Sonnet, small. Set the hit_r values together with the concept heights (1b).

## 2026-11-03 16:30 UTC: owner approves a Blender pipeline for the Warden models (replaces item 2 of the 16:10 queue's approach)
- Install Blender (latest LTS, official Linux tarball into ~/tools, no root needed) on the server. Build the Warden models with scripted Blender (bpy), Opus 5.5 medium, starting with **Bjorn**, then Pin, Zedran, Cinder:
  - real meshes: base forms blocked from the concept sheets, then subdivision surface, sculpt-style deformation (displace/shrinkwrap, smooth), bevelled hard-surface armour, cloth folds; stylised toon-friendly topology that reads top-down;
  - textures: hand-painted look via baked procedural shaders (gradients, AO, edge wear, rim highlights) into a single atlas per hero; matching the game's toon shader;
  - rig with a shared humanoid armature (Rigify or our own) so HunterAnim moves map onto bones; export glTF (.glb) into the repo under art/wardens/<id>/ with a small import note; Godot loads them through a new builder file (models.gd wiring only).
  - Budget per hero: a turnaround render (front/side/3-4/back) in Blender plus an in-engine shot at gameplay zoom and close-up, next to the concept sheet. Ext reviews Bjorn's before the others go ahead.
- Keep the old procedural model as the fallback until a hero's .glb passes review. Hitbox and FX anchors unchanged.

## 2026-11-03 17:00 UTC: queue OWNER_REVIEW item 47 (dash/stamina fill-up bar), Sonnet, after demo-integ is in main (it is: main 31ef8481). Small UI job; build it on a branch from current main.

## 2026-11-03 17:20 UTC: OWNER_REVIEW item 48 (Bjorn's ult: free after the slam). Small; on a branch from current main. Sonnet.

## 2026-11-03 17:25 UTC: OWNER_REVIEW item 49 (Bjorn perfect-timed LMB launch into glide). Do it together with item 48 on one Bjorn branch from current main. Opus (feel matters).

## 2026-11-03 18:05 UTC: two owner RULES, high priority after items 48/49: OWNER_REVIEW item 50 (screen shake almost never; never self-caused; settings slider) and item 51 (every ability combos with jump/Shift; holds survive jumps and dashes; extend DashFlow with jump/hold rows for all 12). Item 51 supersedes item 30's "dash ends the hold" for Bjorn; do 48/49/51 for Bjorn together. Item 50 is one cross-cutting agent (Sonnet is fine); item 51 is Opus (it touches every kit's feel), one agent per 2-3 heroes if you want it fast.

## 2026-11-03 18:30 UTC: ext takes items 46 and 47 locally
- **Skip OWNER_REVIEW items 46 (hitbox by size + ground circle) and 47 (dash/stamina fill-up bar)**: ext is building them on its own account (branches ext/hitbox-ring and ext/stamina-bar from main a3fc5b95). If you already started either, say so in STATUS and ext will stop its copy.
- For 46, ext uses default sizes; when concepts 1b settles the heights, post the per-Warden size order in STATUS and ext tunes hit_r.

## 2026-11-03 18:20 UTC (orchestrator): owner decisions for your hero branches. Full text in INBOX.md 13:20 ET
- **Ostra ult:** ~1 s cast lock (like Void), then free to move while Nightwell runs (replaces the full 4.5 s lock).
- **Tamsin ult:** skating into the ult carries her forward a decent distance; then she's encased in ice and rooted (no sliding) until it ends or she cancels early.
- **Moosh Moosh:** copy Elluna's dash and glide (source values); drop the 3x rule.
- **Dash buffering:** yes; follow the source where known, else your held-to-dash-end default.
- Names Sable/Cinder/Tarek confirmed. At home the player is their own custom person.
- Small, on a branch from current main, after the demo build ships. Sonnet unless the feel needs Opus.

## 2026-11-03 18:45 UTC (orchestrator): owner wants animation + ability parity with the source, all 12, LMB first
- Owner: "match much closer to SUPERVIVE, such as Celeste LMB, and how it tracks when using her ice trail ... all animations and abilities closer to feature parity." Per hero: LMB animation, aim/tracking (Tamsin's LMB while skating), cadence; then the other abilities. Use the footage + hero-ref + data; our own art. Assert the behaviour. After the demo build ships. Details: INBOX.md 13:45 ET.
## 2026-11-03 18:52 UTC (MAIN): FARM TUTORIAL QUESTIONS ARE ALREADY ANSWERED. Stop asking the owner.
The answers are in briefs/DECISIONS.md ("Farm and onboarding") and MAIN_TO_EXT 2026-11-03 10:50 ET:
- Builder: **Hob Brackenridge**.
- The house **costs a little wood**. The tutorial gives an **axe** and teaches chopping (with an animation), then **assigning a Boki** to a task.
- **Yes, a hammer swing** helps build. Every starter Boki can build; species get task skills.
- **Keep** the first-day gem bonus as one end reward.
- **Strict.** The house/farm tutorial can't be skipped on a new save; the fighting tutorial can be.
- **Yes,** the top-right day-1 card becomes "Goals".
Every agent: read briefs/DECISIONS.md before asking the owner anything.

## 2026-11-03 19:20 UTC (orchestrator): model choice + squad decision
- Owner: use Opus 5.5 for anything feel-critical, source-parity, cross-hero or design-heavy; Sonnet only for small, clear fixes it will get right. Redo on Opus rather than ship below the bar.
- Extraction is one queue of auto-filled trios (no solo/duo queue). Details: INBOX.md 14:20 ET.

## 2026-11-03 19:50 UTC (orchestrator): OWNER clarifications, Claire RMB + dash buffering
- **Claire's RMB (replaces item 28's "throw"):** owner: "push" is the motion, not a literal push. The ice spear **emerges from Claire** and travels out to the target point; **the further it goes, the longer the travel time**. Her animation is **push-like** (arms or palms driving forward), **not a throw** (no arm-back wind-up, no throwing release). Item 13's heavy landing, slow zone and delayed detonation stay. Assert: travel time grows with distance; it starts at her and doesn't spawn at the target.
- **Dash buffering:** owner: "whatever SUPERVIVE does." Check briefs/supervive-data (nothing found under "buffer") and the footage: what happens to presses made during a dash in the source (fires on dash end, fires mid-dash, or lost after a window)? Match that per hero in DashFlow, and write the finding and its source into docs/decisions/0010 and the dash_interactions table. Until you know, keep your current default.
- Name: Tamsin is now **Claire** (DECISIONS.md).

## 2026-11-03 20:10 UTC (MAIN, owner asked): KICK OFF THE 12 WARDEN 3D MODELS on ext/warden-models
The image-gen session's art lands on **origin/ext/imagegen** (30 commits; main is pushing it now: all 12 Warden turnarounds, splashes, portraits, 12 texture sheets, and STYLE.md / index.md / IMG_STATUS.md).
1. **Model all 12 Wardens** from `docs/art/gen/wardens/<name>_turnaround.png`. Use the splash and portrait for detail, and `docs/art/gen/textures/<name>_materials.png` for materials. Follow `docs/art/gen/STYLE.md`.
2. **Known turnaround flaws** are listed in `docs/art/gen/index.md` (e.g. Zedran's back view is missing his cleaver). Fix them in the model, not by copying the flaw.
3. **Renames:** Tamsin is now **Claire**, and Venator is now **Vex** (see DECISIONS.md).
4. **Pipeline:** use your branch's agreed rigged Blender export format, the loader (replace the stub), and the size check against the concept-sheet heights. Replace the Bjorn and Pin placeholders built from old sheets with ones from the new turnarounds.
5. **Prototype first:** **Vex** (everyone's first Warden) end to end, through rig, in-game swap and a gameplay-zoom screenshot. Keep the procedural rig as the fallback per hero, behind a setting. Then the owner reviews, then the remaining 11.
6. **Image-to-3D is allowed as a head start** (a rough mesh from the turnaround), but clean-up, retopology and rigging are required before anything goes in game. KMoves must retarget onto the skeleton.
7. **Opus** (design, cross-hero work). Post READY with screenshots in EXT_TO_MAIN.

## 2026-11-03 20:20 UTC (MAIN, owner): the 2D Warden portraits go in EARLY, before the 3D models
- Use the new art from origin/ext/imagegen (`docs/art/gen/wardens/<name>_portrait.png`, and the splash where a bigger image fits) in the **menus now**: character select / Mantle pick, the hunter viewer, the kit card, and the HUD portrait slot. Use ext/portrait's frame/HUD side (DECISIONS: "portraits come from the art pass; ext/portrait keeps only its frame/HUD side").
- Replace the procedural portrait renders with these images for all 12. Keep the procedural render as a fallback if an image is missing. Use the new names (Vex, Claire).
- Small and separate from the models: a branch like `ext/portraits-2d` off main, rebased on main. Checks: uipolish, hunter-unlock, class-unlock, hudref. Post READY in EXT_TO_MAIN with a screenshot of character select. Main merges it at the next check-in.

## 2026-11-03 20:35 UTC: fold the Claire rename into ext/class-titles (MAIN_TO_EXT 18:20 UTC)
- Owner renamed Tamsin to **Claire** (rimewright). Main asked for it inside ext/class-titles: base name Claire, everywhere (HeroKit names, archetype text, kit cards, tooltips, docs/heroes, wiki). The title stays "Icy Dancer". Push and post the new commit as READY. Also read briefs/DECISIONS.md (it overrides older items: Claire's RMB is a push-like emerge, not a throw; Moosh Moosh's dashes copy Elluna, the 3x rule is dropped; Ostra's ult has a ~1 s lock, then he moves).
- Your ext/stamina-bar and ext/hitbox-size: reported to main as READY (main had planned to build them itself).

## 2026-11-03 20:35 UTC (MAIN): the portrait IMAGES are done; only wiring them in is left. Names to use
- All 12 `docs/art/gen/wardens/<name>_portrait.png` (2048²) are on origin/ext/imagegen. ext/portraits-2d only has to downscale them (e.g. 512² webp/png into assets) and wire them into the screens. This is a small job: please do it next, before the models, so it ships in tonight's next sync.
- File names use the new names. Mapping (also in DECISIONS.md):
  - vex = gunslinger (Venator)
  - claire = rimewright (Tamsin)
  - tarek = dolm (Breah)
  - cinder = ashwick (Linwick)
  - sable = thief (Dancer)
  - unchanged: zedran = juggernaut, dredge, ostra, pin = archer, vireo = mage, moosh = tender, bjorn = bulwark
- Display names follow the art (the class-titles pass applies the renames everywhere).

## 2026-11-03 21:12 UTC (MAIN, owner): WARDEN MODELS RUN IN PARALLEL WITH MECHANICS, AS FAST AS POSSIBLE
The owner wants the models in the game soon. Run modelling as its **own track** (separate agents on the new low-usage model) alongside the mechanics parity agents. The tracks touch different files: models and loader versus kit code.
How to speed it up:
1. **One shared humanoid skeleton for all 12** (same bone names; proportions per hero via scale). Retarget the KMoves and HunterAnim poses to it once, not 12 times. Only special parts (Tarek's stone fists, Moosh Moosh's tail, Bjorn's shield) get extra bones.
2. **Image-to-3D head start** from each turnaround if any tool is available to you. Otherwise block out the model from primitives in Blender against the turnaround, then refine. Budget: game-ready low-poly (about 8–15k tris) with stylised textures from the materials sheets. Not film quality.
3. **Vex first, today.** Post a gameplay-zoom screenshot plus a close-up for the owner as soon as Vex is in. Do NOT wait for full polish to show it.
4. **After the owner OKs Vex, fan out:** 3–4 model agents in parallel, about 3 Wardens each (the complex ones, Zedran, Tarek and Bjorn, spread across agents).
5. **Swap in per hero behind a setting**, procedural rig as the fallback, so each model ships the moment it passes its size check and screenshot. No big-bang release.
Animations hook to each model as that hero's mechanics pass finalises its moves.

## 2026-11-03 21:40 UTC (MAIN, owner): skeleton = shared BONES, not shared MOTION. And Vex is a woman
- The owner worries that every Warden will move the same. **Rule:** the shared skeleton is only common bone *names* and a common rig layout, so tools, retargeting and the loader work for all 12. **Each Warden keeps fully their own animation set**: their own idle, run cycle, stance, dash and every ability move (the per-hero KMoves and ARCH_STANCE stay per hero, as today). Proportions differ per hero, and per-hero extra bones for unique parts (fists, tails, shields, coats and hair) are encouraged. If two Wardens' runs or idles look alike in the review screenshots, that's a fail.
- **Vex is female** (class-titles data: gender female). Model and animate her as a woman, per the art (`vex_*`). Fix any he/him text.
- The owner is waiting on the **Vex screenshot**: please post a gameplay-zoom shot and a close-up in EXT_TO_MAIN as soon as there's anything in game, even rough.

## 2026-11-03 22:05 UTC (MAIN, owner: "let's work on the servers now"): GAME SERVERS, STAGE 1. S2 OWNS THIS (new low-usage model)
Context: DECISIONS "Hosting and distribution", briefs/specs/HOSTING_OPTIONS.md. Owner chose EU + NA from day one, our own authoritative headless servers on the **existing Hetzner account**, and itch.io for clients (already live: CI uploads Windows and mac on every main push, .github/workflows/itch.yml).
**Main can't reach Hetzner or itch from its sandbox. S2 can, from its Hetzner box, so S2 does the server side end to end.**
Build, in this order; post progress in EXT_TO_MAIN:
1. **Dedicated server mode:** a headless Linux export preset ("Linux Server") plus a `--server --port N --mode duel|arena|trio` start that runs one match as the authoritative host with no local player. Bots fill the empty slots. Reuse the current host-authoritative Net; no rewrite.
2. **Matchmaker:** start with the simplest thing that works. A small service (Godot headless or Python) holds queues (duel 1v1, arena 4v4, extraction trios auto-filled), starts a match process on a free port, and hands clients the address and port plus a one-time token. Nakama later if needed. Region is chosen by lowest ping.
3. **Client:** online buttons call the matchmaker (one URL per region). Show the queue state and connect. Handle "server full / version mismatch" (Net.VERSION) with a clear message.
4. **Deploy:** a script with systemd units that installs the server build and matchmaker on a fresh Ubuntu box. CI: add the Linux server export to itch.yml as a build artifact (or a separate deploy job that S2 runs). Never auto-deploy secrets through the repo.
5. **Servers:** two small boxes (e.g. CPX21/CX32 class), **one EU (Falkenstein or Helsinki) and one US (Ashburn)**. **The owner creates them in the Hetzner console** (agents never create paid resources). Post the exact click-steps: type, location, image Ubuntu 24.04, and **S2's SSH public key** to paste in. Then S2 deploys over SSH.
6. **Checks:** a local test spins up server + matchmaker + 2 headless clients and asserts a duel starts and ends. Main merges it like any branch.
**First deliverable today:** the owner's click-steps for step 5 plus your SSH public key, posted at the top of EXT_TO_MAIN, so the owner can create the servers while you build 1–4.

## 2026-11-03 21:45 UTC (orchestrator): heads-up, Hetzner hosting approved
- Owner approved stage 1 hosting (briefs/specs/HOSTING_OPTIONS.md; build plan in EXT_TO_MAIN 21:45 UTC). Main assigns the owner of the work; likely you. Do not start until main/ext says go. The itch page for butler pushes: https://projectboki.itch.io/project-boki (the owner supplies the API key as a server secret).

## 2026-11-03 22:45 UTC (orchestrator): OWNER CREATED THE GAME SERVERS (your EXT_TO_MAIN 22:10 click-steps): deploy now
- **boki-eu-1:** 2.31.98.197 (Falkenstein, CPX22: 2 vCPU, 4 GB, 80 GB)
- **boki-us-1:** 5.161.241.179 (Ashburn, CPX11: 2 vCPU, 2 GB, 40 GB; the US 4 GB type was nearly double the price, so rescale later if needed)
- Both: Ubuntu 24.04, SSH key boki-s2-deploy (also set as the project's default key), firewall boki-game (TCP 22, TCP 8080, UDP 7777-7799, ICMP).
- Deploy the server build + matchmaker as systemd services, size the match count per box to its RAM (the US box has 2 GB), and post the matchmaker URLs and health status in EXT_TO_MAIN. Nothing secret in the repo.
- Question for you or main: the project also has **boki-1** (CPX11, Ashburn, 5.161.240.47, 3 days old) and the agents' box ubuntu-64gb-ash-1. Is boki-1 still used by anyone? If not, tell the owner so he can delete it.

## 2026-11-03 23:00 UTC (orchestrator): owner answers to your hero questions (STATUS owner Qs)
- **Zedran Warchain:** keep the base range modest, but once hooked the chain **stays attached while he moves back, extending** to a max length (find it in the data/footage). The pull must **depend on his facing and his movement input** (steer, curve, slingshot), like the source's Brall (Juggernaut) chain: match its pull model state by state. Opus. Assert the extend-while-retreating behaviour and the facing/movement-dependent pull.
- **Tarek (was Breah):** RMB slam out of a glide is allowed, per the source (glider no longer wins); follow the source's timing.
- Rule for the rest of your open owner questions: **follow the source** (data > footage) unless DECISIONS or the owner says otherwise. Ask only where the source is silent and it changes feel a lot.
- Black Market is unfrozen (ext/market can proceed); shops move to the map/expedition work (low).

## 2026-11-03 23:20 UTC (orchestrator): the owner can't see the Vex shots: push them
- The Vex 3D shots exist only on your box (/home/boki/shots-s2/warden-3d/vex/: gameplay_match.png, closeup.png, turnaround_game.png, front_34.png); they aren't in git, so the owner can't open them. Push them now to **ext/hero-shots-s2 under warden-3d/vex/** (images only, never video) and post the paths in EXT_TO_MAIN. Do the same for every later "for owner review" shot.
- Blender: the owner is being told that your install is waiting on his permission prompt in your session.

## 2026-11-03 23:40 UTC (orchestrator): KIT AUDIT of all 12 vs the source: work list for the hero agents
- Full report: briefs/specs/kit-audit/README.md (summary + per-hero top gaps) and four detail files with file:line and source refs. It audits main 200effce: **first check your own unmerged branch** (dancer-feel, tarek-glide-slam, bjorn-48-49-51, parity-ostra-claire-moosh, combo-51) before fixing anything.
- **Do first (HIGH):**
  1. ONLINE: Cinder's E and Dredge's hook skip `remote` bodies, so they never move human players online. Audit every displacement in all 12 kits for the same skip; fix before online testers.
  2. Item 50 (no self screen shake) and item 51 (holds survive Shift/jump; abilities fire mid-dash where the source is silent) on every hero.
  3. Owner decisions not yet in code: Ostra ult ~1 s lock; Claire RMB push-emerge and ult skate carry; Moosh 3x rule removed (and the check asserting it); Zedran chain pull by facing/movement + RMB hold without auto-fire, with a perfect release and the sword overhead; Vex RMB side toss; Dredge Abyssal Hand.
  4. Cosmetic rings/discs/bursts on dashes and resets (list in the README).
- Then the per-hero MED gaps (numbers vs data, invented mechanics). Rule: data > footage; owner/DECISIONS overrides both.
- Opus for the parity work. Report per hero in STATUS, with shots pushed to ext/hero-shots-s2.

## 2026-11-03 23:55 UTC (orchestrator): owner answers to the audit questions
- **Claire LMB:** yes, her darts home in **toward the end of their flight**, as in SUPERVIVE (Celeste), including while she skates. Match the source's homing timing and strength from data/footage; assert it.
- **Tarek's rocks:** yes, **allies can jump over friendly rocks** (per the data). Tarek still climbs his own walls by walking (item 25); enemies stay blocked. Update docs/heroes/dolm.md and the assert.

## 2026-11-03 23:45 UTC (MAIN, owner DECISION): no reloading; the ultimate moves to R
- **There is no reload key and no manual reload in the game.** The hunter ultimate moves to **R**, and X is freed. Main does the keys, HUD tile, settings migration and text in the step 5 key pass. The other kit agents: never show "R = reload" or reload prompts.
- **[S2] Gun kits: copy how the source handles ammo without a reload.** Research Ghost's ammo (supervive_kits.md, supervive_physics.md, hero-ref/vex footage) and any other ammo kit. For example: ammo that refills over time or when you stop firing, or refills through the kit's own actions (a dash, a hit, the passive). Write the rule into docs/heroes/<hero>.md and the kit data, then build it with a check. Every other hero has no ammo at all. Part of the slice parity for Vex first.

## 2026-11-04 00:30 UTC (orchestrator): OWNER: the Blender Vex looks bad (made of shapes); switch to Meshy image-to-3D
- Owner's verdict on the blender_* shots: "looks pretty bad, not like the image, made up of shapes." Scripted primitives can't reach the art. Keep your skeleton, retarget, loader and setting; **replace the mesh pipeline**.
- **New pipeline (owner chose Meshy, a paid plan with commercial rights):** the owner is signing up and will give you a **MESHY_API_KEY**. Store it only in an env file outside the repo (e.g. ~/.config/boki/secrets.env, chmod 600); never commit it or print it in logs or shots.
  1. Use Meshy's **image-to-3D (multi-image if available)** with Vex's turnaround front/side/back from docs/art/gen/wardens/vex_turnaround.png (crop the views) plus the portrait/splash for detail. Prefer its low-poly/game option and PBR texture.
  2. In Blender: clean up, decimate/retopo to ~8-15k tris, fix the mechanical-arm side per the art, keep the texture (bake if needed), fit and weight to the shared WardenSkeleton, export .glb through the same loader.
  3. Shots: gameplay zoom + close-up + side by side with the turnaround. Push them to ext/hero-shots-s2 warden-3d/vex/meshy_*.
  4. Record the model version, settings and credits used in docs/art/wardens/PIPELINE.md, and check Meshy's current commercial terms.
- Vex first; the owner reviews before any other Warden. Opus.

## 2026-11-04 01:10 UTC (orchestrator): OWNER BAR for the Meshy Wardens: they must look like the image-gen art
- Owner: "I want the models to look like how they look in the earlier images we made" (origin/ext/imagegen: docs/art/gen/wardens/<name>_turnaround / _portrait / _splash, docs/art/gen/STYLE.md).
- **Acceptance test, per Warden:** a side-by-side of the in-game model (front, 3/4, back, at close-up and gameplay zoom) next to the turnaround and portrait. The silhouette, proportions, outfit pieces, colours and palette, face read and signature details (Vex: beret, mechanical arm on the art's side, lens/eye, ember rifle) must match. Anything that "doesn't look like the image" gets redone, not reported.
- **How:**
  - Meshy multi-image-to-3D from the clean turnaround views; texture from the reference images (Meshy's image-guided texturing), not a generic material.
  - Generate several candidates and keep the closest.
  - Fix the gaps in Blender (proportions, missing pieces, mirrored parts, a texture touch-up projected from the turnaround).
  - Keep the painted look of STYLE.md (toon/painted shading in Godot to match).
  - Decimate only as far as keeps the look (~15k tris is fine; go higher for the face and weapon if needed).
- Report honestly where it still differs and why. The owner reviews Vex before any other Warden.

## 2026-11-04 01:20 UTC (orchestrator): OWNER: line up the parallel Warden agents NOW; goal all 12 by tomorrow evening
- Owner wants all 12 Wardens as a good first pass by tomorrow (Nov 4) evening. Prepare now so they start **the moment the owner approves Vex**: 3-4 Opus model agents, ~3 Wardens each, the complex ones spread out (Moosh tail, Cinder tail/crest, Dredge robot, Ostra wisp, Bjorn shield, Tarek, Zedran).
- Per agent: crop each Warden's turnaround views now (no credits needed), and reuse the Vex pipeline and the acceptance test (INBOX_S2 01:10).
- **Credits:** 1,100/month. Budget about 3 attempts per Warden, and log the credits used in PIPELINE.md. If it would run out, stop and tell the owner (top-up or plan) before spending the rest.
- Push each Warden's shots to ext/hero-shots-s2 as soon as it passes, so the owner can review in batches.
- **Post the Vex shots for approval the moment they pass, with a clear "OWNER: approve Vex" line in EXT_TO_MAIN.**

## 2026-11-04 01:35 UTC (orchestrator): OWNER: after the Wardens, run the Boki through the Meshy pipeline
- The owner wants the Boki to look better fast. The image-gen session now makes Boki turnarounds (INBOX_IMG 01:35). When the 12 Wardens pass, model the starter/common Boki the same way: Meshy from the turnaround, Blender clean-up, the same acceptance test against the art.
- Rig: the Boki need creature rigs (quadruped, tail, wings per species), not the Warden humanoid skeleton. Plan one shared creature skeleton per body type and retarget the existing Boki moves.
- Credits: the Boki will need more than the remaining monthly credits after the Wardens. Estimate the cost and tell the owner before starting.

## 2026-11-04 01:50 UTC (orchestrator): OWNER: full Meshy art pass on the Boki AND the character creator; more credits OK
- Owner: "let's do a full art pass on the Boki as well as the character creator screen in Meshy. Happy to buy more credits if needed."
- **Order:** the 12 Wardens (in flight) -> the starter/common Boki -> the rest of the Boki -> the character creator. Image-gen supplies the turnarounds first (INBOX_IMG 01:35 for the Boki; the creator concepts next).
- **Boki:** Meshy from the turnarounds, Blender clean-up, creature rigs per body type, same acceptance test vs the art.
- **Character creator (the player's own look on the farm, DECISIONS: art-pass scope):** build it as modular Meshy parts on one shared body:
  - base bodies (a few body types), heads/faces, hair styles, outfits;
  - each cleaned in Blender, with **shape keys** so the creator sliders (height, build, face shape...) morph them smoothly;
  - all fitted to the shared skeleton;
  - plus the creator screen UI redone to STYLE.md.

  Plan it in a short doc first (parts list, slider -> shape key map, credit estimate).
- **Credits:** the owner will buy more. Agents never buy them. Post a credit estimate per phase (Wardens / Boki / creator) in EXT_TO_MAIN with "OWNER: buy N credits", and pause before you'd run out.

## 2026-11-04 02:10 UTC (orchestrator): OWNER: 50 original Boki to play with, incl. big rideable ones (one design agent, Opus)
- Owner: "get me a bunch of original Boki to play with that have good 3D modelling I can later change." Target **50 species** (the 9 existing count), a range of sizes, and **some bigger ones that are rideable** (mounts).
- **Originality (DECISIONS rule, non-negotiable):** every Boki is our own. Design them like today's nine: **fusions of real animals, plants, minerals and elements** (fox + scorpion, axolotl + crystal). **Never base one on, name it after or fuse existing franchise creatures** (Pokémon, Digimon, Palworld, etc.). Those may set the quality and readability bar only. If a design could be mistaken for an existing franchise creature, redo it.
- **Phase 1, design (no credits):** docs/boki/ROSTER_50.md + content/kin_v2/<id>.json stubs, using the existing grammar. For each one:
  - name, the real-world mix, theme/element, size class (small / medium / large / rideable), body type for the rig (quadruped, biped, winged, serpent, insect...);
  - a 2-line personality;
  - 1-2 abilities from the existing ability grammar;
  - rarity, and the biome or boss it comes from.

  Spread the themes and body types. Aim for about 6-8 rideable ones. Post the roster for owner review before any art.
- **Phase 2, art:** the image-gen session makes a turnaround per species (INBOX_IMG); then Meshy models them with creature rigs (shared skeleton per body type); same acceptance test vs the art.
- **Riding** is a new mechanic: write a short spec (mount/dismount key via Settings.key_cap, speed, what you can do while riding, and how it fits extraction/PvP), and wait for the owner's OK before building.
- **Credits:** about 50 species x ~3 attempts is several thousand Meshy credits. Post "OWNER: buy N credits" with the estimate, and run in batches of ~10.

## 2026-11-04 02:30 UTC (orchestrator): OWNER: ship the art in BATCHES, video-visible first
- The owner is filming a video to show what he has to an outside viewer (Dylan). **Ship in batches: each batch merged to main and shipped as a sync, not all at once.** Order by what appears first on screen:
  1. **Batch 1 (video):** Vex (everyone's first Warden), then the other first-hour Wardens (Zedran, Pin, Cinder = the second-Mantle picks), and the starter/early Boki the player meets first (the egg-pick species and the tutorial's Boki).
  2. **Batch 2:** the rest of the 12 Wardens and the other current Boki (incl. the boss-egg Cairnback, Hivara and Zephyrak).
  3. **Batches 3+:** the new roster species, ~10 at a time, the rideables when riding is approved.
- Each batch: models pass the art-match test, shots go to ext/hero-shots-s2, then one READY integration branch for main. Credits are watched per batch.

## 2026-11-04 02:00 UTC (ext): owner: focus on the Warden and Boki art for tomorrow's video
- The owner films the demo video tomorrow instead of tonight, to get the new art in. Put your capacity on the Meshy Wardens first, then the Boki; everything else waits. Land Wardens as they pass the acceptance test (looks like the image-gen art, rig + animations + FX anchors OK) so main can merge them in batches through the day. A matched set reads best on video, so post which Wardens pass and when.

## 2026-11-04 02:30 UTC (orchestrator): OWNER: PAUSE the Warden 3D fan-out; the 2D art gets redone first
- The owner reviewed the Warden art and wants most of it regenerated before committing to 3D (feedback in INBOX_IMG 02:30; Vex becomes a cyborg with a gun-arm, a big change). **Don't spend Meshy credits on any Warden until its new art is approved.** Keep the pipeline and the fit tools ready; the Meshy Vex (41b95f7) is superseded by the new Vex art.
- Still useful now: push the Meshy Vex shots anyway (warden-3d/vex/meshy_*) so the owner can see what the pipeline produces.
- **Boki roster:** large Boki aren't all mounts. Add roles: walks beside you, mount, flyer, and other ideas. Update ROSTER_50.md and RIDING_SPEC.md. The image-gen session makes visual thumbnails for the owner's review.
- **Rename: Moosh Moosh is now "Burple"** (display name only; id tender unchanged), with the rename sweep like Claire/Vex. See EXT_TO_MAIN 02:30.

## 2026-11-04 02:40 UTC (orchestrator): OWNER GATE: no Meshy without his explicit approval
- Owner: "get my approval before we move on to 3D with Meshy." **No Meshy run for any Warden, Boki or creator part until the owner has approved that model's new 2D art AND said go for 3D.** Post "OWNER: approve <name> for 3D" with a link to the art in EXT_TO_MAIN and wait.

## 2026-11-04 02:45 UTC (ext): owner on Vex (Meshy v2) + new item 52
- Owner: the in-game Vex model is OK, but the texture/quality is still somewhat low, and her design needs to be better anyway. The image-gen agent is improving the base pictures first. **Don't spend credits on the other 11 yet**: wait for the improved base art (watch ext/imagegen IMG_STATUS.md), then run them. When you do, aim for flat, clean, bright painted colour (no mottled grain) and slightly chunkier game proportions (bigger head and hands, thicker silhouette) so each Warden reads at match zoom.
- Meanwhile, do OWNER_REVIEW item 52 now (Opus): a signature stance and idle per Warden on the shared rig, as data, working on today's models and the Meshy ones.

## 2026-11-04 03:15 UTC (ext): build ext/kits-integ
- Main has merged only combo-flow-base and dancer-feel of your kit work. To make it one step for main: build `ext/kits-integ` = current origin/main + online-displace + no-shake + the five audit tips + vex-ammo (resolve generated files with gen_wiki), run the full suite once, post the commit as READY in STATUS and EXT_TO_MAIN. Same play as demo-integ.

## 2026-11-04 03:40 UTC (orchestrator): OWNER APPROVED the new Vex art: make a better Meshy 3D Vex (Vex only)
- The new art is on **origin/ext/imagegen @ a9fd3b92**, under docs/art/gen/wardens_r2/: vex_turnaround.png, vex_splash.png, vex_portrait.png (review/vex_before_after.jpg). She's a punk cyborg: a minigun fused to a mechanical right arm, black hair with an orange streak, a bolt in the bun, a brass monocle-eye, a denim vest, an orange crop top, shorts, torn tights, boots, and candles on the shoulder. The owner OKs her for 3D; the 11 others still wait for their own approval.
- **Fix what was wrong with Meshy v2** (your shots + owner 02:45):
  1. **Texture:** v2 was patchy and faceted (mottled flat patches on the face, beret and armour). Aim for **flat, clean, bright painted colour, no grain**. Bake from the art; project the turnaround onto the face, hair, vest and gun-arm; fix the seams by hand in Blender.
  2. **Pose/props:** the v2 rifle sat awkwardly. Now the gun IS her arm: model the minigun as part of the right arm (its own bones for the spin and recoil), fitted on the Gun's anchor so the kit's muzzle FX line up.
  3. **Proportions:** slightly chunkier game proportions (bigger head and hands, a thicker silhouette) so she reads at match zoom, still matching the art.
  4. **Input:** the turnaround has front, two 3/4s and back, **no pure side view**. Make a clean profile from the art (or ask IMG for one in INBOX_IMG) before the Meshy run; mask out the candles/scrolls if they confuse the mesh, then add them back as simple pieces.
  5. **Stance:** use item 52's signature stance (hip cocked, weight back, gun-arm resting) once ext/warden-stance lands.
- **Acceptance (INBOX_S2 01:10):** side-by-side with the turnaround and portrait, at close-up and gameplay zoom; the face, hair streak, monocle-eye and gun-arm must read clearly. Push it to ext/hero-shots-s2 as warden-3d/vex/r2_*, and post "OWNER: review Vex r2 3D" with links in EXT_TO_MAIN.
- Credits: ~160 used; budget ≤ 4 attempts (~180) for this; stop and ask if you need more.

## 2026-11-04 03:58 UTC (orchestrator): Vex side profile is in
- origin/ext/imagegen @ 865da870: docs/art/gen/wardens_r2/vex_side.webp (a true profile; the gun-arm on her right). Use it with vex_turnaround(_2k) for the Meshy run. Her hair is a ponytail in the side view vs a messy bun in the turnaround: the turnaround wins. Side views for Zedran and Pin are there too; they are NOT approved for 3D yet.

## 2026-11-04 04:05 UTC (orchestrator): correction, the creator is now the Unmasked (DECISIONS)
- My 01:50 creator plan (modular faces/hair parts) is superseded by DECISIONS: one near-faceless Meshy base with params + decals + outfits. Ext leads it; follow DECISIONS.

## 2026-11-04 04:15 UTC (orchestrator): OWNER APPROVES 3D FOR ALL WARDENS ("do as you think best"): fan out
- The owner approves Meshy 3D for every Warden, with the orchestrator's judgement on details. The rule: **model from the round-2 art only** (docs/art/gen/wardens_r2/ on origin/ext/imagegen). Don't spend credits on old round-1 art that the owner asked to redo.
- **Now (round-2 art + side view present):** Vex (in progress), **Zedran**, **Pin**, **Cinder**. Source of truth = the turnaround + side view; the splash is for mood (Zedran's splash is mirrored: magma arm and lion on his RIGHT, chain in his LEFT). Pin: planted feet, claw scratches (no handprint), smoke only as FX. Cinder: keep her design as drawn (gill-frills OK); the weapon is the turnaround's syringe-spear.
- **Next:** each remaining Warden as soon as its round-2 turnaround + side view lands on ext/imagegen (watch IMG_STATUS.md). The orchestrator commits the owner's uploads there.
- Run 3-4 Opus agents in parallel per INBOX_S2 01:20. Same acceptance test (side by side with the round-2 art; no AI-patchy texture, flat painted colour, chunkier game proportions, signature stance from item 52), and push the shots to ext/hero-shots-s2 warden-3d/<name>/r2_*.
- **Batches to main:** Batch 1 (video) = Vex, Zedran, Pin, Cinder → one READY integration, then the rest.
- **Credits:** ~940 left this month; 4 Wardens ≈ 540-720. Post "OWNER: buy N" before you'd run out; never buy.

## 2026-11-04 04:25 UTC (orchestrator): OWNER RENAME: Vireo is now "Ryzz"
- Do a rename sweep like rename-burple: display name, kit text, docs/heroes, wiki (gen_wiki), and the old name into --hero-title-check. id mage unchanged. New art files are named ryzz_*. Small branch, READY to main.

## 2026-11-04 04:35 UTC (orchestrator): RYZZ (was Vireo) round-2 art is in: add her to the 3D fan-out
- origin/ext/imagegen: docs/art/gen/wardens_r2/ryzz_{turnaround,side,portrait,splash}.webp. Approved for 3D (the owner approved all Wardens). Source = the turnaround (spear in her RIGHT hand) + the side view. Signature: electrified blue hair standing up (model it as chunky hair cards/shells with an emissive lightning layer as FX), lightning veins on her arms (emissive texture), copper-coiled spear with a black flag, bubblegum as an idle fidget. Queue: Vex, Zedran, Pin, Cinder, then Ryzz.
- The rename to Ryzz (04:25) applies to the art and model files: ryzz_*.

## 2026-11-04 05:00 UTC (orchestrator): OWNER: Vex r2 3D is still too buggy; PAUSE the fan-out and do a quality bake-off on Vex (spend is OK)
- Owner on the r2 shots: "looks pretty buggy still; try the highest quality settings and a better agent; there has to be a better way; I don't mind paying more."
- Orchestrator read of r2: jagged/faceted hair with patchy orange blocks, a smeared face and monocle, ragged black outline fringes, a muddy back, and a dark muddy read at match zoom. Likely causes: decimating to 15k with UV-island-safe collapse destroys the texture; re-projection seams; the outline shell; too little light at match zoom.
- **Pause** Zedran/Pin/Cinder/Ryzz 3D until Vex meets the bar (don't spend credits for the same ceiling).
- **One dedicated Opus agent, highest effort, Vex only:**
  1. **Meshy at max:** multi-image with the clean front/side/back (+3/4) crops, `ai_model` latest/meshy-7.1 (or the top model the account offers), **should_remesh=false**, texture_resolution 4k (8k if allowed), PBR on. Check docs.meshy.ai for current params.
  2. **Don't destroy the texture:** keep the high-res mesh for baking, retopologise to a clean ~30-40k tris (top-down camera, 12 heroes: fine), and **bake** colour (+ normal) from high to low instead of collapsing the textured mesh.
  3. **Paint-over:** project the art's front/side/back views onto the baked texture in Blender (face, hair streak, monocle, vest symbols), hand-clean the seams; flat painted colour, no grain.
  4. **Outline:** fix the ragged inked fringe (shell only on the clean low-poly, consistent thickness) or drop it if it hurts.
  5. **Match-zoom read:** brighten the albedo and rim light so she pops like the art.
  6. **Bake-off (owner OK to pay):** run the same Vex views through **Rodin (Hyper3D Gen-2.x)** and **Tripo (v3.x)** too, the leaders for character detail/topology, and compare all three side by side. The owner signs up for and buys those; post "OWNER: please create a Rodin / Tripo API key" with the plan names, and store the keys like MESHY_API_KEY.
- Deliver: a side-by-side of the 3 services + your final cleaned Vex vs the art (close-up, 3/4, back, match zoom) in ext/hero-shots-s2 warden-3d/vex/r3_*, an honest verdict, and the cost per model. If none reaches the art, say so and recommend a human 3D artist clean-up pass (Meshy/Rodin mesh as the start).
