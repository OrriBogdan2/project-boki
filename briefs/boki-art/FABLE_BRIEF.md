# Brief: Boki art quality pass ("not AI slop"): style ruleset and re-render prompts

You are writing the new art ruleset for Project Boki, an indie creature-collector action game. About 225 creatures ("Boki") each have a hero card, a four-view turnaround sheet and an encyclopedia portrait, all AI-generated. The owner: "people are very anti AI art, so I wonder what makes it look AI and how to fix that up." Your output decides how all 225 get re-rendered, so it must be concrete enough to paste into prompts and to check by eye.

## Setup (do this first; the repo is about 6 GB, so never do a full checkout)
```
git clone --depth 1 --filter=blob:none --no-checkout --single-branch -b ext/agent-briefs https://github.com/OrriBogdan2/project-boki
cd project-boki
git sparse-checkout init --no-cone
printf '%s\n' '/briefs/boki-art/*.md' '/briefs/boki-art/batch/*.py' '/briefs/boki-art/style_refs/' '/briefs/boki-art/cards/' > .git/info/sparse-checkout
git checkout ext/agent-briefs
```
Sheets, portraits and generated images are NOT checked out: read any of them with `git show origin/ext/agent-briefs:<path> > /tmp/x.jpg` and view /tmp/x.jpg. Never check out `briefs/boki-art/batch/out/` (7,000+ images).

## Read first (all paths are in repo OrriBogdan2/project-boki, branch ext/agent-briefs)
1. `briefs/boki-art/DEAI_RESEARCH.md`: research on what makes OUR art read as AI, the professional principles that fix each tell, and a verdict on the style test. Start here.
2. `briefs/boki-art/STYLE_CANON.md`, `BOKI_DESIGN_RULES.md` (owner taste notes at the end), `GRADES.md`, `PANEL_BRIEF.md`: the current rules. Several current rules cause the AI look ("soft hand-painted shading", "big glossy eyes", "soft blush at every stage"): you may override them, but list every override and why.
3. `briefs/boki-art/batch/build_jobs.py`: how prompts are assembled today (CORE, LESSONS, CARD(), TA(), P()). Your prompt text must slot into this structure.
4. Images (view them):
   - current cards `briefs/boki-art/cards/*.jpg`, sheets in `turnarounds/` and `evolutions/`, portraits in `portraits/light/`;
   - the style anchor `briefs/boki-art/style_refs/boki_style_ref_2d.png` (glossy; the research says it bakes in the tells);
   - the style test: `briefs/boki-art/batch/out/style_<name>_<a|b|c>_<run>.jpg` for Vespyx, Mycroll, Chandelotl, Gongrowl, Glaciammoth and Rimink (a = flat cel-shaded, b = hand-inked, c = chunky simple). These are not checked out on disk: read them with `git show origin/ext/agent-briefs:<path> > /tmp/x.jpg`.
5. `briefs/boki-art/CHANNEL.md` (latest entries) and `OWNER_FEEDBACK.md` (end): the owner's recent calls.

## Owner's style pick
OWNER STYLE PICK (16:32 ET 11-09): style a, flat cel-shaded, as the base for everything. Exception: he says it does NOT work on Gongrowl. My read: flat cel exposes Gongrowl's design problems rather than being the wrong style. It is a semi-realistic gorilla wearing strapped-on armour (chest plate, shoulder straps, cuffs), and the dark fur flattens to one muddy mid-grey with little value contrast. So: (1) give rules for big, dark or furry finals (keep a clear dark/light value split, clumped fur shapes instead of flat fill, a heavier silhouette line); (2) list Gongrowl, and any Boki with the same strapped-armour problem, for a construction redesign (gong grown into the chest, no straps, Boki proportions with a bigger head) BEFORE their style re-render; (3) put Gongrowl on the human-pass list.

## Hard constraints
- Approved designs do not change: same creature, body plan, colours, signature parts. Only the rendering, line, face treatment and construction cleanup change.
- One creature per image, plain flat pale grey #E8E8EE background, no ground, no shadow, no glow halo, no text (the dex cuts heroes out automatically).
- Born-with parts only: nothing strapped, belted, worn or held. One locomotion system. Babies sit or bounce, middle forms move, finals are planted.
- The image model is Gemini 3 Pro Image ("Nano Banana Pro") with image references. Prompts that say "keep the design of image 1, change only the style" work; prompts that re-pose from a card often keep the old pose (a sheet as reference re-poses better).

## Deliver (one file each, in `briefs/boki-art/`)
1. `STYLE_CANON_V2.md`: the one-page recipe. Line (weights as ratios, colour rule, taper), shading (tone count, shadow shape, highlights by material only), palette (swatch cap, accent share), detail budget, face templates by archetype (cute/sleek/tough/creepy/majestic/pretty) with blush rules, construction rules, effects rule, staging per stage and archetype, and the overrides of the old canon.
2. `REVIEW_CHECKLIST_V2.md`: a 2-minute pass/fail checklist a reviewer applies to each image (including thumbnail and 3-value squint tests, limb count, view-to-view consistency for sheets).
3. `RERENDER_PROMPTS.md`: the exact text blocks to replace RENDER/STYLE/CARD wording in build_jobs.py, the per-asset prompts (card, sheet, portrait) for a style re-render that keeps each design, the new LESSONS lines, and a recommendation for a new style anchor (what to render for it and from which Boki).
4. `MARQUEE_HUMAN_PASS.md`: the ~20 Boki that should get a human paint-over (starters, legendaries, store/marketing art), with what the artist should fix on each.
5. Then render nothing yourself; end with a 10-line summary: the biggest changes, what you overrode in the old canon, and the 3 risks to watch.

Rules: commit ONLY your four new files to ext/agent-briefs and nothing else (no edits to existing files, no deletions): `git add` those four paths, commit, then `git pull --rebase` and `git push`; retry the pull+push if it is rejected (other agents push to this branch often). Then stop. Be concrete (numbers, named Boki examples), and keep each file short enough to use.
