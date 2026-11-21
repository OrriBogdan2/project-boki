# Project Boki: handoff prompt for a second Claude account

Paste everything below the line into a new Claude session on the other account, in an environment where it can add the GitHub repo. The branches `polish`, `farmstart` and `rolling` are all pushed.

---

You are taking over part of the development of **Project Boki**. The code still says Kinfall/kin in many places. It is a Godot 4.6.2 GDScript game: a top-down PvPvE extraction game with creature raising. Hunters drop onto floating sky islands, fight monsters, bosses, other squads and a hostile faction called the Blight, tame creatures called **Boki**, and extract. Between runs they raise and breed Boki on their own farm island. The owner is Orri (GitHub OrriBogdan2). Another Claude session (the "main session") is also working on the game in parallel.

Your job: **run 4 sub-agents in parallel**, one per workstream below. Each agent works on its own branch and pushes it to GitHub. Run the checks, keep the owner updated, and never stop between tasks. When an agent finishes, start the next queued item.

## 1. Repo and coordination (read carefully)

- Repo: `OrriBogdan2/project-boki`. Attach it to the session, then clone it.
- Branches:
  - `main`: the shipped build.
  - `design`: design docs only.
  - Pushed feature branches are what the main session merges.
- **The main session owns `main`.** You do not merge into or push to `main` unless the owner tells you to take over integration. Push your work to feature branches named in this document, or `ext/<topic>` for new ones. When a branch passes all checks, tell the owner it's ready to merge.
- The main session's own agents are working on two things right now. Do not touch them:
  - the `kits4` branch: Archer/Mage/Gunslinger/Bulwark kits, rank previews, hold/charge feedback, distinct RMBs;
  - the `abysslift` branch: abyss glide lift and the farm glide fix.
