# Review: Pin (id `archer`), branch origin/ext/kitfix-pin-bjorn @ 7aad027

**Verdict: PASS WITH FIXES.** The mechanics follow the footage well:
- Empowered lands at the cursor; Supercharged flies past it to 16 m.
- A perfect release speeds up the next draw, and overdraw halves the shot.
- The V reticle closes toward one line.
- Spirit Walk is built with the dark-blue inside tint.
- The Hail Wall is a 120° arc at the cursor distance.

The owner's two asks ("a visible draw wind-up" and "a clear flash at the perfect moment") are only partly met:
- **Perfect flash.** It is a small white puff, not the gold 4-point star.
- **Draw pose.** It barely changes.
- **White flashes.** A persistent white orb sits at the bow hand in every frame, which is exactly the "white flash" look the owner dislikes.

## Ratings

1 = mechanic fidelity, 2 = animation, 3 = telegraph/reticle, 4 = VFX distinctness, 5 = bugs/oddities, 6 = clean room.

| Ability | 1 | 2 | 3 | 4 | 5 | 6 | Note |
|---|---|---|---|---|---|---|---|
| Passive (Focus / Hawk Sense / run down) | ok | ok | n/a | ok | ok | ok | The ledge climb is rightly left out. |
| LMB tap | ok | fix | ok | ok | ok | ok | `anim_arc_tap`: the snap is subtle. |
| LMB draw (Empowered) | ok | **fix** | ok | fix | fix | ok | V reticle present (`after_gap2_draw_reticle`). `anim_arc_draw`: the pose barely changes over 6 frames. A white orb sits permanently at the bow hand. |
| LMB Supercharged | ok | fix | ok | **fix** | ok | ok | `pin_draw_super`: the thick white line runs past the cursor, good. `pin_super_flight`: a thin standard arrow, not a wide white-teal bolt. `pin_super_hit`: a plain white puff, no teal X-star. No full-body white flash caught. |
| LMB perfect | ok | fix | fix | **fix** | ok | ok | `pin_perfect`, `after_gap3_perfect`: a white flash orb and a faint ring. The gold 4-point star by the bow hand isn't readable. |
| LMB overdraw | ok | ok | ok | ok | ok | ok | `pin_overdraw`: the line dims. `arc_over` shake is a nice touch. |
| RMB tap: Snare | ok (extension) | fix | n/a | ok | ok | ok | `anim_arc_snare`: barely any motion. |
| RMB hold: Heavy Shot | ok | ok | ok | fix | ok | ok | Gold V and bar (`pin_heavy_hold`). `pin_heavy_flight`: a large white orb at the bow and a white arrow; the gold-with-violet-fins arrow isn't visible at zoom. `pin_heavy_hit`: white puff. |
| Shift: Spirit Walk | ok | fix | n/a | ok | fix | ok | `pin_spirit_inside`: the blue tint is good. `anim_pin_roll` frames 2-4: only the legs and bow show, and the body looks sunk under the ground. Check the roll pivot. |
| Base long dash (`pin_flick`) | ok | ok | n/a | ok | ok | ok | |
| E: Hail Wall | ok | fix | ok | ok | ok | ok | The arc tell (`pin_hail_tell`) and the rain (`pin_hail_rain`) read well. `anim_arc_hail`: the bow is not visibly raised high. A big white flash is on frame 1. |
| Clean room | | | | | | ok | The recurve bow, red cap and green cloak are our own. |

## FIX list (ranked by impact)

1. **The perfect-release flash must be the big gold star** (owner).
   - Evidence: `pin_perfect.png` and `after_gap3_perfect.png` show a white puff.
   - Change: in `PinFx.star()` as called from `pin_draw.gd` on a perfect release:
     - Size about 1.1 m (0.6 bh at our scale is about 1.1 m).
     - Colour #ffd25a with a soft gold ring, 0.12-0.15 s at full alpha.
     - Draw it in front of the white bow-hand orb, with no white core.
   - Add a 1-frame gold cursor star (`AimKit.perfect`) and a short "shing" pitch-up.
2. **Remove the permanent white orb at the bow hand.**
   - Evidence: every frame of `anim_arc_*`, `pin_draw_*` and `pin_heavy_*`.
   - Change: `PinFx.hold_bow_star()` should be a small green 4-point glint that only grows at stage-ready, not an always-on white sphere. Tint it green (Empowered), white-teal (Super) or gold (Heavy).
3. **A visible draw wind-up.**
   - Evidence: `anim_arc_draw.png` shows almost the same pose for 6 frames.
   - Change, in `KMovesPinBjorn["arc_draw"]`:
     - Pull the string hand clearly back past the chest (`fl` z 0.2 → 0.35).
     - Lean back (`p` 0.2), and turn side-on harder (`y` 0.8).
     - Add a bow-arm extension to full reach by the Empowered frame.
     - Add a slight tremble ramp toward Supercharged.
   - The source pose is side-on with the bow arm fully out.
4. **The Supercharged shot needs its own look.**
   - Evidence: `pin_super_flight.png` and `pin_super_hit.png`.
   - Change, in `PinFx._dress("super")` and the hit callback:
     - A wider (0.35 m) white-teal glowing bolt with a long trail.
     - On a hit, a teal X-shaped 4-point star burst about 1.5 m wide.
   - Add the 1-frame whole-body white flash when Supercharged comes up (`pin_draw.gd`, stage 2): it isn't caught in any shot.
5. **The roll clips into the ground.**
   - Evidence: `anim_pin_roll.png` frames 2-4.
   - Change: in `pin_roll`, add `lift` about 0.35 during the `fx` rotation so the body rolls about its centre, not about the feet.
6. **The Heavy Shot arrow and impact read white.**
   - Evidence: `pin_heavy_flight.png` and `pin_heavy_hit.png`.
   - Change: scale the gold arrow up 1.5x so the violet fins show. Make the impact red-white then dust, plus the white ring (source).
7. **Hail Wall cast pose.**
   - Evidence: `anim_arc_hail.png` shows no bow raised overhead.
   - Change: in `arc_hail`, `gp` 1.1 → 1.6 and `fl` y 0.5 → 0.8; replace the frame-1 white flash with green lobbed streaks.
8. **Snare and tap animations are near-static.**
   - Evidence: `anim_arc_snare`, `anim_arc_tap`.
   - Change: double the key amplitudes, and add an overshoot key.
9. **Screenshot gaps.** No shot shows the spent teal arrow at the cursor clearly at gameplay zoom (`pin_spent_arrow`), and none shows a perfect-speedup draw. Add both.
