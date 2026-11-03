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
