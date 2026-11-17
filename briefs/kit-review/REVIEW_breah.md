# Review: Breah (id `dolm`), branch origin/ext/kitfix-breah-ostra @ c26758e

**Verdict: PASS WITH FIXES**

The owner overrides are in.
- Rocks are climbable and stand-on-able: she stands on a Stone Row rock in `breah_row_hit.png`.
- A punch sends rocks flying: the middle rock is gone with ROCKFALL in `after_pair_dolm_pay.png`.
- LMB is a hold-to-punch with a chevron lane. The tap boulder stays, as in the source.
- The slam: the circle and the sweet spot show to everyone, she hops into the centre, jump-while-charging leaps, a punch-while-charging lunges, and it resets on a knock.
- The dash rock rides ahead and rolls on with a slow.

The main problems:
- Her spatial sizes are about 0.55-0.7x the reference. The doc mixes the brief's 1.8 m/bh scale with the sheet's metre guesses.
- Several animations barely move: throw, raise, sense, lunge, arrive.
- Her "molten" glows render as white blobs.

Ratings: 1 mechanic, 2 animation, 3 telegraph/reticle, 4 VFX distinctness, 5 bugs/oddities, 6 clean room. Scores are 1-5, with ok or fix.

| Ability | 1 Mech | 2 Anim | 3 Tele | 4 VFX | 5 Bugs | 6 Clean | Note |
|---|---|---|---|---|---|---|---|
| Passive Tremor Sense | 4 ok | 1 fix | 4 ok | 3 ok | 4 ok | 5 ok | The cone lines show (`breah_sense_tele.png`). `breah_sense` is 5 identical frames (`anim/br_sense.png`). There's no crouched sneak read. |
| LMB tap boulder | 4 ok | 2 fix | 4 ok | 2 fix | 4 ok | 5 ok | The red ground ring on impact is good (`breah_throw_key.png`). The boulder in flight shows only a white puff, with no molten rock or ember trail visible. `breah_throw` (the hurl) is barely visible (`anim/br_throw.png` f3-6 are identical). |
| LMB hold punch (owner: hold) | 5 ok | 4 ok | 4 ok | 3 fix | 4 ok | 5 ok | The lane, chevrons and wind-up show (`breah_punch_tele.png`), and the big lunge twist reads (`anim/br_punch.png` f3-4). The dummy is launched. There's no impact burst at the fist on the hit frame (`breah_punch_key.png`). The lane is 3.2 x 1.4 m against the reference's 2.5 x 1 bh (4.5 x 1.8 m). |
| Punch rocks flying (owner) | 5 ok | n/a | n/a | 3 fix | 4 ok | 5 ok | It works (`after_pair_dolm_pay.png`), but no frame shows the flaming boulders in flight or the stream along a row. |
| RMB Quakefall | 4 fix | 3 fix | 5 ok | 2 fix | 4 ok | 5 ok | The circle and the growing sweet spot are good and orange (`breah_slam_tele.png`, `breah_leap_key.png`). The impact is a flat white-yellow disc with white dashes (`breah_slam_hit.png`, `anim/br_slam.png` f5-6): no starburst, no rock shards, no lingering dark-red crater visible. The fists glow as white orbs, not molten orange. The radius is 2.3-3.0 m against the reference's about 2.5 bh (4.5 m). |
| RMB jump-leap / punch-lunge | 5 ok | 3 fix | 5 ok | 3 ok | 4 ok | 5 ok | The circle travels with her. `anim/br_lunge.png` shows very little forward body drive. |
| RMB air dive | 4 ok | 3 ok | 4 ok | 2 fix | 4 ok | 5 ok | Same white disc impact (`anim/br_dive.png`). |
| Shift Rubble Rush | 5 ok | 4 ok | n/a | 4 ok | 4 ok | 5 ok | The molten-cracked rock riding ahead is good (`anim/br_dash.png`, `breah_dash_key.png`). The roll-on and its burst aren't in frame (`breah_dash_hit.png` is cut off at the edge). |
| Air dash (`breah_exdash`) | 4 ok | 3 ok | n/a | 3 ok | 3 fix | 5 ok | A "Dummy" hover tooltip is captured in the strip (`anim/br_exdash.png` f3). |
| E Stone Row (verticality) | 5 ok | 1 fix | 2 fix | 3 fix | 3 fix | 5 ok | Climb and stand work (`breah_row_hit.png`). `breah_raise` is near static (`anim/br_raise.png`). `breah_row_tele.png` already shows the rocks up, so the 0.2 s red ground flash appears in no frame. The rocks read as stacked dark discs ("coins"), not jagged basalt spikes. The "molten base" glow renders as a pale yellow-white pool under every rock for its whole life (`after_pair_dolm_rocks.png`). It sits 2.2 m ahead with about a 2.9 m span, against the reference's 2 bh ahead (3.6 m) with a 3 bh span (5.4 m). |

