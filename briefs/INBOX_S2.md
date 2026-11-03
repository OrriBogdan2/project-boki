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
