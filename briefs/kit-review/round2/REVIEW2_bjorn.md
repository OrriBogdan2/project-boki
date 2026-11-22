# Re-review (round 2): Bjorn (`bulwark`), origin/ext/kitfix-pin-bjorn @ 2b3476d6

**Verdict: PASS (minor nits).** The round-1 REWORK is resolved:
- The slam has a real flaming crescent.
- The aegis is a solid pale-gold slab with ribs and a hammer sigil.
- The planted hammer stands up with a vertical gold beam.
- The body stays upright in the Smash.

Faultline (X) is a clear gridded lane that erupts cell by cell into basalt spikes. That is our own look, not the source's cyan glass slabs. The held spin is the weakest remaining beat.

## Round-1 FIX items
| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Visible held hammer spin with a gold trail and ring | **Partly done.** The hammer now sweeps round at arm's length (the strip shows distinct angles) inside a faint gold ring. The gold motion-trail ribbon is barely visible at gameplay zoom. | v2/polish/bjorn_spin.png, anim_bul_smash_wind_close.png |
| 2 | Solid aegis slab with a sigil | Done. A pale-gold curved slab with ribs and a gold hammer sigil. | v2/polish/bjorn_aegis_block_close.png |
| 3 | 180° flaming slam crescent | Done. A big orange-to-yellow crescent and an upright body. | v2/polish/bjorn_slam.png, bjorn_slam_close.png |
| 4 | The body tips flat in the slam and dash | Done for the Smash and the slam (bent, not toppled; commit e90ed6aa). See the ult nit below. | v2/polish/anim_bul_smash_game.png |
| 5 | Beacon tilted, hammer lying flat | Done. The beam is vertical, and the hammer stands head-down with a 0.25 rad lean at scale 1.9. It is still small at gameplay zoom. | v2/polish/bjorn_planted.png |
| 6 | Charge ring colour and full flare | Done. A gold ring and a gold flare. | v2/polish/bjorn_flare_close.png |
| 7 | 360 Smash ring and spin | Done. A red-gold swirl and a visible turn. | v2/polish/anim_bul_whirl_game.png, bjorn_smash_spin.png |
| 8 | Aegis break and Bash feedback | Done. | v2/polish/bjorn_aegis_break_close.png, bjorn_bash_close.png |
| 9 | Throw anticipation | Done. | v2/polish/anim_bul_throw_close.png |
| 10 | Throw minimum against the owner | Done. `throw_min` is 2.5, and the doc matches. | content/archetypes/bulwark.json |
| 11 | E cooldown ratio | Done. 11 s against 9 s, recorded in the doc. | docs/heroes/bulwark.md:26,46 |
| 12 | Screenshot evidence (numbers, cursor, CRUSHED) | Done. | v2/polish/after_gap*.png, bjorn_crushed.png |

## New checks
- **Ultimate (Faultline).**
  - It matches the reference: a 0.4 s planted wind-up and a fixed-length lane toward the cursor (4 cells × 4 m, 4.5 m wide) shown as an outlined, gridded amber telegraph.
  - The cells erupt near to far at 0.15 s each, there is a lift and stun, and a 10 s slowing scar remains.
  - Evidence: v2/polish/ult_bjorn_telegraph.png, ult_bjorn_impact.png, ult_bjorn_scar.png.
- **Body and dash.**
  - Body: `size` 0.975 × heavy (about 1.15 of a medium), `build` 1.18, plate 2.6.
  - Run lean: about 0.32 rad.
  - 360 Smash: 3.5 m at about 20 m/s, with the dash feel applied through `travel` and `dash_feel()`.
- **Readability.** Good, apart from the spin trail.
- **Effects.** In his gold, orange and red, with no white defaults.
- **Clean room.** OK. The basalt spikes, the amber grid and the hammer sigil are our own.

## Nits (non-blocking)
1. Make the spin's gold trail ribbon thicker and brighter so the whirl reads at gameplay zoom. Today the hammer's position does the work and the trail is faint.
2. In the Faultline slam (`bul_ult_slam` keys, kmoves_pin_bjorn.gd:975 and :990), `p` 0.75 and 0.6 with `lift` -0.22 fold him head-down. Cap it at about 0.5, matching the round-1 cap.
3. The planted hammer reads as a small stick at gameplay zoom. Consider a scale of about 2.3, or a gold rim.
4. **Pair-level text (must fix):** "Merge on R" in kit_card.gd:309. See REVIEW2_pin.md.
