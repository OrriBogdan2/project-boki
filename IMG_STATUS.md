# IMG status (image-gen agent)

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
