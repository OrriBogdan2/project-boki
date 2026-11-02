# Review: Bjorn (id `bulwark`), branch origin/ext/kitfix-pin-bjorn @ 7aad027

**Verdict: REWORK (visual layer).** The mechanics are close to the source and the owner's notes. The throw lands at the cursor, the hammer stays planted until recalled, holding LMB spins the hammer, the release slams and carries him forward, the 360 Smash is a fixed dash with one spin hit, and E lands on the hammer or on himself. But the three things the owner named for this hero don't read at gameplay zoom:
- **The spin.** The hammer spinning is not visible in any shot.
- **The shield.** The aegis is a near-invisible outline.
- **The slam.** It has a small smear instead of a flaming crescent, and the body falls flat.

Several "after" shots also fail to show what they claim.

## Ratings

1 = mechanic fidelity, 2 = animation, 3 = telegraph/reticle, 4 = VFX distinctness, 5 = bugs/oddities, 6 = clean room.

| Ability | 1 | 2 | 3 | 4 | 5 | 6 | Note |
|---|---|---|---|---|---|---|---|
| Passive (Guard / Crushed) | ok | fix | ok | fix | ok | ok | Wall stun and heal are in code. No shot of CRUSHED, a STUNNED label or stars on a wall knock, so there's no evidence of the payoff. |
| LMB tap: throw | ok | fix | ok | fix | fix | ok | `AimMode.CURSOR` with a 5 m minimum. `bul_throw` frames 1-3 of the strip are identical, so the cock-back doesn't read. In `bjorn_planted` the hammer lies flat and tiny, and the gold beacon leans about 30° off vertical. |
| LMB tap again: recall | ok | ok | ok | ok | ok | ok | The hand-out pose reads. The catch flash is small but present. |
| LMB hold: spin (owner note) | ok | **fix** | fix | fix | ok | ok | `bjorn_spin`, `bjorn_glint`: at gameplay zoom the hammer spin can't be seen, and the body barely changes. The charge disc round his feet is pale blue, not Bjorn gold. The glint and flare are small white dots. |
| LMB release: Crushing Blow | ok | **fix** | n/a | **fix** | **fix** | ok | `bjorn_slam`: the "crescent" is a small yellow smear. `bjorn_slam_hit` and `after_gap2_slam_numbers`: Bjorn is lying flat on the ground, and no damage number or knocked dummy is visible. |
| RMB: aegis | ok | ok | ok | **fix** | fix | ok | `bjorn_aegis`, `bjorn_aegis_block`: only a faint pale outline arc. It doesn't read as a gold slab, let alone as unique to him. No block sparks are visible. |
| RMB: break | ok | ok | n/a | fix | fix | ok | `bjorn_aegis_break` shows no shard burst and no SHIELD BROKEN word. |
| RMB tap: Bash | ok (extension) | ok | fix | fix | ok | ok | `bjorn_bash` shows a 12 but no cone or flash. |
| Shift: 360 Smash | ok | fix | n/a | fix | fix | ok | `bjorn_smash_dash`: the body is tipped flat during the dash. `bjorn_smash_spin`: a thin yellow ring, not a red-orange swirl. Dash speed 15 m/s against the source's ~27 m/s (acceptable after sync62's slower heavy dashes). |
| E: Mending Ground | ok | ok | ok | ok | ok | ok | Column from the sky, ticked circle, ring burst: readable and green. The cooldown is 16 s; the source ratio E : Shift is ~1.1, ours 1.8. |
| Base long dash (`bul_lumber`) | ok | ok | n/a | ok | ok | ok | A shoulder shove, heavy. |
| Clean room | | | | | | ok | The hammer, aegis sigil and green-cloak design are our own. |

## FIX list (ranked by impact)

1. **Make the hammer spin visible while LMB is held** (owner note 2).
   - Evidence: `bjorn_spin.png` and `bjorn_glint.png` show no visible hammer rotation. In `anim/anim_bul_smash_wind.png` the hammer is hidden behind the shield arm.
   - Change: the spin must swing the whole hammer round him, not turn the "Hammer" pivot about its own grip axis.
     - Rotate the pivot in the horizontal plane round the hand, sweeping the head in a 1-1.2 m circle at about 2.5 turns/s, rising to about 4.
     - Add a gold-orange motion-trail ribbon on the head.
     - Raise the hammer arm out to the side in `bul_smash_wind` (`fl`/`gp`).
   - Where: `BjornFx.hold()` / `_process` spin code, and `KMovesPinBjorn.MOVES["bul_smash_wind"]`.
