# 0020: The glider's dive

- **Status:** accepted
- **Date:** 2026-11-08
- **Area:** movement

## Problem
KIT_PARITY item 18: SUPERVIVE's glider can fold into a dive (Z target -3250 uu/s, pulled there by 350,000
force over 100 mass, keys at 0.25 of their force, cancelled 350 uu above the ground or after 10 s). Ours
only sank or swooped. The source's data and footage name no dive input, and Space is the glider itself
(item 179: hold to glide, release to close).

## Options
1. Overload the existing `diving` flag (the opening skydive). Cheap, but `_deploy`, `_break_drop`, DropReticle
   and DropFeel all read it as "still in the drop", so it would break the opening.
2. A focused `GlideDive` module holding the dive state, wired into the glide branch with a few lines,
   tunables in `content/rules/hunter_move.json`. The anim pose reuses the skydive's folded canopy via
   `Hunter.plunging()`.
3. Key: a new dedicated bind, or hold crouch (Ctrl), which does nothing in the air.

## Decision
Option 2 with crouch-hold as the key. The numbers are the source's; the key is ours (there is none to match)
and costs no new bind. A dedicated bind stays open as the alternative if the owner wants one.

## Consequences
- `scripts/match/glide_dive.gd` (new), `HunterMove.dive_*`, eight lines in `hunter.gd`.
- `GlideLift.sink` caps the swoop at `GLIDE_MAX - GLIDE_SPEED` so pulling out of a 32.5 m/s dive tops
  out at the glide's max instead of ~80 m/s.
- Net.VERSION bump: no. The dive changes velocity, which the snapshot already carries; the folded pose
  is local-only until `diving` joins the snapshot.
- Checks: `--move-feel-check` rows `dive_*` assert each source number; docs/MOVEMENT_FEEL.md and
  docs/SUPERVIVE_FEEL.md updated.
- Debt: the dive cancels 3.5 m up but the canopy can't brake 32.5 m/s in that height, so you land hard
  (no fall damage exists). Source behaviour near the ground is unknown.
