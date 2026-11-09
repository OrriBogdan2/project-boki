# Boki grades (owner rule, Nov 8 17:26)
Every sheet gets an objective grade. Below 8.5 = redo with a different prompt. Graded as each batch comes in.

Rubric, 2 points each: (1) idea fused through the whole body, (2) silhouette that reads as a shadow and is unique in the roster, (3) face with its own personality, (4) appeal plus edge (cute/cool and some bite), (5) sheet quality (four clean views in one row, on-model, no upright posture, buildable).

| Boki | Grade | Main issue | Status |
|---|---|---|---|
| Wyrmink | 9.0 | | keep |
| Umbrink | 9.0 | | keep |
| Effigeetle | 8.5 | small in frame | keep |
| Lockatara | 8.5 | | keep |
| Mycroll | 8.5 | website design | keep |
| Soakybara | 8.5 | | keep |
| Umbrathere | 8.5 | realistic sloth face | keep |
| Teapotamus | 8.5 | | keep |
| Kerchick | 8.5 | | keep |
| Sporcupine | 8.5 | | keep |
| Jarmit | 8.5 | | keep |
| Flarmink | 8.5 | | keep |
| Rippmink | 8.5 | | keep |
| Voltmink | 8.5 | | keep |
| Rimink | 8.5 | | keep |
| Kitlet | 8.5 | | keep |
| Ermink | 8.0 | upright in 3 views | exception proposed: nine forms built on it |
| Bubblisk | 8.0 | no bite | redo |
| Canvastross | 8.0 | stiff vertical wings, strapped saddle | redo |
| Chuggamus | 7.5 | redo still has the band, plus wheels | redo 2: riveted plate hide, piston legs, no band |
| Lunowl | 8.0 | pretty but no edge | redo |
| Mirrolin | 9.0 | redo A: mirror-tile armour, disco-ball mace tail, smug grin; re-laid from 2x2 | keep |
| Murmurling | 8.0 | realistic bird plus pipes | redo |
| Blossmink | 8.0 | upright, mostly a recolour | redo |
| Lunink | 8.5 | owner regrade; brush tail and moon marks link it to the line | keep |
| Prismink | 8.0 | upright, mostly a recolour | redo |
| Oarlet | 8.0 | generic otter plus paddle | redo |
| Amanitusk | 8.0 | realistic boar | redo |
| Lashyx | 8.5 | redo A: smoky legs, triple-blade sting, armoured; reads as final next to a smaller Vespox | keep |
| Bellowary | 7.5 | realistic turkey head, strapped saddle | redo (batch 1) |
| Prismander | 9.0 | redo D: faceted crystal body, prism gills, glass tail blade; re-laid from 5 views | keep |
| Zippelith | 8.5 | owner regrade: the simple glossy blob is its charm | keep (Zipling must look clearly different) |
| Puffamus | 7.5 | belt-like band; wait for new Chuggamus | redo |
| Glaivyx | 9.0 | the locked Vespox redo, promoted to the Fierce final (owner) | keep |
| Barokat | 8.5 | redo A: worried face, funnel ears, vane tail | keep |
| Gongibbon | 8.5 | chest-gong redo A, cropped to its clean row: calm monk, gong chest, mallet tail | keep (base) |
| Gongrowl | 8.5 | crest redo A: skull-crest gong, roaring, bronze knuckles. FLAG (owner): stylise further as a final form in the general review | keep, flagged |
| Skateron | 8.5 | redo B: skater pose, ice blades, smug face | keep |
| Vespox | - | new middle form needed, smaller than both finals | new prompt out |
| Kestrike | 8.5 | redo B: round, copper-spike crest, copper rod tail | keep |

Female sheets for Bellowary and Gongibbon are on hold until their redos are locked.


## Batch mode (owner, Nov 8 19:40)
Hyper-critical grading, but the bar is 8.5 (owner, 19:56: wants a steady stream to review, ideally 2 good images a minute). Owner wants a very low reject rate at review, so reroll freely (up to 4 tries per Boki, then flag). Do not stop between batches; owner checks in periodically. Boards go out every 10 approved.
Auto-fail at batch stage: anything upright or person-like, any strap/belt/band/vest/hat look, a copy of its parent (babies, middles), a final form not clearly bigger than its middle, realistic animal plus prop, missing signature part, blush on non-babies.


## Decimal grades and near-misses (owner, 2026-11-08 21:25 ET)
- Every image gets a decimal grade, rejects included (e.g. 7.4, 8.2). The bar stays 8.5.
- Rubric (one overall grade, judged, not averaged): idea fused through the whole body; silhouette readable at thumbnail size; appeal and face; style match; form logic (stage size, no copying the parent); clean sheet.
- Owner calibration anchors: Sporcupine 7.9, Teapotamus 7.1, Voltmink 7.0.
- 8.0-8.4 with one or two fixable details -> an edit job on that image (cheaper, keeps what works). Below 8.0 -> a new prompt.
- ART lines for rejects: `ART <id> reject <path> grade=<x.x>` (the grade is an extra 5th field; passes keep `ART <id> <grade> <path>`).

