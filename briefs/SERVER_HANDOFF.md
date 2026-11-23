# Server session handoff: Project Boki hero kits

You are the coordinator on the Hetzner agent server (16 cores, 64 GB). Repo: `~/project-boki` (full clone, `gh` auth set up). Another Claude session (on a small cloud box) is running four other workstreams (`polish`, `ext/fixes`, `rolling`, `ext/economy`); the owner's main session owns `main`. You own only the hero branches below.

## Read first
1. `~/briefs/BRIEF_COMMON.md` (environment, git, rules, report format)
2. `~/briefs/BRIEF_HEROES.md` (the hero task)
3. `~/briefs/BRIEF_HEROES_UPDATE1.md` (owner update: no R, Boki keys, animations, research, combos). It overrides BRIEF_HEROES where they differ.
4. `~/briefs/BOKI_HANDOFF_PROMPT.md` §1-§4 only (coordination and hard rules)

Get the briefs with: `cd ~/project-boki && git fetch origin && git worktree add ~/briefs-src origin/ext/agent-briefs && cp -r ~/briefs-src/briefs ~/briefs`

## Environment on this server
- `godot` on PATH is a FIFO queue with 14 slots and a fresh XDG_DATA_HOME per run; it logs every run to `/tmp/godot-runs.log`. Always wrap runs in `timeout`.
- `gitnet` serializes git fetch/push. Use it for all network git ops.
- Screenshots: `timeout 600 xvfb-run -a godot --rendering-driver opengl3 --audio-driver Dummy -- <hooks> --shot=<abs png>`; save under `~/shots/<pair>/`.
- Create a worktree per pair: `git worktree add ~/boki-heroes-<pair> origin/ext/heroes-<pair>` then `cd` into it, `git checkout -B ext/heroes-<pair> origin/ext/heroes-<pair>`, and copy `~/project-boki/.godot` into it.

## State of the hero branches (all pushed, all very early)
| Pair | Branch | Archetype ids | Weight | Net version | State |
|---|---|---|---|---|---|
| Joule + Ghost | ext/heroes-joule-ghost | mage, gunslinger (keep ids, rebuild kits) | Light, Medium | 0.6.1 | WIP: started Joule data/weapon; one WIP commit |
| Kingpin + Felix | ext/heroes-kingpin-felix | new, original ids | Heavy, Heavy | 0.6.2 | only main merged, nothing built |
| Elluna + Celeste | ext/heroes-elluna-celeste | new, original ids | Medium, Light | 0.6.3 | WIP: archetype data + weapon for the first support hero (not wired) |
| Tetra + Void | ext/heroes-tetra-void | new, original ids | Medium, Medium | 0.6.4 | only main merged, nothing built |
| Myth + Oath accuracy pass | ext/heroes-myth-oath (create from main) | archer, bulwark | Light, Heavy | 0.6.5 | queued |

Pair-specific notes:
- Kingpin + Felix: pulls/displacement and zones/burn must respect world collision and abyss rules.
- Elluna + Celeste: healers. Ally targeting must work with bot and online squadmates; revives integrate with the existing knock/revive system; add a support check.
- Tetra + Void: terrain/zones must respect collision, mantle/obstacle systems and abyss edges; sync placement over Net; add a zone check.

## Originality (non-negotiable)
- New hero names and ability names, fresh descriptions in our own words. Never paste or closely paraphrase wiki text. Never use source hero or ability names in anything player-facing.
- Each hero is an original character designed from our own concept (role, weight, element). It must not be recognizable as the source hero: different silhouette, outfit, palette, props, weapon look and VFX style. Do not fetch or view images of the source heroes; use sources only for gameplay behaviour.
- Animations, sounds and payoff words are original.

## USAGE BUDGET (owner priority: do not exhaust the weekly plan limit)
The owner is on the top individual plan and is worried about hitting 100% before the weekly reset. Work efficiently:
1. **Run at most 2 hero pairs at a time.** Start Joule+Ghost and Elluna+Celeste first. When one finishes, start the next (Kingpin+Felix, then Tetra+Void, then Myth+Oath).
2. **Subagents use `model: "sonnet"`** for implementation, checks and screenshots. The coordinator stays on the default model and only coordinates.
3. Keep coordinator turns short: no polling loops, no reading subagent transcripts or long logs; read only the final report and the tail of logs.
4. Research per hero: at most ~5 sources (wiki hero page + ability/upgrade pages, latest patch notes, one guide). Extract notes once into `docs/heroes/<id>.md`, then work from the notes.
5. Agents read files in focused ranges (grep first, then Read with offset/limit), not whole large files repeatedly.
6. Targeted checks while iterating; full suite once per branch at the end. Batch screenshots.
7. If the owner reports usage above ~70% with more than 2 days to reset, drop to 1 pair at a time and pause the Myth+Oath pass.

## Reporting to the owner
Short, standard professional formatting, minimal em dashes, nothing that sounds AI. Per finished branch: what changed, check results table, screenshot list, per-slot tables, ult choices, combos table, Net version, branch ready to merge. Keep a running status list.
