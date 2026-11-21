# Re-review (round 2): Tamsin (`rimewright`), origin/ext/kitfix-moosh-tamsin @ 4aad615e

**Verdict: FIX.** Most of the round-1 REWORK is done:
- Shatter is a big ice starburst.
- The darts are bowed cyan shards.
- Rimelock (X) is excellent.
- The owner's skate rules are built and asserted: hold Shift, fire throughout, steer, and get a refund for a short skate.

But the skate pose tips her about 60° forward, so she lies near-horizontal. The owner's favourite dash looks like a fall, and "bodies tipping" is a stated blocker. The Ice Spear also still reads mostly white.

## Round-1 FIX items
| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Ice Spear prop and throw | **Partly done.** A crystal spear is held above her head and thrown along the aim. It is near-white (pale crystal, white streak) rather than ice-blue, and at gameplay zoom it reads as a white flick. | v2/polish/rimewright_rmb_aim_close.png, rimewright_rmb_fly_game.png, rimewright_rmb_strip_close.png |
| 2 | Shatter visible | Done. A large opaque cyan spike burst and SHATTER. | v2/polish/rimewright_shatter_game.png, rimewright_payoff_strip_close.png |
| 3 | Darts as bowed ice shards | Done. Cyan bowed shards with a frost streak. | v2/polish/rimewright_lmb_fly_game.png |
| 4 | Skate and air-dash animation and trail | **Partly done.** There is an ice-chip trail, edge spray and its own frost after-images. But the skate pose tips over (see the FIX list). | v2/polish/rimewright_dash_strip_close.png, rimewright_skatefire_strip_close.png, rimewright_dash_game.png |
| 5 | Skating beams | Done. | v2/polish/rimewright_skatefire_game.png |
| 6 | Rink Wall cast pose | Done. | v2/polish/rimewright_e_strip_close.png, rimewright_e_slide_game.png |
| 7 | Capture tooling | Done. | v2/polish/* |

## New checks
- **Ultimate (Rimelock).**
  - It matches the reference: rooted and invulnerable in a frost shell, inside a 7.2 m slowing rink with a ragged edge and swirl cracks.
  - The crash comes at 3.5 s, or earlier on a late recast: a light pillar, STUNNED, and ice blocks on targets.
  - The shell shape is our own.
  - Evidence: v2/polish/rimewright_ultkey_game.png, rimewright_ult_crash_game.png.
- **Body and dash.**
  - Body: `size` 1.3 × light and `bulk` 0.78, which is tall and thin as the sheet asks.
  - Skate: 11.5 m/s for up to 1.6 s with a 0.2 s ramp, matching main. It steers at 3.6, refunds by shortness (min_t 0.2, refund 0.6) and fires the whole time, per the owner's notes.
- **Readability.** Good, except the skate pose and the spear.
- **Effects.** Ice cyan and teal, with the spear as the exception.
- **Clean room.** OK. The shell and outfit are our own.

## FIX list
1. **The skate pose tips her over.**
   - Where: `tm_skate` (kmoves_care.gd:364) sets `p` -0.45 for the whole move. HunterAnim's dash pose for a light hunter (`dash_kind` "phase") also lerps the pitch to -0.6 (hunter_anim.gd:846). The two stack to about -1.05 rad.
   - In rimewright_dash_strip_close.png and rimewright_skatefire_strip_close.png she is near-horizontal with her legs out behind.
   - Fix: give the skate its own `dash_kind` (for example "skate", with no pitch from HunterAnim), or cap the total pitch at about 0.5. Keep the lean in the move.
   - Retake the skate strip at gameplay zoom and close-up. Bjorn and Venator had the same stacking in round 1.
2. **Make the Ice Spear ice-blue.**
   - Tint the held and thrown crystal body `9af0ff` with a teal edge on the mix pass.
   - Keep white only for the tip glint and a short frost streak.
3. **Pair-level text (must fix).** "Merge on R" in kit_card.gd:308. See REVIEW2_mooshmoosh.md.
