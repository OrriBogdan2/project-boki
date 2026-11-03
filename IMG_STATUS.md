# IMG status (image-gen agent)

## 2026-11-03 (new session): deliverable 2 starting
- Owner decisions: Q2 yes, download the 2K originals of kept images into the repo; Q3 OK, Anthum's display/training licence is accepted.
- Bjorn's look approved: `docs/art/gen/style/bjorn_optA_epic_bigshield.png` (sleeveless, very muscular, enormous prow-shield).
- Approved twists for the human-based Wardens: Sable moth-folk (silver wing-like cloak scales, large dark eyes); Pin half-wraith (smoky lower body, no shadow, keeps her red); Zedran half-giant (curled ram horns, bronze skin); Vireo storm-touched (glowing lightning-scar tattoos, static-floating hair); Venator part-machine marine (mechanical arm and eye); Tamsin frost-sprite (crystalline ice skin patches, frost-feather hair); Tarek part stone (basalt-cracked skin with glowing seams, keeps the eye bandana). Cinder, Dredge, Moosh Moosh, Ostra and Bjorn already follow items 39/41.
- Owner notes on the proposals: Dredge must look noticeably broken and oozing (torn plates, black ooze dripping, red rot-light). Vireo: whichever twist is cooler; IMG pick: her storm tattoo sleeve becomes glowing branching lightning scars (one read, not two). Venator: religious in behaviour and going insane, a battle between conservative morals and slipping sanity (prayer beads, scripture strips, a devout soldier's bearing with a cracked, too-wide stare). Gender to confirm: the item 39 table has Venator as F, the owner wrote "him". Rest of the proposals approved as written (Sable as the thief who reached the Wyrmheart, Pin's legs fading to smoke below the knee, Zedran's horns on his head).
- Generation switches to the owner's Chrome (Claude in Chrome). Owner asked to talk through each Warden's look and lore before generating; per-Warden proposals are with the owner now.

## 2026-11-03 19:05 UTC: deliverable 2 at 11 of 12 Wardens
- Done (2K originals in `docs/art/gen/wardens/<name>_{splash,portrait,turnaround}.png`, prompts in index.md): Bjorn, Zedran, Dredge, Ostra, Pin, Sable, Tarek, Claire (was Tamsin), Vireo, Cinder, Moosh Moosh.
- Waiting: **Venator**. The item 39 table has her as F, the owner wrote "him". Owner's direction for the look: devout, religious and going insane, a fight between conservative morals and slipping sanity; part-machine marine (mechanical arm and eye).
- Open owner picks: Sable's moth wings as real wings (splash) or wing-scale coat-tails (turnaround); whether Cinder should go sleeker and more dangerous.
- Known turnaround nits for S2 (noted per Warden in index.md): Zedran's back view drops the cleaver, Cinder's lance has a forked tip, Moosh Moosh's back-view tail is small.
- Credits: the studio balance went from 1,228 to 1,122 this session (about 106; 2 per 2K image).
- Then deliverable 3 (texture references).
- **Push still blocked**: the repo isn't attached to this session's sources; all commits are local on `ext/imagegen`.

## 2026-11-03 18:45 UTC: progress; Tamsin renamed Claire
- Done (2K, committed): Zedran, Dredge, Ostra, Pin, Tarek, Tamsin/Claire (take 1), Vireo. Generating: Cinder, Moosh Moosh, Sable splash retry, Claire face rework, Vireo turnaround retry. Then Bjorn's set; Venator waits on the owner (gender).
- **Owner: Tamsin is renamed Claire** (base name for the rimewright / Icy Dancer class; other agents to be told by the owner). Files renamed to `wardens/claire_*`.
- Owner on Claire's face: cuter and sweeter, like an animated feature film. Prompted in plain words (soft rounded face, big expressive eyes, small nose); no film or character named, and her own ponytail and skating dress stay (no side braid, cape or gown) for the originality guard.
- Owner allowed Chrome's "download multiple files" prompt for anthum.ai so the 2K originals land in Downloads.

## 2026-11-03 18:20 UTC: Dredge done
- `docs/art/gen/wardens/dredge_{splash,portrait,turnaround}.png`. Broken, torn hull, black ooze with crimson rot-light. Next: Ostra, Pin, Sable (queued), then Tarek, Tamsin, Vireo, Cinder, Moosh Moosh, Venator (waiting on the gender question), Bjorn's set.

## 2026-11-03 18:10 UTC: Zedran redone leaner (owner: "leaner, jacked more than wide")
- All three Zedran files replaced with the lean takes. Credits so far this session: about 30.

## 2026-11-03 17:55 UTC: Zedran done (splash, portrait, turnaround)
- `docs/art/gen/wardens/zedran_{splash,portrait,turnaround}.png`, 2K originals. Prompts in index.md.
- Owner notes applied: very dark skin, many scars, high-ego showman, ram horns (half-giant), demon in the cleaver with lava possession up the sword arm. Style anchor added (Bjorn frame as 3rd reference) so all Wardens match.
- Credits: about 14 this session (2 per image; 7 images incl. discarded takes).
- Push: blocked; the repo isn't attached to this session's sources, so commits are local until the owner attaches it.

## 2026-11-03 17:25 UTC: owner direction, fewer regular humans
- Wardens should feel interesting, not ordinary people: each human-based Warden gets a visible non-human or otherworldly twist, proposed to the owner before generating (rule in STYLE.md). Per-Warden work moves to a fresher session from here.

## 2026-11-03 17:30 UTC: Bjorn look locked pending a final OK
- Owner: keep sleeveless, make the shield much bigger. Done: `docs/art/gen/style/bjorn_optA_epic_bigshield.png` (prow-shield as tall as him and twice his torso width). STYLE.md gained two rules: give scale as hard relations; never reuse a generated image as a reference to change it.
- Credits used so far: about 20.

## 2026-11-03 17:20 UTC: option A approved; epic body revision done
- Owner approved option A (hand-painted 3D) and asked for Bjorn taller, muscular and epic. Two revised takes in `docs/art/gen/style/` (`bjorn_epic_revision.jpg` compares them). Take 2 is the tallest with a clear oar, but the coat went sleeveless; take 1 keeps the coat. Owner to pick.
- STYLE.md now has the body-direction rule (explicit "taller/muscular than the reference" + head count) and the "name each prop's shape" rule.
- Still open: full-res downloads (Q2) and Anthum's display/training licence (Q3).
- Credits used so far: about 14.
- The owner may move the per-Warden pass to another session; it should start from STYLE.md on this branch.

## 2026-11-03 17:15 UTC: deliverable 1 (style frame) ready; STOPPED for approval
- Done: 4 style options of Bjorn, plus a second take of the best one to check consistency. Recipe written in `docs/art/gen/STYLE.md`; files and prompts in `docs/art/gen/index.md`.
- Recommended: **option A (hand-painted 3D)** on **Nano Banana 2.1** (anthum.ai Studio), 2K, using the concept sheet's body and portrait panels as references.
- Models used: Nano Banana 2.1 only. Licence: Google claims no ownership of outputs and sets no commercial restriction. Backup: FLUX 2 (BFL grants full commercial rights on API images).
- Credits used: about 10 (2 per 2K image).
- `docs/art/gen/.gdignore` keeps these images out of Godot's import.

## Open questions (owner / ext)
1. Approve option A, or pick B/C/D.
2. Allow downloading the full 2K originals of kept images from the studio (previews in the repo are viewer captures).
3. Anthum's terms let it display uploads/outputs as platform examples and train its internal systems on activity. OK for unreleased art and concept sheets?

## Next (after approval)
Per Warden, in brief order: splash (16:9), portrait bust (1:1), turnaround sheet (front/side/back, flat light); then texture close-ups. Check `briefs/INBOX_IMG.md` before each Warden.