## Uniqueness (owner, 2026-11-08 21:24 ET)
- No Boki may feel like a copy of another unless it is its own evolution; evolutions must still be distinct enough to be interesting.
- Every pass is checked against a contact sheet of the whole approved roster. Same base animal + same main idea (or same animal + silhouette + palette) as a Boki from another line = reject, naming the look-alike.

## Evolutions must be fundamental changes (owner, 2026-11-08 21:48 ET)
- A middle or final form that is the parent with things added, more of the same parts, a recolour, or the same body plan and pose is rejected (7.5 or lower), however polished.
- Test: ignore colours and add-ons; if silhouette, proportions and body plan still match the parent, reject. A pass needs a new body plan or posture and its idea grown into something new. Babies must not be the parent shrunk down.
- Evolution prompts (build_jobs REL) now demand this for every unstarted job.

## Two-stage review with a three-critic panel (owner, 2026-11-08 21:50 ET)
1. Screener (one grader, cheap): rejects the obvious fails (copies, upright, strapped props, ghost rows, look-alikes). Anything it scores 8.3+ moves on.
2. Panel (three independent critics, see PANEL_BRIEF.md): A art director (craft, appeal, silhouette), B creature designer and roster keeper (idea through the body, fundamental evolutions, uniqueness), C player and production (would kids want it, memorable, buildable in 3D).
3. Pass = no veto, every seat >= 8.0, average >= 8.5, two seats agree on the run. Panel splits go to the owner flagged, with each seat's note. Each seat is calibrated against owner verdicts over time.
- Update (owner 21:52): the panel reviews EVERY image, not only screener survivors, and gives each a combined score (the three seats' average, with any veto noted). The owner reviews from those combined scores.

## Framing and pose (owner, 2026-11-08 22:00 ET, with Pokedex screenshots as reference)
- Portraits: centred, filling ~85% of the square, interesting characteristic pose with attitude (never a stiff side-on stand), plain light background, no effects. Every saved portrait goes through batch/recrop.py (centres the creature and scales it to fill 88%).
- Sheets with small views are re-laid out before saving.
- "Fine but forgettable" scores in the 7s: designs must be genuinely cool and unique.

## Concept-first pipeline (owner OK, 2026-11-08 22:14 ET)
- New species (ROSTER_200_NEW.md) start as one square concept image each (`c_<name>`), judged by the panel on design alone.
- Approved concepts get a turnaround sheet made from the concept (`ta_<name>`), judged only on matching the concept and a clean single row.
- Families go top-down: a later stage is only generated once the earlier stage's concept passes, using it as image 2.
- Concept prompts are short (core + lessons + the roster entry) instead of the stacked sheet rules.

## Screener + more versions (owner OK 23:16 ET, "without me being a blocker")
- A reject-only screener (SCREEN_BRIEF.md) checks every new image first for objective hard-rule breaks (pasted creatures, ghost rows, two heads, broken layout, upright pose, held or worn items, reskinned evolutions, text, crops). It can never pass anything.
- Survivors go to the 3-critic panel, which alone decides passes (rule unchanged: no veto, every seat >= 8.0, average >= 8.5, two seats agree).
- New jobs make 4 versions (edits 3-4, portraits 3) so each review round sees more options.
- The pipeline runs without waiting for the owner; owner verdicts in the Bokidex still override and recalibrate the panel.

## Two art sets per Boki (owner 23:24 ET)
- Canon hero card (STYLE_CANON) is the main image; the Pokedex-style portraits (light, dark, cut-out) are kept as additional art and keep improving. Neither replaces the other's files.

## Owner-review tier and queue order (owner 23:37 ET 11-08)
- Pass (auto-approve): unchanged (no veto, every seat >= 8.0, average >= 8.5, two seats agree).
- Owner review: no veto and three-seat average >= 8.3 -> posted to the Bokidex with status=owner-review; the owner decides. A fix round still runs in the background.
- Queue order: new-species concepts and turnarounds first, then evolution and other sheets, then portrait touch-ups (specs_zzz_order.py).

## Line stance variety (owner 00:28 ET 11-09)
Every stage of a line must stand differently (baby = round sit/bounce, middle = in motion, final = big planted stance; branch
finals differ from each other). Same stance as another stage = capped at 7.9. Prompts now carry the ladder (REL in build_jobs.py),
turnarounds keep the concept's stance instead of a neutral stand, and existing lines are audited and re-posed stage by stage.

## Owner standing permissions (01:03 ET 11-09)
- Disk: clear anything already stored elsewhere (pushed to GitHub / re-downloadable) without asking.
- Choices between options (e.g. design directions): Claude picks, shows the options in chat, and the owner overrides if he disagrees.
