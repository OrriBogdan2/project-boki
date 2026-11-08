# Server update 7: kit data pass (owner's game data is now the source of truth)

The owner pulled real values for every hunter from in-game tooltips and game data:
- `briefs/supervive-data/supervive_kits.md`: all 12 kits, with rank II/III/IV upgrades.
- `briefs/supervive-data/kit_comparison.md`: our kits against that data, with file:line refs and a top-10 list.
- `briefs/supervive-data/supervive_physics.md`: movement data. That's the main session's job, but read per-hunter values from it where a kit needs them.

Where the data and the footage disagree, **the data wins**. Owner overrides in INBOX and SERVER_UPDATE5/6 still win over both.

## How to run it (cheap, Sonnet)
- **One Sonnet agent per pair, at most 2 at once.** Usage is tight this week.
- **Order:**
  1. dancer-juggernaut and pin-bjorn first. They were reported ready, so the main session may merge them before you start. If either is merged, branch `ext/kitdata-<pair>` from origin/main; otherwise work on the kitfix branch.
  2. Then the other four, each **on its kitfix branch** before it lands.
- **Scope:** every item for that pair's two hunters in kit_comparison.md (the top-10 list plus the per-hero sections). Mechanics and numbers only.
  - Use our own names and our own wording; never copy tooltip text into the game.
  - Keep each hunter's original look.
  - Skip R/ultimate mismatches: hunter ultimates are on X and already built from footage. Only touch an ult if the data shows a mechanic we have wrong.
- **Rank paths:** match the source's rank II/III/IV upgrades where our rank system allows it, and list any that don't fit.
- **Movement values** (`move_speed`, `accel`) come from main's archetype data once it exposes them. Don't hard-code them.
- **Checks:**
  - Update each hero's combo check to assert the changed numbers and behaviours.
  - Run the targeted checks plus one full suite at the end.
  - health --strict, including the style ratchet.
- **Report** in STATUS.md, per pair: commit; items done, skipped and why; lines +/−.
  - Don't take new screenshots unless a visual changed.
  - I'll do a light review before telling main the pair is ready.