2. **Replace the aegis look with a solid, readable slab unique to Bjorn.**
   - Evidence: `bjorn_aegis.png` and `bjorn_aegis_block.png` show only a hairline arc.
   - Change, in `KitShaders` "aegis" and `BjornFx.aegis_show`:
     - Raise the base alpha to about 0.45-0.55 with a pale-gold fill.
     - Add a bright 2-3 px rim and the hammer sigil on the face (emissive).
     - Add a horizontal rib pattern, and a block flash of the whole slab (not just sparks).
   - Make it about 1.0 m tall above the chest, so it reads from the top-down camera.
   - Also check that `aegis_block()` sparks spawn on the slab face (none visible).
3. **Slam crescent at source scale and colour.**
   - Evidence: `bjorn_slam.png` shows a small smear.
   - Change, in `BjornFx.slam()` and the "crescent" shader:
     - Make it a 180° flaming band about 2.7 m in radius (source 1.5 h).
     - Use a yellow-white core with orange-to-red edges.
     - Hold it for 2-3 frames (0.1 s) at full alpha before fading. `cres_t` 0.26 fades too early to catch.
   - Add a white dust puff on hit targets and a debris trail. `_impact_trail` exists, but nothing shows in `bjorn_slam_hit`.
4. **The body tips flat in the slam and the dash.**
   - Evidence: `bjorn_slam_hit.png`, `after_gap2_slam_numbers.png`, `bjorn_smash_dash.png`, and `anim_bul_smash.png` frames 3-5 (horizontal body).
   - Change:
     - Cap the forward pitch at about 0.5 rad in `bul_smash` (keys 0.08 and 0.16: `p` -0.35 with `sq` 0.45 plus the carry dash lean is compounding), and in `bul_whirl` key 0.
     - Make the hammer arm do the sweeping (`gp`, `y`) instead of the whole body.
   - Check `HunterAnim` dash lean (`dash_kind` "charge" pitch -0.35) stacking on top of the move's `p`.
5. **The beacon is tilted and the planted hammer reads as lying flat.**
   - Evidence: `bjorn_planted.png` and `after_gap1_throw_cursor.png`: the beam leans about 30° to the upper right, and the hammer lies on the grass.
   - Change: in `BjornFx.hammer_plant()`, set `beacon.global_rotation = Vector3.ZERO` and use the pillar mesh upright. Stand the hammer head-down at about 20° from vertical (rotation x ≈ -0.35, not -2.3). Scale it about 1.5x so it reads at zoom.
6. **Charge-ring colour and full flare.**
   - Evidence: `bjorn_flare.png`: the ring at his feet is pale blue, and the full flare is a small white puff.
   - Change: tint the hold ring Bjorn gold (find the source of the blue disc: `h.mel_hold` generic hold ring, or `AimKit.charge` col). Make `fx.full_flare()` a large 4-point gold star at the hammer head (about 1 m), for 0.15 s, plus a cursor flare.
7. **360 Smash ring colour and spin.**
   - Evidence: `bjorn_smash_spin.png` shows a thin pale-gold ring.
   - Change: make the "swirl" band red to orange to gold with a spiral sweep, and widen its alpha. Make `bul_whirl` visibly turn once with the hammer held out at arm's length (the `fy` 0 → 6.28 over 0.16 s is too fast to catch: stretch it to 0.25 s).
8. **Aegis break and Bash feedback.**
   - Evidence: `bjorn_aegis_break.png` and `bjorn_bash.png` show nothing.
   - Change: confirm `BjornFx.aegis_break` shards and the SHIELD BROKEN word fire in the shot tool. Give the Bash a gold cone flash of its own, not `m.fx.cone` in `rmb.col` #9ad8ff blue: Bjorn's palette is gold, and the blue is generic.
9. **Throw anticipation.**
   - Evidence: `anim_bul_throw.png`: frames 1-3 are the same, then the hammer is gone.
   - Change: make the 0.1 s cock-back clearly visible: `y` 0.75 → 1.1, `gp` 1.2, and a slight back-lean `p` +0.3. Add an overshoot key after the release.
10. **Throw minimum versus "anywhere in range" (owner).**
    - The code clamps to at least 5 m (`throw_min` 5, from a source patch note). The owner said "lands where the cursor is (anywhere in range)", and the doc's table says 1.5 m while Assumptions says 5 m.
    - Pick one and make the doc consistent. Recommend 2.5 m so close cursor clicks land near the cursor.
11. **E cooldown ratio.** 16 s against Shift 9 s. The source is 10 : 9.2. Move it toward about 11 s, or note it as a deliberate deviation in the doc.
12. **Screenshot evidence.**
    - Retake `after_gap2_slam_numbers` with the damage numbers visible and the cursor shown in `after_gap1_throw_cursor`.
    - Add a CRUSHED-into-pillar shot for the passive.
