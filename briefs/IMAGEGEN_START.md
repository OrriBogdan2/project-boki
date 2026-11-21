# Image-gen agent ("IMG"): start here

You run in the Claude desktop app on the owner's PC, with a built-in browser where the owner has signed in to **anthum.ai** (his own AI studio, which hosts many image models). You drive that studio through the browser to make art for **Project Boki**, a Godot top-down PvPvE extraction game with creature-raising (repo OrriBogdan2/project-boki). Other sessions: ext (coordinator; your reviewer), S2 (server; builds 3D Warden models in Blender), main (merges into `main`). Never push to `main`.

## Rules
- Never type a password or change the owner's account, billing or settings. If you're signed out or hit a paywall or credit prompt, stop and tell the owner.
- **Use only models whose licence allows commercial use** (e.g. FLUX.1-schnell, SDXL, or the studio's own models with commercial rights). If a model's licence is unclear or non-commercial (e.g. FLUX.1-dev), don't use it for anything we keep. Record the model name and settings for every kept image.
- **Originality:** our characters only. No prompts naming existing games, characters, artists or studios ("in the style of ..."). Describe the look in plain words. Reject any output that resembles an existing character.
- Keep generated images out of the game code; they go into `docs/art/gen/` on your branch, with a small `index.md` (file, prompt, model, seed, settings).

## Inputs
- Concept sheets: `docs/art/concepts/<id>.png` and `lineup.png` on branch `ext/concepts` (S2 is polishing them; re-read for newer versions). Each Warden's look, personality, relic and lore: `briefs/OWNER_REVIEW_1103.md` items 18, 37, 39, 41, 43–46, and `briefs/specs/CONCEPT_PASS.md`.
- The owner's bar: high-end MOBA hero art quality. Owner notes on the concepts: Ostra more menacing, Moosh Moosh cuter, Cinder unmistakably salamander-folk and cool, Tamsin a younger pro skater, clearly different heights and builds.

## Deliverables (branch `ext/imagegen`, in this order)
1. **Style frame:** settle one shared art style first (painted, stylised, readable). Make 3–4 style options of one Warden (Bjorn), pick the most consistent recipe (model, prompt template, negative prompt, settings, any reference/img2img use of his concept sheet), write it in `docs/art/gen/STYLE.md`, and STOP for owner/ext approval before doing the rest.
2. **Per Warden (all 12):** one splash (16:9, character in a dynamic pose in their world), one portrait bust (square, for the HUD and picker), and one turnaround reference sheet (front/side/back, neutral pose, flat light) for S2's Blender modelling. Use the concept sheet as the structural guide (img2img / reference) so the design stays the approved one. Generate several, keep the best one or two.
3. **Texture references** for S2: close-ups of materials per Warden (Bjorn's frozen prow wood, Cinder's scales, Ostra's porcelain mask).

## Workflow
- Commit and push to `ext/imagegen` after each Warden. Post progress in `IMG_STATUS.md` at the branch root (what's done, models used, open questions).
- Instructions for you will appear in `briefs/INBOX_IMG.md` on `ext/agent-briefs`; check it before each Warden.
- Work steadily; if the studio rate-limits you, wait and continue.
