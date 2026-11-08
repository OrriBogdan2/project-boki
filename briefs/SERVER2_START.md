# Second server session ("S2"): start here

You are a second Claude Code session on the owner's 16-CPU server, on a separate account. A first session ("S1", tmux `boki`) already works here. You both work on Project Boki (Godot 4.6.2 GDScript top-down PvPvE extraction game with creature-raising Boki), repo OrriBogdan2/project-boki. The main session (elsewhere) owns `main` and merges; ext (another session) coordinates and reviews. Never push to `main`.

## Read first
1. `briefs/OWNER_REVIEW_1103.md` (all items; the owner's playtest notes, the spec for your work).
2. `briefs/INBOX.md` from the "06:25 UTC" entry on (standing rules), and the 07:05 UTC work-order entry.
3. The repo's `AGENTS.md`, `docs/STYLE.md` (lean rules, style ratchet), and the hero docs/kits for your heroes.
4. Source data for kits: `briefs/supervive-data/` (precedence: owner notes > game data > footage refs in `briefs/hero-ref/`).
5. S1's `STATUS.md` on branch `ext/server-status` to see what S1 has in flight.

## Your share (S1 keeps everything else)
Per hero pair, do every OWNER_REVIEW item for those heroes, plus their rows of items 32 (dash -> ability flow) and 35 (own dash animation). One branch per pair: `ext/review-<a>-<b>` from current origin/main.
1. **Breah + Ostra** first: bugs 26 and 42 at the start, then 14, 15, 16, 17, 18 (concept note only), 25, 40.
2. **Zedran + Bjorn**: 21, 22 (Zedran's Warchain on **Opus 5.5 medium**; the rest Sonnet), 10, 29, 30.
3. **Tamsin + Dredge**: 12, 13, 27, 28, 31, 33, 35 (Dredge's monster dash), 36.
4. **Linwick + Moosh Moosh**: 11, 19, 20, 23, 24.
S1 keeps: the airdash-glide fix, item 2 (mapclean), Pin + Venator, Vireo + Dancer, and the farm tutorial.
Do not touch items 34, 37, 39, 41, 43 (concept pass, rename, lore: ext's).

## Limits
- Up to 4 agents at once (Sonnet by default; Opus 5.5 medium where a kit is complex or a Sonnet agent clearly misreads the source mechanic; say which and why in your status).
- One full test suite per branch, at the end. Targeted checks while working.
- The godot queue is shared with S1. If the server's godot wrapper is a slot queue, set it to 8 slots total (16 CPUs) if it's lower, and tell S1 in your status.
- All repo rules apply: big files wiring-only (match/home/main/hud/hunter/models/world.gd), reserved Boki files (kin_*, merge_*, capture*, field_book, boki_hud, bot_kin, content/merge_forms, merges_v2, boki_system.json, capture.json) untouched, `python3 tools/health.py --strict` with no budget raised, new checks in tools/check_registry.gd, never hand-edit content/maps/hollowcrown.json, never `--fresh` or a shared dev save, fresh XDG_DATA_HOME per Godot run, never `pkill` by pattern.
- Commits end with the Co-Authored-By / Claude-Session trailers the harness gives you. Normal pushes only.

## Reporting
- Write your status to `STATUS.md` on branch `ext/server-status2` (create it): one section per pair with branch, commit, items done/left, checks, screenshots path, owner questions. Update it at least every hour and when a branch is ready.
- New instructions for you arrive in `briefs/INBOX_S2.md` on `ext/agent-briefs`; check it every 15-30 minutes and before starting each pair.
- Don't stop while work remains. If an agent stops unfinished, restart it.
