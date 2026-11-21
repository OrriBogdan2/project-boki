# Review: Dredge, branch origin/ext/kitfix-linwick-dredge @ a5590a1

**Verdict: PASS WITH FIXES**

The mechanics are a strong match.
- The gun fires every 0.5 s, its slugs stop at 6.3 m, and it shows two edge lines while firing and one line when idle.
- The grab: the hook flies over rocks and props and drags the target over them (the owner's later note), the caster is Grounded while he reels, the target is stunned, a strafe swings the body, and it scoops wisps.
- Anchor: a hop, then the slam at 0.38 s with a 1.1 s stun.
- Air E (owner): a straight-down smash, a landing ring and height damage.
- Barge: toward the cursor, and further in the air.

The problems are visual.
- The signature looks (the ghost anchor, the slug dots, the barge burst) are gold, cream or white and drawn additive, so they disappear on the yellow-green arena. The giant anchor, the source's most distinctive beat, is not visible in any frame.
- Status words stack on top of each other and become unreadable.
- There's no screenshot of the owner's grab-through-rocks override.

Ratings: 1 mechanic, 2 animation, 3 telegraph/reticle, 4 VFX distinctness, 5 bugs/oddities, 6 clean room. Scores are 1-5, with ok or fix.

| Ability | 1 Mech | 2 Anim | 3 Tele | 4 VFX | 5 Bugs | 6 Clean | Note |
|---|---|---|---|---|---|---|---|
| Passive Salvage | 4 ok | 2 fix | n/a | 3 ok | 4 ok | 5 ok | `dr_flex` is barely visible (`anim/salvage.png`). The SALVAGE word does the work. |
| LMB scattergun | 5 ok | 3 ok | 4 ok | 2 fix | 3 fix | 5 ok | The barrel kick reads (`anim/gun.png` f2-3), but the side-on torso turn is weak. The cone lines are good. The slugs are invisible in flight, and their "violet" stop dots render white (`gun_slugs_hang.png`). `gun_idle_line.png` shows a firing frame (muzzle fan and cone), not the idle single line. |
| RMB Grapnel | 5 ok | 2 fix | 4 ok | 3 fix | 2 fix | 5 ok | The braided rope reads (`grapnel_reel.png`), but it is thin and the claw head is hard to see. The "punch out" throw pose doesn't read (`anim/grapnel_throw.png`). The reel frames are identical (`anim/grapnel_reel.png`). A 3 s GROUNDED word over his head hides the haul. The toast says "GROUNDED · no dash, jump or glide", but the barge does work during the reel. No shot shows the hook over a rock. |
| Shift Barge | 5 ok | 4 ok | n/a | 2 fix | 4 ok | 5 ok | The shoulder-first lumber is visible (`anim/barge.png` f2-3). The start burst is a white-yellow flash, where the reference is a red spiky burst plus an ember scorch. The trail is a yellow comet. |
| Air dash (`dr_hop`) | 4 ok | 3 fix | n/a | 3 ok | 2 fix | 5 ok | The last frames of `anim/air_barge.png` are inside a pink/red sphere at "DUMMY" (Linwick has the same oddity). |
| E Anchor Drop (ground) | 5 ok | 3 fix | 3 fix | 1 fix | 2 fix | 5 ok | The hop and slam timing are right. The ghost anchor is not visible in `anchor_slam.png` or in `anim/anchor.png` f4, and the crescent is a faint lilac arc. On the target, "STUNNED" and "GROUNDED" print on top of each other and read as "GROUNNED" (`anchor_stun.png`, `air_quake_b.png`). The stun spiral looks like a white disc. |
| E Anchor Drop (air, owner) | 5 ok | 3 ok | 3 fix | 2 fix | 3 fix | 5 ok | It goes straight down, and the ring and height damage are built. The landing ring is a faint white circle (`air_ring.png`). The anchor falling beside him is not visible. The impact is a generic white-yellow radial flash (`air_quake.png`). |

## FIX list (ranked by impact)

1. **Make the anchor visible: the reference's signature beat, and the owner's "anchor lands with him".**
   - Evidence: `anchor_slam.png`, `air_quake.png`, `air_ring.png`, `anim/anchor.png`, `anim/anchor_air.png`. No anchor appears in any of them.
   - Cause: `LDFx._anchor_node` uses `Models.glow_mat(Color(ANCHOR_COL "ffcf70", 0.7))`, which is translucent pale gold on yellow grass. `anchor_drop()` lands at 35% of 0.6 s, from 3.2 m up, at scale 0.8 (0.62 in the air). `_tick_dive` places it at 0.55 scale next to his legs.
   - Change:
     - Give the anchor an opaque dark iron body (`3a3f48`), a bright cyan or seafoam rim glow (a hue that contrasts with grass and is still "harbour"), and a fresnel outline.
     - Scale 1.2 on the ground and 1.0 in the air.
     - Hold it planted for about 0.25 s after impact before it fades.
     - In the air dive, place it at full size directly under him, ahead of the fall, so it reads as "riding the anchor down".
   - Where: `ld_fx.gd` `_anchor_node`, `anchor_drop`; `dredge_kit.gd` `_anchor`, `_tick_dive`, `_quake`.
2. **Overlapping status words.**
   - Evidence: `anchor_stun.png`, `air_quake_b.png` ("GROUNNED"), `grapnel_hauled.png` ("HAULED" over "GROUNDED").
   - Change:
     - Stack words vertically with a slot offset per target: give `m.fx.word` an age-based y offset, or a per-entity word queue.
     - Or pick one word per event: ANCHORED replaces the separate STUNNED/GROUNDED pair.
   - Where: `dredge_kit.gd` `_slammed` (the ANCHORED word) and `KitStatus.apply(f, "gnd")` labels. A shared fix in `fx.word` would help every hero.
3. **No evidence for the owner's "grab goes through rocks".** Add a screenshot of the hook flying over a rock, with the rope drawn through the occluder, and a strip of the target dragged over it. The combo check asserts it, but the owner reviews pictures. Where: `arena_demo_pair.gd`, a new `dr_rock` demo.
4. **Wrong Grounded toast during the reel.**
   - `kit_status.gd:91` always says "no dash, jump or glide", but `Hunter.do_dash` lets a reeling Dredge barge (the doc and the card say so).
   - Change: pass a reason or variant to `KitStatus.apply(h, "gnd", t, {"label": "no jump or glide"})`, or check `DredgeKit.reeling(h)` before the toast.
   - Also shrink or move the 3 s overhead "GROUNDED" word on the caster: use the chain ring at his feet as the tell, as the source does.
5. **The VFX palette disappears on bright ground: slugs, barge burst, quake, rope.**
   - Evidence: `gun_slugs_hang.png` (white dots, not violet), `anim/barge.png` f1 (white flash, not a red spiky burst), `air_quake.png`.
   - Change:
     - Apply the shared blend-mix fix from REVIEW_linwick FIX 1 to `ld_fx.gdshader`.
     - Use the red spiky burst plus scorch at `from` for `_barge_burst` (the reference, `0188`): `ff3a2a` spikes on the mix pass.
     - Make the slug rest dot `SLUG_REST` opaque violet with a dark core.
     - Thicken the rope from 0.22 to about 0.32, with a darker strand alternating with the gold one. Make the claw about 1.5x bigger.
6. **The reel animation is static.**
   - Evidence: `anim/grapnel_reel.png` (6 identical frames).
   - `dr_reel` alternates hands every 0.26 s with tiny deltas. Exaggerate it: `fl`/`fr` z swing ±0.5, body pitch 0.25 ↔ 0.5, a twist ±0.2. Make the rope pulse taut on each haul (a width bump in `fx.rope`).
   - The throw (`dr_throw`): the free-arm punch isn't visible top-down. Add a forward lean `p` -0.5 and a shoulder `y` swing of ±0.9.
7. **`dr_flex` and the shot recoil.** Exaggerate `dr_flex`: `lift` 0.2 and fists clearly above the shoulders. In `dr_shot`, raise `y` 0.45 → 0.8 so the side-on turn reads from above (reference `0080`).
8. **Retake mislabelled or missing shots:** an idle single line (`gun_idle_line.png` shows firing), and the slug streaks mid-flight. Also look into the air-dash pink-sphere frame (see REVIEW_linwick FIX 7).
