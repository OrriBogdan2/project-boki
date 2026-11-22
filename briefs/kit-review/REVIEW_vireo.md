# Review: Vireo (id `mage`), branch origin/ext/kitfix-vireo-venator @ 2c83b4d

**Verdict: PASS WITH FIXES.** The mechanics and aim modes follow the footage and the owner:
- **LMB:** `aim: max` to 13 m every 0.8 s, with the line through the cursor to full range.
- **RMB:** a fixed 13 m double-rail lane, a white body flash at full, and an orb at the impact.
- **Shift (Wirerun):** a charge-length dash with the cooldown on press. While held, no self-steering, height held and momentum drift. It is reset only by a full-Static foe.
- **E (Skycall):** place, then flick the drag direction, then the countdown pillar.
- **Static marker:** a stack marker with a sky bolt at 4.

What's weak is the owner's finger-gun firing animation, which is barely visible. The summoned rod isn't readable either, and some shots show a RELOADING state that shouldn't exist.

## Ratings

1 = mechanic fidelity, 2 = animation, 3 = telegraph/reticle, 4 = VFX distinctness, 5 = bugs/oddities, 6 = clean room.

| Ability | 1 | 2 | 3 | 4 | 5 | 6 | Note |
|---|---|---|---|---|---|---|---|
| Passive: Static, marker, Live | ok | ok | fix | ok | ok | ok | `static_2.png`: a small cyan "2" overlapping the target's head/chest, low contrast; the sparks are tiny white squares. `static_live.png`: a good sky bolt and LIVE. |
| LMB: finger bolt (owner note) | ok | **fix** | ok | fix | fix | ok | `anim/vireo/anim_lmb.png`: 6 near-identical frames. No visible arm extension, snap or fingertip crackle. `lmb_bolt.png`: a short pale-cyan streak; the jagged shape isn't readable at zoom. `lmb_aim.png` before/after: the line now runs to full range, good. |
| RMB: Storm Rod | ok | fix | ok | ok | **fix** | ok | `rmb_aim`, `rmb_full`: good rails and body flash. `anim_rmb_hold`: no tall rod prop visible by the shoulder, and **RELOADING** shows over her for the whole hold. `rmb_impact`: a good spark-ring impact. |
| RMB orb | ok | n/a | n/a | fix | ok | ok | `rmb_orb.png`: a plain white glowing sphere. The source is a crackling yellow orb with arcs; ours should have its own crackle. |
| Shift: Wirerun | ok | ok | ok | ok | ok | ok | `dash_aim_mid`/`full`: the end ring slides out by charge. `dash_run`: a lightning streak. `dash_arrive`, `blowout`: strong. |
| E: Skycall | ok | **fix** | ok | fix | ok | ok | `e_aim.png`: a ticked circle and the drag arrow toward her, good. `e_count.png`: the disc is pale green-yellow, not the doc's dark violet with a copper rim, and still reads as a plain ring (the owner's complaint). `anim_e`: almost no motion. |
| Base air dash (`mage_dash_ex`) | ok | n/a | n/a | n/a | n/a | ok | No strip supplied. |
| Clean room | | | | | | ok | Goggles, wrist coils and the pennant mast are our own. |

## FIX list (ranked by impact)

1. **The finger-gun firing animation must read** (owner note 16).
   - Evidence: `anim/vireo/anim_lmb.png` and `lmb_bolt.png`: the arm stays at her side.
   - Change, in `KMovesVV["mage_lmb_l"/"mage_lmb_r"]`:
     - Anticipation at 0.03 s: the hand drawn back to the chest.
     - At 0.06 s: the arm fully extended toward the cursor (`fl` z ≈ -0.75, shoulder height y 0.25), index finger pointing (the `"finger"` hold).
     - At 0.09 s: a recoil snap up about 15° (`gp`/hand pitch).
     - Settle by 0.35.
   - Add a 0.08 s cyan-white crackle burst (3-4 arc sprites) at the fingertip on every shot, in VVFx.
   - Make the bolt a jagged zig-zag ribbon about 1.2 m long, not a short straight streak.
2. **The RELOADING state on Vireo.**
   - Evidence: `anim_rmb_hold.png` (every frame), `rmb_aim.png`, and the "COILCASTER 12/12" HUD in `rmb_impact.png` and `dash_aim_full.png`.
   - `coilcaster.json` has `mag` 99. Either the shots were taken with stale data, or the rod hold empties or reloads the weapon.
   - Check `fire_ok`/`rmb` press handling in `mage_kit.gd` and `Hunter` reload on secondary, then retake the shots.
3. **A visible summoned Storm Rod.**
   - Evidence: `anim_rmb_hold.png` shows a white orb at the hand and no rod.
   - Change: `_summon_rod()` should build a 1.3 m copper rod with a teal crackling tip, held upright by the right shoulder (source: a tall spear upright at her side). Spawn it with a burst flash on press. Raise the arm in `mage_rmb_hold` (`fr` y +0.5).
4. **Skycall area identity** (owner: "reads as a generic ring").
   - Evidence: `e_count.png`.
   - Change, in VVFx `disc`:
     - A dark violet filled disc (alpha about 0.55).
     - A crackling copper rim (animated jagged band, not a clean circle).
     - The rim chevron in gold.
     - Lightning veins inside.
   - Keep the narrowing pillar.
5. **Stack marker over the head** (owner note 14).
   - Evidence: `static_2.png`: the "2" sits on the model.
   - Change: in `VVFx.marker()`, place it above the HP bar (`_top(f)` + 0.5 m). Add 4 pips with a bold number on a dark backing, and scale the body sparks per stack (stack 1: 2 sparks; 4: 8 plus arcs). Today they are tiny white squares.
6. **Skycall cast animation.**
   - Evidence: `anim_e.png`.
   - Change: in `mage_e`, a one-arm sweep toward the spot, then an arm-up flick for the drag direction during the 0.3 s flick window, then a snap down at the strike.
7. **Orb look.**
   - Evidence: `rmb_orb.png`.
   - Change: a crackling teal-gold orb with 2-3 short arcs, distinct from the generic white glow sphere used elsewhere.
8. **Strip for the air dash.** Add `mage_dash_ex` and the `mage_live` proc strip under anim/.
