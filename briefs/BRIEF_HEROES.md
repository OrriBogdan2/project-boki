# Hero kit brief (all hero-pair agents)

Read `~/briefs/BRIEF_COMMON.md` first; it applies in full (environment, `godot` wrapper with 2-slot queue and fresh XDG_DATA_HOME, `gitnet` for all git network ops, never push to main, never `--fresh`, commit trailer). Then read in your worktree: `README.md`, `docs/ARCHETYPES.md` (especially "Kit loops"), everything in `scripts/arch/` and `scripts/arch/kits/`, the existing `content/archetypes/*.json`, and how heroes are drawn (find the hero art code used by the existing six archetypes). Also read `~/briefs/BOKI_HANDOFF_PROMPT.md` §3.

Use `timeout` on every Godot run. Run targeted checks while iterating and the full suite once per branch, at the end. Skip --hitch-check and --load-check. Batch screenshots into one run.

## The task

The owner wants the kits of specific heroes from the game SUPERVIVE reproduced in Project Boki under new identities. Gameplay behaviour follows the source closely. Everything a player sees or hears is original.

### Accuracy (gameplay)
- Before building a hero, read its page on supervive.wiki.gg with WebFetch (`https://supervive.wiki.gg/wiki/<Name>`; follow ability subpages if the hero page is thin). Take notes in your own words.
- Reproduce every slot as closely as our engine allows: LMB tap/hold, RMB, Shift, Q/E, R and the passive, including input patterns, shapes, conditions, resets, combos and rank 2-3 upgrades.
- Scale numbers to our health and time-to-kill, keeping each hero's behaviour relative to the others (ranges, cooldown ratios, damage share, mobility). Don't copy raw numbers; derive ours from the scaling.
- Note anything the engine can't reproduce and what you did instead.

### Originality (non-negotiable, so the game can ship)
- New hero name and new ability names for every slot. Never use a source hero or ability name anywhere in the game: code identifiers visible to players, UI, JSON text, sounds, file names shipped in the build. (Internal design docs may name the source for traceability.)
- Fresh ability descriptions written from scratch. Never paste or closely paraphrase wiki text.
- Hero art must be an original character design that is NOT recognizable as the source hero: different silhouette, outfit, colour palette, props and weapon look. Don't recreate the source hero's signature visual features. Match the quality and style of our existing six heroes.
- VFX, sounds and the payoff word are original. Generate sounds with the repo's own sfx tooling.

### Every hero needs
- One fixed signature weapon (weapon pickups are being removed in a separate task; your hero must work whether or not pickups still exist).
- `content/archetypes/<id>.json` with a "card" block, plus next-rank text for every ability.
- Hold wind-up feedback on every hold input.
- A payoff moment: hitstop, shake, its own sound and a big word.
- Bots that play the kit sensibly (engage range, ability use, retreat).
- Arena support: hero swap and `--arena-demo` shots.
- Net sync for new effects through `scripts/core/net.gd`. Main is now Net 0.6.0. Use the version assigned to your branch below and report it; the integrator reconciles. Never rename Net functions or the "st"/"hit"/"ev" topics.
- Weight class wired to the existing movement/weight system (Light = Myth, Joule, Celeste, Shiv; Medium = Ghost, Elluna, Tetra, Void; Heavy = Brall, Felix, Kingpin, Oath).

### Merge hygiene
Four hero branches run in parallel and will all touch the same registries (archetype list, arena hero swap, bot dispatch, check hooks in `scripts/main.gd`). Keep those edits small and append-only, one line per hero where possible, so merges are trivial. Put kit logic in its own files under `scripts/arch/kits/`. Merge `origin/main` at the start and before the final push.

### Done means
- Full standard suite passes with 0 failures and no SCRIPT ERROR, including `--archetype-check`, `--ability-check`, `--arena-check`, `--bot-sanity-check`, `--duel-check`, `--revive-check` and `--simtest --seed=5`. Extend `--archetype-check` / `--ability-check` to cover your heroes' slots.
- Screenshots per hero under your shots folder: kit card, each ability, payoff. Look at each one with Read before reporting it.
- A per-slot table per hero in `docs/heroes/<id>.md`: slot, input, what it does (our text), source behaviour, any difference and why. Include the scaling you used.
- Branch merged with latest origin/main, pushed, and reported as ready to merge.

### Report back
Same format as BRIEF_COMMON.md, plus for each hero: new name, archetype id, the per-slot table, and the Net version used.
