# Re-review (round 2): Venator (`gunslinger`), origin/ext/kitfix-vireo-venator @ bdebfb1e

**Verdict: FIX (one item).** The round-1 list is done, and Cinderfall is a strong, readable ultimate. But the new ember after-image on Slipstep draws as an opaque, flat salmon-beige silhouette over his body in every slide frame. That is the "white/beige blob" the owner keeps flagging. I confirmed it with my own capture on the branch head.

## Round-1 FIX items
| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Slide pose tipped flat, rifle detached | Done. He stays upright and the rifle stays in hand. | v2/polish/venator_anim_dash.png; own capture: scratchpad/shots-ven/venator_anim_dash.png |
| 2 | Grenade held overhead, visible in flight | Done. A spiked prop in the hand and an ember smear in flight. | v2/polish/venator_anim_rmb_hold.png; scratchpad/shots-ven/venator_rmb_flight_close.png |
| 3 | Longneedle beam colour | Done (warm). A tan-ember band with a hot core and a gold star ring at the muzzle. | scratchpad/shots-ven/venator_e_fire_close.png |
| 4 | Fever pips occlude his face | Done. A small bar above the plate. | v2/ult/venator_ult_anim.png |
| 5 | Rifle firing animation | Done. | v2/polish/venator_anim_lmb.png |
| 6 | Payoff evidence (SKEWERED, Dazed, knock) | Done. | v2/polish/venator_skewer*.png, venator_lmb_dazed*.png, venator_knock*.png |
| 7 | Slide start feedback | Done, but it introduces the bug below. A bright ring, a dust disc and an ember after-image. | scratchpad/shots-ven/venator_dash.png |

## New checks
- **Ultimate (Cinderfall).**
  - It matches the reference: a tap at the cursor and a 1.6 s readable disc with a hot core and a glyph-like rim.
  - Next comes a falling-shell light column, then the impact (DEAD CENTRE, gold number) and a 3 s slowing burn zone. He stays free to move.
  - Evidence: v2/ult/venator_ult_aim.png, venator_ult_impact.png, venator_ult_zone*.png.
- **Body and dash.**
  - Body: size 1.0, plate 2.35.
  - Tap slide: 4.8 m over 0.45 s through `travel()`, so the dash feel applies on top. This matches the sheet's ~0.45 s / ~4.8 m skid.
- **Readability.** Good, except while sliding (below).
- **Effects.** In ember and brass, with the one exception below.
- **Clean room.** OK.

## FIX list
1. **Slipstep after-image blob.**
   - Where: `gunslinger_kit.gd` `_tick_echo` (every 0.05 s) and the start echo at about line 229, `fx().echo(h, EMBER, 0.6)`.
   - Problem: the echoes stack into a solid salmon silhouette drawn *over* the live model. In scratchpad/shots-ven/venator_anim_dash.png it hides his torso in all 5 frames.
   - Fix:
     - Draw the echo with alpha blend, at about 0.35 alpha fading to 0, in a deeper ember (`EMBER.lerp(DEEP, 0.5)`).
     - Use a depth or sort offset so it sits behind the live body.
     - Spawn echoes from the position at least about 0.3 m behind him, so they trail rather than overlap.
   - Retake `venator_anim_dash` and `venator_dash`.

Nit: the arena hint "X reset" (main's text).
