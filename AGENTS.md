# Rules for coding agents (and humans) working on Project Boki

Read this before changing code. The goal: every change leaves the codebase as easy to work in as it was, or easier. New features must not add debt. **How code should read** (naming, line length, comments, no shadowing Godot, keeping the game lean) is in [docs/STYLE.md](docs/STYLE.md): read it too.

## 1. Before you write code
- **Apply the expert checklist.** Go through `docs/GAMEDEV_CHECKLIST.md` (game feel, systems, performance, rendering) for anything gameplay-facing, and use the matching techniques by name.
- **Read the area first.** Find the existing system that already does something similar and extend it. Don't build a parallel one. Search with `grep -rn` across `scripts/` and `content/`.
- **Anything that touches a core system needs a short design note first.** Core systems are movement, combat, networking, the save format, and the match flow. Write it in `docs/decisions/NNNN-title.md` using the template there. It covers the problem, the options, the choice, and what it affects, in 10-20 lines. Small features don't need one.
- **Data over code.** Classes, Boki, gloves, weapons, maps and rules live in `content/` as JSON. A new hero, item or map should mostly be data plus one focused script, never edits scattered across `match.gd`.

## 2. Where code goes
| Kind of code | Where |
|---|---|
| A class kit | `scripts/arch/kits/<id>_kit.gd` + `content/archetypes/<id>.json` |
| Boki behaviour | `scripts/kin/` (grammar, exec) and `scripts/match/kin*.gd` |
| Match systems (lairs, exits, Blight, weather, sessions) | one file per system in `scripts/match/`, wired into `Match` by a few calls |
| Farm/home systems | one file per system in `scripts/home/` (like `home_build.gd`, `home_work.gd`) |
| HUD widgets | `scripts/ui/` |
| Checks and test tools | `tools/<name>_check.gd`, registered in the check registry (never inline in `main.gd`) |
| Networking | only through `scripts/core/net.gd` |

**God files are frozen.** `match.gd`, `home.gd`, `main.gd`, `hud.gd`, `hunter.gd`, `models.gd` and `world.gd` may not grow:
- A change may add at most a few lines of wiring to them.
- New logic goes into a new or existing focused module.
- `tools/health.py` enforces this with line budgets and fails the ship if a budget is exceeded.

## 3. Keep it lean (no bloat)
- **Build exactly what the task asks.** No extra features, options, settings, hooks or "future-proofing" nobody asked for. If you think something else is needed, say so in your report instead of building it.
- **Extend before you add.** Find the existing system first and grow it. A second system that does almost the same thing is a bug.
- **Net lines matter.** Prefer the change that removes code. Every change should delete the code, flags, content and checks it makes obsolete.
- **No speculative abstraction.** Write the direct version. Generalise only when a second real use exists.
- **No leftovers:** commented-out code, unused vars or params, stray prints and debug toggles don't get committed.
- **Hot paths stay cheap.** Per-frame code doesn't allocate, scan everything or load resources without need.
- **Report the cost.** Your final report lists lines added and removed (`git diff --stat`) and any new files, assets or settings, with why each one is needed.

## 4. Rules while coding
- **One responsibility per file and per function.** Split rather than append. Aim for files under ~800 lines and functions under ~60.
- **No duplicate systems or versions.** Don't add `foo_v2` next to `foo`. Migrate, delete the old one, and update the callers in the same change.
- **Delete what you replace.** Remove dead code, old flags, unused content and compatibility shims when you supersede something. If removing something risks too much, file it in `docs/DEBT.md`.
- **No silent dynamic calls.** Avoid `has_method`, `call("name")` and `get_script_method_list` for things you control. Use typed references or signals (`CombatBus`).
- **Constants with a unit and a reason.** Put tuning numbers in `content/rules` or a named `const` with a one-line comment (units, what it controls), not magic numbers inline.
- **Networking:** anything synced between players goes through `Net`. Bump `Net.VERSION` when the sync shape changes. Never rename Net functions, the `"st"`/`"hit"`/`"ev"` topics, or the `--relay`/`--server=`/`--token=` args.
- **Saves:** every save-format change comes with a migration. Old saves must load.
- **Player-facing text:** write it in our own words and use our own names. Never copy text, names or assets from other games.

## 5. Testing (cheap and meaningful)
- **Every feature adds or extends a check** that asserts its behaviour, in `tools/` and registered.
- **While iterating, run only the checks for what you changed.** Run the full suite once, on your final commit.
- **Don't weaken a check to make it pass.** If a check's assumption is wrong, fix the check and explain why in the commit.
- **Godot runs go through `/home/claude/gq`** with a temp `XDG_DATA_HOME`. Never use `--fresh` or the shared dev save.

## 6. Finishing a change
- Commit in small logical commits with clear messages.
- Update the docs that describe what you changed:
  - `docs/wiki` (run `tools/gen_wiki.py` if data changed)
  - the system's doc in `docs/`
  - `docs/DEBT.md` if you knowingly left debt
- Run `python3 tools/health.py --strict`. It must pass: god-file budgets and the style ratchet (`tools/style_lint.py`: no file may get worse; fix what you touch and lock it in with `--update`).
- Report: what changed, which files, the checks run and their results, and any debt you left (with the `docs/DEBT.md` entry).

## 7. Review before merge
The integrator (the main session) merges branches into `main`. Before merging any feature branch, a separate reviewer agent reads the diff with fresh eyes against this file, looking for:
- god-file growth
- bloat: features, options or abstractions nobody asked for; a net line count out of proportion to the task
- readability against docs/STYLE.md (names, packed lines, nested ternaries, history comments, shadowed Godot names)
- duplicated systems
- dead code left behind
- missing checks or migrations
- Net and save risks

Findings get fixed before merge, or filed in `docs/DEBT.md` with an owner task in the queue.
