# Review: Moosh Moosh (id `tender`), branch origin/ext/kitfix-moosh-tamsin @ f793887

**Verdict: REWORK** (animation, VFX and screenshots; the mechanics mostly pass)

From the code and the combo checks, the mechanics follow the sheet:
- Embers fly to max range past the cursor.
- An Empowered ember comes after a 1 s pause.
- Burrseed is hold-to-aim with a dotted lane, fires on release, travels at 30 m/s, shows a disc at once and roots at 0.7 s.
- Hearthlight is cast on her and then thrown to the cursor at 45 m/s.
- Relay Step goes the way you move, and dashing through an ally refunds.

What the owner reviews, though, mostly shows nothing happening:
- Several ability frames contain no ability visual at all (the LMB, the Empowered shot, the RMB lane, the dash).
- Most animation strips are 4-5 near-identical frames, holding the crook straight out.
- The visuals that do show are white and generic: a flat white first-aid plus decal, white rings and glowing capsule after-images.

That fails the 13:46 owner rule ("a pose change is not enough").

Reviewer's own captures: `reviewer_shots/mm_rmb_disc.png` (the Burrseed disc and burst) and `reviewer_shots/mm_rmb_aim_strip.png` (the aim pose).

Ratings: 1 mechanic, 2 animation, 3 telegraph/reticle, 4 VFX distinctness, 5 bugs/oddities, 6 clean room. Scores are 1-5, with ok or fix.

