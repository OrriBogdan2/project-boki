# Re-review (round 2): Vireo (`mage`), origin/ext/kitfix-vireo-venator @ bdebfb1e

**Verdict: PASS (minor nits).** The finger gun, the Storm Rod, Skycall's disc, the stack marker and the Kitefall ultimate all read at gameplay zoom, in teal, copper, gold and violet.

## Round-1 FIX items
| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Finger-gun firing reads | Done. The arm extends to the cursor, with a cyan fingertip crackle and a jagged bolt. Frame 1 of the strip still shows a white glow ball at the hand (see nit 1). | v2/polish/vireo_anim_lmb_r.png, vireo_lmb_fire.png, vireo_lmb_bolt_close.png |
| 2 | RELOADING state on Vireo | Done. The HUD reads COILCASTER 99/99 throughout, and nothing says RELOADING. | v2/polish/vireo_rmb_*.png, v2/ult/vireo_ult_*.png |
| 3 | Visible summoned Storm Rod | Done. A rod by the shoulder with a teal crackling tip, and a summon burst. | v2/polish/vireo_rmb_summon_close.png, vireo_anim_rmb_hold.png |
| 4 | Skycall area identity | Done. A dark disc with a crackling gold-copper rim, a chevron and veins. | v2/polish/vireo_e_count.png |
| 5 | Stack marker over the head | Done. A number with pips above the bar. | v2/polish/vireo_static_2_close.png, v2/ult/vireo_ult_impact.png |
| 6 | Skycall cast animation | Done. | v2/polish/vireo_anim_e.png |
| 7 | Orb look | Done. A teal-gold orb with arcs. | v2/polish/vireo_rmb_orb_close.png |
| 8 | Air dash and live strips | Done. | v2/polish/vireo_anim_dash_ex.png, vireo_anim_live.png |

## New checks
- **Ultimate (Kitefall).**
  - It matches the reference: a launch, a hover of about 1.7 s, then a cursor-placed landing inside a 14.4 m ring.
  - The ring has a dark interior and a crackling gold rim, and the reticle is a bracket ring at the cursor.
  - The landing is a sky pillar, a gold shock ring and +1 Static.
  - Evidence: v2/ult/vireo_ult_aim.png, vireo_ult_impact.png, vireo_ult_anim.png.
- **Body and dash.**
  - Body: `size` 1.12 (light → about 0.96 of a medium), `chest` 1.15 and hit_r 0.37. She runs upright with her arms out (v2/polish/vireo_anim_run.png).
  - Wirerun: a constant 32 m/s over 5–8.5 m, with dash_feel `mage` dist 1.0 and time 1.15, per main.
- **Readability.** Good.
- **Effects.** In her teal, copper, gold and violet. The landing pillar is cream-white with teal veins, which is acceptable as a light column.
- **Bugs.** None found.
- **Clean room.** OK.

## Nits (non-blocking)
1. The first frame of `vireo_anim_lmb_r.png` shows a soft white sphere at the hand (the charge glow). Tint it teal, or drop it.
2. The arena hint still says "X reset" (main's text), and the Kitefall shots show it under the HUD. See the pin-bjorn note; it resolves on main.
