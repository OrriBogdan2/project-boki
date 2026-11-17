# HANDOFF S2 (written 2026-11-06, main 7907d9af)

S2 is the heroes lane: models, animation, kits, art integration, hero bug fixes. S5 merges and releases (paused on low spend; the owner's terminal shipped v0.24.0 while it's paused). S1 perf, S3 VFX, S4 sound, S6 Boki, S7 tutorial/farm/UI, ext routes the owner's items. Orders: briefs/INBOX_S2.md and MAIN_TO_EXT.md on ext/agent-briefs. Reports: STATUS.md on ext/server-status2, EXT_TO_MAIN.md on ext/agent-briefs. Review shots: ext/hero-shots-s2.

## 1. Status
**In main (v0.24.0, live on itch.io and GitHub):** 11 ART-1 Heroes via ext/art1-integ-3 2e10e501 (Lisette, Sable, Pip, Vex, Cinder, Ryzz, Tarek, Claire, Grimble, Breaker, Motley), crouch for all 11, Pip 118b, Ryzz 139, weapon scale, bot aim fix, ext/fix-dash-181 2ed53bc4, ext/art-shrouds-153 d8540dff, gloves 69, glider 63, Cinder 66 and ult-E, Claire 62-65, Lisette 114, Motley 60/75, Pip 118, Ryzz 116, Tarek 111, Vex 112, portraits-three, boki-starter, fix-breaker-spin.

**READY, not merged:**
| Branch | Sha | State |
|---|---|---|
| ext/kit-kael-113b | 03668028 | Item 113 on main's model. juggernaut-combo 183/0, hero-combo 297/0, kit-combo 39/0, move-feel 0, health/style OK. Replaces ext/kit-kael-113. No full suite. Lunge and Wave poses on his old sword not viewed: look first. Clean with main 7907d9af |
| ext/art1-kael-2 | fd33d204 | Kael's new art as one merge, held: the owner hasn't approved Kael. 37 targeted checks pass except mantle-look. Replaces ext/art1-integ-4 (9a6ac1f3, which had the full suite). Clean with main 7907d9af. If 113b lands first: one header conflict in tools/combo51_shots.gd; keep rmb.lunge.hit_r 0.51 |

**Older, unmerged, S2's:** ext/drop-107 0a31cdbd (4 conflicts, needs a Net.VERSION bump), ext/trial-ryzz-116 a6143699 (superseded). ext/friendly-bodies ac64730e isn't S2's call: it was held on the dolm leap row.

**Fidelity vs the owner's 90% target: not met, no Hero proven at 90.** Lane scores, calibrated down: Ryzz 80-85, Cinder 75-80 (match 80, viewer 75), Breaker 76, Motley 75, Grimble about 80 (coordinator a little lower), Vex 85 by lane, 70-75 by the coordinator's view, Kael 65. Tarek, Claire, Pip, Sable, Lisette have no number from this round. Tracked gaps per Hero are in STATUS; the worst: Kael lower-torso mottling at the match camera, Tarek's hair reads as a black hole from above, Grimble's ball head is a pale lump, Vex's patchy skin, Motley's lilac cards.

## 2. Lane rules
briefs/S2_LANE_RULES.md is the full rule file given to every agent. Read it before anything. Things that bit us:
- Check by FAIL text, never exit code. Several checks exit 0 on FAIL. A fresh worktree needs --import first or it gives false passes.
- Merging clip models silently drops things. warden_glb.gd duplicates _look_pose/_play/apply_blade with no conflict marker, a parse error that breaks every Hero and looks like a procedural fallback. A merge can restore main's old Kael rig, textures and model row with no conflict. --clip-check's own-model rows catch a fallback.
- Art branches are clean against main but conflict with each other. Trial-merge them in sequence; a single integration branch is what worked.
- A Hero wearing clips stands upright through a crouch unless warden_anim has a `crouch` key. --crouch-check now fails that. Use tools/art1/crouchkit.py (quick()) plus tools/art1/glb_add_clips.py.
- warden_look weapon_scale does nothing on skinned weapons; use bone_scale in warden_anim/<art>.json. One normal-map path only: use_nrm + normal_tex + normal_k.
- tools/art1/kael_*.py stay: other Heroes' paint imports them.
- --mantle-look can't see skinned bodies (Tarek reads 0.75): a check artifact, not a regression. Fix the check; don't move the assert.
- Keep --weapon-audit out of suites: it's a tool, needs a renderer, and writes to the repo root. Its sheet ratios are read by eye; Kael's row misled us: measure against the master figure in <hero>_FINAL_sheet.png.
- A suite run rewrites art/wardens/src/vex_rig.json and sometimes warden_look.json: restore, don't commit. Own runner and output directory per lane; never shared tmp/suite.sh.
- No GPU here: use jobq for renders, frame times and Blender. Hitch/load numbers from this box aren't meaningful.
- Permissions: stopping another process by PID can be refused. Don't work around a refusal; report it to the owner.
- Secrets: MESHY_API_KEY in ~/.config/boki/secrets.env; never print or commit. Meshy balance about 1930, shared.

