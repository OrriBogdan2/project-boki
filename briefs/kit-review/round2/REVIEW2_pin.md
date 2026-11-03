# Re-review (round 2): Pin (`archer`), origin/ext/kitfix-pin-bjorn @ 2b3476d6

**Verdict: PASS (minor nits).** Every round-1 item is done or close to done. The owner's draw readout is the same behaviour as the source in our own look: a white feathered chevron line, a gold six-petal fletch flash on a perfect release, and the cursor ring. Starpiercer matches its reference section in Pin's teal.

## Round-1 FIX items
| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Gold perfect-release flash | Done. A large gold six-petal "fletch" burst at the bow hand, with no white core. It is our own motif, not a four-point star (owner 22:35). | v2/polish/pin_perfect_close.png, pin_perfect.png |
| 2 | Remove the permanent white orb at the bow hand | Done. The bow glint is tinted per stage and appears only when a stage is ready. | v2/polish/anim_arc_draw_close.png, pin_draw_super.png |
| 3 | Visible draw wind-up | Done. She turns side-on, the bow arm extends and the string hand comes back across 6 frames. | v2/polish/anim_arc_draw_close.png / _game.png |
| 4 | Supercharged look and body flash | Done. A wide white-teal bolt with a long trail, a teal X-star on hit, and `h.flash_t` at stage 2 (pin_draw.gd:131). | v2/polish/pin_super_flight.png, pin_super_hit_close.png, pin_super_ready_close.png |
| 5 | The roll clips into the ground | Done. A full forward flip about the body centre that ends in the crouched walk. | v2/polish/anim_pin_roll_close.png |
| 6 | Heavy arrow and impact read white | Done. The heavy arrow is scaled 2.25 with gold and violet fins (pin_fx.gd LOOK), and the impact is red-gold. | v2/polish/pin_heavy_flight_close.png, pin_heavy_hit_close.png |
| 7 | Hail Wall cast pose | Done. `arc_hail` uses `gp` 1.6 and `fl` y 0.8. | kmoves_pin_bjorn.gd:224; v2/polish/anim_arc_hail_close.png |
| 8 | Snare and tap near-static | Done. The amplitudes are larger and there is an overshoot. | v2/polish/anim_arc_snare_*.png, anim_arc_tap_*.png |
| 9 | Screenshot gaps (spent arrow, quick draw) | Done. | v2/polish/pin_spent_arrow.png, pin_quick_draw.png |

## New checks
- **Ultimate (Starpiercer).**
  - It matches the reference: a tap self-buff, then the next 3 shots fire with no draw as piercing beams at 18 m (1.5× range), with a 6 s window, armour shred, and an execute (12%) on the 3rd shot.
  - The telegraph is a teal aura and a lane line from her, and the cast strip shows the nock and loose clearly.
  - The colour is teal rather than the source's magenta, which is correct for the clean room.
  - Evidence: v2/polish/ult_pin_telegraph.png, ult_pin_impact.png, ult_pin_final_close.png, v2/ult/strip_pin_ult_*.png.
- **Body and dash.**
  - Body: size 1.15 (about 0.98 of a medium) and hit_r 0.37, as the sheet asks.
  - Roll: 3.0 m in 0.16 s, `walk_k` 1.1, through `ArchKit.dash_dir()` and `travel()`, so the ×0.85 / ×1.15 dash feel applies.
- **Readability at zoom.** Good. The draw, the perfect flash, the beams and the hail all read at gameplay zoom.
- **Effects.** They are in her green, teal and gold, with no white defaults left. The draw line itself is white-cream, which is the source's information in our own chevron texture.
- **Bugs.** No tipping. The "BOND READY" word appears over Pin on an ult hit (ult_pin_impact.png). This is main's bond toast, not this kit.
- **Clean room.** OK. The fletch motif, the chevron line and teal beams are our own.

## Nits (non-blocking)
- **Pair-level text (must fix before merge, one line).** In `scripts/ui/kit_card.gd:309`, the X tile's "Bond" line says "...ready for the Merge on R." Merge is now on T, and key letters must not be hard-coded. Use `Settings.key_cap("ultimate")`.
- **Arena hint.** `scripts/match/arena.gd:16` and `:387` still say "X reset", while the reset is Backspace. That text comes from main, and linwick-dredge already fixed it, so it will resolve on merge. Mention it to main.
