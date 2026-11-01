# Known technical debt

Each line: the debt, why it matters, and the fix. Remove the line when it's fixed. `tools/health.py` counts entries.

- God files: match.gd (~6.9k lines), home.gd (~5.8k), main.gd (~4k, mostly inline checks), hud.gd (~3.8k), models.gd, hunter.gd, world.gd. These make every change risky and slow to review. Split by system into focused modules, then lower the budgets in tools/health.py.
- Checks hooked inline in main.gd (about 48 `--*-check` branches). Move each into tools/<name>_check.gd behind one registry so main.gd is only startup.
- Duplicate content versions: content/abilities + abilities_v2, kin + kin_v2. Migrate the callers to one version and delete the other.
- Dynamic calls (`has_method`, `get_script_method_list`, `call("...")`) used for optional features. Replace them with typed references or CombatBus signals.
- Internal names still say kin/Kinfall/archetype while the game says Boki/Project Boki/class. Rename gradually with tools/rebrand.py, never in a big bang.
- Timing checks (--hitch-check, --load-check) are noisy on the shared 2-CPU machine. Move them to CI with stable hardware, or mark them advisory.
- Stale player-facing text found by the wiki pass: README controls/revive/shimmer/renderer facts, "Archetype" labels in Settings.ACTIONS, evolved Boki names built from old internal roots (evo.gd ROOTS; three rare species missing), retired abilities still in class/weapon descriptions, Data.MATCH keys and Data.BUILDINGS/ISLES no longer used, stale comments and doc paths. Fix them in one cleanup pass and keep the wiki generator's --check green.
- main.gd: the --airheal-check branch has no return and falls through to the following hooks. Fix it while moving checks into the registry.
- Class R abilities are held back behind `content/rules/boki_system.json` `class_ults` (off) now that R is the Merge (docs/decisions/0001). The hero-port session should delete the class R code path (ArchKit.use_r, the `r` rows in content/archetypes/*.json, the kit-card held-back line) once the kits are ported. The R slot still unlocks at run level 6; whether the Merge should unlock earlier is an open question in the ADR.
