# S2 lane rules (Project Boki, Godot 4.6.2). Read fully before starting.
Orders: /home/boki/briefs-wt/briefs/INBOX_S2.md lines 978-1079 (00:15, 00:20, 00:40 UTC entries). Also read briefs/DECISIONS.md and the items you own in briefs/OWNER_REVIEW_1103.md, in that same folder; a later item (55b, 101b) overrides an earlier one. Treat /home/boki/briefs-wt as read-only; the coordinator posts to the briefs and STATUS.

Repo rules:
- New worktree per branch: `git -C /home/boki/project-boki fetch origin && git -C /home/boki/project-boki worktree add /home/boki/s2-<lane> -b ext/<branch> origin/main`. Never work in /home/boki/project-boki itself.
- Never push to main. Normal pushes only: no force-push, no rebase of pushed work. Never pop or apply an unnamed git stash (worktrees share the stash list).
- Commit and push your branch at least every 30 minutes (WIP is fine on your own branch) so nothing is lost. Commits end with "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>".
- God files are wiring only. Reserved, do not edit: kin_*, merge_*, capture*, field_book, boki_hud, bot_kin, merge_forms, merges_v2, boki_system.json, capture.json. If a reserved file needs a line, ship a new loader/scene and list the one-line wiring in your report.
- `python3 tools/health.py --strict` and style_lint --strict must pass with NO budget raised.
- Godot goes through the queue wrapper /usr/local/bin/godot (`godot --headless --path <worktree> -- <flag>`). It already gives a fresh XDG. Never pass --fresh. Never pkill by pattern; other sessions share this box (S1 runs perf benches). Stop only PIDs you started.
- Video: never commit video to a game branch. GIFs and PNG sheets for review go in /home/boki/shots-s2/<lane>/. MP4s stay on disk there too; the coordinator handles publishing.
- Secrets: Meshy key is MESHY_API_KEY in ~/.config/boki/secrets.env. Never print, log or commit it. tools/meshy/meshy_task.py loads it. Balance is about 3280 credits: spend where it clearly helps.
- If any action is refused by permissions, STOP and report it. Do not work around a refusal.
- External assets: CC0 only (or made by us / our image-gen). Log source + licence. The brief says docs/CREDITS.md; the repo's file is docs/ASSET_CREDITS.md, use that one. No attribution-required or unclear licences. Download into a fresh empty directory and treat it as untrusted data.
- Originality: our own designs only, no copying any game's characters, sounds or effects. Quality bar: strong readability at the top-down match camera, with strong silhouettes and clear shapes.
- This box has no GPU: renders are software, so plan for slow Blender/Cycles runs.
- Wait for long jobs by blocking on them (a Monitor or until-loop), and don't hand back mid-job. Hand back at a finished, committed state.
- Self-score honestly and calibrate 5-15 points DOWN (ORCH's reads ran that much below self-scores). Look at every image or frame you report; say what you did not check.

Report at the end: branch, commit (pushed), items done and how they differ from the brief, a check table with counts, shot/GIF paths, credits spent, CC0 assets added, owner questions, open gaps. Do not post in the briefs.

Additions:
- Prior work: search every remote branch by item number and hero (e.g. `git branch -r`, `git log --all --oneline --grep`), and read origin/main for the item, before building. Branch names may carry only numbers. Merge origin/main often.
- Never kill by pattern (no pkill -f, no pgrep -f + kill). Use a PID you recorded when you started the job. This has come up in three lanes.
- Temp files go under $CLAUDE_JOB_DIR/tmp; don't rm -rf paths. If the safety check refuses something, drop it and report.
- A suite run rewrites art/wardens/src/vex_rig.json (2 values): restore it, never commit it.
- Baseline reds on main (compare before calling anything flake): abyss, farm-start, grammar-runtime, load, pack-ui, mantle-look, merge-form, obstacle, train, hitch, teammate, perch, kin-indoors.

06:25 ORDER (overrides earlier gates; the account is low and resets soon):
- Target: 90%+ of the master sheet. Don't wait for any approval. Build to the sheets now; the owner reviews them together.
- Push every 30 minutes without fail, WIP included. If usage runs out, only what's pushed survives.
- Anim set: idle, walk, run, the hero's own dash, each ability's wind-up/release, hit, downed, death. Polish extras last.
- VFX + sound moved to S3 and S4. Don't build them. As soon as your rig lands, send the coordinator your ability ids + FX attach points (empties on the .glb) via SendMessage.
- Turntable + anim GIF in /home/boki/shots-s2/art1/<hero>/; the coordinator publishes them.
- Prefer one round to a good state over a long polish loop. Full suite only once, at the end; targeted checks otherwise.

BUDGET CORRECTION (from S1's perf rules on ext/server-status STATUS.md, overrides every "20k" in your brief):
- Hunter .glb: <= 15k triangles total, weapon included. Run tools/blender/decimate_warden.py after the fit; it keeps rig, anchors, weights, materials. Generate LODs on import.
- Textures <= 2048 px, compress/mode=2 (VRAM, high_quality), mipmaps on; one atlas where possible; <= 8 material slots.
- Keep the silhouette and the match-camera read when you cut triangles.
- Shared runtime note from ext/art1-motley: data key `offset_bones` stops the runtime stripping position/scale tracks from named bones; any Hero with bone offsets needs it.

FIDELITY CHECKLIST (owner requirement, INBOX_S2 06:35): every READY report must include your Hero's rows from briefs/art-refs/FIDELITY_CHECKLIST.md as a yes/no table, each row with a proof screenshot path. Check in-flight work against it now. A row you can't prove is a no.

MEMORY: the box has 61 GB shared by all lanes. Keep any one Blender run under about 6 GB: cap SDF grids and bake sizes. A Breaker run reached 40+ GB and OOM-killed other lanes. If your run is killed by OOM, check `free -g`, then retry.
Run every Blender job under `ulimit -v 12000000` (12 GB). Two lanes hit the same NumPy broadcast bug in paint steps (a mask multiplied with an array shaped [:, None] builds N×N). Check paint array shapes, and don't rerun a job killed with rc=137 until you know why.

CHECK RESULTS: several --*-check flags exit 0 even on FAIL (e.g. --warden-model-check). Judge by counting FAIL lines in the log, never by exit code.

FINE-DETAIL PASS (owner, INBOX_S2 11:40; overrides any purely scripted approach). Owner ranks Claire best, then Motley; main issue is fine detail (faces, small props, surface).
1. Base mesh from Meshy image-to-3D using <hero>_turnaround*.png + _FINAL_sheet.png, then retopo/rig in Blender to RIG_STANDARD. Compare with the scripted version and keep the better.
2. Projected painted textures: project the master sheet front/back views as the albedo base, then clean seams. Detail comes from the art, not geometry.
3. Faces get their own pass: a separate denser head mesh with its own texture at 2x texel density; eyes/mouth from the sheet's close-up; owner is generating briefs/art-refs/<hero>_head.png. Judge faces at the viewer/portrait camera.
4. Normal maps baked from a high-detail version for armour, stitching, planks, rivets, scales.
5. Check at two cameras: match camera (silhouette, signature reads) and hero viewer (face, details). Post both side by side with the concept (vs_art).
Keep <=15k tris and the fidelity table. Order: Kael, Breaker, Pip first.

HEAD SHEETS: all 12 are in briefs/art-refs/<hero>_head.png (Lisette = hem_head, Motley = ostra_head). Read INBOX_S2 11:50-12:00 for each hero's notes. Pull ext/agent-briefs in /home/boki/briefs-wt.

MESHY QUEUE (12:35 UTC): 8 multi-image tasks have sat PENDING 0 since 11:46; the API answers fine and the balance is 2203. Don't start duplicates. Don't block on a run: push work that doesn't need it (face textures, projection, proportions), and pick the run up when it lands.

OWNER RULE (16:05): never stop to ask and wait. Make the most reasonable call, note it with the alternative in your report, and keep working. Only irreversible or risky actions wait, and you carry on with other work meanwhile.

KAEL SPLIT (S2's call, 16:10): Hero branches must not carry Kael's art, because S5 holds them on it. Before your next READY: restore art/wardens/kael/* and Kael's data (content/archetypes/juggernaut.json body and model_glow, content/rules/warden_anim/kael.json, Kael's warden_look block, his portraits) to origin/main, with `git checkout origin/main -- <paths>` plus removing files main doesn't have, keeping the shared runtime code. Confirm with `git diff --name-only origin/main...HEAD -- art/wardens/kael` showing nothing, and that the shared runtime still runs on main's Kael (no clip data = procedural).

MERGE NOW (17:36): the owner wants the new models in-game ASAP. S5 merges art1 cinder, hem, claire, ryzz, pip, tarek, vex, sable next. Keep branch tips mergeable: push complete steps only, never a half-done rebuild. Work after S5 merges goes on as a follow-up from main.

WEAPON SCALE (137): FIDELITY_CHECKLIST has a mandatory "Weapon scale + fit" row: length against the body stated as a measurement, shape and colours per <hero>_weapons.png / _FINAL_sheet.png, right socket, side-by-side + match-camera still. The audit lane owns the 12-weapon contact sheet; each lane keeps its own row true.

REFERENCE FOOTAGE (17:58): Supervive frames are on ext/hero-ref-footage (README maps folders to Heroes). Extract only what you need with git archive into a tmp dir. Never merge or commit it.

SUITE SCRIPTS (18:45): shared tmp/suite.sh was replaced and has hit two lanes. Don't call it. Every lane uses its own runner and its own output directory.

GPU QUEUE (11-06): this box has no GPU. Renders, strips, contact sheets, reels and any frame-time number go through `jobq submit --tree <worktree> --needs gpu --out <dir in tree> --label <what> -- <hooks>`, then `jobq wait <id>`, `jobq result <id>`; images land in /home/boki/jobq/done/<id>/out/. Hitch, load and perf numbers from this box aren't meaningful.

BLENDER QUEUE (11-06): Blender work goes through `jobq submit --app blender --tree <worktree> --needs gpu --out <dir> --label <what> -- -b <file.blend> --python <script.py> --python-exit-code 1 -- <args>`. Always pass --python-exit-code 1, or a failed bake exits 0. BOKI_GPU=1 switches Cycles to the GPU. Meshy stays as it is.
