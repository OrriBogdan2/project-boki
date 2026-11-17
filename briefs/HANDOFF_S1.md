# HANDOFF S1 (hetzner server coordinator), 2026-11-06 06:41 UTC

S1 is a coordinator session: it doesn't code directly. It spawns subagents (one at a time on this account's budget), checks their reports against the code and screenshots, publishes shots, and reports in STATUS (branch ext/server-status) and EXT_TO_MAIN. Main/ext merges.

## 1. STATUS: what is done
All S1 branches are merged into main (checked against origin/main 7907d9af, 2026-11-06 05:12 UTC), except one:
| branch | sha | state |
|---|---|---|
| ext/perf-94c | 3338363c | MERGED: items 103 (match audio teardown) + 94 (perf). Supersedes ext/perf-94 8a50cf1f and ext/perf-94b c8b131b7 (also merged). |
| rigfix | 0fe7a84e | MERGED: RIGFIX.md (rig + weapon pass, docs/RIG_STANDARD.md, --rig-standard-check). |
| ext/small-60-66-75 | f44adba4 | MERGED: Ostra 60 + 75, Cinder 66. |
| ext/claire-62-65 | now c4cf394a | MERGED. S1 pushed WIP 92ad07b0 at the 11-04 20:16 pause; another session finished it. |
| ext/mapclean-fix | c36f6ea3 | MERGED: bot glide-route abort 4.0 m + base-check idle mate. |
| ext/mapclean, ext/airdash-glide, ext/kitdata-* | various | MERGED (sync75-78). |
| **ext/hem-reticle** | **693b1b45** | **NOT merged.** Item 55b (filling aim line + perfect circle). S2's ext/kit-hem-55b covers the same item and most likely supersedes it: check before reviving. Owner Qs were open: one circle or two (Empowered + Supercharged), and red/white vs pale green. |

## 2. Lane rules and conventions I follow
- **Domain now:** perf (item 94 follow-ups), and per the coordinator's 06:40 note, physics items 149, 150, 151, 162/162b and 163 on ext/phys-*. **These were never routed to S1 before this note.** There are no ext/phys-* branches and no S1 work on them yet. The fresh session should start them from OWNER_REVIEW_1103.md (lines ~1597-1900, 2420).
- **Precedence:** briefs/DECISIONS.md > the named items in OWNER_REVIEW_1103.md (a later lettered item overrides, e.g. 55b > 55) > briefs/supervive-data/.
- **Budget:**
  - This account (orri@projectboki.com) is the low-usage one. Run one agent at a time.
  - Use Sonnet for well-specified work, Opus 5.5 medium only when ext says so (perf used it).
  - Run targeted checks while working, and ONE full suite per branch only if shared files changed. Don't re-run checks that are already green.
- **Agent prompts:** use the shared rules file. Copy the scratchpad's q/RULES.txt into the new session: it has the name map, repo rules, check list, screenshot method and jobq. Key points:
  - Names (ids unchanged): Vex = gunslinger, Kael = juggernaut, Hem = archer, Breaker = bulwark, Ryzz = mage, Claire = rimewright, Pip = tender, Tarek = dolm, Sable = thief, Cinder = ashwick, plus Ostra and Dredge. Use "Mask" not "Mantle", and "Fusion" not merge form. Final keys are R = ult, X = Fuse, G = Boki, and text never hard-codes key letters (use Settings.key_cap).
  - Big shared files (hunter.gd, main.gd, match.gd, hud.gd, home.gd) get wiring only.
  - Reserved, don't touch: kin_*, merge_kit.gd, merge_*.gd, content/merge_forms/, boki_system.json, capture.json.
  - Health: python3 tools/health.py --strict (style ratchet) and tools/gen_wiki.py --check.
- **Godot:**
  - Always `timeout 1200 godot --headless -- --<check>`. The `--` separator is required, and the PATH wrapper gives a fresh XDG.
  - Never use --fresh or the shared save. Never pkill by pattern, and kill only processes you started.
- **GPU (INBOX 11-06 04:55):** hetzner has no GPU. Screenshots, strips, sheets, reels and ALL perf numbers go through `~/bin/jobq submit --tree <wt> --needs gpu --out <dir> --label <x> -- <hooks>`, then `~/bin/jobq wait/result <id>`. ~/bin is not on the Claude shell PATH, so use the full path.
- **Blender:** /home/boki/tools/blender-4.5.15-linux-x64/blender (not on PATH).
- **Git:**
  - Use gitnet for fetch/push. Normal pushes only: never force, never main.
  - After every push, fetch and confirm origin equals HEAD. Don't hide git errors.
  - Check `git merge-tree --write-tree origin/main origin/<branch>` before calling a branch READY.
  - GitHub sometimes returns 500 on push, so retry (scratchpad push_status.sh retries 4x).
  - The commit trailer is whatever the current brief or system reminder says.
