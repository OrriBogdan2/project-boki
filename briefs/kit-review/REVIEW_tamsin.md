# Review: Tamsin (id `rimewright`), branch origin/ext/kitfix-moosh-tamsin @ f793887

**Verdict: REWORK** (animation and readability; the mechanics and the ice wall pass)

The mechanics match the sheet and the owner:
- A steady dart stream with no pause, darts that come out slowly and home.
- Darts become 1.6x straight beams while skating.
- 8 darts Shatter.
- The spear is hold-to-aim, lands at the cursor and detonates at 1.8 s.
- The Skate is a hold in the movement direction and carries on over ledges.
- The wall erupts narrow, widens, slides to the cursor and can be frozen.
- No healing is added.

The Rink Wall's leaning ice pillars on a frosted footing are distinct and her own, which is good (`rimewright_e.png`).

The rest fails the owner's animation bar:
- The spear has no spear and no raised pose.
- The wall's crouch-and-throw doesn't read.
- The Shatter payoff shows nothing.
- The skate stride isn't visible.
- The air dash is the same generic glowing pill as Moosh Moosh's.

The darts read as small white flecks with almost straight paths, so the owner's "ice shards that home" is only half visible.

Reviewer's own capture: `reviewer_shots/tm_lmb_fly.png` (the darts in flight at gameplay zoom).

Ratings: 1 mechanic, 2 animation, 3 telegraph/reticle, 4 VFX distinctness, 5 bugs/oddities, 6 clean room. Scores are 1-5, with ok or fix.

| Ability | 1 Mech | 2 Anim | 3 Tele | 4 VFX | 5 Bugs | 6 Clean | Note |
|---|---|---|---|---|---|---|---|
| Passive Hoarfrost / Shatter | 5 ok | 1 fix | n/a | 1 fix | 3 fix | 5 ok | The payoff demo is a knock-shatter, and `rimewright_payoff.png` / `_strip.png` show no spike starburst and no visible pose (`tm_shatter`). The growing frost glow on the target appears in no frame. |
| LMB Ice Dart | 5 ok | 2 fix | 4 ok | 2 fix | 4 ok | 5 ok | The stream fires and the darts are crystal-shaped. At gameplay zoom they are about 6 px white flecks, and the 18° bow reads as two straight lines (`reviewer_shots/tm_lmb_fly.png`). The reference shows clearly bowed, blue-white streaks. The fan flick (`tm_dart_r/l`) is barely visible in `rimewright_lmb_strip.png`. |
| LMB while skating (beams) | 4 ok | 2 fix | n/a | 2 fix | 3 fix | 5 ok | `rimewright_skatefire.png` and its strip show no thick beam and no "both hands driven out" pose. |
| RMB Ice Spear | 5 ok | 1 fix | 3 fix | 3 ok | 3 fix | 5 ok | The ice-shell encase on the dummy is good (`rimewright_rmb.png`). `tm_spear_aim` ("spear raised high behind the head") and `tm_spear` never show: she holds the fan at her chest in all 6 frames, and no spear prop exists. The landing ring while held and the star-headed spear in flight appear in no shot. |
| Shift Skate | 5 ok | 2 fix | n/a | 2 fix | 2 fix | 5 ok | `rimewright_dash_strip.png`: a push-off tilt in f1-2, then upright standing. The low, leaning, alternating stride and the hockey stop don't read, and no ice-chip trail is visible. The dummy blocks the view. |
| Air dash | 4 ok | 1 fix | n/a | 1 fix | 2 fix | 5 ok | `rimewright_air_strip.png`: duplicate frames, no side flip visible, and white pill after-images that are the same as Moosh Moosh's. |
| E Rink Wall | 5 ok | 2 fix | 3 fix | 5 ok | 4 ok | 5 ok | The wall look is unique, cold and readable. `tm_wall` (crouch over the feet, hands thrown up and out) is barely visible (`rimewright_e_strip.png`). The 0.2 s sparkle and path tell appear in the strip (a pale lane), but the narrow erupt 1 bh ahead isn't shown. |

## FIX list (ranked by impact)

1. **Ice Spear needs a spear and the throw.**
   - Evidence: `rimewright_rmb_strip.png`.
   - Change:
     - Spawn a held ice-spear prop in the off hand while `spear_aim`, raised behind the head (a long crystal from `care_ice.gdshader`). It leaves the hand on release.
     - Rebuild `tm_spear_aim` and `tm_spear` with big deltas: lean back `p` 0.35, arm up `fl.y` 1.0, then a whip through to `p` -0.5 and a long lunge.
     - Retake: the landing ring at the cursor while held, the star-headed spear with its long white trail in flight, the zone with the spinning crystal, the detonation.
   - Where: `kmoves_care.gd`, `rimewright_kit.gd` (`rmb_hold_tick`, `fire_rmb`), `care_look.gd`.
2. **The Shatter payoff must be seen.**
   - Evidence: `rimewright_payoff*.png`.
   - Change:
     - Make the spike starburst large (about 2.7 m, the reference's 1.5 h) and opaque ice-cyan crystals, not an additive flash.
     - Add a 0.15 s icy shell on the target before it bursts (the reference's `0068`).
     - Make `tm_shatter` a big fan snap-shut with a fist clench and a 0.2 lean.
     - Demo the 8-dart Shatter as well as the knock-shatter.
     - Show the frost glow on the target growing per stack (`care_look.gd` frost glow: scale and alpha by stack).
3. **Darts should read as bowed ice shards (owner note).**
   - Evidence: `reviewer_shots/tm_lmb_fly.png`.
   - Change, in `hoar_fan.json`:
     - Raise `bow_deg` from 18 to about 30-35, so the arcs read at gameplay zoom like the reference's `0028` / `0046`.
     - Raise `size` from 0.16 to about 0.26.
   - Tint the shard body ice-blue (`9af0ff`) with a darker teal edge on a mix pass, and keep a short white frost streak.
   - Where: `care_look.gd` dart look, `shaders/care_ice.gdshader`.
4. **Skate and air dash animation and trail.**
   - Evidence: `rimewright_dash_strip.png`, `rimewright_air_strip.png`.
   - Change:
     - Exaggerate `tm_skate`: a constant forward lean `p` -0.45, deep knee bend, legs pushing out ±0.6, arms swinging opposite, the scarf trailing.
     - Make the ice-chip trail a visible ribbon of crystal chips on the ground (the reference's `0195`).
     - Make `tm_skate_stop` a clear side-on stop with a spray of ice.
     - For the air dash, drop the shared pill (`CareLook "aft"`): use a real side flip (`tm_dash_air`, a full 360° roll) with teal frost streaks.
   - Retake from a side angle without the dummy in front.
5. **Skating beams.** Show the thick straight beam (`tm_beam`) clearly: about 0.3 m wide, a cyan core, 30 m/s. Make the pose read as both hands driven straight out with a stiff lean. Retake `rimewright_skatefire`, with the beams visible mid-flight.
6. **Rink Wall cast pose.** `tm_wall` needs a deep crouch over the feet (`sq` 0.45, `lift` -0.15), then both arms flung up and out at the erupt. Retake a frame of the narrow block erupting 1 bh ahead, and one mid-slide while it widens.
7. **Capture tooling** (shared with Moosh Moosh, `care_demo.gd`):
   - The full frames are taken after the move ends.
   - The strips duplicate frames when TIMES are under one frame apart.
   - The 6th strip frame switches to a different camera.
   - Take the telegraph, key-frame and impact stills at their real moments.