| Ability | 1 Mech | 2 Anim | 3 Tele | 4 VFX | 5 Bugs | 6 Clean | Note |
|---|---|---|---|---|---|---|---|
| Passive Bearer (carry) / Kindle | 4 ok | 2 fix | n/a | 2 fix | 3 fix | 5 ok | The carry works (`tender_carry.png`). In `tender_carry_strip.png` the ally hides the pickup heave, and a "Dummy" hover tooltip is captured in frame 3. The Kindle foot glow and the `mm_kindled` crook spin aren't shown anywhere. |
| LMB Lantern Crook | 4 fix | 2 fix | 3 ok | 1 fix | 3 fix | 5 ok | Strip frame 1 has a nice cocked crook and a white swirl ring (matches the reference's `0074`), then frames 2-5 are the same pose: no overshoot or settle. `tender_lmb.png` shows no ember in flight. Range is 9 m against the reference's 7-8 bh (about 13-14 m by the brief's 1.8 m/bh). |
| LMB Empowered | 4 ok | 1 fix | n/a | 1 fix | 3 fix | 5 ok | `tender_emp_strip.png` can't be told apart from the normal shot: no tiptoe, and the free arm isn't thrown back. `tender_emp.png` shows nothing. |
| RMB Burrseed | 4 fix | 1 fix | 2 fix | 3 fix | 3 fix | 5 ok | The aim pose ("side-on, seed cupped by the ear") never shows: the crook stays straight out in every frame (`tender_rmb_strip.png`, `reviewer_shots/mm_rmb_aim_strip.png`). The dotted lane appears in no shot. The disc and the burr burst are a nice thorny shape but nearly white, pale lilac to white, where the reference has a saturated purple-blue disc, a light column and a root beam (`reviewer_shots/mm_rmb_disc.png`). Range is 11 m against the reference's 8-9 bh (about 15 m). |
| E Hearthlight | 5 ok | 2 fix | 3 ok | 1 fix | 3 fix | 5 ok | The cast has white light columns. The thrown state is a flat white disc with a big white "+" painted on the ground (`tender_e.png`, `tender_payoff.png`): a generic first-aid decal, where the reference reads as a bright cyan disc with a white rim. The `mm_hearth` "lantern hand thrust high" isn't readable (`tender_e_strip.png`). |
| E flare (payoff) | 4 ok | 2 fix | n/a | 2 fix | 3 ok | 5 ok | `tender_payoff_strip.png` has a light column, but "both arms flung up" is not visible. |
| Shift Relay Step | 5 ok | 1 fix | n/a | 1 fix | 2 fix | 5 ok | `tender_dash_strip.png`: the ally blocks her, frames 1-2 and 3-4 are duplicates, and no hop or stretch is visible. The after-image is a glowing yellow capsule, a generic "pill" shared with Tamsin (`CareLook "aft"`). |
| Air dash | 4 ok | 1 fix | n/a | 1 fix | 2 fix | 5 ok | `tender_air_strip.png`: duplicate frames, the same pill after-images, no roll visible. |

## FIX list (ranked by impact)

1. **Make every move readable: rebuild the KMOVES amplitudes and stop the weapon hold overriding them.**
   - Evidence: `tender_lmb_strip`, `tender_emp_strip`, `tender_rmb_strip`, `tender_e_strip`, `tender_payoff_strip`. The crook is held straight out in nearly every frame.
   - The `wa`/`wo` weapon-pivot keys in `kmoves_care.gd` seem to be overridden by the signature-weapon aim hold, or are too small.
   - Change: for `mm_shot`, `mm_shot_emp`, `mm_seed_aim`, `mm_seed`, `mm_hearth`, `mm_toss` and `mm_flare`, let the move own the weapon arm for its duration, then double the key deltas:
     - The seed aim: crook tucked under the arm, off hand raised beside the ear, body twisted 70°.
     - Empowered: `lift` 0.25, the free arm thrown back, a crook flourish of 180°.
     - Hearthlight: crouch `sq` 0.4, then the lantern hand straight overhead.
   - Add secondary motion on the backpack lantern (swing) and the ribbons.
   - Where: `scripts/match/kmoves_care.gd`, `hunter_anim.gd` (`km_sample` weapon channel priority).
2. **The Hearthlight look is a generic white first-aid sign.**
   - Evidence: `tender_e.png`.
   - Change: drop the painted white "+". Make the thrown state a filled warm-amber (hero `#ffd27a`) to teal-cyan disc with a bright rim and drifting lantern motes, brighter than the carried ring. Use a small floating lantern glyph at the centre rather than a floor plus.
   - Where: `care_look.gd` (hearth disc and thrown look), `shaders/care_disc.gdshader`.
3. **The Burrseed area and root are almost white.**
   - Evidence: `reviewer_shots/mm_rmb_disc.png`.
   - Change: make the disc saturated violet (`7a4aff` body, a `c9a0ff` rim) and keep the thorn ring. Add the light column falling over the target during the 0.7 s and a violet root beam on the burst, as the doc says (`_burst`, `care_look.gd`). The `care_disc` shader is probably additive: use a mix pass so it holds on bright grass.
4. **Retake the screenshots so every ability has its tell, key frame and impact.**
   - The current full frames are taken after the move ends: `care_demo.gd` takes the full shot at `TIMES[-1]`, so `tender_lmb.png`, `tender_emp.png`, `tender_rmb.png` and `tender_dash.png` show nothing.
   - Needed:
     - the ember mid-flight past the cursor
     - the dotted lane while RMB is held
     - the disc filling, then the root
     - Hearthlight on her, then thrown
     - the dash mid-hop
   - Fix the strip capture: frames at 0.30 and 0.33 are duplicates. Space the TIMES at least 0.06 s apart, or step the physics a fixed amount per capture.
   - Hide the hover tooltip during captures.
   - Put the ally behind her, not between her and the camera.
   - Where: `scripts/match/care_demo.gd`.
5. **Dash after-images are generic pills.**
   - Evidence: `tender_dash_strip.png`, `tender_air_strip.png`.
   - Change: use her silhouette (a copy of the body mesh at a low alpha, tinted lantern-amber) or a trail of lantern sparks and ribbon streaks. Give her a clearly stretched tuck-hop and a landing squash (`mm_dash`: `sq` -0.45 then +0.45). Each hero needs its own dash look; Tamsin currently shares this pill.
   - Where: `care_look.gd` `"aft"`, `kmoves_care.gd` `mm_dash`, `mm_dash_air`.
6. **Ranges are short against the reference.**
   - The ember is 9 m; the reference is 7-8 bh, about 13 m. The Burrseed is 11 m; the reference is 8-9 bh, about 15 m.
   - Change `lantern_crook.json` `range` to about 12 and `tender.json` `rmb.seed.range` to about 14, or record the reason in Assumptions.
7. **Ember look.** No frame shows the blue-white comet. Make sure the ember comet (in `care_look.gd`) is at least about 0.35 m with a 1.5 m tail, and has a violet-star impact flash. Tint damage numbers warm at Kindle 3+ (sheet gap 9, optional, but cheap in `on_deal`).