- **Posting to ext/agent-briefs:**
  1. Make a temporary detached worktree of origin/ext/agent-briefs.
  2. Append, commit, then push HEAD:ext/agent-briefs. If it's rejected, rebase and push again.
  3. Verify, then remove the worktree.
- **STATUS:** ~/server-status is the orphan branch ext/server-status. The scratchpad status_body.md holds the body and push_status.sh prepends the timestamp. Push on every agent start/finish and at least every 2 h. The format is a FOR EXT/FOR MAIN block on top, then the branch table, then "Running now:", "Queued:", "Questions for the owner:" and "Last INBOX entry handled:".
- **Watcher:** ~/bin/inbox_watch.sh (cron every 10 min, @reboot) nudges tmux boki:0.0 on new INBOX headings and on a stale STATUS (> 45 min). It auto-restarts claude --continue if the pane is a bare shell, with a 15-min cooldown. It only targets window 0, so a fresh S1 in another window gets no nudges unless TARGET is changed.

## 3. Gotchas learned (verify, don't trust agent reports blindly)
- **Close-up quality:** decimation to ~14k shows more shading slivers on faces and cloth in close-ups. Match zoom looks identical. The owner decision is still open: accept, or full detail for close-up viewers only.
- **Map changes:** they shift bot RNG paths and expose latent bugs (mapclean: base-check and boss-check). Run --base-check, --boss-check, --drop-check and --extract-check on any map or geometry change.
- **move-feel-check:** it is spot-dependent, so it now tries its calibration spot first.
- **Merge conflicts:** S2 ships new Hunter GLBs often, so any branch that touches art/wardens/*.glb conflicts fast. Re-decimate main's new art; never keep the old binary.
- **Agents:** they sometimes report checks they didn't run on the final commit. Re-run the one in doubt yourself.
- **Known same-on-main failures (11-05):** --merge-form-check ("to fuse" wording), --teammate-check (rival called before the chest), --obstacle-check (1 line, rc 0), and --hitch-check (lazily built kit FX shaders: LDFx, DJFx, PinFx, swoosh, Boki aura x-ray).
- **Owner preferences:** quality first; don't ship below the bar. Done means played. Fewer, bigger merges, ideally one integrated READY branch per session per day. Keep owner messages brief and plain, with minimal em dashes.

## 4. In-flight work
- **Running agents:** none. Item 185 is assigned but not started (see step 0).
- **Uncommitted:** none in S1 worktrees. The ~/boki-* worktrees listed in `git worktree list` that belong to S1 can be removed: perf-94, perf-94b, perf-integ (= ext/perf-94c), rigfix, small-60-66-75, claire-62-65, hem-reticle, mapclean, mapclean-fix, airdash-glide, kitdata-*, kitfix-*. They're all pushed.

## 5. Next steps, in order
0. **FIRST: item 185 (bug 181 reopened), branch ext/phys-185-boki-dash from origin/main, post READY there.** Assigned by the coordinator at INBOX 2026-11-06 07:40 UTC, after this handoff was first written; not started on S1.
   - The owner says the "blink" dashes (Kael's RMB Lunge, Sable's dash) come from a Boki interaction changing the dash, not frame rate.
   - On current main, verify the item 129 dash-rider removal (DECISIONS 2026-11-05).
   - List every code path where a Boki touches the hero's dash or movement: Boki kits, kin.gd, buffs, passives, auras, commands. Remove or fence what remains. kin_* files are reserved, so fence from the hero/dash side or ask the coordinator.
   - Add a check: with every Boki species equipped in turn, Kael's Lunge and Sable's dash keep the no-Boki baseline's duration, distance and animation frames.
   - Input: the Boki audit, item 186.
1. **Physics items 149, 150, 151, 162/162b and 163** (newly assigned): one ext/phys-* branch per group, from origin/main.
   - Read each item fully; 150 is the SUPERVIVE parity pass.
   - Mind 151's layout rules versus mapclean's no-tiny-walls rule (owner #2): both must hold.
2. **Perf follow-up if ext wants it:** warm the lazily built kit FX shaders so --hitch-check passes.
   - Measure with `jobq --needs gpu` (--hitch-check, --perf-probe --probe-full, --perf-bench).
   - The remaining ranked costs: Hunter sim ~5 ms and Boki sim ~2.5 ms per step, Match._separate allocations, and "triangulation failed" errors.
3. **ext/hem-reticle 693b1b45:** confirm it's superseded by S2's kit-hem-55b, then retire it.

## Open questions (owner)
- Close-up models at ~14k tris: accept, or full detail for close-ups only?
- Hem 55b: one circle or two? Line colour?
- A real-GPU perf re-run on main after perf-94c. The merge-candidate cron now does GPU perf comparisons (ext/reports): read those first.
