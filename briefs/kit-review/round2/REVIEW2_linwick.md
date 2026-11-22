# Re-review (round 2): Linwick (`ashwick`), origin/ext/kitfix-linwick-dredge @ 7d96b6df

**Verdict: PASS (minor nits).** The fire now holds its colour on bright grass:
- The lance is a deep orange-red stream.
- The cinder is a pink-red fireball.
- The ram has a jagged red burst.
- The cloak throws a spiky sunburst.

The owner's two dashes are distinct, and Flue Flight (X) lays a curved lava carpet that steers. One hard-coded "X" in his card text must be changed before merge. It is a pair-level text fix.

## Round-1 FIX items
| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Fire washes out (blend-mix body plus additive core) | Done. | v2/polish/lw_lance_stream_game.png |
| 2 | Cinder Shot as a red-pink fireball | Done. A pink-red head with a violet halo. | v2/polish/lw_cinder_flight_close.png |
| 3 | Flame skull during the ram | Done. A large jagged red-orange burst ahead of him, and fire behind. | v2/polish/lw_ram_skull_close.png, lw_anim_ram.png |
| 4 | Cloak: arms wide and a jagged burst | Done. The flamer swings up and a spiky sunburst fills the frame. | v2/polish/lw_anim_cloak.png |
| 5 | Flashover payoff plays during the lance | **Partly done.** The flamer lifts (fist pump) in frames 2–4 and FLASHOVER shows at his feet, but the body bounce is small at zoom. | v2/polish/lw_anim_flashover.png |
| 6 | Torch Lance pose near-static; bigger pilot | Done. A wobble and a larger cyan pilot. | v2/polish/lw_anim_lance.png |
| 7 | Air-dash pink sphere and camera | Done. The strip flies clear and ends on him (commit 5b338ece). | v2/polish/lw_anim_air_poof.png |
| 8 | Flashover bar glow (optional) | Done (pips above the plate). | v2/polish/lw_flashover_pips.png |

## New checks
- **Ultimate (Flue Flight).**
  - It matches the reference: a tap and an ember ring at lift-off, then a 1.4 s flight at 12.6 m/s that steers at 120°/s toward the cursor.
  - The flight lays a 1.8 m lava carpet for 4 s, with burn, slow and Char. X again lands.
  - The carpet shader is alpha-blended, with a dark rim that stays dark on grass.
  - Evidence: v2/ult/linwick_ult_impact.png (curved carpet), linwick_ult_strip.png, v2/polish/lw_ult_liftoff_game.png.
- **Body and dash.**
  - Body: `size` 0.76 × heavy and `bulk` 1.05, with quick steps (cadence 1.8).
  - Ground ram: 3.4 m in 0.28 s.
  - Air poof (owner note): 8 m in 0.24 s, keeping 50% momentum, with a brown-orange smoke burst and a spread-eagle pose.
  - Both go through `travel()`, so the ×0.85 / ×1.15 dash feel applies.
- **Readability.** Good.
- **Effects.** In his fire palette. The cyan pilot is deliberate as a warm/cool tell.
- **Bugs.** None new. The arena hint now says "Backspace reset" on this branch.
- **Clean room.** OK. The stovepipe hat, the bellows pack and the flamer are our own.

## Nits
1. **Pair-level text (must fix before merge).** `content/archetypes/ashwick.json`:
   - line 8, the card's `x`: "Ultimate (X, level 6) ... X again lands."
   - line 26, the X desc: "Press X again to land early."
   Replace the letters with wording the kit card fills in (for example "press the ultimate again") or with `Settings.key_cap("hunter_ult")`. This follows the owner's keybind rule.
2. The Flashover fist pump could take a bigger `lift`, about 0.2, as round 1 asked.
