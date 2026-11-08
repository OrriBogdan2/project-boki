# Review: Linwick (id `ashwick`), branch origin/ext/kitfix-linwick-dredge @ a5590a1

**Verdict: PASS WITH FIXES**

The mechanics are right. The hose lags on a sweep, the ram stops on the first foe, Cinder Shot is hold-to-aim and lands at the cursor, the cloak shows its ring before the blast and pulls, and there are two burn stages with pips. The look is where it falls short. Every Linwick effect is drawn additive in `shaders/ld_fx.gdshader` (`render_mode ... blend_add`). On the arena's bright yellow-green grass that turns the fire beige, the fireball white and the shield pale. Any dark colour (the smoke tail, the violet char edges, the soot fringe) adds nothing, so it disappears. Some key frames are also missing from the shots.

Ratings: 1 mechanic, 2 animation, 3 telegraph/reticle, 4 VFX distinctness, 5 bugs/oddities, 6 clean room. Scores are 1-5, with ok or fix.

| Ability | 1 Mech | 2 Anim | 3 Tele | 4 VFX | 5 Bugs | 6 Clean | Note |
|---|---|---|---|---|---|---|---|
| Passive Flashover (burn stages) | 5 ok | 1 fix | 4 ok | 4 ok | 3 fix | 5 ok | 1 pip, then 3 pips with a glow, reads well (`flashover_pips.png`). The `lw_stoke` payoff move never plays while the lance is held (`if not was_held`), and the lance is how Flashover happens. `anim/flashover.png` shows 5 identical frames. |
| LMB Torch Lance | 5 ok | 2 fix | 4 ok | 2 fix | 3 fix | 5 ok | The hose lag works (`lance_sweep_bend.png`). The stream is a pale translucent beige smear with no orange body, no white-hot core and no billow silhouette (`lance_stream.png`, `lance_burning.png`). The cyan pilot is a 3-4 px dot. `anim/lance.png` shows almost no pose change, and frames 4-6 show no fire at all. |
| RMB Cinder Shot | 5 ok | 3 ok | 5 ok | 2 fix | 4 ok | 5 ok | The lane and the cyan end ring at the cursor are good (`cinder_lane.png`). In flight the bolt is a white blown-out ball with a stub of orange (`cinder_release.png`), which is the "white flashing projectile" the owner complained about. The reference is a red-pink body, a yellow core, a blue-violet halo and a dark smoke tail. No ember shower or red flash is visible on impact (`cinder_impact*.png` show only the ABLAZE word). |
| Shift Soot Ram | 5 ok | 4 ok | n/a | 3 fix | 3 fix | 5 ok | The head-first lunge reads (`anim/ram.png` f2), and it stops on the dummy. No frame shows the flame-skull crescent wrapped round his front: `ram_skull.png` is actually the impact starburst. Only thin orange streaks trail behind. |
| Air dash (`lw_hop`) | 4 ok | 3 fix | n/a | 3 fix | 2 fix | 5 ok | The tuck reads weakly from top-down. The last frame of `anim/air_hop.png` is the camera inside a pink/red sphere next to "DUMMY" (Dredge's `anim/air_barge.png` shows the same). Either the hop carries him off the island or the camera clips into a dummy. Retake from a safe spot and check. |
| E Furnace Cloak | 5 ok | 2 fix | 3 fix | 3 fix | 3 fix | 5 ok | The pull and the shield work. `cloak_ring.png` is mislabelled: it shows the blast, so the 0.2 s thin-ring telegraph appears in no frame. The arms stay on the flamethrower: `as_cloak` sets `fr`/`fl`, but the two-handed weapon grip wins (`anim/cloak.png`), so "arms flung wide" never shows. The sunburst is a soft radial wash rather than the source's jagged spiky burst. The shield swirl is pale yellow on yellow grass (`cloak_shield.png`). |
| Card / rename | ok | | | | | | The card follows the one-line-per-slot format. The rename is done. |

## FIX list (ranked by impact)

1. **Fire looks wash out on bright ground (lance, cinder, shield, sunbursts).**
   - Evidence: `lance_stream.png`, `cinder_release.png`, `cloak_shield.png`, `cloak_ring.png`.
   - Cause: `shaders/ld_fx.gdshader` is `blend_add` for every mode, so the dark ramp colours (`fire_ramp` d, the comet `color2` smoke, the lava/scorch violet) add almost nothing, and bright values clip to white.
   - Change: split the material in two.
     - (a) A `blend_mix` body pass with premultiplied alpha for the flame puffs (mode 0), the comet smoke (mode 2), the sunburst (4) and the swirl (7). Raise the body alpha to about 0.8 and keep a darker orange-red outer band and a sooty rim.
     - (b) An additive core on top.
   - Also raise mode 0's body gain from 0.42 to about 0.8, and widen the far-end puffs to the 2.2 m the data asks for.
   - Where: `ld_fx.gdshader` (add a `mix_pass` variant), `LDFx._mat()` and `LDFx.flame()`.
   - This fix also covers Dredge.
2. **Cinder Shot must read as a red-pink fireball, not a white ball.**
   - Evidence: `cinder_release.png`.
   - Change, in `LDFx._build_rider("cinder")`:
     - The halo is additive `6a5aff` at 0.85 scale and the head's core is white at 1.3 gain. Drop the core gain to about 0.6 and make the head `ff3a5a` at about 0.45 scale.
     - Put the violet halo on the blend-mix pass at about 0.6 alpha.
     - Make the trail a dark smoke ribbon on the mix pass (`3a2a3a`, alpha about 0.7), 1.6 m long.
   - On a hit, check that `fx.embers()` and the red `fx.orb` in `_cinder_hit` are visible. Neither shows in `cinder_impact*.png`: the emitters may need a minimum particle size or count.
3. **Show the flame skull during the ram.**
   - Evidence: `ram_skull.png`, `anim/ram.png` f2.
   - `_tick_bash` places the "skull" crescent at 1.0 scale, about 0.95 m up and 0.35 m forward, and it is hidden inside the body.
   - Change: scale it to about 1.6, move it to about 0.9 m forward of the chest, tilt it to face the camera (a 30-40° pitch toward the view), and put it on the mix pass so the orange-red crescent reads against grass. Lengthen the ember tails (`Tail*` scale z 1.6 → 2.5).
   - Retake `ram_skull.png` mid-flight, before contact.
4. **Furnace Cloak: arms flung wide, and a jagged burst.**
   - Evidence: `anim/cloak.png`. The arms never leave the gun.
   - Change: in `as_cloak`, release the weapon grip for 0.12-0.6 s. Use the weapon-pivot channel the care pair added (`wa`/`wo`, `kmoves_care.gd`), or swing the flamer to the back with `gp`, so both hands can fling out.
   - Make `LDFx.sunburst` spikier: about 14 sharp triangular rays with a jagged edge, the reference's sunburst read but in our palette.
   - Retake the 0.2 s ring-only frame. `cloak_ring.png` is currently the blast.
5. **The Flashover payoff animation never plays during the lance.**
   - Evidence: `anim/flashover.png` (5 identical frames).
   - Code: `ashwick_kit.gd` `_ignite()` and `on_knock()`, `if not was_held: play("lw_stoke")`.
   - Change: play it as a layered upper-body overlay (off fist pump, head toss) that doesn't break `as_lance`, or briefly blend `lw_stoke`'s `fl`/`p` keys over the hold. Exaggerate it: fist above the head, body bounce `lift` 0.2.
6. **The Torch Lance pose is nearly static.**
   - Evidence: `anim/lance.png`, where frames 2-6 are almost the same.
   - Change, in `as_lance`:
     - Raise the 0.2 s roar kick (`p` 0.22 → 0.4, `sq` -0.3).
     - Add a looping hose recoil wobble while held (±0.06 pitch at about 8 Hz from the kit).
     - Swing the hat brim and the bellows (secondary motion).
   - Make the cyan pilot about 2x bigger (`_tick_tells` scale 0.2 → 0.4) so the warm/cool read survives at gameplay zoom.
   - Retake the strip with the fire on: frames 4-6 currently show no stream.
7. **Air-dash capture oddity.** In the last frame of `anim/air_hop.png` the camera is inside a pink sphere. Check that the hop near the arena edge doesn't drop him into the void, and that the demo camera isn't clipping into a dummy (`arena_demo_pair.gd`). Retake.
8. **Flashover health-bar glow.** The reference shows the bar itself glowing orange-red at Blazing. Today the glow is a blob behind the pips. Optional: tint the overhead bar frame while `lvl >= 2` (`_tick_tells`).
