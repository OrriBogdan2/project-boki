# Inbox for the second server session (S2)
<!-- briefs-trim pointer -->
> Trimmed 2026-11-06 by briefs-trim: 69 finished/superseded entries moved to briefs/archive/INBOX_S2-2026-11-06.md. Kept here: owner rules and decisions, open owner questions, unmerged READY branches, open assignments and review items, the latest SHIPPED/RELEASED, holds still in force, and the last 12 h. Older archives: briefs/archive/INBOX_S2-*.md
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

## 2026-11-04 04:15 UTC (orchestrator): OWNER APPROVES 3D FOR ALL WARDENS ("do as you think best"): fan out
- The owner approves Meshy 3D for every Warden, with the orchestrator's judgement on details. The rule: **model from the round-2 art only** (docs/art/gen/wardens_r2/ on origin/ext/imagegen). Don't spend credits on old round-1 art that the owner asked to redo.
- **Now (round-2 art + side view present):** Vex (in progress), **Zedran**, **Pin**, **Cinder**. Source of truth = the turnaround + side view; the splash is for mood (Zedran's splash is mirrored: magma arm and lion on his RIGHT, chain in his LEFT). Pin: planted feet, claw scratches (no handprint), smoke only as FX. Cinder: keep her design as drawn (gill-frills OK); the weapon is the turnaround's syringe-spear.
- **Next:** each remaining Warden as soon as its round-2 turnaround + side view lands on ext/imagegen (watch IMG_STATUS.md). The orchestrator commits the owner's uploads there.
- Run 3-4 Opus agents in parallel per INBOX_S2 01:20. Same acceptance test (side by side with the round-2 art; no AI-patchy texture, flat painted colour, chunkier game proportions, signature stance from item 52), and push the shots to ext/hero-shots-s2 warden-3d/<name>/r2_*.
- **Batches to main:** Batch 1 (video) = Vex, Zedran, Pin, Cinder → one READY integration, then the rest.
- **Credits:** ~940 left this month; 4 Wardens ≈ 540-720. Post "OWNER: buy N" before you'd run out; never buy.

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

## 2026-11-04 05:15 UTC (orchestrator): OWNER: Meshy only for now, NO Rodin/Tripo; he bought more Meshy credits
- Owner: "do I need Rodin and Tripo? I just paid for more Meshy credits; can we do it through this and just use better models first?" So **drop the Rodin/Tripo bake-off** for now. Do the Vex rerun on Meshy only, with its best models: steps 1-5 of 05:00 (the top ai_model the account has, e.g. meshy-7.x/latest; should_remesh=false; 4k/8k texture; PBR; multi-image front/side/back/3-4) + bake to a clean low-poly + paint-over from the art + outline fix + match-zoom brightness. A couple of variants (e.g. single-image from the front vs multi-image; with/without remesh) are fine; pick the best.
- Only if the Meshy result still can't reach the art, say so and propose the next step (Rodin/Tripo or a human artist); don't ask for keys before then. Post the new credit balance with the r3 shots.

## 2026-11-04 05:30 UTC (orchestrator): UPDATED side profiles; use these
- The owner replaced some side views that were off: ext/imagegen wardens_r2/vex_side.webp, zedran_side.webp and ryzz_side.webp are new (the reference from now on). **For the Vex r3 Meshy run, use the new vex_side** (messy bun with the bolt, gun-arm, candles). New sable_side and bjorn_side are reference only (no turnaround yet; Bjorn not cleared for 3D yet).

## 2026-11-04 06:05 UTC (orchestrator): Dredge art LOCKED (owner)
- The owner picks the bulky Dredge as is (no head change): ext/imagegen wardens_r2/dredge_turnaround.webp (crop the text labels for Meshy) + dredge_splash.webp. Cleared for 3D after Vex passes. The thin variants in review/ are reference only.
- Round-2 art now in: Vex, Zedran, Pin, Cinder, Ryzz, Sable, Dredge (+ updated side views). Still to come: Bjorn (a redo prompt was given), Burple, Claire, Tarek, Ostra.

## 2026-11-04 06:15 UTC (orchestrator): Dredge full set in
- ext/imagegen wardens_r2/dredge_{turnaround (unlabelled, clean for Meshy),side,portrait,splash}.webp. Owner-locked; 3D after Vex passes.

## 2026-11-04 06:35 UTC (orchestrator): Breaker (was Bjorn) art in
- ext/imagegen wardens_r2/breaker_{turnaround,side,portrait,splash}.webp. Approved for 3D after Vex passes. Signature: the biggest Warden (towering), undead tells (white eyes, pale frost skin, rot wounds with bone), the prow shield (scroll top), and the ice-block hammer with an anchor fluke. The turnaround is ordered back/side/3-4/front.
- Round-2 art now in: Vex, Zedran, Pin, Cinder, Ryzz, Sable, Dredge, Breaker. To come: Burple, Claire, Tarek, Ostra.

## 2026-11-04 06:50 UTC (orchestrator): Pip art in + rename
- The tender hero is now **Pip** (supersedes Burple; id tender). Update rename-burple to Pip (display name, kit text, docs, wiki; add "Burple" and "Moosh Moosh" to the old names in --hero-title-check). Art: ext/imagegen wardens_r2/pip_{turnaround,side,portrait,splash}.webp; queued for 3D after Vex (fairy wings as alpha cards, a fluffy tail, a glowing lantern).

## 2026-11-04 07:10 UTC (orchestrator): NEW Vex round-3 art (redesign) + a hand-made Dredge model from the owner's friend
**1. Vex round 3, owner-approved redesign: model it ALONGSIDE the current Vex r3 run.**
- origin/ext/imagegen @ fb523188: docs/art/gen/wardens_r3/vex_{turnaround,side,portrait,splash}.webp + VEX_KIT.md (read it: the gun-arm is her RIGHT forearm, the cyber eye is over her RIGHT eye; the splash mirrors the eye, ignore that).
- Owner: "try to do a better job this time." Apply everything learned from r2/r3: Meshy max, no remesh, bake to a clean low-poly (no collapse of the textured mesh), paint over from the art, flat painted colour, a clean outline, match-zoom brightness. Signatures that must read: the gun-arm, the long green braids (model them as real geometry, not texture), the green cyber eye (emissive). Name the outputs vex_r3b_*.
- Deliver both side by side (the current-art r3 vs the redesign r3b) so the owner can compare the pipeline and the design.

**2. Dredge: a human-made Blender model, use it instead of Meshy.**
- origin/ext/imagegen @ the next commit: docs/art/gen/models/dredge_friend/Dredge.glb (+ .fbx, README). ~43.7k tris, 10 flat materials, **already rigged with 27 joints** + 1 animation.
- Bring it into the Warden pipeline: map its bones to the shared WardenSkeleton (or a Dredge variant: extra claw, winch, rope and hook bones), check scale against the concept height, keep its flat painted materials (match STYLE/toon), retarget the KMoves, and run the warden checks; shots at match zoom + close-up next to his art (r2_dredge_*). Don't spend Meshy credits on Dredge.
- **Worth learning from:** the friend says the owner may "not have the right MCP": he likely built it by driving Blender through a Blender MCP server. Blender is installed on your box; check whether a Blender MCP (or a direct bpy session with live viewport renders) would let your agents iterate in Blender the way he did, and propose it in STATUS if it would beat the Meshy route for the remaining Wardens.

## 2026-11-04 07:10 UTC (orchestrator): owner answers to S2's two calls
- **Ryzz's right-eye "wink":** owner idea, adopted: it's a **scar** through her right eye. Make it a **lightning scar** (a branching Lichtenberg-figure scar, faint blue glow at the edges) running through the brow and cheek; the eye stays closed or half-lidded. This ties into her lore (struck by the Wyrm's storm as a kid). In 3D: model the eye closed or half-closed, with the scar as painted texture + a faint emissive.
- **Cinder's spear hand:** keep it in her **right** hand (the rig default; no rig work). From the top-down camera handedness barely reads, and it matches the other heroes. The art can be mirrored to match later.

## 2026-11-04 07:30 UTC (orchestrator): Claire art in (frost demoness skater)
- ext/imagegen wardens_r2/claire_{turnaround,side,portrait,splash}.webp + CLAIRE_KIT.md. Queued for 3D after Vex passes. Modelling notes: the wings and tail need their own bones (wings fold for the skate pose); ice horns as their own mesh; the ice costume is semi-translucent (a toon shader with a fresnel rim, not real transparency); the spear in her RIGHT hand (the 3/4 view is missing it).
- Round-2 art now in: 10 of 12 (+ the Vex r3 redesign). To come: Tarek, Ostra.

## 2026-11-04 07:40 UTC (orchestrator): Claire, a backwards foot
- The owner noticed one of Claire's feet/skates points backwards (on a 3D model or in the turnaround). When you build her: use the front/side/back views as the Meshy input (skip the 3/4 view: it also lacks the spear), and check both feet point forward. If a generated mesh still has a reversed foot, fix it in Blender (separate the foot/skate, rotate it 180 degrees about the ankle, rejoin, re-weight) before rigging. Add a check: the foot forward vectors match the body forward.

## 2026-11-04 07:50 UTC (orchestrator): Tarek art in
- ext/imagegen wardens_r2/tarek_{turnaround,side,portrait,splash}.webp + TAREK_KIT.md. Queued for 3D after Vex passes. Modelling notes: the three seeing-stones are separate floating props on an orbit around the head (their amber irises face outward, plain backs); the locs as chunky geometry with the bead and crystal props (emissive amber); stone bracers as their own mesh with an emissive crack layer; the ground ripple rings are VFX shown only while sensing or casting (the DECISIONS ring rule), never baked into the model.
- Round-2 art now in: 11 of 12 (+ the Vex r3 redesign). To come: Ostra.

## 2026-11-04 08:30 UTC (orchestrator): Ostra art in; all 12 have round-2 art
- ext/imagegen wardens_r2/ostra_{turnaround,side,portrait,splash}.webp + OSTRA_KIT.md. Queued for 3D after Vex. Modelling notes: the wisp lower body as a soft-alpha shader with a scrolling starfield (also inside the coat tears); the mask as its own mesh with an emissive mouth and eyes; the crescent halo follows the head bone; the strings + card shards are VFX/props; hover with a shadow gap.
- **Main note:** the arena still shows "X · RESET" (seen in the Dredge shots); X is Fuse now: fix the label.

## 2026-11-04 08:45 UTC (orchestrator): OWNER RENAME: Pin is now "Hem"
- Add to the rename sweep (on top of rename-breaker or a small follow-up): display name, kit text, tooltips, picker, docs/heroes, wiki (gen_wiki), and "Pin" into --hero-title-check's old names. id archer unchanged. Art and model files: hem_* from now on.

## 2026-11-04 08:55 UTC (orchestrator): Breaker round 3 (sea-ogre) art in; it supersedes r2
- ext/imagegen docs/art/gen/wardens_r3/breaker_* + BREAKER_KIT.md. Use these, not wardens_r2/breaker_*. Good candidate for the hybrid route: script the hammer and the prow shield in Blender (hard surface), Meshy for the ogre body. Check for an extra third hand (the kit warns the generator adds one). No lantern; a plain hammer.

## 2026-11-04 10:20 UTC (orchestrator): Hem (was Pin) art in
- ext/imagegen wardens_r3/hem_* + HEM_KIT.md. Queued for 3D after Vex passes. Notes: the bow in her LEFT hand, draw RIGHT; the glowing red-thread bowstring (emissive line); the needle-arrows with a stitched-trail VFX; her shadow is a VFX/decal trick (too long, clawed, red seams), not a creature and not in the mesh; the porcelain-shard mask as its own mesh; the thimble claws on the right hand.

## 2026-11-04 09:00 UTC (orchestrator): OWNER PICKS Vex r3b; polish it before any other Warden
- The owner picks **r3b** (the green redesign). Make it the shipped Vex: move vex_r3b into art/wardens/vex/ (r3 stays in history), and apply your carry-pitch fix (-1.3 -> -1.05).
- **Polish pass (one Opus agent, highest effort; credit-free where possible).** This becomes the reference recipe for the other 11:
  1. **Texture clean-up:** remove the blotchy chest-strap cage and the cheek seams; flat, clean painted colour; hand-paint the seams in Blender from the portrait/turnaround.
  2. **Shader:** fix the washed-out skin (match the art's warm tone) and the silvered gun-arm (gunmetal + brass as painted; keep the green emissive vents/lens). If the shared toon shader causes it, add a per-Warden material override rather than changing it for everyone.
  3. **Proportions:** longer legs to match the art (a per-Warden body scale on the shared rig, not a new rig); keep the hitbox unchanged.
  4. **Missing and short pieces:** restore the armoured hoses from the backpack/feeder to the gun-arm; lengthen the braids to the art (keep the spring bones).
  5. **Signature stance** (item 52): weight back, hip cocked, gun-arm resting; check it in idle and in the run blend.
  6. **Match-zoom read:** the green head, braids and lens must pop; check the r3b_gameplay_match framing.
- Deliver: r3c_* shots (close-up, 3/4, back, match zoom, moves) next to the turnaround and portrait, plus an honest list of what still differs. Post "OWNER: review Vex r3c". The other Wardens wait until the owner OKs r3c and says go.

## 2026-11-04 09:05 UTC (orchestrator): OWNER: GO, fan out the 3D now for every Warden whose art is final (don't wait for r3c)
The owner approves starting now. Run 3-4 Opus agents in parallel (about 2 Wardens each), with the r3b recipe: Meshy 7.1 max, no remesh, bake to a clean low-poly, paint-over from the art, per-Warden shader override, braids/hair as real geometry where needed, signature stance. Fold the r3c polish learnings in as they land. Same acceptance test vs the art; shots in ext/hero-shots-s2 warden-3d/<name>/; each Warden ships as its own READY branch (or batched per agent).
**Go now, with the art source for each:**
- **Hem:** ext/imagegen wardens_r3/hem_* + HEM_KIT.md (bow LEFT, draw RIGHT; the shadow is VFX only).
- **Breaker:** wardens_r3/breaker_* + BREAKER_KIT.md (hybrid: Blender-scripted hammer + prow shield; check for a third hand).
- **Sable:** wardens_r2/sable_* (wings as alpha cards on bones; use front/back + sable_side; reconcile the sleeves/collar/two braids).
- **Claire:** wardens_r2/claire_* + CLAIRE_KIT.md (wings + tail bones; spear RIGHT; check both feet point forward).
- **Tarek:** wardens_r2/tarek_* + TAREK_KIT.md (3 orbiting seeing-stones as props; ground ripples are VFX only).
- **Ostra:** wardens_r2/ostra_* + OSTRA_KIT.md (wisp + starfield shader, halo on the head bone, strings/cards as VFX, hover).
- **Pip:** wardens_r2/pip_* (small; fairy wings as alpha cards; fluffy tail with spring bones; lantern glow).
- **Dredge:** the friend's model is in; give it an aged-brass texture pass (dented, darker, patina; not bright yellow), a glowing-orb eye in cracked glass, and thicker tar drips. No Meshy.
**Wait:** Zedran (final art almost done), Ryzz and Cinder (redos pending). Vex: finish r3c.
Credits: ~8 x 70-110 ≈ 600-900; balance 4,993. Post per-Warden "OWNER: review <name>" with links as each one passes.

## 2026-11-04 09:10 UTC (orchestrator): refinement to the 09:05 fan-out (owner unsure whether to wait for one good one)
- Do the fan-out in two stages. **Stage 1 now:** Meshy generation + bake + rig fit + first shots for each Warden. These steps don't depend on r3c. **Stage 2 after the owner OKs Vex r3c:** apply the proven polish recipe (texture clean-up, shader override, proportions, stance) to all of them. Don't hand-polish any Warden before r3c is approved, so nobody polishes twice. If stage 1 shows a Warden's generation is bad, report it instead of burning more than 2 attempts.

## 2026-11-04 09:20 UTC (orchestrator): Zedran final art in: add him to the 3D fan-out (stage 1 now)
- ext/imagegen wardens_r3/zedran_* + ZEDRAN_KIT.md (supersedes r2). Notes: no horns; the white mane as chunky hair geometry with spring bones; the scarf always on; magma cracks (emissive) on the RIGHT arm only; the chain wrapped on the right forearm + hilt continuing to ONE hook (the Warchain; a rope/chain bone chain); left wrist: cuff + a short broken chain, NO second hook; the full blade from the front/3-4 views (the side view crops it); demon smoke as VFX. Hybrid: script the greatsword, chain and hook in Blender.

## 2026-11-04 09:30 UTC (orchestrator): rename Zedran to Kael + titles
- Add to the rename/title sweep: Zedran → **Kael** (id juggernaut; "Zedran" into --hero-title-check). Titles: Kael "The Unbroken", Claire "Frost Siren", Pip "Little Lantern", Ryzz "Storm Chaser". 3D/art files for him: kael_* from now on.

## 2026-11-04 09:45 UTC (orchestrator): HOLD Kael's glow colour
- The owner is testing white-hot cracks for Kael instead of orange magma. Build his mesh/rig in stage 1 as planned, but keep the crack/blade glow as a separate emissive colour parameter so it can be switched without a rebake.

## 2026-11-04 10:00 UTC (orchestrator): Kael glow = WHITE-HOT (owner)
- Set Kael's emissive (arm cracks, blade cracks, hook tip) to white-hot: a near-white core, a faint pale-gold edge, white-gold sparks, black demon smoke. No orange or red. New art files are coming to ext/imagegen as kael_*.

## 2026-11-04 10:15 UTC (orchestrator): Kael final art: use wardens_r3/kael_* (white-hot), not zedran_*
- One hook (right-arm chain); left wrist = cuff + a short chain; the jagged blade tip per kael_side/turnaround. Read ZEDRAN_KIT.md for the rest.

## 2026-11-04 11:00 UTC (ORCH): Ryzz art locked, 3D brief (owner)
- Art on ext/imagegen 93a2757f, docs/art/gen/wardens_r3/: ryzz_fullbody (the locked design), ryzz_front (A-pose, the main Meshy input), ryzz_34, ryzz_back, ryzz_side, ryzz_head_sheet, ryzz_portrait, ryzz_splash. **Read RYZZ_KIT.md first**: it lists which views have errors to ignore (side view jacket on the shoulders; extra pigtail rings on the head sheet).
- Must hold in every view: her RIGHT eye closed by a glowing pink fern-shaped scar (a permanent wink); short twin pigtails with one copper-coil tie each and zigzag ends (keep them SHORT: long twin tails read as a famous existing character); exactly 3 copper rods on the back, the middle one scorched and bent (her relic); plunging bolt-shaped keyhole cutout on the corset with pink neon piping; glowing choker charm; hazard bands on wrists and boot tops.
- Proportions: slimmer and longer-legged than the art (~8 heads), adult. Pink emissive on the scar, charm, corset piping and forearm veins (a switchable emissive like Kael's).
- Queue: after the current fan-out (stage 1). Use the r3 recipe; post review shots under warden-3d/ryzz/ as usual.

## 2026-11-04 11:15 UTC (ORCH): Breaker height = 1.5x (owner)
- Owner: make Breaker 1.5x a medium hunter (was 1.32x in stage 1). Keep the heavy class's 0.50 m hitbox unless the kit says otherwise; re-check the shield and hammer holds at the new scale. Vex r3c review is with the owner now.

## 2026-11-04 11:25 UTC (ORCH): Vex r3c = ~80% there (owner) -> stage 2 GO + a Vex face pass
- Owner on r3c: "almost there... it can use a bit of polishing to get the face stuff exactly right, but it's like 80% there."
- 1. Treat r3c as the approved recipe: start stage 2 (paint-over, per-model look, proportions, stance) for Hem, Kael, Breaker (now 1.5x), Claire, Sable, Pip, Tarek, Ostra.
- 2. In parallel, a Vex face pass (r3d): match the portrait's face exactly (eyes, brows, lips, skin tone), remove the faint jaw seam, make the eye-plate lens read at match zoom, clean the dark smears on the straps at 3/4. Post r3d_closeup_vs_art + r3d_closeup_34_vs_art for the owner.
- Fold whatever the face pass learns back into the recipe for the other eight.

## 2026-11-04 11:45 UTC (ORCH): Cinder art in, 3D brief (owner)
- Art on ext/imagegen 02294108, docs/art/gen/wardens_r3/: cinder_fullbody (design ref), cinder_front (upright, the main Meshy input), cinder_back (rear 3/4), cinder_side. **Read CINDER_KIT.md first.**
- Must hold: the short rounded feminine salamander face (no long snout); the translucent fin-crest with fin rays running onto the tail (replaces the axolotl frills, so she no longer reads like Prismander); cracked brass goggles on the crest (her relic); the flamethrower lance in her LEFT hand, hosed to the copper tank; the tail; glowing spots and vials.
- Queue: with Ryzz, after stage 2. Portrait and splash art are still coming; not needed for the model.

## 2026-11-04 12:40 UTC (ORCH): new 3D reference sheets for every Hunter (owner) -> use them in stage 2
ext/imagegen fb503983. The owner made flat-lit face/head sheets, prop sheets and fixed fronts aimed at your stage-1 gaps. **Read each Hunter's notes file first**: some sheets have parts to ignore.
- **Vex** (wardens_r3, VEX_KIT.md): vex_face, vex_head_sheet; review/vex_eyeplate_detail_ref for the lens iris only. For the r3d face pass.
- **Sable** (wardens_r2, SABLE_REFS.md): sable_face (almond, half-lidded dark eyes, not round orbs), sable_head_sheet, sable_crossbow_sheet (scale the crossbows up).
- **Claire** (wardens_r2, CLAIRE_REFS.md): claire_head_sheet (horns curl back and down, close to the skull), claire_face, claire_spear_sheet (the spear is taller than her).
- **Hem** (wardens_r3, HEM_KIT.md): hem_face, hem_head_sheet, hem_mask_sheet (the separate mask mesh), hem_weapons_sheet (bow with thread string + spool, clean needles, thimbles).
- **Ostra** (wardens_r2, OSTRA_REFS.md): ostra_head_sheet, ostra_mask_sheet, ostra_cap_halo_sheet (violet halo, large), ostra_front_float (orb-hand pose, long wisp, violet rim for match read).
- **Kael** (wardens_r3, ZEDRAN_KIT.md): kael_blade_sheet (whole core white-hot; ignore the pommel hook), kael_arm_sheet (white-hot cracks), kael_head_sheet (soft layered mane), kael_collar_sheet.
- **Breaker** (wardens_r3, BREAKER_KIT.md): breaker_front (hammer on the RIGHT shoulder, shield at the LEFT side), breaker_hammer_sheet (plain banded ice, no anchor), breaker_shield_sheet, breaker_head_sheet. Scale 1.5x.
- **Pip** (wardens_r2, PIP_REFS.md): pip_front (arms clear, cape behind the arms), pip_head_sheet, pip_lantern_sheet (scale only; keep the portrait's arched-pane lantern; make it cast light).
- **Tarek** (wardens_r2, TAREK_KIT.md): tarek_front (lean, long legs, normal head), tarek_head_sheet (locs on springs), tarek_stone_sheet (rocky depth, amber iris).
- **Ryzz, Cinder**: full sets already briefed (10:51, 11:45).

## 2026-11-04 13:10 UTC (ORCH): Dredge hull upgrade GO (owner) + quality bar
- Owner: "upgrade dredge - I want them all looking as good as possible."
- Dredge (ext/warden-dredge-friend acb501fd): KEEP the friend's rig, bones (claw x3, winch, rope, hook) and all 184 retargeted moves. Replace only the hull/shoulder shell with a Meshy-built (or Blender-sculpted) version that matches the art: angular, dented, layered and torn brass plates instead of smooth domes; brass shifted to the art's duller olive-gold (not copper-orange); keep the cracked-lens red orb eye and the thick tar drips. Check the horn arm's size and hold against the art (it reads very big and low). Budget ~80-150 credits (balance 4,327). Post r3 shots vs the art as usual.
- Quality bar for every Hunter in stage 2: match the art as closely as the recipe allows, using the new reference sheets (13:40 list above). Spend credits where they clearly improve the result; tell ORCH if any Hunter needs more than ~150.

## 2026-11-04 12:15 UTC (ORCH): OWNER: iterate every Hunter to the best you can make them, then ship ASAP
- Owner (verbatim): "keep fixing these until they're as good as you can possibly make them - if we run out of meshy credits that's fine ... try to get them all live and ready to ship as soon as possible."
- So: no per-Hunter credit cap. Keep iterating (stage 2, then 3+, more Meshy runs, paint-overs, Blender fixes) until each Hunter matches its art and reference sheets as closely as you can, at close-up AND at match zoom. Use Opus agents (design/feel work).
- Ship as you go: the moment a Hunter is good, mark its ext/warden-3d-<id> branch READY TO MERGE in EXT_TO_MAIN (commit, checks, shots), don't wait for the whole roster. Order: Vex, then whichever are closest.
- Credits: if the balance runs low, STOP that Hunter and post "OWNER: buy credits" with the amount needed (no agent buys anything). Running out is acceptable to the owner.
- Ryzz s1 gaps first: hue (blue hair, less magenta overall, read at match zoom), soft full pigtails, rods flush to the harness, round charm glow.

## 2026-11-04 12:25 UTC (ORCH): OWNER: bar = 95% of the art, then ship without waiting for review
- Owner: "just try to improve until it's 95% there and ship it. I have a lot of Meshy credits."
- Bar: a Hunter ships when its model is ~95% of the art (close-up and match zoom) by your own honest side-by-side read. No owner review step before merging; post the shots anyway so the owner can look later.
- Credits are plentiful: spend what it takes. Still post "OWNER: buy credits" if the balance actually runs low.

## 2026-11-04 12:35 UTC (ORCH): 3D review Ryzz (s1, s1_vs_turnaround.png): ~55% close-up, ~45% match zoom
1. Hue: the whole model is pushed violet. Hair must be light sky/electric blue with hot-pink tips (art), skin warm peach (it reads lilac), corset hot pink, jacket/skirt/boots near-black. Fix the colour first; it is most of the gap.
2. Pigtails: two big soft curly bunches with clear blue-to-pink gradient and copper ties; s1 has small spiky dark tufts. Volume ~2x.
3. Rods: three copper rods flush in a harness between the shoulder blades, angled up and out in a V (back view); s1 rods are dark and stand off the body.
4. Skin glow: forearm veins only, pink; s1 tints the whole skin.
5. Contrast for match zoom: hazard-yellow bands (wrists, thighs) and the pink corset/charm must pop against black; boost saturation/value on those so she reads at distance.
6. Silhouette is right (proportions, thigh-highs, skirt, jacket off the shoulders); keep it.

## 2026-11-04 12:45 UTC (ORCH): clarification (owner): 95% = ship, not stop
- Owner: 95% is the bar to SHIP, not to stop. Once a Hunter ships at ~95%, keep improving it toward 100% and post each better version as a new READY commit on the same branch; main ships the update in the next sync.

## 2026-11-04 13:05 UTC (ORCH): OWNER: max parallel — one Opus agent per Hunter, target all 12 shipped before Fri 06:00
- Owner wants speed. Run one Opus agent per Hunter in parallel (Vex, Kael, Hem, Breaker, Ryzz, Cinder, Dredge, Pip, Claire, Tarek, Ostra, Sable), each owning its ext/warden-3d-<id> branch, iterating to ~95% then marking READY (and continuing toward 100%).
- First do the shared fix once: the toon light / look override pushes every model violet and too dark (Vex skin lilac, Ryzz magenta). Fix it in one shared commit and rebase the Hunter branches on it.
- Order of READY: Vex first (closest), then Kael, Hem, Breaker, Claire, Sable, Ostra, Tarek, Pip, Ryzz, Dredge, Cinder.
- Target: Vex + 3-4 more READY today; all 12 READY by Thursday night; everything shipped before Friday 06:00 (owner's usage reset). Post progress in STATUS.md every couple of hours.
- ORCH reviews every new shot set hourly with Opus and posts fix lists here.

## 2026-11-04 13:15 UTC (ORCH): OWNER: ALL 12 shipped by END OF DAY TODAY. Plan: perfect one recipe on Vex, then batch it (supersedes the 13:05 timeline)
Owner: "figure out the most efficient way to get one done fast and then do them all like that, so it's all done by end of day today."
**Phase A, by ~15:30 UTC (Vex = the golden recipe):**
1. Shared look fix in one commit: toon light/look override so skin reads warm (not lilac/violet), darks lifted one step, saturation kept on signature colours. Verify on Vex AND Ryzz.
2. Vex fixes from the 12:55 review (cannon grey+brass, backpack + hoses, value). Mark Vex READY.
3. Write the recipe down as a script + checklist (docs/art/wardens/RECIPE_95.md): the exact Meshy settings, paint-over steps, look-override defaults, proportion/stance checks, the shot set, and a self-score at close-up and match zoom. Every step that can be a script, make a script.
**Phase B, ~15:30-21:00 UTC (batch):** one Opus agent per remaining Hunter, all in parallel, each runs RECIPE_95 on its branch using its reference sheets, ONE fix round on ORCH's review, then READY. No serial waiting.
**Phase C, by ~23:00 UTC:** main merges all READY branches in one integ and ships sync89. Anything under 95% ships anyway if it's better than the current procedural model, and keeps iterating tomorrow.
- ORCH reviews each batch shot set within the hour. Post READY lines in EXT_TO_MAIN as each lands.

## 13:10 UTC (ORCH): 3D review Dredge (r3d): ~75% close-up, ~60% match zoom
1. Eye: the six black crack strips sit on the orb as a black "spider/face" glyph. Make them thin pale-grey hairline cracks across the porthole glass (in front of the eye), not on the orb itself.
2. Helm: the porthole is three thick black concentric rings with no brass. Use one brass rim with rivets and dark only in the recess, and add the small grilled porthole above-left of the eye (it is on the portrait and turnaround).
3. Brass reads olive/mustard and plastic-shiny under the shared fix. Push it toward warm tarnished brass/copper (less green, rougher spec) and add rust streaks in the seams.
4. Ooze: the drips are flat black planks with hard outlines. Make them thinner, tapered strings with a faint crimson inner glow as the brief asks; the ones hanging off the eye now read as a cage over it.
5. Stance: the hull pitches so far forward that the front view is mostly top of hull. Lift the helm about 10-15 degrees so the eye faces the camera the way it does in the turnaround front.
6. Match zoom: he reads as a muddy brown blob with one red dot. Lift brass value one step, add a bright brass rim/spec on the helm and blunderbuss bell, and let the rib-core red glow show through the gashes.
7. KEEP: the overall silhouette (hull, winch, blunderbuss bell, claw, backward legs, boots), the red eye's punch, the lames and peeled tears.

## 13:10 UTC (ORCH): 3D review Ryzz (s3): ~78% close-up, ~60% match zoom
1. Skin: the shared fix worked and the face reads peach. But magenta smears bleed over her chest, arms and shoulders. Keep the pink glow to the scar, the choker charm and the corset piping only.
2. Pigtails: the pink ends are shredded strands that read as frayed/burnt. Model them as the art's few thick S-curl zigzag locks swooping outward, and make the blue upper volume smoother and less blocky.
3. The black scorched relic sticks up between the pigtails above her head. Seat it in the V on her back, below the shoulder line as in ryzz_back, and tone the rods from yellow-orange to copper.
4. Missing the pink gum bubble (KIT: "pink gum bubble"). Add it at least for idle and close-up.
5. Corset: the bolt keyhole should be a clean cutout with neon pink piping on the edge. Now it is glow streaks painted across the front.
6. Jacket/boots read pure black. Lift them to the art's charcoal-plum leather with visible copper zips and pink boot trim.
7. Match zoom: only the blue hair reads, and the body is a dark smudge. Brighten the pink corset and boot trim and add a stronger rim on the hair so the blue/pink split shows.
8. KEEP: the face paint (wink, fern scar, freckles), the copper hair ties, the hand-on-hip swagger, the hazard bands, the fishnets.

## 13:10 UTC (ORCH): 3D review Hem (s3): ~85% close-up, ~70% match zoom
1. Skin: it now reads pale-warm, which is correct. Keep it.
2. Mask: the 3/4 view shows hard low-poly facets and red smears. Smooth the shading, keep clean white porcelain with thin dark cracks, red-thread stitches, the gold top rim and one painted smile fragment (hem_mask_sheet).
3. Bow: it reads navy/blue with a salmon band. Make it a true black recurve, and make the string a bright glowing red line that is visible at rest. Add the thread spool at the grip.
4. Quiver needles: they are plain silver sticks. Give them visible eyes with red thread through them and a few loose red threads drifting (KIT "at rest").
5. Coat: it is shorter and less flared than the turnaround. Lengthen it to mid-calf with the asymmetric tail and the black lining showing, and clear the dark blotches on the sleeves in the 3/4 view.
6. Match zoom: she reads as a red/black blob with a white face, and the bow is invisible. Thicken the glowing string and the bow limbs' rim light so the bow silhouette reads.
7. KEEP: the bun and needles, the eyes/liner and glasses, the crimson high collar, the bandolier of needles, the bow in her LEFT hand, the boots.

## 13:10 UTC (ORCH): 3D review Kael (s3): ~70% close-up, ~65% match zoom
1. Mane: it is flat semi-transparent cream cards hanging like curtains over his face and chest. Make it opaque silver-white soft layered locks that fall back past the shoulders, with volume and spikes at the crown (kael_head_sheet). Keep it off the face and scarf.
2. Arm cracks: they read as flat white paint (giraffe pattern) on a reddish arm. Make them branching gold/white-hot glowing veins with bloom on the dark skin, on the RIGHT arm only.
3. Skin reads red-brown. Shift it to the art's very dark cool brown, because the shared warm tint is too strong on him.
4. Blade: it is a flat white plank with grey edges. It needs a jagged broken iron silhouette with iron bands, glowing cracks and bloom, plus black smoke. At match zoom it now reads as a white bar longer than his torso, so trim the length slightly.
5. Collar: it is a thick gold ring/torc. Use the art's broken gold shard pieces sitting on the scarf.
6. Posture: he is hunched with oversized shoulders. Stand him upright with the head higher, closer to the turnaround's proportions, and hold the sword point-down diagonally in the right hand with the chain wrapped on the forearm to the hook.
7. Match zoom: the hair blob and the white bar dominate. Fixing 1 and 4 should let the red kilt, gold belt and glowing arm read.
8. KEEP: the red scarf over the mouth, the narrowed eyes, the gold tally buckle, the red pleated kilt, the steel greaves and wrist cuffs, the chain and hook.

## 13:10 UTC (ORCH): 3D review Sable (s3): ~80% close-up, ~55% match zoom
1. Look fix landed for her: skin is the right lavender-grey and the jacket is a believable violet, no longer muddy/too dark. One-off check passes at close-up.
2. Hair: the model has TWO braids, one each side; the art has ONE braid over her right shoulder. Braids and back-of-head read tan/cream-blond; make them silver-white like the head sheet.
3. Crossbows are still too small and thin, and the violet bolt-tip glow is missing. Scale them about 1.5x to the crossbow sheet and add an emissive violet tip.
4. Red pendant is flat red with no glow; add the pink-red emissive halo. The fur collar reads as bright white; tint it grey-lilac.
5. Hold/proportions: side view is hunched forward with bent knees; art stands upright in a wide A-stance. Wings sit high and short; let them hang to mid-calf as in the turnaround.
6. Match zoom: the body breaks into black/white speckle noise and arms/crossbows vanish. Simplify texture contrast (flatten the leather highlights and chains) and add a violet rim so she holds one silhouette.
7. KEEP: the mask pushed up, feather antennae, almond half-lidded eyes, face, jacket cut, iridescent peacock-eye wings.

## 13:10 UTC (ORCH): 3D review Pip (s3): ~80% close-up, ~55% match zoom
1. Hue is now overcorrected: fur reads saturated coral/salmon-red; the art is a dusty rose pink with a cream belly. Pull saturation down and shift toward pink (less orange).
2. Flower crown is still only a few specks; model the full ring of white flowers from the head sheet on top of the goggles.
3. Lantern: held low at her side and barely lit. Raise it to chest height in the LEFT paw (art front view: both paws on the handle in front of the belly), make it about head-sized, glowing warm amber with a real light cast on her chest and cape.
4. Wings: flat panes with hard white grid veins; the art has soft pink, glowing translucent wings. Lose the grid, add pink tint and edge glow.
5. Proportions: limbs and neck read thin and long, torso stretched; the art is a chubbier, fluffier chibi fox. Thicken the chest fluff and thighs, shorten the neck.
6. Match zoom: dithered coral speckle with black specks along the outline; only the tail and lantern read. Smooth the fur texture and keep the tail tip a clean cream.
7. KEEP: the face (big amber eyes, blush, red-tipped ears), goggles, teal cape with leaf clasp, satchel, tail shape, arms clear of the body.

## 13:10 UTC (ORCH): 3D review Tarek (s3): ~72% close-up, ~50% match zoom
1. Look fix overshot warm: skin reads orange/terracotta-saturated; the art skin is a warm deep brown. Lower saturation, and keep the terracotta for the sash only.
2. Vest reads khaki/olive; it must be slate blue-grey (the cool contrast in his palette).
3. Bracers: currently lumpy rock knuckles on the fists only. The art has big forearm-length stone gauntlets (elbow to knuckle) with bright glowing amber cracks. Rebuild them and push the emissive.
4. Seeing-stones: flat, dull grey discs, iris barely visible. Give them rough rock depth, a crystal-lined opening and a glowing amber slit-pupil eye facing out (stone sheet); orbit them closer around the head.
5. Missing signatures: the amber ripple rings on the ground, the shard orbit around his right fist, and the glowing amber crystals in the locs (the yellow spikes on top of the hair look like stray geometry; replace with beads).
6. Proportions/hold: shoulders and deltoids over-bulked and hunched; the art is lean, long-legged, upright, with the right fist raised. Slim the upper body.
7. Match zoom: an orange-brown speckled blob, stones and bracers do not read. Fewer texture details, brighter amber glow points so the stones and fists pop.
8. KEEP: the bandana and grin, the locs with copper rings, the sash knot, the sand trousers, harness and wrapped feet.

## 13:10 UTC (ORCH): 3D review Ostra (s3): ~68% close-up, ~40% match zoom
1. Colour now overcorrected the other way: the coat is flat electric purple everywhere; the art coat is mostly BLACK with violet panels. Restore the black/violet split so the starfield reads through the tears.
2. Mask: the grin is white teeth; the art mouth glows violet. Add violet pinpoints in the black eye holes, the painted violet tear (viewer's left) and the glowing crack (viewer's right).
3. Halo: pale pink-white, smooth, and offset to one side. Make it violet emissive, cracked, larger than the head, centred behind it.
4. Void orb: a matte violet ball. Make it a black swirling core with a violet glow. Strings and card shards are still missing; add them.
5. Hold: both arms are stretched out like a zombie T-pose. Use the art pose: orb hand raised beside the head, the other hand low with long clawed fingers, body leaning forward.
6. Lower body: a rigid flat purple slab; it should be a smoky, tapering, curling wisp with stars, ending near the ground with a shadow gap.
7. Match zoom: reads as a small brown-purple smear plus a white crescent, and a stray solid blue disc sits at his feet. Fix the blue disc and add the violet rim from ostra_front_float.
8. KEEP: the cap shape with silver bells, the grey ruff, the starfield texture inside the coat, the dagged sleeves, the float height.

Shared look fix verdict: models are no longer too dark. Sable now reads right, but Pip and Tarek overshot into saturated coral/orange, and Ostra into flat bright purple. At match zoom all four still break into a high-contrast speckle/dither, so cut texture detail and add rim light.

## 13:10 UTC (ORCH): 3D review Breaker (s2): ~75% close-up, ~70% match zoom
1. Beard: rebuild as the head sheet's THREE stiff frozen red braids with silver rings and icy tips; s2 has one loose shaggy red mass covering his chest.
2. Hold (breaker_front): his right fist goes up at shoulder height near the hammer head, with the haft lying diagonally back over the RIGHT shoulder. s2 holds it upright in front of the shoulder with the hand at the chest, so the hammer reads raised rather than resting.
3. Shield: bring it in to rest against his LEFT forearm and hip, with the rope grip in that hand. s2 floats it beside him, detached, at shoulder height (front and 3/4 views show a gap).
4. Skin: add the frost cracks, barnacles and icicles to his arms and shoulders. s2's skin is smooth flat pale blue, the biggest texture gap at close-up. Add the kelp on his head and mantle, and darken the brows to red.
5. Props: the brass compass on the chest strap and the teddy bear on his belt are missing or hidden by the beard. Both are signature details.
6. Match zoom: the shield reads pinkish-brown and the ice block is barely visible. Lift the ice-blue value on the hammer head and the iron rim on the shield. Check the 1.5x scale against a medium hunter in the same frame.
7. KEEP: the bald head, white eyes, grin and tusks, the plain ice-block hammer in two bands with a rope-wrapped haft and no anchor, the prow shield with its broken top planks, flat figurehead and iron rim, and the mantle, belts, boots and back view (close to the turnaround).

## 14:10 UTC (ORCH): 3D review Ryzz (s5): ~84% close-up, ~70% match zoom
1. The gum bubble is a flat pink disc on her nose (a clown nose in 3/4). Move it to the lips as a glossy translucent sphere, off to one side.
2. Match zoom: the pigtails wash out to pale cyan/white and the pink ends vanish (the electric-blue far rim is too hot). Keep them mid-blue with pink tips; the hazard bands and boot trim are still not readable.
3. The pigtail bodies are faceted, low-poly blue slabs, and the pink ends are thin squiggle strands. Make them rounded, fuller curls, with pink sweeping through the outer half (as in ryzz_front).
4. Skin is orange/tan (worst on the thighs, where the fishnets don't read). It should be the art's pink-peach, with dark fishnet over the thighs.
5. The corset still has white/pink streak highlights across it. Make it a clean pink corset with a crisp neon bolt keyhole. The rods are bright orange, not copper.
6. The jacket is still near-black. Shift it to the art's plum-grey leather with copper zips.
Improved: magenta skin smears gone, gum bubble added, smooth blue pigtails with thick pink ends, relic rods now seated behind the shoulders (no longer above the head), charm and scar glow cleaner, jacket a little lighter.

## 14:10 UTC (ORCH): 3D review Hem (s4): ~83% close-up, ~65% match zoom
1. Match zoom: she is a red blob with white speckles. The black corset, trousers and bow are lost, and the mask is a white smear. Cut the white highlight noise, keep the corset and trousers black, and make the bow and string readable.
2. The coat is bright scarlet with white/pink highlight smears. The art is deep crimson with black lining. Darken it and clean up the paint.
3. Quiver needles read as black/orange arrows or paintbrushes. They should be arm-length silver needles, with the eye at the top and red thread drooping out (hem_weapons_sheet).
4. Back view: the coat tail flares into what looks like baggy red trousers. It needs the art's straight, split, asymmetric tail over black trousers, and the quiver's diagonal strap should read.
5. Tailor's shears at the hip, the lapel needle and the silver thimble claws are not visible. The forearm tape wrap reads as plain bandage.
6. Bow pose: it is held almost vertical against the body. Angle it out at her left side as in the turnaround; the glowing string is only visible in 3/4.
Improved: smooth porcelain mask with gold rim and stitches (no facets), true black recurve with a red glowing string, coat now mid-calf with a back tail, red-threaded needles, needles in the bun right, red rim at the match camera.

## 14:10 UTC (ORCH): 3D review Tarek (s6): ~76% close-up, ~55% match zoom
1. Stones: one hovers right in front of his face and hides the bandana and grin in the front, 3/4 and close-up views. They're also flat tan discs with yellow slit irises. Art: three rough geodes with crystal-lined openings and orange-amber eyes, orbiting above and beside the head.
2. Gauntlets are now forearm-length but look like cream skin with a giraffe pattern of yellow cracks. Art: chunky dark grey-brown rock plates that stand out from the arm, with orange crack glow. They need volume and a darker value.
3. Vest went saturated blue. It should be desaturated slate grey. Skin is still red-orange; push toward warm mid-brown.
4. Match zoom is one orange-brown blob. The vest, stones and bracers don't read, and the edges are speckled. Separate the values (grey vest, dark locs, amber glow).
5. Slimming overshot: legs are thin and knock-kneed and the trousers read orange. Art: sand trousers with knee patches, a wider stance and visible harness pitons.
6. Locs are short and clumped. Art: long locs past the shoulders with copper rings and amber beads.
Improved: slate (not khaki) vest, darker skin, real forearm bracers, raised right fist with orbiting shards and a bright crack glow, amber beads, leaner body.

## 14:10 UTC (ORCH): 3D review Dredge (r3f): ~72% close-up, ~55% match zoom
1. Brass is mustard-yellow glossy plastic. Art: dark tarnished bronze with heavy rivet rows, plate seams and grime. Darken and desaturate it, add rivets, and break up the uniform spec.
2. Eye is a flat saturated red disc with a single white dot. The hairline cracks and the red-glowing recess don't read. Art: a smaller glassy orb, cracked, set deep in the helm.
3. Tar is too thin overall, and the art does run tar from the eye and hull down over the ribs. Restore some drips off the helm rim, not across the lens.
4. Hull and lames are faceted low-poly. Black outline triangles and speckle sit on the hull, worst at match zoom, where he's a brown blob and the eye is barely visible.
5. Stance still pitches forward and hunches; the hull sits low and the legs are short. Art: an upright, tall-legged robot with the hull on top. The grilled port reads as red stripes; it should be a brass grille with dark slots.
Improved: black glyph gone, one riveted brass ring round the eye, warmer brass than olive, red rib core and tears, the eye faces the camera, back hatch and pipe modelled.

## 16:10 UTC (ORCH): 3D review Claire (b2): ~62% close-up, ~52% match zoom
1. Hair: the pigtails are thick black braided ropes lying over the chest, with noisy clumps on the back. They should be long, loose, wavy low pigtails that hang to the hips, with the crystal clips at the ties (no clips yet).
2. Horns: they now curl, but they're ribbed, rise above the crown and float off the head. Seat them low at the temples and curl them back and down, tight to the skull.
3. Face and arms: blush and red lips are smeared like paint, the eyes are flat white, and the raised forearm is a stretched, flat ribbon. The wing membranes show stretched-texture streaks.
4. Match zoom: she reads as a white stick with a purple hood. Wings and tail are lost; only the spear and skates read.
Improved/Keep: the horns curl now (no longer straight up); the spear is taller than her; the skates, spaded tail, dark wings, pale body and crystal skirt are all there.

## 16:10 UTC (ORCH): 3D review Cinder (b3): ~65% close-up, ~45% match zoom
1. Crest: it's an opaque white fan sticking out to one side of the head, with a spike on top. It should be a thin, translucent fin-crest with a glowing orange spiky edge, running from the brow down the neck and spine onto the tail.
2. Lance: it's a plain orange/yellow plastic tube with no brass-and-glass chamber and no live flame. No ribbed copper hose visibly connects it to the tank (it's in the correct left hand).
3. Emissive: the spots, vials and crest edge don't glow. At match zoom she's a muddy brown-purple blob, and the yellow lance is the only clear read.
4. Goggles: I can't see a cracked lens. The grin is narrower and less toothy than the art.
Improved/Keep: rounded salamander face (not a snout), big amber eyes, black skin with orange spots and belly, brass goggles, vest with vial bandolier, red apron, back tank, long finned tail.

## 16:10 UTC (ORCH): 3D review Kael (b9): ~70% close-up, ~63% match zoom
1. Blade and arm: the blade is still a flat white painted stripe, not a white-hot glowing core, and there's almost no demon smoke. The arm cracks are still flat white painted blotches, not glowing magma lines.
2. Mane: stringy dreadlock strands that sit mostly behind the head, sparse and short at the front. It should be soft layered locks falling past the shoulders at the front too.
3. Skin and pose: the skin is still purple/red-brown (not very dark cool brown), the head is small and pushed forward (still hunched), and the scarf bleeds a red smear onto the chest.
4. Collar: chunky rectangular gold blocks floating over the scarf. It needs thinner, broken, jagged torc plates sitting on the neck.
Improved/Keep: red mask-scarf, gold collar now reads from above, harness, tally belt, pleated red skirt, greaves, shackle, chain-wrapped arm, hook on the chain, white mane reads at match zoom.

## 17:10 UTC (ORCH): 3D review Pip (b10): ~83% close-up, ~76% match zoom, face ~80%
1. Face: blotchy cream mask patches on cheeks/muzzle and dark smudges on forehead/ears; paint one clean cream muzzle + two soft blush dots. Eyes are the right size, but the catchlights don't match and the lids are thin, so add the art's heavy lash wing.
2. Wings: opaque flat grey-white panes. Make them translucent with an iridescent pink rim and veins; at match zoom they read as white blobs.
3. Lantern: blocky box with a pixelated flame texture. Add a bevelled cage, a smooth emissive amber core and a halo. In a dimmed match frame (35%, my simulation) it doesn't glow, though the art builds the whole read on it.
4. Match zoom: the face breaks into pink/cream noise and the cape barely reads. Push the teal cape value and keep the goggles' brass.
5. Cape front drape is a thin scarf; the art wraps it over both shoulders. The flower ring is fine.
Improved/Keep: head size, goggles, likeness (smile, fang, eye colour), tail cream tip, pink palette, satchel strap. S2's 90/89 is generous.

## 17:10 UTC (ORCH): 3D review Cinder (b4): ~72% close-up, ~55% match zoom, face ~68%
1. Face: the grin is a thin slit with tiny teeth. The art has a wide, tall open grin with a row of big teeth and an orange gum line. The snout is short and round, the brows/liner are missing, and the eyes are good but small.
2. Crest: now an opaque white sunburst halo with a yellow zigzag rim, radial and symmetric. The art has a swept-back, translucent grey-lilac fin with dark ray spines and an orange rim. At match zoom the white disc is the brightest thing on screen.
3. Dark scene (simulated): the body vanishes and only the crest reads. The vials, the lance flame and the orange spots need real emission.
4. Lance: a pale cage stick. Make the barrel dark steel/copper with a hot orange nozzle, and the hose needs to read connecting tank to lance.
5. Tail: a flat broad slab from the back. It needs the art's big rounded loop with an orange-rimmed fin. The vials are clumped lumps, not a neat bandolier.
Improved/Keep: crest now reads front/back, glowing vials, copper tank + hose loops, purple/orange palette, goggles, eyes.

## 17:10 UTC (ORCH): 3D review Vex (r3f): ~81% close-up, ~79% match zoom, face ~80%
1. Upper chest/belly: pale white smear patches and dark strap streaks. The circuit tattoos still don't read as crisp green lines, and the cleavage/gorget area is the weakest region.
2. Face: the eyeshadow is over-saturated magenta-red, and the face is small and a bit gaunt. Soften it to the sheet's smoky grey-plum, add the cheek circuit tattoo under the eye and keep the smirk. The lens is now good.
3. Gorget: the sheet's bronze plated collar with its green glow slot is mostly lost. It reads as a dark neck band.
4. Gun mount/jacket: grey smeared block, pale patches on the left sleeve. Clean the gunmetal and the bronze bands.
5. Dark scene (simulated): the body goes to black and only the hair reads. The lens, tattoos and gorget slot need emission so she reads at night.
Improved/Keep: lens dome (clean rings), green eye, smirk, hair and braids, cartridge belt, black + toxic green silhouette, minigun read at match zoom.

## 17:10 UTC (ORCH): match-zoom v2 verdict
Speckle is about halved, not gone (captions: 6-7.7% -> 2.8-4.9%). Ostra, Vex, Ryzz and Hem are now clean; the edge-on wing streaks and pale fringe are gone, and Hem's red and Ostra's purple read as solid shapes. Keep it as the shared baseline.
Hem, Ostra, Ryzz and Vex now read at match zoom. Sable is mostly white and pale lilac (17% pale pixels), so she reads as a silhouette with no colour hook.
Tarek is the weakest: he is still a brown, busy blob with yellow bead dots. The gauntlets don't read, and the stones are tan dots with no orange eye. The fix took the noise out but gave him no read; that needs model and palette work, not the shader.
The new pose_clear frame is right: no HUD, sign, aim line or grass over the hero. Every Hunter should reshoot their match crop with it (Tarek s11 and Dredge r3i still show an aim line).

## 17:10 UTC (ORCH): 3D review Tarek (s11): ~80% close-up, ~55% match zoom, face ~82%
1. The gauntlets are near-black boulders hung on the forearm. The art has tan-grey stone plates fitted elbow to knuckle with orange cracks. Make them lighter, warm grey-tan, flatter and tight to the arm.
2. The seeing-stones still show no orange eye from the camera: brown swirl rocks close up, tan dots in game. Make one bright orange iris on each outward face and push emissive so it reads at match zoom.
3. The knees still turn in. Front view: knees straight above the feet, with a slight bend.
4. The orange sash and knot don't read; the waist is busy fragments with a white fringe. Give him one solid orange-red sash with a hanging tail.
5. Match: still a muddy brown column with yellow speckles. Cut the beads and plates at the far LOD and keep the grey vest, the orange sash and the two stones as clean blocks. Reshoot on pose_clear with v2 (the s11 match is pre-v2 and still shows the aim line).
Improved: the face (warm smile, blindfold, deep-brown skin) and the locs with copper beads closely match the head sheet; the gauntlets are fewer, chunkier slabs; the stones sit beside the head.

## 18:20 UTC (ORCH): ORCH reviews paused (owner: this account is low on usage until Fri 06:00)
- ORCH stops the per-round image reviews. Self-review each round with the owner's rubric v2 (full body, face close-up, match zoom, dark scene; MAIN_TO_EXT 17:05) and score honestly: ORCH's reads ran 5-15 pts below your self-scores, so calibrate down.
- Dredge: ship r3j only if its limbs are back in every view; otherwise keep r3h in art-integ.
- ORCH check-ins are now every 4 h, routing only.

## 2026-11-04 18:55 UTC (ext): OWNER_REVIEW item 53 (Sable: infinite dash-reset loop with a flip, clear reset feedback; Bola also slows). Small; Opus for the flip animation. After your current face pass item, or in parallel if you have a free slot.

## 2026-11-04 18:58 UTC (ext): OWNER_REVIEW item 54 (Sable's Encore: dance animation + source blade cadence 0.2 s). Do it with item 53 on one Sable branch (Opus for the animation). No self-slow unless the owner confirms (ext is asking).

## 2026-11-04 19:02 UTC (ext): OWNER_REVIEW item 55 (Hem's draw reticle exactly like the source's: V-lines closing, star glint, Supercharged long line, overdraw dim, perfect star). Owner priority. Opus. Use the hero-ref pin.md reticle section + the Myth footage frames on the server.

## 2026-11-04 19:05 UTC (ext): OWNER_REVIEW item 56: BUG, your own Boki bends your abilities (Hem RMB example). High priority; a central fix in the projectile hit filter + Displace (your online-displace path): friendly Boki/hunters are pass-through for your abilities. List any Boki-side (kin_*) change for main. Opus.

## 2026-11-04 19:10 UTC (ext): OWNER_REVIEW item 57: Kael's Warchain haul must curve clearly toward where you look (it reads as always direct). Same agent who did ext/zedran-warchain if possible. Opus.

## 2026-11-04 19:12 UTC (ext): CORRECTION, item 55 -> see 55b: Hem's reticle is a line that FILLS from her outward with a small circle at the perfect-timing point that flashes when the fill reaches it (owner). Not the V-lines in the hero-ref notes.

## 2026-11-04 19:20 UTC (ext): OWNER_REVIEW item 58: BUG, Dredge's hook pulls at an off angle while Fused. Do it with item 56 (same Displace/collision family). List any merge_form change for main.

## 2026-11-04 19:25 UTC (ext): OWNER_REVIEW item 59: OWNER OVERRIDE: Breaker's LMB hold spins the hammer again (reverses your e625aa8e change). Spin = charge motion; slam on release; keep items 48/49/51. Opus.

## 2026-11-04 19:30 UTC (ext): OWNER_REVIEW item 60: Ostra's LMB: continuous charge from wait time (bigger, harder, slows at full) and every orb passes through walls (owner override on the data). Sonnet is fine; small.

## 2026-11-04 19:35 UTC (ext): OWNER_REVIEW item 61: Tarek's Quakefall: cap the hold at ~0.4-0.5 s (auto-fires), hold = hop forward+up then slam, tap = instant slam in front, slightly smaller circle. Opus (feel).

## 2026-11-04 19:40 UTC (ext): OWNER_REVIEW item 62: Claire's Skate works in the air (starts at once, ice ribbon, gentle descent, carries over gaps); remove the buffer-to-landing from item 12. Opus.

## 2026-11-04 19:47 UTC (ext): OWNER_REVIEW item 64: Claire skate -> ult keeps momentum (her DashFlow row). Same branch as item 62.

## 2026-11-04 19:50 UTC (ext): OWNER_REVIEW item 65: Claire's Rimelock = frozen statue (facing/pose locked, no turning). With item 64: a skating cast makes the statue slide in the skate direction, easing to a stop, then rooted. Same branch as 62/64.

## 2026-11-04 19:52 UTC (ext): OWNER_REVIEW item 66: Cinder: no LMB during her ult (Flue Flight); E Heat Shield stays allowed. Small, Sonnet.

## 2026-11-04 19:55 UTC (ext): OWNER_REVIEW item 67: Tarek's rocks taller (~1.6-2x) and much more noticeable; keep his climb working. Sonnet or Opus at your call.

## 2026-11-04 19:58 UTC (ext): OWNER_REVIEW item 68: Vex's E (Longneedle): wider beam, camera pushes out toward the aim while casting, fires exactly along her aim. Opus (feel/camera).

## 2026-11-04 20:00 UTC (ext): OWNER_REVIEW item 69: 2 gloves (Q and V) in the arena loadout and everywhere a glove is chosen/shown (arena.gd is single-glove today). Sonnet. If the HUD/home loadout parts are main's files, list the wiring for main.

## 2026-11-04 20:05 UTC (ext): OWNER_REVIEW item 70: Ryzz quick data tune: autos rate 0.8->0.72, bolt speed 34->37; Wirerun dist [5,8.5]->[7.5,13], speed 32->40. Sonnet, small; land it fast.

## 2026-11-04 20:10 UTC (ext): OWNER_REVIEW items 71-72 (Ryzz): Skycall orb fling shorter; an orb pulled toward her within ~9 m comes to her and resets Wirerun; Kitefall spreads the highest Static count to everyone it hits. Do with item 70 on one Ryzz branch (Opus for 71).

## 2026-11-04 20:12 UTC (ext): OWNER_REVIEW item 73: BUG, Ryzz's Skycall sometimes pushes the wrong way: store the drag vector at commit, apply it to all inside. Same Ryzz branch.

## 2026-11-04 20:14 UTC (ext): OWNER_REVIEW item 74: BUG, the Storm Rod's charge orb keeps adding Static to the hit foe. The Rod gives exactly 1 stack; the orb never stacks on its own. Same Ryzz branch.

## 2026-11-04 20:16 UTC (ext): OWNER_REVIEW item 75: Ostra Shift drift 0.2 -> 0.3 of run speed (data + text). Batch with item 60.

## 2026-11-04 20:35 UTC (ext): OWNER_REVIEW item 76: weapons look bolted on. Cause: warden_glb.gd `_hold_weapon` re-parents the .glb weapon onto the old procedural Gun node with its fixed offset/scale; never fitted to the new hands. Per-Hunter grip fit + closed hand poses + off-hand IK for two-handers + matching texture/shader. Do it alongside the face pass (same art/shader work). Opus.

## 2026-11-04 20:38 UTC (ext): OWNER_REVIEW item 76b supersedes 76's approach: keep each Warden's weapon IN its .glb, skinned to its hand/arm bones (it's part of the design), FX points as empties on it, the procedural Gun node only an invisible aim reference; separate pieces only for things that leave the hand (arrow, thrown hammer, extended chain). Opus. With the face pass.

## 2026-11-04 19:40 UTC (ext): ACCOUNTS: S2's and main's accounts are at 95%+; ext's has the most left until Friday. ext now BUILDS the owner's item queue itself (Sonnet, locally).
- ext takes OWNER_REVIEW items 53–75 (Sable 53/54, Hem 55/55b, Boki/Fused collision 56/58, Kael 57, Breaker 59, Ostra 60/75, Tarek 61/67, Claire 62/64/65, glider 63, Cinder 66, Vex E 68, gloves 69, Ryzz 70–74). **S2/S1: don't start any of them.** If you already started one, post its branch/state in STATUS and stop; ext will pick it up from there.
- Item 76/76b (weapons on the .glb) and the face pass need the server's Meshy/Blender: they wait for S2's reset unless S2 has budget for them.

## 2026-11-05 00:15 UTC (ext): NEW ACCOUNT for S2: big work order (owner: "offload a bunch of important work there")
The owner is signing this window into a fresh account (full weekly usage). The 19:40 "ext takes 53–75" note is lifted for the items below. Re-read `briefs/DECISIONS.md` and the items in `briefs/OWNER_REVIEW_1103.md` before each branch (a later item, e.g. 55b, 101b, overrides an earlier one).

**S1 keeps:** 94 perf (103 sound first), then 96 combat clarity (+96b, 97, 100, 102, 106). **ext keeps:** ext/tut-airdash (85/104), merges/review. Don't touch those.

**S2 takes, in this order (up to 4 agents at once; Sonnet default, Opus 5.5 medium where noted):**
1. **Kits A (one branch per hero, from origin/main):**
   - Sable 53+54 (Opus)
   - Hem 55b (Opus; it's a filling line + small perfect-timing circle, no V, no UI)
   - Kael 57
   - Breaker 59 (the LMB hold spin is RESTORED)
   - Ostra 60+75
   - Tarek 61+67
   - Cinder 66
   - Vex 68 (Opus, camera)
   - gloves 69
   - glider 63
2. **Claire 62+64+65:** continue S1's WIP `ext/claire-62-65` @ 92ad07b0 (Opus).
3. **98:** choose ability ranks (Ctrl+key / "+" on the slot, max one first; bots keep the fixed order; `bonus_point_at_max` flag off).
4. **99:** full-inventory looting (honest smart-loot message, swap/drop panel).
5. **101 + 101b:** ally boxes team-coloured on the map / in the world; box revive ~7.5 s channel with the potion vulnerability; respawn beacons (revive all, loud + global notice).
6. **105:** Boki talk banks to data, ≤6 words, 5x lines, no repeat within 10, situational triggers (farm + match). Text-heavy: Sonnet. **Note:** `scripts/ui/boki_speech.gd` (shared speech SCALE) lands on ext/tut-airdash; build on it once merged, or keep 105 to the line banks + triggers.
7. **If budget remains:** 76b weapons skinned on the .glb + the face pass (Blender/Meshy on the box, Opus).

**Already done (don't redo):** 56/58 (`ext/friendly-bodies`), 70–74 (`ext/ryzz-70-74`), 76's rigfix (merged in sync91).

**Rules:** as SERVER2_START.md.
- Base each branch on current origin/main (fe51b43b or later).
- One full suite per branch at the end, targeted checks while working.
- Mark READY in STATUS.md (ext/server-status2) with the branch, commit, items done/differs, a check table, screenshot paths and owner Qs.
- ext reviews and merges. Update STATUS at least hourly.

## 2026-11-05 00:20 UTC (ext): OWNER: big ART workflow for S2 (alongside the 00:15 order)
Owner: "I need better animations for all the characters, better 3D models for most characters (especially Kael, Tarek and Breaker), better VFX on abilities, better sounds, better Boki."

**Run 4 lanes at once (re-balance as lanes finish):**

| Lane | Work |
|---|---|
| ART-1 | models + animations |
| ART-2 | VFX + sound |
| KITS | the 00:15 order, items 1–2 first |
| BOKI | Boki models + animation (starts once the Kael pilot is approved) |

Items 98/99/101b/105 slot into KITS after the kits.

**Quality bar (all lanes):** League-of-Legends-level readability at the match camera (top-down, zoomed out).
- Strong silhouettes, clear shapes, saturated but tasteful colour, faces readable at the farm/viewer camera.
- Our own designs only (originality guard: no copying any game's characters, sounds or effects; mood references only).
- Every external asset must be CC0 (or made by us / our image-gen). Log each in `docs/CREDITS.md` with source + licence. Nothing with attribution-required or unclear licences.

### ART-1: models + animations (Opus 5.5)
- **Pilot: Kael first, then Tarek, then Breaker, then the rest.** The rest are ranked by how weak they look now; Vex last (already redone).
- **Model, per Hero:**
  - Rebuild in Blender on the shared armature per `docs/RIG_STANDARD.md` (`--rig-standard-check` must pass), like Vex's Blender pass (`ext/warden-models`) but a clear step up from its "stylised toy" finish.
  - A sculpted face with expression.
  - Proper hands holding the weapon, the weapon skinned in the .glb (item 76b).
  - Proportions and size per DECISIONS (Breaker 1.5x).
  - Our concept art from the IMG agent / anthum as the reference.
  - A tri budget per the perf pass (item 94: agree a number with S1's perf findings, e.g. ≤20k incl. weapon).
- **Animations, per Hero on the shared armature:**
  - idle, a signature stance (item 52), walk/run, a distinct dash (item 35), the air dash/glide
  - every ability (LMB/RMB/Shift/E/R wind-up → release → recover, timed to the kit's real timings)
  - hit react, downed, revive, death, jump/land, Fusion transform
  - an emote
  - Hand-keyed in Blender (scripted where useful). A CC0 base library (e.g. Quaternius' CC0 animation library) may be used for locomotion only, retargeted and then reworked so it reads as that Hero's personality (item 37).
  - Blend trees in Godot so moves flow (item 32 dash→ability).
- **Approval gate:** post Kael's turntable + an animation sheet (GIFs/MP4 of idle, run, dash, each ability) to ext/hero-shots-s2 and EXT_TO_MAIN for **owner approval before rolling out** the rest. Then one Hero per agent run.

### ART-2: ability VFX + sounds (Opus for VFX, Sonnet OK for sound)
- **Per Hero, every ability:** clear telegraph → impact → linger, in that Hero's palette.
  - Shader-based (Godot GPU particles, mesh trails, dissolve/noise shaders), not flat rings.
  - Follow S1's item 96 colour rule (you/ally/enemy); S1 owns the HUD and telegraph colour rule, you own the ability looks. Coordinate via STATUS.
  - Respect the perf budget (item 94: particle caps, LOD at distance).
  - Order: the Heroes in ART-1's order, so a Hero's model, animation and VFX land together.
- **Sound, per Hero:** weapon, each ability (cast + impact), footsteps by surface, dash, hurt/downed voice grunts (no words), plus the UI, farm and Boki sounds.
  - Today's 426 files in `audio/` are mostly synthesized: replace the weak ones.
  - Sources: our own synthesis/layering or CC0 libraries only, logged in CREDITS.
  - Mix with a consistent loudness, routed to the right buses (Match bus per item 103).
- **Approval gate:** Kael's full ability VFX + sound set as a short video for owner approval first.

### BOKI: models + animation (Opus)
- Read `docs/BOKI_IDENTITY.md` first.
- **Per species, then its grown/Fused forms:** a cute, readable creature model in Blender with a face that emotes (happy/sad/sleepy/angry), and an idle, run, attack/ability, happy hop, sleep, eat, work (chop/mine/carry, item 91) and get-petted animation.
- Element VFX on their abilities (with ART-2).
- **Reserved files:** kin_*, merge_*, capture*, field_book, boki_hud, bot_kin. Ship new assets + a new loader/scene, and list the one-line wiring in reserved files for main (ext merges).
- **Approval gate:** one species (the starter) first.

**Reporting:** a STATUS.md section per lane: branch, commit, Heroes/species done, shots/videos (viewed), CREDITS added, owner Qs. ext reviews and merges; nothing to main directly.

## 2026-11-05 00:40 UTC (ext): OWNER: GO FAST. Your account resets Thursday, so use all of it now
- Run **up to 8 agents at once** (16 CPUs; set the godot slot queue to 8 if lower). Use Opus 5.5 freely where quality matters (all art, VFX, Boki, complex kits).
- **Lanes, in priority order:**
  1. ART-1 models+anim: Kael, Tarek, Breaker in parallel (one agent each).
  2. ART-2 VFX+sound: Kael first, then the next as models land.
  3. BOKI: the starter species.
  4. Kits A: several heroes in parallel.
  5. Claire 62/64/65.
  6. 76b weapons skinned on the .glb (folds into ART-1 per hero).
- **The approval gates still apply** (Kael pilot, first Boki), but don't idle while waiting: keep building Tarek/Breaker in the same style and adjust after the owner's notes.
- **Items 98, 99, 101/101b, 105 are MOVED to a new cloud session ("S4")**; drop them from your list. Combat clarity is "S3" (cloud). S1 = perf.
- Commit + push every 30 min so nothing is lost at the reset. Post READY branches in STATUS as each lands.

## 2026-11-05 00:47 UTC (ext): add OWNER_REVIEW item 107 (a cooler, higher drop) as a lane when a slot frees: Opus, with ART-2 VFX/sound. Branch `ext/drop-107`. Post a drop video for owner review.

## 2026-11-05 00:52 UTC (ext): OWNER_REVIEW item 108 (look pass)
- ART-1 order is now **Kael, Tarek, Breaker, Ostra**, then the rest; **Hem's** rework is next after Ostra (more striking and attractive, tasteful).
- **Pip** ~10-15% smaller (a quick data change with the hitbox, item 46).
- **Vex's splash art:** redo it via the image-gen pipeline (or post a request in briefs/INBOX_IMG.md for the IMG agent).

## 2026-11-05 02:02 UTC (ext): HEM OFFICIAL REFERENCE (owner-picked): `briefs/art-refs/hem_v4_needlebow.png`
- **Use this for Hem's model + kit visuals.** It replaces her older look.
- **The design:**
  - a giant silver sewing-needle bow with a glowing red-thread string (the needle's eye at the tips)
  - silver needle arrows trailing red thread (missed arrows linger as needles stuck in the ground, threads attached)
  - a big red thread-spool quiver on her right hip
  - a high ponytail tied in red thread and pinned with a silver needle
  - a long red scarf trailing behind (her top-down signature: give it cloth/spring sim, cheap)
  - a red-stitched eye mask, green eyes, tanned skin
  - a black-and-red stitched corset showing the midriff, stitched pauldrons + half-sleeves on both arms, stitched bracers
  - black capris, tall laced boots, silver tailor's scissors on her belt
- **ext's notes for the model:**
  - Push a little more red onto the shoulders/scarf so she reads from above against dark ground.
  - Keep the bow silhouette exact.
- Her ART-1 slot moves up: right after Kael (the owner is actively iterating on her).

## 2026-11-05 02:04 UTC (ext): Hem props sheet: `briefs/art-refs/hem_v4_props.png` (owner-generated)
Use it with hem_v4_needlebow.png for the weapon/prop meshes:
- **bow:** the left one, slotted needle eyes at both tips, red-wrapped grip, glowing thread string
- **arrows:** the fletched needle arrow with red thread binding
- **quiver:** the spool quiver
- **mask, hairpin, scissors:** as drawn

## 2026-11-05 02:12 UTC (ext): Hem splash (owner-approved candidate): `briefs/art-refs/hem_v4_splash.png`
- Use it for her menu splash + portrait crop (replaces `art/portraits/archer_splash`/portrait via the portraits pipeline) when her model lands, or sooner if a lane is free.
- The owner may send a touched-up version (shadow's bow / mask stitching); if so, ext will replace this file.

## 2026-11-05 02:21 UTC (ext): Hem colour reference: `briefs/art-refs/hem_v5_sheet_vivid.png`
- Owner's pick for colour: vivid green eyes, a slightly darker warm tan skin, crisp reds.
- **Use it for colours / skin tone. Use `hem_v4_needlebow.png` for the outfit cut: she wears CAPRIS (mid-calf), not full pants.**

## 2026-11-05 02:24 UTC (ext): RENAME Hem → **Lisette** ("the Red Stitch"), owner decision (DECISIONS.md updated)
- **Rename sweep** (small, Sonnet, a KITS-lane branch `ext/rename-lisette` from main):
  - every player-facing string, i.e. the archetype JSON display name, hero_kit, HUD/menus, tutorial/lore text and the wiki via gen_wiki
  - the id `archer` and file names unchanged
  - reserved kin_* text: list the lines for main
- **Model reference for 3D:** `briefs/art-refs/lisette_turnaround_apose.png`, a clean A-pose in 4 views (front, left, back, right).
  - It shows full-length pants: **build CAPRIS (mid-calf) per hem_FINAL_sheet.png**.
  - The long hanging red scarf here is fine for the rest pose (cloth sim).
  - No weapons on the turnaround: build them from hem_v4_props.png.

## 2026-11-05 02:26 UTC (ext): Lisette A-pose replaced (now with capris)
`briefs/art-refs/lisette_turnaround_apose.png` is the model reference. Use **skin tone from hem_FINAL_sheet.png** (a darker warm tan; the turnaround came out lighter).

## 2026-11-05 02:35 UTC (ext): KAEL MASTER SHEET (owner-picked): `briefs/art-refs/kael_FINAL_sheet.png`
- **Use this for Kael's model** (ART-1 pilot). It replaces the older Kael look.
- **The design:**
  - **body:** taller, heroic proportions; deep dark brown skin; shirtless, abs, battle scars
  - **head:** long flowing white hair; a scar over the left eye, which glows white
  - **scarf:** an ENORMOUS crimson scarf over the mouth and nose, with ember-glowing burn holes (the iron collar relic hidden beneath) and two very long tattered tails streaming behind him. This is his top-down signature: give it cloth/spring sim, cheap.
  - **right arm:** cracked shoulder-to-wrist with glowing white-gold fissures, the wrist bandaged with a rusted chain ending in a hook (the Warchain)
  - **armour:** engraved silver on the left shoulder, forearms and shins; leather straps; dark trousers; boots
  - **weapon:** a straight, broad, jagged greatsword glowing white-hot, with sparks and dark smoke
- No kilt (owner choice). An A-pose turnaround will follow.

## 2026-11-05 02:39 UTC (ext): Kael splash (owner-approved): `briefs/art-refs/kael_splash.png`
- Use it for his menu splash + portrait crop.
- Model note: the splash puts the chain on his left fist. **The model follows the master sheet: chain + hook on the RIGHT (cracked, bandaged) wrist.**

## 2026-11-05 02:41 UTC (ext): Kael weapon sheet: `briefs/art-refs/kael_weapons.png`
- **Use it for:** the shape and detail. The jagged blade glows white-hot with molten cracks; there's a flat iron crossguard, a leather-wrapped grip and a spiked pommel. The chain and hook are rusted; his right wrist is bandaged, with the chain wrapped round it.
- **Scale: follow the master sheet and splash, NOT this sheet's silhouette.** The blade is long and broad, roughly shoulder-to-ankle on him, with a shorter grip than drawn here.

## 2026-11-05 03:00 UTC (ext): PAUSE Breaker + Ostra MODELS: new concepts in progress (owner)
- **Breaker** is being fully redesigned: a colossal, very wide frozen deep-sea DIVER (brass diving helmet with glowing eyes, anchor on a chain, a ship's-hatch shield, a glowing compass heart). Don't spend more on `ext/art1-breaker` from the old look; keep the rig/proportion groundwork only.
- **Ostra** is also getting new concepts. Pause `ext/art1-ostra` the same way.
- **Lisette (ex-Hem) and Kael have FINAL owner references** in `briefs/art-refs/`: lisette/hem_FINAL_sheet, hem_v4_props, hem_v4_splash, lisette_turnaround_apose; kael_FINAL_sheet, kael_turnaround_apose, kael_weapons, kael_splash.
  - If `ext/art1-kael` was built from the old look, rework it to kael_FINAL_sheet (huge streaming scarf, silver armour, no kilt).
  - Lisette next in ART-1.
- Pip size (108) and kits continue as planned.

## 2026-11-05 03:02 UTC (ext): OWNER ANSWERS on S2's two approvals
- **BOKI starter Vespyx (ext/boki-starter 5aaaf165): APPROVED with one fix.** The owner says "the Boki has very big eyes in game for some reason". Scale the eyes down in the in-game model (the concept/splash look is fine), then continue with the grown/Fused forms and the next species.
- **ART-2 Kael VFX + sound (ext/art2-kael 0fbc63e6): provisionally OK.** The owner can't judge VFX from stills: "I'd need to play it". Mark it READY so S5 merges it; owner notes come after playtesting. Continue ART-2 for the next hero.
- Breaker redesign in progress (a mossy, long-sunken diver with an emotive glowing face); the model stays paused.

## 2026-11-05 03:12 UTC (ext): BREAKER NEW DESIGN (owner-picked): `briefs/art-refs/breaker_FINAL_sheet.png`
A full redesign; `ext/art1-breaker` restarts from this.
- **Body:** a non-human, top-heavy construct. The giant round body is a sunken ship's hull: dark planks, rusted iron bands, moss, barnacles, seaweed, teal light glowing between the planks. Broken mast stumps with rope and sail scraps rise from his shoulders. Stubby legs; enormous iron-banded arms and fists.
- **Head:** a small brass diving-helmet dome whose porthole shows only two simple glowing teal eyes. Animate them as moods (happy, angry, determined, sad), per the expression row; swap textures or a shader param.
- **Details:** a brass compass glowing on his chest. A glowing anglerfish companion dangles on a line from his mast (secondary motion).
- **Shield:** a tall carved hatch door with a figurehead.
- **Weapon:** a HUGE capstan hammer (a drum with a spike, wound with chain, on an iron haft), chained to his wrist. It fits his throw / recall / spin kit (item 59 spin).
- **Size:** keep the Breaker 1.5x scale; the hitbox matches the round body (item 46).
- An A-pose turnaround and weapon sheet will follow.

## 2026-11-05 03:14 UTC (ext): Breaker retitled "the Sunken Bulwark" (DECISIONS updated)
Update the player-facing text in the same rename sweep as Lisette. The anglerfish design question is pending the owner.

## 2026-11-05 03:16 UTC (ext): Breaker turnaround + ANGLERFISH DECISION (owner)
- **Model reference:** `briefs/art-refs/breaker_turnaround.png`, 4 views: front, left, back, right. Ignore the garbled expression row at the bottom; use the master sheet's.
- **Anglerfish (owner decision): always on him, COSMETIC ONLY.** No kit or balance change. It dangles on its line from the broken mast and reacts:
  - **Walking:** bobs and swings (spring sim, cheap).
  - **Blocking a hit:** shivers.
  - **Mood:** wiggles happily when his porthole mood is happy.
  - **Ult** (the ice / sea path over the abyss): its lure flares bright for the duration.
  - Its lure is a small glowing dot visible from top-down. Keep it subtle enough not to look like a pickup or projectile (clarity, item 96).

## 2026-11-05 03:18 UTC (ext): Breaker weapon sheet: `briefs/art-refs/breaker_weapons.png`
- **Use for shape/detail:**
  - **Hammer:** a capstan-drum head of iron-banded planks with spikes on both ends, on an iron haft.
  - **Chain:** a long chain ending in a wrist shackle.
  - **Shield:** the figurehead shield; its back is planks with an iron cross brace.
- **Scale and two fixes:**
  - **Hammer size:** the drum must be as big as his torso and the haft as long as his arm (per the master sheet); this sheet draws it slimmer.
  - **Chain:** wound around the drum, as on the master sheet.
  - **Shield:** taller than his body.

## 2026-11-05 03:22 UTC (ext): Breaker splash: `briefs/art-refs/breaker_splash.png`
His ult moment: a teal sea path over the abyss, allies crossing behind him, shield blocking raiders. Use it for the menu splash + portrait crop.

## 2026-11-05 03:38 UTC (ext): OSTRA NEW DESIGN (owner-picked): `briefs/art-refs/ostra_FINAL_sheet.png`
A full redesign; `ext/art1-ostra` restarts from this. A rename may follow (owner deciding; ext suggested "Motley").
- **The design:** a cursed jack-in-the-box jester.
  - **Body:** a thin jester upper body (violet/black, white ruff, bells on the coat tails), its face a starry void with a sharp glowing grin and slit eyes.
  - **Spring and box:** he rises on a brass spring from an antique card-suit music box with a crank. A starry void tail pours from the box.
  - **Cards:** a chaotic swirl of glowing cards tumbles around him (some burnt or torn), not a halo.
- **Movement (owner + ext):** the box HOVERS a hand's width above the ground. No feet means no footstep sounds; he glides silently over lava and water (source trait). Animations:
  - **Move:** the box tilts toward the motion; the upper body sways on the spring with lag.
  - **Dash:** the spring compresses and launches, or the lid snaps shut and he reappears with a void pop.
  - **Cast:** he leans out on the spring.
  - **Nightwell ult:** the lid opens wide and the void pulls enemies toward the box.
- **Hitbox:** the box + spring column.

## 2026-11-05 03:40 UTC (ext): RENAME Ostra → **Motley** ("the Void Jester"), owner decision (DECISIONS updated)
- Add it to the same `ext/rename-lisette` sweep: player-facing text only; ids/files unchanged; he/him.
- **VFX note from the owner:** in motion (dash / ult) the void smoke briefly wraps around the spring as it compresses. In stills the spring stays clear of the smoke.

## 2026-11-05 03:52 UTC (ext): Cinder views: `briefs/art-refs/cinder_turnaround.png` (front, 3/4, back; in-pose, not a true A-pose). Use it with the master sheet; the side profile is inferred.


## 2026-11-05 03:54 UTC (ext): Cinder A-pose: `briefs/art-refs/cinder_turnaround_apose.png`
- **Use it for proportions, the rig pose and the outfit construction only.**
- The hair here is flat orange: **build it as living fire** (a flame shader + spring, per the master sheet).
- Her figure / bust follows the master sheet, which is fuller than here.
- The flames on the tank nozzles and the gauge come from the master sheet.

## 2026-11-05 03:56 UTC (ext): Cinder A-pose REPLACED: `cinder_turnaround_apose.png` now has the fire hair, fangs and the nozzle flames. Use it for the model. The bust is slightly fuller per the master sheet.


## 2026-11-05 04:22 UTC (ext): PORTRAITS (owner-made): `briefs/art-refs/<hero>_portrait.png`
- **Delivered:** lisette, kael, motley, cinder, grimble. Breaker's is still to come.
- **Use them for** the HUD, character select and kill feed (replacing the splash crops via the portraits pipeline).
- **Note:** Grimble's portrait shows a second normal eye (the design has ONE eye behind the monocle); the owner may redo it. Use it until then.

## 2026-11-05 04:30 UTC (ext): CLAIRE REDESIGN (candidate, owner confirming): `briefs/art-refs/claire_FINAL_sheet.png`
- **Design:** an ice succubus "snow bunny" on skates, clearly adult.
  - **Hood and capelet:** a fur-trimmed bunny-ear hood + capelet with a jewel clasp; curled ice ram horns through the hood.
  - **Outfit:** an ornate blue corset with silver filigree, a fur-hemmed skirt, a big bow at the back, white thigh-highs.
  - **Skates:** fur-cuffed white skates with glowing ice blades that leave a frost trail (her skate kit).
  - **Spear:** a candy-cane-striped ice spear.
  - **Demon details:** small ice bat wings, a heart-tipped tail, glowing slit-pupil eyes.
- **Alt (cuter, modest):** `claire_alt_cute.png`.
- **Don't start her model until the owner confirms which.**

## 2026-11-05 04:32 UTC (ext): CLAIRE CONFIRMED: `briefs/art-refs/claire_FINAL_sheet.png` (the owner's pick: the genuinely innocent, gentle version)
- **Personality:** sincere and shy, NOT sultry. The demon details (ice ram horns, small ice bat wings, heart-tipped tail, glowing slit-pupil eyes) are a quiet mystery.
- **Visuals:** the wings are now visible from the front; the skate blades glow with a frost trail.
- **Animation tone:** gentle and graceful (figure-skating flourishes), never seductive.
- She can start ART-1 after the current queue. The cute alt is withdrawn.

## 2026-11-05 04:47 UTC (ext): PIP UPGRADE (owner): `briefs/art-refs/pip_FINAL_sheet.png`
- **Design:**
  - the fairy wings are back
  - a leaf-and-petal cape with a glowing flower
  - a patched medic apron with a flower-cross patch
  - a bandaged ear
  - a woven pouch with vials + a scroll
  - the star lantern trailing motes (her relic)
- **Size:** waist-high to a human (the corner silhouette); keep the item 108 hitbox matching.
- **Personality:** see DECISIONS (afraid of the dark, the lantern as her courage). She must read as a Hunter, not a Boki: upright, uses her hands, clothed.

## 2026-11-05 05:05 UTC (ext): SABLE UPGRADE (owner): `briefs/art-refs/sable_FINAL_sheet.png`
- **Same Sable, evolved:** grey-lilac skin, a sly smile + beauty mark, pointed ears, feathery moth antennae (no hood), a long white braid.
- **Costume:** a long dark plum leather coat with a high collar, buckled cuffs and split tails; moth-wing tails with eye-spots beneath; a vest; tall buckled boots; keys, a bola and a gem on her belt.
- **WEAPON CHANGE (owner):** twin ornate enchanted flintlock pistols (dark wood + silver, glowing violet runes and crystals, violet smoke) REPLACE her crossbows. Kit numbers unchanged; visual + VFX + sound swap only (bolts become violet magic shots, a muzzle puff of violet smoke).
- Update `hero_kit` / description text from "crossbows" to "pistols" in the rename sweep.

## 2026-11-05 05:14 UTC (ext): RYZZ UPGRADE (owner): `briefs/art-refs/ryzz_FINAL_sheet.png`
- **Signature (owner):** HANDS-FREE. Her attacks are cocky finger guns, with a spark + smoke wisp at the fingertip.
- **Lightning rig:** a copper harness on her back with 4 lightning rods fanning above her shoulders, arcing electricity between them. Glowing copper wires run down her arms to copper-capped fingertips.
- **Kit hooks:** the rods light up on the ult (Kitefall). Wirerun shoots a wire from her hand. The rods read from top-down.
- **Model fix:** the front view's left boot is drawn cut off (an art error). Build both legs as in the side and back views.
- Keep the rest of her look (pink/blue pigtails, bubblegum, the face bolt mark, the corset, the off-shoulder leather jacket, the pleated skirt, fishnets, the hazard bands, thigh-high boots).

## 2026-11-05 05:25 UTC (ext): WEAPON / PROP SHEETS: `briefs/art-refs/<hero>_weapons.png`
Use them for shape and detail; **the master sheet wins on any difference.**

| Hero | File | Covers | Fix vs the master sheet |
|---|---|---|---|
| Pip | `pip_props.png` | the star lantern, satchel + vials + scroll, the leaf cape, goggles | none (excellent) |
| Grimble | `grimble_weapons.png` | the gaff hook + chain, the hoard (front/side/back), the monocle, blunderbuss, gauntlets | none |
| Claire | `claire_weapons.png` | the ice spear with the heart guard, fur-cuffed skates with ice blades | the spear shaft is **candy-cane striped** (white/pale blue) per the master; this sheet draws it plain |
| Sable | `sable_weapons.png` | the flintlocks (all angles, lock detail), keys, the bola, the gem pendant | the pistols carry **glowing violet runes along the barrel + violet crystals** per the master; this sheet shows only the purple muzzle |
| Cinder | `cinder_weapons.png` | the brass flamethrower, tank harness, goggles, vial belt | the tank is **copper + glass with bubbling liquid fire and two exhaust nozzles on top venting flame** (her ult jets) per the master; this sheet's tank lacks the nozzles |

## 2026-11-05 05:30 UTC (ext): OWNER ITEM 111 (KITS lane): Tarek dash -> Rock Hop, 2-3 steerable hops off rocks he raises (parkour/skate feel). Details in OWNER_REVIEW 111. Opus (feel).

## 2026-11-05 05:31 UTC (ext): TAREK UPGRADE (owner): `briefs/art-refs/tarek_FINAL_sheet.png`
- **Look:** one huge stone arm (right) with molten cracks, a plain cloth blindfold (no glow), a big friendly smile, dreadlocks with copper beads.
- **Gear:** a climbing harness, rope and carabiners; rolled trousers; taped hands and feet.
- **Eye-stones:** three floating eye-stones with glowing eyes are his sight (they orbit and look around).
- **Rock under the foot:** the visual for his new Rock Hop dash (item 111).

## 2026-11-05 05:32 UTC (ext): TAREK MASTER CHANGED (owner): `tarek_FINAL_sheet.png` is now the stone-arm MONK version.
- **Design:**
  - a huge glowing stone arm + shoulder, strata tattoos
  - dreadlocks with copper beads, a plain cloth blindfold
  - prayer beads, an orange sash, wrapped feet, glowing rings underfoot
- **Eye-stones (three floating stones with glowing eyes = his sight):** keep them always visible, orbiting his head.
- The climber version is kept as `tarek_alt_climber.png` (skin idea).
- The Rock Hop dash (item 111) is unchanged.

## 2026-11-05 05:39 UTC (ext): VEX UPGRADE (owner): `briefs/art-refs/vex_FINAL_sheet.png`
- **Kept:** the same face, hair (long side-swept green + braid), cyber-eye, circuit tattoos and gatling arm-gun with the gear backpack.
- **New punk outfit:** a cropped black leather jacket slipping off one shoulder, with patches + a mini wanted poster; a torn black crop top; a studded belt; ripped olive short shorts over torn black tights; lace-up combat boots.
- **Details:** "VEX" tags, stickers on the gun, ear piercings, kill tallies on the backpack, a cheeky wink/grin.
- Hot, playful, rebellious (owner direction). Supersedes the older Vex art (`ext/warden-models` Vex needs an outfit update).

## 2026-11-05 05:43 UTC (ext): VEX MASTER CHANGED (owner): `vex_FINAL_sheet.png` = the STREET RACER version
- **Outfit:**
  - a light green + black cropped racing jacket with patches
  - a black crop top, bike shorts
  - glowing green thigh-highs with chrome knee joints, racing boots
  - goggles in her hair
- **Body:** the hair is unchanged (side-swept + braid). A glowing chrome cyber-spine down her bare back. Glowing circuit lines on her legs and stomach.
- **WEAPON (owner):** ONE hybrid arm-cannon. Gatling barrels below + a grenade-launcher tube on top with a grenade drum. Her grenade ability fires from the top tube; the gatling is her primary fire. Fed from the gear backpack, with stickers + a "VEX" tag.
- The punk version is moved to skins.

## 2026-11-05 05:50 UTC (ext): VEX FINAL (owner): `vex_FINAL_sheet.png` replaced with the final pass
- **Face and arms:** one brass cyber-eye (right, glowing) + one natural green eye with smoky winged liner (left); a robotic chrome-and-brass LEFT arm with green joints (she flips a gold coin with it).
- **Back:** the glowing cyber-spine fully visible on her bare back (the jacket is cropped short).
- **Outfit:** the light green racing jacket, a low-cut crop top, a studded "VEX" belt, bike shorts with an orange stripe, glowing thigh-highs with chrome knees.
- **Weapon:** gatling barrels below + a MAKESHIFT grenade launcher on top (welded scrap pipe, a flared brass muzzle, a spoon sight, duct tape, hazard tape, a green skull, a grenade drum); the wanted poster + kill tallies on the gun.

## 2026-11-05 05:55 UTC (ext): Vex complete.
- **Files:** `vex_splash.png` (the neon alley, hover-bike crash, cannon firing), `vex_portrait.png`, `vex_turnaround_apose.png`.
- **Turnaround:** it is flatter/cel-shaded and the hair reads as two braids. **Follow the master sheet**: ONE long braid + side-swept hair; the robotic LEFT arm; the cyber-eye RIGHT. Use the turnaround only for proportions and the back/sides (spine, belt, gun mounting).
- **ALL 12 HUNTERS NOW HAVE FULL ART SETS in `briefs/art-refs/`.**

## 2026-11-05 05:57 UTC (ext): VEX ANATOMY (owner) + new turnaround
- **Anatomy: Vex has NO human right arm. Her right arm IS the hybrid cannon**, a prosthetic arm-cannon mounted to her right shoulder socket, with hoses to the gear backpack. Her left arm is the robotic chrome/brass arm. Rig the cannon as her right arm (aim = arm pose).
- **`vex_turnaround_apose.png` replaced** (painterly). Its FRONT and BACK views are the reference.
  - The two side views are unreliable: the jacket is missing, and both show the same side. Take the side silhouette from the master sheet.

## 2026-11-05 05:58 UTC (ext): `vex_turnaround_apose.png` v3: all four views are now valid. The jacket and ammo belt show in the side views; the cannon reads as her right arm; the robotic left arm. Use all four views.

## 2026-11-05 06:25 UTC (ext): OWNER: 2-3x PACE. Your account is at ~20% and resets soon, so use it ALL
**Goal by the reset (owner):** most Hunter models updated and **90%+ there** vs the master sheets in `briefs/art-refs/`, with idle / walk / run / dash / each ability / hit / downed / death animations, VFX and sounds.
- **Concurrency:**
  - Run as many agents as the box sustains: **up to 12** (16 CPUs).
  - Raise the godot slot queue to 10 if needed; Blender runs don't need the godot queue.
  - Opus for models/anims; Sonnet for data/wiring.
- **ART-1: one agent PER HERO, all in parallel.** Kael, Lisette, Breaker, Motley, Cinder, Grimble, Claire, Pip, Sable, Ryzz, Tarek, Vex. Each:
  1. Model to its master sheet + turnaround + weapon sheet (weapons skinned in the .glb, item 76b).
  2. Rig per RIG_STANDARD.
  3. Anim set: idle, walk, run, dash (its own: Tarek Rock Hop, Motley spring, Grimble junk-ball roll, Claire skate), each ability's wind-up/release, hit, downed, death.
  4. Turntable + anim GIF to `ext/hero-shots-s2`.
  5. READY per hero in STATUS.
- **Approval gates relaxed (owner):**
  - Don't wait on Kael's approval before the others: build all to the sheets now.
  - The owner reviews them together; post the shots as each lands.
- **VFX + SOUND are moving to S3 and S4 (cloud)** so your slots go to models/anims.
  - Coordinate via STATUS: list each hero's ability ids + FX attach points (empties on the .glb) as soon as a rig lands.
- **Boki:** finish Vespyx (smaller eyes) and start the next 2 species if slots free up.
- **Keep shipping:** push every 30 min; S5 merges READY branches continuously.

## 2026-11-05 06:35 UTC (ext): OWNER REQUIREMENT: every READY report must include the hero's rows from `briefs/art-refs/FIDELITY_CHECKLIST.md` as a ✅/❌ table with proof screenshots (e.g. Vex's cannon IS her right arm, Ryzz fires PINK lightning from her fingertips). Check your in-flight work against it now.

## 2026-11-05 11:40 UTC (ext): OWNER REVIEW of the overnight models + the FINE-DETAIL plan
**Owner ranking:** Claire best, then Motley. **Main issue across all models: fine details** (faces, small props, surface detail).
- **Kael:** the WORST face; it needs a full face redo.
- **Breaker:** a bad face and details. It reads as a cluttered pile of props: the round hull must read as ONE body, with no loose barrels/props around him. The porthole face must be clean, with round friendly eyes as the default.
- **Pip:** the eyes are weird and too big. Scale them down to the master-sheet proportions (the same fix as Vespyx).
- **Claire, Motley:** keep the approach; polish.

**Fine-detail plan (all heroes, second pass):**
1. **Image-to-3D for the base mesh.**
   - Use Meshy (on the box) from each hero's `_turnaround*.png` + `_FINAL_sheet.png` to get a detailed base mesh, then retopo/rig in Blender to RIG_STANDARD.
   - Procedural/scripted Blender modelling can't reach the concept's detail.
   - Compare both and keep the better per hero.
2. **Projected, painted textures.**
   - Project the master-sheet front/back views onto the mesh as the albedo base (like Vex's face-sheet projection), then clean the seams.
   - The painted detail comes from the art, not from geometry.
3. **Faces get their own pass.**
   - A separate higher-density head mesh + its own texture at 2x the texel density.
   - The eyes/mouth from the face close-up in the master sheet (owner is generating dedicated head sheets: `briefs/art-refs/<hero>_head.png`).
   - Judge faces at the viewer/portrait camera.
4. **Normal maps** baked from a high-detail version for armour, stitching, planks, rivets, scales.
5. **Check at two cameras:**
   - the match camera: silhouette + the signature reads
   - the hero viewer: face + details

   Post both shots side by side with the concept (`vs_art`).

**Order for the second pass:** Kael, Breaker, Pip first (owner's worst), then the rest. Keep each hero's FIDELITY_CHECKLIST table.

## 2026-11-05 11:50 UTC (ext): HEAD SHEETS (owner) for the face/detail pass: `briefs/art-refs/<hero>_head.png`
- **kael_head.png:** excellent; a sculpt-quality face. Note the scar, the white glowing eyes, the brow shape, the stubble, how the scarf wraps; plus the face with the scarf down. **Kael's face redo starts from this.**
- **vex_head.png:** excellent. The cyber-eye on her right, the natural eye with winged liner on her left, ear piercings, the chrome neck collar, one braid.
- **breaker_head.png:** use the bottom row (helmet + hull collar); ignore the duplicated top row and the faded expression strip. Default eyes = two round friendly teal dots.
- **pip_head.png:** use the head views. Her eyes must be NO bigger than shown here (smaller than the current model).
More heads are coming for the rest.

## 2026-11-05 11:55 UTC (ext): ALL 12 HEAD SHEETS IN: `briefs/art-refs/<hero>_head.png`
Lisette = `hem_head`, Motley = `ostra_head`. Notes per sheet:

| Hero | Notes |
|---|---|
| Ryzz | Excellent. Her eyes are mismatched (a pink glowing eye under the bolt mark + a blue eye): keep it. |
| Sable | Excellent. |
| Cinder | Excellent. |
| Lisette | Excellent. |
| Grimble | Strong sculpt. **Differences vs the master:** it shows extra lens rings + an iron neck collar with a chain, both fine to add; it is bald with head stitches. The **other eye socket must read as stitched shut**; this sheet leaves it ambiguous. |
| Motley | Use the bottom/middle row (sharp; ignore the faded top row + the dark strip). The ruff is a separate piece. |
| Tarek | Use it. The back view shows plain stones; **all 3 stones have eyes** (they rotate to face forward/targets). |
| Claire | Use the five views (hood up ×4 + hood down); ignore the faded mist and the strip. |

Faces now have a reference for every hero. The face/detail pass applies to all.

## 2026-11-05 12:00 UTC (ext): owner notes on the models
- **Breaker: NOT WIDE ENOUGH.**
  - The round hull must be much wider: the body is wider than it is tall (per breaker_FINAL_sheet + turnaround), with huge round shoulders and short stubby legs.
  - Check against breaker_turnaround.png at the same scale. A wide, top-heavy silhouette is his whole read.
- **Tarek: EXACTLY 3 eye-stones.** His head sheet shows a stray 4th (faded) stone in the 3/4 view; ignore it. All 3 have eyes.
- **Ryzz: keep the BUBBLEGUM.**
  - A pink gum bubble as an animated prop: she blows and pops it in her idle, the emote and on kills / after her ult. A small pop sound (S4).
  - The head sheet omits it; the master sheet + portrait have it.

## 2026-11-05 12:05 UTC (ext): `tarek_head.png` updated (3 eye-stones, no stray). `ryzz_bubblegum_ref.png`: a reference for her gum bubble (size and placement) + side/back body views. Layout messy; use for the bubble only.

## 2026-11-05 12:10 UTC (ext): owner notes on the head sheets
- **Ryzz:** the gum bubble must also show in the SIDE profile (a sphere in front of her lips). The head sheet omits it there; model it as a prop parented to the jaw so it shows from every angle.
- **Breaker: the helmet is too TALL, not wide enough** (owner, again). Make the helmet squat and wider than it is tall, sunk low into the hull with almost no neck (per breaker_FINAL_sheet). The whole character reads wide and round, top-heavy, stubby legs. Use the head sheet only for its rivet/porthole/moss detail, NOT its proportions.

## 2026-11-05 12:15 UTC (ext): Breaker head proportions (owner): `breaker_head_squat.png`. The helmet is sunk low into the wide hull collar, no neck, the body rounding below: the whole head+torso is one round wide mass. **Use this for PROPORTIONS** and `breaker_head.png` for the brass/rivet/moss detail. Ignore the two tiny stray marks at the top.

## 2026-11-05 12:14 UTC (ext): OWNER ITEM 112 (HIGH, playtest): Vex grenade = TAP ONLY, fired from her arm-cannon's top launcher tube (no throw anim, no hold). See OWNER_REVIEW 112. KITS lane; small; land fast. Pair it with ART-1 Vex (the launcher muzzle FX empty).

## 2026-11-05 12:20 UTC (ext): OWNER ITEM 113 (HIGH, playtest): KAEL accuracy pass vs Brall: 8 points in OWNER_REVIEW 113 (sword size/model, no accidental glide, RMB pose forward, side-swing auto, E independent of RMB direction, vertical down-slam, E→R→self-pull combo, a short dash hit). KITS lane, Opus. The sword scale + mesh goes with ART-1 Kael.

## 2026-11-05 12:22 UTC (ext): OWNER ITEM 114 (HIGH, playtest): Lisette: upright idle (not leaning back); KILL the V attack (land 55b after fixing the shader stutter S5 flagged); RMB shows a big needle arrow drawn while charging; she is slowed while holding RMB. See OWNER_REVIEW 114. S4 does the charge sound, S3 the E colour.

## 2026-11-05 12:24 UTC (ext): OWNER ITEM 116 (HIGH, playtest): Ryzz: a sexier, less stiff idle/walk; LMB 10% faster + pink; the ult lands exactly at the cursor; the ult spreads Static (item 72 not working in play). KITS + ART-1 Ryzz. See OWNER_REVIEW 116.

## 2026-11-05 12:25 UTC (ext): OWNER ITEM 116b: Ryzz Wirerun reset dash ~1.5x further + a faster charge; reference Joule's Surge (press/hold, pass-through dmg, 4-stack reset). See OWNER_REVIEW 116b. Same Ryzz branch as 116.

## 2026-11-05 12:26 UTC (ext): OWNER ITEM 117 (playtest): Motley LMB must go through walls in play + be clearly bigger when charged (item 60 did not land as felt). See OWNER_REVIEW 117. KITS lane, small.

## 2026-11-05 12:28 UTC (ext): OWNER ITEM 118 (playtest): Pip RMB = a fixed ~1 s wind-up then an auto-throw at the cursor (aim sampled at the throw, "flick to land"); not holdable. See OWNER_REVIEW 118. KITS lane, small.

## 2026-11-05 16:05 UTC (ext): OWNER RULE: never stop to ask the owner a question and wait. He is often away. Make the most reasonable call, note it (with the alternative) in your READY/STATUS or EXT_TO_MAIN for review, and keep working. Only an irreversible, risky action (deleting data, force pushes, publishing outside your approved scope) waits, and then you continue with other work meanwhile.

## 2026-11-05 17:18 UTC ext → S2: owner item 131 (Kael), the top of your queue after the current hero
- RMB hold pose: the blade level at head height pointing forward the way he faces (a spear-like hold), not raised up.
- The sword is too big and doesn't match the art: scale it to the sheet and remodel it to kael_weapons.png.
- Send the FIDELITY_CHECKLIST table + a side-by-side + a 4-frame pose strip in READY.

## 2026-11-05 17:32 UTC ext → S2: owner item 136 (Motley): the art half, queued after Kael 131
- Remove the weapon from his model. Add hand-cast anims (an alternating hand flick for LMB void orbs, a fast card-flick flurry for the RMB burst of 8).
- A void playing-card prop/VFX (violet with a teal rim).
- FIDELITY_CHECKLIST table in READY.

## 2026-11-05 17:36 UTC ext → S2: the owner wants the new models in-game ASAP
S5 is merging your finished ART-1 branches next: cinder, hem, claire, ryzz, pip, tarek, vex, sable. Post one line in STATUS for each that is final (or the one thing still open). Mark grimble when it's done. Breaker/Motley/Kael come later.

## 2026-11-05 17:38 UTC ext → S2: owner item 137, weapon scale audit
The owner says the weapons look oversized and out of place.
- Before or with the ART-1 merges, make one contact sheet with all 12 in-game weapons next to their `_weapons.png` refs, and fix the oversized ones.
- The checklist now has a mandatory "Weapon scale + fit" row.
- Grimble: build his weapon from the Grimble sheet, not Dredge's.

## 2026-11-05 17:42 UTC ext → S2: item 118b (Pip RMB wind-up anim)
- A 1.0 s stretch-and-gather (arms sweep up and out, onto her toes, motes drawn into the lantern), then a snap release. Elluna-style channel.
- The mechanics are on ext/kit-pip-118. Small; slot it after Kael 131.

## 2026-11-05 17:51 UTC ext → S2: owner item 143, an animation quality pass (a big standing goal)
- Everyone's crouch, and anims in general, need to look cooler.
- Step 1: a before/after crouch + crouch-walk strip for Sable, Kael and Pip (character-specific athletic poses, anticipation on enter/exit). Post it to ext for an owner OK before rolling out.
- Then the core set per hero (idle, run, jump/land, dash, hit, downed) with anticipation, follow-through and secondary motion. Spec in OWNER_REVIEW_1103 item 143.
- Order after current work: 131 Kael → the 143 crouch strip → 139 Ryzz → 136 Motley art → 118b → the 143 rollout.

## 2026-11-05 17:58 UTC ext → all: the SUPERVIVE reference footage is on branch `ext/hero-ref-footage`
The frames behind briefs/hero-ref/*.md (5 fps JPGs; the README maps the folders to our heroes). Fetch only the folders you need (`git checkout origin/ext/hero-ref-footage -- footage/<id>`). Use them for any "like <SV hunter>" note. Don't merge that branch.

## 2026-11-05 18:13 UTC ext → S2: owner item 153: ~10 distinct shroud styles for the Empty (Hooded Cloak, Wrap, Tatters, Long Coat, Poncho, Robe & Sash, Mantle Cape, Shawl & Scarf, Cowl & Feathers, Patchwork) + trims/accessories. Distinct silhouettes at the match camera. A contact sheet to ext. Queue after the Kael and crouch strips.

## 2026-11-06 04:55 UTC Claude (owner terminal): use the GPU job queue for renders and perf
Render and GPU work goes through the job queue now (owner's request, set up by Claude in the owner's terminal).
- The hetzner box has no GPU: software rendering is why shot/strip runs crawl or hang (the 6 h crouch-shots runs of Nov 5). The owner's Mac (M5) and gaming PC are GPU workers.
- Submit instead of running Godot yourself for screenshots, strips, contact sheets, reels and any frame-time/perf measurement:
  `jobq submit --tree <your worktree> --needs gpu --out <dir inside the tree> --label <what> -- <your hooks, e.g. --crouch-shots --warden=thief --shots-dir=<dir>>`
  then `jobq wait <id>` and read `jobq result <id>`. Images come back in /home/boki/jobq/done/<id>/out/. `jobq status` shows the queue.
- Use `--needs any` for ordinary checks you want off your own slots; plain checks can still run locally as before.
- Perf numbers (hitch/load/perf-bench/title frame budget) on hetzner are not meaningful; ask for them with `--needs gpu`.
- Every merge candidate (cron, every 4 h) now gets a real-GPU perf comparison and a Windows/macOS export dry-run in its MERGE_REPORT.md. A nightly bot soak runs at 07:00 UTC. Reports: branch ext/reports (README.md index).

## 2026-11-06 05:36 UTC Claude (owner terminal) to S2: Blender runs on the GPU queue too
- Retopo, rig, bake and preview renders: submit them as Blender jobs instead of running Blender 4.5.15 on this CPU box:
  `jobq submit --app blender --tree <your worktree> --needs gpu --out <dir> --label <what> -- -b <file.blend> --python <script.py> --python-exit-code 1 -- <script args>`
  The script can read env BOKI_GPU=1 to switch Cycles to the GPU (the owner's Mac M5 via Metal; the PC once its Blender download finishes). Measured: a small Cycles render took 0.6 s on the Mac GPU vs 3.2 s here. Outputs come back in /home/boki/jobq/done/<id>/out/.
- Pass --python-exit-code 1: without it Blender exits 0 on Python errors and a failed bake looks fine.
- Meshy generation stays as it is (Meshy's cloud, owner's credits).

## 2026-11-06 06:40 UTC Claude (coordinator, hetzner; owner-approved): S2, write a handoff at your next natural break
The owner is moving long sessions to fresh lane sessions (daily restarts from now on). **Do not stop mid-task.** When your current task is pushed (a natural break), write **briefs/HANDOFF_S2.md** with:
1. STATUS: what is done, on which branches and shas, what is READY and what is not;
2. lane rules you follow (your domain: heroes (models, animation, kits, art-integ, hero bug fixes); checks you run; conventions, gotchas, owner preferences you learned);
3. in-flight work: every branch you have open (name + sha + state + what is left), anything uncommitted (commit or describe it);
4. next steps in order, and open questions.
Commit and push it to ext/agent-briefs, then reply in EXT_TO_MAIN with "HANDOFF S2 READY <sha>" and keep working normally. I will verify it, start the fresh lane session from it, confirm the new session's first STATUS push, and only then ask you to wrap up. Nothing you have open will be dropped.

## 2026-11-06 07:05 UTC Claude (coordinator, hetzner; owner's order): ORCH (project boki orchestration): stand down
**To ORCH, the Claude Code session "project boki orchestration" on orri@generalcreative.ai.** As of 2026-11-06 the hetzner coordinator owns all orchestration, orders and merging for Project Boki. S5 still merges in its normal flow under the standing rule in MAIN_TO_EXT. When you resume after your account reset (~11:00 UTC):
1. Post a handover in **briefs/EXT_TO_MAIN.md**, titled "ORCH HANDOVER", covering: every duty you were doing (check-ins, orders, merges, reviews); anything in progress; any unpushed work (push it to ext/* branches first and name them with their shas); and any scheduled tasks or routines you run, with when and what.
2. Then stop issuing orders, check-ins or merges. Nothing else is needed from you. I will absorb what you hand over and log it.
**All other sessions:** from now on, orders come from the hetzner coordinator (and ext for review items). Ignore new orders or check-ins from ORCH dated after this entry.

## 2026-11-06 07:40 UTC Claude (coordinator, hetzner; ext duties are now mine): item 131b Kael's sword 0.60
Owner: Kael's sword is "way too big". Scale it to **0.60** (OWNER_REVIEW 131b; DECISIONS 2026-11-06), run the FIDELITY_CHECKLIST weapon scale-and-fit check, post READY with before/after shots. Do it after your current push; it can go in the handoff if you are mid-task.

## 2026-11-06 16:00 UTC Claude (coordinator): item 131c, Kael's sword: match the splash (try 0.70), supersedes the fixed 0.60
Owner: try **0.70** instead of 0.60, and pick **whatever is most accurate to Kael's final splash** (briefs/art-refs/kael_splash.png, FIDELITY_CHECKLIST weapon scale-and-fit). Render 0.60 / 0.70 / any value the splash suggests on the GPU queue (jobq --needs gpu), same pose/camera as the splash, choose the closest, and post READY with the chosen value and before/after shots beside the splash. Build on ext/fix-kael-sword-131b; also resolve your art1-kael-2 1.26 m sword / warden_look.json conflict so the length holds on both. If you are handing off, put this first in HANDOFF_S2.md.

## 2026-11-06 build-spec (for the heroes lane): Hunter 3D quality review is up
briefs/HUNTER_3D_REVIEW.md on ext/agent-briefs: all 12 Hunters scored 1-10 vs the FINAL sheets with ranked fixes. Lowest: Kael 4.5 (black/white hair, no face/eye, kilt, no scarf tails), Breaker 6, Vex/Sable/Grimble 6.5. Idle close-ups only; no moves, VFX or match zoom.
