# Re-review (round 2): Moosh Moosh (`tender`), origin/ext/kitfix-moosh-tamsin @ 4aad615e

**Verdict: PASS (minor nits).** The round-1 REWORK and the owner's changes are in:
- She is small (0.74, hit_r 0.34, plate 2.05).
- She has no weapon and casts from alternating palms.
- The moves drive the arms.
- The Hearthlight is a coloured disc, not a white "+".
- The Burrseed is saturated violet with a thorn ring.
- The air dash is a head-first glide into a tucked float.

Hearth Call (X) works as a tether with a reach ring and a pull-in of a downed ally.

## Round-1 FIX items
| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Moves readable; the weapon hold overrides them | Done. The prop is gone, palm casts alternate hands, and her pose changes frame to frame. | v2/polish/tender_lmb_strip_close.png, tender_emp_strip_close.png |
| 2 | Hearthlight as a white "+" | Done. A cyan-to-amber disc with a lantern glyph. | v2/polish/tender_e_thrown_game.png |
| 3 | Burrseed almost white | Done. A violet disc with a thorn rim, a column and ROOTED. | v2/polish/tender_rmb_disc_game.png, tender_rmb_root_game.png |
| 4 | Capture timing, duplicate frames, tooltip, ally placement | Done. The moments are captured at the real frame, with distinct frames and no tooltip. | v2/polish/*_strip_*.png |
| 5 | Generic pill after-images | Done. Lantern-amber sparks and streaks, and a stretched tuck. | v2/polish/tender_air_strip_close.png, tender_dash_strip_close.png |
| 6 | Short ranges | Done. The seed is at 14 m; the ember range is recorded. | content/archetypes/tender.json:88 |
| 7 | Ember look | **Partly done.** At gameplay zoom the ember in flight is a thin pale line, and only the impact flash on the dummy reads. | v2/polish/tender_lmb_fly_game.png |

## New checks
- **Ultimate (Hearth Call).**
  - It matches the reference: a tap on the teammate under the cursor (12.6 m, about 7 bh), then a 5 s heal tether while she walks, shown with a gold reach ring.
  - A downed teammate is pulled to her side and stood up at the end, and it breaks if she is stunned or the ally leaves the ring.
  - The ready state draws an aim line to the ally and a green ring.
  - Evidence: v2/polish/tender_ultaim_game.png, tender_ult_strip_game.png, tender_ultkey_game.png, tender_ult_end_game.png.
- **Body and dash.**
  - Body: size 0.74, hit_r 0.34, plate 2.05, and the pack frame above her head is dropped.
  - Ground dash: 4.2 m in 0.16 s with a hop.
  - The air dash is a glide. The owner sets its length.
  - Both go through `travel()`, so the dash feel applies.
  - The walk strip shows a low scurry (v2/polish/tender_walk_strip_close.png).
- **Readability.** Good, except the ember in flight.
- **Effects.** In her amber, cyan, violet and green.
- **Bugs.** None new found.
- **Clean room.** OK. Her silhouette, a fox tail with a capelet, is not the source's look, and the crescent motif is avoided.

## Nits
1. Make the ember in flight fatter and warmer: at least a 0.35 m head and a 1.5 m amber tail on the mix pass, so it reads before it lands.
2. The ult tether is a thin pale line. Tint it amber or green and widen it a little.
3. **Pair-level text (must fix).** In `scripts/ui/kit_card.gd:308`, "ready for the Merge on R." Merge is on T; use `Settings.key_cap("ultimate")`. It is the same string as on pin-bjorn.
