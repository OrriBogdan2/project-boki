# Common brief for every Project Boki workstream agent

Read the full handoff first: `~/briefs/BOKI_HANDOFF_PROMPT.md`. Sections §1 (repo and coordination), §2 (checks), §3 (hard rules) and §4 (owner style) apply to you in full, plus your own workstream section in §5. The notes below override §2's setup steps, because the environment is already prepared.

## Environment (already done, do not redo)

- Godot 4.6.2 is installed. The `godot` command on PATH is a wrapper that:
  - queues runs into a FIFO pool of (cores - 2) slots (14 on this 16-core server); every run is logged to /tmp/godot-runs.log, and
  - gives every run a fresh temp `XDG_DATA_HOME` automatically, so no shared dev save is touched.
  Always call `godot`, never `/opt/godot/godot-bin` directly. Always wrap runs in `timeout` (e.g. `timeout 900 godot --headless -- --drop-check`). A run can wait in the queue before starting, so allow for that. Don't run the whole check suite as parallel background jobs; run checks one after another.
- Export templates are installed (only needed for exports).
- Screenshots: `timeout 600 xvfb-run -a godot --rendering-driver opengl3 --audio-driver Dummy -- <hooks> --shot=<abs path>.png`. Save every screenshot under `~/shots/<your-branch-short-name>/` with a descriptive name (e.g. `before_chest.png`, `after_chest.png`). Look at each screenshot with the Read tool to confirm it shows what you intended before reporting it.
- Your git worktree already exists with `.godot` copied in. Work only in your own worktree. Never touch other worktrees or `~/project-boki` (main checkout).
- **All git network operations (fetch, pull, push) must go through `gitnet`** (e.g. `gitnet fetch origin main`, `gitnet push origin <branch>`). It serializes them, so concurrent agents never race each other on pushes. Local git commands (commit, merge, log) use plain `git`.
- The clone is a full clone.
- Before pushing, `gitnet fetch origin main` so the push sends a thin pack.
- Commit identity is configured. Every commit message ends with:
  ```
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```
- If a new script with `class_name` isn't recognized, run `timeout 600 godot --headless --import` in your worktree, and commit any new `.gd.uid` files.

## Rules that matter most

- Never push to or merge into `main`. Push only your own branch. Do not touch `kits4`, `abysslift`, or any other agent's branch.
- Merge `origin/main` into your branch at the start and again before your final push; resolve conflicts keeping both sides' intent.
- Commit after every meaningful step, and push regularly so work is never lost.
- Never use `--fresh`. Never sign in anywhere or enter passwords. Don't download anything beyond what the repo's own tooling needs; if you think you need a download, list it in your report instead.
- Original names, art, sounds and numbers only. Taming is approach + feed + hold to bond, never throwing an item.
- Anything synced between players goes through `scripts/core/net.gd`; bump `Net.VERSION` when the sync shape changes. Never rename Net functions, the "st"/"hit"/"ev" topics, or the --relay/--server=/--token= args.
- You cannot talk to the owner directly. If you hit a genuine owner decision, pick the most reasonable default, keep it easy to change, and list the question in your report.

## Definition of done

Every relevant check from the standard set in §2 reports 0 failures and no `SCRIPT ERROR`, plus any new checks your workstream adds and `--simtest --seed=5`. Timing checks (`--hitch-check`, `--load-check`) are reported but don't block. Branch merged with latest `origin/main` and pushed.

## Your final report (returned to the coordinator, keep it tight)

1. What changed, as short bullets an owner can read.
2. Check results as a table: check name, failures, notes. Include the simtest outcome (how it ended and when).
3. Screenshot list: absolute path + one-line caption each, before/after pairs where relevant.
4. Branch name and final pushed commit hash.
5. Open questions for the owner, and anything you couldn't finish and why.