## FIX list (ranked by impact)

1. **Spatial scale is about 0.6x the source (the brief says 1 bh ≈ 1.8 m).**
   - The doc's "Scaling" line admits to using the sheet's metre guesses for gameplay and bh only for visuals.
   - Change, in `content/archetypes/dolm.json`:
     - `rmb.slam.radius` [2.3, 3.0] → about [3.6, 4.5]
     - `core` [0.9, 1.8] (already bh-scaled, keep)
     - `reach` 1.3 → about 2.0
     - `e.dist` 2.2 → about 3.4, `gap` 1.45 → about 2.4 (a 3 bh span)
     - `lmb.punch.len` 3.2 → about 4.2, `width` 1.4 → about 1.8
   - Re-check the combo-check distances.
   - If gameplay balance argues for smaller, write it under Assumptions so the owner can decide.
2. **The slam impact is a generic white disc.**
   - Evidence: `breah_slam_hit.png`, `anim/br_slam.png` f5-6, `anim/br_dive.png`.
   - Change, in `breah_slam.gd` (impact) and `kit_looks.gd` (`scorch`):
     - A molten orange-yellow starburst with flying rock shards (pooled lumps with `rock_mat`) and a 4-5 bh dust ring.
     - Then the dark-red cracked crater with ember flecks for 1 s.
     - Replace the white dashes with radial crack lines.
   - Make the fist glow during the charge molten orange (`ff7a2a`, rising with charge), not white `Models.glow_mat`.
3. **Animations that barely move: `breah_raise`, `breah_sense`, `breah_throw`, `breah_lunge`.**
   - Evidence: `anim/br_raise.png`, `br_sense.png`, `br_throw.png`, `br_lunge.png`.
   - Change, in `scripts/match/kmoves_stone.gd`:
     - Raise: both gauntlets slammed down then heaved up (`p` 0.5 → -0.4, `lift` -0.2 → 0.15, a fist arc of more than 1 m).
     - Sense: a crouch `sq` 0.35 with a palm to the ground.
     - Throw: a side hurl with a 0.5 twist and a follow-through.
     - Lunge: `p` -0.6 with a body drive.
   - Use top-down-readable channels (twist `y`, `sq`, `lift`, arm reach), not pitch alone.
4. **Stone Row look and tell.**
   - Evidence: `breah_row_*.png`, `after_pair_dolm_rocks.png`.
   - Change:
     - Make the rock silhouettes jagged spikes or columns with tapered, broken tops: vary the radius per segment, add a lean, and stop stacking equal discs.
     - Make the base glow thin orange crack lines that fade after about 0.6 s, instead of a permanent pale pool.
     - Retake the 0.2 s red-orange ground flash before the rise.
   - Where: `hero_zones.gd` `rock_node()` (lines 82-90), `dolm_kit.gd` (the Stone Row tell).
5. **Boulder and launched rocks in flight.**
   - The tap boulder shows as a white puff.
   - Make sure the molten boulder skin (`kit_looks.gd` `_build` "boulder", halo `glow_mat` alpha 0.22) is visible at gameplay zoom: size about 0.5 m, opaque `rock_mat` heat 0.8, ember trail sparks every frame.
   - Add a screenshot of a punch sweeping a whole row (the "Rocksweeping" stream).
6. **Punch impact.** Add a fist-impact burst (dust ring plus orange sparks) at the lane end on the hit frame. Today `breah_punch_key.png` shows only the number.
7. **Capture hygiene.** Hide the hover tooltip in strips (`pair_demo.gd`). Keep the dash roll-on and its burst in frame. The HUD hero caption prints twice, overlapping (every Breah and Ostra screenshot). It shows on the "before" shots too, so it may be a main-side HUD bug: check `hud.gd` caption duplication.