Owner preferences: never stop and wait on him (make the call, note the alternative, keep going; only irreversible actions wait). READY reports carry the fidelity table with proof shots. Calibrate scores down and look at every image reported. He judges at the match camera. Supervive is the quality bar (frames on ext/hero-ref-footage; never merge it). Daily lane restarts.

## 3. In flight
- No S2 agents running. Nothing uncommitted that matters.
- Bug 181 on a real GPU (Mac M5, Compatibility, job 20261106-065923-30932): first uses 28-29 ms, 0 compiles; a 45 ms frame on Sable's second dash did not repeat on the rerun (job 20261106-070202-08522, worst 29 ms). That rerun's last four Kael rows had 0 frames: his later moves never started, which looks like the harness; not diagnosed. Before any jobq run, `--import` the worktree after moving it, or the job fails on a stale class cache (that is why two earlier jobs timed out at rc 124). No GPU hitch number from S2 yet; see ext/reports.
- Open branches with work: only the two READY ones above.
- Worktrees: /home/boki/s2-* (use /home/boki/s2-art1-integ for ext/art1-kael-2, /home/boki/s2-kit-kael-113b for 113b, /home/boki/s2-art1-kael2 is ext/art1-kael's work, branch name ext/art1-kael-r4 locally; ignore /home/boki/s2-art1-kael, stale). /home/boki/s2-fix-181 is detached on main for the GPU jobs. Clean up freely once merged: s2-art1-cinder-main, s2-kit-ryzz-116-base, s2-trial-116.
- Shots: /home/boki/shots-s2/art1/<hero>/ (Lisette = hem), published to ext/hero-shots-s2 art1/. MP4s stay on disk. Grimble's raw scans live in ~/meshy/grimble, not in git; check ~/meshy for other Heroes before rebuilding.

## 4. Next steps, in order
0. Item 131b READY: ext/fix-kael-sword-131b 77368bca, main's sword 0.70 m. New art's sword is 1.26 m: before landing ext/art1-kael-2, resize it (BLADE_LEN 0.40 and a 0.15 hilt give 0.70 m, proportional) and re-derive hit_r, or the owner's order is undone. Item 185 reopened bug 181 with a Boki cause: S1's lane; S2's frame-rate reading is unconfirmed.
1. Find why tools/dash_frames.gd's later Kael rows got 0 frames on the Mac, then get a clean GPU run; add Forward+ if a worker offers it.
2. When the owner decides on Kael: land ext/art1-kael-2 (refresh on main first), with his sword choice: BLADE_LEN in tools/art1/kael_pieces.py, then re-derive the Lunge tip and hit_r (formula: tip - 0.428 - 0.4).
3. Item 143, phase 2: the core animation set per Hero (idle, run, jump/land, dash, hit, downed) once the owner OKs the crouch style. Strips: hero-shots-s2 art1/anim143/.
4. Item 158 pose, after S5's Mask transformation lands. S3 VFX, S4 sound follow.
5. Polish gaps toward 90, match camera first. Fold Vex and Tarek's crouch polish (data only) and Motley's card tighten (a small shared orbit_k) in here.
6. Remaining: Grimble kit text rewrite (gender, robot, Brass Broadside, Abyssal Hand, Anchor Drop). Boki element VFX if still S2's. --mantle-look check fix. Recurring flakes to fix: --mage-combo Kitefall stacks line (also on main), --teammate goexit lead.
7. Kit half of item 136 is S5's. ext/art1-integ, -2, -3, -4 are superseded; don't reuse.

## Open questions for the owner (defaults are in place)
- Kael: approve his art? Sword 0.60 of height whole (built) or the sheet's 0.79?
- Crouch style OK for item 143 (rollout already shipped; style changes are data).
- Cinder: Shift blocked in Flue Flight (poof gone), X and jump kept.
- Ryzz: Storm Rod in hand on RMB; wires copper-orange or blue.
- Motley: empty hands (sheet's orb dropped). Claire: closed neckline and mid-thigh skirt, darts from the spear tip. Breaker: rest hold low; whirl at true scale. Grimble: sculpted hoard or a second scan.
- The cousin's frame rate for bug 181.
- Permission for lanes to stop their own jobs by PID.