- Pull `origin/main` often and merge it into your branches. Resolve conflicts keeping both sides' intent.
- Commit messages end with:
  ```
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

## 2. Environment setup

1. Install Godot 4.6.2 stable (Linux x86_64) and its export templates from the official godotengine GitHub releases. Use `--headless` for checks. For screenshots use `xvfb-run -a godot --rendering-driver opengl3 --audio-driver Dummy -- <hooks> --shot=<png>`.
2. After cloning, run `godot --headless --import` once. Copy the `.godot` folder into every new git worktree you create (`git worktree add -b <branch> ../boki-<branch> origin/<branch>`).
3. **Never use `--fresh` and never write a shared dev save.** Set `XDG_DATA_HOME` to a fresh temp dir for every Godot run.
4. If the machine has few CPUs, cap concurrent Godot runs with a queue wrapper. The main session uses a 2-slot `flock` wrapper. Several agents running heavy sims at once will time out.
5. All checks are hooks in `scripts/main.gd`. Run them as `godot --headless -- --<name>-check`. Each prints `... DONE, failures: N` or PASS/FAIL. A branch is green only when every relevant check reports 0 failures and no `SCRIPT ERROR`.
   - Standard set:
     - `--check`, `--mantle-check`, `--drop-check`, `--extract-check`, `--boss-check`
     - `--duel-check`, `--revive-check`, `--economy-check`, `--home-build-check`
     - `--arena-check`, `--archetype-check`, `--airheal-check`, `--record-check`
     - `--obstacle-check`, `--bot-sanity-check`, `--blight-check`, `--raid-check`, `--teammate-check` (if present)
     - `--simtest --seed=5`
   - Timing checks such as `--hitch-check` and `--load-check` are noisy on slow machines. Report them, but don't block on them.
6. Read these first:
   - `README.md` and `docs/ARCHETYPES.md`
   - `git show origin/design:docs/ROADMAP.md`
   - `git show origin/design:docs/TONE_AND_THREATS.md`
   - `git show origin/design:docs/POSITIONING.md`
   - `git show origin/design:docs/ARCHITECTURE_PLAN.md`

## 3. Hard rules

- **Networking:** anything synced between players goes through `scripts/core/net.gd`. Bump `Net.VERSION` whenever the sync shape changes. It is 0.5.0 on main now; the `rolling` branch may move it to 0.6.0. Never rename Net functions, the `"st"`/`"hit"`/`"ev"` topics, or the `--relay` / `--server=` / `--token=` args.
- **Originality:** no assets, names, text or kits copied from other games. Taking ideas from SUPERVIVE, League, Deadlock, ARC Raiders or Palworld is fine (the owner asks for this), but use original names, art, sounds and numbers. Never use "throw an item to capture a creature": taming is approach + feed + hold to bond.
- Never sign in or enter passwords for the owner. Ask before downloading files.
- Don't change the git remote URL.

## 4. Owner style

- The owner is a busy founder. Reply briefly in standard professional formatting, with minimal em dashes and nothing that sounds AI.
- Lead with what landed and what's next. Send screenshots of visual changes.
- He wants work to keep moving without prompting ("never stop; when an agent finishes, start the next item").

## 5. The four workstreams (one sub-agent each)

Brief each sub-agent with: §1-§4 above, its section below, its branch, and the instruction to commit after every step and report check results plus a screenshot list.

### Agent A: visual polish (continue branch `polish`)

Read `docs/HANDOFF_polish.md` on the branch first; it has the exact state.

Items 1-7 below are already done and committed. Only `--check` has been run on them. What's left:
- Run the full check suite. The drop check and the simtest are the most at risk, because item 7 changed which weapons drop. Fix any failures.
- Item 8. The map generator already makes stairs 3-5 tiles wide, so the one-block look probably comes from how stairs are drawn in `terrain_mesh.gd`. Screenshot with `--at-stairs` to confirm.
- Make chests chunkier, with their own colour and glow.

Then report the branch as ready to merge. Original task list, for reference:
1. Fade or make see-through any tree or tall prop between the camera and your hunter or Boki.
2. Lighten the out-of-sight (view-cone) dimming so scenes read well on camera, while hidden enemies stay hidden.
3. Make Boki readable at the farm camera zoom without changing match hitboxes.
4. Fix the odd camera view after landing from a lair updraft.
5. Fix the training-area glove pedestal labels that overlap, and the "DUEL ROOM" label hidden behind geometry.
6. Loading screen:
   - "Solo · 20 squads" should read naturally, e.g. "Solo · 20 hunters";
   - the loading overlay must be gone before the planning map shows.
7. Minor:
   - the region banner overlaps lair labels;
   - a Thief sees unusable rifles near lairs;
   - the "Make it home" spot markers stay after closing it.
8. Owner art notes:
   - widen one-block-wide stairs;
   - chests vs breakables must be clearly distinct (chunkier chest silhouette, its own colour/glow).

Take before/after screenshots of everything.

### Agent B: owner fixes bundle (new branch `ext/fixes`)

The farm start rework is already finished and being merged by the main session, so don't redo it. Check each item below against current main first (some may be partly done), then build what's missing:
1. Incubator: 5 visible egg slots (buy more as an unlock). Each egg takes time to hatch. An ember Boki or bought warmers speed it up. Slots incubate in parallel.
2. Boss loot: fewer drops, all high value. The Rare Egg drops on its own spot a few metres away with its own beam.
3. Reload on swap: swapping or dropping mid-reload cancels the reload instantly. A dropped gun is full when picked up, unless it's re-picked within ~2 s, in which case it keeps its ammo (prevents a drop-to-reload exploit).
4. Level readability:
   - big level number on the portrait with an XP ring;
   - level-up flash and sound;
   - R visibly locked until level 6.
5. Boss lair vs campers: after the kill, the lair locks you in for ~20 s, then opens. Also consider an inside button.
6. The new farm start means a new player has no crop plots until they place one. Update `tools/loop_tour.gd` (`--loop-tour=thief`) so the full-loop tour runs again end to end.

### Agent C: rolling 30-minute sessions (continue branch `rolling`)

Read `docs/HANDOFF_rolling.md` first. This sits behind a match option `rolling`, off by default until the owner switches it on.

Everything in the brief below is already coded, and `--check` and `--rolling-check` (59/59) pass. What's left:
1. Run the full 30-minute `--rolling-sim` (expect 30-60 minutes) and tune the XP rate given to squads already on the map when you join from its results.
2. Run the full check suite, and compare `--simtest --seed=5` with the pre-change baseline: it extracted by hatch at 205 s.
3. Debug the three screenshot modes and take the shots.
4. Generate `.gd.uid` files for the 3 new scripts by running `--import`. A `.godot` copied from another worktree won't know `class_name Rolling` until a re-import.
5. Ask the owner whether "24-40 hunters" means on the map at once (current reading) or in total over the session.

Rolling stays off for online play until late-join snapshots exist. That is a later task.

Original brief, for reference:

- 30-minute session clock. Squads drop in waves every 2-3 minutes, 2-4 squads per wave, with 24-40 hunters over a session.
- No joins in the last ~8 minutes. The session ends for everyone at 30:00.
- Late-joiner levelling:
  - level floor = min(5, 1 + floor(minutes / 4)) on landing;
  - catch-up XP below the lobby median;
  - bounties on hunters well above the median;
  - per-squad soft landing (the fresh-lander grace and per-squad Blight ramp already exist; key them to each squad's landing time).
- Enlarge the map only in rolling mode if needed.
- HUD:
  - session clock;
  - "joined at mm:ss";
  - wave-incoming indicator;
  - bounty markers.
- Add `--rolling-check` and `--rolling-sim`.

### Agent D: follower Boki, free kit and economy floor (new branch `ext/economy`)

Owner decisions, from ROADMAP §2 on the design branch:
1. **Follower Boki.** Wild Boki are rare now. A tamed Boki can follow you in the match as a "second" Boki instead of going to your inventory. It can be knocked out but can't be tamed by others while you're still in the map. If you leave the map (knocked out or extracted without it), rivals get a steal window to tame it, by difficulty: Easy none, Hard 10 s, Hardest 30 s. Otherwise it goes back to its owner.
2. **Economy floor.** A player can never hit 0 Boki and 0 money with no way to play. Add a cheap Boki market.
3. **Free-kit loaner Boki.** Queue with a basic loadout and a loaner Boki (a reroll of a starter egg) with nothing at risk.
4. **Exchange.** A commodity order book for basic materials, plus a separate Boki market. Start with working local versions and design stubs for the server-backed version (see ARCHITECTURE_PLAN.md: public match server, private backend).

Make sure bots handle follower Boki. Sync through Net and bump the version. Add `--follower-check` and `--economy-floor-check`.

### Queue for agents that finish

Before starting each item, check it isn't already done on main:
1. Blight phase 2: Hollow Fliers (dive at gliders), Husks (armored chargers that break cover), and the Walker (one huge roaming threat per map). Uplinks draw the Blight. Keep the early game weak (TONE_AND_THREATS §1b).
2. Character stylization: stronger, less stiff hunters (exaggerated proportions, chunkier silhouettes per class, expressive faces).
3. Farm follow-ups: cliffs that look like rock faces rather than grassy ridges; some wild land on old saves so the axe and pickaxe have something to chop.
4. Homeplay: resume the paused `homeplay` branch (parkour + wardrobe; dress-up only on the farm, colour variants of hats allowed, never disguising your class).

## 6. Reporting

After each agent finishes, give the owner a short summary:
- what changed;
- check results;
- screenshots;
- the branch name, ready to merge.

Keep a running status list so he can see progress at a glance.
